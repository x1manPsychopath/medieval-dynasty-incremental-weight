-- IncrementalWeight: adjust max carry weight at runtime (UE4SS v3.0.1).
-- F5: -10 kg   F6: +10 kg   F7: diagnostics dump
local MOD_NAME = "IncrementalWeight"
local STEP = 10.0
local MIN_OFFSET = -500.0
local MAX_OFFSET = 5000.0
local REAPPLY_MS = 2000
local DUMP_FILE = "IncrementalWeight_dump.txt"

-- Candidate owner classes (short names; not all may exist in a given game build).
local CLASS_CANDIDATES = {
    "BP_PlayerCharacter_C", "PlayerCharacter", "BP_Player_C", "BP_MDPlayerCharacter_C",
    "InventoryComponent", "BP_InventoryComponent_C", "PlayerInventoryComponent",
    "BP_PlayerInventory_C", "CharacterInventoryComponent",
}

-- Candidate property names, in priority order.
local PROPERTY_CANDIDATES = {
    "MaxCarryWeight", "MaxWeight", "MaxInventoryWeight", "MaxCarryingWeight",
    "CarryWeightMax", "WeightLimit", "MaxLoad", "CarryCapacity", "MaxCapacity",
    "CarryWeight", "InventoryMaxWeight",
}

-- Keywords for reflection fallback scan (lower-case, matched against property names).
local SCAN_KEYWORDS = { "weight", "carry", "capacity", "load" }
local SCAN_EXCLUDE = { "current", "total", "used", "min", "bone", "cloth", "animation" }

local offset = 0.0
local state = {}      -- [objectKey] = { base = number, written = number }
local propCache = {}  -- [className] = property name

local function log(fmt, ...)
    local ok, msg = pcall(string.format, fmt, ...)
    print(string.format("[%s] %s\n", MOD_NAME, ok and msg or tostring(fmt)))
end

local function isValid(obj)
    if obj == nil then return false end
    local ok, v = pcall(function() return obj:IsValid() end)
    return ok and v == true
end

local function safeName(obj)
    local ok, n = pcall(function() return obj:GetFullName() end)
    return ok and n or "<unknown>"
end

local function readNumber(obj, prop)
    local ok, v = pcall(function() return obj[prop] end)
    if ok and type(v) == "number" then return v end
    return nil
end

local function writeNumber(obj, prop, value)
    local ok = pcall(function() obj[prop] = value end)
    return ok
end

-- Reflection fallback: returns list of numeric property names matching keywords.
local function scanProperties(obj)
    local found = {}
    local ok, err = pcall(function()
        local cls = obj:GetClass()
        while cls ~= nil and isValid(cls) do
            cls:ForEachProperty(function(p)
                local okn, name = pcall(function() return p:GetFName():ToString() end)
                if okn and type(name) == "string" then
                    local l = name:lower()
                    local hit, bad = false, false
                    for _, k in ipairs(SCAN_KEYWORDS) do if l:find(k, 1, true) then hit = true end end
                    for _, k in ipairs(SCAN_EXCLUDE) do if l:find(k, 1, true) then bad = true end end
                    if hit and not bad and readNumber(obj, name) ~= nil then found[#found + 1] = name end
                end
            end)
            local okp, parent = pcall(function() return cls:GetSuperStruct() end)
            if not okp then break end
            cls = parent
        end
    end)
    if not ok then log("scanProperties error: %s", tostring(err)) end
    return found
end

local function detectProperty(obj, className)
    local cached = propCache[className]
    if cached and readNumber(obj, cached) ~= nil then return cached end
    for _, name in ipairs(PROPERTY_CANDIDATES) do
        if readNumber(obj, name) ~= nil then
            propCache[className] = name
            log("Detected weight property '%s' on %s", name, className)
            return name
        end
    end
    local scanned = scanProperties(obj)
    if #scanned > 0 then
        propCache[className] = scanned[1]
        log("Reflection fallback chose '%s' on %s (%d candidates; run F7)", scanned[1], className, #scanned)
        return scanned[1]
    end
    return nil
end

local function collectTargets()
    local targets = {}
    for _, className in ipairs(CLASS_CANDIDATES) do
        local ok, list = pcall(FindAllOf, className)
        if ok and type(list) == "table" then
            for _, obj in ipairs(list) do
                if isValid(obj) then targets[#targets + 1] = { obj = obj, class = className } end
            end
        end
    end
    return targets
end

-- Applies baseline + offset. If the game changed the value since our last write
-- (backpack swap, perk, load, respawn, recalculation) the new value becomes the baseline.
local function applyAll(reason)
    local applied = 0
    for _, t in ipairs(collectTargets()) do
        local prop = detectProperty(t.obj, t.class)
        if prop then
            local key = safeName(t.obj)
            local cur = readNumber(t.obj, prop)
            if cur ~= nil then
                local s = state[key]
                if s == nil or math.abs(cur - s.written) > 0.001 then
                    s = { base = cur, written = cur }
                    state[key] = s
                end
                local target = math.max(0, s.base + offset)
                if math.abs(cur - target) > 0.001 then
                    if writeNumber(t.obj, prop, target) then
                        s.written = target
                        applied = applied + 1
                    else
                        log("Failed to write %s on %s", prop, key)
                    end
                end
            end
        end
    end
    if applied > 0 then log("Applied offset %+.1f kg to %d object(s) (%s)", offset, applied, reason) end
    return applied
end

local function changeOffset(delta)
    ExecuteInGameThread(function()
        local new = math.min(MAX_OFFSET, math.max(MIN_OFFSET, offset + delta))
        offset = new
        local n = applyAll("keybind")
        if n == 0 then log("Offset now %+.1f kg but no target updated (run F7)", offset) end
    end)
end

local function dumpDiagnostics()
    ExecuteInGameThread(function()
        local lines = { string.format("%s diagnostics, offset=%+.1f", MOD_NAME, offset) }
        local any = false
        for _, className in ipairs(CLASS_CANDIDATES) do
            local ok, list = pcall(FindAllOf, className)
            local count = (ok and type(list) == "table") and #list or 0
            lines[#lines + 1] = string.format("class %s: %d instance(s)", className, count)
            if count > 0 then
                any = true
                local obj = list[1]
                if isValid(obj) then
                    lines[#lines + 1] = "  sample: " .. safeName(obj)
                    for _, name in ipairs(PROPERTY_CANDIDATES) do
                        local v = readNumber(obj, name)
                        if v ~= nil then lines[#lines + 1] = string.format("  candidate %s = %s", name, tostring(v)) end
                    end
                    for _, name in ipairs(scanProperties(obj)) do
                        lines[#lines + 1] = string.format("  scan %s = %s", name, tostring(readNumber(obj, name)))
                    end
                end
            end
        end
        if not any then lines[#lines + 1] = "No candidate class instances found; load into a save first." end
        for k, v in pairs(propCache) do lines[#lines + 1] = string.format("cached %s -> %s", k, v) end
        for _, l in ipairs(lines) do log("%s", l) end
        local f = io.open(DUMP_FILE, "w")
        if f then
            f:write(table.concat(lines, "\n"), "\n")
            f:close()
            log("Dump written to %s (relative to the game's working directory)", DUMP_FILE)
        else
            log("Could not write %s", DUMP_FILE)
        end
    end)
end

local function register(key, fn, label)
    local ok, err = pcall(RegisterKeyBind, key, fn)
    if not ok then log("RegisterKeyBind %s failed: %s", label, tostring(err)) end
end

register(Key.F5, function() changeOffset(-STEP) end, "F5")
register(Key.F6, function() changeOffset(STEP) end, "F6")
register(Key.F7, dumpDiagnostics, "F7")

-- Persistence: periodic re-apply covers save loads, backpack changes, perks, respawns and
-- fast travel without depending on unverified hook paths.
LoopAsync(REAPPLY_MS, function()
    if offset ~= 0 then
        ExecuteInGameThread(function()
            local ok, err = pcall(applyAll, "loop")
            if not ok then log("Periodic re-apply failed: %s", tostring(err)) end
        end)
    end
    return false
end)

log("Loaded. F5 -%d kg, F6 +%d kg, F7 diagnostics.", STEP, STEP)

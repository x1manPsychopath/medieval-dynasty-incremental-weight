-- IncrementalWeight: adjust max carry weight at runtime (UE4SS v3.0.1).
-- F6: -10 kg   F7: +10 kg   F8: diagnostics dump (F5 is the game autosave key)
local MOD_NAME = "IncrementalWeight"
local STEP = 10.0
local MIN_OFFSET = -500.0
local MAX_OFFSET = 5000.0
local REAPPLY_MS = 2000
local DUMP_FILE = "IncrementalWeight_dump.txt"

-- Verified from the UE4SS object dump (Medieval Dynasty 2.7.4.0): the player's inventory is an
-- InventoryComponent_C with PlayerCharacter == true. Its carry limit fields are the *OverloadWeight
-- floats. Runtime F8 dump of the player inventory: InitialOverloadWeight=35 (matches the HUD limit),
-- FinalOverloadWeight=0 at first load, 50 later.
local CLASS_CANDIDATES = { "InventoryComponent_C" }
-- Initial = HUD limit / slowdown threshold (confirmed: HUD moved 35 -> 65). Final = 50 on the player and is
-- probably the hard cap, so both receive the offset (unconfirmed for Final; verify by carrying > 50 kg).
local PROPERTY_CANDIDATES = { "InitialOverloadWeight", "FinalOverloadWeight" }
-- Floats shown by F8 so the Mule skill (+5 kg/level) can be matched to the right field.
local DIAG_PROPERTIES = {
    "InitialOverloadWeight", "FinalOverloadWeight", "BaseInitialOverloadWeight",
    "BaseFinalOverloadWeight", "CurrentTotalWeightOfInventory",
}

local offset = 0.0
local state = {}      -- [objectKey#property] = { base = number, written = number }

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

-- NPC/animal/storage inventories share the class; only the player's has PlayerCharacter == true.
local function isPlayerInventory(obj)
    local ok, v = pcall(function() return obj.PlayerCharacter end)
    return ok and v == true
end

local function collectTargets()
    local targets = {}
    for _, className in ipairs(CLASS_CANDIDATES) do
        local ok, list = pcall(FindAllOf, className)
        if ok and type(list) == "table" then
            for _, obj in ipairs(list) do
                if isValid(obj) and isPlayerInventory(obj) then targets[#targets + 1] = { obj = obj, class = className } end
            end
        end
    end
    return targets
end

-- Applies baseline + offset. If the game changed the value since our last write
-- (backpack swap, perk, load, respawn, recalculation) the new value becomes the baseline.
local function applyAll(reason)
    local applied = 0
    local changed = {}
    for _, t in ipairs(collectTargets()) do
        for _, prop in ipairs(PROPERTY_CANDIDATES) do
            local key = safeName(t.obj) .. "#" .. prop
            local cur = readNumber(t.obj, prop)
            -- A zero value means the game has not initialised the field yet; never raise it from 0.
            if cur ~= nil and (cur > 0 or state[key] ~= nil) then
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
                        changed[t.obj] = true
                    else
                        log("Failed to write %s on %s", prop, key)
                    end
                end
            end
        end
    end
    -- Runtime test: the game only re-evaluates the "overloaded" (immobile) state when inventory weight is
    -- recalculated, so a raised limit did not free the player until an item was added. Trigger that recalc.
    for obj in pairs(changed) do
        local ok, err = pcall(function() obj:UpdateTotalWeightOfInventory_BPI() end)
        if not ok then log("UpdateTotalWeightOfInventory_BPI failed: %s", tostring(err)) end
    end
    if applied > 0 then log("Applied offset %+.1f kg to %d value(s) (%s)", offset, applied, reason) end
    return applied
end

local function changeOffset(delta)
    ExecuteInGameThread(function()
        local new = math.min(MAX_OFFSET, math.max(MIN_OFFSET, offset + delta))
        offset = new
        local n = applyAll("keybind")
        if n == 0 then log("Offset now %+.1f kg but no target updated (run F8)", offset) end
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
                for i, obj in ipairs(list) do
                    if isValid(obj) then
                        any = true
                        local ok2, pc = pcall(function() return obj.PlayerCharacter end)
                        local parts = {}
                        for _, name in ipairs(DIAG_PROPERTIES) do
                            parts[#parts + 1] = string.format("%s=%s", name, tostring(readNumber(obj, name)))
                        end
                        lines[#lines + 1] = string.format("  [%d] player=%s %s | %s", i,
                            tostring(ok2 and pc), table.concat(parts, " "), safeName(obj))
                    end
                end
            end
        end
        if not any then lines[#lines + 1] = "No InventoryComponent_C instances found; load into a save first." end
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

register(Key.F6, function() changeOffset(-STEP) end, "F6")
register(Key.F7, function() changeOffset(STEP) end, "F7")
register(Key.F8, dumpDiagnostics, "F8")

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

log("Loaded. F6 -%d kg, F7 +%d kg, F8 diagnostics.", STEP, STEP)

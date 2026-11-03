# Runtime Test Plan

Target: Medieval Dynasty 2.7.4.0 (Game Pass, `WinGDK`), UE4SS v3.0.1 Beta (`1ceefac8`).
Keys: **F6** = -10 kg, **F7** = +10 kg, **F8** = diagnostics (F5 is the game's autosave).

Status legend: PASS / FAIL / BLOCKED (cannot run until an earlier test passes) / RETEST (code changed since the result).

## Findings from run 1 (log `UE4SS.log`, 2026-11-03)

| Finding | Evidence | Fix |
|---|---|---|
| Deployed `main.lua` is not the repo's `main.lua` (361 lines vs ~210; different config/logging) | File on disk vs repo | Redeploy from repo (see Deployment) |
| Player class guess was wrong: scripts looked for `BP_MasterCharacter_C`; the real class is `BP_PlayerCharacter_C` | Object dump: `/Game/Blueprints/Characters/BP_PlayerCharacter.BP_PlayerCharacter_C` | Mod now targets the inventory component instead |
| The weight data is not on the pawn. It lives on `InventoryComponent_C` floats `InitialOverloadWeight`, `FinalOverloadWeight`, `BaseInitialOverloadWeight`, `BaseFinalOverloadWeight` (+ `CurrentTotalWeightOfInventory`). The player's component has `PlayerCharacter == true` | Object dump, `InventoryComponent.InventoryComponent_C` members | `main.lua` writes `FinalOverloadWeight` on that instance |
| `/Script/Engine.Character:PossessedBy` hook unavailable (harmless) | Log: `hook not available` | None needed; the 2 s loop covers re-application |
| UE4SS lives in `Binaries\WinGDK\ue4ss\` (Mods at `ue4ss\Mods`), not `Binaries\WinGDK\Mods` | Log line 6 `Loading mods from: ...\WinGDK\ue4ss\Mods` | `deploy.ps1` now targets `<Binaries>\ue4ss\Mods` (fixed; see `DeploymentVerification.md`) |

`FinalOverloadWeight` as the field shown in the HUD is an **inference from names**. Test 3 confirms it using the Mule skill (+5 kg per level).

## Tests

### 1. UE4SS startup - PASS
- Expected: UE4SS loads; `Starting Lua mod 'IncrementalWeight'`; keys bound.
- Actual: loaded. Log: `UE4SS - v3.0.1 Beta #0`, `Starting Lua mod 'IncrementalWeight'`, `bound F5/F6/F7`, `loaded.` (old key map).
- Re-check after redeploy: log should say `Loaded. F6 -10 kg, F7 +10 kg, F8 diagnostics.`

### 2. Save-load / player detection - FAIL (old script) -> RETEST
- Expected: after loading a save the mod finds the player's inventory.
- Actual: once per second `player pawn BP_MasterCharacter_C not found yet (no save loaded?)` for 14+ minutes after load. `ClientRestart` hook fired (00:13:05, 00:13:07, 00:22:12, 00:22:19), so the save loaded; the class name was wrong.
- Next: after redeploy, press F8 in-game. Expect a line `[n] player=true ... FinalOverloadWeight=35.0 ...`.

### 3. Property resolution - RETEST (Mule method)
Mule skill: Extraction tree, 3 levels, +5 kg each (per community sources; unverified in this build).
1. Press F8; record all five values for the `player=true` instance and the HUD limit (35 kg).
2. Buy a Mule level (or equip/unequip a backpack); press F8 again.
3. The field that changed by exactly the HUD change is the limit. Expected: `FinalOverloadWeight` (and probably `InitialOverloadWeight`/`BaseFinalOverloadWeight` shift too).
- If a different field moved, change `PROPERTY_CANDIDATES` in `main.lua` to it.
- If both Initial and Final move, test whether Final alone changes the HUD max (Test 4). Initial is likely the slowdown threshold.
- Record: before = ___ after = ___ (paste log lines here)

### 4. F7 increase - RETEST
- Expected: HUD limit 35 -> 45 kg; log `Applied offset +10.0 kg to 1 object(s) (keybind)`.
- Run 1 actual: no change (35 kg), mod had no target. Not valid for the new script.

### 5. F6 decrease - RETEST
- Expected: 45 -> 35 kg (or 35 -> 25); log `Applied offset -10.0 ...`.

### 6. Repeated adjustment - BLOCKED
- Expected: 10 x F7 = +100 kg, one log line per press, no drift. Offset caps at +5000 / -500.

### 7. Bounds - BLOCKED
- Expected: value never below 0; offset clamped at -500 kg.

### 8. Equipment recalculation - BLOCKED
- Expected: after equipping/unequipping a backpack the limit is (new game value + offset) within ~2 s (re-apply loop). Watch for a brief flash of the vanilla value.

### 9. Save/reload persistence - BLOCKED
- Expected: offset is **not** saved by the game; it resets to 0 on game restart (it is held in memory). The game's own value on the saved game is whatever the game writes; if the mod's modified number gets saved, remove the offset in-game (F6) before saving. Record which happens.
- Risk to check: whether the save stores the modified float.

### 10. Fast travel - BLOCKED
### 11. Sleep - BLOCKED
### 12. Seasonal change - BLOCKED
- Expected (10-12): value stays at base + offset after each event; no repeated errors in the log.

### 13. Hot reload (Ctrl+R) - BLOCKED
- Expected: after reload the log shows a single `Loaded.` line and one `Applied` line per key press (no doubled steps). Known risk: `LoopAsync` started before the reload may keep running in UE4SS 3.0.1; if presses double, report it.

## Deployment verification (before retesting)

Run `pwsh .\deploy.ps1 -Target GamePass` (add `-DryRun` first to preview). Full detail in `docs/DeploymentVerification.md`.

| Item | Value |
|---|---|
| Source path | `src\IncrementalWeight\scripts\main.lua` (repo) |
| Target path | `D:\XboxGames\Medieval Dynasty\Content\Medieval_Dynasty\Binaries\WinGDK\ue4ss\Mods\IncrementalWeight\scripts\main.lua` (also reachable as `C:\Program Files\WindowsApps\ToplitzProductionsGmbH.MedievalDynasty_2.7.4.0_x64__xk3erba5yp89y\...`, a junction to the same folder) |
| SHA-256 source | `44552DCA356748B67A50796723F66803945DFAE3F8386264D4C5E6A72AEF91C7` |
| SHA-256 target | `44552DCA356748B67A50796723F66803945DFAE3F8386264D4C5E6A72AEF91C7` (match, 2026-11-03 00:44) |
| Expected target timestamp | `2026-11-03 00:38:48` (Copy-Item keeps the source file's LastWriteTime; it is **not** the copy time) |
| Previous deployed file | 12,667 bytes, 2026-11-01 16:52:30; backed up under `Backups\...-deployed-original` (untracked) |

Hash changes whenever `main.lua` changes; re-run `deploy.ps1` and use the hash it prints. Then confirm `mods.txt` has `IncrementalWeight : 1` (it does), start the game and look for the log line `Loaded. F6 -10 kg, F7 +10 kg, F8 diagnostics.`. If the old `waiting for BP_MasterCharacter_C` line appears, the old file is still loaded.

## Inventory fields (from `UE4SS_ObjectDump.txt`)

All four are `float`s on `InventoryComponent_C` (offsets: Initial 0xB8, Final 0xBC, CurrentTotal 0xC0, BaseInitial 0x128, BaseFinal 0x12C). The mod **writes only `FinalOverloadWeight`**, and only on the instance where `PlayerCharacter == true`. It reads (F8 only) the other four.

| Field | What the dump shows | Interpretation (inferred) |
|---|---|---|
| `InitialOverloadWeight` | Getter `GetInitialOverloadWeight_BPI`; **no Set function**; read by `UI_HUD.UpdateMountWeightHUD`, `BP_HusbandryAI.CalculateEncumberedSpeed`, `BP_AnimalStatsComponent`, `PC_Player.UpdateTimeStatsPer5sec`, `UI_MasterCountSlider` | Lower threshold: carried weight above this starts to encumber (slowdown) |
| `FinalOverloadWeight` | Getter **and** `SetFinalOverloadWeight_BPI`; has `OnRep_FinalOverloadWeight` and the `OnFinalOverloadWeightChange` delegate; read by HUD, `CalculateEncumberedSpeed`, `UI_ManagementDetails_Building.UpdateMoneyAndWeight` (storage weight display, beside `GetCurrentTotalWeightOfInventory`), `BP_AnimalsManager`, `UI_MasterCountSlider` (transfer slider) | Upper limit / displayed maximum capacity |
| `BaseInitialOverloadWeight` | Getter only (`BaseInitialOverloadWeight_BPI`); read by `BP_CrestManager.TryToUnlock_Butterfly` | Unmodified per-owner default, before backpack/skills |
| `BaseFinalOverloadWeight` | Getter only (`BaseFinalOverloadWeight_BPI`) | Unmodified default of Final; the game derives Final from it plus bonuses (backpack, Mule) |

Why `FinalOverloadWeight` is the current candidate:
1. It is the only one of the four that has a setter, a replication callback and a change delegate. That is how a value that perks/backpacks change at runtime is built.
2. Every "max weight" consumer in the dump (storage detail window, animals manager, transfer slider, HUD) reads Final; `CalculateEncumberedSpeed` and the HUD read Initial and Final together, which matches a "slow from Initial, capped at Final" model.
3. The Base* fields have only getters, so they are inputs, not the live value; writing them may do nothing or be overwritten.

What this does **not** prove: the dump holds names and types, not function bodies or values. We have not seen that the 35 kg HUD number equals Final (it could be Initial), nor whether the game recomputes Final from Base on its own schedule (the 2 s re-apply loop covers that). Risks: if the 35 kg shown is Initial, raising only Final will not remove slowdown; if direct writes skip the `OnRep`/delegate, the HUD may not refresh until the game recalculates. Test 3 (F8 before/after a Mule level or backpack swap) decides this; if wrong, change `PROPERTY_CANDIDATES`, or call `SetFinalOverloadWeight_BPI` instead (a change to be made only after a failing run).

## What to send back
`UE4SS.log` after: startup, loading a save, F8, one F7, one F6, and the Mule/backpack comparison. Include the HUD limit at each step.

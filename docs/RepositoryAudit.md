# Repository Audit

Note: the initial repository contained only README and .gitignore; `main.lua`, `deploy.ps1`, `enabled.txt` and the mods.txt template did not exist, so there was no prior code to audit. They were created with the hardening below built in.

## Issues addressed (by design)
| Area | Risk | Fix |
|------|------|-----|
| API usage | Unverified hook paths | Only RegisterKeyBind, ExecuteInGameThread, LoopAsync, FindAllOf, ForEachProperty, GetFName used; no RegisterHook |
| Game-thread safety | Property writes from key/async callbacks | All object access inside `ExecuteInGameThread` |
| Null refs | Stale/invalid UObjects | `IsValid` checks and `pcall` around reads/writes |
| Race conditions | Game recalculating while mod writes | Baseline tracking: externally changed value becomes new baseline |
| Hot reload | Duplicate state/loops | State is local to the script; reload recreates it. Old LoopAsync from previous load may persist — verify manually |
| Logging | Silent failures | Central `log()`; F7 dump to log and file |
| Game Pass / Steam | Different Binaries dirs | deploy.ps1 detects `WinGDK` / `Win64` |
| Deploy | No validation | Path validation, `-DryRun`, `-Verbose`, hash verification |

## Property detection
Candidate class and property lists, then reflection scan (keywords weight/carry/capacity/load) over the class hierarchy; F7 lists everything found.

## Persistence
A 2 s re-apply loop covers save load, backpack change, recalculation, perks, respawn and fast travel without dependence on specific hooks. Limitation: up to 2 s window of vanilla value; if the game resets by writing the same value we wrote, baseline detection cannot distinguish it. Hooks (if needed, found via F7/UE4SS object dump): the inventory recalculation function and the player BeginPlay/restart event.

## Remaining unknowns / manual verification
- Actual class and property names in Medieval Dynasty (candidates are guesses; use F7).
- Whether the weight limit is a stored property or computed by a function (then property writes won't work; a hook is needed).
- Working directory for the dump file; hot-reload behaviour; Game Pass install paths. See `docs/TestingChecklist.md`.
- Offset is not saved across game restarts.
- Lua tooling (luac/luacheck) was run locally; deploy.ps1 only syntax-checked and dry-run on Linux.

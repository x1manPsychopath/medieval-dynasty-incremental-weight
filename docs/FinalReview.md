# Final Engineering Review

## Scope and result

Reviewed every tracked repository file: both GitHub Actions workflows, `deploy.ps1`, `main.lua`, all documentation, mod metadata, `.luacheckrc`, `.gitignore`, and `LICENSE`. No confirmed class/property name for Medieval Dynasty's carry-weight limit could be established without inspecting a running game.

One confirmed diagnostics defect was fixed in this review: the periodic re-apply callback caught errors from `applyAll` and discarded them. It now writes the exception to the UE4SS log. No feature behavior or deployment logic was otherwise changed. The repository is ready for controlled in-game testing, but the game-dependent assumptions below remain unverified.

## Completed / Verified / Pending

- **Completed:** Reviewed the tracked repository, fixed periodic re-apply error logging, and added this report. A pull request is open.
- **Verified:** Both GitHub Actions workflows pass. PowerShell parsing, `git diff --check`, and temporary Steam/Win64 plus Game Pass/WinGDK dry-run and copy/hash checks passed.
- **Pending:** In-game verification remains necessary; follow the manual test list below. Lua tools were unavailable locally, so Lua syntax and lint were validated by the passing CI workflow.

## Confirmed issues

| Finding | Status | Detail |
|---|---|---|
| Periodic re-apply errors were silently suppressed | Fixed in this change | `main.lua` previously called `pcall(applyAll, "loop")` without checking its result. The callback now logs the error, making failures visible in UE4SS logs. |
| No confirmed in-game weight owner/property | Unverified runtime requirement | Class and property candidates in `main.lua` are guesses. F7 output must be checked against the actual max-weight value before relying on any write. |

No confirmed Lua syntax error, invalid use of the reviewed core UE4SS APIs, workflow dependency failure, or deployment path failure was found by static review. This is not a substitute for running the mod under the exact UE4SS v3.0.1 build.

## Potential issues and edge cases

- **Property detection can choose the wrong field.** Candidate names and the keyword scan accept any readable number matching `weight`, `carry`, `capacity`, or `load`. A matching field may be current load or another unrelated value. Confirm the selected field/value in F7 output before changing values in a save.
- **Game-specific assumptions remain unknown.** Candidate classes may not exist in this game's build, the weight limit may be computed rather than stored, or a setter/function may be required. In those cases the mod can load and bind keys without changing the displayed limit.
- **Hot reload may leave old callbacks active.** The script-local state resets on reload, but the repository has no in-game evidence that UE4SS cancels the previous `LoopAsync` loop and keybinds. Check for duplicate effects and log spam after reload.
- **Steam auto-detection covers only the standard `ProgramFiles` Steam locations.** A custom Steam library outside those roots may not be found automatically; use `-GamePath` for that installation. Game Pass detection checks each filesystem drive's `XboxGames\Medieval Dynasty\Content` root and recurses beneath it.
- **Deployment checks the mod payload, not a complete runtime install.** Missing `UE4SS.dll` produces a warning but does not stop deployment. The final hash check verifies `main.lua` and `enabled.txt` presence, and compares the source/destination `main.lua` hash; it does not prove that UE4SS loads the mod or validate every copied file.
- **F7 dump location is process-relative.** `IncrementalWeight_dump.txt` is written relative to the game's working directory and may not be writable. The script logs a failure if `io.open` returns nil.
- **Some read/reflection failures intentionally look like an absent candidate.** `readNumber` and property-name conversion return nil after a protected access fails. F7 is needed to distinguish an inaccessible/missing property from a candidate that is genuinely absent.

## Workflow and deployment review

- `lua-validation.yml` installs Ubuntu packages `lua5.4` and `lua-check`; both package names are valid. `lua5.4` provides `luac5.4`, and `lua-check` provides `luacheck`. The syntax-check and lint commands match the repository layout and `.luacheckrc`.
- `repository-validation.yml` uses `actions/checkout@v4`, checks files tracked in the repository, and parses the deployment script with PowerShell on `ubuntu-latest`. No missing dependency is apparent.
- `deploy.ps1` resolves source files relative to `$PSScriptRoot`; the Steam and Game Pass candidate roots map to `Win64` and `WinGDK` respectively. `Find-Binaries` searches the expected Unreal `Binaries\<platform>` directory to depth 3. Explicit `-GamePath` scans that root; `-Target` restricts the platform as expected.
- PowerShell's parser accepted `deploy.ps1`. Temporary Steam/Win64 and Game Pass/WinGDK fixtures passed `-DryRun` and real deployment; both destination payloads contained `main.lua` and `enabled.txt`, and both `main.lua` hashes matched the source. These checks do not validate a real installation, permissions, or a live UE4SS runtime.
- The core APIs and signatures reviewed against UE4SS documentation include `RegisterKeyBind`, `ExecuteInGameThread`, `LoopAsync`, and `UStruct:ForEachProperty`/`GetSuperStruct`. `LoopAsync` returns `false` to continue and `true` to stop, consistent with the code. The online documentation is not pinned to the exact UE4SS v3.0.1 package; confirm against the installed build if behavior differs.
- Both GitHub Actions workflows passed on the pull request, including Lua syntax/lint and repository/PowerShell validation.

## Runtime assumptions

- UE4SS v3.0.1 is installed beside the game's executable in the matching `Binaries\Win64` or `Binaries\WinGDK` directory, with `Mods` present.
- The game accepts Lua writes to the selected reflected numeric property and recomputes its visible capacity from that property.
- Candidate UObjects remain valid while inspected; the script rechecks validity and protects individual UObject/property operations.
- UE4SS key callbacks run when the game or debug console has focus. Object enumeration, reflection, reads, and writes are dispatched through `ExecuteInGameThread`.
- The game is loaded into a save when testing; no candidate instances before loading is an expected condition.

## Manual game testing still required

1. On a backed-up save, confirm UE4SS v3.0.1 and the mod load; verify the startup line and absence of Lua/UE4SS errors.
2. Press F7 after loading into a save. Confirm a candidate class is present and manually identify the exact property corresponding to displayed maximum carry weight before relying on the mod.
3. Press F5 once and F6 once. Verify the displayed maximum changes by exactly 10 kg each time, never goes below zero, and no unrelated value changes.
4. Test offset bounds with repeated F5/F6 presses; confirm behavior at -500 kg and +5000 kg offsets and inspect logs for misleading or missing diagnostics.
5. Test F7 output and dump-file creation; confirm its actual location and behavior when the destination is unavailable.
6. Save/load, change backpack, gain or lose a relevant perk, respawn, and fast travel. Verify re-application within about two seconds and check that newly changed game baselines are preserved.
7. Hot-reload the mod and repeat one key action. Confirm a single press causes exactly one 10 kg change and that only one periodic loop remains active.
8. Test deployment on real Steam and Game Pass installs, including a nonstandard Steam library via `-GamePath`; confirm the destination files and UE4SS load. Do a dry run before each real deployment.

## Recommended next actions

1. Complete the manual checks above, especially validating the detected property before exercising repeated writes.
2. If standard Steam auto-detection must support custom libraries, add detection for Steam's configured library folders rather than relying only on `ProgramFiles`.

## References

- [UE4SS RegisterKeyBind](https://docs.ue4ss.com/lua-api/global-functions/registerkeybind.html)
- [UE4SS ExecuteInGameThread](https://docs.ue4ss.com/lua-api/global-functions/executeingamethread.html)
- [UE4SS LoopAsync](https://docs.ue4ss.com/lua-api/global-functions/loopasync.html)
- [UE4SS UStruct](https://docs.ue4ss.com/lua-api/classes/ustruct.html)
- [Ubuntu `lua-check` package](https://packages.ubuntu.com/noble/lua-check)

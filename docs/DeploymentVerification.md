# Deployment Verification

## Defect
`deploy.ps1` copied the mod to `<Binaries>\Mods\IncrementalWeight` and required `UE4SS.dll` in `<Binaries>`. UE4SS v3.0.1 as installed for Medieval Dynasty keeps everything in a `ue4ss` subfolder. Run 1's `UE4SS.log` says so:

`Loading mods from: ...\Medieval_Dynasty\Binaries\WinGDK\ue4ss\Mods`

The old script would have failed with "Mods folder missing" (or deployed to a folder UE4SS never reads). The file that ran in game was a hand-copied older version.

## Paths

| | Previous (incorrect) | Correct |
|---|---|---|
| Layout | `<Binaries>\Mods\IncrementalWeight\` | `<Binaries>\ue4ss\Mods\IncrementalWeight\` |
| Steam | `...\steamapps\common\Medieval Dynasty\<Game>\Binaries\Win64\Mods\...` | `...\steamapps\common\Medieval Dynasty\<Game>\Binaries\Win64\ue4ss\Mods\IncrementalWeight\` |
| Game Pass | `...\Binaries\WinGDK\Mods\...` | `...\Medieval_Dynasty\Binaries\WinGDK\ue4ss\Mods\IncrementalWeight\` |

Steam is verified only with a fixture (no Steam install here); the folder name under `common` and the `ue4ss` layout there are assumptions. Use `-GamePath` if different.

### Locations searched
- **Steam:** `%ProgramFiles(x86)%\Steam` and `%ProgramFiles%\Steam`, plus any library listed in `steamapps\libraryfolders.vdf`, under `steamapps\common\Medieval Dynasty` -> `Binaries\Win64`.
- **Game Pass (this machine):** `D:\XboxGames\Medieval Dynasty\Content\Medieval_Dynasty\Binaries\WinGDK`. `C:\Program Files\WindowsApps\ToplitzProductionsGmbH.MedievalDynasty_2.7.4.0_x64__xk3erba5yp89y` is a **junction** to that same folder (same files, same timestamps). The script resolves the junction and de-duplicates so the mod is deployed once. Also searched: `<drive>:\XboxGames\Medieval Dynasty\Content` on every drive.
- Legacy `<Binaries>\Mods` is used only if `ue4ss\Mods` is absent **and** `UE4SS.dll` is in `<Binaries>`; a warning is printed.

## Verification method (per install)
1. Resolve the Mods folder; fail clearly (non-zero exit) if absent.
2. Copy `src\IncrementalWeight\*` to `<Mods>\IncrementalWeight`.
3. Check `scripts\main.lua` and `enabled.txt` exist at the target.
4. Compare SHA-256 of source and target `main.lua`; print both hashes and the target LastWriteTime.
5. Warn if `mods.txt` lacks `IncrementalWeight : 1`.
6. Print `SUCCESS` or `MISMATCH`; any failure ends with an exception (exit 1) after all installs are tried. Copy failures (e.g. read-only ACLs) are reported with an elevation hint.

`-DryRun` prints the resolved target and changes nothing. Note `Copy-Item` preserves the source modification time, so the target timestamp equals the source's, not the deploy time.

## Results (2026-11-03)

| Case | Result |
|---|---|
| Steam fixture `Win64\ue4ss\Mods` | SUCCESS, hashes match |
| Game Pass fixture `WinGDK\ue4ss\Mods` | SUCCESS, hashes match |
| Legacy fixture `Win64\Mods` + `UE4SS.dll` | SUCCESS with warning |
| No Mods folder | error, exit 1 |
| Real install, dry run, `-Target GamePass` and Auto | single target (junction de-duplicated) |
| Real install, deploy | SUCCESS: SHA-256 `44552DCA356748B67A50796723F66803945DFAE3F8386264D4C5E6A72AEF91C7` both sides, LastWriteTime `2026-11-03 00:38:48` |

Previous deployed file (12,667 bytes, 2026-11-01 16:52:30) was backed up to `Backups\<timestamp>-deployed-original\` first.

## Not verified
The game was not launched after deploy; whether UE4SS loads the new file is confirmed only by the next `UE4SS.log` (see `RuntimeTestPlan.md`).

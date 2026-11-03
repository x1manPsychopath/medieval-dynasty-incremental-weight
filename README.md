# medieval-dynasty-incremental-weight
UE4SS Lua mod for Medieval Dynasty that adds configurable incremental carry-weight adjustments with Steam and Xbox Game Pass support.

## Controls
| Key | Action |
|-----|--------|
| F6 | Decrease max carry weight by 10 kg |
| F7 | Increase max carry weight by 10 kg |
| F8 | Diagnostics (log + `IncrementalWeight_dump.txt`) |

## Install
Requires UE4SS v3.0.1. Run `./deploy.ps1 [-Target Auto|Steam|GamePass] [-GamePath <dir>] [-DryRun] [-Verbose]`.
The mod is copied to `...\Binaries\WinGDK\ue4ss\Mods\IncrementalWeight` (Game Pass) or `...\Binaries\Win64\ue4ss\Mods\IncrementalWeight` (Steam), then verified by SHA-256. See `docs/DeploymentVerification.md`.
`enabled.txt` enables it; alternatively add `IncrementalWeight : 1` to `mods.txt` (see `src/IncrementalWeight/mods.txt.template`).

## Docs
[Testing checklist](docs/TestingChecklist.md) · [Repository audit](docs/RepositoryAudit.md) · [CI](docs/CI.md)

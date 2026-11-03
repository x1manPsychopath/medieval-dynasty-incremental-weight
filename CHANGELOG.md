# Changelog

## [Unreleased]
### Added
- `main.lua`: F5/F6 carry-weight adjustment, F7 diagnostics dump, multi-candidate and reflection-based property detection, periodic re-apply for persistence.
- `deploy.ps1`: Steam/Game Pass auto-detection, path validation, `-DryRun`, `-Verbose`, deployment verification.
- Docs (`docs/`), `.luacheckrc`, LICENSE (MIT), CONTRIBUTING, CI workflows.

- Key remap: F6 = -10 kg, F7 = +10 kg, F8 = diagnostics (F5 conflicts with the game's autosave).
- Runtime fix: target the player's InventoryComponent_C (PlayerCharacter == true) and its FinalOverloadWeight, per object dump; removed guess-based class/property scan. F8 prints all OverloadWeight fields for Mule/backpack comparison. Added docs/RuntimeTestPlan.md.
- deploy.ps1: target <Binaries>\ue4ss\Mods (legacy <Binaries>\Mods only as fallback), Steam library folders, Game Pass WindowsApps junction de-duplication, SHA-256 verification with source/target/timestamp output and non-zero exit on mismatch. Added docs/DeploymentVerification.md.

# Contributing

- Target UE4SS v3.0.1 (Lua 5.4). Only use APIs verified for that version.
- Touch game objects only inside `ExecuteInGameThread`, and wrap property access in `pcall`.
- Validate locally: `luac5.4 -p src/IncrementalWeight/scripts/main.lua` and `luacheck src`.
- Test `deploy.ps1 -DryRun -Verbose` for script changes.
- Follow `docs/TestingChecklist.md` before opening a PR; update `CHANGELOG.md`.

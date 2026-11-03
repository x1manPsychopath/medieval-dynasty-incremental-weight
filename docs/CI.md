# CI Workflows
- `.github/workflows/lua-validation.yml` — on push/PR: `luac -p` on every `*.lua`, then `luacheck` using `.luacheckrc`.
- `.github/workflows/repository-validation.yml` — on push/PR: fails if README.md, LICENSE, CHANGELOG.md, CONTRIBUTING.md, deploy.ps1, `src/IncrementalWeight/scripts/main.lua`, `src/IncrementalWeight/enabled.txt` are missing; also parses `deploy.ps1` with PowerShell.

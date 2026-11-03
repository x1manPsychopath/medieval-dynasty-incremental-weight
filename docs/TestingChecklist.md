# Testing Checklist
- [ ] **Fresh install**: UE4SS v3.0.1 installed, run `deploy.ps1 -DryRun -Verbose`, then real run; verification passes; log shows "Loaded".
- [ ] **Game Pass** (`Binaries\WinGDK`): auto-detect finds install; mod loads.
- [ ] **Steam** (`Binaries\Win64`): auto-detect finds install; mod loads.
- [ ] **Hot reload** (UE4SS reload key): no duplicate F5/F6 effect (a single press changes exactly 10 kg), no errors.
- [ ] **F6**: max weight drops by 10 kg per press; never below 0.
- [ ] **F7**: max weight rises by 10 kg per press.
- [ ] **F8**: log shows detected class/property candidates; `IncrementalWeight_dump.txt` written.
- [ ] **Save/load persistence**: adjust, save, reload; offset re-applied within ~2 s. Repeat for backpack swap, perk unlock, respawn, fast travel.
- [ ] Note: offset is per session; restarting the game resets it to 0.

# KERNEL PANIC 3.0.0 — Tester Handoff

Builds in `build/` come from the frozen 3.0.0 tree. Record device, OS,
artifact hash, and PASS/FAIL per item. Any real FAIL blocks release until a
fixed build is retested.

## Key ceremony (Android, READ FIRST)

The original 2.5.0 release key is LOST. 3.0.0 ships under a NEW key:

- Generate the new release keystore now and back it up in two places.
- The QA APK in `build/android` is debug-signed (`CN=Kernel Panic Debug`).
  It is for checklist validation only, NOT the release artifact.
- The author signs the release APK with the new key; record its SHA-256 here.
- Migration path for 2.5.0 users: export progress
  (Settings → Save transfer → Export), uninstall 2.5.0, install 3.0.0,
  import the transfer string. Same-key updates are impossible.

## Linux x86_64 (`build/linux-x86_64/kernel-panic`)

- [ ] clean launch, no crash
- [ ] version shows 3.0.0
- [ ] menu: PURGE, mode/difficulty rows, Story/Archives/Program/Settings/Awards
- [ ] start a Classic run, reach wave 2, take a patch
- [ ] pause/resume, terminal open/close, clean exit
- [ ] Settings: switch EN ↔ PT-BR, restart game, language persists
- [ ] Story: open selector, mount /boot, clear wave 1
- [ ] save persists across restarts (best score / unlocks)

## Windows x86_64 (`build/windows-x86_64/kernel-panic.exe`)

- [ ] clean launch, no crash, no SmartScreen/engine-visible issue
- [ ] version shows 3.0.0
- [ ] menu, run, mode/difficulty
- [ ] language switch + persistence across restart
- [ ] Story, patch, pause, terminal
- [ ] fullscreen/window behavior sane
- [ ] save persists, clean exit

## Android arm64 (`build/android/KERNEL-PANIC-v3.0.0-qa.apk`, debug-signed QA)

Device: ____________________ Android version: ____________________
APK SHA-256: ____________________

- [ ] install (allow unknown apps), version 3.0.0 confirmed in-app
- [ ] sensor-landscape: rotate the device, layout recovers
- [ ] notch/cutout: no actions hidden behind it, no overlap
- [ ] move (left thumb) + aim/fire (right thumb) simultaneously
- [ ] move + aim + DASH (third finger): dash fires, channels kept
- [ ] move + aim + BOOST: boost fires, channels kept
- [ ] pause/resume, background/foreground app switch
- [ ] menu, mode/difficulty, Program selector
- [ ] PT-BR and EN (Settings → language), restart keeps language
- [ ] Story select, intro, combat, victory
- [ ] patch selection by tap (all three cards reachable)
- [ ] save persistence across reopens
- [ ] save transfer export/import round trip
- [ ] audio + haptic sane, no jank in dense wave-7+ combat
- [ ] stability: reopen after kill, no crash

## Reporting

For each FAIL: build hash, device/OS, repro steps, expected vs actual,
screenshot or clip when visual. PASS requires the full list green on the
FINAL signed artifacts, not just the QA builds.

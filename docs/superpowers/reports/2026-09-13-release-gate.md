# KERNEL PANIC 3.0.0 — Release Gate Report (DRAFT)

## RELEASE STATUS: PENDING FINAL GATE RUN

## SOURCE
- branch: feat/design-system-and-glyphs
- HEAD (audit start): 65256925099e0ddb490978134c43ac924b9c4ce1
- final HEAD: TBD (commits below)
- git status final: TBD

## COMMITS (selective, coherent)
TBD

## FIXES (blocker / root cause / files / regression / evidence)
TBD — see sections below.

## AUTOMATED
TBD — final file-logged run counts.

## VISUAL PC
TBD — capture matrix.

## VISUAL MOBILE (forced touch)
TBD — capture matrix.

## ARTIFACTS
TBD — paths, sizes, hashes.

## TESTERS
- Linux: NOT PERFORMED (awaiting author dispatch; handoff ready).
- Windows: NOT PERFORMED (binary not runnable on this host; handoff ready).
- Android: NOT PERFORMED (QA APK debug-signed; release needs author's NEW key).

## KEY CEREMONY (Android)
- Original 2.5.0 key LOST (not on phone, Termux wiped, not on this PC).
- Original cert fingerprint: CN=KERNEL PANIC, OU=OX,
  SHA256 EA:8A:AE:8F:AB:EC:82:57:38:A9:57:B6:8A:90:E5:64:92:35:75:C3:74:54:82:C5:09:45:C3:9C:DA:BA:71:85.
- 3.0.0 MUST ship under a new author-held key (generate once, back up twice).
- 2.5.0 users must uninstall + reinstall; migrate via save transfer.

## DEFERRED
- macOS Story act, Photo Mode, unique Windows-era soundtrack.
- Shipped SHOULD: TempleOS holy music variant.

## PUBLISH
- NOT PERFORMED (no tag, no push, no release, no AUR publish).

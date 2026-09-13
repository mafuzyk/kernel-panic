# KERNEL PANIC 3.0.0 — Release Gate Report

## RELEASE STATUS: NOT RELEASE READY (tester gates pending)

All automatable gates are green. Real-device/real-OS tester validation
(Linux playthrough, Windows, Android) has not been performed in this
session — the handoff and QA builds are ready for the author to dispatch.

## SOURCE

- branch: `feat/design-system-and-glyphs`
- HEAD at audit start: `6525692`
- final HEAD: `abe4c87` (tree clean)
- commits:
  - `2e575df` run-config UI, gameplay regressions A-G, save hardening
  - `3854b5e` story runtime i18n, bounded sweep, settings language selector
  - `dfb32e6` god cadence, reticle modals, purge ring, mobile touch UX
  - `df7ede6` 3.0.0 metadata, packaging, font licenses, docs
  - `abe4c87` footer stacks in compact, explicit min invalidation
- `git diff --check`: clean (enforced per edit; no whitespace errors).

## FIXES

- P0 run-config: MODE/DIFFICULTY rows (`menu_shell.gd`, `menu.gd`).
  Regression: `run_config_interaction` presses the live controls.
- Gameplay: idempotent death, ROOTLET shield, orb cap 40, GOD spawn,
  event banner delegate, absorber→overclock, story hold-restart,
  OOM uid ownership, page-fault cap+ownership, daemon recharge,
  heal semantics + `integrity_restored`. Each with a deep probe.
- Save: typed-assignment sanitizers, import validation, vampic reset.
  Regression: `corrupt_save`, `deep_vampic_reset`.
- GOD cadence: `oracle_interval_for_phase` 2.20/1.90/1.60, roll untouched.
  Regression: monotonic + same-seed oracle checks in `_temple_test`.
- Reticle: PROCESS_MODE_ALWAYS + `_wants_hidden_cursor` predicate.
  Regression: predicate across pause/terminal/patch/resume headless;
  full visibility E2E green on a real display (virtual session).
- PURGE ring: host shrink-wraps the action; footer ring fits its label.
  Regression: geometry checks + `cap-menu-ring.png`.
- Overlay contract: `_overlay_button` now sets the `hit` meta like
  `ScreenKit.action` — its absence silently broke initial keyboard focus.
- Story runtime i18n via `StoryData` localized helpers + 33 klog keys +
  chrome keys; short tab labels; narrow rows. Regression: locale matrix.
- Settings EN/PT-BR selector with rebuild + focus restore.
  Regression: `language_selector`.
- Sweep: patch/terminal/settings/summary/bestiary/man PT-BR.
  Regression: sweep key matrix in `_i18n_test`.
- Multitouch: momentary actions hit-tested before aim allocation;
  disabled boost consumed, never steals aim.
  Regression: three-finger dash/boost + disabled-boost checks.
- Safe areas: `Design.safe_margins` + pure math + touch insets.
  Regression: cutout conversion checks.
- Touch composition: stacked story/bestiary, hidden terminal entry and
  keyboard hints, CONTROLS section hidden, touch-sized targets.
  Regression: `touch_layout` + forced-touch captures.
- Orphan hunt: boss intro quote was built parentless
  (`intro_kit.gd`) — one orphan per arena plus an invisible boss quote.
  Fixed by parenting; micro-test `deep_swap_hygiene` pins the rate.
- Stale-arena waits: mode flips sync, scenes swap deferred — all
  scene waits now match by instance id.
- holy music variant (pitch 1.12, existing stems only).
- Settings slider keyboard focus (grabber highlight; Slider has no
  focus stylebox).
- Menu footer stacks in compact (its 409px min forced the whole menu
  past 432); explicit min invalidation after vertical flips.

## AUTOMATED

- Source, isolated XDG, file-logged (`/tmp/kp3-gate11/autotest.log`):
  exit 0, **1769 AT_PASS, 0 AT_FAIL, 2 AT_SKIP**
  (reticle visibility needs a real cursor; vsync needs a display),
  0 SCRIPT ERROR, 0 Godot ERROR in-run
  (only engine exit-time teardown notes).
- Exported Linux artifact gate: exit 0, AUTOTEST_ALL_PASS, 0 AT_FAIL
  (31 source-only checks skip where scripts ship compiled).
- Virtual-display E2E (`/tmp/kp3-e2e.log`): AUTOTEST_ALL_PASS, 0 AT_FAIL,
  reticle visibility E2E fully green, 0 script errors.

## VISUAL PC

- 1920×1080 PT-BR: menu, game, pause, patch, boss, terminal, program,
  story, settings, bestiary, achievements (`/tmp/opencode/cap-*.png`).
- 1920×1080 EN: menu, no raw keys.
- 1366×768 menu, 1280×720 menu, 720×720 menu: contained.
- Bounded PURGE ring proven (`cap-menu-ring.png`).

## VISUAL MOBILE (forced touch)

- 720×432 menu (no keyboard hints), 960×540 settings (no CONTROLS),
  story (stacked, short tabs), pause (no hints/terminal), patch
  (tap copy), 1280×720 gameplay HUD with touch zones.

## ARTIFACTS (frozen tree, HEAD `abe4c87`)

- Linux x86_64: `build/linux-x86_64/kernel-panic`
  78,588,952 bytes,
  SHA-256 `81485e30eb9f9bcbc418b5ccd0686a2d3e2f532428af1171990530b37e8ebd65`.
- Windows x86_64: `build/windows-x86_64/kernel-panic.exe`
  114,279,656 bytes,
  SHA-256 `b61d9100212eea78d2ea872ac4fa7123d6b353d941800640e313d965d034319c`.
- Android QA: `build/android/KERNEL-PANIC-v3.0.0-qa.apk`
  32,779,857 bytes,
  SHA-256 `8925f3e7a2bd4cfd13827200b86ae45c6777a9d4b31f006d4bf2bcac67710267`,
  debug-signed (`CN=Kernel Panic Debug`), versionCode 6, versionName 3.0.0,
  built from the final tree, apksigner VERIFIED.
  Release APK still needs the author's NEW key (see key ceremony).

## TESTERS

- Linux/Windows/Android: NOT PERFORMED — handoff ready at
  `docs/superpowers/reports/2026-09-13-tester-handoff.md`.

## KEY CEREMONY (Android)

- Original 2.5.0 key LOST (phone/MTP areas, wiped Termux, this PC).
- Original cert: CN=KERNEL PANIC, OU=OX,
  SHA256 EA:8A:AE:8F:AB:EC:82:57:38:A9:57:B6:8A:90:E5:64:92:35:75:C3:74:54:82:C5:09:45:C3:9C:DA:BA:71:85.
- New author-held key generated 2026-09-13: alias `kernelpanic`,
  RSA 4096, valid to 2056,
  SHA256 9F:D5:54:57:5A:25:3B:A9:A9:8F:EC:40:3E:45:A7:2A:8D:EB:0B:06:6F:F7:0E:50:5A:60:D6:39:3F:B4:5E:31.
  Stored at `~/.local/share/kernel-panic/keystore/` — back up twice.
- 2.5.0 users must uninstall + reinstall; migrate via save transfer.

## DEFERRED

- macOS Story act, Photo Mode, unique Windows-era soundtrack.
- Shipped SHOULD: TempleOS holy music variant.

## PUBLISH

- NOT PERFORMED. No tag, no push, no release, no AUR publish —
  per author instruction.

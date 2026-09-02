# Release checklist

This checklist is for a real public release, not merely a green local test run. A release candidate must satisfy every required item or explicitly document why the maintainer accepted the risk.

## Current development checkpoint (not release approval)

The current branch `fuzzy/ui-reference-remake` is a published pre-release
checkpoint at `63c04a8`. The local correctness gate is green, but this section
must not be read as permission to tag or publish the game:

| Gate | Current evidence | Status |
| --- | --- | --- |
| DevHarness and accumulated probes | `1454 AT_PASS`, `0 AT_FAIL`, `AUTOTEST_ALL_PASS`, `VALIDATION OK` | verified locally |
| Legacy HUD physical-window reflow | H8: 4 headless / 14 Xvfb passes, 0 failures at `1600×900` and `1776×975` | verified locally |
| Runtime/script errors | zero gateable runtime errors in the accumulated run | verified locally |
| Teardown ownership | resources/RIDs/ObjectDB diagnostics still present in some fixtures | open |
| vNext migration | vNext remains opt-in; legacy remains default | open |
| PT-BR coverage | catalog/service and selected surfaces exist; legacy player-facing copy remains | open |
| Device/export validation | no release exports or Android device run in this environment | open |
| Human visual/gameplay review | required for direction, telegraphs, balance and feel | open |

The detailed evidence and release verdict are in
[`FINAL-UI-REFERENCE-REMAKE-REPORT.md`](FINAL-UI-REFERENCE-REMAKE-REPORT.md).

## Build and repository hygiene

- [ ] Version, release name, and build metadata are updated intentionally.
- [ ] The release is built from the reviewed commit and the working tree is clean except for approved build output.
- [ ] Project import completes without new parser or resource errors.
- [ ] No `.godot` state, `.uid` files, personal saves, local logs, credentials, editor settings, or orphaned capture imports are in the archive.
- [ ] Linux and Windows release exports are produced and launched.
- [ ] Android arm64 export is produced and installed on at least one representative device, or mobile release is explicitly deferred.

## Automated verification

- [ ] DevHarness finishes with `AUTOTEST_ALL_PASS` and zero `AT_FAIL`.
- [ ] `tools/validate_input_dispatch.sh` completes with `VALIDATION OK`.
- [ ] Every focused probe for the release scope has a completion marker and zero failures.
- [ ] Runtime errors are reviewed separately from expected teardown warnings; no new error is silently excluded.
- [ ] `git diff --check` and any available static checks pass.

## Gameplay and saves

- [ ] New-game, restart, pause, game-over, story completion, unlock, and quit paths work on each release platform.
- [ ] Existing save data loads, malformed data fails safely, and interrupted writes cannot destroy the previous valid save.
- [ ] Input works with keyboard, gamepad where supported, touch, and remapped/accessibility profiles.
- [ ] Difficulty, enemy telegraphs, boss behavior, rewards, and new content receive a human playtest.

## UI, accessibility, and device validation

- [ ] Main menu, settings, story, bestiary, pause, HUD, and game-over are reviewed at narrow, base, and wide aspect ratios, including a maximize/restore cycle while the legacy HUD is active.
- [ ] Touch controls are usable with both hand preferences and do not block critical playfield information.
- [ ] Reduced motion, reduced flashes, color assistance, and available text/contrast options are verified in a live run.
- [ ] Focus order, visible focus, controller navigation, activation feedback, and back behavior are verified.
- [ ] At least one human reviews the visual direction against `docs/ART-DIRECTION-CODE-DRAWN.md`.

## Performance and stability

- [ ] The fixed-seed stress profile passes on the minimum supported desktop target.
- [ ] A representative Android device is measured before declaring mobile ready.
- [ ] No unbounded node, signal, timer, tween, audio, physics, or GPU resource growth is observed across repeated runs.
- [ ] Startup, scene transitions, pause/resume, and shutdown are checked for hangs and resource warnings.

## Maintainer decisions required before publishing

- [ ] Final PT-BR scope and editorial pass are approved.
- [ ] The vNext UI route and migration/deprecation plan are approved.
- [ ] Mobile minimum hardware/OS and desktop minimum hardware/renderer are stated.
- [ ] Native screen-reader, high-contrast, text-scaling, and platform-specific accessibility scope is either verified or clearly listed as unsupported.
- [ ] Known issues are published with workarounds where possible.

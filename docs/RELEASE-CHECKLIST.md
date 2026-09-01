# Release checklist

This checklist is for a real public release, not merely a green local test run. A release candidate must satisfy every required item or explicitly document why the maintainer accepted the risk.

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

- [ ] Main menu, settings, story, bestiary, pause, HUD, and game-over are reviewed at narrow, base, and wide aspect ratios.
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

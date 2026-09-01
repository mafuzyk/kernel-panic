# Handoff — G2C — Display settings

## Branch and commit

- Branch: `codex/plan-execution`
- Worktree: `/tmp/kernel-panic-plan-execution`
- Commit: `0e2afb4` — `feat: add dedicated display settings`
- No merge into `main`.

## What landed

Settings now contains a separate DISPLAY section with fullscreen and target FPS
controls. Target values are 30/60/120/unlimited (`0` internally). New profiles
use 60 for touch contexts and unlimited for non-touch desktop contexts. Values
are normalized and applied to the engine/window immediately.

Persistence uses a new `[display]` section. The old `[feel] target_fps` key is
still read and written, so older settings files and external tools remain
compatible.

## Verification

- Red: `/tmp/kernel-panic-g2c-red2.log`, exit `124` before implementation;
  missing methods/section and no completion marker.
- Headless green: `/tmp/kernel-panic-g2c-green.log`, exit `0`, 13 passes,
  `PROBE_DONE fails=0`.
- Xvfb green: `/tmp/kernel-panic-g2c-xvfb.log`, exit `0`, 13 passes,
  `PROBE_DONE fails=0`.
- `git diff --check`: clean before commit.

## Limits

This is the legacy Settings display slice. vNext promotion, physical Android
and macOS window behavior, device performance and final visual approval remain
open. The touchscreen heuristic is intentionally conservative and should be
validated against actual release hardware.


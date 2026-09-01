# Handoff — M5 macOS surface integration

## Branch and status

- Branch: `codex/plan-execution`
- Worktree: `/tmp/kernel-panic-plan-execution`
- No merge into `main`.
- M5 integration gate is green; final release approval is still blocked by
  human visual, physical mobile, performance, localization, export, and
  repository-release gates.

## Delivered

- Added `permission_root` to the bestiary map and catalog.
- Added stage `RULE` and `REWARD` metadata to the vNext story detail surface.
- Added a focused Mac integration probe covering story data, profiles, era
  overlay, bestiary identity, adapter projection, renderer bounds and
  responsive overflow/list-detail behavior.
- Validated both desktop and narrow dimensions without adding raster art to the
  runtime path.

## Verification

```text
/tmp/m5-macos-release-gate.log
  exit 0, 26 passes, PROBE_DONE fails=0

/tmp/m5-story.log
  exit 0, PROBE_DONE fails=0

/tmp/m5-layout.log
  exit 0, PROBE_RESULT passes=130 fails=0

/tmp/m5-import.log
  editor import exit 0
```

All game invocations used the Dummy audio driver. The full suite and remaining
release checks must still be run after the next batch of changes.

## Review limits

The automated gate proves contract and geometry, not art quality. It does not
approve the visual direction, final boss silhouette, balance, physical touch,
Android export, macOS export, or crash-safe save journaling.

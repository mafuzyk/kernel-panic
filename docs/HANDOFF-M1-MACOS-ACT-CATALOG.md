# Handoff — M1 macOS history act catalog

## Branch and status

- Branch: `codex/plan-execution`
- Worktree: `/tmp/kernel-panic-plan-execution`
- No merge into `main`.
- Focused commits are kept per plan task; generated Godot `.uid` and capture
  import artifacts remain untracked and were not staged.

## Delivered

- Added the separate macOS act catalog with four stable stages:
  `MAC::CLASSIC`, `MAC::AQUA`, `MAC::DARWIN`, `MAC::MODERN`.
- Added English narrative/klog keys and four era presentation profiles.
- Aggregated the act through `StoryData` while preserving all previous stage
  indices and save/transfer keys.
- Added an explicit `Game.story_act_unlocked("macos")` query and linear first
  stage unlock after `temple_god`.
- Added a profile-driven code-drawn arena overlay and Mac act tabs in both the
  legacy and vNext story selectors.
- Replaced stale `UNIX ACT 1` menu copy with the selected stage's dynamic act.

## Verification

```text
godot --headless --audio-driver Dummy --path . --editor --quit
  exit 0

XDG_DATA_HOME=/tmp/kernel-panic-macos-m1-xdg3 \
  godot --headless --audio-driver Dummy --path . \
  --resolution 1280x720 --scene res://tools/macos_story_probe.tscn
  exit 0, PROBE_DONE fails=0

XDG_DATA_HOME=/tmp/kernel-panic-macos-selection-xdg3 \
  godot --headless --audio-driver Dummy --path . \
  --resolution 1280x720 --scene res://tools/vnext_selection_probe.tscn
  exit 0, PROBE_DONE fails=0

XDG_DATA_HOME=/tmp/kernel-panic-m1-suite-xdg1 \
  godot --headless --audio-driver Dummy --path . -- --autotest
  exit 0, 1453 AT_PASS, 0 AT_FAIL, AUTOTEST_ALL_PASS
```

The full suite still reports the established teardown resource/RID/ObjectDB
diagnostics; they are not introduced or fixed by M1 and remain a P/RPO gate.

## Not claimed

- The Mac stages are not yet a complete playable/release-ready act.
- Reward IDs are declarations; reward behavior and export/import proof belong
  to M4.
- The act mechanic and final boss are not accepted by this catalog task.
- PT-BR, accessibility-specific copy, physical mobile behavior, Android export,
  human visual approval and performance budgets remain open.

## Next task

M2: review and localize the narrative slice in English and PT-BR in the actual
story surfaces at wide, compact and narrow densities. Keep strings in the
catalog/service boundary; do not bury copy in `_draw()` code.

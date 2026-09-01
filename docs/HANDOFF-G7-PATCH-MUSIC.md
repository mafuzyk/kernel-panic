# Handoff — G7 — desktop patch music layers

## Branch and checkpoint

- Branch: `codex/plan-execution`
- Worktree: `/tmp/kernel-panic-plan-execution`
- No merge into `main`.

## Delivered behavior

Desktop builds now add a short crossfaded B/C music response when a run gains
an offensive or defensive patch. Existing combat intensity remains intact.
Mobile and headless builds keep patch layers silent and retain the existing
simpler music path. Both legacy Settings and vNext Accessibility provide
independent toggles, persisted under additive `[accessibility]` keys.

The patch mapping is catalog-owned: offensive patches request percussion,
defensive patches request bass, and neutral patches are acoustically neutral.
The map is presentation-only and cannot alter gameplay or records.

## Verification

```text
XDG_DATA_HOME=/tmp/kernel-panic-g7-green-xdg3 timeout 60s godot --headless --audio-driver Dummy --path . --resolution 1280x720 --scene res://tools/g7_patch_music_probe.tscn
XDG_DATA_HOME=/tmp/kernel-panic-g7-green-xvfb-xdg xvfb-run -a timeout 70s godot --audio-driver Dummy --path . --resolution 1280x720 --scene res://tools/g7_patch_music_probe.tscn
XDG_DATA_HOME=/tmp/kernel-panic-g7-access-xdg2 KP_VNEXT_SETTINGS=1 timeout 80s godot --headless --audio-driver Dummy --path . --resolution 1280x720 --scene res://tools/vnext_accessibility_probe.tscn
```

Results: G7 headless 23/0, G7 Xvfb 23/0, and accessibility regression green;
all emitted `PROBE_DONE fails=0`. The Xvfb run reported
`patch_music_supported=true` and exercised both audible layer transitions.

## Known limits

- No human mix/volume approval has been recorded yet.
- Android hardware/audio latency and physical mobile behavior remain open.
- The pre-existing teardown ObjectDB/resource/RID diagnostics are not changed
  by this task and remain tracked separately.
- A future new audio asset set requires a separate design/audio gate.

## Technical report

`.superpowers/sdd/00-MASTER-PLAN/report-G7-patch-music.md`

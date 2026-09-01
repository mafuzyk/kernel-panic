# Handoff — G6 — local death heatmap

## Branch and checkpoint

- Branch: `codex/plan-execution`
- Worktree: `/tmp/kernel-panic-plan-execution`
- No merge into `main`.

## Delivered behavior

Player deaths now record one quantized cell per run. The 12×7 map is scoped by
mode/story stage, stored under the existing Sfx ConfigFile save path, versioned
at schema 1 and bounded to 50 runs per scope. Invalid data is rejected on
load. The aggregate snapshot contains counts rather than screenshots or raw
telemetry.

Game over exposes a low-priority map in both the legacy panel and the vNext
surface. The view is absent when there is no death history and is cleared for
story victory. Retry, abandon, killer/cause and run summary remain separate.

## Verification

```text
XDG_DATA_HOME=/tmp/kernel-panic-g6-xdg3 timeout 30s godot --headless --audio-driver Dummy --path . --resolution 1280x720 --scene res://tools/g6_death_heatmap_probe.tscn
```

Result: exit 0, 33 passes, zero failures and `PROBE_DONE fails=0`.

The pre-feature red run is `/tmp/g6-red.log`. The focused import is
`/tmp/kernel-panic-g6-import2.log`. The final focused run is
`/tmp/g6-green-final.log`. The probe covers malformed version/scope
input, coordinate bounds, duplicate recording, capacity, mode separation and
legacy/vNext layout safety.

## Review notes and limits

- The storage is local-only and uses the established settings path.
- The map is diagnostic, not a gameplay instruction; it is intentionally
  lower priority than the cause and retry controls.
- Physical mobile persistence, disk-full behavior, final visual approval and
  a pattern/legend treatment for color-assist remain open.
- Final aggregate validation is recorded in the master progress ledger after
  the next full-suite checkpoint.

## Technical report

`.superpowers/sdd/00-MASTER-PLAN/report-G6-death-heatmap.md`

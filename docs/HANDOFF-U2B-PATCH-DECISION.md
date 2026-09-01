# Handoff — U2b vNext patch/build decision surface

Branch: `codex/plan-execution`

This handoff records the completed U2b slice. It is an opt-in development
route and does not replace the default legacy patch overlay.

## Run it

From the repository root, use the normal Godot command with the environment
flag below to exercise the new route:

```text
KP_VNEXT_PATCH=1 godot --path .
```

Use the existing normal route without the variable to confirm the legacy
overlay remains in place. Automated focused checks are:

```text
godot --headless --audio-driver Dummy --path . res://tools/vnext_patch_probe.tscn
KP_VNEXT_PATCH=1 godot --headless --audio-driver Dummy --path . res://tools/vnext_patch_arena_probe.tscn
```

## Ownership contract

`VNextPatchSurface` consumes a deep-copied snapshot and emits commands. It does
not mutate `Game.patch_levels`, pause the tree, or decide whether a patch is
valid. `Arena` owns the offer, validates the returned offer identity, applies
the existing gameplay mutation, and resumes the run.

## Current decisions

- Desktop displays all offered patches in readable parallel cards.
- Narrow layouts display one card with previous/next navigation.
- `TRADEOFF` is a visible warning and remains selectable because that is the
  current gameplay rule; locked and unavailable states cannot be confirmed.
- Close, Skip and ESC resume the run without applying a patch.
- Confirm applies exactly one selected patch through the existing Arena path.

## Evidence and residual risk

The surface probe and real Arena probe both finish with `PROBE_DONE fails=0`.
The project suite remains at `1414 AT_PASS`, `0 AT_FAIL`,
`AUTOTEST_ALL_PASS`. Existing exit-time resource/RID/ObjectDB diagnostics
remain open. Visual approval, PT-BR content, persisted accessibility and
device-level mobile validation remain future gates.

Detailed technical reasoning is in
`.superpowers/sdd/00-MASTER-PLAN/report-U2b.md`; release-facing notes are in
`docs/release/2026-09-01-plan-execution.md`.

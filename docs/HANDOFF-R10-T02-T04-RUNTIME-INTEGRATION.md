# Handoff — R10 / T02 / T04 — runtime integration

## Branch and base

- Branch: `codex/r10-event-banner`
- Base: `84cca33` (`codex/r08-oom-loot-isolation`)
- No merge into `main`; no force-push.
- Production change is limited to the Arena event-banner delegate. The remaining changes harden tests and repair the capture harness.

## Commits

- `9ec4d10` — `fix: restore Arena event banner delegate (R10)`
- `c36dcb1` — `test: reject runtime errors across regression probes (T02)`
- `b73f0ef` — `fix: update terminal capture harness route (T04)`

## R10 — event banner delegate

### Cause

Arena subsystems call `arena.show_event_banner(...)`, but `Arena` no longer exposed that delegate. The implementation still existed in `_intro_kit`, so deferred calls failed at runtime with:

```text
ERROR: Error calling deferred method: 'Node2D(arena.gd)::show_event_banner': Method not found.
```

### Fix

`Arena.show_event_banner(txt)` now delegates directly to `_intro_kit.show_event_banner(txt)`. No banner timing, text, drawing, or gameplay rule changed.

### Evidence

- Red: the full headless suite reported `AUTOTEST_ALL_PASS` while also emitting the missing-method runtime error.
- Green: 1418 passes, 0 failures, `AUTOTEST_ALL_PASS`, and 0 runtime/script errors.

## T02 — green tests may not hide runtime errors

### Causes found

1. `tools/validate_input_dispatch.sh` reported every engine/script error as a non-gating baseline.
2. The DevHarness and several probes captured an Arena object inside an asynchronous lambda and then intentionally replaced that scene. Godot passed `null` after the captured object was freed and emitted `Lambda capture at index 0 was freed` even when every assertion passed.
3. Later gameplay probes were not part of the official validation entry point, so their runtime errors were easy to miss.

### Fixes

- Runtime and script errors now fail validation.
- Known shutdown-only resource, RID, and GLES texture diagnostics remain visible but non-gating until ownership is isolated.
- Scene-change predicates retain the previous scene's integer instance ID instead of capturing the scene object.
- The official validator now runs the accumulated R04–R08 gameplay probes in addition to the suite and input probes.
- Every Godot invocation in the validator uses `--audio-driver Dummy`.

### Validator red/green

A fake Godot executable that printed valid completion markers plus `SCRIPT ERROR` reproduced the previous false green:

- Before: `VALIDATION OK`, exit 0.
- After: runtime error listed as gating, `VALIDATION FAILED`, exit 1.

The expanded validator then exposed the freed captures in R04, R05, and R06. Each was reproduced before changing its runner and disappeared after switching the predicate to instance IDs.

Final real validation (`/tmp/kp-r10-final-green.sFT06m/logs`):

| Case | Passes | Failures | Runtime errors |
| --- | ---: | ---: | ---: |
| DevHarness suite | 1418 | 0 | 0 |
| Input dispatch, headless | 32 | 0 | 0 |
| R04 projectile orphan | 7 | 0 | 0 |
| R05 rootlet shield | 28 | 0 | 0 |
| R06 Temple GOD boss | 7 | 0 | 0 |
| R07 Story restart | 4 | 0 | 0 |
| R08 OOM loot isolation | 6 | 0 | 0 |
| Input dispatch, Xvfb debug | 34 | 0 | 0 |

Result: `VALIDATION OK`, exit 0.

## T04 — terminal capture harness

### Cause and fix

The capture mode still called the removed `arena._open_terminal()` API. It now uses the current owner, `arena._panel_kit._open_terminal()`, matching the tested input-dispatch path.

### Visual smoke test

Executed silently under Xvfb with an isolated save:

```bash
XDG_DATA_HOME=<isolated> \
KP_SHOT=terminal \
KP_SHOT_OUT=<output>/terminal.png \
KP_SHOT_FRAMES=5 \
xvfb-run -a godot --audio-driver Dummy --path .
```

Result: `SHOT_SAVED`, 1280x720, terminal visible and populated. Evidence image from this run: `/tmp/kp-t04-fixed.UC82lN/terminal.png`.

## Remaining limitation

The validator still reports resource/RID/texture diagnostics produced during engine teardown. They are not classified as successful cleanup and are not hidden; they remain a separate, explicit non-gating category because this batch did not isolate their owners. Any other `ERROR:` or `SCRIPT ERROR:` line fails validation.

## Reproduction

```bash
KP_VALIDATION_LOGS=<absolute-log-dir> tools/validate_input_dispatch.sh
```

All repository changes outside the files named by these commits were left untouched.

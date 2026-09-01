# Handoff — E4 — ZOMBIE_PROCESS

## Branch and scope

- Branch: `codex/plan-execution`
- Worktree: `/tmp/kernel-panic-plan-execution`
- Base: `295cc0c`
- Implementation commit: `16f6f24` — `feat: add zombie process enemy slice`
- Documentation commits: `8443afb` and the final evidence amendment below
- Scope: first approved new enemy only, `ZOMBIE_PROCESS`.
- Explicit non-scope: `RACE_CONDITION`, `DEADLOCK` and later plan items.

## What changed

The new temporary `ZombieProcessEnemy` blocks player bullets on the existing
enemy layer, stays stationary, is ignored by enemy separation/pathing, and
expires after the named `LIFETIME` of 4 seconds. Damage destruction and expiry
both avoid the normal `died` signal and therefore cannot leak kill rewards.
The arena still removes either instance through its existing child-exit path.

The first story teach wave in `/boot` is `["zombie_process"]`; later waves
retain the existing drone teaching flow. The factory, bestiary/catalog, shared
presentation descriptor/adapter, glyph vocabulary and code-drawn renderer path
all use the stable `zombie_process` kind.

## Red/green history

- Red focused real-path probe: `/tmp/kernel-panic-e4-red-2.log`, exit 1,
  `PROBE_DONE fails=5` before the production implementation.
- Green focused headless probe: `/tmp/kernel-panic-e4-focused-green.log`, exit 0,
  18 passes, `PROBE_DONE fails=0`.
- Green focused Xvfb probe: `/tmp/kernel-panic-e4-focused-green-xvfb.log`, exit 0,
  18 passes, `PROBE_DONE fails=0`.
- Full DevHarness: `/tmp/kernel-panic-e4-suite-2.log`, exit 0, 1414 passes,
  0 failures, `AUTOTEST_ALL_PASS`.
- Aggregate validator summary: `/tmp/kernel-panic-e4-validator-final-summary.log`.
- Final post-commit aggregate: `/tmp/kernel-panic-e4-post-validator.log`.
  It finished `VALIDATION OK`; all cases were green, E4 was 18/0, and no
  runtime ERRORs gated, while known teardown diagnostics remained separate.

## Review notes

The probe was corrected after an initial green attempt exposed a freed lambda
capture. Its async expiry checks now observe stable instance IDs, so the E4
probe itself emits no lifecycle capture error. The renderer snapshot is
read-only and carries `remaining_life`, `lifetime` and `timer_marker`; the
non-color timer representation is drawn by the real enemy `_draw()` path.

The aggregate validator's E2 byte-hash guard needed a narrow expected-baseline
update because E4 intentionally adds a glyph to the shared file. No E2 enemy
implementation was changed. Existing teardown leaks and the import Android
build-tools warning remain outside E4's scope.

## Files and rollback

Runtime/content/test files are listed in `report-E4-zombie-process.md`. Rollback
is the removal/revert of the E4 commit(s), including the focused probe and
documentation; no save migration or external data mutation exists. Generated
`.uid`/capture-import files in the worktree remain unstaged.

## Handoff gate

The slice is ready for independent adversarial review only after the final
fresh aggregate validator result is recorded. Visual approval is not claimed.

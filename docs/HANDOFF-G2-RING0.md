# Handoff — G2B — Ring-0 double overclock

## Branch and commits

- Branch: `codex/plan-execution`
- Worktree: `/tmp/kernel-panic-plan-execution`
- Commit: `8be4d06` — `feat: add ring-0 double overclock`
- No merge into `main`.

## Behavior

The new max-one RING-0 passive patch allows one re-press during an active
overclock. The second press raises the active stack to two and adds one current
overclock duration. It does not spend HP and cannot be repeated beyond two
stacks. A two-stack use imposes a post-use recovery lock equal to one current
overclock duration; immediate reactivation is blocked. A single ordinary use
does not get that lock.

The exact “adds one existing duration” and “lock equals one existing duration”
choices are explicit implementation interpretations because the source rule
specified the relationship but not numeric tuning. They are isolated in the
Player overclock boundary and can be retuned without changing the patch
catalog or input contract.

DAEMON was tested specifically: it can dash during stack one, the re-press does
not cancel the dash, the dash charge is consumed exactly once, and HP remains
unchanged. Rootlet remains shield-only and Ring-0 cannot activate it.

## Verification

- Focused first attempt: `/tmp/kernel-panic-g2b-green.log`, exit `1` because
  the probe's label expected a single-stack fixture while it was testing the
  double-stack player.
- Corrected focused probe: `/tmp/kernel-panic-g2b-green2.log`, exit `0`, `15`
  passes, `0` failures, `PROBE_DONE fails=0`.
- `git diff --check`: clean before commit.

Known teardown diagnostics remain non-gating. No script or compile errors were
present in the final focused log.

## Open product questions

- Confirm by playtest whether a longer active window is the desired meaning of
  “stack,” or whether a future balance pass should strengthen the active
  effect instead.
- Confirm the recovery-lock duration and add a clear visible cooldown state to
  the future rebuilt HUD.


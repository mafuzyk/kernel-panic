# Handoff — G5 — RACE_CONDITION enemy

## Branch and checkpoint

- Branch: `codex/plan-execution`
- Worktree: `/tmp/kernel-panic-plan-execution`
- No merge into `main`.

## Delivered behavior

RACE_CONDITION is a paired enemy. Two independent processes are linked when
their live distance is at most 170px. While linked, each moves at 1.18x its
configured speed. The link is broken by separation, and removing one partner
does not transfer damage or create a shared health pool.

Wave teaching is explicit: wave 4 contains only the pair, wave 6 combines the
pair with DRONEs, and wave 8+ can include the pair in mixed compositions. The
spawner groups race tokens into pairs and repairs an odd later roll by adding
the missing partner at the spawn boundary.

The code-drawn identity is a diamond/cross glyph with a segmented cable,
open brackets and white ticks. The white geometry is intentionally redundant
with the magenta accent so color-assist and grayscale presentation can still
communicate the state. The bestiary and vNext entity presentation paths know
the new identity.

## Verification

```text
timeout 30s godot --headless --audio-driver Dummy --path . --resolution 1280x720 --scene res://tools/g5_race_condition_probe.tscn
```

Result: exit 0, 23 passes, zero failures and `PROBE_DONE fails=0`.

The pre-feature run at `/tmp/g5-red.log` exited 1 with four expected missing
contract failures. The full DevHarness at `/tmp/kernel-panic-g5-suite.log`
exited 0 with 1427 passes, zero assertion failures and
`AUTOTEST_ALL_PASS`.

## Review notes and limits

- The first draft passed the same origin to both pair members because the
  callback compared two equal string tokens. This was corrected before the
  green evidence was accepted.
- The first adapter assertion was too weak and exposed that nested snapshot
  data was being discarded. The adapter now merges nested payloads, and the
  probe validates the live linked state.
- Current numerical tuning is provisional. Human normal/One-HP playtest is
  required before calling the mechanic balanced.
- The real spawn probe validates the delayed spawner callback but does not
  replace a full late-wave playthrough.
- Physical mobile, Android/macOS builds, Vega load, visual approval and
  existing teardown diagnostics remain open.

## Technical report

`.superpowers/sdd/00-MASTER-PLAN/report-G5-race-condition.md`

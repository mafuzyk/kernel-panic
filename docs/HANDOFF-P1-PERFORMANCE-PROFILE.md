# Handoff — P1 performance profile

## Branch and status

- Branch: `codex/plan-execution`
- Worktree: `/tmp/kernel-panic-plan-execution`
- No merge into `main`.

## Delivered

- Reusable percentile metric class.
- Fixed-seed stress probe with 48 real enemies and 96 real bullets.
- Baseline/stress comparison, memory peak, entity peak and tail-frame gates.

## Verification

```text
/tmp/p1-headless.log
  exit 0, PROBE_DONE fails=0

/tmp/p1-xvfb.log
  exit 0, PROBE_DONE fails=0
```

The Xvfb run uses Mesa llvmpipe. Treat the numbers as a regression baseline
until physical Vega/Android measurements exist.

The full DevHarness after the integrated M5 text-budget correction is also
green: `/tmp/full-after-m5-copy-fix.log`, exit 0, 1455 `AT_PASS`, 0
`AT_FAIL`, `AUTOTEST_ALL_PASS`.

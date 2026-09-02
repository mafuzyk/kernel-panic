# Handoff — P1 performance profile

## Branch and status

- Branch: `codex/plan-execution`
- Worktree: `/tmp/kernel-panic-plan-execution-resume`
- No merge into `main`.

## Delivered

- Reusable percentile metric class.
- Fixed-seed stress probe with 48 real enemies and 96 real bullets.
- Baseline/stress comparison, memory peak, entity peak and tail-frame gates.

## Verification

```text
/tmp/kernel-panic-final-validation-resumed-2/probe-performance-stress.log
  exit 0, PROBE_DONE fails=0

/tmp/kernel-panic-final-validation-resumed-2/probe-performance-stress-xvfb.log
  exit 0, PROBE_DONE fails=0
```

Recheck 2026-09-02: headless stress p95/p99/worst were 16.813/16.985/17.163
ms; Xvfb/Mesa llvmpipe was 7.322/7.842/8.229 ms. These are host-specific
regression samples, not device certification.

The Xvfb run uses Mesa llvmpipe. Treat the numbers as a regression baseline
until physical Vega/Android measurements exist.

The full DevHarness after the integrated M5 text-budget correction is also
green: `/tmp/kernel-panic-final-validation-resumed-2/suite-headless.log`, exit 0, 1453 `AT_PASS`, 0
`AT_FAIL`, `AUTOTEST_ALL_PASS`.

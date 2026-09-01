# Handoff — A11/A14 accessibility profile

## Branch and status

- Branch: `codex/plan-execution`
- Worktree: `/tmp/kernel-panic-plan-execution`
- No merge into `main`.
- The vNext dedicated accessibility route now has live motion/flash and
  handedness controls; native screen-reader/high-contrast/text-scale claims
  remain explicitly unavailable.

## Delivered

- Versioned Sfx accessibility profile schema 3 with additive save keys and
  safe normalization/rollback.
- Reduced-motion gates for camera shake/zoom.
- Reduced-flash gate before full-screen flash allocation.
- Left-handed touch layout mirroring movement and action zones.
- Three focusable controls integrated into the dedicated accessibility
  surface, with reset, semantic states and responsive overflow checks.
- Focused and route-level probes.

## Verification

```text
/tmp/a11-green.log
  exit 0, 9 passes, PROBE_DONE fails=0

/tmp/a11-vnext-green.log
  exit 0, PROBE_DONE fails=0

/tmp/a11-import.log
  editor import exit 0
```

All runs used the Dummy audio driver. The integrated full suite is green after
the M5 text-budget correction: `/tmp/full-after-m5-copy-fix.log`, exit 0, 1455
`AT_PASS`, 0 `AT_FAIL`, `AUTOTEST_ALL_PASS`. PT-BR accessibility labels are
covered by `/tmp/l10n-green.log` and `/tmp/l10n-xvfb.log`, both with exit 0 and
`PROBE_DONE fails=0`.

Physical device, final visual, native assistive-tech and legacy-route
integration remain release gates.

## Known limitation

The old legacy settings panel remains unchanged while the vNext surface is
opt-in. A final UI migration must make the new profile controls reachable from
the shipping route before release.

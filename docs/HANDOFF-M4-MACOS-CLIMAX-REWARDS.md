# Handoff — M4 macOS climax, boss identity and rewards

## Branch and status

- Branch: `codex/plan-execution`
- Worktree: `/tmp/kernel-panic-plan-execution`
- No merge into `main`.
- M4 is implemented and locally validated; it is not a final release gate.

## Delivered

- Added the code-drawn `PermissionRootBoss` variant for `mac_modern`.
- Added a readable directional permission-check wind-up and denial burst while
  retaining RootBoss phases, integrity, HUD wiring and desperation behavior.
- Added `boss_variant: permission_root` to the Mac climax data and selected it
  at the generic story boss spawn boundary.
- Added stable story reward IDs to Game's load/save/snapshot/export/import
  contracts.
- Made story checkpoint writes reject completion on failure and preserve prior
  story maps/rewards in memory.
- Added an Arena recovery surface for a failed story checkpoint.
- Extended the entity adapter so future vNext surfaces do not drop the boss
  variant or its permission telegraph projection.
- Added a focused probe covering direct contract, real story spawn, clear,
  transfer and forced save failure.

## Verification

```text
/tmp/m4-probe-green8.log
  exit 0, PROBE_DONE fails=0

/tmp/m4-suite.log
  exit 0, 1453 AT_PASS, 0 AT_FAIL, AUTOTEST_ALL_PASS

/tmp/m4-import-green2.log
  editor import exit 0
```

The suite's known shutdown leak diagnostics remain non-gating and are recorded
in the technical report. There is no claim of human visual approval or
physical mobile performance.

## Save semantics and limitation

The story maps are updated only after `ConfigFile.save()` returns `OK`. A
forced invalid save path was used by the probe to prove no Mac reward is
granted on that failure. This is a guarded checkpoint, not a crash-safe
journal. A later RPO task must add backup/atomic-write/recovery evidence
before the save system can be called robust against power loss.

## Next recommended work

M5 should review the Mac route in captures and reduced-motion/high-contrast
conditions, then L2/L3 should migrate the remaining legacy literals before
PT-BR can be called complete. The next critical technical sequence is the
remaining reliability/performance/mobile/export gates, not more boss content.

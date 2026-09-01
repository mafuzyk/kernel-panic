# Handoff — G3 — Weekly mutator and Practice wave selection

## Branch and checkpoint

- Branch: `codex/plan-execution`
- Worktree: `/tmp/kernel-panic-plan-execution`
- Base: current reviewed G2 tip on this branch
- No merge into `main`.

## Delivered behavior

Weekly mode now selects one deterministic, visible mutator per week:

- `SWIFT DAEMONS` — daemons move 20% faster (`movement` tag).
- `RUSH HOUR` — wave budget is 20% larger (`spawn` tag).

The menu exposes the week and effect before launch; the run context and boot
event log carry the same ID. Weekly records remain in the existing dedicated
`[weekly]` namespace.

Practice becomes available after a Classic Endless run reaches its first wave.
Its maximum selectable wave is the highest Classic wave seen at run end. The
menu provides a `PRACTICE WAVE: NN / NN` control, and Arena passes that value to
the real Spawner. Practice is non-recording and non-achievement-producing.

## Important implementation choices

The plan recommended enemy movement +20% as the first mutator but did not
require a one-entry catalog. Two entries were chosen so deterministic weekly
selection has observable rotation while remaining easy to explain. Both are
additive and use an explicit contract tag. No damage, cooldown, HP or reward
modifier was introduced.

Practice unlock uses `best_endless_wave > 0`, which means the first Classic run
unlocks wave 1. This is the direct interpretation of “highest Endless wave
reached.” If onboarding playtest shows that Practice should unlock later, the
threshold is isolated in `Game.practice_unlocked()`.

The speed modifier is applied to normal enemies and all RootBoss/GodBoss
configure overrides. The budget modifier is applied only in
`Balance.difficulty_wave_budget()`. Story and Practice cannot inherit a
Weekly modifier because the selection helper resolves an ID only for Weekly
mode and `RunContext` is empty for Practice.

## Verification commands and results

```text
env XDG_DATA_HOME=/tmp/kernel-panic-g3-xdg4 godot --audio-driver Dummy --headless --path . res://tools/g3_weekly_practice_probe.tscn
```

Result: exit 0, `PROBE_DONE fails=0`.

```text
env XDG_DATA_HOME=/tmp/kernel-panic-g3-xvfb-xdg xvfb-run -a godot --audio-driver Dummy --path . res://tools/g3_weekly_practice_probe.tscn
```

Result: exit 0, `PROBE_DONE fails=0`; Xvfb used llvmpipe.

```text
env XDG_DATA_HOME=/tmp/kernel-panic-g3-full-xdg2 godot --audio-driver Dummy --headless --path . -- --autotest
```

Result: exit 0, 1427 `AT_PASS`, 0 `AT_FAIL`, `AUTOTEST_ALL_PASS`. The existing
teardown warnings (resources, RIDs, shaped text and ObjectDB instances) remain
reported baseline diagnostics.

## Files to review

- `src/gameplay/weekly_mutator_catalog.gd`
- `src/autoload/game.gd`
- `src/autoload/balance.gd`
- `src/gameplay/run_context.gd`
- `src/arena/arena.gd`
- `src/enemies/enemy_base.gd`
- `src/enemies/root_boss.gd`
- `src/enemies/god_boss.gd`
- `src/ui/menu.gd`
- `src/ui/menu_chrome_kit.gd`
- `tools/g3_weekly_practice_probe.gd`
- `tools/validate_input_dispatch.sh`

## Known limits

- The mutator values and two-entry rotation need human balance/playtest
  approval. The probe proves routing and isolation, not that the difficulty is
  fun or fair in a long run.
- Xvfb is not a physical mobile/desktop device test.
- Practice still allows the existing Bestiary/program progression hooks; only
  records and achievements were explicitly excluded.
- The legacy menu is still the active default. This is not the from-scratch UI
  migration checkpoint.
- Process teardown diagnostics remain open from baseline.

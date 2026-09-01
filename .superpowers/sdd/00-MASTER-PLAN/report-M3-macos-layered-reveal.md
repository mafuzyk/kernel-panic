# M3 — macOS layered visibility mechanic

## Status

Implemented and reviewed as the first macOS act mechanic. The chosen rule is
layered visibility with a stable reveal warning: an incoming stage enemy is
announced as `BACKGROUND`, shows a geometric countdown and remains inert until
the warning expires. This is a mechanic foundation, not final balance or
release approval.

## Design gate

The plan considered route restriction, proximity/layered processes and
background visibility. Layered visibility was chosen because it is teachable,
code-drawn and portable to touch: it creates anticipation without taking away
the whole arena or requiring a new target-selection rule. The enemy is never
silently hidden. The countdown arc, corner ticks, horizontal marker and
`BACKGROUND` label are redundant channels; the current era accent is merely
decoration.

## Before and after

Before, Mac stages were only content definitions. Their enemies appeared
through the normal spawn telegraph and immediately entered simulation. There
was no stage-specific mechanical identity, no stable background state and no
shared renderer marker for a pre-activation entity.

After, each Mac stage declares `act_rule: "layered_reveal"` and a deliberately
explicit delay. The generic `Spawner` applies the rule at the one enemy spawn
boundary, not through four stage-specific branches. `EnemyBase` creates a
presentation-only `LayeredRevealTelegraph` child, disables its own simulation
and monitorability during the warning, then re-enables itself through the
telegraph's signal. The enemy keeps its normal HP, movement, attack, collision,
reward and RNG behavior after reveal. `EnemyBase.presentation_snapshot()` and
the vNext descriptor/renderer expose a `background` state with a non-color
`background-ring` marker.

## Timing and progression

The authored delays decrease conservatively by stage: 1.20s, 1.05s, 0.95s and
0.85s. These are explicit content values, not hidden difficulty multipliers.
The first Mac node introduces the rule on a single DRONE; the next reuses it
with the already-authored RACE_CONDITION pair. Later Mac nodes combine it with
existing roster pressure. No additional enemy was added for this mechanic.

## Ownership and edge cases

- `Spawner` owns when the rule is applied and never owns telegraph drawing.
- `EnemyBase` owns the simulation gate and snapshot state.
- `LayeredRevealTelegraph` owns only the countdown visual and emits one reveal
  signal; it does not advance gameplay RNG or choose an attack.
- The telegraph child uses `PROCESS_MODE_ALWAYS`, so it continues while the
  parent is disabled. Parent cleanup automatically cleans the child.
- `monitorable` is disabled during the warning, preventing a pre-reveal enemy
  from colliding with the player or accepting a hit. It becomes active only
  after the signal.
- Boss tokens are excluded from the ordinary layered spawn hook; the final Mac
  boss remains governed by the boss path and desperation contract.
- If a stage omits the rule, existing spawn behavior is unchanged.

## Files

- `src/enemies/layered_reveal_telegraph.gd`: code-drawn countdown child.
- `src/enemies/enemy_base.gd`: lifecycle gate and snapshot fields.
- `src/arena/spawner.gd`: generic stage-rule dispatch.
- `src/story/acts/macos_act.gd`: explicit rule and delay values.
- `src/ui/vnext/core/entity_descriptor.gd`: accepted presentation state.
- `src/ui/vnext/core/entity_renderer.gd`: redundant background marker.
- `tools/macos_mechanic_probe.gd/.tscn`: real delayed story-spawn probe.

## Verification

- Editor import/parse: `/tmp/m3-import2.log`, exit 0 with no script errors.
- Focused green: `/tmp/m3-green3.log`, exit 0, all checks passed and
  `PROBE_DONE fails=0`. It exercises the real Spawner story boundary, confirms
  the parent is disabled while the child telegraph remains active, checks the
  `background` snapshot and confirms activation after the delay.
- The renderer state signature is checked by the same probe. No gameplay RNG,
  HP or stage reward was changed by the mechanic hook.

## Second-pass self-review

The implementation was reviewed for hidden enemies, collision before reveal,
parent-disabled child processing, duplicate reveal callbacks, boss-path
interference, random-seed consumption, state normalization and stage-specific
branch sprawl. The result is structurally safe, but the human risks remain:
the 0.85–1.20s cadence may feel too slow or too generous, the `BACKGROUND`
label may be visually noisy in dense late waves, and physical touch/Vega
performance have not been proven. M5 must review captures and P/X tasks must
measure real devices before release.

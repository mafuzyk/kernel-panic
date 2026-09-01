# G5 — RACE_CONDITION enemy and wave teaching

## Status

Implemented on `codex/plan-execution` as the first new enemy in the master
plan's expansion track. The feature is intentionally narrow: it establishes a
pair mechanic, introduces it in isolation, then combines it with a familiar
DRONE pressure pattern. No second new enemy was added before this contract was
covered.

## Threat contract

- Purpose: create a positioning problem in which two otherwise ordinary
  processes become more dangerous when allowed to remain close.
- Telegraph: a code-drawn diamond identity, a broken/segmented cable between
  the pair, open brackets and rotating white ticks while the proximity state is
  active. The active state is not communicated by color alone.
- Counterplay: separate the processes beyond the 170px link radius, then
  eliminate them independently. The pair has no shared HP pool.
- Failure state: while linked, each process moves at 1.18x its configured speed.
  This raises pressure without changing damage, collision size, rewards or
  player controls.
- Drops: each process keeps its own normal `mote_count`, score and kill path.
- Bestiary: the new entry explains separation as the fix and identifies the
  timing/paired-process fiction.

## Before and after

Before, the spawner had no RACE_CONDITION factory or paired encounter. The
code-drawn registry, entity adapter and bestiary had no stable identity for
the mechanic, so adding it only in the enemy script would have produced a
runtime entity that the presentation layer could not describe consistently.

After, `RaceConditionEnemy` is a normal `EnemyBase` with a bidirectional,
optional partner reference. `update_pair_state()` derives distance from live
positions and disables the buff when the partner is missing, invalid or too
far away. Damage remains inherited and therefore independent. The spawner
creates the first pair on wave 4, a pair plus drones on wave 6, and includes
the kind in later mixed compositions from wave 8 onward. Mixed groups repair
odd race-token counts at the spawn boundary so a lone token cannot silently
become a one-enemy introduction.

The entity presentation adapter now preserves an existing nested payload while
adding pair defaults. This is additive and is required because the first
implementation put the pair state in `presentation_snapshot()["nested"]`; a
probe assertion caught that the adapter was discarding nested data. The
adapter was corrected before acceptance and the probe now checks live values,
not merely key presence.

## Files and ownership

- `src/enemies/race_condition.gd`: simulation state, proximity rule, movement,
  independent damage inheritance and code-drawn pair telegraph.
- `src/arena/spawner.gd`: factory registration, deterministic teaching waves,
  pair-safe spawn grouping and linked callback.
- `src/autoload/balance.gd`: centralized RACE color token.
- `src/ui/glyph_lib.gd`: stable glyph kind, extent and diamond/cross identity.
- `src/ui/vnext/core/entity_presentation_adapter.gd`: preserves nested pair
  state and keeps existing boss/nested payloads intact.
- `src/ui/vnext/core/entity_renderer.gd` and
  `src/ui/vnext/entity_illustration.gd`: color lookup for previews.
- `src/data/content_catalog.gd`: bestiary map and player-facing entry.
- `tools/g5_race_condition_probe.gd/.tscn`: focused red/green contract and
  real spawn callback coverage.

## Compatibility and impact

- Existing enemy kinds, boss scheduling, player HP, damage, rewards, save
  schema, input actions and modes are unchanged.
- The new `Balance.COL_RACE` constant is additive. No UI color is hardcoded in
  the renderer or bestiary path.
- The pair reference is runtime-only and is invalidated by the normal
  `is_instance_valid()` check; no node owns or frees its partner.
- The only extra per-frame simulation work is a distance check and normal
  movement for the new enemy. The pair cable is drawn only by the lower
  instance id, avoiding doubled line brightness and redundant draw work.
- A later mixed composition may append a partner token, so its realized enemy
  count can exceed the nominal budget by at most one for an odd roll. This is
  intentional to preserve the threat contract that a race process is never
  spawned without a partner.
- No breaking API or save change was introduced. The adapter's additive nested
  merge fixes a real data-loss edge case for any future nested enemy snapshot,
  not only RACE_CONDITION.

## Evidence

- Focused red: `/tmp/g5-red.log`, exit `1`, four expected failures (missing
  script, factory registration, catalog entry and glyph registration) with
  `PROBE_DONE fails=4`.
- Focused green: `/tmp/g5-green4.log`, exit `0`, 23 passes, zero failures and
  `PROBE_DONE fails=0`. It checks independent health, proximity transition,
  bidirectional linking, live adapter values, wave teaching queues and the
  real delayed spawn callback.
- Import/parse check: `/tmp/kernel-panic-g5-import4.log`, editor import exit 0.
  An initial typed-inference error in the new draw helper was fixed before the
  green run.
- Aggregate DevHarness: `/tmp/kernel-panic-g5-suite.log`, exit 0,
  `AUTOTEST_ALL_PASS`, 1427 `AT_PASS`, zero `AT_FAIL`. Existing teardown
  ObjectDB/resource/RID diagnostics remain non-gating baseline.
- `git diff --check` passed.

## Second-pass self-review

The first code read found two issues before acceptance: the pair callback's
two identical string values would have sent both enemies to the same origin,
and the adapter probe checked only nested key presence while the adapter was
discarding the nested payload. The spawn call was changed to pass explicit
origin/partner positions, the adapter now deep-merges the source nested
dictionary, and the probe checks the linked boolean and distance values.

The remaining risk is not structural correctness but encounter feel. The
170px radius, 1.18x speed, wave 4 isolation and wave 6 composition are
evidence-backed implementation values, not final balance approval. The probe
does not prove a human can read the cable and brackets at every game scale,
nor does it test physical touch, Vega performance or a full late-wave mixed
encounter. Those are release gates for the upcoming visual/gameplay pass.

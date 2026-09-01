# E4 — ZOMBIE_PROCESS

## Scope and player-facing result

Implementation commit: `16f6f24` (`feat: add zombie process enemy slice`).
Documentation commit follows after this report is finalized.

E4 adds the first approved new enemy slice only. `ZOMBIE_PROCESS` is a
temporary dead shell: it blocks player bullets, does not pursue or attack,
does not participate in enemy separation/pathing, expires after 4.0 seconds,
and never grants score, motes, recover, combo, chain or kill notifications.
The first `/boot` teach wave is now one zombie, followed by the existing drone
waves. `RACE_CONDITION` and `DEADLOCK` are not implemented.

## Threat sheet

| Field | Decision |
| --- | --- |
| Purpose | Teach that a defeated process can leave short-lived projectile clutter. |
| Telegraph | Broken shell, dead terminal caret, shrinking timer ring and a white timer bar. |
| Counterplay | Reposition, wait for expiry, or choose another target. |
| If ignored | Bullets are absorbed until the shell is destroyed or expires; enemies keep their normal pathing. |
| Reward/cost | No reward, no kill/combo/chain progression, no mote/recover drop. A shot or time is the only cost. |
| Desktop/mobile readability | Code-drawn shell and non-color caret/ring markers; bounds are measured through the shared renderer at compact sizes. |
| Why first | It has low coupling: one temporary projectile obstacle can be taught and tested before the linked pair's shared buff/leash state. |

## Files

- Added `src/enemies/zombie_process.gd`.
- Updated `EnemyBase` with virtual participation hooks and separation filtering.
- Updated `Arena` reward handling and `Spawner` factory.
- Updated `GlyphLib`, `Balance`, shared descriptor/adapter, content catalog,
  bestiary and first story wave.
- Added `tools/e4_zombie_process_probe.gd/.tscn` and validator registration.
- Updated the existing story harness expectation and created the required
  E4 handoff/release records.

## Red/green evidence

The first real-path probe was run before the production implementation:

- Red log: `/tmp/kernel-panic-e4-red-2.log` (retained outside the repository).
- Exit `1`, `PROBE_DONE fails=5`; factory, glyph, catalog, teach-wave and real
  spawn assertions failed as expected.

After implementation, the focused probe passed headless and under Xvfb:

- Headless: exit `0`, 18 `PROBE_PASS`, `PROBE_DONE fails=0` (`/tmp/kernel-panic-e4-focused-green.log`).
- Xvfb: exit `0`, 18 `PROBE_PASS`, `PROBE_DONE fails=0` (`/tmp/kernel-panic-e4-focused-green-xvfb.log`).
- It covers factory/story spawn, collision layer, pathing exclusion, expiry,
  wave clear, no zombie rewards, ordinary drone rewards, snapshot fields,
  bounded extent and reduced-motion/color-assist marker data.

Additional verification:

- Import: exit `0`; Godot printed the existing environment warning that the
  Android `build-tools` directory could not be opened.
- DevHarness: exit `0`, 1414 `AT_PASS`, 0 `AT_FAIL`, `AUTOTEST_ALL_PASS`.
- Aggregate validator: `/tmp/kernel-panic-e4-post-validator.log`, `VALIDATION
  OK`; E4 was `exit=0`, 18 passes, 0 fails, and no runtime ERRORs. The first
  aggregate run exposed and was corrected for the pre-existing E2 glyph hash
  guard by making its non-batch baseline include the intentional E4 glyph.

## Adversarial review correction

The first implementation added the pathing participation hook to
`EnemyBase._separation()`, but the same `shared_list` is also read by the
reusable `steer_separation()` and `steer_open_space()` helpers. A normal enemy
using the former could still avoid a zombie as if it were an ordinary
navigation peer. The new focused red run reproduced that concrete integration
failure at `/tmp/kernel-panic-e4-review-red2.log` (exit 1).

The review fix adds `_is_pathing_peer()` and applies it consistently to direct
separation, steering separation, nearby-count and congestion loops. The probe
also compares open-space output with and without two zombie blockers, then
restores the arena shared list. Post-fix evidence is
`/tmp/kernel-panic-e4-review-green2.log`: exit 0, 20 passes, zero failures.
The default hook still returns true, so ordinary enemy behavior is unchanged.

Fresh aggregate verification after the correction is recorded in
`/tmp/kernel-panic-e4-review-validator-summary.log`: exit 0,
`VALIDATION OK`, full suite 1414/0, E2 77/0, E4 20/0 and no gated runtime
errors. Teardown diagnostics remain separately reported and non-gating.

## Technical decisions and compatibility

`ZombieProcessEnemy` overrides `take_hit()` and expiry to queue itself without
emitting `died`; the arena's existing child-exit cleanup removes it from the
shared list. `participates_in_enemy_pathing()` and
`participates_in_kill_rewards()` default to true on `EnemyBase`, preserving old
enemy behavior while making the exception explicit. No bullet damage/lifetime,
player movement, score constants, ordinary enemy stats, save schema, input
bindings or balance progression were changed.

## Limitations and uncertainty

Headless/Xvfb checks do not constitute human visual approval. No manual wide /
compact / narrow screenshot review, physical mobile test, Android export,
dense-wave performance profile or gameplay-feel review was performed. Existing
teardown resource/RID/texture diagnostics remain non-gating and unresolved.
The known teardown diagnostics still need a later ownership/performance pass;
they were not altered by E4.
The authoritative brief was found in the plan-execution worktree at the path
requested by the task; the original checkout is a separate worktree and was
not modified.

## Next safe checkpoint

Stop for adversarial review of this isolated slice. Do not begin
`RACE_CONDITION` or any later plan item from this handoff.

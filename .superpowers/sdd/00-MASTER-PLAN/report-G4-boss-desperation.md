# G4 — Boss desperation and late-wave pressure

## Status

Implemented on `codex/plan-execution` and reviewed through focused red/green
probes plus the full DevHarness. The rule is shared by RootBoss variants,
GodBoss and split fragments. It does not change boss damage.

## Rule

When a boss reaches `<= 8%` of maximum HP for the first time, it enters a
permanent desperation state. The transition is one-shot and creates a
`0.75s` transition window. During that window the boss is staggered and its
attack scheduler cannot immediately fire. After the window, future attack
cooldowns are multiplied by `0.72`, increasing cadence without adding an
unexplained damage multiplier.

The state has redundant non-color communication: a high-contrast white outer
border, rotating white ticks, a transition progress arc, and the text
`DESPERATION // CADENCE UP`. The presentation snapshot and entity adapter
carry the state and timer so a future HUD can expose it without querying or
mutating the boss directly.

## Before and after

Before, bosses had phase changes at 66% and 33% but no late-health threshold.
Each variant could continue its normal scheduler until death, and the vNext
entity adapter discarded boss-specific presentation state.

After, the shared RootBoss implementation owns the threshold, transition,
cadence helper and visual telegraph. GodBoss calls the same state step from
its own movement and damage paths, which matters because it overrides both
RootBoss movement and `take_hit`. RootBoss configure overrides and GodBoss
configuration reset the state, so test fixtures or reused instances do not
inherit an old desperation flag. The root draw path and God draw path both
mount the shared telegraph.

## Fairness decision

The transition is a short reaction beat rather than an immediate attack. Its
duration is more than three times the normal dash invulnerability window
(`0.24s`), and attack dispatch is explicitly blocked during it. Damage
remains the original incoming value; only future cadence changes. This is the
least invasive interpretation of “late-wave pressure” and is safer for
One-HP than adding damage or removing player control.

This is still a balance assumption. The probe proves a structural reaction
window and normal damage path, not that every arena position is safe in a
human run. A manual normal/One-HP playtest must decide whether `0.75s` and
`0.72` create pressure without turning an already-active projectile pattern
into a forced death.

## Files and ownership

- `src/enemies/root_boss.gd`: shared state, threshold, cadence, transition
  guard, snapshot and white telegraph; applies cadence to RootBoss attack
  paths and split minis.
- `src/enemies/god_boss.gd`: calls shared state in its overridden movement and
  damage paths, and draws the shared telegraph.
- `src/ui/vnext/core/entity_presentation_adapter.gd`: preserves boss title,
  variant, mini and desperation state in the nested presentation payload.
- `tools/g4_boss_desperation_probe.gd/.tscn`: real damage-entry coverage for
  four RootBoss variants, a split fragment and GodBoss.
- `tools/validate_input_dispatch.sh`: accumulated G4 headless/Xvfb coverage.

## Compatibility and impact

- No player HP, boss damage, collision, reward, save, input or mode rule was
  changed.
- RootBoss existing phase/split/page/shield rules remain in place. Kind 4
  page restoration still owns its existing asynchronous path.
- Mini fragments now receive the same late-state rule because they are real
  RootBoss instances; this is intentional and covered.
- The adapter payload is additive and deep-copied by the existing descriptor
  boundary. Existing renderers ignore the new nested fields.
- The change adds a small amount of `_draw()` work only while desperation is
  active; no per-frame gameplay RNG or extra node is introduced.

## Evidence

- Pre-feature red in isolated parent worktree: `/tmp/g4-red.log`, exit `1`,
  four contract failures (threshold, transition API, cadence API and GOD
  telegraph) with `PROBE_DONE fails=4`. The temporary worktree was based on
  the reviewed G3 commit and was removed after capture.
- Focused headless green: `/tmp/g4-green4.log`, exit `0`, 55 passes,
  `PROBE_DONE fails=0`, no script errors.
- The final focused probe specifically checked every RootBoss kind, a split
  fragment, GodBoss, one-shot activation, attack blocking, adapter projection,
  normal damage, cadence-only behavior and dash reaction margin.
- `git diff --check` and the editor import completed successfully.
- Full DevHarness will be recorded at the aggregate validation checkpoint;
  the G4 focused probe is green. Existing teardown resource diagnostics are
  not attributed to G4.

## Second-pass self-review

The implementation was re-read for overridden `GodBoss.take_hit`, overridden
GodBoss movement, RootBoss mini configuration, kind-4 page guard, kind-1 split
guard, repeated threshold checks, transition-time attacks, cooldown reset,
normal damage and adapter field loss. The first GodBoss patch briefly placed
the oracle cast below an unconditional transition return; that was corrected
before the green run so the transition skips only the cast and still updates
phase/state. The focused probe is intentionally tree-attached to avoid
mistaking null-tree test setup errors for product behavior.

Known baseline: focused probes still report small resource/ObjectDB teardown
diagnostics, and no physical-device visual capture or One-HP human playtest
has been performed.

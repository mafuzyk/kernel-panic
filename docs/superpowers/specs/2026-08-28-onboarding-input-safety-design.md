# KERNEL PANIC Onboarding + Input Safety Design

**Date:** 2026-08-28

## Goal

Teach the player the first important combat rules without interrupting play,
unlock bestiary information when an enemy is first seen, and remove the
possibility that the combat overclock key abandons a paused run.

## Design

### First-sight bestiary unlocks

`Arena` will notify `Game` when an `EnemyBase` enters the enemy container.
`Game` will expose an idempotent helper that marks the enemy's display name
and, for a non-mini `RootBoss`, its `boss_title`. The existing death callback
remains safe to call as a fallback, but the first-sight path owns the normal
unlock timing. Mini ROOTs do not create duplicate boss-variant unlocks.

The behavior is persistence-compatible: existing `bestiary_unlocked` data is
not migrated or cleared, and repeated sightings do not rewrite the entry or
emit a second unlock signal.

### Contextual first-run hints

The first arena run gets short, non-blocking code-drawn hints. The basic
controls appear once in the opening arena intro, then the first sighting of a
LANCER, SPEWER, or SPLITTER may show its tactical counterplay:

- `MOVE // WASD OR TOUCH`
- `DASH // SPACE / SHIFT`
- `SIDESTEP THE LINE`
- `SHOOT THE ORBS DOWN`
- `KILL IT AWAY FROM YOU`

Each hint has its own persisted `shown` flag, is displayed for a bounded
duration, never pauses the tree, and is rate-limited so a wave banner is not
replaced by a stack of messages. Existing touch hints and `KP_HINTS` test
behavior remain compatible. A player who has already seen a hint never sees
it again unless the test environment explicitly requests hints.

### Pause and abandon input

`overclock` is bound to `E` only. A new `abandon` action is bound to `Q`.
While a run is paused, the first `Q` changes the pause copy to
`PRESS Q AGAIN // ABANDON PROCESS` and arms a short confirmation window; the
second `Q` returns to the menu. `E` has no abandon behavior in the paused
state. Leaving pause, restarting, or letting the confirmation window expire
clears the armed state.

The action remains keyboard-only and does not alter touch pause/overclock
behavior. The pause help text and README desktop controls use the separated
actions.

## Files and boundaries

- `src/autoload/game.gd`: first-sight helper, persisted hint flags, distinct
  input actions.
- `src/arena/arena.gd`: first-sight notification and contextual hint routing;
  paused abandon confirmation.
- `src/ui/hud.gd` or a small code-drawn hint control: non-blocking hint copy.
- `src/autoload/dev_harness.gd`: first-sight idempotency, hint, and E/Q tests.
- `README.md`: corrected desktop controls.

No player movement or touch-control implementation is changed.

## Verification

The harness must prove that a spawned enemy unlocks its bestiary record before
death, a repeated sighting emits no duplicate unlock, and a boss variant is
recognized on spawn. It must also prove that `E` does not call `Game.to_menu()`
while paused, that `Q` requires two presses, and that restart/resume clears the
confirmation state. The full suite must finish with `AUTOTEST_ALL_PASS` and
zero `AT_FAIL`.

## Constraints

- No new image asset or runtime dependency.
- No change to combat numbers, enemy spawn budgets, lock-on, or touch input.
- Hints and bestiary UI consume no `Game.rng`.
- Cursor/state cleanup must remain valid in pause, game over, and menu.

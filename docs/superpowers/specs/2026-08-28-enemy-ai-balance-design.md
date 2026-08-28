# KERNEL PANIC Enemy AI + Cadence Design

**Date:** 2026-08-28

## Goal

Make elite enemies, late-wave attack timing, group positioning, Splitter
children, and boss teleports feel intentionally different while preserving
readable telegraphs and the existing enemy identities.

## Design

### Wave-aware attack cadence

`EnemyBase` receives a `threat_wave` context from `Spawner`. Add one bounded
shared cadence function:

```gdscript
attack_cadence_factor(wave: int) -> float
```

It returns `1.0` through wave 5, decreases by `0.015` per later wave, and has
a floor of `0.78`. It scales cooldown intervals, not projectile damage,
projectile speed, HP, movement speed, wave budget, spawn limits, or telegraph
visibility. Apply it to LANCER phase re-entry, SPEWER firing intervals, and
the repeated attack cooldowns of ROOT variants. Wind-up durations remain long
enough to read, and all gameplay randomness continues to use `Game.rng`.

### Qualitative elites

Keep the existing `swift` and `volatile` identities, but route their behavior
through explicit hooks instead of treating them as only stat multipliers:

- `swift` keeps its speed and ghost trail, gains a stronger lateral steering
  preference, and reacquires its next attack state faster through the bounded
  cadence hook.
- `volatile` keeps the existing six-orb death burst and receives a clear
  pre-death pulse/arming visual so the hazard is legible before contact. Its
  death burst remains the only extra damage event.

LANCER and SPEWER must expose the behavioral difference in their existing
`_move` state machines. Other enemies inherit the safe marker/steering hooks
without receiving a new attack pattern.

### Role cooperation

Extend the local `EnemyBase.shared_list` query with a lightweight cover-role
helper. When a SPEWER has a nearby BULWARK roughly between it and the player,
the SPEWER biases toward a valid point behind or beside that BULWARK while
still respecting its distance band and open-space escape. BULWARK continues
to pressure the player and does not pathfind for the group. If no valid
Bulwark exists, the old ranged profile is used.

This is a local geometric preference only; no navigation mesh, global planner,
or new collision body is introduced.

### Splitter elite budget

An elite SPLITTER remains a volatile/swift threat as the parent, but its two
one-hit child drones are explicitly non-elite and do not inherit
`elite_kind`. This keeps one elite roll from multiplying into an uncontrolled
elite chain while preserving the Splitter's existing two-child behavior.

### Tactical teleports

RECURSOR and boss teleport destinations remain inside the arena and outside
the existing safety distance. Candidate destinations are scored against the
player's current aim/movement heading so the preferred candidate appears on a
flanking side or behind the player's facing direction. A deterministic
fallback preserves the current valid random destination when no heading is
available. Teleport phases, corruption zones, attacks, and no-spawn-on-player
safety remain authoritative.

## Files and boundaries

- `src/autoload/balance.gd`: bounded cadence and elite profile constants.
- `src/arena/spawner.gd`: pass the current wave context without changing the
  existing wave budget or spawn selection.
- `src/enemies/enemy_base.gd`: cadence/elite/role-query helpers.
- `src/enemies/lancer.gd`, `spewer.gd`: elite and cadence behavior.
- `src/enemies/splitter.gd`: child elite boundary.
- `src/enemies/recursor.gd`, `root_boss.gd`: tactical teleport scoring.
- `src/autoload/dev_harness.gd`: deterministic behavior probes and cadence
  bounds.

No base HP, damage, fire-rate constant, wave composition, elite chance, or
alive cap is changed. The only intended difficulty change is the explicitly
bounded late-wave cooldown factor above.

## Verification

Tests must cover the cadence floor and wave-5 baseline, distinct swift and
volatile behavior, SPEWER cover preference with fallback, non-elite Splitter
children, and teleport candidates that favor a flank without landing on the
player. Existing ranged retreat, open-space, boss attack, and split tests
must remain green. The full suite must finish with `AUTOTEST_ALL_PASS` and
zero `AT_FAIL`.

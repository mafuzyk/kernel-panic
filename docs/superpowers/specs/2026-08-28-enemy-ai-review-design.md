# KERNEL PANIC Enemy AI Review + ROOT Split HUD Design

**Date:** 2026-08-28

## Goal

Improve enemy decision-making and readability across the full roster while
preserving each enemy's identity, keeping difficulty numbers stable by
default, and keeping the split ROOT encounter visible through two combined
mini-boss health bars.

## Current behavior

- `EnemyBase` already applies shared collision separation, arena clamping,
  knockback, and a per-enemy `vel()` contract.
- Most enemies implement `_move(delta)` as a direct vector toward the player.
- `SpewerEnemy` is the only regular enemy with an explicit distance band and
  strafe behavior.
- `RootBoss` uses the same player-seeking hover target for its non-attack
  movement, while its attack phases override velocity.
- The first ROOT replaces itself with two `RootBoss` mini instances at half
  health. `Arena` currently points `Hud` at the original instance, so the
  boss bar disappears when that instance is freed.
- The bestiary has entries for the current regular enemies and one aggregate
  ROOT entry, but does not expose the four boss variants as separate records.

## Design

### Shared steering contract

Add small, stateless steering helpers at the `EnemyBase` boundary. Helpers
return desired velocity vectors; each enemy remains responsible for choosing
when to call them and for its attack state machine. The helpers may use the
player position, the arena rectangle, and `EnemyBase.shared_list`, but must
not alter `Game.rng`, balance constants, combat damage, or spawn budgets.

The shared behaviors are:

- **Approach:** move toward the player until an attack or distance condition
  is met.
- **Retreat:** move away from the player while preserving a valid arena
  position.
- **Hold band:** combine approach/retreat with a tangential strafe so a
  ranged enemy attempts to remain between its minimum and maximum distance.
- **Separation:** preserve the existing collision response and expose a
  reusable steering contribution for enemies that need early spacing rather
  than waiting until physical overlap.
- **Open-space preference:** when a ranged enemy is too close to the player or
  boxed in by nearby enemies, bias its desired direction toward the least
  crowded valid side of the arena. This is a local heuristic, not a navigation
  mesh or pathfinding system.

All steering outputs are clamped by each enemy's existing speed and remain
subject to the existing arena clamp in `EnemyBase`.

### Enemy profiles

The implementation will assign behavior by role without changing base HP,
damage, fire rate, wave budget, elite chance, or other difficulty knobs.

- **Melee pressure:** DRONE, LANCER, SPLITTER, and BULWARK approach with
  lateral bias and early separation so groups do not stack into one body.
- **Ranged pressure:** SPEWER and ranged boss variants hold a distance band,
  retreat when the player breaches the minimum distance, and strafe while
  their attack telegraph is inactive. During a telegraph they may brake in
  place so the warning remains readable.
- **Area denial:** TROJAN prefers a side or offset approach that places its
  corruption zones across likely player routes rather than following the
  player centerline every frame.
- **Resource thief:** OOM_KILLER keeps its mote target and escape behavior,
  but applies local separation/open-space steering so it does not become
  trapped inside enemy clusters.
- **Anchor controller:** FIREWALL chooses an anchor outside the player's
  immediate space, settles there, and preserves the existing rotating wall
  ownership/lifetime contract.
- **Teleport stalker:** RECURSOR keeps its teleport phases and no-teleport-on-
  player safety rule, but stalks from an offset instead of continuously
  converging on the player.
- **Split ROOT:** each mini uses a distinct lateral offset and explicit
  separation target. Minis may use their existing Lancer-like wind-up and
  reduced burst, but the pair must not orbit as a single overlapping unit.
- **Boss profiles:** ROOT remains able to close and charge; SEGFAULT, BLUE
  SCREEN, and PAGE FAULT prefer space during their ranged hover periods. A
  boss attack phase keeps priority over steering until it completes.

The first pass is behavior-only. Any later numeric tuning will be a separate
change backed by bot telemetry and must not be smuggled into this review.

### ROOT split health HUD

`Arena` will own a small encounter view for the active ROOT fight rather than
leaving `Hud` dependent on a single freed node. Before the split, the HUD
shows the existing single boss bar. At the split, the encounter exposes two
mini entries in stable creation order, each with:

- mini label (`MINI-A` / `MINI-B`);
- current fraction based on that mini's own `hp / max_hp`;
- the same boss color family used by the existing bar.

The two bars share the existing boss-bar container and are displayed as one
combined `ROOT.exe // FORKED` block. The block remains visible while either
mini is alive and clears only after the encounter's final reward path fires.
The aggregate encounter must still count as one boss for cards, heals,
RECOVER drops, score, bestiary logging, and program unlocks.

### Bestiary coverage

Extend the bestiary data model without changing its unlock persistence:

- keep the aggregate ROOT record for the family overview;
- add separate records for `ROOT.exe`, `SEGFAULT`, `BLUE SCREEN`, and
  `PAGE FAULT` variants, each with a stable id, threat value, description,
  and counterplay/BUGS text;
- ensure the display-name-to-id map logs every current enemy and boss variant;
- keep RECURSOR and FIREWALL entries visible in the same scrollable panel.

The panel remains code-drawn and mobile-scrollable. Locked records continue to
show the existing `???` treatment until the corresponding enemy is purged.

## Data flow

1. Each enemy asks the shared steering helpers for a desired vector during its
   existing `_move(delta)` state machine.
2. `EnemyBase` applies velocity, knockback, local separation, and arena clamp
   as it does today.
3. `RootBoss` emits or exposes split state and its two mini instances through
   the arena encounter owner.
4. `Arena` updates the HUD encounter model on boss spawn, split, mini death,
   and final boss death.
5. `Game.mark_bestiary()` receives stable ids for regular enemies and boss
   variants; persistence remains in the existing config file.

## Safety and platform constraints

- No new runtime dependency, image asset, navigation mesh, or physics body.
- No consumption of `Game.rng` by cosmetic/UI logic. Existing gameplay RNG
  remains the only source for gameplay randomness.
- Mobile/touch behavior and lock-on behavior remain unchanged.
- No changes to One-HP rules, difficulty knobs, wave budgets, elite chance,
  player movement, damage values, or spawn limits in this design.
- Boss telegraphs remain readable; attack state machines retain priority over
  steering.
- Missing or freed boss nodes must leave the HUD in a safe state in pause,
  game-over, menu, and scene teardown transitions.

## Verification

The implementation plan will add regression checks before production changes
for:

1. ranged enemies moving away after entering their minimum distance;
2. ranged enemies holding a bounded distance band when space is available;
3. melee groups receiving separation without changing their attack contract;
4. OOM_KILLER retaining its selected mote and escaping with stolen motes;
5. FIREWALL retaining wall ownership and rotating while anchored;
6. RECURSOR never choosing the player's exact position;
7. mini-ROOTs having two distinct HUD bars, remaining visible through the
   split, and clearing only after both minis die;
8. the aggregate ROOT encounter producing one reward flow;
9. every current display name mapping to a bestiary entry and every boss
   variant being renderable in the panel;
10. the full headless suite ending with `AUTOTEST_ALL_PASS` and zero
    `AT_FAIL`.

Manual desktop smoke testing will use the existing bot/demo harness to watch
the first boss split and ranged spacing through cycle 20. This is observational
and must not alter the seeded gameplay contract.

## Scope exclusions

- No balance pass for healing, RECOVER, patch rarity, enemy counts, or arena
  size. Those require a separate telemetry-backed plan after this AI review.
- No new enemy types or boss attacks.
- No replacement of the existing state machines with global pathfinding.
- No changes to player.gd.

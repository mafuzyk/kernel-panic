# KERNEL PANIC — Code-Drawn Programs and Enemy Art Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans`. Treat each entity as a gameplay communication problem before treating it as an illustration problem.

**Goal:** Make every legacy program, enemy, projectile and boss read as deliberate code-drawn art instead of a generic shape with a color swap, while keeping silhouettes fast, stateful, performant and readable on desktop and mobile.

**Architecture:** `GlyphLib` remains the compatibility entry point, but the art system gains data-driven descriptors and a state layer. Simulation classes expose presentation snapshots; a renderer draws identity first and overlays state, telegraph and damage feedback separately. Programs and enemies may share primitives, but never share an indistinguishable silhouette.

**Tech Stack:** Godot `CanvasItem.draw_*`, `GlyphLib`, `EntityIllustration`, `EnemyBase`, per-enemy `_draw()` methods, `Balance` semantic colors, deterministic animation time, optional raster fallback disabled by default.

**Spec:** [master plan](00-MASTER-PLAN.md), [UI direction](../../../UI-REDESIGN-DIRECTION.md), and the current [sprite gate documented in the code-audit handoff](../../../HANDOFF-CODE-AUDIT-UI-DIRECTION.md).

## Global Constraints

- Code-drawn is the shipped default for enemies and programs.
- Identity must survive color-assist mode, grayscale, low glow, pause frames and small mobile rendering.
- Gameplay state never depends on the renderer; drawing must not consume `Game.rng` or mutate physics.
- A sprite candidate is optional, author-gated and rejected if it loses facing, state, silhouette, animation or contrast parity.
- Do not add detail that increases draw cost without improving identity, state or feedback.
- Every new enemy has a threat contract before code: purpose, telegraph, counterplay, failure mode, drop behavior and bestiary explanation.

## Art Grammar

Each entity is drawn in five passes:

1. **identity silhouette:** recognizable as a solid black shape at 24 px;
2. **structural anatomy:** modules, rails, mouth, shield, eye, pages, forks or
   other motifs that explain what it does;
3. **orientation:** facing vector, movement direction or attack direction;
4. **state channel:** idle, charging, vulnerable, damaged, elite, blocked,
   desperate, split, dead or carrying loot;
5. **finish:** glow, scanline, particles, fragments and micro-noise.

The first four passes must work in a clean capture. Finish layers are removable
by accessibility and performance settings.

## Current Cast Audit and Redesign Targets

| Entity | Current identity to preserve | Art upgrade target | State that must read |
| --- | --- | --- | --- |
| `DRONE` | basic pursuing process | compact core with directional sensor and exhaust ticks | tracking, hit, elite |
| `LANCER` | line/charge threat | narrow spear chassis with a visible attack axis | aim, charge, release, recovery |
| `SPEWER` | ranged pressure | asymmetric emitter body and rotating muzzle | wind-up, firing, cooldown |
| `SPLITTER` | multiplication | fractured diamond with separated halves | split-ready, split, damaged |
| `BULWARK` | armor/cover | layered shield body with readable armor plates | covered, exposed, hit |
| `TROJAN` | invasive route mutation | payload core with hooked route arms | carrying, dropping, hit |
| `OOM_KILLER` | steals motes | compressed cell, collecting mouth and orbiting loot slots | searching, stealing, fleeing, dying |
| `RECURSOR` | recursive threat | nested loop/crossing path motif | phase, rewind, attack |
| `FIREWALL` | rotating barrier | segmented wall ring with clear gaps | rotate, closed, vulnerable |
| `PAGE_NODE` | page-like hazard | folded page slab with edge markers | spawned, active, destroyed |
| `UPDATE_LOOP` | installing process | looped progress chassis and visible “update” cycle | updating, interruptible, burst |
| `BLOATWARE` | excess background process | overfilled container with leaking modules | loading, spawning, overloaded |
| `ROOT` variants | boss identity | distinct core/orbit/lance language per variant | phase, desperation, split |
| `GOD` | oracle boss | incomplete orbit and bright eye; ritual geometry | roll, telegraph, desperation |
| `KERNEL` | balanced player program | modular forward core with clean aim/facing | idle, firing, dash, overclock |
| `DAEMON` | aggressive player program | forked/split forward silhouette | dash chain, overclock, hit |
| `ROOTLET` | shielded player program | protected nucleus and shield plates | shield ready, consumed, recharging |

## Renderer Contracts

The following data is sufficient for UI previews, bestiary and combat drawing:

```gdscript
func presentation_snapshot() -> Dictionary:
	return {
		"kind": presentation_kind(),
		"state": presentation_state(),
		"facing": presentation_facing(),
		"hp_fraction": clampf(float(hp) / maxf(float(max_hp), 1.0), 0.0, 1.0),
		"elite": elite,
		"era_accent": era_accent,
		"loot_count": mote_count,
	}
```

`EntityIllustration` accepts the snapshot and a target rectangle. It calculates
an extent before drawing so a lancer lance, OOM horn or boss orbit cannot clip a
detail panel. The entity class owns animation timing; the renderer receives a
cosmetic time value that is never used as a gameplay random seed.

## Redesign Workflow per Entity

For each legacy entity:

- [ ] Write a one-sentence gameplay identity and a one-sentence visual identity.
- [ ] Draw a black silhouette at 24, 48, 96 and 160 logical pixels.
- [ ] Add one internal structural motif tied to its behavior.
- [ ] Add facing and attack-axis readout where direction matters.
- [ ] Add state overlays for idle, hit, attack/charge and death.
- [ ] Add a color-assist marker or pattern when color is part of the distinction.
- [ ] Add a bestiary preview using the same renderer, not a second illustration.
- [ ] Measure extent and confirm no clipping in the intended UI slot.
- [ ] Add a probe that asserts drawing does not alter RNG, HP, position or drops.
- [ ] Capture clean, standard, high-contrast and reduced-motion variants.

## Program Identity Rules

Programs are not enemies with a different tint. They need:

- a player-facing center of mass and clear facing vector;
- an explicit mechanical affordance: balanced, aggressive, shielded;
- a distinct overclock treatment;
- a dash treatment that does not obscure aim/firing;
- a silhouette that remains identifiable in HUD, selector, pause and gameplay.

`ROOTLET` must communicate that the shield is passive and rechargeable; do not
invent an activation button simply to fill a composition. `DAEMON` must not
look like a second KERNEL with larger glow. `KERNEL` should be the visual
baseline against which other programs are compared.

## New Enemy Candidates

### Approved concept A — `ZOMBIE_PROCESS`

The zombie is a temporary dead process that blocks player projectiles but is
ignored by enemy pathing. It expires after a fixed interval and does not grant
chain or combo when destroyed. The shape is a broken shell with a dead cursor;
the expiry is communicated by a shrinking terminal caret and a visible timer
ring. Counterplay is repositioning or waiting, not wasting all shots.

### Approved concept B — `RACE_CONDITION`

Two linked processes spawn as a pair. Proximity grants them a conservative
buff; keeping them apart is the counterplay. The leash is visible as a broken
code cable, not a full-bright beam that hides bullets. Each member has its own
hit state, but the pair's shared buff and separation state are explicit in the
renderer and bestiary.

### Design-gated candidate C — `DEADLOCK`

A slow anchor that creates a small, telegraphed denial zone and becomes
vulnerable when its two locks desynchronize. This candidate is not implemented
until a written design gate proves it does not make mobile movement unfair or
duplicate Firewall's role. The default recommendation is to keep its zone
small, short-lived and visually sparse.

No other enemy is added until one of these candidates has a threat sheet and a
real wave probe. A bigger roster is not automatically better content.

## Art Work Packages

### Task E1 — descriptor and renderer foundation

Create the presentation descriptor, extent calculation, state overlay API and
shared primitive vocabulary. Connect one existing program and one existing
enemy through compatibility adapters before touching the complete cast.

**Acceptance:** drawing a descriptor is deterministic, serializable, safe for a
missing kind, does not mutate simulation state and supplies the same extent to
combat, bestiary and selector previews.

### Task E2 — legacy cast identity pass

Work through the current enemy table in small batches, starting with the
highest-frequency threats. For each batch, preserve collision/attack behavior,
add the silhouette/state evidence and update the bestiary description. A visual
pass cannot silently change hitbox size, facing, spawn timing or reward logic.

**Acceptance:** each batch has clean/finished captures, grayscale and
color-assist checks, a performance comparison and a real-path regression probe.

### Task E3 — program identity pass

Apply the same renderer contract to `KERNEL`, `DAEMON` and `ROOTLET` in HUD,
program selection, pause and gameplay. Verify shield/overclock/dash states
with the actual gameplay snapshot instead of preview-only flags.

**Acceptance:** the three programs remain distinguishable at combat size and
their art states agree with gameplay state, HUD text and accessibility markers.

### Task E4 — new entity slice

Implement at most one approved new enemy at a time. The threat sheet, isolated
teach wave, bestiary entry, code-drawn identity and real-path probe land
together. The second candidate waits for review of the first slice so roster
size does not outrun balance and mobile readability.

### Task E5 — finish tiers and sprite gate

Add finish layers only after the clean structural review. Measure draw cost at
the densest supported wave, define reduced-motion/mobile variants and compare
any proposed raster asset against the code-drawn fallback using the sprite
policy below.

**Commit boundary:** descriptor, each cast/program batch, each new enemy and
finish-tier work are separate commits with their own handoff and release-log
entry.

## Testing and Art Review

- silhouette test: black/white images at all target sizes;
- state test: same entity in idle, attack, hit, elite, death and accessibility
  modes;
- orientation test: enemy facing and player aim in four quadrants;
- overlap test: several enemies, bullets and motes without merged identities;
- bestiary test: preview extent, description and stats share the same identity;
- performance test: fixed-seed stress wave under desktop and mobile quality
  tiers;
- RNG guard: repeated capture/draw produces the same gameplay state;
- input guard: visual state never changes action ownership or hitboxes.

The acceptance question is not “does the glyph look complex?” It is “can a
player say what it is doing before it hurts them?”

## Sprite Policy

The existing `EntitySprite` registry remains empty/default-off. A future sprite
may be proposed only with a comparison package containing:

- the sprite and code-drawn version at 24/48/96 px;
- idle, facing, hit, charge, death and elite frames;
- color-assist and grayscale captures;
- memory/import size and draw-cost notes;
- a clear reason geometry cannot deliver the intended result.

If any state is weaker, the code-drawn version remains the shipped fallback.

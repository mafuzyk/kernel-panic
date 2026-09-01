# KERNEL PANIC — Gameplay, Balance and Enemy Expansion Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans`. Gameplay changes require red/green evidence and a short human-readable explanation of why the change improves decisions, fairness or replayability.

**Goal:** Improve the actual game loop—movement, aiming, dash, overclock,
patches, motes, waves, bosses, progression and retry—while adding a small
number of high-identity enemies with clear counterplay instead of inflating
the roster or making difficulty feel random.

**Architecture:** Keep simulation authoritative in `Game`, `Arena`, `Spawner`,
`Player`, `EnemyBase` and `MoteField`. New rules are explicit state machines or
data definitions in `src/gameplay/` and `Balance`; presentation reads their
snapshots. Mode-specific rules are isolated behind a run/mutator context so
Classic, Story, Weekly, One-HP and Practice do not silently alter each other.

**Tech Stack:** Godot 4.7.2/GDScript, deterministic `RandomNumberGenerator`,
`Balance`, `Game` state/save helpers, `Spawner`, `EnemyBase`, `MoteField`,
DevHarness and real-path probes.

**Spec:** [master plan](00-MASTER-PLAN.md), [gameplay design answers](../../specs/2026-08-30-gameplay-backlog-answers.md), [enemy AI design](../../specs/2026-08-28-enemy-ai-balance-design.md), and [entity art plan](03-CODE-DRAWN-ENTITY-ART.md).

## Global Constraints

- Existing player feel and balance are measured before changing values.
- The user-approved ROOTLET full-shield mote overflow remains: each excess mote grants the existing `+5` score/scrap progression behavior.
- New mechanics must state their reward, cost, failure mode, telegraph and counterplay before implementation.
- Practice runs never write records; Weekly runs use their own leaderboard/record namespace; Story keeps its fixed curve.
- Determinism uses `Game.rng` for gameplay. Cosmetic drawing, particles and captures use a separate cosmetic clock/source.
- No enemy can be dangerous only because its warning is invisible on mobile or hidden by the HUD.
- Every new wave composition gets a density and recovery review, not just a spawn-count test.

## Player Experience Goals

The player should repeatedly make these decisions:

1. **Position:** move through a readable danger field rather than collide with
   invisible geometry.
2. **Aim:** choose the next threat, with mouse/touch aim behaving consistently.
3. **Commit:** dash now for safety or save it for the next telegraph.
4. **Overclock:** spend a resource for tempo, knowing what the program allows.
5. **Route:** collect motes safely, abandon a dangerous pickup, or exploit a
   patch's synergy.
6. **Adapt:** recognize enemy state and change behavior instead of only raising
   damage numbers.

Any feature that does not improve at least one of these decisions is a lower
priority than fixing readability, input, fairness or performance.

## Current Loop Audit Before Changes

Before changing gameplay, record a fixed-seed baseline for:

- time-to-first-threat and time-to-first-mote;
- average wave clear time for waves 1, 5, 10 and boss waves;
- player damage sources and recovery sources;
- dash availability, cooldown and invulnerability window;
- overclock fill rate, active duration and program-specific restrictions;
- patch offer timing and common build combinations;
- enemy count, elite count, projectile count and mote count per wave;
- death cause distribution in a local sample;
- frame time and object count at the densest wave.

The baseline is evidence, not a promise that the current values are correct.
Balance changes need a reasoned delta and a comparison log.

## Implementation Order

### Task G1 — state and rule contracts

Create a run context/snapshot in `src/gameplay/` with:

```gdscript
func mode_id() -> String
func stage_id() -> String
func mutators() -> Array[String]
func writes_records() -> bool
func uses_deterministic_seed() -> bool
```

Keep compatibility accessors in `Game`. Make the mode rules explicit before
adding Practice or Weekly changes.

Tests: snapshot stability, mode isolation, save round-trip and no record write
from a practice run.

### Task G2 — approved low-risk mechanics

Implement and probe the already answered backlog items:

- **Zombie process:** blocks player bullets, ignores enemy pathing, expires,
  grants no chain/combo when destroyed.
- **Page cache:** stores up to three motes and auto-releases a bonus on fill;
  no decay or manual action.
- **Ring-0 double overclock:** re-press while active stacks the effect, with a
  significantly longer post-use cooldown and no integrity cost. Verify DAEMON's
  dash-overclock interaction before setting the final cap.
- **Display control settings:** fullscreen and target FPS (30/60/120/unlimited)
  as a separate display section, with mobile default 60 and desktop default
  unlimited where the platform supports it.

Each item must be one commit or one clearly bounded pair of test/fix commits,
with the feature's rule visible in a probe rather than inferred from a capture.

### Task G3 — modes and replayability

Implement:

- one weekly mutator selected from a deterministic weekly seed;
- mutator preview before launch;
- separate Weekly record namespace;
- Practice wave select unlocked by highest Endless wave reached;
- Practice runs excluded from records and achievement conditions unless an
  achievement explicitly says Practice.

The first mutator recommendation is “enemy movement speed +20%” because it is
easy to explain and test. Mutators must be tagged as affecting spawn, movement,
damage, cooldown or rewards; never hide a reward multiplier in a vague label.

### Task G4 — boss fairness and late-wave pressure

Implement the shared boss desperation rule below 8% HP only after reviewing
one-HP balance. The rule includes:

- stronger attack cadence, not an unexplained damage spike;
- a strong border/telegraph state visible without color;
- a short transition window so the player can react;
- a one-time state transition, not repeated rearming each frame;
- a probe for all boss variants and split fragments.

The test must prove the threshold does not become an unavoidable death in a
standard movement/dash scenario.

### Task G5 — new enemy pair and temporary hazard

Add `ZOMBIE_PROCESS` and `RACE_CONDITION` from the entity-art plan. Wave data
must introduce them gradually:

- first encounter isolates the mechanic;
- second encounter pairs it with one familiar pressure enemy;
- later encounters test combinations only after the counterplay is taught;
- no new enemy appears in the same wave as a new boss mechanic without a
  playtest reason.

### Task G6 — death feedback and heatmap

Add a local, mode-scoped death heatmap retained for approximately 50 runs.
Store quantized arena coordinates and counts, not screenshots or telemetry.
Game over displays it as a low-priority diagnostic layer that never hides retry
or cause. The storage format must be versioned and bounded.

### Task G7 — music and feedback layering

Desktop-only patch music uses two stems: offensive patches add percussion,
defensive patches add bass, with a short 0.5s crossfade. Mobile keeps the
existing simpler audio path to protect budget and avoid making music a required
gameplay signal. Accessibility can disable the stems independently of gameplay.

## Balance Review Framework

For every mechanic, record:

| Question | Required answer |
| --- | --- |
| What does the player notice? | exact visual/audio/text telegraph |
| What can the player do? | movement, aim, dash, target priority or route choice |
| What happens if ignored? | bounded consequence, not surprise death |
| What rewards mastery? | score, safety, tempo, route or build synergy |
| What is the mobile adjustment? | spacing, target size, timing or visual priority |
| How is it tested? | deterministic real-path probe and manual capture/playtest |

Do not fix difficulty by only increasing HP, speed or spawn budget. Prefer
telegraph quality, enemy composition, recovery windows and meaningful target
priority.

## Gameplay UX Improvements

- Show why an enemy is dangerous before the first unavoidable attack.
- Make patch synergies and conflicts legible at offer time, not only after
  selecting a build.
- Keep the pause terminal useful for diagnosis: current wave, HP, program,
  patches, threat and recent event log.
- After death, state one primary cause, one secondary contributing factor and
  one next action. Avoid raw engine errors as player-facing copy.
- Give the player a short recovery beat after a boss or high-density wave.
- Keep the first run educational without removing agency: hints may be
  disabled, repeated hints are deduplicated and mobile input hints match the
  actual control surface.

## Acceptance Gates

- [ ] A fixed-seed run produces the same gameplay events after a capture or UI resize.
- [ ] Each new mechanic has a red probe that fails before implementation and a green probe after it.
- [ ] Practice cannot overwrite Classic/Story/Weekly records.
- [ ] Weekly mutator and leaderboard identity are visible before launch.
- [ ] New enemies have distinct silhouette, telegraph, counterplay and bestiary entry.
- [ ] One-HP mode does not receive hidden healing or an untelegraphed threshold kill.
- [ ] Mote ownership, projectile lifecycle and boss fragment cleanup remain bounded.
- [ ] Mobile and desktop playtests cover the same mechanic with appropriate controls.
- [ ] Balance notes, changed constants and player-facing effects enter the release log.

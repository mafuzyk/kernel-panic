# KERNEL PANIC — Performance, Memory and Reliability Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans`. Measure first, change one ownership or hot-path cause at a time, and keep teardown diagnostics separate from gameplay correctness.

**Goal:** Make the game stable and responsive on a mid-range desktop and a
representative Android device while removing avoidable per-frame work, bounding
entity lifetimes, preserving deterministic runs and producing honest release
evidence.

**Architecture:** Define budgets for simulation, rendering, UI layout, memory
and startup. Cache immutable resources and layout metrics, use pools only when
profiling proves allocation churn matters, and isolate cosmetic quality tiers
from simulation. Every resource has an owner and cleanup path; no global signal
or tween may retain a dead scene.

**Tech Stack:** Godot 4.7.2 profilers, `Performance` counters, fixed-seed
stress scenes, `Game.rng`, `queue_redraw()`, `Resource` caches, object pools
where measured, Xvfb, Android profiling and the existing aggregate validator.

**Spec:** [master plan](00-MASTER-PLAN.md), [repository architecture](01-REPOSITORY-ARCHITECTURE.md), [UI remake](02-UI-REMAKE-VNEXT.md), and the current teardown notes in the handoffs.

## Global Constraints

- Do not optimize by changing gameplay values, collision rules or RNG order
  unless a separate gameplay decision explicitly approves it.
- Headless success is not a performance claim; at least one real desktop and
  one representative mobile profile must be measured.
- Rendering improvements must preserve clean, high-contrast state channels.
- A pool is justified by an allocation profile and has an explicit reset
  contract; it is not added merely because pools sound fast.
- All tests use `--audio-driver Dummy` and isolate saves.
- Runtime errors, resource leaks, RID leaks and object counts are reported in
  separate categories; one green assertion suite cannot erase a teardown leak.

## Initial Budgets

These are release targets to measure and refine, not excuses to hide failures:

| Area | Desktop target | Mobile target |
| --- | --- | --- |
| frame pacing | stable 60 FPS at the standard stress wave | stable 60 FPS on the reference device; graceful 30 FPS fallback |
| input-to-visible response | under one frame in normal conditions | under two frames in normal conditions |
| UI layout | no full layout rebuild every frame | same; resize/setting changes only |
| gameplay allocations | no unbounded per-shot/per-wave growth | no unbounded per-shot/per-wave growth |
| visual effects | full approved finish tier | reduced/medium tier without losing telegraphs |
| startup | no avoidable blocking asset scan after boot | no avoidable blocking asset scan after boot |

Capture actual device model, OS, export type, resolution, quality tier and
measurement method with every profile. Do not compare an editor run to an
exported release as if they were equivalent.

## Hot-Path Audit

### UI and drawing

- cache fonts, textures and shared primitives instead of calling `load()` in
  `_draw()` or constructing style resources repeatedly;
- compute `layout_snapshot()` and hit regions on resize/state changes, not ten
  times per frame;
- update patch chip rectangles only when viewport, patch list or layout state
  changes;
- avoid `queue_redraw()` for static surfaces;
- keep text measurement cached per key/locale/font size where safe;
- reduce scanline/noise/glow passes on mobile and in reduced-motion mode;
- use extent/LOD rules for entity illustrations so detail scales with size.

### Gameplay

- profile bullet, mote, enemy, fragment, particle and audio-player creation;
- verify `PlayerBullet` has no unused Node construction or orphan path;
- bound OOM stolen-mote ownership by UID and release only the owner set;
- ensure dead enemies, boss fragments and temporary hazards leave the tree;
- verify tweens and deferred calls are canceled or become harmless on owner
  exit;
- keep wave composition and RNG order stable while measuring.

### Signals and scene lifetime

- use named methods instead of anonymous global-signal lambdas when the target
  is recreated;
- disconnect or rely on lifecycle-safe connections for HUD/menu surfaces;
- kill old tweens before starting replacement transitions;
- reject deferred calls to methods removed by a refactor;
- ensure `free()`/`queue_free()` paths cannot emit gameplay rewards twice.

## Work Packages

### Task P1 — measurement harness

Create a fixed-seed stress probe that records frame time, active nodes by
category, bullets, motes, enemies, boss fragments, redraw count and resource
counts over a repeatable wave sequence. It must emit a completion marker and
never write a user save.

### Task P2 — UI/layout caching

Move layout calculations behind invalidation keys: viewport, density, locale,
text scale, accessibility profile and surface state. A cached layout is reused
until one of those inputs changes. Add assertions that a stable frame does not
recalculate geometry or allocate labels.

### Task P3 — entity lifecycle

Trace every spawn/despawn path for bullets, motes, enemies, boss fragments,
zones and overlays. Add owner IDs and cleanup assertions where necessary.
Only then decide whether bullet/mote pooling is worthwhile.

### Task P4 — effects quality tiers

Define `low`, `medium` and `high` cosmetic tiers. Low removes expensive noise,
reduces particles and stabilizes animation; it cannot remove warning shapes,
boss telegraphs, aim feedback or state markers. Mobile defaults to medium or
low based on measured device capability, with a manual override.

### Task P5 — teardown and startup

Investigate remaining ObjectDB/resource/RID diagnostics with isolated probes.
Attribute each resource to an owner, fix only confirmed leaks, and preserve a
baseline file when a Godot backend diagnostic cannot be eliminated safely.
Profile startup imports and avoid loading unused screens/assets during boot.

## Determinism and Save Safety

- UI capture, localization change, accessibility toggle and resize must not
  change `Game.rng` state.
- Cosmetic quality changes must not reorder gameplay events.
- Save writes happen at defined transitions, not every frame.
- Versioned save migrations have a backup/read-failure fallback and a probe for
  old fixture data.
- A failed save import never partially overwrites the current save.

## Acceptance Gates

- [ ] Fixed-seed stress runs are repeatable across quality tiers.
- [ ] No unbounded object/orphan growth across repeated firing, waves, restarts or overlays.
- [ ] Stable UI frames reuse cached layout and do not load resources from `_draw()`.
- [ ] Mobile quality reduction keeps all gameplay telegraphs and controls legible.
- [ ] Input response and frame pacing are measured on real targets.
- [ ] Teardown diagnostics have a categorized before/after report.
- [ ] Save export/import and locale/accessibility settings survive the performance changes.
- [ ] Performance claims and known limits are recorded in the release log.

# KERNEL PANIC — macOS History Story Act Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans`. This is a content-and-systems expansion; do not confuse it with the terminal command history feature, which already exists in the current codebase.

**Goal:** Add a hand-authored macOS history act that feels like a legitimate
chapter of KERNEL PANIC: historically recognizable, mechanically distinct,
code-drawn, funny without being disposable, playable on PC and mobile, and
fully localized through the same content pipeline as the existing acts.

**Architecture:** Add a new act catalog under `src/story/acts/` and keep
`StoryData` as a compatibility facade while existing stages migrate. The act
owns narrative, stage order, era profiles and wave definitions; `Spawner`,
`Arena` and the UI consume those definitions without hardcoded `if macos`
branches scattered through drawing code. Era decoration is a profile, not a
platform detection path.

**Tech Stack:** Godot 4.7.2/GDScript, `StoryData`, `Game.start_story()`,
`Spawner`, `Arena` stage profiles, `GlyphLib`, localized catalogs and real
story progression probes.

**Spec:** [master plan](00-MASTER-PLAN.md), [UI remake](02-UI-REMAKE-VNEXT.md), [entity art](03-CODE-DRAWN-ENTITY-ART.md), [localization](06-LOCALIZATION-PT-BR.md), and current story data in `src/story/story_data.gd`.

## Interpretation of “MAC-OS history”

This plan interprets the request as a **macOS history/story act**: a new
playable historical route alongside UNIX, Windows and TempleOS. It is not a
second implementation of terminal ↑↓ history/autocomplete, which is already
present in `src/ui/terminal_panel.gd` and covered by the existing probe. If the
intended feature was the terminal history instead, stop before Task M1 and
redirect the work to the terminal surface rather than adding a story act.

## Content Principles

- Use recognizable era references without importing Apple logos, system
  screenshots, proprietary fonts or copied UI assets.
- Treat the act as parody and system mythology, not as a factual encyclopedia.
- Every stage introduces one visual/mechanical idea and reuses it with one
  older idea before adding another.
- Historical flavor appears in paths, diagnostics, typography rhythm, color
  and behavior; it does not require exact product replicas.
- The act must remain understandable to a player who does not know the history.
- PT-BR copy is written during content creation, not bolted on after visual
  layouts are locked.

## Proposed Act Structure

Four stages are recommended: enough arc to feel complete, small enough to
finish and balance properly.

| Stage | Fictional path | Era language | Gameplay role |
| --- | --- | --- | --- |
| M1 | `MAC::CLASSIC` | compact monochrome desktop, menus and folders | teach the act; low density, clear basic threats |
| M2 | `MAC::AQUA` | translucent aqua layers and fluid motion | introduce movement pressure and soft visual depth |
| M3 | `MAC::DARWIN` | terminal substrate under a polished shell | combine classic threats with UNIX-like route hazards |
| M4 | `MAC::MODERN` | minimal dark glass, permissions and background services | climax with permission/daemon pressure and a new boss or boss variant |

These names are content keys, not required final player-facing copy. The
player-facing titles and jokes can be tuned during writing review. The route
should unlock after the current story acts or through an explicit post-clear
condition; use the existing story progression model instead of a second save
system.

## Narrative Beat Sheet

### M1 — the friendly shell

The system presents itself as simple and welcoming while hiding a process
table. The player learns that familiar surfaces still contain hostile daemons.
The visual language is sparse and high-contrast so the new act does not begin
with a wall of effects.

### M2 — the beautiful layer

The shell becomes smoother and more layered. Visual polish is treated as a
mechanical cover: threats can appear in soft motion, but telegraphs stay hard
and readable. The act should make the player distrust prettiness without
punishing them for not knowing the reference.

### M3 — the substrate underneath

The clean shell exposes its lower layer. Terminal language, process ownership
and permission diagnostics become story texture. Existing UNIX-style threats
can return in a new composition, not with inflated numbers.

### M4 — permission to panic

The system's promise of simplicity collapses into background services and
permission failures. The final encounter must be readable as a consequence of
the act's ideas, with a fair telegraph and a clear story reward.

## Mechanical Identity

The act's primary mechanical identity should be **layered visibility and
permission pressure**, not a permanent screen filter. Candidate rules:

- some hazards begin in a quiet “background” state and reveal themselves with
  a stable telegraph before becoming active;
- a permission gate briefly restricts a route or target, but always leaves a
  readable alternative;
- layered processes can be separated or interrupted, creating space rather
  than merely increasing damage.

Only one of these becomes a global act rule after a design gate. The default
recommendation is layered visibility because it can be taught, code-drawn and
adapted to mobile without hiding the entire arena.

## Content and File Plan

**Create:**

- `src/story/acts/macos_act.gd` — stage catalog and act metadata;
- `src/story/acts/macos_dialogue.gd` — keys only, no drawing;
- `src/story/acts/macos_profiles.gd` — era palette/grid/CRT profiles;
- `tools/macos_story_probe.gd` and `.tscn` — real unlock and progression path.

**Modify:**

- `src/story/story_data.gd` — compatibility aggregation;
- `src/autoload/game.gd` — act count/unlock/reward accessors and save migration;
- `src/arena/stage_kit.gd` — profile-driven visuals;
- `src/arena/spawner.gd` — only generic rule dispatch, no stage-specific copy;
- `src/ui/vnext/surfaces/story_surface.gd` — act tab, lock state and briefing;
- `src/ui/bestiary_panel.gd` or its adapter — new entity records;
- localization catalogs and release documentation.

## Boss and Enemy Policy

The act may reuse the existing enemy cast with new composition. A new
act-specific enemy is justified only if its mechanic explains the history
theme and does not overlap `UPDATE_LOOP`, `BLOATWARE`, `FIREWALL` or
`RACE_CONDITION`. A possible candidate is `PERMISSION_DENIED`, a stationary
gate that projects a visible denied route and opens after a telegraphed cycle;
it remains design-gated until the wave does not become unfair on touch.

The final boss may be a new variant of `RootBoss` or a dedicated class, but it
must share the boss desperation contract and HUD fragment interface. The act
reward must be keyed by stage ID and survive a save export/import.

## Implementation Sequence

### Task M1 — act catalog and unlock contract

Add the four stage definitions, stable IDs, unlock condition, reward IDs,
profiles and wave references without yet exposing the route as a default
button. Add a save fixture for locked, partially cleared and fully cleared
states. Keep the existing story facade and save keys compatible.

### Task M2 — narrative and localization slice

Write the player-facing title, intro, klog, objective, reward and first-failure
copy for M1 in English and PT-BR. Review it in the actual story surface at
wide, compact and narrow sizes before writing the remaining stages. The joke
must be understandable without knowing Apple history and must not rely on a
copied trademark asset.

### Task M3 — teachable mechanic and wave progression

Select one act rule at the design gate, implement it behind the generic stage
profile, then add the M1 teach wave and M2 reuse wave. Verify that the rule has
a stable telegraph, a safe alternative, a touch-readable layout and no hidden
platform detection. Only after the probe and playtest pass should it be used in
M3/M4.

### Task M4 — climax, reward and persistence

Implement the final stage composition, boss/variant, desperation behavior,
story-cleared transition, unlock/reward write and save transfer. Test an
interrupted completion and a failed save so the player does not receive a
partial reward or lose earlier progress.

### Task M5 — visual integration and release gate

Connect era profiles to the vNext story/HUD/entity surfaces, add bestiary
entries, perform the code-drawn art review and run the complete localization,
accessibility, responsive and performance matrix. The act is not release-ready
when its stage probe passes but its text, boss telegraph or mobile route is
untested.

Each task ends with a handoff and one coherent commit (or a documented red/
green test/fix pair). The route remains hidden or locked until M1–M4 are
accepted; M5 promotes it to the release candidate.

## Acceptance Tests

- [ ] The act is locked/unlocked through a documented rule and does not corrupt existing progress.
- [ ] Each of four stages loads its own title, intro, klog, wave list, theme and reward.
- [ ] The full route is playable through `Game.start_story()` and the real spawner state machine.
- [ ] The final boss class/title/HUD wiring match the stage definition.
- [ ] New act rules have telegraphs, counterplay and a narrow-layout capture.
- [ ] Stage completion, best score, unlock and reward survive save transfer.
- [ ] Unknown or unavailable localization keys fall back to English without raw key text.
- [ ] No proprietary screenshot, logo, copied font or image-gen panel is added as runtime content.
- [ ] README and release log explain the act without claiming unsupported platform ports.

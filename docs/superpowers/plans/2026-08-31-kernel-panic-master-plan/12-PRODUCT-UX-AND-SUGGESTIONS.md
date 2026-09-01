# KERNEL PANIC — Product UX, Scope and Improvement Suggestions

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` for behavior changes. This document is the product filter for deciding what deserves implementation.

**Goal:** Make KERNEL PANIC feel like a complete game with a strong first
minute, meaningful repeat runs, understandable progression and a coherent
reason to return, while keeping the scope appropriate for a free/open-source
project maintained by a small team.

**Architecture:** Optimize the player journey around short arcade sessions.
Every feature must belong to the core loop, mastery/progression, expression of
the operating-system fiction, or maintenance/accessibility. Features that do
not serve one of those pillars stay as proposals until they earn a concrete
player problem, design, cost and test.

**Tech Stack:** Existing Godot game state, story/mode definitions, vNext UI,
local save data, accessibility/localization services, DevHarness and release
documentation.

**Spec:** [master plan](00-MASTER-PLAN.md), [gameplay](04-GAMEPLAY-AND-ENEMY-EXPANSION.md), [UI remake](02-UI-REMAKE-VNEXT.md), [PC/mobile UX](08-PC-MOBILE-UX.md), and the current [README](../../../../README.md).

## Global Constraints

- No accounts, ads, energy timers, loot boxes, online requirement or invasive analytics.
- Local progression must remain complete when offline.
- A feature that adds content must also add onboarding, counterplay or explanation.
- A feature that adds complexity must provide a shorter default path.
- A feature that adds a decision must make its consequence visible before commitment.
- Every new screen has a primary action, a safe back path and a recovery path.
- Every mode must be explainable in one short paragraph before launch.
- New content is not accepted from a design pitch alone: it needs a player
  problem, a smallest testable slice, a teaching moment, a failure/recovery
  story and a maintenance owner.

## Playtest and Prioritization Protocol

For every major UX or gameplay slice, run a short internal playtest script
covering first launch, first combat decision, first failure and return flow.
Record where the player hesitated, what they expected, what they missed and
whether they recovered without outside explanation. Do not collect telemetry
or personally identifying data; this is a qualitative development artifact.

Rank proposals with four explicit dimensions: player impact, identity/fit,
implementation risk and maintenance cost. A high-impact feature with high risk
must be split into a reversible vertical slice before it enters the release
train. A low-impact feature does not outrank input, readability, fairness,
save safety or frame pacing merely because it is visually attractive.

Each accepted proposal records a success signal and a kill condition. If the
smallest slice fails to improve comprehension, decision quality or replay value
without adding unacceptable complexity, stop it and keep the evidence in the
idea log. This protects the free/open-source project from an ever-growing
catalog that the default player never needs.

## Product Pillars

### 1. Immediate arcade action

The first run should get the player moving, aiming and firing quickly. Menus
may be stylish, but they must not delay the first meaningful input. The first
enemy should be readable, the first mote should teach collection and the first
patch should expose a real build decision.

### 2. Mastery through recognition

Players improve by recognizing enemy behavior, telegraphs, spacing and patch
synergy. Difficulty should reward knowledge and execution, not memorization of
hidden rules or reading tiny logs.

### 3. A world with a voice

Paths, processes, klogs, panic messages and terminal commands create a coherent
fiction. Humor is strongest when it emerges from a real system rule. Do not
replace play with paragraphs; put lore beside an action the player understands.

### 4. Respect for the player

No forced account, no ads, no energy gate, no manipulative notification and no
online dependency. Settings, accessibility, language and save transfer are
part of respecting the player's time and hardware.

### 5. Open development

Players and contributors can inspect code, report reproducible issues, add
translations and understand release changes. Local diagnostics should help a
player report a bug without exposing private data.

## Player Journey

### First launch

1. Boot overlay establishes the terminal voice in a few lines.
2. Input mode is detected and the correct controls are shown.
3. The menu presents one obvious action to start a run.
4. The first arena teaches movement, aim/fire and dash through play.
5. A first threat label appears only when useful, not as a tutorial wall.
6. The first patch offer explains effect and one meaningful synergy/conflict.
7. Death explains the primary cause and offers Retry or Main Menu.
8. The player can reach settings/accessibility without losing their route.

Measure this journey with a local probe and a manual playtest checklist. The
goal is not to collect user analytics; it is to ensure the designed path exists.

### Returning player

The menu should immediately show:

- last selected program/mode;
- best record relevant to that mode;
- story progress and newly unlocked content;
- a clear primary boot action;
- optional weekly mutator and practice entry points.

Do not bury the main game under a content catalog. Secondary screens support
the run; they do not compete with it.

### After a death

Game over must answer, in order:

1. What happened?
2. What did I accomplish?
3. What can I do now?

The heatmap, patch list and raw diagnostic details are useful secondary data.
They must not push Retry below the fold or hide the cause behind decoration.

## UX Improvements Worth Prioritizing

### High value, low scope

- consistent focus/back/confirm behavior across all screens;
- visible mobile controls and device-correct onboarding;
- patch effect + conflict preview before selection;
- clearer enemy first-encounter hints;
- retry preserving a deliberate mode/program choice;
- localized error/recovery messages;
- pause terminal commands that reflect the actual run state;
- immediate display of newly unlocked program/story/bestiary content.

### Medium scope

- practice wave selection with a clear “does not write records” label;
- weekly mutator preview and separate record identity;
- local death heatmap;
- compact run summary that can be copied into a bug report;
- bestiary comparison of two known enemies;
- optional reduced-information HUD mode for players who want less clutter.

### Deliberately lower priority

- photo mode;
- large animated background scenes;
- procedural lore that has no gameplay consequence;
- additional settings that duplicate existing sliders;
- online leaderboards or social systems;
- cosmetic collections that require an inventory system.

These may become good future ideas, but they do not outrank a broken input
path, unclear telegraph, clipped text, save risk or unstable frame pacing.

## Mode Clarity

Before launch, each mode displays:

| Mode | Player promise | Record policy |
| --- | --- | --- |
| Classic | escalating survival and full build expression | writes Classic records |
| Story | fixed stages, authored waves and narrative route | writes stage bests, not Endless records |
| Weekly | shared deterministic mutator/seed challenge | separate Weekly records |
| One-HP | one mistake, explicit harshness | separate or marked records according to current policy |
| Practice | replay an unlocked wave to learn | never writes records |

The UI should use short copy plus an inspectable detail view. It should not
require the player to infer rules from mode names.

## Product Metrics Without Telemetry

Use local QA measurements rather than collecting player data:

- time from launch to first playable input;
- number of inputs to start a run;
- time until first threat/patch/death screen;
- whether the player can identify the death cause from the screenshot;
- whether a new player can find accessibility and language settings;
- whether a mobile player can play one wave without UI obstruction;
- whether a contributor can run tests and understand a handoff.

These are acceptance questions for manual playtests and probes, not remote
analytics events.

## Proposal Record

Every new suggestion is recorded with: player problem, target player, affected
moment in the journey, smallest experiment, expected benefit, risks, PC/mobile
behavior, accessibility/localization impact, save/record/RNG impact,
performance cost, maintenance owner, success signal, kill condition and
decision state. This record may live in an issue or handoff, but it must be
linked from the release decision so ideas do not disappear into chat.

For a feature that changes difficulty or records, include a before/after
comparison using the same seed and mode. For a feature that changes UI, include
the action map, narrow-layout compromise and visual recipe. For a content
feature, include teach wave, counterplay, bestiary copy and a reason the
existing cast cannot already express the idea.

## Feature Decision Filter

Before accepting a suggestion, answer:

1. Which player problem does it solve?
2. Which pillar does it serve?
3. What is the smallest version that tests the idea?
4. What does the player see before committing?
5. What happens on PC, mobile, reduced motion, high contrast and PT-BR?
6. Does it affect save format, records, RNG or performance?
7. What probe proves it works and what capture proves it reads well?
8. What existing feature becomes more confusing because of it?

If the answer to the first two questions is weak, keep the suggestion in the
idea log rather than letting it expand the release scope.

## Acceptance Gates

- [ ] First launch reaches a playable run quickly and with device-correct instructions.
- [ ] Returning players see a clear primary path and useful progress context.
- [ ] Death, pause, patch and mode flows explain consequence before commitment.
- [ ] Practice/Weekly/Story rules are visible and record policies are unambiguous.
- [ ] Mobile and accessibility choices are part of the normal UX, not hidden QA options.
- [ ] No feature adds account, ad, energy, network or telemetry requirements.
- [ ] New suggestions are recorded with problem, scope, cost and acceptance evidence.
- [ ] Major slices have a playtest script, observed outcomes, success signal and kill condition.
- [ ] Scope decisions identify player impact, identity fit, implementation risk and maintenance cost.

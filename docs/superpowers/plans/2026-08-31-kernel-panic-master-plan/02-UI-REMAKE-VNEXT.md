# KERNEL PANIC — From-Scratch UI Remake Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans`. Do not migrate a legacy panel one-to-one. Each surface is a new composition backed by the current game's state contracts.

**Goal:** Rebuild the entire player-facing UI from scratch around the `media/Ideas/` visual language: a restrained terminal operating shell, strong code-drawn geometry, clear state hierarchy, adaptive layouts and zero dependence on the current menu's coordinates.

**Architecture:** Introduce a small vNext UI runtime that consumes immutable-ish snapshots and produces layout metrics, draw primitives and action hit regions. A single surface owns its layout calculation; the same `Rect2` values feed `_draw()`, keyboard focus and pointer/touch hit tests. Legacy screens remain available only as temporary compatibility routes until their vNext replacement passes flow, visual, responsive and accessibility gates.

**Tech Stack:** Godot `Control`/`CanvasItem`, GDScript `_draw()` and `draw_*`, `ui_tokens.gd`, `ui_primitives.gd`, `entity_illustration.gd`, `GlyphLib`, `TacticalUI`, Orbitron and ShareTechMono, viewport/safe-area metrics, real `Button`/`LineEdit` controls where input semantics require them.

**Spec:** [master plan](00-MASTER-PLAN.md), [visual direction](../../../UI-REDESIGN-DIRECTION.md), [UI overhaul design](../../specs/2026-08-29-ui-overhaul-design.md), and the local references in `/home/mafu/Projetos/kernel-panic/media/Ideas/`.

## Global Constraints

- The visual references are a moodboard. Copy, example values, rails, maps, scanlines and decorative density are not acceptance requirements.
- The shell, hierarchy, state redundancy, code-drawn geometry and adaptive behavior are acceptance requirements.
- No new surface uses fixed physical 1280×720 coordinates or scales desktop artwork down until text becomes unreadable.
- Every action has a real focusable/pressable target. Drawn text cannot pretend to be a button.
- Visual effects are applied after clean geometry and can be reduced globally for accessibility and mobile.
- A surface must be readable without color, glow, scanline or animation before those effects are enabled.
- Every screen exposes `layout_snapshot()`, `text_overflow_report()` and an action map for probes.
- Interactive targets use the accessibility floor of 44–48 logical pixels,
  with spacing that prevents accidental adjacent activation on touch.
- A route owns one lifecycle: configure, enter, update, suspend, resume and
  exit. Signals, timers, tweens and deferred calls must be disconnected or
  invalidated when the route exits.

## Visual Translation of the References

The new UI should preserve these high-value traits from the references:

- a persistent top route/status strip that tells the player where they are;
- a thin outer shell and small side telemetry, used as framing rather than
  decoration on every child component;
- large, short headings and generous tracking for identity;
- an asymmetric content composition instead of a centered stack of identical
  cards;
- cyan as structure/selection, white as primary readable content, magenta as
  threat/failure, amber as warning/cost and lime as recovery/readiness;
- segmented meters and glyphs that make numeric state scannable;
- a quiet center in combat and a clear action rail in menus;
- explicit diagnostic copy in pause, terminal and game-over rather than vague
  modal titles.

The visual system must be less noisy than the references when the screen is
small. Every surface gets a detail budget: one primary title/action, the most
important state, and only enough decoration to establish the machine identity.

## Shared Runtime Contracts

### UI context

Create a context value consumed by all vNext surfaces:

```gdscript
class_name VNextUIContext

var viewport_size: Vector2
var safe_rect: Rect2
var density: String       # "wide", "compact" or "narrow"
var input_mode: String    # "desktop", "touch" or "hybrid"
var reduce_motion: bool
var high_contrast: bool
var text_scale: float
```

`density` is derived from available logical width/height and minimum readable
content sizes. It is not derived from the operating system name alone.

### Surface contract

Every surface implements the same conceptual interface:

```gdscript
func configure(snapshot: Dictionary, context: VNextUIContext) -> void
func layout_snapshot() -> Dictionary
func action_regions() -> Dictionary
func text_overflow_report() -> Array
func semantic_snapshot() -> Dictionary
```

`action_regions()` returns named `Rect2` values and semantic metadata. It is the
only source used by mouse/touch hit testing and keyboard focus navigation.

### Navigation contract

The coordinator owns a stack of route IDs, for example:

```text
menu → program_select → story_select → arena
menu → settings → accessibility
arena → pause → terminal
arena → game_over → menu or retry
```

Back/escape always pops one route unless the current route explicitly presents
a destructive confirmation. The route announces its focus order and default
focus target; it does not inspect another surface's private nodes.

### Lifecycle and transition contract

Route changes are transactional from the player's perspective. The outgoing
surface stops accepting actions before the incoming surface becomes active;
exactly one route owns focus and exactly one coordinator handles a submitted
action. A rejected transition restores the previous route and explains the
failure without leaving a half-created Arena, duplicated overlay or stale
selection.

Every surface cancels its timers/tweens, releases signal connections and clears
pending deferred work on exit. Re-entering a route creates a fresh snapshot or
reuses an explicitly immutable one; it never replays a stale action from the
previous visit. Probes must cover rapid open/back/open, resize during a
transition, locale change during a transition and scene replacement while a
signal is queued.

### Typography and content budget

Before decorative polish, each surface defines its minimum readable body size,
heading size, maximum text measure, line-count budget and truncation policy.
Technical labels may use tracking and uppercase, but descriptions, error copy
and accessibility text must retain readable mixed-case forms. A button label
may wrap only when its target grows with it; otherwise the design supplies a
short action label plus a detail description.

Font fallback and Unicode coverage are checked for English and PT-BR before a
capture is approved. No surface solves overflow by shrinking below the text
floor, hiding an action, or silently replacing a translated string with a key.

## Surface-by-Surface Plan

### Task U1 — shell and boot/menu vertical slice

**Files:**

- Create: `src/ui/vnext/ui_context.gd`, `ui_layout.gd`, `ui_navigation.gd`.
- Extend: `src/ui/vnext/ui_tokens.gd`, `ui_primitives.gd`.
- Create: `src/ui/vnext/surfaces/boot_surface.gd` and its probe.
- Modify: `src/ui/menu.gd` only to route the development slice.

Composition:

- top route/status strip;
- brand/title block with a short diagnostic subtitle;
- one visually dominant `BOOT/RUN PROCESS` action;
- compact telemetry block with best record and current program;
- secondary routes below or beside the primary action;
- no current menu panel copied into the new surface.

Tests:

- title, primary action and back action exist in the action map;
- ENTER, mouse and touch activate only the intended action;
- pressing the action once cannot also trigger an overlay underneath;
- 1366×768, 720×720 and 432×720 produce valid layout snapshots;
- grayscale capture still distinguishes selected, locked and available.

### Task U2 — program and story selection

Program selection follows the reference pattern of a list plus a detail area.
On narrow layouts it becomes list → detail with a visible back action. The
detail must expose identity, playstyle, risk, starting loadout and the true
launch action.

Story selection uses act tabs and connected nodes on wide layouts. On narrow
layouts, the route list and briefing are separate readable states. It must not
force a three-column map into a phone viewport.

**Files:** `src/ui/vnext/surfaces/program_surface.gd`,
`story_surface.gd`, `src/story/` catalogs, `ProgramPanel`/`StoryPanel` only as
compatibility data providers during migration.

**Tests:** selection and launch actions, locked stages, keyboard navigation,
touch selection, scroll-into-view, no duplicate launch through ENTER, and
localized/wrapped descriptions.

### Task U2b — patch offer and build decision surface

Patch selection deserves its own surface contract because it is a gameplay
decision, not another content list. The offer shows the patch identity, effect,
cost/benefit, one relevant synergy or conflict, current build impact and a
clear confirm/skip action. It must make the consequence visible before the
player commits and must preserve the run if the offer is closed or rejected.

On narrow layouts, present one patch at a time with a deliberate next/previous
action instead of three compressed cards. On desktop, parallel offers may be
shown only when each card keeps its readable description and independent focus.
Locked/unavailable/conflicting states use explicit reason text and a state
marker, not opacity alone.

**Files:** `src/ui/vnext/surfaces/patch_surface.gd`, shared patch snapshot and
action contract, and the adapter for the current patch offer path.

**Tests:** deterministic offer ordering, confirm/skip/close, conflict preview,
keyboard/mouse/touch focus, no duplicate selection, locale/text-scale
overflow, resize during an offer and a pause-tree/overlay recovery path.

### Task U3 — combat HUD

The HUD reserves the arena center. The information zones are:

- upper-left: player integrity/program and the most important resource;
- upper-center: temporary event/encounter announcement only;
- upper-right: cycle/wave and compact patch/status dock;
- lower-left: dash/ability state and touch-safe control space;
- lower-right: score, combo, time and optional run telemetry;
- bottom/center only when necessary: boss integrity, never over the player.

The HUD distinguishes continuous state from temporary feedback. It must not
repeat the same cycle label in multiple strong locations. A low-integrity state,
cooldown, full meter, damage direction and boss phase each have a non-color
signal.

**Files:** new `src/ui/vnext/surfaces/combat_hud_surface.gd`,
`src/ui/vnext/widgets/`, compatibility adapter in `src/ui/hud.gd`, and the
existing `Arena` signal wiring.

**Tests:** fixed-seed wave, boss split, low HP, full/empty meter, long event
log, 1–12 HP pip ranges, touch overlay, 432×720 and ultrawide layout.

### Task U4 — pause, terminal and game over

Pause is a decision surface over a visibly frozen combat context. Terminal is
not a reskinned pause menu: it is a diagnostic workstation with event stream,
command index, status, prompt and history. Game over is a diagnosis followed by
retry/menu actions, not a wall of stats.

**Files:** `pause_surface.gd`, `terminal_surface.gd`, `game_over_surface.gd`,
adapters for `src/arena/panel_kit.gd` and `src/ui/terminal_panel.gd`.

**Tests:** real pause/unpause, terminal focus, ↑↓ history, TAB completion,
destructive abandon confirmation, game-over ENTER/ESC, disabled actions,
keyboard/mouse/touch paths and narrow modal layouts.

### Task U5 — settings, bestiary and awards

These screens share the shell but have different information jobs:

- settings groups preferences by responsibility and adds a dedicated
  accessibility route;
- bestiary prioritizes threat identity, behavior, counterplay and silhouette;
- awards uses a progress summary and cards/list states without requiring four
  desktop columns on mobile.

**Files:** `settings_surface.gd`, `bestiary_surface.gd`, `awards_surface.gd`,
adapters for current panel files and `menu_settings_kit.gd`.

**Tests:** section switching, persistence, focus order, locked states, detail
scroll, input method labels, localization overflow, mobile stacking and
reopening the same selected item.

### Task U6 — shared error, empty, loading and transition states

Define reusable states for unavailable content, invalid actions, missing
catalog entries, save read/write failure, first-load delay and route
transition. These states must have a readable explanation, a safe recovery
action and a back path. They are part of the design system, not ad-hoc text
drawn by whichever screen first encounters the error.

**Files:** `src/ui/vnext/core/ui_state.gd`, `ui_focus_model.gd` and shared
state primitives; adapters in each surface that can load data or reject an
action.

**Tests:** missing optional content, malformed save fixture, unavailable
localized key, rapid route changes, disabled primary action and a failed
transition under keyboard, mouse and touch. Verify no duplicate signal,
overlay or focus owner remains after recovery.

## Effects and Drawing Order

Every surface draws in this order:

1. opaque/readable base and safe-area frame;
2. hierarchy lines, separators and focus geometry;
3. semantic text, meters and glyphs;
4. state markers and alerts;
5. optional glow, scanline, noise and animated accents.

`reduce_motion` removes or shortens animated layers. `high_contrast` increases
text/panel contrast and preserves markers. A screenshot of layer 1–4 is the
first visual review artifact; layer 5 is never allowed to rescue poor layout.

## Visual Review Protocol

Each surface receives two independent reviews before migration: a structural
review and a finish review. The structural review uses layers 1–4, grayscale,
large text and reduced motion to judge hierarchy, state and actionability. The
finish review enables the intended glow/scanline/noise tier and checks whether
the effects reinforce rather than obscure the structure.

The reviewer records the route, commit, viewport, locale, text scale, input
mode, accessibility profile and capture layer. Approval must name the primary
action, the most important state, the narrow-layout compromise and any
deliberately omitted decoration. “Looks close to the reference” is not a
criterion; the evidence must explain what the screen lets the player do and
understand.

## Migration Rules

- A new surface first runs beside the legacy surface through a development
  route or feature flag.
- The adapter translates `Game`/Arena state into a snapshot; it does not copy
  old labels or coordinates into the new `_draw()`.
- The legacy route is removed only after the new route passes flow probes,
  viewport matrix, accessibility checks and visual review.
- Unused legacy code is removed in a separate cleanup commit, with a grep and
  full test log proving that no route still imports it.
- The reference images stay in `media/Ideas/` as design material and are not
  imported as backgrounds, panels or acceptance screenshots.
- If a legacy route remains as rollback, it must be reachable by an explicit
  development switch, have a removal condition in the handoff and be tested
  for save/input parity. It must not remain accidentally reachable through a
  stale button, deep link or failed transition.

## Visual Acceptance Checklist

- [ ] One black-and-white screenshot communicates route, focus, state and primary action.
- [ ] Text remains readable without glow or scanlines.
- [ ] No accidental double frame or identical-card wall is required by the composition.
- [ ] No action is represented only by a drawn label.
- [ ] Wide, compact and narrow layouts have distinct, intentional compositions.
- [ ] Touch targets are comfortable and do not cover gameplay-critical content.
- [ ] The surface uses at most the amount of decorative detail its smallest target can afford.
- [ ] Captures show no clipping, overlap, hidden cursor or stale state after resize.
- [ ] The screen has a semantic snapshot and a passing overflow report.
- [ ] Route entry/exit does not leak focus, signals, timers, tweens or deferred actions.
- [ ] Empty/error/loading states have recovery and safe back behavior.
- [ ] The visual review records both the clean structural layer and the finished effect layer.

# KERNEL PANIC — PC/Mobile UX and Responsive Layout Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans`. Treat PC and mobile as first-class experiences sharing rules, not as one layout with hidden controls.

**Goal:** Make KERNEL PANIC comfortable on desktop windows, ultrawide/square
layouts, Android touch devices and compact portrait situations while improving
onboarding, navigation, feedback, pause, patch selection and retry UX.

**Architecture:** All surfaces calculate a logical safe rectangle and choose a
composition density (`wide`, `compact`, `narrow`). Input is normalized into
action IDs; device-specific affordances are presentation layers over the same
action contract. The combat camera/arena and UI overlays have explicit reserved
zones so adaptation cannot silently cover threats or controls.

**Tech Stack:** Godot `Control`, `DisplayServer`, viewport resize notifications,
`TacticalUI`, vNext layout/surface contracts, `TouchControls`, keybinds,
mouse/touch event routing and Xvfb/device captures.

**Spec:** [master plan](00-MASTER-PLAN.md), [UI remake](02-UI-REMAKE-VNEXT.md), [accessibility](07-ACCESSIBILITY-SETTINGS.md), and the current responsive design notes in `docs/superpowers/specs/`.

## Global Constraints

- No physical-resolution constants in new layout logic.
- The arena never receives a UI panel that hides player, boss telegraph,
  projectile path or pickup route without a deliberate state transition.
- Mobile does not rely on hover, right-click, keyboard or tiny text.
- PC does not receive mobile-only controls unless a touch device is detected or
  explicitly forced for testing.
- A resize, orientation change or display-scale change recomputes layout once
  and preserves semantic selection.
- Every screen has a usable back action and an obvious primary action.

## Layout Densities

Use measured minimum content requirements, with initial names:

- **wide:** enough width for full shell, peripheral telemetry and parallel
  content columns;
- **compact:** enough width for a reduced shell and two prioritized content
  regions, with low-value telemetry collapsed;
- **narrow:** one-column content, explicit route header, stacked controls and
  scroll/step navigation where necessary.

The actual thresholds live in `ui_tokens.gd` and are validated with real
rectangles. They must be tunable without editing every screen.

## PC-Focused UX

### Window and navigation

- support resize without stale hitboxes;
- support fullscreen/windowed/borderless where the display backend allows it;
- expose target FPS 30/60/120/unlimited with a measured default;
- show keyboard hints only when keyboard navigation is available;
- preserve mouse cursor and hover feedback outside combat;
- allow complete menu navigation with arrows, Enter and Escape;
- make the primary action usable by mouse and keyboard with no double-trigger.

### Desktop combat

- keep raw mouse aim responsive and independent from menu cursor;
- reserve the upper/lower peripheral zones shown by the reference HUD;
- expose optional run telemetry, seed and timer without crowding the arena;
- support debug tools only in debug desktop builds and never let them swallow
  ordinary pause/game-over input;
- make pause/terminal a diagnostic workstation for players who want details,
  while keeping Resume/Restart/Abandon immediately understandable.

### Desktop settings and content screens

Use wide layouts for program/story/bestiary/settings/awards, but make secondary
information collapsible so ultrawide screens do not stretch text into long
unreadable lines. Keep a content max width and use empty space as hierarchy.

## Mobile-Focused UX

### First launch and onboarding

- detect touch capability but allow a forced-touch QA mode;
- show a short, skippable overlay explaining move, aim/fire, dash, overclock
  and pause using the current control scheme;
- never show `WASD`, `SHIFT` or mouse instructions as the only mobile hint;
- teach one mechanic at a time and remember dismissed hints locally;
- make the first primary action large enough for an accidental-safe tap.

### Touch combat

- left movement stick and right aim/fire remain separate action ownership;
- dash, overclock and pause have visible, reachable buttons in reserved corners;
- multitouch allows aim/movement plus action buttons simultaneously;
- touch buttons expose ready/cooldown/disabled states with shape and label;
- no button is placed on top of the patch dock, low-HP warning, boss telegraph
  or pickup route;
- configured `touch_scale` updates draw radius, hit rect and movement geometry
  together while preserving normalized movement vectors;
- portrait/very narrow layouts may stack or reduce noncritical HUD telemetry,
  but must not shrink action targets below the accessibility floor.

### Mobile menus

- one column by default;
- list/detail screens become list then detail with persistent back;
- settings sections become a scrollable grouped list with sticky section title;
- awards become one-column cards or a compact progress list;
- terminal prioritizes event stream and prompt; command index can collapse;
- large decorative rails disappear before title, status, focus, action and
  error copy;
- prevent accidental destructive taps with confirmation and sufficient spacing.

## Shared UX Improvements

- use stable route names and breadcrumbs so a player knows where Back goes;
- preserve selection on resize and locale change;
- keep confirmation language consistent: `CANCEL`, `CONFIRM`, `BACK`,
  `ABANDON` and `RESTART` must not vary randomly by screen;
- show disabled/locked reasons near the action, not in an invisible tooltip;
- distinguish transient feedback from persistent state;
- give every error a recovery action or a clear safe exit;
- make the terminal history and autocomplete promises match actual behavior;
- do not make a player read an event log to discover a core control.

## Viewport Matrix

Every surface is checked at:

| Profile | Purpose |
| --- | --- |
| 1366×768 | wide desktop reference and visual hierarchy |
| 720×720 | square/compact window behavior |
| 432×720 | narrow mobile landscape-ish logical test and overflow stress |
| 390×844 | representative tall phone composition |
| ultrawide desktop | max-width discipline and unused-space hierarchy |

The 432×720 profile is mandatory because it already exists in the project's
probe history. The 390×844 profile complements it; it does not replace it.

## Acceptance Tests

- [ ] Every screen has wide, compact and narrow layout snapshots.
- [ ] All action regions use the same geometry for draw, hit test and focus.
- [ ] No text clipping, off-screen action, stale selection or overlapping critical panel exists in the matrix.
- [ ] Desktop keyboard/mouse flow and mobile touch flow reach the same game states.
- [ ] Aim + movement + dash/overclock multitouch works without input theft.
- [ ] Onboarding labels match the detected/forced input mode.
- [ ] Resize/orientation/locale/accessibility changes preserve route and safe state.
- [ ] PC and mobile captures are silent, reproducible and reviewed outside the repository.
- [ ] UX regressions enter the release log with the affected platform and recovery behavior.

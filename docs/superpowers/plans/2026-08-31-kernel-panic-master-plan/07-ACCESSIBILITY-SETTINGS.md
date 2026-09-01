# KERNEL PANIC — Accessibility and Dedicated Settings Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans`. Accessibility is part of gameplay communication and input reliability, not a decorative settings category.

**Goal:** Add a real, dedicated Accessibility section to Settings and make the
game readable, controllable and fair for more players on PC and mobile without
changing the intended challenge unless a player explicitly enables an assist.

**Architecture:** Store presentation/input preferences in a versioned
accessibility profile, expose a snapshot to UI and gameplay presentation, and
route all visual/audio/input accommodations through shared helpers. Gameplay
rules remain unchanged by default; assist modes are explicit, visible and
excluded from records only when they materially change challenge according to
the documented mode policy.

**Tech Stack:** `src/ui/menu_settings_kit.gd`, new vNext settings surface,
`Sfx` persistence helpers, `Balance` semantic colors, `TacticalUI`,
`TouchControls`, `GlyphLib`, `Localization`, Godot focus/navigation and
DevHarness probes.

**Spec:** [master plan](00-MASTER-PLAN.md), [UI remake](02-UI-REMAKE-VNEXT.md), [localization](06-LOCALIZATION-PT-BR.md), and the existing [accessibility/responsive design](../../specs/2026-08-28-accessibility-responsive-design.md).

## Global Constraints

- The Accessibility tab is visible and reachable on both desktop and mobile.
- Defaults preserve current behavior as closely as possible.
- Color is never the only state channel; every important state has shape,
  text, pattern, position, motion or sound redundancy.
- Options are applied immediately where safe and show a clear current value.
- Settings persist through existing local helpers; no new unmanaged save file.
- Cosmetic assists do not consume gameplay RNG or alter collisions.
- Flash, shake, motion and audio options never remove necessary hazard
  telegraphs; they replace them with stable alternatives.
- Every interactive control remains keyboard-focusable where keyboard input is
  supported and has a 44–48 logical-pixel touch target on mobile.
- Accessibility state is applied at a shared presentation/input boundary;
  individual screens may not implement their own incompatible meaning for an
  option.

## Support Scope and Feasibility Gate

The first release promises keyboard/mouse focus, touch accommodations, clear
semantic labels, redundant visual/audio feedback, scalable text and reduced
motion/flash behavior. Native OS screen-reader announcements are a separate
feasibility task: do not claim screen-reader support until Godot's exported
Linux, Windows and Android builds have been tested with the relevant platform
assistive technology. Until then, semantic snapshots, logical focus order and
high-quality labels are the supported foundation rather than a fictional
compatibility badge.

The same rule applies to gamepad navigation, remapping APIs and platform-level
font scaling: inventory what the current build actually exposes, implement the
smallest consistent contract, and document unsupported combinations instead of
showing an option that does nothing.

## Accessibility Profile

Create a serializable profile with explicit defaults:

```gdscript
class_name AccessibilityProfile

var color_assist := false
var high_contrast := false
var reduce_motion := false
var reduce_flashes := false
var screen_shake := true
var crt_effects := true
var text_scale := 1.0
var ui_scale := 1.0
var touch_scale := 1.0
var subtitles := true
var tutorial_hints := true
var hold_to_confirm := false
var aim_assist := false
var toggle_dash := false
var left_handed_touch := false
var touch_opacity := 0.85
var subtitle_duration := 3.0
```

The exact property owner may be `Sfx` plus an accessibility helper, but the
profile must have `snapshot()`, `apply(dict)`, `defaults()` and `reset()`.
Avoid adding options that cannot be applied consistently across screens.

## Dedicated Tab Layout

The Accessibility screen is grouped by the user's problem, not by internal
implementation:

### Visual clarity

- Color Assist: alternate high-contrast palette plus `S`/`B`/state markers.
- High Contrast: stronger text/panel separation and reduced background detail;
  critical text and controls meet a measured contrast target in the clean
  structural layer.
- UI Scale and Text Scale: independent controls with preview.
- CRT Effects: full/low/off, including scanline/noise/aberration.
- Reduce Flashes: replaces hit/death flashes with a stable border/status mark.

### Motion and audio

- Reduce Motion: removes cosmetic jitter and shortens/locks decorative loops.
- Screen Shake: off/low/normal; hazard direction remains visible without it.
- Subtitles and combat event text: on/off with readable duration.
- Master/SFX/Music/UI volume and mute behavior remain in Audio but are linked
  from this section when a player needs them for sensory control.

### Controls and motor access

- Touch scale with live preview and safe-area check.
- Left-handed touch layout with mirrored controls and a live preview; the
  mirror must not change action IDs or movement normalization.
- Aim mode selection: drag/assist/lock-on where the existing game supports it.
- Hold/toggle alternatives for dash and overclock where mechanics remain fair.
- Full keybind remapping on desktop, including visible conflict errors.
- No action may require a hidden chord that cannot be performed on mobile.

### Cognitive support

- Tutorial hints and input hints.
- Plain-language hazard labels in bestiary and first encounter.
- Persistent pause/terminal explanation of current state.
- Confirmation before destructive abandon/reset actions.
- A `RESET TO DEFAULTS` action that itself has confirmation, visible scope and
  a recovery path if persistence fails.

## Semantics and Redundant Feedback

Use a state matrix for every critical gameplay state:

| State | Color | Shape/pattern | Text/icon | Motion/audio |
| --- | --- | --- | --- | --- |
| low integrity | danger red | segmented pips + border pattern | `LOW HP`/equivalent | optional pulse, never required |
| dash ready | cyan/lime | filled pip and chevron | `READY` | optional sound |
| overclock active | white/cyan | active ring or timer stripe | `OVERCLOCK` | reduced-motion-safe |
| shield ready | lime | shield plates | `SHIELD READY` | optional confirmation |
| enemy charging | magenta/amber | directional arc/telegraph | threat label when needed | optional cadence |
| locked content | muted | lock glyph and disabled geometry | unlock condition | none |
| patch conflict | danger/amber | crossed relation marker | explicit conflict copy | none |

Color-assist and grayscale probes must inspect these channels directly.

For flashes, the reduced mode replaces full-screen color inversion and intense
bursts with a bounded border/status indicator. The implementation must record
duration and repetition in the probe so a “reduced” label cannot hide an
equally aggressive animation under a different name.

## Input and Focus

- Keyboard focus order follows reading order and announces the selected item by
  structure, not only tint.
- Mouse hover cannot be the only route to discover an action.
- Touch uses the same action IDs and semantic state as keyboard/mouse.
- Focus is restored to the last meaningful action when returning from a child
  route, unless the action became invalid.
- Escape/back is consistent across menus, settings, pause, terminal and game
  over; destructive actions require the same confirmation policy everywhere.
- The cursor is visible outside gameplay and is restored after overlays close.
- Focus changes expose a visible geometry marker and a localized accessible
  name/description. A control that is disabled or locked also exposes the
  reason, not just a dimmed color.

## Assist and Record Policy

Cosmetic options (contrast, colors, text scale, CRT, motion, shake, subtitles,
volume) never affect records. Input assists that change aim, timing or
survivability are explicit in the run snapshot. The default recommendation is
to keep `aim_assist` and toggle alternatives available without disabling
records when they only alter input mapping; if a future assist changes target
selection or damage, mark that run as assisted and exclude it from competitive
Weekly records while preserving local personal history.

## Accessibility Work Packages

### Task A11 — profile, persistence and defaults

Inventory the current settings owner and add the versioned profile with
defaults, validation, reset and migration fixtures. Apply harmless visual
changes immediately; apply input changes at a safe transition. Verify malformed
values clamp to safe defaults and never prevent the game from reaching the
menu.

### Task A12 — redundant gameplay communication

For each critical state in the matrix, implement the non-color marker in HUD,
pause, bestiary and entity renderer. Test low HP, charge, shield, cooldown,
locked content, patch conflict and boss desperation with color assist,
grayscale, high contrast, reduced motion and reduced flashes.

### Task A13 — controls and motor access

Implement remapping/conflict feedback where the platform supports it, touch
scale and left-handed mirroring, hold/toggle alternatives and safe destructive
confirmation. Keep the action IDs shared across keyboard, mouse and touch;
assist options must declare whether they affect records.

### Task A14 — dedicated settings surface

Build the Accessibility tab as a first-class vNext surface with grouped
explanations, live preview, focus order, reset action and recovery for failed
persistence. The tab must remain usable at narrow width and large text, not
become a dense list of unlabeled toggles.

### Task A15 — platform assistive-technology feasibility

Run a time-boxed feasibility check for native screen-reader announcements,
controller navigation and platform font scaling on each claimed export. Record
supported combinations, limitations and follow-up work. Do not turn a failed
feasibility experiment into an inert setting or an unsupported marketing
claim.

## Acceptance Tests

- [ ] Accessibility is a first-class settings route on desktop and mobile.
- [ ] Every option persists, resets to default and applies without a scene reload unless required.
- [ ] Unsupported native assistive technologies are documented honestly and are not represented by inert toggles.
- [ ] Color Assist distinguishes every ambiguous enemy/program in gameplay, bestiary and HUD.
- [ ] Reduce Motion/Flashes/Shake preserve hazard information with stable alternatives.
- [ ] Text/UI scales do not create overflow at 432×720.
- [ ] Touch scale preserves normalized movement behavior and keeps action buttons inside safe areas.
- [ ] Keyboard focus, pointer, touch and back/escape work on all settings sections.
- [ ] Mirrored touch layout, reset-to-defaults and persistence-failure recovery are covered.
- [ ] No setting consumes gameplay RNG or changes collision behavior by accident.
- [ ] The release log records new options, defaults, save keys and any record-policy impact.

# KERNEL PANIC Accessibility + Responsive Layout Design

**Date:** 2026-08-28

## Goal

Improve rapid threat recognition for Splitter and Bulwark, offer a practical
color-assist mode, and make combat UI/touch controls follow the actual
viewport and configured touch size.

## Design

### Threat contrast and redundant markers

Give SPLITTER and BULWARK clearly separated neon hues in the standard palette
while preserving their existing silhouettes. Add a persisted `COLOR ASSIST`
setting. In that mode, use a colorblind-friendly high-contrast palette and a
small code-drawn identity marker for the ambiguous pair (`S` split marker and
`B` armor marker). The markers supplement, never replace, the circle/diamond
silhouettes and do not alter hitboxes or gameplay.

The palette helper is shared by combat drawing and bestiary drawing so the
setting does not create mismatched identities. No raster assets are added.

### Responsive HUD and panels

Replace bottom-anchored HUD coordinates that assume 720px with positions
derived from `Control.size.y` and safe margins. Boss bars, dash text, patch
chips, and resource bars remain in their current visual zones but stay near
the actual bottom edge on expanded aspect ratios. Pause, game-over, intro,
and patch panels use centered anchors or viewport-relative offsets instead of
fixed 1280x720 assumptions. Desktop and mobile controls keep their current
relative side placement.

### Touch-size consistency

The movement stick uses the same `Sfx.touch_scale` as the action buttons:
deadzone, travel radius, draw radius, knob radius, and normalized divisor are
all derived from one scale helper. Aim controls remain behaviorally
unchanged, and a scale change never changes the player's resulting normalized
input vector.

## Files and boundaries

- `src/autoload/balance.gd`: palette/identity helpers.
- `src/autoload/sfx.gd`, `src/ui/menu.gd`: persisted color-assist setting.
- `src/enemies/splitter.gd`, `bulwark.gd`, and
  `src/ui/bestiary_panel.gd`: contrast and redundant markers.
- `src/ui/hud.gd`, `src/arena/arena.gd`: viewport-relative layout helpers.
- `src/ui/touch_controls.gd`: scaled movement-stick geometry only.
- `src/autoload/dev_harness.gd`: palette, layout, and touch-scale probes.

The mode is available on desktop and mobile, but it does not change touch
input, lock-on, enemy stats, or collision behavior.

## Verification

Tests must prove Splitter and Bulwark receive distinct palette values, the
assist marker path is code-drawn, standard rendering remains available, HUD
bottom positions change with viewport height, and movement-stick geometry
scales while its normalized vector remains equivalent. Run the existing
touch harness under normal and forced-touch conditions and finish the full
suite with `AUTOTEST_ALL_PASS` and zero `AT_FAIL`.

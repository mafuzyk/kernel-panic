# KERNEL PANIC Settings + Patch QOL Design

**Date:** 2026-08-28

## Goal

Make desktop controls configurable, make the active build understandable,
and remove the unused Weekly lock-on restriction while preserving the local
deterministic run contract.

## Design

### Desktop key remapping

Define one source of truth for keyboard actions and their defaults. Load saved
physical keycodes from the existing local config before adding events to the
`InputMap`; old saves receive the defaults automatically. The desktop settings
panel exposes the gameplay actions (movement, dash, overclock, pause, abandon,
mute, restart, and confirm) through a capture state. The next valid key press
assigns the action, `Escape` cancels, duplicate assignments are rejected with
a visible conflict message, and `RESET KEYBINDS` restores defaults.

The panel is gated to desktop displays and is not shown or processed as a
touch control. Mouse fire/aim behavior remains unchanged. The `E` overclock /
`Q` abandon separation from the onboarding package is the canonical default.

### Patch context and tooltips

Keep the compact HUD chips, but make them discoverable. Each chip has a hit
rectangle and exposes the full patch title, current level, description, and
short `SYNERGY`/`TRADEOFF` text drawn from static patch metadata. The first
documented anti-synergy is the fire-rate tradeoff between HEAVY and SPLITSHOT;
other entries only advertise relationships that are explicitly listed in the
metadata. Unknown combinations show `NO DIRECT INTERACTION`, never invented
numeric advice.

Desktop hover shows the tooltip without pausing. On touch, a 0.45-second hold
on a chip shows it; movement or release dismisses it. Tooltips consume no
randomness and never change a patch's effect.

### Weekly lock-on

Remove the `weekly` branch that downgrades lock-on. Weekly remains locally
seeded and score-persistent, with no network leaderboard; the selected aim
mode is therefore a valid local preference. The menu copy and regression test
must reflect that lock-on remains selected in Weekly.

## Files and boundaries

- `src/autoload/game.gd`: action registry/config persistence, patch metadata,
  and effective aim mode.
- `src/ui/menu.gd`: desktop keybind capture and settings copy.
- `src/ui/hud.gd`: chip hit testing and code-drawn tooltip.
- `src/autoload/sfx.gd`: persisted settings only if the existing config
  helper needs a small extension.
- `src/autoload/dev_harness.gd`: remap conflict/default tests, tooltip hit/
  hold tests, and Weekly lock-on regression.
- `README.md`: updated desktop controls/settings instructions.

No patch effect, rarity, healing, score, or network behavior changes in this
package.

## Verification

Tests must prove saved/default keybind loading, conflict rejection, cancel and
reset behavior, full patch tooltip content, desktop hover/touch hold timing,
and Weekly lock-on preservation. The full suite must finish with
`AUTOTEST_ALL_PASS` and zero `AT_FAIL`.

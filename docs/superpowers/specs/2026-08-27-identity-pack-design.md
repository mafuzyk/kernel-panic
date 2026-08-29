# KERNEL PANIC — Identity Pack v2.3.5 (design)

Date: 2026-08-27
Status: approved scope (brainstorming session with the author)
Next step: `docs/superpowers/plans/2026-08-27-identity-pack.md`

## Context

KERNEL PANIC is a Godot 4.7.2 mobile-first neon arena shooter (all UI drawn in
code). The strongest identity lever is "you are playing inside an operating
system". This pack turns four cheap cosmetic ideas into reality. It is the
follow-up to the v2.3 balance pass (see `KERNEL-PANIC-V23-HANDOFF.md`) and to
the full code review of 2026-08-27 (see
`docs/superpowers/specs/2026-08-27-review-findings.md`).

## Features

### 1. Boot sequence (menu, all platforms)

- New `src/ui/boot.gd` (`BootOverlay`, Control), instantiated by `menu.gd`
  into a CanvasLayer (layer 95, above the Fx flash layer).
- `menu.tscn` stays the main scene → the autotest assertion
  "menu is main scene" is untouched.
- Content: sequential klog lines (version from ProjectSettings, a real
  save-integrity check via ConfigFile load, "mounting /dev/purge", spawning
  last process), blinking-block aesthetic, ~1.8 s total.
- Any input (key / mouse / touch press) skips it instantly; the consuming
  press must NOT also start a run (overlay intercepts in `_input` before the
  menu's `_unhandled_input`).
- Blocks menu buttons while visible (MOUSE_FILTER_STOP on the overlay).
- Disabled when `DevHarness.active` or `DisplayServer.get_name() == "headless"`
  → the harness ENTER-to-start test keeps its timing.

### 2. Bestiary as man pages

- `src/ui/bestiary_panel.gd`: every `ENTRIES` dict gains
  `"threat"` (enemy pts) and `"bugs"` (one English flavor line, terminal
  humor, per enemy).
- Card layout: glyph unchanged; name unchanged; existing desc line becomes
  the SYNOPSIS; bottom status line becomes `BUGS: <line>` when seen
  (`[ LOCKED ]` stays for unseen entries); threat shown right-aligned as
  `<pts> PTS` on the glyph row, only when seen.
- Lock/scroll/glyph logic untouched.

### 3. Stack trace on elite/boss kill

- `src/autoload/fx.gd`: `FloatText` gains optional multiline rendering
  (`draw_multiline_string`); new `Fx.stacktrace(pos, killer, big := false)`
  with a pool of 3 fake-trace templates (one `%s` each, filled with the
  killer's `display_name`).
- Hook in `arena.gd _on_enemy_died`: only `e.elite` (small, COL_MOTE) and
  non-split `RootBoss` (big, COL_DANGER) emit a trace. Regular enemies never
  do. Fade ~1.1 s.
- Uses the global `randi()`, never `Game.rng` → Weekly seed determinism for
  gameplay is preserved.

### 4. Terminal-block reticle (PC only)

- New `src/ui/reticle.gd` (`Reticle`, Node2D) on a CanvasLayer (layer 85) so
  it ignores camera shake/lean; follows the mouse in screen space.
- Active only when `Balance.is_desktop_display() and not
  DisplayServer.is_touchscreen_available()`; env `KP_FORCE_RETICLE` overrides
  (mirrors the existing `KP_FORCE_TOUCH` pattern).
- OS cursor hidden only while `_state == "play" and not paused`; restored on
  pause, patch UI, game over, and in `_exit_tree` (never leave the player
  cursorless in the menu).
- Draw (no sprites, matches the code-drawn identity): solid cyan block;
  four spread ticks open when `player.fire_cd > 0` and decay; block grows and
  turns COL_PLAYER_HOT while Overclock is active; hidden when the OS cursor
  is visible (pause/menus).

### 5. Included fix: `Balance.is_desktop_display()`

- New static helper in `src/autoload/balance.gd` returning true for display
  server names `["windows", "macos", "x11", "wayland", "embedded"]`.
- `camera_rig.gd` switches its local desktop expression to this helper —
  fixes the camera mouse-lean half of the Wayland detection bug found in the
  review. The `player.gd` half stays for the later fixes pack (out of scope
  here to keep this pack cosmetic-only).

## Non-goals / constraints

- No difficulty knobs (WAVE_SCALE_CAP, elite_chance are LOCKED until
  playtest). No controller support. Lock-on untouched. One-HP rules untouched.
- Mobile behavior unchanged: every PC-only piece is gated behind
  desktop + non-touchscreen checks.
- Texts stay hardcoded English (i18n is a later roadmap item).
- No new assets: everything is code-drawn; fonts already in
  `res://assets/fonts/`.

## Testing

- Full autotest after every task:
  `godot --headless --path . -- --autotest` → must print `AUTOTEST_ALL_PASS`.
- New harness checks (added to `_autotest` in `src/autoload/dev_harness.gd`):
  desktop helper truthiness, boot overlay absent in headless, bestiary
  entries carry `threat`/`bugs`, `Fx.stacktrace` renders without error,
  reticle script loads and ticks without error.

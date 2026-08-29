# KERNEL PANIC — Tactical Kernel UI overhaul

## Goal

Unify every game surface under the approved Tactical Kernel visual system while preserving the code-drawn neon identity, gameplay behavior, touch controls, and desktop responsiveness.

## Visual language

- Deep navy-black surfaces over a restrained grid.
- Thin angular circuit frames; cyan is structural, magenta signals threats, lime signals recovery or protection, amber signals warnings.
- Orbitron for display headings and Share Tech Mono for labels, values, logs, and body copy.
- Glyphs, silhouettes, frames, bars, and stateful previews remain code-drawn so they scale and react correctly. Generated raster assets may be used for measured static slots such as subtle backgrounds or textures only when a same-size comparison proves they improve the approved mock rather than merely decorate it.
- Effects are layered and restrained: opaque readable panels first, glow and scan details second.

## Shared components

The implementation should centralize reusable drawing and layout primitives instead of duplicating coordinates in each screen:

- safe-area-aware viewport metrics and compact-mode breakpoint;
- angular panel/frame and clipped-corner button;
- section header, breadcrumb, status tag, segmented meter, key hint;
- semantic palette helpers and disabled/locked states;
- responsive typography scale and spacing tokens;
- focus, hover, pressed, touch, and keyboard-selected states.

## Screens

### Combat HUD

Integrity and core state live in the upper-left frame; cycle and encounter title are centered; score, combo, and a collapsible four-line event log live upper-right. Dash state occupies the lower-left, active patch chips the lower-right, and boss health remains centered at the bottom. Split ROOT phases use two combined bars. The arena center must remain visually quiet.

### Menu

The title remains the dominant element. Primary run actions form a strong central boot stack; secondary navigation and lifetime data sit in quieter peripheral panels. Mode selection must explain its rules before launch.

### Program selection

Three comparison cards expose identity and tradeoffs at a glance. KERNEL is the balanced default, DAEMON is the two-dash close-range snowball character, and ROOTLET is the armored shield character with no overclock. Selection updates the boot CTA.

### Story selection

Three act tabs (UNIX, Windows, TempleOS) contain connected stage routes rather than a generic grid. The selected stage opens a detail panel with story copy, threats, wave count, scale, klog, and a code-drawn arena preview. Locked progression remains explicit.

### Patch selection

Patch cards state rarity, current level, mechanical effect, and important synergy or conflict. Keyboard, pointer, and touch selection share the same visible state.

### Pause and terminal

Pause preserves combat context and clearly separates resume/restart/settings/terminal from the confirmed abandon action. The terminal is a wide diagnostic workstation with command history, command index, system status, and a persistent prompt. It exposes only the existing command router.

### Settings, bestiary, and game over

Settings groups related controls into readable sections and keeps keybind capture desktop-only. Bestiary uses a threat index plus a large tactical detail area. Game over prioritizes cause, run summary, records, and retry before secondary actions.

## Responsiveness

The 1366×768 mocks define the full layout. At narrow desktop widths, side panels collapse or stack without shrinking text below readability; the event log collapses first. Touch layouts retain existing controls and safe areas. No fixed 1280×720 bottom coordinate may be introduced.

Every generated asset candidate is reviewed at 1366×768, a narrow Hyprland/dwindle window, and a representative mobile aspect ratio. Candidates with visible blur, seams, poor cropping, weak contrast, or a style mismatch are rejected and are never committed as placeholders.

## Accessibility and interaction

- Color is always reinforced by shape, label, or icon.
- Text contrast and panel opacity take priority over decorative grid detail.
- Focus order follows reading order and every actionable item has a visible focus state.
- Motion uses global cosmetic randomness only and never consumes `Game.rng`.
- The OS cursor is restored in menu, pause, patch, terminal, settings, bestiary, program, story, and game-over states.

## Approved visual references

The approved mock set covers HUD, menu, patch selection, pause, settings, bestiary, game over, program selection, story selection, and terminal. Generated references remain outside the repository and are implementation targets, not shipped assets.

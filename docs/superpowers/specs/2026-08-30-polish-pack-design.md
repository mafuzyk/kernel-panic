# KERNEL PANIC — Pack 2: UI polish pack

## Goal

Turn the author's overnight screenshot review (2026-08-30) into a polish pack that fixes what the review flagged without touching gameplay: settings sidebar buttons that really filter content into five tabs, a menu that reflows on viewport resize with the three documented overlap sites repaired, an AWARDS panel with proper dim/frame chrome, the bestiary detail glyph contained inside its rail, a raster icon optical-size pass that stops icons looking "pasted on", the story rail restyled to the approved connected-path mock `exec-e6d82072`, a teardown leak hunt with a recorded baseline and no-increase guard, an author-gated sprite trial behind the glyph fallback, and a gameplay design questionnaire appendix that produces answers for later sessions — not code.

## Non-Goals

- No gameplay changes in items 1–7: damage, spawning, scoring, difficulty numbers, One-HP, lock-on, and touch input rules are untouched. Item 8 is a non-default trial.
- The difficulty selector stays in the menu (prior decision); it does not move into settings.
- No new settings this pack: target fps and fullscreen toggle exist only as backlog questions in the appendix.
- Item 9 is questionnaire-only; nothing from the appendix is implemented in this pack.
- Glyphs remain the shipped default look; the sprite trial changes nothing until the author decides.
- Leak target is "no new leaks vs recorded baseline plus a clear reduction from ~199 ObjectDB instances" — zero is not chased.
- No captures or side-by-side montages are committed; they live in `/tmp` for author review.
- No i18n, no macOS act, no photo mode (v2.7+ roadmap items).

## Context

- Baseline: autotest at 1194 AT_PASS / 0 AT_FAIL across 68 AT_STEP labels. Harness engine lives in `src/autoload/dev_harness.gd` (624 lines after refactor) with case sections in `src/autoload/harness/sections_*.gd`; the `KP_SHOT` capture path already exists (`dev_harness.gd` lines 39–41).
- Settings (`src/ui/menu_settings_kit.gd`): one scrolling VBox (`_settings_box`) behind a sidebar. Nav buttons AUDIO/GAMEPLAY/CONTROLS/ACCESSIBILITY/SAVE DATA only scroll — `nav_targets = [0, 0, 0, 0, 100000]` (lines 359–382), which is exactly the author's "4–5 botões mas só um realmente é diferente" complaint. Keybind capture is desktop-gated via `_desktop_keybinds_enabled()`; ESC handling lives in `menu.gd::_unhandled_input` with keybind-capture ESC consumed first (`_handle_keybind_capture`).
- Menu (`src/ui/menu.gd` + `src/ui/menu_chrome_kit.gd`): every block is placed once at `_ready` from `m.size` — title offsets 125–235 at font 76 (`_mk_title`), klog 120–190 at x 16–620 (`menu.gd` lines 226–238), controls line 193–219, `mode_info` 190–234, best label 265–289. There is no resize hook anywhere in `menu.gd`, confirming the old finding "menu button row built once with _ready size does not reflow". Screenshot evidence maps to real rect overlaps: title band (125–235) overlaps klog (120–190), and controls (193–219) overlaps `mode_info` (190–234).
- AWARDS button (`menu_chrome_kit.gd` lines 251–256) is the only footer card button built without `_add_button_icon` — SETTINGS uses the "settings" kind, BESTIARY the "bestiary" kind.
- Achievements panel (`src/ui/achievements_panel.gd`) draws only a polygon frame; there is no dim layer over the menu, so rows float over the visible shell — matching the screenshot.
- Bestiary detail (`src/ui/bestiary_panel.gd::_draw_detail`, lines 246–280): the large glyph is drawn at `rail.end.x - 118` with scale 3.5 and unit radius 16 (`GlyphLib.draw_glyph(self, id, Vector2.ZERO, 16.0, c)`); lancer-class glyphs reach ~40 units, so the dart pokes ~22px past the rail's right edge. The PTS chip (line 264) sits on its own row, unaligned with the glyph.
- Story route (`src/ui/story_panel.gd` lines 221–277): center-to-center connector lines drawn under opaque card chips. The approved mock `exec-e6d82072` (per overnight report §2) wants a connected node path with node brackets and CLEARED / CURRENT / LOCKED state labels instead of plain chips.
- Task 7c icon registry (`src/ui/tactical_icon.gd`): `raster_path()` returns the generated PNG when present, else `""` → code-drawn fallback; `ICON_METRICS` / `ICON_BOUNDS` are harness-enforced contracts; rasters are drawn stretched across the full control rect (line 103), so baked glow inflates the optical footprint at 52px and softens glyphs at 24px. The Task 7c decision-log correction stands: style is the identity, not the drawing technique.
- Teardown: ~199 ObjectDB instances plus CanvasItem/Area2D RID leaks logged at exit (overnight report §2). Known suspects: static resource caches (`tactical_icon.gd::_raster_tex_cache`), fonts/materials loaded by RefCounted kits, orphan CanvasLayers and tweens.
- Verified 2026-08-30: `assets/icons/generated/` contains no `trophy`/`awards` raster — and also no `settings.png`/`bestiary.png`; those kinds currently render via the code fallback. The approved assumption "raster trophy already exists" is incorrect; the registry pattern must support generating it or falling back to a new code-drawn "awards" kind.

## Proposed Architecture

### 1. Settings REAL tabs

The sidebar becomes a section selector, not a scroller. A single `active_section` state in `menu_settings_kit.gd` drives which controls are visible; nav buttons set state instead of scroll targets. Exactly one section is visible at a time, the section title shows the active name ("SETTINGS // AUDIO" style), and the selected nav button gets a distinct selected style + marker.

Content mapping (every existing control survives, only its section home changes):

- AUDIO: SFX slider, MUSIC slider, MUTE ALL, and the "M = MUTE IN GAME" hint.
- GAMEPLAY: HAPTICS, AIM MODE, TOUCH SIZE (visible on touch devices only, as approved), plus SCREEN SHAKE and SPEEDRUN HUD. Flagged assumption: the approved mapping did not name these two; they are gameplay-feel toggles and GAMEPLAY is their only coherent home.
- CONTROLS: DESKTOP KEYBINDS grid + RESET KEYBINDS, desktop-gated exactly as today; on touch builds the section shows a "DESKTOP ONLY" note instead of an empty pane.
- ACCESSIBILITY: COLOR ASSIST.
- SAVE DATA: export field, COPY EXPORT / IMPORT PASTE row, transfer status, RESET HIGH SCORE, and the lifetime stats line.

Constraints preserved: ESC closes the whole settings panel exactly as today (keybind-capture ESC still wins first); keyboard/touch navigation keeps working through the existing Button-based nav; difficulty stays in the menu. Mobile layout: below the 760 compact breakpoint (the breakpoint used by `TacticalUI` / `TacticalStateSurface`), the sidebar collapses to a horizontal chips row above the content; chips share the same active state. A `settings_section_snapshot()` helper exposes `{active, sections, visible_controls}` for the harness.

### 2. Menu responsive reflow + overlap fixes

Introduce `menu_layout_for_viewport(viewport)` in `menu_chrome_kit.gd` (mirroring `settings_layout_for_viewport`) returning rects for title, klog, controls line, best label, mode_info, program/difficulty pair, and the button row + its three frames. `_build_button_row` consumes it at build time; menu connects to viewport resize and re-applies rects, re-scales the title font, and re-derives the decorative anchors used by `draw_shell` (warning ring, mode dot) from the same dict. No fixed 1280×720 bottom coordinate may appear.

The three review fixes: (a) klog moves to a corner zone guaranteed disjoint from the title band at all supported sizes; (b) controls line and mode_info get disjoint rects from the same dict (mode_info keeps autowrap and only shows for non-classic modes); (c) AWARDS gets its trophy icon — a new code-drawn "awards" kind plus a trophy raster generated through the Task 7c pipeline, wired via the same `_add_button_icon` path as SETTINGS/BESTIARY, with the registry fallback covering whichever asset the author rejects.

### 3. AWARDS panel chrome

`achievements_panel.gd` adopts the bestiary/story overlay treatment: full-rect dim over the menu, TacticalStateSurface-class chrome framing a centered panel, header preserved. Rows become card rows (angular frame each): unlocked rows get lime border + check glyph + label; locked rows get muted border + dim hint text. The existing ScrollContainer, `refresh()` semantics, back button, and the ESC chain are unchanged. Mobile containment is checked like every other overlay.

### 4. Bestiary detail glyph containment

Designate a fixed glyph box inside the detail rail (right column), compute the per-entry glyph extent, and fit the glyph scale into that box (scale down; clip only as a last resort so silhouettes stay readable) — no entry's glyph may cross the rail border at 1366×768 or 432×720. The PTS chip row aligns to the glyph box baseline. A small metrics dict normalizes the detail column's vertical rhythm (FIELD ENTRY line, name, threat line, divider, BEHAVIOR, BUG REPORT). `text_overflow_report()` gains a `glyph_contained` entry.

### 5. Raster icon optical-size pass

- Optical margins: per-kind inner padding so the raster glyph's visual center and stroke weight match the code baseline at 52px and 24px; the texture is drawn into the padded rect, not edge-to-edge.
- Trim baked glow halos from generated PNGs (tight re-exports) so hit rects hug the glyph; `ICON_BOUNDS` remains the containment contract.
- Registry extension: per-kind × per-size (52/24) opt-out list — where a raster reads blurry at 24px, the registry returns `""` for that size and the code fallback renders. Documented and harness-visible.
- Side-by-side before/after captures per placement go to `/tmp` for author review; nothing commits without her gate.
- The Task 7c correction is preserved verbatim: the neon geometric style is the identity; raster vs code is a technique swap, never a style change.

### 6. Story rail connected path

Restyle the route drawing only in `story_panel.gd` toward mock `exec-e6d82072`. Frozen by this task: `_card_rects`, `_tab_rects`, touch hit areas, scroll mechanics, stage data, and the wide/narrow layout metrics. Kept: the existing connector lines. Added per mock: node brackets around the existing number circles, a state ring/glyph per node — CLEARED (stage-accent ring + check), CURRENT (bright ring + pulse), LOCKED (dim ring + lock glyph) — and small state labels ("CLEARED" / "CURRENT" / "LOCKED") replacing the plain chips' implicit state. Containment checks (wide + narrow) must stay green; `text_overflow_report()` is extended for the new labels.

### 7. Teardown leak hunt

Profile first: one stable harness invocation with `--verbose`, capturing the exit ObjectDB/RID report and attributing leaks to owners (static caches, kit-held fonts/materials, orphan layers/tweens/viewports). Then free offenders through explicit teardown — closing overlays frees their layers, static caches clear on exit notification, shared fonts/materials preload once — never by hiding orphans. Finally, a harness check records the baseline leak counts and asserts future runs do not increase them (small documented tolerance for engine noise). The achieved number is recorded in the completion report; target is no new leaks plus a clear reduction from ~199.

### 8. Sprite trial (author-gated, non-default)

Same trial pattern as Task 7c: the orchestrator's imagegen produces per-entity concept sheets (enemies, bosses, programs) outside the repo; they are cropped/keyed to white-base sprites with transparent backgrounds. A new `src/ui/entity_sprite.gd` registry holds the per-entity path lookup with glyph fallback, and all glyph call sites route through one lookup so fallback is a single switch. Arena sprites stay non-rotating; silhouette readability is the acceptance bar; hit flash (modulate) and elite/era tint must work via modulate, which requires white-base art. If a sheet cannot be tinted via modulate without artifacts, that is recorded as a trial finding instead of forcing it. Side-by-side glyph-vs-sprite captures go to `/tmp`; glyphs remain the shipped default until the author decides.

### 9. Gameplay backlog design questionnaire (appendix only)

The appendix at the end of this document lists the approved-direction gameplay ideas, each with the open design questions the author must answer before implementation. The orchestrator will surface them as interactive questions in a later session; nothing here is implemented in this pack.

## Files To Change

New:

- `src/ui/entity_sprite.gd` — sprite trial registry with glyph fallback (item 8).
- `src/autoload/harness/sections_polish.gd` — new test-first checks: settings tab filtering + selection state, menu resize probe, awards containment, leak baseline guard (items 1, 2, 3, 7).

Modified:

- `src/ui/menu_settings_kit.gd` — section state machine, content mapping, selected styles, mobile chips row, `settings_section_snapshot()`.
- `src/ui/menu.gd` — resize wiring and re-layout calls, overlap fixes, snapshot updates (`settings_shell_snapshot` groups follow the new sections); ESC chain untouched.
- `src/ui/menu_chrome_kit.gd` — `menu_layout_for_viewport()`, reflowable frames, AWARDS icon wiring, `draw_shell` anchors from the shared dict.
- `src/ui/achievements_panel.gd` — dim + chrome + card rows.
- `src/ui/bestiary_panel.gd` — detail glyph box/containment, PTS chip alignment, spacing sweep.
- `src/ui/story_panel.gd` — node brackets, state rings, state labels, lock/check glyphs (drawing only).
- `src/ui/tactical_icon.gd` — optical padding, per-size opt-out registry, "awards" code kind + metrics/bounds entries.
- `src/ui/glyph_lib.gd` — single entity-lookup shim consumed through the sprite registry (item 8).
- `assets/icons/generated/` — trimmed raster re-exports and `awards.png` via the Task 7c pipeline (author gate before commit).
- `src/autoload/dev_harness.gd` — register the new section and the KP_SHOT side-by-side capture targets.

Unchanged by design: `src/player/`, `src/enemies/`, `src/arena/`, gameplay constants and all difficulty read points in `src/autoload/balance.gd`, One-HP / lock-on / touch input rules.

## Testing Strategy

- Gate for every task: full autotest green — baseline 1194 AT_PASS / 0 AT_FAIL; the count only grows with new checks, and each behavior-changing task adds its checks test-first (red → green) before the fix:
  - Item 1: for each of the five sections, activating it hides every other section's control inside the visible content rect; exactly one nav button is selected and the header shows the active name; ESC still closes the panel; touch-width run exercises the chips row.
  - Item 2: resize probe sets 1366×768, 432×720, and two intermediate viewports, asserting no rect intersections among title / klog / controls / best / mode_info / button row and containment inside the shell.
  - Item 3: awards rows sit inside the panel rect at both resolutions with chrome present and scroll intact.
  - Item 7: leak baseline recorded once; the guard asserts no increase within documented tolerance.
- Containment/overflow reporting extends where drawing changes: bestiary `glyph_contained`, story state labels, keeping the existing `text_overflow_report()` pattern.
- Visual verification uses KP_SHOT captures on the author's DP-1 monitor (window class `KERNEL PANIC` via the `hl.window_rule()` runtime eval pattern, process killed after captures); captures and side-by-side montages stay in `/tmp` and are never committed.
- Both resolutions are hard gates for every visual change: 1366×768 and 432×720.

## Risks And Mitigations

- The settings split can break existing harness assumptions (single scrolling box, `settings_shell_snapshot` groups, keybind grid checks). Mitigation: keep every control alive in the tree (visibility-filtered, never rebuilt), update the snapshot APIs in the same change, and run the autotest immediately after the split lands.
- The resize reflow can regress decorative draw anchors that are not in the layout dict. Mitigation: route all anchor math in `draw_shell` and frame placement through `menu_layout_for_viewport()`, and land the resize probe check before any layout change (test-first).
- The leak baseline can be flaky because Godot's exit reports vary run-to-run. Mitigation: one fixed profiling invocation, a baseline recorded in the harness, and a no-increase assertion with a small documented tolerance instead of exact equality.
- Icon trimming alters visuals the author already approved. Mitigation: per-placement side-by-side captures, a per-kind opt-out that restores prior behavior with one list entry, and an author review gate before commit.
- Sprite tint-via-modulate may prove unviable for some sheets. Mitigation: record it as a trial finding; the glyph fallback remains the shipped default.
- The story restyle could disturb touch hit areas. Mitigation: `_card_rects` / `_tab_rects` computation is frozen by the task; only the draw pass changes while hit-rect and containment checks stay green.

## Decision Summary

- Settings sidebar becomes five real filter tabs (AUDIO / GAMEPLAY / CONTROLS / ACCESSIBILITY / SAVE DATA), one visible at a time, selected state on the nav button, ESC chain unchanged, difficulty stays in the menu; SCREEN SHAKE and SPEEDRUN HUD assigned to GAMEPLAY (flagged assumption); touch devices only see TOUCH SIZE in GAMEPLAY and a desktop-only note in CONTROLS.
- Menu gains a central layout dict with resize reflow; the klog/title and controls/mode_info overlaps are fixed from that dict; AWARDS gets a trophy icon via the Task 7c registry with code fallback (the raster does not exist yet — verified 2026-08-30).
- AWARDS panel adopts bestiary/story chrome (dim + frame) with card rows and unlocked/locked visual states; scroll and ESC preserved.
- Bestiary detail glyph fits a designated box inside the rail; PTS chip aligned; detail-column spacing normalized via one metrics dict.
- Raster icons get optical padding, trimmed glow halos, and a per-kind × per-size opt-out; the style-is-identity correction is preserved.
- Story rail is restyled to the connected-node mock (CLEARED / CURRENT / LOCKED brackets) with hit rects, scroll, and layout metrics frozen.
- Teardown: profile → free offenders → recorded leak baseline with a no-increase guard; the achieved number is recorded, zero not required.
- Sprite trial runs behind a new `entity_sprite` registry with single-switch glyph fallback; author-gated; white-base modulate tinting required or recorded as a finding.
- Item 9 is questions-only: the gameplay ideas below are deferred pending the author's answers.

## Appendix — Gameplay backlog design questionnaire (no implementation in this pack)

1. **Zombie processes `<defunct>`** — defeated enemies leave harmless ghost hulls for a while. Open questions: Do zombies block enemy pathing or only bullets? Is their lifetime fixed seconds or hit count? Do they award chain/combo when destroyed?
2. **Ring-0 double overclock** — overclock can stack twice with an intensified cost. Open questions: Does stacking come from re-pressing during overclock or from a separate charge? What is the cost model (integrity, longer cooldown, or both)? How does it interact with DAEMON's dash overclock?
3. **Page cache** — store spare motes and release them later. Open questions: What is the capacity? Is release a manual action or automatic on empty? Does the cache decay while stored?
4. **Weekly mutators per seed** — rotating rule modifiers on the weekly mode. Open questions: How many mutators are active per week? Are they visible before the run starts? Do they separate leaderboards from unmutated runs?
5. **Boss OOM desperation (<8% HP)** — final-phase frenzy below a threshold. Open questions: Is the behavior per-boss or a shared pattern? What is the fairness telegraph (visual/audio tell)? Does it threaten One-HP mode balance?
6. **Race-condition pair** — twin enemies that punish distance between them. Open questions: Is the link shared HP, a leash, or synced attacks? What spawn density keeps it fair? Is the intended counter-play killing fast or keeping them apart?
7. **SAFE MODE** — low-risk assist mode. Open questions: Does it disable scoring/records? Does it stack with the FÁCIL difficulty or stand alone? Is it unlockable or always visible?
8. **Practice wave select** — replay any reached wave. Open questions: Is entry unlocked per stage clear or per wave reached? Do practice runs write records or carry a practice flag? Where is the entry point (story detail panel vs pause)?
9. **Score-as-PID** — score presented as a process id narrative. Open questions: Is it pure display flavor or does PID ordering affect anything (spawn priority, log ordering)? What are the rollover/reuse rules?
10. **Death heatmap** — persistent map of death positions. Open questions: Where is it visible (game over, bestiary, terminal)? Is it per-stage or global? What is the retention window?
11. **Patch music layers** — music stems keyed to active patches. Open questions: Which layers exist (bass/lead/percussion)? Crossfade or mute on transition? What is the mobile performance budget?
12. **Fullscreen toggle + target_fps UI** — future settings additions. Open questions: Which section hosts them (AUDIO was noted earlier — or a future DISPLAY section)? What are the per-platform defaults (mobile vs desktop)? Does target_fps expose an unlimited option?

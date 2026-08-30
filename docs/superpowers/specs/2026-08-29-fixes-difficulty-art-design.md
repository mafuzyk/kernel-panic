# KERNEL PANIC — Fixes: Story Intro, HUD Transparency, Mote Tunneling, Difficulty, Entity Glyphs

**Date:** 2026-08-29

## Goal

Fix six diagnosed bugs (story intro overflow/rushing/enemy pre-spawn, opaque combat
HUD, HUD ignoring era color, mote pickup tunneling) and add two approved features
(EASY/NORMAL/HARD difficulty for endless modes, code-drawn enemy/program glyph
rework) while keeping every existing behavior, the neon geometric terminal identity,
and the full autotest suite green at default settings.

## Non-Goals

- No changes to Story mode's fixed per-stage difficulty curve.
- No touch control, controller, or input-remap work (controller remains unsupported).
- Approved mocks are targets, not committed assets. Raster icon trials (Tasks 7b/7c)
  ship under `assets/icons/generated/` only where a same-size in-game comparison
  proves they look better than the code-drawn version — the identity is the neon
  geometric terminal style, not the drawing technique (code-drawn was only the
  original technique because sprites were harder to make; author statement
  2026-08-29). No entity raster sprites in this pack; a generated-sprite trial for
  enemies/bosses/playable programs is approved and scheduled for a future session.
- No edits to locked balance constants (`WAVE_SCALE_CAP`, base `wave_budget`,
  `max_alive`, `elite_chance`, cadence floor 0.78) — difficulty acts as multipliers
  at read points only.
- No One-HP heal sources, no lock-on availability changes, no RECOVER/SECOND WIND
  saves in any mode.
- Endless wave-intro bars (`_intro_label` path) are untouched.

## Task 1 — Story intro sequence

**Root cause.** `arena.gd:737-738` sizes `_story_intro_text` at 344x54 (font 15, no
autowrap) while `story_data.gd` intros are 70-95 chars, so text overflows the panel.
`arena.gd:757-764` plays a fixed 0.35s fade-in + 2.4s hold + 0.5s fade-out (~3.25s)
with no input dismiss. `arena.gd:153-155` calls `spawner.start_story(...)` in
`_ready()` before the deferred intro shows, so enemies move during the popup.

**Design.**

- Intro text wraps: measure every line with `Font.get_string_size()` / wrapped-line
  count at the panel content width; the label gets `autowrap_mode = WORD_SMART` and
  the panel grows vertically to fit, capped at a viewport-safe height with one
  font-size step down (floor 12) before any truncation. Panel stays code-drawn.
- Timing becomes a small state machine in `arena.gd`: fade in 0.35s → hold (input
  ignored for the first 0.8s, then any key/tap dismisses; a "PRESS ANY KEY" hint
  appears once the minimum display elapses) → fade out 0.5s → fire an
  intro-dismissed callback. Safety auto-dismiss at 8.0s after full visibility.
- Story spawning is gated on that callback: `_ready()` keeps signal wiring but moves
  `spawner.start_story(...)` to after intro dismissal, so the player sees an empty
  arena during the intro. Player movement is not frozen.
- Dismiss input listens on keyboard, mouse, and touch equally; it consumes no
  `Game.rng` values.

**Files.** `src/arena/arena.gd`, `src/autoload/dev_harness.gd`.

**Verification.** Harness checks must prove: (a) with no input, zero enemies exist
during the intro and the first story wave starts only after auto-dismiss; (b) input
at t≥0.9s dismisses and starts spawning; (c) input before 0.8s is ignored; (d) for
every stage in `story_data.gd`, the wrapped intro measures inside the panel's text
rect at 1366x768, 720x720, and 432x720.

## Task 2 — Combat HUD transparency

**Root cause.** `hud.gd:395-401` `_draw_angular_panel` fills all six combat panels
(integrity, encounter, score, dash, patches, event log) with
`tactical_ui.gd:5` `PANEL = Color(0.015, 0.035, 0.07, 0.90)`, blocking the arena.

**Design.** Combat-only change, matching the approved combat HUD mock: during
gameplay the six panels render the existing 0.72-alpha outline plus a faint fill
capped at alpha 0.04-0.08 (new `TacticalUI.COMBAT_FILL`). Menu, pause, terminal,
game-over, and settings surfaces keep the opaque `PANEL`. Text drawn over the faint
fill keeps its current contrast treatment; no layout positions change.

**Files.** `src/ui/tactical_ui.gd` (new constant), `src/ui/hud.gd`, harness.

**Verification.** Harness check that the combat draw path uses `COMBAT_FILL` (alpha
≤ 0.08) while non-combat panels still use `PANEL`; KP_SHOT captures at all three
reference resolutions compared against the approved combat HUD mock
(`exec-10cafd61`).

## Task 3 — HUD follows era accent

**Root cause.** `arena.gd` sets `_era_color` at three sites — `_apply_story_theme`
(line ~773), endless per-wave `Balance.era_color(wave)` (line 842), and TempleOS
rainbow (line ~1529) — but `hud.gd` draws with static `TacticalUI.CYAN`.

**Design.** Add `Hud.set_era_accent(color: Color)`. Arena pushes the accent at all
three sites; Hud stores `_era_accent` (default `TacticalUI.CYAN`) and replaces the
static CYAN references in its shell/panel/bar/log draw paths with it. In TempleOS
rainbow mode Arena re-pushes the cycling color each frame (cheap set +
`queue_redraw`; uses cosmetic time only, never `Game.rng`). Endless modes that
resolve to CYAN look exactly as today.

**Files.** `src/arena/arena.gd`, `src/ui/hud.gd`, harness.

**Verification.** Harness: default accent is CYAN before any push;
`set_era_accent` changes the exposed accent and a redraw occurs; rainbow mode
produces different accents across sampled frames without advancing `Game.rng`.

## Task 4 — Mote pickup tunneling + OOM_KILLER steal association

**Root cause.** `mote_field.gd:207` collects only when `d < 20.0` at a single
physics-frame position. `balance.gd:17` DASH_SPEED 1150 → 19.2px/frame at 60Hz;
with TURBO DASH (`player.gd:308`, +12%/level) up to ~1426px/s = 23.8px/frame, so a
dash can step over a mote. Separately, `oom_killer.gd:30-37` resolves a mote by
index; `MoteField` swap-remove (`kill_slot`) reindexes slots, so a held index can
silently point at a different mote.

**Design.** Swept pickup: `MoteField` stores the player's previous physics-frame
position and collects when the distance from a mote to the segment
(prev_pos → current_pos) is < 20.0 (point-segment distance; magnet/pull logic
unchanged). OOM_KILLER: replace the held raw index with per-frame re-resolution via
the existing nearest-free-mote query (or an id-checked handle that re-resolves when
the slot's identity no longer matches); a steal must always target a live, free mote.

**Files.** `src/pickups/mote_field.gd`, `src/enemies/oom_killer.gd`, harness.

**Verification.** Regression test: a simulated max-turbo dash trajectory (1426px/s,
60Hz steps) passing directly over a mote collects it, including a mote centered at
the segment midpoint; a trajectory far away does not. OOM test: kill the mote
adjacent to the OOM's target and assert the steal still binds to a live free mote,
never a dead slot.

## Task 5 — Game-wide text overflow audit

**Root cause.** Fixed widths/positions without measurement across the new Tactical
UI surfaces, e.g. `story_panel.gd:336` klog lines at hardcoded x=208 with a 2-line
cap and `rail.size.x - 226` width, plus `bestiary_panel.gd:274,276`,
`program_panel.gd:185-189`, `patch_card.gd:87`, menu, terminal, and game-over text.

**Design.** One measurement discipline applied everywhere: measure with
`Font.get_string_size` / wrapped-line counts before drawing; then (a) autowrap
inside the panel content rect with panel-grown or clamped height, (b) one font-size
step down (per-surface minimum) when wrapped height exceeds the space, (c)
ellipsis-truncate only non-essential single-line chips — never rules/copy text.
Positions become rail-relative instead of hardcoded absolutes (klog x=208 becomes a
measured second-column origin; fixed line-count caps become measured-space caps).
All rendering stays code-drawn.

**Files.** `src/ui/story_panel.gd`, `src/ui/bestiary_panel.gd`,
`src/ui/program_panel.gd`, `src/ui/patch_card.gd`, `src/ui/menu.gd`,
`src/ui/terminal_panel.gd`, `src/ui/tactical_state_surface.gd` (game-over),
`src/ui/tactical_ui.gd` (shared measurement helpers), harness.

**Verification.** Harness checks that representative long strings for every listed
surface measure inside their panel rects at 1366x768, 720x720, and 432x720. During
implementation, run the game with the `KP_SHOT` capture hook fullscreen/windowed
and compare captures against the approved mocks before declaring each surface done.

## Task 6 — Difficulty setting (endless modes only)

**Design.** EASY/NORMAL/HARD applies to classic, weekly, and onehp only; Story
keeps its fixed per-stage curve. Default NORMAL is exactly today's numbers. The
setting persists as `game/difficulty` in the existing `Sfx.SAVE_PATH` config,
loads at boot into a `Game.difficulty` property, and a `DIFFICULTY: NORMAL` cycler
sits next to MODE in the menu (mirrors `_cycle_mode` persistence in
`menu.gd:664-676`); when mode is STORY the cycler shows "FIXED CURVE" and does not
change gameplay.

Multiplier table (applied at spawner/Balance read points; locked constants
untouched):

| Knob | EASY | NORMAL | HARD | Base |
| --- | --- | --- | --- | --- |
| max_alive cap | 7 | 10 | 13 | 10 |
| wave budget multiplier | 0.8 | 1.0 | 1.2 | 1.0 |
| elite_chance multiplier | 0.6 | 1.0 | 1.4 | 1.0 |
| attack cadence floor | 0.90 | 0.78 | 0.70 | 0.78 |

Semantics: `alive_cap = ceil(Balance.max_alive(wave) * alive_mult)` (7/10/13 on
base-10 waves; the wave-1 ramp scales proportionally). Budget:
`int(wave_budget(wave) * budget_mult)` before the existing surge/rich event
modifiers at `spawner.gd:163-167`. Elite: `clampf(elite_chance(wave) *
elite_mult, 0.0, 1.0)` at the roll in `spawner.gd:329`. Cadence:
`clampf(attack_cadence_factor(wave) * cadence_scale, floor, 1.0)` where
cadence_scale is 1.0/1.0/0.897 (35/39, so the base 0.78 floor maps onto the 0.70
hard floor) and floors are 0.90/0.78/0.70. `Balance` exposes these as new
difficulty-aware read helpers; the existing base functions keep their signatures
and values, so all locked harness checks (`max_alive(1)==8`, `max_alive(2)==10`,
`max_alive(30)==10`, cadence wave checks) pass unchanged at NORMAL.

Weekly determinism: difficulty is a local setting, never part of the seed; the same
seed plus the same difficulty reproduces the same run, and the existing weekly
seed-determinism harness check must stay green. One-HP remains no-heal at every
difficulty.

**Data flow.** Config (`game/difficulty`) → `Game.difficulty` at boot → menu cycler
writes config on change → Balance read helpers consulted by `spawner.gd` and
`enemy_base.gd` cadence calls.

**Files.** `src/autoload/balance.gd`, `src/autoload/game.gd`, `src/ui/menu.gd`,
`src/arena/spawner.gd`, harness.

**Verification.** Harness must prove, per difficulty: alive caps 7/10/13 at wave 2+
(and proportional wave-1 ramp); budget multiplier applied before surge/rich;
elite roll multiplied and clamped; cadence at wave 1 is 1.0 for all difficulties
and at wave 30 is 0.90/0.78/0.70; story-mode spawns identical across difficulties;
weekly determinism check unchanged; the full suite still passes with all 792
existing checks unmodified at default NORMAL.

## Task 6b — Achievements panel and run-log surfacing

**Design.** Achievement unlocks surface in two places while persistence stays
untouched. Data flow: `Game.unlock_achievement()` (game.gd:485) already calls
`log_event("achievement: %s enabled" % label)` before emitting
`achievement_unlocked`, so the line lands in `Game.event_log` and the in-run HUD
event log (`hud.gd` `visible_event_lines()` at line 155, drawn at hud.gd:437)
shows it during gameplay; the existing klog toast (`Hud.show_achievement`,
hud.gd:212, wired at hud.gd:111) stays exactly as is. The harness guards this
path: a fresh mid-run unlock must appear in the HUD event lines, and an unlock
while the event log is hidden (compact/mobile layouts where
`event_log_visible()` is false) must not error. `game.gd` is edited only if that
guard fails (expected: no edit — the log call already precedes the emit).
Achievements unlocked outside a run never touch the HUD draw path and never
error.

Panel design: new code-drawn `AchievementsPanel` (`src/ui/achievements_panel.gd`)
in the Tactical Kernel language — angular `TacticalUI.PANEL` background, cyan
outline, mono type, TacticalUI tokens only. It opens from the menu secondary
navigation as an AWARDS card next to BESTIARY in the bottom button row, mirroring
the bestiary overlay shell (CanvasLayer layer 70, BACK [ESC] button, both ESC
close chains). The body is a ScrollContainer so mobile scroll is never blocked.
Header reads "ACHIEVEMENTS // X / Y UNLOCKED"; one row per `ACHIEVEMENT_DEFS` id
(first_blood, boss_purge, chain_max, terminal_operator, integrity_restored):
unlocked rows bright with an `[OK]` chip, locked rows dimmed with a hint line.
Persistence is unchanged: config section "achievements" and the save
export/import coverage (game.gd:538/585) are not modified.

**Files.** `src/ui/menu.gd` (entry + shell), new `src/ui/achievements_panel.gd`,
`src/autoload/game.gd` (only if the surfacing guard fails), harness.

**Verification.** Harness: the panel lists every `ACHIEVEMENT_DEFS` id with the
correct locked state and a non-empty hint per locked row; the header shows the
X/Y progress count; the panel body uses a ScrollContainer; the menu wires
`_open_achievements`; a fresh mid-run unlock appears in a detached HUD's
`visible_event_lines()`; unlocking with the event log hidden at a 432x720
viewport raises no error. Interactive check: the AWARDS panel renders at
1366x768 and 432x720 with working scroll and ESC/BACK closing.

## Task 7 — Enemy and program glyph rework

**Design.** New shared library `src/ui/glyph_lib.gd` with static drawing functions
(one per entity kind: `draw_glyph(kind, center, radius, color, t)` style), consumed
by enemy `_draw` in-arena, `bestiary_panel.gd` detail views, and
`program_panel.gd` cards so silhouettes match everywhere. It is distinct from
`tactical_icon.gd`, which stays the UI-chrome icon library. Glyphs per the approved
mocks: DRONE magenta dart triangle; LANCER amber dart with line; SPEWER purple
hexagon with core dot; SPLITTER red circle with minus; BULWARK blue/cyan square
with X; TROJAN dark-red diamond; OOM_KILLER purple horned circle; PAGE small page
glyph; RECURSOR green angular glyph; FIREWALL cyan wall/anchor glyph; BLOATWARE
fat rounded square; UPDATE_LOOP circular-arrow glyph; ROOT bosses segmented broken
ring (ROOT.exe) with SEGFAULT/BLUE SCREEN/PAGE FAULT variants restyled in the same
language; TempleOS act glyphs follow the rainbow cycling. Playable programs:
KERNEL cyan hex-core dart, DAEMON magenta tri-dart, ROOTLET lime shield-carrier.
On story acts the identity color mixes toward the era accent (~0.25 lerp). Hit
flash, glow, telegraphs, color-assist markers, and hitboxes are unchanged — this
is visual-only. Approved references: combat `exec-10cafd61`, bestiary
`exec-6582ea9f`, programs `exec-450f92b7` in
`/home/mafu/.codex/generated_images/01a044e4-d316-7ef2-85d8-9aa85056ea3a/`.

**Files.** New `src/ui/glyph_lib.gd`; draw paths in `src/enemies/drone.gd`,
`lancer.gd`, `spewer.gd`, `splitter.gd`, `bulwark.gd`, `trojan.gd`,
`oom_killer.gd`, `recursor.gd`, `firewall.gd`, `bloatware.gd`, `update_loop.gd`,
`page_node.gd`, `root_boss.gd`, `god_boss.gd`, `enemy_base.gd` (shared
flash/glow hooks only); `src/ui/bestiary_panel.gd`, `src/ui/program_panel.gd`,
`src/player/player.gd`; harness.

**Verification.** Harness: every glyph kind draws without errors at minimum and
maximum radii; existing hitbox, telegraph, color-assist, and hit-flash tests stay
green unchanged. KP_SHOT captures of arena, bestiary, and program panel compared
against the three named mocks at all three reference resolutions.

## Task 7b — Tactical icon quality pass

**Scope.** Every code-drawn UI icon: all 10 `tactical_icon.gd` kinds (settings,
bestiary, dash, back, resume, restart, terminal, audio, music, warning — used by
pause buttons, the HUD dash badge, and menu/settings cards) plus all 26
`Game.PATCH_CODES` hex icons in `patch_card.gd` `_draw_icon` (today mostly "+"
crosses and dot grids), grouped by family — damage (heavy, core, splitshot,
ricochet, pdash, thorns, staticf), fire (rapid, threads, chain), defense (hp,
shield, absorb, restore, secondwind, vampic, recycler, dataleech), utility
(cell, magnet), movement (dash, mdash, turbo, light), economy (frag, scrapdiet)
— and the program glyph icons on `program_panel.gd` cards. Author report: the
current icon set reads rough/unclear at UI sizes.

**Workflow.** GPT image generation is a design tool, not an asset pipeline: the
orchestrator runs `gpt_imagegen` and hands candidate concept sheets to the
implementer (saved to `media/concepts/`, gitignored, never committed); the
implementer never calls imagegen. Every candidate is judged critically at the
same pixel size as the shipped icon. A raster ships only when the same-size
comparison proves it beats the code-drawn version; otherwise the generated art
serves as visual reference and the icon is implemented as a crisper code-drawn
drawing. The code-drawn version always remains the fallback; rasters are never
placeholders. The identity is the neon geometric terminal style, not the drawing
technique — code-drawn was only the original technique because sprites were harder
to make (author correction, 2026-08-29) — and rasters are welcome wherever a
same-size in-game comparison proves they look better. Any winning raster is trimmed, transparent-compatible,
stored at `assets/icons/generated/`, and committed only after the comparison is
approved, wired through a registry that keeps the code path alive.

**Critical-evaluation criteria.** (a) Crispness at 52px (menu/settings card
icons) and 24px (small HUD chips): no blur, no anti-alias mud, no seams.
(b) Silhouette readability: each icon distinguishable from the others at both
sizes. (c) Tactical Kernel angular/neon consistency: sharp polylines, accent
stroke on the dark PANEL fill, same stroke language as the combat HUD.
(d) Transparent-compatible alpha with no halo artifacts.

**Files.** `src/ui/tactical_icon.gd`, `src/ui/patch_card.gd`,
`src/ui/program_panel.gd`, harness; optionally `assets/icons/generated/` (raster
wins only) and a `media/concepts/` `.gitignore` entry.

**Verification.** Harness: every icon kind and every `PATCH_CODES` id resolves
to a non-empty drawing routine with documented minimum stroke (>= 1.5 UI,
>= 2.0 patch) and contrast (>= 0.55 vs PANEL) metrics; documented silhouette
bounds stay contained at 24px and 52px; any raster resolves only through the
registry with the code-drawn fallback intact. KP_SHOT captures of the menu and
arena at 1366x768 and 432x720 plus an interactive pause/patch-card check confirm
containment and readability at both sizes.

## Task 7c — Raster icon trial (generated textures behind the registries)

**Facts.** Task 7b shipped `raster_path(kind)` in `src/ui/tactical_icon.gd` and
`patch_raster_path(id)` in `src/ui/patch_card.gd` (both fall back to the code-drawn
drawing when no asset exists; only `patch_card._draw_icon` consumes a raster so far).
The orchestrator generated two trial sheets (gitignored, never committed):
`media/concepts/ui-icons-trial.png` (5x2 grid on pure black: play, restart, terminal,
warning, chevrons, speaker, music note, low-poly skull, shield keyhole, trophy
hexagon) and `media/concepts/patch-icons-trial.png` (3x2 grid: pierce hex magenta,
dot-grid hex amber, chevron hex cyan, shield hex lime, fire-up hex orange, magnet
hex cyan).

**Design.** Six steps, one commit:

1. Failing harness check: the `raster_path`/`patch_raster_path` registries resolve a
   loadable texture for every icon kind / patch id that has a generated asset, and
   return an empty path (code-drawn fallback) for every one that does not — both
   paths exercised.
2. Crop the two trial sheets into individual transparent-background PNGs with
   ImageMagick (black-keying + trim; 128px masters downscaled to 52px and 24px
   variants) into `assets/icons/generated/` — committed only in this task's commit
   if the author approves; the task ships them on a visible trial basis wired
   through the registries.
3. Wire the registries to the generated textures: give `tactical_icon.gd` `_draw()`
   the same raster-first branch `patch_card._draw_icon` already has, and land the
   PNGs at the registry names (`<kind>.png`, `patch_<id>.png`).
4. Side-by-side in-game captures (code-drawn vs raster) of the pause panel, settings
   rows, and patch selection at 1366x768 — saved to `/tmp/opencode/` for author
   review; captures are never committed.
5. Full autotest `AUTOTEST_ALL_PASS` with zero `AT_FAIL` — the registries must not
   break headless runs where textures may be absent.
6. Commit `feat: trial generated raster icons behind registry fallback`.

The final decision (ship raster vs revert to code-only) belongs to the author after
reviewing the captures; the follow-up commit (either keep or remove the PNGs) is
author-gated, separate, and not part of this task.

**Files.** `src/ui/tactical_icon.gd` (raster draw branch + registry comment),
`src/autoload/dev_harness.gd`; `assets/icons/generated/` (trial PNGs + `.import`
sidecars).

**Verification.** Harness: registry probes cover both paths (resolved texture for
shipped assets; empty path / code-drawn fallback for the rest); full autotest
`AUTOTEST_ALL_PASS` with zero `AT_FAIL`; side-by-side captures of pause, settings
rows, and patch selection exist in `/tmp/opencode/` for the author.

## Task 4b — Mobile combat HUD adaptation

**Verified problems.** From the author's mobile (touch, landscape) combat screenshot
plus code inspection:

1. Duplicate CYCLE display on wave start: the banner shows "CYCLE 03 / PURGE THE
   DAEMONS" (`arena.gd:853`, story variant `arena.gd:876`) while the persistent
   encounter panel directly above already shows "CYCLE 03 / PROCESS PURGE"
   (`tactical_ui.gd` layout "encounter" sits at the top on compact), so the two
   visually stack on mobile.
2. Keyboard hints visible on touch: `hud.gd` `_oc_bar()` appends "  READY [E]"
   (lines 476-477) regardless of input device; the dash charge fallback "[SHIFT]"
   (`hud.gd:568`) sits in `_dash_pip()`, which already returns early on touch
   (line 562) via the raw touchscreen check.
3. Empty desktop dash module on touch: the frame `_draw_angular_panel(dash_rect,
   ...)` (`hud.gd:423`) draws unconditionally while `_dash_icon` visibility already
   gates on touch (`hud.gd:310`) and `_dash_pip()` returns early, leaving an empty
   bottom-left panel next to the touch DASH button.
4. Patch dock collides with the touch DASH button: the "patches" rect
   (`tactical_ui.gd:51`, bottom-right up to 48% width) intersects the DASH button
   ring rect (`touch_controls.gd:101-103`) at 1366x768, 720x720, and 432x720.
5. Touch ring containment: BOOST (`touch_controls.gd:105-107`) and DASH rings must
   stay inside the safe area at the reference resolutions and touch scales.

**Design.** Layout/drawing only — touch input handling, button hit-area semantics,
and gameplay are unchanged; the existing `KP_FORCE_TOUCH` env pattern
(`arena.gd:133`, `menu.gd:52`) may force the touch presentation for harness tests.

- Banner: on compact layouts (`TacticalUI.layout` "compact" flag) `Hud.show_banner`
  hides the main line whenever a subtitle exists (wave banners keep only
  "PURGE THE DAEMONS"; subtitle-less hint banners keep their main line) and the
  subtitle animates at y=186, in the arena area below the compact encounter panel
  instead of hugging it. Desktop banner text and the y=120/172 geometry are
  unchanged; `arena.gd` call sites are untouched.
- Keyboard hints: a new `Hud.touch_layout()` gate
  (`DisplayServer.is_touchscreen_available() or KP_FORCE_TOUCH`) replaces the raw
  touchscreen checks in `_oc_bar` ("  READY" always, " [E]" only when not touch),
  `_dash_pip` (early return gains the shared gate; the "[SHIFT]" fallback renders
  only when not touch), and `_dash_icon` visibility.
- Dash module: the dash panel frame call site is skipped entirely when
  `touch_layout()`; the touch DASH button in `touch_controls.gd` is the mobile
  dash UI.
- Patch dock: `TacticalUI.layout` gains optional `touch` / `touch_scale` parameters
  (default off — every existing caller is unchanged). When touch, the "patches"
  rect is narrowed to end 12px left of the DASH button with a 120px readability
  floor, shifting leftward if needed so the rects never intersect.
  `Hud.layout_snapshot` passes the touch flag and `Sfx.touch_scale`, and
  `patch_dock_rects` routes through it, so chips reflow inside the shrunken dock.
- Ring containment: new pure helpers `TacticalUI.touch_dash_rect(viewport,
  touch_scale)` and `TacticalUI.touch_boost_rect(viewport, touch_scale)` mirror the
  `touch_controls.gd` button metrics (same formulas, one source for layout probes);
  touch_controls.gd itself stays read-only.

**Files.** `src/ui/tactical_ui.gd`, `src/ui/hud.gd`, `src/ui/touch_controls.gd`
(read-only metrics), harness.

**Verification.** Layout-only harness probes (`KP_FORCE_TOUCH` for the touch
flag): compact+touch `patches` rect and the touch DASH button rect never intersect
at 1366x768, 720x720, and 432x720 across touch scales 0.85/1.0/1.2; DASH/BOOST
rings stay enclosed in the viewport; `touch_controls` button rects equal the
shared helpers; detached-Hud probes prove `_banner_compact()` is true at
432x720/720x720 with a subtitle and false at 1366x768 or without one;
`KP_FORCE_TOUCH` flips `Hud.touch_layout()` and the forced snapshot's dock clears
the DASH button; the non-touch snapshot equals today's layout. KP_SHOT captures
at 720x720 and 432x720 with `KP_FORCE_TOUCH=1` show no empty dash panel, no
"[SHIFT]" text, the dock clear of the DASH ring, and unclipped rings; a visible
banner shows only the subtitle below the encounter panel.

## Safety and constraints

- TDD: write the harness regression check before each behavior change; run
  `godot --headless --path . -- --autotest` after every task and require
  `AUTOTEST_ALL_PASS` with zero `AT_FAIL`.
- Cosmetic/UI code never consumes `Game.rng`; gameplay randomness stays on
  `Game.rng` (intro dismiss hints, rainbow cycling, glyph animation time included).
- One-HP never gains heal sources; lock-on stays selectable in every mode;
  RECOVER/SECOND WIND-style saves stay excluded from One-HP.
- Mobile-first: touch behavior unchanged; any desktop-only convenience is gated by
  `Balance.is_desktop_display()`.
- Locked difficulty constants are never edited directly — multipliers at read
  points only. No controller support. No new binary assets beyond the Task 7b/7c
  trial icon rasters under `assets/icons/generated/`.
- Visual tasks are verified by running the game fullscreen/windowed with the
  `KP_SHOT` capture hook and comparing screenshots against the approved mocks
  (references live outside the repo and are never committed).

## Known test-adaptation risks

- Story tests that assume waves start immediately after scene load must be adapted
  to the intro-dismiss gate (spawn assertions wait for dismissal or auto-dismiss).
- Default NORMAL must keep all 792 existing autotest checks passing unchanged; the
  base Balance functions and locked constants are the guardrails for this.

## Decision Summary

- Story intro: measured/autowrapped text, input-to-dismiss with 0.8s minimum,
  "PRESS ANY KEY" hint, 8s safety auto-dismiss; story spawning gated on dismissal.
- Combat HUD panels become outline + faint fill (alpha ≤ 0.08); non-combat
  surfaces stay opaque.
- Era accent threaded into the HUD from all three `_era_color` sources; default
  CYAN keeps endless visuals identical where era color is CYAN.
- Mote pickup uses a swept segment test; OOM_KILLER re-resolves its steal target.
- Text overflow fixed system-wide via measurement helpers at three resolutions.
- Difficulty EASY/NORMAL/HARD for endless modes only, multipliers at read points,
  persisted as `game/difficulty`, NORMAL identical to today, weekly seed untouched.
- Shared code-drawn glyph library unifies enemy/program silhouettes across arena,
  bestiary, and program panel; gameplay visuals (hitboxes, telegraphs) unchanged.
- Achievements: code-drawn ACHIEVEMENTS panel in the menu secondary navigation
  (ScrollContainer body, X/Y header, hints) plus a harness guard that mid-run
  unlocks surface in the in-run HUD event log; persistence untouched.
- Icon quality pass across tactical icons and patch hex icons: orchestrator-driven
  imagegen concept sheets; rasters ship on proven same-size wins into
  `assets/icons/generated/` with the code-drawn icons as the permanent fallback —
  the identity is the neon geometric terminal style, not the drawing technique.
- Task 7c ships the generated icon rasters as a visible trial behind the registry
  fallback; keep-or-revert is author-gated after reviewing the side-by-side
  captures.
- Task 7c author ruling (2026-08-29): the neon geometric terminal STYLE is the
  identity; code-drawn was only the original technique.
- Task 7c author ruling (2026-08-29): hybrid contextual icons — UI icon glyphs are
  the clean frameless style; the angular corner-bracket frame (cross ticks) is
  drawn in code by tactical_icon as a conditional overlay ONLY where the placement
  has no existing frame (new placements), never where panel/button chrome already
  frames it (pause buttons, HUD panels, touch rings — no double framing); a
  `framed` parameter (default false) was added to tactical_icon's configure/draw
  path.
- Task 7c author ruling (2026-08-29): the generated-sprite trial for
  enemies/programs stays scheduled post-pack; entity glyphs are untouched.
- A generated-sprite trial for enemies/bosses/playable programs is approved and
  scheduled for a future session after this pack (do not implement now).

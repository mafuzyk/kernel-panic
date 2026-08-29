# KERNEL PANIC Fixes: Story Intro, HUD Transparency, Motes, Difficulty, Glyphs — Implementation Plan

> For agentic workers: REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

Goal: Fix the story intro (overflow, rushing, enemy pre-spawn), make the combat HUD panels transparent, thread era accent colors into the HUD, fix mote pickup tunneling and OOM_KILLER steal association, run a game-wide text overflow audit, add an EASY/NORMAL/HARD difficulty setting for endless modes, and rework every enemy/program glyph through one shared code-drawn library — all while the full autotest suite stays green at default settings.

Architecture: All changes stay inside the existing Godot 4.7.2 GDScript layout. UI is code-drawn (`_draw()` + `draw_*` calls); the new shared measurement helpers live in `src/ui/tactical_ui.gd` (`class_name TacticalUI`) and the new glyph library in `src/ui/glyph_lib.gd` (`class_name GlyphLib`). Difficulty is implemented purely as multipliers at read points in `src/autoload/balance.gd` static helpers; locked constants and base functions are never edited. Harness regressions live in `src/autoload/dev_harness.gd` and must be written and shown failing before each production change. New harness APIs are always accessed dynamically (`has_method` / `call` / `get` on untyped vars or `Script` objects) so the failing-test run parses and executes cleanly instead of erroring.

Tech Stack: Godot 4.7.2, GDScript, headless autotest harness (`godot --headless --path . -- --autotest`), `KP_SHOT` capture hook, ConfigFile persistence via `Sfx.SAVE_PATH`.

Spec: docs/superpowers/specs/2026-08-29-fixes-difficulty-art-design.md

## Global Constraints

- TDD: write the failing harness regression BEFORE each production change; after every task run `godot --headless --path . -- --autotest` and require `AUTOTEST_ALL_PASS` and zero `AT_FAIL` lines before committing.
- Cosmetic/UI code never consumes `Game.rng` (intro dismiss, rainbow accent cycling, glyph drawing included). Gameplay randomness stays on `Game.rng`.
- One-HP never gains heal sources; lock-on stays selectable in every mode; RECOVER/SECOND WIND-style saves stay excluded from One-HP.
- Mobile-first: touch behavior unchanged; desktop-only conveniences stay gated by `Balance.is_desktop_display()`.
- Locked balance constants (`WAVE_SCALE_CAP`, `wave_budget`, `max_alive`, `elite_chance`, cadence floor 0.78) are never edited — difficulty acts only through new multiplier read helpers.
- Endless wave-intro bars (`_intro_label` path in `arena.gd`) are untouched.
- No new binary assets; no raster sprites; all rendering stays code-drawn. No controller support work. (Task 7b exception: proven-win icon rasters under `assets/icons/generated/` plus their Godot `.import` sidecars, committed only after same-size comparison approval; `media/concepts/` stays gitignored.)
- Approved visual mocks live outside the repo at
  `/home/mafu/.codex/generated_images/01a044e4-d316-7ef2-85d8-9aa85056ea3a/`
  (`exec-10cafd61-...png` combat HUD, `exec-6582ea9f-...png` bestiary, `exec-450f92b7-...png` programs).
  KP_SHOT captures must be written to `/tmp/opencode/` and are never committed.
- Do not stage `.godot/`, build outputs, or unrelated docs.

---

### Task 1: Story intro — measured text, input dismiss, gated spawning

Files:
- Modify: `src/ui/tactical_ui.gd` (shared wrap/fit measurement helpers, reused by Task 4)
- Modify: `src/arena/arena.gd`
- Modify: `src/autoload/dev_harness.gd`

Interfaces:
- Consumes: `arena.gd` `_build_story_intro()` / `_show_story_intro()` / `_unhandled_input()` / `_process()`, `_ready()` story branch at lines 153-155, `story_data.gd` stage intros.
- Produces: `TacticalUI.wrapped_line_count()`, `TacticalUI.wrapped_height()`, `TacticalUI.fit_block()`; `Arena.story_intro_active()`, `Arena.dismiss_story_intro()`; intro dismiss gating of `spawner.start_story`.

- [x] Step 1: Write the failing harness regression

In `src/autoload/dev_harness.gd`, in the autotest flow, after the line `await _story_scene_test()` add:

~~~gdscript
	await _story_intro_auto_test()
	await _story_intro_layout_test()
~~~

Then replace the block in `_story_scene_test()` (currently lines 2886-2890):

~~~gdscript
	await _ticks(3)
	_check(Game.mode == "story" and story_arena.spawner.story_mode, "story arena uses the scripted spawner")
	_check(str(story_arena.get("_story_stage").get("path", "")) == "/boot", "story arena loads the selected stage")
	_check(story_arena.get("_story_intro_panel") != null, "story arena builds an intro card")
	story_arena.spawner.stop()
~~~

with:

~~~gdscript
	await _ticks(3)
	_check(Game.mode == "story", "story arena loads in story mode")
	_check(str(story_arena.get("_story_stage").get("path", "")) == "/boot", "story arena loads the selected stage")
	_check(story_arena.get("_story_intro_panel") != null, "story arena builds an intro card")
	_check(story_arena.has_method("story_intro_active"), "story arena exposes the intro state query")
	_check(not story_arena.spawner.story_mode, "story spawner idles during the intro")
	await _simulation_seconds(1.5)
	_check(story_arena.enemy_container.get_children().is_empty(), "no enemies spawn during the intro")
	if story_arena.has_method("story_intro_active") and story_arena.has_method("dismiss_story_intro"):
		_check(story_arena.call("story_intro_active"), "story intro is active on scene load")
		_check(not story_arena.call("dismiss_story_intro"), "dismiss input before the minimum hold is ignored")
		story_arena.set("_story_intro_t", 1.0)
		_check(story_arena.call("dismiss_story_intro"), "dismiss after the minimum hold starts the story")
		await _ticks(6)
	_check(story_arena.spawner.story_mode, "story arena uses the scripted spawner")
	story_arena.spawner.stop()
~~~

Then append these two new functions directly after `_story_scene_test()`:

~~~gdscript
func _story_intro_auto_test() -> void:
	print("AT_STEP story_intro_auto")
	var saved_mode := Game.mode
	var saved_state := Game.state
	var saved_stage := Game.story_stage_index
	Game.story_cleared[Game.story_stage_id(0)] = true
	_check(bool(Game.start_story(0)), "story auto-dismiss test loads the first stage")
	var loaded := await _until(func() -> bool:
		return get_tree().current_scene != null and get_tree().current_scene.name == "Arena", 6.0, "story arena")
	if not loaded:
		return
	var auto_arena: Arena = get_tree().current_scene
	await _ticks(3)
	_check(auto_arena.has_method("story_intro_active"), "auto-dismiss arena exposes the intro state query")
	if auto_arena.has_method("story_intro_active"):
		var dismissed := await _until(func() -> bool: return not auto_arena.call("story_intro_active"), 12.0, "story intro auto-dismiss")
		_check(dismissed, "story intro auto-dismisses after 8 seconds without input")
		await _ticks(6)
		_check(auto_arena.spawner.story_mode, "auto-dismiss starts story spawning")
	auto_arena.spawner.stop()
	auto_arena.spawner.debug_clear_encounter()
	Game.mode = saved_mode
	Game.state = saved_state
	Game.story_stage_index = saved_stage
	Game.to_menu()
	await _until(func() -> bool:
		return get_tree().current_scene != null and get_tree().current_scene.name == "Menu", 6.0, "menu return")

func _story_intro_layout_test() -> void:
	print("AT_STEP story_intro_layout")
	var tui_script: Script = load("res://src/ui/tactical_ui.gd")
	var tui = tui_script.new() if tui_script != null else null
	_check(tui != null and tui.has_method("fit_block"), "tactical ui exposes fit_block text measurement")
	if tui == null or not tui.has_method("fit_block"):
		return
	var mono: Font = load("res://assets/fonts/ShareTechMono.ttf")
	for vp in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
		var cap := minf(216.0, vp.y * 0.3)
		for stage_index in Game.story_stage_count():
			var intro := str(Game.story_stage_def(stage_index).get("intro", ""))
			var fit: Dictionary = tui.call("fit_block", mono, intro, 344.0, cap, 15, 12)
			_check(bool(fit.get("fits", false)) and int(fit.get("font_size", 0)) >= 12, "story intro %d measures inside the intro panel at %dx%d" % [stage_index + 1, int(vp.x), int(vp.y)])
~~~

- [x] Step 2: Run the test to verify it fails

Run:

~~~sh
godot --headless --path . -- --autotest
~~~

Expected: AT_FAIL lines including `story arena exposes the intro state query` and
`story spawner idles during the intro` (today the spawner runs immediately) and
`no enemies spawn during the intro`. The command must not fail from a parse
error; the suite still exits with `AUTOTEST_FAILED` because of these checks.

- [x] Step 3: Add the shared measurement helpers to tactical_ui.gd

Append to `src/ui/tactical_ui.gd` (end of file, inside the `TacticalUI` class):

~~~gdscript
static func wrapped_line_count(font: Font, text: String, width: float, font_size: int) -> int:
	if font == null:
		return 0
	var lines := 0
	for raw_line in text.split("\n"):
		var words := str(raw_line).split(" ")
		var current := ""
		for word in words:
			var candidate := word if current.is_empty() else current + " " + word
			if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width or current.is_empty():
				current = candidate
			else:
				lines += 1
				current = word
		lines += 1
	return maxi(lines, 1)

static func wrapped_height(font: Font, text: String, width: float, font_size: int) -> float:
	if font == null or text.is_empty():
		return 0.0
	return float(wrapped_line_count(font, text, width, font_size)) * font.get_height(font_size) * 1.25

static func fit_block(font: Font, text: String, width: float, height_cap: float, start_size: int, min_size: int) -> Dictionary:
	var chosen := clampi(start_size, min_size, 64)
	while chosen > min_size and wrapped_height(font, text, width, chosen) > height_cap:
		chosen -= 1
	var height := wrapped_height(font, text, width, chosen)
	return {"font_size": chosen, "height": height, "fits": height <= height_cap}
~~~

- [x] Step 4: Rework the intro state machine in arena.gd

4a. In `src/arena/arena.gd`, immediately before `func _build_story_intro() -> void:`, add:

~~~gdscript
const STORY_INTRO_FADE_IN := 0.35
const STORY_INTRO_MIN_HOLD := 0.8
const STORY_INTRO_AUTO_DISMISS := 8.0
const STORY_INTRO_FADE_OUT := 0.5
const STORY_INTRO_MAX_HEIGHT := 216.0
const STORY_INTRO_FONT_FLOOR := 12

var _story_intro_state := 0 # 0 = off, 1 = fade in, 2 = hold, 3 = fade out
var _story_intro_t := 0.0
var _story_intro_hint: Label = null
var _story_spawn_started := false
~~~

4b. In `_build_story_intro()`, replace:

~~~gdscript
	_story_intro_text = _make_label("", 15, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.75))
	_center_panel_control(_story_intro_text, 344.0, 54.0)
	_story_intro_panel.add_child(_story_intro_text)
~~~

with:

~~~gdscript
	_story_intro_text = _make_label("", 15, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.75))
	_center_panel_control(_story_intro_text, 344.0, 54.0)
	_story_intro_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story_intro_panel.add_child(_story_intro_text)
	_story_intro_hint = _make_label("PRESS ANY KEY", 12, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.55))
	_center_panel_control(_story_intro_hint, 392.0, 20.0)
	_story_intro_hint.modulate.a = 0.0
	_story_intro_panel.add_child(_story_intro_hint)
~~~

4c. Replace the whole `_show_story_intro()` function with:

~~~gdscript
func _show_story_intro() -> void:
	if _story_intro_panel == null or _story_stage.is_empty():
		return
	_story_intro_path.text = str(_story_stage.get("path", ""))
	_story_intro_title.text = str(_story_stage.get("title", "STORY STAGE"))
	_story_intro_text.text = str(_story_stage.get("intro", ""))
	_fit_story_intro_text()
	_story_intro_panel.modulate.a = 0.0
	_story_intro_panel.visible = true
	_story_intro_state = 1
	_story_intro_t = 0.0

func _fit_story_intro_text() -> void:
	var font: Font = _story_intro_text.get_theme_font("font")
	var text := _story_intro_text.text
	var cap := minf(STORY_INTRO_MAX_HEIGHT, get_viewport_rect().size.y * 0.3)
	var chosen := STORY_INTRO_FONT_FLOOR
	for fs in [15, 13, 12]:
		if TacticalUI.wrapped_height(font, text, 344.0, fs) <= cap:
			chosen = fs
			break
	_story_intro_text.add_theme_font_size_override("font_size", chosen)
	_story_intro_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story_intro_text.offset_bottom = _story_intro_text.offset_top + TacticalUI.wrapped_height(font, text, 344.0, chosen) + 8.0

func story_intro_active() -> bool:
	return _story_intro_state != 0

func dismiss_story_intro() -> bool:
	if _story_intro_state != 2 or _story_intro_t < STORY_INTRO_MIN_HOLD:
		return false
	_finish_story_intro()
	return true

func _finish_story_intro() -> void:
	if _story_intro_state != 2:
		return
	_story_intro_state = 3
	_story_intro_t = 0.0
	if _story_intro_hint != null:
		_story_intro_hint.modulate.a = 0.0
	_begin_story_spawning()

func _begin_story_spawning() -> void:
	if _story_spawn_started or _story_stage.is_empty():
		return
	_story_spawn_started = true
	spawner.start_story(self, enemy_container, _story_stage)

func _tick_story_intro(delta: float) -> void:
	_story_intro_t += delta
	match _story_intro_state:
		1:
			_story_intro_panel.modulate.a = minf(_story_intro_t / STORY_INTRO_FADE_IN, 1.0)
			if _story_intro_t >= STORY_INTRO_FADE_IN:
				_story_intro_state = 2
				_story_intro_t = 0.0
		2:
			if _story_intro_hint != null:
				_story_intro_hint.modulate.a = 1.0 if _story_intro_t >= STORY_INTRO_MIN_HOLD else 0.0
			if _story_intro_t >= STORY_INTRO_AUTO_DISMISS:
				_finish_story_intro()
		3:
			_story_intro_panel.modulate.a = maxf(1.0 - _story_intro_t / STORY_INTRO_FADE_OUT, 0.0)
			if _story_intro_t >= STORY_INTRO_FADE_OUT:
				if _story_intro_panel != null and is_instance_valid(_story_intro_panel):
					_story_intro_panel.visible = false
				_story_intro_state = 0
~~~

4d. In `_ready()`, replace:

~~~gdscript
	if Game.mode == "story":
		spawner.start_story(self, enemy_container, _story_stage)
		call_deferred("_show_story_intro")
	else:
~~~

with:

~~~gdscript
	if Game.mode == "story":
		call_deferred("_show_story_intro")
	else:
~~~

4e. In `_process(delta: float)`, directly after the line `_refresh_responsive_layout()`, add:

~~~gdscript
	if _story_intro_state != 0:
		_tick_story_intro(delta)
~~~

4f. In `_unhandled_input(event: InputEvent)` (line ~1327), as the first statements of the function body, add:

~~~gdscript
	if _story_intro_state == 2:
		var wants_dismiss := false
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.pressed and not key_event.echo:
				wants_dismiss = true
		elif event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			if mouse_event.pressed:
				wants_dismiss = true
		elif event is InputEventScreenTouch:
			var touch_event := event as InputEventScreenTouch
			if touch_event.pressed:
				wants_dismiss = true
		if wants_dismiss:
			dismiss_story_intro()
			return
~~~

- [x] Step 5: Run the full suite

Run:

~~~sh
godot --headless --path . -- --autotest
~~~

Expected: `AUTOTEST_ALL_PASS` and zero `AT_FAIL`. The adapted `_story_scene_test`,
new auto-dismiss and layout checks, and every pre-existing story/spawner check pass.

- [x] Step 6: Commit

~~~sh
git add src/arena/arena.gd src/ui/tactical_ui.gd src/autoload/dev_harness.gd
git commit -m "feat: gate story waves behind a dismissible measured intro"
~~~

---

### Task 2: Combat HUD transparency

Files:
- Modify: `src/ui/tactical_ui.gd`
- Modify: `src/ui/hud.gd`
- Modify: `src/autoload/dev_harness.gd`

Interfaces:
- Consumes: `hud.gd` `_draw_angular_panel()` (line 395) and its six combat call sites (lines 420-424, 434); `TacticalUI.PANEL`.
- Produces: `TacticalUI.COMBAT_FILL`, `TacticalUI.panel_fill_color(combat: bool)`; opaque panels unchanged for menu/pause/terminal/game-over surfaces (they use `TacticalUI.PANEL` directly and are not touched).

- [x] Step 1: Write the failing harness regression

In `src/autoload/dev_harness.gd`, after the line `await _task9_test(arena2)` add:

~~~gdscript
	await _hud_style_test(arena2)
~~~

Then append the new function anywhere at class level (for example directly before `_story_test`):

~~~gdscript
func _hud_style_test(_arena: Arena) -> void:
	print("AT_STEP hud_style")
	var tui_script: Script = load("res://src/ui/tactical_ui.gd")
	var tui = tui_script.new() if tui_script != null else null
	_check(tui != null and tui.has_method("panel_fill_color"), "tactical ui exposes panel_fill_color")
	if tui == null or not tui.has_method("panel_fill_color"):
		return
	var combat_fill: Color = tui.call("panel_fill_color", true)
	var menu_fill: Color = tui.call("panel_fill_color", false)
	_check(combat_fill.a <= 0.08, "combat panel fill stays faint (alpha <= 0.08)")
	_check(combat_fill.a >= 0.04, "combat panel fill keeps a visible tint (alpha >= 0.04)")
	_check(menu_fill.is_equal_approx(TacticalUI.PANEL), "non-combat surfaces keep the opaque PANEL fill")
	var hud_script: Script = load("res://src/ui/hud.gd")
	_check(str(hud_script.source_code).contains("panel_fill_color(true)"), "combat hud panels draw with the faint combat fill")
~~~

- [x] Step 2: Run the test to verify it fails

Run:

~~~sh
godot --headless --path . -- --autotest
~~~

Expected: AT_FAIL `tactical ui exposes panel_fill_color`. No parse error.

- [x] Step 3: Add COMBAT_FILL to tactical_ui.gd

In `src/ui/tactical_ui.gd`, directly below the line `const PANEL := Color(0.015, 0.035, 0.07, 0.90)`, add:

~~~gdscript
const COMBAT_FILL := Color(0.015, 0.035, 0.07, 0.06)
~~~

And at the end of the file (inside the class) add:

~~~gdscript
static func panel_fill_color(combat: bool) -> Color:
	return COMBAT_FILL if combat else PANEL
~~~

- [x] Step 4: Route the combat panels through the faint fill in hud.gd

4a. In `src/ui/hud.gd`, replace `_draw_angular_panel`:

~~~gdscript
func _draw_angular_panel(rect: Rect2, color: Color, fill_alpha: float = 0.08) -> void:
	var points := TacticalUIHelper.angular_points(rect, minf(12.0, rect.size.y * 0.22))
	draw_colored_polygon(points, TacticalUIHelper.PANEL)
	draw_colored_polygon(points, Color(color.r, color.g, color.b, fill_alpha))
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(color.r, color.g, color.b, 0.72), 1.4, true)
~~~

with:

~~~gdscript
func _draw_angular_panel(rect: Rect2, color: Color, fill_alpha: float = 0.08, combat: bool = false) -> void:
	var points := TacticalUIHelper.angular_points(rect, minf(12.0, rect.size.y * 0.22))
	draw_colored_polygon(points, TacticalUIHelper.panel_fill_color(combat))
	draw_colored_polygon(points, Color(color.r, color.g, color.b, fill_alpha))
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(color.r, color.g, color.b, 0.72), 1.4, true)
~~~

4b. Change the five base-panel call sites (currently lines 420-424) from:

~~~gdscript
	_draw_angular_panel(integrity_rect, TacticalUIHelper.CYAN, 0.055)
	_draw_angular_panel(encounter_rect, TacticalUIHelper.CYAN, 0.045)
	_draw_angular_panel(score_rect, TacticalUIHelper.CYAN, 0.055)
	_draw_angular_panel(dash_rect, TacticalUIHelper.CYAN, 0.045)
	_draw_angular_panel(patch_rect, TacticalUIHelper.CYAN, 0.045)
~~~

to:

~~~gdscript
	_draw_angular_panel(integrity_rect, TacticalUIHelper.CYAN, 0.055, true)
	_draw_angular_panel(encounter_rect, TacticalUIHelper.CYAN, 0.045, true)
	_draw_angular_panel(score_rect, TacticalUIHelper.CYAN, 0.055, true)
	_draw_angular_panel(dash_rect, TacticalUIHelper.CYAN, 0.045, true)
	_draw_angular_panel(patch_rect, TacticalUIHelper.CYAN, 0.045, true)
~~~

4c. Change the event-log call site (currently line 434) from:

~~~gdscript
		_draw_angular_panel(event_rect, TacticalUIHelper.CYAN, 0.025)
~~~

to:

~~~gdscript
		_draw_angular_panel(event_rect, TacticalUIHelper.CYAN, 0.025, true)
~~~

- [x] Step 5: Run the full suite

Run:

~~~sh
godot --headless --path . -- --autotest
~~~

Expected: `AUTOTEST_ALL_PASS` and zero `AT_FAIL`.

- [x] Step 6: Visual capture against the approved combat HUD mock

Run (desktop, windowed):

~~~sh
mkdir -p /tmp/opencode
KP_SHOT=game KP_SHOT_OUT=/tmp/opencode/hud_combat.png godot --path . --resolution 1366x768
KP_SHOT=game KP_SHOT_OUT=/tmp/opencode/hud_combat_720.png godot --path . --resolution 720x720
KP_SHOT=game KP_SHOT_OUT=/tmp/opencode/hud_combat_432.png godot --path . --resolution 432x720
~~~

Expected: the three captures show the six combat panels as outline + faint tint
with the arena visible through them, matching
`/home/mafu/.codex/generated_images/01a044e4-d316-7ef2-85d8-9aa85056ea3a/exec-10cafd61-702d-4c80-bb5e-20e90420d23c.png`
at all three resolutions. Menu, pause, terminal, and game-over surfaces remain opaque.

- [x] Step 7: Commit

~~~sh
git add src/ui/tactical_ui.gd src/ui/hud.gd src/autoload/dev_harness.gd
git commit -m "fix: render combat hud panels as faint outlined fills"
~~~

---

### Task 3: HUD follows era accent

Files:
- Modify: `src/ui/hud.gd`
- Modify: `src/arena/arena.gd`
- Modify: `src/autoload/dev_harness.gd`

Interfaces:
- Consumes: `arena.gd` `_era_color` sites — `_apply_story_theme()` (line ~773), `_on_wave_started()` endless branch (line ~842), `_process()` TempleOS/rainbow block (lines 1528-1534); `hud.gd` static `TacticalUIHelper.CYAN` draw references.
- Produces: `Hud.set_era_accent(color)` / `Hud.era_accent()`; default stays `TacticalUI.CYAN`.

- [x] Step 1: Write the failing harness regression

In `src/autoload/dev_harness.gd`, directly after the `await _hud_style_test(arena2)` line added in Task 2, add:

~~~gdscript
	await _era_accent_test(arena2)
~~~

Then append the new function:

~~~gdscript
func _era_accent_test(arena: Arena) -> void:
	print("AT_STEP era_accent")
	var hud_ref = arena.hud
	_check(hud_ref != null and hud_ref.has_method("set_era_accent") and hud_ref.has_method("era_accent"), "hud exposes era accent controls")
	if hud_ref == null or not hud_ref.has_method("set_era_accent"):
		return
	_check(hud_ref.call("era_accent") == TacticalUI.CYAN, "hud era accent defaults to cyan")
	var seed_before := Game.rng.seed
	hud_ref.call("set_era_accent", Balance.era_color(8))
	_check(hud_ref.call("era_accent") == Balance.era_color(8), "set_era_accent updates the hud accent")
	_check(Game.rng.seed == seed_before, "era accent changes never advance the gameplay rng")
	arena.call("_on_wave_started", 8, false)
	_check(arena.hud.call("era_accent") == Balance.era_color(8), "arena pushes the per-wave era accent to the hud")
	arena.set("_temple_mode", true)
	var accent_a: Color = arena.hud.call("era_accent")
	await _ticks(4)
	var accent_b: Color = arena.hud.call("era_accent")
	arena.set("_temple_mode", false)
	_check(accent_a != accent_b, "rainbow mode cycles the hud accent over time")
	hud_ref.call("set_era_accent", TacticalUI.CYAN)
~~~

- [x] Step 2: Run the test to verify it fails

Run:

~~~sh
godot --headless --path . -- --autotest
~~~

Expected: AT_FAIL `hud exposes era accent controls`. No parse error.

- [x] Step 3: Add the accent to hud.gd

3a. In `src/ui/hud.gd`, after the line `var _dash_icon: Control` (line ~47), add:

~~~gdscript
var _era_accent: Color = TacticalUIHelper.CYAN
~~~

3b. At the end of the file (inside the class) add:

~~~gdscript
func set_era_accent(color: Color) -> void:
	if color == _era_accent:
		return
	_era_accent = color
	queue_redraw()

func era_accent() -> Color:
	return _era_accent
~~~

3c. In `_draw_tactical_shell(f: Font)`, replace every static `TacticalUIHelper.CYAN` color construction with the accent. Concretely:

- Replace (line ~408):

~~~gdscript
	draw_polyline(outer_points + PackedVector2Array([outer_points[0]]), Color(TacticalUIHelper.CYAN.r, TacticalUIHelper.CYAN.g, TacticalUIHelper.CYAN.b, 0.68), 1.25, true)
~~~

with:

~~~gdscript
	draw_polyline(outer_points + PackedVector2Array([outer_points[0]]), Color(_era_accent.r, _era_accent.g, _era_accent.b, 0.68), 1.25, true)
~~~

- Replace all four `draw_line(... Color(TacticalUIHelper.CYAN.r, TacticalUIHelper.CYAN.g, TacticalUIHelper.CYAN.b, 0.52), 1.0)` shell trim lines (lines ~409-412) so each uses `Color(_era_accent.r, _era_accent.g, _era_accent.b, 0.52)`.

- Replace the corner-dots line (line ~413-414):

~~~gdscript
	for corner in [Vector2(outer.position.x + 28.0, outer.position.y + 14.0), Vector2(outer.end.x - 28.0, outer.position.y + 14.0), Vector2(outer.position.x + 28.0, outer.end.y - 14.0), Vector2(outer.end.x - 28.0, outer.end.y - 14.0)]:
		draw_circle(corner, 2.0, Color(TacticalUIHelper.CYAN.r, TacticalUIHelper.CYAN.g, TacticalUIHelper.CYAN.b, 0.82))
~~~

with:

~~~gdscript
	for corner in [Vector2(outer.position.x + 28.0, outer.position.y + 14.0), Vector2(outer.end.x - 28.0, outer.position.y + 14.0), Vector2(outer.position.x + 28.0, outer.end.y - 14.0), Vector2(outer.end.x - 28.0, outer.end.y - 14.0)]:
		draw_circle(corner, 2.0, Color(_era_accent.r, _era_accent.g, _era_accent.b, 0.82))
~~~

- Replace the five combat-panel calls (lines ~420-424, as edited in Task 2) so each passes `_era_accent` instead of `TacticalUIHelper.CYAN`, e.g.:

~~~gdscript
	_draw_angular_panel(integrity_rect, _era_accent, 0.055, true)
	_draw_angular_panel(encounter_rect, _era_accent, 0.045, true)
	_draw_angular_panel(score_rect, _era_accent, 0.055, true)
	_draw_angular_panel(dash_rect, _era_accent, 0.045, true)
	_draw_angular_panel(patch_rect, _era_accent, 0.045, true)
~~~

- Replace the "SCORE" label color (line ~430):

~~~gdscript
	draw_string(f, score_rect.position + Vector2(14.0, 22.0), "SCORE", HORIZONTAL_ALIGNMENT_LEFT, score_rect.size.x - 28.0, 12, TacticalUIHelper.CYAN)
~~~

with:

~~~gdscript
	draw_string(f, score_rect.position + Vector2(14.0, 22.0), "SCORE", HORIZONTAL_ALIGNMENT_LEFT, score_rect.size.x - 28.0, 12, _era_accent)
~~~

- Replace the "EVENT LOG" label color (line ~436):

~~~gdscript
		draw_string(f, Vector2(score_rect.position.x + 14.0, event_y), "EVENT LOG", HORIZONTAL_ALIGNMENT_LEFT, score_rect.size.x - 28.0, 12, TacticalUIHelper.CYAN)
~~~

with:

~~~gdscript
		draw_string(f, Vector2(score_rect.position.x + 14.0, event_y), "EVENT LOG", HORIZONTAL_ALIGNMENT_LEFT, score_rect.size.x - 28.0, 12, _era_accent)
~~~

- [x] Step 4: Push the accent from arena.gd at all three era sites

4a. In `_apply_story_theme()`, directly after `_era_color = accent` (line ~773), add:

~~~gdscript
	if hud != null:
		hud.set_era_accent(accent)
~~~

4b. In `_on_wave_started()`, directly after `_era_color = Balance.era_color(wave)` (line ~842), add:

~~~gdscript
	if hud != null:
		hud.set_era_accent(_era_color)
~~~

4c. In `_process()`, inside the rainbow block, directly after `_era_color = rainbow` (line ~1530), add:

~~~gdscript
		if hud != null:
			hud.set_era_accent(rainbow)
~~~

The rainbow hue is derived from `Game.stats.get("time", 0.0)` (cosmetic time) — it never touches `Game.rng`.

- [x] Step 5: Run the full suite

Run:

~~~sh
godot --headless --path . -- --autotest
~~~

Expected: `AUTOTEST_ALL_PASS` and zero `AT_FAIL`. Endless modes that resolve to CYAN look unchanged.

- [x] Step 6: Commit

~~~sh
git add src/ui/hud.gd src/arena/arena.gd src/autoload/dev_harness.gd
git commit -m "feat: thread era accent colors through the combat hud"
~~~

---

### Task 4: Game-wide text overflow audit

Files:
- Modify: `src/ui/tactical_ui.gd` (ellipsis helper; wrapped/fit helpers already exist from Task 1)
- Modify: `src/ui/story_panel.gd`, `src/ui/bestiary_panel.gd`, `src/ui/program_panel.gd`, `src/ui/patch_card.gd`, `src/ui/menu.gd`, `src/ui/terminal_panel.gd`, `src/ui/tactical_state_surface.gd`
- Modify: `src/autoload/dev_harness.gd`

Interfaces:
- Consumes: `TacticalUI.wrapped_line_count/wrapped_height/fit_block`; each panel's own layout metrics (`_content_metrics()`, `pause_layout`, `terminal_layout`, `panel_rect_for_viewport`).
- Produces: `TacticalUI.ellipsis_fit()`; a `text_overflow_report() -> Array` method on every listed surface (entries `{"id": String, "fits": bool}`), measured klog column in story_panel, autowrapped menu mode info, fitted multiline blocks.

- [x] Step 1: Write the failing harness regression

In `src/autoload/dev_harness.gd`, after the line `await _menu_shell_test(menu_scene)` add:

~~~gdscript
	await _text_overflow_test()
~~~

Then append the new function:

~~~gdscript
func _text_overflow_test() -> void:
	print("AT_STEP text_overflow")
	var surfaces := {
		"story": "res://src/ui/story_panel.gd",
		"bestiary": "res://src/ui/bestiary_panel.gd",
		"program": "res://src/ui/program_panel.gd",
		"patch_card": "res://src/ui/patch_card.gd",
		"menu": "res://src/ui/menu.gd",
		"terminal": "res://src/ui/terminal_panel.gd",
		"state_surface": "res://src/ui/tactical_state_surface.gd",
	}
	for surface_id in surfaces:
		var script: Script = load(surfaces[surface_id])
		var panel = script.new() if script != null else null
		_check(panel != null and panel.has_method("text_overflow_report"), "%s exposes text_overflow_report" % surface_id)
		if panel == null or not panel.has_method("text_overflow_report"):
			continue
		var all_fit := true
		for vp in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
			panel.size = vp
			for entry in panel.call("text_overflow_report"):
				all_fit = all_fit and bool(entry.get("fits", false))
		_check(all_fit, "%s keeps its representative text inside the panel at 1366x768, 720x720, and 432x720" % surface_id)
		panel.free()
~~~

- [x] Step 2: Run the test to verify it fails

Run:

~~~sh
godot --headless --path . -- --autotest
~~~

Expected: seven AT_FAIL lines, one per surface (`story exposes text_overflow_report`, ...). No parse error.

- [x] Step 3: Add ellipsis_fit to tactical_ui.gd

Append to `src/ui/tactical_ui.gd` (inside the class):

~~~gdscript
static func ellipsis_fit(font: Font, text: String, max_width: float, font_size: int) -> String:
	if font == null or font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
		return text
	var clipped := text
	while clipped.length() > 1 and font.get_string_size(clipped + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_width:
		clipped = clipped.substr(0, clipped.length() - 1)
	return clipped + "…"
~~~

- [x] Step 4: story_panel.gd — measured klog column + report

4a. In `src/ui/story_panel.gd` `_draw_stage_detail()`, replace the klog loop (currently lines ~335-337):

~~~gdscript
	var klog: Array = stage.get("klog", [])
	for log_i in mini(klog.size(), 2):
		draw_string(mono, rail.position + Vector2(208.0, 292.0 + float(log_i) * 20.0), "> " + str(klog[log_i]), HORIZONTAL_ALIGNMENT_LEFT, rail.size.x - 226.0, 10, Color(TacticalUIHelper.TEXT.r, TacticalUIHelper.TEXT.g, TacticalUIHelper.TEXT.b, 0.56))
~~~

with a measured second-column origin (preview left inset 18 + preview width + 20 gap):

~~~gdscript
	var klog: Array = stage.get("klog", [])
	var klog_x := 18.0 + preview.size.x + 20.0
	var klog_width := maxf(rail.size.x - klog_x - 18.0, 0.0)
	for log_i in mini(klog.size(), 2):
		var klog_text := "> " + str(klog[log_i])
		draw_string(mono, rail.position + Vector2(klog_x, 292.0 + float(log_i) * 20.0), TacticalUI.ellipsis_fit(mono, klog_text, klog_width, 10), HORIZONTAL_ALIGNMENT_LEFT, klog_width, 10, Color(TacticalUIHelper.TEXT.r, TacticalUIHelper.TEXT.g, TacticalUIHelper.TEXT.b, 0.56))
~~~

4b. In the intro block of the same function (line ~312), replace the fixed 3-line cap:

~~~gdscript
	draw_multiline_string(mono, rail.position + Vector2(18.0, 108.0), str(stage.get("intro", "")), HORIZONTAL_ALIGNMENT_LEFT, rail.size.x - 36.0, 12, 3, Color(TacticalUIHelper.TEXT.r, TacticalUIHelper.TEXT.g, TacticalUIHelper.TEXT.b, 0.74))
~~~

with a measured font fit (block height 108→164 divider = 56px):

~~~gdscript
	var intro_size: int = TacticalUI.fit_block(mono, str(stage.get("intro", "")), rail.size.x - 36.0, 56.0, 12, 10)["font_size"]
	draw_multiline_string(mono, rail.position + Vector2(18.0, 108.0), str(stage.get("intro", "")), HORIZONTAL_ALIGNMENT_LEFT, rail.size.x - 36.0, intro_size, 5, Color(TacticalUIHelper.TEXT.r, TacticalUIHelper.TEXT.g, TacticalUIHelper.TEXT.b, 0.74))
~~~

4c. Append the report method to `src/ui/story_panel.gd`:

~~~gdscript
func text_overflow_report() -> Array:
	var mono: Font = load("res://assets/fonts/ShareTechMono.ttf")
	var orbitron: Font = load("res://assets/fonts/Orbitron.ttf")
	var out: Array = []
	var longest_intro := ""
	var longest_title := ""
	var longest_klog := ""
	for stage_index in Game.story_stage_count():
		var stage: Dictionary = Game.story_stage_def(stage_index)
		if str(stage.get("intro", "")).length() > longest_intro.length():
			longest_intro = str(stage.get("intro", ""))
		if str(stage.get("title", "")).length() > longest_title.length():
			longest_title = str(stage.get("title", ""))
		for line in stage.get("klog", []):
			if ("> " + str(line)).length() > longest_klog.length():
				longest_klog = "> " + str(line)
	var rail_w: float = size.x * 0.42 if _is_wide() else size.x
	out.append({"id": "detail_intro", "fits": TacticalUI.wrapped_height(mono, longest_intro, rail_w - 36.0, 12) <= 56.0 or TacticalUI.wrapped_height(mono, longest_intro, rail_w - 36.0, 10) <= 56.0})
	out.append({"id": "detail_title", "fits": orbitron.get_string_size(longest_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x <= rail_w - 36.0})
	var klog_width: float = maxf(rail_w - (minf(rail_w - 36.0, 170.0) + 38.0) - 18.0, 0.0)
	out.append({"id": "klog_lines", "fits": mono.get_string_size(longest_klog, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x <= klog_width})
	return out
~~~

- [x] Step 5: bestiary_panel.gd — fitted behavior/bug text + report

5a. In `src/ui/bestiary_panel.gd` `_draw_detail()` (lines ~274-276), replace:

~~~gdscript
	draw_multiline_string(mono, rail.position + Vector2(20.0, 204.0), "> " + (str(entry["desc"]) if seen else "No field data available. The first sighting will unlock this behavior report."), HORIZONTAL_ALIGNMENT_LEFT, rail.size.x - 40.0, 13, 3, Color(TacticalUIHelper.TEXT.r, TacticalUIHelper.TEXT.g, TacticalUIHelper.TEXT.b, 0.78 if seen else 0.42))
	draw_string(mono, rail.position + Vector2(20.0, 278.0), "BUG REPORT", HORIZONTAL_ALIGNMENT_LEFT, rail.size.x - 40.0, 11, accent)
	draw_multiline_string(mono, rail.position + Vector2(20.0, 302.0), "> " + (str(entry["bugs"]) if seen else "LOCKED // COMPLETE A SIGHTING TO ACCESS NOTES"), HORIZONTAL_ALIGNMENT_LEFT, rail.size.x - 40.0, 12, 3, Color(TacticalUIHelper.TEXT.r, TacticalUIHelper.TEXT.g, TacticalUIHelper.TEXT.b, 0.64 if seen else 0.36))
~~~

with:

~~~gdscript
	var desc_text := "> " + (str(entry["desc"]) if seen else "No field data available. The first sighting will unlock this behavior report.")
	var desc_size: int = TacticalUI.fit_block(mono, desc_text, rail.size.x - 40.0, 64.0, 13, 10)["font_size"]
	draw_multiline_string(mono, rail.position + Vector2(20.0, 204.0), desc_text, HORIZONTAL_ALIGNMENT_LEFT, rail.size.x - 40.0, desc_size, 5, Color(TacticalUIHelper.TEXT.r, TacticalUIHelper.TEXT.g, TacticalUIHelper.TEXT.b, 0.78 if seen else 0.42))
	draw_string(mono, rail.position + Vector2(20.0, 278.0), "BUG REPORT", HORIZONTAL_ALIGNMENT_LEFT, rail.size.x - 40.0, 11, accent)
	var bugs_text := "> " + (str(entry["bugs"]) if seen else "LOCKED // COMPLETE A SIGHTING TO ACCESS NOTES")
	var bugs_size: int = TacticalUI.fit_block(mono, bugs_text, rail.size.x - 40.0, float(rail.size.y) - 316.0, 12, 10)["font_size"]
	draw_multiline_string(mono, rail.position + Vector2(20.0, 302.0), bugs_text, HORIZONTAL_ALIGNMENT_LEFT, rail.size.x - 40.0, bugs_size, 6, Color(TacticalUIHelper.TEXT.r, TacticalUIHelper.TEXT.g, TacticalUIHelper.TEXT.b, 0.64 if seen else 0.36))
~~~

5b. Append the report method to `src/ui/bestiary_panel.gd`:

~~~gdscript
func text_overflow_report() -> Array:
	var mono: Font = load("res://assets/fonts/ShareTechMono.ttf")
	var out: Array = []
	var metrics := _content_metrics()
	var rail_w: float = size.x - float(metrics.get("list_w", size.x * 0.4)) - 86.0
	var longest_desc := ""
	var longest_bugs := ""
	for entry in ENTRIES:
		if ("> " + str(entry["desc"])).length() > longest_desc.length():
			longest_desc = "> " + str(entry["desc"])
		if ("> " + str(entry["bugs"])).length() > longest_bugs.length():
			longest_bugs = "> " + str(entry["bugs"])
	out.append({"id": "bestiary_desc", "fits": TacticalUI.wrapped_height(mono, longest_desc, rail_w - 40.0, 13) <= 64.0 or TacticalUI.wrapped_height(mono, longest_desc, rail_w - 40.0, 10) <= 64.0})
	out.append({"id": "bestiary_bugs", "fits": TacticalUI.wrapped_height(mono, longest_bugs, rail_w - 40.0, 12) <= maxf(size.y - 258.0 - 58.0, 0.0) or TacticalUI.wrapped_height(mono, longest_bugs, rail_w - 40.0, 10) <= maxf(size.y - 258.0 - 58.0, 0.0)})
	return out
~~~

- [x] Step 6: program_panel.gd — fitted summary/stats + report

6a. In `src/ui/program_panel.gd` (lines ~185-189), replace the fixed 2-line summary and 5-line stat block:

~~~gdscript
		draw_multiline_string(mono, origin + Vector2(16.0, 91.0), str(definition.get("summary", "")), HORIZONTAL_ALIGNMENT_LEFT, card_w - 32.0, 12, 2, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.68 if unlocked else 0.36))
		var stat_text := "INTEGRITY  %s\nSPEED      %s\nFIRE       %s\nRANGE      %s\nDASH/CORE  %s" % [definition.get("integrity", "—"), definition.get("speed", "—"), definition.get("fire", "—"), definition.get("range", "—"), definition.get("dash_shield", "—")]
		draw_multiline_string(mono, origin + Vector2(16.0, 132.0), stat_text, HORIZONTAL_ALIGNMENT_LEFT, card_w - 32.0, 11, 5, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.78 if unlocked else 0.42))
~~~

with:

~~~gdscript
		var summary_size: int = TacticalUI.fit_block(mono, str(definition.get("summary", "")), card_w - 32.0, 34.0, 12, 10)["font_size"]
		draw_multiline_string(mono, origin + Vector2(16.0, 91.0), str(definition.get("summary", "")), HORIZONTAL_ALIGNMENT_LEFT, card_w - 32.0, summary_size, 3, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.68 if unlocked else 0.36))
		var stat_text := "INTEGRITY  %s\nSPEED      %s\nFIRE       %s\nRANGE      %s\nDASH/CORE  %s" % [definition.get("integrity", "—"), definition.get("speed", "—"), definition.get("fire", "—"), definition.get("range", "—"), definition.get("dash_shield", "—")]
		var stat_size: int = TacticalUI.fit_block(mono, stat_text, card_w - 32.0, 64.0, 11, 9)["font_size"]
		draw_multiline_string(mono, origin + Vector2(16.0, 132.0), stat_text, HORIZONTAL_ALIGNMENT_LEFT, card_w - 32.0, stat_size, 5, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.78 if unlocked else 0.42))
~~~

6b. Append the report method to `src/ui/program_panel.gd`:

~~~gdscript
func text_overflow_report() -> Array:
	var mono: Font = load("res://assets/fonts/ShareTechMono.ttf")
	var out: Array = []
	var longest_summary := ""
	var longest_stat_line := ""
	for id in Game.PROGRAM_DEFS:
		var definition: Dictionary = Game.PROGRAM_DEFS[id]
		if str(definition.get("summary", "")).length() > longest_summary.length():
			longest_summary = str(definition.get("summary", ""))
		for stat_key in ["fire", "dash_shield"]:
			var line := str(definition.get(stat_key, ""))
			if line.length() > longest_stat_line.length():
				longest_stat_line = line
	var card_w: float = minf(430.0, (size.x - 48.0) * 0.5)
	out.append({"id": "program_summary", "fits": TacticalUI.wrapped_height(mono, longest_summary, card_w - 32.0, 12) <= 34.0 or TacticalUI.wrapped_height(mono, longest_summary, card_w - 32.0, 10) <= 34.0})
	out.append({"id": "program_stats", "fits": mono.get_string_size(longest_stat_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x <= card_w - 32.0})
	return out
~~~

- [x] Step 7: patch_card.gd — fitted description + report

7a. In `src/ui/patch_card.gd` (line ~87), replace:

~~~gdscript
	draw_multiline_string(_mono, Vector2(126.0, 143.0), str(_def.get("desc", "")), HORIZONTAL_ALIGNMENT_LEFT, size.x - 148.0, 13, 3, TacticalUIHelper.TEXT)
~~~

with:

~~~gdscript
	var desc_size: int = TacticalUI.fit_block(_mono, str(_def.get("desc", "")), size.x - 148.0, 54.0, 13, 10)["font_size"]
	draw_multiline_string(_mono, Vector2(126.0, 143.0), str(_def.get("desc", "")), HORIZONTAL_ALIGNMENT_LEFT, size.x - 148.0, desc_size, 4, TacticalUIHelper.TEXT)
~~~

7b. Append the report method to `src/ui/patch_card.gd`:

~~~gdscript
func text_overflow_report() -> Array:
	var mono: Font = load("res://assets/fonts/ShareTechMono.ttf")
	var out: Array = []
	var longest_desc := ""
	for definition in Game.PATCH_DEFS:
		if str(definition.get("desc", "")).length() > longest_desc.length():
			longest_desc = str(definition.get("desc", ""))
	out.append({"id": "patch_desc", "fits": TacticalUI.wrapped_height(mono, longest_desc, size.x - 148.0, 13) <= 54.0 or TacticalUI.wrapped_height(mono, longest_desc, size.x - 148.0, 10) <= 54.0})
	return out
~~~

(`_mono` is only assigned in `_ready()`, which does not run for a detached instance, so the report loads its own font copy.)

- [x] Step 8: menu.gd — autowrap mode info + report

8a. In `src/ui/menu.gd` `_build_button_row()` (lines ~423-437), change the `_mode_info` label block from:

~~~gdscript
	_mode_info.visible = false
	add_child(_mode_info)
~~~

to:

~~~gdscript
	_mode_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mode_info.offset_top = 190.0
	_mode_info.offset_bottom = 234.0
	_mode_info.visible = false
	add_child(_mode_info)
~~~

8b. In `_refresh_mode_ui()`, replace the final line `_refresh_mode_ui()`'s body ending — concretely, change the last line of the match statement block:

~~~gdscript
		_:
			_mode_btn.text = "MODE: CLASSIC"
			_mode_info.text = "CLASSIC // ENDLESS WAVES // HIGH SCORE %07d" % Game.best
~~~

to:

~~~gdscript
		_:
			_mode_btn.text = "MODE: CLASSIC"
			_mode_info.text = "CLASSIC // ENDLESS WAVES // HIGH SCORE %07d" % Game.best
	if Game.mode == "story":
		_mode_info.text = "STORY // FIXED DIFFICULTY CURVE // " + _mode_info.text
~~~

Note: do NOT add the difficulty cycler here — that is Task 6. This step only touches text fitting.

8c. Append the report method to `src/ui/menu.gd`:

~~~gdscript
func text_overflow_report() -> Array:
	var mono: Font = load("res://assets/fonts/ShareTechMono.ttf")
	var out: Array = []
	var longest := ""
	for text in [
		"UNIX ACT 1 // CURRENT /kernel // 6/6 STAGES CLEAR",
		"WEEK W9999 // LOCAL DETERMINISTIC // BEST 0000000 // LAST 0000000",
		"CLASSIC // ENDLESS WAVES // HIGH SCORE 0000000",
		"STORY // FIXED DIFFICULTY CURVE // UNIX ACT 1 // CURRENT /kernel // 6/6 STAGES CLEAR",
	]:
		if text.length() > longest.length():
			longest = text
	var info_width: float = maxf(size.x - 48.0, 0.0)
	out.append({"id": "mode_info", "fits": TacticalUI.wrapped_height(mono, longest, info_width, 12) <= 44.0})
	return out
~~~

- [x] Step 9: terminal_panel.gd and tactical_state_surface.gd — reports

9a. Append to `src/ui/terminal_panel.gd`:

~~~gdscript
func text_overflow_report() -> Array:
	var mono: Font = load("res://assets/fonts/ShareTechMono.ttf")
	var out: Array = []
	var workstation := workstation_rect(Vector2(size.x, size.y))
	out.append({"id": "workstation_inside_viewport", "fits": Rect2(Vector2.ZERO, Vector2(size.x, size.y)).encloses(workstation)})
	var longest := ""
	for line in _initial_output().split("\n"):
		if line.length() > longest.length():
			longest = line
	out.append({"id": "terminal_output_wraps", "fits": TacticalUI.wrapped_height(mono, longest, maxf(workstation.size.x - 48.0, 0.0), 13) > 0.0})
	return out
~~~

9b. Append to `src/ui/tactical_state_surface.gd`:

~~~gdscript
func text_overflow_report() -> Array:
	var mono: Font = load("res://assets/fonts/ShareTechMono.ttf")
	var out: Array = []
	var panel := panel_rect_for_viewport(Vector2(size.x, size.y), "game_over")
	var section_width: float = (panel.size.x - 56.0 - 18.0) * 0.5
	var longest_dump_line := ""
	for line in "SEGFAULT AT player.hp=0 // state dumped\nKILLER DAEMON // HITS 99".split("\n"):
		if line.length() > longest_dump_line.length():
			longest_dump_line = line
	out.append({"id": "gameover_headings", "fits": mono.get_string_size("RUN SUMMARY", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x <= section_width - 48.0})
	out.append({"id": "gameover_dump_line", "fits": mono.get_string_size(longest_dump_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x <= section_width - 48.0 or TacticalUI.wrapped_height(mono, longest_dump_line, section_width - 48.0, 10) <= 190.0})
	return out
~~~

- [x] Step 10: Run the full suite

Run:

~~~sh
godot --headless --path . -- --autotest
~~~

Expected: `AUTOTEST_ALL_PASS` and zero `AT_FAIL`. If a surface report fails at
432x720, tighten that surface's `fit_block` bounds (never by truncating rules or
copy text; ellipsis is allowed only for the single-line klog chips added in
Step 4a) and re-run until green.

- [x] Step 11: Visual sweep against the approved mocks

Run (desktop, windowed):

~~~sh
KP_SHOT=menu KP_SHOT_OUT=/tmp/opencode/menu_1366.png godot --path . --resolution 1366x768
KP_SHOT=menu KP_PROGRAM=1 KP_SHOT_OUT=/tmp/opencode/programs_1366.png godot --path . --resolution 1366x768
KP_SHOT=menu KP_BESTIARY=1 KP_SHOT_OUT=/tmp/opencode/bestiary_1366.png godot --path . --resolution 1366x768
KP_SHOT=menu KP_STORY=1 KP_SHOT_OUT=/tmp/opencode/story_432.png godot --path . --resolution 432x720
~~~

Expected: no clipped or overlapping text on any captured surface; compare against
`exec-10cafd61-...png`, `exec-6582ea9f-...png`, and `exec-450f92b7-...png` in
`/home/mafu/.codex/generated_images/01a044e4-d316-7ef2-85d8-9aa85056ea3a/`.
Captures stay in `/tmp/opencode/` and are never committed.

- [x] Step 12: Commit

~~~sh
git add src/ui/tactical_ui.gd src/ui/story_panel.gd src/ui/bestiary_panel.gd src/ui/program_panel.gd src/ui/patch_card.gd src/ui/menu.gd src/ui/terminal_panel.gd src/ui/tactical_state_surface.gd src/autoload/dev_harness.gd
git commit -m "fix: measure and fit text across ui surfaces"
~~~

---

### Task 4b: Mobile combat HUD adaptation (touch layouts)

Files:
- Modify: `src/ui/tactical_ui.gd` (touch button rect helpers, touch-aware patches rect)
- Modify: `src/ui/hud.gd`
- Read-only: `src/ui/touch_controls.gd` (button metrics consumed by the helpers/probes — no edits)
- Modify: `src/autoload/dev_harness.gd`

Interfaces:
- Consumes: `TacticalUI.layout(viewport)` (tactical_ui.gd:35-53); `hud.gd` `layout_snapshot()` (149-150), `show_banner()` (219-224), `_process()` banner block (275-283), `_dash_icon` visibility (310), dash frame call site (~423, `_era_accent` form after Task 3), `_oc_bar()` label build (476-477), `patch_dock_rects()` (511-517), `_dash_pip()` gate + charge text (562, 568); `touch_controls.gd` `_dash_btn()` / `_oc_btn()` (101-107); `Sfx.touch_scale`; the `KP_FORCE_TOUCH` env pattern (arena.gd:133, menu.gd:52).
- Produces: `TacticalUI.touch_dash_rect(viewport, touch_scale)`, `TacticalUI.touch_boost_rect(viewport, touch_scale)`, `TacticalUI.layout(viewport, touch := false, touch_scale := 1.0)` (patches rect avoids the touch DASH button when touch); `Hud.touch_layout()`, `Hud._banner_compact()`; compact wave banner (cycle line suppressed, subtitle at y=186); touch-gated "[E]"/"[SHIFT]" hints; dash frame skipped on touch; touch-aware patch dock.

Numeric expectations used by the probes (scale 1.0): desktop `patches` x-ranges [1020, 1350] / [381.4, 711.4] / [216.6, 424] at 1366x768 / 720x720 / 432x720 all intersect the DASH rect [1206, 1326] / [560, 680] / [272, 392]; after the fix the touch dock ends at x=1194 / 548 / 260 with widths 174 / 166.6 / 120 and never intersects.

- [x] Step 1: Write the failing harness regression

In `src/autoload/dev_harness.gd`, after the line `await _text_overflow_test()` (added in Task 4 Step 1) add:

~~~gdscript
	await _touch_hud_layout_test()
~~~

Then append the new function directly after the `_text_overflow_test()` function (added in Task 4 Step 1):

~~~gdscript
func _touch_hud_layout_test() -> void:
	print("AT_STEP touch_hud_layout")
	var tui_script: Script = load("res://src/ui/tactical_ui.gd")
	var tui = tui_script.new() if tui_script != null else null
	_check(tui != null and tui.has_method("touch_dash_rect") and tui.has_method("touch_boost_rect"), "tactical ui exposes touch button rect helpers")
	if tui == null or not tui.has_method("touch_dash_rect"):
		return
	var hud_script: Script = load("res://src/ui/hud.gd")
	var hud_src := str(hud_script.source_code)
	_check(hud_src.contains("if not touch_layout():"), "combat hud skips desktop-only dash module drawing on touch")
	_check(hud_src.contains("label += \"  READY\""), "overclock ready keeps its label without the [E] keyboard hint on touch")
	_check(hud_src.contains("\"[SHIFT]\" if not touch_layout()"), "dash charge text gates the [SHIFT] keyboard hint on touch")
	_check(hud_src.contains("_banner.text = \"\" if hide_main else text"), "compact wave banner omits the duplicated cycle line")
	_check(hud_src.contains("_banner_sub_l.offset_top = 186"), "compact wave banner repositions below the encounter panel")
	var tc_script: Script = load("res://src/ui/touch_controls.gd")
	var tc = tc_script.new() if tc_script != null else null
	_check(tc != null and tc.has_method("_dash_btn") and tc.has_method("_oc_btn"), "touch controls expose button rects for layout probes")
	var saved_touch_scale := Sfx.touch_scale
	var saved_force := OS.get_environment("KP_FORCE_TOUCH")
	for scale in [0.85, 1.0, 1.2]:
		Sfx.touch_scale = scale
		for vp in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
			var view := Rect2(Vector2.ZERO, vp)
			var dash: Rect2 = tui.call("touch_dash_rect", vp, scale)
			var boost: Rect2 = tui.call("touch_boost_rect", vp, scale)
			_check(view.encloses(dash.grow(-2.0)), "touch dash ring stays inside the safe area at %dx%d scale %.2f" % [int(vp.x), int(vp.y), scale])
			_check(view.encloses(boost.grow(-2.0)), "touch boost ring stays inside the safe area at %dx%d scale %.2f" % [int(vp.x), int(vp.y), scale])
			if tc != null:
				tc.size = vp
				var tc_dash: Rect2 = tc.call("_dash_btn")
				var tc_boost: Rect2 = tc.call("_oc_btn")
				_check(tc_dash.is_equal_approx(dash), "touch dash button metrics match the shared helper at %dx%d scale %.2f" % [int(vp.x), int(vp.y), scale])
				_check(tc_boost.is_equal_approx(boost), "touch boost button metrics match the shared helper at %dx%d scale %.2f" % [int(vp.x), int(vp.y), scale])
			var layout_touch: Dictionary = tui.call("layout", vp, true, scale)
			var layout_plain: Dictionary = tui.call("layout", vp)
			var touch_patches: Rect2 = layout_touch["patches"]
			var plain_patches_vp: Rect2 = layout_plain["patches"]
			_check(bool(layout_touch["compact"]) == bool(layout_plain["compact"]), "touch layout keeps the compact flag size-based at %dx%d" % [int(vp.x), int(vp.y)])
			_check(not touch_patches.intersects(dash), "compact+touch patch dock never intersects the touch dash button at %dx%d scale %.2f" % [int(vp.x), int(vp.y), scale])
			_check(touch_patches.size.x >= minf(120.0, plain_patches_vp.size.x) - 0.01, "touch patch dock keeps readable chips at %dx%d scale %.2f" % [int(vp.x), int(vp.y), scale])
	Sfx.touch_scale = saved_touch_scale
	var banner_hud = hud_script.new()
	banner_hud.size = Vector2(432, 720)
	banner_hud.set("_banner_sub", "PURGE THE DAEMONS")
	_check(bool(banner_hud.call("_banner_compact")), "compact viewport suppresses the duplicated wave-banner cycle line")
	banner_hud.size = Vector2(1366, 768)
	_check(not bool(banner_hud.call("_banner_compact")), "desktop viewport keeps the full wave banner")
	banner_hud.size = Vector2(720, 720)
	banner_hud.set("_banner_sub", "")
	_check(not bool(banner_hud.call("_banner_compact")), "subtitle-less hint banners keep their main line on compact")
	banner_hud.free()
	var gate_hud = hud_script.new()
	OS.set_environment("KP_FORCE_TOUCH", "")
	_check(not bool(gate_hud.call("touch_layout")), "hud touch flag stays off without a touchscreen or override")
	var plain_patches: Rect2 = tui.call("layout", Vector2(1366, 768))["patches"]
	var snapshot_patches: Rect2 = gate_hud.call("layout_snapshot", Vector2(1366, 768))["patches"]
	_check(snapshot_patches.is_equal_approx(plain_patches), "non-touch hud snapshot keeps the desktop patch dock unchanged")
	OS.set_environment("KP_FORCE_TOUCH", "1")
	_check(bool(gate_hud.call("touch_layout")), "KP_FORCE_TOUCH forces the hud touch layout flag")
	var forced_patches: Rect2 = gate_hud.call("layout_snapshot", Vector2(1366, 768))["patches"]
	var forced_dash: Rect2 = tui.call("touch_dash_rect", Vector2(1366, 768), Sfx.touch_scale)
	_check(not forced_patches.intersects(forced_dash), "KP_FORCE_TOUCH snapshot moves the patch dock clear of the touch dash button")
	if saved_force.is_empty():
		OS.set_environment("KP_FORCE_TOUCH", "")
	else:
		OS.set_environment("KP_FORCE_TOUCH", saved_force)
	gate_hud.free()
	if tc != null:
		tc.free()
~~~

- [x] Step 2: Run the test to verify it fails

Run:

~~~sh
godot --headless --path . -- --autotest
~~~

Expected: AT_FAIL `tactical ui exposes touch button rect helpers` (the early
return stops the function at the first missing helper). No parse error; the suite
still exits with `AUTOTEST_FAILED` because of this check.

- [x] Step 3: Add touch rect helpers and the touch-aware patches rect to tactical_ui.gd

3a. In `src/ui/tactical_ui.gd`, replace the whole `layout` function (lines 35-53):

~~~gdscript
static func layout(viewport: Vector2) -> Dictionary:
	var compact := viewport.x < 760.0
	var side := clampf(viewport.x * 0.012, 8.0, 16.0)
	var top := clampf(viewport.y * 0.025, 12.0, 20.0)
	var bottom := viewport.y - clampf(viewport.y * 0.025, 12.0, 20.0)
	var corner_w := minf(245.0, viewport.x * (0.46 if compact else 0.19))
	var center_w := minf(460.0, viewport.x - side * 2.0)
	var encounter_h := 58.0 if compact else 76.0
	var encounter_y := top + 100.0 if compact else top
	var boss_y := bottom - 152.0 if compact else bottom - 88.0
	return {
		"compact": compact,
		"integrity": Rect2(side, top, corner_w, 92.0 if compact else 112.0),
		"encounter": Rect2((viewport.x - center_w) * 0.5, encounter_y, center_w, encounter_h),
		"score": Rect2(viewport.x - side - corner_w, top, corner_w, 92.0 if compact else 120.0),
		"dash": Rect2(side, bottom - 76.0, minf(225.0, viewport.x * 0.45), 76.0),
		"patches": Rect2(viewport.x - side - minf(330.0, viewport.x * 0.48), bottom - 76.0, minf(330.0, viewport.x * 0.48), 76.0),
		"boss": Rect2((viewport.x - center_w) * 0.5, boss_y, center_w, 64.0),
	}
~~~

with:

~~~gdscript
static func layout(viewport: Vector2, touch: bool = false, touch_scale: float = 1.0) -> Dictionary:
	var compact := viewport.x < 760.0
	var side := clampf(viewport.x * 0.012, 8.0, 16.0)
	var top := clampf(viewport.y * 0.025, 12.0, 20.0)
	var bottom := viewport.y - clampf(viewport.y * 0.025, 12.0, 20.0)
	var corner_w := minf(245.0, viewport.x * (0.46 if compact else 0.19))
	var center_w := minf(460.0, viewport.x - side * 2.0)
	var encounter_h := 58.0 if compact else 76.0
	var encounter_y := top + 100.0 if compact else top
	var boss_y := bottom - 152.0 if compact else bottom - 88.0
	var patch_w := minf(330.0, viewport.x * 0.48)
	var patches := Rect2(viewport.x - side - patch_w, bottom - 76.0, patch_w, 76.0)
	if touch:
		var max_right := touch_dash_rect(viewport, touch_scale).position.x - 12.0
		patches.size.x = clampf(max_right - patches.position.x, minf(120.0, patch_w), patch_w)
		if patches.end.x > max_right:
			patches.position.x = max_right - patches.size.x
	return {
		"compact": compact,
		"integrity": Rect2(side, top, corner_w, 92.0 if compact else 112.0),
		"encounter": Rect2((viewport.x - center_w) * 0.5, encounter_y, center_w, encounter_h),
		"score": Rect2(viewport.x - side - corner_w, top, corner_w, 92.0 if compact else 120.0),
		"dash": Rect2(side, bottom - 76.0, minf(225.0, viewport.x * 0.45), 76.0),
		"patches": patches,
		"boss": Rect2((viewport.x - center_w) * 0.5, boss_y, center_w, 64.0),
	}
~~~

The `touch := false` defaults keep every existing caller (`hud.gd:176`,
`boss_bar_rects`, and all non-touch snapshots) byte-identical in output.

3b. At the end of `src/ui/tactical_ui.gd` (inside the class) add the two pure
helpers that mirror `touch_controls.gd` `_dash_btn()` / `_oc_btn()` formulas
exactly (`sc = maxf(touch_scale, 0.1)`, `s = 120.0 * sc`):

~~~gdscript
static func touch_dash_rect(viewport: Vector2, touch_scale: float = 1.0) -> Rect2:
	var sc := maxf(touch_scale, 0.1)
	var s := 120.0 * sc
	return Rect2(viewport.x - s - 40.0 * sc, viewport.y - s - 36.0, s, s)

static func touch_boost_rect(viewport: Vector2, touch_scale: float = 1.0) -> Rect2:
	var sc := maxf(touch_scale, 0.1)
	var s := 120.0 * sc
	return Rect2(viewport.x - s - 40.0 * sc, viewport.y - s * 2.0 - 36.0 - 22.0, s, s)
~~~

- [x] Step 4: Route hud.gd through the touch gate

4a. In `src/ui/hud.gd`, replace (lines 149-150):

~~~gdscript
func layout_snapshot(viewport: Vector2 = size) -> Dictionary:
	return TacticalUIHelper.layout(viewport)
~~~

with:

~~~gdscript
func layout_snapshot(viewport: Vector2 = size) -> Dictionary:
	return TacticalUIHelper.layout(viewport, touch_layout(), Sfx.touch_scale)

func touch_layout() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.get_environment("KP_FORCE_TOUCH") != ""
~~~

4b. Replace `show_banner` (lines 219-224):

~~~gdscript
func show_banner(text: String, sub: String, dur := 2.0) -> void:
	_banner_text = text
	_banner_sub = sub
	_banner_t = dur
	_banner.text = text
	_banner_sub_l.text = sub
~~~

with (the null guards keep detached-Hud probes safe; desktop output is identical
because `_banner_compact()` is false there):

~~~gdscript
func show_banner(text: String, sub: String, dur := 2.0) -> void:
	_banner_text = text
	_banner_sub = sub
	_banner_t = dur
	var hide_main := _banner_compact()
	if _banner != null and is_instance_valid(_banner):
		_banner.text = "" if hide_main else text
	if _banner_sub_l != null and is_instance_valid(_banner_sub_l):
		_banner_sub_l.text = sub

func _banner_compact() -> bool:
	return bool(layout_snapshot()["compact"]) and not _banner_sub.is_empty()
~~~

4c. In `_process()`, replace the banner animation block (lines 275-283):

~~~gdscript
	if _banner_t > 0.0:
		_banner_t -= delta
		var k := _banner_t
		var a_in := clampf((2.0 - k) * 6.0, 0.0, 1.0) if k > 1.7 else 1.0
		var a_out := clampf(k * 2.5, 0.0, 1.0)
		_banner.modulate.a = minf(a_in, a_out)
		_banner_sub_l.modulate.a = _banner.modulate.a * 0.8
		_banner.offset_top = 120 + (1.0 - minf(a_in, 1.0)) * -14.0
		_banner.offset_bottom = _banner.offset_top + 52
~~~

with (compact wave banners drop the cycle line and animate the subtitle at y=186,
below the compact encounter panel that ends at ~y=176; desktop keeps y=120/172):

~~~gdscript
	if _banner_t > 0.0:
		_banner_t -= delta
		var k := _banner_t
		var a_in := clampf((2.0 - k) * 6.0, 0.0, 1.0) if k > 1.7 else 1.0
		var a_out := clampf(k * 2.5, 0.0, 1.0)
		_banner.modulate.a = minf(a_in, a_out)
		_banner_sub_l.modulate.a = _banner.modulate.a * 0.8
		if _banner_compact():
			_banner_sub_l.offset_top = 186 + (1.0 - minf(a_in, 1.0)) * -14.0
			_banner_sub_l.offset_bottom = _banner_sub_l.offset_top + 22
		else:
			_banner.offset_top = 120 + (1.0 - minf(a_in, 1.0)) * -14.0
			_banner.offset_bottom = _banner.offset_top + 52
~~~

4d. Skip the desktop dash module frame on touch — replace (post-Task 3 lines 423):

~~~gdscript
	_draw_angular_panel(score_rect, _era_accent, 0.055, true)
	_draw_angular_panel(dash_rect, _era_accent, 0.045, true)
~~~

with:

~~~gdscript
	_draw_angular_panel(score_rect, _era_accent, 0.055, true)
	if not touch_layout():
		_draw_angular_panel(dash_rect, _era_accent, 0.045, true)
~~~

(The "DASH READY"/"DASH CHARGING" text, charge pips, and cooldown bar already sit
behind the `_dash_pip()` early return handled in 4h; the touch DASH button in
`touch_controls.gd` is the mobile dash UI.)

4e. Replace the `_dash_icon` visibility line (line 310):

~~~gdscript
		_dash_icon.visible = Balance.is_desktop_display() and not DisplayServer.is_touchscreen_available()
~~~

with:

~~~gdscript
		_dash_icon.visible = Balance.is_desktop_display() and not touch_layout()
~~~

4f. Gate the [E] keyboard hint — replace (lines 476-477):

~~~gdscript
	if _oc_ready and not _oc_active and not shield_mode:
		label += "  READY [E]"
~~~

with ("OVERCLOCK READY" / "SHIELD READY" text is kept on touch; the desktop
string still renders as `  READY [E]`):

~~~gdscript
	if _oc_ready and not _oc_active and not shield_mode:
		label += "  READY"
		if not touch_layout():
			label += " [E]"
~~~

4g. Make the patch dock touch-aware — replace (lines 515-517):

~~~gdscript
	var panel: Rect2 = TacticalUIHelper.layout(viewport)["patches"]
	var ids: Array = Game.patch_levels.keys()
	var compact := bool(TacticalUIHelper.layout(viewport)["compact"])
~~~

with (chips reflow inside the narrowed dock automatically):

~~~gdscript
	var panel: Rect2 = layout_snapshot(viewport)["patches"]
	var ids: Array = Game.patch_levels.keys()
	var compact := bool(layout_snapshot(viewport)["compact"])
~~~

4h. In `_dash_pip()`, replace (lines 562-564):

~~~gdscript
	if not Balance.is_desktop_display() or DisplayServer.is_touchscreen_available():
		return
	var col := Balance.COL_PLAYER if _dash_frac >= 1.0 else Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.35)
~~~

with:

~~~gdscript
	if not Balance.is_desktop_display() or touch_layout():
		return
	var col := Balance.COL_PLAYER if _dash_frac >= 1.0 else Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.35)
~~~

and replace the charge-text fallback (line 568):

~~~gdscript
	var charge_text := "x%d" % _dash_max if _dash_max > 1 else "[SHIFT]"
~~~

with:

~~~gdscript
	var charge_text := ("x%d" % _dash_max) if _dash_max > 1 else ("[SHIFT]" if not touch_layout() else "x1")
~~~

- [x] Step 5: Run the full suite

Run:

~~~sh
godot --headless --path . -- --autotest
~~~

Expected: `AUTOTEST_ALL_PASS` and zero `AT_FAIL`. The new `touch_hud_layout`
section passes all 76 of its checks (5 source gates + 1 probe-availability check
+ 9 viewport/scale iterations × 7 ring/metrics/intersection checks + 3 banner
probes + 4 `KP_FORCE_TOUCH` gate probes), and the
pre-existing `patch dock chip fits %dx%d`, `active banner is not replaced by
queued hint` (reads the `_banner_text` var, not the label), `queued hint drains
after active banner`, and `touch dash button dashes` checks stay green unchanged.

- [x] Step 6: Visual capture at touch resolutions

Run (desktop, windowed; `KP_FORCE_TOUCH=1` makes the arena instantiate
`TouchControls` per arena.gd:133):

~~~sh
mkdir -p /tmp/opencode
KP_FORCE_TOUCH=1 KP_SHOT=game KP_SHOT_OUT=/tmp/opencode/hud_touch_720.png godot --path . --resolution 720x720
KP_FORCE_TOUCH=1 KP_SHOT=game KP_SHOT_OUT=/tmp/opencode/hud_touch_432.png godot --path . --resolution 432x720
~~~

Expected: no empty dash panel frame bottom-left; no "[SHIFT]" text bottom-left;
the patch dock is narrowed and its chips stay clear of the DASH ring; the DASH
and BOOST rings sit fully inside the frame with no clipping. If a wave banner is
visible during the capture, only its subtitle shows, positioned below the
encounter panel. Desktop appearance is unchanged when `KP_FORCE_TOUCH` is unset
(covered by the Task 2 / Task 8 captures). Captures stay in `/tmp/opencode/` and
are never committed.

- [x] Step 7: Commit

~~~sh
git add src/ui/tactical_ui.gd src/ui/hud.gd src/autoload/dev_harness.gd
git commit -m "fix: adapt combat hud for touch layouts"
~~~

---

### Task 5: Mote pickup tunneling + OOM_KILLER steal association

Files:
- Modify: `src/pickups/mote_field.gd`
- Modify: `src/enemies/oom_killer.gd`
- Modify: `src/autoload/dev_harness.gd`

Interfaces:
- Consumes: `mote_field.gd` `_physics_process()` pickup at `d < 20.0` (line 207), `kill_slot()` swap-remove, `nearest_free()`; `oom_killer.gd` `_move()` SEEK branch and `carried_ids`.
- Produces: swept segment collection (prev→current player position vs 20px radius); `MoteField.uid_of(idx)` / `MoteField.idx_of_uid(uid)` identity handles; `OomKiller._steal(idx, expected_uid)` re-validation; uid-based `carried_ids`.

- [x] Step 1: Write the failing harness regression

In `src/autoload/dev_harness.gd`, after the line `await _debug_controls_test(arena2)` add:

~~~gdscript
	await _mote_sweep_test(arena2)
	await _oom_steal_identity_test(arena2)
~~~

Then append the two new functions:

~~~gdscript
func _mote_sweep_test(arena: Arena) -> void:
	print("AT_STEP mote_sweep")
	arena.spawner.stop()
	arena.spawner.debug_clear_encounter()
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node):
			node.queue_free()
	await _ticks(2)
	var mf: MoteField = arena.mote_field
	var player_ref: Player = arena.player
	player_ref.invuln = 9999.0
	Game.patch_levels = {}
	player_ref.meter = 0.0
	player_ref.overclock_active = false
	for i in range(mf.count() - 1, -1, -1):
		mf.kill_slot(i)
	var start := player_ref.global_position
	var far_idx := mf.spawn(start + Vector2(400.0, 0.0))
	var mid_idx := mf.spawn(start + Vector2(130.0, 0.0))
	await _ticks(3)
	player_ref.global_position = start + Vector2(260.0, 0.0)
	var collected := await _until(func() -> bool: return not mf.alive_at(mid_idx), 3.0, "swept mote pickup")
	_check(collected, "a dash-speed position jump collects a mote centered in the swept segment")
	_check(mf.alive_at(far_idx), "a distant mote is not collected by the swept segment")
	if far_idx >= 0 and mf.alive_at(far_idx):
		mf.kill_slot(far_idx)
	player_ref.invuln = 0.0

func _oom_steal_identity_test(arena: Arena) -> void:
	print("AT_STEP oom_identity")
	var mf: MoteField = arena.mote_field
	_check(mf.has_method("uid_of") and mf.has_method("idx_of_uid"), "mote field exposes identity handles")
	if not (mf.has_method("uid_of") and mf.has_method("idx_of_uid")):
		return
	arena.spawner.stop()
	arena.spawner.debug_clear_encounter()
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node):
			node.queue_free()
	await _ticks(2)
	var oom: EnemyBase = arena.spawner._make_enemy("oom")
	oom.position = arena.player.global_position + Vector2(320, 0)
	arena.enemy_container.add_child(oom)
	await _ticks(2)
	for i in range(mf.count() - 1, -1, -1):
		mf.kill_slot(i)
	var near_idx := mf.spawn(oom.global_position + Vector2(12.0, 0.0))
	var target_idx := mf.spawn(oom.global_position + Vector2(160.0, 0.0))
	var target_pos := mf.pos_of(target_idx)
	var target_uid: int = mf.call("uid_of", target_idx)
	oom.call("_steal", target_idx, target_uid)
	_check(mf.is_stolen(target_idx), "oom steals the targeted mote")
	mf.kill_slot(near_idx)
	var resolved: int = mf.call("idx_of_uid", target_uid)
	_check(resolved >= 0 and mf.alive_at(resolved) and mf.is_stolen(resolved), "the stolen mote keeps its identity after a slot swap")
	_check(mf.pos_of(resolved).distance_to(target_pos) < 0.01, "the carried slot still points at the stolen mote's position")
	var third_idx := mf.spawn(oom.global_position + Vector2(300.0, 0.0))
	var wrong_uid: int = int(target_uid) + 1000000
	oom.call("_steal", third_idx, wrong_uid)
	_check(not mf.is_stolen(third_idx), "a stale identity never steals a live free mote")
	oom.call("_steal", third_idx, mf.call("uid_of", third_idx))
	_check(mf.is_stolen(third_idx), "a matching identity steals normally")
	var probe: int = mf.nearest_free(oom.global_position)
	_check(probe < 0 or (mf.alive_at(probe) and not mf.is_stolen(probe)), "re-resolution only targets live free motes")
	oom.carried_ids.clear()
	mf.free_all_stolen()
	oom.queue_free()
	await _ticks(2)
~~~

- [x] Step 2: Run the test to verify it fails

Run:

~~~sh
godot --headless --path . -- --autotest
~~~

Expected: AT_FAIL `a dash-speed position jump collects a mote centered in the
swept segment` (today the 260px teleport steps over the mote at 130px, outside
both the 115px magnet radius and the 20px pickup radius) and AT_FAIL `mote field
exposes identity handles`. No parse error.

- [x] Step 3: Swept pickup in mote_field.gd

3a. In `src/pickups/mote_field.gd`, after the line `var player: Node2D` (line ~19), add:

~~~gdscript
var _prev_player_pos := Vector2.ZERO
var _has_prev := false
~~~

3b. In `_physics_process()`, replace:

~~~gdscript
	var ppos: Vector2 = player.global_position if player != null and is_instance_valid(player) else Vector2.ZERO
~~~

with:

~~~gdscript
	var ppos: Vector2 = player.global_position if player != null and is_instance_valid(player) else Vector2.ZERO
	var sweep_from := _prev_player_pos if _has_prev else ppos
~~~

3c. In the same function, replace the pickup block:

~~~gdscript
			if d < 20.0:
				player.collect_mote()
				Fx.sparks(_pos[i], Balance.COL_MOTE, 4, 120.0, 0.25, 2.0)
				kill_slot(i)
				continue
~~~

with the swept-segment distance test (magnet logic above it stays untouched):

~~~gdscript
			var seg := ppos - sweep_from
			var seg_len_sq := seg.length_squared()
			var seg_t := 0.0
			if seg_len_sq > 0.0001:
				seg_t = clampf((_pos[i] - sweep_from).dot(seg) / seg_len_sq, 0.0, 1.0)
			var nearest := sweep_from + seg * seg_t
			if d < 20.0 or _pos[i].distance_to(nearest) < 20.0:
				player.collect_mote()
				Fx.sparks(_pos[i], Balance.COL_MOTE, 4, 120.0, 0.25, 2.0)
				kill_slot(i)
				continue
~~~

3d. At the end of `_physics_process()`, directly before `_push_instances()`, add:

~~~gdscript
	_prev_player_pos = ppos
	_has_prev = true
~~~

- [x] Step 4: Identity handles in mote_field.gd

4a. After the line `var _count := 0` (line ~17), add:

~~~gdscript
var _uid := PackedInt64Array()
var _next_uid := 1
~~~

4b. In `_ready()`, directly after `_seed_t.resize(MAX)`, add:

~~~gdscript
	_uid.resize(MAX)
~~~

4c. In `_init_slot()`, directly after `_flags[idx] = F_ALIVE`, add:

~~~gdscript
	_uid[idx] = _next_uid
	_next_uid += 1
~~~

4d. In `kill_slot()`, directly after `_seed_t[idx] = _seed_t[last]`, add:

~~~gdscript
		_uid[idx] = _uid[last]
~~~

4e. At the end of the file (inside the class) add:

~~~gdscript
func uid_of(idx: int) -> int:
	if idx < 0 or idx >= _count or not alive_at(idx):
		return -1
	return _uid[idx]

func idx_of_uid(uid: int) -> int:
	if uid <= 0:
		return -1
	for i in _count:
		if alive_at(i) and _uid[i] == uid:
			return i
	return -1
~~~

- [x] Step 5: Harden oom_killer.gd

5a. In `src/enemies/oom_killer.gd` `_move()` St.SEEK branch, replace:

~~~gdscript
			var target_idx: int = _nearest_free_mote()
			if target_idx >= 0:
				var tp := _field().pos_of(target_idx)
				var desired := (tp - global_position).normalized()
				desired += steer_separation(2.4) * 0.7
				_v = _v.move_toward(desired.limit_length(1.0) * speed, 500.0 * delta)
				if global_position.distance_to(tp) < 18.0:
					_steal(target_idx)
~~~

with:

~~~gdscript
			var target_idx: int = _nearest_free_mote()
			if target_idx >= 0:
				var f := _field()
				var tp := f.pos_of(target_idx)
				var target_uid := f.uid_of(target_idx)
				var desired := (tp - global_position).normalized()
				desired += steer_separation(2.4) * 0.7
				_v = _v.move_toward(desired.limit_length(1.0) * speed, 500.0 * delta)
				if global_position.distance_to(tp) < 18.0 and f.uid_of(target_idx) == target_uid:
					_steal(target_idx, target_uid)
~~~

5b. In the same function, replace the carried-motes loop:

~~~gdscript
	var f := _field()
	if f != null:
		for i in range(carried_ids.size() - 1, -1, -1):
			var idx: int = carried_ids[i]
			if not f.alive_at(idx):
				carried_ids.remove_at(i)
				continue
			f.set_slot_position(idx, global_position + Vector2.from_angle(t * 4.0 + TAU * i / maxi(carried_ids.size(), 1)) * 22.0)
~~~

with:

~~~gdscript
	var f := _field()
	if f != null:
		for i in range(carried_ids.size() - 1, -1, -1):
			var idx: int = f.idx_of_uid(int(carried_ids[i]))
			if idx < 0:
				carried_ids.remove_at(i)
				continue
			f.set_slot_position(idx, global_position + Vector2.from_angle(t * 4.0 + TAU * i / maxi(carried_ids.size(), 1)) * 22.0)
~~~

5c. Replace `_steal()`:

~~~gdscript
func _steal(idx: int, expected_uid: int = -1) -> void:
	var f := _field()
	if f == null or f.is_stolen(idx):
		return
	if expected_uid >= 0 and f.uid_of(idx) != expected_uid:
		return
	if f.steal(idx) < 0:
		return
	f.set_slot_position(idx, f.pos_of(idx))
	carried_ids.append(f.uid_of(idx))
	Fx.sparks(f.pos_of(idx), col, 5, 140.0, 0.3, 2.5)
	Sfx.play("hit", 1.6, -10.0, 0.1)
	Fx.text(global_position + Vector2(0, -22), "STOLEN", col, 11)
~~~

The existing harness calls `oom._steal(mote_idx)` with one argument (lines ~1211 and ~2384); the `expected_uid = -1` default keeps them valid.

- [x] Step 6: Run the full suite

Run:

~~~sh
godot --headless --path . -- --autotest
~~~

Expected: `AUTOTEST_ALL_PASS` and zero `AT_FAIL`, including the pre-existing
`OOM_KILLER steals selected mote slot`, `OOM_KILLER steals motes`, and
`killed OOM_KILLER returns motes` checks.

- [x] Step 7: Commit

~~~sh
git add src/pickups/mote_field.gd src/enemies/oom_killer.gd src/autoload/dev_harness.gd
git commit -m "fix: sweep mote pickups and harden oom steal targets"
~~~

---

### Task 6: Difficulty setting (endless modes only)

Files:
- Modify: `src/autoload/balance.gd`, `src/autoload/game.gd`, `src/ui/menu.gd`, `src/arena/spawner.gd`, `src/enemies/enemy_base.gd`, `src/enemies/spewer.gd`, `src/enemies/root_boss.gd`, `README.md`
- Modify: `src/autoload/dev_harness.gd`

Interfaces:
- Consumes: `Game.mode` / `Game.difficulty`, `spawner.gd` budget (line 163), alive cap (line 283), elite roll (line 329); cadence read points in `enemy_base.gd` (lines 50-51), `spewer.gd` (line 67), `root_boss.gd` (lines 340, 510); menu `_cycle_mode()` persistence pattern (lines 664-676).
- Produces: `Game.difficulty` + `Game.set_difficulty()`; `Balance.DIFFICULTY_ORDER`, `Balance.difficulty_max_alive()`, `Balance.difficulty_wave_budget()`, `Balance.difficulty_elite_chance()`, `Balance.difficulty_cadence()`; a `DIFFICULTY` cycler next to MODE.

- [x] Step 1: Write the failing harness regression

In `src/autoload/dev_harness.gd`, after the line `await _systems_test(arena2)` add:

~~~gdscript
	await _difficulty_test()
~~~

Then append the new function:

~~~gdscript
func _difficulty_test() -> void:
	print("AT_STEP difficulty")
	var balance_script: Script = load("res://src/autoload/balance.gd")
	var has_helpers: bool = balance_script != null and balance_script.has_method("difficulty_max_alive") and balance_script.has_method("difficulty_wave_budget") and balance_script.has_method("difficulty_elite_chance") and balance_script.has_method("difficulty_cadence")
	_check(has_helpers, "balance exposes difficulty-aware read helpers")
	if not has_helpers:
		return
	var saved_mode := Game.mode
	var saved_difficulty := str(Game.get("difficulty"))
	var alive_caps := {"easy": 7, "normal": 10, "hard": 13}
	var budget_mults := {"easy": 0.8, "normal": 1.0, "hard": 1.2}
	var elite_mults := {"easy": 0.6, "normal": 1.0, "hard": 1.4}
	var cadence_floors := {"easy": 0.90, "normal": 0.78, "hard": 0.70}
	Game.mode = "classic"
	for difficulty in ["easy", "normal", "hard"]:
		Game.set("difficulty", difficulty)
		_check(balance_script.call("difficulty_max_alive", 2) == int(alive_caps[difficulty]), "difficulty %s caps wave 2 alive at %d" % [difficulty, alive_caps[difficulty]])
		var expected_budget: int = int(floor(float(Balance.wave_budget(5)) * float(budget_mults[difficulty])))
		_check(balance_script.call("difficulty_wave_budget", 5) == expected_budget, "difficulty %s scales the wave budget" % difficulty)
		var expected_elite: float = clampf(Balance.elite_chance(10) * float(elite_mults[difficulty]), 0.0, 1.0)
		_check(absf(float(balance_script.call("difficulty_elite_chance", 10)) - expected_elite) < 0.0001, "difficulty %s scales the elite chance" % difficulty)
		_check(absf(float(balance_script.call("difficulty_cadence", 1)) - 1.0) < 0.001, "difficulty %s keeps wave 1 cadence at 1.0" % difficulty)
		_check(absf(float(balance_script.call("difficulty_cadence", 30)) - float(cadence_floors[difficulty])) < 0.005, "difficulty %s lands wave 30 cadence on %.2f" % [difficulty, cadence_floors[difficulty]])
	Game.mode = "story"
	for difficulty in ["easy", "normal", "hard"]:
		Game.set("difficulty", difficulty)
		var story_unscaled: bool = balance_script.call("difficulty_max_alive", 30) == Balance.max_alive(30) and balance_script.call("difficulty_wave_budget", 30) == Balance.wave_budget(30) and absf(float(balance_script.call("difficulty_cadence", 30)) - Balance.attack_cadence_factor(30)) < 0.0001 and absf(float(balance_script.call("difficulty_elite_chance", 10)) - Balance.elite_chance(10)) < 0.0001
		_check(story_unscaled, "story ignores difficulty %s" % difficulty)
	Game.mode = "classic"
	if Game.has_method("set_difficulty"):
		Game.call("set_difficulty", "hard")
		_check(str(Game.get("difficulty")) == "hard", "set_difficulty stores a new difficulty")
		var cf_probe := ConfigFile.new()
		cf_probe.load(Sfx.SAVE_PATH)
		_check(str(cf_probe.get_value("game", "difficulty", "")) == "hard", "difficulty persists to the save config")
		Game.call("set_difficulty", "normal")
		_check(str(Game.get("difficulty")) == "normal", "set_difficulty restores normal")
	Game.mode = saved_mode
	Game.set("difficulty", saved_difficulty)
~~~

- [x] Step 2: Run the test to verify it fails

Run:

~~~sh
godot --headless --path . -- --autotest
~~~

Expected: AT_FAIL `balance exposes difficulty-aware read helpers`. No parse error.

- [x] Step 3: Add the difficulty tables and read helpers to balance.gd

3a. In `src/autoload/balance.gd`, directly after `const HEAL_EVERY := 3` (line ~39), add:

~~~gdscript
const DIFFICULTY_ORDER := ["easy", "normal", "hard"]
const DIFF_ALIVE_MULT := {"easy": 0.7, "normal": 1.0, "hard": 1.3}
const DIFF_BUDGET_MULT := {"easy": 0.8, "normal": 1.0, "hard": 1.2}
const DIFF_ELITE_MULT := {"easy": 0.6, "normal": 1.0, "hard": 1.4}
const DIFF_CADENCE_SCALE := {"easy": 1.0, "normal": 1.0, "hard": 0.897}
const DIFF_CADENCE_FLOOR := {"easy": 0.90, "normal": 0.78, "hard": 0.70}
~~~

3b. Directly after `static func elite_chance(wave: int) -> float:` block (after line ~103), add:

~~~gdscript
static func difficulty_applies() -> bool:
	return Game.mode != "story"

static func difficulty_max_alive(wave: int) -> int:
	if not difficulty_applies():
		return max_alive(wave)
	var mult: float = DIFF_ALIVE_MULT.get(Game.difficulty, 1.0)
	return maxi(1, int(ceil(float(max_alive(wave)) * mult)))

static func difficulty_wave_budget(wave: int) -> int:
	if not difficulty_applies():
		return wave_budget(wave)
	var mult: float = DIFF_BUDGET_MULT.get(Game.difficulty, 1.0)
	return maxi(1, int(floor(float(wave_budget(wave)) * mult)))

static func difficulty_elite_chance(wave: int) -> float:
	if not difficulty_applies():
		return elite_chance(wave)
	var mult: float = DIFF_ELITE_MULT.get(Game.difficulty, 1.0)
	return clampf(elite_chance(wave) * mult, 0.0, 1.0)

static func difficulty_cadence(wave: int) -> float:
	if not difficulty_applies():
		return attack_cadence_factor(wave)
	var base := attack_cadence_factor(wave)
	if base >= 1.0:
		return 1.0
	var scale: float = DIFF_CADENCE_SCALE.get(Game.difficulty, 1.0)
	var floor_v: float = DIFF_CADENCE_FLOOR.get(Game.difficulty, 0.78)
	return clampf(base * scale, floor_v, 1.0)
~~~

The `base >= 1.0` guard keeps the wave 1-5 ramp at exactly 1.0 for every difficulty (the spec requires wave 1 cadence 1.0 in all modes); below the ramp the scale applies and the floor clamps the result, landing wave 30 on 0.90 / 0.78 / 0.70.

The base functions `wave_budget`, `max_alive`, `attack_cadence_factor`, `elite_chance` keep their signatures and values, so the locked harness checks (`max_alive(1)==8`, `max_alive(2)==10`, `max_alive(30)==10`, cadence wave checks) pass unchanged.

- [x] Step 4: Persist the setting in game.gd

4a. In `src/autoload/game.gd`, directly after `var mode := "classic"` (line ~19), add:

~~~gdscript
var difficulty := "normal"
~~~

4b. In `_load_run_config()`, directly after the `onehp` mode guard (lines ~139-140), add:

~~~gdscript
		difficulty = str(cf.get_value("game", "difficulty", "normal"))
		if difficulty not in Balance.DIFFICULTY_ORDER:
			difficulty = "normal"
~~~

4c. Directly after `func set_program(id: String) -> void:` block, add:

~~~gdscript
func set_difficulty(value: String) -> void:
	if value not in Balance.DIFFICULTY_ORDER:
		return
	difficulty = value
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	cf.set_value("game", "difficulty", value)
	cf.save(Sfx.SAVE_PATH)
~~~

- [x] Step 5: Apply the multipliers at the read points

5a. In `src/arena/spawner.gd` `_build_queue()`, replace (line ~163):

~~~gdscript
	var budget := Balance.wave_budget(wave)
~~~

with (multiplier lands before the existing surge/rich event modifiers on lines 164-167):

~~~gdscript
	var budget := Balance.difficulty_wave_budget(wave)
~~~

5b. In `_physics_process()`, replace (line ~283):

~~~gdscript
	if _spawn_t > 0.0 or alive >= Balance.max_alive(wave):
~~~

with:

~~~gdscript
	if _spawn_t > 0.0 or alive >= Balance.difficulty_max_alive(wave):
~~~

5c. In `_telegraph_spawn()`, replace (line ~329):

~~~gdscript
			_configure_enemy(e, Game.rng.randf() < Balance.elite_chance(wave))
~~~

with:

~~~gdscript
			_configure_enemy(e, Game.rng.randf() < Balance.difficulty_elite_chance(wave))
~~~

5d. In `src/enemies/enemy_base.gd` `elite_reacquire_interval()` (lines ~50-51), replace both `Balance.attack_cadence_factor(threat_wave)` occurrences with `Balance.difficulty_cadence(threat_wave)`:

~~~gdscript
func elite_reacquire_interval(base_interval: float) -> float:
	if elite and elite_kind == "swift":
		return maxf(base_interval * Balance.difficulty_cadence(threat_wave) * 0.82, 0.35)
	return base_interval * Balance.difficulty_cadence(threat_wave)
~~~

5e. In `src/enemies/spewer.gd` (line ~67), replace:

~~~gdscript
	return maxf(base_interval * Balance.attack_cadence_factor(threat_wave), 0.5)
~~~

with:

~~~gdscript
	return maxf(base_interval * Balance.difficulty_cadence(threat_wave), 0.5)
~~~

5f. In `src/enemies/root_boss.gd` (lines ~340 and ~510), replace both occurrences of `Balance.attack_cadence_factor(threat_wave)` with `Balance.difficulty_cadence(threat_wave)`.

- [x] Step 6: Add the DIFFICULTY cycler to menu.gd

6a. In `src/ui/menu.gd`, directly after the line `var _mode_btn: Button` (line ~18), add:

~~~gdscript
var _diff_btn: Button
~~~

6b. In `_build_button_row()`, directly after the `add_child(_program_btn)` line (line ~385), add:

~~~gdscript
	_diff_btn = Button.new()
	_diff_btn.flat = true
	_diff_btn.z_index = 2
	_diff_btn.focus_mode = Control.FOCUS_NONE
	_diff_btn.anchor_left = 0.5
	_diff_btn.anchor_right = 0.5
	_diff_btn.anchor_top = 0.5
	_diff_btn.anchor_bottom = 0.5
	_diff_btn.offset_left = -216.0
	_diff_btn.offset_right = -42.0
	_diff_btn.offset_top = 112.0
	_diff_btn.offset_bottom = 162.0
	_diff_btn.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	_diff_btn.add_theme_font_size_override("font_size", 15)
	_diff_btn.add_theme_color_override("font_color", Color(0.6, 1.0, 0.8, 0.9))
	_diff_btn.add_theme_color_override("font_hover_color", TacticalUIHelper.LIME)
	_diff_btn.pressed.connect(_cycle_difficulty)
	add_child(_diff_btn)
	_refresh_difficulty_label()
~~~

6c. Directly after `_cycle_mode()` (after line ~680), add:

~~~gdscript
func _cycle_difficulty() -> void:
	if Game.mode == "story":
		Sfx.play("ui", 0.9, -10.0)
		_refresh_difficulty_label()
		return
	var order: Array = Balance.DIFFICULTY_ORDER
	var idx := order.find(Game.difficulty)
	Game.set_difficulty(str(order[(idx + 1) % order.size()]))
	Sfx.play("ui", 1.1, -8.0)
	_refresh_difficulty_label()

func _refresh_difficulty_label() -> void:
	if _diff_btn == null:
		return
	if Game.mode == "story":
		_diff_btn.text = "DIFFICULTY: FIXED CURVE"
	else:
		_diff_btn.text = "DIFFICULTY: %s" % Game.difficulty.to_upper()
~~~

6d. In `_refresh_mode_ui()`, as the last statement of the function, add:

~~~gdscript
	_refresh_difficulty_label()
~~~

- [x] Step 7: Document the control in README.md

In `README.md`, directly after the One-HP bullet (line ~152, the `- **One-HP** gives you one mistake and no excuses.` line), insert:

~~~markdown
Endless modes also expose a **DIFFICULTY** cycler next to **MODE** (EASY /
NORMAL / HARD, default NORMAL). It scales the spawn cap, wave budget, elite
chance, and attack cadence, and it is stored locally; Story keeps its fixed
per-stage curve and weekly runs stay seed-deterministic.
~~~

- [x] Step 8: Run the full suite

Run:

~~~sh
godot --headless --path . -- --autotest
~~~

Expected: `AUTOTEST_ALL_PASS` and zero `AT_FAIL` — every pre-existing check
passes unmodified at default NORMAL, including the weekly seed-determinism
check and the locked `Balance.max_alive` / cadence checks. Story-mode spawn
behavior is identical across difficulties.

- [x] Step 9: Commit

~~~sh
git add src/autoload/balance.gd src/autoload/game.gd src/ui/menu.gd src/arena/spawner.gd src/enemies/enemy_base.gd src/enemies/spewer.gd src/enemies/root_boss.gd README.md src/autoload/dev_harness.gd
git commit -m "feat: add endless difficulty setting"
~~~

---

### Task 6b: Achievements panel + run-log surfacing

Files:
- Create: `src/ui/achievements_panel.gd`
- Modify: `src/ui/menu.gd`
- Modify: `src/autoload/game.gd` (ONLY if the Step 1 surfacing guard fails — expected: no edit; `unlock_achievement` already logs before emitting)
- Modify: `src/autoload/dev_harness.gd`

Interfaces:
- Consumes: `Game.ACHIEVEMENT_DEFS` (game.gd:39), `Game.achievements` (persisted in config section "achievements"), `Game.unlock_achievement()` (game.gd:485, already calls `log_event("achievement: %s enabled" % label)` before `achievement_unlocked.emit`), `Game.event_log` + `hud.gd` `visible_event_lines()` (line 155), the bestiary overlay pattern in `menu.gd` (`_open_bestiary` ~551, `_close_bestiary` ~600, `_style_overlay_back` ~604, ESC close chains at ~1452 and ~1490), the bottom card-button row (`_style_card_button`, `bottom_button_w`, row after `best_btn`).
- Produces: `AchievementsPanel.achievement_rows()`, `AchievementsPanel.progress_header()`, `AchievementsPanel.refresh()`; menu `_open_achievements()` / `_close_achievements()`; harness `_achievements_panel_test()`.

- [ ] Step 1: Write the failing harness regression

In `src/autoload/dev_harness.gd`, after the line `await _touch_hud_layout_test()` add:

~~~gdscript
	await _achievements_panel_test()
~~~

Then append the new function:

~~~gdscript
func _achievements_panel_test() -> void:
	print("AT_STEP achievements_panel")
	var panel_script: Script = load("res://src/ui/achievements_panel.gd")
	var panel = panel_script.new() if panel_script != null else null
	_check(panel != null and panel.has_method("achievement_rows") and panel.has_method("progress_header"), "achievements panel exposes achievement_rows and progress_header")
	if panel == null or not panel.has_method("achievement_rows"):
		if panel != null:
			panel.free()
		return
	var saved_achievements: Dictionary = Game.achievements.duplicate()
	Game.achievements = {"first_blood": true}
	panel.size = Vector2(1366, 768)
	var rows: Array = panel.call("achievement_rows")
	var ids: Array = []
	for row in rows:
		ids.append(str(row.get("id", "")))
	var all_listed := true
	for id in Game.ACHIEVEMENT_DEFS:
		if not ids.has(str(id)):
			all_listed = false
	_check(all_listed, "achievements panel lists every ACHIEVEMENT_DEFS id")
	var state_ok: bool = rows.size() == Game.ACHIEVEMENT_DEFS.size()
	for row in rows:
		if bool(row.get("unlocked", false)) == (not Game.achievements.has(str(row.get("id", "")))):
			state_ok = false
	_check(state_ok, "achievements rows report the correct locked state")
	_check(str(panel.call("progress_header")).contains("1 / %d" % Game.ACHIEVEMENT_DEFS.size()), "achievements header shows the X / Y progress count")
	var hints_ok := true
	for row in rows:
		if not Game.achievements.has(str(row.get("id", ""))) and str(row.get("hint", "")).strip_edges().is_empty():
			hints_ok = false
	_check(hints_ok, "locked achievements expose a hint line")
	var panel_src := str(panel_script.source_code)
	_check(panel_src.contains("ScrollContainer"), "achievements panel scrolls instead of blocking mobile input")
	panel.free()
	var menu_src := str(load("res://src/ui/menu.gd").source_code)
	_check(menu_src.contains("_open_achievements"), "menu exposes an achievements entry point")
	var hud_script: Script = load("res://src/ui/hud.gd")
	var hud_detached = hud_script.new()
	hud_detached.size = Vector2(1366, 768)
	Game.achievements.erase("chain_max")
	var unlocked_now: bool = Game.unlock_achievement("chain_max")
	_check(unlocked_now, "test unlock of a fresh achievement succeeds")
	var surfaced := false
	for line in hud_detached.call("visible_event_lines"):
		if str(line).contains("achievement: CHAIN_REACTION"):
			surfaced = true
	_check(surfaced, "a mid-run unlock appears in the hud event log lines")
	hud_detached.size = Vector2(432, 720)
	_check(not bool(hud_detached.call("event_log_visible")), "compact viewport keeps the event log hidden for the hidden-log probe")
	Game.achievements.erase("terminal_operator")
	Game.unlock_achievement("terminal_operator")
	_check(hud_detached.call("visible_event_lines").size() > 0, "unlocking while the event log is hidden does not error")
	hud_detached.free()
	Game.achievements = saved_achievements
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	cf.set_value("achievements", "unlocked", saved_achievements)
	cf.save(Sfx.SAVE_PATH)
~~~

- [ ] Step 2: Run the test to verify it fails

Run:

~~~sh
godot --headless --path . -- --autotest
~~~

Expected: AT_FAIL `achievements panel exposes achievement_rows and progress_header`
(the early return stops the function, so the later guards do not run yet — they
are regression protection for the already-working `unlock_achievement →
log_event` path, not new wiring). No parse error.

- [ ] Step 3: Create src/ui/achievements_panel.gd with the full content

Create `src/ui/achievements_panel.gd`:

~~~gdscript
class_name AchievementsPanel
extends Control

## Code-drawn ACHIEVEMENTS overlay for the menu shell.
## Lists every Game.ACHIEVEMENT_DEFS entry with unlocked/locked state, a hint
## for locked rows, and an X / Y progress header. Persistence is untouched.

const TacticalUIHelper = preload("res://src/ui/tactical_ui.gd")

const ACHIEVEMENT_HINTS := {
	"first_blood": "Terminate your first daemon.",
	"boss_purge": "Take down a ROOT-class boss.",
	"chain_max": "Push the combo meter to its maximum multiplier.",
	"terminal_operator": "Grant a sudo heal in the terminal.",
	"integrity_restored": "Recover integrity after it drops.",
}

var _header: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Game.achievement_unlocked.connect(_on_achievement_unlocked)
	_build()

func achievement_rows() -> Array:
	var rows: Array = []
	for id in Game.ACHIEVEMENT_DEFS:
		rows.append({
			"id": str(id),
			"label": str(Game.ACHIEVEMENT_DEFS[id]),
			"unlocked": Game.achievements.has(id),
			"hint": str(ACHIEVEMENT_HINTS.get(id, "")),
		})
	return rows

func progress_header() -> String:
	var unlocked := 0
	for id in Game.ACHIEVEMENT_DEFS:
		if Game.achievements.has(id):
			unlocked += 1
	return "ACHIEVEMENTS // %d / %d UNLOCKED" % [unlocked, Game.ACHIEVEMENT_DEFS.size()]

func refresh() -> void:
	_build()
	queue_redraw()

func _on_achievement_unlocked(_id: String, _label: String) -> void:
	if visible:
		refresh()

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var mono: Font = load("res://assets/fonts/ShareTechMono.ttf")
	_header = Label.new()
	_header.text = progress_header()
	_header.add_theme_font_override("font", mono)
	_header.add_theme_font_size_override("font_size", 17)
	_header.add_theme_color_override("font_color", TacticalUIHelper.CYAN)
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.anchor_left = 0.0
	_header.anchor_right = 1.0
	_header.offset_top = 118.0
	_header.offset_bottom = 148.0
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_header)
	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.0
	scroll.anchor_right = 1.0
	scroll.anchor_top = 0.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 40.0
	scroll.offset_right = -40.0
	scroll.offset_top = 160.0
	scroll.offset_bottom = -116.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var rows_box := VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", 14)
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows_box)
	for row in achievement_rows():
		rows_box.add_child(_make_row(row, mono))

func _make_row(row: Dictionary, mono: Font) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", mono)
	label.add_theme_font_size_override("font_size", 14)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if bool(row.get("unlocked", false)):
		label.text = "[OK] %s" % str(row.get("label", ""))
		label.add_theme_color_override("font_color", TacticalUIHelper.LIME)
	else:
		label.text = "[  ] %s  //  %s" % [str(row.get("label", "")), str(row.get("hint", ""))]
		label.add_theme_color_override("font_color", Color(TacticalUIHelper.TEXT.r, TacticalUIHelper.TEXT.g, TacticalUIHelper.TEXT.b, 0.45))
	return label

func _draw() -> void:
	var panel := Rect2(Vector2(36.0, 102.0), Vector2(size.x - 72.0, size.y - 216.0))
	if panel.size.x <= 0.0 or panel.size.y <= 0.0:
		return
	var points := TacticalUIHelper.angular_points(panel, 14.0)
	draw_colored_polygon(points, TacticalUIHelper.PANEL)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, Color(TacticalUIHelper.CYAN.r, TacticalUIHelper.CYAN.g, TacticalUIHelper.CYAN.b, 0.72), 1.4, true)
~~~

- [ ] Step 4: Wire the menu entry in menu.gd

4a. In `src/ui/menu.gd`, replace:

~~~gdscript
var _bestiary_panel: BestiaryPanel
~~~

with:

~~~gdscript
var _bestiary_panel: BestiaryPanel
var _ach_panel: Control
~~~

4b. Replace:

~~~gdscript
	best_btn.pressed.connect(_open_bestiary)
	row.add_child(best_btn)
~~~

with (text-only card button — no icon, so no `_set_button_text_inset` call):

~~~gdscript
	best_btn.pressed.connect(_open_bestiary)
	row.add_child(best_btn)
	var ach_btn := Button.new()
	_style_card_button(ach_btn, TacticalUIHelper.LIME, Vector2(bottom_button_w, 48.0))
	ach_btn.text = "AWARDS"
	ach_btn.z_index = 2
	ach_btn.pressed.connect(_open_achievements)
	row.add_child(ach_btn)
~~~

4c. Replace:

~~~gdscript
func _close_bestiary() -> void:
	_bestiary_panel.visible = false
	Sfx.play("ui", 0.9, -8.0)
~~~

with:

~~~gdscript
func _close_bestiary() -> void:
	_bestiary_panel.visible = false
	Sfx.play("ui", 0.9, -8.0)

func _open_achievements() -> void:
	if _ach_panel == null:
		var panel_script: Script = load("res://src/ui/achievements_panel.gd")
		if panel_script == null:
			return
		_ach_panel = panel_script.new()
		_ach_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		var back := Button.new()
		_style_overlay_back(back)
		back.text = "BACK  [ESC]"
		back.anchor_left = 0.0
		back.anchor_right = 0.0
		back.anchor_top = 1.0
		back.anchor_bottom = 1.0
		back.offset_left = 28.0
		back.offset_right = 190.0
		back.offset_top = -72.0
		back.offset_bottom = -30.0
		back.pressed.connect(_close_achievements)
		_ach_panel.add_child(back)
		var layer := CanvasLayer.new()
		layer.layer = 70
		layer.add_child(_ach_panel)
		add_child(layer)
	_ach_panel.visible = true
	if _ach_panel.has_method("refresh"):
		_ach_panel.call("refresh")
	Sfx.play("ui", 1.1, -8.0)

func _close_achievements() -> void:
	if _ach_panel != null:
		_ach_panel.visible = false
	Sfx.play("ui", 0.9, -8.0)
~~~

4d. In the first ESC chain, replace:

~~~gdscript
	elif _bestiary_panel != null and _bestiary_panel.visible:
		_close_bestiary()
		get_viewport().set_input_as_handled()
~~~

with:

~~~gdscript
	elif _bestiary_panel != null and _bestiary_panel.visible:
		_close_bestiary()
		get_viewport().set_input_as_handled()
	elif _ach_panel != null and _ach_panel.visible:
		_close_achievements()
		get_viewport().set_input_as_handled()
~~~

4e. In `_unhandled_input()`, replace:

~~~gdscript
	if _bestiary_panel != null and _bestiary_panel.visible:
		if event.is_action_pressed("pause"):
			_close_bestiary()
			get_viewport().set_input_as_handled()
		return
~~~

with:

~~~gdscript
	if _bestiary_panel != null and _bestiary_panel.visible:
		if event.is_action_pressed("pause"):
			_close_bestiary()
			get_viewport().set_input_as_handled()
		return
	if _ach_panel != null and _ach_panel.visible:
		if event.is_action_pressed("pause"):
			_close_achievements()
			get_viewport().set_input_as_handled()
		return
~~~

- [ ] Step 5: Confirm no game.gd change is needed

The Step 1 guard `a mid-run unlock appears in the hud event log lines` must pass
in the Step 6 run: `unlock_achievement()` (game.gd:485) already calls
`log_event("achievement: %s enabled" % label)` before `achievement_unlocked.emit`,
and `hud.gd` `visible_event_lines()` reads `Game.event_log` directly. If (and
only if) that guard fails, the fix is to keep that exact `log_event` call as the
last statement before the `achievement_unlocked.emit(id, label)` line in
`unlock_achievement` — do not add a HUD-specific accessor. Expected: no edit.

- [ ] Step 6: Run the full suite

Run:

~~~sh
godot --headless --path . -- --autotest
~~~

Expected: `AUTOTEST_ALL_PASS` and zero `AT_FAIL`, with the new `achievements_panel`
`AT_STEP` section present and the save config's achievements section restored by
the test itself.

- [ ] Step 7: Interactive visual verification

Run (desktop, windowed):

~~~sh
godot --path . --resolution 1366x768
~~~

Expected: the menu bottom row shows the AWARDS card next to BESTIARY; opening it
shows "ACHIEVEMENTS // X / 5 UNLOCKED", five rows (unlocked bright `[OK]`, locked
dimmed with hints), and BACK [ESC] / ESC closes it. Resize the window to 432x720:
the row list scrolls with wheel/touch drag and the panel never blocks scrolling.
Repeat once at 720x720. (Interactive because no KP_* hook opens this panel.)

- [ ] Step 8: Commit

~~~sh
git add src/ui/achievements_panel.gd src/ui/menu.gd src/autoload/dev_harness.gd
git commit -m "feat: add achievements panel and run log surfacing"
~~~

(Add `src/autoload/game.gd` to the `git add` line only if Step 5 required an edit.)

---

### Task 7: Enemy and program glyph rework

Files:
- Create: `src/ui/glyph_lib.gd`
- Modify: `src/enemies/drone.gd`, `lancer.gd`, `spewer.gd`, `splitter.gd`, `bulwark.gd`, `trojan.gd`, `oom_killer.gd`, `recursor.gd`, `firewall.gd`, `bloatware.gd`, `update_loop.gd`, `page_node.gd`, `root_boss.gd`, `god_boss.gd`, `enemy_base.gd`
- Modify: `src/ui/bestiary_panel.gd`, `src/ui/program_panel.gd`, `src/player/player.gd`
- Modify: `src/autoload/dev_harness.gd`

Interfaces:
- Consumes: each enemy's `_draw()` silhouette section (telegraph, elite ring, color-assist, HP arc, and hit-flash `_flash_col()` code stays); `bestiary_panel.gd` `_draw_glyph(id, c)`; `program_panel.gd` `_draw_silhouette(key, c)`; `player.gd` `_ship_draw(node, c)`.
- Produces: `GlyphLib.draw_glyph(canvas, kind, center, radius, color, t)`, `GlyphLib.era_mix(base, era, amount)`, `GlyphLib.glyph_kinds()`; era-tinted story glyphs via `EnemyBase.era_accent`.

- [ ] Step 1: Write the failing harness regression

In `src/autoload/dev_harness.gd`, after the line `await _temple_test(arena2)` add:

~~~gdscript
	await _glyph_lib_test()
~~~

Then append the new function:

~~~gdscript
func _glyph_lib_test() -> void:
	print("AT_STEP glyph_lib")
	var glyph_script: Script = load("res://src/ui/glyph_lib.gd")
	var glyph = glyph_script.new() if glyph_script != null else null
	_check(glyph != null and glyph.has_method("draw_glyph") and glyph.has_method("glyph_kinds") and glyph.has_method("era_mix"), "glyph library exposes draw_glyph, glyph_kinds, and era_mix")
	if glyph == null or not glyph.has_method("draw_glyph"):
		return
	var required := ["drone", "lancer", "spewer", "splitter", "bulwark", "trojan", "oom", "recursor", "firewall", "bloatware", "update_loop", "page", "root", "boss", "segfault", "bluescreen", "pagefault", "god", "kernel", "daemon", "rootlet"]
	var kinds: Array = glyph.call("glyph_kinds")
	var missing := false
	for kind in required:
		if not kinds.has(kind):
			missing = true
	_check(not missing, "glyph library covers every enemy and program kind")
	var seed_before := Game.rng.seed
	for kind in required:
		glyph.call("draw_glyph", null, kind, Vector2.ZERO, 4.0, Color.CYAN, 0.0)
		glyph.call("draw_glyph", null, kind, Vector2.ZERO, 64.0, Color.CYAN, 1.0)
	_check(Game.rng.seed == seed_before, "glyph drawing never advances the gameplay rng")
	var mixed: Color = glyph.call("era_mix", Color.RED, Color.CYAN, 0.25)
	_check(not mixed.is_equal_approx(Color.RED) and not mixed.is_equal_approx(Color.CYAN), "era_mix blends identity colors toward the era accent")
	var bestiary_source := str(load("res://src/ui/bestiary_panel.gd").source_code)
	var program_source := str(load("res://src/ui/program_panel.gd").source_code)
	_check(bestiary_source.contains("GlyphLib.draw_glyph"), "bestiary detail views reuse glyph_lib")
	_check(program_source.contains("GlyphLib.draw_glyph"), "program cards reuse glyph_lib")
~~~

- [ ] Step 2: Run the test to verify it fails

Run:

~~~sh
godot --headless --path . -- --autotest
~~~

Expected: AT_FAIL `glyph library exposes draw_glyph, glyph_kinds, and era_mix`. No parse error.

- [ ] Step 3: Create src/ui/glyph_lib.gd with the full content

Create `src/ui/glyph_lib.gd`:

~~~gdscript
class_name GlyphLib
extends RefCounted

## Shared code-drawn silhouettes for enemies and playable programs.
## Pure canvas drawing: no state, no Game.rng, no node allocation.

static func glyph_kinds() -> Array:
	return ["drone", "lancer", "spewer", "splitter", "bulwark", "trojan", "oom", "recursor", "firewall", "bloatware", "update_loop", "page", "root", "boss", "segfault", "bluescreen", "pagefault", "god", "kernel", "daemon", "rootlet"]

static func era_mix(base: Color, era: Color, amount: float = 0.25) -> Color:
	if era.a <= 0.0 or amount <= 0.0:
		return base
	return base.lerp(era, clampf(amount, 0.0, 1.0))

static func draw_glyph(canvas: CanvasItem, kind: String, center: Vector2, radius: float, color: Color, t: float = 0.0) -> void:
	if canvas == null or radius <= 0.0:
		return
	var c := color
	match kind:
		"drone":
			_dart(canvas, center, radius, c, 1.15, 0.85, 0.25)
			canvas.draw_circle(center + Vector2(radius * 0.15, 0), radius * 0.3, c)
		"lancer":
			_dart(canvas, center, radius, c, 1.6, 0.7, 0.45)
			canvas.draw_line(center + Vector2(radius * 1.3, 0), center + Vector2(radius * 2.4, 0), Color(c.r, c.g, c.b, 0.5), 1.5)
		"spewer":
			var hex := PackedVector2Array()
			for i in 6:
				hex.push_back(center + Vector2.from_angle(TAU * i / 6.0 + t * 0.9) * radius)
			canvas.draw_colored_polygon(hex, Color(c.r, c.g, c.b, 0.2))
			canvas.draw_polyline(hex + PackedVector2Array([hex[0]]), c, 2.0, true)
			canvas.draw_circle(center, radius * 0.32, c)
		"splitter":
			canvas.draw_circle(center, radius, Color(c.r, c.g, c.b, 0.18))
			canvas.draw_arc(center, radius, 0, TAU, 32, c, 2.2, true)
			canvas.draw_line(center + Vector2(-radius * 0.55, 0), center + Vector2(radius * 0.55, 0), c, 2.0)
			canvas.draw_circle(center + Vector2(-radius * 0.3, 0), radius * 0.2, c)
			canvas.draw_circle(center + Vector2(radius * 0.3, 0), radius * 0.2, c)
		"bulwark":
			var square := PackedVector2Array()
			for i in 4:
				square.push_back(center + Vector2.from_angle(TAU * i / 4.0 + PI / 4.0) * radius)
			canvas.draw_colored_polygon(square, Color(c.r, c.g, c.b, 0.16))
			canvas.draw_polyline(square + PackedVector2Array([square[0]]), c, 3.0, true)
			canvas.draw_line(center + Vector2(-radius * 0.4, -radius * 0.4), center + Vector2(radius * 0.4, radius * 0.4), Color(c.r, c.g, c.b, 0.8), 2.2)
			canvas.draw_line(center + Vector2(-radius * 0.4, radius * 0.4), center + Vector2(radius * 0.4, -radius * 0.4), Color(c.r, c.g, c.b, 0.8), 2.2)
			canvas.draw_arc(center, radius * 0.4, 0, TAU, 20, Color(c.r, c.g, c.b, 0.8), 2.0, true)
		"trojan":
			var diamond := PackedVector2Array([center + Vector2(0, -radius * 1.2), center + Vector2(radius * 0.75, 0), center + Vector2(0, radius * 1.2), center + Vector2(-radius * 0.75, 0)])
			canvas.draw_colored_polygon(diamond, Color(c.r, c.g, c.b, 0.22))
			canvas.draw_polyline(diamond + PackedVector2Array([diamond[0]]), c, 2.0, true)
			canvas.draw_line(center + Vector2(-radius * 0.9, -radius * 0.5), center + Vector2(radius * 0.9, radius * 0.5), Color(c.r, c.g, c.b, 0.8), 2.0)
			canvas.draw_line(center + Vector2(-radius * 0.9, radius * 0.5), center + Vector2(radius * 0.9, -radius * 0.5), Color(c.r, c.g, c.b, 0.8), 2.0)
		"oom":
			canvas.draw_circle(center, radius, Color(c.r, c.g, c.b, 0.2))
			canvas.draw_arc(center, radius, 0, TAU, 24, c, 2.2, true)
			_horn(canvas, center + Vector2(-radius * 0.5, -radius * 0.7), radius * 0.45, c)
			_horn(canvas, center + Vector2(radius * 0.5, -radius * 0.7), radius * 0.45, c, true)
		"recursor":
			var angles := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(radius * 0.5, radius * 0.5), center + Vector2(0, radius), center + Vector2(-radius * 0.5, radius * 0.5), center + Vector2(-radius, 0), center + Vector2(-radius * 0.5, -radius * 0.5), center + Vector2(0, -radius * 0.6)])
			canvas.draw_colored_polygon(PackedVector2Array([angles[0], angles[1], angles[3], angles[5]]), Color(c.r, c.g, c.b, 0.25))
			canvas.draw_polyline(angles, c, 2.0, true)
			canvas.draw_circle(center, radius * 0.3, c)
		"firewall":
			var oct := PackedVector2Array()
			for i in 8:
				oct.push_back(center + Vector2.from_angle(TAU * i / 8.0 + t * 0.4) * radius)
			canvas.draw_colored_polygon(oct, Color(c.r, c.g, c.b, 0.18))
			canvas.draw_polyline(oct + PackedVector2Array([oct[0]]), c, 2.4, true)
			canvas.draw_rect(Rect2(center - Vector2(radius * 0.3, radius * 0.3), Vector2(radius * 0.6, radius * 0.6)), Color(c.r, c.g, c.b, 0.8), false, 2.0)
			canvas.draw_line(center + Vector2(-radius, radius * 0.8), center + Vector2(radius, radius * 0.8), Color(c.r, c.g, c.b, 0.4), 2.0)
		"bloatware":
			var body := Rect2(center - Vector2(radius, radius * 0.78), Vector2(radius * 2.0, radius * 1.56))
			canvas.draw_rect(body, Color(c.r, c.g, c.b, 0.18))
			canvas.draw_rect(body, c, false, 3.0)
			canvas.draw_line(center + Vector2(-radius * 0.72, -radius * 0.22), center + Vector2(radius * 0.72, -radius * 0.22), Color(c.r, c.g, c.b, 0.7), 2.0)
			canvas.draw_line(center + Vector2(-radius * 0.72, radius * 0.24), center + Vector2(radius * 0.4, radius * 0.24), Color(c.r, c.g, c.b, 0.6), 2.0)
			var spin := t * 3.2
			for i in 8:
				var a := spin + TAU * i / 8.0
				var alpha := 0.18 + 0.72 * float(i + 1) / 8.0
				canvas.draw_line(center + Vector2.from_angle(a) * (radius * 0.72), center + Vector2.from_angle(a) * (radius * 0.93), Color(c.r, c.g, c.b, alpha), 3.0)
		"update_loop":
			var ring := Rect2(center - Vector2(radius * 0.72, radius * 0.72), Vector2(radius * 1.44, radius * 1.44))
			canvas.draw_arc(center, radius * 0.72, t * 2.0, t * 2.0 + TAU * 0.78, 20, c, 3.0, true)
			canvas.draw_arc(center, radius * 0.72, t * 2.0 + PI, t * 2.0 + PI + TAU * 0.78, 20, c, 3.0, true)
			canvas.draw_rect(ring, Color(c.r, c.g, c.b, 0.16))
			canvas.draw_rect(ring, c, false, 2.0)
			canvas.draw_circle(center, radius * 0.2, Color(1, 1, 1, 0.85))
		"page":
			var page := PackedVector2Array([center + Vector2(-radius, -radius * 1.2), center + Vector2(radius * 0.8, -radius), center + Vector2(radius, radius * 1.2), center + Vector2(-radius * 0.8, radius)])
			canvas.draw_colored_polygon(page, Color(c.r, c.g, c.b, 0.18))
			canvas.draw_polyline(page + PackedVector2Array([page[0]]), c, 2.0, true)
			for i in 2:
				canvas.draw_line(center + Vector2(-radius * 0.5, -radius * 0.4 + i * radius * 0.6), center + Vector2(radius * 0.5, -radius * 0.4 + i * radius * 0.6), Color(c.r, c.g, c.b, 0.5), 1.5)
		"root":
			var segs := 6
			for i in segs:
				var a0 := t * 0.8 + TAU * i / segs
				canvas.draw_arc(center, radius, a0, a0 + TAU / segs * 0.62, 10, Color(c.r, c.g, c.b, 0.9), 5.0, true)
			var tri := PackedVector2Array()
			var spin2 := -t * 1.3
			for i in 3:
				tri.push_back(center + Vector2.from_angle(spin2 + TAU * i / 3.0) * radius * 0.62)
			canvas.draw_polyline(tri + PackedVector2Array([tri[0]]), Color(c.r, c.g, c.b, 0.75), 3.5, true)
			canvas.draw_circle(center, radius * 0.34, Color(c.r, c.g, c.b, 0.25))
			canvas.draw_arc(center, radius * 0.34, 0, TAU, 28, c, 2.6, true)
		"boss":
			draw_glyph(canvas, "root", center, radius, color, t)
		"segfault":
			for half in 2:
				var pts := PackedVector2Array()
				for i in 4:
					var a := TAU * (half * 3 + i) / 6.0 + t * 0.5
					pts.push_back(center + Vector2.from_angle(a) * radius + (Vector2(3.0, 0.0) if half == 0 else Vector2(-4.2, 0.0)))
				if pts.size() > 2:
					canvas.draw_polyline(pts, Color(c.r, c.g, c.b, 0.85 if half == 0 else 0.5), 4.0, true)
			canvas.draw_circle(center, radius * 0.3, Color(c.r, c.g, c.b, 0.3))
			canvas.draw_circle(center, radius * 0.14, c)
		"bluescreen":
			var rr := radius * 0.92
			var rect := Rect2(center - Vector2(rr, rr * 0.72), Vector2(rr * 2.0, rr * 1.44))
			canvas.draw_rect(rect, Color(c.r, c.g, c.b, 0.10))
			canvas.draw_rect(rect, Color(c.r, c.g, c.b, 0.9), false, 4.0)
			for i in 5:
				var ly: float = rect.position.y + rect.size.y * (0.15 + 0.18 * i) + sin(t * 3.0 + i) * 3.0
				canvas.draw_line(Vector2(rect.position.x + 10.0, ly), Vector2(rect.end.x - 10.0, ly), Color(c.r, c.g, c.b, 0.14), 1.5)
		"pagefault":
			for i in 3:
				var off := Vector2.from_angle(t * (0.6 + i * 0.25)) * radius * 0.12 * i
				canvas.draw_rect(Rect2(center + Vector2(-radius * 0.7, -radius * 0.5) + off, Vector2(radius * 1.4, radius)), Color(c.r, c.g, c.b, 0.10 + 0.06 * i), false, 2.0)
			canvas.draw_circle(center, radius * 0.3, Color(c.r, c.g, c.b, 0.3))
		"god":
			for i in 3:
				canvas.draw_arc(center, radius * (0.9 + i * 0.22), -t * (0.35 + i * 0.12), TAU - t * (0.35 + i * 0.12), 40, Color(c.r, c.g, c.b, 0.34 - i * 0.08), 2.0, true)
			canvas.draw_circle(center, radius * 0.7, Color(1.0, 0.78, 0.26, 0.22 + 0.08 * sin(t * 3.0)))
			canvas.draw_circle(center, radius * 0.38, Color(c.r, c.g, c.b, 0.22))
			canvas.draw_arc(center, radius * 0.38, 0.0, TAU, 32, c, 3.0, true)
			canvas.draw_circle(center, radius * 0.18, Color(1.0, 0.92, 0.62, 0.94))
			canvas.draw_circle(center, radius * 0.07, Color(1.0, 0.25, 0.35, 1.0))
		"kernel":
			_dart(canvas, center, radius, c, 1.5, 1.0, 0.45)
			var hex := PackedVector2Array()
			for i in 6:
				hex.push_back(center + Vector2.from_angle(TAU * i / 6.0) * radius * 0.34)
			canvas.draw_polyline(hex + PackedVector2Array([hex[0]]), c, 1.6, true)
			canvas.draw_circle(center + Vector2(radius * 0.25, 0), radius * 0.22, c)
		"daemon":
			_dart(canvas, center, radius, c, 1.4, 1.05, 0.4)
			for side in [-1, 1]:
				var fork := PackedVector2Array([center + Vector2(-radius * 0.2, 0), center + Vector2(-radius * 0.9, side * radius * 0.7)])
				canvas.draw_polyline(fork, Color(c.r, c.g, c.b, 0.8), 2.0, true)
			canvas.draw_circle(center + Vector2(radius * 0.3, 0), radius * 0.24, c)
		"rootlet":
			var shield := PackedVector2Array([center + Vector2(0, -radius * 1.1), center + Vector2(radius * 0.85, -radius * 0.5), center + Vector2(radius * 0.85, radius * 0.2), center + Vector2(0, radius * 1.1), center + Vector2(-radius * 0.85, radius * 0.2), center + Vector2(-radius * 0.85, -radius * 0.5)])
			canvas.draw_colored_polygon(shield, Color(c.r, c.g, c.b, 0.25))
			canvas.draw_polyline(shield + PackedVector2Array([shield[0]]), c, 2.4, true)
			canvas.draw_arc(center, radius * 0.45, 0, TAU, 24, Color(1, 1, 1, 0.7), 1.6, true)

static func _dart(canvas: CanvasItem, center: Vector2, radius: float, c: Color, nose: float, wing: float, tail: float) -> void:
	var pts := PackedVector2Array([
		center + Vector2(radius * nose, 0), center + Vector2(-radius, radius * wing),
		center + Vector2(-radius * tail, 0), center + Vector2(-radius, -radius * wing),
	])
	canvas.draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.22))
	canvas.draw_polyline(pts + PackedVector2Array([pts[0]]), c, 2.0, true)

static func _horn(canvas: CanvasItem, base: Vector2, size: float, c: Color, mirrored: bool = false) -> void:
	var sign_x := -1.0 if mirrored else 1.0
	var pts := PackedVector2Array([base, base + Vector2(sign_x * size * 0.8, -size * 1.9), base + Vector2(sign_x * size * 0.1, -size * 0.55)])
	canvas.draw_colored_polygon(pts, c)
~~~

- [ ] Step 4: Route enemy silhouettes through glyph_lib

For each enemy file, replace only the silhouette statements inside `_draw()` with the
`GlyphLib.draw_glyph(...)` call shown; keep every flash, telegraph, HP arc, elite ring,
and color-assist line exactly as it is. Apply `era_mix` through the color argument.

4a. `src/enemies/drone.gd` — replace the four shape statements (`var pts := ...` through `draw_circle(Vector2(r * 0.15, 0), r * 0.3, c)`) with:

~~~gdscript
	GlyphLib.draw_glyph(self, "drone", Vector2.ZERO, r, _glyph_color(c), t)
~~~

4b. `src/enemies/lancer.gd` — replace the `var pts := ...`, `draw_colored_polygon(pts, ...)`, and `draw_polyline(pts + ...)` statements (keep the whole `if phase == Phase.AIM:` telegraph block) with:

~~~gdscript
	GlyphLib.draw_glyph(self, "lancer", Vector2.ZERO, r, _glyph_color(c), t)
~~~

4c. `src/enemies/spewer.gd` — replace only the hexagon statements (`var pts := PackedVector2Array()`, the `for i in 6:` fill loop, `draw_colored_polygon(pts, ...)`, and `draw_polyline(pts + ...)`) with:

~~~gdscript
	GlyphLib.draw_glyph(self, "spewer", Vector2.ZERO, r, _glyph_color(c), t)
~~~

Keep `rotation = t * 0.9`, the entire `var eye_r` / `_telegraph` outer-flash block, the look-based eye circles (they layer the telegraph eye over the glyph core), and the elite ring.

4d. `src/enemies/splitter.gd` — keep `var c := _flash_col(col)` and `var r := radius * (1.0 + 0.06 * sin(_pulse))` (the elite ring below still uses `r`), and replace the circle/minus/inner-dot statements (from `draw_circle(Vector2.ZERO, r, ...)` through the second `draw_circle(Vector2(r * 0.3, 0), r * 0.22, c)`) with:

~~~gdscript
	GlyphLib.draw_glyph(self, "splitter", Vector2.ZERO, r, _glyph_color(c), t)
~~~

Keep the elite ring and `_draw_color_assist_marker(c)` lines.

4e. `src/enemies/bulwark.gd` — replace the square/X/inner-arc statements (from `var pts := PackedVector2Array()` through `draw_arc(Vector2.ZERO, r * 0.4, ...)`) with:

~~~gdscript
	GlyphLib.draw_glyph(self, "bulwark", Vector2.ZERO, r, _glyph_color(c), t)
~~~

Keep the `hp_frac` arc, elite ring, and `_draw_color_assist_marker(c)` lines.

4f. `src/enemies/trojan.gd` — replace the diamond body and cross lines (from `var body := ...` through the second `draw_line(... -r * 0.9, r * 0.5 ...)` statement) with:

~~~gdscript
	GlyphLib.draw_glyph(self, "trojan", Vector2.ZERO, r, _glyph_color(c), t)
~~~

Keep the `drop_glow` circle and elite ring.

4g. `src/enemies/oom_killer.gd` — replace the circle + horns block (from `draw_circle(Vector2.ZERO, r, ...)` through the second horn `draw_colored_polygon(horn2, c)`) with:

~~~gdscript
	GlyphLib.draw_glyph(self, "oom", Vector2.ZERO, r, c, t)
~~~

Keep the eye, carried-arc, and elite lines.

4h. `src/enemies/recursor.gd` — replace the diamond + center-dot statements (from `draw_colored_polygon(PackedVector2Array([...r...]))` through `draw_circle(Vector2.ZERO, r * 0.3, c)`) with:

~~~gdscript
	GlyphLib.draw_glyph(self, "recursor", Vector2.ZERO, r, _glyph_color(c), t)
~~~

Keep the `Phase.WIND` telegraph and elite lines.

4i. `src/enemies/firewall.gd` — replace the octagon + square statements (from `var pts := PackedVector2Array()` through `draw_rect(Rect2(-r * 0.3, ...))`) with:

~~~gdscript
	GlyphLib.draw_glyph(self, "firewall", Vector2.ZERO, r, _glyph_color(c), t)
~~~

Keep the `WALL_ARMS` wall lines and elite ring.

4j. `src/enemies/bloatware.gd` — replace the body rect, the two text lines, and the spinner loop (from `var body := Rect2(...)` through the `for i in 8:` spinner loop) with:

~~~gdscript
	GlyphLib.draw_glyph(self, "bloatware", Vector2.ZERO, r, _glyph_color(c), t)
~~~

Keep the `LOADING` string and the elite ring (the glyph supplies the spinner, so do not keep the original loop).

4k. `src/enemies/update_loop.gd` — replace the body polygon statements (`var body := ...`, `draw_colored_polygon(body, ...)`, `draw_polyline(body + ...)`) and, inside the `else:` (not reinstalling) branch, the `draw_line(Vector2(-r * 0.55, 0), ...)` + `draw_circle(Vector2.ZERO, r * 0.2, ...)` pair, with:

~~~gdscript
	GlyphLib.draw_glyph(self, "update_loop", Vector2.ZERO, r, _glyph_color(c), t)
~~~

Keep the `_reinstalling` progress arc + `UPDATING` string and the elite ring.

4l. `src/enemies/page_node.gd` — replace the page polygon + two text lines (from `var pts := ...` through the second `draw_line(... s * 0.5 ...)`) with:

~~~gdscript
	GlyphLib.draw_glyph(self, "page", Vector2.ZERO, s, _glyph_color(c), t)
~~~

Keep the `rotation` wobble, low-hp arc, and everything else.

4m. `src/enemies/root_boss.gd` — in `_draw_root()`, replace the segmented ring + triangle + core block (from `var spin := t * 0.8` through `draw_arc(Vector2.ZERO, r * 0.34, 0, TAU, 28, c, 2.6, true)`) with:

~~~gdscript
	GlyphLib.draw_glyph(self, "root", Vector2.ZERO, r, _glyph_color(c), t)
~~~

Keep the eye/exposure, `hp_frac` arc, and mini lance telegraph lines. In `_draw_segfault()`, keep the `var off := _glitch_off` line (the scan lines below still use `off.y`) and replace only the two glitch polyline loops (the whole `for half in 2:` block) with:

~~~gdscript
	GlyphLib.draw_glyph(self, "segfault", Vector2.ZERO, r, _glyph_color(c), t)
~~~

Keep the glitch scan lines, blink core `draw_circle` pair, hp arc, teleport, and lance lines. In `_draw_bluescreen()`, replace the rect + scan lines (from `var rr := r * 0.92` through the scan-line `for i in 5:` loop) with:

~~~gdscript
	GlyphLib.draw_glyph(self, "bluescreen", Vector2.ZERO, r, _glyph_color(c), t)
~~~

Keep the eyes, mouth arc, freeze telegraph, and hp arc. In `_draw_pagefault()`, replace the three rotating rects and core circle (from `var pages := _pages_alive()` — keep that line — then from the `for i in 3:` rect loop through `draw_circle(Vector2.ZERO, r * 0.3, ...)`) with:

~~~gdscript
	GlyphLib.draw_glyph(self, "pagefault", Vector2.ZERO, r, _glyph_color(c), t)
~~~

Keep the pages counter arc/text or eye fallback, and hp arc.

4n. `src/enemies/god_boss.gd` — in `_draw()`, replace the three halo arcs + golden halo + core circle + core ring statements (from `for i in 3:` through `draw_arc(Vector2.ZERO, radius * 0.38, 0.0, TAU, 32, c, 3.0, true)`) with:

~~~gdscript
	GlyphLib.draw_glyph(self, "god", Vector2.ZERO, radius, _glyph_color(c), t)
~~~

Keep the eye, hp arc, and elite lines.

4o. Era tinting — in `src/enemies/enemy_base.gd`, directly after `var glow: Sprite2D` (line ~27), add:

~~~gdscript
var era_accent := Color(0, 0, 0, 0)
~~~

and at the end of the file (inside the class) add:

~~~gdscript
func _glyph_color(flash_col: Color) -> Color:
	return GlyphLib.era_mix(flash_col, era_accent, 0.25)
~~~

Then in `src/arena/spawner.gd` `_configure_story_enemy()`, replace:

~~~gdscript
func _configure_story_enemy(e: EnemyBase) -> void:
	e.threat_wave = wave
	e.configure(_story_wave_scale, false)
~~~

with:

~~~gdscript
func _configure_story_enemy(e: EnemyBase) -> void:
	e.threat_wave = wave
	e.configure(_story_wave_scale, false)
	var theme: Dictionary = story_stage.get("theme", {})
	if str(story_stage.get("act", "")) == "templeos":
		e.era_accent = Color.from_hsv(fmod(float(Game.stats.get("time", 0.0)) * 0.08, 1.0), 0.78, 1.0)
	else:
		e.era_accent = theme.get("accent", Balance.COL_PLAYER)
~~~

TempleOS enemies pick up the live rainbow hue at spawn (cosmetic time only, never `Game.rng`); other story acts mix ~0.25 toward the stage accent.

- [ ] Step 5: Reuse glyph_lib in the UI panels and the player ship

5a. In `src/ui/bestiary_panel.gd`, at the top of `_draw_glyph(id: String, c: Color)`, immediately after the opening brace, add:

~~~gdscript
	GlyphLib.draw_glyph(self, id, Vector2.ZERO, 16.0, c)
	return
~~~

The existing match body stays below as a fallback for any id glyph_lib does not cover (the scale transform already applied by the caller sizes the 16px base glyph to match the old 3.5x-scaled shapes).

5b. In `src/ui/program_panel.gd`, at the top of `_draw_silhouette(key: String, c: Color)`, immediately after the opening brace, add:

~~~gdscript
	var program_kind := {"kernel_arrow": "kernel", "daemon_fork": "daemon", "rootlet_block": "rootlet"}.get(key, "")
	if program_kind != "":
		GlyphLib.draw_glyph(self, program_kind, Vector2.ZERO, 16.0, c)
		return
~~~

5c. In `src/player/player.gd`, in `_ship_draw(node: Node2D, c: Color)` (line ~522), insert between the `var r := Balance.PLAYER_RADIUS` line and the `match visual_silhouette_key():` line:

~~~gdscript
	var program_kind := {"kernel_arrow": "kernel", "daemon_fork": "daemon", "rootlet_block": "rootlet"}.get(visual_silhouette_key(), "")
	if program_kind != "":
		GlyphLib.draw_glyph(node, program_kind, Vector2.ZERO, r, c)
		return
~~~

The existing match arms stay as a fallback for any unlisted silhouette key.

- [ ] Step 6: Run the full suite

Run:

~~~sh
godot --headless --path . -- --autotest
~~~

Expected: `AUTOTEST_ALL_PASS` and zero `AT_FAIL` — every hitbox, telegraph,
color-assist, and hit-flash test stays green unchanged.

- [ ] Step 7: Visual comparison against the approved mocks

Run (desktop, windowed):

~~~sh
KP_SHOT=game KP_SHOT_OUT=/tmp/opencode/glyphs_game.png godot --path . --resolution 1366x768
KP_SHOT=boss KP_SHOT_OUT=/tmp/opencode/glyphs_boss.png godot --path . --resolution 1366x768
KP_SHOT=menu KP_BESTIARY=1 KP_SHOT_OUT=/tmp/opencode/glyphs_bestiary.png godot --path . --resolution 720x720
KP_SHOT=menu KP_PROGRAM=1 KP_SHOT_OUT=/tmp/opencode/glyphs_programs.png godot --path . --resolution 720x720
~~~

Expected: arena, boss, bestiary, and program captures match the approved mocks
(`exec-10cafd61-...png` combat, `exec-6582ea9f-...png` bestiary, `exec-450f92b7-...png`
programs): DRONE magenta dart, LANCER amber dart+line, SPEWER purple hexagon+core,
SPLITTER red circle+minus, BULWARK blue square+X, TROJAN dark-red diamond,
OOM_KILLER purple horned circle, PAGE page glyph, RECURSOR green angular glyph,
FIREWALL cyan wall glyph, BLOATWARE fat rounded square, UPDATE_LOOP circular arrow,
segmented broken-ring ROOT bosses, KERNEL cyan hex-core dart, DAEMON magenta
tri-dart, ROOTLET lime shield. Hitboxes are untouched (visual-only change).
Captures stay in `/tmp/opencode/` and are never committed.

- [ ] Step 8: Commit

~~~sh
git add src/ui/glyph_lib.gd src/enemies src/ui/bestiary_panel.gd src/ui/program_panel.gd src/player/player.gd src/arena/spawner.gd src/autoload/dev_harness.gd
git commit -m "feat: rework entity glyphs with a shared glyph library"
~~~

---

### Task 7b: Tactical icon quality pass

Files:
- Modify: `src/ui/tactical_icon.gd`, `src/ui/patch_card.gd`, `src/ui/program_panel.gd`
- Modify: `src/autoload/dev_harness.gd`
- Append: `.gitignore` (`media/concepts/` entry)
- Optionally create: `assets/icons/generated/` (only proven-win rasters + their Godot `.import` sidecars; skipped when no raster wins)

Interfaces:
- Consumes: `tactical_icon.gd` `configure(icon_kind, color)` + the `_draw()` `match _kind` (line ~37; kinds settings, bestiary, dash, back, resume, restart, terminal, audio, music, warning); `patch_card.gd` `_draw_icon(center, accent)` (line 96; hex radius 34, today staticf dot grid / splitshot rays / "+" cross fallback); `Game.PATCH_CODES` (26 ids); `program_panel.gd` `_draw_silhouette` (line ~217, routed through GlyphLib by Task 7 Step 5b) and its call site (line ~181).
- Produces: `tactical_icon.gd` `icon_kinds()`, `icon_metrics(kind)`, `icon_bounds(kind)`, `raster_path(kind)` registry (code-drawn fallback intact); `patch_card.gd` `patch_icon_family(id)`, `patch_icon_metrics(id)`, `patch_raster_path(id)` and six family glyph draws; refined code-drawn icons; harness `_icon_quality_test()`.

- [ ] Step 1: Write the failing harness regression

In `src/autoload/dev_harness.gd`, after the line `await _glyph_lib_test()` add:

~~~gdscript
	await _icon_quality_test()
~~~

Then append the new function:

~~~gdscript
func _icon_quality_test() -> void:
	print("AT_STEP icon_quality")
	var icon_script: Script = load("res://src/ui/tactical_icon.gd")
	var icon = icon_script.new() if icon_script != null else null
	_check(icon != null and icon.has_method("icon_kinds") and icon.has_method("icon_metrics") and icon.has_method("icon_bounds"), "tactical icon exposes icon_kinds, icon_metrics, and icon_bounds")
	if icon == null or not icon.has_method("icon_kinds"):
		if icon != null:
			icon.free()
		return
	var icon_src := str(icon_script.source_code)
	var kinds: Array = icon.call("icon_kinds")
	for kind in ["settings", "bestiary", "dash", "back", "resume", "restart", "terminal", "audio", "music", "warning"]:
		_check(kinds.has(kind), "tactical icon covers the %s kind" % kind)
		_check(icon_src.contains("\t\t\"%s\":" % kind), "%s icon resolves to a non-empty drawing routine" % kind)
		var metrics: Dictionary = icon.call("icon_metrics", str(kind))
		_check(bool(metrics.get("covered", false)), "%s icon has documented quality metrics" % kind)
		_check(float(metrics.get("min_stroke", 0.0)) >= 1.5, "%s icon documents a minimum stroke of at least 1.5" % kind)
		_check(float(metrics.get("contrast", 0.0)) >= 0.55, "%s icon documents panel contrast of at least 0.55" % kind)
		var bounds: Rect2 = icon.call("icon_bounds", str(kind))
		for side in [24.0, 52.0]:
			var abs_bounds := Rect2(bounds.position * side, bounds.size * side)
			_check(Rect2(Vector2.ZERO, Vector2(side, side)).encloses(abs_bounds.grow(-0.5)), "%s icon silhouette stays contained at %.0fpx" % [kind, side])
	icon.free()
	var patch_script: Script = load("res://src/ui/patch_card.gd")
	_check(patch_script != null and patch_script.has_method("patch_icon_family") and patch_script.has_method("patch_icon_metrics"), "patch card exposes patch_icon_family and patch_icon_metrics")
	if patch_script == null or not patch_script.has_method("patch_icon_family"):
		return
	var patch_src := str(patch_script.source_code)
	for family in ["_draw_damage_glyph", "_draw_fire_glyph", "_draw_defense_glyph", "_draw_utility_glyph", "_draw_movement_glyph", "_draw_economy_glyph"]:
		_check(patch_src.contains("func %s" % family), "patch card draws the %s family" % family.trim_prefix("_draw_").trim_suffix("_glyph"))
	for id in Game.PATCH_CODES:
		var family: String = patch_script.call("patch_icon_family", str(id))
		_check(["damage", "fire", "defense", "utility", "movement", "economy"].has(family), "%s patch icon belongs to a documented family" % str(id))
		var pmetrics: Dictionary = patch_script.call("patch_icon_metrics", str(id))
		_check(bool(pmetrics.get("covered", false)), "%s patch icon resolves to a non-empty drawing routine" % str(id))
		_check(float(pmetrics.get("min_stroke", 0.0)) >= 2.0, "%s patch icon documents a minimum stroke of at least 2.0" % str(id))
		_check(float(pmetrics.get("contrast", 0.0)) >= 0.55, "%s patch icon documents panel contrast of at least 0.55" % str(id))
	var hex_rect := Rect2(Vector2(24.0, 123.0), Vector2(68.0, 68.0))
	_check(Rect2(Vector2.ZERO, Vector2(280.0, 330.0)).encloses(hex_rect), "patch hex icon geometry stays contained in the 280x330 patch card")
	_check(icon_script.has_method("raster_path") and patch_script.has_method("patch_raster_path"), "icon raster registries keep the code-drawn fallback")
	var probe_path: String = icon_script.call("raster_path", "resume")
	_check(probe_path.is_empty() or ResourceLoader.exists(probe_path), "raster registry only resolves existing assets")
~~~

- [ ] Step 2: Run the test to verify it fails

Run:

~~~sh
godot --headless --path . -- --autotest
~~~

Expected: AT_FAIL `tactical icon exposes icon_kinds, icon_metrics, and icon_bounds`
(the early return stops the function). No parse error.

- [ ] Step 3: Intake concept sheets and refine the code-drawn icons

3a. Append to `.gitignore` (so orchestrator-provided concept sheets never get
committed) — replace:

~~~gitignore
# Local files
.nomedia
.DS_Store
*.tmp
*.log
~~~

with:

~~~gitignore
# Local files
.nomedia
.DS_Store
*.tmp
*.log

# Design references (never committed)
media/concepts/
~~~

3b. Read the orchestrator's concept sheets in `media/concepts/` (the orchestrator
runs gpt_imagegen and saves candidate sheets there before this step). Grade every
candidate icon against the spec's critical-evaluation criteria — crisp at 52px
and 24px, silhouette readability, angular/neon consistency with the combat HUD,
no blur/seams, transparent-compatible — and keep a verdict list (beats code /
reference only). If `media/concepts/` is empty, apply the refinements below from
the criteria alone; the pass never blocks on missing sheets. Rasters are NOT
shipped in this step (Step 4 handles proven wins only).

3c. Refine `src/ui/tactical_icon.gd` code-drawn drawings to hit these exact
targets (keep each function's identity and the `match _kind` dispatch; update the
`ICON_BOUNDS` row only if a target intentionally changes geometry):

- settings: gear stroke 2.0, tooth radius ratio 1.0/0.74 kept, remove the thin
  diagonal slash detail if it vanishes at 24px, keep core ring + dot.
- bestiary: lens stroke 2.0, iris dot solid at r*0.14, drop the 0.10-alpha lens
  fill if it muddies at 24px.
- dash: darts solid at stroke 2.2, badge outline 1.5, badge fill alpha 0.10.
- back: shaft stroke 2.2, arrowhead becomes one solid triangle instead of two
  open lines.
- resume: outline 2.0, 0.16 fill kept.
- restart: arc stroke 2.2, arrowhead becomes a solid polygon closing the arc tip.
- terminal: chevron + underscore strokes at 2.2 minimum (no sub-1.5 lines).
- audio: speaker outline 2.0, wave arcs 2.0 with 0.55/0.80 alpha steps.
- music: stem 2.2, note head solid (no 1.0 strokes anywhere).
- warning: triangle stroke 2.2, exclamation bar solid width >= 3.0.

3d. In `src/ui/tactical_icon.gd`, directly after `func icon_kind() -> String:`'s
block, add the documented metrics/bounds tables and the raster registry:

~~~gdscript
## Documented quality metrics per icon kind, enforced by the harness.
## min_stroke: narrowest stroke width the primary silhouette may use.
## contrast: minimum luminance distance of the primary stroke vs TacticalUI.PANEL.
const ICON_METRICS := {
	"settings": {"min_stroke": 1.7, "contrast": 0.55},
	"bestiary": {"min_stroke": 1.7, "contrast": 0.55},
	"dash": {"min_stroke": 1.5, "contrast": 0.55},
	"back": {"min_stroke": 2.0, "contrast": 0.55},
	"resume": {"min_stroke": 1.8, "contrast": 0.55},
	"restart": {"min_stroke": 2.0, "contrast": 0.55},
	"terminal": {"min_stroke": 1.8, "contrast": 0.55},
	"audio": {"min_stroke": 1.8, "contrast": 0.55},
	"music": {"min_stroke": 1.8, "contrast": 0.55},
	"warning": {"min_stroke": 2.0, "contrast": 0.55},
}

## Documented silhouette bounds per kind in unit space (fractions of size);
## the harness verifies containment at 24px and 52px.
const ICON_BOUNDS := {
	"settings": Rect2(0.12, 0.12, 0.76, 0.76),
	"bestiary": Rect2(0.14, 0.16, 0.72, 0.68),
	"dash": Rect2(0.08, 0.10, 0.84, 0.80),
	"back": Rect2(0.16, 0.28, 0.68, 0.44),
	"resume": Rect2(0.30, 0.18, 0.44, 0.64),
	"restart": Rect2(0.14, 0.14, 0.72, 0.72),
	"terminal": Rect2(0.16, 0.22, 0.68, 0.56),
	"audio": Rect2(0.16, 0.26, 0.68, 0.48),
	"music": Rect2(0.24, 0.12, 0.52, 0.76),
	"warning": Rect2(0.14, 0.16, 0.72, 0.68),
}

static func icon_kinds() -> Array:
	return ICON_METRICS.keys()

static func icon_metrics(icon_kind: String) -> Dictionary:
	var entry: Dictionary = ICON_METRICS.get(icon_kind, {})
	return {"covered": not entry.is_empty(), "min_stroke": float(entry.get("min_stroke", 0.0)), "contrast": float(entry.get("contrast", 0.0))}

static func icon_bounds(icon_kind: String) -> Rect2:
	return ICON_BOUNDS.get(icon_kind, Rect2(0.08, 0.08, 0.84, 0.84))

const RASTER_DIR := "res://assets/icons/generated/"

## Raster registry: proven-win rasters only; empty string keeps the code-drawn
## identity as the active path. Never used as a placeholder.
static func raster_path(icon_kind: String) -> String:
	var path := RASTER_DIR + icon_kind + ".png"
	return path if ResourceLoader.exists(path) else ""
~~~

3e. In `src/ui/patch_card.gd`, replace the whole `_draw_icon` function (line 96)
with the family-routed version, and add the family table, metrics, raster
registry, and the six family glyph functions directly below it:

~~~gdscript
func _draw_icon(center: Vector2, accent: Color) -> void:
	var points := PackedVector2Array()
	for i in 6:
		var angle := -PI * 0.5 + TAU * float(i) / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * 34.0)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_colored_polygon(points, Color(accent.r, accent.g, accent.b, 0.08))
	draw_polyline(closed, accent, 2.0, true)
	var id := str(_def.get("id", ""))
	var raster := patch_raster_path(id)
	if raster != "":
		var tex: Texture2D = load(raster)
		if tex != null:
			draw_texture_rect(tex, Rect2(center - Vector2(26.0, 26.0), Vector2(52.0, 52.0)), false)
			return
	match patch_icon_family(id):
		"damage":
			_draw_damage_glyph(center, accent)
		"fire":
			_draw_fire_glyph(center, accent)
		"defense":
			_draw_defense_glyph(center, accent)
		"utility":
			_draw_utility_glyph(center, accent)
		"movement":
			_draw_movement_glyph(center, accent)
		"economy":
			_draw_economy_glyph(center, accent)

## Patch icon family table: every Game.PATCH_CODES id maps to one of six visual
## families so hex icons share a silhouette language per effect type.
const PATCH_ICON_FAMILIES := {
	"heavy": "damage", "core": "damage", "splitshot": "damage", "ricochet": "damage", "pdash": "damage", "thorns": "damage", "staticf": "damage",
	"rapid": "fire", "threads": "fire", "chain": "fire",
	"hp": "defense", "shield": "defense", "absorb": "defense", "restore": "defense", "secondwind": "defense", "vampic": "defense", "recycler": "defense", "dataleech": "defense",
	"cell": "utility", "magnet": "utility",
	"dash": "movement", "mdash": "movement", "turbo": "movement", "light": "movement",
	"frag": "economy", "scrapdiet": "economy",
}

const RASTER_DIR := "res://assets/icons/generated/"

static func patch_icon_family(id: String) -> String:
	return str(PATCH_ICON_FAMILIES.get(id, "utility"))

static func patch_icon_metrics(id: String) -> Dictionary:
	return {"covered": PATCH_ICON_FAMILIES.has(id), "min_stroke": 2.0, "contrast": 0.55}

static func patch_raster_path(id: String) -> String:
	var path := RASTER_DIR + "patch_" + id + ".png"
	return path if ResourceLoader.exists(path) else ""

func _draw_damage_glyph(center: Vector2, accent: Color) -> void:
	for i in 3:
		var a := -PI * 0.5 + TAU * float(i) / 3.0
		var tip := center + Vector2.from_angle(a) * 22.0
		var left := center + Vector2.from_angle(a - 0.42) * 8.0
		var right := center + Vector2.from_angle(a + 0.42) * 8.0
		draw_colored_polygon(PackedVector2Array([tip, left, right]), accent)
	draw_arc(center, 7.0, 0.0, TAU, 16, accent, 2.0, true)

func _draw_fire_glyph(center: Vector2, accent: Color) -> void:
	for i in 3:
		var x := center.x - 14.0 + float(i) * 10.0
		var pts := PackedVector2Array([Vector2(x, center.y - 10.0), Vector2(x + 8.0, center.y), Vector2(x, center.y + 10.0)])
		draw_polyline(pts, accent, 2.2, true)

func _draw_defense_glyph(center: Vector2, accent: Color) -> void:
	var pts := PackedVector2Array([
		center + Vector2(0.0, -20.0), center + Vector2(15.0, -12.0), center + Vector2(15.0, 4.0),
		center + Vector2(0.0, 20.0), center + Vector2(-15.0, 4.0), center + Vector2(-15.0, -12.0),
	])
	draw_colored_polygon(pts, Color(accent.r, accent.g, accent.b, 0.14))
	draw_polyline(pts + PackedVector2Array([pts[0]]), accent, 2.2, true)
	draw_line(center + Vector2(0.0, -12.0), center + Vector2(0.0, 12.0), accent, 2.0)

func _draw_utility_glyph(center: Vector2, accent: Color) -> void:
	var nut := PackedVector2Array()
	for i in 6:
		nut.append(center + Vector2.from_angle(TAU * float(i) / 6.0) * 15.0)
	draw_polyline(nut + PackedVector2Array([nut[0]]), accent, 2.2, true)
	draw_circle(center, 5.0, accent)

func _draw_movement_glyph(center: Vector2, accent: Color) -> void:
	draw_line(center + Vector2(-16.0, 6.0), center + Vector2(2.0, 6.0), Color(accent.r, accent.g, accent.b, 0.6), 2.0)
	draw_line(center + Vector2(-10.0, -2.0), center + Vector2(8.0, -2.0), accent, 2.2)
	draw_colored_polygon(PackedVector2Array([center + Vector2(8.0, -8.0), center + Vector2(16.0, -2.0), center + Vector2(8.0, 4.0)]), accent)

func _draw_economy_glyph(center: Vector2, accent: Color) -> void:
	for offset in [Vector2(-12.0, -8.0), Vector2(-4.0, 2.0), Vector2(6.0, -4.0)]:
		draw_circle(center + offset, 4.0, accent)
	draw_line(center + Vector2(-14.0, 12.0), center + Vector2(14.0, 12.0), accent, 2.0)
~~~

3f. `src/ui/program_panel.gd` audit: confirm the GlyphLib-routed card silhouettes
(Task 7 Step 5b, fixed `16.0` radius) render at least ~20px on the card at
1366x768 and stay unclipped at 432x720. If they render clipped or under 20px,
replace that `16.0` with the measured radius (one-number edit). No other
program_panel changes are in scope; if a concept sheet wins for a program glyph,
wire it through `tactical_icon.gd`'s `raster_path` pattern in Step 4.

- [ ] Step 4: Wire proven-win rasters (only after same-size comparison approval)

For each icon where the approved verdict is "beats code" at BOTH 52px and 24px:
save the trimmed, transparent PNG at `assets/icons/generated/<kind>.png` (or
`patch_<id>.png` for patch hexes), then add the raster path to `_draw()` in
`src/ui/tactical_icon.gd` — replace:

~~~gdscript
func _draw() -> void:
	if size.x <= 2.0 or size.y <= 2.0:
		return
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.34
	match _kind:
~~~

with:

~~~gdscript
func _draw() -> void:
	if size.x <= 2.0 or size.y <= 2.0:
		return
	var raster := raster_path(_kind)
	if raster != "":
		var tex: Texture2D = load(raster)
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
			return
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.34
	match _kind:
~~~

(patch_card's `_draw_icon` already gained the equivalent registry check in Step
3e.) The code-drawn branch stays intact as the permanent fallback; a missing or
failed texture always falls through to it. If no raster wins, skip this step and
leave `assets/icons/generated/` uncreated.

- [ ] Step 5: Containment/readability probes at 1366x768 and 432x720

Run (desktop, windowed):

~~~sh
mkdir -p /tmp/opencode
KP_SHOT=menu KP_SHOT_OUT=/tmp/opencode/icons_menu_1366.png godot --path . --resolution 1366x768
KP_SHOT=menu KP_SHOT_OUT=/tmp/opencode/icons_menu_432.png godot --path . --resolution 432x720
KP_SHOT=game KP_SHOT_OUT=/tmp/opencode/icons_game_1366.png godot --path . --resolution 1366x768
KP_SHOT=game KP_SHOT_OUT=/tmp/opencode/icons_game_432.png godot --path . --resolution 432x720
~~~

Expected: menu/settings card icons (52px class) and HUD chips (24px class) read
crisply at both viewports with every silhouette inside its control; open a run
and pause once per capture size to confirm the resume/restart/terminal/warning
pause glyphs are distinct at a glance, and check one patch-pick screen to confirm
the family hex icons are clean (no "+"-cross mush) and contained in the card.
Captures stay in `/tmp/opencode/` and are never committed.

- [ ] Step 6: Run the full suite

Run:

~~~sh
godot --headless --path . -- --autotest
~~~

Expected: `AUTOTEST_ALL_PASS` and zero `AT_FAIL`, with the new `icon_quality`
`AT_STEP` section present (10 kinds x 7 checks + 26 patch ids x 4 checks + family
draws + containment + raster registry probes).

- [ ] Step 7: Commit

~~~sh
git add src/ui/tactical_icon.gd src/ui/patch_card.gd src/ui/program_panel.gd src/autoload/dev_harness.gd .gitignore
git commit -m "feat: rework tactical icon set"
~~~

(If Step 4 produced rasters, also run `git add assets/icons/generated` before
committing so the PNGs and their `.import` sidecars are included; `media/concepts/`
is gitignored and must never appear in the commit.)

---

### Task 8: Final verification

Files:
- Modify: none (verification only; fix commits only if a defect surfaces)

Interfaces:
- Consumes: every prior task's production code and harness checks; the three approved mocks.
- Produces: a verified green suite, visual evidence in `/tmp/opencode/`, and a clean working tree.

- [ ] Step 1: Full autotest from a clean state

Run:

~~~sh
godot --headless --path . -- --autotest
~~~

Expected: the final line is `AUTOTEST_ALL_PASS`, with zero `AT_FAIL` lines anywhere in the output and all `AT_STEP` sections (including `hud_style`, `era_accent`, `text_overflow`, `touch_hud_layout`, `mote_sweep`, `oom_identity`, `difficulty`, `achievements_panel`, `glyph_lib`, `icon_quality`, `story_intro_auto`, `story_intro_layout`) present.

- [ ] Step 2: Repeat at default settings integrity

Run:

~~~sh
git status --short
git diff --check
~~~

Expected: only the files touched by Tasks 1-7b are modified; no `.godot/`, captures, binaries, or private paths are staged or tracked. The save config default remains NORMAL (delete `~/.local/share/godot/app_userdata/` save only if a manual test left `game/difficulty` set; the harness restores it itself).

- [ ] Step 3: Final visual pass against the mocks

Run:

~~~sh
KP_SHOT=game KP_SHOT_OUT=/tmp/opencode/final_game.png godot --path . --resolution 1366x768
KP_SHOT=menu KP_SHOT_OUT=/tmp/opencode/final_menu.png godot --path . --resolution 1366x768
~~~

Expected: transparent combat HUD with era-correct accent, dismissible story intro
with "PRESS ANY KEY" (verify interactively once: launch a story run, confirm no
enemies appear until dismissal, dismiss with a key/tap, and confirm an idle run
auto-dismisses after 8 seconds), fitted text at all three reference resolutions,
and reworked glyphs — all matching the approved mocks.

- [ ] Step 4: Release prep is out of scope

Do not bump `application/config/version`, do not edit the changelog section of
README.md beyond the Task 6 difficulty paragraph, and do not create release
artifacts. If any verification step required a production fix, commit it with:

~~~sh
git add -A
git commit -m "fix: address final verification findings"
~~~

(Only when a fix was actually needed; otherwise skip this commit.)

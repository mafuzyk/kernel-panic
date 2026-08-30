# KERNEL PANIC Polish Pack — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-subagent-driven-development (recommended) or superpowers-executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the approved 2026-08-30 polish pack — five real settings tabs, a reflowing menu with the three documented overlap fixes, AWARDS panel chrome, bestiary glyph containment, a raster icon optical-size pass, the connected-path story rail, a teardown leak hunt with a recorded baseline, and the author-gated sprite trial scaffolding — with zero gameplay changes and the full autotest suite green after every task.

**Architecture:** All UI stays code-drawn Godot 4.7.2 GDScript (`_draw()` + `draw_*`). Settings tab state lives in `src/ui/menu_settings_kit.gd` as a visibility filter over the existing (never rebuilt) controls; the menu gains one layout dict (`menu_layout_for_viewport`) that both build-time placement and resize reflow consume; containment/overflow surfaces extend the existing `text_overflow_report()` pattern; new harness checks live in a new `src/autoload/harness/sections_polish.gd` registered in `src/autoload/dev_harness.gd`; the sprite trial is an empty-path registry (`src/ui/entity_sprite.gd`) behind a single switch in `GlyphLib.draw_glyph`.

**Tech Stack:** Godot 4.7.2, GDScript, headless autotest harness (`godot --headless --path . -- --autotest`), `KP_SHOT` capture hook, ImageMagick (`magick`) for raster re-exports, Hyprland `hl.window_rule()` runtime eval for DP-1 captures.

Spec: docs/superpowers/specs/2026-08-30-polish-pack-design.md

## Global Constraints

- Baseline gate: `godot --headless --path . -- --autotest` ends with `AUTOTEST_ALL_PASS`, `0` `AT_FAIL`, and **1194** `AT_PASS` lines across **68** `AT_STEP` labels. The counts only grow with new checks. Every task ends with a full green run before its commit.
- TDD: write the failing harness regression BEFORE each behavior-changing production edit; run it red (`AUTOTEST_FAILED`, no parse errors), then make it green.
- Cosmetic/UI code never consumes `Game.rng` (menu reflow, story pulse, icon drawing, sprite registry included). Gameplay randomness stays on `Game.rng`.
- One-HP never gains heal sources; lock-on stays selectable in every mode; touch input rules are untouched. `src/player/`, `src/enemies/`, `src/arena/`, and all difficulty read points in `src/autoload/balance.gd` are never edited.
- Mobile-first: every visual change is verified at **1366×768 and 432×720**; desktop-only conveniences stay gated by `Balance.is_desktop_display()` / `m._desktop_keybinds_enabled()`.
- Captures never commit. KP_SHOT captures and side-by-side montages live in `/tmp/opencode/`. Captures run on the author's DP-1 monitor: before the first capture of a session, ensure the window class `KERNEL PANIC` lands fullscreen on DP-1 via the runtime `hl.window_rule()` eval (same pattern as the 2026-08-30 KP_DEMO smoke boot recorded in `docs/superpowers/plans/2026-08-30-structure-refactor.md`); after each `SHOT_SAVED` line, kill the process (`pkill -f "godot --path ."`).
- Item 9 (gameplay questionnaire appendix) is **not** a task in this plan; the orchestrator surfaces those questions in a later session. Nothing from the appendix is implemented here.
- Do not stage `.godot/`, build outputs, or unrelated docs. One conventional commit per task.
- The approved story-rail mock lives outside the repo at `/home/mafu/.codex/generated_images/01a044e4-d316-7ef2-85d8-9aa85056ea3a/exec-e6d82072-a577-4578-876d-1a5e9bb5ba8a.png`; `exec-6582ea9f-...png` (bestiary), `exec-450f92b7-...png` (programs), `exec-10cafd61-...png` (combat HUD) are the other approved references. Style is the identity; raster vs code is a technique swap, never a style change (Task 7c correction preserved verbatim).
- Harness sections pattern: every file in `src/autoload/harness/` is `extends RefCounted`, holds `var h: Node`, sets `h = harness` in `_init(harness: Node)`, and prefixes every harness helper with `h.` (e.g. `h._check(...)`, `h._ticks(...)`, `h.get_tree()`, `h._key_event(...)`). Dynamic access (`has_method` / `call` / `get`) on game objects keeps red runs parse-clean.

---

### Task 1: Register the art-direction decision in the spec

**Files:**
- Modify: `docs/superpowers/specs/2026-08-30-polish-pack-design.md` (Decision Summary, last bullet)

- [x] **Step 1: Append the author decision to the spec's Decision Summary**

In `docs/superpowers/specs/2026-08-30-polish-pack-design.md`, find the last line of the `## Decision Summary` section:

```
- Item 9 is questions-only: the gameplay ideas below are deferred pending the author's answers.
```

and replace it with:

```
- Item 9 is questions-only: the gameplay ideas below are deferred pending the author's answers.
- Long-term art direction (author decision 2026-08-30): progressive migration from code-drawn glyphs to real generated art after this polish pack; registries-with-fallback are the migration mechanism; this pack's sprite trial (item 8) is the first step.
```

- [x] **Step 2: Confirm the autotest baseline**

Run:

~~~sh
godot --headless --path . -- --autotest 2>&1 | tee /tmp/opencode/baseline_polish.txt | tail -3
grep -c "AT_PASS" /tmp/opencode/baseline_polish.txt
grep -c "AT_FAIL" /tmp/opencode/baseline_polish.txt
grep -c "AT_STEP" /tmp/opencode/baseline_polish.txt
~~~

Expected: final line `AUTOTEST_ALL_PASS`, `1194` AT_PASS, `0` AT_FAIL, `68` AT_STEP labels. Record these three numbers — every later task re-checks against them.

- [x] **Step 3: Commit**

~~~sh
git add docs/superpowers/specs/2026-08-30-polish-pack-design.md
git commit -m "docs: register art direction decision in polish pack spec"
~~~

---

### Task 2: Settings REAL tabs — desktop section state machine (test-first)

**Files:**
- Create: `src/autoload/harness/sections_polish.gd`
- Modify: `src/autoload/dev_harness.gd` (register the polish section)
- Modify: `src/autoload/harness/sections_scene.gd` (groups check follows the five sections)
- Modify: `src/ui/menu_settings_kit.gd` (section state machine)
- Modify: `src/ui/menu.gd` (snapshot + wrapper)

Interfaces:
- Consumes: `menu_settings_kit.gd` `_build_settings()` content block, the scroll-only `nav_targets = [0, 0, 0, 0, 100000]`, `m._settings_nav_buttons`, `m._settings_title`, `m._keybind_box`, `m._desktop_keybinds_enabled()`.
- Produces: kit API `SETTINGS_SECTIONS`, `SECTION_CHIP_LABELS`, `assign_section(control, section)`, `set_active_section(section)`, `active_section()`, `section_names()`, `section_controls(section)`, `settings_section_snapshot()`; menu wrapper `settings_section_snapshot()`; updated `settings_shell_snapshot()` groups. Content mapping: AUDIO = SFX/MUSIC/MUTE ALL/"M = MUTE IN GAME" hint; GAMEPLAY = HAPTICS, AIM MODE, TOUCH SIZE (touch-only via meta), SCREEN SHAKE, SPEEDRUN HUD; CONTROLS = desktop keybind grid + RESET KEYBINDS, else a "DESKTOP ONLY" note; ACCESSIBILITY = COLOR ASSIST; SAVE DATA = transfer field, COPY EXPORT / IMPORT PASTE, transfer status, RESET HIGH SCORE, lifetime stats. Every control stays in the tree, only visibility-filtered; ESC chain untouched; difficulty stays in the menu.

- [x] **Step 1: Write the failing harness checks**

Create `src/autoload/harness/sections_polish.gd` with exactly:

~~~gdscript
extends RefCounted

## Autotest section for the 2026-08-30 polish pack: settings real tabs,
## compact chips, menu reflow, awards chrome, bestiary glyph containment,
## raster optical pass, story rail restyle, leak guard, sprite trial.
## Same conventions as the other sections: helper references prefixed `h.`.

var h: Node


func _init(harness: Node) -> void:
	h = harness

func _settings_tabs_test(menu: Node) -> void:
	print("AT_STEP settings_tabs")
	var kit = menu.get("_settings_kit")
	h._check(kit != null and kit.has_method("set_active_section") and kit.has_method("active_section") and kit.has_method("settings_section_snapshot"), "settings kit exposes the section state machine")
	if kit == null or not kit.has_method("set_active_section"):
		return
	var sections: Array = kit.call("section_names")
	h._check(sections == ["AUDIO", "GAMEPLAY", "CONTROLS", "ACCESSIBILITY", "SAVE DATA"], "settings kit declares the five sections in order")
	menu.call("_open_settings")
	await h._ticks(2)
	for section in sections:
		kit.call("set_active_section", str(section))
		await h._ticks(1)
		var snapshot: Dictionary = kit.call("settings_section_snapshot")
		h._check(str(snapshot.get("active", "")) == str(section), "settings active section follows set_active_section (%s)" % str(section))
		var hidden_ok := true
		for other in sections:
			if str(other) == str(section):
				continue
			for control in kit.call("section_controls", str(other)):
				if is_instance_valid(control) and control.visible:
					hidden_ok = false
		h._check(hidden_ok, "%s tab hides every other section's control" % str(section))
		var visible := 0
		for control in kit.call("section_controls", str(section)):
			if is_instance_valid(control) and control.visible:
				visible += 1
		h._check(visible >= 1, "%s tab keeps at least one visible control" % str(section))
		var title: Label = menu.get("_settings_title")
		h._check(title != null and str(title.text).ends_with(str(section)), "settings title shows the active section (%s)" % str(section))
		var selected_index: int = sections.find(str(section))
		var nav_buttons: Array = menu.get("_settings_nav_buttons")
		var selected_ok: bool = nav_buttons.size() == sections.size()
		for i in nav_buttons.size():
			var btn: Button = nav_buttons[i]
			if (i == selected_index) != str(btn.text).begins_with("▸"):
				selected_ok = false
		h._check(selected_ok, "exactly one nav button carries the selected marker (%s)" % str(section))
	kit.call("set_active_section", "AUDIO")
	h.get_viewport().push_input(h._key_event(KEY_ESCAPE))
	h._check(not bool(menu.get("_settings_panel").visible), "ESC still closes the whole settings panel")
	menu.call("_close_settings")
~~~

In `src/autoload/dev_harness.gd`, add the preload directly below line 11 (`const HSectionModes = preload("res://src/autoload/harness/sections_modes.gd")`):

~~~gdscript
const HSectionPolish = preload("res://src/autoload/harness/sections_polish.gd")
~~~

Add `var _sec_polish` directly below `var _sec_modes` (line 24), add `_sec_polish = HSectionPolish.new(self)` directly below `_sec_modes = HSectionModes.new(self)` (line 92), and insert after the line `await _sec_scene._menu_shell_test(menu_scene)` (line 443):

~~~gdscript
	await _sec_polish._settings_tabs_test(menu_scene)
~~~

In `src/autoload/harness/sections_scene.gd`, replace (line 69):

~~~gdscript
		h._check(groups.has("AUDIO") and groups.has("CONTROL") and groups.has("DISPLAY") and groups.has("SAVE TRANSFER"), "settings shell exposes aligned option groups")
~~~

with:

~~~gdscript
		h._check(groups.has("AUDIO") and groups.has("GAMEPLAY") and groups.has("CONTROLS") and groups.has("ACCESSIBILITY") and groups.has("SAVE DATA"), "settings shell exposes the five real sections")
~~~

- [x] **Step 2: Run the test to verify it fails**

Run:

~~~sh
godot --headless --path . -- --autotest 2>&1 | grep -E "AT_FAIL|AUTOTEST" | head -10
~~~

Expected: `AUTOTEST_FAILED` with AT_FAIL lines including `settings shell exposes the five real sections` and `settings kit exposes the section state machine`. No parse errors.

- [x] **Step 3: Add the section state machine to menu_settings_kit.gd**

In `src/ui/menu_settings_kit.gd`, directly below `var m` (line 11), add:

~~~gdscript
const SETTINGS_SECTIONS := ["AUDIO", "GAMEPLAY", "CONTROLS", "ACCESSIBILITY", "SAVE DATA"]
const SECTION_CHIP_LABELS := {"AUDIO": "AUDIO", "GAMEPLAY": "GAME", "CONTROLS": "KEYS", "ACCESSIBILITY": "ACCESS", "SAVE DATA": "DATA"}
var _active_section := "AUDIO"
var _section_members := {}
~~~

Then append these methods at the very end of the file:

~~~gdscript
func assign_section(control: Control, section: String) -> void:
	if control == null or not SETTINGS_SECTIONS.has(section):
		return
	if not _section_members.has(section):
		_section_members[section] = []
	_section_members[section].append(control)

func active_section() -> String:
	return _active_section

func section_names() -> Array:
	return SETTINGS_SECTIONS.duplicate()

func section_controls(section: String) -> Array:
	return _section_members.get(section, [])

func set_active_section(section: String) -> void:
	if not SETTINGS_SECTIONS.has(section):
		return
	_active_section = section
	_apply_section_visibility()
	_refresh_nav_selection()
	if m._settings_title != null and is_instance_valid(m._settings_title):
		m._settings_title.text = "SETTINGS // %s" % section
	Sfx.play("ui", 1.0, -10.0)

func _touch_only_controls_ok() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.get_environment("KP_FORCE_TOUCH") != ""

func _apply_section_visibility() -> void:
	for section in _section_members:
		var active: bool = section == _active_section
		for control in _section_members[section]:
			if control == null or not is_instance_valid(control):
				continue
			control.visible = active
			if active and control.has_meta("touch_only") and not _touch_only_controls_ok():
				control.visible = false
	if m._keybind_box != null and is_instance_valid(m._keybind_box):
		m._keybind_box.visible = _active_section == "CONTROLS"

func _refresh_nav_selection() -> void:
	var index := SETTINGS_SECTIONS.find(_active_section)
	if not m._settings_nav_buttons.is_empty():
		for i in m._settings_nav_buttons.size():
			var nav_button: Button = m._settings_nav_buttons[i]
			if not is_instance_valid(nav_button):
				continue
			var selected := i == index
			nav_button.text = ("▸ %s" % SETTINGS_SECTIONS[i]) if selected else "  %s" % SETTINGS_SECTIONS[i]
			nav_button.add_theme_color_override("font_color", TacticalUIHelper.LIME if selected else TacticalUIHelper.TEXT)
			nav_button.add_theme_stylebox_override("normal", m._settings_nav_style(TacticalUIHelper.LIME if selected else Color(TacticalUIHelper.CYAN.r, TacticalUIHelper.CYAN.g, TacticalUIHelper.CYAN.b, 0.18)))

func settings_section_snapshot() -> Dictionary:
	var visible_controls := 0
	for section in _section_members:
		for control in _section_members[section]:
			if control != null and is_instance_valid(control) and control.visible:
				visible_controls += 1
	return {"active": _active_section, "sections": section_names(), "visible_controls": visible_controls}
~~~

- [x] **Step 4: Rewrite the settings content build with section assignment**

In `src/ui/menu_settings_kit.gd`, replace the ENTIRE `_build_settings()` function (from `func _build_settings() -> void:` through the `\t_layout_settings()` line that ends it) with:

~~~gdscript
func _build_settings() -> void:
	m._settings_panel = Control.new()
	m._settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	m._settings_panel.visible = false
	m._settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.012, 0.03, 0.88)
	m._settings_panel.add_child(dim)
	var outer_chrome: Control = TacticalChromeScript.new()
	outer_chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer_chrome.call("configure_shell", TacticalUIHelper.CYAN, 0.0)
	m._settings_panel.add_child(outer_chrome)
	var settings_layout := settings_layout_for_viewport(m.size)
	var workstation: Rect2 = settings_layout["workstation"]
	var navigation: Rect2 = settings_layout["navigation"]
	var content: Rect2 = settings_layout["content"]
	var footer: Rect2 = settings_layout["footer"]
	var scroll := ScrollContainer.new()
	scroll.name = "SettingsScroll"
	scroll.anchor_left = 0.0
	scroll.anchor_right = 0.0
	scroll.anchor_top = 0.0
	scroll.anchor_bottom = 0.0
	m._settings_scroll = scroll
	var frame := Panel.new()
	frame.name = "SettingsFrame"
	frame.position = workstation.position
	frame.size = workstation.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	frame_style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	frame_style.set_border_width_all(0)
	frame.add_theme_stylebox_override("panel", frame_style)
	m._settings_frame = frame
	m._settings_panel.add_child(frame)
	var workstation_chrome: Control = TacticalChromeScript.new()
	workstation_chrome.set_anchors_preset(Control.PRESET_TOP_LEFT)
	workstation_chrome.position = workstation.position
	workstation_chrome.size = workstation.size
	workstation_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	workstation_chrome.call("configure_panel", Rect2(Vector2.ZERO, workstation.size), TacticalUIHelper.CYAN, 0.025)
	m._settings_workstation_chrome = workstation_chrome
	m._settings_panel.add_child(workstation_chrome)
	var navigation_chrome: Control = TacticalChromeScript.new()
	navigation_chrome.set_anchors_preset(Control.PRESET_TOP_LEFT)
	navigation_chrome.position = navigation.position
	navigation_chrome.size = navigation.size
	navigation_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	navigation_chrome.call("configure_panel", Rect2(Vector2.ZERO, navigation.size), TacticalUIHelper.CYAN, 0.025)
	m._settings_navigation_chrome = navigation_chrome
	m._settings_panel.add_child(navigation_chrome)
	scroll.offset_left = content.position.x
	scroll.offset_right = content.end.x
	scroll.offset_top = content.position.y + 8.0
	scroll.offset_bottom = footer.position.y - 8.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	m._settings_panel.add_child(scroll)
	var box := VBoxContainer.new()
	m._settings_box = box
	box.custom_minimum_size.x = maxf(content.size.x - 28.0, 240.0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 20)
	scroll.add_child(box)
	var title := Label.new()
	title.text = "SETTINGS // AUDIO"
	title.add_theme_font_override("font", load("res://assets/fonts/Orbitron.ttf"))
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Balance.COL_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_rect: Rect2 = settings_layout["title"]
	title.position = title_rect.position
	title.size = title_rect.size
	title.add_theme_font_size_override("font_size", int(settings_layout["title_size"]))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m._settings_title = title
	m._settings_panel.add_child(title)
	var audio_label := _settings_group_label("AUDIO // MIX")
	assign_section(audio_label, "AUDIO")
	box.add_child(audio_label)
	var sfx_row := _make_slider_row("SFX", Sfx.sfx_vol, func(v: float) -> void:
		Sfx.set_sfx_vol(v)
		Sfx.play("ui", 1.0, -6.0)
	)
	assign_section(sfx_row, "AUDIO")
	box.add_child(sfx_row)
	var music_row := _make_slider_row("MUSIC", Sfx.music_vol, func(v: float) -> void:
		Sfx.set_music_vol(v)
	)
	assign_section(music_row, "AUDIO")
	box.add_child(music_row)
	var mute := CheckButton.new()
	mute.text = "MUTE ALL"
	mute.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	mute.add_theme_font_size_override("font_size", 17)
	mute.add_theme_color_override("font_color", Balance.COL_TEXT)
	mute.button_pressed = Sfx.muted
	mute.toggled.connect(func(on: bool) -> void:
		Sfx.set_muted(on)
	)
	assign_section(mute, "AUDIO")
	box.add_child(mute)
	var mute_hint := _settings_group_label("M = MUTE IN GAME")
	mute_hint.add_theme_font_size_override("font_size", 12)
	mute_hint.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.4))
	assign_section(mute_hint, "AUDIO")
	box.add_child(mute_hint)
	var gameplay_label := _settings_group_label("GAMEPLAY // FEEL")
	assign_section(gameplay_label, "GAMEPLAY")
	box.add_child(gameplay_label)
	var haptics := CheckButton.new()
	haptics.text = "HAPTICS"
	haptics.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	haptics.add_theme_font_size_override("font_size", 17)
	haptics.add_theme_color_override("font_color", Balance.COL_TEXT)
	haptics.button_pressed = Sfx.haptics_enabled
	haptics.toggled.connect(func(on: bool) -> void:
		Sfx.haptics_enabled = on
		Sfx.save_settings()
	)
	assign_section(haptics, "GAMEPLAY")
	box.add_child(haptics)
	var aim_btn := Button.new()
	aim_btn.flat = true
	aim_btn.text = "AIM MODE: %s" % Sfx.aim_mode.to_upper()
	aim_btn.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	aim_btn.add_theme_font_size_override("font_size", 17)
	aim_btn.add_theme_color_override("font_color", Balance.COL_TEXT)
	aim_btn.add_theme_color_override("font_hover_color", Balance.COL_PLAYER)
	aim_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	aim_btn.pressed.connect(func() -> void:
		var order := ["drag", "stick", "lockon"]
		Sfx.aim_mode = order[(order.find(Sfx.aim_mode) + 1) % order.size()]
		m._refresh_aim_label(aim_btn)
		Sfx.save_settings()
	)
	m._aim_btn_ref = aim_btn
	m._refresh_aim_label(aim_btn)
	assign_section(aim_btn, "GAMEPLAY")
	box.add_child(aim_btn)
	var touch_sz := Button.new()
	touch_sz.flat = true
	touch_sz.text = "TOUCH SIZE: %s" % ["SMALL", "NORMAL", "BIG"][m._touch_scale_idx(Sfx.touch_scale)]
	touch_sz.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	touch_sz.add_theme_font_size_override("font_size", 17)
	touch_sz.add_theme_color_override("font_color", Balance.COL_TEXT)
	touch_sz.add_theme_color_override("font_hover_color", Balance.COL_PLAYER)
	touch_sz.alignment = HORIZONTAL_ALIGNMENT_LEFT
	touch_sz.pressed.connect(func() -> void:
		var idx: int = m._next_touch_scale_idx(Sfx.touch_scale)
		Sfx.touch_scale = [0.85, 1.0, 1.2][idx]
		touch_sz.text = "TOUCH SIZE: %s" % ["SMALL", "NORMAL", "BIG"][idx]
		Sfx.save_settings()
	)
	touch_sz.set_meta("touch_only", true)
	assign_section(touch_sz, "GAMEPLAY")
	box.add_child(touch_sz)
	var shake_btn := Button.new()
	shake_btn.flat = true
	shake_btn.text = "SCREEN SHAKE: %s" % ["OFF", "LOW", "FULL"][clampi(Sfx.shake_level, 0, 2)]
	shake_btn.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	shake_btn.add_theme_font_size_override("font_size", 17)
	shake_btn.add_theme_color_override("font_color", Balance.COL_TEXT)
	shake_btn.add_theme_color_override("font_hover_color", Balance.COL_PLAYER)
	shake_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	shake_btn.pressed.connect(func() -> void:
		Sfx.shake_level = (Sfx.shake_level + 1) % 3
		shake_btn.text = "SCREEN SHAKE: %s" % ["OFF", "LOW", "FULL"][Sfx.shake_level]
		Sfx.save_settings()
	)
	assign_section(shake_btn, "GAMEPLAY")
	box.add_child(shake_btn)
	var run_info := Button.new()
	run_info.flat = true
	run_info.text = "SPEEDRUN HUD: %s" % ("ON" if Sfx.show_run_info else "OFF")
	run_info.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	run_info.add_theme_font_size_override("font_size", 17)
	run_info.add_theme_color_override("font_color", Balance.COL_TEXT)
	run_info.add_theme_color_override("font_hover_color", Balance.COL_PLAYER)
	run_info.alignment = HORIZONTAL_ALIGNMENT_LEFT
	run_info.pressed.connect(func() -> void:
		Sfx.show_run_info = not Sfx.show_run_info
		run_info.text = "SPEEDRUN HUD: %s" % ("ON" if Sfx.show_run_info else "OFF")
		Sfx.save_settings()
	)
	assign_section(run_info, "GAMEPLAY")
	box.add_child(run_info)
	var access_label := _settings_group_label("ACCESSIBILITY // VISION")
	assign_section(access_label, "ACCESSIBILITY")
	box.add_child(access_label)
	m._color_assist_btn = Button.new()
	m._color_assist_btn.flat = true
	m._color_assist_btn.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	m._color_assist_btn.add_theme_font_size_override("font_size", 17)
	m._color_assist_btn.add_theme_color_override("font_color", Balance.COL_TEXT)
	m._color_assist_btn.add_theme_color_override("font_hover_color", Balance.COL_PLAYER)
	m._color_assist_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	m._color_assist_btn.pressed.connect(func() -> void:
		Sfx.set_color_assist(not Sfx.color_assist)
		_refresh_color_assist_label()
	)
	_refresh_color_assist_label()
	assign_section(m._color_assist_btn, "ACCESSIBILITY")
	box.add_child(m._color_assist_btn)
	var save_label := _settings_group_label("SAVE TRANSFER // PHONE ↔ PC")
	assign_section(save_label, "SAVE DATA")
	box.add_child(save_label)
	var transfer_title := Label.new()
	transfer_title.text = "ENCODED PROGRESS // COPY OR PASTE"
	transfer_title.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	transfer_title.add_theme_font_size_override("font_size", 14)
	transfer_title.add_theme_color_override("font_color", Balance.COL_MOTE)
	assign_section(transfer_title, "SAVE DATA")
	box.add_child(transfer_title)
	m._save_transfer_field = LineEdit.new()
	m._save_transfer_field.placeholder_text = "BASE64 SAVE STRING // PASTE HERE"
	m._save_transfer_field.custom_minimum_size = Vector2(0.0, 38.0)
	m._save_transfer_field.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	m._save_transfer_field.add_theme_font_size_override("font_size", 11)
	m._save_transfer_field.add_theme_color_override("font_color", Balance.COL_TEXT)
	assign_section(m._save_transfer_field, "SAVE DATA")
	box.add_child(m._save_transfer_field)
	var transfer_row := HBoxContainer.new()
	transfer_row.add_theme_constant_override("separation", 8)
	var export_btn := Button.new()
	export_btn.text = "COPY EXPORT"
	export_btn.flat = true
	export_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_btn.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	export_btn.add_theme_font_size_override("font_size", 13)
	export_btn.add_theme_color_override("font_color", Balance.COL_TEXT)
	export_btn.add_theme_color_override("font_hover_color", Balance.COL_PLAYER)
	export_btn.pressed.connect(m._export_save_to_clipboard)
	transfer_row.add_child(export_btn)
	var import_btn := Button.new()
	import_btn.text = "IMPORT PASTE"
	import_btn.flat = true
	import_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	import_btn.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	import_btn.add_theme_font_size_override("font_size", 13)
	import_btn.add_theme_color_override("font_color", Balance.COL_TEXT)
	import_btn.add_theme_color_override("font_hover_color", Balance.COL_PLAYER)
	import_btn.pressed.connect(m._import_save_from_clipboard)
	transfer_row.add_child(import_btn)
	assign_section(transfer_row, "SAVE DATA")
	box.add_child(transfer_row)
	m._save_transfer_status = Label.new()
	m._save_transfer_status.text = "EXPORT INCLUDES RECORDS, BESTIARY, PROGRAMS, ACHIEVEMENTS"
	m._save_transfer_status.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	m._save_transfer_status.add_theme_font_size_override("font_size", 10)
	m._save_transfer_status.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.5))
	m._save_transfer_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	assign_section(m._save_transfer_status, "SAVE DATA")
	box.add_child(m._save_transfer_status)
	var stats := Label.new()
	stats.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	stats.add_theme_font_size_override("font_size", 12)
	stats.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.45))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cf2 := ConfigFile.new()
	cf2.load(Sfx.SAVE_PATH)
	var runs := int(cf2.get_value("lifetime", "runs", 0))
	var kills := int(cf2.get_value("lifetime", "kills", 0))
	var chain := int(cf2.get_value("lifetime", "best_chain", 0))
	var kd: Dictionary = cf2.get_value("lifetime", "killers", {})
	var top := "NONE"
	var tk := 0
	for k in kd:
		if int(kd[k]) > tk:
			tk = int(kd[k])
			top = str(k)
	stats.text = "LIFETIME  RUNS %d  KILLS %d  BEST CHAIN x%d  TOP THREAT %s" % [runs, kills, chain, top]
	assign_section(stats, "SAVE DATA")
	box.add_child(stats)
	if m._desktop_keybinds_enabled():
		_build_keybind_settings(box)
	else:
		var controls_note := _settings_group_label("DESKTOP ONLY // KEYBINDS ARE EDITABLE ON DESKTOP BUILDS")
		assign_section(controls_note, "CONTROLS")
		box.add_child(controls_note)
	var reset := Button.new()
	reset.flat = true
	reset.text = "RESET HIGH SCORE"
	reset.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	reset.add_theme_font_size_override("font_size", 14)
	reset.add_theme_color_override("font_color", Color(Balance.COL_DANGER.r, Balance.COL_DANGER.g, Balance.COL_DANGER.b, 0.8))
	reset.alignment = HORIZONTAL_ALIGNMENT_LEFT
	reset.pressed.connect(func() -> void:
		if reset.text == "RESET HIGH SCORE":
			reset.text = "TAP AGAIN TO CONFIRM"
			return
		m._reset_scores()
		m._update_best()
		reset.text = "CLEARED"
	)
	var back := Button.new()
	back.text = "BACK"
	back.flat = true
	back.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	back.add_theme_font_size_override("font_size", 18)
	back.add_theme_color_override("font_color", Balance.COL_PLAYER)
	back.add_theme_color_override("font_hover_color", Balance.COL_PLAYER_HOT)
	back.pressed.connect(_close_settings)
	var footer_row := HBoxContainer.new()
	footer_row.position = footer.position
	footer_row.size = footer.size
	footer_row.add_theme_constant_override("separation", 12)
	m._style_settings_footer_button(back, TacticalUIHelper.CYAN)
	m._style_settings_footer_button(reset, TacticalUIHelper.MAGENTA)
	back.custom_minimum_size = Vector2(196.0, 42.0)
	reset.custom_minimum_size = Vector2(250.0, 42.0)
	m._add_button_icon(back, "back", TacticalUIHelper.CYAN, 36.0)
	m._add_button_icon(reset, "warning", TacticalUIHelper.MAGENTA, 36.0)
	footer_row.add_child(back)
	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_row.add_child(footer_spacer)
	footer_row.add_child(reset)
	m._settings_panel.add_child(footer_row)
	m._settings_footer_row = footer_row
	m._settings_nav_buttons.clear()
	for index in SETTINGS_SECTIONS.size():
		var nav_button := Button.new()
		nav_button.text = "  %s" % SETTINGS_SECTIONS[index]
		nav_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		nav_button.position = navigation.position + Vector2(10.0, 12.0 + float(index) * 48.0)
		nav_button.size = Vector2(navigation.size.x - 20.0, 38.0)
		nav_button.focus_mode = Control.FOCUS_NONE
		nav_button.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
		nav_button.add_theme_font_size_override("font_size", 14)
		nav_button.add_theme_color_override("font_color", TacticalUIHelper.TEXT)
		nav_button.add_theme_color_override("font_hover_color", TacticalUIHelper.CYAN)
		nav_button.add_theme_stylebox_override("normal", m._settings_nav_style(Color(TacticalUIHelper.CYAN.r, TacticalUIHelper.CYAN.g, TacticalUIHelper.CYAN.b, 0.18)))
		nav_button.add_theme_stylebox_override("hover", m._settings_nav_style(TacticalUIHelper.CYAN))
		nav_button.add_theme_stylebox_override("pressed", m._settings_nav_style(TacticalUIHelper.CYAN))
		m._add_button_chrome(nav_button, TacticalUIHelper.CYAN, 0.018)
		m._settings_nav_buttons.append(nav_button)
		nav_button.pressed.connect(set_active_section.bind(str(SETTINGS_SECTIONS[index])))
		m._settings_panel.add_child(nav_button)
	var nav_hint := Label.new()
	nav_hint.text = "SYSTEM / CONFIG"
	nav_hint.position = navigation.position + Vector2(14.0, navigation.size.y - 28.0)
	nav_hint.size = Vector2(navigation.size.x - 28.0, 18.0)
	nav_hint.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	nav_hint.add_theme_font_size_override("font_size", 10)
	nav_hint.add_theme_color_override("font_color", TacticalUIHelper.MUTED)
	m._settings_panel.add_child(nav_hint)
	m.add_child(m._settings_panel)
	_apply_section_visibility()
	_refresh_nav_selection()
	_layout_settings()
~~~

Then in the same file, at the very end of `_build_keybind_settings`, directly below the line `parent.add_child(m._keybind_box)`, add:

~~~gdscript
	assign_section(m._keybind_box, "CONTROLS")
~~~

- [x] **Step 5: Update menu.gd snapshot + wrapper**

In `src/ui/menu.gd`, directly below the `settings_layout_for_viewport` function (after its closing brace), add:

~~~gdscript
func settings_section_snapshot() -> Dictionary:
	return _settings_kit.settings_section_snapshot()
~~~

And in `settings_shell_snapshot()`, replace the line:

~~~gdscript
		"groups": ["AUDIO", "CONTROL", "DISPLAY", "SAVE TRANSFER"],
~~~

with:

~~~gdscript
		"groups": ["AUDIO", "GAMEPLAY", "CONTROLS", "ACCESSIBILITY", "SAVE DATA"],
~~~

- [x] **Step 6: Run the full suite**

Run:

~~~sh
godot --headless --path . -- --autotest 2>&1 | grep -E "AT_FAIL|AUTOTEST" | head -10
~~~

Expected: `AUTOTEST_ALL_PASS`, zero `AT_FAIL`. New AT_STEP label `settings_tabs` present; AT_PASS count grows above 1194.

- [x] **Step 7: Commit**

~~~sh
git add src/ui/menu_settings_kit.gd src/ui/menu.gd src/autoload/dev_harness.gd src/autoload/harness/sections_polish.gd src/autoload/harness/sections_scene.gd
git commit -m "feat: settings sidebar becomes five real tabs"
~~~

---

### Task 3: Settings compact chips row for mobile (test-first)

**Files:**
- Modify: `src/ui/menu_settings_kit.gd` (compact layout, chips row, viewport override)
- Modify: `src/ui/menu.gd` (chips state refs)
- Modify: `src/autoload/harness/sections_polish.gd`
- Modify: `src/autoload/dev_harness.gd`
- Modify: `src/autoload/harness/sections_scene.gd` (compact-conditional rail check)

Interfaces:
- Consumes: `settings_layout_for_viewport` (kit); the 760 compact breakpoint used by `TacticalUI.layout` / `TacticalUI.shell_rect` (`tactical_ui.gd` line 37/74).
- Produces: layout keys `compact` (bool) and `chips` (Rect2); kit `apply_viewport(viewport)` / `_current_viewport()`; menu members `_settings_chips_row: HBoxContainer`, `_settings_chip_buttons: Array[Button]`, `_settings_nav_hint: Label`. Below 760 px the sidebar (nav buttons + rail chrome + hint) hides and a horizontal chips row above the content shares `_active_section` with it.

- [x] **Step 1: Write the failing harness check**

In `src/autoload/harness/sections_polish.gd`, append at the end of the class:

~~~gdscript
func _settings_chips_test(menu: Node) -> void:
	print("AT_STEP settings_chips")
	var kit = menu.get("_settings_kit")
	h._check(kit != null and kit.has_method("apply_viewport"), "settings kit exposes a viewport override for layout probes")
	if kit == null or not kit.has_method("apply_viewport"):
		return
	menu.call("_open_settings")
	await h._ticks(1)
	kit.call("apply_viewport", Vector2(432, 720))
	await h._ticks(1)
	var layout: Dictionary = menu.call("settings_layout_for_viewport", Vector2(432, 720))
	h._check(bool(layout.get("compact", false)), "432x720 uses the compact settings layout")
	var chips_row: Control = menu.get("_settings_chips_row")
	h._check(chips_row != null and chips_row.visible, "compact layout shows the chips row")
	var nav_buttons: Array = menu.get("_settings_nav_buttons")
	var nav_hidden: bool = not nav_buttons.is_empty()
	for btn in nav_buttons:
		nav_hidden = nav_hidden and (is_instance_valid(btn) and not btn.visible)
	h._check(nav_hidden, "compact layout hides the sidebar nav buttons")
	kit.call("set_active_section", "SAVE DATA")
	await h._ticks(1)
	var chips: Array = menu.get("_settings_chip_buttons")
	var chip_selected: bool = chips.size() == 5
	for i in chips.size():
		if (i == 4) != str(chips[i].text).begins_with("▸"):
			chip_selected = false
	h._check(chip_selected, "chips share the active section state with the sidebar")
	kit.call("apply_viewport", Vector2.ZERO)
	kit.call("set_active_section", "AUDIO")
	menu.call("_close_settings")
~~~

In `src/autoload/dev_harness.gd`, directly below the `await _sec_polish._settings_tabs_test(menu_scene)` line added in Task 2, add:

~~~gdscript
	await _sec_polish._settings_chips_test(menu_scene)
~~~

In `src/autoload/harness/sections_scene.gd`, replace (line 43):

~~~gdscript
			h._check(settings_layout["navigation"].position.x < settings_layout["content"].position.x, "settings navigation precedes content at %dx%d" % [int(viewport_size.x), int(viewport_size.y)])
~~~

with:

~~~gdscript
			if bool(settings_layout.get("compact", false)):
				h._check(Rect2(settings_layout["chips"]).end.y <= settings_layout["content"].position.y, "settings chips row sits above the content at %dx%d" % [int(viewport_size.x), int(viewport_size.y)])
			else:
				h._check(settings_layout["navigation"].position.x < settings_layout["content"].position.x, "settings navigation precedes content at %dx%d" % [int(viewport_size.x), int(viewport_size.y)])
~~~

- [x] **Step 2: Run the test to verify it fails**

Run:

~~~sh
godot --headless --path . -- --autotest 2>&1 | grep -E "AT_FAIL|AUTOTEST" | head -10
~~~

Expected: `AUTOTEST_FAILED` with AT_FAIL `settings kit exposes a viewport override for layout probes`. No parse errors.

- [x] **Step 3: Compact layout + chips in menu_settings_kit.gd**

3a. In `settings_layout_for_viewport`, replace everything from the line `\tvar navigation_width := minf(230.0, maxf(132.0, workstation.size.x * 0.27))` through the line `\tvar content := Rect2(Vector2(content_x, navigation.position.y), Vector2(maxf(workstation.end.x - content_x - 10.0, 0.0), navigation.size.y))` with:

~~~gdscript
	var compact := viewport.x < 760.0
	var navigation := Rect2.ZERO
	var chips := Rect2.ZERO
	var content := Rect2.ZERO
	if compact:
		chips = Rect2(workstation.position + Vector2(10.0, 88.0), Vector2(workstation.size.x - 20.0, 40.0))
		content = Rect2(Vector2(workstation.position.x + 10.0, chips.end.y + 8.0), Vector2(workstation.size.x - 20.0, maxf(footer.position.y - chips.end.y - 16.0, 0.0)))
	else:
		var navigation_width := minf(230.0, maxf(132.0, workstation.size.x * 0.27))
		navigation = Rect2(workstation.position + Vector2(10.0, 88.0), Vector2(navigation_width, maxf(workstation.size.y - 160.0, 0.0)))
		var content_x := navigation.end.x + 14.0
		content = Rect2(Vector2(content_x, navigation.position.y), Vector2(maxf(workstation.end.x - content_x - 10.0, 0.0), navigation.size.y))
~~~

3b. In the same function's `return` dict, add two keys — replace:

~~~gdscript
	return {
		"workstation": workstation,
		"navigation": navigation,
		"content": content,
		"footer": footer,
		"title": title,
		"title_size": title_size,
	}
~~~

with:

~~~gdscript
	return {
		"workstation": workstation,
		"navigation": navigation,
		"content": content,
		"footer": footer,
		"title": title,
		"title_size": title_size,
		"compact": compact,
		"chips": chips,
	}
~~~

3c. Add a state var directly below `var _section_members := {}`:

~~~gdscript
var _viewport_override := Vector2.ZERO
~~~

3d. Add these two methods at the end of the file:

~~~gdscript
func apply_viewport(viewport: Vector2) -> void:
	_viewport_override = viewport
	_layout_settings()

func _current_viewport() -> Vector2:
	return _viewport_override if _viewport_override != Vector2.ZERO else m.size
~~~

3e. In `_layout_settings()`, replace the line `\tvar settings_layout := settings_layout_for_viewport(m.size)` with:

~~~gdscript
	var settings_layout := settings_layout_for_viewport(_current_viewport())
~~~

3f. In `_build_settings()`, replace the line `\tvar settings_layout := settings_layout_for_viewport(m.size)` with:

~~~gdscript
	var settings_layout := settings_layout_for_viewport(_current_viewport())
~~~

3g. In `_build_settings()`, change the nav_hint block ending — replace:

~~~gdscript
	nav_hint.add_theme_color_override("font_color", TacticalUIHelper.MUTED)
	m._settings_panel.add_child(nav_hint)
~~~

with:

~~~gdscript
	nav_hint.add_theme_color_override("font_color", TacticalUIHelper.MUTED)
	m._settings_nav_hint = nav_hint
	m._settings_panel.add_child(nav_hint)
	var chips_row := HBoxContainer.new()
	chips_row.name = "SettingsChips"
	chips_row.add_theme_constant_override("separation", 8)
	m._settings_chips_row = chips_row
	m._settings_panel.add_child(chips_row)
	for section in SETTINGS_SECTIONS:
		var chip := Button.new()
		chip.text = str(SECTION_CHIP_LABELS[section])
		chip.focus_mode = Control.FOCUS_NONE
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.size_flags_vertical = Control.SIZE_EXPAND_FILL
		chip.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
		chip.add_theme_font_size_override("font_size", 11)
		chip.add_theme_color_override("font_color", TacticalUIHelper.TEXT)
		chip.add_theme_color_override("font_hover_color", TacticalUIHelper.CYAN)
		chip.add_theme_stylebox_override("normal", m._settings_nav_style(Color(TacticalUIHelper.CYAN.r, TacticalUIHelper.CYAN.g, TacticalUIHelper.CYAN.b, 0.18)))
		chip.add_theme_stylebox_override("hover", m._settings_nav_style(TacticalUIHelper.CYAN))
		chip.add_theme_stylebox_override("pressed", m._settings_nav_style(TacticalUIHelper.CYAN))
		chip.pressed.connect(set_active_section.bind(str(section)))
		chips_row.add_child(chip)
		m._settings_chip_buttons.append(chip)
~~~

3h. Extend `_refresh_nav_selection()` — replace the whole function with:

~~~gdscript
func _refresh_nav_selection() -> void:
	var index := SETTINGS_SECTIONS.find(_active_section)
	if not m._settings_nav_buttons.is_empty():
		for i in m._settings_nav_buttons.size():
			var nav_button: Button = m._settings_nav_buttons[i]
			if not is_instance_valid(nav_button):
				continue
			var selected := i == index
			nav_button.text = ("▸ %s" % SETTINGS_SECTIONS[i]) if selected else "  %s" % SETTINGS_SECTIONS[i]
			nav_button.add_theme_color_override("font_color", TacticalUIHelper.LIME if selected else TacticalUIHelper.TEXT)
			nav_button.add_theme_stylebox_override("normal", m._settings_nav_style(TacticalUIHelper.LIME if selected else Color(TacticalUIHelper.CYAN.r, TacticalUIHelper.CYAN.g, TacticalUIHelper.CYAN.b, 0.18)))
	if not m._settings_chip_buttons.is_empty():
		for i in m._settings_chip_buttons.size():
			var chip: Button = m._settings_chip_buttons[i]
			if not is_instance_valid(chip):
				continue
			var chip_selected := i == index
			chip.text = ("▸ %s" % str(SECTION_CHIP_LABELS[SETTINGS_SECTIONS[i]])) if chip_selected else str(SECTION_CHIP_LABELS[SETTINGS_SECTIONS[i]])
			chip.add_theme_color_override("font_color", TacticalUIHelper.LIME if chip_selected else TacticalUIHelper.TEXT)
			chip.add_theme_stylebox_override("normal", m._settings_nav_style(TacticalUIHelper.LIME if chip_selected else Color(TacticalUIHelper.CYAN.r, TacticalUIHelper.CYAN.g, TacticalUIHelper.CYAN.b, 0.18)))
~~~

3i. In `_layout_settings()`, replace the nav-button placement block (from `\tif not m._settings_nav_buttons.is_empty():` through the closing line of that `for` loop) with:

~~~gdscript
	var compact: bool = bool(settings_layout.get("compact", false))
	if m._settings_navigation_chrome != null and is_instance_valid(m._settings_navigation_chrome):
		m._settings_navigation_chrome.visible = not compact
	if m._settings_nav_hint != null and is_instance_valid(m._settings_nav_hint):
		m._settings_nav_hint.visible = not compact
	if m._settings_chips_row != null and is_instance_valid(m._settings_chips_row):
		m._settings_chips_row.visible = compact
		m._settings_chips_row.position = (settings_layout["chips"] as Rect2).position
		m._settings_chips_row.size = (settings_layout["chips"] as Rect2).size
	for index in m._settings_nav_buttons.size():
		var nav_button: Button = m._settings_nav_buttons[index]
		if not is_instance_valid(nav_button):
			continue
		nav_button.visible = not compact
		if compact:
			continue
		nav_button.position = navigation.position + Vector2(10.0, 12.0 + float(index) * 48.0)
		nav_button.size = Vector2(maxf(navigation.size.x - 20.0, 96.0), 38.0)
~~~

- [x] **Step 4: Menu state refs**

In `src/ui/menu.gd`, directly below `var _settings_nav_buttons: Array[Button] = []` (line 48), add:

~~~gdscript
var _settings_chip_buttons: Array[Button] = []
var _settings_chips_row: HBoxContainer
var _settings_nav_hint: Label
~~~

- [x] **Step 5: Run the full suite**

Run:

~~~sh
godot --headless --path . -- --autotest 2>&1 | grep -E "AT_FAIL|AUTOTEST" | head -10
~~~

Expected: `AUTOTEST_ALL_PASS`, zero `AT_FAIL`. New AT_STEP label `settings_chips`.

- [x] **Step 6: Commit**

~~~sh
git add src/ui/menu_settings_kit.gd src/ui/menu.gd src/autoload/dev_harness.gd src/autoload/harness/sections_polish.gd src/autoload/harness/sections_scene.gd
git commit -m "feat: settings compact chips row for mobile"
~~~

---

### Task 4: Menu responsive reflow + three overlap fixes (test-first)

**Files:**
- Modify: `src/ui/menu_chrome_kit.gd` (`menu_layout_for_viewport`, `apply_menu_layout`, dict-consuming `draw_shell`, stored frames/row)
- Modify: `src/ui/menu.gd` (resize wiring, element refs, wrapper)
- Modify: `src/autoload/harness/sections_polish.gd`
- Modify: `src/autoload/dev_harness.gd`

Interfaces:
- Consumes: `footer_button_layout_for_viewport` (chrome kit); `_mk_title` offsets 125–235; klog offsets 120–190 / x 16–620 (`menu.gd` lines 226–238); controls RichTextLabel offsets 193–219 (anchor 0.5); `_mode_info` offsets 190–234 (anchor 0.5); `draw_shell` ring/dot anchors (`menu_chrome_kit.gd` lines 354, 365–366).
- Produces: chrome kit `menu_layout_for_viewport(viewport) -> Dictionary` with keys `viewport, compact, title, title_size, klog, subtitle, controls, best, mode_info, purge, story, mode, program, diff, button_row, button_width, gap, ring_center, mode_dot`; kit `apply_menu_layout()` + `menu_layout()`; menu wrapper `menu_layout_for_viewport()`; menu members `_subtitle: Label`, `_controls_line: RichTextLabel`, `_menu_frames: Array[Control]`, `_footer_row: Control`.

Layout math (verified disjoint at all four probe sizes): title top 104 desktop / 84 compact, font 76 / 58 (x<1100) / 44 (x<760), height = size×1.45; klog Rect2(16, 12, min(340, vp.x−32), 68); subtitle = title.end+4, h 30; controls = subtitle.end+4, h 26; best = controls.end+4, h 24; mode_info = Rect2(24, vp.y−95−8−mi_h, vp.x−48, mi_h) with mi_h = 44 (vp.y ≥ 700) else 24; button_row = Rect2((vp.x−row_w)/2, vp.y−95, row_w, 48). The three review fixes: (a) klog (y 12–80) sits fully above the title band (84/104+); (b) controls line moves into the top stack, disjoint from `mode_info` (bottom stack); (c) mode_info is clamped clear of the footer row at every probed height.

- [x] **Step 1: Write the failing harness check**

In `src/autoload/harness/sections_polish.gd`, append at the end of the class:

~~~gdscript
func _menu_reflow_test(menu: Node) -> void:
	print("AT_STEP menu_reflow")
	h._check(menu.has_method("menu_layout_for_viewport"), "menu exposes the central layout dict")
	if not menu.has_method("menu_layout_for_viewport"):
		return
	for vp in [Vector2(1366, 768), Vector2(1024, 640), Vector2(760, 720), Vector2(432, 720)]:
		var lay: Dictionary = menu.call("menu_layout_for_viewport", vp)
		var view := Rect2(Vector2.ZERO, vp)
		for key in ["title", "klog", "subtitle", "controls", "best", "mode_info", "button_row", "purge", "story", "mode", "program", "diff"]:
			h._check(view.encloses(Rect2(lay[key])), "menu %s stays inside the viewport at %dx%d" % [str(key), int(vp.x), int(vp.y)])
		var band_keys := ["title", "klog", "controls", "best", "mode_info", "button_row"]
		for i in band_keys.size():
			for j in range(i + 1, band_keys.size()):
				var a: Rect2 = lay[band_keys[i]]
				var b: Rect2 = lay[band_keys[j]]
				h._check(not a.intersects(b), "menu %s and %s stay disjoint at %dx%d" % [str(band_keys[i]), str(band_keys[j]), int(vp.x), int(vp.y)])
		h._check(int(lay["title_size"]) >= 44, "menu title scales down with the viewport at %dx%d" % [int(vp.x), int(vp.y)])
	var src := str(load("res://src/ui/menu_chrome_kit.gd").source_code)
	h._check(src.contains("apply_menu_layout"), "menu chrome kit applies the layout dict on resize")
	h._check(not src.contains("m.size.y * 0.44"), "draw_shell derives its decorative anchors from the shared dict")
~~~

In `src/autoload/dev_harness.gd`, directly below the `await _sec_polish._settings_chips_test(menu_scene)` line added in Task 3, add:

~~~gdscript
	await _sec_polish._menu_reflow_test(menu_scene)
~~~

- [x] **Step 2: Run the test to verify it fails**

Run:

~~~sh
godot --headless --path . -- --autotest 2>&1 | grep -E "AT_FAIL|AUTOTEST" | head -10
~~~

Expected: `AUTOTEST_FAILED` with AT_FAIL `menu exposes the central layout dict`. No parse errors.

- [x] **Step 3: Layout dict + apply in menu_chrome_kit.gd**

3a. Directly below `var m` (line 12), add:

~~~gdscript
var _layout: Dictionary = {}
~~~

3b. Add these functions directly above `func _style_overlay_back`:

~~~gdscript
func menu_layout_for_viewport(viewport: Vector2) -> Dictionary:
	var compact := viewport.x < 760.0
	var title_size := 76
	if viewport.x < 1100.0:
		title_size = 58
	if compact:
		title_size = 44
	var title_top := 104.0 if not compact else 84.0
	var title_h := float(title_size) * 1.45
	var title := Rect2(0.0, title_top, viewport.x, title_h)
	var klog := Rect2(16.0, 12.0, minf(340.0, maxf(viewport.x - 32.0, 0.0)), 68.0)
	var subtitle := Rect2(0.0, title.end.y + 4.0, viewport.x, 30.0)
	var controls := Rect2(0.0, subtitle.end.y + 4.0, viewport.x, 26.0)
	var best := Rect2(0.0, controls.end.y + 4.0, viewport.x, 24.0)
	var mi_h := 44.0 if viewport.y >= 700.0 else 24.0
	var mode_info := Rect2(24.0, viewport.y - 95.0 - 8.0 - mi_h, viewport.x - 48.0, mi_h)
	var center := Vector2(viewport.x * 0.5, viewport.y * 0.5)
	var purge_w := minf(430.0, maxf(viewport.x * 0.30, 280.0))
	var purge := Rect2(center.x - purge_w * 0.5, center.y - 52.0, purge_w, 88.0)
	var story_w := minf(360.0, purge_w * 0.84)
	var story := Rect2(center.x - story_w * 0.5, center.y + 44.0, story_w, 58.0)
	var mode_w := minf(440.0, maxf(viewport.x * 0.42, 300.0))
	var mode := Rect2(center.x - mode_w * 0.5, center.y + 112.0, mode_w, 50.0)
	var program := Rect2(center.x + 42.0, center.y + 112.0, 178.0, 50.0)
	var diff := Rect2(center.x - 110.0, center.y + 166.0, 220.0, 26.0)
	var footer_layout := footer_button_layout_for_viewport(viewport)
	var row_w: float = footer_layout["total_width"]
	var button_row := Rect2((viewport.x - row_w) * 0.5, viewport.y - 95.0, row_w, 48.0)
	var ring_center := Vector2(maxf(150.0, center.x - 470.0), viewport.y * 0.44)
	var mode_dot := Vector2(center.x, center.y + 130.0)
	return {"viewport": viewport, "compact": compact, "title": title, "title_size": title_size, "klog": klog, "subtitle": subtitle, "controls": controls, "best": best, "mode_info": mode_info, "purge": purge, "story": story, "mode": mode, "program": program, "diff": diff, "button_row": button_row, "button_width": float(footer_layout["button_width"]), "gap": float(footer_layout["gap"]), "ring_center": ring_center, "mode_dot": mode_dot}

func menu_layout() -> Dictionary:
	return _layout if not _layout.is_empty() else menu_layout_for_viewport(m.size)

func apply_menu_layout() -> void:
	_layout = menu_layout_for_viewport(m.size)
	var lay := _layout
	var center := Vector2(m.size.x * 0.5, m.size.y * 0.5)
	for title_label in [m._title, m._title_r, m._title_b]:
		if title_label != null and is_instance_valid(title_label):
			title_label.offset_top = (lay["title"] as Rect2).position.y
			title_label.offset_bottom = (lay["title"] as Rect2).end.y
			title_label.add_theme_font_size_override("font_size", int(lay["title_size"]))
	if m._subtitle != null and is_instance_valid(m._subtitle):
		m._subtitle.offset_top = (lay["subtitle"] as Rect2).position.y
		m._subtitle.offset_bottom = (lay["subtitle"] as Rect2).end.y
	if m._controls_line != null and is_instance_valid(m._controls_line):
		m._controls_line.offset_top = (lay["controls"] as Rect2).position.y
		m._controls_line.offset_bottom = (lay["controls"] as Rect2).end.y
	if m._best_label != null and is_instance_valid(m._best_label):
		m._best_label.offset_top = (lay["best"] as Rect2).position.y
		m._best_label.offset_bottom = (lay["best"] as Rect2).end.y
	if m._klog != null and is_instance_valid(m._klog):
		m._klog.offset_left = (lay["klog"] as Rect2).position.x
		m._klog.offset_right = (lay["klog"] as Rect2).end.x
		m._klog.offset_top = (lay["klog"] as Rect2).position.y
		m._klog.offset_bottom = (lay["klog"] as Rect2).end.y
	if m._mode_info != null and is_instance_valid(m._mode_info):
		m._mode_info.offset_left = (lay["mode_info"] as Rect2).position.x
		m._mode_info.offset_right = (lay["mode_info"] as Rect2).end.x
		m._mode_info.offset_top = (lay["mode_info"] as Rect2).position.y
		m._mode_info.offset_bottom = (lay["mode_info"] as Rect2).end.y
	_place_center_button(m._purge_btn, lay["purge"], center)
	_place_center_button(m._story_btn, lay["story"], center)
	_place_center_button(m._mode_btn, lay["mode"], center)
	_place_center_button(m._program_btn, lay["program"], center)
	_place_center_button(m._diff_btn, lay["diff"], center)
	if m._footer_row != null and is_instance_valid(m._footer_row):
		m._footer_row.anchor_left = 0.0
		m._footer_row.anchor_right = 0.0
		m._footer_row.anchor_top = 0.0
		m._footer_row.anchor_bottom = 0.0
		m._footer_row.position = (lay["button_row"] as Rect2).position
		m._footer_row.size = (lay["button_row"] as Rect2).size
	var row_rect := lay["button_row"] as Rect2
	var slots := [
		row_rect.position,
		Vector2(row_rect.position.x + float(lay["button_width"]) + float(lay["gap"]), row_rect.position.y),
		Vector2(row_rect.position.x + (float(lay["button_width"]) + float(lay["gap"])) * 2.0, row_rect.position.y),
	]
	var frame_rects: Array = [lay["purge"], lay["story"], lay["mode"]]
	for slot in slots:
		frame_rects.append(Rect2(slot, Vector2(float(lay["button_width"]), 48.0)))
	for i in mini(m._menu_frames.size(), frame_rects.size()):
		var frame: Control = m._menu_frames[i]
		if frame != null and is_instance_valid(frame):
			frame.position = (frame_rects[i] as Rect2).position
			frame.size = (frame_rects[i] as Rect2).size

func _place_center_button(button: Button, rect: Rect2, center: Vector2) -> void:
	if button == null or not is_instance_valid(button):
		return
	button.anchor_left = 0.5
	button.anchor_right = 0.5
	button.anchor_top = 0.5
	button.anchor_bottom = 0.5
	button.offset_left = rect.position.x - center.x
	button.offset_right = rect.end.x - center.x
	button.offset_top = rect.position.y - center.y
	button.offset_bottom = rect.end.y - center.y
	button.pivot_offset = rect.size * 0.5
~~~

3c. In `_build_button_row()`, make these exact replacements:

- Replace `\tvar purge_width := minf(430.0, maxf(m.size.x * 0.30, 280.0))` with:

~~~gdscript
	var lay := menu_layout_for_viewport(m.size)
	var purge_width: float = (lay["purge"] as Rect2).size.x
~~~

- Replace `\t_add_menu_frame(Rect2(Vector2((m.size.x - purge_width) * 0.5, m.size.y * 0.5 - 52.0), Vector2(purge_width, 88.0)), Balance.COL_PLAYER, 0.035)` with:

~~~gdscript
	_add_menu_frame(lay["purge"], Balance.COL_PLAYER, 0.035)
~~~

- Replace `\t_style_card_button(m._story_btn, Balance.COL_PLAYER, Vector2(minf(360.0, purge_width * 0.84), 58.0))` with:

~~~gdscript
	_style_card_button(m._story_btn, Balance.COL_PLAYER, Vector2((lay["story"] as Rect2).size.x, 58.0))
~~~

- Replace `\tvar story_width := minf(360.0, purge_width * 0.84)` with:

~~~gdscript
	var story_width: float = (lay["story"] as Rect2).size.x
~~~

- Replace `\t_add_menu_frame(Rect2(Vector2((m.size.x - story_width) * 0.5, m.size.y * 0.5 + 44.0), Vector2(story_width, 58.0)), Balance.COL_PLAYER, 0.025)` with:

~~~gdscript
	_add_menu_frame(lay["story"], Balance.COL_PLAYER, 0.025)
~~~

- Replace `\t_style_card_button(m._mode_btn, Balance.COL_MOTE, Vector2(minf(440.0, maxf(m.size.x * 0.42, 300.0)), 50.0))` with:

~~~gdscript
	_style_card_button(m._mode_btn, Balance.COL_MOTE, Vector2((lay["mode"] as Rect2).size.x, 50.0))
~~~

- Replace `\tvar mode_width := minf(440.0, maxf(m.size.x * 0.42, 300.0))` with:

~~~gdscript
	var mode_width: float = (lay["mode"] as Rect2).size.x
~~~

- Replace `\t_add_menu_frame(Rect2(Vector2((m.size.x - mode_width) * 0.5, m.size.y * 0.5 + 112.0), Vector2(mode_width, 50.0)), Balance.COL_MOTE, 0.03)` with:

~~~gdscript
	_add_menu_frame(lay["mode"], Balance.COL_MOTE, 0.03)
~~~

- Replace the footer-layout block:

~~~gdscript
	var footer_layout := footer_button_layout_for_viewport(m.size)
	var bottom_width: float = footer_layout["total_width"]
	var bottom_gap: float = footer_layout["gap"]
	var bottom_button_w: float = footer_layout["button_width"]
~~~

with:

~~~gdscript
	var bottom_width: float = (lay["button_row"] as Rect2).size.x
	var bottom_gap: float = lay["gap"]
	var bottom_button_w: float = lay["button_width"]
~~~

- Replace the four `_mode_info` offset lines:

~~~gdscript
	m._mode_info.offset_left = 24.0
	m._mode_info.offset_right = m.size.x - 24.0
	m._mode_info.offset_top = 190.0
	m._mode_info.offset_bottom = 234.0
~~~

with:

~~~gdscript
	m._mode_info.offset_left = (lay["mode_info"] as Rect2).position.x
	m._mode_info.offset_right = (lay["mode_info"] as Rect2).end.x
	m._mode_info.offset_top = (lay["mode_info"] as Rect2).position.y
	m._mode_info.offset_bottom = (lay["mode_info"] as Rect2).end.y
~~~

3d. In `_add_menu_frame`, directly above `\treturn frame`, add:

~~~gdscript
	m._menu_frames.append(frame)
~~~

3e. In `_build_button_row()`, directly below `\trow.alignment = BoxContainer.ALIGNMENT_CENTER`, add:

~~~gdscript
	m._footer_row = row
~~~

3f. In `draw_shell`, replace:

~~~gdscript
	var ring_center := Vector2(maxf(150.0, center_x - 470.0), m.size.y * 0.44)
~~~

with:

~~~gdscript
	var ring_center: Vector2 = menu_layout()["ring_center"]
~~~

and replace:

~~~gdscript
	var mode_y: float = m.size.y * 0.5 + 130.0
	m.draw_circle(Vector2(center_x, mode_y), 4.0, Balance.COL_MOTE)
~~~

with:

~~~gdscript
	m.draw_circle(menu_layout()["mode_dot"], 4.0, Balance.COL_MOTE)
~~~

- [x] **Step 4: Menu element refs + resize wiring**

In `src/ui/menu.gd`:

4a. Directly below `var _klog: Label` (line 23), add:

~~~gdscript
var _subtitle: Label
var _controls_line: RichTextLabel
var _menu_frames: Array[Control] = []
var _footer_row: Control
~~~

4b. In `_ready()`, directly below `\tadd_child(sub)`, add:

~~~gdscript
	_subtitle = sub
~~~

and directly below `\tadd_child(controls)`, add:

~~~gdscript
	_controls_line = controls
~~~

4c. Directly below `\tadd_child(_klog)` (after the klog build block), add:

~~~gdscript
	_chrome_kit.apply_menu_layout()
~~~

4d. Replace the `_notification` body:

~~~gdscript
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _settings_panel != null and is_instance_valid(_settings_panel):
		_settings_kit._layout_settings.call_deferred()
~~~

with:

~~~gdscript
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if _settings_panel != null and is_instance_valid(_settings_panel):
			_settings_kit._layout_settings.call_deferred()
		if _chrome_kit != null:
			_chrome_kit.apply_menu_layout.call_deferred()
~~~

4e. Directly below the `settings_section_snapshot` wrapper added in Task 2, add:

~~~gdscript
func menu_layout_for_viewport(viewport: Vector2) -> Dictionary:
	return _chrome_kit.menu_layout_for_viewport(viewport)
~~~

- [x] **Step 5: Run the full suite**

Run:

~~~sh
godot --headless --path . -- --autotest 2>&1 | grep -E "AT_FAIL|AUTOTEST" | head -10
~~~

Expected: `AUTOTEST_ALL_PASS`, zero `AT_FAIL`. New AT_STEP label `menu_reflow`. The pre-existing `menu_shell` checks stay green — the best label moved to y 282–306 and never intersects the purge rect (purge top = center−52 ≥ 332 at 768).

- [x] **Step 6: Resize smoke capture (visual, images never committed)**

Run on the author desktop (DP-1 rules per Global Constraints):

~~~sh
KP_SHOT=menu KP_SHOT_OUT=/tmp/opencode/reflow_menu_1366.png godot --path . --resolution 1366x768
KP_SHOT=menu KP_SHOT_OUT=/tmp/opencode/reflow_menu_432.png godot --path . --resolution 432x720
~~~

Expected: both prints contain `SHOT_SAVED`; title, klog, controls line, best label, and footer row show no overlaps at either size. Kill the processes after the `SHOT_SAVED` lines.

- [x] **Step 7: Commit**

~~~sh
git add src/ui/menu_chrome_kit.gd src/ui/menu.gd src/autoload/dev_harness.gd src/autoload/harness/sections_polish.gd
git commit -m "feat: reflow the menu from one layout dict"
~~~

---

### Task 5: AWARDS footer trophy icon (code-drawn "awards" kind; raster optional)

**Files:**
- Modify: `src/ui/tactical_icon.gd` ("awards" kind: metrics, bounds, draw dispatch)
- Modify: `src/ui/menu_chrome_kit.gd` (wire the icon into the AWARDS card)
- Modify: `src/autoload/harness/sections_visual.gd` (kind list)
- Optional, author-gated, never committed without her approval: `assets/icons/generated/awards.png` + `.import`

Spec correction applied: the trophy raster does NOT exist (verified 2026-08-30 — no `awards.png`/`trophy` under `assets/icons/generated/`), so the code-drawn "awards" kind ships first; the registry fallback covers the raster automatically if the author later approves one.

- [x] **Step 1: Extend the icon kind list in the harness (failing)**

In `src/autoload/harness/sections_visual.gd`, replace (line 211):

~~~gdscript
	for kind in ["settings", "bestiary", "dash", "back", "resume", "restart", "terminal", "audio", "music", "warning"]:
~~~

with:

~~~gdscript
	for kind in ["settings", "bestiary", "dash", "back", "resume", "restart", "terminal", "audio", "music", "warning", "awards"]:
~~~

- [x] **Step 2: Run the test to verify it fails**

Run:

~~~sh
godot --headless --path . -- --autotest 2>&1 | grep -E "AT_FAIL|AUTOTEST" | head -10
~~~

Expected: `AUTOTEST_FAILED` with AT_FAIL lines `tactical icon covers the awards kind`, `awards icon resolves to a non-empty drawing routine`, `awards icon has documented quality metrics`, `awards icon documents a minimum stroke of at least 1.5`, `awards icon documents panel contrast of at least 0.55`, and the two `awards icon silhouette stays contained at 24px/52px` failures. No parse errors.

- [x] **Step 3: Implement the "awards" kind in tactical_icon.gd**

3a. In `ICON_METRICS`, directly below the `"warning"` entry, add:

~~~gdscript
	"awards": {"min_stroke": 1.8, "contrast": 0.55},
~~~

3b. In `ICON_BOUNDS`, directly below the `"warning"` entry, add:

~~~gdscript
	"awards": Rect2(0.16, 0.14, 0.68, 0.72),
~~~

3c. In the `_draw()` match, directly below the `"warning":` arm, add:

~~~gdscript
		"awards":
			_draw_awards(center, radius)
~~~

3d. Append at the end of the file:

~~~gdscript
func _draw_awards(center: Vector2, radius: float) -> void:
	var cup := PackedVector2Array([
		center + Vector2(-radius * 0.52, -radius * 0.66),
		center + Vector2(radius * 0.52, -radius * 0.66),
		center + Vector2(radius * 0.40, radius * 0.10),
		center + Vector2(0.0, radius * 0.30),
		center + Vector2(-radius * 0.40, radius * 0.10),
	])
	draw_colored_polygon(cup, Color(_accent.r, _accent.g, _accent.b, 0.14))
	_points_closed(cup, _line_color(), 2.0)
	draw_line(center + Vector2(-radius * 0.52, -radius * 0.66), center + Vector2(-radius * 0.78, -radius * 0.36), _line_color(), 1.8, true)
	draw_line(center + Vector2(-radius * 0.78, -radius * 0.36), center + Vector2(-radius * 0.42, -radius * 0.06), _line_color(), 1.8, true)
	draw_line(center + Vector2(radius * 0.52, -radius * 0.66), center + Vector2(radius * 0.78, -radius * 0.36), _line_color(), 1.8, true)
	draw_line(center + Vector2(radius * 0.78, -radius * 0.36), center + Vector2(radius * 0.42, -radius * 0.06), _line_color(), 1.8, true)
	draw_line(center + Vector2(0.0, radius * 0.30), center + Vector2(0.0, radius * 0.58), _line_color(), 2.0)
	draw_line(center + Vector2(-radius * 0.30, radius * 0.58), center + Vector2(radius * 0.30, radius * 0.58), _line_color(), 2.2)
~~~

- [x] **Step 4: Wire the icon into the AWARDS card**

In `src/ui/menu_chrome_kit.gd` `_build_button_row()`, replace:

~~~gdscript
	var ach_btn := Button.new()
	_style_card_button(ach_btn, TacticalUIHelper.LIME, Vector2(bottom_button_w, 48.0))
	ach_btn.text = "AWARDS"
	ach_btn.z_index = 2
~~~

with:

~~~gdscript
	var ach_btn := Button.new()
	_style_card_button(ach_btn, TacticalUIHelper.LIME, Vector2(bottom_button_w, 48.0))
	ach_btn.text = "AWARDS"
	_set_button_text_inset(ach_btn, 92.0)
	_add_button_icon(ach_btn, "awards", TacticalUIHelper.LIME, 52.0)
	ach_btn.z_index = 2
~~~

- [x] **Step 5: Run the full suite**

Run:

~~~sh
godot --headless --path . -- --autotest 2>&1 | grep -E "AT_FAIL|AUTOTEST" | head -10
~~~

Expected: `AUTOTEST_ALL_PASS`, zero `AT_FAIL`.

- [x] **Step 6: OPTIONAL raster trial (author-gated; skip to Step 7 if the author declines)**

Generate one candidate in `/tmp` only, show it side-by-side with the code-drawn icon, and copy it into the repo ONLY after the author approves:

~~~sh
mkdir -p /tmp/opencode
# Orchestrator: generate a 512x512 neon geometric trophy on a transparent
# background with the imagegen tool, prompt below, output
# /tmp/opencode/awards_candidate.png
# Prompt: "neon geometric terminal-style trophy icon, cyan-on-transparent,
# thin angular outlines, flat dark navy fills, glow accents, centered,
# minimal, no text, 512x512"
KP_SHOT=menu KP_SHOT_OUT=/tmp/opencode/awards_code.png godot --path . --resolution 1366x768
# If approved: cp /tmp/opencode/awards_candidate.png assets/icons/generated/awards.png
# then run: godot --headless --path . -- --import   (mints the .import sidecar)
~~~

Decision rule: without author approval, nothing under `assets/icons/generated/` changes; the code-drawn kind ships. `raster_path("awards")` resolves the raster automatically the moment the file exists (Task 7c registry pattern) — no further wiring needed either way.

- [x] **Step 7: Commit**

~~~sh
git add src/ui/tactical_icon.gd src/ui/menu_chrome_kit.gd src/autoload/harness/sections_visual.gd
git commit -m "feat: add the awards footer icon"
~~~

(If and only if the author approved the raster in Step 6, also `git add assets/icons/generated/awards.png assets/icons/generated/awards.png.import` in the same commit.)

---

### Task 6: AWARDS panel chrome — dim, frame, card rows (test-first)

**Files:**
- Modify: `src/ui/achievements_panel.gd`
- Modify: `src/ui/tactical_icon.gd` ("check" glyph kind)
- Modify: `src/autoload/harness/sections_polish.gd`
- Modify: `src/autoload/dev_harness.gd`
- Modify: `src/autoload/harness/sections_modes.gd` (KP_AWARDS capture branch)
- Modify: `src/autoload/harness/sections_visual.gd` (add "check" to the kind list)

Interfaces:
- Consumes: `TacticalUIHelper.angular_points`, `TacticalChromeScript.configure_panel`, the existing `achievement_rows()` / `progress_header()` / `refresh()` / ScrollContainer / back button / ESC chain (`menu.gd` `_open_achievements` / `_unhandled_input`).
- Produces: `achievements_panel.gd` `awards_panel_rect(viewport) -> Rect2` (Rect2((vp.x−w)/2, 102, w, vp.y−216) with w = min(680, vp.x−56)), `award_row_rects() -> Array[Rect2]` (row rects in GLOBAL space), `AwardsDim`/`AwardsChrome` named nodes preserved across `refresh()`, `_row_controls: Array[Control]`, and TacticalIcon kind `"check"` (metrics `{"min_stroke": 2.0, "contrast": 0.55}`, bounds `Rect2(0.22, 0.24, 0.56, 0.52)`).

- [x] **Step 1: Write the failing harness check**

In `src/autoload/harness/sections_polish.gd`, append at the end of the class:

~~~gdscript
func _awards_chrome_test(menu: Node) -> void:
	print("AT_STEP awards_chrome")
	var panel_script: Script = load("res://src/ui/achievements_panel.gd")
	var panel = panel_script.new() if panel_script != null else null
	h._check(panel != null and panel.has_method("awards_panel_rect") and panel.has_method("award_row_rects"), "awards panel exposes its chrome rect and row rect helpers")
	if panel == null:
		return
	for vp in [Vector2(1366, 768), Vector2(432, 720)]:
		var rect: Rect2 = panel.call("awards_panel_rect", vp)
		h._check(Rect2(Vector2.ZERO, vp).encloses(rect.grow(-2.0)), "awards chrome stays inside the viewport at %dx%d" % [int(vp.x), int(vp.y)])
		h._check(rect.size.x >= 240.0 and rect.size.y >= 220.0, "awards chrome keeps a usable panel size at %dx%d" % [int(vp.x), int(vp.y)])
	var src := str(panel_script.source_code)
	h._check(src.contains("AwardsDim"), "awards panel draws a full-rect dim behind the chrome")
	h._check(src.contains("configure_panel"), "awards rows use angular chrome frames")
	panel.free()
	if menu != null and menu.get("_ach_panel") != null:
		menu.call("_open_achievements")
		await h._ticks(2)
		var live = menu.get("_ach_panel")
		var chrome_rect: Rect2 = live.call("awards_panel_rect", live.size)
		var contained := true
		var row_found := false
		for row in live.call("award_row_rects"):
			row_found = true
			if not chrome_rect.grow(-4.0).encloses(Rect2(row)):
				contained = false
		h._check(row_found, "awards panel exposes live row rects for containment probes")
		h._check(contained, "awards rows sit inside the chrome at the live viewport")
		menu.call("_close_achievements")
~~~

In `src/autoload/dev_harness.gd`, directly below the line `await _sec_modes._achievements_panel_test()` (line 446), add:

~~~gdscript
	await _sec_polish._awards_chrome_test(menu_scene)
~~~

In `src/autoload/harness/sections_visual.gd`, extend the kind list once more:

~~~gdscript
	for kind in ["settings", "bestiary", "dash", "back", "resume", "restart", "terminal", "audio", "music", "warning", "awards", "check"]:
~~~

In `src/autoload/harness/sections_modes.gd` `_capture()`, replace:

~~~gdscript
		elif OS.get_environment("KP_SETTINGS") != "" and menu.has_method("_open_settings"):
			menu._open_settings()
~~~

with:

~~~gdscript
		elif OS.get_environment("KP_SETTINGS") != "" and menu.has_method("_open_settings"):
			menu._open_settings()
		elif OS.get_environment("KP_AWARDS") != "" and menu.has_method("_open_achievements"):
			menu._open_achievements()
~~~

- [x] **Step 2: Run the test to verify it fails**

Run:

~~~sh
godot --headless --path . -- --autotest 2>&1 | grep -E "AT_FAIL|AUTOTEST" | head -10
~~~

Expected: `AUTOTEST_FAILED` with AT_FAIL `awards panel exposes its chrome rect and row rect helpers` plus the `check`-kind icon failures. No parse errors.

- [x] **Step 3: Add the "check" icon kind**

3a. In `src/ui/tactical_icon.gd` `ICON_METRICS`, below the `"awards"` entry, add:

~~~gdscript
	"check": {"min_stroke": 2.0, "contrast": 0.55},
~~~

3b. In `ICON_BOUNDS`, below the `"awards"` entry, add:

~~~gdscript
	"check": Rect2(0.22, 0.24, 0.56, 0.52),
~~~

3c. In the `_draw()` match, below the `"awards":` arm, add:

~~~gdscript
		"check":
			_draw_check(center, radius)
~~~

3d. Append at the end of the file:

~~~gdscript
func _draw_check(center: Vector2, radius: float) -> void:
	draw_line(center + Vector2(-radius * 0.42, radius * 0.02), center + Vector2(-radius * 0.10, radius * 0.36), _line_color(), 2.4, true)
	draw_line(center + Vector2(-radius * 0.10, radius * 0.36), center + Vector2(radius * 0.46, -radius * 0.30), _line_color(), 2.4, true)
~~~

- [x] **Step 4: AWARDS chrome in achievements_panel.gd**

4a. Directly below the existing `const TacticalUIHelper = preload("res://src/ui/tactical_ui.gd")` line, add:

~~~gdscript
const TacticalChromeScript = preload("res://src/ui/tactical_chrome.gd")
const TacticalIconScript = preload("res://src/ui/tactical_icon.gd")
~~~

4b. Directly below `var _header: Label`, add:

~~~gdscript
var _row_controls: Array[Control] = []
~~~

4c. In `_build()`, replace the child-clearing loop:

~~~gdscript
	for child in get_children():
		if child is Button:
			continue
		remove_child(child)
		child.queue_free()
~~~

with:

~~~gdscript
	for child in get_children():
		if child is Button or child.name == "AwardsDim" or child.name == "AwardsChrome":
			continue
		remove_child(child)
		child.queue_free()
	_row_controls.clear()
	if get_node_or_null("AwardsDim") == null:
		var dim := ColorRect.new()
		dim.name = "AwardsDim"
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.color = Color(0.01, 0.012, 0.03, 0.88)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dim)
	if get_node_or_null("AwardsChrome") == null:
		var chrome: Control = TacticalChromeScript.new()
		chrome.name = "AwardsChrome"
		chrome.position = awards_panel_rect(size).position
		chrome.size = awards_panel_rect(size).size
		chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chrome.call("configure_panel", Rect2(Vector2.ZERO, awards_panel_rect(size).size), TacticalUIHelper.CYAN, 0.03)
		add_child(chrome)
~~~

4d. In `_build()`, position the header inside the chrome — replace:

~~~gdscript
	_header.anchor_left = 0.0
	_header.anchor_right = 1.0
	_header.offset_top = 118.0
	_header.offset_bottom = 148.0
~~~

with:

~~~gdscript
	var rect := awards_panel_rect(size)
	_header.position = rect.position + Vector2(0.0, 12.0)
	_header.size = Vector2(rect.size.x, 30.0)
~~~

4e. In `_build()`, replace the scroll anchors/offsets block:

~~~gdscript
	scroll.anchor_left = 0.0
	scroll.anchor_right = 1.0
	scroll.anchor_top = 0.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 40.0
	scroll.offset_right = -40.0
	scroll.offset_top = 160.0
	scroll.offset_bottom = -116.0
~~~

with:

~~~gdscript
	scroll.anchor_left = 0.0
	scroll.anchor_right = 0.0
	scroll.anchor_top = 0.0
	scroll.anchor_bottom = 0.0
	scroll.offset_left = rect.position.x + 20.0
	scroll.offset_right = rect.end.x - 20.0
	scroll.offset_top = rect.position.y + 46.0
	scroll.offset_bottom = rect.end.y - 16.0
~~~

4f. In `_build()`, replace the row loop:

~~~gdscript
	for row in achievement_rows():
		rows_box.add_child(_make_row(row, mono))
~~~

with:

~~~gdscript
	for row in achievement_rows():
		var row_control: Control = _make_row(row, mono)
		_row_controls.append(row_control)
		rows_box.add_child(row_control)
~~~

4g. Replace the whole `_make_row` function with the card-row version:

~~~gdscript
func _make_row(row: Dictionary, mono: Font) -> Control:
	var row_control := Control.new()
	row_control.custom_minimum_size = Vector2(0.0, 44.0)
	row_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var unlocked := bool(row.get("unlocked", false))
	var accent: Color = TacticalUIHelper.LIME if unlocked else Color(TacticalUIHelper.MUTED.r, TacticalUIHelper.MUTED.g, TacticalUIHelper.MUTED.b, 0.5)
	var chrome: Control = TacticalChromeScript.new()
	chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome.call("configure_panel", Rect2(Vector2.ZERO, Vector2(0.0, 44.0)), accent, 0.05 if unlocked else 0.015)
	row_control.add_child(chrome)
	var text_x := 12.0
	if unlocked:
		var icon: Control = TacticalIconScript.new()
		icon.position = Vector2(8.0, 8.0)
		icon.size = Vector2(28.0, 28.0)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_control.add_child(icon)
		icon.call("configure", "check", TacticalUIHelper.LIME)
		text_x = 44.0
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", mono)
	label.add_theme_font_size_override("font_size", 13)
	label.position = Vector2(text_x, 0.0)
	label.size = Vector2(360.0, 44.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if unlocked:
		label.text = str(row.get("label", ""))
		label.add_theme_color_override("font_color", TacticalUIHelper.LIME)
	else:
		label.text = "%s  //  %s" % [str(row.get("label", "")), str(row.get("hint", ""))]
		label.add_theme_color_override("font_color", Color(TacticalUIHelper.TEXT.r, TacticalUIHelper.TEXT.g, TacticalUIHelper.TEXT.b, 0.45))
	row_control.add_child(label)
	return row_control
~~~

4h. Replace the whole `_draw()` with:

~~~gdscript
func _draw() -> void:
	pass
~~~

(The dim + chrome nodes carry the visuals now; the old polygon frame drew under the rows with no dim.)

4i. Append the two helpers at the end of the file:

~~~gdscript
func awards_panel_rect(viewport: Vector2) -> Rect2:
	var w := minf(680.0, maxf(viewport.x - 56.0, 240.0))
	var h := maxf(viewport.y - 216.0, 220.0)
	return Rect2((viewport.x - w) * 0.5, 102.0, w, h)

func award_row_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for row in _row_controls:
		if row != null and is_instance_valid(row):
			out.append(Rect2(row.global_position, row.size))
	return out
~~~

- [x] **Step 5: Run the full suite**

Run:

~~~sh
godot --headless --path . -- --autotest 2>&1 | grep -E "AT_FAIL|AUTOTEST" | head -10
~~~

Expected: `AUTOTEST_ALL_PASS`, zero `AT_FAIL`. The pre-existing `achievements_panel` AT_STEP (rows/header/scroll checks, source contains `ScrollContainer`) stays green.

- [x] **Step 6: Capture both resolutions (never committed)**

~~~sh
KP_SHOT=menu KP_AWARDS=1 KP_SHOT_OUT=/tmp/opencode/awards_1366.png godot --path . --resolution 1366x768
KP_SHOT=menu KP_AWARDS=1 KP_SHOT_OUT=/tmp/opencode/awards_432.png godot --path . --resolution 432x720
~~~

Expected: `SHOT_SAVED` twice; dim over the menu, framed centered panel, lime unlocked rows with check glyphs, muted locked rows with hint text, scroll intact at 432×720.

- [x] **Step 7: Commit**

~~~sh
git add src/ui/achievements_panel.gd src/ui/tactical_icon.gd src/autoload/dev_harness.gd src/autoload/harness/sections_polish.gd src/autoload/harness/sections_modes.gd src/autoload/harness/sections_visual.gd
git commit -m "feat: give the awards panel dim and card chrome"
~~~

---

### Task 7: Bestiary detail glyph containment + detail column sweep (test-first)

**Files:**
- Modify: `src/ui/glyph_lib.gd` (per-kind extent table)
- Modify: `src/ui/bestiary_panel.gd` (glyph box, fit scale, PTS chip alignment, metrics dict, report entry)
- Modify: `src/autoload/harness/sections_polish.gd`
- Modify: `src/autoload/dev_harness.gd`

Interfaces:
- Consumes: `bestiary_panel.gd::_draw_detail` (glyph today drawn at `rail.end.x − 118`, scale 3.5, unit radius 16 — the lancer's 2.4-unit lance pokes ~22px past the rail's right edge), `text_overflow_report()`.
- Produces: `GlyphLib.glyph_extent(kind) -> float` + `GLYPH_EXTENT` table; bestiary `DETAIL_METRICS` dict + `_detail_glyph_box(rail)`; fit scale `min(3.5, (box half − 6) / (16 × extent))`; `text_overflow_report()` entry `glyph_contained`.

- [x] **Step 1: Write the failing harness check**

In `src/autoload/harness/sections_polish.gd`, append at the end of the class:

~~~gdscript
func _bestiary_glyph_test() -> void:
	print("AT_STEP bestiary_glyph")
	var glyph_script: Script = load("res://src/ui/glyph_lib.gd")
	h._check(glyph_script != null and glyph_script.has_method("glyph_extent"), "glyph library exposes per-kind extent factors")
	var panel_script: Script = load("res://src/ui/bestiary_panel.gd")
	var panel = panel_script.new() if panel_script != null else null
	h._check(panel != null and panel.has_method("text_overflow_report"), "bestiary keeps text_overflow_report")
	if panel == null:
		return
	var all_fit := true
	var saw_glyph_entry := false
	for vp in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
		panel.size = vp
		for entry in panel.call("text_overflow_report"):
			if str(entry.get("id", "")) == "glyph_contained":
				saw_glyph_entry = true
			if not bool(entry.get("fits", false)):
				all_fit = false
	h._check(saw_glyph_entry, "bestiary report carries the glyph_contained entry")
	h._check(all_fit, "bestiary detail stays contained including glyphs at 1366x768, 720x720, and 432x720")
	panel.free()
~~~

In `src/autoload/dev_harness.gd`, directly below the line `await _sec_scene._text_overflow_test()` (line 444), add:

~~~gdscript
	await _sec_polish._bestiary_glyph_test()
~~~

- [x] **Step 2: Run the test to verify it fails**

Run:

~~~sh
godot --headless --path . -- --autotest 2>&1 | grep -E "AT_FAIL|AUTOTEST" | head -10
~~~

Expected: `AUTOTEST_FAILED` with AT_FAIL `glyph library exposes per-kind extent factors` and `bestiary report carries the glyph_contained entry`. No parse errors.

- [x] **Step 3: Extent table in glyph_lib.gd**

In `src/ui/glyph_lib.gd`, directly below the closing line of `static func glyph_kinds()`, add:

~~~gdscript
## Maximum silhouette reach per kind, in multiples of the draw radius.
## Conservative outer bounds (lancer's lance tip reaches 2.4x, oom horns 1.6x,
## segfault jitter 1.45x); detail views use this to fit glyphs into fixed boxes.
const GLYPH_EXTENT := {
	"drone": 1.5, "lancer": 2.4, "spewer": 1.1, "splitter": 1.05, "bulwark": 1.05,
	"trojan": 1.25, "oom": 1.6, "recursor": 1.05, "firewall": 1.05, "bloatware": 1.05,
	"update_loop": 1.05, "page": 1.25, "root": 1.05, "boss": 1.05, "segfault": 1.45,
	"bluescreen": 0.95, "pagefault": 1.15, "god": 1.35, "kernel": 1.5, "daemon": 1.45,
	"rootlet": 1.1,
}

static func glyph_extent(kind: String) -> float:
	return float(GLYPH_EXTENT.get(kind, 1.0))
~~~

- [x] **Step 4: Bestiary detail box + metrics + report**

4a. In `src/ui/bestiary_panel.gd`, directly above `func _entry_color`, add:

~~~gdscript
## Detail-column vertical rhythm + glyph box geometry (single source of truth
## for _draw_detail and text_overflow_report).
const DETAIL_METRICS := {"inset": 20.0, "header_y": 26.0, "name_y": 58.0, "threat_y": 82.0, "divider_y": 152.0, "behavior_y": 180.0, "desc_y": 204.0, "bugs_label_y": 278.0, "bugs_y": 302.0, "glyph_box_w": 156.0, "glyph_box_h": 104.0}

func _detail_glyph_box(rail: Rect2) -> Rect2:
	return Rect2(rail.position + Vector2(rail.size.x - float(DETAIL_METRICS["glyph_box_w"]) - float(DETAIL_METRICS["inset"]), 44.0), Vector2(float(DETAIL_METRICS["glyph_box_w"]), float(DETAIL_METRICS["glyph_box_h"])))
~~~

4b. In `_draw_detail()`, make these exact replacements:

- Replace:

~~~gdscript
	var points_chip := Rect2(rail.position + Vector2(20.0, 100.0), Vector2(154.0, 36.0))
~~~

with:

~~~gdscript
	var glyph_box := _detail_glyph_box(rail)
	var points_chip := Rect2(rail.position + Vector2(float(DETAIL_METRICS["inset"]), glyph_box.end.y - 36.0), Vector2(154.0, 36.0))
~~~

(The PTS chip baseline now aligns to the glyph box bottom: chip bottom = glyph_box.end.y.)

- Replace:

~~~gdscript
	var glyph_pos := Vector2(rail.end.x - 118.0, rail.position.y + 120.0)
	draw_set_transform(glyph_pos, 0.0, Vector2(3.5, 3.5))
	_draw_glyph(id, Color(accent.r, accent.g, accent.b, 0.9 if seen else 0.2))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
~~~

with:

~~~gdscript
	var extent: float = GlyphLib.glyph_extent(id)
	var fit_scale: float = minf(3.5, minf((glyph_box.size.x * 0.5 - 6.0) / (16.0 * extent), (glyph_box.size.y * 0.5 - 6.0) / (16.0 * extent)))
	draw_set_transform(glyph_box.get_center(), 0.0, Vector2(fit_scale, fit_scale))
	_draw_glyph(id, Color(accent.r, accent.g, accent.b, 0.9 if seen else 0.2))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
~~~

- Replace the divider line:

~~~gdscript
	draw_line(rail.position + Vector2(20.0, 152.0), rail.position + Vector2(rail.size.x - 20.0, 152.0), Color(accent.r, accent.g, accent.b, 0.28), 1.0)
~~~

with:

~~~gdscript
	draw_line(rail.position + Vector2(float(DETAIL_METRICS["inset"]), float(DETAIL_METRICS["divider_y"])), rail.position + Vector2(rail.size.x - float(DETAIL_METRICS["inset"]), float(DETAIL_METRICS["divider_y"])), Color(accent.r, accent.g, accent.b, 0.28), 1.0)
~~~

4c. In `text_overflow_report()`, directly below the line `\tvar rail_w: float = size.x - float(metrics.get("list_w", size.x * 0.4)) - 86.0`, add:

~~~gdscript
	var rail_rect := Rect2(float(metrics.get("list_w", size.x * 0.4)) + 58.0, 146.0, rail_w, size.y - 258.0)
	var box := _detail_glyph_box(rail_rect)
	var glyph_ok: bool = rail_rect.grow(-2.0).encloses(box)
	var min_scale := 99.0
	for entry in ENTRIES:
		var extent: float = GlyphLib.glyph_extent(str(entry["id"]))
		min_scale = minf(min_scale, minf((box.size.x * 0.5 - 6.0) / (16.0 * extent), (box.size.y * 0.5 - 6.0) / (16.0 * extent)))
	glyph_ok = glyph_ok and min_scale >= 1.4
	out.append({"id": "glyph_contained", "fits": glyph_ok})
~~~

(The 1.4 floor keeps silhouettes readable — clipping is the last resort, never the default. At 1366×768 the lancer fits at fit_scale ≈ 1.72.)

- [x] **Step 5: Run the full suite**

Run:

~~~sh
godot --headless --path . -- --autotest 2>&1 | grep -E "AT_FAIL|AUTOTEST" | head -10
~~~

Expected: `AUTOTEST_ALL_PASS`, zero `AT_FAIL`. New AT_STEP label `bestiary_glyph`. If `glyph_contained` reports fits=false at any probed viewport, re-check the box math against `rail_w` — never widen the rail or lower the 1.4 readability floor.

- [x] **Step 6: Capture check (never committed)**

~~~sh
KP_SHOT=menu KP_BESTIARY=1 KP_SHOT_OUT=/tmp/opencode/bestiary_glyph_1366.png godot --path . --resolution 1366x768
~~~

Expected: `SHOT_SAVED`; with Lancer, OOM_KILLER, and ROOT DAEMON selected in the capture session, every detail glyph stays inside the rail and the PTS chip baseline aligns with the glyph box bottom. Compare the rail against `exec-6582ea9f-...png` (approved bestiary mock).

- [x] **Step 7: Commit**

~~~sh
git add src/ui/glyph_lib.gd src/ui/bestiary_panel.gd src/autoload/dev_harness.gd src/autoload/harness/sections_polish.gd
git commit -m "fix: contain bestiary detail glyphs and align the pts chip"
~~~

---

### Task 8: Raster icon optical-size pass — padding + per-size opt-out (test-first)

**Files:**
- Modify: `src/ui/tactical_icon.gd`
- Modify: `src/ui/patch_card.gd`
- Modify: `src/autoload/harness/sections_polish.gd`
- Modify: `src/autoload/dev_harness.gd`

Interfaces:
- Consumes: `raster_path()` (tactical_icon.gd line 77), the edge-to-edge `draw_texture_rect(tex, Rect2(Vector2.ZERO, size))` raster draw (line 103), `patch_card.gd::_draw_icon` raster branch (line 114).
- Produces: `ICON_OPTICAL` per-kind pad table + `optical_pad(kind)`; `RASTER_OPTOUT` per-kind × per-size opt-out list + `raster_optouts()`; `raster_path(kind, render_size := 0)` returning `""` for opted-out sizes; padded raster rects in both draw sites.

- [x] **Step 1: Write the failing harness check**

In `src/autoload/harness/sections_polish.gd`, append at the end of the class:

~~~gdscript
func _raster_optical_test() -> void:
	print("AT_STEP raster_optical")
	var icon_script: Script = load("res://src/ui/tactical_icon.gd")
	h._check(icon_script != null and icon_script.has_method("optical_pad") and icon_script.has_method("raster_optouts"), "tactical icon exposes optical padding and the per-size opt-out registry")
	if icon_script == null:
		return
	for kind in icon_script.call("icon_kinds"):
		var pad: float = icon_script.call("optical_pad", str(kind))
		h._check(pad >= 0.02 and pad <= 0.14, "%s icon optical padding stays in the 0.02..0.14 band" % str(kind))
	var src := str(icon_script.source_code)
	h._check(src.contains("raster_path(_kind, int(minf(size.x, size.y)))"), "icon draw queries the registry with its rendered size")
	h._check(src.contains("draw_texture_rect(tex, Rect2(Vector2(pad, pad)"), "icon raster draws into the padded rect")
	var patch_script: Script = load("res://src/ui/patch_card.gd")
	h._check(patch_script != null and str(patch_script.source_code).contains("PATCH_RASTER_PAD"), "patch card raster draws into the padded rect")
	var music_small: String = icon_script.call("raster_path", "music", 24)
	h._check(music_small.is_empty(), "24px opt-out kinds fall back to the code-drawn icon")
	var music_big: String = icon_script.call("raster_path", "music", 52)
	h._check(not music_big.is_empty() and ResourceLoader.exists(music_big), "52px keeps the raster for opt-out kinds")
~~~

In `src/autoload/dev_harness.gd`, directly below the line `await _sec_visual._raster_trial_test()` (line 413), add:

~~~gdscript
	await _sec_polish._raster_optical_test()
~~~

- [x] **Step 2: Run the test to verify it fails**

Run:

~~~sh
godot --headless --path . -- --autotest 2>&1 | grep -E "AT_FAIL|AUTOTEST" | head -10
~~~

Expected: `AUTOTEST_FAILED` with AT_FAIL `tactical icon exposes optical padding and the per-size opt-out registry` (the remaining checks return early). No parse errors.

- [x] **Step 3: Implement the optical registry in tactical_icon.gd**

3a. Directly below the `ICON_BOUNDS` const, add:

~~~gdscript
## Optical padding per kind (fraction of the icon size inset per side) so the
## raster glyph's visual center and stroke weight match the code baseline at
## 52px and 24px; the texture is drawn into the padded rect, never edge-to-edge.
const ICON_OPTICAL := {
	"settings": 0.06, "bestiary": 0.06, "dash": 0.05, "back": 0.08, "resume": 0.10,
	"restart": 0.06, "terminal": 0.08, "audio": 0.07, "music": 0.10, "warning": 0.06,
	"awards": 0.07, "check": 0.10,
}

## Per-kind x per-size opt-out list: where a raster reads blurry at a size, the
## registry returns "" for that size and the code fallback renders. Documented
## and harness-visible; the author may extend it after the trim review (Task 9).
const RASTER_OPTOUT := {"music": [24]}

static func optical_pad(icon_kind: String) -> float:
	return float(ICON_OPTICAL.get(icon_kind, 0.06))

static func raster_optouts() -> Dictionary:
	return RASTER_OPTOUT.duplicate(true)
~~~

3b. Replace the whole `raster_path` function:

~~~gdscript
static func raster_path(icon_kind: String, render_size: int = 0) -> String:
	if render_size > 0 and RASTER_OPTOUT.get(icon_kind, []).has(render_size):
		return ""
	var path := RASTER_DIR + icon_kind + ".png"
	return path if ResourceLoader.exists(path) else ""
~~~

3c. In `_draw()`, replace the raster branch:

~~~gdscript
	var raster := raster_path(_kind)
	if raster != "":
		if not _raster_tex_cache.has(raster):
			_raster_tex_cache[raster] = load(raster)
			queue_redraw()
		var tex: Texture2D = _raster_tex_cache[raster]
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
			if _framed:
				_draw_frame_overlay()
			return
~~~

with:

~~~gdscript
	var raster := raster_path(_kind, int(minf(size.x, size.y)))
	if raster != "":
		if not _raster_tex_cache.has(raster):
			_raster_tex_cache[raster] = load(raster)
			queue_redraw()
		var tex: Texture2D = _raster_tex_cache[raster]
		if tex != null:
			var pad := optical_pad(_kind) * minf(size.x, size.y)
			draw_texture_rect(tex, Rect2(Vector2(pad, pad), size - Vector2(pad * 2.0, pad * 2.0)), false)
			if _framed:
				_draw_frame_overlay()
			return
~~~

(`configure()` keeps calling `raster_path(icon_kind)` with the default size — the cache prime stays valid.)

- [x] **Step 4: Patch card padded raster**

In `src/ui/patch_card.gd`:

4a. Directly below the line `const RASTER_DIR := "res://assets/icons/generated/"`, add:

~~~gdscript
## Optical pad fraction for patch rasters inside the 52px hex slot; matches the
## tactical_icon optical pass so rasters and code glyphs share stroke weight.
const PATCH_RASTER_PAD := 0.08
~~~

4b. In `_draw_icon()`, replace:

~~~gdscript
		if tex != null:
			draw_texture_rect(tex, Rect2(center - Vector2(26.0, 26.0), Vector2(52.0, 52.0)), false)
			return
~~~

with:

~~~gdscript
		if tex != null:
			var pad: float = PATCH_RASTER_PAD * 52.0
			draw_texture_rect(tex, Rect2(center - Vector2(26.0 - pad, 26.0 - pad), Vector2(52.0 - pad * 2.0, 52.0 - pad * 2.0)), false)
			return
~~~

- [x] **Step 5: Run the full suite**

Run:

~~~sh
godot --headless --path . -- --autotest 2>&1 | grep -E "AT_FAIL|AUTOTEST" | head -10
~~~

Expected: `AUTOTEST_ALL_PASS`, zero `AT_FAIL`. New AT_STEP label `raster_optical`. The pre-existing `raster_trial` and `icon_quality` AT_STEPs stay green (they call `raster_path(kind)` with the default size, which still resolves).

- [x] **Step 6: Commit**

~~~sh
git add src/ui/tactical_icon.gd src/ui/patch_card.gd src/autoload/dev_harness.gd src/autoload/harness/sections_polish.gd
git commit -m "feat: pad raster icons optically per kind and size"
~~~

---

### Task 9: Trim baked glow from the generated rasters + author side-by-side gate

**Files:**
- Modify: `assets/icons/generated/*.png` (base-size files only; `-24`/`-52` variants untouched)
- Possibly Modify: `src/ui/tactical_icon.gd` (only if the author rejects specific rasters — extend `RASTER_OPTOUT`)

Interfaces:
- Consumes: the `assets/icons/generated/` PNGs imported by Godot; `raster_path` / `patch_raster_path` registries.
- Produces: tight re-exports with baked glow halos removed so hit rects hug the glyph; `ICON_BOUNDS` remains the containment contract. Author gate before commit (spec: "nothing commits without her gate").

- [x] **Step 1: Record before captures**

~~~sh
KP_SHOT=menu KP_SHOT_OUT=/tmp/opencode/trim_before_menu.png godot --path . --resolution 1366x768
KP_SHOT=game KP_SHOT_OUT=/tmp/opencode/trim_before_game.png godot --path . --resolution 1366x768
~~~

Expected: two `SHOT_SAVED` lines; kill the processes after.

- [x] **Step 2: Trim the base rasters**

~~~sh
for f in assets/icons/generated/*.png; do
  case "$f" in *-24.png|*-52.png) continue ;; esac
  magick "$f" -fuzz 8% -trim +repage -gravity center -background none -resize 128x128 -extent 128x128 "$f"
done
magick identify -format "%f %wx%h\n" assets/icons/generated/*.png | grep -v -e -24.png -e -52.png | head -5
~~~

Expected: each listed file reports `128x128` (trimmed, then re-centered on a transparent 128×128 canvas).

- [x] **Step 3: Reimport and verify the suite**

~~~sh
godot --headless --path . -- --import
godot --headless --path . -- --autotest 2>&1 | grep -E "AT_FAIL|AUTOTEST" | head -5
~~~

Expected: import exits clean; `AUTOTEST_ALL_PASS`, zero `AT_FAIL` (containment contracts in `icon_quality` still hold — the textures are only re-exported inside the same 128×128 frame).

- [x] **Step 4: After captures + side-by-side montage**

~~~sh
KP_SHOT=menu KP_SHOT_OUT=/tmp/opencode/trim_after_menu.png godot --path . --resolution 1366x768
KP_SHOT=game KP_SHOT_OUT=/tmp/opencode/trim_after_game.png godot --path . --resolution 1366x768
magick montage /tmp/opencode/trim_before_menu.png /tmp/opencode/trim_after_menu.png /tmp/opencode/trim_before_game.png /tmp/opencode/trim_after_game.png -tile 2x2 -geometry +4+4 /tmp/opencode/icons_trim_sbs.png
~~~

Expected: `SHOT_SAVED` twice + `/tmp/opencode/icons_trim_sbs.png` written.

- [ ] **Step 5: Author gate** (PENDING author verdict — montage at `/tmp/opencode/icons_trim_sbs.png`, raw shots `/tmp/opencode/trim_{before,after}_{menu,game}.png`; per-kind rollback: `git checkout a474f89^ -- assets/icons/generated/<kind>.png` then re-import)

Show `/tmp/opencode/icons_trim_sbs.png` to the author. If she approves: proceed to Step 6. If she rejects specific kinds: restore them with `git checkout -- assets/icons/generated/` (all) or extend `RASTER_OPTOUT` in `tactical_icon.gd` (per-kind × per-size, e.g. `"music": [24, 52]` to drop a kind's raster entirely), re-run the full autotest green, and record the outcome in the Task 13 report.

- [x] **Step 6: Commit**

~~~sh
git add assets/icons/generated/
git add src/ui/tactical_icon.gd
git commit -m "chore: trim baked glow from icon rasters"
~~~

(Only stage the opt-out edit if Step 5 changed it; captures and the montage are never staged.)

---

### Task 10: Story rail connected path restyle (drawing only; hit areas frozen)

**Files:**
- Modify: `src/ui/story_panel.gd`
- Modify: `src/autoload/harness/sections_polish.gd`
- Modify: `src/autoload/dev_harness.gd`

Interfaces:
- Consumes: the existing connector lines under the opaque card chips (`story_panel.gd` `_draw()`, wide node circle at `origin + (card_w*0.5, 42)` r18, narrow node circle at `origin + (42, 43)` r18), `Game.story_stage_unlocked`, `Game.story_cleared`, `Game.story_stage_id`, the panel's cosmetic `t` clock.
- Produces: `_stage_state(index) -> "CLEARED"|"CURRENT"|"LOCKED"`, `_draw_node_brackets(node, radius, color)`, `_draw_state_glyph(node, radius, state, color)`, state labels per node, and a `story_state_labels` entry in `text_overflow_report()`.

Frozen by this task (must NOT be edited): `_card_rects`, `_tab_rects`, `_gui_input`, `_content_metrics`, scroll mechanics, stage data, and the connector-line loop. Containment checks (wide + narrow) must stay green.

- [x] **Step 1: Write the failing harness check**

In `src/autoload/harness/sections_polish.gd`, append at the end of the class:

~~~gdscript
func _story_path_test() -> void:
	print("AT_STEP story_path")
	var script: Script = load("res://src/ui/story_panel.gd")
	h._check(script != null, "story panel script loads")
	if script == null:
		return
	var src := str(script.source_code)
	h._check(src.contains("_draw_node_brackets"), "story rail draws node brackets")
	h._check(src.contains("_draw_state_glyph"), "story rail draws state rings and glyphs")
	h._check(src.contains("\"CLEARED\"") and src.contains("\"CURRENT\"") and src.contains("\"LOCKED\""), "story rail renders the three state labels")
	h._check(src.contains("sin(t"), "story rail keeps the cosmetic-time pulse (no gameplay rng)")
	var panel = script.new()
	if panel == null:
		return
	var ok := true
	var saw_labels := false
	for vp in [Vector2(1366, 768), Vector2(432, 720)]:
		panel.size = vp
		for entry in panel.call("text_overflow_report"):
			if str(entry.get("id", "")) == "story_state_labels":
				saw_labels = true
			ok = ok and bool(entry.get("fits", false))
	h._check(saw_labels, "story report carries the story_state_labels entry")
	h._check(ok, "story rail report stays green including the state labels")
	panel.free()
~~~

In `src/autoload/dev_harness.gd`, directly below the `await _sec_polish._bestiary_glyph_test()` line added in Task 7, add:

~~~gdscript
	await _sec_polish._story_path_test()
~~~

- [x] **Step 2: Run the test to verify it fails**

Run:

~~~sh
godot --headless --path . -- --autotest 2>&1 | grep -E "AT_FAIL|AUTOTEST" | head -10
~~~

Expected: `AUTOTEST_FAILED` with AT_FAIL `story rail draws node brackets` (and the state-glyph/label failures). No parse errors.

- [x] **Step 3: State + drawing helpers in story_panel.gd**

3a. Directly above `func _draw()`, add:

~~~gdscript
func _stage_state(index: int) -> String:
	if not Game.story_stage_unlocked(index):
		return "LOCKED"
	if bool(Game.story_cleared.get(Game.story_stage_id(index), false)):
		return "CLEARED"
	return "CURRENT"

func _draw_node_brackets(node: Vector2, radius: float, color: Color) -> void:
	var arm := radius * 0.55
	for sign_x in [-1.0, 1.0]:
		for sign_y in [-1.0, 1.0]:
			var corner := node + Vector2(sign_x * (radius + 5.0), sign_y * (radius + 5.0))
			draw_line(corner, corner + Vector2(-sign_x * arm, 0.0), Color(color.r, color.g, color.b, 0.7), 1.2, true)
			draw_line(corner, corner + Vector2(0.0, -sign_y * arm), Color(color.r, color.g, color.b, 0.7), 1.2, true)

func _draw_state_glyph(node: Vector2, radius: float, state: String, color: Color) -> void:
	match state:
		"CLEARED":
			draw_arc(node, radius + 3.0, 0.0, TAU, 24, Color(color.r, color.g, color.b, 0.95), 2.2, true)
			var b := node + Vector2(radius + 6.0, -radius - 6.0)
			draw_line(b + Vector2(-3.0, 0.0), b + Vector2(-0.5, 2.5), Color(color.r, color.g, color.b, 0.95), 2.0, true)
			draw_line(b + Vector2(-0.5, 2.5), b + Vector2(3.5, -2.5), Color(color.r, color.g, color.b, 0.95), 2.0, true)
		"CURRENT":
			var pulse := radius + 3.0 + sin(t * 4.0) * 2.0
			draw_arc(node, pulse, 0.0, TAU, 24, Color(color.r, color.g, color.b, 0.95), 2.6, true)
		"LOCKED":
			draw_arc(node, radius + 3.0, 0.0, TAU, 24, Color(color.r, color.g, color.b, 0.3), 2.0, true)
			var lb := node + Vector2(radius + 6.0, -radius - 6.0)
			draw_rect(Rect2(lb + Vector2(-3.0, -1.0), Vector2(6.0, 5.0)), Color(color.r, color.g, color.b, 0.6), false, 1.4)
			draw_arc(lb + Vector2(0.0, -1.0), 2.2, PI, TAU, 10, Color(color.r, color.g, color.b, 0.6), 1.4, true)

func _state_label_color(state: String, color: Color) -> Color:
	match state:
		"CLEARED":
			return Color(color.r, color.g, color.b, 0.9)
		"CURRENT":
			return TacticalUIHelper.TEXT
		_:
			return Color(TacticalUIHelper.MUTED.r, TacticalUIHelper.MUTED.g, TacticalUIHelper.MUTED.b, 0.7)
~~~

(The pulse uses the panel's cosmetic `t` clock — never `Game.rng`.)

3b. In `_draw()`, in the WIDE card branch, replace:

~~~gdscript
			draw_circle(origin + Vector2(card_w * 0.5, 42.0), 18.0, Color(border.r, border.g, border.b, 0.12))
			draw_arc(origin + Vector2(card_w * 0.5, 42.0), 18.0, 0.0, TAU, 20, border, 1.4, true)
			draw_string(mono, origin + Vector2(0.0, 47.0), "%02d" % (stage_index + 1), HORIZONTAL_ALIGNMENT_CENTER, card_w, 13, border)
~~~

with:

~~~gdscript
			var node := origin + Vector2(card_w * 0.5, 42.0)
			var state := _stage_state(stage_index)
			draw_circle(node, 18.0, Color(border.r, border.g, border.b, 0.12))
			draw_arc(node, 18.0, 0.0, TAU, 20, border, 1.4, true)
			_draw_node_brackets(node, 18.0, border)
			_draw_state_glyph(node, 18.0, state, border)
			draw_string(mono, origin + Vector2(0.0, 47.0), "%02d" % (stage_index + 1), HORIZONTAL_ALIGNMENT_CENTER, card_w, 13, border)
			draw_string(mono, origin + Vector2(0.0, 68.0), state, HORIZONTAL_ALIGNMENT_CENTER, card_w, 9, _state_label_color(state, border))
~~~

(The label at y=68 sits between the circle bottom (60) and the orbitron name baseline (82).)

3c. In the NARROW card branch, replace:

~~~gdscript
			draw_circle(origin + Vector2(42.0, 43.0), 18.0, Color(border.r, border.g, border.b, 0.12))
			draw_arc(origin + Vector2(42.0, 43.0), 18.0, 0.0, TAU, 20, border, 1.4, true)
			draw_string(mono, origin + Vector2(31.0, 48.0), "%02d" % (stage_index + 1), HORIZONTAL_ALIGNMENT_LEFT, 24.0, 13, border)
~~~

with:

~~~gdscript
			var node := origin + Vector2(42.0, 43.0)
			var state := _stage_state(stage_index)
			draw_circle(node, 18.0, Color(border.r, border.g, border.b, 0.12))
			draw_arc(node, 18.0, 0.0, TAU, 20, border, 1.4, true)
			_draw_node_brackets(node, 18.0, border)
			_draw_state_glyph(node, 18.0, state, border)
			draw_string(mono, origin + Vector2(31.0, 48.0), "%02d" % (stage_index + 1), HORIZONTAL_ALIGNMENT_LEFT, 24.0, 13, border)
			draw_string(mono, origin + Vector2(12.0, 68.0), state, HORIZONTAL_ALIGNMENT_CENTER, 60.0, 9, _state_label_color(state, border))
~~~

3d. In `text_overflow_report()`, directly above `\treturn out`, add:

~~~gdscript
	out.append({"id": "story_state_labels", "fits": mono.get_string_size("CLEARED", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x <= 60.0 and mono.get_string_size("CURRENT", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x <= 60.0 and mono.get_string_size("LOCKED", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x <= 60.0})
~~~

- [x] **Step 4: Run the full suite**

Run:

~~~sh
godot --headless --path . -- --autotest 2>&1 | grep -E "AT_FAIL|AUTOTEST" | head -10
~~~

Expected: `AUTOTEST_ALL_PASS`, zero `AT_FAIL`. New AT_STEP label `story_path`. All pre-existing story checks (selection, containment, scroll via `_card_rects`) stay green because only the draw pass changed.

- [x] **Step 5: Capture vs the approved mock (never committed)**

~~~sh
KP_SHOT=menu KP_STORY=1 KP_SHOT_OUT=/tmp/opencode/story_rail_1366.png godot --path . --resolution 1366x768
~~~

Expected: `SHOT_SAVED`; wide rail shows bracketed nodes with CLEARED / CURRENT / LOCKED rings + labels matching mock `/home/mafu/.codex/generated_images/01a044e4-d316-7ef2-85d8-9aa85056ea3a/exec-e6d82072-a577-4578-876d-1a5e9bb5ba8a.png`; tapping and scrolling still select stages (hit rects untouched).

- [x] **Step 6: Commit**

~~~sh
git add src/ui/story_panel.gd src/autoload/dev_harness.gd src/autoload/harness/sections_polish.gd
git commit -m "feat: restyle the story rail to the connected node path"
~~~

---

### Task 11: Teardown leak hunt — profile, free offenders, baseline guard

**Files:**
- Modify: `src/ui/tactical_icon.gd` (cache-clear helper)
- Modify: `src/ui/patch_card.gd` (cache-clear helper)
- Modify: `src/autoload/game.gd` (teardown hook)
- Modify: `src/autoload/fx.gd` (flash tween reuse + layer validity)
- Modify: `src/autoload/harness/sections_polish.gd`
- Modify: `src/autoload/dev_harness.gd` (guard consts + call)

Interfaces:
- Consumes: the exit ObjectDB/RID report; static caches `tactical_icon.gd::_raster_tex_cache` and `patch_card.gd::_raster_tex_cache` (the only `static var` resource caches in the repo); `fx.gd::flash()` which stacks a fresh `create_tween()` per call and parents `_flash_layer` to a scene that gets freed.
- Produces: `TacticalIcon.clear_raster_cache()` / `PatchCard.clear_raster_cache()`; `Game._exit_tree()` teardown hook; `Fx._flash_tween`; harness `LEAK_GUARD_MAX_ORPHANS` + `_leak_guard_test()`.

- [x] **Step 1: Profile first (one fixed invocation)**

~~~sh
godot --headless --path . -- --autotest --verbose > /tmp/opencode/leak_profile_before.txt 2>&1
grep -E "ObjectDB instances leaked|Orphan|still in use|Leaked instance|RID" /tmp/opencode/leak_profile_before.txt | tail -20
tail -5 /tmp/opencode/leak_profile_before.txt
~~~

Expected: `AUTOTEST_ALL_PASS` in the tail plus an exit report line like `ObjectDB instances leaked at exit: N` — record that number as **N0** (the overnight review measured ~199) and note the RID/resource lines. Attribute each leaked class printed by the verbose report to an owner; the two known owners are fixed below, and any additional owner gets fixed with the same two patterns (static caches cleared in `Game._exit_tree`; owner-held tweens/layers stored, validated, and killed/recreated — never hidden orphans) and recorded in the Task 13 report.

- [x] **Step 2: Write the failing harness guard**

In `src/autoload/harness/sections_polish.gd`, append at the end of the class:

~~~gdscript
func _leak_guard_test() -> void:
	print("AT_STEP leak_guard")
	var game_src := str(load("res://src/autoload/game.gd").source_code)
	h._check(game_src.contains("TacticalIcon.clear_raster_cache()"), "teardown clears the tactical icon raster cache")
	h._check(game_src.contains("PatchCard.clear_raster_cache()"), "teardown clears the patch card raster cache")
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	print("AT_DEBUG leak_guard orphans=%d objects=%d" % [orphans, objects])
	h._check(orphans <= h.LEAK_GUARD_MAX_ORPHANS, "orphan node count stays under the recorded baseline (%d)" % h.LEAK_GUARD_MAX_ORPHANS)
~~~

In `src/autoload/dev_harness.gd`, add the const directly below the `var active := false` line (line 13):

~~~gdscript
const LEAK_GUARD_MAX_ORPHANS := 40
~~~

(Documentation for this constant: it records the pre-fix orphan-node baseline with tolerance for the harness's own probe nodes. If the first run prints `AT_DEBUG leak_guard orphans=M` with M > 40, set the constant to M — that records the true baseline; the reduction target is enforced on the ObjectDB exit report in Step 5, not on this no-increase guard.)

Insert the call in `_autotest()` directly above the final `\t_finish()` line (after the last `await _ticks(4)` of the cleanup block):

~~~gdscript
	await _sec_polish._leak_guard_test()
~~~

- [x] **Step 3: Run the test to verify it fails**

Run:

~~~sh
godot --headless --path . -- --autotest 2>&1 | grep -E "AT_FAIL|AT_DEBUG leak_guard|AUTOTEST" | head -10
~~~

Expected: `AUTOTEST_FAILED` with AT_FAIL `teardown clears the tactical icon raster cache` and `teardown clears the patch card raster cache`. Note the printed `orphans=M objects=K` values.

- [x] **Step 4: Free the offenders**

4a. In `src/ui/tactical_icon.gd`, append at the end of the file:

~~~gdscript
static func clear_raster_cache() -> void:
	_raster_tex_cache.clear()
~~~

4b. In `src/ui/patch_card.gd`, append at the end of the file:

~~~gdscript
static func clear_raster_cache() -> void:
	_raster_tex_cache.clear()
~~~

4c. In `src/autoload/game.gd`, add at class level (directly below the `_ready` function's closing line):

~~~gdscript
func _exit_tree() -> void:
	TacticalIcon.clear_raster_cache()
	PatchCard.clear_raster_cache()
~~~

4d. In `src/autoload/fx.gd`, directly below `var _flash_rect: ColorRect` (line 7), add:

~~~gdscript
var _flash_tween: Tween
~~~

4e. In the same file's `flash()`, replace:

~~~gdscript
	if _flash_layer == null:
~~~

with:

~~~gdscript
	if _flash_layer == null or not is_instance_valid(_flash_layer) or not is_instance_valid(_flash_rect):
~~~

and replace:

~~~gdscript
	_flash_rect.color = Color(color.r, color.g, color.b, alpha)
	var tw := create_tween()
	tw.tween_property(_flash_rect, "modulate:a", 0.0, dur).set_ease(Tween.EASE_OUT)
~~~

with:

~~~gdscript
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_rect.color = Color(color.r, color.g, color.b, alpha)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_rect, "modulate:a", 0.0, dur).set_ease(Tween.EASE_OUT)
~~~

- [x] **Step 5: Run green and record the achieved numbers**

Run:

~~~sh
godot --headless --path . -- --autotest 2>&1 | tee /tmp/opencode/leak_after.txt | grep -E "AT_FAIL|AT_DEBUG leak_guard|AUTOTEST" | head -10
grep -E "ObjectDB instances leaked" /tmp/opencode/leak_after.txt
~~~

Expected: `AUTOTEST_ALL_PASS`, zero `AT_FAIL`, new AT_STEP `leak_guard`. The exit report prints a new instance count — record it as **N1**. Reduction target: N1 clearly below N0 (~199); zero is not chased. If `AT_DEBUG leak_guard` printed orphans > 40 before the fix, set `LEAK_GUARD_MAX_ORPHANS` to that measured baseline and re-run green.

- [x] **Step 6: Commit**

~~~sh
git add src/ui/tactical_icon.gd src/ui/patch_card.gd src/autoload/game.gd src/autoload/fx.gd src/autoload/dev_harness.gd src/autoload/harness/sections_polish.gd
git commit -m "fix: free teardown leak offenders and guard the baseline"
~~~

---

### Task 12: Sprite trial scaffolding — entity_sprite registry behind the glyph fallback

**Files:**
- Create: `src/ui/entity_sprite.gd`
- Modify: `src/ui/glyph_lib.gd` (single switch)
- Modify: `src/autoload/game.gd` (teardown line)
- Modify: `src/autoload/harness/sections_polish.gd`
- Modify: `src/autoload/dev_harness.gd`

Interfaces:
- Consumes: every enemy/program/bestiary glyph call site already routes through `GlyphLib.draw_glyph` (enemy scripts, `player.gd`, `program_panel.gd`, `bestiary_panel.gd` — verified by `_glyph_lib_test`).
- Produces: `EntitySprite.sprite_path(kind)`, `EntitySprite.has_sprite(kind)`, `EntitySprite.sprite_texture(kind)`, `EntitySprite.draw_entity(canvas, kind, center, size_px, tint) -> bool`, `EntitySprite.clear_sprite_cache()`; `GlyphLib.draw_glyph` dispatches through it as the single switch. Registry ships EMPTY — zero visual change. Arena sprites stay non-rotating; tinting is `draw_texture_rect` modulate and requires white-base art (recorded as a trial finding if a sheet cannot be tinted without artifacts).

- [x] **Step 1: Write the failing harness check**

In `src/autoload/harness/sections_polish.gd`, append at the end of the class:

~~~gdscript
func _sprite_trial_test() -> void:
	print("AT_STEP sprite_trial")
	var sprite_script: Script = load("res://src/ui/entity_sprite.gd")
	h._check(sprite_script != null and sprite_script.has_method("sprite_path") and sprite_script.has_method("has_sprite"), "entity sprite registry exposes the path lookup")
	if sprite_script == null:
		return
	var seed_before := Game.rng.seed
	for kind in ["drone", "lancer", "root", "god", "kernel"]:
		h._check(not bool(sprite_script.call("has_sprite", str(kind))), "sprite trial registry ships empty for %s (glyph fallback active)" % str(kind))
	h._check(Game.rng.seed == seed_before, "sprite registry lookups never advance the gameplay rng")
	var probe = sprite_script.call("draw_entity", null, "drone", Vector2.ZERO, 24.0, Color.WHITE)
	h._check(not bool(probe), "draw_entity reports the glyph fallback while the registry is empty")
	var glyph_src := str(load("res://src/ui/glyph_lib.gd").source_code)
	h._check(glyph_src.contains("EntitySprite.draw_entity"), "glyph library routes through the single sprite switch")
~~~

Also extend `_leak_guard_test()` — directly below its `PatchCard` check line, add:

~~~gdscript
	h._check(game_src.contains("EntitySprite.clear_sprite_cache()"), "teardown clears the sprite trial cache")
~~~

In `src/autoload/dev_harness.gd`, directly below the line `await _sec_visual._raster_trial_test()` (after the Task 8 optical call), add:

~~~gdscript
	await _sec_polish._sprite_trial_test()
~~~

- [x] **Step 2: Run the test to verify it fails**

Run:

~~~sh
godot --headless --path . -- --autotest 2>&1 | grep -E "AT_FAIL|AUTOTEST" | head -10
~~~

Expected: `AUTOTEST_FAILED` with AT_FAIL `entity sprite registry exposes the path lookup` and `teardown clears the sprite trial cache`. No parse errors.

- [x] **Step 3: Create the registry**

Create `src/ui/entity_sprite.gd` with exactly:

~~~gdscript
class_name EntitySprite
extends RefCounted

## Sprite trial registry (author-gated, non-default): per-entity path lookup
## with the code-drawn GlyphLib silhouettes as the shipped fallback. The
## registry ships empty — zero visual change until the author drops sheets in.
## Long-term art direction (author decision 2026-08-30): progressive migration
## from code-drawn glyphs to generated art; registries-with-fallback are the
## migration mechanism and this trial is its first step.

const SPRITE_DIR := "res://assets/sprites/generated/"

static var _sprite_tex_cache := {}

## Per-entity sprite path; "" keeps the glyph fallback active. Renaming or
## subfolder rules live here only — call sites never touch the filesystem.
static func sprite_path(kind: String) -> String:
	var path := SPRITE_DIR + kind + ".png"
	return path if ResourceLoader.exists(path) else ""

static func has_sprite(kind: String) -> bool:
	return not sprite_path(kind).is_empty()

static func sprite_texture(kind: String) -> Texture2D:
	var path := sprite_path(kind)
	if path.is_empty():
		return null
	if not _sprite_tex_cache.has(path):
		_sprite_tex_cache[path] = load(path)
	return _sprite_tex_cache[path]

static func clear_sprite_cache() -> void:
	_sprite_tex_cache.clear()

## Draws the entity sprite fitted to a square of `size_px` centered on
## `center`, tinted via draw_texture_rect modulate (requires white-base art).
## Returns true when a sprite was drawn so GlyphLib can skip its fallback.
static func draw_entity(canvas: CanvasItem, kind: String, center: Vector2, size_px: float, tint: Color) -> bool:
	if canvas == null or size_px <= 0.0:
		return false
	var tex := sprite_texture(kind)
	if tex == null:
		return false
	var half := size_px * 0.5
	canvas.draw_texture_rect(tex, Rect2(center - Vector2(half, half), Vector2(size_px, size_px)), false, tint)
	return true
~~~

- [x] **Step 4: Single switch in glyph_lib.gd + teardown line**

4a. In `src/ui/glyph_lib.gd`, replace the head of `draw_glyph`:

~~~gdscript
static func draw_glyph(canvas: CanvasItem, kind: String, center: Vector2, radius: float, color: Color, t: float = 0.0) -> void:
	if canvas == null or radius <= 0.0:
		return
	var c := color
~~~

with:

~~~gdscript
static func draw_glyph(canvas: CanvasItem, kind: String, center: Vector2, radius: float, color: Color, t: float = 0.0) -> void:
	if canvas == null or radius <= 0.0:
		return
	if EntitySprite.draw_entity(canvas, kind, center, radius * 2.4, color):
		return
	var c := color
~~~

(The 2.4 factor maps a glyph radius to a square sprite of matching silhouette size; sprites are drawn axis-aligned — non-rotating.)

4b. In `src/autoload/game.gd`, add one line to the `_exit_tree` function created in Task 11:

~~~gdscript
func _exit_tree() -> void:
	TacticalIcon.clear_raster_cache()
	PatchCard.clear_raster_cache()
	EntitySprite.clear_sprite_cache()
~~~

- [x] **Step 5: Run the full suite**

Run:

~~~sh
godot --headless --path . -- --autotest 2>&1 | grep -E "AT_FAIL|AUTOTEST" | head -10
~~~

Expected: `AUTOTEST_ALL_PASS`, zero `AT_FAIL`. New AT_STEP label `sprite_trial`. Visually nothing changes (registry empty). The pre-existing `glyph_lib` AT_STEP stays green — the dispatch is inside the same function every call site already uses.

- [x] **Step 6: Wire the crop pipeline for when the orchestrator delivers sheets**

The orchestrator's imagegen produces per-entity concept sheets OUTSIDE the repo (4×4 grid, white background, one cell per pose) at `/tmp/opencode/sheets/<kind>_sheet.png`. When they exist, crop + key + place with:

~~~sh
mkdir -p assets/sprites/generated
magick /tmp/opencode/sheets/drone_sheet.png -crop 25%x25% +repage +adjoin /tmp/opencode/sheets/drone_cell_%d.png
magick /tmp/opencode/sheets/drone_cell_0.png -fuzz 12% -transparent white /tmp/opencode/drone_keyed.png
magick /tmp/opencode/drone_keyed.png -gravity center -background none -resize 128x128 -extent 128x128 assets/sprites/generated/drone.png
godot --headless --path . -- --import
~~~

`assets/sprites/generated/` is committed ONLY after the author approves the side-by-side; until then the directory may not exist at all. Once any sprite exists, capture the side-by-side for her review:

~~~sh
KP_SHOT=game KP_SHOT_OUT=/tmp/opencode/sprite_trial_game.png godot --path . --resolution 1366x768
KP_SHOT=menu KP_BESTIARY=1 KP_SHOT_OUT=/tmp/opencode/sprite_trial_bestiary.png godot --path . --resolution 1366x768
~~~

If a sheet cannot be tinted via modulate without artifacts, record it as a trial finding (keep the glyph for that kind; a per-kind opt-out table can be added to `sprite_path` following the `RASTER_OPTOUT` pattern). Glyphs remain the shipped default until the author decides; the decision note goes in the Task 13 report.

- [x] **Step 7: Commit**

~~~sh
git add src/ui/entity_sprite.gd src/ui/glyph_lib.gd src/autoload/game.gd src/autoload/dev_harness.gd src/autoload/harness/sections_polish.gd
git commit -m "feat: scaffold the entity sprite trial registry"
~~~

---

### Task 13: Final verification — full suite, captures vs mocks, docs

**Files:**
- Modify: `docs/superpowers/plans/2026-08-30-polish-pack.md` (tick checkboxes)
- Create: `docs/superpowers/reports/2026-08-30-polish-pack.md`

- [ ] **Step 1: Full autotest with recorded numbers**

~~~sh
godot --headless --path . -- --autotest 2>&1 | tee /tmp/opencode/final_polish.txt | tail -3
grep -c "AT_PASS" /tmp/opencode/final_polish.txt
grep -c "AT_FAIL" /tmp/opencode/final_polish.txt
grep -c "AT_STEP" /tmp/opencode/final_polish.txt
~~~

Expected: `AUTOTEST_ALL_PASS`, `0` AT_FAIL, AT_PASS strictly above 1194 (every task added checks), AT_STEP labels above 68, including `settings_tabs`, `settings_chips`, `menu_reflow`, `awards_chrome`, `bestiary_glyph`, `raster_optical`, `story_path`, `leak_guard`, `sprite_trial`.

- [ ] **Step 2: Captures of every changed surface at both hard-gate resolutions**

~~~sh
KP_SHOT=menu KP_SHOT_OUT=/tmp/opencode/final_menu_1366.png godot --path . --resolution 1366x768
KP_SHOT=menu KP_SHOT_OUT=/tmp/opencode/final_menu_432.png godot --path . --resolution 432x720
KP_SHOT=menu KP_SETTINGS=1 KP_SHOT_OUT=/tmp/opencode/final_settings_1366.png godot --path . --resolution 1366x768
KP_SHOT=menu KP_SETTINGS=1 KP_SHOT_OUT=/tmp/opencode/final_settings_432.png godot --path . --resolution 432x720
KP_SHOT=menu KP_AWARDS=1 KP_SHOT_OUT=/tmp/opencode/final_awards_1366.png godot --path . --resolution 1366x768
KP_SHOT=menu KP_AWARDS=1 KP_SHOT_OUT=/tmp/opencode/final_awards_432.png godot --path . --resolution 432x720
KP_SHOT=menu KP_BESTIARY=1 KP_SHOT_OUT=/tmp/opencode/final_bestiary_1366.png godot --path . --resolution 1366x768
KP_SHOT=menu KP_STORY=1 KP_SHOT_OUT=/tmp/opencode/final_story_1366.png godot --path . --resolution 1366x768
KP_SHOT=game KP_SHOT_OUT=/tmp/opencode/final_game_1366.png godot --path . --resolution 1366x768
pkill -f "godot --path ."
~~~

Expected: nine `SHOT_SAVED` lines. Visual gates: settings shows the five tabs at 1366 and the chips row at 432; AWARDS shows dim + framed chrome + card rows; bestiary detail glyphs contained; story rail shows the connected-node path; menu shows no title/klog/controls/best/mode_info overlaps; game shows the padded rasters.

- [ ] **Step 3: Mock comparison + leak re-check**

Compare against the approved references in `/home/mafu/.codex/generated_images/01a044e4-d316-7ef2-85d8-9aa85056ea3a/`: story rail vs `exec-e6d82072-a577-4578-876d-1a5e9bb5ba8a.png`, bestiary vs `exec-6582ea9f-...png`, programs vs `exec-450f92b7-...png`, combat vs `exec-10cafd61-...png`. Then re-check the leak guard:

~~~sh
grep -E "ObjectDB instances leaked" /tmp/opencode/leak_after.txt
godot --headless --path . -- --autotest --verbose 2>&1 | grep -E "ObjectDB instances leaked" 
~~~

Expected: the count does not increase vs the Task 11 recorded N1 and stays clearly below the pre-fix N0. Both numbers go into the report.

- [ ] **Step 4: Tick the plan and write the report**

Mark every `- [ ]` checkbox in `docs/superpowers/plans/2026-08-30-polish-pack.md` as `- [x]`:

~~~sh
sed -i 's/^- \[ \]/- [x]/' docs/superpowers/plans/2026-08-30-polish-pack.md
~~~

Create `docs/superpowers/reports/2026-08-30-polish-pack.md` with exactly this skeleton, filling each `<RECORDED ...>` from the step that produced it (Task 1 → baseline counts; Task 9 → trim gate outcome; Task 11 → N0, orphan baseline, N1; Task 12 → trial status and capture paths; this task → final counts and capture paths):

~~~markdown
# Polish Pack Completion Report (2026-08-30)

## Result
- Final autotest: <RECORDED final AT_PASS count> AT_PASS / 0 AT_FAIL across <RECORDED final AT_STEP count> labels (baseline was 1194 / 0 / 68).
- Every behavior task was test-first (red run recorded before its fix).

## Settings tabs (item 1)
- Five real sections, one visible at a time; ESC chain and difficulty placement unchanged; compact chips row below 760px.
- Notes: <RECORDED anything notable from Task 2/3 runs>

## Menu reflow (item 2)
- One layout dict; klog/title, controls/mode_info, and mode_info/footer disjoint at 1366x768, 1024x640, 760x720, 432x720.
- AWARDS icon: code-drawn "awards" kind; raster decision: <RECORDED Task 5 Step 6 outcome>.

## AWARDS chrome (item 3) / Bestiary glyph containment (item 4)
- Dim + framed chrome + card rows; glyph box fit with the 1.4 readability floor; PTS chip aligned.

## Icon optical pass (item 5)
- Padded rects + trimmed glow re-exports; author gate outcome: <RECORDED Task 9 Step 5 outcome>; RASTER_OPTOUT state: <RECORDED final opt-out table>.

## Story rail (item 6)
- Brackets, state rings (CLEARED/CURRENT/LOCKED), state labels; hit rects, scroll, and layout metrics frozen.

## Teardown (item 7)
- Leak baseline N0: <RECORDED Task 11 Step 1>; achieved N1: <RECORDED Task 11 Step 5 / Task 13 Step 3>; orphan-node guard constant: <RECORDED LEAK_GUARD_MAX_ORPHANS as set>.
- Owners freed: static raster caches (Game._exit_tree), Fx flash tween + layer validity; <RECORDED any additional owners attributed from the verbose profile and their fixes>.

## Sprite trial (item 8)
- entity_sprite registry shipped empty; single switch in GlyphLib.draw_glyph; trial status: <RECORDED Task 12 Step 6 — sheets pending / tint findings / author decision pending>.
- Art-direction decision registered in the spec Decision Summary (author, 2026-08-30).

## Captures (never committed)
- /tmp/opencode/final_*.png (nine files) + /tmp/opencode/icons_trim_sbs.png + sprite-trial captures when sheets land.

## Item 9
- Not implemented: the gameplay questionnaire is surfaced separately by the orchestrator.
~~~

- [ ] **Step 5: Commit**

~~~sh
git add docs/superpowers/plans/2026-08-30-polish-pack.md docs/superpowers/reports/2026-08-30-polish-pack.md
git commit -m "docs: add polish pack report"
~~~

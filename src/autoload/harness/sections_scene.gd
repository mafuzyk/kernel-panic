extends RefCounted

## Autotest section script. Function bodies below are moved verbatim from
## src/autoload/dev_harness.gd; only harness-helper references are prefixed
## with `h` per plan section G3. No behavior changes. AT_STEP labels and
## message strings are byte-identical to the originals.

var h: Node


func _init(harness: Node) -> void:
	h = harness

func _story_menu_test(menu: Node) -> void:
	print("AT_STEP story_menu")
	var story_panel_script: Script = load("res://src/ui/story_panel.gd")
	h._check(story_panel_script != null, "story selector script loads")
	h._check(menu.has_method("_open_story_selector") and menu.get("_story_btn") != null, "menu exposes a separate Story entry")
	if story_panel_script == null or not menu.has_method("_open_story_selector"):
		return
	menu.call("_open_story_selector")
	await h._ticks(2)
	var panel = menu.get("_story_panel")
	h._check(panel != null and panel.visible, "story selector opens without changing endless mode")
	if panel != null:
		h._check(panel.has_method("available_stage_indices") and panel.has_method("select_stage"), "story selector exposes stage interaction API")
		h._check(panel.available_stage_indices().has(0), "first Story stage is selectable")
	menu.call("_close_story_selector")
	await h._ticks(1)
	h._check(not panel.visible, "story selector closes cleanly")

func _menu_shell_test(menu: Node) -> void:
	print("AT_STEP menu_shell")
	h._check(menu.has_method("main_shell_snapshot"), "menu exposes main shell snapshot")
	h._check(menu.has_method("settings_shell_snapshot"), "menu exposes settings shell snapshot")
	h._check(menu.has_method("settings_layout_for_viewport"), "settings exposes responsive workstation geometry")
	if menu.has_method("settings_layout_for_viewport"):
		for viewport_size in [Vector2(1366, 768), Vector2(820, 768), Vector2(720, 720), Vector2(432, 720)]:
			var settings_layout: Dictionary = menu.settings_layout_for_viewport(viewport_size)
			var settings_bounds := Rect2(Vector2.ZERO, viewport_size)
			for rect_key in ["workstation", "navigation", "content", "footer", "title"]:
				h._check(settings_bounds.encloses(settings_layout[rect_key]), "settings %s stays inside viewport at %dx%d" % [rect_key, int(viewport_size.x), int(viewport_size.y)])
			h._check(settings_layout["navigation"].position.x < settings_layout["content"].position.x, "settings navigation precedes content at %dx%d" % [int(viewport_size.x), int(viewport_size.y)])
	if menu.has_method("main_shell_snapshot"):
		var main_snapshot: Dictionary = menu.main_shell_snapshot()
		h._check(str(main_snapshot.get("title", "")).contains("KERNEL PANIC"), "main shell exposes kernel panic title")
		h._check(str(main_snapshot.get("primary_action", "")).contains("PURGE"), "main shell exposes primary purge action")
		h._check(not str(main_snapshot.get("mode_explanation", "")).strip_edges().is_empty(), "main shell exposes mode explanation")
		var routes: Array = main_snapshot.get("routes", [])
		h._check(routes.has("PROGRAM") and routes.has("STORY") and routes.has("BESTIARY"), "main shell exposes program story and bestiary routes")
		h._check(main_snapshot.has("shell_rect") and main_snapshot.has("footer_rect"), "main shell exposes shared frame and footer geometry")
		h._check(main_snapshot.has("score_rect") and main_snapshot.has("primary_rect"), "main shell exposes score and primary action geometry")
		if main_snapshot.has("shell_rect") and main_snapshot.has("footer_rect"):
			var main_shell: Rect2 = main_snapshot["shell_rect"]
			h._check(main_shell.encloses(main_snapshot["footer_rect"]), "main footer stays inside shared frame")
		if main_snapshot.has("score_rect") and main_snapshot.has("primary_rect"):
			h._check(not Rect2(main_snapshot["score_rect"]).intersects(Rect2(main_snapshot["primary_rect"])), "main score clears the primary action")
	h._check(menu.has_method("footer_button_layout_for_viewport"), "main footer exposes measured button geometry")
	if menu.has_method("footer_button_layout_for_viewport"):
		var footer_layout: Dictionary = menu.footer_button_layout_for_viewport(Vector2(1400, 768))
		h._check(is_equal_approx(float(footer_layout.get("total_width", 0.0)), 448.0), "main footer matches the approved compact width")
		h._check(is_equal_approx(float(footer_layout.get("button_width", 0.0)), 217.0), "main footer buttons keep equal measured widths")
		h._check(is_equal_approx(float(footer_layout.get("gap", 0.0)), 14.0), "main footer keeps the measured center gap")
		var runtime_footer_layout: Dictionary = menu.footer_button_layout_for_viewport(Vector2(1024, 576))
		h._check(is_equal_approx(float(runtime_footer_layout.get("total_width", 0.0)), 1024.0 * 0.327), "main footer scales from the logical viewport")
	if menu.has_method("settings_shell_snapshot"):
		var settings_snapshot: Dictionary = menu.settings_shell_snapshot()
		var groups: Array = settings_snapshot.get("groups", [])
		h._check(groups.has("AUDIO") and groups.has("GAMEPLAY") and groups.has("CONTROLS") and groups.has("ACCESSIBILITY") and groups.has("SAVE DATA"), "settings shell exposes the five real sections")
		h._check(bool(settings_snapshot.get("scrollable", false)), "settings shell remains scrollable")
		h._check(settings_snapshot.has("shell_rect") and settings_snapshot.has("navigation_rect") and settings_snapshot.has("content_rect") and settings_snapshot.has("footer_rect"), "settings shell exposes workstation geometry")
		if settings_snapshot.has("shell_rect") and settings_snapshot.has("navigation_rect") and settings_snapshot.has("content_rect") and settings_snapshot.has("footer_rect"):
			var settings_shell: Rect2 = settings_snapshot["shell_rect"]
			h._check(settings_shell.encloses(settings_snapshot["navigation_rect"]) and settings_shell.encloses(settings_snapshot["content_rect"]) and settings_shell.encloses(settings_snapshot["footer_rect"]), "settings workstation stays inside shared frame")
			h._check(settings_snapshot["navigation_rect"].position.x < settings_snapshot["content_rect"].position.x, "settings navigation rail precedes content canvas")
		if menu.has_method("_open_settings"):
			menu._open_settings()
			await h._ticks(1)
			var settings_scroll_nodes := menu.find_children("SettingsScroll", "ScrollContainer", true, false)
			h._check(not settings_scroll_nodes.is_empty(), "settings workstation exposes its content scroll")
			if not settings_scroll_nodes.is_empty():
				var settings_scroll: ScrollContainer = settings_scroll_nodes[0]
				h._check(settings_scroll.anchor_left == 0.0 and settings_scroll.anchor_right == 0.0 and settings_scroll.anchor_top == 0.0 and settings_scroll.anchor_bottom == 0.0, "settings scroll uses absolute workstation coordinates")
			var settings_field: LineEdit = menu.get("_save_transfer_field")
			if settings_field != null:
				settings_field.grab_focus()
			h.get_viewport().push_input(h._key_event(KEY_ESCAPE))
			h._check(not bool(menu.get("_settings_panel").visible), "Viewport Escape closes settings with a focused text field")
			menu._close_settings()
	var tactical_surface_script: Script = load("res://src/ui/tactical_state_surface.gd")
	h._check(tactical_surface_script != null and tactical_surface_script.has_method("pause_section_rects"), "pause surface exposes separated volume and warning geometry")
	if tactical_surface_script != null and tactical_surface_script.has_method("pause_section_rects"):
		for viewport_size in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
			var pause_sections: Dictionary = tactical_surface_script.pause_section_rects(viewport_size)
			var pause_panel: Rect2 = tactical_surface_script.panel_rect_for_viewport(viewport_size, "pause")
			var volume_rect: Rect2 = pause_sections["volume"]
			var warning_rect: Rect2 = pause_sections["warning"]
			h._check(pause_panel.encloses(volume_rect) and pause_panel.encloses(warning_rect), "pause sections stay inside panel at %dx%d" % [int(viewport_size.x), int(viewport_size.y)])
			h._check(not volume_rect.intersects(warning_rect), "pause volume and abandon warning keep a visible gap at %dx%d" % [int(viewport_size.x), int(viewport_size.y)])

func _story_scene_test() -> void:
	print("AT_STEP story_scene")
	var saved_mode := Game.mode
	var saved_state := Game.state
	var saved_stage := Game.story_stage_index
	var saved_cleared: Dictionary = Game.story_cleared.duplicate(true)
	var saved_best: Dictionary = Game.story_best.duplicate(true)
	var story_disk: Dictionary = h._config_section_snapshot("story")
	Game.story_cleared = {}
	Game.story_best = {}
	h._check(bool(Game.start_story(0)), "story start accepts the first unlocked stage")
	var loaded: bool = await h._until(func() -> bool:
		return h.get_tree().current_scene != null and h.get_tree().current_scene.name == "Arena", 6.0, "story arena")
	if not loaded:
		return
	var story_arena: Arena = h.get_tree().current_scene
	await h._ticks(3)
	h._check(Game.mode == "story", "story arena loads in story mode")
	h._check(str(story_arena.get("_story_stage").get("path", "")) == "/boot", "story arena loads the selected stage")
	h._check(story_arena.get("_story_intro_panel") != null, "story arena builds an intro card")
	h._check(story_arena.has_method("story_intro_active"), "story arena exposes the intro state query")
	h._check(not story_arena.spawner.story_mode, "story spawner idles during the intro")
	await h._simulation_seconds(1.5)
	h._check(story_arena.enemy_container.get_children().is_empty(), "no enemies spawn during the intro")
	if story_arena.has_method("story_intro_active") and story_arena.has_method("dismiss_story_intro"):
		h._check(story_arena.call("story_intro_active"), "story intro is active on scene load")
		story_arena.set("_story_intro_t", 0.0)
		h._check(not story_arena.call("dismiss_story_intro"), "dismiss input before the minimum hold is ignored")
		story_arena.set("_story_intro_t", 1.0)
		h._check(story_arena.call("dismiss_story_intro"), "dismiss after the minimum hold starts the story")
		await h._ticks(6)
	h._check(story_arena.spawner.story_mode, "story arena uses the scripted spawner")
	story_arena.spawner.stop()
	story_arena.spawner.debug_clear_encounter()
	story_arena.spawner.story_cleared.emit("boot")
	await h._ticks(3)
	h._check(Game.state == Game.State.GAME_OVER and bool(Game.story_cleared.get("boot", false)), "story victory saves the cleared stage")
	h._check(bool(story_arena.get("_story_victory")), "story victory screen is shown")
	Game.story_cleared = saved_cleared
	Game.story_best = saved_best
	h._restore_config_section("story", story_disk)
	Game.mode = saved_mode
	Game.state = saved_state
	Game.story_stage_index = saved_stage
	Game.to_menu()
	await h._until(func() -> bool:
		return h.get_tree().current_scene != null and h.get_tree().current_scene.name == "Menu", 6.0, "story menu return")

func _story_intro_auto_test() -> void:
	print("AT_STEP story_intro_auto")
	var saved_mode := Game.mode
	var saved_state := Game.state
	var saved_stage := Game.story_stage_index
	Game.story_cleared[Game.story_stage_id(0)] = true
	h._check(bool(Game.start_story(0)), "story auto-dismiss test loads the first stage")
	var loaded: bool = await h._until(func() -> bool:
		return h.get_tree().current_scene != null and h.get_tree().current_scene.name == "Arena", 6.0, "story arena")
	if not loaded:
		return
	var auto_arena: Arena = h.get_tree().current_scene
	await h._ticks(3)
	h._check(auto_arena.has_method("story_intro_active"), "auto-dismiss arena exposes the intro state query")
	if auto_arena.has_method("story_intro_active"):
		var dismissed: bool = await h._until(func() -> bool: return not auto_arena.call("story_intro_active"), 12.0, "story intro auto-dismiss")
		h._check(dismissed, "story intro auto-dismisses after 8 seconds without input")
		await h._ticks(6)
		h._check(auto_arena.spawner.story_mode, "auto-dismiss starts story spawning")
	auto_arena.spawner.stop()
	auto_arena.spawner.debug_clear_encounter()
	Game.mode = saved_mode
	Game.state = saved_state
	Game.story_stage_index = saved_stage
	Game.to_menu()
	await h._until(func() -> bool:
		return h.get_tree().current_scene != null and h.get_tree().current_scene.name == "Menu", 6.0, "menu return")

func _story_intro_layout_test() -> void:
	print("AT_STEP story_intro_layout")
	var tui_script: Script = load("res://src/ui/tactical_ui.gd")
	var tui = tui_script.new() if tui_script != null else null
	h._check(tui != null and tui.has_method("fit_block"), "tactical ui exposes fit_block text measurement")
	if tui == null or not tui.has_method("fit_block"):
		return
	var mono: Font = load("res://assets/fonts/ShareTechMono.ttf")
	for vp in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
		var cap := minf(216.0, vp.y * 0.3)
		for stage_index in Game.story_stage_count():
			var intro := str(Game.story_stage_def(stage_index).get("intro", ""))
			var fit: Dictionary = tui.call("fit_block", mono, intro, 344.0, cap, 15, 12)
			h._check(bool(fit.get("fits", false)) and int(fit.get("font_size", 0)) >= 12, "story intro %d measures inside the intro panel at %dx%d" % [stage_index + 1, int(vp.x), int(vp.y)])

func _temple_scene_test() -> void:
	print("AT_STEP temple_scene")
	var saved_mode := Game.mode
	var saved_state := Game.state
	var saved_stage := Game.story_stage_index
	var saved_cleared: Dictionary = Game.story_cleared.duplicate(true)
	var saved_best: Dictionary = Game.story_best.duplicate(true)
	var saved_rainbow := Game.temple_rainbow_unlocked
	var story_disk: Dictionary = h._config_section_snapshot("story")
	Game.story_cleared = {}
	Game.story_best = {}
	Game.temple_rainbow_unlocked = false
	for i in 9:
		Game.story_cleared[Game.story_stage_id(i)] = true
	h._check(bool(Game.start_story(9)), "TempleOS scene accepts the unlocked bonus act")
	var loaded: bool = await h._until(func() -> bool:
		return h.get_tree().current_scene != null and h.get_tree().current_scene.name == "Arena", 6.0, "TempleOS arena")
	if not loaded:
		Game.to_menu()
		await h._until(func() -> bool:
			return h.get_tree().current_scene != null and h.get_tree().current_scene.name == "Menu", 6.0, "TempleOS menu return")
		Game.mode = saved_mode
		Game.state = saved_state
		Game.story_stage_index = saved_stage
		Game.story_cleared = saved_cleared
		Game.story_best = saved_best
		Game.temple_rainbow_unlocked = saved_rainbow
		h._restore_config_section("story", story_disk)
		return
	var temple_arena: Arena = h.get_tree().current_scene
	await h._ticks(3)
	if temple_arena.has_method("story_intro_active") and temple_arena.has_method("dismiss_story_intro"):
		if temple_arena.call("story_intro_active"):
			await h._simulation_seconds(0.5)
			temple_arena.set("_story_intro_t", 1.0)
			temple_arena.call("dismiss_story_intro")
			await h._ticks(6)
	h._check(temple_arena.spawner.story_mode, "TempleOS arena uses the scripted spawner")
	h._check(str(temple_arena.get("_story_stage").get("path", "")) == "TempleOS::BOOT", "TempleOS arena loads the boot stage")
	h._check(Balance.arena_rect().size == Vector2(640.0, 640.0), "TempleOS runtime uses the compact arena")
	var temple_overlay = temple_arena.get("_crt_overlay")
	h._check(temple_overlay != null and temple_overlay.is_active(), "TempleOS runtime enables the holy CRT")
	h._check(bool(temple_arena.get("_temple_mode")), "TempleOS runtime enables the rainbow mode")
	temple_arena.spawner.stop()
	temple_arena.spawner.debug_clear_encounter()
	Game.to_menu()
	await h._until(func() -> bool:
		return h.get_tree().current_scene != null and h.get_tree().current_scene.name == "Menu", 6.0, "TempleOS menu return")
	Game.mode = saved_mode
	Game.state = saved_state
	Game.story_stage_index = saved_stage
	Game.story_cleared = saved_cleared
	Game.story_best = saved_best
	Game.temple_rainbow_unlocked = saved_rainbow
	h._restore_config_section("story", story_disk)

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
		h._check(panel != null and panel.has_method("text_overflow_report"), "%s exposes text_overflow_report" % surface_id)
		if panel == null or not panel.has_method("text_overflow_report"):
			continue
		var all_fit := true
		for vp in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
			panel.size = vp
			for entry in panel.call("text_overflow_report"):
				all_fit = all_fit and bool(entry.get("fits", false))
		h._check(all_fit, "%s keeps its representative text inside the panel at 1366x768, 720x720, and 432x720" % surface_id)
		panel.free()

func _touch_hud_layout_test() -> void:
	print("AT_STEP touch_hud_layout")
	var tui_script: Script = load("res://src/ui/tactical_ui.gd")
	var tui = tui_script.new() if tui_script != null else null
	h._check(tui != null and tui.has_method("touch_dash_rect") and tui.has_method("touch_boost_rect"), "tactical ui exposes touch button rect helpers")
	if tui == null or not tui.has_method("touch_dash_rect"):
		return
	var hud_script: Script = load("res://src/ui/hud.gd")
	var hud_src := str(hud_script.source_code)
	h._check(hud_src.contains("if not touch_layout():"), "combat hud skips desktop-only dash module drawing on touch")
	h._check(hud_src.contains("label += \"  READY\""), "overclock ready keeps its label without the [E] keyboard hint on touch")
	h._check(hud_src.contains("\"[SHIFT]\" if not touch_layout()"), "dash charge text gates the [SHIFT] keyboard hint on touch")
	h._check(hud_src.contains("_banner.text = \"\" if hide_main else text"), "compact wave banner omits the duplicated cycle line")
	h._check(hud_src.contains("_banner_sub_l.offset_top = 186"), "compact wave banner repositions below the encounter panel")
	var tc_script: Script = load("res://src/ui/touch_controls.gd")
	var tc = tc_script.new() if tc_script != null else null
	h._check(tc != null and tc.has_method("_dash_btn") and tc.has_method("_oc_btn"), "touch controls expose button rects for layout probes")
	var saved_touch_scale := Sfx.touch_scale
	var saved_force := OS.get_environment("KP_FORCE_TOUCH")
	for scale in [0.85, 1.0, 1.2]:
		Sfx.touch_scale = scale
		for vp in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
			var view := Rect2(Vector2.ZERO, vp)
			var dash: Rect2 = tui.call("touch_dash_rect", vp, scale)
			var boost: Rect2 = tui.call("touch_boost_rect", vp, scale)
			h._check(view.encloses(dash.grow(-2.0)), "touch dash ring stays inside the safe area at %dx%d scale %.2f" % [int(vp.x), int(vp.y), scale])
			h._check(view.encloses(boost.grow(-2.0)), "touch boost ring stays inside the safe area at %dx%d scale %.2f" % [int(vp.x), int(vp.y), scale])
			if tc != null:
				tc.size = vp
				var tc_dash: Rect2 = tc.call("_dash_btn")
				var tc_boost: Rect2 = tc.call("_oc_btn")
				h._check(tc_dash.is_equal_approx(dash), "touch dash button metrics match the shared helper at %dx%d scale %.2f" % [int(vp.x), int(vp.y), scale])
				h._check(tc_boost.is_equal_approx(boost), "touch boost button metrics match the shared helper at %dx%d scale %.2f" % [int(vp.x), int(vp.y), scale])
			var layout_touch: Dictionary = tui.call("layout", vp, true, scale)
			var layout_plain: Dictionary = tui.call("layout", vp)
			var touch_patches: Rect2 = layout_touch["patches"]
			var plain_patches_vp: Rect2 = layout_plain["patches"]
			h._check(bool(layout_touch["compact"]) == bool(layout_plain["compact"]), "touch layout keeps the compact flag size-based at %dx%d" % [int(vp.x), int(vp.y)])
			h._check(not touch_patches.intersects(dash), "compact+touch patch dock never intersects the touch dash button at %dx%d scale %.2f" % [int(vp.x), int(vp.y), scale])
			h._check(touch_patches.size.x >= minf(120.0, plain_patches_vp.size.x) - 0.01, "touch patch dock keeps readable chips at %dx%d scale %.2f" % [int(vp.x), int(vp.y), scale])
	Sfx.touch_scale = saved_touch_scale
	var banner_hud = hud_script.new()
	banner_hud.size = Vector2(432, 720)
	banner_hud.set("_banner_sub", "PURGE THE DAEMONS")
	h._check(bool(banner_hud.call("_banner_compact")), "compact viewport suppresses the duplicated wave-banner cycle line")
	banner_hud.size = Vector2(1366, 768)
	h._check(not bool(banner_hud.call("_banner_compact")), "desktop viewport keeps the full wave banner")
	banner_hud.size = Vector2(720, 720)
	banner_hud.set("_banner_sub", "")
	h._check(not bool(banner_hud.call("_banner_compact")), "subtitle-less hint banners keep their main line on compact")
	banner_hud.free()
	var gate_hud = hud_script.new()
	OS.set_environment("KP_FORCE_TOUCH", "")
	h._check(not bool(gate_hud.call("touch_layout")), "hud touch flag stays off without a touchscreen or override")
	var plain_patches: Rect2 = tui.call("layout", Vector2(1366, 768))["patches"]
	var snapshot_patches: Rect2 = gate_hud.call("layout_snapshot", Vector2(1366, 768))["patches"]
	h._check(snapshot_patches.is_equal_approx(plain_patches), "non-touch hud snapshot keeps the desktop patch dock unchanged")
	OS.set_environment("KP_FORCE_TOUCH", "1")
	h._check(bool(gate_hud.call("touch_layout")), "KP_FORCE_TOUCH forces the hud touch layout flag")
	var forced_patches: Rect2 = gate_hud.call("layout_snapshot", Vector2(1366, 768))["patches"]
	var forced_dash: Rect2 = tui.call("touch_dash_rect", Vector2(1366, 768), Sfx.touch_scale)
	h._check(not forced_patches.intersects(forced_dash), "KP_FORCE_TOUCH snapshot moves the patch dock clear of the touch dash button")
	if saved_force.is_empty():
		OS.set_environment("KP_FORCE_TOUCH", "")
	else:
		OS.set_environment("KP_FORCE_TOUCH", saved_force)
	gate_hud.free()
	if tc != null:
		tc.free()

func _charm_save_transfer_test(menu: Node) -> void:
	print("AT_STEP charm_save_transfer")
	h._check(Game.has_method("export_save_string") and Game.has_method("import_save_string"), "game exposes save transfer API")
	h._check(menu.has_method("_export_save_to_clipboard") and menu.has_method("_import_save_from_clipboard"), "settings exposes save transfer actions")
	if not Game.has_method("export_save_string") or not Game.has_method("import_save_string"):
		return
	var saved_sections := {}
	for section in ["run", "weekly", "story", "bestiary", "programs", "achievements"]:
		saved_sections[section] = h._config_section_snapshot(section)
	var saved_state := Game.state
	var saved_stats: Dictionary = Game.stats.duplicate(true)
	var saved_mode := Game.mode
	var saved_program := Game.program
	var saved_bestiary: Dictionary = Game.bestiary.duplicate(true)
	var saved_unlocked: Dictionary = Game.unlocked_programs.duplicate(true)
	var saved_achievements: Dictionary = Game.achievements.duplicate(true)
	var saved_story_cleared: Dictionary = Game.story_cleared.duplicate(true)
	var saved_story_best: Dictionary = Game.story_best.duplicate(true)
	var fixture := ConfigFile.new()
	fixture.load(Sfx.SAVE_PATH)
	fixture.set_value("run", "best_classic", 24680)
	fixture.set_value("run", "best_onehp", 13579)
	fixture.set_value("run", "onehp_unlocked", true)
	fixture.set_value("run", "program", "daemon")
	fixture.set_value("bestiary", "seen", {"drone": true, "oom": true})
	fixture.set_value("programs", "unlocked", {"kernel": true, "daemon": true})
	fixture.set_value("achievements", "unlocked", {"first_blood": true})
	fixture.save(Sfx.SAVE_PATH)
	Game.call("_load_run_config")
	var encoded := str(Game.export_save_string())
	h._check(encoded.length() > 20 and not encoded.contains("24680"), "save export is a compact encoded string")
	Game.best = 0
	Game.bestiary = {}
	Game.unlocked_programs = {"kernel": true}
	Game.achievements = {}
	h._check(bool(Game.import_save_string(encoded)), "save import accepts a valid transfer string")
	h._check(Game.best == 24680 and Game.bestiary.has("oom") and Game.unlocked_programs.has("daemon") and Game.achievements.has("first_blood"), "save import restores progress, records, unlocks, and achievements")
	h._check(not bool(Game.import_save_string("not-a-save")), "save import rejects malformed data")
	for section in saved_sections:
		h._restore_config_section(section, saved_sections[section])
	Game.state = saved_state
	Game.stats = saved_stats
	Game.mode = saved_mode
	Game.program = saved_program
	Game.bestiary = saved_bestiary
	Game.unlocked_programs = saved_unlocked
	Game.achievements = saved_achievements
	Game.story_cleared = saved_story_cleared
	Game.story_best = saved_story_best


extends RefCounted

## Autotest section script. Function bodies below are moved verbatim from
## src/autoload/dev_harness.gd; only harness-helper references are prefixed
## with `h` per plan section G3. No behavior changes. AT_STEP labels and
## message strings are byte-identical to the originals.

var h: Node


func _init(harness: Node) -> void:
	h = harness

class OnboardingFixtureGuard extends RefCounted:
	var _cleanup: Callable
	var _closed := false

	func _init(cleanup: Callable) -> void:
		_cleanup = cleanup

	func keep_alive() -> void:
		pass

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			if _closed:
				return
			_closed = true
			if _cleanup.is_valid():
				_cleanup.call()

func _onboarding_test(arena: Arena) -> void:
	print("AT_STEP onboarding")
	var saved_bestiary: Dictionary = Game.bestiary.duplicate(true)
	var saved_bestiary_disk: Dictionary = h._config_snapshot("bestiary", "seen", {})
	var saved_tutorial: Dictionary = Game.get("tutorial").duplicate(true)
	var saved_tutorial_disk: Dictionary = h._config_snapshot("tutorial", "hints", {})
	var saved_run_best_disk: Dictionary = h._config_snapshot("run", "best_classic", 0)
	var fixture_guard := OnboardingFixtureGuard.new(func() -> void:
		_restore_onboarding_fixture(saved_bestiary, saved_tutorial, saved_bestiary_disk, saved_tutorial_disk)
	)
	Game.bestiary.clear()
	var sighting_unlocks := {}
	var sighting_cb := func(id: String) -> void:
		sighting_unlocks[id] = int(sighting_unlocks.get(id, 0)) + 1
	Game.bestiary_unlocked.connect(sighting_cb)
	var drone_a := DroneEnemy.new()
	arena.enemy_container.add_child(drone_a)
	await h._ticks(1)
	var drone_b := DroneEnemy.new()
	arena.enemy_container.add_child(drone_b)
	await h._ticks(1)
	h._check(Game.bestiary_seen("drone"), "first sight unlocks regular enemy before death")
	h._check(int(sighting_unlocks.get("drone", 0)) == 1, "repeated regular sighting unlocks exactly once")
	var boss := RootBoss.new()
	boss.boss_index = 2
	boss.configure(1.0, false)
	arena.enemy_container.add_child(boss)
	await h._ticks(1)
	h._check(Game.bestiary_seen("segfault"), "first sight unlocks boss variant before death")
	h._check(int(sighting_unlocks.get("segfault", 0)) == 1, "repeated boss sighting unlocks exactly once")
	Game.bestiary_unlocked.disconnect(sighting_cb)
	for probe in [drone_a, drone_b, boss]:
		if is_instance_valid(probe):
			probe.queue_free()
	await h._ticks(2)
	h._check(Game.has_method("show_hint_once"), "game exposes persisted hint helper")
	if Game.has_method("show_hint_once"):
		Game.set("tutorial", {})
		h._check(bool(Game.call("show_hint_once", "move")), "first hint call is available")
		var second_hint_available := bool(Game.call("show_hint_once", "move"))
		h._check(second_hint_available == (OS.get_environment("KP_HINTS") != ""), "second hint call is suppressed unless KP_HINTS is set")
		if OS.get_environment("KP_HINTS") != "":
			Game.set("tutorial", {"move": true})
			h._check(bool(Game.call("show_hint_once", "move")), "KP_HINTS forces an already-seen hint")
		if OS.get_environment("KP_HINTS") == "":
			Game.set("tutorial", {})
			h._check(bool(Game.call("show_hint_once", "round1_reload_hint")), "hint persists before reload")
			Game._load_run_config()
			h._check(Game.tutorial.has("round1_reload_hint"), "hint survives ConfigFile reload")
			Game.bestiary.clear()
			Game.mark_bestiary("DRONE")
			Game._load_run_config()
			h._check(Game.bestiary_seen("drone"), "bestiary survives ConfigFile reload")
		h._check(h._config_snapshot_matches(saved_run_best_disk, h._config_snapshot("run", "best_classic", 0)), "hint probe preserves unrelated run save section")
	var hud: Hud = arena.hud
	var saved_banner_t: float = hud._banner_t
	var saved_banner_text: String = hud._banner_text
	var saved_banner_sub: String = hud._banner_sub
	var saved_hint_queue: Array[Dictionary] = hud._hint_queue.duplicate(true)
	var saved_hint_queue_ids: Dictionary = hud._hint_queue_ids.duplicate(true)
	hud._hint_queue.clear()
	hud._hint_queue_ids.clear()
	hud.show_banner("BLOCKING BANNER", "EVENT", 1.0)
	hud.queue_hint("round1_queue", "QUEUED HINT", 0.1)
	hud.queue_hint("round1_queue", "DUPLICATE HINT", 0.1)
	h._check(hud._banner_text == "BLOCKING BANNER", "active banner is not replaced by queued hint")
	h._check(hud._hint_queue.size() == 1, "duplicate hint is rate-limited")
	hud._process(0.5)
	h._check(hud._banner_text == "BLOCKING BANNER", "queued hint waits during active banner")
	hud._process(0.6)
	hud._process(0.01)
	h._check(hud._banner_text == "QUEUED HINT" and hud._hint_queue.is_empty(), "queued hint drains after active banner")
	hud._banner_t = saved_banner_t
	hud._banner_text = saved_banner_text
	hud._banner_sub = saved_banner_sub
	hud._hint_queue = saved_hint_queue
	hud._hint_queue_ids = saved_hint_queue_ids
	if OS.get_environment("KP_ONBOARDING_ABORT") != "":
		fixture_guard.keep_alive()
		return
	if OS.get_environment("KP_ONBOARDING_EARLY_EXIT") != "":
		fixture_guard.keep_alive()
		return
	fixture_guard.keep_alive()

func _restore_onboarding_fixture(saved_bestiary: Dictionary, saved_tutorial: Dictionary, saved_bestiary_disk: Dictionary, saved_tutorial_disk: Dictionary) -> void:
	Game.bestiary = saved_bestiary
	Game.tutorial = saved_tutorial
	h._restore_config_snapshot("bestiary", "seen", saved_bestiary_disk)
	h._restore_config_snapshot("tutorial", "hints", saved_tutorial_disk)

func _task10_test(menu: Node) -> void:
	print("AT_STEP task10")
	var run_snapshot: Dictionary = h._config_section_snapshot("run")
	var expected_defaults := {
		"move_up": KEY_W,
		"move_down": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"dash": KEY_SPACE,
		"overclock": KEY_E,
		"pause": KEY_ESCAPE,
		"abandon": KEY_Q,
		"mute": KEY_M,
		"restart": KEY_R,
		"confirm": KEY_ENTER,
	}
	var registry_ready := Game.has_method("keybind_defaults") and Game.has_method("get_keybind") and Game.has_method("set_keybind") and Game.has_method("reset_keybinds") and Game.has_method("reload_keybinds")
	h._check(registry_ready, "desktop keybind registry exposes persistence API")
	var controls_snapshot: Dictionary = h._config_section_snapshot("controls")
	if registry_ready:
		var defaults: Dictionary = Game.keybind_defaults()
		for action in expected_defaults:
			h._check(int(defaults.get(action, -1)) == int(expected_defaults[action]), "keybind default exists for %s" % action)
		Game.reset_keybinds()
		h._check(int(Game.get_keybind("dash")) == KEY_SPACE and h._has_physical_key("dash", KEY_SPACE), "reset keybinds applies default dash")
		var cf_controls := ConfigFile.new()
		cf_controls.load(Sfx.SAVE_PATH)
		cf_controls.set_value("controls", "dash", KEY_F)
		cf_controls.set_value("run", "best_classic", 654321)
		cf_controls.save(Sfx.SAVE_PATH)
		Game.reload_keybinds()
		h._check(int(Game.get_keybind("dash")) == KEY_F and h._has_physical_key("dash", KEY_F), "saved physical keycode loads into InputMap")
		var dash_mouse_events := 0
		var fire_mouse_events := 0
		for event in InputMap.action_get_events("dash"):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
				dash_mouse_events += 1
		for event in InputMap.action_get_events("fire"):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				fire_mouse_events += 1
		h._check(dash_mouse_events == 1 and fire_mouse_events == 1, "keybind reload preserves one mouse fire/aim binding")
		var run_after_load := ConfigFile.new()
		run_after_load.load(Sfx.SAVE_PATH)
		h._check(int(run_after_load.get_value("run", "best_classic", 0)) == 654321, "keybind save preserves other ConfigFile sections")
		var old_dash := int(Game.get_keybind("dash"))
		var old_overclock := int(Game.get_keybind("overclock"))
		h._check(not bool(Game.set_keybind("overclock", old_dash)), "duplicate keybind is rejected")
		h._check(int(Game.get_keybind("dash")) == old_dash and int(Game.get_keybind("overclock")) == old_overclock, "duplicate rejection leaves original actions unchanged")
		h._check(bool(Game.set_keybind("dash", KEY_G)) and int(Game.get_keybind("dash")) == KEY_G, "new keybind assigns selected action")
		var cf_fallback := ConfigFile.new()
		cf_fallback.load(Sfx.SAVE_PATH)
		cf_fallback.erase_section_key("controls", "overclock")
		cf_fallback.save(Sfx.SAVE_PATH)
		Game.reload_keybinds()
		h._check(int(Game.get_keybind("overclock")) == KEY_E, "missing keybind falls back to default")
		Game.reset_keybinds()
		h._check(int(Game.get_keybind("dash")) == KEY_SPACE and int(Game.get_keybind("overclock")) == KEY_E, "reset keybinds restores all defaults")
		h._restore_config_section("controls", controls_snapshot)
		Game.reload_keybinds()
	var capture_api_ready := menu != null and menu.has_method("_desktop_keybinds_enabled") and menu.has_method("keybind_capture_visible")
	h._check(capture_api_ready, "menu exposes desktop-only keybind capture state")
	if capture_api_ready:
		var desktop_keybinds := Balance.is_desktop_display() and not DisplayServer.is_touchscreen_available() and OS.get_environment("KP_FORCE_TOUCH") == ""
		h._check(bool(menu._desktop_keybinds_enabled()) == desktop_keybinds, "keybind capture is desktop-only and touch-gated")
		h._check(bool(menu.keybind_capture_visible()) == desktop_keybinds, "keybind capture panel visibility follows desktop gate")
		if desktop_keybinds and menu.has_method("_begin_keybind_capture") and menu.has_method("_handle_keybind_capture"):
			menu._begin_keybind_capture("dash")
			menu._handle_keybind_capture(h._key_event(KEY_ESCAPE))
			h._check(str(menu.get("_capture_action")) == "", "Escape cancels keybind capture")
			menu._begin_keybind_capture("dash")
			menu._handle_keybind_capture(h._key_event(KEY_E))
			h._check(str(menu.get("_capture_action")) == "dash" and str(menu.get("_keybind_status").text).contains("CONFLICT"), "capture shows duplicate conflict without assigning")
			menu._handle_keybind_capture(h._key_event(KEY_G, true))
			h._check(str(menu.get("_capture_action")) == "dash", "echo key does not capture")
			menu._handle_keybind_capture(h._key_event(KEY_H))
			h._check(str(menu.get("_capture_action")) == "" and int(Game.get_keybind("dash")) == KEY_H, "valid key ends capture and assigns")
	if menu != null and menu.has_method("_open_settings"):
		menu._open_settings()
		var settings_scrolls := menu.find_children("*", "ScrollContainer", true, false)
		h._check(not settings_scrolls.is_empty(), "settings content is scrollable")
		var desktop_keybinds := Balance.is_desktop_display() and not DisplayServer.is_touchscreen_available() and OS.get_environment("KP_FORCE_TOUCH") == ""
		if not settings_scrolls.is_empty() and desktop_keybinds:
			var settings_scroll: ScrollContainer = settings_scrolls[0]
			var reset_button: Button = null
			for node in settings_scroll.find_children("*", "Button", true, false):
				if node is Button and node.text == "RESET KEYBINDS":
					reset_button = node
					break
			h._check(reset_button != null, "keybind reset remains reachable inside settings scroll")
		menu._close_settings()
	h._restore_config_section("run", run_snapshot)

func _task11_test(menu: Node) -> void:
	print("AT_STEP task11")
	var metadata_ready := Game.has_method("patch_tooltip_data") and Game.has_method("patch_relation")
	h._check(metadata_ready, "patch tooltip metadata API exists")
	if metadata_ready:
		Game.patch_levels = {"heavy": 1, "splitshot": 1}
		var heavy_info: Dictionary = Game.patch_tooltip_data("heavy")
		h._check(str(heavy_info.get("title", "")) == "HEAVY ROUNDS" and str(heavy_info.get("description", "")) != "" and int(heavy_info.get("level", 0)) == 1, "patch tooltip exposes full title description and level")
		h._check(str(heavy_info.get("relation", "")).contains("TRADEOFF") and str(heavy_info.get("relation", "")).contains("FIRE RATE"), "heavy and splitshot expose documented fire-rate tradeoff")
		h._check(Game.patch_relation("heavy", "ricochet") == "NO DIRECT INTERACTION", "unknown patch relation makes no invented claim")
	var hud := Hud.new()
	hud.size = Vector2(1280, 720)
	h.add_child(hud)
	await h._ticks(1)
	var tooltip_api_ready := hud.has_method("patch_chip_rect") and hud.has_method("patch_tooltip_visible") and hud.has_method("patch_tooltip_snapshot")
	h._check(tooltip_api_ready, "HUD exposes patch tooltip hit state")
	if tooltip_api_ready:
		hud._update_patch_chip_rects()
		var chip_rect: Rect2 = hud.patch_chip_rect("heavy")
		h._check(chip_rect.size.x > 0.0 and chip_rect.size.y > 0.0, "active patch chip exposes hit rectangle")
		var mouse_motion := InputEventMouseMotion.new()
		mouse_motion.position = chip_rect.get_center()
		hud._input(mouse_motion)
		h._check(hud.patch_tooltip_visible(), "desktop hover shows patch tooltip")
		var tooltip_snapshot: Dictionary = hud.patch_tooltip_snapshot()
		h._check(str(tooltip_snapshot.get("title", "")) == "HEAVY ROUNDS" and int(tooltip_snapshot.get("level", 0)) == 1, "hover tooltip contains active patch data")
		var touch_down := InputEventScreenTouch.new()
		touch_down.index = 41
		touch_down.pressed = true
		touch_down.position = chip_rect.get_center()
		hud._input(touch_down)
		hud._process(0.44)
		h._check(not hud.patch_tooltip_visible(), "touch hold below threshold stays hidden")
		hud._process(0.02)
		h._check(hud.patch_tooltip_visible(), "touch hold at threshold shows patch tooltip")
		var touch_drag := InputEventScreenDrag.new()
		touch_drag.index = 41
		touch_drag.position = chip_rect.get_center() + Vector2(20, 0)
		hud._input(touch_drag)
		h._check(not hud.patch_tooltip_visible(), "touch movement dismisses patch tooltip")
		touch_down.position = chip_rect.get_center()
		hud._input(touch_down)
		hud._process(0.5)
		var paused_before := h.get_tree().paused
		var touch_up := InputEventScreenTouch.new()
		touch_up.index = 41
		touch_up.pressed = false
		touch_up.position = chip_rect.get_center()
		hud._input(touch_up)
		h._check(not hud.patch_tooltip_visible() and h.get_tree().paused == paused_before, "touch release dismisses tooltip without pausing")
	Game.patch_levels = {}
	hud.queue_free()
	await h._ticks(2)
	var saved_mode := Game.mode
	var saved_aim := Sfx.aim_mode
	Game.mode = "weekly"
	Sfx.aim_mode = "lockon"
	h._check(Game.effective_aim_mode() == "lockon", "weekly keeps saved local lock-on mode")
	if menu != null and menu.has_method("_refresh_mode_ui") and menu.has_method("_refresh_aim_label"):
		menu._refresh_mode_ui()
		menu._refresh_aim_label(menu.get("_aim_btn_ref"))
		h._check(not str(menu.get("_mode_info").text).contains("BLOCKED") and str(menu.get("_mode_info").text).contains("LOCAL"), "weekly menu explains local deterministic play")
		h._check(not str(menu.get("_aim_btn_ref").text).contains("BLOCKED"), "weekly menu does not block lock-on")
	Game.mode = saved_mode
	Sfx.aim_mode = saved_aim

func _color_assist_test() -> void:
	print("AT_STEP color_assist")
	var balance_script: Script = load("res://src/autoload/balance.gd")
	var palette_ready := balance_script != null and balance_script.has_method("threat_palette") and balance_script.has_method("threat_color")
	h._check(palette_ready, "threat palette helper exists")
	if palette_ready:
		var standard: Dictionary = balance_script.call("threat_palette", false)
		var assist: Dictionary = balance_script.call("threat_palette", true)
		var standard_pair: bool = standard.get("splitter", Color.BLACK) != standard.get("bulwark", Color.BLACK)
		var assist_pair: bool = assist.get("splitter", Color.BLACK) != assist.get("bulwark", Color.BLACK)
		h._check(standard_pair, "standard Splitter and Bulwark colors are distinct")
		h._check(assist_pair and h._color_distance(assist["splitter"], assist["bulwark"]) > 0.45, "color assist threat pair is accessible")
		h._check(balance_script.call("threat_color", "splitter", false) == standard["splitter"] and balance_script.call("threat_color", "bulwark", false) == standard["bulwark"], "standard threats route through shared palette")

	var saved_disk: Dictionary = h._config_snapshot("feel", "color_assist", false)
	var saved_color_assist := false
	if Sfx.has_method("set_color_assist"):
		saved_color_assist = bool(Sfx.get("color_assist"))
	var settings_cf := ConfigFile.new()
	settings_cf.load(Sfx.SAVE_PATH)
	if settings_cf.has_section_key("feel", "color_assist"):
		settings_cf.erase_section_key("feel", "color_assist")
	settings_cf.save(Sfx.SAVE_PATH)
	Sfx._load_settings()
	h._check(Sfx.has_method("set_color_assist") and not bool(Sfx.get("color_assist")), "color assist defaults off")
	if Sfx.has_method("set_color_assist"):
		Sfx.set_color_assist(true)
		Sfx._load_settings()
		h._check(bool(Sfx.get("color_assist")), "color assist persists through reload")

	var menu := h.get_tree().current_scene
	var color_button: Button = null
	if menu != null:
		if menu.has_method("_refresh_color_assist_label"):
			Sfx.set_color_assist(false)
			menu._refresh_color_assist_label()
		if menu.has_method("_open_settings"):
			menu._open_settings()
		for node in menu.find_children("*", "Button", true, false):
			if node is Button and str(node.text).begins_with("COLOR ASSIST:"):
				color_button = node
				break
	h._check(color_button != null, "settings expose color assist toggle")
	if color_button != null:
		h._check(color_button.text == "COLOR ASSIST: OFF", "color assist toggle shows OFF by default")
		color_button.pressed.emit()
		h._check(bool(Sfx.get("color_assist")) and color_button.text == "COLOR ASSIST: ON", "color assist toggle enables assist mode")
		color_button.pressed.emit()
		h._check(not bool(Sfx.get("color_assist")) and color_button.text == "COLOR ASSIST: OFF", "color assist toggle disables assist mode")
	if menu != null and menu.has_method("_close_settings"):
		menu._close_settings()

	var splitter := SplitterEnemy.new()
	var bulwark := BulwarkEnemy.new()
	var splitter_source := FileAccess.get_file_as_string("res://src/enemies/splitter.gd")
	var bulwark_source := FileAccess.get_file_as_string("res://src/enemies/bulwark.gd")
	h._check(splitter.has_method("color_assist_marker") and splitter.color_assist_marker() == "SPLIT", "Splitter exposes code-drawn assist marker")
	h._check(bulwark.has_method("color_assist_marker") and bulwark.color_assist_marker() == "BULW", "Bulwark exposes code-drawn assist marker")
	h._check(splitter_source.contains("draw_string") and bulwark_source.contains("draw_string") and not splitter_source.contains(".png") and not bulwark_source.contains(".png"), "threat markers use code drawing without images")
	var bestiary_source := FileAccess.get_file_as_string("res://src/ui/bestiary_panel.gd")
	h._check(bestiary_source.contains("_draw_color_assist_marker") and bestiary_source.contains("SPLIT") and bestiary_source.contains("BULW") and bestiary_source.contains("Sfx.color_assist"), "bestiary draws assist markers beside Splitter and Bulwark glyphs")
	splitter.free()
	bulwark.free()

	if Sfx.has_method("set_color_assist"):
		Sfx.set("color_assist", saved_color_assist)
	h._restore_config_snapshot("feel", "color_assist", saved_disk)
	if menu != null and menu.has_method("_refresh_color_assist_label"):
		menu._refresh_color_assist_label()


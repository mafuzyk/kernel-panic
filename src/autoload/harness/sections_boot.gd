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
		menu._open_settings()
		menu.get("_settings_kit").set_active_section("CONTROLS")
		var desktop_keybinds := Balance.is_desktop_display() and not DisplayServer.is_touchscreen_available() and OS.get_environment("KP_FORCE_TOUCH") == ""
		h._check(bool(menu._desktop_keybinds_enabled()) == desktop_keybinds, "keybind capture is desktop-only and touch-gated")
		h._check(bool(menu.keybind_capture_visible()) == desktop_keybinds, "keybind capture panel visibility follows desktop gate")
		if desktop_keybinds and menu.has_method("_begin_keybind_capture") and menu.has_method("_handle_keybind_capture"):
			menu._begin_keybind_capture("dash")
			menu._handle_keybind_capture(h._key_event(KEY_ESCAPE))
			h._check(str(menu.get("_capture_action")) == "", "Escape cancels keybind capture")
			menu._begin_keybind_capture("dash")
			menu._handle_keybind_capture(h._key_event(KEY_E))
			h._check(str(menu.get("_capture_action")) == "dash" and str(menu.get("_keybind_status").text) == tr("SET_BIND_CONFLICT") % ["E", tr("SET_BIND_OVERCLOCK")], "capture shows duplicate conflict without assigning")
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
				if node is Button and node.text == tr("SET_BIND_RESET"):
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
	var tooltip_api_ready := hud.has_method("patch_chip_rect") and hud.has_method("patch_tooltip_visible") and hud.has_method("patch_tooltip_snapshot") and hud.has_method("patch_tooltip_rect")
	h._check(tooltip_api_ready, "HUD exposes patch tooltip hit state")
	if tooltip_api_ready:
		hud._update_patch_chip_rects()
		var chip_rect: Rect2 = hud.patch_chip_rect("heavy")
		h._check(chip_rect.size.x > 0.0 and chip_rect.size.y > 0.0, "active patch chip exposes hit rectangle")
		for viewport in [Vector2(1280, 720), Vector2(720, 720), Vector2(432, 720)]:
			var probe_chip := Rect2(viewport.x - 90.0, viewport.y - 70.0, 64.0, 28.0)
			var tooltip_rect: Rect2 = hud.call("patch_tooltip_rect", viewport, probe_chip)
			h._check(Rect2(Vector2.ZERO, viewport).encloses(tooltip_rect), "patch tooltip stays inside viewport %dx%d" % [int(viewport.x), int(viewport.y)])
		var mouse_motion := InputEventMouseMotion.new()
		var chip_position: Vector2 = hud.get_global_transform_with_canvas() * chip_rect.get_center()
		mouse_motion.position = chip_position
		hud._input(mouse_motion)
		h._check(hud.patch_tooltip_visible(), "desktop hover shows patch tooltip")
		var tooltip_snapshot: Dictionary = hud.patch_tooltip_snapshot()
		h._check(str(tooltip_snapshot.get("title", "")) == "HEAVY ROUNDS" and int(tooltip_snapshot.get("level", 0)) == 1, "hover tooltip contains active patch data")
		var touch_down := InputEventScreenTouch.new()
		touch_down.index = 41
		touch_down.pressed = true
		touch_down.position = chip_position
		hud._input(touch_down)
		hud._process(0.44)
		h._check(not hud.patch_tooltip_visible(), "touch hold below threshold stays hidden")
		hud._process(0.02)
		h._check(hud.patch_tooltip_visible(), "touch hold at threshold shows patch tooltip")
		var touch_drag := InputEventScreenDrag.new()
		touch_drag.index = 41
		touch_drag.position = chip_position + Vector2(20, 0)
		hud._input(touch_drag)
		h._check(not hud.patch_tooltip_visible(), "touch movement dismisses patch tooltip")
		touch_down.position = chip_position
		hud._input(touch_down)
		hud._process(0.5)
		var paused_before := h.get_tree().paused
		var touch_up := InputEventScreenTouch.new()
		touch_up.index = 41
		touch_up.pressed = false
		touch_up.position = chip_position
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
	# A barra antiga foi removida; verificar o shell vivo e o controle de mira
	# das settings. Ler _mode_info abortava este teste antes da restauração.
	if menu != null and menu.has_method("refresh_shell") and menu.has_method("_refresh_aim_label"):
		menu.refresh_shell()
		menu._refresh_aim_label(menu.get("_aim_btn_ref"))
		h._check(str(menu.main_shell_snapshot().get("mode_explanation", "")).contains(tr("MODE_WEEKLY")), "weekly mode appears in the live menu shell")
		h._check(not str(menu.get("_aim_btn_ref").text).contains("BLOCKED"), "weekly menu does not block lock-on")
	Game.mode = saved_mode
	Sfx.aim_mode = saved_aim
	if menu != null:
		menu.refresh_shell()

func _settings_focus_test(menu: Node) -> void:
	print("AT_STEP settings_focus")
	menu.call("_open_settings")
	await h._ticks(3)
	var panel: Control = menu.get("_settings_panel")
	var owner: Control = h.get_viewport().gui_get_focus_owner()
	print("AT_DEBUG settings focus=", owner.get_class() if owner != null else "null")
	h._check(owner != null and panel != null and panel.is_ancestor_of(owner), "opening settings takes keyboard focus inside the panel")
	menu.call("_close_settings")
	await h._ticks(1)

## `[Label, chave]` de cada rótulo do shell que nasceu de uma tradução.
func _tagged_labels(root: Node) -> Array:
	var found: Array = []
	if root is Label and root.has_meta(MenuShell.TR_KEY_META):
		found.append([root as Label, str(root.get_meta(MenuShell.TR_KEY_META))])
	for child in root.get_children():
		found.append_array(_tagged_labels(child))
	return found


func _language_selector_test(menu: Node) -> void:
	print("AT_STEP language_selector")
	var saved_lang := Game.language()
	var kit: RefCounted = menu.get("_settings_kit")
	h._check(kit != null and kit.has_method("language_button"), "settings exposes a language control")
	if kit == null or not kit.has_method("language_button"):
		return
	menu.call("_open_settings")
	await h._ticks(2)
	kit.call("set_active_section", "ACCESSIBILITY")
	await h._ticks(1)
	var lang_btn: Button = kit.call("language_button")
	h._check(is_instance_valid(lang_btn) and lang_btn.visible, "language control is visible in settings")
	if not is_instance_valid(lang_btn):
		menu.call("_close_settings")
		return
	var before := Game.language()
	lang_btn.pressed.emit()
	await h._ticks(2)
	var after := Game.language()
	h._check(after != before, "pressing the language control switches language")
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	h._check(str(cf.get_value("feel", "language", "")) == after, "language selection persists")
	h._check(str(menu.main_shell_snapshot().get("mode_explanation", "")) != "", "shell survives the language rebuild")
	lang_btn = kit.call("language_button")
	h._check(is_instance_valid(lang_btn), "language control exists after rebuild")
	menu.call("_close_settings")
	await h._ticks(1)
	# Os widgets legacy do menu nascem escondidos e ninguém os desenha desde que
	# o MenuShell assumiu. Fechar settings voltou a exibi-los durante o 3.0 —
	# moldura e rótulos antigos por cima do shell — e trocar de idioma era o
	# gatilho, porque reconstruir settings passa pelo par abrir/fechar.
	var resurrected: Array[String] = []
	for child in menu.get_children():
		if not (child is Control) or child is ColorRect:
			continue
		var control := child as Control
		if control.visible:
			resurrected.append(control.get_class() + ":" + str(control.name))
	h._check(resurrected.is_empty(),
		"closing settings does not resurrect the legacy menu widgets (%s)" % ", ".join(resurrected))
	# O shell resolve cada `tr()` uma vez, na construção. Sem retradução em
	# tempo de execução, trocar de idioma deixava PURGE, Story, Archives,
	# ACTIVE PROGRAM, Swap, Start, Settings, Awards e Quit no idioma do boot,
	# ao lado de modo e recorde já traduzidos: menu metade em cada língua.
	var shell_node: Control = menu.get("_shell")
	var stale_labels: Array[String] = []
	var tagged := 0
	if is_instance_valid(shell_node):
		for entry in _tagged_labels(shell_node):
			tagged += 1
			var label: Label = entry[0]
			var key: String = entry[1]
			if label.text != tr(key):
				stale_labels.append("%s=%s" % [key, label.text])
	h._check(tagged >= 8, "the menu shell tags its translated labels (%d found)" % tagged)
	h._check(stale_labels.is_empty(),
		"the whole menu shell speaks the language just selected (%s)" % ", ".join(stale_labels))
	var post_close: Control = h.get_viewport().gui_get_focus_owner()
	# O teste possui a própria higiene de foco: restaura o PURGE de forma
	# síncrona para não vazar estado para o desktop_focus.
	var shell_fix: Control = menu.get("_shell")
	if shell_fix != null and shell_fix.has_method("focus_primary"):
		shell_fix.call("focus_primary")
		await h._ticks(1)
		post_close = h.get_viewport().gui_get_focus_owner()
	Game.set_language(saved_lang)
	if menu.has_method("refresh_shell"):
		menu.refresh_shell()
	await h._ticks(1)

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
			if node is Button and node == menu.get("_color_assist_btn"):
				color_button = node
				break
	h._check(color_button != null, "settings expose color assist toggle")
	if color_button != null:
		h._check(color_button.text == tr("SET_COLOR_ASSIST") % tr("SET_VAL_OFF"), "color assist toggle shows OFF by default")
		color_button.pressed.emit()
		h._check(bool(Sfx.get("color_assist")) and color_button.text == tr("SET_COLOR_ASSIST") % tr("SET_VAL_ON"), "color assist toggle enables assist mode")
		color_button.pressed.emit()
		h._check(not bool(Sfx.get("color_assist")) and color_button.text == tr("SET_COLOR_ASSIST") % tr("SET_VAL_OFF"), "color assist toggle disables assist mode")
	if menu != null and menu.has_method("_close_settings"):
		menu._close_settings()

	var splitter := SplitterEnemy.new()
	var bulwark := BulwarkEnemy.new()
	# load(), não FileAccess: no artefato o .gd não existe como texto, mas o
	# script compilado carrega e `source_code` vem vazio — sem ERROR no log.
	var splitter_source := str((load("res://src/enemies/splitter.gd") as Script).source_code)
	var bulwark_source := str((load("res://src/enemies/bulwark.gd") as Script).source_code)
	h._check(splitter.has_method("color_assist_marker") and splitter.color_assist_marker() == "SPLIT", "Splitter exposes code-drawn assist marker")
	h._check(bulwark.has_method("color_assist_marker") and bulwark.color_assist_marker() == "BULW", "Bulwark exposes code-drawn assist marker")
	h._check_source(splitter_source.contains("draw_string") and bulwark_source.contains("draw_string") and not splitter_source.contains(".png") and not bulwark_source.contains(".png"), "threat markers use code drawing without images")
	var bestiary_probe := BestiaryPanel.new()
	h._check(bestiary_probe.has_method("assist_marker_text") \
		and bestiary_probe.call("assist_marker_text", "splitter") == ("SPLIT" if Sfx.color_assist else "") \
		and bestiary_probe.call("assist_marker_text", "bulwark") == ("BULW" if Sfx.color_assist else ""),
		"bestiary exposes the same color-assist markers as the arena threats")
	bestiary_probe.free()
	splitter.free()
	bulwark.free()

	if Sfx.has_method("set_color_assist"):
		Sfx.set("color_assist", saved_color_assist)
	h._restore_config_snapshot("feel", "color_assist", saved_disk)
	if menu != null and menu.has_method("_refresh_color_assist_label"):
		menu._refresh_color_assist_label()

func _run_config_test(menu: Node) -> void:
	print("AT_STEP run_config_interaction")
	var saved_mode := Game.mode
	var saved_diff := Game.difficulty
	var saved_onehp := Game.onehp_unlocked
	var saved_mode_disk: Dictionary = h._config_snapshot("game", "mode", "classic")
	var saved_diff_disk: Dictionary = h._config_snapshot("game", "difficulty", "normal")
	var saved_onehp_disk: Dictionary = h._config_snapshot("run", "onehp_unlocked", false)
	var shell: Control = menu.get("_shell")
	h._check(shell != null and is_instance_valid(shell), "live menu shell exists for run config")
	if shell == null or not is_instance_valid(shell) or not menu.has_method("refresh_shell"):
		_restore_run_config_fixture(saved_mode, saved_diff, saved_onehp, saved_mode_disk, saved_diff_disk, saved_onehp_disk, menu)
		return
	h._check(shell.has_method("run_config_hits"), "shell exposes run-config controls")
	if not shell.has_method("run_config_hits"):
		_restore_run_config_fixture(saved_mode, saved_diff, saved_onehp, saved_mode_disk, saved_diff_disk, saved_onehp_disk, menu)
		return
	Game.onehp_unlocked = false
	Game.mode = "classic"
	Game.set_difficulty("normal")
	menu.refresh_shell()
	await h._ticks(1)
	var hits: Dictionary = shell.run_config_hits()
	var mode_hit: Button = hits.get("mode")
	var diff_hit: Button = hits.get("difficulty")
	h._check(is_instance_valid(mode_hit) and is_instance_valid(diff_hit), "mode and difficulty controls exist in the live shell")
	if not is_instance_valid(mode_hit) or not is_instance_valid(diff_hit):
		_restore_run_config_fixture(saved_mode, saved_diff, saved_onehp, saved_mode_disk, saved_diff_disk, saved_onehp_disk, menu)
		return
	h._check(mode_hit.focus_mode == Control.FOCUS_ALL and diff_hit.focus_mode == Control.FOCUS_ALL, "mode and difficulty controls are keyboard reachable")
	mode_hit.grab_focus()
	h._check(mode_hit.has_focus(), "mode control takes keyboard focus")
	h._check(mode_hit.get_global_rect().size.x > 0.0 and mode_hit.get_global_rect().size.y > 0.0, "mode control has a clickable rect")
	mode_hit.pressed.emit()
	await h._ticks(1)
	h._check(Game.mode == "weekly", "pressing the MODE control selects weekly")
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	h._check(str(cf.get_value("game", "mode", "")) == "weekly", "mode selection persists to ConfigFile")
	h._check(str(menu.main_shell_snapshot().get("mode_explanation", "")).contains(tr("MODE_WEEKLY")), "shell shows weekly immediately")
	mode_hit.pressed.emit()
	await h._ticks(1)
	h._check(Game.mode == "classic", "locked one-hp is skipped when cycling modes")
	Game.unlock_onehp()
	Game.mode = "classic"
	menu.refresh_shell()
	await h._ticks(1)
	mode_hit.pressed.emit()
	mode_hit.pressed.emit()
	await h._ticks(1)
	h._check(Game.mode == "onehp", "unlocked one-hp is selectable from the shell")
	Game.mode = "classic"
	Game.set_difficulty("normal")
	menu.refresh_shell()
	await h._ticks(1)
	diff_hit.pressed.emit()
	await h._ticks(1)
	h._check(Game.difficulty == "hard", "pressing the DIFFICULTY control cycles normal to hard")
	cf.load(Sfx.SAVE_PATH)
	h._check(str(cf.get_value("game", "difficulty", "")) == "hard", "difficulty selection persists to ConfigFile")
	h._check(str(menu.main_shell_snapshot().get("mode_explanation", "")).contains(tr("DIFF_HARD")), "shell shows hard immediately")
	Game.mode = "story"
	menu.refresh_shell()
	await h._ticks(1)
	var story_diff := Game.difficulty
	diff_hit.pressed.emit()
	await h._ticks(1)
	h._check(Game.difficulty == story_diff, "story keeps its fixed difficulty curve")
	var diff_text := ""
	var diff_block: Control = shell.get("_diff_block")
	if diff_block != null and diff_block.has_meta("label_node"):
		diff_text = str(diff_block.get_meta("label_node").text)
	h._check(diff_text == tr("MENU_DIFFICULTY_FIXED"), "shell shows fixed difficulty in story")
	_restore_run_config_fixture(saved_mode, saved_diff, saved_onehp, saved_mode_disk, saved_diff_disk, saved_onehp_disk, menu)

func _restore_run_config_fixture(saved_mode: String, saved_diff: String, saved_onehp: bool, saved_mode_disk: Dictionary, saved_diff_disk: Dictionary, saved_onehp_disk: Dictionary, menu: Node) -> void:
	Game.mode = saved_mode
	Game.difficulty = saved_diff
	Game.onehp_unlocked = saved_onehp
	h._restore_config_snapshot("game", "mode", saved_mode_disk)
	h._restore_config_snapshot("game", "difficulty", saved_diff_disk)
	h._restore_config_snapshot("run", "onehp_unlocked", saved_onehp_disk)
	if menu != null and menu.has_method("refresh_shell"):
		menu.refresh_shell()

## O manifesto de settings é o que impede a volta do bug "opção que não faz
## nada nesta plataforma" — `aim_mode` e háptico apareciam no desktop, onde
## `Game.effective_aim_mode()` só é lido pelo `touch_controls.gd`.
func _settings_manifest_test() -> void:
	print("AT_STEP settings_manifest")
	var touch := Platform.TOUCH
	var desktop := Platform.DESKTOP

	# Regra central, afirmada por ID e não por rótulo: o teste antigo do HUD
	# já foi quebrado uma vez por travar frase literal, e a frase muda com a
	# tradução sem que nada tenha regredido.
	for id in ["aim_mode", "touch_scale", "haptics"]:
		h._check(SettingsManifest.shows(id, touch), "%s is offered on touch" % id)
		h._check(not SettingsManifest.shows(id, desktop), "%s stays hidden on desktop, where it does nothing" % id)
	for id in ["keybinds", "window_mode"]:
		h._check(SettingsManifest.shows(id, desktop), "%s is offered on desktop" % id)
		h._check(not SettingsManifest.shows(id, touch), "%s stays hidden on touch, where it does nothing" % id)
	for id in ["sfx_vol", "shake", "color_assist", "language", "board_enabled", "save_transfer"]:
		h._check(SettingsManifest.shows(id, touch) and SettingsManifest.shows(id, desktop),
			"%s is offered on both platforms" % id)

	# Uma seção sem nada para mostrar não vira aba vazia. Hoje é o caso de
	# CONTROLS no toque, que só contém keybinds.
	# O kit não declara `class_name`, então a lista de seções vem pelo mapa de
	# constantes do script em vez de ser reescrita aqui — reescrever criaria
	# uma segunda ordem que envelheceria sozinha.
	var kit_script: GDScript = load("res://src/ui/menu_settings_kit.gd")
	var order: Array = kit_script.get_script_constant_map()["SETTINGS_SECTIONS"]
	var touch_sections: Array = SettingsManifest.sections_for(touch, order)
	var desktop_sections: Array = SettingsManifest.sections_for(desktop, order)
	h._check(not touch_sections.has("CONTROLS"), "touch drops a section with nothing to show")
	h._check(desktop_sections.has("CONTROLS"), "desktop keeps its keybind section")
	for section in ["AUDIO", "VIDEO", "ACCESSIBILITY", "BOARD", "SAVE DATA"]:
		h._check(touch_sections.has(section) and desktop_sections.has(section),
			"%s survives on both platforms" % section)

	# Controle declarado na tela mas não no manifesto passaria despercebido e
	# voltaria a decidir plataforma sozinho. Isto cobra a declaração.
	var kit_src := str(kit_script.source_code)
	var undeclared: Array[String] = []
	for line in kit_src.split("\n"):
		var at := line.find("assign_section(")
		if at < 0 or line.begins_with("##") or line.begins_with("func "):
			continue
		var parts := line.substr(at).split("\"")
		# assign_section(ctrl, "SECTION", "id") -> parts[1] seção, parts[3] id
		if parts.size() >= 4 and str(parts[3]) != "":
			var id := str(parts[3])
			if SettingsManifest.section_of(id) == "":
				undeclared.append(id)
	h._check(undeclared.is_empty(), "every tagged settings control is declared in the manifest (stray: %s)" % str(undeclared))

	# Esconder é só UI: o valor tem que atravessar disco igual nas duas
	# plataformas, senão quem transfere o save do celular para o PC e volta
	# perde a configuração escondida.
	var saved_aim := Sfx.aim_mode
	var saved_scale := Sfx.touch_scale
	var saved_haptics := Sfx.haptics_enabled
	Sfx.aim_mode = "lockon"
	Sfx.touch_scale = 1.2
	Sfx.haptics_enabled = false
	Sfx.save_settings()
	Sfx.aim_mode = "drag"
	Sfx.touch_scale = 0.85
	Sfx.haptics_enabled = true
	Sfx._load_settings()
	h._check(Sfx.aim_mode == "lockon" and is_equal_approx(Sfx.touch_scale, 1.2) and not Sfx.haptics_enabled,
		"touch-only settings survive a save/load round trip regardless of platform")

	# A prova de que o filtro nunca encosta na persistência: quem salva não
	# conhece o manifesto.
	var sfx_src := str((load("res://src/autoload/sfx.gd") as Script).source_code)
	h._check_source(not sfx_src.contains("SettingsManifest") and not sfx_src.contains("Platform."),
		"settings persistence never consults the platform filter")

	Sfx.aim_mode = saved_aim
	Sfx.touch_scale = saved_scale
	Sfx.haptics_enabled = saved_haptics
	Sfx.save_settings()

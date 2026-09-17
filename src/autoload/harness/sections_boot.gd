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
		# A linha distribui a frase em duas colunas, então o estado é lido na
		# COLUNA DE VALOR — que é justamente o que a pessoa olha para saber se
		# está ligado. Ler `.text` do botão testava a frase inteira.
		var kit = menu.get("_settings_kit")
		var value_of := func() -> String:
			var label: Label = color_button.get_meta(kit.ROW_VALUE_META) if color_button.has_meta(kit.ROW_VALUE_META) else null
			return str(label.text) if is_instance_valid(label) else ""
		h._check(value_of.call() == tr("SET_VAL_OFF"), "color assist toggle shows OFF by default")
		color_button.pressed.emit()
		h._check(bool(Sfx.get("color_assist")) and value_of.call() == tr("SET_VAL_ON"), "color assist toggle enables assist mode")
		color_button.pressed.emit()
		h._check(not bool(Sfx.get("color_assist")) and value_of.call() == tr("SET_VAL_OFF"), "color assist toggle disables assist mode")
		h._check(str((color_button.get_meta(kit.ROW_NAME_META) as Label).text) == kit.split_row_text(tr("SET_COLOR_ASSIST") % tr("SET_VAL_OFF"))[0],
			"the row keeps its label in the left column")
	if menu != null and menu.has_method("_close_settings"):
		menu._close_settings()

	var splitter := SplitterEnemy.new()
	var bulwark := BulwarkEnemy.new()
	# load(), não FileAccess: no artefato o .gd não existe como texto, mas o
	# script compilado carrega e `source_code` vem vazio — sem ERROR no log.
	# O marcador saiu de dentro de cada inimigo e virou um filho de
	# `EnemyBase`: eram duas cópias da mesma função, e os outros 21 — os seis
	# do 3.1 inclusive — não tinham nenhuma.
	h._check(splitter.color_assist_marker() == "SPLIT", "Splitter still answers with its own marker")
	h._check(bulwark.color_assist_marker() == "BULW", "Bulwark still answers with its own marker")
	var base_source := str((load("res://src/enemies/enemy_base.gd") as Script).source_code)
	h._check_source(base_source.contains("draw_string") and not base_source.contains(".png"),
		"threat markers use code drawing without images")
	var splitter_source := str((load("res://src/enemies/splitter.gd") as Script).source_code)
	var bulwark_source := str((load("res://src/enemies/bulwark.gd") as Script).source_code)
	h._check_source(not splitter_source.contains("_draw_color_assist_marker") \
		and not bulwark_source.contains("_draw_color_assist_marker"),
		"no enemy carries its own copy of the marker drawing any more")
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

	# CONTROLS é a MESMA seção com conteúdo diferente: teclas no desktop,
	# toque no celular. Era aqui que o mobile não tinha casa — mira, háptico e
	# tamanho de toque moravam em GAMEPLAY.
	var kit_script: GDScript = load("res://src/ui/menu_settings_kit.gd")
	var touch_sections: Array = SettingsManifest.sections_for(touch)
	var desktop_sections: Array = SettingsManifest.sections_for(desktop)
	h._check(touch_sections.has("CONTROLS") and desktop_sections.has("CONTROLS"),
		"both platforms get a controls section")
	for id in ["aim_mode", "touch_scale", "haptics"]:
		h._check(SettingsManifest.section_of(id) == "CONTROLS", "%s lives in the controls section" % id)
	h._check(SettingsManifest.section_of("keybinds") == "CONTROLS", "keybinds live in the controls section")
	h._check(SettingsManifest.section_of("shake") == "ACCESSIBILITY", "screen shake sits with the comfort settings")
	for section in ["AUDIO", "VIDEO", "ACCESSIBILITY", "BOARD", "SAVE DATA"]:
		h._check(touch_sections.has(section) and desktop_sections.has(section),
			"%s survives on both platforms" % section)

	# A regra "seção sem nada não vira aba" continua valendo — provada direto,
	# com uma seção que o manifesto não serve em plataforma nenhuma.
	var with_ghost: Array = SettingsManifest.sections_for(touch, ["CONTROLS", "SECAO_FANTASMA", "AUDIO"])
	h._check(with_ghost == ["CONTROLS", "AUDIO"], "a section with nothing to show never becomes an empty tab")

	# No celular o que se veio ajustar abre primeiro; no desktop a ordem
	# histórica fica de pé.
	h._check(str(touch_sections[0]) == "CONTROLS", "touch opens settings on the controls it came for")
	h._check(str(desktop_sections[0]) == "AUDIO", "desktop keeps the order people already know")

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

## Alvo de toque das linhas de settings.
##
## Só é afirmável porque `Design.target_min()` passou a respeitar
## `KP_FORCE_TOUCH`: antes ele lia `DisplayServer` direto, então o harness
## mudava o que a tela MOSTRA sem mudar o tamanho do alvo, e este contrato era
## impossível de provar sem aparelho de verdade.
func _settings_touch_target_test(menu: Node) -> void:
	print("AT_STEP settings_touch_targets")
	var saved_force := OS.get_environment("KP_FORCE_TOUCH")
	OS.set_environment("KP_FORCE_TOUCH", "1")
	h._check(is_equal_approx(Design.target_min(), Design.TOUCH_TARGET_MIN),
		"forcing touch raises the minimum interaction target to 56px")

	var kit = menu.get("_settings_kit")
	if kit == null:
		h._check(false, "menu exposes its settings kit")
		OS.set_environment("KP_FORCE_TOUCH", saved_force)
		return
	kit.call("rebuild_settings")
	await h._ticks(2)

	# Rótulo e nota não são alvo; o contrato vale para quem o dedo pressiona.
	var members: Dictionary = kit.get("_section_members")
	var small: Array[String] = []
	var checked := 0
	for section in members:
		for control in members[section]:
			if control == null or not is_instance_valid(control):
				continue
			if not (control is Button or control is LineEdit):
				continue
			checked += 1
			if control.custom_minimum_size.y < Design.TOUCH_TARGET_MIN:
				small.append("%s/%s@%.0f" % [section, control.get_class(), control.custom_minimum_size.y])
	h._check(checked > 0, "settings expose pressable rows to measure (%d)" % checked)
	h._check(small.is_empty(), "every pressable settings row meets the touch target (short: %s)" % str(small))

	OS.set_environment("KP_FORCE_TOUCH", saved_force)
	kit.call("rebuild_settings")
	await h._ticks(2)


## Catraca contra reincidência do número mágico de fonte.
##
## O `Design` já declara a regra — "nenhum arquivo de UI deve conter número
## mágico de tamanho" — e o projeto a violava 43 vezes. Settings, que sozinho
## respondia por 28, está zerado; o resto das telas ainda não foi refeito,
## então o teto só pode CAIR. Ao zerar tudo, isto vira `== 0`.
func _ui_font_scale_ratchet_test() -> void:
	print("AT_STEP ui_font_scale_ratchet")
	# Era catraca em 16 enquanto as telas iam sendo refeitas. Zerou: agora a
	# regra que o próprio `Design` declara — "nenhum arquivo de UI deve conter
	# número mágico de tamanho" — é exigida, não tolerada.
	const CEILING := 0
	const CLEAN_FILES := ["res://src/ui/menu_settings_kit.gd"]
	var dir := DirAccess.open("res://src/ui")
	var offenders := {}
	var total := 0
	var pattern := RegEx.new()
	pattern.compile("add_theme_font_size_override\\(\"font_size\", [0-9]")
	var stack: Array[String] = ["res://src/ui"]
	while not stack.is_empty():
		var at: String = stack.pop_back()
		var d := DirAccess.open(at)
		if d == null:
			continue
		for name in d.get_files():
			if not name.ends_with(".gd"):
				continue
			var path := "%s/%s" % [at, name]
			var script: Script = load(path)
			if script == null:
				continue
			var hits := pattern.search_all(str(script.source_code)).size()
			if hits > 0:
				offenders[path] = hits
				total += hits
		for sub in d.get_directories():
			stack.append("%s/%s" % [at, sub])
	h._check_source(total <= CEILING,
		"no UI file carries a magic font size (%d): %s" % [total, str(offenders)])
	for clean in CLEAN_FILES:
		h._check_source(not offenders.has(clean), "%s stays free of magic font sizes" % clean)


## A UI do KERNEL PANIC é desenhada, não rasterizada.
##
## Os controles de toque eram o último resto: dash, boost e pausa saíam de
## PNG porque o `TacticalIcon` nunca ganhou overclock nem pausa, e um símbolo
## rasterizado não acompanha escala de toque nem densidade de tela. Agora os
## três vêm da mesma geometria que o HUD usa.
func _ui_is_vector_test() -> void:
	print("AT_STEP ui_is_vector")
	var icon_script: GDScript = load("res://src/ui/tactical_icon.gd")
	var drawable := {}
	for entry in icon_script.get_script_method_list():
		drawable[str(entry["name"])] = true
	for kind in ["dash", "overclock", "pause"]:
		h._check(drawable.has("stroke_%s" % kind),
			"the icon library can draw %s in code" % kind)

	var offenders: Array[String] = []
	var stack: Array[String] = ["res://src/ui"]
	while not stack.is_empty():
		var at: String = stack.pop_back()
		var d := DirAccess.open(at)
		if d == null:
			continue
		for name in d.get_files():
			if not name.ends_with(".gd"):
				continue
			var script: Script = load("%s/%s" % [at, name])
			if script == null:
				continue
			var src := str(script.source_code)
			# `generated/` é cache rasterizado DO QUE JÁ É VETOR, gerado a
			# partir destas mesmas funções; ícone desenhado à mão é que não.
			if src.contains("assets/icons/") and not src.contains("assets/icons/generated/"):
				offenders.append("%s/%s" % [at, name])
		for sub in d.get_directories():
			stack.append("%s/%s" % [at, sub])
	h._check_source(offenders.is_empty(), "no UI script draws from a hand-made raster icon (%s)" % str(offenders))

## Intensidade de luz: um fator, quatro consumidores.
##
## O jogo dispara branco puro a 0.55 na tela inteira (`root_boss.gd`), inverte
## a paleta da fase no KERNEL_TASK, distorce tudo no dano e cintila no CRT —
## e até aqui nada disso tinha controle. Só o shake tinha.
func _flash_intensity_test() -> void:
	print("AT_STEP flash_intensity")
	var saved := Sfx.flash_level

	Sfx.flash_level = 2
	h._check(is_equal_approx(Fx.flash_scale(), 1.0), "full intensity leaves the light events untouched")
	Sfx.flash_level = 1
	var reduced := Fx.flash_scale()
	h._check(reduced > 0.0 and reduced < 1.0, "reduced intensity dims without removing the cue")
	Sfx.flash_level = 0
	h._check(is_equal_approx(Fx.flash_scale(), 0.0), "off silences the light events")

	# Com o flash desligado o clarão não desenha NADA. Afirmado pelo estado do
	# retângulo de flash, não pela ausência de erro.
	var before_layer = Fx.get("_flash_layer")
	Fx.flash(Color(1, 1, 1), 0.55, 0.4)
	h._check(Fx.get("_flash_layer") == before_layer, "a silenced flash never even builds its layer")

	# A inversão de paleta do KERNEL_TASK é o maior evento de luminância do
	# jogo, e é o que mais assusta quem precisa deste controle.
	var arena_src := str((load("res://src/arena/arena.gd") as Script).source_code)
	h._check_source(arena_src.contains("if inverted and Fx.flash_scale() <= 0.0:"),
		"the field inversion asks the light budget before flipping the stage")

	# O que INFORMA não pode ser apagado junto com o que decora.
	var overlay_src := str((load("res://src/arena/arena_overlay.gd") as Script).source_code)
	h._check_source(overlay_src.contains('"aberr", aberr * Fx.flash_scale()'),
		"the damage distortion obeys the light budget")
	h._check_source(overlay_src.contains('"hurt", hurt)') and overlay_src.contains('"low_hp", low_hp)'),
		"the damage and low-integrity cues stay readable at every setting")

	# Shake e flash são incômodos diferentes e continuam separados.
	var saved_shake := Sfx.shake_level
	Sfx.shake_level = 2
	Sfx.flash_level = 0
	h._check(Sfx.shake_level == 2 and is_equal_approx(Fx.flash_scale(), 0.0),
		"silencing the light never touches the screen shake")
	Sfx.shake_level = saved_shake

	# Atravessa o disco, como todo o resto.
	Sfx.flash_level = 1
	Sfx.save_settings()
	Sfx.flash_level = 2
	Sfx._load_settings()
	h._check(Sfx.flash_level == 1, "the light setting survives a save/load round trip")

	Sfx.flash_level = saved
	Sfx.save_settings()

## Color assist medido, não inventado.
##
## Até aqui a assistência cobria DOIS inimigos de 23; os seis que entraram no
## 3.1 não tinham nada. Recolorir os 23 na mão trocaria um problema por outro,
## então a regra é: mede a distância entre todos os pares e só exige troca
## onde duas entidades são confusáveis de verdade.
func _entity_palette_test() -> void:
	print("AT_STEP entity_palette")
	var ids: Array[String] = []
	for entry in BestiaryPanel.ENTRIES:
		ids.append(str(entry["id"]))
	h._check(ids.size() == 23, "the bestiary still holds 23 entries (%d)" % ids.size())

	# Nenhuma entidade pode cair no texto padrão: era o que acontecia com GOD
	# e com os seis do 3.1, todos pintados da mesma cor na lista.
	var defaulted: Array[String] = []
	for id in ids:
		if not Balance.ENTITY_COLORS.has(id):
			defaulted.append(id)
	h._check(defaulted.is_empty(), "every bestiary entry has its own colour (missing: %s)" % str(defaulted))

	# Marcador para todo mundo: é ele que funciona sem depender de matiz.
	var unmarked: Array[String] = []
	for id in ids:
		if Balance.entity_marker(id) == "":
			unmarked.append(id)
	h._check(unmarked.is_empty(), "every bestiary entry has an assist marker (missing: %s)" % str(unmarked))

	# Pares confusáveis, com a assistência LIGADA.
	#
	# A regra vale entre os inimigos COMUNS, que é o que divide a tela num
	# mesmo instante. Bosses reusam a cor da própria família de propósito
	# (ROOT herda de DRONE, SEGFAULT de LANCER) e chegam sozinhos, no dobro do
	# tamanho: exigir que fossem distintos apagaria um sinal de leitura em vez
	# de criar um. O marcador, esse sim, todos têm.
	const TOO_CLOSE := 0.14
	var regulars: Array[String] = []
	for entry in BestiaryPanel.ENTRIES:
		if not Balance.is_boss_id(str(entry["id"])):
			regulars.append(str(entry["id"]))
	h._check(regulars.size() >= 12, "the regular roster is big enough to be worth sweeping (%d)" % regulars.size())
	var clashes: Array[String] = []
	for i in regulars.size():
		for j in range(i + 1, regulars.size()):
			var a := Balance.entity_color(regulars[i], true)
			var b := Balance.entity_color(regulars[j], true)
			var d: float = h._color_distance(a, b)
			if d < TOO_CLOSE:
				clashes.append("%s~%s=%.3f" % [regulars[i], regulars[j], d])
	h._check(clashes.is_empty(), "no two regular enemies stay confusable with color assist on: %s" % str(clashes))

	# ── daltonismo, medido ────────────────────────────────────────────────
	#
	# Distância em RGB não diz nada sobre confusão real: duas cores longe em
	# RGB podem ser idênticas para quem tem protanopia. Foi assim que a
	# assistência anterior passou despercebida — ela punha BULWARK e
	# OOM_KILLER a 0.009 em deuteranopia, para justamente quem a liga.
	const CVD_FLOOR := 0.07
	var cvd_clashes: Array[String] = []
	for kind in Balance.CVD_MATRICES:
		for i in regulars.size():
			for j in range(i + 1, regulars.size()):
				var sa := Balance.simulate_cvd(Balance.entity_color(regulars[i], true), kind)
				var sb := Balance.simulate_cvd(Balance.entity_color(regulars[j], true), kind)
				var sd: float = h._color_distance(sa, sb)
				if sd < CVD_FLOOR:
					cvd_clashes.append("%s~%s(%s)=%.3f" % [regulars[i], regulars[j], kind, sd])
	h._check(cvd_clashes.is_empty(), "the regular roster survives simulated colour blindness: %s" % str(cvd_clashes))

	# O INVARIANTE que faltava: ligar a assistência nunca pode APROXIMAR duas
	# entidades. A versão anterior piorava 36 combinações de par e deficiência,
	# e nada no projeto impedia isso.
	var regressions: Array[String] = []
	for i in regulars.size():
		for j in range(i + 1, regulars.size()):
			var plain_a := Balance.entity_color(regulars[i], false)
			var plain_b := Balance.entity_color(regulars[j], false)
			var help_a := Balance.entity_color(regulars[i], true)
			var help_b := Balance.entity_color(regulars[j], true)
			for kind2 in Balance.CVD_MATRICES:
				var off: float = h._color_distance(Balance.simulate_cvd(plain_a, kind2), Balance.simulate_cvd(plain_b, kind2))
				var on: float = h._color_distance(Balance.simulate_cvd(help_a, kind2), Balance.simulate_cvd(help_b, kind2))
				if on < off - 0.01:
					regressions.append("%s~%s(%s) %.3f->%.3f" % [regulars[i], regulars[j], kind2, off, on])
	h._check(regressions.is_empty(), "colour assist never pushes two entities closer together: %s" % str(regressions))

	# A simulação em si tem que estar certa, senão os dois testes acima medem
	# o nada. Cinza é acromático: nenhuma deficiência o desloca.
	var grey := Color(0.5, 0.5, 0.5)
	for kind3 in Balance.CVD_MATRICES:
		h._check(h._color_distance(Balance.simulate_cvd(grey, kind3), grey) < 0.02,
			"%s simulation leaves an achromatic colour where it is" % kind3)
	var pure_red := Color(1, 0, 0)
	h._check(h._color_distance(Balance.simulate_cvd(pure_red, "protan"), pure_red) > 0.3,
		"protanopia visibly moves pure red, so the simulation is doing something")

## Escala global de texto.
##
## Só é possível porque nenhum arquivo de UI carrega mais número mágico de
## tamanho: os 65 pontos que definem fonte passam por `Design.px()`, e a
## preferência multiplica ali. Antes eram 43 literais espalhados por dez
## arquivos, e qualquer escala global deixaria metade da tela para trás.
func _text_scale_test(menu: Node) -> void:
	print("AT_STEP text_scale")
	var saved := Sfx.text_scale

	Sfx.text_scale = 1.0
	h._check(Design.px(Design.TEXT_BODY) == Design.TEXT_BODY, "at normal size the scale changes nothing")
	Sfx.text_scale = 1.3
	h._check(Design.px(Design.TEXT_BODY) > Design.TEXT_BODY, "a larger setting grows the body text")
	h._check(Design.px(Design.TEXT_MICRO) > Design.TEXT_MICRO, "it grows the smallest step too, which is the one that hurts")
	# A ordem dos degraus tem que sobreviver à multiplicação, senão a
	# hierarquia da tela inverte em algum tamanho.
	for scale in Sfx.TEXT_SCALE_STEPS:
		Sfx.text_scale = float(scale)
		var last := 0
		var ordered := true
		for step in Design.TEXT_SCALE:
			var value := Design.px(int(step))
			if value <= last:
				ordered = false
			last = value
		h._check(ordered, "the type scale stays strictly increasing at %.2fx" % scale)

	# E o layout tem que aguentar: cada linha de settings dentro da coluna.
	var kit = menu.get("_settings_kit")
	if kit != null:
		for scale2 in Sfx.TEXT_SCALE_STEPS:
			Sfx.text_scale = float(scale2)
			kit.call("rebuild_settings")
			await h._ticks(2)
			var box: Control = menu.get("_settings_box")
			var overflow: Array[String] = []
			if box != null and is_instance_valid(box):
				for section in (kit.get("_section_members") as Dictionary):
					for control in (kit.get("_section_members") as Dictionary)[section]:
						if control == null or not is_instance_valid(control) or not control.visible:
							continue
						if control.size.x > box.size.x + 1.0:
							overflow.append("%s@%.0f>%.0f" % [section, control.size.x, box.size.x])
			h._check(overflow.is_empty(), "no settings row overflows its column at %.2fx (%s)" % [scale2, str(overflow)])

	Sfx.text_scale = saved
	Sfx.save_settings()
	if kit != null:
		kit.call("rebuild_settings")
		await h._ticks(2)

## Alvo de toque em TODAS as telas, não só em settings.
##
## O 3.1 foi feito PC-first: a regra de 56px existia em `Design.target_min()`
## mas quase nada a consultava. Esta varredura instancia cada painel com o
## toque forçado e mede o que o dedo pressiona.
func _panel_touch_target_test() -> void:
	print("AT_STEP panel_touch_targets")
	var saved_force := OS.get_environment("KP_FORCE_TOUCH")
	OS.set_environment("KP_FORCE_TOUCH", "1")

	var panels := {
		"pause": "res://src/ui/pause_panel.gd",
		"bestiary": "res://src/ui/bestiary_panel.gd",
		"programs": "res://src/ui/program_panel.gd",
		"story": "res://src/ui/story_panel.gd",
		"summary": "res://src/ui/run_summary_panel.gd",
		"awards": "res://src/ui/achievements_panel.gd",
		"board": "res://src/ui/board_panel.gd",
		"terminal": "res://src/ui/terminal_panel.gd",
		"shell": "res://src/ui/menu_shell.gd",
	}
	var short: Array[String] = []
	var measured := 0
	for name in panels:
		var script: Script = load(panels[name])
		if script == null:
			continue
		var panel = script.new()
		if not (panel is Control):
			continue
		panel.size = Vector2(900, 480)
		h.add_child(panel)
		await h._ticks(3)
		for node in (panel as Control).find_children("*", "", true, false):
			if not (node is BaseButton or node is LineEdit):
				continue
			var control := node as Control
			# Só conta o que está realmente na tela: nó escondido não é alvo.
			if not control.is_visible_in_tree():
				continue
			measured += 1
			var height := maxf(control.custom_minimum_size.y, control.size.y)
			if height < Design.TOUCH_TARGET_MIN - 0.5:
				var who: String = str(control.get("text")) if control.has_method("get_text") else str(control.name)
				var parent_h: float = (control.get_parent() as Control).size.y if control.get_parent() is Control else -1.0
				short.append("%s/%s'%s'@%.0f(pai=%.0f)" % [name, control.get_class(), who.substr(0, 12), height, parent_h])
		panel.queue_free()
		await h._ticks(1)

	h._check(measured > 0, "the sweep found pressable controls to measure (%d)" % measured)
	h._check(short.is_empty(), "every on-screen control meets the touch target: %s" % str(short))

	if saved_force.is_empty():
		OS.set_environment("KP_FORCE_TOUCH", "")
	else:
		OS.set_environment("KP_FORCE_TOUCH", saved_force)

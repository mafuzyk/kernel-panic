extends RefCounted

## Autotest section script. Function bodies below are moved verbatim from
## src/autoload/dev_harness.gd; only harness-helper references are prefixed
## with `h` per plan section G3. No behavior changes. AT_STEP labels and
## message strings are byte-identical to the originals.

var h: Node


func _init(harness: Node) -> void:
	h = harness


## Entrada pelo viewport: detecta ausência de foco, armadilha de seta e foco
## perdido ao fechar overlays. Não chama handlers de teclado diretamente.
func _desktop_focus_test(menu: Node) -> void:
	print("AT_STEP desktop_focus")
	var viewport: Viewport = h.get_viewport()
	var shell: Control = menu.get("_shell")
	var initial: Control = viewport.gui_get_focus_owner()
	if initial == null or not shell.is_ancestor_of(initial):
		print("AT_DEBUG menu initial focus=", initial.name if initial != null else "null")
	h._check(initial != null and shell.is_ancestor_of(initial),
		"desktop menu opens with an actionable keyboard focus")
	# Mesmo sem foco inicial, reproduz a armadilha de seta de forma independente.
	var purge: Button = h._first_button(shell)
	purge.grab_focus()
	_focus_key(KEY_DOWN)
	var next: Control = viewport.gui_get_focus_owner()
	h._check(next != null and next != purge and shell.is_ancestor_of(next),
		"Down leaves PURGE for another menu action")
	# A fileira MODE entrou entre PURGE e o resto: um Down para nela.
	if shell.has_method("run_config_hits"):
		var mode_hit: Button = shell.run_config_hits().get("mode")
		h._check(next == mode_hit, "Down from PURGE reaches the MODE control")
	# Travessia genuína por teclado até trocar programa: Tab do PURGE ao swap,
	# Enter abre o seletor. Sem mouse em nenhum ponto.
	h._check(shell.has_method("swap_hit") and is_instance_valid(shell.swap_hit()), "shell exposes the program swap control")
	if shell.has_method("swap_hit") and is_instance_valid(shell.swap_hit()):
		var swap: Button = shell.swap_hit()
		purge.grab_focus()
		var reached := false
		for i in 8:
			_focus_key(KEY_TAB)
			if viewport.gui_get_focus_owner() == swap:
				reached = true
				break
		h._check(reached, "Tab from PURGE reaches program swap without a mouse")
		if not reached:
			return
		_focus_key(KEY_ENTER)
		if not h._check(not bool(menu.get("_starting")),
			"Enter on a menu route does not trigger the global start shortcut"):
			return
		await h._ticks(3)
		var opened: Control = menu.get("_program_panel")
		h._check(opened != null and opened.visible,
			"keyboard Enter on swap opens program selection without a mouse")
		if opened != null and opened.visible:
			menu.call("_close_program_selector")
	# O anel de foco do PURGE envolve a ação primária, não a coluna inteira.
	h._check(shell.has_method("primary_hit_rect"), "shell exposes the primary action geometry")
	if shell.has_method("primary_hit_rect"):
		var hit_rect: Rect2 = shell.primary_hit_rect()
		var purge_label: Label = shell.get("_purge_label")
		if not (is_instance_valid(purge_label) and hit_rect.encloses(purge_label.get_global_rect())):
			var host: Control = shell.get("_purge_host")
			print("AT_DEBUG purge hit=", hit_rect, " label=", purge_label.get_global_rect() if is_instance_valid(purge_label) else Rect2(), " host=", (host.size if is_instance_valid(host) else Vector2(-1, -1)), " shell=", shell.size)
		h._check(is_instance_valid(purge_label) and hit_rect.encloses(purge_label.get_global_rect()), "purge focus ring wraps the arrow and wordmark")
		h._check(hit_rect.size.y >= Design.CLICK_TARGET_MIN, "purge hit keeps the click-target minimum")
		h._check(hit_rect.size.x < shell.size.x * 0.85, "purge focus ring stays bounded to the primary action")
	for spec in [
		["program", "_open_program_selector", "_close_program_selector", "_program_panel"],
		["story", "_open_story_selector", "_close_story_selector", "_story_panel"],
		["bestiary", "_open_bestiary", "_close_bestiary", "_bestiary_panel"],
		["achievements", "_open_achievements", "_close_achievements", "_ach_panel"],
		["settings", "_open_settings", "_close_settings", "_settings_panel"],
	]:
		purge.grab_focus()
		menu.call(str(spec[1]))
		await h._ticks(3)
		var panel: Control = menu.get(str(spec[3]))
		var focused: Control = viewport.gui_get_focus_owner()
		h._check(focused != null and panel.is_ancestor_of(focused),
			"%s takes keyboard focus when opened" % spec[0])
		var visited: Array[Control] = []
		var contained := true
		for step in panel.find_children("*", "Control", true, false).size() + 1:
			focused = viewport.gui_get_focus_owner()
			if focused == null or not panel.is_ancestor_of(focused):
				contained = false
				break
			if visited.has(focused):
				break
			visited.append(focused)
			_focus_key(KEY_TAB)
		h._check(contained, "%s keeps Tab inside the open panel" % spec[0])
		var reachable := true
		for node in panel.find_children("*", "BaseButton", true, false):
			if node.is_visible_in_tree() and not node.disabled and node.focus_mode == Control.FOCUS_ALL:
				reachable = reachable and visited.has(node)
		h._check(reachable, "%s makes every enabled button reachable by Tab" % spec[0])
		menu.call(str(spec[2]))
		await h._ticks(3)
		h._check(viewport.gui_get_focus_owner() == purge,
			"%s returns focus to its opener when closed" % spec[0])
		# O segundo show não passa por _ready().
		menu.call(str(spec[1]))
		await h._ticks(3)
		focused = viewport.gui_get_focus_owner()
		h._check(focused != null and panel.is_ancestor_of(focused),
			"%s takes keyboard focus again when reopened" % spec[0])
		menu.call(str(spec[2]))
		await h._ticks(3)
	purge.grab_focus()
	await _selector_activation_test()
	# O anel de foco do rodapé precisa conter o rótulo: a célula media
	# `get_minimum_size()` antes do layout (zero) e o texto transbordava.
	if shell.has_method("footer_hosts"):
		var ring_ok := true
		for host in shell.footer_hosts():
			if not is_instance_valid(host):
				ring_ok = false
				continue
			for label in host.find_children("*", "Label", true, false):
				if not (host as Control).get_global_rect().encloses((label as Control).get_global_rect()):
					ring_ok = false
		h._check(ring_ok, "footer focus ring contains its label")
	await _menu_pointer_test()
	await _action_feedback_test()
	purge.grab_focus()


func _action_feedback_test() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	h.add_child(layer)
	var col := VBoxContainer.new()
	layer.add_child(col)
	for emphasis in ["text", "danger", "primary"]:
		var block := ScreenKit.action("Action", "", emphasis, func() -> void: pass)
		col.add_child(block)
		await h._ticks(3)
		var hit: Button = block.get_meta("hit")
		var label: Label = block.get_meta("label_node")
		var outside := InputEventMouseMotion.new()
		outside.position = Vector2(1200, 650)
		h.get_viewport().push_input(outside, true)
		hit.release_focus()
		await h._ticks(2)
		var idle: Color = label.self_modulate
		var fill: StyleBoxFlat = block.get_theme_stylebox("panel")
		var idle_fill: Color = fill.bg_color
		var motion := InputEventMouseMotion.new()
		motion.position = hit.get_global_rect().get_center()
		h.get_viewport().push_input(motion, true)
		await h._ticks(2)
		var hover: Color = label.self_modulate
		var hover_fill: Color = fill.bg_color
		hit.grab_focus()
		h.get_viewport().push_input(outside, true)
		await h._ticks(2)
		h._check(label.self_modulate == hover and fill.bg_color == hover_fill,
			"%s mouse and keyboard use the same active feedback" % emphasis)
		if emphasis == "primary":
			h._check(idle_fill == Design.ACCENT and hover_fill == Design.ACCENT_HOT
				and label.get_theme_color("font_color") == Design.SURFACE and label.self_modulate == Color.WHITE,
				"primary feedback brightens the surface while preserving dark text")
		else:
			h._check(is_equal_approx(idle.a, Design.TEXT_SECONDARY.a) and hover == Color.WHITE,
				"%s feedback brightens the separate label on hover" % emphasis)
		hit.release_focus()
		await h._ticks(2)
		h._check(label.self_modulate == idle and fill.bg_color == idle_fill,
			"%s feedback restores idle after mouse and focus leave" % emphasis)
		hit.disabled = true
		h.get_viewport().push_input(motion, true)
		await h._ticks(2)
		h._check(label.self_modulate == idle and fill.bg_color == idle_fill,
			"%s disabled action does not display active feedback" % emphasis)
		hit.disabled = false
		hit.grab_focus()
		await h._ticks(2)
		hit.disabled = true
		await h._ticks(2)
		h._check(label.self_modulate == idle and fill.bg_color == idle_fill,
			"%s disabling an active action removes its feedback" % emphasis)
		var ring: StyleBoxFlat = hit.get_theme_stylebox("focus")
		h._check(ring.border_color == Design.FOCUS_RING_COLOR and ring.border_width_left == int(Design.FOCUS_RING_WIDTH),
			"%s feedback preserves the amber keyboard ring" % emphasis)
		block.queue_free()
		await h._ticks(2)
	layer.queue_free()
	await h._ticks(2)


func _menu_pointer_test() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	h.add_child(layer)
	var shell := MenuShell.new()
	layer.add_child(shell)
	await h._ticks(3)
	var presses: Array = []
	shell.purge_pressed.connect(func() -> void: presses.append("purge"))
	var label: Label = shell.get("_purge_label")
	var hit: Button = h._first_button(shell)
	h._check(hit.get_global_rect().encloses(label.get_global_rect()),
		"PURGE mouse target covers its visible label")
	await _focus_click(label.get_global_rect().get_center())
	h._check(presses == ["purge"], "clicking the PURGE label triggers it exactly once")
	presses.clear()
	hit.grab_focus()
	_focus_key(KEY_ENTER)
	h._check(presses == ["purge"], "keyboard and mouse activate the same PURGE action")
	layer.queue_free()
	await h._ticks(2)


func _focus_click(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	# get_global_rect() está no viewport lógico; não aplicar o stretch da janela
	# novamente ao injetar coordenadas de mouse.
	h.get_viewport().push_input(motion, true)
	await h._ticks(1)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		h.get_viewport().push_input(event, true)


func _selector_activation_test() -> void:
	var saved_program: String = Game.program
	var layer := CanvasLayer.new()
	layer.layer = 100
	h.add_child(layer)
	var program := ProgramPanel.new()
	program.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(program)
	await h._ticks(3)
	var selections: Array = []
	var boots: Array = []
	program.selection_changed.connect(func(id: String) -> void: selections.append(id))
	program.boot_pressed.connect(func() -> void: boots.append(true))
	var card: Button = program.get("_cards")["kernel"].get_meta("hit")
	card.grab_focus()
	_focus_key(KEY_ENTER)
	h._check(selections == ["kernel"] and boots.is_empty(),
		"program Enter selects the focused card once without booting")
	selections.clear()
	boots.clear()
	var boot: Button = program.get("_boot_block").get_meta("hit")
	boot.grab_focus()
	_focus_key(KEY_ENTER)
	h._check(boots == [true], "program Enter on BOOT emits exactly one boot")
	program.hide()
	var story: Control = load("res://src/ui/story_panel.gd").new()
	story.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(story)
	await h._ticks(3)
	var mounts: Array = []
	story.stage_mounted.connect(func(index: int) -> void: mounts.append(index))
	var mount: Button = story.get("_mount_block").get_meta("hit")
	mount.grab_focus()
	_focus_key(KEY_ENTER)
	h._check(mounts.size() == 1, "story Enter on MOUNT emits exactly one mount")
	layer.queue_free()
	await h._ticks(2)
	Game.set_program(saved_program)


func _focus_key(code: int) -> void:
	var event: InputEventKey = h._key_event(code)
	h.get_viewport().push_input(event)
	var released := InputEventKey.new()
	released.keycode = code
	released.physical_keycode = code
	h.get_viewport().push_input(released)


func _arena_focus_test(arena: Arena) -> void:
	print("AT_STEP arena_focus")
	arena._set_paused(true)
	await h._ticks(3)
	var pause: Control = arena.get("_pause_screen")
	var resume: Button = h._first_button(pause)
	h._check(h.get_viewport().gui_get_focus_owner() == resume,
		"pause opens with Resume focused instead of requiring Tab")
	var terminal: Button = pause.get("_action_blocks")[2].get_meta("hit")
	terminal.grab_focus()
	_focus_key(KEY_ENTER)
	await h._ticks(3)
	var terminal_panel: Control = arena.get("_terminal_panel")
	h._check(terminal_panel.visible and h.get_viewport().gui_get_focus_owner() is LineEdit,
		"Enter on Terminal opens the command field")
	terminal_panel.close_terminal()
	await h._ticks(3)
	h._check(pause.visible, "Terminal close action restores the pause panel")
	h._check(h.get_viewport().gui_get_focus_owner() == terminal,
		"closing Terminal restores focus to its pause action")
	arena._set_paused(false)
	arena._show_run_summary()
	await h._ticks(3)
	var summary: Control = arena.get("_run_summary")
	h._check(h.get_viewport().gui_get_focus_owner() == h._first_button(summary),
		"run summary opens with its primary action focused")
	summary.hide()
	var saved_pending: int = arena.get("_patch_pending")
	var saved_rng: int = Game.rng.state
	arena.set("_patch_pending", 1)
	arena._try_show_patch()
	await h._ticks(3)
	var patch_panel: Control = arena.get("_patch_panel")
	var focused: Control = h.get_viewport().gui_get_focus_owner()
	h._check(focused != null and patch_panel.is_ancestor_of(focused),
		"patch offers open with a card focused")
	patch_panel.hide()
	arena.set("_patch_open", false)
	arena.set("_patch_pending", saved_pending)
	Game.rng.state = saved_rng
	h.get_tree().paused = false

## Um card de fase estreito demais corta a descrição no meio da palavra —
## era o caso com `cols = 6` cravado (73px por card).
func _story_card_width_test(story_panel) -> void:
	if story_panel == null or not story_panel.has_method("_content_metrics"):
		return
	for vp in [Vector2(1280, 720), Vector2(1366, 768), Vector2(720, 720)]:
		story_panel.size = vp
		var metrics: Dictionary = story_panel.call("_content_metrics")
		h._check(float(metrics["card_w"]) >= 120.0,
			"story stage cards stay readable at %dx%d (%dpx)" % [int(vp.x), int(vp.y), int(metrics["card_w"])])


func _story_menu_test(menu: Node) -> void:
	print("AT_STEP story_menu")
	var story_panel_script: Script = load("res://src/ui/story_panel.gd")
	h._check(story_panel_script != null, "story selector script loads")
	# Era `menu.get("_story_btn") != null` — prendia o contrato a um WIDGET da
	# barra antiga, que é construída e escondida. A rota é o contrato; por onde
	# ela é oferecida é decisão da casca.
	var menu_routes: Array = menu.main_shell_snapshot().get("routes", [])
	h._check(menu.has_method("_open_story_selector") and menu_routes.has("STORY"),
		"menu exposes a separate Story entry")
	if story_panel_script == null or not menu.has_method("_open_story_selector"):
		return
	menu.call("_open_story_selector")
	await h._ticks(2)
	var panel = menu.get("_story_panel")
	h._check(panel != null and panel.visible, "story selector opens without changing endless mode")
	if panel != null:
		h._check(panel.has_method("available_stage_indices") and panel.has_method("select_stage"), "story selector exposes stage interaction API")
		await _story_card_width_test(panel)
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
			if bool(settings_layout.get("compact", false)):
				h._check(Rect2(settings_layout["chips"]).end.y <= settings_layout["content"].position.y, "settings chips row sits above the content at %dx%d" % [int(viewport_size.x), int(viewport_size.y)])
			else:
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
	# A geometria da pausa era verificada contra TacticalStateSurface.pause_layout(),
	# que posicionava tudo por retângulo absoluto. A tela virou PausePanel, com
	# containers, e essas asserções passaram a descrever um layout que não existe
	# mais — foram substituídas pelas de contenção em _task9_test, que medem o
	# painel VIVO. Ver docs/superpowers/reports/2026-09-11-auditoria-desktop.md.

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
	var story_intro_panel = story_arena.get("_story_intro_panel")
	var story_intro_title: Label = story_arena.get("_story_intro_title")
	h._check(story_intro_panel is Control and story_intro_panel.theme == UiTheme.shared(),
		"story intro uses the shared design theme")
	h._check(story_intro_panel is Control and story_intro_panel.has_method("content_rects"),
		"story intro exposes live editorial content geometry")
	if story_intro_panel is Control and story_intro_panel.has_method("content_rects"):
		var intro_bounds := Rect2(Vector2.ZERO, story_intro_panel.size)
		var intro_inside := true
		for raw_rect in story_intro_panel.call("content_rects"):
			intro_inside = intro_inside and intro_bounds.encloses(Rect2(raw_rect))
		h._check(intro_inside, "story intro live editorial content stays inside the viewport")
	h._check(story_intro_title != null and story_intro_title.get_theme_font("font") == Design.grotesk(Design.WEIGHT_BLACK),
		"story intro title uses the editorial grotesk instead of Orbitron")
	h._check(story_intro_title != null and story_intro_title.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT,
		"story intro title follows the left-aligned editorial hierarchy")
	var tactical_story_surfaces: Array[Node] = story_intro_panel.find_children("*", "TacticalStateSurface", true, false) if story_intro_panel is Control else []
	h._check(tactical_story_surfaces.is_empty(), "story intro no longer renders a TacticalStateSurface shell")
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
	var pre_auto_id := h.get_tree().current_scene.get_instance_id() if h.get_tree().current_scene != null else 0
	var loaded: bool = await h._until(func() -> bool:
		var cur := h.get_tree().current_scene
		return cur != null and cur.name == "Arena" and cur.get_instance_id() != pre_auto_id, 6.0, "story arena")
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
	h._check_source(hud_src.contains("if not touch_layout():"), "combat hud skips desktop-only dash module drawing on touch")
	# Era texto-fonte e travava a frase na forma literal — quebrou na tradução,
	# sem regressão nenhuma. `overclock_label()` é função pura dos quatro
	# estados, então a REGRA dá para afirmar direto.
	var hud_probe: Hud = hud_script.new()
	h._check(not hud_probe.overclock_label(false, true, false, true).contains("[E]"),
		"overclock ready keeps its label without the [E] keyboard hint on touch")
	h._check(hud_probe.overclock_label(false, true, false, false).contains("[E]"),
		"desktop keeps the [E] hint when overclock is ready")
	h._check(not hud_probe.overclock_label(true, true, false, false).contains("[E]"),
		"shield programs never advertise the overclock key")
	hud_probe.queue_free()
	h._check(hud_probe.dash_charge_text(1, false).contains("[SHIFT]"), "dash charge text gates the [SHIFT] keyboard hint on touch")
	h._check(not hud_probe.dash_charge_text(1, true).contains("[SHIFT]"), "touch dash charge hides the keyboard hint")
	h._check(hud_probe.dash_charge_text(2, true) == "x2", "multi-charge dash shows its count")
	var tc_script: Script = load("res://src/ui/touch_controls.gd")
	var tc = tc_script.new() if tc_script != null else null
	h._check(tc != null and tc.has_method("_dash_btn") and tc.has_method("_oc_btn"), "touch controls expose button rects for layout probes")
	h._check(tc != null and tc.has_method("visual_state"), "touch controls expose their live visual state")
	if tc != null and tc.has_method("visual_state"):
		tc.set("_aim_active", false)
		var idle_visual: Dictionary = tc.call("visual_state")
		h._check(bool(idle_visual.get("dash", false)) and bool(idle_visual.get("boost", false)),
			"touch dash and boost remain visible without an active aim gesture")
		h._check(not bool(idle_visual.get("aim", true)), "touch aim overlay stays hidden until aim is active")
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
	h._check(banner_hud.has_method("banner_layout_snapshot"), "combat hud exposes live banner layout geometry")
	if banner_hud.has_method("banner_layout_snapshot"):
		for vp in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
			banner_hud.size = vp
			var wave_banner: Dictionary = banner_hud.call("banner_layout_snapshot", vp, "CYCLE 01", "PURGE THE DAEMONS")
			var encounter: Rect2 = banner_hud.call("layout_snapshot", vp)["encounter"]
			var sub_rect: Rect2 = wave_banner.get("sub_rect", Rect2())
			h._check(not bool(wave_banner.get("main_visible", true)), "cycle banner does not duplicate the encounter cycle at %dx%d" % [int(vp.x), int(vp.y)])
			h._check(sub_rect.position.y >= encounter.end.y and Rect2(Vector2.ZERO, vp).encloses(sub_rect),
				"cycle banner subtitle stays below encounter and inside viewport at %dx%d" % [int(vp.x), int(vp.y)])
		var hint_banner: Dictionary = banner_hud.call("banner_layout_snapshot", Vector2(432, 720), "MOVE // WASD", "")
		h._check(bool(hint_banner.get("main_visible", false)), "subtitle-less combat hint keeps its main line on compact")
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

func _corrupt_save_test() -> void:
	print("AT_STEP corrupt_save")
	var path := Sfx.SAVE_PATH
	var had_file := FileAccess.file_exists(path)
	var backup := FileAccess.get_file_as_bytes(path) if had_file else PackedByteArray()
	var dir := DirAccess.open("user://")
	var saved_mode := Game.mode
	var saved_diff := Game.difficulty
	var saved_onehp := Game.onehp_unlocked
	if had_file:
		dir.remove("kernel_panic.cfg")
	# Sem arquivo, o load não tem o que ler: mantém o estado seguro em
	# memória sem erro e sem lixo. (Defaults de boot vêm das declarações.)
	Game.mode = "classic"
	Game.difficulty = "normal"
	Game.onehp_unlocked = false
	Game._load_run_config()
	h._check(Game.mode == "classic" and Game.difficulty == "normal" and not Game.onehp_unlocked, "missing save keeps safe state without errors")
	var bad := ConfigFile.new()
	bad.set_value("run", "best_classic", 424242)
	bad.set_value("run", "onehp_unlocked", "yes-please")
	bad.set_value("game", "mode", 12345)
	bad.set_value("game", "difficulty", "lunatic")
	bad.set_value("bestiary", "seen", "nope")
	bad.set_value("programs", "unlocked", "kernel")
	bad.set_value("story", "cleared", "cleared!")
	bad.save(path)
	Game._load_run_config()
	h._check(Game.mode == "classic", "wrong-typed mode falls back to classic")
	h._check(Game.difficulty == "normal", "unknown difficulty falls back to normal")
	h._check(not Game.onehp_unlocked, "wrong-typed onehp lock stays locked")
	h._check(Game.bestiary.is_empty(), "wrong-typed bestiary falls back to empty")
	h._check(Game.best == 424242, "valid progress survives a corrupt neighbor section")
	h._check(not bool(Game.import_save_string("!!!not-base64!!!")), "non-base64 transfer is rejected")
	var non_dict_run := {"format": "kernel-panic-save", "version": 1, "run": "oops", "weekly": {}}
	h._check(not bool(Game.import_save_string(Marshalls.raw_to_base64(JSON.stringify(non_dict_run).to_utf8_buffer()))), "non-dict run section is rejected")
	var nested_bad := {"format": "kernel-panic-save", "version": 1, "run": {"best_classic": "lots", "onehp_unlocked": "maybe", "program": "daemon"}, "weekly": {"best": "many"}, "story": {"cleared": "yes", "best": {"boot": "fast"}}, "bestiary": "all", "achievements": {"first_blood": "yep"}}
	h._check(bool(Game.import_save_string(Marshalls.raw_to_base64(JSON.stringify(nested_bad).to_utf8_buffer()))), "nested wrong types sanitize instead of failing")
	var cf := ConfigFile.new()
	cf.load(path)
	h._check(int(cf.get_value("run", "best_classic", -1)) == 0 and int(cf.get_value("weekly", "best", -1)) == 0, "nested wrong numbers sanitize to zero")
	h._check(not Game.achievements.has("first_blood"), "stringly achievement flags are dropped")
	if had_file:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(backup)
		f.close()
	elif FileAccess.file_exists(path):
		dir.remove("kernel_panic.cfg")
	Game.mode = saved_mode
	Game.difficulty = saved_diff
	Game.onehp_unlocked = saved_onehp
	Game._load_run_config()

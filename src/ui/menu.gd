extends Control

const TacticalUIHelper = preload("res://src/ui/tactical_ui.gd")
const TacticalChromeScript = preload("res://src/ui/tactical_chrome.gd")
const TacticalIconScript = preload("res://src/ui/tactical_icon.gd")
const MenuSettingsKitScript = preload("res://src/ui/menu_settings_kit.gd")
const MenuChromeKitScript = preload("res://src/ui/menu_chrome_kit.gd")

## Shell novo. O antigo continua na árvore, escondido — ver _ready.
var _shell: MenuShell
var _prompt: Label
var _best_label: Label
var _t := 0.0
var _glitch_t := 0.0
var _starting := false
var _drifters: Array = []
var _settings_panel: Control
var _purge_btn: Button
var _mode_btn: Button
var _diff_btn: Button
var _mode_info: Label
var _klog: Label
var _subtitle: Label
var _controls_line: RichTextLabel
var _menu_frames: Array[Control] = []
var _footer_row: Control
var _klog_t := 0.0
var _esc_armed := 0.0
var _bestiary_panel: BestiaryPanel
var _ach_panel: Control
var _program_panel: ProgramPanel
var _story_panel: StoryPanel
var _program_btn: Button
var _story_btn: Button
var _aim_btn_ref: Button
var _color_assist_btn: Button
var _language_btn: Button
var _boot: BootOverlay
var _keybind_box: VBoxContainer
var _keybind_status: Label
var _keybind_buttons: Dictionary = {}
var _capture_action := ""
var _save_transfer_field: LineEdit
var _save_transfer_status: Label
var _settings_frame: Panel
var _settings_scroll: ScrollContainer
var _settings_box: VBoxContainer
var _settings_title: Label
var _settings_workstation_chrome: Control
var _settings_navigation_chrome: Control
var _settings_footer_row: HBoxContainer
var _settings_nav_buttons: Array[Button] = []
var _settings_chip_buttons: Array[Button] = []
var _settings_chips_row: HBoxContainer
var _settings_nav_hint: Label
var _settings_keybind_grid: GridContainer
var _settings_kit
var _chrome_kit

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if _settings_panel != null and is_instance_valid(_settings_panel):
			_settings_kit._layout_settings.call_deferred()
		if _chrome_kit != null:
			pass

func _on_window_size_changed() -> void:
	if _settings_panel != null and is_instance_valid(_settings_panel):
		_settings_kit._layout_settings.call_deferred()

func _desktop_keybinds_enabled() -> bool:
	return Balance.is_desktop_display() and not DisplayServer.is_touchscreen_available() and OS.get_environment("KP_FORCE_TOUCH") == ""

func keybind_capture_visible() -> bool:
	return _keybind_box != null and _keybind_box.visible

func settings_layout_for_viewport(viewport: Vector2) -> Dictionary:
	return _settings_kit.settings_layout_for_viewport(viewport)

func settings_section_snapshot() -> Dictionary:
	return _settings_kit.settings_section_snapshot()

func menu_layout_for_viewport(viewport: Vector2) -> Dictionary:
	return _chrome_kit.menu_layout_for_viewport(viewport)

func footer_button_layout_for_viewport(viewport_size: Vector2) -> Dictionary:
	return _chrome_kit.footer_button_layout_for_viewport(viewport_size)

func _style_settings_footer_button(button: Button, border: Color) -> void:
	_chrome_kit._style_settings_footer_button(button, border)

func _add_button_icon(button: Button, kind: String, accent: Color, icon_size: float = 52.0) -> void:
	_chrome_kit._add_button_icon(button, kind, accent, icon_size)

func _add_button_chrome(button: Button, accent: Color, alpha: float = 0.02) -> void:
	_chrome_kit._add_button_chrome(button, accent, alpha)

func _settings_nav_style(border: Color) -> StyleBoxFlat:
	return _chrome_kit._settings_nav_style(border)

func _open_settings() -> void:
	_settings_kit._open_settings()

func _close_settings() -> void:
	_settings_kit._close_settings()
	# Devolve o foco ao menu: fechar overlay sem dono de foco deixava a
	# navegação por teclado órfã. Diferido um frame — o grab imediato cai no
	# vazio quando a visibilidade ainda está assentando.
	if _shell != null and _shell.has_method("focus_primary"):
		_shell.call_deferred("focus_primary")

## Troca de idioma com refresh imediato: persiste, invalida painéis lazy
## (nascem no idioma novo na próxima abertura) e reconstrói shell+settings.
func _apply_language(code: String) -> void:
	var section := "AUDIO"
	if _settings_kit != null:
		section = _settings_kit.active_section()
	Game.set_language(code)
	_invalidate_lazy_panels()
	refresh_shell()
	if _settings_kit != null:
		_settings_kit.rebuild_settings()
		_settings_kit.set_active_section(section)
		_settings_kit.focus_language_control()

func _invalidate_lazy_panels() -> void:
	for key in ["_program_panel", "_story_panel", "_bestiary_panel", "_ach_panel"]:
		var panel: Control = get(key)
		if panel != null and is_instance_valid(panel):
			panel.queue_free()
		set(key, null)

func _handle_keybind_capture(event: InputEventKey) -> bool:
	return _settings_kit._handle_keybind_capture(event)

func _begin_keybind_capture(action: String) -> void:
	_settings_kit._begin_keybind_capture(action)

func _refresh_color_assist_label() -> void:
	_settings_kit._refresh_color_assist_label()

func _refresh_aim_label(btn: Button) -> void:
	btn.text = tr("MENU_AIM") % Game.effective_aim_mode().to_upper()

func _ready() -> void:
	_settings_kit = MenuSettingsKitScript.new(self)
	_chrome_kit = MenuChromeKitScript.new(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Window resizes that keep the logical canvas size (uniform scale changes)
	# never reach NOTIFICATION_RESIZED, so track the window signal too.
	get_window().size_changed.connect(_on_window_size_changed)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 5:
		_drifters.append({
			"pos": Vector2(randf_range(60, 1220), randf_range(80, 640)),
			"vel": Vector2.from_angle(randf() * TAU) * randf_range(9.0, 22.0),
			"rot": randf() * TAU,
			"rot_spd": randf_range(-0.5, 0.5),
			"kind": i % 3,
			"scale": randf_range(14.0, 26.0),
			"col": [Balance.COL_DRONE, Balance.COL_SPEWER, Balance.COL_LANCER][i % 3]
		})
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -2
	bg.modulate = Color(0.72, 0.82, 0.96, 0.48)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/bg_grid.gdshader")
	mat.set_shader_parameter("corruption_col", Balance.BG_CORRUPTION_COL)
	mat.set_shader_parameter("corruption_mix", Balance.BG_CORRUPTION_MIX)
	mat.set_shader_parameter("corruption_coverage", Balance.BG_CORRUPTION_COVERAGE)
	mat.set_shader_parameter("subgrid_weight", Balance.BG_SUBGRID_WEIGHT)
	mat.set_shader_parameter("era_gain_grid", Balance.ERA_TINT_GAIN_GRID)
	mat.set_shader_parameter("era_gain_glow", Balance.ERA_TINT_GAIN_GLOW)
	bg.material = mat
	add_child(bg)
	var dust := CPUParticles2D.new()
	dust.amount = 24
	dust.z_index = -1
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(700, 420)
	dust.gravity = Vector2(0, -14)
	dust.initial_velocity_min = 4.0
	dust.initial_velocity_max = 14.0
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 2.2
	dust.color = Color(1.0, 0.85, 0.35, 0.14)
	add_child(dust)
	# O shell antigo (pilha centralizada posicionada por retângulo absoluto em
	# MenuChromeKit.apply_menu_layout) continua sendo construído porque muita
	# lógica de refresh ainda referencia seus widgets — mas fica ESCONDIDO: quem
	# desenha é o MenuShell. Remover menu_chrome_kit é o passo seguinte.
	var legacy_first := get_child_count()
	var chrome: Control = TacticalChromeScript.new()
	chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome.call("configure_shell", TacticalUIHelper.CYAN, 0.0)
	add_child(chrome)
	var mono: Font = load("res://assets/fonts/ShareTechMono.ttf")
	var orbitron: Font = load("res://assets/fonts/Orbitron.ttf")
	var sub := Label.new()
	sub.text = "// last process standing"
	sub.add_theme_font_override("font", mono)
	sub.add_theme_font_size_override("font_size", 17)
	sub.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.65))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.anchor_left = 0.0
	sub.anchor_right = 1.0
	sub.offset_top = 220.0
	sub.offset_bottom = 250.0
	add_child(sub)
	_subtitle = sub
	_prompt = Label.new()
	_prompt.text = "PRESS [ENTER] OR HIT >> PURGE"
	_prompt.add_theme_font_override("font", mono)
	_prompt.add_theme_font_size_override("font_size", 19)
	_prompt.add_theme_color_override("font_color", Balance.COL_PLAYER)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.anchor_left = 0.0
	_prompt.anchor_right = 1.0
	_prompt.offset_top = 422.0
	_prompt.offset_bottom = 452.0
	if DisplayServer.is_touchscreen_available():
		_prompt.text = "[TAP] TO PURGE"
	_prompt.visible = false
	add_child(_prompt)
	var controls := RichTextLabel.new()
	controls.bbcode_enabled = true
	controls.fit_content = true
	controls.scroll_active = false
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls.text = "[center][color=#4ff2ff][WASD][/color] MOVE   [color=#4ff2ff][MOUSE][/color] AIM + FIRE   [color=#4ff2ff][SHIFT][/color] DASH   [color=#4ff2ff][E][/color] OVERCLOCK[/center]"
	controls.add_theme_font_override("normal_font", mono)
	controls.add_theme_font_size_override("normal_font_size", 12)
	controls.add_theme_color_override("default_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.6))
	controls.anchor_left = 0.0
	controls.anchor_right = 1.0
	controls.anchor_top = 0.5
	controls.anchor_bottom = 0.5
	controls.offset_top = 193.0
	controls.offset_bottom = 219.0
	add_child(controls)
	_controls_line = controls
	_best_label = Label.new()
	_best_label.add_theme_font_override("font", mono)
	_best_label.add_theme_font_size_override("font_size", 14)
	_best_label.add_theme_color_override("font_color", Color(Balance.COL_MOTE.r, Balance.COL_MOTE.g, Balance.COL_MOTE.b, 0.8))
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_best_label.anchor_left = 0.0
	_best_label.anchor_right = 1.0
	_best_label.offset_top = 265.0
	_best_label.offset_bottom = 289.0
	add_child(_best_label)
	var tag := Label.new()
	tag.text = tr("MENU_TAGLINE") % ProjectSettings.get_setting("application/config/version", "dev")
	tag.add_theme_font_override("font", mono)
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.3))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.anchor_left = 1.0
	tag.anchor_right = 1.0
	tag.offset_left = -500.0
	tag.offset_right = -16.0
	# Keep the build stamp out of Android's gesture/navigation inset.
	tag.offset_top = 96.0
	tag.offset_bottom = 116.0
	add_child(tag)
	var overlay_layer := CanvasLayer.new()
	overlay_layer.layer = 80
	var ov := ColorRect.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ov_mat := ShaderMaterial.new()
	ov_mat.shader = load("res://shaders/overlay.gdshader")
	ov.material = ov_mat
	overlay_layer.add_child(ov)
	add_child(overlay_layer)
	_update_best()
	Sfx.play_music()
	# A fileira de botões antiga NÃO é mais construída. Ela era montada aqui e
	# escondida logo abaixo, no laço de `legacy_first` — 161 linhas de widget
	# que nascia invisível. Quem desenha o menu é `MenuShell`.
	_settings_kit._build_settings()
	_klog = Label.new()
	_klog.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	_klog.add_theme_font_size_override("font_size", 11)
	_klog.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.22))
	_klog.anchor_top = 0.0
	_klog.anchor_bottom = 0.0
	_klog.anchor_left = 0.0
	_klog.offset_left = 16.0
	_klog.offset_right = 620.0
	_klog.offset_top = 120.0
	_klog.offset_bottom = 190.0
	_klog.text = "[    0.000000] kernel panic daemon online"
	add_child(_klog)
	# `apply_menu_layout()` só posicionava aqueles widgets.
	for legacy_index in range(legacy_first, get_child_count()):
		var legacy_node := get_child(legacy_index)
		if legacy_node is CanvasItem:
			(legacy_node as CanvasItem).visible = false
		if legacy_node is Control:
			(legacy_node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_shell()
	if not DevHarness.active and DisplayServer.get_name() != "headless":
		_boot = BootOverlay.new()
		var bl := CanvasLayer.new()
		bl.layer = 95
		bl.add_child(_boot)
		add_child(bl)

func _refresh_program_label() -> void:
	if _program_btn != null:
		_program_btn.text = tr("MENU_PROGRAM") % Game.program_def()["name"]

func _open_program_selector() -> void:
	if _program_panel == null:
		_program_panel = ProgramPanel.new()
		# `set_anchors_preset` deixa os offsets como estavam; sob um CanvasLayer
		# isso dá tamanho zero e a tela inteira colapsa.
		_program_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_program_panel.selection_changed.connect(func(_id: String) -> void:
			_refresh_program_label()
		)
		_program_panel.back_pressed.connect(_close_program_selector)
		# O rodapé anterior desenhava ">> BOOT KERNEL [ENTER]" e não fazia nada:
		# era rótulo sem ação. Agora ele faz o que diz.
		_program_panel.boot_pressed.connect(func() -> void:
			_close_program_selector()
			_start()
		)
		var layer := CanvasLayer.new()
		layer.layer = 70
		layer.add_child(_program_panel)
		add_child(layer)
	ScreenKit.open_focus(_program_panel)
	_program_panel.visible = true
	_program_panel.scroll_y = 0.0
	Sfx.play("ui", 1.1, -8.0)

func _close_program_selector() -> void:
	_program_panel.visible = false
	ScreenKit.close_focus(_program_panel)
	Sfx.play("ui", 0.9, -8.0)

func _open_story_selector() -> void:
	if _story_panel == null:
		var story_script: Script = load("res://src/ui/story_panel.gd")
		if story_script == null:
			return
		_story_panel = story_script.new()
		_story_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# `stage_selected` passou a significar DESTACAR, não entrar. Antes ele
		# ia direto em `_start_story`, então clicar num card já iniciava a fase
		# e o painel de detalhe — a metade direita da tela — nunca era lido.
		_story_panel.stage_mounted.connect(_start_story)
		_story_panel.back_pressed.connect(_close_story_selector)
		var layer := CanvasLayer.new()
		layer.layer = 70
		layer.process_mode = Node.PROCESS_MODE_ALWAYS
		layer.add_child(_story_panel)
		add_child(layer)
	ScreenKit.open_focus(_story_panel)
	_story_panel.visible = true
	_story_panel.scroll_y = 0.0
	Sfx.play("ui", 1.1, -8.0)

func _close_story_selector() -> void:
	if _story_panel != null:
		_story_panel.visible = false
		ScreenKit.close_focus(_story_panel)
	Sfx.play("ui", 0.9, -8.0)

func _start_story(index: int) -> void:
	if _starting or not Game.story_stage_unlocked(index):
		return
	_starting = true
	Sfx.play("ui", 1.2, -4.0)
	Fx.flash(Balance.COL_PLAYER, 0.18, 0.4)
	Game.start_story(index)

func _open_bestiary() -> void:
	if _bestiary_panel == null:
		_bestiary_panel = BestiaryPanel.new()
		_bestiary_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		_bestiary_panel.back_pressed.connect(_close_bestiary)
		var layer := CanvasLayer.new()
		layer.layer = 70
		layer.process_mode = Node.PROCESS_MODE_ALWAYS
		layer.add_child(_bestiary_panel)
		add_child(layer)
	ScreenKit.open_focus(_bestiary_panel)
	_bestiary_panel.visible = true
	_bestiary_panel.refresh(true)
	Sfx.play("ui", 1.1, -8.0)

func _close_bestiary() -> void:
	_bestiary_panel.visible = false
	ScreenKit.close_focus(_bestiary_panel)
	Sfx.play("ui", 0.9, -8.0)

func _open_achievements() -> void:
	if _ach_panel == null:
		var panel_script: Script = load("res://src/ui/achievements_panel.gd")
		if panel_script == null:
			return
		_ach_panel = panel_script.new()
		_ach_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if _ach_panel.has_signal("back_pressed"):
			_ach_panel.connect("back_pressed", _close_achievements)
		var layer := CanvasLayer.new()
		layer.layer = 70
		layer.add_child(_ach_panel)
		add_child(layer)
	ScreenKit.open_focus(_ach_panel)
	_ach_panel.visible = true
	if _ach_panel.has_method("refresh"):
		_ach_panel.call("refresh")
	Sfx.play("ui", 1.1, -8.0)

func _close_achievements() -> void:
	if _ach_panel != null:
		_ach_panel.visible = false
		ScreenKit.close_focus(_ach_panel)
	Sfx.play("ui", 0.9, -8.0)

## Constrói o shell novo e liga seus sinais aos fluxos que já existiam.
func _build_shell() -> void:
	_shell = MenuShell.new()
	_shell.purge_pressed.connect(_start)
	_shell.story_pressed.connect(_open_story_selector)
	_shell.archives_pressed.connect(_open_bestiary)
	_shell.configure_pressed.connect(_open_program_selector)
	_shell.mode_cycled.connect(_cycle_mode)
	_shell.difficulty_cycled.connect(_cycle_difficulty)
	_shell.settings_pressed.connect(_open_settings)
	_shell.awards_pressed.connect(_open_achievements)
	_shell.quit_pressed.connect(func() -> void: get_tree().quit())
	var layer := CanvasLayer.new()
	layer.layer = 5
	layer.add_child(_shell)
	add_child(layer)
	_shell.set_version("v%s" % ProjectSettings.get_setting("application/config/version", "2.5.0"))
	refresh_shell()


## Reflete o estado corrente (modo, dificuldade, recorde, programa) no shell.
func refresh_shell() -> void:
	if not is_instance_valid(_shell):
		return
	# Tipo explícito: Dictionary.get() devolve Variant e o projeto trata
	# inferência a partir de Variant como erro.
	var mode_keys := {
		"classic": "MODE_CLASSIC", "weekly": "MODE_WEEKLY",
		"onehp": "MODE_ONEHP", "story": "MODE_STORY",
	}
	var mode_key: String = str(mode_keys.get(Game.mode, "MODE_CLASSIC"))
	var mode_text := tr(mode_key)
	if Game.mode in ["classic", "weekly", "onehp"]:
		mode_text += "  /  " + tr("DIFF_%s" % Game.difficulty.to_upper())
	var best := Game.best_for_mode()
	var best_text := "%s %07d" % [tr("MENU_BEST"), best] if best > 0 else tr("MENU_NO_RECORD")
	_shell.set_run_config(mode_text, best_text, str(Game.program_def()["name"]))
	var cycle_modes := {"classic": "MENU_MODE_CLASSIC", "weekly": "MENU_MODE_WEEKLY", "onehp": "MENU_MODE_ONEHP", "story": "MENU_MODE_STORY"}
	var cycle_mode_text := tr(str(cycle_modes.get(Game.mode, "MENU_MODE_CLASSIC")))
	var cycle_diff_text := tr("MENU_DIFFICULTY_FIXED") if Game.mode == "story" else tr("MENU_DIFFICULTY") % Game.difficulty.to_upper()
	_shell.set_cycle_labels(cycle_mode_text, cycle_diff_text)
	_shell.set_hero(str(Game.program), Balance.COL_PLAYER)


func main_shell_snapshot() -> Dictionary:
	var shell_sections := TacticalUIHelper.shell_sections(size)
	if is_instance_valid(_shell):
		var live := _shell.shell_snapshot()
		live["shell_rect"] = TacticalUIHelper.shell_rect(size)
		live["footer_rect"] = shell_sections["footer"]
		return live
	return {
		"title": "KERNEL PANIC",
		"primary_action": _purge_btn.text if _purge_btn != null else ">> PURGE",
		"mode_explanation": _mode_info.text if _mode_info != null else "",
		"routes": ["PROGRAM", "STORY", "BESTIARY"],
		"shell_rect": TacticalUIHelper.shell_rect(size),
		"footer_rect": shell_sections["footer"],
		"score_rect": _best_label.get_global_rect() if _best_label != null else Rect2(),
		"primary_rect": _purge_btn.get_global_rect() if _purge_btn != null else Rect2(),
	}

func settings_shell_snapshot() -> Dictionary:
	var shell := TacticalUIHelper.shell_rect(size)
	var sections := TacticalUIHelper.shell_sections(size)
	var settings_layout: Dictionary = _settings_kit.settings_layout_for_viewport(size)
	return {
		"groups": ["AUDIO", "GAMEPLAY", "CONTROLS", "ACCESSIBILITY", "SAVE DATA"],
		"scrollable": _settings_panel != null and _settings_panel.find_child("SettingsScroll", true, false) != null,
		"shell_rect": shell,
		"navigation_rect": settings_layout["navigation"],
		"content_rect": settings_layout["content"],
		"footer_rect": sections["footer"],
		"title_rect": settings_layout["title"],
	}

func _cycle_mode() -> void:
	var order := ["classic", "weekly", "onehp"]
	var idx := order.find(Game.mode)
	for step in 3:
		idx = (idx + 1) % 3
		if order[idx] != "onehp" or Game.onehp_unlocked:
			Game.mode = order[idx]
			break
	Sfx.play("ui", 1.1, -8.0)
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	cf.set_value("game", "mode", Game.mode)
	cf.save(Sfx.SAVE_PATH)
	_refresh_mode_ui()
	refresh_shell()
	if _aim_btn_ref != null:
		_refresh_aim_label(_aim_btn_ref)

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
	refresh_shell()

func _refresh_difficulty_label() -> void:
	if _diff_btn == null:
		return
	if Game.mode == "story":
		_diff_btn.text = tr("MENU_DIFFICULTY_FIXED")
	else:
		_diff_btn.text = tr("MENU_DIFFICULTY") % Game.difficulty.to_upper()

func _refresh_mode_ui() -> void:
	# A UI legacy não é mais construída; só o shell novo reflete estado.
	# Sem este guard, ciclar modo logava SCRIPT ERROR em _mode_btn nulo.
	if _mode_btn == null or _mode_info == null:
		_update_best()
		return
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	match Game.mode:
		"story":
			_mode_btn.text = tr("MENU_MODE_STORY")
			var story_path: String = str(Game.story_stage_def(Game.story_stage_index).get("path", "/boot"))
			_mode_info.text = tr("MENU_STORY_PROGRESS") % [story_path, Game.story_cleared.size(), Game.story_stage_count()]
		"weekly":
			_mode_btn.text = tr("MENU_MODE_WEEKLY")
			var cur := int(cf.get_value("weekly", "best", 0)) if cf.get_value("weekly", "id", "") == Game.week_id() else 0
			var last := int(cf.get_value("weekly", "last_best", 0))
			_mode_info.text = tr("MENU_WEEKLY_INFO") % [Game.week_id(), cur, last]
		"onehp":
			_mode_btn.text = tr("MENU_MODE_ONEHP")
			_mode_info.text = "1 INTEGRITY // SCORE x3 // BEST %d" % int(cf.get_value("run", "best_onehp", 0))
		_:
			_mode_btn.text = tr("MENU_MODE_CLASSIC")
			_mode_info.text = tr("MENU_CLASSIC_INFO") % Game.best
	if Game.mode == "story":
		_mode_info.text = tr("MENU_STORY_INFO") + _mode_info.text
	_update_best()
	_refresh_difficulty_label()

func _set_main_menu_controls_visible(visible: bool) -> void:
	for child in get_children():
		if child == _settings_panel:
			continue
		if child is Control and not child is ColorRect:
			child.visible = visible

func _export_save_to_clipboard() -> void:
	if _save_transfer_field == null or not is_instance_valid(_save_transfer_field):
		return
	var encoded := Game.export_save_string()
	_save_transfer_field.text = encoded
	DisplayServer.clipboard_set(encoded)
	_save_transfer_status.text = tr("MENU_SAVE_EXPORTED")

func _import_save_from_clipboard() -> void:
	if _save_transfer_field == null or not is_instance_valid(_save_transfer_field):
		return
	var encoded := _save_transfer_field.text.strip_edges()
	if encoded.is_empty():
		encoded = DisplayServer.clipboard_get().strip_edges()
	if Game.import_save_string(encoded):
		_save_transfer_field.text = encoded
		_save_transfer_status.text = tr("MENU_SAVE_IMPORTED")
		_refresh_mode_ui()
		_refresh_program_label()
	else:
		_save_transfer_status.text = tr("MENU_SAVE_REJECTED")

func _reset_scores() -> void:
	Game.best = 0
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	cf.set_value("run", "best", 0)
	cf.set_value("run", "best_classic", 0)
	cf.save(Sfx.SAVE_PATH)

static func _touch_scale_idx(v: float) -> int:
	return clampi(int(round((v - 0.85) / 0.175)), 0, 2)

static func _next_touch_scale_idx(v: float) -> int:
	return (_touch_scale_idx(v) + 1) % 3

func _update_best() -> void:
	if _best_label == null:
		return
	var b := Game.best_for_mode()
	_best_label.text = (tr("MENU_HIGH_SCORE") % b) if b > 0 else "NO RECORD YET"

const KLOG_POOL := [
	"daemon[666]: segfault at 0 ip 0xdeadbeef sp 0xffffd0 error 6",
	"systemd[1]: purge.service entered RUNNING state",
	"oom_killer: pressure high, harvesting loose motes",
	"root.exe: you have 1 unread virus",
	"mtrr: your free memory is a lie",
	"kswapd0: page steal successful lol",
	"watchdog: BUG: unable to handle kernel paging",
	"cron[424]: weekly defrag postponed forever",
]

func _process(delta: float) -> void:
	_t += delta
	if _esc_armed > 0.0:
		_esc_armed -= delta
		if _esc_armed <= 0.0 and not _starting:
			_prompt.text = "PRESS [ENTER] OR HIT >> PURGE" if not DisplayServer.is_touchscreen_available() else tr("MENU_HIT_PURGE")
			_prompt.add_theme_color_override("font_color", Balance.COL_PLAYER)
	_klog_t -= delta
	if _klog_t <= 0.0 and _klog != null:
		_klog_t = randf_range(2.2, 4.5)
		var lines := _klog.text.split("\n")
		var keep := lines.slice(maxi(lines.size() - 2, 0), lines.size())
		var ts := "%.6f" % (randf_range(1.0, 99.0))
		keep.append("[ %10s ] %s" % [ts, KLOG_POOL[randi() % KLOG_POOL.size()]])
		_klog.text = "\n".join(keep)
	_glitch_t -= delta
	_prompt.visible = false
	if _glitch_t <= 0.0:
		_glitch_t = randf_range(1.2, 3.4)
		var burst := randf_range(0.06, 0.16)
		set_meta("glitch_until", _t + burst)
		set_meta("glitch_off", Vector2(randf_range(-5, 5), randf_range(-3, 3)))
	var glitching: bool = _t < float(get_meta("glitch_until", 0.0))
	var off: Vector2 = get_meta("glitch_off", Vector2.ZERO) if glitching else Vector2.ZERO
	# O jitter de glitch movia os três Labels Orbitron escondidos. O título vivo
	# é do MenuShell; o efeito some com eles.
	for d in _drifters:
		d["pos"] += d["vel"] * delta
		d["rot"] += d["rot_spd"] * delta
		var p: Vector2 = d["pos"]
		if p.x < -40:
			d["pos"] = Vector2(1320, d["pos"].y)
		elif p.x > 1320:
			d["pos"] = Vector2(-40, d["pos"].y)
		if p.y < -40:
			d["pos"] = Vector2(d["pos"].x, 760)
		elif p.y > 760:
			d["pos"] = Vector2(d["pos"].x, -40)
	queue_redraw()

func _draw() -> void:
	if _chrome_kit == null:
		_chrome_kit = MenuChromeKitScript.new(self)
	_chrome_kit.draw_shell(self)

func _input(event: InputEvent) -> void:
	if _starting or not _capture_action.is_empty() or not event.is_action_pressed("pause"):
		return
	if _settings_panel != null and _settings_panel.visible:
		_settings_kit._close_settings()
		get_viewport().set_input_as_handled()
	elif _program_panel != null and _program_panel.visible:
		_close_program_selector()
		get_viewport().set_input_as_handled()
	elif _story_panel != null and _story_panel.visible:
		_close_story_selector()
		get_viewport().set_input_as_handled()
	elif _bestiary_panel != null and _bestiary_panel.visible:
		_close_bestiary()
		get_viewport().set_input_as_handled()
	elif _ach_panel != null and _ach_panel.visible:
		_close_achievements()
		get_viewport().set_input_as_handled()

func _start() -> void:
	if _starting:
		return
	_starting = true
	Sfx.play("ui", 1.2, -4.0)
	Fx.flash(Balance.COL_PLAYER, 0.18, 0.4)
	Game.start_run()

func _unhandled_input(event: InputEvent) -> void:
	if _starting:
		return
	if _settings_panel != null and _settings_panel.visible:
		if not _capture_action.is_empty():
			if not _desktop_keybinds_enabled():
				_capture_action = ""
				return
			if event is InputEventKey:
				_settings_kit._handle_keybind_capture(event)
				get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("pause"):
			_settings_kit._close_settings()
			get_viewport().set_input_as_handled()
		return
	if _program_panel != null and _program_panel.visible:
		if event.is_action_pressed("pause"):
			_close_program_selector()
			get_viewport().set_input_as_handled()
			return
	if _story_panel != null and _story_panel.visible:
		if event.is_action_pressed("pause"):
			_close_story_selector()
			get_viewport().set_input_as_handled()
		return
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
	if event.is_action_pressed("pause"):
		if _esc_armed > 0.0:
			get_tree().quit()
		else:
			_esc_armed = 2.0
			_prompt.text = tr("MENU_QUIT_CONFIRM")
			_prompt.add_theme_color_override("font_color", Balance.COL_DANGER)
			Sfx.play("ui", 0.8, -8.0)
		get_viewport().set_input_as_handled()
		return
	# BaseButton aciona no release, mas o press ainda pode chegar aqui.
	# O atalho global só serve quando não há um controle tratando o teclado.
	if event.is_action_pressed("confirm") and get_viewport().gui_get_focus_owner() == null:
		_start()

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

extends Control

const TacticalUIHelper = preload("res://src/ui/tactical_ui.gd")
const TacticalChromeScript = preload("res://src/ui/tactical_chrome.gd")
const TacticalIconScript = preload("res://src/ui/tactical_icon.gd")

var _title: Label
var _title_r: Label
var _title_b: Label
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
var _settings_keybind_grid: GridContainer

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _settings_panel != null and is_instance_valid(_settings_panel):
		call_deferred("_layout_settings")

func _desktop_keybinds_enabled() -> bool:
	return Balance.is_desktop_display() and not DisplayServer.is_touchscreen_available() and OS.get_environment("KP_FORCE_TOUCH") == ""

func keybind_capture_visible() -> bool:
	return _keybind_box != null and _keybind_box.visible

func _refresh_aim_label(btn: Button) -> void:
	btn.text = "AIM MODE: %s" % Game.effective_aim_mode().to_upper()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
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
	var chrome: Control = TacticalChromeScript.new()
	chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome.call("configure_shell", TacticalUIHelper.CYAN, 0.0)
	add_child(chrome)
	var mono: Font = load("res://assets/fonts/ShareTechMono.ttf")
	var orbitron: Font = load("res://assets/fonts/Orbitron.ttf")
	_title_r = _mk_title(orbitron, Color(1, 0.1, 0.3, 0.5))
	_title_b = _mk_title(orbitron, Color(0.1, 0.9, 1.0, 0.5))
	_title = _mk_title(orbitron, Balance.COL_TEXT)
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
	tag.text = "KERNEL PANIC v%s // purge loop online" % ProjectSettings.get_setting("application/config/version", "dev")
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
	_build_button_row()
	_build_settings()
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
	if not DevHarness.active and DisplayServer.get_name() != "headless":
		_boot = BootOverlay.new()
		var bl := CanvasLayer.new()
		bl.layer = 95
		bl.add_child(_boot)
		add_child(bl)

func _style_card_button(b: Button, border: Color, button_size := Vector2(270, 84)) -> void:
	b.custom_minimum_size = button_size
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(border.r, border.g, border.b, 0.0)
	sb.border_color = Color(border.r, border.g, border.b, 0.0)
	sb.set_border_width_all(0)
	sb.set_corner_radius_all(0)
	b.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	sbh.bg_color = Color(border.r, border.g, border.b, 0.08)
	sbh.border_color = Color(border.r, border.g, border.b, 0.0)
	sbh.set_border_width_all(0)
	b.add_theme_stylebox_override("hover", sbh)
	var sbp := sb.duplicate()
	sbp.bg_color = Color(border.r, border.g, border.b, 0.16)
	sbp.border_color = Color(border.r, border.g, border.b, 0.0)
	sbp.set_border_width_all(0)
	b.add_theme_stylebox_override("pressed", sbp)
	b.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Balance.COL_TEXT)
	b.add_theme_color_override("font_hover_color", Balance.COL_PLAYER_HOT)
	b.add_theme_color_override("font_pressed_color", Balance.COL_PLAYER_HOT)
	b.z_index = 2
	b.pivot_offset = button_size * 0.5
	b.button_down.connect(func() -> void:
		b.scale = Vector2(0.96, 0.96)
		Sfx.play("ui", 1.0, -10.0)
	)
	b.button_up.connect(func() -> void:
		b.scale = Vector2.ONE
	)

func _add_menu_frame(rect: Rect2, accent: Color, alpha: float = 0.025) -> Control:
	var frame: Control = TacticalChromeScript.new()
	frame.set_anchors_preset(Control.PRESET_TOP_LEFT)
	frame.position = rect.position
	frame.size = rect.size
	frame.z_index = 1
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.call("configure_panel", Rect2(Vector2.ZERO, rect.size), accent, alpha)
	add_child(frame)
	return frame

func _set_button_text_inset(button: Button, inset: float) -> void:
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for state in ["normal", "hover", "pressed"]:
		var base: StyleBox = button.get_theme_stylebox(state)
		if base == null:
			continue
		var adjusted: StyleBox = base.duplicate()
		adjusted.content_margin_left = inset
		button.add_theme_stylebox_override(state, adjusted)

func _settings_nav_style(border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(border.r, border.g, border.b, 0.0 if border.a < 0.5 else 0.055)
	style.border_color = Color(border.r, border.g, border.b, 0.0)
	style.set_border_width_all(0)
	style.content_margin_left = 8.0
	return style

func _add_button_chrome(button: Button, accent: Color, alpha: float = 0.02) -> void:
	var frame: Control = TacticalChromeScript.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.z_index = 1
	button.add_child(frame)
	frame.call("configure_control", accent, alpha)
	button.z_index = 2

func _add_button_icon(button: Button, kind: String, accent: Color, icon_size: float = 52.0) -> void:
	var icon: Control = TacticalIconScript.new()
	icon.position = Vector2(10.0, (button.custom_minimum_size.y - icon_size) * 0.5)
	icon.size = Vector2(icon_size, icon_size)
	icon.z_index = 2
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	icon.call("configure", kind, accent)

func _style_settings_footer_button(button: Button, border: Color) -> void:
	button.flat = false
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", border if border != TacticalUIHelper.CYAN else TacticalUIHelper.TEXT)
	button.add_theme_color_override("font_hover_color", TacticalUIHelper.TEXT)
	button.add_theme_stylebox_override("normal", _settings_nav_style(Color(border.r, border.g, border.b, 0.55)))
	button.add_theme_stylebox_override("hover", _settings_nav_style(border))
	button.add_theme_stylebox_override("pressed", _settings_nav_style(border))
	_set_button_text_inset(button, 54.0)
	_add_button_chrome(button, border, 0.02)

func footer_button_layout_for_viewport(viewport_size: Vector2) -> Dictionary:
	var total_width := minf(448.0, maxf(viewport_size.x * 0.327, 280.0))
	var gap := 14.0
	return {
		"total_width": total_width,
		"gap": gap,
		"button_width": (total_width - gap) * 0.5,
	}

func _build_button_row() -> void:
	var purge_width := minf(430.0, maxf(size.x * 0.30, 280.0))
	_purge_btn = Button.new()
	_style_card_button(_purge_btn, Balance.COL_PLAYER, Vector2(purge_width, 88.0))
	_purge_btn.text = ">> PURGE"
	_purge_btn.add_theme_font_size_override("font_size", 30)
	_purge_btn.anchor_left = 0.5
	_purge_btn.anchor_right = 0.5
	_purge_btn.anchor_top = 0.5
	_purge_btn.anchor_bottom = 0.5
	_purge_btn.offset_left = -purge_width * 0.5
	_purge_btn.offset_right = purge_width * 0.5
	_purge_btn.offset_top = -52.0
	_purge_btn.offset_bottom = 36.0
	_purge_btn.pressed.connect(_start)
	add_child(_purge_btn)
	_add_menu_frame(Rect2(Vector2((size.x - purge_width) * 0.5, size.y * 0.5 - 52.0), Vector2(purge_width, 88.0)), Balance.COL_PLAYER, 0.035)
	_story_btn = Button.new()
	_style_card_button(_story_btn, Balance.COL_PLAYER, Vector2(minf(360.0, purge_width * 0.84), 58.0))
	_story_btn.text = "STORY // ACTS"
	_story_btn.add_theme_font_size_override("font_size", 19)
	_story_btn.anchor_left = 0.5
	_story_btn.anchor_right = 0.5
	_story_btn.anchor_top = 0.5
	_story_btn.anchor_bottom = 0.5
	var story_width := minf(360.0, purge_width * 0.84)
	_story_btn.offset_left = -story_width * 0.5
	_story_btn.offset_right = story_width * 0.5
	_story_btn.offset_top = 44.0
	_story_btn.offset_bottom = 102.0
	_story_btn.pressed.connect(_open_story_selector)
	add_child(_story_btn)
	_add_menu_frame(Rect2(Vector2((size.x - story_width) * 0.5, size.y * 0.5 + 44.0), Vector2(story_width, 58.0)), Balance.COL_PLAYER, 0.025)
	_mode_btn = Button.new()
	_style_card_button(_mode_btn, Balance.COL_MOTE, Vector2(minf(440.0, maxf(size.x * 0.42, 300.0)), 50.0))
	_mode_btn.text = "MODE: CLASSIC"
	_mode_btn.add_theme_font_size_override("font_size", 16)
	_mode_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_mode_btn.anchor_left = 0.5
	_mode_btn.anchor_right = 0.5
	_mode_btn.anchor_top = 0.5
	_mode_btn.anchor_bottom = 0.5
	var mode_width := minf(440.0, maxf(size.x * 0.42, 300.0))
	_mode_btn.offset_left = -mode_width * 0.5
	_mode_btn.offset_right = mode_width * 0.5
	_mode_btn.offset_top = 112.0
	_mode_btn.offset_bottom = 162.0
	_mode_btn.pressed.connect(_cycle_mode)
	add_child(_mode_btn)
	var mode_normal := _mode_btn.get_theme_stylebox("normal").duplicate()
	mode_normal.content_margin_left = 40.0
	_mode_btn.add_theme_stylebox_override("normal", mode_normal)
	var mode_hover := _mode_btn.get_theme_stylebox("hover").duplicate()
	mode_hover.content_margin_left = 40.0
	_mode_btn.add_theme_stylebox_override("hover", mode_hover)
	var mode_pressed := _mode_btn.get_theme_stylebox("pressed").duplicate()
	mode_pressed.content_margin_left = 40.0
	_mode_btn.add_theme_stylebox_override("pressed", mode_pressed)
	_add_menu_frame(Rect2(Vector2((size.x - mode_width) * 0.5, size.y * 0.5 + 112.0), Vector2(mode_width, 50.0)), Balance.COL_MOTE, 0.03)
	_program_btn = Button.new()
	_program_btn.flat = true
	_program_btn.z_index = 2
	_program_btn.focus_mode = Control.FOCUS_NONE
	_program_btn.anchor_left = 0.5
	_program_btn.anchor_right = 0.5
	_program_btn.anchor_top = 0.5
	_program_btn.anchor_bottom = 0.5
	_program_btn.offset_left = 42.0
	_program_btn.offset_right = 220.0
	_program_btn.offset_top = 112.0
	_program_btn.offset_bottom = 162.0
	_program_btn.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	_program_btn.add_theme_font_size_override("font_size", 15)
	_program_btn.add_theme_color_override("font_color", Color(0.6, 1.0, 0.8, 0.9))
	_program_btn.add_theme_color_override("font_hover_color", TacticalUIHelper.LIME)
	_program_btn.pressed.connect(_open_program_selector)
	add_child(_program_btn)
	_diff_btn = Button.new()
	_diff_btn.flat = true
	_diff_btn.z_index = 2
	_diff_btn.focus_mode = Control.FOCUS_NONE
	_diff_btn.anchor_left = 0.5
	_diff_btn.anchor_right = 0.5
	_diff_btn.anchor_top = 0.5
	_diff_btn.anchor_bottom = 0.5
	_diff_btn.offset_left = -110.0
	_diff_btn.offset_right = 110.0
	_diff_btn.offset_top = 166.0
	_diff_btn.offset_bottom = 192.0
	_diff_btn.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	_diff_btn.add_theme_font_size_override("font_size", 13)
	_diff_btn.add_theme_color_override("font_color", Color(0.6, 1.0, 0.8, 0.9))
	_diff_btn.add_theme_color_override("font_hover_color", TacticalUIHelper.LIME)
	_diff_btn.pressed.connect(_cycle_difficulty)
	add_child(_diff_btn)
	_refresh_difficulty_label()
	var footer_layout := footer_button_layout_for_viewport(size)
	var bottom_width: float = footer_layout["total_width"]
	var bottom_gap: float = footer_layout["gap"]
	var bottom_button_w: float = footer_layout["button_width"]
	var row := HBoxContainer.new()
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = -bottom_width * 0.5
	row.offset_right = bottom_width * 0.5
	row.offset_top = -95.0
	row.offset_bottom = -47.0
	row.add_theme_constant_override("separation", int(bottom_gap))
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)
	_refresh_program_label()
	var settings_btn := Button.new()
	_style_card_button(settings_btn, Balance.COL_TEXT, Vector2(bottom_button_w, 48.0))
	settings_btn.text = "SETTINGS"
	_set_button_text_inset(settings_btn, 92.0)
	_add_button_icon(settings_btn, "settings", Balance.COL_PLAYER, 52.0)
	settings_btn.z_index = 2
	settings_btn.pressed.connect(_open_settings)
	row.add_child(settings_btn)
	var best_btn := Button.new()
	_style_card_button(best_btn, Balance.COL_SPEWER, Vector2(bottom_button_w, 48.0))
	best_btn.text = "BESTIARY"
	_set_button_text_inset(best_btn, 92.0)
	_add_button_icon(best_btn, "bestiary", Balance.COL_SPEWER, 52.0)
	best_btn.z_index = 2
	best_btn.pressed.connect(_open_bestiary)
	row.add_child(best_btn)
	var ach_btn := Button.new()
	_style_card_button(ach_btn, TacticalUIHelper.LIME, Vector2(bottom_button_w, 48.0))
	ach_btn.text = "AWARDS"
	ach_btn.z_index = 2
	ach_btn.pressed.connect(_open_achievements)
	row.add_child(ach_btn)
	var bottom_y := size.y - 95.0
	var bottom_x := (size.x - bottom_width) * 0.5
	_add_menu_frame(Rect2(Vector2(bottom_x, bottom_y), Vector2(bottom_button_w, 48.0)), Balance.COL_TEXT, 0.015)
	_add_menu_frame(Rect2(Vector2(bottom_x + bottom_button_w + bottom_gap, bottom_y), Vector2(bottom_button_w, 48.0)), Balance.COL_SPEWER, 0.02)
	_add_menu_frame(Rect2(Vector2(bottom_x + (bottom_button_w + bottom_gap) * 2.0, bottom_y), Vector2(bottom_button_w, 48.0)), TacticalUIHelper.LIME, 0.02)
	_mode_info = Label.new()
	_mode_info.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	_mode_info.add_theme_font_size_override("font_size", 12)
	_mode_info.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.6))
	_mode_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_info.anchor_left = 0.0
	_mode_info.anchor_right = 0.0
	_mode_info.anchor_top = 0.5
	_mode_info.anchor_bottom = 0.5
	_mode_info.offset_left = 24.0
	_mode_info.offset_right = size.x - 24.0
	_mode_info.offset_top = 190.0
	_mode_info.offset_bottom = 234.0
	_mode_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mode_info.visible = false
	add_child(_mode_info)
	_refresh_mode_ui()

func _refresh_program_label() -> void:
	if _program_btn != null:
		_program_btn.text = "PROGRAM: %s" % Game.program_def()["name"]

func _open_program_selector() -> void:
	if _program_panel == null:
		_program_panel = ProgramPanel.new()
		_program_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		_program_panel.selection_changed.connect(func(_id: String) -> void:
			_refresh_program_label()
		)
		var title := Label.new()
		title.text = "SELECT PROGRAM"
		title.add_theme_font_override("font", load("res://assets/fonts/Orbitron.ttf"))
		title.add_theme_font_size_override("font_size", 28)
		title.add_theme_color_override("font_color", Balance.COL_TEXT)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.anchor_left = 0.0
		title.anchor_right = 1.0
		title.offset_top = 60.0
		title.offset_bottom = 110.0
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_program_panel.add_child(title)
		var hint := Label.new()
		hint.text = "Choose the process that survives the purge."
		hint.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
		hint.add_theme_font_size_override("font_size", 13)
		hint.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.5))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.anchor_left = 0.0
		hint.anchor_right = 1.0
		hint.offset_top = 112.0
		hint.offset_bottom = 136.0
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_program_panel.add_child(hint)
		var back := Button.new()
		_style_overlay_back(back)
		back.pressed.connect(_close_program_selector)
		_program_panel.add_child(back)
		var layer := CanvasLayer.new()
		layer.layer = 70
		layer.add_child(_program_panel)
		add_child(layer)
	_program_panel.visible = true
	_program_panel.scroll_y = 0.0
	_program_panel.queue_redraw()
	Sfx.play("ui", 1.1, -8.0)

func _close_program_selector() -> void:
	_program_panel.visible = false
	Sfx.play("ui", 0.9, -8.0)

func _open_story_selector() -> void:
	if _story_panel == null:
		var story_script: Script = load("res://src/ui/story_panel.gd")
		if story_script == null:
			return
		_story_panel = story_script.new()
		_story_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		_story_panel.stage_selected.connect(_start_story)
		var title := Label.new()
		title.text = "SELECT MOUNT POINT"
		title.add_theme_font_override("font", load("res://assets/fonts/Orbitron.ttf"))
		title.add_theme_font_size_override("font_size", 28)
		title.add_theme_color_override("font_color", Balance.COL_TEXT)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.anchor_left = 0.0
		title.anchor_right = 1.0
		title.offset_top = 60.0
		title.offset_bottom = 110.0
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_story_panel.add_child(title)
		var hint := Label.new()
		hint.text = "Trace the infection across three operating systems."
		hint.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
		hint.add_theme_font_size_override("font_size", 13)
		hint.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.5))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.anchor_left = 0.0
		hint.anchor_right = 1.0
		hint.offset_top = 112.0
		hint.offset_bottom = 136.0
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_story_panel.add_child(hint)
		var back := Button.new()
		_style_overlay_back(back)
		back.pressed.connect(_close_story_selector)
		_story_panel.add_child(back)
		var layer := CanvasLayer.new()
		layer.layer = 70
		layer.process_mode = Node.PROCESS_MODE_ALWAYS
		layer.add_child(_story_panel)
		add_child(layer)
	_story_panel.visible = true
	_story_panel.scroll_y = 0.0
	_story_panel.queue_redraw()
	Sfx.play("ui", 1.1, -8.0)

func _close_story_selector() -> void:
	if _story_panel != null:
		_story_panel.visible = false
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
		var title := Label.new()
		title.text = "BESTIARY // FIELD DATA"
		title.add_theme_font_override("font", load("res://assets/fonts/Orbitron.ttf"))
		title.add_theme_font_size_override("font_size", 28)
		title.add_theme_color_override("font_color", Balance.COL_TEXT)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.anchor_left = 0.0
		title.anchor_right = 1.0
		title.offset_top = 60.0
		title.offset_bottom = 110.0
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bestiary_panel.add_child(title)
		var hint := Label.new()
		hint.text = "%d / %d LOGGED  //  SELECT A PROCESS FOR FIELD DATA" % [Game.bestiary.size(), BestiaryPanel.ENTRIES.size()]
		hint.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
		hint.add_theme_font_size_override("font_size", 13)
		hint.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.5))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.anchor_left = 0.0
		hint.anchor_right = 1.0
		hint.offset_top = 112.0
		hint.offset_bottom = 136.0
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bestiary_panel.add_child(hint)
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
		back.pressed.connect(_close_bestiary)
		_bestiary_panel.add_child(back)
		var layer := CanvasLayer.new()
		layer.layer = 70
		layer.add_child(_bestiary_panel)
		add_child(layer)
	_bestiary_panel.visible = true
	_bestiary_panel.scroll_y = 0.0
	Sfx.play("ui", 1.1, -8.0)

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

func _style_overlay_back(back: Button) -> void:
	back.text = "BACK // ESC"
	back.custom_minimum_size = Vector2(154.0, 42.0)
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	back.add_theme_font_size_override("font_size", 13)
	back.add_theme_color_override("font_color", Balance.COL_PLAYER)
	back.add_theme_color_override("font_hover_color", Balance.COL_TEXT)
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.anchor_left = 1.0
	back.anchor_right = 1.0
	back.anchor_top = 0.0
	back.anchor_bottom = 0.0
	back.offset_left = -190.0
	back.offset_right = -36.0
	back.offset_top = 58.0
	back.offset_bottom = 100.0
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(Balance.COL_PLAYER.r, Balance.COL_PLAYER.g, Balance.COL_PLAYER.b, 0.0)
	normal.border_color = Color(Balance.COL_PLAYER.r, Balance.COL_PLAYER.g, Balance.COL_PLAYER.b, 0.0)
	normal.set_border_width_all(0)
	normal.content_margin_left = 42.0
	normal.content_margin_right = 8.0
	back.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(Balance.COL_PLAYER.r, Balance.COL_PLAYER.g, Balance.COL_PLAYER.b, 0.08)
	hover.border_color = Color(Balance.COL_PLAYER.r, Balance.COL_PLAYER.g, Balance.COL_PLAYER.b, 0.0)
	hover.set_border_width_all(0)
	back.add_theme_stylebox_override("hover", hover)
	back.add_theme_stylebox_override("pressed", hover)
	_add_button_chrome(back, Balance.COL_PLAYER, 0.018)
	_add_button_icon(back, "back", Balance.COL_PLAYER, 30.0)

func main_shell_snapshot() -> Dictionary:
	var shell_sections := TacticalUIHelper.shell_sections(size)
	return {
		"title": _title.text if _title != null else "KERNEL PANIC",
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
	var settings_layout := settings_layout_for_viewport(size)
	return {
		"groups": ["AUDIO", "CONTROL", "DISPLAY", "SAVE TRANSFER"],
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

func _refresh_difficulty_label() -> void:
	if _diff_btn == null:
		return
	if Game.mode == "story":
		_diff_btn.text = "DIFFICULTY: FIXED CURVE"
	else:
		_diff_btn.text = "DIFFICULTY: %s" % Game.difficulty.to_upper()

func _refresh_mode_ui() -> void:
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	match Game.mode:
		"story":
			_mode_btn.text = "MODE: STORY"
			var story_path: String = str(Game.story_stage_def(Game.story_stage_index).get("path", "/boot"))
			_mode_info.text = "UNIX ACT 1 // CURRENT %s // %d/%d STAGES CLEAR" % [story_path, Game.story_cleared.size(), Game.story_stage_count()]
		"weekly":
			_mode_btn.text = "MODE: WEEKLY RUN"
			var cur := int(cf.get_value("weekly", "best", 0)) if cf.get_value("weekly", "id", "") == Game.week_id() else 0
			var last := int(cf.get_value("weekly", "last_best", 0))
			_mode_info.text = "WEEK %s // LOCAL DETERMINISTIC // BEST %d // LAST %d" % [Game.week_id(), cur, last]
		"onehp":
			_mode_btn.text = "MODE: ONE-HP"
			_mode_info.text = "1 INTEGRITY // SCORE x3 // BEST %d" % int(cf.get_value("run", "best_onehp", 0))
		_:
			_mode_btn.text = "MODE: CLASSIC"
			_mode_info.text = "CLASSIC // ENDLESS WAVES // HIGH SCORE %07d" % Game.best
	if Game.mode == "story":
		_mode_info.text = "STORY // FIXED DIFFICULTY CURVE // " + _mode_info.text
	_update_best()
	_refresh_difficulty_label()

func settings_layout_for_viewport(viewport: Vector2) -> Dictionary:
	var panel_width := minf(1080.0, maxf(viewport.x - 48.0, 280.0))
	var panel_height := minf(680.0, maxf(viewport.y - 48.0, 240.0))
	var workstation := Rect2((viewport.x - panel_width) * 0.5, (viewport.y - panel_height) * 0.5, panel_width, panel_height)
	var navigation_width := minf(230.0, maxf(132.0, workstation.size.x * 0.27))
	var navigation := Rect2(workstation.position + Vector2(10.0, 88.0), Vector2(navigation_width, maxf(workstation.size.y - 160.0, 0.0)))
	var content_x := navigation.end.x + 14.0
	var content := Rect2(Vector2(content_x, navigation.position.y), Vector2(maxf(workstation.end.x - content_x - 10.0, 0.0), navigation.size.y))
	var footer := Rect2(workstation.position + Vector2(10.0, workstation.size.y - 68.0), Vector2(workstation.size.x - 20.0, 56.0))
	var title_height := 42.0
	var title_size := 34
	if viewport.x < 960.0:
		title_size = 26
	if viewport.x < 600.0:
		title_size = 20
	if viewport.x < 460.0:
		title_size = 16
	var title := Rect2(content.position.x, workstation.position.y + 14.0, content.size.x, title_height)
	return {
		"workstation": workstation,
		"navigation": navigation,
		"content": content,
		"footer": footer,
		"title": title,
		"title_size": title_size,
	}

func _layout_settings() -> void:
	if _settings_panel == null or not is_instance_valid(_settings_panel):
		return
	var settings_layout := settings_layout_for_viewport(size)
	var workstation: Rect2 = settings_layout["workstation"]
	var navigation: Rect2 = settings_layout["navigation"]
	var content: Rect2 = settings_layout["content"]
	var footer: Rect2 = settings_layout["footer"]
	var title: Rect2 = settings_layout["title"]
	if _settings_frame != null and is_instance_valid(_settings_frame):
		_settings_frame.position = workstation.position
		_settings_frame.size = workstation.size
	if _settings_workstation_chrome != null and is_instance_valid(_settings_workstation_chrome):
		_settings_workstation_chrome.position = workstation.position
		_settings_workstation_chrome.size = workstation.size
		_settings_workstation_chrome.call("configure_panel", Rect2(Vector2.ZERO, workstation.size), TacticalUIHelper.CYAN, 0.025)
	if _settings_navigation_chrome != null and is_instance_valid(_settings_navigation_chrome):
		_settings_navigation_chrome.position = navigation.position
		_settings_navigation_chrome.size = navigation.size
		_settings_navigation_chrome.call("configure_panel", Rect2(Vector2.ZERO, navigation.size), TacticalUIHelper.CYAN, 0.025)
	if _settings_scroll != null and is_instance_valid(_settings_scroll):
		_settings_scroll.offset_left = content.position.x
		_settings_scroll.offset_right = content.end.x
		_settings_scroll.offset_top = content.position.y + 8.0
		_settings_scroll.offset_bottom = footer.position.y - 8.0
	if _settings_box != null and is_instance_valid(_settings_box):
		_settings_box.custom_minimum_size.x = maxf(content.size.x - 28.0, 240.0)
	if _settings_title != null and is_instance_valid(_settings_title):
		_settings_title.position = title.position
		_settings_title.size = title.size
		_settings_title.add_theme_font_size_override("font_size", int(settings_layout["title_size"]))
	if _settings_footer_row != null and is_instance_valid(_settings_footer_row):
		_settings_footer_row.position = footer.position
		_settings_footer_row.size = footer.size
	if not _settings_nav_buttons.is_empty():
		for index in _settings_nav_buttons.size():
			var nav_button := _settings_nav_buttons[index]
			if not is_instance_valid(nav_button):
				continue
			nav_button.position = navigation.position + Vector2(10.0, 12.0 + float(index) * 48.0)
			nav_button.size = Vector2(maxf(navigation.size.x - 20.0, 96.0), 38.0)
	if _settings_keybind_grid != null and is_instance_valid(_settings_keybind_grid):
		_settings_keybind_grid.columns = 1 if content.size.x < 600.0 else 2

func _build_settings() -> void:
	_settings_panel = Control.new()
	_settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_panel.visible = false
	_settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.012, 0.03, 0.88)
	_settings_panel.add_child(dim)
	var outer_chrome: Control = TacticalChromeScript.new()
	outer_chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer_chrome.call("configure_shell", TacticalUIHelper.CYAN, 0.0)
	_settings_panel.add_child(outer_chrome)
	var settings_layout := settings_layout_for_viewport(size)
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
	_settings_scroll = scroll
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
	_settings_frame = frame
	_settings_panel.add_child(frame)
	var workstation_chrome: Control = TacticalChromeScript.new()
	workstation_chrome.set_anchors_preset(Control.PRESET_TOP_LEFT)
	workstation_chrome.position = workstation.position
	workstation_chrome.size = workstation.size
	workstation_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	workstation_chrome.call("configure_panel", Rect2(Vector2.ZERO, workstation.size), TacticalUIHelper.CYAN, 0.025)
	_settings_workstation_chrome = workstation_chrome
	_settings_panel.add_child(workstation_chrome)
	var navigation_chrome: Control = TacticalChromeScript.new()
	navigation_chrome.set_anchors_preset(Control.PRESET_TOP_LEFT)
	navigation_chrome.position = navigation.position
	navigation_chrome.size = navigation.size
	navigation_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	navigation_chrome.call("configure_panel", Rect2(Vector2.ZERO, navigation.size), TacticalUIHelper.CYAN, 0.025)
	_settings_navigation_chrome = navigation_chrome
	_settings_panel.add_child(navigation_chrome)
	scroll.offset_left = content.position.x
	scroll.offset_right = content.end.x
	scroll.offset_top = content.position.y + 8.0
	scroll.offset_bottom = footer.position.y - 8.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_panel.add_child(scroll)
	var box := VBoxContainer.new()
	_settings_box = box
	box.custom_minimum_size.x = maxf(content.size.x - 28.0, 240.0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 20)
	scroll.add_child(box)
	var title := Label.new()
	title.text = "SETTINGS // SYSTEM CONFIG"
	title.add_theme_font_override("font", load("res://assets/fonts/Orbitron.ttf"))
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Balance.COL_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_rect: Rect2 = settings_layout["title"]
	title.position = title_rect.position
	title.size = title_rect.size
	title.add_theme_font_size_override("font_size", int(settings_layout["title_size"]))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_title = title
	_settings_panel.add_child(title)
	box.add_child(_settings_group_label("AUDIO // MIX"))
	box.add_child(_make_slider_row("SFX", Sfx.sfx_vol, func(v: float) -> void:
		Sfx.set_sfx_vol(v)
		Sfx.play("ui", 1.0, -6.0)
	))
	box.add_child(_make_slider_row("MUSIC", Sfx.music_vol, func(v: float) -> void:
		Sfx.set_music_vol(v)
	))
	box.add_child(_settings_group_label("CONTROL // INPUT"))
	var mute := CheckButton.new()
	mute.text = "MUTE ALL"
	mute.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	mute.add_theme_font_size_override("font_size", 17)
	mute.add_theme_color_override("font_color", Balance.COL_TEXT)
	mute.button_pressed = Sfx.muted
	mute.toggled.connect(func(on: bool) -> void:
		Sfx.set_muted(on)
	)
	box.add_child(mute)
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
	box.add_child(haptics)
	_color_assist_btn = Button.new()
	_color_assist_btn.flat = true
	_color_assist_btn.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	_color_assist_btn.add_theme_font_size_override("font_size", 17)
	_color_assist_btn.add_theme_color_override("font_color", Balance.COL_TEXT)
	_color_assist_btn.add_theme_color_override("font_hover_color", Balance.COL_PLAYER)
	_color_assist_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_color_assist_btn.pressed.connect(func() -> void:
		Sfx.set_color_assist(not Sfx.color_assist)
		_refresh_color_assist_label()
	)
	_refresh_color_assist_label()
	box.add_child(_color_assist_btn)
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
		_refresh_aim_label(aim_btn)
		Sfx.save_settings()
	)
	_aim_btn_ref = aim_btn
	_refresh_aim_label(aim_btn)
	box.add_child(aim_btn)
	if _desktop_keybinds_enabled():
		_build_keybind_settings(box)
	box.add_child(_settings_group_label("DISPLAY // READABILITY"))
	var touch_sz := Button.new()
	touch_sz.flat = true
	touch_sz.text = "TOUCH SIZE: %s" % ["SMALL", "NORMAL", "BIG"][_touch_scale_idx(Sfx.touch_scale)]
	touch_sz.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	touch_sz.add_theme_font_size_override("font_size", 17)
	touch_sz.add_theme_color_override("font_color", Balance.COL_TEXT)
	touch_sz.add_theme_color_override("font_hover_color", Balance.COL_PLAYER)
	touch_sz.alignment = HORIZONTAL_ALIGNMENT_LEFT
	touch_sz.pressed.connect(func() -> void:
		var idx := _next_touch_scale_idx(Sfx.touch_scale)
		Sfx.touch_scale = [0.85, 1.0, 1.2][idx]
		touch_sz.text = "TOUCH SIZE: %s" % ["SMALL", "NORMAL", "BIG"][idx]
		Sfx.save_settings()
	)
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
	box.add_child(run_info)
	box.add_child(_settings_group_label("SAVE TRANSFER // PHONE ↔ PC"))
	var transfer_title := Label.new()
	transfer_title.text = "ENCODED PROGRESS // COPY OR PASTE"
	transfer_title.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	transfer_title.add_theme_font_size_override("font_size", 14)
	transfer_title.add_theme_color_override("font_color", Balance.COL_MOTE)
	box.add_child(transfer_title)
	_save_transfer_field = LineEdit.new()
	_save_transfer_field.placeholder_text = "BASE64 SAVE STRING // PASTE HERE"
	_save_transfer_field.custom_minimum_size = Vector2(0.0, 38.0)
	_save_transfer_field.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	_save_transfer_field.add_theme_font_size_override("font_size", 11)
	_save_transfer_field.add_theme_color_override("font_color", Balance.COL_TEXT)
	box.add_child(_save_transfer_field)
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
	export_btn.pressed.connect(_export_save_to_clipboard)
	transfer_row.add_child(export_btn)
	var import_btn := Button.new()
	import_btn.text = "IMPORT PASTE"
	import_btn.flat = true
	import_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	import_btn.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	import_btn.add_theme_font_size_override("font_size", 13)
	import_btn.add_theme_color_override("font_color", Balance.COL_TEXT)
	import_btn.add_theme_color_override("font_hover_color", Balance.COL_PLAYER)
	import_btn.pressed.connect(_import_save_from_clipboard)
	transfer_row.add_child(import_btn)
	box.add_child(transfer_row)
	_save_transfer_status = Label.new()
	_save_transfer_status.text = "EXPORT INCLUDES RECORDS, BESTIARY, PROGRAMS, ACHIEVEMENTS"
	_save_transfer_status.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	_save_transfer_status.add_theme_font_size_override("font_size", 10)
	_save_transfer_status.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.5))
	_save_transfer_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_save_transfer_status)
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
		_reset_scores()
		_update_best()
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
	_style_settings_footer_button(back, TacticalUIHelper.CYAN)
	_style_settings_footer_button(reset, TacticalUIHelper.MAGENTA)
	back.custom_minimum_size = Vector2(196.0, 42.0)
	reset.custom_minimum_size = Vector2(250.0, 42.0)
	_add_button_icon(back, "back", TacticalUIHelper.CYAN, 36.0)
	_add_button_icon(reset, "warning", TacticalUIHelper.MAGENTA, 36.0)
	footer_row.add_child(back)
	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_row.add_child(footer_spacer)
	footer_row.add_child(reset)
	_settings_panel.add_child(footer_row)
	_settings_footer_row = footer_row
	var nav_labels := ["AUDIO", "GAMEPLAY", "CONTROLS", "ACCESSIBILITY", "SAVE DATA"]
	var nav_targets := [0, 0, 0, 0, 100000]
	_settings_nav_buttons.clear()
	for index in nav_labels.size():
		var nav_button := Button.new()
		nav_button.text = "  %s" % nav_labels[index]
		nav_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		nav_button.position = navigation.position + Vector2(10.0, 12.0 + float(index) * 48.0)
		nav_button.size = Vector2(navigation.size.x - 20.0, 38.0)
		nav_button.focus_mode = Control.FOCUS_NONE
		nav_button.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
		nav_button.add_theme_font_size_override("font_size", 14)
		nav_button.add_theme_color_override("font_color", TacticalUIHelper.TEXT)
		nav_button.add_theme_color_override("font_hover_color", TacticalUIHelper.CYAN)
		nav_button.add_theme_stylebox_override("normal", _settings_nav_style(Color(TacticalUIHelper.CYAN.r, TacticalUIHelper.CYAN.g, TacticalUIHelper.CYAN.b, 0.18)))
		nav_button.add_theme_stylebox_override("hover", _settings_nav_style(TacticalUIHelper.CYAN))
		nav_button.add_theme_stylebox_override("pressed", _settings_nav_style(TacticalUIHelper.CYAN))
		_add_button_chrome(nav_button, TacticalUIHelper.CYAN, 0.018)
		_settings_nav_buttons.append(nav_button)
		var target: int = nav_targets[index]
		nav_button.pressed.connect(func() -> void:
			scroll.set_v_scroll(target)
		)
		_settings_panel.add_child(nav_button)
	var nav_hint := Label.new()
	nav_hint.text = "SYSTEM / CONFIG"
	nav_hint.position = navigation.position + Vector2(14.0, navigation.size.y - 28.0)
	nav_hint.size = Vector2(navigation.size.x - 28.0, 18.0)
	nav_hint.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	nav_hint.add_theme_font_size_override("font_size", 10)
	nav_hint.add_theme_color_override("font_color", TacticalUIHelper.MUTED)
	_settings_panel.add_child(nav_hint)
	var hint := Label.new()
	hint.text = "M = MUTE IN GAME"
	hint.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.4))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
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
	box.add_child(stats)
	add_child(_settings_panel)
	_layout_settings()

func _settings_group_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Balance.COL_MOTE)
	label.custom_minimum_size = Vector2(0.0, 22.0)
	return label

func _build_keybind_settings(parent: VBoxContainer) -> void:
	_keybind_box = VBoxContainer.new()
	_keybind_box.add_theme_constant_override("separation", 7)
	var title := Label.new()
	title.text = "DESKTOP KEYBINDS"
	title.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Balance.COL_MOTE)
	_keybind_box.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	_settings_keybind_grid = grid
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 5)
	for action in Game.KEYBIND_DEFAULTS:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(220, 28)
		row.add_theme_constant_override("separation", 6)
		var label := Label.new()
		label.text = _keybind_action_label(action)
		label.custom_minimum_size = Vector2(92, 0)
		label.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.7))
		row.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(112, 28)
		button.flat = true
		button.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_color_override("font_color", Balance.COL_TEXT)
		button.add_theme_color_override("font_hover_color", Balance.COL_PLAYER)
		button.pressed.connect(_begin_keybind_capture.bind(action))
		_keybind_buttons[action] = button
		row.add_child(button)
		grid.add_child(row)
	_keybind_box.add_child(grid)
	_keybind_status = Label.new()
	_keybind_status.text = "SELECT A BIND TO CHANGE IT"
	_keybind_status.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	_keybind_status.add_theme_font_size_override("font_size", 11)
	_keybind_status.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.55))
	_keybind_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_keybind_box.add_child(_keybind_status)
	var reset := Button.new()
	reset.text = "RESET KEYBINDS"
	reset.flat = true
	reset.alignment = HORIZONTAL_ALIGNMENT_LEFT
	reset.custom_minimum_size = Vector2(160.0, 28.0)
	reset.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	reset.add_theme_font_size_override("font_size", 12)
	reset.add_theme_color_override("font_color", Balance.COL_DANGER)
	reset.add_theme_color_override("font_hover_color", Balance.COL_PLAYER_HOT)
	reset.pressed.connect(func() -> void:
		Game.reset_keybinds()
		_refresh_keybind_buttons()
		_capture_action = ""
		_keybind_status.text = "KEYBINDS RESET TO DEFAULTS"
	)
	_keybind_box.add_child(reset)
	_refresh_keybind_buttons()
	parent.add_child(_keybind_box)

func _keybind_action_label(action: String) -> String:
	return {
		"move_up": "MOVE UP",
		"move_down": "MOVE DOWN",
		"move_left": "MOVE LEFT",
		"move_right": "MOVE RIGHT",
		"dash": "DASH",
		"overclock": "OVERCLOCK",
		"pause": "PAUSE",
		"abandon": "ABANDON",
		"mute": "MUTE",
		"restart": "RESTART",
		"confirm": "CONFIRM",
	}.get(action, action.to_upper())

func _keybind_key_name(physical_key: int) -> String:
	var key_name := OS.get_keycode_string(physical_key)
	return key_name if not key_name.is_empty() else "KEY %d" % physical_key

func _refresh_keybind_buttons() -> void:
	for action in _keybind_buttons:
		var button: Button = _keybind_buttons[action]
		button.text = _keybind_key_name(Game.get_keybind(action))

func _begin_keybind_capture(action: String) -> void:
	if not _desktop_keybinds_enabled() or not Game.KEYBIND_DEFAULTS.has(action):
		return
	_capture_action = action
	_keybind_status.text = "PRESS A KEY FOR %s // ESC CANCELS" % _keybind_action_label(action)

func _handle_keybind_capture(event: InputEventKey) -> bool:
	if _capture_action.is_empty():
		return false
	if not event.pressed or event.echo:
		return true
	var physical_key := int(event.physical_keycode)
	if physical_key <= 0:
		return true
	if physical_key == KEY_ESCAPE or int(event.keycode) == KEY_ESCAPE:
		_capture_action = ""
		_keybind_status.text = "KEYBIND CAPTURE CANCELLED"
		return true
	var conflict := Game.keybind_conflict(physical_key, _capture_action)
	if conflict != "":
		_keybind_status.text = "CONFLICT: %s IS ALREADY %s" % [_keybind_key_name(physical_key), _keybind_action_label(conflict)]
		return true
	var action := _capture_action
	if not Game.set_keybind(action, physical_key):
		_keybind_status.text = "KEYBIND REJECTED"
		return true
	_capture_action = ""
	_refresh_keybind_buttons()
	_keybind_status.text = "%s BOUND TO %s" % [_keybind_action_label(action), _keybind_key_name(physical_key)]
	return true

func _make_slider_row(label_text: String, value: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(86, 0)
	l.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Balance.COL_TEXT)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(220, 36)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.modulate = Color(0.55, 0.9, 1.0)
	s.value_changed.connect(on_change)
	row.add_child(s)
	var v := Label.new()
	v.text = "%d%%" % int(value * 100.0)
	v.custom_minimum_size = Vector2(56, 0)
	v.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	v.add_theme_font_size_override("font_size", 15)
	v.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.7))
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s.value_changed.connect(func(val: float) -> void:
		v.text = "%d%%" % int(val * 100.0)
	)
	row.add_child(v)
	return row

func _open_settings() -> void:
	_set_main_menu_controls_visible(false)
	_settings_panel.visible = true
	Sfx.play("ui", 1.1, -6.0)

func _close_settings() -> void:
	_capture_action = ""
	_settings_panel.visible = false
	_set_main_menu_controls_visible(true)
	Sfx.play("ui", 0.9, -6.0)

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
	_save_transfer_status.text = "SAVE EXPORTED // COPIED TO CLIPBOARD"

func _import_save_from_clipboard() -> void:
	if _save_transfer_field == null or not is_instance_valid(_save_transfer_field):
		return
	var encoded := _save_transfer_field.text.strip_edges()
	if encoded.is_empty():
		encoded = DisplayServer.clipboard_get().strip_edges()
	if Game.import_save_string(encoded):
		_save_transfer_field.text = encoded
		_save_transfer_status.text = "SAVE IMPORTED // PROGRESS RESTORED"
		_refresh_mode_ui()
		_refresh_program_label()
	else:
		_save_transfer_status.text = "IMPORT REJECTED // INVALID SAVE STRING"

func _refresh_color_assist_label() -> void:
	if _color_assist_btn != null:
		_color_assist_btn.text = "COLOR ASSIST: %s" % ("ON" if Sfx.color_assist else "OFF")

func _mk_title(f: Font, col: Color) -> Label:
	var l := Label.new()
	l.text = "KERNEL PANIC"
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", 76)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.offset_left = 0.0
	l.offset_right = 0.0
	l.offset_top = 125.0
	l.offset_bottom = 235.0
	add_child(l)
	return l

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
	var b := Game.best_for_mode()
	_best_label.text = ("HIGH SCORE  %07d" % b) if b > 0 else "NO RECORD YET"

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
			_prompt.text = "PRESS [ENTER] OR HIT >> PURGE" if not DisplayServer.is_touchscreen_available() else "HIT PURGE TO BEGIN"
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
	_title.offset_left = off.x
	_title.offset_right = off.x
	_title_r.offset_left = off.x * 0.4 - 4.0
	_title_r.offset_right = off.x * 0.4 - 4.0
	_title_b.offset_left = off.x * 0.4 + 4.0
	_title_b.offset_right = off.x * 0.4 + 4.0
	_title_r.visible = glitching
	_title_b.visible = glitching
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
	if _settings_panel != null and _settings_panel.visible:
		return
	for d in _drifters:
		var c: Color = d["col"]
		c.a = 0.16
		var s: float = d["scale"]
		var pts := PackedVector2Array()
		match int(d["kind"]):
			0:
				pts = PackedVector2Array([Vector2(s * 1.2, 0), Vector2(-s, s * 0.85), Vector2(-s * 0.3, 0), Vector2(-s, -s * 0.85)])
			1:
				for i in 6:
					pts.push_back(Vector2.from_angle(TAU * i / 6.0) * s)
			2:
				pts = PackedVector2Array([Vector2(s * 1.5, 0), Vector2(-s, s * 0.8), Vector2(-s * 0.4, 0), Vector2(-s, -s * 0.8)])
		draw_set_transform(d["pos"], d["rot"], Vector2.ONE)
		draw_polyline(pts + PackedVector2Array([pts[0]]), c, 1.6, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var center_x := size.x * 0.5
	if _best_label != null and _purge_btn != null:
		var score_rect := _best_label.get_global_rect()
		var score_y := score_rect.position.y + score_rect.size.y * 0.58
		draw_line(Vector2(center_x - 112.0, score_y), Vector2(center_x - 72.0, score_y), Color(Balance.COL_PLAYER.r, Balance.COL_PLAYER.g, Balance.COL_PLAYER.b, 0.72), 1.2)
		draw_line(Vector2(center_x + 72.0, score_y), Vector2(center_x + 112.0, score_y), Color(Balance.COL_PLAYER.r, Balance.COL_PLAYER.g, Balance.COL_PLAYER.b, 0.72), 1.2)
	var ring_center := Vector2(maxf(150.0, center_x - 470.0), size.y * 0.44)
	for arc_index in 3:
		var start := -PI * 0.82 + arc_index * TAU / 3.0
		draw_arc(ring_center, 64.0, start, start + PI * 0.48, 18, Color(Balance.COL_DANGER.r, Balance.COL_DANGER.g, Balance.COL_DANGER.b, 0.5), 5.0, true)
	var ring_triangle := PackedVector2Array([
		ring_center + Vector2(0.0, -24.0),
		ring_center + Vector2(27.0, 22.0),
		ring_center + Vector2(-27.0, 22.0),
	])
	draw_polyline(ring_triangle + PackedVector2Array([ring_triangle[0]]), Color(Balance.COL_DANGER.r, Balance.COL_DANGER.g, Balance.COL_DANGER.b, 0.58), 2.0, true)
	draw_circle(ring_center, 9.0, Color(Balance.COL_DANGER.r, Balance.COL_DANGER.g, Balance.COL_DANGER.b, 0.42))
	var mode_y := size.y * 0.5 + 130.0
	draw_circle(Vector2(center_x, mode_y), 4.0, Balance.COL_MOTE)

func _input(event: InputEvent) -> void:
	if _starting or not _capture_action.is_empty() or not event.is_action_pressed("pause"):
		return
	if _settings_panel != null and _settings_panel.visible:
		_close_settings()
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
				_handle_keybind_capture(event)
				get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("pause"):
			_close_settings()
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
			_prompt.text = "PRESS ESC AGAIN TO QUIT"
			_prompt.add_theme_color_override("font_color", Balance.COL_DANGER)
			Sfx.play("ui", 0.8, -8.0)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("confirm"):
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

extends Control

const TacticalUIHelper = preload("res://src/ui/tactical_ui.gd")
const TacticalChromeScript = preload("res://src/ui/tactical_chrome.gd")
const TacticalIconScript = preload("res://src/ui/tactical_icon.gd")
const MenuSettingsKitScript = preload("res://src/ui/menu_settings_kit.gd")

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
var _settings_kit

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _settings_panel != null and is_instance_valid(_settings_panel):
		_settings_kit._layout_settings.call_deferred()

func _desktop_keybinds_enabled() -> bool:
	return Balance.is_desktop_display() and not DisplayServer.is_touchscreen_available() and OS.get_environment("KP_FORCE_TOUCH") == ""

func keybind_capture_visible() -> bool:
	return _keybind_box != null and _keybind_box.visible

func settings_layout_for_viewport(viewport: Vector2) -> Dictionary:
	return _settings_kit.settings_layout_for_viewport(viewport)

func _open_settings() -> void:
	_settings_kit._open_settings()

func _close_settings() -> void:
	_settings_kit._close_settings()

func _handle_keybind_capture(event: InputEventKey) -> bool:
	return _settings_kit._handle_keybind_capture(event)

func _begin_keybind_capture(action: String) -> void:
	_settings_kit._begin_keybind_capture(action)

func _refresh_color_assist_label() -> void:
	_settings_kit._refresh_color_assist_label()

func _refresh_aim_label(btn: Button) -> void:
	btn.text = "AIM MODE: %s" % Game.effective_aim_mode().to_upper()

func _ready() -> void:
	_settings_kit = MenuSettingsKitScript.new(self)
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
	var settings_layout: Dictionary = _settings_kit.settings_layout_for_viewport(size)
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

extends Control

const TacticalUIHelper = preload("res://src/ui/tactical_ui.gd")
const TacticalChromeScript = preload("res://src/ui/tactical_chrome.gd")
const TacticalIconScript = preload("res://src/ui/tactical_icon.gd")
const MenuSettingsKitScript = preload("res://src/ui/menu_settings_kit.gd")
const MenuChromeKitScript = preload("res://src/ui/menu_chrome_kit.gd")
const VNextBootScript = preload("res://src/ui/vnext/surfaces/boot_surface.gd")
const VNextProgramScript = preload("res://src/ui/vnext/surfaces/program_surface.gd")
const VNextStoryScript = preload("res://src/ui/vnext/surfaces/story_surface.gd")
const VNextBestiaryScript = preload("res://src/ui/vnext/surfaces/bestiary_surface.gd")
const VNextAccessibilityScript = preload("res://src/ui/vnext/surfaces/accessibility_surface.gd")
const VNextTokens = preload("res://src/ui/vnext/ui_tokens.gd")

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
var _practice_wave_btn: Button
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
var _program_boot_button: Button
var _story_mount_button: Button
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
var _version_tag: Label
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
var _vnext_boot: Control
var _vnext_surface: Control
var _vnext_mode := false

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if _vnext_surface != null and is_instance_valid(_vnext_surface):
			_configure_vnext_surface()
		if _settings_panel != null and is_instance_valid(_settings_panel):
			_settings_kit._layout_settings.call_deferred()
		if _chrome_kit != null:
			_chrome_kit.apply_menu_layout.call_deferred()
		_layout_overlay_action_buttons()

func _on_window_size_changed() -> void:
	# Window resizes that keep the logical canvas size (uniform scale changes)
	# never reach NOTIFICATION_RESIZED; reflowing is idempotent, so cover both.
	if _vnext_surface != null and is_instance_valid(_vnext_surface):
		_configure_vnext_surface()
	if _settings_panel != null and is_instance_valid(_settings_panel):
		_settings_kit._layout_settings.call_deferred()
	if _chrome_kit != null:
		_chrome_kit.apply_menu_layout.call_deferred()
	_layout_overlay_action_buttons()

func _style_overlay_action(button: Button, accent: Color) -> void:
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", load("res://assets/fonts/Orbitron.ttf"))
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", accent)
	button.add_theme_color_override("font_hover_color", Balance.COL_TEXT)
	button.add_theme_color_override("font_pressed_color", Balance.COL_TEXT)
	button.add_theme_color_override("font_focus_color", Balance.COL_TEXT)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())

func _layout_overlay_action_buttons() -> void:
	if _program_panel != null and is_instance_valid(_program_panel) and _program_boot_button != null and is_instance_valid(_program_boot_button):
		var boot_rect := _program_panel.boot_action_rect()
		_program_boot_button.position = boot_rect.position
		_program_boot_button.size = boot_rect.size
		_program_boot_button.add_theme_font_size_override("font_size", 16 if boot_rect.size.x >= 360.0 else 12)
		_program_boot_button.text = ">> BOOT %s  [ENTER]" % Game.program_def().get("name", "KERNEL")
	if _story_panel != null and is_instance_valid(_story_panel) and _story_mount_button != null and is_instance_valid(_story_mount_button):
		var mount_rect := _story_panel.mount_action_rect()
		_story_mount_button.position = mount_rect.position
		_story_mount_button.size = mount_rect.size

func _refresh_story_mount_action(_index: int = -1) -> void:
	if _story_mount_button != null and _story_panel != null:
		var selected := _story_panel.selected_stage_index()
		_story_mount_button.text = "MOUNT %s  [ENTER]" % str(Game.story_stage_def(selected).get("path", "/boot"))
		_story_mount_button.add_theme_color_override("font_color", _story_panel.card_accent(selected))

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

func _handle_keybind_capture(event: InputEventKey) -> bool:
	return _settings_kit._handle_keybind_capture(event)

func _begin_keybind_capture(action: String) -> void:
	_settings_kit._begin_keybind_capture(action)

func _refresh_color_assist_label() -> void:
	_settings_kit._refresh_color_assist_label()

func _refresh_aim_label(btn: Button) -> void:
	btn.text = "AIM MODE: %s" % Game.effective_aim_mode().to_upper()

func _vnext_layout_viewport() -> Vector2:
	# The project deliberately keeps a 1280-wide logical canvas. With
	# canvas_items + aspect=expand, a portrait window exposes a tall logical
	# canvas instead of changing its width, so using get_viewport_rect() here
	# would keep selecting the desktop composition forever. VNext surfaces are
	# authored in the actual window coordinate space and fitted back into the
	# logical canvas below.
	var window_size := Vector2(get_window().size)
	if window_size.x < 320.0 or window_size.y < 240.0:
		var viewport_size := get_viewport_rect().size
		return viewport_size if viewport_size.x >= 320.0 and viewport_size.y >= 240.0 else VNextTokens.BASE_VIEWPORT
	return window_size

func _fit_vnext_surface(surface: Control, layout_viewport: Vector2) -> void:
	if surface == null or layout_viewport.x < 1.0 or layout_viewport.y < 1.0:
		return
	var logical_size := get_viewport_rect().size
	var fit_scale := minf(logical_size.x / layout_viewport.x, logical_size.y / layout_viewport.y)
	if fit_scale <= 0.0:
		fit_scale = 1.0
	surface.set_anchors_preset(Control.PRESET_TOP_LEFT)
	surface.position = Vector2.ZERO
	surface.size = layout_viewport
	surface.scale = Vector2.ONE * fit_scale

func _configure_vnext_boot(next_viewport_size: Vector2 = Vector2.ZERO) -> void:
	if _vnext_boot == null or not is_instance_valid(_vnext_boot):
		return
	var viewport_size := next_viewport_size if next_viewport_size != Vector2.ZERO else _vnext_layout_viewport()
	_fit_vnext_surface(_vnext_boot, viewport_size)
	var touch := DisplayServer.is_touchscreen_available() or OS.get_environment("KP_FORCE_TOUCH") != ""
	_vnext_boot.configure({"program": Game.program, "best": Game.best_for_mode(), "settings_enabled": OS.get_environment("KP_VNEXT_SETTINGS") == "1"}, VNextBootScript.context_for_viewport(viewport_size, touch))

func _configure_vnext_surface(next_viewport_size: Vector2 = Vector2.ZERO) -> void:
	if _vnext_surface == null or not is_instance_valid(_vnext_surface):
		return
	var viewport_size := next_viewport_size if next_viewport_size != Vector2.ZERO else _vnext_layout_viewport()
	_fit_vnext_surface(_vnext_surface, viewport_size)
	var touch := DisplayServer.is_touchscreen_available() or OS.get_environment("KP_FORCE_TOUCH") != ""
	if _vnext_surface.get_script() == VNextProgramScript:
		_vnext_surface.configure({"selected": Game.program}, VNextProgramScript.context_for_viewport(viewport_size, touch))
	elif _vnext_surface.get_script() == VNextStoryScript:
		_vnext_surface.configure({"selected": Game.story_stage_index}, VNextStoryScript.context_for_viewport(viewport_size, touch))
	elif _vnext_surface.get_script() == VNextBestiaryScript:
		_vnext_surface.configure({"selected": "drone"}, VNextBestiaryScript.context_for_viewport(viewport_size, touch))
	elif _vnext_surface.get_script() == VNextAccessibilityScript:
		_vnext_surface.configure(Sfx.accessibility_snapshot(), VNextAccessibilityScript.context_for_viewport(viewport_size, touch))
	else:
		_configure_vnext_boot(viewport_size)

func _show_vnext_route(route: String) -> void:
	if _vnext_surface != null and is_instance_valid(_vnext_surface):
		_vnext_surface.queue_free()
	_vnext_surface = VNextProgramScript.new() if route == "program" else VNextStoryScript.new() if route == "story" else VNextBestiaryScript.new() if route == "bestiary" else VNextAccessibilityScript.new() if route == "settings" else VNextBootScript.new()
	add_child(_vnext_surface)
	_vnext_surface.action_requested.connect(_on_vnext_boot_action)
	if route == "program":
		_vnext_boot = null
		_configure_vnext_surface()
	elif route == "story":
		_vnext_boot = null
		_configure_vnext_surface()
	elif route == "bestiary":
		_vnext_boot = null
		_configure_vnext_surface()
	elif route == "settings":
		_vnext_boot = null
		_configure_vnext_surface()
	else:
		_vnext_boot = _vnext_surface
		_configure_vnext_boot()

func _on_vnext_boot_action(action_id: String, _payload: Dictionary) -> void:
	if action_id == "boot":
		_start()
	elif action_id == "program":
		_show_vnext_route("program")
	elif action_id == "story":
		_show_vnext_route("story")
	elif action_id == "bestiary":
		_show_vnext_route("bestiary")
	elif action_id == "launch_program":
		Game.set_program(str(_payload.get("program", Game.program)))
		_start()
	elif action_id == "launch_story":
		_start_story(int(_payload.get("index", 0)))
	elif action_id == "settings":
		_show_vnext_route("settings")
	elif action_id == "back":
		if _vnext_surface != null and _vnext_surface != _vnext_boot:
			_show_vnext_route("boot")
		else:
			get_tree().quit()

func _on_locale_changed(_locale: String) -> void:
	if _settings_kit != null and _settings_kit.has_method("refresh_localized_controls"):
		_settings_kit.refresh_localized_controls()
	if _story_panel != null and is_instance_valid(_story_panel):
		_story_panel.queue_redraw()
	if _vnext_surface != null and is_instance_valid(_vnext_surface):
		_configure_vnext_surface()
	if not _vnext_mode:
		_refresh_mode_ui()

func _ready() -> void:
	var localization := get_node_or_null("/root/Localization")
	if localization != null and localization.has_signal("locale_changed"):
		localization.locale_changed.connect(_on_locale_changed)
	if OS.get_environment("KP_VNEXT_BOOT") == "1" or OS.get_environment("KP_VNEXT_SETTINGS") == "1":
		_vnext_mode = true
		set_anchors_preset(Control.PRESET_FULL_RECT)
		_show_vnext_route("boot")
		if OS.get_environment("KP_VNEXT_SETTINGS") == "1":
			_configure_vnext_boot()
		get_window().size_changed.connect(_on_window_size_changed)
		return
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
	_title_r = _chrome_kit._mk_title(orbitron, Color(1, 0.1, 0.3, 0.5))
	_title_b = _chrome_kit._mk_title(orbitron, Color(0.1, 0.9, 1.0, 0.5))
	_title = _chrome_kit._mk_title(orbitron, Balance.COL_TEXT)
	var sub := Label.new()
	sub.text = "// last process standing"
	sub.add_theme_font_override("font", mono)
	sub.add_theme_font_size_override("font_size", 17)
	sub.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.65))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.anchor_left = 0.0
	sub.anchor_right = 1.0
	# Geometry placeholder: the menu grid spec owns every rect via apply_menu_layout.
	sub.offset_top = 0.0
	sub.offset_bottom = 0.0
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
	_prompt.offset_top = 0.0
	_prompt.offset_bottom = 0.0
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
	controls.anchor_top = 0.0
	controls.anchor_bottom = 0.0
	controls.offset_top = 0.0
	controls.offset_bottom = 0.0
	add_child(controls)
	_controls_line = controls
	_best_label = Label.new()
	_best_label.add_theme_font_override("font", mono)
	_best_label.add_theme_font_size_override("font_size", 14)
	_best_label.add_theme_color_override("font_color", Color(Balance.COL_MOTE.r, Balance.COL_MOTE.g, Balance.COL_MOTE.b, 0.8))
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_best_label.anchor_left = 0.0
	_best_label.anchor_right = 1.0
	_best_label.offset_top = 0.0
	_best_label.offset_bottom = 0.0
	add_child(_best_label)
	var tag := Label.new()
	tag.text = "KERNEL PANIC v%s // purge loop online" % ProjectSettings.get_setting("application/config/version", "dev")
	tag.add_theme_font_override("font", mono)
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.3))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.anchor_left = 1.0
	tag.anchor_right = 1.0
	# Geometry placeholder: apply_menu_layout hangs the stamp under the meta
	# band on the right rail (it lands at the same height on real devices, where
	# the logical canvas is never compact).
	tag.offset_left = 0.0
	tag.offset_right = 0.0
	tag.offset_top = 0.0
	tag.offset_bottom = 0.0
	add_child(tag)
	_version_tag = tag
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
	_chrome_kit._build_button_row()
	_settings_kit._build_settings()
	_klog = Label.new()
	_klog.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	_klog.add_theme_font_size_override("font_size", 11)
	_klog.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.22))
	_klog.anchor_top = 0.0
	_klog.anchor_bottom = 0.0
	_klog.anchor_left = 0.0
	# Geometry placeholder: the meta band rides the shell top rail per the spec.
	_klog.offset_left = 0.0
	_klog.offset_right = 0.0
	_klog.offset_top = 0.0
	_klog.offset_bottom = 0.0
	_klog.text = "[    0.000000] kernel panic daemon online"
	add_child(_klog)
	_chrome_kit.apply_menu_layout()
	if not DevHarness.active and DisplayServer.get_name() != "headless":
		_boot = BootOverlay.new()
		var bl := CanvasLayer.new()
		bl.layer = 95
		bl.add_child(_boot)
		add_child(bl)

func _refresh_program_label() -> void:
	if _program_btn != null:
		_program_btn.text = "PROGRAM: %s" % Game.program_def()["name"]

func _open_program_selector() -> void:
	if _program_panel == null:
		_program_panel = ProgramPanel.new()
		_program_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		_program_panel.selection_changed.connect(func(_id: String) -> void:
			_refresh_program_label()
			_layout_overlay_action_buttons()
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
		_chrome_kit._style_overlay_back(back)
		back.pressed.connect(_close_program_selector)
		_program_panel.add_child(back)
		_program_boot_button = Button.new()
		_program_boot_button.name = "BootAction"
		_program_boot_button.text = ">> BOOT KERNEL  [ENTER]"
		_program_boot_button.tooltip_text = "Boot the selected process"
		_style_overlay_action(_program_boot_button, TacticalUIHelper.CYAN)
		_program_boot_button.pressed.connect(_start)
		_program_panel.add_child(_program_boot_button)
		var layer := CanvasLayer.new()
		layer.layer = 70
		layer.add_child(_program_panel)
		add_child(layer)
	_program_panel.visible = true
	_program_panel.scroll_y = 0.0
	_program_panel.queue_redraw()
	_layout_overlay_action_buttons()
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
		_story_panel.selection_changed.connect(_refresh_story_mount_action)
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
		_chrome_kit._style_overlay_back(back)
		back.pressed.connect(_close_story_selector)
		_story_panel.add_child(back)
		_story_mount_button = Button.new()
		_story_mount_button.name = "MountAction"
		_story_mount_button.tooltip_text = "Mount the selected story stage"
		_style_overlay_action(_story_mount_button, TacticalUIHelper.CYAN)
		_story_mount_button.pressed.connect(_confirm_story_selection)
		_story_panel.add_child(_story_mount_button)
		var layer := CanvasLayer.new()
		layer.layer = 70
		layer.process_mode = Node.PROCESS_MODE_ALWAYS
		layer.add_child(_story_panel)
		add_child(layer)
	_story_panel.visible = true
	_story_panel.scroll_y = 0.0
	_story_panel.queue_redraw()
	_refresh_story_mount_action()
	_layout_overlay_action_buttons()
	Sfx.play("ui", 1.1, -8.0)

func _close_story_selector() -> void:
	if _story_panel != null:
		_story_panel.visible = false
	Sfx.play("ui", 0.9, -8.0)

func _confirm_story_selection() -> void:
	if _story_panel != null:
		_story_panel.confirm_selection()

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
		_chrome_kit._style_overlay_back(back)
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
		_chrome_kit._style_overlay_back(back)
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
		"groups": ["AUDIO", "DISPLAY", "GAMEPLAY", "CONTROLS", "ACCESSIBILITY", "SAVE DATA"],
		"scrollable": _settings_panel != null and _settings_panel.find_child("SettingsScroll", true, false) != null,
		"shell_rect": shell,
		"navigation_rect": settings_layout["navigation"],
		"content_rect": settings_layout["content"],
		"footer_rect": sections["footer"],
		"title_rect": settings_layout["title"],
	}

func menu_snapshot() -> Dictionary:
	var required := ["screen", "mode", "difficulty", "program", "best", "layout"]
	var optional := ["settings_section", "keybind_capture_visible", "weekly_mutator", "practice", "palette"]
	var layout := menu_layout_for_viewport(size)
	var encoded_layout := {}
	for key in layout:
		encoded_layout[str(key)] = _snapshot_value(layout[key])
	var snapshot := {
		"schema_version": 1,
		"owner": "Menu",
		"required_fields": required.duplicate(true),
		"optional_fields": optional.duplicate(true),
		"screen": "main" if _settings_panel == null or not _settings_panel.visible else "settings",
		"mode": str(Game.mode),
		"difficulty": str(Game.difficulty),
		"program": str(Game.program),
		"best": int(Game.best_for_mode()),
		"layout": encoded_layout,
		"settings_section": _settings_kit.active_section() if _settings_kit != null and _settings_kit.has_method("active_section") else "AUDIO",
		"keybind_capture_visible": keybind_capture_visible(),
		"weekly_mutator": Game.weekly_mutator().duplicate(true),
		"practice": {"unlocked": Game.practice_unlocked(), "wave": Game.practice_wave, "max_wave": Game.practice_max_wave()},
		"palette": {"accent": Balance.COL_PLAYER.to_html(false), "danger": Balance.COL_DANGER.to_html(false)},
	}
	for field in required:
		assert(snapshot.has(field), "Menu menu_snapshot missing required field: " + str(field))
	return snapshot.duplicate(true)

func _snapshot_value(value):
	if value is Rect2:
		return {"x": float(value.position.x), "y": float(value.position.y), "width": float(value.size.x), "height": float(value.size.y)}
	if value is Vector2:
		return {"x": float(value.x), "y": float(value.y)}
	if value is Color:
		return value.to_html(false)
	if value is Dictionary:
		var result := {}
		for key in value:
			result[str(key)] = _snapshot_value(value[key])
		return result
	if value is Array:
		var result: Array = []
		for child in value:
			result.append(_snapshot_value(child))
		return result
	return value

func _cycle_mode() -> void:
	var order: Array[String] = ["classic", "weekly"]
	if Game.onehp_unlocked:
		order.append("onehp")
	if Game.practice_unlocked():
		order.append("practice")
	var idx := order.find(Game.mode)
	Game.mode = order[(idx + 1) % order.size()]
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
			_mode_info.text = "%s ACT // CURRENT %s // %d/%d STAGES CLEAR" % [_story_act_label(Game.story_stage_index), story_path, Game.story_cleared.size(), Game.story_stage_count()]
		"weekly":
			_mode_btn.text = "MODE: WEEKLY RUN"
			var cur := int(cf.get_value("weekly", "best", 0)) if cf.get_value("weekly", "id", "") == Game.week_id() else 0
			var last := int(cf.get_value("weekly", "last_best", 0))
			if size.x < 760.0:
				_mode_info.text = "WEEK %s // %s // %s" % [Game.week_id(), Game.weekly_mutator_title(), Game.weekly_mutator_description()]
			else:
				_mode_info.text = "WEEK %s // LOCAL DETERMINISTIC // %s // %s // BEST %d // LAST %d" % [Game.week_id(), Game.weekly_mutator_title(), Game.weekly_mutator_description(), cur, last]
			_mode_info.visible = true
		"onehp":
			_mode_btn.text = "MODE: ONE-HP"
			_mode_info.text = "1 INTEGRITY // SCORE x3 // BEST %d" % int(cf.get_value("run", "best_onehp", 0))
		"practice":
			_mode_btn.text = "MODE: PRACTICE"
			_mode_info.text = "PRACTICE // ENDLESS RECORDS AND ACHIEVEMENTS OFF"
			_mode_info.visible = false
			if _practice_wave_btn != null:
				_practice_wave_btn.text = "PRACTICE WAVE: %02d / %02d" % [Game.practice_wave, Game.practice_max_wave()]
				_practice_wave_btn.visible = true
		_:
			_mode_btn.text = "MODE: CLASSIC"
			_mode_info.text = "CLASSIC // ENDLESS WAVES // HIGH SCORE %07d" % Game.best
	if Game.mode != "weekly" and Game.mode != "practice":
		_mode_info.visible = false
	if Game.mode == "story":
		_mode_info.text = "STORY // %s ACT // %s // %d/%d CLEAR" % [_story_act_label(Game.story_stage_index), str(Game.story_stage_def(Game.story_stage_index).get("path", "/boot")), Game.story_cleared.size(), Game.story_stage_count()] if size.x < 760.0 else "STORY // FIXED DIFFICULTY CURVE // " + _mode_info.text
	if _practice_wave_btn != null and Game.mode != "practice":
		_practice_wave_btn.visible = false
	_update_best()
	_refresh_difficulty_label()

func _cycle_practice_wave() -> void:
	if Game.mode != "practice" or not Game.practice_unlocked():
		return
	var next_wave := Game.practice_wave + 1
	if next_wave > Game.practice_max_wave():
		next_wave = 1
	Game.set_practice_wave(next_wave)
	Sfx.play("ui", 1.1, -8.0)
	_refresh_mode_ui()

func _story_act_label(index: int) -> String:
	var stage := Game.story_stage_def(index)
	var act := str(stage.get("act", "unix")).to_lower()
	return {"unix": "UNIX", "windows": "WINDOWS", "templeos": "TEMPLEOS", "macos": "MACOS"}.get(act, act.to_upper())

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

func _default_launch_prompt() -> String:
	return "HIT PURGE TO BEGIN" if DisplayServer.is_touchscreen_available() else "PRESS [ENTER] OR HIT >> PURGE"

func _legacy_prompt_should_show() -> bool:
	if _vnext_mode or _starting or _prompt == null or not is_instance_valid(_prompt):
		return false
	for overlay in [_settings_panel, _program_panel, _story_panel, _bestiary_panel, _ach_panel]:
		if overlay != null and is_instance_valid(overlay) and overlay.visible:
			return false
	return true

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
	if _vnext_mode:
		return
	_t += delta
	if _esc_armed > 0.0:
		_esc_armed -= delta
		if _esc_armed <= 0.0 and not _starting:
			_prompt.text = _default_launch_prompt()
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
	_prompt.visible = _legacy_prompt_should_show()
	if _prompt.visible:
		# This is a navigation instruction, not an alarm. Keep its pulse
		# restrained so the PURGE action remains the visual priority.
		_prompt.modulate.a = 0.78 + 0.22 * (0.5 + 0.5 * sin(_t * 3.2))
	else:
		_prompt.modulate.a = 0.0
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
	if _vnext_surface != null and is_instance_valid(_vnext_surface):
		if _vnext_surface.handle_input(event):
			get_viewport().set_input_as_handled()
		return
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
		if event.is_action_pressed("confirm"):
			_start()
			get_viewport().set_input_as_handled()
		return
	if _story_panel != null and _story_panel.visible:
		if event.is_action_pressed("pause"):
			_close_story_selector()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("confirm"):
			_story_panel.confirm_selection()
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
	var weekly_preview := "WEEK %s // %s // %s" % [Game.week_id(), Game.weekly_mutator_title(), Game.weekly_mutator_description()] if size.x < 760.0 else "WEEK W9999 // LOCAL DETERMINISTIC // SWIFT DAEMONS // DAEMONS MOVE +20% // BEST 0000000 // LAST 0000000"
	var story_preview := "STORY // MACOS ACT // Mac::MODERN // 4/15 CLEAR" if size.x < 760.0 else "STORY // FIXED DIFFICULTY CURVE // MACOS ACT // CURRENT Mac::MODERN // 4/15 STAGES CLEAR"
	for text in [
		story_preview,
		weekly_preview,
		"CLASSIC // ENDLESS WAVES // HIGH SCORE 0000000",
		"PRACTICE // ENDLESS RECORDS AND ACHIEVEMENTS OFF",
	]:
		if text.length() > longest.length():
			longest = text
	# Measure against the spec's real annotation column (shell margins + gutter).
	var side := TacticalUIHelper.frame_margins(size).x + MenuChromeKitScript.GUTTER
	var info_width: float = maxf(size.x - side * 2.0, 0.0)
	var height_limit := 24.0 if size.x < 760.0 else 44.0
	out.append({"id": "mode_info", "fits": TacticalUI.wrapped_height(mono, longest, info_width, 12) <= height_limit})
	return out

extends RefCounted

## Arena state-panel kit: pause / terminal / game-over builders and panel rect
## math. Functions are moved verbatim from src/arena/arena.gd; Arena-owned
## state and non-moved calls are prefixed with `a.` (plan G5). Untyped owner
## reference avoids a preload cycle. No behavior changes.

var a


func _init(arena) -> void:
	a = arena

func _panel_viewport_height() -> float:
	return maxf(a.get_viewport_rect().size.y, 1.0)

func panel_scale_for_height(viewport_height: float = -1.0) -> float:
	var height := _panel_viewport_height() if viewport_height <= 0.0 else viewport_height
	return clampf((height - a.PANEL_SAFE_MARGIN * 2.0) / a.PANEL_CONTENT_HEIGHT, 0.45, 1.0)

func panel_control_rect(design_top: float, control_height: float, viewport_height: float = -1.0) -> Rect2:
	var height := _panel_viewport_height() if viewport_height <= 0.0 else viewport_height
	var scale := panel_scale_for_height(height)
	var scaled_height := control_height * scale
	var top: float = height * 0.5 + (design_top - a.PANEL_REFERENCE_HEIGHT * 0.5) * scale
	var max_top := maxf(a.PANEL_SAFE_MARGIN, height - a.PANEL_SAFE_MARGIN - scaled_height)
	top = clampf(top, a.PANEL_SAFE_MARGIN, max_top)
	return Rect2(0.0, top, 0.0, scaled_height)

func _build_pause_panel() -> void:
	a._pause_panel = _make_panel("pause")
	a._pause_title = _make_label("PAUSED", 42, Balance.COL_TEXT)
	a._pause_panel.add_child(a._pause_title)
	a._pause_info = _make_label(a.PAUSE_INFO_DEFAULT, 13, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.55))
	a._pause_panel.add_child(a._pause_info)
	a._pause_stats = _make_label("", 14, Color(Balance.COL_MOTE.r, Balance.COL_MOTE.g, Balance.COL_MOTE.b, 0.85))
	a._pause_panel.add_child(a._pause_stats)
	var b_resume := _make_button("RESUME", 288)
	b_resume.pressed.connect(func() -> void:
		a._set_paused(false)
	)
	a._pause_panel.add_child(b_resume)
	a._pause_buttons.append(b_resume)
	var b_restart := _make_button("RESTART", 334)
	b_restart.pressed.connect(func() -> void:
		a._set_paused(false)
		a._restart_current_run()
	)
	a._pause_panel.add_child(b_restart)
	a._pause_buttons.append(b_restart)
	var b_terminal := _make_button("OPEN TERMINAL", 380)
	b_terminal.pressed.connect(_open_terminal)
	a._pause_panel.add_child(b_terminal)
	a._pause_buttons.append(b_terminal)
	var b_menu := _make_button("ABANDON PROCESS", 500)
	b_menu.pressed.connect(a._request_abandon_confirmation)
	a._pause_panel.add_child(b_menu)
	a._pause_buttons.append(b_menu)
	var sfx_row := _make_volume_row("SFX", Sfx.sfx_vol, 426.0, func(v: float) -> void:
		Sfx.set_sfx_vol(v)
	)
	a._pause_panel.add_child(sfx_row)
	a._pause_volume_rows.append(sfx_row)
	var music_row := _make_volume_row("MUSIC", Sfx.music_vol, 464.0, func(v: float) -> void:
		Sfx.set_music_vol(v)
	)
	a._pause_panel.add_child(music_row)
	a._pause_volume_rows.append(music_row)
	_layout_pause_panel()

func _place_pause_control(control: Control, rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position
	control.size = rect.size
	control.scale = Vector2.ONE
	control.remove_meta("panel_design_top")
	control.remove_meta("panel_control_height")

func _layout_pause_panel() -> void:
	if a._pause_panel == null or not is_instance_valid(a._pause_panel) or a._pause_buttons.size() != 4:
		return
	var layout: Dictionary = a.TacticalStateSurfaceHelper.pause_layout(a.get_viewport_rect().size)
	var scale: float = float(layout["scale"])
	_place_pause_control(a._pause_title, layout["title"])
	_place_pause_control(a._pause_stats, layout["stats"])
	_place_pause_control(a._pause_info, layout["shortcuts"])
	a._pause_title.add_theme_font_size_override("font_size", maxi(30, int(round(42.0 * scale))))
	a._pause_stats.add_theme_font_size_override("font_size", maxi(11, int(round(14.0 * scale))))
	a._pause_info.add_theme_font_size_override("font_size", maxi(9, int(round(12.0 * scale))))
	var actions: Array = layout["actions"]
	for index in a._pause_buttons.size():
		_place_pause_control(a._pause_buttons[index], actions[index])
		a._pause_buttons[index].add_theme_font_size_override("font_size", maxi(14, int(round(18.0 * scale))))
	var volume: Rect2 = layout["volume"]
	var row_gap := 4.0 * scale
	var row_height := (volume.size.y - row_gap) * 0.5
	for index in a._pause_volume_rows.size():
		var row_rect := Rect2(volume.position + Vector2(12.0 * scale, index * (row_height + row_gap)), Vector2(volume.size.x - 24.0 * scale, row_height))
		_place_pause_control(a._pause_volume_rows[index], row_rect)

func _build_terminal_panel() -> void:
	var terminal_script: Script = load("res://src/ui/terminal_panel.gd")
	if terminal_script == null:
		return
	a._terminal_panel = terminal_script.new()
	a._terminal_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	a._terminal_panel.set("arena", a)
	a._terminal_panel.visible = false
	var layer := CanvasLayer.new()
	layer.layer = 66
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(a._terminal_panel)
	a.add_child(layer)

func _open_terminal() -> void:
	if a._terminal_panel == null or a._state != "play" or not a.get_tree().paused:
		return
	a._pause_panel.visible = false
	a._terminal_panel.call("open_terminal")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play("ui", 1.1, -6.0)

func _close_terminal() -> void:
	if a._terminal_panel != null and is_instance_valid(a._terminal_panel):
		a._terminal_panel.visible = false
	if a._pause_panel != null and is_instance_valid(a._pause_panel) and a._state == "play" and a.get_tree().paused:
		a._pause_panel.visible = true

func _make_volume_row(label_text: String, value: float, y: float, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.offset_left = -205.0
	row.offset_right = 205.0
	_center_panel_control(row, y, 36.0)
	row.add_theme_constant_override("separation", 14)
	var icon: Control = a.TacticalIconScript.new()
	icon.custom_minimum_size = Vector2(24.0, 24.0)
	icon.size = Vector2(24.0, 24.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.call("configure", "audio" if label_text == "SFX" else "music", Balance.COL_TEXT)
	row.add_child(icon)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(70, 0)
	l.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Balance.COL_TEXT)
	row.add_child(l)
	var value_label := Label.new()
	value_label.text = "%d%%" % int(round(value * 100.0))
	value_label.custom_minimum_size = Vector2(42, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	value_label.add_theme_font_size_override("font_size", 13)
	value_label.add_theme_color_override("font_color", Balance.COL_TEXT)
	row.add_child(value_label)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(100, 28)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.modulate = Color(0.55, 0.9, 1.0)
	s.value_changed.connect(func(next_value: float) -> void:
		value_label.text = "%d%%" % int(round(next_value * 100.0))
		on_change.call(next_value)
	)
	row.add_child(s)
	return row

func _build_game_over_panel() -> void:
	a._over_panel = _make_panel("game_over")
	a._over_title = _make_label("PROCESS TERMINATED", 44, Balance.COL_DANGER)
	_center_panel_control(a._over_title, 132.0, 62.0)
	a._over_panel.add_child(a._over_title)
	a._over_sub = _make_label("", 14, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.55))
	_center_panel_control(a._over_sub, 186.0, 26.0)
	a._over_panel.add_child(a._over_sub)
	a._over_stats = _make_label("", 17, Balance.COL_TEXT)
	a._over_stats.visible = false
	a._over_panel.add_child(a._over_stats)
	a._over_core_stats = _make_label("", 13, Balance.COL_TEXT)
	a._over_core_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_position_game_over_stat(a._over_core_stats, false)
	a._over_panel.add_child(a._over_core_stats)
	a._over_run_stats = _make_label("", 13, Balance.COL_TEXT)
	a._over_run_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_position_game_over_stat(a._over_run_stats, true)
	a._over_panel.add_child(a._over_run_stats)
	var heatmap_script: Script = load("res://src/ui/death_heatmap_view.gd")
	if heatmap_script != null:
		a._over_heatmap = heatmap_script.new()
		a._over_heatmap.set_anchors_preset(Control.PRESET_FULL_RECT)
		a._over_panel.add_child(a._over_heatmap)
	a._over_primary = _make_button("REBOOT  [ENTER]", 500)
	_position_game_over_button(a._over_primary, false)
	a._over_primary.pressed.connect(a._handle_over_primary)
	a._over_panel.add_child(a._over_primary)
	a._over_menu = _make_button("ABANDON PROCESS  [ESC]", 500)
	_position_game_over_button(a._over_menu, true)
	a._over_menu.pressed.connect(Game.to_menu)
	a._over_panel.add_child(a._over_menu)

func _make_panel(kind: String = "pause") -> Control:
	var p := Control.new()
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.visible = false
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.012, 0.03, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(dim)
	var surface: TacticalStateSurface = a.TacticalStateSurfaceHelper.new()
	surface.set_anchors_preset(Control.PRESET_FULL_RECT)
	surface.configure(kind)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(surface)
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(p)
	if kind == "pause":
		var input_router: Node = a.PauseInputRouterScript.new()
		input_router.arena = a
		layer.add_child(input_router)
	a.add_child(layer)
	return p

func _make_button(txt: String, y: float) -> Button:
	var b := Button.new()
	b.text = txt
	b.flat = false
	b.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Balance.COL_TEXT)
	b.add_theme_color_override("font_hover_color", Balance.COL_PLAYER)
	b.add_theme_color_override("font_pressed_color", Balance.COL_PLAYER_HOT)
	b.add_theme_color_override("font_focus_color", Balance.COL_TEXT)
	var accent := Balance.COL_DANGER if txt.contains("ABANDON") else Balance.COL_PLAYER
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(accent.r, accent.g, accent.b, 0.0)
	normal.border_color = Color(accent.r, accent.g, accent.b, 0.0)
	normal.set_border_width_all(0)
	normal.set_corner_radius_all(0)
	normal.content_margin_left = 54.0
	normal.content_margin_right = 18.0
	b.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.08)
	hover.border_color = Color(accent.r, accent.g, accent.b, 0.0)
	hover.set_border_width_all(0)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.anchor_left = 0.5
	b.anchor_right = 0.5
	b.offset_left = -230.0
	b.offset_right = 230.0
	_center_panel_control(b, y, 40.0)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	var frame: Control = a.TacticalChromeScript.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.z_index = 1
	b.add_child(frame)
	frame.call("configure_control", accent, 0.025)
	var icon_kind := "warning" if txt.contains("ABANDON") else ("terminal" if txt.contains("TERMINAL") else ("restart" if txt.contains("RESTART") else "resume"))
	var icon: Control = a.TacticalIconScript.new()
	icon.position = Vector2(12.0, 4.0)
	icon.size = Vector2(32.0, 32.0)
	icon.z_index = 2
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	icon.call("configure", icon_kind, accent)
	return b

func _position_game_over_button(button: Button, right_side: bool) -> void:
	var viewport: Vector2 = a.get_viewport_rect().size
	var panel: Rect2 = a.TacticalStateSurfaceHelper.panel_rect_for_viewport(viewport, "game_over")
	var gap := 18.0
	var button_width := maxf((panel.size.x - 56.0 - gap) * 0.5, 120.0)
	var x := panel.position.x + 28.0 + (button_width + gap if right_side else 0.0)
	button.offset_left = x - viewport.x * 0.5
	button.offset_right = button.offset_left + button_width

func _position_game_over_stat(label: Label, right_side: bool) -> void:
	var side_offset := 408.0 if right_side else 0.0
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.offset_left = -375.0 + side_offset
	label.offset_right = -35.0 + side_offset
	_center_panel_control(label, 320.0, 180.0)

func state_panel_rect(viewport: Vector2, design_top: float = 0.0, control_size: Vector2 = Vector2.ZERO) -> Rect2:
	var kind := "game_over" if control_size.x > 700.0 else "pause"
	return a.TacticalStateSurfaceHelper.panel_rect_for_viewport(viewport, kind)

func state_action_rects(viewport: Vector2, count: int) -> Array[Rect2]:
	var kind := "game_over" if count <= 2 else "pause"
	return a.TacticalStateSurfaceHelper.action_rects_for_viewport(viewport, kind, count)

func pause_action_labels() -> Array[String]:
	return ["RESUME", "RESTART", "OPEN TERMINAL", "ABANDON PROCESS"]

func pause_action_icon_kinds() -> Array[String]:
	var result: Array[String] = []
	if a._pause_panel == null or not is_instance_valid(a._pause_panel):
		return result
	for child in a._pause_panel.get_children():
		if not child is Button:
			continue
		for icon in child.get_children():
			if icon.has_method("icon_kind"):
				result.append(str(icon.call("icon_kind")))
				break
	return result

func handle_pause_input(event: InputEvent) -> bool:
	if not a.get_tree().paused or not event.is_action_pressed("pause"):
		return false
	if a._terminal_panel != null and is_instance_valid(a._terminal_panel) and a._terminal_panel.visible:
		_close_terminal()
		return true
	if a._patch_open:
		if a._vnext_patch_mode:
			if event.is_action_pressed("pause"):
				a._close_vnext_patch()
				return true
			return false
		return true
	if a._state == "play":
		a._set_paused(false)
		return true
	return false

func game_over_action_labels() -> Array[String]:
	return ["REBOOT", "ABANDON PROCESS"]

func _make_label(txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	var font: Font = load("res://assets/fonts/Orbitron.ttf") if size >= 24 else load("res://assets/fonts/ShareTechMono.ttf")
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.offset_left = 0.0
	l.offset_right = 0.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _center_panel_control(control: Control, design_top: float, control_height: float, viewport_height: float = -1.0) -> void:
	var height := _panel_viewport_height() if viewport_height <= 0.0 else viewport_height
	var scale := panel_scale_for_height(height)
	var rect := panel_control_rect(design_top, control_height, height)
	control.anchor_top = 0.5
	control.anchor_bottom = 0.5
	control.offset_top = rect.position.y - height * 0.5
	control.offset_bottom = control.offset_top + control_height
	control.scale = Vector2(scale, scale)
	control.set_meta("panel_design_top", design_top)
	control.set_meta("panel_control_height", control_height)

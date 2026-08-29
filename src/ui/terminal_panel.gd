class_name TerminalPanel
extends Control

const TacticalStateSurfaceHelper = preload("res://src/ui/tactical_state_surface.gd")

var arena: Node
var _surface: Control
var _panel: PanelContainer
var _output: RichTextLabel
var _input: LineEdit
var _header_status: Label
var _system_status: Label
var _command_count := 0
var _cursor_t := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()

func _process(delta: float) -> void:
	_cursor_t += delta
	if _input != null and is_instance_valid(_input):
		_input.caret_blink = fmod(_cursor_t, 1.0) < 0.72

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _panel != null and is_instance_valid(_panel):
		_layout_panel()

func open_terminal() -> void:
	visible = true
	_cursor_t = 0.0
	_update_status()
	if _input != null and is_instance_valid(_input):
		_input.call_deferred("grab_focus")

func close_terminal() -> void:
	visible = false
	if arena != null and is_instance_valid(arena) and arena.has_method("_close_terminal"):
		arena.call("_close_terminal")

func submit_command(command: String) -> String:
	var clean := command.strip_edges()
	if clean.is_empty() or arena == null or not is_instance_valid(arena):
		return ""
	var result := str(arena.call("execute_terminal_command", clean))
	_command_count += 1
	_append_output("$ " + clean + "\n" + result)
	_update_status()
	if clean.to_lower() == "rm -rf /":
		visible = false
	return result

func output_text() -> String:
	return _output.text if _output != null and is_instance_valid(_output) else ""

func workstation_rect(viewport: Vector2) -> Rect2:
	return TacticalStateSurfaceHelper.panel_rect_for_viewport(viewport, "terminal")

func status_snapshot() -> Dictionary:
	return {
		"tty": "TTY0",
		"paused": true,
		"command_count": _command_count,
		"prompt_visible": _input != null and is_instance_valid(_input) and _input.visible,
	}

func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.005, 0.008, 0.02, 0.9)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_surface = TacticalStateSurfaceHelper.new()
	_surface.set_anchors_preset(Control.PRESET_FULL_RECT)
	_surface.configure("terminal")
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_surface)
	_panel = PanelContainer.new()
	_panel.position = workstation_rect(get_viewport_rect().size).position
	_panel.size = workstation_rect(get_viewport_rect().size).size
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0.0, 40.0)
	header.add_theme_constant_override("separation", 14)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := _label("KERNEL PANIC TERMINAL // TTY0", 25, Balance.COL_TEXT)
	title_box.add_child(title)
	var hint := _label("DIAGNOSTIC WORKSTATION // INPUT LOCKED TO FROZEN RUN", 11, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.52))
	title_box.add_child(hint)
	header.add_child(title_box)
	_header_status = _label("PROCESS LINK // STABLE", 13, Balance.COL_PLAYER)
	_header_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_header_status)
	var close := _make_button("CLOSE  [ESC]", 13, Balance.COL_TEXT)
	close.custom_minimum_size = Vector2(112.0, 34.0)
	close.pressed.connect(close_terminal)
	header.add_child(close)
	box.add_child(header)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	var history := VBoxContainer.new()
	history.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output = RichTextLabel.new()
	_output.bbcode_enabled = false
	_output.fit_content = false
	_output.scroll_active = true
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.add_theme_font_override("normal_font", load("res://assets/fonts/ShareTechMono.ttf"))
	_output.add_theme_font_size_override("normal_font_size", 16)
	_output.add_theme_color_override("default_color", Balance.COL_PLAYER)
	_output.text = _initial_output()
	history.add_child(_output)
	body.add_child(history)

	var side := VBoxContainer.new()
	var compact := get_viewport_rect().size.x < 760.0
	var side_width := 118.0 if compact else 340.0
	side.custom_minimum_size = Vector2(side_width, 0.0)
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 8)
	side.add_child(_label("COMMAND INDEX", 13 if not compact else 10, Balance.COL_PLAYER))
	var command_list := VBoxContainer.new()
	command_list.add_theme_constant_override("separation", 4)
	var command_defs := [
		["help", "available commands"],
		["top", "process snapshot"],
		["dmesg", "run event log"],
		["man <enemy>", "tactical reference"],
		["sudo heal", "one-use recovery"],
		["rm -rf /", "abort process"],
	]
	var command_list_margin := MarginContainer.new()
	command_list_margin.add_theme_constant_override("margin_left", 26)
	command_list_margin.add_theme_constant_override("margin_right", 30)
	command_list_margin.add_child(command_list)
	for command_def in command_defs:
		var command_row := HBoxContainer.new()
		command_row.custom_minimum_size = Vector2(0.0, 30.0 if not compact else 25.0)
		var command_label := _label(str(command_def[0]), 12 if not compact else 9, Balance.COL_TEXT)
		command_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		command_label.clip_text = true
		command_row.add_child(command_label)
		var description := _label(str(command_def[1]), 9 if not compact else 8, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.72))
		description.custom_minimum_size = Vector2(128.0 if not compact else 72.0, 0.0)
		description.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		description.clip_text = true
		command_row.add_child(description)
		command_list.add_child(command_row)
	side.add_child(command_list_margin)
	var side_spacer := Control.new()
	side_spacer.custom_minimum_size = Vector2(0.0, 36.0 if not compact else 12.0)
	side.add_child(side_spacer)
	side.add_child(_label("SYSTEM STATUS", 13 if not compact else 10, Balance.COL_PLAYER))
	_system_status = _label("TTY0 / PAUSED\nPROCESS LINK // STABLE\nINPUT // READY\nPROMPT // ACTIVE", 12 if not compact else 9, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.72))
	side.add_child(_system_status)
	var side_margin := MarginContainer.new()
	side_margin.custom_minimum_size = Vector2(side_width + 24.0, 0.0)
	side_margin.add_theme_constant_override("margin_left", 18)
	side_margin.add_theme_constant_override("margin_right", 6)
	side_margin.add_child(side)
	body.add_child(side_margin)
	box.add_child(body)

	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 44.0)
	row.add_theme_constant_override("separation", 6)
	var prompt_frame := PanelContainer.new()
	prompt_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_frame.custom_minimum_size = Vector2(0.0, 44.0)
	prompt_frame.add_theme_stylebox_override("panel", _outline_style(Color(Balance.COL_PLAYER.r, Balance.COL_PLAYER.g, Balance.COL_PLAYER.b, 0.72)))
	var prompt_content := HBoxContainer.new()
	prompt_content.add_theme_constant_override("separation", 6)
	var prompt := _label("kernel@panic:~$", 17, Balance.COL_PLAYER)
	prompt.custom_minimum_size = Vector2(170.0, 34.0)
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_content.add_child(prompt)
	_input = LineEdit.new()
	_input.placeholder_text = "enter diagnostic command"
	_input.custom_minimum_size = Vector2(0.0, 34.0)
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	_input.add_theme_font_size_override("font_size", 16)
	_input.add_theme_color_override("font_color", Balance.COL_TEXT)
	_input.add_theme_color_override("caret_color", Balance.COL_PLAYER)
	_input.add_theme_stylebox_override("normal", _input_style())
	_input.add_theme_stylebox_override("focus", _input_style())
	_input.text_submitted.connect(_on_command_submitted)
	prompt_content.add_child(_input)
	prompt_frame.add_child(prompt_content)
	row.add_child(prompt_frame)
	var run := Button.new()
	run.text = "RUN [ENTER]"
	run.flat = false
	run.custom_minimum_size = Vector2(150.0, 34.0)
	run.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	run.add_theme_font_size_override("font_size", 15)
	run.add_theme_color_override("font_color", Balance.COL_PLAYER)
	run.add_theme_stylebox_override("normal", _outline_style(Color(Balance.COL_PLAYER.r, Balance.COL_PLAYER.g, Balance.COL_PLAYER.b, 0.72)))
	run.add_theme_stylebox_override("hover", _outline_style(Balance.COL_PLAYER))
	run.pressed.connect(_submit_input)
	row.add_child(run)
	box.add_child(row)
	var shortcuts := _label("↑↓ HISTORY        TAB AUTOCOMPLETE        ESC CLOSE", 11, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.52))
	shortcuts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shortcuts.custom_minimum_size = Vector2(0.0, 18.0)
	box.add_child(shortcuts)
	_update_status()

func _on_command_submitted(_text: String) -> void:
	_submit_input()

func _submit_input() -> void:
	if _input == null or not is_instance_valid(_input):
		return
	var command := _input.text.strip_edges()
	if command.is_empty():
		return
	_input.clear()
	submit_command(command)
	if visible:
		_input.grab_focus()

func _append_output(text: String) -> void:
	if _output == null or not is_instance_valid(_output):
		return
	_output.append_text(text + "\n")
	_output.scroll_to_line(_output.get_line_count())

func _initial_output() -> String:
	var lines: Array[String] = ["KERNEL PANIC TTY READY", "", "kernel@panic:~$ top"]
	if arena != null and is_instance_valid(arena) and arena.has_method("_terminal_top"):
		lines.append_array(str(arena.call("_terminal_top")).split("\n"))
	var events: Array = Game.dmesg_lines(6)
	if not events.is_empty():
		lines.append("")
		for event in events:
			lines.append(str(event))
	lines.append("")
	lines.append("Type 'help' for available commands.")
	return "\n".join(lines) + "\n"

func _panel_size() -> Vector2:
	return workstation_rect(get_viewport_rect().size).size

func _panel_position() -> Vector2:
	return workstation_rect(get_viewport_rect().size).position

func _layout_panel() -> void:
	var rect := workstation_rect(get_viewport_rect().size)
	_panel.position = rect.position
	_panel.size = rect.size

func _update_status() -> void:
	if _header_status != null and is_instance_valid(_header_status):
		_header_status.text = "PROCESS LINK // FROZEN" if is_inside_tree() and get_tree().paused else "PROCESS LINK // STANDBY"
	if _system_status != null and is_instance_valid(_system_status):
		var cycle := int(Game.wave)
		_system_status.text = "TTY0 / PAUSED\nCYCLE %02d\nINPUT // READY\nPROMPT // ACTIVE\nCOMMANDS // %02d" % [cycle, _command_count]

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 16.0
	return style

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _input_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.005, 0.015, 0.03, 0.0)
	style.set_border_width_all(0)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	return style

func _outline_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.005, 0.015, 0.03, 0.28)
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	return style

func _make_button(text: String, size: int, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", Balance.COL_PLAYER_HOT)
	return button

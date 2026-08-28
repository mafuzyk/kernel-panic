class_name TerminalPanel
extends Control

var arena: Node
var _panel: PanelContainer
var _output: RichTextLabel
var _input: LineEdit
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
		_panel.position = _panel_position()
		_panel.size = _panel_size()

func open_terminal() -> void:
	visible = true
	_cursor_t = 0.0
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
	_append_output("$ " + clean + "\n" + result)
	if clean.to_lower() == "rm -rf /":
		visible = false
	return result

func output_text() -> String:
	return _output.text if _output != null and is_instance_valid(_output) else ""

func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.005, 0.008, 0.02, 0.9)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.position = _panel_position()
	_panel.size = _panel_size()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	var title := _label("KERNEL PANIC TERMINAL // TTY0", 20, Balance.COL_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(title)
	var hint := _label("TYPE help // ENTER EXECUTES // ESC CLOSES", 11, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.55))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(hint)
	_output = RichTextLabel.new()
	_output.bbcode_enabled = false
	_output.fit_content = false
	_output.scroll_active = true
	_output.custom_minimum_size = Vector2(0.0, 300.0)
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.add_theme_font_override("normal_font", load("res://assets/fonts/ShareTechMono.ttf"))
	_output.add_theme_font_size_override("normal_font_size", 13)
	_output.add_theme_color_override("default_color", Balance.COL_PLAYER)
	_output.text = "KERNEL PANIC TTY READY\nType 'help' for available commands.\n"
	box.add_child(_output)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var prompt := _label("$", 15, Balance.COL_MOTE)
	prompt.custom_minimum_size = Vector2(16.0, 34.0)
	row.add_child(prompt)
	_input = LineEdit.new()
	_input.placeholder_text = "command"
	_input.custom_minimum_size = Vector2(0.0, 34.0)
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	_input.add_theme_font_size_override("font_size", 14)
	_input.add_theme_color_override("font_color", Balance.COL_TEXT)
	_input.add_theme_color_override("caret_color", Balance.COL_PLAYER)
	_input.text_submitted.connect(_on_command_submitted)
	row.add_child(_input)
	var run := Button.new()
	run.text = "RUN"
	run.flat = true
	run.custom_minimum_size = Vector2(70.0, 34.0)
	run.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	run.add_theme_font_size_override("font_size", 13)
	run.add_theme_color_override("font_color", Balance.COL_PLAYER)
	run.pressed.connect(_submit_input)
	row.add_child(run)
	box.add_child(row)
	var close := Button.new()
	close.text = "CLOSE TERMINAL // ESC"
	close.flat = true
	close.custom_minimum_size = Vector2(0.0, 32.0)
	close.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	close.add_theme_font_size_override("font_size", 13)
	close.add_theme_color_override("font_color", Balance.COL_TEXT)
	close.add_theme_color_override("font_hover_color", Balance.COL_PLAYER_HOT)
	close.pressed.connect(close_terminal)
	box.add_child(close)

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

func _panel_size() -> Vector2:
	var viewport := get_viewport_rect().size
	return Vector2(minf(820.0, maxf(viewport.x - 32.0, 280.0)), minf(560.0, maxf(viewport.y - 32.0, 360.0)))

func _panel_position() -> Vector2:
	var viewport := get_viewport_rect().size
	var panel_size := _panel_size()
	return Vector2((viewport.x - panel_size.x) * 0.5, (viewport.y - panel_size.y) * 0.5)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.008, 0.018, 0.04, 0.98)
	style.border_color = Color(Balance.COL_PLAYER.r, Balance.COL_PLAYER.g, Balance.COL_PLAYER.b, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

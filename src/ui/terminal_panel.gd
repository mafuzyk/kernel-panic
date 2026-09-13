class_name TerminalPanel
extends Control

var arena: Node
var _panel: PanelContainer
var _output: RichTextLabel
var _input: LineEdit
var _header_status: Label
var _system_status: Label
var _title: Label
var _body: BoxContainer
var _side: VBoxContainer
var _shortcuts: Label
var _run_button: Button
var _prompt_label: Label
var _command_count := 0
var _cursor_t := 0.0
var _history: Array[String] = []
var _history_idx := -1
var _draft := ""

## Comandos completáveis por TAB. "man " leva espaço para seguir o alvo.
const TERMINAL_COMMANDS := ["help", "top", "dmesg", "man ", "sudo heal", "rm -rf /"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.shared()
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
	_history.append(clean)
	if _history.size() > 50:
		_history.pop_front()
	_history_idx = -1
	_draft = ""
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
	var narrow := Design.breakpoint_for(viewport.x) in ["compact", "medium"]
	var side_margin := float(Design.SPACE_XL if narrow else Design.SPACE_3XL)
	var vertical_margin := float(Design.SPACE_XL if viewport.y < 700.0 else Design.SPACE_2XL)
	var width := minf(1180.0, maxf(viewport.x - side_margin * 2.0, 280.0))
	var height := minf(720.0, maxf(viewport.y - vertical_margin * 2.0, 320.0))
	return Rect2((viewport.x - width) * 0.5, (viewport.y - height) * 0.5, width, height)

func status_snapshot() -> Dictionary:
	return {
		"tty": "TTY0",
		"paused": true,
		"command_count": _command_count,
		"prompt_visible": _input != null and is_instance_valid(_input) and _input.visible,
	}

func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "TerminalDim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Design.alpha(Design.SURFACE, 0.96)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.position = workstation_rect(get_viewport_rect().size).position
	_panel.size = workstation_rect(get_viewport_rect().size).size
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_style(Design.SPACE_LG))
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Design.SPACE_MD)
	_panel.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", Design.SPACE_LG)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_child(ScreenKit.mono("KERNEL PANIC // TTY0", Design.TEXT_MICRO, Design.ACCENT))
	_title = ScreenKit.grot("TERMINAL", Design.TEXT_HEADING, Design.WEIGHT_BLACK, Design.TEXT_PRIMARY)
	_title.name = "TerminalTitle"
	title_box.add_child(_title)
	var hint := ScreenKit.mono("DIAGNOSTIC WORKSTATION // INPUT LOCKED TO FROZEN RUN", Design.TEXT_MICRO, Design.TEXT_MUTED)
	title_box.add_child(hint)
	header.add_child(title_box)
	_header_status = ScreenKit.mono(tr("TERM_LINK") + " // " + tr("TERM_STATE_STABLE"), Design.TEXT_CAPTION, Design.ACCENT)
	_header_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_header_status)
	var close := _make_button(tr("TERM_CLOSE"), Design.TEXT_CAPTION, Design.TEXT_SECONDARY)
	close.custom_minimum_size = Vector2(112.0, Design.CLICK_TARGET_MIN)
	close.pressed.connect(close_terminal)
	header.add_child(close)
	box.add_child(header)
	ScreenKit.rule(box, 0.24)

	_body = BoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", Design.SPACE_XL)
	var history := VBoxContainer.new()
	history.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output = RichTextLabel.new()
	_output.bbcode_enabled = false
	_output.fit_content = false
	_output.scroll_active = true
	_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.add_theme_font_override("normal_font", Design.FONT_MONO)
	_output.add_theme_font_size_override("normal_font_size", Design.TEXT_BODY)
	_output.add_theme_color_override("default_color", Design.TEXT_SECONDARY)
	_output.add_theme_stylebox_override("normal", _output_style())
	_output.text = _initial_output()
	history.add_child(_output)
	_body.add_child(history)

	var side_wrap := HBoxContainer.new()
	side_wrap.add_theme_constant_override("separation", Design.SPACE_LG)
	side_wrap.custom_minimum_size.x = 320.0
	side_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var side_rule := ColorRect.new()
	side_rule.color = Design.alpha(Design.TEXT_PRIMARY, 0.18)
	side_rule.custom_minimum_size = Vector2(1.0, 0.0)
	side_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side_wrap.add_child(side_rule)
	_side = VBoxContainer.new()
	_side.add_theme_constant_override("separation", Design.SPACE_SM)
	_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_wrap.add_child(_side)
	var command_title := ScreenKit.mono(tr("TERM_CMD_INDEX"), Design.TEXT_CAPTION, Design.ACCENT)
	_side.add_child(command_title)
	var command_list := VBoxContainer.new()
	command_list.add_theme_constant_override("separation", Design.SPACE_XS)
	var command_defs := [
		["help", tr("TERM_DESC_HELP")],
		["top", tr("TERM_DESC_TOP")],
		["dmesg", tr("TERM_DESC_DMESG")],
		["man <enemy>", tr("TERM_DESC_MAN")],
		["sudo heal", tr("TERM_DESC_SUDO")],
		["rm -rf /", tr("TERM_DESC_RM")],
	]
	for command_def in command_defs:
		var command_row := HBoxContainer.new()
		command_row.custom_minimum_size.y = 28.0
		var command_label := ScreenKit.mono(str(command_def[0]), Design.TEXT_CAPTION, Design.TEXT_PRIMARY)
		command_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		command_label.clip_text = true
		command_row.add_child(command_label)
		var description := ScreenKit.mono(str(command_def[1]), Design.TEXT_MICRO, Design.TEXT_MUTED)
		description.custom_minimum_size.x = 128.0
		description.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		description.clip_text = true
		command_row.add_child(description)
		command_list.add_child(command_row)
	_side.add_child(command_list)
	ScreenKit.grow_v(_side)
	ScreenKit.rule(_side, 0.16)
	_side.add_child(ScreenKit.mono("SYSTEM STATUS", Design.TEXT_CAPTION, Design.ACCENT))
	_system_status = ScreenKit.mono(_status_block(false, 0), Design.TEXT_CAPTION, Design.TEXT_MUTED)
	_side.add_child(_system_status)
	_body.add_child(side_wrap)
	box.add_child(_body)
	ScreenKit.rule(box, 0.24)

	var row := HBoxContainer.new()
	row.custom_minimum_size.y = Design.CLICK_TARGET_MIN
	row.add_theme_constant_override("separation", Design.SPACE_MD)
	_prompt_label = ScreenKit.mono("kernel@panic:~$", Design.TEXT_SUBHEAD, Design.ACCENT)
	_prompt_label.custom_minimum_size.x = 170.0
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_prompt_label)
	_input = LineEdit.new()
	_input.placeholder_text = tr("TERM_PLACEHOLDER")
	_input.custom_minimum_size.y = Design.CLICK_TARGET_MIN
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.add_theme_font_override("font", Design.FONT_MONO)
	_input.add_theme_font_size_override("font_size", Design.TEXT_BODY)
	_input.add_theme_color_override("font_color", Design.TEXT_PRIMARY)
	_input.add_theme_color_override("caret_color", Design.ACCENT)
	_input.add_theme_stylebox_override("normal", _input_style(false))
	_input.add_theme_stylebox_override("focus", _input_style(true))
	_input.text_submitted.connect(_on_command_submitted)
	_input.gui_input.connect(_on_input_gui)
	row.add_child(_input)
	_run_button = _make_button(tr("TERM_RUN"), Design.TEXT_BODY, Design.ACCENT)
	_run_button.custom_minimum_size = Vector2(150.0, Design.CLICK_TARGET_MIN)
	_run_button.pressed.connect(_submit_input)
	row.add_child(_run_button)
	box.add_child(row)
	_shortcuts = ScreenKit.mono(tr("TERM_SHORTCUTS"), Design.TEXT_MICRO, Design.TEXT_MUTED)
	_shortcuts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_shortcuts.custom_minimum_size.y = 18.0
	box.add_child(_shortcuts)
	_update_status()
	_layout_panel()

func _on_command_submitted(_text: String) -> void:
	_submit_input()

## ↑↓ percorrem o histórico, TAB completa. Prefixo vazio ou sem match único
## devolve false para preservar a navegação de foco por TAB.
func _on_input_gui(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_UP and _history_step(-1):
		_input.accept_event()
	elif key.keycode == KEY_DOWN and _history_step(1):
		_input.accept_event()
	elif key.keycode == KEY_TAB and _history_complete():
		_input.accept_event()

func _history_step(dir: int) -> bool:
	if _history.is_empty() or _input == null:
		return false
	if _history_idx < 0:
		if dir > 0:
			return false
		_draft = _input.text
		_history_idx = _history.size() - 1
	else:
		_history_idx += dir
		if _history_idx >= _history.size():
			_history_idx = -1
			_input.text = _draft
			_input.caret_column = _input.text.length()
			return true
		_history_idx = clampi(_history_idx, 0, _history.size() - 1)
	_input.text = _history[_history_idx]
	_input.caret_column = _input.text.length()
	return true

func _history_complete() -> bool:
	if _input == null:
		return false
	var prefix := _input.text
	if prefix.is_empty():
		return false
	var matches: Array[String] = []
	for cmd in TERMINAL_COMMANDS:
		if cmd.begins_with(prefix) and cmd != prefix:
			matches.append(cmd)
	if matches.is_empty():
		return false
	var common := matches[0]
	for m in matches:
		while not m.begins_with(common):
			common = common.left(common.length() - 1)
	if common.length() <= prefix.length():
		return false
	_input.text = common
	_input.caret_column = _input.text.length()
	return true

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
	var lines: Array[String] = [tr("TERM_READY"), "", "kernel@panic:~$ top"]
	if arena != null and is_instance_valid(arena) and arena.has_method("_terminal_top"):
		lines.append_array(str(arena.call("_terminal_top")).split("\n"))
	var events: Array = Game.dmesg_lines(6)
	if not events.is_empty():
		lines.append("")
		for event in events:
			lines.append(str(event))
	lines.append("")
	lines.append(tr("TERMINAL_TYPE_HELP"))
	return "\n".join(lines) + "\n"

func _panel_size() -> Vector2:
	return workstation_rect(get_viewport_rect().size).size

func _layout_panel() -> void:
	if _panel == null or not is_instance_valid(_panel):
		return
	var rect := workstation_rect(get_viewport_rect().size)
	_panel.position = rect.position
	_panel.size = rect.size
	var narrow := Design.breakpoint_for(get_viewport_rect().size.x) in ["compact", "medium"]
	_panel.add_theme_stylebox_override("panel", _panel_style(float(Design.SPACE_MD if narrow else Design.SPACE_LG)))
	if is_instance_valid(_side) and _side.get_parent() is Control:
		(_side.get_parent() as Control).visible = not narrow
	if is_instance_valid(_header_status):
		_header_status.visible = not narrow
	if is_instance_valid(_shortcuts):
		_shortcuts.visible = not narrow
	if is_instance_valid(_title):
		_title.add_theme_font_size_override("font_size", 26 if narrow else Design.TEXT_HEADING)
	if is_instance_valid(_output):
		_output.add_theme_font_size_override("normal_font_size", Design.TEXT_CAPTION if narrow else Design.TEXT_BODY)
	if is_instance_valid(_prompt_label):
		_prompt_label.custom_minimum_size.x = 100.0 if narrow else 170.0
		_prompt_label.add_theme_font_size_override("font_size", Design.TEXT_CAPTION if narrow else Design.TEXT_SUBHEAD)
	if is_instance_valid(_run_button):
		_run_button.text = tr("TERM_RUN_SHORT") if narrow else tr("TERM_RUN")
		_run_button.custom_minimum_size.x = 70.0 if narrow else 150.0

func _status_block(full: bool, cycle: int) -> String:
	var lines := [
		"TTY0 / " + tr("TERM_PAUSED"),
		tr("TERM_LINK") + " // " + tr("TERM_STATE_STABLE"),
		tr("TERM_INPUT") + " // " + tr("TERM_READY_STATE"),
		tr("TERM_PROMPT") + " // " + tr("TERM_ACTIVE"),
	]
	if full:
		lines.insert(2, tr("TERM_CYCLE") + " %02d" % cycle)
		lines.append(tr("TERM_COMMANDS") + " // %02d" % _command_count)
	return "\n".join(lines)

func _update_status() -> void:
	if _header_status != null and is_instance_valid(_header_status):
		_header_status.text = tr("TERM_LINK") + " // " + (tr("TERM_STATE_FROZEN") if is_inside_tree() and get_tree().paused else tr("TERM_STATE_STANDBY"))
	if _system_status != null and is_instance_valid(_system_status):
		var cycle := int(Game.wave)
		_system_status.text = _status_block(true, cycle)

func _panel_style(inset: float = 20.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.content_margin_left = inset
	style.content_margin_right = inset
	style.content_margin_top = inset
	style.content_margin_bottom = inset
	return style

func _output_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.content_margin_left = 10.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style

func _input_style(focused: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.border_width_bottom = int(Design.STROKE_REGULAR if focused else Design.STROKE_HAIRLINE)
	style.border_color = Design.ACCENT if focused else Design.BORDER_SUBTLE
	style.content_margin_left = Design.SPACE_SM
	style.content_margin_right = Design.SPACE_SM
	return style

func _make_button(text: String, size: int, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", Design.FONT_MONO)
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", Design.ACCENT_HOT)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	normal.set_border_width_all(0)
	var hover := normal.duplicate()
	hover.bg_color = Design.alpha(Design.TEXT_PRIMARY, 0.08)
	var focus := normal.duplicate()
	focus.set_border_width_all(int(Design.FOCUS_RING_WIDTH))
	focus.border_color = Design.FOCUS_RING_COLOR
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", focus)
	return button

func content_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for node in [_title, _header_status, _output, _side, _prompt_label, _input, _run_button, _shortcuts]:
		if node != null and is_instance_valid(node) and node.is_visible_in_tree():
			out.append(Rect2(node.global_position - global_position, node.size))
	return out

func text_overflow_report() -> Array:
	var mono: Font = Design.FONT_MONO
	var out: Array = []
	var workstation := workstation_rect(Vector2(size.x, size.y))
	out.append({"id": "workstation_inside_viewport", "fits": Rect2(Vector2.ZERO, Vector2(size.x, size.y)).encloses(workstation)})
	var longest := ""
	for line in _initial_output().split("\n"):
		if line.length() > longest.length():
			longest = line
	out.append({"id": "terminal_output_wraps", "fits": TacticalUI.wrapped_height(mono, longest, maxf(workstation.size.x - 48.0, 0.0), 13) > 0.0})
	return out

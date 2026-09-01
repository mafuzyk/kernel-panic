class_name VNextTerminalSurface
extends Control

const Context = preload("res://src/ui/vnext/ui_context.gd")
const Tokens = preload("res://src/ui/vnext/ui_tokens.gd")
const TacticalUI = preload("res://src/ui/tactical_ui.gd")
const Orbitron: Font = preload("res://assets/fonts/Orbitron.ttf")
const ShareTechMono: Font = preload("res://assets/fonts/ShareTechMono.ttf")
const COMPLETIONS := ["help", "top", "dmesg", "man ", "sudo heal", "rm -rf /"]

signal action_requested(action_id: String, payload: Dictionary)

var context: RefCounted
var snapshot := {}
var _layout := {}
var _semantic := {}
var _input: LineEdit
var _close: Button
var _run: Button
var _history: Array[String] = []
var _history_index := -1
var _draft := ""
var _output := ""
var _dispatching := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_input = LineEdit.new()
	_input.name = "Prompt"
	_input.focus_mode = Control.FOCUS_ALL
	_input.mouse_filter = Control.MOUSE_FILTER_STOP
	_input.add_theme_font_override("font", ShareTechMono)
	_input.add_theme_font_size_override("font_size", 16)
	_input.gui_input.connect(_on_input)
	_input.text_submitted.connect(_submit)
	add_child(_input)
	_run = Button.new()
	_run.text = "RUN [ENTER]"
	_run.focus_mode = Control.FOCUS_ALL
	_run.pressed.connect(_submit.bind(""))
	add_child(_run)
	_close = Button.new()
	_close.text = "CLOSE [ESC]"
	_close.focus_mode = Control.FOCUS_ALL
	_close.pressed.connect(_close_surface)
	add_child(_close)

func configure_adapter(next_snapshot: Dictionary, next_context: RefCounted) -> void:
	context = next_context
	snapshot = next_snapshot.duplicate(true)
	visible = bool(snapshot.get("visible", false))
	_refresh()
	if visible:
		_focus_prompt()

func show_terminal(next_snapshot: Dictionary) -> void:
	snapshot = next_snapshot.duplicate(true)
	snapshot["visible"] = true
	visible = true
	_refresh()
	_focus_prompt()

func hide_surface() -> void:
	visible = false
	_dispatching = false

func reflow_for_viewport(viewport: Vector2) -> void:
	context = Context.from_viewport(viewport, false, false, false, context.text_scale if context != null else 1.0)
	_refresh()

func layout_snapshot() -> Dictionary: return _layout.duplicate(true)
func semantic_snapshot() -> Dictionary: return _semantic.duplicate(true)
func action_regions() -> Dictionary: return _layout.get("regions", {}).duplicate(true)
func history_snapshot() -> Array[String]: return _history.duplicate()

func apply_command_result(command: String, result: String) -> void:
	snapshot["event_stream"] = "$ " + command + "\n" + result
	_refresh()

func _focus_prompt() -> void:
	if _input.is_inside_tree():
		_input.grab_focus()
	else:
		_input.call_deferred("grab_focus")

func text_overflow_report() -> Dictionary:
	var fields := {}
	var values := {
		"title": {"text": str(snapshot.get("title", "DIAGNOSTIC WORKSTATION // TTY0")), "size": 18 if context != null and context.density == "narrow" else 22},
		"event_stream": {"text": str(snapshot.get("event_stream", "EVENT STREAM // RUN FROZEN\nREADY FOR DIAGNOSTICS")), "size": 14},
		"command_index": {"text": "COMMAND INDEX\nhelp\ntop\ndmesg\nman <enemy>\nsudo heal\nrm -rf /", "size": 13},
		"status": {"text": "SYSTEM STATUS\nTTY0 / PAUSED\nINPUT // READY\nPROMPT // ACTIVE", "size": 12},
		"prompt": {"text": "", "size": 16},
		"hint": {"text": "↑↓ HISTORY        TAB COMPLETE        ESC CLOSE", "size": 11},
	}
	for id in values:
		var value := str(values[id]["text"])
		var rect: Rect2 = _layout.get("regions", {}).get(id, Rect2())
		var measured := _multiline_size(value, int(values[id]["size"]))
		fields[id] = {"text": value, "fits": measured.x <= maxf(rect.size.x - 16.0, 0.0), "measured_width": measured.x, "available_width": maxf(rect.size.x - 16.0, 0.0)}
	var overflow := false
	for field in fields.values(): overflow = overflow or not bool(field["fits"])
	return {"has_overflow": overflow, "has_unmeasured_fields": false, "fields": fields}

func _multiline_size(value: String, font_size: int) -> Vector2:
	var widest := 0.0
	var height := 0.0
	for line in value.split("\n"):
		var measured := ShareTechMono.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		widest = maxf(widest, measured.x)
		height += measured.y
	return Vector2(widest, height)

func handle_input(event: InputEvent) -> bool:
	if not visible: return false
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		var key := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
		if key == KEY_ESCAPE:
			_close_surface()
			return true
	return false

func _on_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	var key_event := event as InputEventKey
	var key := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
	if key == KEY_ESCAPE:
		_input.accept_event()
		_close_surface()
	elif key == KEY_UP:
		_input.accept_event(); _history_previous()
	elif key == KEY_DOWN:
		_input.accept_event(); _history_next()
	elif key == KEY_TAB:
		_input.accept_event(); _autocomplete()

func _submit(_unused := "") -> void:
	var command := _input.text.strip_edges()
	if command.is_empty(): return
	if _history.is_empty() or _history.back() != command: _history.append(command)
	_history_index = -1; _draft = ""; _input.clear()
	action_requested.emit("command", {"command": command})

func _history_previous() -> void:
	if _history.is_empty(): return
	if _history_index == -1: _draft = _input.text; _history_index = _history.size() - 1
	else: _history_index = maxi(_history_index - 1, 0)
	_input.text = _history[_history_index]; _input.caret_column = _input.text.length()

func _history_next() -> void:
	if _history_index == -1: return
	if _history_index < _history.size() - 1: _history_index += 1; _input.text = _history[_history_index]
	else: _history_index = -1; _input.text = _draft; _draft = ""
	_input.caret_column = _input.text.length()

func _autocomplete() -> void:
	var matches: Array[String] = []
	for command in COMPLETIONS:
		if command.begins_with(_input.text) and command != _input.text: matches.append(command)
	if matches.size() == 1: _input.text = matches[0]; _input.caret_column = _input.text.length()

func _close_surface() -> void:
	if _dispatching: return
	_dispatching = true
	action_requested.emit("close", {})
	call_deferred("_clear_dispatching")

func _clear_dispatching() -> void: _dispatching = false

func _refresh() -> void:
	if context == null: context = Context.from_viewport(get_viewport_rect().size)
	var safe: Rect2 = context.safe_rect
	var narrow: bool = context.density == "narrow"
	var side := 142.0 if narrow else 240.0
	var panel := Rect2(safe.position + Vector2(12, 12), safe.size - Vector2(24, 24))
	var body := Rect2(panel.position + Vector2(16, 76), Vector2(maxf(panel.size.x - 32, 1), maxf(panel.size.y - 164, 1)))
	var prompt := Rect2(panel.position + Vector2(16, panel.size.y - 76), Vector2(maxf(panel.size.x - 32, 1), 42))
	var regions := {"safe":safe, "panel":panel, "title":Rect2(panel.position + Vector2(16, 18), Vector2(panel.size.x - 32, 40)), "event_stream":Rect2(body.position, Vector2(maxf(body.size.x - side - 12, 1), body.size.y)), "command_index":Rect2(Vector2(body.end.x - side, body.position.y), Vector2(side, body.size.y * 0.62)), "status":Rect2(Vector2(body.end.x - side, body.position.y + body.size.y * 0.64), Vector2(side, body.size.y * 0.36)), "prompt":prompt, "hint":Rect2(panel.position + Vector2(16, panel.size.y - 28), Vector2(panel.size.x - 32, 20))}
	if narrow:
		var event_h := body.size.y * 0.48
		var command_y := body.position.y + event_h + 12.0
		var command_h := body.size.y * 0.25
		regions["event_stream"] = Rect2(body.position, Vector2(body.size.x, event_h))
		regions["command_index"] = Rect2(Vector2(body.position.x, command_y), Vector2(body.size.x, command_h))
		regions["status"] = Rect2(Vector2(body.position.x, command_y + command_h + 12.0), Vector2(body.size.x, maxf(body.end.y - (command_y + command_h + 12.0), 1.0)))
	_layout = {"safe":safe, "regions":regions, "narrow":narrow}
	_semantic = {"paused":true, "terminal_ready":true, "focus":"prompt", "history_size":_history.size(), "status":"READY"}
	_input.position = prompt.position; _input.size = Vector2(prompt.size.x - 130, prompt.size.y); _input.visible = visible
	_run.position = Vector2(prompt.end.x - 120, prompt.position.y); _run.size = Vector2(120, prompt.size.y); _run.visible = visible
	_close.position = Vector2(panel.end.x - 118, panel.position.y + 16); _close.size = Vector2(106, 36); _close.visible = visible
	queue_redraw()

func _draw() -> void:
	if _layout.is_empty() or not visible: return
	var panel: Rect2 = _layout["regions"]["panel"]
	var points := TacticalUI.angular_points(panel, 14.0)
	draw_colored_polygon(points, Color(0.005, 0.012, 0.03, 0.98)); draw_polyline(points + PackedVector2Array([points[0]]), Tokens.role_color("player"), 1.4, true)
	var title_size := 18 if context != null and context.density == "narrow" else 22
	draw_string(Orbitron, _layout["regions"]["title"].position + Vector2(0, 28), "DIAGNOSTIC WORKSTATION // TTY0", HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Tokens.role_color("text"))
	draw_string(ShareTechMono, _layout["regions"]["event_stream"].position + Vector2(0, 22), str(snapshot.get("event_stream", "EVENT STREAM // RUN FROZEN\nREADY FOR DIAGNOSTICS")), HORIZONTAL_ALIGNMENT_LEFT, _layout["regions"]["event_stream"].size.x, 14, Tokens.role_color("player"))
	draw_string(ShareTechMono, _layout["regions"]["command_index"].position + Vector2(0, 20), "COMMAND INDEX\nhelp\ntop\ndmesg\nman <enemy>\nsudo heal\nrm -rf /", HORIZONTAL_ALIGNMENT_LEFT, _layout["regions"]["command_index"].size.x, 13, Tokens.role_color("text"))
	draw_string(ShareTechMono, _layout["regions"]["status"].position + Vector2(0, 20), "SYSTEM STATUS\nTTY0 / PAUSED\nINPUT // READY\nPROMPT // ACTIVE", HORIZONTAL_ALIGNMENT_LEFT, _layout["regions"]["status"].size.x, 12, Tokens.role_color("text"))
	draw_string(ShareTechMono, _layout["regions"]["hint"].position, "↑↓ HISTORY        TAB COMPLETE        ESC CLOSE", HORIZONTAL_ALIGNMENT_CENTER, _layout["regions"]["hint"].size.x, 11, Tokens.role_color("text"))

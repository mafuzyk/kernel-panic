class_name VNextStateSurface
extends Control

const Context = preload("res://src/ui/vnext/ui_context.gd")
const Tokens = preload("res://src/ui/vnext/ui_tokens.gd")
const FocusModel = preload("res://src/ui/vnext/core/ui_focus_model.gd")
const Orbitron: Font = preload("res://assets/fonts/Orbitron.ttf")
const ShareTechMono: Font = preload("res://assets/fonts/ShareTechMono.ttf")

signal action_requested(action_id: String, payload: Dictionary)

var context: RefCounted
var snapshot := {}
var _layout := {}
var _focus := ""
var _focus_model: RefCounted = FocusModel.new()
var _buttons: Dictionary = {}
var _gui_event_ids := {}
var activation_count := 0
var last_action_id := ""

static func context_for_viewport(viewport: Vector2, touch := false, reduced := false, contrast := false, scale := 1.0) -> RefCounted:
	return Context.from_viewport(viewport, touch, reduced, contrast, scale)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func configure(next_snapshot: Dictionary, next_context: RefCounted) -> void:
	snapshot = next_snapshot.duplicate(true)
	context = next_context
	var remembered := _focus
	var action_ids := _action_ids()
	_focus_model.set_focus_order(action_ids)
	_layout = _layout_for_context()
	_rebuild_buttons(action_ids)
	set_focus_id(remembered if remembered in action_ids else (_focus_model.focus_id if not action_ids.is_empty() else ""))
	queue_redraw()

func layout_snapshot() -> Dictionary:
	return {"density": context.density if context != null else "unknown", "safe_rect": context.safe_rect if context != null else Rect2(), "regions": _layout.duplicate(true)}

func action_regions() -> Dictionary:
	var regions := {}
	for action_id in _action_ids():
		regions[action_id] = {"rect": _layout.get(action_id, Rect2()), "label": _label_for(action_id), "state": "FOCUS" if action_id == _focus else "READY"}
	return regions

func semantic_snapshot() -> Dictionary:
	return {"kind": snapshot.get("kind", "error"), "title": snapshot.get("title", "RECOVERY REQUIRED"), "message": snapshot.get("message", "Return and try again."), "reason_code": snapshot.get("reason_code", "unknown"), "semantic_label": snapshot.get("semantic_label", "ERROR"), "pattern": snapshot.get("pattern", "broken bars"), "recoverable": snapshot.get("recoverable", true), "source": snapshot.get("source", "unknown"), "focus": _focus, "navigation": _focus_model.snapshot()}

func text_overflow_report() -> Array:
	if context == null or _layout.is_empty():
		return [{"id": "surface", "measured": false, "fits": false}]
	var scale := float(context.text_scale)
	var narrow: bool = context.density == "narrow"
	var entries := [
		{"id": "title", "text": str(snapshot.get("title", "")), "rect": _layout["title"], "font": Orbitron, "size": 22.0 if narrow else 26.0, "padding": 0.0},
		{"id": "marker", "text": "%s // %s" % [str(snapshot.get("semantic_label", "ERROR")), str(snapshot.get("pattern", ""))], "rect": _layout["marker"], "font": ShareTechMono, "size": 12.0 if narrow else 14.0, "padding": 0.0},
		{"id": "message", "text": str(snapshot.get("message", "")), "rect": _layout["message"], "font": ShareTechMono, "size": 13.0 if narrow else 16.0, "padding": 0.0},
		{"id": "reason", "text": _details_text(), "rect": _layout["reason"], "font": ShareTechMono, "size": 11.0 if narrow else 13.0, "padding": 0.0},
	]
	if snapshot.get("destination", "") != "":
		entries.append({"id": "destination", "text": "DESTINATION: %s" % str(snapshot["destination"]), "rect": _layout["destination"], "font": ShareTechMono, "size": 12.0 if narrow else 14.0, "padding": 0.0})
	for action_id in _action_ids():
		entries.append({"id": action_id, "text": _label_for(action_id), "rect": _layout[action_id], "font": ShareTechMono, "size": 16.0, "padding": 24.0})
	var report: Array = []
	for entry in entries:
		var measured := (entry["font"] as Font).get_string_size(str(entry["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(float(entry["size"]) * scale)))
		var rect: Rect2 = entry["rect"]
		var available := maxf(rect.size.x - float(entry["padding"]), 0.0)
		report.append({"id": entry["id"], "text": str(entry["text"]), "measured": true, "fits": measured.x <= available and measured.y <= rect.size.y, "measured_width": measured.x, "available_width": available})
	return report

func handle_input(event: InputEvent) -> bool:
	var action := ""
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			action = _focus
		elif event.keycode in [KEY_TAB, KEY_DOWN]:
			set_focus_id(_focus_model.move_focus(1))
			return true
		elif event.keycode == KEY_UP:
			set_focus_id(_focus_model.move_focus(-1))
			return true
		elif event.keycode == KEY_ESCAPE:
			action = _back_id()
	elif event is InputEventMouseButton and event.pressed:
		action = _action_at(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		action = _action_at(event.position)
	return _dispatch(action)

func focus_id() -> String:
	return _focus

func set_focus_id(id: String) -> bool:
	if not _focus_model.set_focus(id):
		return false
	_focus = id
	if _buttons.has(id) and is_inside_tree():
		(_buttons[id] as Button).grab_focus()
	queue_redraw()
	return true

func _action_ids() -> Array[String]:
	var ids: Array[String] = []
	if bool(snapshot.get("can_retry", false)) and not str(snapshot.get("primary_action", "")).is_empty():
		ids.append(str(snapshot["primary_action"]))
	if not str(snapshot.get("back_action", "")).is_empty():
		ids.append(str(snapshot["back_action"]))
	return ids

func _back_id() -> String:
	return str(snapshot.get("back_action", ""))

func _layout_for_context() -> Dictionary:
	var safe: Rect2 = context.safe_rect
	var width := minf(820.0, safe.size.x)
	var x := safe.position.x + (safe.size.x - width) * 0.5
	var y := safe.position.y + 20.0
	var compact: bool = context.density == "narrow"
	var h := 52.0
	var text_height := 48.0 if compact else 36.0
	var reason_height := 34.0 if compact else 24.0
	var layout := {"shell": Rect2(x, y, width, safe.size.y - 40.0), "title": Rect2(x + 16.0, y + 16.0, width - 32.0, 34.0), "marker": Rect2(x + 16.0, y + 56.0, width - 32.0, 24.0), "message": Rect2(x + 16.0, y + 88.0, width - 32.0, text_height), "reason": Rect2(x + 16.0, y + 88.0 + text_height + 6.0, width - 32.0, reason_height), "destination": Rect2(x + 16.0, y + 88.0 + text_height + reason_height + 12.0, width - 32.0, 22.0)}
	var button_y := y + 88.0 + text_height + reason_height + (44.0 if snapshot.get("destination", "") != "" else 12.0)
	for action_id in _action_ids():
		layout[action_id] = Rect2(x + 12.0, button_y, width - 24.0, h)
		button_y += h + 10.0
	return layout

func _rebuild_buttons(action_ids: Array[String]) -> void:
	for child in get_children():
		if child is Button:
			child.queue_free()
	_buttons.clear()
	for action_id in action_ids:
		var button := Button.new()
		button.name = action_id.capitalize()
		button.text = _label_for(action_id)
		button.flat = true
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_override("font", ShareTechMono)
		button.add_theme_color_override("font_color", Tokens.role_color("structure"))
		button.add_theme_color_override("font_focus_color", Tokens.role_color("focus"))
		for state in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.pressed.connect(_on_button_pressed.bind(action_id))
		button.focus_entered.connect(_on_button_focus.bind(action_id))
		button.gui_input.connect(_on_button_gui_input)
		add_child(button)
		_buttons[action_id] = button
		button.position = _layout[action_id].position
		button.size = _layout[action_id].size

func _on_button_pressed(action_id: String) -> void:
	_dispatch(action_id)

func _on_button_focus(action_id: String) -> void:
	_focus = action_id
	_focus_model.set_focus(action_id)
	queue_redraw()

func _on_button_gui_input(event: InputEvent) -> void:
	_gui_event_ids[event.get_instance_id()] = true

func _unhandled_input(event: InputEvent) -> void:
	var event_id := event.get_instance_id()
	if _gui_event_ids.has(event_id):
		_gui_event_ids.erase(event_id)
		get_viewport().set_input_as_handled()
		return
	if handle_input(event):
		get_viewport().set_input_as_handled()

func _dispatch(action_id: String) -> bool:
	if not _focus_model.begin_dispatch(action_id):
		return false
	activation_count += 1
	last_action_id = action_id
	_focus = action_id
	action_requested.emit(action_id, {"kind": snapshot.get("kind", "error"), "source": snapshot.get("source", "unknown")})
	_focus_model.end_dispatch()
	return true

func _action_at(point: Vector2) -> String:
	for action_id in _action_ids():
		if (_layout.get(action_id, Rect2()) as Rect2).has_point(point):
			return action_id
	return ""

func _label_for(action_id: String) -> String:
	if action_id == str(snapshot.get("primary_action", "")):
		return str(snapshot.get("primary_label", "RETRY"))
	return str(snapshot.get("back_label", "BACK"))

func _details_text() -> String:
	if snapshot.get("kind", "error") == "error" and not bool(snapshot.get("can_retry", false)):
		return "RETRY UNAVAILABLE — RETURN TO A SAFE SCREEN"
	if snapshot.get("kind", "error") == "loading":
		return "WORKING — NO COMPLETION PERCENTAGE AVAILABLE"
	if snapshot.get("kind", "error") == "transition":
		return "CANCELLATION IS SAFE" if bool(snapshot.get("cancel_safe", false)) else "CANCELLATION IS NOT AVAILABLE"
	return "SOURCE: %s" % str(snapshot.get("source", "unknown")).to_upper()

func _draw() -> void:
	if context == null or _layout.is_empty():
		return
	var shell: Rect2 = _layout["shell"]
	draw_rect(Rect2(Vector2.ZERO, size), Tokens.role_color("background"))
	draw_polyline(Tokens.frame_points(shell, 18.0), Tokens.role_color("structure"), 1.5, true)
	var narrow: bool = context.density == "narrow"
	draw_string(Orbitron, _layout["title"].position + Vector2(0, 22), str(snapshot.get("title", "RECOVERY REQUIRED")), HORIZONTAL_ALIGNMENT_LEFT, -1, int(round((22.0 if narrow else 26.0) * context.text_scale)), Tokens.role_color("focus"))
	draw_string(ShareTechMono, _layout["marker"].position + Vector2(0, 15), "%s // %s" % [str(snapshot.get("semantic_label", "ERROR")), str(snapshot.get("pattern", "broken bars"))], HORIZONTAL_ALIGNMENT_LEFT, -1, int(round((12.0 if narrow else 14.0) * context.text_scale)), Tokens.role_color("warning"))
	draw_string(ShareTechMono, _layout["message"].position + Vector2(0, 16), str(snapshot.get("message", "Return and try again.")), HORIZONTAL_ALIGNMENT_LEFT, -1, int(round((13.0 if narrow else 16.0) * context.text_scale)), Tokens.role_color("structure"))
	draw_string(ShareTechMono, _layout["reason"].position + Vector2(0, 13), _details_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(round((11.0 if narrow else 13.0) * context.text_scale)), Tokens.role_color("muted"))
	if snapshot.get("destination", "") != "":
		draw_string(ShareTechMono, _layout["destination"].position + Vector2(0, 14), "DESTINATION: %s" % str(snapshot["destination"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(round((12.0 if narrow else 14.0) * context.text_scale)), Tokens.role_color("ready"))
	for action_id in _action_ids():
		var color := Tokens.role_color("focus") if action_id == _focus else Tokens.role_color("structure")
		draw_polyline(Tokens.frame_points(_layout[action_id], 10.0), color, 2.0 if action_id == _focus else 1.0, true)

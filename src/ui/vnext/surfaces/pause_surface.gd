class_name VNextPauseSurface
extends Control

const Context = preload("res://src/ui/vnext/ui_context.gd")
const Tokens = preload("res://src/ui/vnext/ui_tokens.gd")
const TacticalUI = preload("res://src/ui/tactical_ui.gd")
const Orbitron: Font = preload("res://assets/fonts/Orbitron.ttf")
const ShareTechMono: Font = preload("res://assets/fonts/ShareTechMono.ttf")

signal action_requested(action_id: String, payload: Dictionary)

var context: RefCounted
var snapshot := {}
var _layout := {}
var _semantic := {}
var _buttons: Dictionary = {}
var _focus_id := "resume"
var _dispatching := false

const PAUSE_TITLE := "PAUSED // FROZEN RUN"

func _program_snapshot() -> Dictionary:
	var value = snapshot.get("program_snapshot", {})
	return value if value is Dictionary else {}

func _ability_state() -> String:
	var program_snapshot := _program_snapshot()
	var nested: Dictionary = program_snapshot.get("nested", {})
	var id := str(nested.get("program_id", Game.program))
	if id == "rootlet":
		return "SHIELD READY" if bool(nested.get("shield_ready", false)) else ("SHIELD CHARGING" if float(nested.get("shield_meter", 0.0)) > 0.0 else "SHIELD DOWN")
	if id == "daemon":
		return "DASH ACTIVE" if bool(nested.get("dash_active", false)) else ("DASH READY" if int(nested.get("dash_available", 0)) > 0 else "DASH COOLDOWN")
	return "OVERCLOCK ACTIVE" if bool(nested.get("overclock_active", false)) else ("OVERCLOCK READY" if bool(nested.get("overclock_ready", false)) else "OVERCLOCK CHARGING")

func _display_context() -> String:
	var program_snapshot := _program_snapshot()
	var nested: Dictionary = program_snapshot.get("nested", {})
	return "%s // %s" % [str(nested.get("program_id", Game.program)).to_upper(), _ability_state()]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for spec in [{"id":"resume", "text":"RESUME"}, {"id":"restart", "text":"RESTART"}, {"id":"terminal", "text":"OPEN TERMINAL"}, {"id":"abandon", "text":"ABANDON PROCESS"}]:
		var button := Button.new()
		button.name = str(spec["id"]).capitalize()
		button.text = str(spec["text"])
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.flat = true
		button.add_theme_font_override("font", ShareTechMono)
		button.add_theme_color_override("font_color", Tokens.role_color("focus"))
		button.add_theme_color_override("font_focus_color", Tokens.role_color("player"))
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.pressed.connect(_dispatch.bind(str(spec["id"])))
		button.focus_entered.connect(_set_focus.bind(str(spec["id"])))
		add_child(button)
		_buttons[str(spec["id"])] = button

func configure_adapter(next_snapshot: Dictionary, next_context: RefCounted) -> void:
	context = next_context
	snapshot = next_snapshot.duplicate(true)
	visible = bool(snapshot.get("visible", false))
	_refresh()
	if visible:
		_focus_first()

func show_pause(next_snapshot: Dictionary) -> void:
	snapshot = next_snapshot.duplicate(true)
	snapshot["visible"] = true
	visible = true
	_refresh()
	_focus_first()

func hide_surface() -> void:
	visible = false
	_dispatching = false

func reflow_for_viewport(viewport: Vector2) -> void:
	context = Context.from_viewport(viewport, context != null and context.input_mode == "touch", false, false, context.text_scale if context != null else 1.0)
	_refresh()

func layout_snapshot() -> Dictionary:
	return _layout.duplicate(true)

func semantic_snapshot() -> Dictionary:
	return _semantic.duplicate(true)

func action_regions() -> Dictionary:
	return _layout.get("regions", {}).duplicate(true)

func text_overflow_report() -> Dictionary:
	var fields := {}
	var values := {
		"title": {"text": PAUSE_TITLE, "size": _title_font_size()},
		"context": {"text": _display_context(), "size": 15},
		"confirmation": {"text": str(snapshot.get("confirmation", "STATE MARKER // PAUSED / FROZEN")), "size": 13},
		"resume": {"text": "RESUME", "size": 15},
		"restart": {"text": "RESTART", "size": 15},
		"terminal": {"text": "OPEN TERMINAL", "size": 15},
		"abandon": {"text": "ABANDON PROCESS", "size": 15},
	}
	for id in values:
		var text := str(values[id]["text"])
		var rect: Rect2 = _layout.get("regions", {}).get(id, Rect2())
		var font: Font = Orbitron if id == "title" else ShareTechMono
		var font_size := int(values[id]["size"])
		var measured := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		fields[id] = {"text": text, "font_size": font_size, "fits": measured.x <= maxf(rect.size.x - 20.0, 0.0), "measured_width": measured.x, "available_width": maxf(rect.size.x - 20.0, 0.0)}
	var overflow := false
	for field in fields.values():
		overflow = overflow or not bool(field["fits"])
	return {"has_overflow": overflow, "has_unmeasured_fields": false, "fields": fields}

func handle_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).physical_keycode
		if key in [KEY_TAB, KEY_DOWN]:
			_move_focus(1)
			return true
		if key == KEY_UP:
			_move_focus(-1)
			return true
		if key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			return _dispatch(_focus_id)
		if key == KEY_ESCAPE:
			return _dispatch("resume")
		if key == KEY_Q:
			return _dispatch("abandon")
	if event is InputEventMouseButton and event.pressed:
		var point := get_viewport().get_final_transform().affine_inverse() * (event as InputEventMouseButton).position
		for id in _layout.get("regions", {}):
			if id in _buttons and (_layout["regions"][id] as Rect2).has_point(point):
				return _dispatch(id)
	return false

func _refresh() -> void:
	if context == null:
		context = Context.from_viewport(get_viewport_rect().size)
	var safe: Rect2 = context.safe_rect
	var narrow: bool = context.density == "narrow"
	var panel := Rect2(safe.position + Vector2(16.0, 16.0), Vector2(maxf(safe.size.x - 32.0, 1.0), maxf(safe.size.y - 32.0, 1.0)))
	var width := panel.size.x if narrow else minf(panel.size.x, 680.0)
	var x := panel.position.x if narrow else panel.get_center().x - width * 0.5
	var button_h := 46.0
	var gap := 8.0
	var start := panel.position.y + 190.0 if not narrow else panel.position.y + 210.0
	var regions := {"safe": safe, "panel": Rect2(Vector2(x, panel.position.y), Vector2(width, panel.size.y)), "title": Rect2(x + 20.0, panel.position.y + 22.0, width - 40.0, 42.0), "context": Rect2(x + 20.0, panel.position.y + 76.0, width - 40.0, 70.0), "confirmation": Rect2(x + 20.0, panel.position.y + 146.0, width - 40.0, 28.0)}
	for index in 4:
		regions[_buttons.keys()[index]] = Rect2(x + 20.0, start + index * (button_h + gap), width - 40.0, button_h)
	_layout = {"safe": safe, "regions": regions, "narrow": narrow}
	var program_snapshot := _program_snapshot()
	var nested: Dictionary = program_snapshot.get("nested", {})
	_semantic = {"paused": true, "frozen": true, "focus": _focus_id, "title_font_size": _title_font_size(), "abandon_armed": bool(snapshot.get("abandon_armed", false)), "restart_armed": bool(snapshot.get("restart_armed", false)), "destructive_action": _destructive_action(), "disabled_actions": [], "program_id": str(nested.get("program_id", Game.program)), "program_kind": str(program_snapshot.get("kind", "kernel")), "ability_state": _ability_state()}
	for id in _buttons:
		var button: Button = _buttons[id]
		button.position = regions[id].position
		button.size = regions[id].size
		button.visible = visible
		button.add_theme_font_size_override("font_size", maxi(12, int(round(15.0 * context.text_scale))))
	queue_redraw()

func _focus_first() -> void:
	_focus_id = "resume"
	if _buttons.has(_focus_id):
		var button: Button = _buttons[_focus_id]
		if button.is_inside_tree():
			button.grab_focus()
		else:
			button.call_deferred("grab_focus")

func _set_focus(id: String) -> void:
	_focus_id = id
	_semantic["focus"] = id
	queue_redraw()

func _move_focus(delta: int) -> void:
	var ids := ["resume", "restart", "terminal", "abandon"]
	_focus_id = ids[wrapi(ids.find(_focus_id) + delta, 0, ids.size())]
	(_buttons[_focus_id] as Button).grab_focus()

func _title_font_size() -> int:
	if _layout.is_empty():
		return 27
	var title_rect: Rect2 = _layout.get("regions", {}).get("title", Rect2())
	var max_size := 27.0
	if context != null:
		max_size = 27.0 if context.density == "wide" else 23.0 if context.density == "compact" else 20.0
		max_size *= context.text_scale
	var font_size := maxi(14, int(floor(max_size)))
	while font_size > 14 and Orbitron.get_string_size(PAUSE_TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > maxf(title_rect.size.x - 20.0, 1.0):
		font_size -= 1
	return font_size

func _dispatch(id: String) -> bool:
	if _dispatching or not _buttons.has(id):
		return false
	_dispatching = true
	_focus_id = id
	action_requested.emit(id, {"confirmation": _destructive_action() != ""})
	call_deferred("_clear_dispatching")
	return true

func _destructive_action() -> String:
	var action := str(snapshot.get("destructive_action", ""))
	if action == "restart" or action == "abandon":
		return action
	if bool(snapshot.get("abandon_armed", false)):
		return "abandon"
	if bool(snapshot.get("restart_armed", false)):
		return "restart"
	return ""

func _clear_dispatching() -> void:
	_dispatching = false

func _draw() -> void:
	if _layout.is_empty() or not visible:
		return
	var panel: Rect2 = _layout["regions"]["panel"]
	var points := TacticalUI.angular_points(panel, 16.0)
	draw_colored_polygon(points, Color(0.01, 0.02, 0.06, 0.96))
	draw_polyline(points + PackedVector2Array([points[0]]), Tokens.role_color("structure"), 1.5, true)
	draw_string(Orbitron, _layout["regions"]["title"].position + Vector2(0, 30), PAUSE_TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, _title_font_size(), Tokens.role_color("text"))
	draw_string(ShareTechMono, _layout["regions"]["context"].position, _display_context(), HORIZONTAL_ALIGNMENT_LEFT, _layout["regions"]["context"].size.x, 15, Tokens.role_color("player"))
	draw_string(ShareTechMono, _layout["regions"]["confirmation"].position, str(snapshot.get("confirmation", "STATE MARKER // PAUSED / FROZEN")), HORIZONTAL_ALIGNMENT_LEFT, _layout["regions"]["confirmation"].size.x, 13, Tokens.role_color("danger") if _destructive_action() != "" else Tokens.role_color("text"))

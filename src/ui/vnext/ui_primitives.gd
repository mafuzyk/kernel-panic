class_name VNextUIPrimitives
extends Control

const Tokens = preload("res://src/ui/vnext/ui_tokens.gd")

var _role := "structure"
var _state := "idle"
var _label := ""
var _value := 0.0
var _last_viewport := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func configure_surface(role: String, state: String = "idle", label: String = "", value: float = 0.0) -> void:
	_role = role
	_state = state
	_label = label
	_value = clampf(value, 0.0, 1.0)
	queue_redraw()

func frame_rect(viewport: Vector2 = Vector2.ZERO) -> Rect2:
	var target := viewport if viewport != Vector2.ZERO else size
	return Tokens.safe_rect(target)

func semantic_snapshot() -> Dictionary:
	var state_visual: Dictionary = Tokens.state_visual(_state)
	return {
		"role": _role,
		"state": _state,
		"state_label": str(state_visual.get("label", Tokens.state_label(_state))),
		"label": _label,
		"value": _value,
		"frame": frame_rect(),
	}

func text_overflow_report() -> Array:
	return [{
		"id": "surface_label",
		"fits": _label.is_empty() or _label.length() <= 32,
	}]

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and size != _last_viewport:
		_last_viewport = size
		queue_redraw()

func _draw() -> void:
	var rect := frame_rect()
	if rect.size.x <= 2.0 or rect.size.y <= 2.0:
		return
	var points := Tokens.frame_points(rect, minf(18.0, rect.size.y * 0.12))
	var color := Tokens.role_color(_role)
	draw_colored_polygon(points, Color(color.r, color.g, color.b, 0.035))
	draw_polyline(points + PackedVector2Array([points[0]]), Color(color.r, color.g, color.b, 0.78), 1.4, true)
	_draw_state_marker(rect)
	if _value > 0.0:
		_draw_meter(rect, color)

func _draw_state_marker(rect: Rect2) -> void:
	var center := rect.position + Vector2(24.0, 24.0)
	var state_visual: Dictionary = Tokens.state_visual(_state)
	var state_color := Tokens.role_color(str(state_visual.get("role", "structure")))
	match str(state_visual.get("pattern", "steady")):
		"pulse":
			draw_circle(center, 4.0, state_color)
			draw_arc(center, 8.0, 0.0, TAU, 16, Color(state_color.r, state_color.g, state_color.b, 0.55), 1.0, true)
		"break":
			draw_line(center - Vector2(5.0, 5.0), center + Vector2(5.0, 5.0), state_color, 1.8, true)
			draw_line(center + Vector2(5.0, -5.0), center - Vector2(5.0, -5.0), state_color, 1.8, true)
		"hatch":
			var diamond := PackedVector2Array([
				center + Vector2(0.0, -6.0),
				center + Vector2(6.0, 0.0),
				center + Vector2(0.0, 6.0),
				center + Vector2(-6.0, 0.0),
				center + Vector2(0.0, -6.0),
			])
			draw_polyline(diamond, state_color, 1.2, true)
		_:
			draw_circle(center, 3.0, state_color)

func _draw_meter(rect: Rect2, color: Color) -> void:
	var bar_width := maxf(rect.size.x - 48.0, 0.0)
	if bar_width <= 0.0:
		return
	var bar := Rect2(rect.position + Vector2(24.0, rect.size.y - 18.0), Vector2(bar_width, 4.0))
	draw_rect(bar, Color(color.r, color.g, color.b, 0.16))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _value, bar.size.y)), Color(color.r, color.g, color.b, 0.86))

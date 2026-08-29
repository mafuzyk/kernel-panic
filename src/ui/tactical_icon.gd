class_name TacticalIcon
extends Control

const TacticalUIHelper = preload("res://src/ui/tactical_ui.gd")

var _kind := "settings"
var _accent := TacticalUIHelper.CYAN

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func configure(icon_kind: String, color: Color = TacticalUIHelper.CYAN) -> void:
	_kind = icon_kind
	_accent = color
	queue_redraw()

func icon_kind() -> String:
	return _kind

func _line_color(alpha: float = 0.92) -> Color:
	return Color(_accent.r, _accent.g, _accent.b, alpha)

func _points_closed(points: PackedVector2Array, color: Color = _line_color(), width: float = 1.8) -> void:
	if points.is_empty():
		return
	draw_polyline(points + PackedVector2Array([points[0]]), color, width, true)

func _draw() -> void:
	if size.x <= 2.0 or size.y <= 2.0:
		return
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.34
	match _kind:
		"settings":
			_draw_settings(center, radius)
		"bestiary":
			_draw_bestiary(center, radius)
		"dash":
			_draw_dash(center, radius)
		"back":
			_draw_back(center, radius)
		"resume":
			_draw_resume(center, radius)
		"restart":
			_draw_restart(center, radius)
		"terminal":
			_draw_terminal(center, radius)
		"audio":
			_draw_audio(center, radius)
		"music":
			_draw_music(center, radius)
		"warning":
			_draw_warning(center, radius)
		_:
			_draw_bestiary(center, radius)

func _draw_settings(center: Vector2, radius: float) -> void:
	var gear := PackedVector2Array()
	for index in 16:
		var angle := TAU * float(index) / 16.0 - PI / 2.0
		var ring := radius if index % 2 == 0 else radius * 0.78
		gear.append(center + Vector2.from_angle(angle) * ring)
	_points_closed(gear, _line_color(), 1.7)
	draw_circle(center, radius * 0.46, Color(_accent.r, _accent.g, _accent.b, 0.10))
	draw_arc(center, radius * 0.46, 0.0, TAU, 20, _line_color(), 1.6, true)
	draw_line(center - Vector2(radius * 0.18, -radius * 0.18), center + Vector2(radius * 0.30, -radius * 0.30), _line_color(), 2.0)
	draw_circle(center + Vector2(radius * 0.34, -radius * 0.34), radius * 0.10, _line_color())

func _draw_bestiary(center: Vector2, radius: float) -> void:
	var eye := PackedVector2Array([
		center + Vector2(-radius, 0.0),
		center + Vector2(-radius * 0.34, -radius * 0.64),
		center + Vector2(radius * 0.44, -radius * 0.52),
		center + Vector2(radius, 0.0),
		center + Vector2(radius * 0.44, radius * 0.52),
		center + Vector2(-radius * 0.34, radius * 0.64),
	])
	_points_closed(eye, _line_color(), 1.8)
	draw_circle(center, radius * 0.33, Color(_accent.r, _accent.g, _accent.b, 0.10))
	draw_arc(center, radius * 0.33, 0.0, TAU, 18, _line_color(), 1.7, true)
	draw_circle(center, radius * 0.12, _line_color())

func _draw_dash(center: Vector2, radius: float) -> void:
	var badge := Rect2(center - Vector2(radius * 1.18, radius * 0.90), Vector2(radius * 2.36, radius * 1.80))
	var badge_points := TacticalUIHelper.angular_points(badge, radius * 0.28)
	draw_colored_polygon(badge_points, Color(_accent.r, _accent.g, _accent.b, 0.08))
	_points_closed(badge_points, _line_color(0.72), 1.5)
	for index in 3:
		var x := center.x - radius * 0.62 + float(index) * radius * 0.62
		var points := PackedVector2Array([
			Vector2(x - radius * 0.25, center.y - radius * 0.55),
			Vector2(x + radius * 0.26, center.y),
			Vector2(x - radius * 0.25, center.y + radius * 0.55),
		])
		_points_closed(points, _line_color(), 2.2)

func _draw_back(center: Vector2, radius: float) -> void:
	draw_line(Vector2(center.x - radius * 0.62, center.y), Vector2(center.x + radius * 0.62, center.y), _line_color(), 2.0)
	draw_line(Vector2(center.x - radius * 0.62, center.y), Vector2(center.x - radius * 0.14, center.y - radius * 0.46), _line_color(), 2.0)
	draw_line(Vector2(center.x - radius * 0.62, center.y), Vector2(center.x - radius * 0.14, center.y + radius * 0.46), _line_color(), 2.0)

func _draw_resume(center: Vector2, radius: float) -> void:
	var triangle := PackedVector2Array([
		center + Vector2(-radius * 0.34, -radius * 0.62),
		center + Vector2(radius * 0.58, 0.0),
		center + Vector2(-radius * 0.34, radius * 0.62),
	])
	draw_colored_polygon(triangle, Color(_accent.r, _accent.g, _accent.b, 0.16))
	_points_closed(triangle, _line_color(), 1.8)

func _draw_restart(center: Vector2, radius: float) -> void:
	draw_arc(center, radius * 0.68, -PI * 0.80, PI * 0.92, 20, _line_color(), 2.0, true)
	var tip := center + Vector2.from_angle(-PI * 0.80) * radius * 0.68
	var arrow := PackedVector2Array([
		tip,
		tip + Vector2(radius * 0.46, -radius * 0.06),
		tip + Vector2(radius * 0.12, radius * 0.36),
	])
	_points_closed(arrow, _line_color(), 1.8)

func _draw_terminal(center: Vector2, radius: float) -> void:
	var box := Rect2(center - Vector2(radius * 0.78, radius * 0.56), Vector2(radius * 1.56, radius * 1.12))
	_points_closed(TacticalUIHelper.angular_points(box, radius * 0.18), _line_color(), 1.7)
	draw_line(center + Vector2(-radius * 0.45, -radius * 0.12), center + Vector2(-radius * 0.10, center.y * 0.0), _line_color(), 1.8)
	draw_line(center + Vector2(-radius * 0.10, center.y * 0.0), center + Vector2(-radius * 0.45, radius * 0.26), _line_color(), 1.8)
	draw_line(center + Vector2(radius * 0.06, radius * 0.28), center + Vector2(radius * 0.42, radius * 0.28), _line_color(), 1.8)

func _draw_audio(center: Vector2, radius: float) -> void:
	var speaker := PackedVector2Array([
		center + Vector2(-radius * 0.72, -radius * 0.20),
		center + Vector2(-radius * 0.30, -radius * 0.20),
		center + Vector2(radius * 0.22, -radius * 0.62),
		center + Vector2(radius * 0.22, radius * 0.62),
		center + Vector2(-radius * 0.30, radius * 0.20),
		center + Vector2(-radius * 0.72, radius * 0.20),
	])
	draw_colored_polygon(speaker, Color(_accent.r, _accent.g, _accent.b, 0.14))
	_points_closed(speaker, _line_color(), 1.6)
	draw_arc(center, radius * 0.54, -PI * 0.42, PI * 0.42, 12, _line_color(0.8), 1.5, true)
	draw_arc(center, radius * 0.78, -PI * 0.34, PI * 0.34, 12, _line_color(0.6), 1.3, true)

func _draw_music(center: Vector2, radius: float) -> void:
	draw_line(center + Vector2(radius * 0.18, -radius * 0.68), center + Vector2(radius * 0.18, radius * 0.32), _line_color(), 1.9)
	draw_line(center + Vector2(radius * 0.18, -radius * 0.68), center + Vector2(radius * 0.64, -radius * 0.82), _line_color(), 1.9)
	draw_circle(center + Vector2(-radius * 0.16, radius * 0.38), radius * 0.25, _line_color())
	draw_circle(center + Vector2(radius * 0.34, radius * 0.24), radius * 0.25, _line_color())

func _draw_warning(center: Vector2, radius: float) -> void:
	var triangle := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.78),
		center + Vector2(radius * 0.72, radius * 0.60),
		center + Vector2(-radius * 0.72, radius * 0.60),
	])
	_points_closed(triangle, _line_color(), 1.8)
	draw_line(center + Vector2(0.0, -radius * 0.36), center + Vector2(0.0, radius * 0.22), _line_color(), 2.0)
	draw_circle(center + Vector2(0.0, radius * 0.43), radius * 0.08, _line_color())

class_name TacticalChrome
extends Control

const TacticalUIHelper = preload("res://src/ui/tactical_ui.gd")

var accent := TacticalUIHelper.CYAN
var fill_alpha := 0.0
var _frame_rect := Rect2()
var _use_shell := true
var _control_mode := false

func configure_shell(color: Color = TacticalUIHelper.CYAN, alpha: float = 0.0) -> void:
	accent = color
	fill_alpha = alpha
	_use_shell = true
	_control_mode = false
	_frame_rect = Rect2()
	queue_redraw()

func configure_panel(rect: Rect2, color: Color = TacticalUIHelper.CYAN, alpha: float = 0.04) -> void:
	accent = color
	fill_alpha = alpha
	_use_shell = false
	_control_mode = false
	_frame_rect = rect
	queue_redraw()

func configure_control(color: Color = TacticalUIHelper.CYAN, alpha: float = 0.02) -> void:
	accent = color
	fill_alpha = alpha
	_use_shell = false
	_control_mode = true
	_frame_rect = Rect2()
	queue_redraw()

func frame_rect() -> Rect2:
	if _use_shell:
		return TacticalUIHelper.shell_rect(size)
	if _frame_rect.size == Vector2.ZERO:
		return Rect2(Vector2.ZERO, size)
	return _frame_rect

func frame_points() -> PackedVector2Array:
	var rect := frame_rect()
	return TacticalUIHelper.angular_points(rect, minf(16.0, rect.size.y * 0.12))

func _draw() -> void:
	var rect := frame_rect()
	if rect.size.x <= 2.0 or rect.size.y <= 2.0:
		return
	var points := frame_points()
	var closed := points.duplicate()
	closed.append(points[0])
	if fill_alpha > 0.0:
		draw_colored_polygon(points, Color(accent.r, accent.g, accent.b, fill_alpha))
	draw_polyline(closed, Color(accent.r, accent.g, accent.b, 0.76), 1.35, true)
	if _control_mode:
		var detail_alpha := 0.48
		draw_line(Vector2(rect.position.x + 18.0, rect.position.y + 7.0), Vector2(rect.position.x + 68.0, rect.position.y + 7.0), Color(accent.r, accent.g, accent.b, detail_alpha), 1.0)
		draw_line(Vector2(rect.end.x - 68.0, rect.position.y + 7.0), Vector2(rect.end.x - 18.0, rect.position.y + 7.0), Color(accent.r, accent.g, accent.b, detail_alpha), 1.0)
		draw_line(Vector2(rect.position.x + 18.0, rect.end.y - 7.0), Vector2(rect.position.x + 68.0, rect.end.y - 7.0), Color(accent.r, accent.g, accent.b, detail_alpha), 1.0)
		draw_line(Vector2(rect.end.x - 68.0, rect.end.y - 7.0), Vector2(rect.end.x - 18.0, rect.end.y - 7.0), Color(accent.r, accent.g, accent.b, detail_alpha), 1.0)
		return
	var rail_alpha := 0.62
	var rail_y_top := rect.position.y + 7.0
	var rail_y_bottom := rect.end.y - 7.0
	draw_line(Vector2(rect.position.x + 28.0, rail_y_top), Vector2(rect.position.x + 156.0, rail_y_top), Color(accent.r, accent.g, accent.b, rail_alpha), 1.0)
	draw_line(Vector2(rect.end.x - 156.0, rail_y_top), Vector2(rect.end.x - 28.0, rail_y_top), Color(accent.r, accent.g, accent.b, rail_alpha), 1.0)
	draw_line(Vector2(rect.position.x + 28.0, rail_y_bottom), Vector2(rect.position.x + 156.0, rail_y_bottom), Color(accent.r, accent.g, accent.b, rail_alpha), 1.0)
	draw_line(Vector2(rect.end.x - 156.0, rail_y_bottom), Vector2(rect.end.x - 28.0, rail_y_bottom), Color(accent.r, accent.g, accent.b, rail_alpha), 1.0)
	for corner in [Vector2(rect.position.x + 29.0, rect.position.y + 15.0), Vector2(rect.end.x - 29.0, rect.position.y + 15.0), Vector2(rect.position.x + 29.0, rect.end.y - 15.0), Vector2(rect.end.x - 29.0, rect.end.y - 15.0)]:
		draw_circle(corner, 2.1, Color(accent.r, accent.g, accent.b, 0.85))

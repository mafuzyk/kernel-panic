class_name TacticalStateSurface
extends Control

const TacticalUIHelper = preload("res://src/ui/tactical_ui.gd")

var variant := "pause"
var accent := TacticalUIHelper.CYAN

func configure(kind: String) -> void:
	variant = kind
	accent = TacticalUIHelper.MAGENTA if kind == "game_over" else TacticalUIHelper.CYAN
	queue_redraw()

static func panel_rect_for_viewport(viewport: Vector2, kind: String = "pause") -> Rect2:
	var compact := viewport.x < 760.0
	var width := minf(850.0 if kind == "game_over" else 500.0, viewport.x - (28.0 if compact else 48.0))
	var height := minf(512.0 if kind == "game_over" else 510.0, viewport.y - (28.0 if compact else 32.0))
	width = maxf(width, 300.0 if compact else 420.0)
	height = maxf(height, 340.0)
	return Rect2((viewport.x - width) * 0.5, (viewport.y - height) * 0.5, width, height)

static func action_rects_for_viewport(viewport: Vector2, kind: String, count: int) -> Array[Rect2]:
	var panel := panel_rect_for_viewport(viewport, kind)
	var result: Array[Rect2] = []
	if count <= 0:
		return result
	if kind == "game_over":
		var game_gap := 18.0
		var game_width := maxf((panel.size.x - 56.0 - game_gap) * 0.5, 120.0)
		for index in count:
			result.append(Rect2(panel.position + Vector2(28.0 + index * (game_width + game_gap), panel.size.y - 112.0), Vector2(game_width, 66.0)))
			return result
	var pause_width := maxf(panel.size.x - 72.0, 180.0)
	for index in count:
		result.append(Rect2(panel.position + Vector2(36.0, 128.0 + index * 52.0), Vector2(pause_width, 42.0)))
	return result

func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var panel := panel_rect_for_viewport(size, variant)
	var frame := TacticalUIHelper.angular_points(panel, 18.0)
	var closed := frame.duplicate()
	closed.append(frame[0])
	draw_colored_polygon(frame, Color(TacticalUIHelper.PANEL.r, TacticalUIHelper.PANEL.g, TacticalUIHelper.PANEL.b, 0.96))
	draw_colored_polygon(frame, Color(accent.r, accent.g, accent.b, 0.035))
	draw_polyline(closed, Color(accent.r, accent.g, accent.b, 0.9), 2.0, true)
	var top_line_y := panel.position.y + 34.0
	draw_line(Vector2(panel.position.x + 38.0, top_line_y), Vector2(panel.end.x - 38.0, top_line_y), Color(accent.r, accent.g, accent.b, 0.42), 1.0)
	var bottom_line_y := panel.end.y - 28.0
	draw_line(Vector2(panel.position.x + 38.0, bottom_line_y), Vector2(panel.end.x - 38.0, bottom_line_y), Color(accent.r, accent.g, accent.b, 0.42), 1.0)
	if variant == "game_over":
		_draw_game_over_sections(panel)
	else:
		_draw_pause_sections(panel)

func _draw_pause_sections(panel: Rect2) -> void:
	var mono: Font = load("res://assets/fonts/ShareTechMono.ttf")
	var info := Rect2(panel.position + Vector2(36.0, 92.0), Vector2(panel.size.x - 72.0, 48.0))
	draw_colored_polygon(TacticalUIHelper.angular_points(info, 8.0), Color(TacticalUIHelper.CYAN.r, TacticalUIHelper.CYAN.g, TacticalUIHelper.CYAN.b, 0.025))
	draw_string(mono, info.position + Vector2(14.0, 20.0), "PROCESS CONTROL // RUN STATE FROZEN", HORIZONTAL_ALIGNMENT_LEFT, info.size.x - 28.0, 11, TacticalUIHelper.MUTED)
	var volume := Rect2(panel.position + Vector2(36.0, panel.size.y - 220.0), Vector2(panel.size.x - 72.0, 82.0))
	var volume_points := TacticalUIHelper.angular_points(volume, 8.0)
	draw_colored_polygon(volume_points, Color(TacticalUIHelper.CYAN.r, TacticalUIHelper.CYAN.g, TacticalUIHelper.CYAN.b, 0.025))
	draw_polyline(volume_points + PackedVector2Array([volume_points[0]]), Color(TacticalUIHelper.CYAN.r, TacticalUIHelper.CYAN.g, TacticalUIHelper.CYAN.b, 0.38), 1.0, true)
	var warning := Rect2(panel.position + Vector2(36.0, panel.size.y - 130.0), Vector2(panel.size.x - 72.0, 78.0))
	var warning_points := TacticalUIHelper.angular_points(warning, 8.0)
	draw_polyline(warning_points + PackedVector2Array([warning_points[0]]), Color(TacticalUIHelper.MAGENTA.r, TacticalUIHelper.MAGENTA.g, TacticalUIHelper.MAGENTA.b, 0.7), 1.3, true)

func _draw_game_over_sections(panel: Rect2) -> void:
	var mono: Font = load("res://assets/fonts/ShareTechMono.ttf")
	var gap := 18.0
	var section_size := Vector2((panel.size.x - 56.0 - gap) * 0.5, 230.0)
	var top := panel.position.y + 150.0
	var headings := ["CORE DUMP", "RUN SUMMARY"]
	for index in 2:
		var section := Rect2(panel.position.x + 28.0 + index * (section_size.x + gap), top, section_size.x, section_size.y)
		var points := TacticalUIHelper.angular_points(section, 12.0)
		draw_colored_polygon(points, Color(TacticalUIHelper.MAGENTA.r, TacticalUIHelper.MAGENTA.g, TacticalUIHelper.MAGENTA.b, 0.025))
		draw_polyline(points + PackedVector2Array([points[0]]), Color(TacticalUIHelper.MAGENTA.r, TacticalUIHelper.MAGENTA.g, TacticalUIHelper.MAGENTA.b, 0.65), 1.2, true)
		draw_line(section.position + Vector2(26.0, 66.0), Vector2(section.end.x - 26.0, section.position.y + 66.0), Color(TacticalUIHelper.MAGENTA.r, TacticalUIHelper.MAGENTA.g, TacticalUIHelper.MAGENTA.b, 0.38), 1.0)
		draw_string(mono, section.position + Vector2(24.0, 42.0), headings[index], HORIZONTAL_ALIGNMENT_LEFT, section.size.x - 48.0, 15, TacticalUIHelper.MAGENTA)

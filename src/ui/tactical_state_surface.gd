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
	var width_limit := 1060.0 if kind == "terminal" else (850.0 if kind == "game_over" else 500.0)
	var height_limit := 576.0 if kind == "terminal" else (512.0 if kind == "game_over" else 510.0)
	var width := minf(width_limit, viewport.x - (28.0 if compact else 48.0))
	var height := minf(height_limit, viewport.y - (28.0 if compact else 32.0))
	width = maxf(width, 300.0 if compact else 420.0)
	height = maxf(height, 340.0)
	var y_offset := -8.0 if kind == "terminal" else 0.0
	return Rect2((viewport.x - width) * 0.5, (viewport.y - height) * 0.5 + y_offset, width, height)

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
		if index < 3:
			result.append(Rect2(panel.position + Vector2(36.0, 188.0 + index * 48.0), Vector2(pause_width, 42.0)))
		else:
			var warning: Rect2 = pause_section_rects(viewport)["warning"]
			result.append(Rect2(warning.position, Vector2(warning.size.x, 42.0)))
	return result

static func pause_section_rects(viewport: Vector2) -> Dictionary:
	var panel := panel_rect_for_viewport(viewport, "pause")
	var section_width := maxf(panel.size.x - 72.0, 180.0)
	var volume := Rect2(panel.position + Vector2(36.0, panel.size.y - 196.0), Vector2(section_width, 72.0))
	var warning := Rect2(panel.position + Vector2(36.0, panel.size.y - 112.0), Vector2(section_width, 80.0))
	return {"panel": panel, "volume": volume, "warning": warning}

func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var outer := TacticalUIHelper.shell_rect(size)
	var outer_points := TacticalUIHelper.angular_points(outer, 14.0)
	draw_polyline(outer_points + PackedVector2Array([outer_points[0]]), Color(accent.r, accent.g, accent.b, 0.5), 1.1, true)
	draw_line(outer.position + Vector2(28.0, 7.0), outer.position + Vector2(164.0, 7.0), Color(accent.r, accent.g, accent.b, 0.42), 1.0)
	draw_line(Vector2(outer.end.x - 164.0, outer.position.y + 7.0), Vector2(outer.end.x - 28.0, outer.position.y + 7.0), Color(accent.r, accent.g, accent.b, 0.42), 1.0)
	var panel := panel_rect_for_viewport(size, variant)
	var frame := TacticalUIHelper.angular_points(panel, 18.0)
	var closed := frame.duplicate()
	closed.append(frame[0])
	draw_colored_polygon(frame, Color(TacticalUIHelper.PANEL.r, TacticalUIHelper.PANEL.g, TacticalUIHelper.PANEL.b, 0.96))
	draw_colored_polygon(frame, Color(accent.r, accent.g, accent.b, 0.035))
	draw_polyline(closed, Color(accent.r, accent.g, accent.b, 0.9), 2.0, true)
	var top_line_y := panel.position.y + (54.0 if variant == "terminal" else 34.0)
	draw_line(Vector2(panel.position.x + 38.0, top_line_y), Vector2(panel.end.x - 38.0, top_line_y), Color(accent.r, accent.g, accent.b, 0.42), 1.0)
	var bottom_line_y := panel.end.y - 28.0
	draw_line(Vector2(panel.position.x + 38.0, bottom_line_y), Vector2(panel.end.x - 38.0, bottom_line_y), Color(accent.r, accent.g, accent.b, 0.42), 1.0)
	if variant == "game_over":
		_draw_game_over_sections(panel)
	elif variant == "terminal":
		_draw_terminal_sections(panel)
	else:
		_draw_pause_sections(panel)

func _draw_pause_sections(panel: Rect2) -> void:
	var mono: Font = load("res://assets/fonts/ShareTechMono.ttf")
	var info := Rect2(panel.position + Vector2(36.0, 44.0), Vector2(panel.size.x - 72.0, 38.0))
	draw_colored_polygon(TacticalUIHelper.angular_points(info, 8.0), Color(TacticalUIHelper.CYAN.r, TacticalUIHelper.CYAN.g, TacticalUIHelper.CYAN.b, 0.025))
	draw_string(mono, info.position + Vector2(14.0, 20.0), "PROCESS CONTROL // RUN STATE FROZEN", HORIZONTAL_ALIGNMENT_LEFT, info.size.x - 28.0, 11, TacticalUIHelper.MUTED)
	var sections := pause_section_rects(size)
	var volume: Rect2 = sections["volume"]
	var volume_points := TacticalUIHelper.angular_points(volume, 8.0)
	draw_colored_polygon(volume_points, Color(TacticalUIHelper.CYAN.r, TacticalUIHelper.CYAN.g, TacticalUIHelper.CYAN.b, 0.025))
	draw_polyline(volume_points + PackedVector2Array([volume_points[0]]), Color(TacticalUIHelper.CYAN.r, TacticalUIHelper.CYAN.g, TacticalUIHelper.CYAN.b, 0.38), 1.0, true)
	var warning: Rect2 = sections["warning"]
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

func _draw_terminal_sections(panel: Rect2) -> void:
	var inner := panel.grow(-20.0)
	var header_y := panel.position.y + 54.0
	var right_w := minf(360.0, inner.size.x * 0.34)
	var gap := 14.0
	var main_top := header_y + 6.0
	var footer_h := 78.0
	var main_h := inner.end.y - footer_h - main_top - 4.0
	var left := Rect2(inner.position.x, main_top, inner.size.x - right_w - gap, main_h)
	var right := Rect2(left.end.x + gap, main_top, right_w, main_h)
	var prompt := Rect2(inner.position.x, inner.end.y - footer_h, inner.size.x, footer_h - 10.0)
	for section in [left, right, prompt]:
		var points := TacticalUIHelper.angular_points(section, 9.0)
		draw_colored_polygon(points, Color(accent.r, accent.g, accent.b, 0.018))
		draw_polyline(points + PackedVector2Array([points[0]]), Color(accent.r, accent.g, accent.b, 0.58), 1.1, true)
	var command_index := Rect2(right.position + Vector2(12.0, 12.0), Vector2(right.size.x - 24.0, right.size.y * 0.66 - 18.0))
	var system_status := Rect2(right.position + Vector2(12.0, right.size.y * 0.66), Vector2(right.size.x - 24.0, right.size.y * 0.34 - 24.0))
	for section in [command_index, system_status]:
		var points := TacticalUIHelper.angular_points(section, 7.0)
		draw_polyline(points + PackedVector2Array([points[0]]), Color(accent.r, accent.g, accent.b, 0.32), 1.0, true)
	var row_height := 34.0
	for row_index in 6:
		var row := Rect2(command_index.position + Vector2(10.0, 18.0 + row_index * row_height), Vector2(command_index.size.x - 20.0, row_height - 5.0))
		var row_points := TacticalUIHelper.angular_points(row, 5.0)
		var row_color := TacticalUIHelper.MAGENTA if row_index == 5 else accent
		draw_polyline(row_points + PackedVector2Array([row_points[0]]), Color(row_color.r, row_color.g, row_color.b, 0.55), 1.0, true)

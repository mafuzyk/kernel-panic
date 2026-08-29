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
	var pause_actions: Array = pause_layout(viewport)["actions"]
	for index in mini(count, pause_actions.size()):
		result.append(pause_actions[index])
	return result

static func pause_section_rects(viewport: Vector2) -> Dictionary:
	var layout := pause_layout(viewport)
	return {"panel": layout["panel"], "volume": layout["volume"], "warning": layout["warning"]}

static func pause_layout(viewport: Vector2) -> Dictionary:
	var panel := panel_rect_for_viewport(viewport, "pause")
	var inset_x := clampf(panel.size.x * 0.055, 18.0, 36.0)
	var width := panel.size.x - inset_x * 2.0
	var scale := clampf((panel.size.y - 36.0) / 436.0, 0.68, 1.0)
	var y := panel.position.y + 18.0
	var info := Rect2(panel.position.x + inset_x, y, width, 28.0 * scale)
	y = info.end.y + 4.0 * scale
	var title := Rect2(panel.position.x + inset_x, y, width, 50.0 * scale)
	y = title.end.y
	var stats := Rect2(panel.position.x + inset_x, y, width, 46.0 * scale)
	y = stats.end.y + 8.0 * scale
	var action_height := 40.0 * scale
	var action_gap := 6.0 * scale
	var actions: Array[Rect2] = []
	for index in 3:
		actions.append(Rect2(panel.position.x + inset_x, y, width, action_height))
		y += action_height + (action_gap if index < 2 else 0.0)
	y += 8.0 * scale
	var volume := Rect2(panel.position.x + inset_x, y, width, 72.0 * scale)
	y = volume.end.y + 8.0 * scale
	var warning := Rect2(panel.position.x + inset_x, y, width, 80.0 * scale)
	var abandon := Rect2(warning.position + Vector2(8.0 * scale, 6.0 * scale), Vector2(warning.size.x - 16.0 * scale, action_height))
	var shortcuts := Rect2(warning.position + Vector2(8.0 * scale, 54.0 * scale), Vector2(warning.size.x - 16.0 * scale, 18.0 * scale))
	actions.append(abandon)
	return {
		"panel": panel,
		"info": info,
		"title": title,
		"stats": stats,
		"actions": actions,
		"volume": volume,
		"warning": warning,
		"shortcuts": shortcuts,
		"scale": scale,
	}

static func terminal_layout(viewport: Vector2) -> Dictionary:
	var panel := panel_rect_for_viewport(viewport, "terminal")
	var compact := panel.size.x < 760.0 or panel.size.y < 560.0
	var inset := 14.0 if compact else 20.0
	var inner := panel.grow(-inset)
	var header_h := 46.0 if compact else 52.0
	var prompt_h := 44.0 if compact else 48.0
	var shortcuts_h := 18.0
	var gap := 8.0 if compact else 12.0
	var header := Rect2(inner.position, Vector2(inner.size.x, header_h))
	var shortcuts := Rect2(Vector2(inner.position.x, inner.end.y - shortcuts_h), Vector2(inner.size.x, shortcuts_h))
	var prompt := Rect2(Vector2(inner.position.x, shortcuts.position.y - gap - prompt_h), Vector2(inner.size.x, prompt_h))
	var body_top := header.end.y + gap
	var body_bottom := prompt.position.y - gap
	var body_height := maxf(body_bottom - body_top, 80.0)
	var side_width := clampf(inner.size.x * 0.32, 180.0, 340.0)
	var history := Rect2(Vector2(inner.position.x, body_top), Vector2(maxf(inner.size.x - side_width - gap, 120.0), body_height))
	var side_x := history.end.x + gap
	var side_height := body_height
	var status_height := clampf(side_height * 0.28, 86.0, 124.0)
	var command_index := Rect2(Vector2(side_x, body_top), Vector2(side_width, maxf(side_height - status_height - gap, 80.0)))
	var system_status := Rect2(Vector2(side_x, command_index.end.y + gap), Vector2(side_width, status_height))
	return {
		"panel": panel,
		"header": header,
		"history": history,
		"command_index": command_index,
		"system_status": system_status,
		"prompt": prompt,
		"shortcuts": shortcuts,
		"compact": compact,
	}

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
	if variant != "terminal":
		var top_line_y := panel.position.y + 34.0
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
	var layout := pause_layout(size)
	var info: Rect2 = layout["info"]
	draw_colored_polygon(TacticalUIHelper.angular_points(info, 8.0), Color(TacticalUIHelper.CYAN.r, TacticalUIHelper.CYAN.g, TacticalUIHelper.CYAN.b, 0.025))
	draw_string(mono, info.position + Vector2(14.0, 20.0), "PROCESS CONTROL // RUN STATE FROZEN", HORIZONTAL_ALIGNMENT_LEFT, info.size.x - 28.0, 11, TacticalUIHelper.MUTED)
	var volume: Rect2 = layout["volume"]
	var volume_points := TacticalUIHelper.angular_points(volume, 8.0)
	draw_colored_polygon(volume_points, Color(TacticalUIHelper.CYAN.r, TacticalUIHelper.CYAN.g, TacticalUIHelper.CYAN.b, 0.025))
	draw_polyline(volume_points + PackedVector2Array([volume_points[0]]), Color(TacticalUIHelper.CYAN.r, TacticalUIHelper.CYAN.g, TacticalUIHelper.CYAN.b, 0.38), 1.0, true)
	var warning: Rect2 = layout["warning"]
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
	var layout := terminal_layout(size)
	for section in [layout["history"], layout["command_index"], layout["system_status"], layout["prompt"]]:
		var points := TacticalUIHelper.angular_points(section, 9.0)
		draw_colored_polygon(points, Color(accent.r, accent.g, accent.b, 0.018))
		draw_polyline(points + PackedVector2Array([points[0]]), Color(accent.r, accent.g, accent.b, 0.58), 1.1, true)

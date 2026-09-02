class_name VNextUIChrome
extends RefCounted

const Tokens = preload("res://src/ui/vnext/ui_tokens.gd")
const ShareTechMono: Font = preload("res://assets/fonts/ShareTechMono.ttf")

## The shared shell is intentionally data-light: it establishes the visual
## grammar, while each surface owns the facts displayed in its dossier.
## Keeping this layer independent prevents four near-identical shells from
## drifting in spacing, rails, and state markers.
static func signature_snapshot() -> Dictionary:
	return {
		"id": "incident_console",
		"density_model": "evidence_blocks",
		"required_questions": ["route", "state", "subject", "next_action"],
		"decorative_data_policy": "no_unsourced_metrics",
	}

static func draw_shell(canvas: CanvasItem, shell: Rect2, density: String, route: String, text_scale := 1.0, high_contrast := false) -> void:
	if shell.size.x <= 0.0 or shell.size.y <= 0.0:
		return
	var structure := Tokens.role_color("structure")
	var frame_alpha := 0.86 if high_contrast else 0.68
	var grid_alpha := 0.055 if high_contrast else 0.035
	var step := 48.0 if density == "wide" else 36.0
	var x := shell.position.x + step
	while x < shell.end.x:
		canvas.draw_line(Vector2(x, shell.position.y + 42.0), Vector2(x, shell.end.y - 30.0), Color(structure.r, structure.g, structure.b, grid_alpha), 1.0, true)
		x += step
	var y := shell.position.y + 42.0
	while y < shell.end.y - 30.0:
		canvas.draw_line(Vector2(shell.position.x + 18.0, y), Vector2(shell.end.x - 18.0, y), Color(structure.r, structure.g, structure.b, grid_alpha), 1.0, true)
		y += step
	var points := Tokens.frame_points(shell, 16.0)
	canvas.draw_polyline(points + PackedVector2Array([points[0]]), Color(structure.r, structure.g, structure.b, frame_alpha), 1.5, true)
	_draw_rail(canvas, shell, structure, high_contrast)
	_draw_shell_meta(canvas, shell, density, route, text_scale, structure)

static func draw_evidence_block(canvas: CanvasItem, rect: Rect2, heading: String, rows: Array, accent: Color, text_scale := 1.0) -> void:
	if rect.size.x < 80.0 or rect.size.y < 42.0:
		return
	var structure := accent
	var points := Tokens.frame_points(rect, minf(10.0, rect.size.y * 0.2))
	canvas.draw_colored_polygon(points, Color(structure.r, structure.g, structure.b, 0.025))
	canvas.draw_polyline(points + PackedVector2Array([points[0]]), Color(structure.r, structure.g, structure.b, 0.68), 1.0, true)
	var font_size := int(round(10.0 * text_scale))
	canvas.draw_string(ShareTechMono, rect.position + Vector2(14.0, 18.0), heading, HORIZONTAL_ALIGNMENT_LEFT, maxf(rect.size.x - 28.0, 1.0), font_size, structure)
	canvas.draw_line(rect.position + Vector2(14.0, 27.0), Vector2(rect.end.x - 14.0, rect.position.y + 27.0), Color(structure.r, structure.g, structure.b, 0.26), 1.0, true)
	var row_y := rect.position.y + 46.0
	var row_step := minf(22.0, maxf(17.0, (rect.size.y - 52.0) / maxf(float(rows.size()), 1.0)))
	for row in rows:
		if row_y > rect.end.y - 8.0:
			break
		var label := str(row.get("label", ""))
		var value := str(row.get("value", ""))
		var value_color: Color = structure
		var raw_color = row.get("color", structure)
		if raw_color is Color:
			value_color = raw_color
		canvas.draw_string(ShareTechMono, rect.position + Vector2(14.0, row_y - rect.position.y), label, HORIZONTAL_ALIGNMENT_LEFT, minf(104.0, rect.size.x * 0.28), int(round(10.0 * text_scale)), Color(structure.r, structure.g, structure.b, 0.72))
		canvas.draw_string(ShareTechMono, rect.position + Vector2(minf(116.0, rect.size.x * 0.32), row_y - rect.position.y), value, HORIZONTAL_ALIGNMENT_LEFT, maxf(rect.size.x - minf(130.0, rect.size.x * 0.36) - 14.0, 1.0), int(round(11.0 * text_scale)), value_color)
		row_y += row_step

static func _draw_rail(canvas: CanvasItem, shell: Rect2, color: Color, high_contrast: bool) -> void:
	var alpha := 0.55 if high_contrast else 0.34
	var top := shell.position.y + 52.0
	var bottom := shell.end.y - 30.0
	var left_x := shell.position.x + 12.0
	var right_x := shell.end.x - 12.0
	canvas.draw_line(Vector2(left_x, top), Vector2(left_x, bottom), Color(color.r, color.g, color.b, alpha), 1.0, true)
	canvas.draw_line(Vector2(right_x, top), Vector2(right_x, bottom), Color(color.r, color.g, color.b, alpha), 1.0, true)
	for fraction in [0.0, 0.5, 1.0]:
		var mark_y := lerpf(top, bottom, fraction)
		canvas.draw_line(Vector2(left_x - 4.0, mark_y), Vector2(left_x + 8.0, mark_y), Color(color.r, color.g, color.b, alpha + 0.12), 1.0, true)
		canvas.draw_line(Vector2(right_x - 8.0, mark_y), Vector2(right_x + 4.0, mark_y), Color(color.r, color.g, color.b, alpha + 0.12), 1.0, true)
	canvas.draw_rect(Rect2(Vector2(left_x - 2.0, top - 2.0), Vector2(4.0, 4.0)), color)
	canvas.draw_rect(Rect2(Vector2(right_x - 2.0, bottom - 2.0), Vector2(4.0, 4.0)), color)

static func _draw_shell_meta(canvas: CanvasItem, shell: Rect2, density: String, route: String, text_scale: float, color: Color) -> void:
	var font_size := int(round(12.0 * text_scale))
	var meta_y := shell.position.y + 28.0
	var short_route := route
	if density == "narrow":
		short_route = "KP://" + route.get_slice("/", 2) if route.count("/") >= 2 else route
		canvas.draw_string(ShareTechMono, Vector2(shell.position.x + 24.0, meta_y), "■ ONLINE", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		canvas.draw_string(ShareTechMono, Vector2(shell.get_center().x - 40.0 * text_scale, meta_y), short_route, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		canvas.draw_string(ShareTechMono, Vector2(shell.end.x - 48.0 * text_scale, meta_y), "GUEST", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	else:
		canvas.draw_string(ShareTechMono, Vector2(shell.position.x + 24.0, meta_y), "■  SYSTEM ONLINE", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		canvas.draw_string(ShareTechMono, Vector2(shell.get_center().x - 64.0 * text_scale, meta_y), short_route, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		canvas.draw_string(ShareTechMono, Vector2(shell.end.x - 108.0 * text_scale, meta_y), "USER: GUEST", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	canvas.draw_line(shell.position + Vector2(170.0, 38.0), shell.position + Vector2(250.0, 38.0), Color(color.r, color.g, color.b, 0.5), 1.0, true)

class_name TacticalIcon
extends Control

const TacticalUIHelper = preload("res://src/ui/tactical_ui.gd")

var _kind := "settings"
var _accent := TacticalUIHelper.CYAN
var _framed := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func configure(icon_kind: String, color: Color = TacticalUIHelper.CYAN, framed: bool = false) -> void:
	_kind = icon_kind
	_accent = color
	_framed = framed
	var raster := raster_path(icon_kind)
	if raster != "" and not _raster_tex_cache.has(raster):
		_raster_tex_cache[raster] = load(raster)
	queue_redraw()

func icon_kind() -> String:
	return _kind

## Documented quality metrics per icon kind, enforced by the harness.
## min_stroke: narrowest stroke width the primary silhouette may use.
## contrast: minimum luminance distance of the primary stroke vs TacticalUI.PANEL.
const ICON_METRICS := {
	"settings": {"min_stroke": 1.7, "contrast": 0.55},
	"bestiary": {"min_stroke": 1.7, "contrast": 0.55},
	"dash": {"min_stroke": 1.5, "contrast": 0.55},
	"back": {"min_stroke": 2.0, "contrast": 0.55},
	"resume": {"min_stroke": 1.8, "contrast": 0.55},
	"restart": {"min_stroke": 2.0, "contrast": 0.55},
	"terminal": {"min_stroke": 1.8, "contrast": 0.55},
	"audio": {"min_stroke": 1.8, "contrast": 0.55},
	"music": {"min_stroke": 1.8, "contrast": 0.55},
	"warning": {"min_stroke": 2.0, "contrast": 0.55},
	"awards": {"min_stroke": 1.8, "contrast": 0.55},
}

## Documented silhouette bounds per kind in unit space (fractions of size);
## the harness verifies containment at 24px and 52px.
const ICON_BOUNDS := {
	"settings": Rect2(0.12, 0.12, 0.76, 0.76),
	"bestiary": Rect2(0.14, 0.16, 0.72, 0.68),
	"dash": Rect2(0.08, 0.10, 0.84, 0.80),
	"back": Rect2(0.16, 0.28, 0.68, 0.44),
	"resume": Rect2(0.30, 0.18, 0.44, 0.64),
	"restart": Rect2(0.14, 0.14, 0.72, 0.72),
	"terminal": Rect2(0.16, 0.22, 0.68, 0.56),
	"audio": Rect2(0.16, 0.26, 0.68, 0.48),
	"music": Rect2(0.24, 0.12, 0.52, 0.76),
	"warning": Rect2(0.14, 0.16, 0.72, 0.68),
	"awards": Rect2(0.16, 0.14, 0.68, 0.72),
}

static func icon_kinds() -> Array:
	return ICON_METRICS.keys()

static func icon_metrics(icon_kind: String) -> Dictionary:
	var entry: Dictionary = ICON_METRICS.get(icon_kind, {})
	return {"covered": not entry.is_empty(), "min_stroke": float(entry.get("min_stroke", 0.0)), "contrast": float(entry.get("contrast", 0.0))}

static func icon_bounds(icon_kind: String) -> Rect2:
	return ICON_BOUNDS.get(icon_kind, Rect2(0.08, 0.08, 0.84, 0.84))

const RASTER_DIR := "res://assets/icons/generated/"

## Textures must finish loading before the frame that draws them: a load() first
## issued inside _draw() records the command before the GPU upload exists and
## samples the engine's white placeholder for that pass. Pre-heat the cache in
## configure() and let _draw() only consume (or prime + queue a healing redraw).
static var _raster_tex_cache := {}

## Raster registry: trial rasters only; empty string keeps the code-drawn fallback
## active. Never used as a placeholder. The identity is the neon geometric terminal
## style, not the drawing technique (author correction, 2026-08-29).
static func raster_path(icon_kind: String) -> String:
	var path := RASTER_DIR + icon_kind + ".png"
	return path if ResourceLoader.exists(path) else ""

static func music_glyph_bounds(control_size: Vector2) -> Rect2:
	var inset := maxf(2.0, minf(control_size.x, control_size.y) * 0.125)
	return Rect2(Vector2(inset, inset), control_size - Vector2(inset * 2.0, inset * 2.0))

func _line_color(alpha: float = 0.92) -> Color:
	return Color(_accent.r, _accent.g, _accent.b, alpha)

func _points_closed(points: PackedVector2Array, color: Color = _line_color(), width: float = 1.8) -> void:
	if points.is_empty():
		return
	draw_polyline(points + PackedVector2Array([points[0]]), color, width, true)

func _draw() -> void:
	if size.x <= 2.0 or size.y <= 2.0:
		return
	var raster := raster_path(_kind)
	if raster != "":
		if not _raster_tex_cache.has(raster):
			_raster_tex_cache[raster] = load(raster)
			queue_redraw()
		var tex: Texture2D = _raster_tex_cache[raster]
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
			if _framed:
				_draw_frame_overlay()
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
		"awards":
			_draw_awards(center, radius)
		_:
			_draw_bestiary(center, radius)
	if _framed:
		_draw_frame_overlay()

## Angular corner-bracket frame with cross ticks, drawn in code as a conditional
## overlay (hybrid contextual icons, author decision 2026-08-29). Only enabled
## for placements that have no existing frame; placements already framed by
## panel/button/touch chrome keep the default false so nothing is double framed.
func _draw_frame_overlay() -> void:
	var unit := minf(size.x, size.y)
	var inset := unit * 0.06
	var arm := unit * 0.16
	var rect := Rect2(Vector2(inset, inset), size - Vector2(inset * 2.0, inset * 2.0))
	var color := _line_color(0.66)
	var mid := rect.get_center()
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var x_dir := 1.0 if corner.x < mid.x else -1.0
		var y_dir := 1.0 if corner.y < mid.y else -1.0
		draw_line(corner, corner + Vector2(x_dir * arm, 0.0), color, 1.6, true)
		draw_line(corner, corner + Vector2(0.0, y_dir * arm), color, 1.6, true)
	var tick := arm * 0.34
	draw_line(Vector2(mid.x, rect.position.y - tick), Vector2(mid.x, rect.position.y + tick), color, 1.4, true)
	draw_line(Vector2(mid.x, rect.end.y - tick), Vector2(mid.x, rect.end.y + tick), color, 1.4, true)
	draw_line(Vector2(rect.position.x - tick, mid.y), Vector2(rect.position.x + tick, mid.y), color, 1.4, true)
	draw_line(Vector2(rect.end.x - tick, mid.y), Vector2(rect.end.x + tick, mid.y), color, 1.4, true)

func _draw_settings(center: Vector2, radius: float) -> void:
	var gear := PackedVector2Array()
	for index in 16:
		var angle := TAU * float(index) / 16.0 - PI / 2.0
		var ring := radius if index % 2 == 0 else radius * 0.74
		gear.append(center + Vector2.from_angle(angle) * ring)
	_points_closed(gear, _line_color(), 2.0)
	draw_arc(center, radius * 0.46, 0.0, TAU, 20, _line_color(), 1.7, true)
	draw_circle(center, radius * 0.12, _line_color())

func _draw_bestiary(center: Vector2, radius: float) -> void:
	var eye := PackedVector2Array([
		center + Vector2(-radius, 0.0),
		center + Vector2(-radius * 0.34, -radius * 0.64),
		center + Vector2(radius * 0.44, -radius * 0.52),
		center + Vector2(radius, 0.0),
		center + Vector2(radius * 0.44, radius * 0.52),
		center + Vector2(-radius * 0.34, radius * 0.64),
	])
	_points_closed(eye, _line_color(), 2.0)
	draw_arc(center, radius * 0.33, 0.0, TAU, 18, _line_color(), 1.7, true)
	draw_circle(center, radius * 0.14, _line_color())

func _draw_dash(center: Vector2, radius: float) -> void:
	var badge := Rect2(center - Vector2(radius * 1.18, radius * 0.90), Vector2(radius * 2.36, radius * 1.80))
	var badge_points := TacticalUIHelper.angular_points(badge, radius * 0.28)
	draw_colored_polygon(badge_points, Color(_accent.r, _accent.g, _accent.b, 0.10))
	_points_closed(badge_points, _line_color(0.72), 1.5)
	for index in 3:
		var x := center.x - radius * 0.62 + float(index) * radius * 0.62
		var points := PackedVector2Array([
			Vector2(x - radius * 0.25, center.y - radius * 0.55),
			Vector2(x + radius * 0.26, center.y),
			Vector2(x - radius * 0.25, center.y + radius * 0.55),
		])
		draw_colored_polygon(points, _line_color())
		_points_closed(points, _line_color(), 2.2)

func _draw_back(center: Vector2, radius: float) -> void:
	draw_line(Vector2(center.x - radius * 0.62, center.y), Vector2(center.x + radius * 0.62, center.y), _line_color(), 2.2)
	var head := PackedVector2Array([
		Vector2(center.x - radius * 0.70, center.y),
		Vector2(center.x - radius * 0.10, center.y - radius * 0.50),
		Vector2(center.x - radius * 0.10, center.y + radius * 0.50),
	])
	draw_colored_polygon(head, _line_color())

func _draw_resume(center: Vector2, radius: float) -> void:
	var triangle := PackedVector2Array([
		center + Vector2(-radius * 0.34, -radius * 0.62),
		center + Vector2(radius * 0.58, 0.0),
		center + Vector2(-radius * 0.34, radius * 0.62),
	])
	draw_colored_polygon(triangle, Color(_accent.r, _accent.g, _accent.b, 0.16))
	_points_closed(triangle, _line_color(), 2.0)

func _draw_restart(center: Vector2, radius: float) -> void:
	draw_arc(center, radius * 0.68, -PI * 0.80, PI * 0.92, 20, _line_color(), 2.2, true)
	var tip := center + Vector2.from_angle(-PI * 0.80) * radius * 0.68
	var arrow := PackedVector2Array([
		tip,
		tip + Vector2(radius * 0.46, -radius * 0.06),
		tip + Vector2(radius * 0.12, radius * 0.36),
	])
	draw_colored_polygon(arrow, _line_color())

func _draw_terminal(center: Vector2, radius: float) -> void:
	var box := Rect2(center - Vector2(radius * 0.78, radius * 0.56), Vector2(radius * 1.56, radius * 1.12))
	_points_closed(TacticalUIHelper.angular_points(box, radius * 0.18), _line_color(), 1.8)
	draw_line(center + Vector2(-radius * 0.45, -radius * 0.12), center + Vector2(-radius * 0.10, center.y * 0.0), _line_color(), 2.2)
	draw_line(center + Vector2(-radius * 0.10, center.y * 0.0), center + Vector2(-radius * 0.45, radius * 0.26), _line_color(), 2.2)
	draw_line(center + Vector2(radius * 0.06, radius * 0.28), center + Vector2(radius * 0.42, radius * 0.28), _line_color(), 2.2)

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
	_points_closed(speaker, _line_color(), 2.0)
	draw_arc(center, radius * 0.54, -PI * 0.42, PI * 0.42, 12, _line_color(0.80), 2.0, true)
	draw_arc(center, radius * 0.78, -PI * 0.34, PI * 0.34, 12, _line_color(0.55), 2.0, true)

func _draw_music(center: Vector2, radius: float) -> void:
	var glyph := music_glyph_bounds(size)
	var stem_x := glyph.position.x + glyph.size.x * 0.58
	var stem_top := glyph.position.y + glyph.size.y * 0.12
	var stem_bottom := glyph.position.y + glyph.size.y * 0.72
	var head_center := Vector2(glyph.position.x + glyph.size.x * 0.38, glyph.position.y + glyph.size.y * 0.76)
	draw_line(Vector2(stem_x, stem_top), Vector2(stem_x, stem_bottom), _line_color(), 2.2)
	draw_line(Vector2(stem_x, stem_top), Vector2(glyph.position.x + glyph.size.x * 0.84, glyph.position.y + glyph.size.y * 0.22), _line_color(), 2.2)
	draw_circle(head_center, glyph.size.x * 0.18, _line_color())

func _draw_warning(center: Vector2, radius: float) -> void:
	var triangle := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.78),
		center + Vector2(radius * 0.72, radius * 0.60),
		center + Vector2(-radius * 0.72, radius * 0.60),
	])
	_points_closed(triangle, _line_color(), 2.2)
	draw_rect(Rect2(center + Vector2(-1.6, -radius * 0.36), Vector2(3.2, radius * 0.58)), _line_color())
	draw_circle(center + Vector2(0.0, radius * 0.43), radius * 0.10, _line_color())

func _draw_awards(center: Vector2, radius: float) -> void:
	var cup := PackedVector2Array([
		center + Vector2(-radius * 0.52, -radius * 0.66),
		center + Vector2(radius * 0.52, -radius * 0.66),
		center + Vector2(radius * 0.40, radius * 0.10),
		center + Vector2(0.0, radius * 0.30),
		center + Vector2(-radius * 0.40, radius * 0.10),
	])
	draw_colored_polygon(cup, Color(_accent.r, _accent.g, _accent.b, 0.14))
	_points_closed(cup, _line_color(), 2.0)
	draw_line(center + Vector2(-radius * 0.52, -radius * 0.66), center + Vector2(-radius * 0.78, -radius * 0.36), _line_color(), 1.8, true)
	draw_line(center + Vector2(-radius * 0.78, -radius * 0.36), center + Vector2(-radius * 0.42, -radius * 0.06), _line_color(), 1.8, true)
	draw_line(center + Vector2(radius * 0.52, -radius * 0.66), center + Vector2(radius * 0.78, -radius * 0.36), _line_color(), 1.8, true)
	draw_line(center + Vector2(radius * 0.78, -radius * 0.36), center + Vector2(radius * 0.42, -radius * 0.06), _line_color(), 1.8, true)
	draw_line(center + Vector2(0.0, radius * 0.30), center + Vector2(0.0, radius * 0.58), _line_color(), 2.0)
	draw_line(center + Vector2(-radius * 0.30, radius * 0.58), center + Vector2(radius * 0.30, radius * 0.58), _line_color(), 2.2)

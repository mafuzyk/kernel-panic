class_name VNextEntityRenderer
extends RefCounted

const BalanceData = preload("res://src/autoload/balance.gd")
const Descriptor = preload("res://src/ui/vnext/core/entity_descriptor.gd")
const Glyphs = preload("res://src/ui/glyph_lib.gd")

const MARKER_EXTENT := 1.38

const KIND_COLORS := {
	"drone": BalanceData.COL_DRONE,
	"kernel": BalanceData.COL_PLAYER,
	"daemon": BalanceData.COL_PLAYER_HOT,
	"rootlet": BalanceData.COL_PLAYER,
}

static func fit_rect(snapshot: Dictionary, target: Rect2) -> Rect2:
	## Body allocation; the published marker-aware envelope is draw_bounds().
	var normalized := Descriptor.normalize(snapshot)
	return _fit_normalized(normalized, target)

static func _available_side(target: Rect2) -> float:
	if target.size.x <= 0.0 or target.size.y <= 0.0:
		return 0.0
	var inset := minf(4.0, minf(target.size.x, target.size.y) * 0.2)
	return maxf(minf(target.size.x, target.size.y) - inset * 2.0, 0.0)

static func _fit_normalized(normalized: Dictionary, target: Rect2) -> Rect2:
	var available_side := _available_side(target)
	if available_side <= 0.0:
		return Rect2(target.get_center(), Vector2.ZERO)
	var side := available_side / _draw_extent_factor_normalized(normalized)
	return Rect2(target.get_center() - Vector2.ONE * side * 0.5, Vector2.ONE * side)

static func draw_bounds(snapshot: Dictionary, target: Rect2) -> Rect2:
	## Full visible envelope, including glyph details and interaction markers.
	var normalized := Descriptor.normalize(snapshot)
	return _draw_bounds_normalized(normalized, target)

static func _draw_bounds_normalized(normalized: Dictionary, target: Rect2) -> Rect2:
	var body_rect := _fit_normalized(normalized, target)
	var side := body_rect.size.x * _draw_extent_factor_normalized(normalized)
	return Rect2(target.get_center() - Vector2.ONE * side * 0.5, Vector2.ONE * side)

static func draw_extent_factor(snapshot: Dictionary) -> float:
	var normalized := Descriptor.normalize(snapshot)
	return _draw_extent_factor_normalized(normalized)

static func _draw_extent_factor_normalized(normalized: Dictionary) -> float:
	return maxf(Glyphs.glyph_extent(str(normalized["kind"])), MARKER_EXTENT)

static func draw_radius(snapshot: Dictionary, target: Rect2) -> float:
	## Radius for GlyphLib's identity inside the body's fitted allocation.
	var normalized := Descriptor.normalize(snapshot)
	var rect := _fit_normalized(normalized, target)
	return _draw_radius_normalized(normalized, rect)

static func draw_radius_from_bounds(snapshot: Dictionary, bounds: Rect2) -> float:
	## Radius for GlyphLib's identity when the caller already has draw_bounds().
	var normalized := Descriptor.normalize(snapshot)
	return _draw_radius_normalized(normalized, _body_from_bounds_normalized(normalized, bounds))

static func _body_from_bounds_normalized(normalized: Dictionary, bounds: Rect2) -> Rect2:
	var side := maxf(minf(bounds.size.x, bounds.size.y), 0.0) / _draw_extent_factor_normalized(normalized)
	return Rect2(bounds.get_center() - Vector2.ONE * side * 0.5, Vector2.ONE * side)

static func _draw_radius_normalized(normalized: Dictionary, body_rect: Rect2) -> float:
	return body_rect.size.x * 0.5 / maxf(Glyphs.glyph_extent(str(normalized["kind"])), 1.0)

static func orientation_angle(snapshot: Dictionary) -> float:
	return _orientation_angle_normalized(Descriptor.normalize(snapshot))

static func _orientation_angle_normalized(normalized: Dictionary) -> float:
	return normalized["facing"].angle()

static func color_for(snapshot: Dictionary, quality: Dictionary = {}) -> Color:
	var normalized := Descriptor.normalize(snapshot)
	return _color_for_normalized(normalized, quality)

static func _color_for_normalized(normalized: Dictionary, quality: Dictionary) -> Color:
	var color: Color = KIND_COLORS.get(str(normalized["kind"]), BalanceData.COL_PLAYER)
	color = Glyphs.era_mix(color, normalized["era_accent"], 0.25)
	if bool(quality.get("grayscale", false)):
		var luminance := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
		color = Color(luminance, luminance, luminance, color.a)
	return color

static func render_key(snapshot: Dictionary, cosmetic_time: float, quality: Dictionary) -> String:
	var normalized := Descriptor.normalize(snapshot)
	return "%s|%s|%s|%s|%s|%s|%.4f|%s" % [normalized.get("kind"), normalized.get("visual_state"), _canonical(normalized.get("facing")), normalized.get("hp_fraction"), normalized.get("elite"), _canonical(normalized.get("era_accent")), cosmetic_time, _canonical(quality)]

static func _canonical(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort()
		var pairs := PackedStringArray()
		for key in keys:
			pairs.append("%s=%s" % [str(key), _canonical(value[key])])
		return "{" + ",".join(pairs) + "}"
	if value is Array:
		var items := PackedStringArray()
		for item in value:
			items.append(_canonical(item))
		return "[" + ",".join(items) + "]"
	if value is Vector2:
		return "v2:%.6f,%.6f" % [value.x, value.y]
	if value is Color:
		return "c:%.6f,%.6f,%.6f,%.6f" % [value.r, value.g, value.b, value.a]
	return str(value)

static func draw(canvas: CanvasItem, snapshot: Dictionary, target: Rect2, cosmetic_time: float = 0.0, quality: Dictionary = {}) -> void:
	if canvas == null:
		return
	var normalized := Descriptor.normalize(snapshot)
	var body_rect := _fit_normalized(normalized, target)
	if body_rect.size.x <= 0.0:
		return
	var center := body_rect.get_center()
	var radius := _draw_radius_normalized(normalized, body_rect)
	var color := _color_for_normalized(normalized, quality)
	var facing: Vector2 = normalized["facing"]
	var assist := bool(quality.get("color_assist", false))
	var reduced_motion := bool(quality.get("reduced_motion", false))
	canvas.draw_set_transform(center, _orientation_angle_normalized(normalized), Vector2.ONE)
	Glyphs.draw_glyph(canvas, str(normalized["kind"]), Vector2.ZERO, radius, color, 0.0 if reduced_motion else cosmetic_time)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	canvas.draw_line(center, center + facing * radius * 1.25, Color(color.r, color.g, color.b, 0.9), maxf(1.0, radius * 0.08), true)
	if assist:
		canvas.draw_arc(center, radius * 1.18, facing.angle() - 0.35, facing.angle() + 0.35, 8, BalanceData.COL_TEXT, maxf(1.0, radius * 0.07), true)
	_draw_state(canvas, center, radius * 1.2, str(normalized["visual_state"]), BalanceData.COL_TEXT)
	if bool(normalized["elite"]):
		canvas.draw_arc(center, radius * 1.32, 0.0, TAU, 24, BalanceData.COL_MOTE, maxf(1.0, radius * 0.06), true)

static func _draw_state(canvas: CanvasItem, center: Vector2, radius: float, state: String, color: Color) -> void:
	match state:
		"attack":
			canvas.draw_line(center + Vector2(-radius, radius), center + Vector2(-radius + 8.0, radius - 8.0), color, 2.0, true)
		"hit":
			canvas.draw_line(center + Vector2(-radius, -radius), center + Vector2(radius, radius), color, 2.0, true)
			canvas.draw_line(center + Vector2(radius, -radius), center + Vector2(-radius, radius), color, 2.0, true)
		"death":
			canvas.draw_arc(center, radius, 0.0, PI, 12, color, 2.0, true)
		"elite":
			canvas.draw_circle(center, maxf(1.5, radius * 0.1), color)

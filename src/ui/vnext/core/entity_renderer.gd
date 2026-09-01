class_name VNextEntityRenderer
extends RefCounted

const BalanceData = preload("res://src/autoload/balance.gd")
const Descriptor = preload("res://src/ui/vnext/core/entity_descriptor.gd")
const Glyphs = preload("res://src/ui/glyph_lib.gd")

const KIND_COLORS := {
	"drone": BalanceData.COL_DRONE,
	"kernel": BalanceData.COL_PLAYER,
	"daemon": BalanceData.COL_PLAYER_HOT,
	"rootlet": BalanceData.COL_PLAYER,
}

static func fit_rect(snapshot: Dictionary, target: Rect2) -> Rect2:
	var normalized := Descriptor.normalize(snapshot)
	if target.size.x <= 0.0 or target.size.y <= 0.0:
		return Rect2(target.get_center(), Vector2.ZERO)
	var inset := minf(4.0, minf(target.size.x, target.size.y) * 0.2)
	var side := maxf(minf(target.size.x, target.size.y) - inset * 2.0, 0.0)
	return Rect2(target.get_center() - Vector2.ONE * side * 0.5, Vector2.ONE * side)

static func draw_bounds(snapshot: Dictionary, target: Rect2) -> Rect2:
	return fit_rect(snapshot, target)

static func render_key(snapshot: Dictionary, cosmetic_time: float, quality: Dictionary) -> String:
	var normalized := Descriptor.normalize(snapshot)
	return "%s|%s|%s|%.4f|%s" % [normalized.get("kind"), normalized.get("visual_state"), normalized.get("facing"), cosmetic_time, quality]

static func draw(canvas: CanvasItem, snapshot: Dictionary, target: Rect2, cosmetic_time: float = 0.0, quality: Dictionary = {}) -> void:
	if canvas == null:
		return
	var normalized := Descriptor.normalize(snapshot)
	var rect := fit_rect(normalized, target)
	if rect.size.x <= 0.0:
		return
	var center := rect.get_center()
	var radius := rect.size.x * 0.5 / maxf(Glyphs.glyph_extent(str(normalized["kind"])), 1.0)
	var color: Color = KIND_COLORS.get(str(normalized["kind"]), BalanceData.COL_PLAYER)
	if bool(quality.get("grayscale", false)):
		color = Color(0.75, 0.75, 0.75, color.a)
	var facing: Vector2 = normalized["facing"]
	var assist := bool(quality.get("color_assist", false))
	var reduced_motion := bool(quality.get("reduced_motion", false))
	Glyphs.draw_glyph(canvas, str(normalized["kind"]), center, radius, color, 0.0 if reduced_motion else cosmetic_time)
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

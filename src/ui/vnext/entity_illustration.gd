class_name VNextEntityIllustration
extends Control

const Tokens = preload("res://src/ui/vnext/ui_tokens.gd")
const Glyphs = preload("res://src/ui/glyph_lib.gd")

const ENTITY_COLORS := {
	"drone": Color("#42e8ff"),
	"lancer": Color("#42e8ff"),
	"oom": Color("#9d72ff"),
	"god": Color("#f4b942"),
	"kernel": Color("#4ff2ff"),
	"daemon": Color("#ff5b88"),
	"rootlet": Color("#9dff72"),
}
const STATES := ["idle", "ready", "locked", "danger"]

var _kind := "drone"
var _state := "idle"
var _label := ""
var _motion_phase := 0.0
var _last_size := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func configure_entity(kind: String, state: String = "idle", label: String = "") -> void:
	_kind = kind if kind in Glyphs.glyph_kinds() else "drone"
	_state = state if state in STATES else "idle"
	_label = label
	queue_redraw()

func set_motion_phase(phase: float) -> void:
	_motion_phase = phase
	queue_redraw()

func visual_rect(viewport: Vector2 = Vector2.ZERO) -> Rect2:
	var target := viewport if viewport != Vector2.ZERO else size
	var safe := Tokens.safe_rect(target, 16.0)
	var side := minf(safe.size.x, safe.size.y)
	return Rect2(safe.get_center() - Vector2.ONE * side * 0.5, Vector2.ONE * side)

func glyph_radius(rect: Rect2 = visual_rect()) -> float:
	return rect.size.x * 0.5 / maxf(Glyphs.glyph_extent(_kind), 1.0)

func visual_snapshot() -> Dictionary:
	var state_visual: Dictionary = Tokens.state_visual(_state)
	return {
		"kind": _kind,
		"state": _state,
		"state_label": str(state_visual.get("label", "STANDBY")),
		"state_pattern": str(state_visual.get("pattern", "steady")),
		"label": _label,
		"renderer": "glyph-library",
		"glyph_extent": Glyphs.glyph_extent(_kind),
		"frame": visual_rect(),
	}

func text_overflow_report() -> Array:
	return [
		{"id": "entity_label", "fits": _label.is_empty() or _label.length() <= 24},
		{"id": "entity_state_label", "fits": Tokens.state_label(_state).length() <= 12},
	]

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and size != _last_size:
		_last_size = size
		queue_redraw()

func _draw() -> void:
	var rect := visual_rect()
	if rect.size.x <= 2.0 or rect.size.y <= 2.0:
		return
	var center := rect.get_center()
	var radius := glyph_radius(rect)
	var base_color: Color = ENTITY_COLORS.get(_kind, Tokens.role_color("structure"))
	var state_visual: Dictionary = Tokens.state_visual(_state)
	var state_color := Tokens.role_color(str(state_visual.get("role", "structure")))
	var reach := radius * Glyphs.glyph_extent(_kind)

	# The ring is a state channel, while GlyphLib remains the identity channel.
	# This makes a hit/lock/ready state legible without recolouring the entity.
	draw_arc(center, minf(rect.size.x * 0.46, reach + 10.0), 0.0, TAU, 48, Color(state_color.r, state_color.g, state_color.b, 0.22), 1.0, true)
	Glyphs.draw_glyph(self, _kind, center, radius, base_color, _motion_phase)
	_draw_state_marks(center, minf(rect.size.x * 0.46, reach + 10.0), state_visual)

func _draw_state_marks(center: Vector2, radius: float, state_visual: Dictionary) -> void:
	var state_color := Tokens.role_color(str(state_visual.get("role", "structure")))
	match str(state_visual.get("pattern", "steady")):
		"pulse":
			draw_arc(center, radius + 5.0, -PI * 0.75, -PI * 0.25, 18, state_color, 2.0, true)
		"break":
			draw_line(center + Vector2(-radius, -radius), center + Vector2(-radius + 8.0, -radius + 8.0), state_color, 2.0, true)
			draw_line(center + Vector2(radius, radius), center + Vector2(radius - 8.0, radius - 8.0), state_color, 2.0, true)
		"hatch":
			for i in 3:
				var offset := -radius * 0.35 + i * radius * 0.35
				draw_line(center + Vector2(-radius, offset), center + Vector2(-radius + 8.0, offset - 8.0), state_color, 1.2, true)
		_:
			draw_circle(center, 2.5, state_color)

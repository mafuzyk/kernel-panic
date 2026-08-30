class_name PatchCard
extends Control

signal selected(index: int)

const TacticalUIHelper = preload("res://src/ui/tactical_ui.gd")

var _def: Dictionary = {}
var _index := 0
var _level := 0
var _hovered := false
var _mono: Font
var _orbitron: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_mono = load("res://assets/fonts/ShareTechMono.ttf")
	_orbitron = load("res://assets/fonts/Orbitron.ttf")
	mouse_entered.connect(func() -> void:
		_hovered = true
		queue_redraw()
	)
	mouse_exited.connect(func() -> void:
		_hovered = false
		queue_redraw()
	)

func configure(definition: Dictionary, index: int) -> void:
	_def = definition.duplicate(true)
	_index = index
	_level = Game.patch_level(str(_def.get("id", "")))
	queue_redraw()

func frame_points() -> PackedVector2Array:
	return TacticalUIHelper.angular_points(Rect2(Vector2.ZERO, size), 14.0)

func rarity_label() -> String:
	if bool(_def.get("legend", false)):
		return "LEGENDARY"
	if bool(_def.get("rare", false)):
		return "RARE"
	return "STANDARD"

func card_title() -> String:
	return str(_def.get("title", "PATCH"))

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected.emit(_index)
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		selected.emit(_index)
		accept_event()

func _accent() -> Color:
	if bool(_def.get("legend", false)):
		return TacticalUIHelper.AMBER
	if bool(_def.get("rare", false)):
		return Color("b46bff")
	return TacticalUIHelper.CYAN

func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var accent := _accent()
	var points := frame_points()
	var closed := points.duplicate()
	closed.append(points[0])
	draw_colored_polygon(points, Color(accent.r, accent.g, accent.b, 0.12 if _hovered else 0.07))
	draw_colored_polygon(TacticalUIHelper.angular_points(Rect2(2, 2, size.x - 4, size.y - 4), 12.0), Color(TacticalUIHelper.PANEL.r, TacticalUIHelper.PANEL.g, TacticalUIHelper.PANEL.b, 0.84))
	draw_polyline(closed, Color(accent.r, accent.g, accent.b, 1.0 if _hovered else 0.82), 2.4 if _hovered else 1.6, true)
	var top_tag := Rect2(20.0, 22.0, 42.0, 32.0)
	var tag_points := TacticalUIHelper.angular_points(top_tag, 7.0)
	var tag_closed := tag_points.duplicate()
	tag_closed.append(tag_points[0])
	draw_colored_polygon(tag_points, Color(accent.r, accent.g, accent.b, 0.08))
	draw_polyline(tag_closed, Color(accent.r, accent.g, accent.b, 0.85), 1.2, true)
	draw_string(_mono, top_tag.position + Vector2(0.0, 22.0), "%d" % (_index + 1), HORIZONTAL_ALIGNMENT_CENTER, top_tag.size.x, 15, accent)
	draw_string(_mono, Vector2(76.0, 43.0), rarity_label(), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 96.0, 12, accent)
	draw_string(_orbitron, Vector2(22.0, 94.0), card_title(), HORIZONTAL_ALIGNMENT_LEFT, size.x - 44.0, 21, TacticalUIHelper.TEXT)
	_draw_icon(Vector2(58.0, 157.0), accent)
	var desc_size: int = TacticalUI.fit_block(_mono, str(_def.get("desc", "")), size.x - 148.0, 54.0, 13, 10)["font_size"]
	draw_multiline_string(_mono, Vector2(126.0, 143.0), str(_def.get("desc", "")), HORIZONTAL_ALIGNMENT_LEFT, size.x - 148.0, desc_size, 4, TacticalUIHelper.TEXT)
	var line_y := size.y - 66.0
	draw_line(Vector2(20.0, line_y), Vector2(size.x - 20.0, line_y), Color(accent.r, accent.g, accent.b, 0.46), 1.0)
	var level_text := "LEVEL %d > %d" % [_level, _level + 1] if _level > 0 else "NEW PATCH"
	draw_string(_mono, Vector2(22.0, line_y + 25.0), level_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 44.0, 13, accent)
	for dot in 4:
		var dot_col := accent if dot <= _level else Color(accent.r, accent.g, accent.b, 0.35)
		draw_circle(Vector2(28.0 + dot * 18.0, size.y - 18.0), 4.0, dot_col)

func _draw_icon(center: Vector2, accent: Color) -> void:
	var points := PackedVector2Array()
	for i in 6:
		var angle := -PI * 0.5 + TAU * float(i) / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * 34.0)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_colored_polygon(points, Color(accent.r, accent.g, accent.b, 0.08))
	draw_polyline(closed, accent, 2.0, true)
	var id := str(_def.get("id", ""))
	var raster := patch_raster_path(id)
	if raster != "":
		if not _raster_tex_cache.has(raster):
			_raster_tex_cache[raster] = load(raster)
			queue_redraw()
		var tex: Texture2D = _raster_tex_cache[raster]
		if tex != null:
			draw_texture_rect(tex, Rect2(center - Vector2(26.0, 26.0), Vector2(52.0, 52.0)), false)
			return
	match patch_icon_family(id):
		"damage":
			_draw_damage_glyph(center, accent)
		"fire":
			_draw_fire_glyph(center, accent)
		"defense":
			_draw_defense_glyph(center, accent)
		"utility":
			_draw_utility_glyph(center, accent)
		"movement":
			_draw_movement_glyph(center, accent)
		"economy":
			_draw_economy_glyph(center, accent)

## Patch icon family table: every Game.PATCH_CODES id maps to one of six visual
## families so hex icons share a silhouette language per effect type.
const PATCH_ICON_FAMILIES := {
	"heavy": "damage", "core": "damage", "splitshot": "damage", "ricochet": "damage", "pdash": "damage", "thorns": "damage", "staticf": "damage",
	"rapid": "fire", "threads": "fire", "chain": "fire",
	"hp": "defense", "shield": "defense", "absorb": "defense", "restore": "defense", "secondwind": "defense", "vampic": "defense", "recycler": "defense", "dataleech": "defense",
	"cell": "utility", "magnet": "utility",
	"dash": "movement", "mdash": "movement", "turbo": "movement", "light": "movement",
	"frag": "economy", "scrapdiet": "economy",
}

const RASTER_DIR := "res://assets/icons/generated/"

## Textures must finish loading before the frame that draws them: a load() first
## issued inside _draw() records the command before the GPU upload exists and
## samples the engine's white placeholder for that pass (same quirk as
## tactical_icon; the cache primes + queues one healing redraw instead).
static var _raster_tex_cache := {}

static func patch_icon_family(id: String) -> String:
	return str(PATCH_ICON_FAMILIES.get(id, "utility"))

static func patch_icon_metrics(id: String) -> Dictionary:
	return {"covered": PATCH_ICON_FAMILIES.has(id), "min_stroke": 2.0, "contrast": 0.55}

static func patch_raster_path(id: String) -> String:
	var path := RASTER_DIR + "patch_" + id + ".png"
	return path if ResourceLoader.exists(path) else ""

func _draw_damage_glyph(center: Vector2, accent: Color) -> void:
	for i in 3:
		var a := -PI * 0.5 + TAU * float(i) / 3.0
		var tip := center + Vector2.from_angle(a) * 22.0
		var left := center + Vector2.from_angle(a - 0.42) * 8.0
		var right := center + Vector2.from_angle(a + 0.42) * 8.0
		draw_colored_polygon(PackedVector2Array([tip, left, right]), accent)
	draw_arc(center, 7.0, 0.0, TAU, 16, accent, 2.0, true)

func _draw_fire_glyph(center: Vector2, accent: Color) -> void:
	for i in 3:
		var x := center.x - 14.0 + float(i) * 10.0
		var pts := PackedVector2Array([Vector2(x, center.y - 10.0), Vector2(x + 8.0, center.y), Vector2(x, center.y + 10.0)])
		draw_polyline(pts, accent, 2.2, true)

func _draw_defense_glyph(center: Vector2, accent: Color) -> void:
	var pts := PackedVector2Array([
		center + Vector2(0.0, -20.0), center + Vector2(15.0, -12.0), center + Vector2(15.0, 4.0),
		center + Vector2(0.0, 20.0), center + Vector2(-15.0, 4.0), center + Vector2(-15.0, -12.0),
	])
	draw_colored_polygon(pts, Color(accent.r, accent.g, accent.b, 0.14))
	draw_polyline(pts + PackedVector2Array([pts[0]]), accent, 2.2, true)
	draw_line(center + Vector2(0.0, -12.0), center + Vector2(0.0, 12.0), accent, 2.0)

func _draw_utility_glyph(center: Vector2, accent: Color) -> void:
	var nut := PackedVector2Array()
	for i in 6:
		nut.append(center + Vector2.from_angle(TAU * float(i) / 6.0) * 15.0)
	draw_polyline(nut + PackedVector2Array([nut[0]]), accent, 2.2, true)
	draw_circle(center, 5.0, accent)

func _draw_movement_glyph(center: Vector2, accent: Color) -> void:
	draw_line(center + Vector2(-16.0, 6.0), center + Vector2(2.0, 6.0), Color(accent.r, accent.g, accent.b, 0.6), 2.0)
	draw_line(center + Vector2(-10.0, -2.0), center + Vector2(8.0, -2.0), accent, 2.2)
	draw_colored_polygon(PackedVector2Array([center + Vector2(8.0, -8.0), center + Vector2(16.0, -2.0), center + Vector2(8.0, 4.0)]), accent)

func _draw_economy_glyph(center: Vector2, accent: Color) -> void:
	for offset in [Vector2(-12.0, -8.0), Vector2(-4.0, 2.0), Vector2(6.0, -4.0)]:
		draw_circle(center + offset, 4.0, accent)
	draw_line(center + Vector2(-14.0, 12.0), center + Vector2(14.0, 12.0), accent, 2.0)

func text_overflow_report() -> Array:
	var mono: Font = load("res://assets/fonts/ShareTechMono.ttf")
	var out: Array = []
	var longest_desc := ""
	for definition in Game.PATCH_DEFS:
		if str(definition.get("desc", "")).length() > longest_desc.length():
			longest_desc = str(definition.get("desc", ""))
	out.append({"id": "patch_desc", "fits": TacticalUI.wrapped_height(mono, longest_desc, size.x - 148.0, 13) <= 54.0 or TacticalUI.wrapped_height(mono, longest_desc, size.x - 148.0, 10) <= 54.0})
	return out

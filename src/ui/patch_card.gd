class_name PatchCard
extends Control

## Card de patch na direção editorial.
##
## O card antigo era uma pilha de molduras angulares desenhadas em `_draw()`:
## frame externo, frame interno, tag angular e hexágono, todos competindo com o
## conteúdo. Aqui a hierarquia vem de tipo, espaço e uma única régua de raridade.
## A cor fica no papel de marcador; título e descrição voltam para tinta neutra.

signal selected(index: int)

const CARD_PAD := Design.SPACE_LG
const ICON_SLOT := 64.0
const ICON_DRAW_SIZE := 52.0
const LONG_TITLE_SIZE := 28

var _def: Dictionary = {}
var _index := 0
var _level := 0

var _surface: PanelContainer
var _index_label: Label
var _rarity: Label
var _title: Label
var _desc: Label
var _icon_slot: Control
var _marker_rule: ColorRect
var _level_label: Label
var _level_marks: Label


func _ready() -> void:
	theme = UiTheme.shared()
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()
	_refresh()


## Arena chama `configure()` antes de o card entrar na árvore. Mantenha esse
## contrato: os dados são guardados imediatamente e a árvore visual só é tocada
## depois de `_ready()` existir.
func configure(definition: Dictionary, index: int) -> void:
	_def = definition.duplicate(true)
	_index = index
	_level = Game.patch_level(str(_def.get("id", "")))
	if is_node_ready():
		_refresh()


func rarity_label() -> String:
	if bool(_def.get("legend", false)):
		return "LEGENDARY"
	if bool(_def.get("rare", false)):
		return "RARE"
	return "STANDARD"


func card_title() -> String:
	return str(_def.get("title", "PATCH"))


## Papéis de tinta. Raridade é informação, mas não deve tingir o conteúdo todo.
func card_ink() -> Dictionary:
	return {
		"title": Design.TEXT_PRIMARY,
		"body": Design.TEXT_SECONDARY,
		"meta": Design.TEXT_MUTED,
		"marker": _accent(),
	}


func _accent() -> Color:
	if bool(_def.get("legend", false)):
		return Design.WARNING
	if bool(_def.get("rare", false)):
		return Color("b46bff")
	return Design.ACCENT


## Retângulos reais do conteúdo. O harness usa isso em vez de depender das
## coordenadas da antiga rotina `_draw()`.
func content_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for node in [_index_label, _rarity, _title, _desc, _icon_slot, _marker_rule, _level_label, _level_marks]:
		if node != null and is_instance_valid(node) and node.is_visible_in_tree():
			out.append(Rect2(node.global_position - global_position, node.size))
	return out


func _build() -> void:
	_surface = PanelContainer.new()
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var surface_box := StyleBoxFlat.new()
	surface_box.bg_color = Design.SURFACE_SUNKEN
	_surface.add_theme_stylebox_override("panel", surface_box)
	add_child(_surface)

	var pad := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, CARD_PAD)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(col)

	var eyebrow := HBoxContainer.new()
	eyebrow.add_theme_constant_override("separation", Design.SPACE_SM)
	eyebrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(eyebrow)
	_index_label = ScreenKit.mono("", Design.TEXT_MICRO, Design.ACCENT)
	eyebrow.add_child(_index_label)
	ScreenKit.grow_h(eyebrow)
	_rarity = ScreenKit.mono("", Design.TEXT_MICRO, Design.ACCENT)
	eyebrow.add_child(_rarity)

	ScreenKit.gap(col, Design.SPACE_SM)
	_title = ScreenKit.grot("", Design.TEXT_HEADING, Design.WEIGHT_BLACK, Design.TEXT_PRIMARY)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Label vazio nasce com mínimo vertical quase nulo quando o card é construído
	# antes de `configure()` propagar o texto. Reserve uma linha editorial real;
	# títulos longos ainda podem crescer por autowrap.
	_title.custom_minimum_size.y = Design.TEXT_HEADING
	col.add_child(_title)

	ScreenKit.gap(col, Design.SPACE_MD)
	_marker_rule = ColorRect.new()
	_marker_rule.custom_minimum_size = Vector2(0, 1)
	_marker_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_marker_rule)
	ScreenKit.gap(col, Design.SPACE_LG)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", Design.SPACE_LG)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(body)

	_icon_slot = Control.new()
	_icon_slot.custom_minimum_size = Vector2(ICON_SLOT, ICON_SLOT)
	_icon_slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_slot.draw.connect(func() -> void: _draw_icon_on(_icon_slot, _accent()))
	body.add_child(_icon_slot)

	_desc = ScreenKit.mono("", Design.TEXT_CAPTION, Design.TEXT_SECONDARY)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_desc)

	ScreenKit.grow_v(col)
	ScreenKit.gap(col, Design.SPACE_MD)
	ScreenKit.rule(col, 0.18)
	ScreenKit.gap(col, Design.SPACE_SM)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", Design.SPACE_MD)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(footer)
	_level_label = ScreenKit.mono("", Design.TEXT_CAPTION, Design.TEXT_MUTED)
	footer.add_child(_level_label)
	ScreenKit.grow_h(footer)
	_level_marks = ScreenKit.mono("", Design.TEXT_CAPTION, Design.TEXT_MUTED)
	footer.add_child(_level_marks)

	# Interação é uma camada transparente sobre o layout. Button não dispõe os
	# filhos; o PanelContainer continua sendo quem mede o conteúdo.
	var hit := Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_ALL
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ring := StyleBoxFlat.new()
	ring.bg_color = Color(0, 0, 0, 0)
	for side in ["border_width_left", "border_width_right", "border_width_top", "border_width_bottom"]:
		ring.set(side, int(Design.FOCUS_RING_WIDTH))
	ring.border_color = Design.FOCUS_RING_COLOR
	hit.add_theme_stylebox_override("focus", ring)
	var glow := StyleBoxFlat.new()
	glow.bg_color = Design.alpha(Design.TEXT_PRIMARY, 0.08)
	hit.add_theme_stylebox_override("hover", glow)
	hit.pressed.connect(func() -> void: selected.emit(_index))
	add_child(hit)


func _refresh() -> void:
	if not is_instance_valid(_title):
		return
	var ink := card_ink()
	var marker: Color = ink.get("marker", Design.ACCENT)
	_index_label.text = "%02d" % (_index + 1)
	_index_label.add_theme_color_override("font_color", marker)
	_rarity.text = rarity_label()
	_rarity.add_theme_color_override("font_color", marker)
	_title.text = card_title()
	_title.add_theme_font_size_override("font_size", _title_font_size(_title.text))
	_title.add_theme_color_override("font_color", ink.get("title", Design.TEXT_PRIMARY))
	_desc.text = str(_def.get("desc", ""))
	_desc.add_theme_color_override("font_color", ink.get("body", Design.TEXT_SECONDARY))
	_marker_rule.color = Design.alpha(marker, 0.58)
	_level_label.text = "LEVEL %d → %d" % [_level, _level + 1] if _level > 0 else "NEW PATCH"
	_level_label.add_theme_color_override("font_color", marker)
	var marks: Array[String] = []
	for dot in 4:
		marks.append("●" if dot <= _level else "○")
	_level_marks.text = " ".join(marks)
	_level_marks.add_theme_color_override("font_color", Design.alpha(marker, 0.82))
	_icon_slot.queue_redraw()


func _title_font_size(text: String) -> int:
	return LONG_TITLE_SIZE if text.length() >= 12 else Design.TEXT_HEADING


## Patch icon family table: every Game.PATCH_CODES id maps to one of six visual
## families so icons share a silhouette language per effect type.
const PATCH_ICON_FAMILIES := {
	"heavy": "damage", "core": "damage", "splitshot": "damage", "ricochet": "damage", "pdash": "damage", "thorns": "damage", "staticf": "damage",
	"rapid": "fire", "threads": "fire", "chain": "fire",
	"hp": "defense", "shield": "defense", "absorb": "defense", "restore": "defense", "secondwind": "defense", "vampic": "defense", "recycler": "defense", "dataleech": "defense",
	"cell": "utility", "magnet": "utility",
	"dash": "movement", "mdash": "movement", "turbo": "movement", "light": "movement",
	"frag": "economy", "scrapdiet": "economy",
}

const RASTER_DIR := "res://assets/icons/generated/"

## Optical pad fraction for patch rasters inside the 52px slot; matches the
## tactical_icon optical pass so rasters and code glyphs share stroke weight.
const PATCH_RASTER_PAD := 0.08

static var _raster_tex_cache := {}


static func patch_icon_family(id: String) -> String:
	return str(PATCH_ICON_FAMILIES.get(id, "utility"))


static func patch_icon_metrics(id: String) -> Dictionary:
	return {"covered": PATCH_ICON_FAMILIES.has(id), "min_stroke": 2.0, "contrast": 0.55}


static func patch_raster_path(id: String) -> String:
	var path := RASTER_DIR + "patch_" + id + ".png"
	return path if ResourceLoader.exists(path) else ""


func _draw_icon_on(canvas: Control, accent: Color) -> void:
	if canvas == null or not is_instance_valid(canvas):
		return
	var center := canvas.size * 0.5
	var id := str(_def.get("id", ""))
	var raster := patch_raster_path(id)
	if raster != "":
		if not _raster_tex_cache.has(raster):
			_raster_tex_cache[raster] = load(raster)
			canvas.queue_redraw()
		var tex: Texture2D = _raster_tex_cache[raster]
		if tex != null:
			var pad: float = PATCH_RASTER_PAD * ICON_DRAW_SIZE
			var side := ICON_DRAW_SIZE - pad * 2.0
			canvas.draw_texture_rect(tex, Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side)), false)
			return
	match patch_icon_family(id):
		"damage":
			_draw_damage_glyph(canvas, center, accent)
		"fire":
			_draw_fire_glyph(canvas, center, accent)
		"defense":
			_draw_defense_glyph(canvas, center, accent)
		"utility":
			_draw_utility_glyph(canvas, center, accent)
		"movement":
			_draw_movement_glyph(canvas, center, accent)
		"economy":
			_draw_economy_glyph(canvas, center, accent)


func _draw_damage_glyph(canvas: Control, center: Vector2, accent: Color) -> void:
	for i in 3:
		var a := -PI * 0.5 + TAU * float(i) / 3.0
		var tip := center + Vector2.from_angle(a) * 22.0
		var left := center + Vector2.from_angle(a - 0.42) * 8.0
		var right := center + Vector2.from_angle(a + 0.42) * 8.0
		canvas.draw_colored_polygon(PackedVector2Array([tip, left, right]), accent)
	canvas.draw_arc(center, 7.0, 0.0, TAU, 16, accent, 2.0, true)


func _draw_fire_glyph(canvas: Control, center: Vector2, accent: Color) -> void:
	for i in 3:
		var x := center.x - 14.0 + float(i) * 10.0
		var pts := PackedVector2Array([Vector2(x, center.y - 10.0), Vector2(x + 8.0, center.y), Vector2(x, center.y + 10.0)])
		canvas.draw_polyline(pts, accent, 2.2, true)


func _draw_defense_glyph(canvas: Control, center: Vector2, accent: Color) -> void:
	var pts := PackedVector2Array([
		center + Vector2(0.0, -20.0), center + Vector2(15.0, -12.0), center + Vector2(15.0, 4.0),
		center + Vector2(0.0, 20.0), center + Vector2(-15.0, 4.0), center + Vector2(-15.0, -12.0),
	])
	canvas.draw_colored_polygon(pts, Design.alpha(accent, 0.14))
	canvas.draw_polyline(pts + PackedVector2Array([pts[0]]), accent, 2.2, true)
	canvas.draw_line(center + Vector2(0.0, -12.0), center + Vector2(0.0, 12.0), accent, 2.0)


func _draw_utility_glyph(canvas: Control, center: Vector2, accent: Color) -> void:
	var nut := PackedVector2Array()
	for i in 6:
		nut.append(center + Vector2.from_angle(TAU * float(i) / 6.0) * 15.0)
	canvas.draw_polyline(nut + PackedVector2Array([nut[0]]), accent, 2.2, true)
	canvas.draw_circle(center, 5.0, accent)


func _draw_movement_glyph(canvas: Control, center: Vector2, accent: Color) -> void:
	canvas.draw_line(center + Vector2(-16.0, 6.0), center + Vector2(2.0, 6.0), Design.alpha(accent, 0.6), 2.0)
	canvas.draw_line(center + Vector2(-10.0, -2.0), center + Vector2(8.0, -2.0), accent, 2.2)
	canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(8.0, -8.0), center + Vector2(16.0, -2.0), center + Vector2(8.0, 4.0)]), accent)


func _draw_economy_glyph(canvas: Control, center: Vector2, accent: Color) -> void:
	for offset in [Vector2(-12.0, -8.0), Vector2(-4.0, 2.0), Vector2(6.0, -4.0)]:
		canvas.draw_circle(center + offset, 4.0, accent)
	canvas.draw_line(center + Vector2(-14.0, 12.0), center + Vector2(14.0, 12.0), accent, 2.0)


func text_overflow_report() -> Array:
	var longest_desc := ""
	for definition in Game.PATCH_DEFS:
		if str(definition.get("desc", "")).length() > longest_desc.length():
			longest_desc = str(definition.get("desc", ""))
	var body_w := maxf(size.x - float(CARD_PAD * 2) - ICON_SLOT - float(Design.SPACE_LG), 120.0)
	var fits := TacticalUI.wrapped_height(Design.FONT_MONO, longest_desc, body_w, Design.TEXT_CAPTION) <= 96.0 \
		or TacticalUI.wrapped_height(Design.FONT_MONO, longest_desc, body_w, Design.TEXT_MICRO) <= 96.0
	return [{"id": "patch_desc", "fits": fits}]


static func clear_raster_cache() -> void:
	_raster_tex_cache.clear()

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
	draw_multiline_string(_mono, Vector2(126.0, 143.0), str(_def.get("desc", "")), HORIZONTAL_ALIGNMENT_LEFT, size.x - 148.0, 13, 3, TacticalUIHelper.TEXT)
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
	if id == "staticf":
		for i in 3:
			for j in 3:
				draw_circle(center + Vector2((i - 1) * 11.0, (j - 1) * 11.0), 3.5, accent)
	elif id == "splitshot":
		for direction in [Vector2.UP, Vector2(0.86, 0.5), Vector2(-0.86, 0.5)]:
			draw_line(center, center + direction * 22.0, accent, 3.0)
	else:
		draw_rect(Rect2(center - Vector2(4.0, 21.0), Vector2(8.0, 42.0)), accent)
		draw_rect(Rect2(center - Vector2(21.0, 4.0), Vector2(42.0, 8.0)), accent)

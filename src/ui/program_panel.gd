class_name ProgramPanel
extends Control

signal selection_changed(id: String)

var scroll_y := 0.0
var _dragging := false
var _press_position := Vector2.ZERO
var _drag_start_y := 0.0
var _scroll_start := 0.0
var _card_rects: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func available_program_ids() -> Array:
	var ids: Array = []
	for raw_id in Game.PROGRAM_DEFS.keys():
		var id := str(raw_id)
		if Game.unlocked_programs.has(id):
			ids.append(id)
	return ids

func select_program(id: String) -> bool:
	if not Game.PROGRAM_DEFS.has(id) or not Game.unlocked_programs.has(id):
		return false
	Game.set_program(id)
	selection_changed.emit(id)
	queue_redraw()
	return true

func _columns() -> int:
	if size.x >= 1080.0:
		return 3
	if size.x >= 720.0:
		return 2
	return 1

func _content_metrics() -> Dictionary:
	var cols := _columns()
	var gap := 18.0
	var card_h := 214.0
	var card_w: float = minf(390.0, (size.x - 48.0 - gap * float(cols - 1)) / float(cols))
	var rows := ceili(float(Game.PROGRAM_DEFS.size()) / float(cols))
	var content_h: float = rows * card_h + maxf(rows - 1, 0) * gap
	var viewport_top := 140.0
	var viewport_bottom: float = maxf(size.y - 130.0, viewport_top)
	var viewport_h: float = viewport_bottom - viewport_top
	return {"cols": cols, "gap": gap, "card_h": card_h, "card_w": card_w, "rows": rows, "content_h": content_h, "viewport_top": viewport_top, "viewport_bottom": viewport_bottom, "viewport_h": viewport_h}

func content_viewport_rect() -> Rect2:
	var metrics := _content_metrics()
	return Rect2(0.0, float(metrics["viewport_top"]), size.x, float(metrics["viewport_h"]))

func _scroll_to(value: float) -> void:
	var metrics := _content_metrics()
	var content_top := 150.0
	var max_scroll: float = maxf(content_top + float(metrics["content_h"]) - float(metrics["viewport_bottom"]), 0.0)
	scroll_y = clampf(value, 0.0, max_scroll)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_scroll_to(scroll_y - 80.0)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_scroll_to(scroll_y + 80.0)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_press_position = event.position
				_drag_start_y = event.position.y
				_scroll_start = scroll_y
			else:
				if _dragging and event.position.distance_to(_press_position) < 14.0:
					_select_at(event.position)
				_dragging = false
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_scroll_to(_scroll_start - (event.position.y - _drag_start_y))
		accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_dragging = true
			_press_position = event.position
			_drag_start_y = event.position.y
			_scroll_start = scroll_y
		else:
			if _dragging and event.position.distance_to(_press_position) < 18.0:
				_select_at(event.position)
			_dragging = false
		accept_event()
	elif event is InputEventScreenDrag and _dragging:
		_scroll_to(_scroll_start - (event.position.y - _drag_start_y))
		accept_event()

func _select_at(position: Vector2) -> void:
	for raw_id in _card_rects:
		var id := str(raw_id)
		if _card_rects[id].has_point(position):
			if select_program(id):
				Sfx.play("ui", 1.05, -8.0)
			return

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.012, 0.03, 1.0))
	var mono: Font = load("res://assets/fonts/ShareTechMono.ttf")
	var orbitron: Font = load("res://assets/fonts/Orbitron.ttf")
	var metrics := _content_metrics()
	var cols: int = metrics["cols"]
	var gap: float = metrics["gap"]
	var card_w: float = metrics["card_w"]
	var card_h: float = metrics["card_h"]
	var total_w: float = card_w * float(cols) + gap * float(cols - 1)
	var x0 := (size.x - total_w) * 0.5
	var y0 := 150.0 - scroll_y
	var viewport_top: float = metrics["viewport_top"]
	var viewport_bottom: float = metrics["viewport_bottom"]
	_card_rects.clear()
	var ids: Array = Game.PROGRAM_DEFS.keys()
	for i in ids.size():
		var id := str(ids[i])
		var definition: Dictionary = Game.PROGRAM_DEFS[id]
		var col := i % cols
		var row := i / cols
		var origin := Vector2(x0 + col * (card_w + gap), y0 + row * (card_h + gap))
		var rect := Rect2(origin, Vector2(card_w, card_h))
		_card_rects[id] = rect
		if origin.y < viewport_top or origin.y + card_h > viewport_bottom:
			continue
		var unlocked := Game.unlocked_programs.has(id)
		var visual: Dictionary = definition.get("visual", {})
		var true_col: Color = visual.get("color", Balance.COL_TEXT)
		var border := true_col if unlocked else Color(true_col.r, true_col.g, true_col.b, 0.28)
		draw_rect(rect, Color(border.r, border.g, border.b, 0.06 if unlocked else 0.025))
		draw_rect(rect, border, false, 1.8 if unlocked else 1.2)
		draw_set_transform(origin + Vector2(48.0, 50.0), 0.0, Vector2(1.35, 1.35))
		_draw_silhouette(str(visual.get("silhouette", "kernel_arrow")), true_col if unlocked else Color(true_col.r, true_col.g, true_col.b, 0.22))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_string(orbitron, origin + Vector2(90.0, 38.0), str(definition.get("name", id.to_upper())), HORIZONTAL_ALIGNMENT_LEFT, card_w - 104.0, 17, Balance.COL_TEXT if unlocked else Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.45))
		draw_string(mono, origin + Vector2(90.0, 60.0), str(definition.get("role", "PROGRAM")), HORIZONTAL_ALIGNMENT_LEFT, card_w - 104.0, 11, Color(true_col.r, true_col.g, true_col.b, 0.8 if unlocked else 0.35))
		draw_multiline_string(mono, origin + Vector2(16.0, 91.0), str(definition.get("summary", "")), HORIZONTAL_ALIGNMENT_LEFT, card_w - 32.0, 12, 2, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.68 if unlocked else 0.36))
		var stat_text := "INTEGRITY  %s\nSPEED      %s\nFIRE       %s\nRANGE      %s\nDASH/CORE  %s" % [definition.get("integrity", "—"), definition.get("speed", "—"), definition.get("fire", "—"), definition.get("range", "—"), definition.get("dash_shield", "—")]
		draw_multiline_string(mono, origin + Vector2(16.0, 132.0), stat_text, HORIZONTAL_ALIGNMENT_LEFT, card_w - 32.0, 11, 2, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.78 if unlocked else 0.42))
		var footer := "[ SELECTED ]" if Game.program == id and unlocked else "[ READY ]" if unlocked else "[ LOCKED // UNLOCK IN RUN ]"
		var footer_col := true_col if unlocked else Balance.COL_DANGER
		draw_string(mono, origin + Vector2(16.0, card_h - 14.0), footer, HORIZONTAL_ALIGNMENT_LEFT, card_w - 32.0, 11, Color(footer_col.r, footer_col.g, footer_col.b, 0.8 if unlocked else 0.5))
	var viewport_h: float = metrics["viewport_h"]
	var content_h: float = metrics["content_h"]
	var max_scroll: float = maxf(150.0 + content_h - viewport_bottom, 0.0)
	if max_scroll > 0.0:
		var track := Rect2(size.x - 22.0, 150.0, 4.0, viewport_h)
		var thumb_h: float = maxf(28.0, viewport_h * viewport_h / content_h)
		var thumb_y: float = track.position.y + (track.size.y - thumb_h) * (scroll_y / max_scroll)
		draw_rect(track, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.12))
		draw_rect(Rect2(track.position.x, thumb_y, track.size.x, thumb_h), Color(Balance.COL_PLAYER.r, Balance.COL_PLAYER.g, Balance.COL_PLAYER.b, 0.75))
		draw_string(mono, Vector2(size.x - 210.0, size.y - 102.0), "SWIPE TO SCROLL", HORIZONTAL_ALIGNMENT_RIGHT, 180.0, 11, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.45))

func _draw_silhouette(key: String, c: Color) -> void:
	match key:
		"daemon_fork":
			var body := PackedVector2Array([Vector2(18, 0), Vector2(2, 5), Vector2(-12, 12), Vector2(-7, 0), Vector2(-12, -12), Vector2(2, -5)])
			draw_colored_polygon(body, Color(c.r, c.g, c.b, 0.28))
			draw_polyline(body + PackedVector2Array([body[0]]), c, 1.8, true)
			draw_line(Vector2(-4, -3), Vector2(10, -9), c, 1.2)
			draw_line(Vector2(-4, 3), Vector2(10, 9), c, 1.2)
		"rootlet_block":
			var block := Rect2(-12, -12, 24, 24)
			draw_rect(block, Color(c.r, c.g, c.b, 0.28))
			draw_rect(block, c, false, 1.8)
			draw_arc(Vector2.ZERO, 17.0, -PI * 0.82, PI * 0.82, 20, c, 1.5, true)
		"kernel_arrow", _:
			var pts := PackedVector2Array([Vector2(20, 0), Vector2(-13, 12), Vector2(-6, 0), Vector2(-13, -12)])
			draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.3))
			draw_polyline(pts + PackedVector2Array([pts[0]]), c, 1.8, true)
			draw_circle(Vector2(4, 0), 4.0, c)

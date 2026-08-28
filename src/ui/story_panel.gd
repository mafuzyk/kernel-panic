class_name StoryPanel
extends Control

signal stage_selected(index: int)

var scroll_y := 0.0
var _dragging := false
var _press_position := Vector2.ZERO
var _drag_start_y := 0.0
var _scroll_start := 0.0
var _card_rects: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func available_stage_indices() -> Array:
	var result: Array = []
	for i in Game.story_stage_count():
		if Game.story_stage_unlocked(i):
			result.append(i)
	return result

func select_stage(index: int) -> bool:
	if not Game.story_stage_unlocked(index):
		return false
	stage_selected.emit(index)
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
	var card_h := 190.0
	var card_w: float = minf(390.0, (size.x - 48.0 - gap * float(cols - 1)) / float(cols))
	var rows := ceili(float(Game.story_stage_count()) / float(cols))
	var content_h := rows * card_h + maxf(rows - 1, 0) * gap
	var viewport_top := 140.0
	var viewport_bottom: float = maxf(size.y - 130.0, viewport_top)
	return {"cols": cols, "gap": gap, "card_h": card_h, "card_w": card_w, "content_h": content_h, "viewport_top": viewport_top, "viewport_bottom": viewport_bottom, "viewport_h": viewport_bottom - viewport_top}

func _scroll_to(value: float) -> void:
	var metrics := _content_metrics()
	var max_scroll: float = maxf(150.0 + float(metrics["content_h"]) - float(metrics["viewport_bottom"]), 0.0)
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
	for raw_index in _card_rects:
		var index := int(raw_index)
		if _card_rects[index].has_point(position):
			if select_stage(index):
				Sfx.play("ui", 1.05, -8.0)
			return

func _process(_delta: float) -> void:
	queue_redraw()

func _stage_color(index: int) -> Color:
	var stage := Game.story_stage_def(index)
	return stage.get("theme", {}).get("accent", Balance.COL_PLAYER)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.012, 0.03, 1.0))
	var mono: Font = load("res://assets/fonts/ShareTechMono.ttf")
	var orbitron: Font = load("res://assets/fonts/Orbitron.ttf")
	var metrics := _content_metrics()
	var cols: int = metrics["cols"]
	var gap: float = metrics["gap"]
	var card_w: float = metrics["card_w"]
	var card_h: float = metrics["card_h"]
	var total_w := card_w * float(cols) + gap * float(cols - 1)
	var x0 := (size.x - total_w) * 0.5
	var y0 := 150.0 - scroll_y
	var viewport_top: float = metrics["viewport_top"]
	var viewport_bottom: float = metrics["viewport_bottom"]
	_card_rects.clear()
	for i in Game.story_stage_count():
		var stage := Game.story_stage_def(i)
		var col := i % cols
		var row := i / cols
		var origin := Vector2(x0 + col * (card_w + gap), y0 + row * (card_h + gap))
		var rect := Rect2(origin, Vector2(card_w, card_h))
		_card_rects[i] = rect
		if origin.y < viewport_top or origin.y + card_h > viewport_bottom:
			continue
		var unlocked := Game.story_stage_unlocked(i)
		var accent: Color = _stage_color(i)
		var border := accent if unlocked else Color(accent.r, accent.g, accent.b, 0.24)
		draw_rect(rect, Color(border.r, border.g, border.b, 0.07 if unlocked else 0.025))
		draw_rect(rect, border, false, 1.8 if unlocked else 1.2)
		draw_circle(origin + Vector2(42.0, 43.0), 18.0, Color(border.r, border.g, border.b, 0.12))
		draw_arc(origin + Vector2(42.0, 43.0), 18.0, 0.0, TAU, 20, border, 1.4, true)
		draw_string(mono, origin + Vector2(31.0, 48.0), "%02d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, 24.0, 13, border)
		var name_text := str(stage.get("path", "")) if unlocked else "LOCKED"
		draw_string(orbitron, origin + Vector2(76.0, 36.0), name_text, HORIZONTAL_ALIGNMENT_LEFT, card_w - 92.0, 18, Balance.COL_TEXT if unlocked else Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.42))
		draw_string(mono, origin + Vector2(76.0, 59.0), str(stage.get("title", "STORY STAGE")) if unlocked else "CLEAR THE PREVIOUS STAGE", HORIZONTAL_ALIGNMENT_LEFT, card_w - 92.0, 11, Color(border.r, border.g, border.b, 0.8 if unlocked else 0.35))
		var body := str(stage.get("intro", "")) if unlocked else "This process is not mounted yet."
		draw_multiline_string(mono, origin + Vector2(16.0, 93.0), body, HORIZONTAL_ALIGNMENT_LEFT, card_w - 32.0, 12, 2, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.68 if unlocked else 0.32))
		var waves: int = stage.get("waves", []).size()
		var footer := "%d FIXED WAVES // READY" % waves if unlocked else "[ LOCKED ]"
		draw_string(mono, origin + Vector2(16.0, card_h - 16.0), footer, HORIZONTAL_ALIGNMENT_LEFT, card_w - 32.0, 11, Color(border.r, border.g, border.b, 0.8 if unlocked else 0.45))
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

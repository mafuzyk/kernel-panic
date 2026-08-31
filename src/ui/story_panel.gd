class_name StoryPanel
extends Control

const TacticalUIHelper = preload("res://src/ui/tactical_ui.gd")
const TacticalChromeScript = preload("res://src/ui/tactical_chrome.gd")

signal stage_selected(index: int)
signal selection_changed(index: int)

var scroll_y := 0.0
var _dragging := false
var _press_position := Vector2.ZERO
var _drag_start_y := 0.0
var _scroll_start := 0.0
var _card_rects: Dictionary = {}
var _tab_rects: Dictionary = {}
var _selected_stage := 0
var _act_filter := "unix"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var chrome: Control = TacticalChromeScript.new()
	chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome.call("configure_shell", TacticalUIHelper.CYAN, 0.0)
	add_child(chrome)

func available_stage_indices() -> Array:
	var result: Array = []
	for i in Game.story_stage_count():
		if Game.story_stage_unlocked(i):
			result.append(i)
	return result

func select_stage(index: int) -> bool:
	if not Game.story_stage_unlocked(index):
		return false
	_selected_stage = index
	selection_changed.emit(index)
	queue_redraw()
	return true

func confirm_selection() -> bool:
	if not Game.story_stage_unlocked(_selected_stage):
		return false
	stage_selected.emit(_selected_stage)
	return true

func mount_action_rect() -> Rect2:
	if not _is_wide():
		return Rect2()
	var footer: Rect2 = TacticalUIHelper.shell_sections(size)["footer"]
	return Rect2(Vector2(size.x * 0.50, footer.position.y), Vector2(size.x * 0.46, footer.size.y - 4.0))

func selected_stage_index() -> int:
	return _selected_stage

func _is_wide() -> bool:
	return size.x >= 1080.0

func _visible_stage_indices() -> Array:
	var result: Array = []
	for index in Game.story_stage_count():
		var stage := Game.story_stage_def(index)
		var act := str(stage.get("act", "unix"))
		if _is_wide() and act != _act_filter:
			continue
		result.append(index)
	return result

func _columns() -> int:
	if size.x >= 1080.0:
		return 3
	if size.x >= 720.0:
		return 2
	return 1

func _content_metrics() -> Dictionary:
	if _is_wide():
		var route_w := size.x * 0.42
		var gap := 10.0
		var cols := 6
		var card_h := 250.0
		var card_w: float = (route_w - 48.0 - gap * float(cols - 1)) / float(cols)
		var visible_count := _visible_stage_indices().size()
		var rows := ceili(float(maxi(visible_count, 1)) / float(cols))
		var content_h := rows * card_h + maxf(rows - 1, 0) * gap
		var viewport_top := 210.0
		var viewport_bottom: float = maxf(size.y - 132.0, viewport_top + card_h)
		return {"cols": cols, "gap": gap, "card_h": card_h, "card_w": card_w, "rows": rows, "content_h": content_h, "viewport_top": viewport_top, "viewport_bottom": viewport_bottom, "viewport_h": viewport_bottom - viewport_top, "route_w": route_w}
	var cols := _columns()
	var gap := 18.0
	var card_h := 190.0
	var card_w: float = minf(390.0, (size.x - 48.0 - gap * float(cols - 1)) / float(cols))
	var rows := ceili(float(Game.story_stage_count()) / float(cols))
	var content_h := rows * card_h + maxf(rows - 1, 0) * gap
	var viewport_top := 140.0
	var viewport_bottom: float = maxf(size.y - 130.0, viewport_top)
	return {"cols": cols, "gap": gap, "card_h": card_h, "card_w": card_w, "content_h": content_h, "viewport_top": viewport_top, "viewport_bottom": viewport_bottom, "viewport_h": viewport_bottom - viewport_top}

func content_viewport_rect() -> Rect2:
	var metrics := _content_metrics()
	var x := 28.0 if _is_wide() else 0.0
	var width := float(metrics.get("route_w", size.x)) if _is_wide() else size.x
	return Rect2(x, float(metrics["viewport_top"]), width, float(metrics["viewport_h"]))

func visible_card_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	var viewport := content_viewport_rect()
	for raw_rect in _card_rects.values():
		var rect: Rect2 = raw_rect
		if viewport.encloses(rect):
			result.append(rect)
	return result

func card_accent(index: int) -> Color:
	var accent := _stage_color(index)
	if index == _selected_stage and Game.story_stage_unlocked(index):
		return accent
	return Color(accent.r, accent.g, accent.b, 0.46)

func _tab_for_position(position: Vector2) -> String:
	for raw_act in _tab_rects:
		if _tab_rects[raw_act].has_point(position):
			return str(raw_act)
	return ""

func _select_act(act_id: String) -> void:
	if act_id == "" or act_id == _act_filter:
		return
	_act_filter = act_id
	_scroll_to(0.0)
	queue_redraw()

func _scroll_to(value: float) -> void:
	var metrics := _content_metrics()
	var content_top: float = 214.0 if _is_wide() else 150.0
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
					var act := _tab_for_position(event.position)
					if act != "":
						_select_act(act)
					else:
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
				var act := _tab_for_position(event.position)
				if act != "":
					_select_act(act)
				else:
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

var t := 0.0

func _process(_delta: float) -> void:
	t += _delta
	queue_redraw()

func _stage_color(index: int) -> Color:
	var stage := Game.story_stage_def(index)
	return stage.get("theme", {}).get("accent", Balance.COL_PLAYER)

func _stage_state(index: int) -> String:
	if not Game.story_stage_unlocked(index):
		return "LOCKED"
	if bool(Game.story_cleared.get(Game.story_stage_id(index), false)):
		return "CLEARED"
	return "CURRENT"

func _draw_node_brackets(node: Vector2, radius: float, color: Color) -> void:
	var arm := radius * 0.55
	for sign_x in [-1.0, 1.0]:
		for sign_y in [-1.0, 1.0]:
			var corner := node + Vector2(sign_x * (radius + 5.0), sign_y * (radius + 5.0))
			draw_line(corner, corner + Vector2(-sign_x * arm, 0.0), Color(color.r, color.g, color.b, 0.7), 1.2, true)
			draw_line(corner, corner + Vector2(0.0, -sign_y * arm), Color(color.r, color.g, color.b, 0.7), 1.2, true)

func _draw_state_glyph(node: Vector2, radius: float, state: String, color: Color) -> void:
	match state:
		"CLEARED":
			draw_arc(node, radius + 3.0, 0.0, TAU, 24, Color(color.r, color.g, color.b, 0.95), 2.2, true)
			var b := node + Vector2(radius + 6.0, -radius - 6.0)
			draw_line(b + Vector2(-3.0, 0.0), b + Vector2(-0.5, 2.5), Color(color.r, color.g, color.b, 0.95), 2.0, true)
			draw_line(b + Vector2(-0.5, 2.5), b + Vector2(3.5, -2.5), Color(color.r, color.g, color.b, 0.95), 2.0, true)
		"CURRENT":
			var pulse := radius + 3.0 + sin(t * 4.0) * 2.0
			draw_arc(node, pulse, 0.0, TAU, 24, Color(color.r, color.g, color.b, 0.95), 2.6, true)
		"LOCKED":
			draw_arc(node, radius + 3.0, 0.0, TAU, 24, Color(color.r, color.g, color.b, 0.3), 2.0, true)
			var lb := node + Vector2(radius + 6.0, -radius - 6.0)
			draw_rect(Rect2(lb + Vector2(-3.0, -1.0), Vector2(6.0, 5.0)), Color(color.r, color.g, color.b, 0.6), false, 1.4)
			draw_arc(lb + Vector2(0.0, -1.0), 2.2, PI, TAU, 10, Color(color.r, color.g, color.b, 0.6), 1.4, true)

func _state_label_color(state: String, color: Color) -> Color:
	match state:
		"CLEARED":
			return Color(color.r, color.g, color.b, 0.9)
		"CURRENT":
			return TacticalUIHelper.TEXT
		_:
			return Color(TacticalUIHelper.MUTED.r, TacticalUIHelper.MUTED.g, TacticalUIHelper.MUTED.b, 0.7)

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
	var x0 := 28.0 if _is_wide() else (size.x - total_w) * 0.5
	var content_top: float = 214.0 if _is_wide() else 150.0
	var y0 := content_top - scroll_y
	var viewport_top: float = metrics["viewport_top"]
	var viewport_bottom: float = metrics["viewport_bottom"]
	_tab_rects.clear()
	if _is_wide():
		var tab_x := 28.0
		var tab_y := 154.0
		var tab_w := (float(metrics["route_w"]) - 20.0) / 3.0
		for act_id in ["unix", "windows", "templeos"]:
			var tab := Rect2(tab_x, tab_y, tab_w, 34.0)
			_tab_rects[act_id] = tab
			var tab_col := Balance.COL_PLAYER if act_id == "unix" else Color("b46bff") if act_id == "windows" else Balance.COL_MOTE
			var active: bool = act_id == _act_filter
			var tab_points := TacticalUIHelper.angular_points(tab, 7.0)
			draw_colored_polygon(tab_points, Color(tab_col.r, tab_col.g, tab_col.b, 0.16 if active else 0.035))
			draw_polyline(tab_points + PackedVector2Array([tab_points[0]]), Color(tab_col.r, tab_col.g, tab_col.b, 0.95 if active else 0.42), 1.7 if active else 1.0, true)
			draw_string(mono, tab.position + Vector2(14.0, 22.0), act_id.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, tab.size.x - 28.0, 12, Color(tab_col.r, tab_col.g, tab_col.b, 1.0 if active else 0.58))
			tab_x += tab_w + 10.0
	var stage_indices: Array = _visible_stage_indices()
	_card_rects.clear()
	# Route connectors are drawn first so each stage marker remains legible above them.
	for route_i in stage_indices.size() - 1:
		var first_index: int = stage_indices[route_i]
		var second_index: int = stage_indices[route_i + 1]
		var first_col := route_i % cols
		var first_row := route_i / cols
		var second_col := (route_i + 1) % cols
		var second_row := (route_i + 1) / cols
		var first_center := Vector2(x0 + first_col * (card_w + gap) + card_w * 0.5, y0 + first_row * (card_h + gap) + card_h * 0.5)
		var second_center := Vector2(x0 + second_col * (card_w + gap) + card_w * 0.5, y0 + second_row * (card_h + gap) + card_h * 0.5)
		var route_col := _stage_color(second_index) if Game.story_stage_unlocked(second_index) else Color(TacticalUIHelper.MUTED.r, TacticalUIHelper.MUTED.g, TacticalUIHelper.MUTED.b, 0.25)
		draw_line(first_center, second_center, Color(route_col.r, route_col.g, route_col.b, 0.54), 2.0)
	for i in stage_indices.size():
		var stage_index: int = stage_indices[i]
		var stage := Game.story_stage_def(stage_index)
		var col := i % cols
		var row := i / cols
		var origin := Vector2(x0 + col * (card_w + gap), y0 + row * (card_h + gap))
		var rect := Rect2(origin, Vector2(card_w, card_h))
		_card_rects[stage_index] = rect
		if origin.y < viewport_top or origin.y + card_h > viewport_bottom:
			continue
		var unlocked: bool = Game.story_stage_unlocked(stage_index)
		var selected: bool = stage_index == _selected_stage and unlocked
		var accent: Color = card_accent(stage_index) if unlocked else _stage_color(stage_index)
		var border := accent if unlocked else Color(accent.r, accent.g, accent.b, 0.24)
		var card_points := TacticalUIHelper.angular_points(rect, 10.0)
		# Opaque card fill keeps route connectors behind the card, never through its copy.
		draw_colored_polygon(card_points, Color(0.01, 0.012, 0.03, 0.96))
		if selected:
			draw_colored_polygon(card_points, Color(border.r, border.g, border.b, 0.12))
		draw_polyline(card_points + PackedVector2Array([card_points[0]]), border, 2.1 if selected else (1.7 if unlocked else 1.1), true)
		if selected:
			var selected_points := TacticalUIHelper.angular_points(rect.grow(-4.0), 7.0)
			draw_polyline(selected_points + PackedVector2Array([selected_points[0]]), Color(border.r, border.g, border.b, 0.48), 1.0, true)
		var name_text := str(stage.get("path", "")) if unlocked else "LOCKED"
		var waves: int = stage.get("waves", []).size()
		if _is_wide():
			var node := origin + Vector2(card_w * 0.5, 42.0)
			var state := _stage_state(stage_index)
			draw_circle(node, 18.0, Color(border.r, border.g, border.b, 0.12))
			draw_arc(node, 18.0, 0.0, TAU, 20, border, 1.4, true)
			_draw_node_brackets(node, 18.0, border)
			_draw_state_glyph(node, 18.0, state, border)
			draw_string(mono, origin + Vector2(0.0, 47.0), "%02d" % (stage_index + 1), HORIZONTAL_ALIGNMENT_CENTER, card_w, 13, border)
			draw_string(mono, origin + Vector2(0.0, 68.0), state, HORIZONTAL_ALIGNMENT_CENTER, card_w, 9, _state_label_color(state, border))
			draw_string(orbitron, origin + Vector2(6.0, 82.0), name_text, HORIZONTAL_ALIGNMENT_CENTER, card_w - 12.0, 14, Balance.COL_TEXT if unlocked else Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.42))
			draw_string(mono, origin + Vector2(6.0, 98.0), str(stage.get("title", "STORY STAGE")) if unlocked else "LOCKED", HORIZONTAL_ALIGNMENT_CENTER, card_w - 12.0, 9, Color(border.r, border.g, border.b, 0.8 if unlocked else 0.35))
			var body := str(stage.get("intro", "")) if unlocked else "NOT MOUNTED"
			draw_multiline_string(mono, origin + Vector2(8.0, 105.0), body, HORIZONTAL_ALIGNMENT_CENTER, card_w - 16.0, 9, 4, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.66 if unlocked else 0.32))
			var footer := "%d WAVES" % waves if unlocked else "LOCKED"
			draw_string(mono, origin + Vector2(8.0, card_h - 18.0), footer, HORIZONTAL_ALIGNMENT_CENTER, card_w - 16.0, 9, Color(border.r, border.g, border.b, 0.8 if unlocked else 0.45))
		else:
			var node := origin + Vector2(42.0, 43.0)
			var state := _stage_state(stage_index)
			draw_circle(node, 18.0, Color(border.r, border.g, border.b, 0.12))
			draw_arc(node, 18.0, 0.0, TAU, 20, border, 1.4, true)
			_draw_node_brackets(node, 18.0, border)
			_draw_state_glyph(node, 18.0, state, border)
			draw_string(mono, origin + Vector2(31.0, 48.0), "%02d" % (stage_index + 1), HORIZONTAL_ALIGNMENT_LEFT, 24.0, 13, border)
			draw_string(mono, origin + Vector2(12.0, 68.0), state, HORIZONTAL_ALIGNMENT_CENTER, 60.0, 9, _state_label_color(state, border))
			draw_string(orbitron, origin + Vector2(76.0, 36.0), name_text, HORIZONTAL_ALIGNMENT_LEFT, card_w - 92.0, 18, Balance.COL_TEXT if unlocked else Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.42))
			draw_string(mono, origin + Vector2(76.0, 59.0), str(stage.get("title", "STORY STAGE")) if unlocked else "CLEAR THE PREVIOUS STAGE", HORIZONTAL_ALIGNMENT_LEFT, card_w - 92.0, 11, Color(border.r, border.g, border.b, 0.8 if unlocked else 0.35))
			var body := str(stage.get("intro", "")) if unlocked else "This process is not mounted yet."
			draw_multiline_string(mono, origin + Vector2(16.0, 93.0), body, HORIZONTAL_ALIGNMENT_LEFT, card_w - 32.0, 12, 2, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.68 if unlocked else 0.32))
			var footer := "%d FIXED WAVES // READY" % waves if unlocked else "[ LOCKED ]"
			draw_string(mono, origin + Vector2(16.0, card_h - 16.0), footer, HORIZONTAL_ALIGNMENT_LEFT, card_w - 32.0, 11, Color(border.r, border.g, border.b, 0.8 if unlocked else 0.45))
	if _is_wide():
		_draw_stage_detail(metrics, mono, orbitron)
	var viewport_h: float = metrics["viewport_h"]
	var content_h: float = metrics["content_h"]
	var max_scroll: float = maxf(content_top + content_h - viewport_bottom, 0.0)
	if max_scroll > 0.0:
		var track := Rect2((float(metrics["route_w"]) if _is_wide() else size.x) - 22.0, float(metrics["viewport_top"]), 4.0, viewport_h)
		var thumb_h: float = maxf(28.0, viewport_h * viewport_h / content_h)
		var thumb_y: float = track.position.y + (track.size.y - thumb_h) * (scroll_y / max_scroll)
		draw_rect(track, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.12))
		draw_rect(Rect2(track.position.x, thumb_y, track.size.x, thumb_h), Color(Balance.COL_PLAYER.r, Balance.COL_PLAYER.g, Balance.COL_PLAYER.b, 0.75))
		draw_string(mono, Vector2(size.x - 210.0, size.y - 102.0), "SWIPE TO SCROLL", HORIZONTAL_ALIGNMENT_RIGHT, 180.0, 11, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.45))
	if _is_wide():
		var mount := mount_action_rect()
		var mount_points := TacticalUIHelper.angular_points(mount, 9.0)
		var mount_accent := _stage_color(_selected_stage)
		draw_colored_polygon(mount_points, Color(mount_accent.r, mount_accent.g, mount_accent.b, 0.08))
		draw_polyline(mount_points + PackedVector2Array([mount_points[0]]), mount_accent, 1.7, true)

func _draw_stage_detail(metrics: Dictionary, mono: Font, orbitron: Font) -> void:
	var route_w: float = metrics["route_w"]
	var rail := Rect2(route_w + 48.0, float(metrics["viewport_top"]), size.x - route_w - 76.0, float(metrics["viewport_h"]))
	var stage := Game.story_stage_def(_selected_stage)
	var accent := _stage_color(_selected_stage)
	var frame := TacticalUIHelper.angular_points(rail, 13.0)
	draw_colored_polygon(frame, Color(accent.r, accent.g, accent.b, 0.055))
	draw_polyline(frame + PackedVector2Array([frame[0]]), Color(accent.r, accent.g, accent.b, 0.66), 1.5, true)
	draw_string(mono, rail.position + Vector2(18.0, 24.0), "MOUNT POINT // %s" % str(stage.get("path", "UNKNOWN")), HORIZONTAL_ALIGNMENT_LEFT, rail.size.x - 36.0, 11, Color(accent.r, accent.g, accent.b, 0.9))
	draw_string(orbitron, rail.position + Vector2(18.0, 54.0), str(stage.get("title", "STORY STAGE")), HORIZONTAL_ALIGNMENT_LEFT, rail.size.x - 36.0, 20, TacticalUIHelper.TEXT)
	var unlocked: bool = Game.story_stage_unlocked(_selected_stage)
	draw_string(mono, rail.position + Vector2(18.0, 76.0), "STATUS: %s" % ("READY TO MOUNT" if unlocked else "LOCKED // CLEAR PREVIOUS"), HORIZONTAL_ALIGNMENT_LEFT, rail.size.x - 36.0, 11, accent if unlocked else TacticalUIHelper.MUTED)
	var intro_size: int = TacticalUI.fit_block(mono, str(stage.get("intro", "")), rail.size.x - 36.0, 56.0, 12, 10)["font_size"]
	draw_multiline_string(mono, rail.position + Vector2(18.0, 108.0), str(stage.get("intro", "")), HORIZONTAL_ALIGNMENT_LEFT, rail.size.x - 36.0, intro_size, 5, Color(TacticalUIHelper.TEXT.r, TacticalUIHelper.TEXT.g, TacticalUIHelper.TEXT.b, 0.74))
	var divider_y := rail.position.y + 164.0
	draw_line(rail.position + Vector2(18.0, divider_y - rail.position.y), rail.position + Vector2(rail.size.x - 18.0, divider_y - rail.position.y), Color(accent.r, accent.g, accent.b, 0.3), 1.0)
	draw_string(mono, rail.position + Vector2(18.0, 188.0), "THREATS", HORIZONTAL_ALIGNMENT_LEFT, rail.size.x - 36.0, 11, accent)
	var threat_names: Array = []
	for wave in stage.get("waves", []):
		for enemy in wave:
			if not threat_names.has(enemy):
				threat_names.append(enemy)
	var threat_text := ", ".join(threat_names)
	draw_multiline_string(mono, rail.position + Vector2(18.0, 210.0), threat_text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, rail.size.x - 36.0, 11, 2, TacticalUIHelper.TEXT)
	draw_string(mono, rail.position + Vector2(18.0, 252.0), "WAVES  %02d     SCALE  %.2fx" % [stage.get("waves", []).size(), float(stage.get("scale", 1.0))], HORIZONTAL_ALIGNMENT_LEFT, rail.size.x - 36.0, 11, TacticalUIHelper.MUTED)
	var preview := Rect2(rail.position + Vector2(18.0, 274.0), Vector2(minf(rail.size.x - 36.0, 170.0), 92.0))
	var preview_points := TacticalUIHelper.angular_points(preview, 8.0)
	draw_colored_polygon(preview_points, Color(0.02, 0.06, 0.11, 0.75))
	draw_polyline(preview_points + PackedVector2Array([preview_points[0]]), Color(accent.r, accent.g, accent.b, 0.42), 1.0, true)
	for grid_i in range(1, 5):
		draw_line(preview.position + Vector2(float(grid_i) * preview.size.x / 5.0, 8.0), preview.position + Vector2(float(grid_i) * preview.size.x / 5.0, preview.size.y - 8.0), Color(accent.r, accent.g, accent.b, 0.16), 1.0)
	for grid_i in range(1, 3):
		draw_line(preview.position + Vector2(8.0, float(grid_i) * preview.size.y / 3.0), preview.position + Vector2(preview.size.x - 8.0, float(grid_i) * preview.size.y / 3.0), Color(accent.r, accent.g, accent.b, 0.16), 1.0)
	draw_circle(preview.get_center(), 5.0, accent)
	draw_string(mono, preview.position + Vector2(12.0, 18.0), "ARENA PREVIEW", HORIZONTAL_ALIGNMENT_LEFT, preview.size.x - 24.0, 9, Color(TacticalUIHelper.TEXT.r, TacticalUIHelper.TEXT.g, TacticalUIHelper.TEXT.b, 0.62))
	var klog: Array = stage.get("klog", [])
	var klog_x := 18.0 + preview.size.x + 20.0
	var klog_width := maxf(rail.size.x - klog_x - 18.0, 0.0)
	for log_i in mini(klog.size(), 2):
		var klog_text := "> " + str(klog[log_i])
		draw_string(mono, rail.position + Vector2(klog_x, 292.0 + float(log_i) * 20.0), TacticalUI.ellipsis_fit(mono, klog_text, klog_width, 10), HORIZONTAL_ALIGNMENT_LEFT, klog_width, 10, Color(TacticalUIHelper.TEXT.r, TacticalUIHelper.TEXT.g, TacticalUIHelper.TEXT.b, 0.56))

func text_overflow_report() -> Array:
	var mono: Font = load("res://assets/fonts/ShareTechMono.ttf")
	var orbitron: Font = load("res://assets/fonts/Orbitron.ttf")
	var out: Array = []
	var longest_intro := ""
	var longest_title := ""
	var longest_klog := ""
	for stage_index in Game.story_stage_count():
		var stage: Dictionary = Game.story_stage_def(stage_index)
		if str(stage.get("intro", "")).length() > longest_intro.length():
			longest_intro = str(stage.get("intro", ""))
		if str(stage.get("title", "")).length() > longest_title.length():
			longest_title = str(stage.get("title", ""))
		for line in stage.get("klog", []):
			if ("> " + str(line)).length() > longest_klog.length():
				longest_klog = "> " + str(line)
	var rail_w: float = size.x * 0.42 if _is_wide() else size.x
	out.append({"id": "detail_intro", "fits": TacticalUI.wrapped_height(mono, longest_intro, rail_w - 36.0, 12) <= 56.0 or TacticalUI.wrapped_height(mono, longest_intro, rail_w - 36.0, 10) <= 56.0})
	out.append({"id": "detail_title", "fits": orbitron.get_string_size(longest_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x <= rail_w - 36.0})
	var klog_width: float = maxf(rail_w - (minf(rail_w - 36.0, 170.0) + 38.0) - 18.0, 0.0)
	out.append({"id": "klog_lines", "fits": mono.get_string_size(TacticalUI.ellipsis_fit(mono, longest_klog, klog_width, 10), HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x <= klog_width})
	out.append({"id": "story_state_labels", "fits": mono.get_string_size("CLEARED", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x <= 60.0 and mono.get_string_size("CURRENT", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x <= 60.0 and mono.get_string_size("LOCKED", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x <= 60.0})
	var mount_rect := mount_action_rect()
	var mount_text := "MOUNT /boot  [ENTER]"
	out.append({"id": "mount_action", "fits": mount_rect == Rect2() or orbitron.get_string_size(mount_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x <= mount_rect.size.x - 24.0})
	return out

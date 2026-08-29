class_name ProgramPanel
extends Control

const TacticalUIHelper = preload("res://src/ui/tactical_ui.gd")
const TacticalChromeScript = preload("res://src/ui/tactical_chrome.gd")

signal selection_changed(id: String)

var scroll_y := 0.0
var _dragging := false
var _press_position := Vector2.ZERO
var _drag_start_y := 0.0
var _scroll_start := 0.0
var _card_rects: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var chrome: Control = TacticalChromeScript.new()
	chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome.call("configure_shell", TacticalUIHelper.CYAN, 0.0)
	add_child(chrome)

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
	var gap := 22.0 if size.x >= 1080.0 else 18.0
	var card_h := 440.0 if size.x >= 1080.0 else 300.0
	var card_w: float = (size.x - 112.0 - gap * float(cols - 1)) / float(cols) if size.x >= 1080.0 else minf(390.0, (size.x - 48.0 - gap * float(cols - 1)) / float(cols))
	var rows := ceili(float(Game.PROGRAM_DEFS.size()) / float(cols))
	var content_h: float = rows * card_h + maxf(rows - 1, 0) * gap
	var viewport_top := 150.0
	var viewport_bottom: float = maxf(size.y - 132.0, viewport_top + card_h)
	var viewport_h: float = viewport_bottom - viewport_top
	return {"cols": cols, "gap": gap, "card_h": card_h, "card_w": card_w, "rows": rows, "content_h": content_h, "viewport_top": viewport_top, "viewport_bottom": viewport_bottom, "viewport_h": viewport_h}

func content_viewport_rect() -> Rect2:
	var metrics := _content_metrics()
	return Rect2(0.0, float(metrics["viewport_top"]), size.x, float(metrics["viewport_h"]))

func visible_card_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	var viewport := content_viewport_rect()
	for raw_rect in _card_rects.values():
		var rect: Rect2 = raw_rect
		if viewport.encloses(rect):
			result.append(rect)
	return result

func card_accent(id: String) -> Color:
	var definition: Dictionary = Game.PROGRAM_DEFS.get(id, {})
	var visual: Dictionary = definition.get("visual", {})
	var accent: Color = visual.get("color", Balance.COL_TEXT)
	if Game.program == id and Game.unlocked_programs.has(id):
		return accent
	return Color(accent.r, accent.g, accent.b, 0.46)

func _tradeoff(id: String) -> String:
	match id:
		"kernel": return "OVERclock enabled // no shield core"
		"daemon": return "HIGH RISK // kill recharge on close-range hits"
		"rootlet": return "NO OVERCLOCK // shield core absorbs one hit"
		_: return "PROCESS PROFILE // no additional notes"

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
		var selected := Game.program == id and unlocked
		var border: Color = card_accent(id) if unlocked else Color(true_col.r, true_col.g, true_col.b, 0.28)
		var frame := TacticalUIHelper.angular_points(rect, 13.0)
		draw_colored_polygon(frame, Color(border.r, border.g, border.b, 0.07 if unlocked else 0.025))
		draw_polyline(frame + PackedVector2Array([frame[0]]), border, 2.3 if selected else (1.8 if unlocked else 1.2), true)
		if selected:
			var inner_frame := TacticalUIHelper.angular_points(rect.grow(-5.0), 9.0)
			draw_polyline(inner_frame + PackedVector2Array([inner_frame[0]]), Color(border.r, border.g, border.b, 0.48), 1.0, true)
			draw_line(origin + Vector2(18.0, 16.0), origin + Vector2(76.0, 16.0), border, 2.0)
		draw_set_transform(origin + Vector2(48.0, 50.0), 0.0, Vector2(1.35, 1.35))
		_draw_silhouette(str(visual.get("silhouette", "kernel_arrow")), true_col if unlocked else Color(true_col.r, true_col.g, true_col.b, 0.22))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_string(orbitron, origin + Vector2(90.0, 38.0), str(definition.get("name", id.to_upper())), HORIZONTAL_ALIGNMENT_LEFT, card_w - 104.0, 17, Balance.COL_TEXT if unlocked else Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.45))
		draw_string(mono, origin + Vector2(90.0, 60.0), str(definition.get("role", "PROGRAM")), HORIZONTAL_ALIGNMENT_LEFT, card_w - 104.0, 11, Color(true_col.r, true_col.g, true_col.b, 0.8 if unlocked else 0.35))
		var summary_size: int = TacticalUI.fit_block(mono, str(definition.get("summary", "")), card_w - 32.0, 34.0, 12, 10)["font_size"]
		draw_multiline_string(mono, origin + Vector2(16.0, 91.0), str(definition.get("summary", "")), HORIZONTAL_ALIGNMENT_LEFT, card_w - 32.0, summary_size, 3, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.68 if unlocked else 0.36))
		var stat_text := "INTEGRITY  %s\nSPEED      %s\nFIRE       %s\nRANGE      %s\nDASH/CORE  %s" % [definition.get("integrity", "—"), definition.get("speed", "—"), definition.get("fire", "—"), definition.get("range", "—"), definition.get("dash_shield", "—")]
		var stat_size: int = TacticalUI.fit_block(mono, stat_text, card_w - 32.0, 64.0, 11, 9)["font_size"]
		draw_multiline_string(mono, origin + Vector2(16.0, 132.0), stat_text, HORIZONTAL_ALIGNMENT_LEFT, card_w - 32.0, stat_size, 5, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.78 if unlocked else 0.42))
		draw_line(origin + Vector2(16.0, card_h - 62.0), origin + Vector2(card_w - 16.0, card_h - 62.0), Color(border.r, border.g, border.b, 0.32), 1.0)
		draw_multiline_string(mono, origin + Vector2(16.0, card_h - 42.0), _tradeoff(id), HORIZONTAL_ALIGNMENT_LEFT, card_w - 32.0, 10, 2, Color(border.r, border.g, border.b, 0.78 if unlocked else 0.42))
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
	var footer: Rect2 = TacticalUIHelper.shell_sections(size)["footer"]
	var legend := Rect2(footer.position, Vector2(maxf(size.x * 0.66, 360.0), footer.size.y - 4.0))
	var legend_points := TacticalUIHelper.angular_points(legend, 8.0)
	draw_colored_polygon(legend_points, Color(TacticalUIHelper.CYAN.r, TacticalUIHelper.CYAN.g, TacticalUIHelper.CYAN.b, 0.025))
	draw_polyline(legend_points + PackedVector2Array([legend_points[0]]), Color(TacticalUIHelper.CYAN.r, TacticalUIHelper.CYAN.g, TacticalUIHelper.CYAN.b, 0.58), 1.0, true)
	draw_string(mono, legend.position + Vector2(14.0, 20.0), "COMPARISON", HORIZONTAL_ALIGNMENT_LEFT, 112.0, 10, TacticalUIHelper.CYAN)
	draw_string(mono, legend.position + Vector2(14.0, 36.0), "INTEGRITY   SPEED   FIRE   RANGE   CORE", HORIZONTAL_ALIGNMENT_LEFT, legend.size.x - 28.0, 10, TacticalUIHelper.MUTED)
	var boot := Rect2(Vector2(legend.end.x + 14.0, footer.position.y), Vector2(maxf(size.x - legend.end.x - 30.0, 220.0), footer.size.y - 4.0))
	var boot_points := TacticalUIHelper.angular_points(boot, 9.0)
	draw_colored_polygon(boot_points, Color(TacticalUIHelper.CYAN.r, TacticalUIHelper.CYAN.g, TacticalUIHelper.CYAN.b, 0.08))
	draw_polyline(boot_points + PackedVector2Array([boot_points[0]]), TacticalUIHelper.CYAN, 1.7, true)
	draw_string(orbitron, boot.position + Vector2(22.0, 30.0), ">> BOOT KERNEL", HORIZONTAL_ALIGNMENT_LEFT, boot.size.x - 100.0, 16, TacticalUIHelper.CYAN)
	draw_string(mono, boot.position + Vector2(boot.size.x - 74.0, 30.0), "[ENTER]", HORIZONTAL_ALIGNMENT_RIGHT, 62.0, 10, TacticalUIHelper.TEXT)

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

func text_overflow_report() -> Array:
	var mono: Font = load("res://assets/fonts/ShareTechMono.ttf")
	var out: Array = []
	var longest_summary := ""
	var longest_stat_line := ""
	for id in Game.PROGRAM_DEFS:
		var definition: Dictionary = Game.PROGRAM_DEFS[id]
		if str(definition.get("summary", "")).length() > longest_summary.length():
			longest_summary = str(definition.get("summary", ""))
		for stat_key in ["fire", "dash_shield"]:
			var line := str(definition.get(stat_key, ""))
			if line.length() > longest_stat_line.length():
				longest_stat_line = line
	var card_w: float = float(_content_metrics().get("card_w", minf(430.0, (size.x - 48.0) * 0.5)))
	out.append({"id": "program_summary", "fits": TacticalUI.wrapped_height(mono, longest_summary, card_w - 32.0, 12) <= 34.0 or TacticalUI.wrapped_height(mono, longest_summary, card_w - 32.0, 10) <= 34.0})
	out.append({"id": "program_stats", "fits": mono.get_string_size(longest_stat_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x <= card_w - 32.0})
	return out

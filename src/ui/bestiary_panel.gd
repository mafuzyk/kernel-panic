class_name BestiaryPanel
extends Control

const TacticalUIHelper = preload("res://src/ui/tactical_ui.gd")
const TacticalChromeScript = preload("res://src/ui/tactical_chrome.gd")

const ENTRIES := [
	{"id": "drone", "name": "DRONE", "desc": "basic corrupted process. dash through packs.", "threat": 50, "bugs": "swarms without a scheduler. forever."},
	{"id": "lancer", "name": "LANCER", "desc": "telegraphs then lunges. sidestep the line, punish the stagger.", "threat": 90, "bugs": "lunges in a straight line. sidestep = fix."},
	{"id": "spewer", "name": "SPEWER", "desc": "keeps distance, spits orbs. shoot the orbs down.", "threat": 110, "bugs": "orbs are shootable. it has not learned this."},
	{"id": "splitter", "name": "SPLITTER", "desc": "splits on death. kill it away from you.", "threat": 100, "bugs": "death is a fork(). plan accordingly."},
	{"id": "bulwark", "name": "BULWARK", "desc": "armored and slow. dash past, never hug.", "threat": 300, "bugs": "armor does not cover the back. or manners."},
	{"id": "trojan", "name": "TROJAN", "desc": "leaves corruption pools. do not swim.", "threat": 140, "bugs": "leaves pools. calls them 'features'."},
	{"id": "oom", "name": "OOM_KILLER", "desc": "steals your motes and runs. hunt it first.", "threat": 150, "bugs": "steals motes. returns nothing. ever."},
	{"id": "boss", "name": "ROOT DAEMON", "desc": "every variant has a tell. learn it. respect it.", "threat": 2500, "bugs": "segfaults reproduce. two of them."},
	{"id": "root", "name": "ROOT.exe", "desc": "splits at half integrity. track both processes.", "threat": 2500, "bugs": "forks once. both children are real."},
	{"id": "segfault", "name": "SEGFAULT", "desc": "glitches, teleports, then opens a lance line.", "threat": 5000, "bugs": "address is invalid. movement is not."},
	{"id": "bluescreen", "name": "BLUE SCREEN", "desc": "freezes systems and floods the arena with fan shots.", "threat": 7500, "bugs": "the error is blue. the projectiles are not."},
	{"id": "pagefault", "name": "PAGE FAULT", "desc": "pages shield it until the orbiting nodes are purged.", "threat": 10000, "bugs": "read protection enabled. delete the pages."},
	{"id": "recursor", "name": "RECURSOR", "desc": "teleports and leaves corruption. pools mark where it was. keep moving.", "threat": 140, "bugs": "leaves corruption where it *was*. check behind you."},
	{"id": "firewall", "name": "FIREWALL", "desc": "rotating wall of orbs. kill the wall to drop the wall.", "threat": 180, "bugs": "wall persists after death of nearby processes."},
	{"id": "update_loop", "name": "UPDATE_LOOP", "desc": "reinstalls once after death. finish the update before celebrating.", "threat": 190, "bugs": "dies, says 'reinstalling', returns with fewer excuses."},
	{"id": "bloatware", "name": "BLOATWARE", "desc": "fat process. drops static popup orbs and spawns background drones.", "threat": 450, "bugs": "47 background processes terminated on exit."},
	{"id": "god", "name": "GOD", "desc": "oracle process. chooses its next attack by literal random roll.", "threat": 777, "bugs": "the attack pattern is not a pattern. it is a result."},
]

var t := 0.0
var scroll_y := 0.0
var _dragging := false
var _press_position := Vector2.ZERO
var _drag_start_y := 0.0
var _scroll_start := 0.0
var _card_rects: Dictionary = {}
var _selected_id := "root"

func _entry_color(id: String) -> Color:
	match id:
		"drone": return Balance.COL_DRONE
		"lancer": return Balance.COL_LANCER
		"spewer": return Balance.COL_SPEWER
		"splitter", "bulwark": return Balance.threat_color(id, Sfx.color_assist)
		"trojan": return Color("c23a5e")
		"oom": return Color("9a4dff")
		"boss": return Color("ff3d81")
		"root": return Color("ff3d81")
		"segfault": return Color("ff9a3d")
		"bluescreen": return Color("4f8cff")
		"pagefault": return Color("b46bff")
		"recursor": return Color("52ff7a")
		"firewall": return Color("37d8ff")
		"update_loop": return Color("67b8ff")
		"bloatware": return Color("4b9ee8")
		_: return Balance.COL_TEXT

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var chrome: Control = TacticalChromeScript.new()
	chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome.call("configure_shell", TacticalUIHelper.CYAN, 0.0)
	add_child(chrome)
	if _selected_id == "" and not ENTRIES.is_empty():
		_selected_id = ENTRIES[0]["id"]

func select_entry(id: String) -> bool:
	for entry in ENTRIES:
		if str(entry["id"]) == id:
			_selected_id = id
			queue_redraw()
			return true
	return false

func detail_entry_id() -> String:
	return _selected_id

func entry_status(id: String) -> String:
	return "LOGGED" if Game.bestiary_seen(id) else "LOCKED // PURGE TO LOG"

func _is_wide() -> bool:
	return size.x >= 1080.0

func _content_metrics() -> Dictionary:
	if _is_wide():
		var list_w := minf(430.0, size.x * 0.34)
		var card_h := 58.0
		var gap := 8.0
		var viewport_top := 156.0
		var viewport_bottom: float = maxf(size.y - 116.0, viewport_top + card_h)
		var content_h := ENTRIES.size() * card_h + maxf(ENTRIES.size() - 1, 0) * gap
		return {"cols": 1, "gap": gap, "card_h": card_h, "card_w": list_w - 16.0, "content_h": content_h, "viewport_top": viewport_top, "viewport_bottom": viewport_bottom, "viewport_h": viewport_bottom - viewport_top, "list_w": list_w}
	var cols: int = 4 if size.x >= 1100.0 else 2
	var card_h := 170.0
	var gap := 18.0
	var viewport_top := 140.0
	var viewport_bottom: float = maxf(size.y - 130.0, viewport_top + card_h)
	var cw: float = minf(280.0, (size.x - 48.0 - gap * float(cols - 1)) / float(cols))
	var rows := ceili(float(ENTRIES.size()) / float(cols))
	var content_h := rows * card_h + maxf(rows - 1, 0) * gap
	return {"cols": cols, "gap": gap, "card_h": card_h, "card_w": cw, "content_h": content_h, "viewport_top": viewport_top, "viewport_bottom": viewport_bottom, "viewport_h": viewport_bottom - viewport_top}

func content_viewport_rect() -> Rect2:
	var metrics := _content_metrics()
	var x := 28.0 if _is_wide() else 0.0
	var width := float(metrics.get("list_w", size.x)) if _is_wide() else size.x
	return Rect2(x, float(metrics["viewport_top"]), width, float(metrics["viewport_h"]))

func visible_card_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	var viewport := content_viewport_rect()
	for raw_rect in _card_rects.values():
		var rect: Rect2 = raw_rect
		if viewport.encloses(rect):
			result.append(rect)
	return result

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_scroll_by(-72.0)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_scroll_by(72.0)
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

func _scroll_by(amount: float) -> void:
	_scroll_to(scroll_y + amount)

func _scroll_to(value: float) -> void:
	var metrics := _content_metrics()
	var max_scroll: float = maxf(float(metrics["content_h"]) - float(metrics["viewport_h"]), 0.0)
	scroll_y = clampf(value, 0.0, max_scroll)
	queue_redraw()

func _select_at(position: Vector2) -> void:
	for raw_id in _card_rects:
		var id := str(raw_id)
		if _card_rects[id].has_point(position):
			if select_entry(id):
				Sfx.play("ui", 1.05, -8.0)
			return

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.012, 0.03, 1.0))
	var mono: Font = load("res://assets/fonts/ShareTechMono.ttf")
	var orbitron: Font = load("res://assets/fonts/Orbitron.ttf")
	var metrics := _content_metrics()
	var cols: int = metrics["cols"]
	var gap: float = metrics["gap"]
	var cw: float = metrics["card_w"]
	var ch: float = metrics["card_h"]
	var x0: float = 28.0 if _is_wide() else (size.x - cw * float(cols) - gap * float(cols - 1)) * 0.5
	var y0: float = float(metrics["viewport_top"]) - scroll_y
	var viewport_top: float = metrics["viewport_top"]
	var viewport_bottom: float = metrics["viewport_bottom"]
	_card_rects.clear()
	if _is_wide():
		var list_frame := TacticalUIHelper.angular_points(Rect2(28.0, 146.0, float(metrics["list_w"]), size.y - 258.0), 12.0)
		draw_colored_polygon(list_frame, Color(TacticalUIHelper.CYAN.r, TacticalUIHelper.CYAN.g, TacticalUIHelper.CYAN.b, 0.025))
		draw_polyline(list_frame + PackedVector2Array([list_frame[0]]), Color(TacticalUIHelper.CYAN.r, TacticalUIHelper.CYAN.g, TacticalUIHelper.CYAN.b, 0.42), 1.0, true)
	for i in ENTRIES.size():
		var e: Dictionary = ENTRIES[i]
		var col := i % cols
		var row := i / cols
		var origin := Vector2(x0 + col * (cw + gap), y0 + row * (ch + gap))
		var rect := Rect2(origin, Vector2(cw, ch))
		_card_rects[e["id"]] = rect
		if origin.y < viewport_top or origin.y + ch > viewport_bottom:
			continue
		var seen := Game.bestiary_seen(e["id"])
		var true_col: Color = _entry_color(e["id"])
		var selected: bool = _selected_id == e["id"]
		var border := true_col if seen else Color(true_col.r, true_col.g, true_col.b, 0.25)
		var frame := TacticalUIHelper.angular_points(rect, 8.0)
		draw_colored_polygon(frame, Color(border.r, border.g, border.b, 0.10 if selected else 0.045))
		draw_polyline(frame + PackedVector2Array([frame[0]]), Color(border.r, border.g, border.b, 1.0 if selected else 0.65), 1.8 if selected else 1.1, true)
		if selected:
			var inner := TacticalUIHelper.angular_points(rect.grow(-3.0), 6.0)
			draw_polyline(inner + PackedVector2Array([inner[0]]), Color(border.r, border.g, border.b, 0.38), 1.0, true)
		var glyph_c := origin + Vector2(30.0, ch * 0.5)
		draw_set_transform(glyph_c, 0.0, Vector2(0.76 if _is_wide() else 1.6, 0.76 if _is_wide() else 1.6))
		_draw_glyph(e["id"], true_col if seen else Color(true_col.r, true_col.g, true_col.b, 0.18))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if _is_wide():
			var name_txt: String = e["name"] if seen else "???"
			draw_string(orbitron, origin + Vector2(58.0, 24.0), name_txt, HORIZONTAL_ALIGNMENT_LEFT, cw - 160.0, 13, Balance.COL_TEXT if seen else Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.4))
			draw_string(mono, origin + Vector2(cw - 94.0, 23.0), "%d PTS" % int(e["threat"]), HORIZONTAL_ALIGNMENT_RIGHT, 78.0, 10, Color(Balance.COL_MOTE.r, Balance.COL_MOTE.g, Balance.COL_MOTE.b, 0.72 if seen else 0.32))
			var status := "LOGGED // SELECT FOR DETAIL" if seen else "LOCKED // PURGE TO LOG"
			draw_string(mono, origin + Vector2(58.0, 43.0), status, HORIZONTAL_ALIGNMENT_LEFT, cw - 72.0, 9, Color(border.r, border.g, border.b, 0.75))
		else:
			var name_txt: String = e["name"] if seen else "???"
			draw_string(orbitron, origin + Vector2(14, ch - 70.0), name_txt, HORIZONTAL_ALIGNMENT_LEFT, cw - 28, 16, Balance.COL_TEXT if seen else Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.4))
			var desc: String = e["desc"] if seen else "purge one to log its data."
			draw_multiline_string(mono, origin + Vector2(14, ch - 48.0), desc, HORIZONTAL_ALIGNMENT_LEFT, cw - 28, 12, 2, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.65 if seen else 0.3))
		if not _is_wide():
			if seen:
				draw_string(mono, origin + Vector2(cw - 14.0, 20.0), "%d PTS" % int(e["threat"]), HORIZONTAL_ALIGNMENT_RIGHT, 90.0, 11, Color(Balance.COL_MOTE.r, Balance.COL_MOTE.g, Balance.COL_MOTE.b, 0.7))
			if not seen:
				draw_string(mono, origin + Vector2(14, ch - 14.0), "[ LOCKED ]", HORIZONTAL_ALIGNMENT_LEFT, cw - 28, 11, Color(Balance.COL_DANGER.r, Balance.COL_DANGER.g, Balance.COL_DANGER.b, 0.5))
			else:
				draw_string(mono, origin + Vector2(14, ch - 14.0), "BUGS: " + str(e["bugs"]), HORIZONTAL_ALIGNMENT_LEFT, cw - 28, 11, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.55))
	if _is_wide():
		_draw_detail(metrics, mono, orbitron)
	var viewport_h: float = metrics["viewport_h"]
	var content_h: float = metrics["content_h"]
	var max_scroll: float = maxf(content_h - viewport_h, 0.0)
	if max_scroll > 0.0:
		var track := Rect2((float(metrics["list_w"]) + 18.0 if _is_wide() else size.x - 22.0), viewport_top, 4.0, viewport_h)
		var thumb_h: float = maxf(28.0, viewport_h * viewport_h / content_h)
		var thumb_y: float = track.position.y + (track.size.y - thumb_h) * (scroll_y / max_scroll)
		draw_rect(track, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.12))
		draw_rect(Rect2(track.position.x, thumb_y, track.size.x, thumb_h), Color(Balance.COL_PLAYER.r, Balance.COL_PLAYER.g, Balance.COL_PLAYER.b, 0.75))
		draw_string(mono, Vector2(size.x - 210.0, size.y - 102.0), "SWIPE TO SCROLL", HORIZONTAL_ALIGNMENT_RIGHT, 180.0, 11, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.45))

func _draw_detail(metrics: Dictionary, mono: Font, orbitron: Font) -> void:
	var rail := Rect2(float(metrics["list_w"]) + 58.0, 146.0, size.x - float(metrics["list_w"]) - 86.0, size.y - 258.0)
	var entry: Dictionary = {}
	for candidate in ENTRIES:
		if str(candidate["id"]) == _selected_id:
			entry = candidate
			break
	if entry.is_empty():
		entry = ENTRIES[0]
	var id := str(entry["id"])
	var seen := Game.bestiary_seen(id)
	var accent: Color = _entry_color(id)
	var frame := TacticalUIHelper.angular_points(rail, 13.0)
	draw_colored_polygon(frame, Color(accent.r, accent.g, accent.b, 0.055))
	draw_polyline(frame + PackedVector2Array([frame[0]]), Color(accent.r, accent.g, accent.b, 0.62), 1.5, true)
	draw_string(mono, rail.position + Vector2(20.0, 26.0), "FIELD ENTRY // %s" % ("LOGGED" if seen else "LOCKED"), HORIZONTAL_ALIGNMENT_LEFT, rail.size.x - 40.0, 11, Color(accent.r, accent.g, accent.b, 0.85))
	draw_string(orbitron, rail.position + Vector2(20.0, 58.0), str(entry["name"]) if seen else "UNKNOWN PROCESS", HORIZONTAL_ALIGNMENT_LEFT, rail.size.x - 220.0, 23, TacticalUIHelper.TEXT)
	draw_string(mono, rail.position + Vector2(20.0, 82.0), "%d THREAT POINTS" % int(entry["threat"]) if seen else "PURGE THIS PROCESS TO REVEAL", HORIZONTAL_ALIGNMENT_LEFT, rail.size.x - 220.0, 11, Color(Balance.COL_MOTE.r, Balance.COL_MOTE.g, Balance.COL_MOTE.b, 0.85 if seen else 0.45))
	var points_chip := Rect2(rail.position + Vector2(20.0, 100.0), Vector2(154.0, 36.0))
	var points_frame := TacticalUIHelper.angular_points(points_chip, 7.0)
	draw_polyline(points_frame + PackedVector2Array([points_frame[0]]), Color(accent.r, accent.g, accent.b, 0.72), 1.2, true)
	draw_string(orbitron, points_chip.position + Vector2(14.0, 24.0), "%d PTS" % int(entry["threat"]) if seen else "??? PTS", HORIZONTAL_ALIGNMENT_LEFT, points_chip.size.x - 28.0, 15, accent)
	var glyph_pos := Vector2(rail.end.x - 118.0, rail.position.y + 120.0)
	draw_set_transform(glyph_pos, 0.0, Vector2(3.5, 3.5))
	_draw_glyph(id, Color(accent.r, accent.g, accent.b, 0.9 if seen else 0.2))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_line(rail.position + Vector2(20.0, 152.0), rail.position + Vector2(rail.size.x - 20.0, 152.0), Color(accent.r, accent.g, accent.b, 0.28), 1.0)
	draw_string(mono, rail.position + Vector2(20.0, 180.0), "BEHAVIOR", HORIZONTAL_ALIGNMENT_LEFT, rail.size.x - 40.0, 11, accent)
	var desc_text := "> " + (str(entry["desc"]) if seen else "No field data available. The first sighting will unlock this behavior report.")
	var desc_size: int = TacticalUI.fit_block(mono, desc_text, rail.size.x - 40.0, 64.0, 13, 10)["font_size"]
	draw_multiline_string(mono, rail.position + Vector2(20.0, 204.0), desc_text, HORIZONTAL_ALIGNMENT_LEFT, rail.size.x - 40.0, desc_size, 5, Color(TacticalUIHelper.TEXT.r, TacticalUIHelper.TEXT.g, TacticalUIHelper.TEXT.b, 0.78 if seen else 0.42))
	draw_string(mono, rail.position + Vector2(20.0, 278.0), "BUG REPORT", HORIZONTAL_ALIGNMENT_LEFT, rail.size.x - 40.0, 11, accent)
	var bugs_text := "> " + (str(entry["bugs"]) if seen else "LOCKED // COMPLETE A SIGHTING TO ACCESS NOTES")
	var bugs_size: int = TacticalUI.fit_block(mono, bugs_text, rail.size.x - 40.0, float(rail.size.y) - 316.0, 12, 10)["font_size"]
	draw_multiline_string(mono, rail.position + Vector2(20.0, 302.0), bugs_text, HORIZONTAL_ALIGNMENT_LEFT, rail.size.x - 40.0, bugs_size, 6, Color(TacticalUIHelper.TEXT.r, TacticalUIHelper.TEXT.g, TacticalUIHelper.TEXT.b, 0.64 if seen else 0.36))

func _draw_glyph(id: String, c: Color) -> void:
	match id:
		"drone":
			var pts := PackedVector2Array([Vector2(16, 0), Vector2(-10, 11), Vector2(-3, 0), Vector2(-10, -11)])
			draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.25))
			draw_polyline(pts + PackedVector2Array([pts[0]]), c, 1.5, true)
		"lancer":
			var pts := PackedVector2Array([Vector2(20, 0), Vector2(-12, 8), Vector2(-5, 0), Vector2(-12, -8)])
			draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.25))
			draw_polyline(pts + PackedVector2Array([pts[0]]), c, 1.5, true)
			draw_line(Vector2(24, 0), Vector2(40, 0), Color(c.r, c.g, c.b, 0.5), 1.0)
		"spewer":
			var pts := PackedVector2Array()
			for i in 6:
				pts.push_back(Vector2.from_angle(TAU * i / 6.0) * 15)
			draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.2))
			draw_polyline(pts + PackedVector2Array([pts[0]]), c, 1.5, true)
			draw_circle(Vector2.ZERO, 5, c)
		"splitter":
			draw_circle(Vector2.ZERO, 15, Color(c.r, c.g, c.b, 0.15))
			draw_arc(Vector2.ZERO, 15, 0, TAU, 28, c, 1.5, true)
			draw_line(Vector2(-8, 0), Vector2(8, 0), c, 1.5)
			_draw_color_assist_marker("SPLIT", c)
		"bulwark":
			var pts := PackedVector2Array([Vector2(12, 12), Vector2(-12, 12), Vector2(-12, -12), Vector2(12, -12)])
			draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.15))
			draw_polyline(pts + PackedVector2Array([pts[0]]), c, 2.0, true)
			draw_line(Vector2(-6, -6), Vector2(6, 6), Color(c.r, c.g, c.b, 0.7), 1.5)
			draw_line(Vector2(-6, 6), Vector2(6, -6), Color(c.r, c.g, c.b, 0.7), 1.5)
			_draw_color_assist_marker("BULW", c)
		"trojan":
			var pts := PackedVector2Array([Vector2(0, -15), Vector2(9, 0), Vector2(0, 15), Vector2(-9, 0)])
			draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.2))
			draw_polyline(pts + PackedVector2Array([pts[0]]), c, 1.5, true)
			draw_line(Vector2(-7, -5), Vector2(7, 5), c, 1.2)
			draw_line(Vector2(-7, 5), Vector2(7, -5), c, 1.2)
		"oom":
			draw_circle(Vector2.ZERO, 12, Color(c.r, c.g, c.b, 0.2))
			draw_arc(Vector2.ZERO, 12, 0, TAU, 22, c, 1.5, true)
			draw_colored_polygon(PackedVector2Array([Vector2(-4, -8), Vector2(-8, -16), Vector2(-1, -9)]), c)
			draw_colored_polygon(PackedVector2Array([Vector2(4, -8), Vector2(8, -16), Vector2(1, -9)]), c)
		"boss":
			for i in 6:
				var a0 := TAU * i / 6.0
				draw_arc(Vector2.ZERO, 17, a0, a0 + TAU / 6.0 * 0.6, 8, c, 2.0, true)
		"root":
			for i in 6:
				var a0 := TAU * i / 6.0
				draw_arc(Vector2.ZERO, 17, a0, a0 + TAU / 6.0 * 0.6, 8, c, 2.0, true)
			draw_line(Vector2(-8, 0), Vector2(8, 0), c, 1.5)
		"segfault":
			draw_line(Vector2(-16, -12), Vector2(16, 12), c, 2.0)
			draw_line(Vector2(-16, 12), Vector2(-3, 0), c, 2.0)
			draw_line(Vector2(3, 0), Vector2(16, -12), c, 2.0)
		"bluescreen":
			draw_rect(Rect2(-15, -13, 30, 26), Color(c.r, c.g, c.b, 0.18))
			draw_rect(Rect2(-15, -13, 30, 26), c, false, 1.5)
			draw_line(Vector2(-8, -3), Vector2(8, -3), c, 1.5)
			draw_line(Vector2(-8, 4), Vector2(4, 4), c, 1.5)
		"pagefault":
			var page := PackedVector2Array([Vector2(-14, -15), Vector2(8, -15), Vector2(15, -8), Vector2(15, 15), Vector2(-14, 15)])
			draw_colored_polygon(page, Color(c.r, c.g, c.b, 0.18))
			draw_polyline(page + PackedVector2Array([page[0]]), c, 1.5, true)
			draw_line(Vector2(-8, -3), Vector2(8, -3), c, 1.5)
			draw_line(Vector2(-8, 5), Vector2(5, 5), c, 1.5)
		"recursor":
			draw_colored_polygon(PackedVector2Array([Vector2(0, -15), Vector2(15, 0), Vector2(0, 15), Vector2(-15, 0)]), Color(c.r, c.g, c.b, 0.25))
			draw_polyline(PackedVector2Array([Vector2(0, -15), Vector2(15, 0), Vector2(0, 15), Vector2(-15, 0), Vector2(0, -15)]), c, 1.5, true)
			draw_circle(Vector2.ZERO, 4.5, c)
			draw_circle(Vector2(14, -14), 3.0, Color(c.r, c.g, c.b, 0.5))
		"firewall":
			var fpts := PackedVector2Array()
			for i in 8:
				fpts.push_back(Vector2.from_angle(TAU * i / 8.0) * 14)
			draw_polyline(fpts + PackedVector2Array([fpts[0]]), c, 1.5, true)
			for i in 5:
				draw_circle(Vector2.from_angle(TAU * i / 5.0) * 22, 3.0, Color(c.r, c.g, c.b, 0.7))
			var tri := PackedVector2Array([Vector2(8, 0), Vector2(-6, 7), Vector2(-6, -7)])
			draw_polyline(tri + PackedVector2Array([tri[0]]), c, 1.5, true)
		"update_loop":
			draw_rect(Rect2(-14, -11, 28, 22), Color(c.r, c.g, c.b, 0.18))
			draw_rect(Rect2(-14, -11, 28, 22), c, false, 1.5)
			draw_arc(Vector2.ZERO, 19.0, -PI / 2.0, PI, 18, c, 2.0, true)
		"bloatware":
			draw_rect(Rect2(-17, -12, 34, 24), Color(c.r, c.g, c.b, 0.18))
			draw_rect(Rect2(-17, -12, 34, 24), c, false, 2.0)
			for i in 5:
				draw_circle(Vector2.from_angle(TAU * i / 5.0) * 24.0, 3.0, Color(c.r, c.g, c.b, 0.75))
		"god":
			draw_circle(Vector2.ZERO, 17.0, Color(c.r, c.g, c.b, 0.12))
			draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 32, c, 2.0, true)
			for i in 6:
				draw_line(Vector2.from_angle(TAU * i / 6.0) * 20.0, Vector2.from_angle(TAU * i / 6.0) * 25.0, c, 2.0)

func _draw_color_assist_marker(label: String, c: Color) -> void:
	if not Sfx.color_assist:
		return
	var center := Vector2(30.0, -20.0)
	draw_circle(center, 10.0, Color(c.r, c.g, c.b, 0.14))
	draw_arc(center, 10.0, 0.0, TAU, 20, c, 1.2, true)
	draw_string(ThemeDB.fallback_font, center + Vector2(-18.0, 3.0), label, HORIZONTAL_ALIGNMENT_CENTER, 36.0, 8, c)

func text_overflow_report() -> Array:
	var mono: Font = load("res://assets/fonts/ShareTechMono.ttf")
	var out: Array = []
	var metrics := _content_metrics()
	var rail_w: float = size.x - float(metrics.get("list_w", size.x * 0.4)) - 86.0
	var longest_desc := ""
	var longest_bugs := ""
	for entry in ENTRIES:
		if ("> " + str(entry["desc"])).length() > longest_desc.length():
			longest_desc = "> " + str(entry["desc"])
		if ("> " + str(entry["bugs"])).length() > longest_bugs.length():
			longest_bugs = "> " + str(entry["bugs"])
	out.append({"id": "bestiary_desc", "fits": TacticalUI.wrapped_height(mono, longest_desc, rail_w - 40.0, 13) <= 64.0 or TacticalUI.wrapped_height(mono, longest_desc, rail_w - 40.0, 10) <= 64.0})
	out.append({"id": "bestiary_bugs", "fits": TacticalUI.wrapped_height(mono, longest_bugs, rail_w - 40.0, 12) <= maxf(size.y - 258.0 - 58.0, 0.0) or TacticalUI.wrapped_height(mono, longest_bugs, rail_w - 40.0, 10) <= maxf(size.y - 258.0 - 58.0, 0.0)})
	return out

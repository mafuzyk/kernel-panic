class_name BestiaryPanel
extends Control

const ENTRIES := [
	{"id": "drone", "name": "DRONE", "desc": "basic corrupted process. dash through packs.", "threat": 50, "bugs": "swarms without a scheduler. forever."},
	{"id": "lancer", "name": "LANCER", "desc": "telegraphs then lunges. sidestep the line, punish the stagger.", "threat": 90, "bugs": "lunges in a straight line. sidestep = fix."},
	{"id": "spewer", "name": "SPEWER", "desc": "keeps distance, spits orbs. shoot the orbs down.", "threat": 110, "bugs": "orbs are shootable. it has not learned this."},
	{"id": "splitter", "name": "SPLITTER", "desc": "splits on death. kill it away from you.", "threat": 100, "bugs": "death is a fork(). plan accordingly."},
	{"id": "bulwark", "name": "BULWARK", "desc": "armored and slow. dash past, never hug.", "threat": 300, "bugs": "armor does not cover the back. or manners."},
	{"id": "trojan", "name": "TROJAN", "desc": "leaves corruption pools. do not swim.", "threat": 140, "bugs": "leaves pools. calls them 'features'."},
	{"id": "oom", "name": "OOM_KILLER", "desc": "steals your motes and runs. hunt it first.", "threat": 150, "bugs": "steals motes. returns nothing. ever."},
	{"id": "boss", "name": "ROOT DAEMON", "desc": "every variant has a tell. learn it. respect it.", "threat": 2500, "bugs": "segfaults reproduce. two of them."},
	{"id": "recursor", "name": "RECURSOR", "desc": "teleports and leaves corruption. pools mark where it was. keep moving.", "threat": 140, "bugs": "leaves corruption where it *was*. check behind you."},
	{"id": "firewall", "name": "FIREWALL", "desc": "rotating wall of orbs. kill the wall to drop the wall.", "threat": 180, "bugs": "wall persists after death of nearby processes."},
]

var t := 0.0
var scroll_y := 0.0
var _dragging := false
var _drag_start_y := 0.0
var _scroll_start := 0.0

func _entry_color(id: String) -> Color:
	match id:
		"drone": return Balance.COL_DRONE
		"lancer": return Balance.COL_LANCER
		"spewer": return Balance.COL_SPEWER
		"splitter": return Balance.COL_SPLITTER
		"bulwark": return Balance.COL_BULWARK
		"trojan": return Color("c23a5e")
		"oom": return Color("9a4dff")
		"boss": return Color("ff3d81")
		"recursor": return Color("52ff7a")
		"firewall": return Color("37d8ff")
		_: return Balance.COL_TEXT

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

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
			_dragging = event.pressed
			if _dragging:
				_drag_start_y = event.position.y
				_scroll_start = scroll_y
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_scroll_to(_scroll_start - (event.position.y - _drag_start_y))
		accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_dragging = true
			_drag_start_y = event.position.y
			_scroll_start = scroll_y
		else:
			_dragging = false
		accept_event()
	elif event is InputEventScreenDrag and _dragging:
		_scroll_to(_scroll_start - (event.position.y - _drag_start_y))
		accept_event()

func _scroll_by(amount: float) -> void:
	_scroll_to(scroll_y + amount)

func _scroll_to(value: float) -> void:
	var cols: int = 4 if size.x >= 1100.0 else 2
	var rows: int = ceili(float(ENTRIES.size()) / float(cols))
	var card_h := 170.0
	var gap := 18.0
	var viewport_h: float = maxf(size.y - 270.0, 240.0)
	var content_h: float = rows * card_h + (rows - 1) * gap
	var max_scroll: float = maxf(content_h - viewport_h, 0.0)
	scroll_y = clampf(value, 0.0, max_scroll)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.012, 0.03, 1.0))
	var mono: Font = load("res://assets/fonts/ShareTechMono.ttf")
	var orbitron: Font = load("res://assets/fonts/Orbitron.ttf")
	var cols: int = 4 if size.x >= 1100.0 else 2
	var gap := 18.0
	var cw: float = minf(280.0, (size.x - 48.0 - gap * float(cols - 1)) / float(cols))
	var ch := 170.0
	var total_w: float = cw * float(cols) + gap * float(cols - 1)
	var x0: float = (size.x - total_w) * 0.5
	var y0 := 150.0 - scroll_y
	var viewport_top := 140.0
	var viewport_bottom: float = size.y - 130.0
	for i in ENTRIES.size():
		var e: Dictionary = ENTRIES[i]
		var col := i % cols
		var row := i / cols
		var origin := Vector2(x0 + col * (cw + gap), y0 + row * (ch + gap))
		# Keep whole cards inside the scroll viewport; never paint under BACK/nav UI.
		if origin.y < viewport_top or origin.y + ch > viewport_bottom:
			continue
		var seen := Game.bestiary_seen(e["id"])
		var true_col: Color = _entry_color(e["id"])
		var border := true_col if seen else Color(true_col.r, true_col.g, true_col.b, 0.25)
		draw_rect(Rect2(origin, Vector2(cw, ch)), Color(border.r, border.g, border.b, 0.06))
		draw_rect(Rect2(origin, Vector2(cw, ch)), border, false, 1.5)
		var glyph_c := Vector2(origin + Vector2(cw * 0.5, 54.0))
		draw_set_transform(glyph_c, 0.0, Vector2(1.6, 1.6))
		if seen:
			_draw_glyph(e["id"], true_col)
		else:
			_draw_glyph(e["id"], Color(true_col.r, true_col.g, true_col.b, 0.18))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var name_txt: String = e["name"] if seen else "???"
		draw_string(orbitron, origin + Vector2(14, ch - 70.0), name_txt, HORIZONTAL_ALIGNMENT_LEFT, cw - 28, 16, Balance.COL_TEXT if seen else Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.4))
		var desc: String = e["desc"] if seen else "purge one to log its data."
		draw_multiline_string(mono, origin + Vector2(14, ch - 48.0), desc, HORIZONTAL_ALIGNMENT_LEFT, cw - 28, 12, 2, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.65 if seen else 0.3))
		if seen:
			draw_string(mono, origin + Vector2(cw - 14.0, 20.0), "%d PTS" % int(e["threat"]), HORIZONTAL_ALIGNMENT_RIGHT, 90.0, 11, Color(Balance.COL_MOTE.r, Balance.COL_MOTE.g, Balance.COL_MOTE.b, 0.7))
		if not seen:
			draw_string(mono, origin + Vector2(14, ch - 14.0), "[ LOCKED ]", HORIZONTAL_ALIGNMENT_LEFT, cw - 28, 11, Color(Balance.COL_DANGER.r, Balance.COL_DANGER.g, Balance.COL_DANGER.b, 0.5))
		else:
			draw_string(mono, origin + Vector2(14, ch - 14.0), "BUGS: " + str(e["bugs"]), HORIZONTAL_ALIGNMENT_LEFT, cw - 28, 11, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.55))
	var viewport_h: float = maxf(size.y - 270.0, 240.0)
	var rows: int = ceili(float(ENTRIES.size()) / float(cols))
	var content_h: float = rows * ch + (rows - 1) * gap
	var max_scroll: float = maxf(content_h - viewport_h, 0.0)
	if max_scroll > 0.0:
		var track := Rect2(size.x - 22.0, 150.0, 4.0, viewport_h)
		var thumb_h: float = maxf(28.0, viewport_h * viewport_h / content_h)
		var thumb_y: float = track.position.y + (track.size.y - thumb_h) * (scroll_y / max_scroll)
		draw_rect(track, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.12))
		draw_rect(Rect2(track.position.x, thumb_y, track.size.x, thumb_h), Color(Balance.COL_PLAYER.r, Balance.COL_PLAYER.g, Balance.COL_PLAYER.b, 0.75))
		draw_string(mono, Vector2(size.x - 210.0, size.y - 102.0), "SWIPE TO SCROLL", HORIZONTAL_ALIGNMENT_RIGHT, 180.0, 11, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.45))

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
		"bulwark":
			var pts := PackedVector2Array([Vector2(12, 12), Vector2(-12, 12), Vector2(-12, -12), Vector2(12, -12)])
			draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.15))
			draw_polyline(pts + PackedVector2Array([pts[0]]), c, 2.0, true)
			draw_line(Vector2(-6, -6), Vector2(6, 6), Color(c.r, c.g, c.b, 0.7), 1.5)
			draw_line(Vector2(-6, 6), Vector2(6, -6), Color(c.r, c.g, c.b, 0.7), 1.5)
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

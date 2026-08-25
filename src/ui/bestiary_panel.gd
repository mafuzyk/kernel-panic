class_name BestiaryPanel
extends Control

const ENTRIES := [
	{"id": "drone", "name": "DRONE", "desc": "basic corrupted process. chases. dies. respawns."},
	{"id": "lancer", "name": "LANCER", "desc": "telegraphs, then lunges. respect the line."},
	{"id": "spewer", "name": "SPEWER", "desc": "keeps distance, spits orbs. orbs are destructible."},
	{"id": "splitter", "name": "SPLITTER", "desc": "splits in two on death. math is not on your side."},
	{"id": "bulwark", "name": "BULWARK", "desc": "armored. slow, angry, full of orbs on death."},
	{"id": "trojan", "name": "TROJAN", "desc": "leaves corruption pools. do not swim."},
	{"id": "oom", "name": "OOM_KILLER", "desc": "steals your motes and runs. rude."},
	{"id": "boss", "name": "ROOT DAEMON", "desc": "cycle boss. every variant gets personal."},
]

var t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.012, 0.03, 0.92))
	var mono: Font = load("res://assets/fonts/ShareTechMono.ttf")
	var orbitron: Font = load("res://assets/fonts/Orbitron.ttf")
	var cw := 280.0
	var ch := 190.0
	var gap := 22.0
	var total_w := cw * 4.0 + gap * 3.0
	var x0 := (size.x - total_w) * 0.5
	var y0 := (size.y - ch * 2.0 - gap) * 0.5 + 30.0
	for i in ENTRIES.size():
		var e: Dictionary = ENTRIES[i]
		var col := i % 4
		var row := i / 4
		var origin := Vector2(x0 + col * (cw + gap), y0 + row * (ch + gap))
		var seen := Game.bestiary_seen(e["id"])
		var border := Balance.COL_PLAYER if seen else Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.25)
		draw_rect(Rect2(origin, Vector2(cw, ch)), Color(border.r, border.g, border.b, 0.06))
		draw_rect(Rect2(origin, Vector2(cw, ch)), border, false, 1.5)
		var glyph_c := Vector2(origin + Vector2(cw * 0.5, 62.0))
		draw_set_transform(glyph_c, 0.0, Vector2(1.6, 1.6))
		if seen:
			_draw_glyph(e["id"], border)
		else:
			_draw_glyph(e["id"], Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.13))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var name_txt: String = e["name"] if seen else "???"
		draw_string(orbitron, origin + Vector2(14, ch - 62.0), name_txt, HORIZONTAL_ALIGNMENT_LEFT, cw - 28, 17, Balance.COL_TEXT if seen else Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.4))
		var desc: String = e["desc"] if seen else "purge one to log its data."
		draw_string(mono, origin + Vector2(14, ch - 36.0), desc, HORIZONTAL_ALIGNMENT_LEFT, cw - 28, 12, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.65 if seen else 0.3))
		if not seen:
			draw_string(mono, origin + Vector2(14, ch - 16.0), "[ LOCKED ]", HORIZONTAL_ALIGNMENT_LEFT, cw - 28, 11, Color(Balance.COL_DANGER.r, Balance.COL_DANGER.g, Balance.COL_DANGER.b, 0.5))
		else:
			draw_string(mono, origin + Vector2(14, ch - 16.0), "[ LOGGED ]", HORIZONTAL_ALIGNMENT_LEFT, cw - 28, 11, Color(Balance.COL_PLAYER.r, Balance.COL_PLAYER.g, Balance.COL_PLAYER.b, 0.6))

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
			var tri := PackedVector2Array([Vector2(8, 0), Vector2(-6, 7), Vector2(-6, -7)])
			draw_polyline(tri + PackedVector2Array([tri[0]]), c, 1.5, true)

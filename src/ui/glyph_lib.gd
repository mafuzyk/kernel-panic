class_name GlyphLib
extends RefCounted

## Shared code-drawn silhouettes for enemies and playable programs.
## Pure canvas drawing: no state, no Game.rng, no node allocation.

static func glyph_kinds() -> Array:
	return ["drone", "lancer", "spewer", "splitter", "bulwark", "trojan", "oom", "recursor", "firewall", "bloatware", "update_loop", "zombie_process", "race_condition", "page", "root", "boss", "segfault", "bluescreen", "pagefault", "god", "kernel", "daemon", "rootlet"]

## Maximum silhouette reach per kind, in multiples of the draw radius.
## Conservative outer bounds (lancer's lance tip reaches 2.4x, oom horns 1.6x,
## segfault jitter 1.45x); detail views use this to fit glyphs into fixed boxes.
const GLYPH_EXTENT := {
	"drone": 1.5, "lancer": 2.4, "spewer": 1.25, "splitter": 1.05, "bulwark": 1.05,
	"trojan": 1.25, "oom": 1.6, "recursor": 1.05, "firewall": 1.05, "bloatware": 1.05,
	"update_loop": 1.05, "zombie_process": 1.35, "race_condition": 1.35, "page": 1.25, "root": 1.05, "boss": 1.05, "segfault": 1.45,
	"bluescreen": 0.95, "pagefault": 1.15, "god": 1.35, "kernel": 1.5, "daemon": 1.45,
	"rootlet": 1.1,
}

static func glyph_extent(kind: String) -> float:
	return float(GLYPH_EXTENT.get(kind, 1.0))

static func era_mix(base: Color, era: Color, amount: float = 0.25) -> Color:
	if era.a <= 0.0 or amount <= 0.0:
		return base
	return base.lerp(era, clampf(amount, 0.0, 1.0))

static func draw_glyph(canvas: CanvasItem, kind: String, center: Vector2, radius: float, color: Color, t: float = 0.0) -> void:
	if canvas == null or radius <= 0.0:
		return
	# Single sprite-trial switch: when the registry holds a sprite for this
	# kind it is drawn axis-aligned (non-rotating) and the code silhouette is
	# skipped; an empty/missing sprite keeps exactly the current visuals.
	if EntitySprite.draw_entity(canvas, kind, center, radius * 2.4, color):
		return
	var c := color
	match kind:
		"drone":
			_draw_drone(canvas, center, radius, c, t)
		"lancer":
			_draw_lancer(canvas, center, radius, c, t)
		"spewer":
			_draw_spewer(canvas, center, radius, c, t)
		"splitter":
			canvas.draw_circle(center, radius, Color(c.r, c.g, c.b, 0.18))
			canvas.draw_arc(center, radius, 0, TAU, 32, c, 2.2, true)
			canvas.draw_line(center + Vector2(-radius * 0.55, 0), center + Vector2(radius * 0.55, 0), c, 2.0)
			canvas.draw_circle(center + Vector2(-radius * 0.3, 0), radius * 0.2, c)
			canvas.draw_circle(center + Vector2(radius * 0.3, 0), radius * 0.2, c)
		"bulwark":
			var square := PackedVector2Array()
			for i in 4:
				square.push_back(center + Vector2.from_angle(TAU * i / 4.0 + PI / 4.0) * radius)
			canvas.draw_colored_polygon(square, Color(c.r, c.g, c.b, 0.16))
			canvas.draw_polyline(square + PackedVector2Array([square[0]]), c, 3.0, true)
			canvas.draw_line(center + Vector2(-radius * 0.4, -radius * 0.4), center + Vector2(radius * 0.4, radius * 0.4), Color(c.r, c.g, c.b, 0.8), 2.2)
			canvas.draw_line(center + Vector2(-radius * 0.4, radius * 0.4), center + Vector2(radius * 0.4, -radius * 0.4), Color(c.r, c.g, c.b, 0.8), 2.2)
			canvas.draw_arc(center, radius * 0.4, 0, TAU, 20, Color(c.r, c.g, c.b, 0.8), 2.0, true)
		"trojan":
			var diamond := PackedVector2Array([center + Vector2(0, -radius * 1.2), center + Vector2(radius * 0.75, 0), center + Vector2(0, radius * 1.2), center + Vector2(-radius * 0.75, 0)])
			canvas.draw_colored_polygon(diamond, Color(c.r, c.g, c.b, 0.22))
			canvas.draw_polyline(diamond + PackedVector2Array([diamond[0]]), c, 2.0, true)
			canvas.draw_line(center + Vector2(-radius * 0.9, -radius * 0.5), center + Vector2(radius * 0.9, radius * 0.5), Color(c.r, c.g, c.b, 0.8), 2.0)
			canvas.draw_line(center + Vector2(-radius * 0.9, radius * 0.5), center + Vector2(radius * 0.9, -radius * 0.5), Color(c.r, c.g, c.b, 0.8), 2.0)
		"oom":
			canvas.draw_circle(center, radius, Color(c.r, c.g, c.b, 0.2))
			canvas.draw_arc(center, radius, 0, TAU, 24, c, 2.2, true)
			_horn(canvas, center + Vector2(-radius * 0.5, -radius * 0.7), radius * 0.45, c)
			_horn(canvas, center + Vector2(radius * 0.5, -radius * 0.7), radius * 0.45, c, true)
		"recursor":
			var angles := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(radius * 0.5, radius * 0.5), center + Vector2(0, radius), center + Vector2(-radius * 0.5, radius * 0.5), center + Vector2(-radius, 0), center + Vector2(-radius * 0.5, -radius * 0.5), center + Vector2(0, -radius * 0.6)])
			canvas.draw_colored_polygon(PackedVector2Array([angles[0], angles[1], angles[3], angles[5]]), Color(c.r, c.g, c.b, 0.25))
			canvas.draw_polyline(angles, c, 2.0, true)
			canvas.draw_circle(center, radius * 0.3, c)
		"firewall":
			var oct := PackedVector2Array()
			for i in 8:
				oct.push_back(center + Vector2.from_angle(TAU * i / 8.0 + t * 0.4) * radius)
			canvas.draw_colored_polygon(oct, Color(c.r, c.g, c.b, 0.18))
			canvas.draw_polyline(oct + PackedVector2Array([oct[0]]), c, 2.4, true)
			canvas.draw_rect(Rect2(center - Vector2(radius * 0.3, radius * 0.3), Vector2(radius * 0.6, radius * 0.6)), Color(c.r, c.g, c.b, 0.8), false, 2.0)
			canvas.draw_line(center + Vector2(-radius, radius * 0.8), center + Vector2(radius, radius * 0.8), Color(c.r, c.g, c.b, 0.4), 2.0)
		"bloatware":
			var body := Rect2(center - Vector2(radius, radius * 0.78), Vector2(radius * 2.0, radius * 1.56))
			canvas.draw_rect(body, Color(c.r, c.g, c.b, 0.18))
			canvas.draw_rect(body, c, false, 3.0)
			canvas.draw_line(center + Vector2(-radius * 0.72, -radius * 0.22), center + Vector2(radius * 0.72, -radius * 0.22), Color(c.r, c.g, c.b, 0.7), 2.0)
			canvas.draw_line(center + Vector2(-radius * 0.72, radius * 0.24), center + Vector2(radius * 0.4, radius * 0.24), Color(c.r, c.g, c.b, 0.6), 2.0)
			var spin := t * 3.2
			for i in 8:
				var a := spin + TAU * i / 8.0
				var alpha := 0.18 + 0.72 * float(i + 1) / 8.0
				canvas.draw_line(center + Vector2.from_angle(a) * (radius * 0.72), center + Vector2.from_angle(a) * (radius * 0.93), Color(c.r, c.g, c.b, alpha), 3.0)
		"update_loop":
			var ring := Rect2(center - Vector2(radius * 0.72, radius * 0.72), Vector2(radius * 1.44, radius * 1.44))
			canvas.draw_arc(center, radius * 0.72, t * 2.0, t * 2.0 + TAU * 0.78, 20, c, 3.0, true)
			canvas.draw_arc(center, radius * 0.72, t * 2.0 + PI, t * 2.0 + PI + TAU * 0.78, 20, c, 3.0, true)
			canvas.draw_rect(ring, Color(c.r, c.g, c.b, 0.16))
			canvas.draw_rect(ring, c, false, 2.0)
			canvas.draw_circle(center, radius * 0.2, Color(1, 1, 1, 0.85))
		"zombie_process":
			var shell := PackedVector2Array([center + Vector2(-radius, -radius * 0.72), center + Vector2(radius * 0.8, -radius * 0.72), center + Vector2(radius, radius * 0.62), center + Vector2(-radius * 0.72, radius * 0.72)])
			canvas.draw_colored_polygon(shell, Color(c.r, c.g, c.b, 0.18))
			canvas.draw_polyline(shell + PackedVector2Array([shell[0]]), c, 2.4, true)
			canvas.draw_line(center + Vector2(-radius * 0.58, -radius * 0.2), center + Vector2(radius * 0.42, -radius * 0.2), c, 2.0, true)
			canvas.draw_line(center + Vector2(-radius * 0.58, radius * 0.18), center + Vector2(radius * 0.08, radius * 0.18), Color(c.r, c.g, c.b, 0.7), 2.0, true)
			canvas.draw_line(center + Vector2(radius * 0.42, radius * 0.08), center + Vector2(radius * 0.42, radius * 0.48), Color(1, 1, 1, 0.9), 2.0, true)
		"race_condition":
			var race_diamond := PackedVector2Array([center + Vector2(0, -radius * 1.05), center + Vector2(radius * 0.82, 0), center + Vector2(0, radius * 1.05), center + Vector2(-radius * 0.82, 0)])
			canvas.draw_colored_polygon(race_diamond, Color(c.r, c.g, c.b, 0.18))
			canvas.draw_polyline(race_diamond + PackedVector2Array([race_diamond[0]]), c, 2.2, true)
			canvas.draw_line(center + Vector2(-radius * 0.55, -radius * 0.24), center + Vector2(radius * 0.55, radius * 0.24), Color(c.r, c.g, c.b, 0.72), 1.8, true)
			canvas.draw_line(center + Vector2(-radius * 0.55, radius * 0.24), center + Vector2(radius * 0.55, -radius * 0.24), Color(c.r, c.g, c.b, 0.72), 1.8, true)
			canvas.draw_circle(center, radius * 0.2, Color(1, 1, 1, 0.86))
		"page":
			var page := PackedVector2Array([center + Vector2(-radius, -radius * 1.2), center + Vector2(radius * 0.8, -radius), center + Vector2(radius, radius * 1.2), center + Vector2(-radius * 0.8, radius)])
			canvas.draw_colored_polygon(page, Color(c.r, c.g, c.b, 0.18))
			canvas.draw_polyline(page + PackedVector2Array([page[0]]), c, 2.0, true)
			for i in 2:
				canvas.draw_line(center + Vector2(-radius * 0.5, -radius * 0.4 + i * radius * 0.6), center + Vector2(radius * 0.5, -radius * 0.4 + i * radius * 0.6), Color(c.r, c.g, c.b, 0.5), 1.5)
		"root":
			var segs := 6
			for i in segs:
				var a0 := t * 0.8 + TAU * i / segs
				canvas.draw_arc(center, radius, a0, a0 + TAU / segs * 0.62, 10, Color(c.r, c.g, c.b, 0.9), 5.0, true)
			var tri := PackedVector2Array()
			var spin2 := -t * 1.3
			for i in 3:
				tri.push_back(center + Vector2.from_angle(spin2 + TAU * i / 3.0) * radius * 0.62)
			canvas.draw_polyline(tri + PackedVector2Array([tri[0]]), Color(c.r, c.g, c.b, 0.75), 3.5, true)
			canvas.draw_circle(center, radius * 0.34, Color(c.r, c.g, c.b, 0.25))
			canvas.draw_arc(center, radius * 0.34, 0, TAU, 28, c, 2.6, true)
		"boss":
			draw_glyph(canvas, "root", center, radius, color, t)
		"segfault":
			for half in 2:
				var pts := PackedVector2Array()
				for i in 4:
					var a := TAU * (half * 3 + i) / 6.0 + t * 0.5
					pts.push_back(center + Vector2.from_angle(a) * radius + (Vector2(3.0, 0.0) if half == 0 else Vector2(-4.2, 0.0)))
				if pts.size() > 2:
					canvas.draw_polyline(pts, Color(c.r, c.g, c.b, 0.85 if half == 0 else 0.5), 4.0, true)
			canvas.draw_circle(center, radius * 0.3, Color(c.r, c.g, c.b, 0.3))
			canvas.draw_circle(center, radius * 0.14, c)
		"bluescreen":
			var rr := radius * 0.92
			var rect := Rect2(center - Vector2(rr, rr * 0.72), Vector2(rr * 2.0, rr * 1.44))
			canvas.draw_rect(rect, Color(c.r, c.g, c.b, 0.10))
			canvas.draw_rect(rect, Color(c.r, c.g, c.b, 0.9), false, 4.0)
			for i in 5:
				var ly: float = rect.position.y + rect.size.y * (0.15 + 0.18 * i) + sin(t * 3.0 + i) * 3.0
				canvas.draw_line(Vector2(rect.position.x + 10.0, ly), Vector2(rect.end.x - 10.0, ly), Color(c.r, c.g, c.b, 0.14), 1.5)
		"pagefault":
			for i in 3:
				var off := Vector2.from_angle(t * (0.6 + i * 0.25)) * radius * 0.12 * i
				canvas.draw_rect(Rect2(center + Vector2(-radius * 0.7, -radius * 0.5) + off, Vector2(radius * 1.4, radius)), Color(c.r, c.g, c.b, 0.10 + 0.06 * i), false, 2.0)
			canvas.draw_circle(center, radius * 0.3, Color(c.r, c.g, c.b, 0.3))
		"god":
			for i in 3:
				canvas.draw_arc(center, radius * (0.9 + i * 0.22), -t * (0.35 + i * 0.12), TAU - t * (0.35 + i * 0.12), 40, Color(c.r, c.g, c.b, 0.34 - i * 0.08), 2.0, true)
			canvas.draw_circle(center, radius * 0.7, Color(1.0, 0.78, 0.26, 0.22 + 0.08 * sin(t * 3.0)))
			canvas.draw_circle(center, radius * 0.38, Color(c.r, c.g, c.b, 0.22))
			canvas.draw_arc(center, radius * 0.38, 0.0, TAU, 32, c, 3.0, true)
			canvas.draw_circle(center, radius * 0.18, Color(1.0, 0.92, 0.62, 0.94))
			canvas.draw_circle(center, radius * 0.07, Color(1.0, 0.25, 0.35, 1.0))
		"kernel":
			_dart(canvas, center, radius, c, 1.5, 1.0, 0.45)
			var hex := PackedVector2Array()
			for i in 6:
				hex.push_back(center + Vector2.from_angle(TAU * i / 6.0) * radius * 0.34)
			canvas.draw_polyline(hex + PackedVector2Array([hex[0]]), c, 1.6, true)
			canvas.draw_circle(center + Vector2(radius * 0.25, 0), radius * 0.22, c)
		"daemon":
			_draw_daemon(canvas, center, radius, c, t)
		"rootlet":
			_draw_rootlet(canvas, center, radius, c, t)

static func _dart(canvas: CanvasItem, center: Vector2, radius: float, c: Color, nose: float, wing: float, tail: float) -> void:
	var pts := PackedVector2Array([
		center + Vector2(radius * nose, 0), center + Vector2(-radius, radius * wing),
		center + Vector2(-radius * tail, 0), center + Vector2(-radius, -radius * wing),
	])
	canvas.draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.22))
	canvas.draw_polyline(pts + PackedVector2Array([pts[0]]), c, 2.0, true)

static func _draw_drone(canvas: CanvasItem, center: Vector2, radius: float, c: Color, t: float) -> void:
	# The drone is a compact pursuit chassis: a forward sensor, a dense core,
	# two stabilizer fins and exhaust ticks. The silhouette remains legible
	# without glow or animation and is intentionally unlike the player dart.
	var chassis := PackedVector2Array([
		center + Vector2(radius * 1.30, 0.0),
		center + Vector2(radius * 0.48, -radius * 0.62),
		center + Vector2(-radius * 0.72, -radius * 0.48),
		center + Vector2(-radius * 0.98, 0.0),
		center + Vector2(-radius * 0.72, radius * 0.48),
		center + Vector2(radius * 0.48, radius * 0.62),
	])
	canvas.draw_colored_polygon(chassis, Color(c.r, c.g, c.b, 0.18))
	canvas.draw_polyline(chassis + PackedVector2Array([chassis[0]]), c, maxf(1.8, radius * 0.11), true)
	var sensor_center := center + Vector2(radius * 0.68, 0.0)
	canvas.draw_circle(sensor_center, radius * 0.28, Color(c.r, c.g, c.b, 0.12))
	canvas.draw_arc(sensor_center, radius * 0.28, -PI * 0.7, PI * 0.7, 12, c, maxf(1.2, radius * 0.07), true)
	canvas.draw_line(sensor_center - Vector2(radius * 0.18, 0.0), sensor_center + Vector2(radius * 0.18, 0.0), c, maxf(1.0, radius * 0.055), true)
	canvas.draw_line(sensor_center - Vector2(0.0, radius * 0.18), sensor_center + Vector2(0.0, radius * 0.18), c, maxf(1.0, radius * 0.055), true)
	var core := Rect2(center - Vector2(radius * 0.23, radius * 0.23), Vector2.ONE * radius * 0.46)
	canvas.draw_rect(core, Color(c.r, c.g, c.b, 0.18))
	canvas.draw_rect(core, Color(c.r, c.g, c.b, 0.82), false, maxf(1.0, radius * 0.07))
	canvas.draw_circle(center, radius * (0.09 + 0.025 * sin(t * 5.0)), c)
	for side in [-1.0, 1.0]:
		var fin := PackedVector2Array([
			center + Vector2(-radius * 0.18, side * radius * 0.32),
			center + Vector2(-radius * 0.64, side * radius * 0.92),
			center + Vector2(-radius * 0.52, side * radius * 0.20),
		])
		canvas.draw_polyline(fin, Color(c.r, c.g, c.b, 0.72), maxf(1.0, radius * 0.06), true)
	for index in 3:
		var length := radius * (0.16 + 0.08 * float(index))
		var alpha := 0.72 - float(index) * 0.16
		var y := (float(index) - 1.0) * radius * 0.18
		canvas.draw_line(center + Vector2(-radius * 1.02, y), center + Vector2(-radius * 1.02 - length, y), Color(c.r, c.g, c.b, alpha), maxf(1.0, radius * 0.05), true)

static func _draw_lancer(canvas: CanvasItem, center: Vector2, radius: float, c: Color, t: float) -> void:
	# A charge spear rather than a generic dart: the long forward lance is the
	# readable threat, while the split rear fins and charge ticks explain its
	# movement/attack role at small sizes.
	var body := PackedVector2Array([
		center + Vector2(radius * 1.22, 0.0),
		center + Vector2(-radius * 0.58, -radius * 0.72),
		center + Vector2(-radius * 0.38, 0.0),
		center + Vector2(-radius * 0.58, radius * 0.72),
	])
	canvas.draw_colored_polygon(body, Color(c.r, c.g, c.b, 0.16))
	canvas.draw_polyline(body + PackedVector2Array([body[0]]), c, maxf(1.8, radius * 0.1), true)
	canvas.draw_line(center + Vector2(radius * 0.42, 0.0), center + Vector2(radius * 2.4, 0.0), c, maxf(1.2, radius * 0.065), true)
	canvas.draw_line(center + Vector2(radius * 1.95, -radius * 0.08), center + Vector2(radius * 2.4, 0.0), Color(c.r, c.g, c.b, 0.62), maxf(1.0, radius * 0.045), true)
	canvas.draw_line(center + Vector2(radius * 1.95, radius * 0.08), center + Vector2(radius * 2.4, 0.0), Color(c.r, c.g, c.b, 0.62), maxf(1.0, radius * 0.045), true)
	var core := Rect2(center - Vector2(radius * 0.22, radius * 0.22), Vector2.ONE * radius * 0.44)
	canvas.draw_rect(core, Color(c.r, c.g, c.b, 0.26))
	canvas.draw_rect(core, c, false, maxf(1.0, radius * 0.06))
	for index in 3:
		var offset := (float(index) - 1.0) * radius * 0.22
		var phase_alpha := 0.38 + 0.22 * sin(t * 4.0 + index)
		canvas.draw_line(center + Vector2(-radius * 0.88, offset - radius * 0.08), center + Vector2(-radius * 0.88 - radius * 0.22, offset - radius * 0.08), Color(c.r, c.g, c.b, phase_alpha), maxf(1.0, radius * 0.045), true)

static func _draw_spewer(canvas: CanvasItem, center: Vector2, radius: float, c: Color, t: float) -> void:
	# The nozzle is the identity: a pressure pod with a directional mouth and
	# side vents. Its asymmetry makes the attack cone legible without particles.
	var pod := PackedVector2Array()
	for i in 6:
		pod.push_back(center + Vector2.from_angle(TAU * i / 6.0 + PI / 6.0) * radius * (0.94 + 0.04 * sin(t * 1.4)))
	canvas.draw_colored_polygon(pod, Color(c.r, c.g, c.b, 0.17))
	canvas.draw_polyline(pod + PackedVector2Array([pod[0]]), c, maxf(1.8, radius * 0.1), true)
	var mouth := PackedVector2Array([
		center + Vector2(radius * 0.18, -radius * 0.28),
		center + Vector2(radius * 1.14, 0.0),
		center + Vector2(radius * 0.18, radius * 0.28),
	])
	canvas.draw_colored_polygon(mouth, Color(c.r, c.g, c.b, 0.34))
	canvas.draw_polyline(mouth + PackedVector2Array([mouth[0]]), c, maxf(1.2, radius * 0.065), true)
	canvas.draw_circle(center + Vector2(-radius * 0.22, 0.0), radius * 0.21, c)
	for side in [-1.0, 1.0]:
		var vent := PackedVector2Array([
			center + Vector2(-radius * 0.32, side * radius * 0.46),
			center + Vector2(-radius * 0.78, side * radius * 0.72),
			center + Vector2(-radius * 0.56, side * radius * 0.28),
		])
		canvas.draw_polyline(vent, Color(c.r, c.g, c.b, 0.72), maxf(1.0, radius * 0.055), true)

static func _draw_daemon(canvas: CanvasItem, center: Vector2, radius: float, c: Color, t: float) -> void:
	# Daemon is a close-range claw: the forked tail and split front jaws are
	# deliberately more animal/menacing than the player's clean process dart.
	var body := PackedVector2Array([
		center + Vector2(radius * 1.28, 0.0),
		center + Vector2(radius * 0.35, -radius * 0.58),
		center + Vector2(-radius * 0.46, -radius * 0.42),
		center + Vector2(-radius * 0.88, 0.0),
		center + Vector2(-radius * 0.46, radius * 0.42),
		center + Vector2(radius * 0.35, radius * 0.58),
	])
	canvas.draw_colored_polygon(body, Color(c.r, c.g, c.b, 0.2))
	canvas.draw_polyline(body + PackedVector2Array([body[0]]), c, maxf(1.8, radius * 0.1), true)
	for side in [-1.0, 1.0]:
		var jaw := PackedVector2Array([
			center + Vector2(radius * 0.55, side * radius * 0.18),
			center + Vector2(radius * 1.42, side * radius * 0.64),
			center + Vector2(radius * 1.08, side * radius * 0.08),
		])
		canvas.draw_polyline(jaw, Color(c.r, c.g, c.b, 0.82), maxf(1.0, radius * 0.06), true)
	for side in [-1.0, 1.0]:
		canvas.draw_line(center + Vector2(-radius * 0.32, 0.0), center + Vector2(-radius * 1.16, side * radius * 0.74), Color(c.r, c.g, c.b, 0.76), maxf(1.0, radius * 0.07), true)
	canvas.draw_circle(center + Vector2(radius * 0.3, 0.0), radius * (0.18 + 0.03 * sin(t * 4.0)), c)

static func _draw_rootlet(canvas: CanvasItem, center: Vector2, radius: float, c: Color, _t: float) -> void:
	# Rootlet reads as a compact shielded kernel: broad barrier, inset process
	# core and two braces that remain visible behind the HUD-scale outline.
	var shield := PackedVector2Array([
		center + Vector2(0.0, -radius * 1.05),
		center + Vector2(radius * 0.82, -radius * 0.5),
		center + Vector2(radius * 0.82, radius * 0.22),
		center + Vector2(0.0, radius * 1.05),
		center + Vector2(-radius * 0.82, radius * 0.22),
		center + Vector2(-radius * 0.82, -radius * 0.5),
	])
	canvas.draw_colored_polygon(shield, Color(c.r, c.g, c.b, 0.22))
	canvas.draw_polyline(shield + PackedVector2Array([shield[0]]), c, maxf(1.8, radius * 0.1), true)
	var core := Rect2(center - Vector2(radius * 0.28, radius * 0.28), Vector2.ONE * radius * 0.56)
	canvas.draw_rect(core, Color(c.r, c.g, c.b, 0.16))
	canvas.draw_rect(core, Color(1.0, 1.0, 1.0, 0.76), false, maxf(1.0, radius * 0.05))
	canvas.draw_line(center + Vector2(-radius * 0.55, -radius * 0.36), center + Vector2(radius * 0.55, radius * 0.36), c, maxf(1.0, radius * 0.055), true)
	canvas.draw_line(center + Vector2(-radius * 0.55, radius * 0.36), center + Vector2(radius * 0.55, -radius * 0.36), c, maxf(1.0, radius * 0.055), true)
	canvas.draw_arc(center + Vector2(radius * 0.04, 0.0), radius * 0.72, -PI * 0.68, PI * 0.68, 18, Color(1.0, 1.0, 1.0, 0.7), maxf(1.0, radius * 0.06), true)

static func _horn(canvas: CanvasItem, base: Vector2, size: float, c: Color, mirrored: bool = false) -> void:
	var sign_x := -1.0 if mirrored else 1.0
	var pts := PackedVector2Array([base, base + Vector2(sign_x * size * 0.8, -size * 1.9), base + Vector2(sign_x * size * 0.1, -size * 0.55)])
	canvas.draw_colored_polygon(pts, c)

class_name GlyphLib
extends RefCounted

## Shared code-drawn silhouettes for enemies and playable programs.
## Pure canvas drawing: no state, no Game.rng, no node allocation.

static func glyph_kinds() -> Array:
	return ["drone", "lancer", "spewer", "splitter", "bulwark", "trojan", "oom", "recursor", "firewall", "bloatware", "update_loop", "page", "root", "boss", "segfault", "bluescreen", "pagefault", "god", "kernel", "daemon", "rootlet"]

## Maximum silhouette reach per kind, in multiples of the draw radius.
## Conservative outer bounds (lancer's lance tip reaches 2.4x, oom horns 1.6x,
## segfault jitter 1.45x); detail views use this to fit glyphs into fixed boxes.
const GLYPH_EXTENT := {
	"drone": 1.5, "lancer": 2.4, "spewer": 1.1, "splitter": 1.05, "bulwark": 1.05,
	"trojan": 1.25, "oom": 1.6, "recursor": 1.05, "firewall": 1.05, "bloatware": 1.05,
	"update_loop": 1.05, "page": 1.25, "root": 1.05, "boss": 1.05, "segfault": 1.45,
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
			_dart(canvas, center, radius, c, 1.15, 0.85, 0.25)
			canvas.draw_circle(center + Vector2(radius * 0.15, 0), radius * 0.3, c)
		"lancer":
			_dart(canvas, center, radius, c, 1.6, 0.7, 0.45)
			canvas.draw_line(center + Vector2(radius * 1.3, 0), center + Vector2(radius * 2.4, 0), Color(c.r, c.g, c.b, 0.5), 1.5)
		"spewer":
			var hex := PackedVector2Array()
			for i in 6:
				hex.push_back(center + Vector2.from_angle(TAU * i / 6.0 + t * 0.9) * radius)
			canvas.draw_colored_polygon(hex, Color(c.r, c.g, c.b, 0.2))
			canvas.draw_polyline(hex + PackedVector2Array([hex[0]]), c, 2.0, true)
			canvas.draw_circle(center, radius * 0.32, c)
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
			_dart(canvas, center, radius, c, 1.4, 1.05, 0.4)
			for side in [-1, 1]:
				var fork := PackedVector2Array([center + Vector2(-radius * 0.2, 0), center + Vector2(-radius * 0.9, side * radius * 0.7)])
				canvas.draw_polyline(fork, Color(c.r, c.g, c.b, 0.8), 2.0, true)
			canvas.draw_circle(center + Vector2(radius * 0.3, 0), radius * 0.24, c)
		"rootlet":
			var shield := PackedVector2Array([center + Vector2(0, -radius * 1.1), center + Vector2(radius * 0.85, -radius * 0.5), center + Vector2(radius * 0.85, radius * 0.2), center + Vector2(0, radius * 1.1), center + Vector2(-radius * 0.85, radius * 0.2), center + Vector2(-radius * 0.85, -radius * 0.5)])
			canvas.draw_colored_polygon(shield, Color(c.r, c.g, c.b, 0.25))
			canvas.draw_polyline(shield + PackedVector2Array([shield[0]]), c, 2.4, true)
			canvas.draw_arc(center, radius * 0.45, 0, TAU, 24, Color(1, 1, 1, 0.7), 1.6, true)

static func _dart(canvas: CanvasItem, center: Vector2, radius: float, c: Color, nose: float, wing: float, tail: float) -> void:
	var pts := PackedVector2Array([
		center + Vector2(radius * nose, 0), center + Vector2(-radius, radius * wing),
		center + Vector2(-radius * tail, 0), center + Vector2(-radius, -radius * wing),
	])
	canvas.draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.22))
	canvas.draw_polyline(pts + PackedVector2Array([pts[0]]), c, 2.0, true)

static func _horn(canvas: CanvasItem, base: Vector2, size: float, c: Color, mirrored: bool = false) -> void:
	var sign_x := -1.0 if mirrored else 1.0
	var pts := PackedVector2Array([base, base + Vector2(sign_x * size * 0.8, -size * 1.9), base + Vector2(sign_x * size * 0.1, -size * 0.55)])
	canvas.draw_colored_polygon(pts, c)

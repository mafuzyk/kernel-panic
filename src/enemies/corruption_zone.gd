class_name CorruptionZone
extends Node2D

var life := 4.5
var radius := 36.0
var hurt_cd := 0.0
var t := 0.0

func _ready() -> void:
	add_to_group("corruption")
	z_index = 3

func can_hurt() -> bool:
	return hurt_cd <= 0.0 and t > 0.25

func _physics_process(delta: float) -> void:
	t += delta
	life -= delta
	if hurt_cd > 0.0:
		hurt_cd -= delta
	if life <= 0.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var fade := clampf(minf(t * 3.0, life * 1.6), 0.0, 1.0)
	var pulse := 1.0 + 0.06 * sin(t * 5.0)
	var c := Color(0.55, 0.08, 0.2)
	var pts := PackedVector2Array()
	for i in 6:
		pts.push_back(Vector2.from_angle(TAU * i / 6.0 + t * 0.4) * radius * pulse)
	draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.16 * fade))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(c.r + 0.25, c.g, c.b + 0.1, 0.65 * fade), 1.8, true)
	draw_circle(Vector2.ZERO, radius * 0.3 * pulse, Color(0.8, 0.12, 0.25, 0.3 * fade))

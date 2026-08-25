class_name ArenaWalls
extends Node2D

var _pulse := 0.0
var tint := Color("4ff2ff")
var _tint_target := Color("4ff2ff")

func set_tint(c: Color) -> void:
	_tint_target = c

func pulse() -> void:
	_pulse = 1.0

func _process(delta: float) -> void:
	_pulse = maxf(_pulse - delta * 1.2, 0.0)
	tint = tint.lerp(_tint_target, 2.0 * delta)
	queue_redraw()

func _draw() -> void:
	var r := Balance.arena_rect()
	var c := tint.lerp(Balance.COL_PLAYER, 0.25 + _pulse * 0.5)
	c.a = 0.55 + _pulse * 0.45
	draw_rect(r, Color(0, 0, 0, 0), false)
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position])
	draw_polyline(pts, c, 2.0, true)
	var glow_c := tint
	glow_c.a = 0.08 + _pulse * 0.12
	draw_rect(r.grow(3.0), glow_c, false, 6.0)
	var corner := 26.0
	var cc := tint
	cc.a = 0.9
	var corners := [
		[r.position, Vector2(1, 1)],
		[Vector2(r.end.x, r.position.y), Vector2(-1, 1)],
		[r.end, Vector2(-1, -1)],
		[Vector2(r.position.x, r.end.y), Vector2(1, -1)]
	]
	for cn in corners:
		var p: Vector2 = cn[0]
		var d: Vector2 = cn[1]
		draw_line(p, p + Vector2(corner * d.x, 0), cc, 3.0)
		draw_line(p, p + Vector2(0, corner * d.y), cc, 3.0)
	var tick_c := Balance.COL_GRID
	tick_c.a = 0.8
	var n := 12
	for i in n:
		var t := float(i) / n
		var top := Vector2(lerpf(r.position.x, r.end.x, t), r.position.y)
		var bot := Vector2(lerpf(r.position.x, r.end.x, t), r.end.y)
		draw_line(top, top + Vector2(0, 6), tick_c, 1.0)
		draw_line(bot, bot - Vector2(0, 6), tick_c, 1.0)

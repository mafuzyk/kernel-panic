class_name ArenaWalls
extends Node2D

## Comprimento da marca de canto em L. Zero: elas saíram.
##
## Eram 26px por 3px de espessura sobre cada canto do retângulo da arena. A
## polilinha do retângulo já mostra o limite, então a marca não carregava
## informação — e como a câmera segue o jogador, o canto passeia pela tela e
## cai sobre o HUD. No capture de 2026-09-12 uma delas atravessa "DASH READY" e
## outra corta o placar. A constante fica como ponto de extensão e como o que a
## asserção mede.
const CORNER_MARK_LENGTH := 0.0

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
	if CORNER_MARK_LENGTH > 0.0:
		var cc := tint
		cc.a = 0.9
		for cn in [
			[r.position, Vector2(1, 1)],
			[Vector2(r.end.x, r.position.y), Vector2(-1, 1)],
			[r.end, Vector2(-1, -1)],
			[Vector2(r.position.x, r.end.y), Vector2(1, -1)]
		]:
			var p: Vector2 = cn[0]
			var d: Vector2 = cn[1]
			draw_line(p, p + Vector2(CORNER_MARK_LENGTH * d.x, 0), cc, 3.0)
			draw_line(p, p + Vector2(0, CORNER_MARK_LENGTH * d.y), cc, 3.0)
	var tick_c := Balance.COL_GRID
	tick_c.a = 0.8
	var n := 12
	for i in n:
		var t := float(i) / n
		var top := Vector2(lerpf(r.position.x, r.end.x, t), r.position.y)
		var bot := Vector2(lerpf(r.position.x, r.end.x, t), r.end.y)
		draw_line(top, top + Vector2(0, 6), tick_c, 1.0)
		draw_line(bot, bot - Vector2(0, 6), tick_c, 1.0)

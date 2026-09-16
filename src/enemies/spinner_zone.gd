class_name SpinnerZone
extends Node2D

## Roda de espera do BEACHBALL: um setor do campo onde o processo do jogador
## fica ESPERANDO.
##
## Não machuca — ao contrário da `CorruptionZone`, que é dano por contato. A
## piada e a ameaça são a mesma coisa: o jogador continua vivo, só não consegue
## sair a tempo. O perigo real é o que o resto da onda faz com ele parado.

const SLOW_REFRESH := 0.25

var life := 5.0
var radius := 78.0
var t := 0.0
var tint := Color("ff9ad2")

func _ready() -> void:
	add_to_group("spinner_zone")
	z_index = 3

## Verdadeiro quando o ponto está sob a roda. Puro, para o autotest medir sem
## precisar de um jogador vivo dentro da arena.
func covers(point: Vector2) -> bool:
	return global_position.distance_to(point) < radius

func _physics_process(delta: float) -> void:
	t += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	# Renovada a cada quadro enquanto o jogador estiver dentro: `apply_freeze`
	# usa `maxf`, então a lentidão dura 0.25s depois que ele sai — e não mais.
	for raw_player in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(raw_player) or not (raw_player is Node2D):
			continue
		var target: Node2D = raw_player
		if covers(target.global_position) and target.has_method("apply_freeze"):
			target.call("apply_freeze", SLOW_REFRESH)
	queue_redraw()

func _draw() -> void:
	var fade := clampf(minf(t * 3.0, life * 1.6), 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(tint.r, tint.g, tint.b, 0.10 * fade))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(tint.r, tint.g, tint.b, 0.42 * fade), 1.6, true)
	# A roda girando: doze raios com opacidade em rampa, o beach ball inteiro.
	for i in 12:
		var a := t * 2.6 + TAU * float(i) / 12.0
		var alpha := (0.12 + 0.70 * float(i + 1) / 12.0) * fade
		var hue := fmod(float(i) / 12.0, 1.0)
		var spoke := Color.from_hsv(hue, 0.62, 1.0)
		draw_line(Vector2.from_angle(a) * radius * 0.22, Vector2.from_angle(a) * radius * 0.54,
			Color(spoke.r, spoke.g, spoke.b, alpha), 4.0)

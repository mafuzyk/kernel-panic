class_name SwapEnemy
extends EnemyBase

## SWAP — a partição de troca.
##
## Gordo, lento e praticamente inofensivo no contato. O que ele faz é PUXAR: o
## jogador e os motes soltos são arrastados na direção dele enquanto estiverem
## no raio. Não tira integridade; tira controle.
##
## É o inimigo que muda a leitura da arena inteira sem disparar nada: com um
## SWAP em campo, recuar para a parede deixa de ser fuga e vira armadilha.

const PULL_RADIUS := 300.0
const PULL_STRENGTH := 190.0

var _v := Vector2.ZERO
var _pull_pulse := 0.0

func _init() -> void:
	display_name = "SWAP"
	hp = 16
	speed = 42.0
	pts = 320
	radius = 28.0
	col = Color("5f7fd8")
	mote_count = 5

## Aceleração aplicada a um corpo em `point`, já com a queda pela distância.
## Pura: o autotest mede a curva sem montar uma arena.
func pull_at(point: Vector2) -> Vector2:
	var to_well := global_position - point
	var distance := to_well.length()
	if distance <= 0.01 or distance >= PULL_RADIUS:
		return Vector2.ZERO
	# Queda linear: forte perto, some na borda do raio. Um inverso do quadrado
	# faria o poço colar o jogador no centro e tirar o jogo dele.
	var falloff := 1.0 - distance / PULL_RADIUS
	return to_well / distance * PULL_STRENGTH * falloff

func _move(delta: float) -> void:
	var desired := steer_approach(aim_at_player(), flank_sign, flank_weight * 0.6)
	desired += steer_separation(2.4) * 0.8
	_v = _v.move_toward(desired.limit_length(1.0) * speed, 160.0 * delta)
	_pull_pulse += delta
	_apply_pull(delta)

func _apply_pull(delta: float) -> void:
	for raw_player in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(raw_player) or not (raw_player is Node2D):
			continue
		var target: Node2D = raw_player
		# Dash é a saída: quem está no dash ignora o poço, e é isso que torna o
		# SWAP um problema de recurso e não um castigo.
		if bool(target.get("dash_t")) and float(target.get("dash_t")) > 0.0:
			continue
		target.global_position += pull_at(target.global_position) * delta
	var field: Node = get_tree().get_first_node_in_group("mote_field")
	if field != null and is_instance_valid(field) and field.has_method("attract_toward"):
		field.call("attract_toward", global_position, PULL_RADIUS, PULL_STRENGTH * 0.5, delta)

func vel() -> Vector2:
	return _v

func _draw() -> void:
	var c := _flash_col(col)
	GlyphLib.draw_glyph(self, "swap", Vector2.ZERO, radius, _glyph_color(c), t)
	# O raio do poço é desenhado: o jogador precisa saber onde começa a puxar.
	var breathe := 1.0 + 0.03 * sin(_pull_pulse * 2.2)
	draw_arc(Vector2.ZERO, PULL_RADIUS * breathe, 0.0, TAU, 56, Color(c.r, c.g, c.b, 0.16), 1.4, true)
	for i in 4:
		var a := -_pull_pulse * 1.1 + TAU * float(i) / 4.0
		var reach := PULL_RADIUS * breathe
		var inner := radius + 10.0
		var span := fmod(_pull_pulse * 0.6 + float(i) * 0.25, 1.0)
		var head := lerpf(reach, inner, span)
		draw_line(Vector2.from_angle(a) * head, Vector2.from_angle(a) * minf(head + 26.0, reach),
			Color(c.r, c.g, c.b, 0.42 * (1.0 - span)), 2.0)
	if elite:
		draw_arc(Vector2.ZERO, radius + 5.0, 0, TAU, 24, Color(1, 1, 1, 0.75), 1.6, true)

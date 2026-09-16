class_name GeniusEnemy
extends LancerEnemy

## GENIUS — o lancer que acha que sabe melhor.
##
## Mesmo ciclo do LANCER, com um passo a mais: no fim do telegrafo, se o
## jogador já saiu da linha, ele PISCA para um ângulo melhor e recomeça a mira
## em vez de errar. O tell continua sendo a linha vermelha; o que muda é que
## desviar cedo demais não resolve — tem que desviar no tempo certo.
##
## O blink tem teto por investida: sem ele um jogador que circula ficaria preso
## num lancer que nunca dispara.

const BLINK_RANGE := 150.0
const BLINK_MAX_PER_LUNGE := 1
const AIM_TOLERANCE := 0.965

var _blinks_used := 0

func _init() -> void:
	display_name = "GENIUS"
	hp = 3
	speed = 110.0
	pts = 160
	radius = 13.0
	col = Color("d8dee9")

func telegraph_duration() -> float:
	return 0.72

## Verdadeiro quando o jogador já saiu da linha que o GENIUS carregou.
## Pura: o autotest mede a regra sem precisar do ciclo inteiro.
func aim_has_drifted(aim_dir: Vector2, target_dir: Vector2) -> bool:
	if aim_dir.length_squared() <= 0.0001 or target_dir.length_squared() <= 0.0001:
		return false
	return aim_dir.normalized().dot(target_dir.normalized()) < AIM_TOLERANCE

func can_blink() -> bool:
	return _blinks_used < BLINK_MAX_PER_LUNGE

## Destino do blink: um ponto atrás do jogador, do lado do flanco, dentro da
## arena. "Deixa que eu corrijo isso pra você."
func blink_destination() -> Vector2:
	if player == null or not is_instance_valid(player):
		return global_position
	var target := predict_player_position(telegraph_duration())
	var away := (global_position - target)
	if away.length_squared() <= 0.0001:
		away = Vector2.RIGHT
	var offset := away.normalized().rotated(flank_sign * PI * 0.45) * BLINK_RANGE
	var bounds := Balance.arena_rect().grow(-radius - 6.0)
	var destination := target + offset
	return Vector2(
		clampf(destination.x, bounds.position.x, bounds.end.x),
		clampf(destination.y, bounds.position.y, bounds.end.y))

func _move(delta: float) -> void:
	var before := phase
	if phase == Phase.AIM and phase_t <= delta and can_blink() \
			and aim_has_drifted(_aim, aim_at_player()):
		_blink()
		return
	super._move(delta)
	if before != Phase.APPROACH and phase == Phase.APPROACH:
		_blinks_used = 0

func _blink() -> void:
	_blinks_used += 1
	var origin := global_position
	var destination := blink_destination()
	Fx.ring(origin, col, radius, radius + 40.0, 0.26, 2.2)
	Fx.ghost(origin, rotation, _ghost_draw, col, 0.3, scale.x)
	global_position = destination
	_v = Vector2.ZERO
	_aim = aim_predicted(telegraph_duration())
	phase_t = telegraph_duration() * 0.55
	Fx.ring(destination, col, radius + 40.0, radius, 0.26, 2.2, true)
	Sfx.play("dash", 1.35, -10.0)

func _draw() -> void:
	var c := _flash_col(col)
	GlyphLib.draw_glyph(self, "genius", Vector2.ZERO, radius, _glyph_color(c), t)
	if phase == Phase.AIM:
		var a := 0.35 + 0.4 * absf(sin(t * 30.0))
		draw_line(Vector2.ZERO, Vector2(560.0, 0), Color(c.r, c.g, c.b, a), 1.6)
		draw_line(Vector2.ZERO, Vector2(560.0, 0), Color(1, 1, 1, a * 0.4), 1.0)
	if elite:
		draw_arc(Vector2.ZERO, radius + 5.0, 0, TAU, 24, Color(1, 1, 1, 0.75), 1.6, true)

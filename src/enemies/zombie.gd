class_name ZombieEnemy
extends EnemyBase

## ZOMBIE — o processo defunto.
##
## Matá-lo não o remove: ele vira uma casca `<defunct>` que continua andando,
## mais lenta e sem cor, por uma janela curta. Um segundo tiro nessa janela o
## COLHE de vez; deixar a janela fechar o traz de volta com metade da
## integridade.
##
## É o oposto do UPDATE_LOOP, que ressuscita sozinho uma vez e não dá escolha:
## aqui a decisão é do jogador, e custa munição e atenção num momento em que ele
## normalmente já virou as costas.

const REAP_WINDOW := 3.2
const REVIVE_FRACTION := 0.5

var defunct := false
var reap_t := 0.0
var _v := Vector2.ZERO
var _revivals := 0

func _init() -> void:
	display_name = "ZOMBIE"
	hp = 4
	speed = 96.0
	pts = 150
	radius = 14.0
	col = Color("7bd88f")
	mote_count = 2

## Integridade com que ele volta se ninguém o colher.
func revive_hp() -> int:
	return maxi(1, int(ceil(float(max_hp) * REVIVE_FRACTION)))

func _move(delta: float) -> void:
	var desired := steer_approach(aim_at_player(), cutoff_sign(), flank_weight)
	desired += steer_separation(2.2) * 0.7
	var target_speed := speed * (0.55 if defunct else 1.0)
	_v = _v.move_toward(desired.limit_length(1.0) * target_speed, 420.0 * delta)
	if not defunct:
		return
	reap_t -= delta
	if reap_t <= 0.0:
		_revive()

## A morte de um zumbi é condicional. Só a segunda vale.
func die() -> void:
	if dead:
		return
	if defunct:
		super.die()
		return
	defunct = true
	reap_t = REAP_WINDOW
	hp = 1
	Game.log_event("zombie: process <defunct> // reap it or it returns")
	Fx.ring(global_position, col, radius, radius + 34.0, 0.32, 2.2)
	Fx.text(global_position + Vector2(0, -radius - 14.0), "<defunct>", col, 12)
	Sfx.play("hit", 0.5, -8.0)

func _revive() -> void:
	defunct = false
	_revivals += 1
	hp = revive_hp()
	max_hp = maxi(max_hp, hp)
	Fx.ring(global_position, col, radius + 40.0, radius, 0.34, 2.6, true)
	Fx.text(global_position + Vector2(0, -radius - 14.0), "REAPED? NO", col, 12)
	Sfx.play("ready", 0.7, -8.0)

func revivals() -> int:
	return _revivals

func vel() -> Vector2:
	return _v

func _draw() -> void:
	var c := _flash_col(col)
	if defunct:
		# A casca perde o preenchimento: o que sobra é contorno piscando, e o
		# anel que fecha marca quanto tempo resta para colher.
		var blink := 0.45 + 0.4 * absf(sin(t * 9.0))
		GlyphLib.draw_glyph(self, "zombie", Vector2.ZERO, radius, Color(c.r, c.g, c.b, blink), t)
		var left := clampf(reap_t / REAP_WINDOW, 0.0, 1.0)
		draw_arc(Vector2.ZERO, radius + 7.0, -PI * 0.5, -PI * 0.5 + TAU * left, 30, Color(1, 1, 1, 0.75), 2.2, true)
		return
	GlyphLib.draw_glyph(self, "zombie", Vector2.ZERO, radius, _glyph_color(c), t)
	if elite:
		draw_arc(Vector2.ZERO, radius + 5.0, 0, TAU, 24, Color(1, 1, 1, 0.75), 1.6, true)

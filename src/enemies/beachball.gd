class_name BeachballEnemy
extends EnemyBase

## BEACHBALL — a roda de espera do macOS.
##
## Não persegue para bater: persegue para PLANTAR. Circula o jogador na faixa
## média e, quando pega vaga de ataque, deixa uma `SpinnerZone` sob ele. Sozinho
## é inofensivo; o que mata é o resto da onda alcançando um jogador lento.

enum Phase { ORBIT, WIND, PLANT }

const BAND_MIN := 150.0
const BAND_MAX := 260.0
const WIND_DURATION := 0.55
const ZONE_CAP := 3

var phase: int = Phase.ORBIT
var phase_t := 0.0
var _v := Vector2.ZERO
var _spin := 0.0

func _init() -> void:
	display_name = "BEACHBALL"
	hp = 6
	speed = 118.0
	pts = 170
	radius = 18.0
	col = Color("ff9ad2")
	mote_count = 3

func _on_ready() -> void:
	phase_t = Game.rng.randf_range(1.0, 2.0)
	_spin = Game.rng.randf() * TAU

func telegraph_duration() -> float:
	return WIND_DURATION

func plant_interval() -> float:
	return maxf(2.6 * Balance.difficulty_cadence(threat_wave), 1.4)

## Teto de rodas simultâneas DESTE inimigo mais os irmãos: sem ele três
## beachballs cobriam a arena inteira e o jogador nunca voltava à velocidade.
func zones_at_cap() -> bool:
	return get_tree().get_nodes_in_group("spinner_zone").size() >= ZONE_CAP

func _move(delta: float) -> void:
	phase_t -= delta
	var to_player := player.global_position - global_position if is_instance_valid(player) else Vector2.ZERO
	match phase:
		Phase.ORBIT:
			var desired := steer_distance_band(to_player, BAND_MIN, BAND_MAX, flank_sign, 0.95)
			desired += steer_separation(2.2) * 0.7
			_v = _v.move_toward(desired.limit_length(1.0) * speed, 380.0 * delta)
			if phase_t <= 0.0 and dist_to_player() < BAND_MAX + 60.0 and not zones_at_cap() \
					and claim_attack_slot(WIND_DURATION + 0.3):
				phase = Phase.WIND
				phase_t = WIND_DURATION
				Sfx.play("charge", 0.7, -12.0)
			elif phase_t <= 0.0:
				phase_t = 0.4
		Phase.WIND:
			# Vai para cima do jogador enquanto carrega: o alvo da roda é onde
			# ele ESTARÁ, não onde ele estava quando o giro começou.
			var lunge := (predict_player_position(phase_t) - global_position)
			_v = _v.move_toward(lunge.limit_length(1.0).normalized() * speed * 1.6, 620.0 * delta)
			if phase_t <= 0.0:
				_plant_zone()
				phase = Phase.PLANT
				phase_t = 0.5
		Phase.PLANT:
			_v = _v.move_toward(Vector2.ZERO, 500.0 * delta)
			if phase_t <= 0.0:
				release_attack_slot()
				phase = Phase.ORBIT
				phase_t = plant_interval()

func _plant_zone() -> void:
	if zones_at_cap():
		return
	var zone := SpinnerZone.new()
	zone.position = position
	zone.tint = col
	get_parent().call_deferred("add_child", zone)
	Fx.ring(global_position, col, radius, 88.0, 0.4, 3.0)
	Sfx.play("hit", 0.4, -10.0, 0.1)

func vel() -> Vector2:
	return _v

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_spin += delta * (7.0 if phase == Phase.WIND else 2.4)

func _draw() -> void:
	var c := _flash_col(col)
	GlyphLib.draw_glyph(self, "beachball", Vector2.ZERO, radius, _glyph_color(c), _spin)
	if phase == Phase.WIND:
		var charge := 1.0 - clampf(phase_t / WIND_DURATION, 0.0, 1.0)
		draw_arc(Vector2.ZERO, radius + 8.0 + 6.0 * charge, 0.0, TAU * charge, 32, Color(c.r, c.g, c.b, 0.8), 2.4, true)
	if elite:
		draw_arc(Vector2.ZERO, radius + 5.0, 0, TAU, 24, Color(1, 1, 1, 0.75), 1.6, true)

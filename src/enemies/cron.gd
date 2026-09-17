class_name CronEnemy
extends EnemyBase

## CRON — a tabela de agendamento.
##
## Não ataca. Fica na borda, longe, e a cada intervalo FIXO e telegrafado
## dispara dois drones. O relógio é visível no corpo, então o jogador sabe
## exatamente quanto tempo tem.
##
## O que ele cria é pressão de PRIORIDADE: enquanto ele vive a onda não acaba,
## mas ir atrás dele significa atravessar o que ele já agendou.

const PERIOD := 6.0
const SPAWN_COUNT := 2
const KEEP_DISTANCE := 380.0

var tick_t := PERIOD
var _v := Vector2.ZERO
var _jobs_run := 0

func _init() -> void:
	display_name = "CRON"
	hp = 7
	speed = 70.0
	pts = 200
	radius = 15.0
	# Lima, não verde: o ZOMBIE já é verde e os dois nasceram vizinhos demais.
	col = Color("66ffb2")
	mote_count = 3

func _on_ready() -> void:
	tick_t = PERIOD

func period() -> float:
	return maxf(PERIOD * Balance.difficulty_cadence(threat_wave), 3.5)

func jobs_run() -> int:
	return _jobs_run

## Fração já decorrida do intervalo. O corpo desenha isto: o relógio é o tell.
func schedule_fraction() -> float:
	return clampf(1.0 - tick_t / maxf(period(), 0.001), 0.0, 1.0)

func _move(delta: float) -> void:
	var to_player := player.global_position - global_position if is_instance_valid(player) else Vector2.ZERO
	# Mantém distância e procura espaço: ele quer ser chato de alcançar, não
	# perigoso de encostar.
	var desired := steer_distance_band(to_player, KEEP_DISTANCE, KEEP_DISTANCE + 120.0, flank_sign, 0.7)
	desired += steer_separation(2.4) * 0.8
	desired += steer_open_space(to_player, KEEP_DISTANCE, flank_sign) * 0.9
	_v = _v.move_toward(desired.limit_length(1.0) * speed, 300.0 * delta)
	tick_t -= delta
	if tick_t <= 0.0:
		tick_t = period()
		_run_job()

func _run_job() -> void:
	if not is_inside_tree() or get_parent() == null:
		return
	# Nunca agenda para dentro de um campo já cheio: a agenda é pressão, não
	# um gerador de travamento.
	if EnemyBase.shared_list.size() >= Balance.difficulty_max_alive(threat_wave):
		Game.log_event("cron: job skipped // table full")
		return
	_jobs_run += 1
	for index in SPAWN_COUNT:
		var child := DroneEnemy.new()
		child.setup_mini()
		child.threat_wave = threat_wave
		child.position = position + Vector2.from_angle(TAU * float(index) / float(SPAWN_COUNT) + t) * (radius + 26.0)
		get_parent().call_deferred("add_child", child)
	Fx.ring(global_position, col, radius, radius + 60.0, 0.4, 2.6)
	Game.log_event("cron: */%d job fired // 2 processes spawned" % int(period()))
	Sfx.play("wave", 0.8, -12.0)

func die() -> void:
	if dead:
		return
	Game.log_event("cron: crontab removed // schedule cancelled")
	super.die()

func vel() -> Vector2:
	return _v

func _draw() -> void:
	var c := _flash_col(col)
	GlyphLib.draw_glyph(self, "cron", Vector2.ZERO, radius, _glyph_color(c), t)
	# O ponteiro: fecha a volta e o job dispara. Vermelho no último quarto.
	var progress := schedule_fraction()
	var hand := Color(c.r, c.g, c.b, 0.85) if progress < 0.75 else Balance.COL_DANGER
	draw_arc(Vector2.ZERO, radius + 7.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 32, hand, 2.6, true)
	if elite:
		draw_arc(Vector2.ZERO, radius + 5.0, 0, TAU, 24, Color(1, 1, 1, 0.75), 1.6, true)

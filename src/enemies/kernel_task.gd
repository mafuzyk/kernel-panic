class_name KernelTaskBoss
extends RootBoss

## KERNEL_TASK — o pânico literal do macOS.
##
## O boss do ato é a própria tela de erro. Ele alterna dois estados:
##
## REPORT: a máquina "está bem". Ele circula e cospe linhas de stack trace —
##   salvas de orbes em linha reta, retas como as linhas de um dump.
##
## PANIC: a tela reinicia. Ele INVERTE a paleta do campo por alguns segundos e
##   dispara um dump em leque enquanto o jogador está lendo um fundo trocado.
##   A inversão é o ataque: nada machuca sozinho, mas a leitura da arena muda no
##   meio de uma esquiva.
##
## A inversão respeita a mesma regra de legibilidade das fases: ela troca o
## MATIZ do campo, nunca acende a luz dele.

enum Mode { REPORT, PANIC }

const PANIC_DURATION := 3.4
const REPORT_DURATION := 6.0
const TRACE_LINES := 5

var mode: int = Mode.REPORT
var mode_t := REPORT_DURATION
var trace_cd := 1.4
var panics_triggered := 0

func _init() -> void:
	display_name = "KERNEL_TASK"
	hp = 190
	speed = 52.0
	pts = 6000
	radius = 54.0
	col = Color("cfd6e4")
	mote_count = 36

func configure(wave_scale_f: float, _is_elite: bool) -> void:
	boss_index = 1
	hp = int(ceil(190.0 * wave_scale_f))
	max_hp = hp
	speed = 52.0
	pts = 6000
	radius = 54.0
	boss_title = "KERNEL_TASK"
	boss_quote = "YOU NEED TO RESTART YOUR COMPUTER"
	col = Color("cfd6e4")
	mote_count = 36

func in_panic() -> bool:
	return mode == Mode.PANIC

## Cadência do dump, mais apertada conforme ele perde integridade.
func trace_interval_for_phase(target_phase: int) -> float:
	match clampi(target_phase, 1, 3):
		1:
			return 1.45
		2:
			return 1.15
		_:
			return 0.90

func _move(delta: float) -> void:
	var to_player := player.global_position - global_position if player != null and is_instance_valid(player) else Vector2.ZERO
	var band_sign := -1.0 if in_panic() else 1.0
	var desired := steer_distance_band(to_player, 200.0, 340.0, band_sign, 0.70)
	desired += steer_separation(2.4) * 0.7
	_v = _v.move_toward(desired.limit_length(1.0) * speed * (1.4 if in_panic() else 1.0), 260.0 * delta)
	var frac := float(hp) / float(max_hp) if max_hp > 0 else 0.0
	phase = 3 if frac < 0.33 else (2 if frac < 0.66 else 1)
	mode_t -= delta
	if mode_t <= 0.0:
		_flip_mode()
	trace_cd -= delta
	if trace_cd <= 0.0:
		trace_cd = trace_interval_for_phase(phase) * (0.6 if in_panic() else 1.0)
		_dump_trace()

func _flip_mode() -> void:
	if in_panic():
		mode = Mode.REPORT
		mode_t = maxf(REPORT_DURATION - float(phase) * 0.8, 3.0)
		_set_field_inverted(false)
		return
	mode = Mode.PANIC
	mode_t = PANIC_DURATION
	panics_triggered += 1
	_set_field_inverted(true)
	Game.log_event("panic: kernel_task // you need to restart your computer")
	Fx.ring(global_position, col, radius, radius + 160.0, 0.5, 4.0, true)
	Fx.text(global_position + Vector2(0, -radius - 24.0), "KERNEL PANIC", Balance.COL_DANGER, 14)
	Sfx.play("boss", 0.7, -4.0)

## Pede à arena que troque o matiz do campo. A arena é quem sabe o tema da
## fase; o boss só diz QUANDO. Silencioso fora do story, onde não há tema.
func _set_field_inverted(inverted: bool) -> void:
	var arena: Node = get_tree().get_first_node_in_group("arena")
	if arena != null and is_instance_valid(arena) and arena.has_method("set_field_inverted"):
		arena.call("set_field_inverted", inverted)

## Um dump é uma LINHA de orbes, não um leque: linhas retas lidas de cima para
## baixo, como as do trace que ele imprime.
func _dump_trace() -> void:
	var base_dir := aim_predicted(0.45)
	var spread: float = PI * (0.34 if in_panic() else 0.16)
	for index in TRACE_LINES:
		var offset := lerpf(-spread, spread, float(index) / float(maxi(TRACE_LINES - 1, 1)))
		_spawn_orb(base_dir.rotated(offset), 250.0 if in_panic() else 205.0)
	Fx.sparks(global_position + base_dir * radius, col, 6, 130.0, 0.3, 2.4)
	Sfx.play("shoot", 0.5, -6.0)

func take_hit(dmg: int, from: Vector2) -> void:
	if dead:
		return
	hp -= dmg
	hit_flash = 1.0
	kb += (global_position - from).normalized() * 18.0
	Sfx.play("hit", 1.0, -6.0)
	if hp <= 0:
		die()
	boss_hp_changed.emit(float(maxi(hp, 0)) / float(maxi(max_hp, 1)))

## O campo tem de voltar ao normal mesmo se ele morrer no meio de um panic.
func die() -> void:
	if dead:
		return
	_set_field_inverted(false)
	super.die()

func vel() -> Vector2:
	return _v

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _v.length_squared() > 0.01:
		rotation = lerp_angle(rotation, _v.angle(), 2.4 * delta)

func _draw() -> void:
	var c := _flash_col(Balance.COL_DANGER if in_panic() else col)
	GlyphLib.draw_glyph(self, "kernel_task", Vector2.ZERO, radius, _glyph_color(c), t)
	var hp_frac := float(maxi(hp, 0)) / float(maxi(max_hp, 1))
	draw_arc(Vector2.ZERO, radius + 10.0, -PI / 2.0, -PI / 2.0 + TAU * hp_frac, 48, c, 2.8, true)
	if in_panic():
		var pulse := 0.4 + 0.35 * absf(sin(t * 7.0))
		draw_arc(Vector2.ZERO, radius + 18.0, 0.0, TAU, 40, Color(1.0, 0.2, 0.32, pulse), 2.0, true)

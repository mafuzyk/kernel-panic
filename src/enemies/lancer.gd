class_name LancerEnemy
extends EnemyBase

enum Phase { APPROACH, AIM, LUNGE, RECOVER }

var phase: int = Phase.APPROACH
var phase_t := 0.0
var _v := Vector2.ZERO
var _aim := Vector2.RIGHT
var _ghost_cd := 0.0

func _init() -> void:
	display_name = "LANCER"
	hp = 2
	speed = 95.0
	pts = 90
	radius = 12.0
	col = Balance.COL_LANCER

func _on_ready() -> void:
	phase_t = Game.rng.randf_range(0.6, 1.1)

func _move(delta: float) -> void:
	phase_t -= delta
	match phase:
		Phase.APPROACH:
			var desired := elite_steering(aim_at_player(), 1.0)
			desired += steer_separation(2.2) * 0.7
			_v = _v.move_toward(desired.limit_length(1.0) * speed, 500.0 * delta)
			if phase_t <= 0.0 and dist_to_player() < 520.0:
				phase = Phase.AIM
				phase_t = 0.6
				Sfx.play("charge", 1.4, -10.0)
		Phase.AIM:
			_v = _v.move_toward(Vector2.ZERO, 900.0 * delta)
			_aim = aim_at_player()
			if phase_t <= 0.0:
				phase = Phase.LUNGE
				phase_t = 0.28
				_v = _aim * 780.0
				Sfx.play("dash", 0.8, -8.0)
		Phase.LUNGE:
			_ghost_cd -= delta
			if _ghost_cd <= 0.0:
				_ghost_cd = 0.04
				Fx.ghost(global_position, 0.0, _ghost_draw, col, 0.22, scale.x)
			if phase_t <= 0.0:
				phase = Phase.RECOVER
				phase_t = 0.85
		Phase.RECOVER:
			var desired := elite_steering(aim_at_player(), 1.0)
			desired += steer_separation(2.2) * 0.7
			_v = _v.move_toward(desired.limit_length(1.0) * speed * 0.4, 400.0 * delta)
			if phase_t <= 0.0:
				phase = Phase.APPROACH
				phase_t = phase_reentry_interval(Game.rng.randf_range(0.5, 0.9))

func phase_reentry_interval(base_interval: float) -> float:
	return elite_reacquire_interval(base_interval)

func telegraph_duration() -> float:
	return 0.6

func presentation_state() -> String:
	if hit_flash > 0.0:
		return "hit"
	if phase == Phase.AIM or phase == Phase.LUNGE:
		return "attack"
	return "elite" if elite else "idle"

func presentation_facing() -> Vector2:
	if phase == Phase.AIM or phase == Phase.LUNGE:
		return _aim.normalized() if _aim.length_squared() > 0.0001 else super.presentation_facing()
	return super.presentation_facing()

func _ghost_draw(node: Node2D, c: Color) -> void:
	var r := radius
	var pts := PackedVector2Array([
		Vector2(r * 1.6, 0), Vector2(-r, r * 0.7), Vector2(-r * 0.45, 0), Vector2(-r, -r * 0.7)
	])
	node.draw_colored_polygon(pts, c)

func vel() -> Vector2:
	return _v

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	rotation = _v.angle() if _v.length() > 20.0 else aim_at_player().angle()

func _draw() -> void:
	var c := _flash_col(col)
	var r := radius
	VNextEntityRenderer.draw_enemy(self, presentation_snapshot(), r, t, _glyph_color(c))
	if phase == Phase.AIM:
		var a := 0.35 + 0.4 * absf(sin(t * 30.0))
		draw_line(Vector2.ZERO, Vector2(560.0, 0), Color(c.r, c.g, c.b, a), 1.6)
		draw_line(Vector2.ZERO, Vector2(560.0, 0), Color(1, 1, 1, a * 0.4), 1.0)
	if elite:
		draw_arc(Vector2.ZERO, r + 5.0, 0, TAU, 24, Color(1, 1, 1, 0.75), 1.6, true)

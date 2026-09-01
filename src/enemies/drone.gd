class_name DroneEnemy
extends EnemyBase

var mini := false
var _wob := 0.0
var _v := Vector2.ZERO

func _init() -> void:
	display_name = "DRONE"
	hp = 2
	speed = 125.0
	pts = 50
	radius = 13.0
	col = Balance.COL_DRONE

func setup_mini() -> void:
	mini = true
	hp = 1
	speed = 205.0
	pts = 30
	radius = 9.0

func configure(wave_scale_f: float, is_elite: bool) -> void:
	super.configure(wave_scale_f, is_elite)
	if mini:
		max_hp = hp

func _on_ready() -> void:
	_wob = Game.rng.randf() * TAU
	if mini:
		col = Color("ff7ba4")
		glow.self_modulate = col

func _move(delta: float) -> void:
	_wob += delta * 5.0
	var desired := steer_approach(aim_at_player(), 1.0, 0.35)
	desired += steer_separation(2.2) * 0.7
	_v = _v.move_toward(desired.limit_length(1.0) * speed, 620.0 * delta)

func vel() -> Vector2:
	return _v

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _v.length() > 20.0:
		rotation = lerp_angle(rotation, _v.angle(), 9.0 * delta)

func _draw() -> void:
	var c := _flash_col(col)
	var r := radius
	VNextEntityRenderer.draw_enemy(self, presentation_snapshot(), r, t, _glyph_color(c))
	if elite and elite_kind == "volatile":
		var pulse := 0.5 + 0.5 * absf(sin(t * 8.0))
		draw_circle(Vector2(r * 0.15, 0), r * (0.42 + 0.2 * pulse), Color(1.0, 0.6, 0.1, 0.5 + 0.5 * pulse))
	if elite:
		draw_arc(Vector2.ZERO, r + 5.0, 0, TAU, 24, Color(1, 1, 1, 0.75), 1.6, true)

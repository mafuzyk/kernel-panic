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
	var dir := aim_at_player()
	var side := dir.orthogonal() * sin(_wob) * 0.45
	var target := (dir + side).normalized() * speed
	_v = _v.move_toward(target, 620.0 * delta)

func vel() -> Vector2:
	return _v

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _v.length() > 20.0:
		rotation = lerp_angle(rotation, _v.angle(), 9.0 * delta)

func _draw() -> void:
	var c := _flash_col(col)
	var r := radius
	var pts := PackedVector2Array([
		Vector2(r * 1.15, 0), Vector2(-r * 0.7, r * 0.85), Vector2(-r * 0.25, 0), Vector2(-r * 0.7, -r * 0.85)
	])
	draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.22))
	draw_polyline(pts + PackedVector2Array([pts[0]]), c, 2.0, true)
	draw_circle(Vector2(r * 0.15, 0), r * 0.3, c)
	if elite and elite_kind == "volatile":
		var pulse := 0.5 + 0.5 * absf(sin(t * 8.0))
		draw_circle(Vector2(r * 0.15, 0), r * (0.42 + 0.2 * pulse), Color(1.0, 0.6, 0.1, 0.5 + 0.5 * pulse))
	if elite:
		draw_arc(Vector2.ZERO, r + 5.0, 0, TAU, 24, Color(1, 1, 1, 0.75), 1.6, true)

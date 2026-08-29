class_name SpewerEnemy
extends EnemyBase

var _v := Vector2.ZERO
var _strafe_dir := 1.0
var _fire_t := 0.0
var _telegraph := 0.0
var _orbit_flip_t := 0.0

const BAND_MIN := 250.0
const BAND_MAX := 340.0

func _init() -> void:
	display_name = "SPEWER"
	hp = 3
	speed = 105.0
	pts = 110
	radius = 15.0
	col = Balance.COL_SPEWER
	_fire_t = Game.rng.randf_range(1.2, 2.2)

func _on_ready() -> void:
	_strafe_dir = 1.0 if Game.rng.randf() < 0.5 else -1.0

func _move(delta: float) -> void:
	_orbit_flip_t -= delta
	if _orbit_flip_t <= 0.0:
		_orbit_flip_t = Game.rng.randf_range(2.0, 4.0)
		if Game.rng.randf() < 0.35:
			_strafe_dir *= -1.0
	var to_p := player.global_position - global_position if player != null else Vector2.ZERO
	var d := to_p.length()
	var lateral_weight := 1.15 if elite and elite_kind == "swift" else 0.85
	var desired := steer_distance_band(to_p, BAND_MIN, BAND_MAX, _strafe_dir, lateral_weight)
	desired += steer_separation(2.2) * 0.65
	if _telegraph <= 0.0 and player != null and is_instance_valid(player):
		desired += steer_open_space(to_p, BAND_MIN, _strafe_dir) * 0.85
		if d >= BAND_MIN:
			var cover_position := find_bulwark_cover(player.global_position)
			var cover_delta := cover_position - global_position
			if cover_position != Vector2.ZERO and cover_delta.length_squared() > 0.0001:
				desired += cover_delta.normalized() * 0.75
	_v = _v.move_toward(desired.limit_length(1.0) * speed, 420.0 * delta)
	_fire_t -= delta
	if _fire_t <= 0.0 and _telegraph <= 0.0 and d < 620.0:
		_telegraph = 0.42
	if _telegraph > 0.0:
		_telegraph -= delta
		_v = _v.move_toward(Vector2.ZERO, 700.0 * delta)
		if _telegraph <= 0.0:
			_fire()

func _fire() -> void:
	if player == null or not is_instance_valid(player):
		return
	if not EnemyOrb.can_spawn(self):
		_fire_t = repeated_fire_interval(0.8)
		return
	var orb := EnemyOrb.new()
	orb.setup(global_position + aim_at_player() * (radius + 10.0), aim_at_player(), 265.0, col)
	get_parent().add_child(orb)
	Sfx.play("shoot", 0.55, -7.0, 0.08)
	Fx.sparks(global_position + aim_at_player() * radius, col, 5, 120.0, 0.3, 2.4)
	_fire_t = repeated_fire_interval(Game.rng.randf_range(1.9, 2.5))

func repeated_fire_interval(base_interval: float) -> float:
	return maxf(base_interval * Balance.difficulty_cadence(threat_wave), 0.5)

func telegraph_duration() -> float:
	return 0.42

func vel() -> Vector2:
	return _v

func _draw() -> void:
	var c := _flash_col(col)
	var r := radius
	rotation = t * 0.9
	var pts := PackedVector2Array()
	for i in 6:
		pts.push_back(Vector2.from_angle(float(i) / 6.0 * TAU) * r)
	draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.2))
	draw_polyline(pts + PackedVector2Array([pts[0]]), c, 2.0, true)
	var eye_r := r * 0.42
	if _telegraph > 0.0:
		eye_r = r * (0.42 + 0.5 * (1.0 - _telegraph / 0.42))
		draw_circle(Vector2.ZERO, r * 1.25, Color(c.r, c.g, c.b, 0.14))
	var look := aim_at_player().angle() - rotation
	draw_circle(Vector2.from_angle(look) * r * 0.25, eye_r, c)
	draw_circle(Vector2.from_angle(look) * r * 0.25, eye_r * 0.45, Color(1, 1, 1, 0.9))
	if elite:
		draw_arc(Vector2.ZERO, r + 5.0, 0, TAU, 24, Color(1, 1, 1, 0.75), 1.6, true)

class_name UpdateLoopEnemy
extends EnemyBase

var _v := Vector2.ZERO
var _reinstalling := false
var _reinstall_t := 0.0
var _reinstalled := false

func _init() -> void:
	display_name = "UPDATE_LOOP"
	hp = 5
	speed = 82.0
	pts = 190
	radius = 16.0
	col = Color("67b8ff")
	mote_count = 3

func reinstall_duration() -> float:
	return 1.35

func _move(delta: float) -> void:
	if _reinstalling:
		_v = Vector2.ZERO
		_reinstall_t -= delta
		if _reinstall_t <= 0.0:
			_reinstalling = false
			_reinstalled = true
			hp = maxi(int(ceil(max_hp * 0.6)), 1)
			collision_layer = Balance.LAYER_ENEMY
			Fx.ring(global_position, col, radius, radius + 28.0, 0.45, 2.0)
			Fx.text(global_position + Vector2(0, -28), "UPDATE COMPLETE", col, 10)
		return
	var to_player := player.global_position - global_position if is_instance_valid(player) else Vector2.ZERO
	var desired := steer_distance_band(to_player, 210.0, 330.0, 1.0, 0.72)
	desired += steer_separation(2.2) * 0.7
	_v = _v.move_toward(desired * speed, 260.0 * delta)

func take_hit(dmg: int, from: Vector2) -> void:
	if _reinstalling:
		return
	super.take_hit(dmg, from)

func die() -> void:
	if _reinstalling:
		return
	if not _reinstalled:
		_reinstalling = true
		_reinstall_t = reinstall_duration()
		hp = 1
		collision_layer = 0
		Fx.text(global_position + Vector2(0, -28), "REINSTALLING...", col, 12)
		Fx.ring(global_position, col, radius, radius + 22.0, reinstall_duration(), 1.8)
		Sfx.play("ui", 0.7, -8.0)
		return
	super.die()

func vel() -> Vector2:
	return _v

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _v.length_squared() > 0.01:
		rotation = lerp_angle(rotation, _v.angle(), 5.0 * delta)

func _draw() -> void:
	var c := _flash_col(col)
	var r := radius
	var body := PackedVector2Array([Vector2(-r, -r * 0.72), Vector2(r, -r * 0.72), Vector2(r * 0.72, r * 0.72), Vector2(-r * 0.72, r * 0.72)])
	draw_colored_polygon(body, Color(c.r, c.g, c.b, 0.2))
	draw_polyline(body + PackedVector2Array([body[0]]), c, 2.0, true)
	if _reinstalling:
		var progress := 1.0 - _reinstall_t / reinstall_duration()
		draw_arc(Vector2.ZERO, r + 7.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 20, c, 3.0, true)
		draw_string(ThemeDB.fallback_font, Vector2(-34, r + 18), "UPDATING", HORIZONTAL_ALIGNMENT_CENTER, 68.0, 9, c)
	else:
		draw_line(Vector2(-r * 0.55, 0), Vector2(r * 0.55, 0), c, 2.0)
		draw_circle(Vector2.ZERO, r * 0.2, Color(1, 1, 1, 0.85))
	if elite:
		draw_arc(Vector2.ZERO, r + 5.0, 0, TAU, 24, Color(1, 1, 1, 0.75), 1.6, true)

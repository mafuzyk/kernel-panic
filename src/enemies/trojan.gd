class_name TrojanEnemy
extends EnemyBase

var _v := Vector2.ZERO
var _drop_t := 1.6

func _init() -> void:
	display_name = "TROJAN"
	hp = 4
	speed = 62.0
	pts = 140
	radius = 15.0
	col = Color("c23a5e")
	mote_count = 3

func _move(delta: float) -> void:
	_v = _v.move_toward(aim_at_player() * speed, 240.0 * delta)
	_drop_t -= delta
	if _drop_t <= 0.0:
		_drop_t = 2.4
		_drop_pool()

func _drop_pool() -> void:
	if get_tree().get_nodes_in_group("corruption").size() >= 6:
		return
	var z := CorruptionZone.new()
	z.position = position
	get_parent().call_deferred("add_child", z)
	Fx.sparks(global_position, col, 5, 90.0, 0.4, 2.5)
	Sfx.play("hit", 0.45, -12.0, 0.1)

func vel() -> Vector2:
	return _v

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	rotation = lerp_angle(rotation, _v.angle() + PI * 0.5, 6.0 * delta)

func _draw() -> void:
	var c := _flash_col(col)
	var r := radius
	var body := PackedVector2Array([
		Vector2(0, -r * 1.2), Vector2(r * 0.75, 0), Vector2(0, r * 1.2), Vector2(-r * 0.75, 0)
	])
	draw_colored_polygon(body, Color(c.r, c.g, c.b, 0.22))
	draw_polyline(body + PackedVector2Array([body[0]]), c, 2.0, true)
	draw_line(Vector2(-r * 0.9, -r * 0.5), Vector2(r * 0.9, r * 0.5), Color(c.r, c.g, c.b, 0.8), 2.0)
	draw_line(Vector2(-r * 0.9, r * 0.5), Vector2(r * 0.9, -r * 0.5), Color(c.r, c.g, c.b, 0.8), 2.0)
	var drop_glow := clampf(1.0 - _drop_t / 2.4, 0.0, 1.0)
	draw_circle(Vector2.ZERO, r * 0.35 * (0.6 + 0.6 * drop_glow), Color(1.0, 0.25, 0.4, 0.4 + 0.4 * drop_glow))
	if elite:
		draw_arc(Vector2.ZERO, r + 5.0, 0, TAU, 24, Color(1, 1, 1, 0.75), 1.6, true)

class_name RecursorEnemy
extends EnemyBase

enum Phase { STALK, WIND, GONE, ARRIVE }

var phase: int = Phase.STALK
var phase_t := 0.0
var _v := Vector2.ZERO
var _dest := Vector2.ZERO

const COL_RECURSOR := Color("52ff7a")
const MAX_ZONES := 4

func _init() -> void:
	display_name = "RECURSOR"
	hp = 3
	speed = 130.0
	pts = 140
	radius = 13.0
	col = COL_RECURSOR

func _on_ready() -> void:
	phase_t = Game.rng.randf_range(1.0, 1.8)

func _move(delta: float) -> void:
	phase_t -= delta
	match phase:
		Phase.STALK:
			_v = _v.move_toward(aim_at_player() * speed * 0.8 + aim_at_player().orthogonal() * speed * 0.5, 500.0 * delta)
			if phase_t <= 0.0 and dist_to_player() < 520.0:
				phase = Phase.WIND
				phase_t = 0.35
				Sfx.play("charge", 1.5, -10.0)
		Phase.WIND:
			_v = _v.move_toward(Vector2.ZERO, 900.0 * delta)
			if phase_t <= 0.0:
				_begin_teleport()
		Phase.GONE:
			if phase_t <= 0.0:
				_finish_teleport()
		Phase.ARRIVE:
			_v = Vector2.ZERO
			if phase_t <= 0.0:
				phase = Phase.STALK
				phase_t = Game.rng.randf_range(1.2, 2.0)

func _begin_teleport() -> void:
	var origin := global_position
	var r := Balance.arena_rect()
	for attempt in 12:
		var ang := Game.rng.randf() * TAU
		var dist := Game.rng.randf_range(120.0, 220.0)
		_dest = player.global_position if is_instance_valid(player) else Vector2.ZERO
		_dest += Vector2.from_angle(ang) * dist
		_dest.x = clampf(_dest.x, r.position.x + radius + 8.0, r.end.x - radius - 8.0)
		_dest.y = clampf(_dest.y, r.position.y + radius + 8.0, r.end.y - radius - 8.0)
		if not is_instance_valid(player) or _dest.distance_to(player.global_position) > 90.0:
			break
	_leave_zone(origin)
	modulate.a = 0.0
	phase = Phase.GONE
	phase_t = 0.18
	Fx.sparks(origin, col, 6, 160.0, 0.3, 2.0)

func _finish_teleport() -> void:
	global_position = _dest
	_leave_zone(_dest)
	modulate.a = 1.0
	phase = Phase.ARRIVE
	phase_t = 0.3
	Fx.ring(global_position, col, 4.0, 40.0, 0.3, 2.0)
	Sfx.play("teleport" if Sfx.has_sound("teleport") else "hit", 1.3, -12.0)

func _leave_zone(pos: Vector2) -> void:
	var zones := get_tree().get_nodes_in_group("corruption") if get_tree() != null else []
	if zones.size() >= MAX_ZONES and zones.size() > 0:
		var oldest: Node = zones[0]
		if is_instance_valid(oldest):
			oldest.queue_free()
	var z := CorruptionZone.new()
	z.position = pos
	get_parent().call_deferred("add_child", z)

func vel() -> Vector2:
	return _v

func _draw() -> void:
	var c := _flash_col(col)
	var r := radius
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0)
	]), Color(c.r, c.g, c.b, 0.25))
	draw_polyline(PackedVector2Array([Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0), Vector2(0, -r)]), c, 2.0, true)
	draw_circle(Vector2.ZERO, r * 0.3, c)
	if phase == Phase.WIND:
		var a := 0.35 + 0.45 * absf(sin(t * 30.0))
		draw_arc(Vector2.ZERO, r + 6.0 + (1.0 - phase_t / 0.35) * 14.0, 0, TAU, 24, Color(c.r, c.g, c.b, a), 2.0, true)
	if elite:
		draw_arc(Vector2.ZERO, r + 5.0, 0, TAU, 24, Color(1, 1, 1, 0.75), 1.6, true)

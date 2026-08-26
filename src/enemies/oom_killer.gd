class_name OomKiller
extends EnemyBase

enum St { SEEK, FLEE }

var st: int = St.SEEK
var _v := Vector2.ZERO
var carried: Array = []

func _init() -> void:
	display_name = "OOM_KILLER"
	hp = 3
	speed = 145.0
	pts = 150
	radius = 14.0
	col = Color("9a4dff")
	mote_count = 2

func _ready() -> void:
	super._ready()
	add_to_group("oom")

func _move(delta: float) -> void:
	match st:
		St.SEEK:
			var target_mote: Node2D = _nearest_free_mote()
			if target_mote != null:
				_v = _v.move_toward((target_mote.global_position - global_position).normalized() * speed, 500.0 * delta)
				if global_position.distance_to(target_mote.global_position) < 18.0:
					_steal(target_mote)
			else:
				_v = _v.move_toward(aim_at_player() * speed * 0.7, 400.0 * delta)
			if carried.size() >= 2:
				st = St.FLEE
		St.FLEE:
			var r := Balance.arena_rect()
			var edge := _nearest_edge_point()
			_v = _v.move_toward((edge - global_position).normalized() * 245.0, 600.0 * delta)
			if not r.grow(26.0).has_point(global_position):
				_escape()
	_v = _v.limit_length(400.0)
	for i in carried.size():
		var m = carried[i]
		if is_instance_valid(m):
			m.global_position = global_position + Vector2.from_angle(t * 4.0 + TAU * i / maxi(carried.size(), 1)) * 22.0

func _nearest_free_mote() -> Node2D:
	var best: Node2D = null
	var bd := 1e9
	for m in get_tree().get_nodes_in_group("motes"):
		if not is_instance_valid(m) or m.stolen:
			continue
		var d: float = global_position.distance_squared_to(m.global_position)
		if d < bd:
			bd = d
			best = m
	return best

func _nearest_edge_point() -> Vector2:
	var r := Balance.arena_rect()
	var cx := clampf(global_position.x, r.position.x + 40.0, r.end.x - 40.0)
	var cy := clampf(global_position.y, r.position.y + 40.0, r.end.y - 40.0)
	var candidates := [
		Vector2(cx, r.position.y - 60.0), Vector2(cx, r.end.y + 60.0),
		Vector2(r.position.x - 60.0, cy), Vector2(r.end.x + 60.0, cy)
	]
	var best: Vector2 = candidates[0]
	var bd := 1e9
	for cpt in candidates:
		var d := global_position.distance_squared_to(cpt)
		if d < bd:
			bd = d
			best = cpt
	return best

func _steal(m: Node2D) -> void:
	if m.stolen:
		return
	m.stolen = true
	carried.append(m)
	Fx.sparks(m.global_position, col, 5, 140.0, 0.3, 2.5)
	Sfx.play("hit", 1.6, -10.0, 0.1)
	Fx.text(global_position + Vector2(0, -22), "STOLEN", col, 11)

func _escape() -> void:
	for m in carried:
		if is_instance_valid(m):
			m.queue_free()
	carried.clear()
	Fx.ring(global_position, col, 6.0, 30.0, 0.3, 2.0)
	queue_free()

func die() -> void:
	for m in carried:
		if is_instance_valid(m):
			m.stolen = false
			m.vel = Vector2.from_angle(Game.rng.randf() * TAU) * 180.0
			m.life = maxf(m.life, 6.0)
	carried.clear()
	Game.add_score(25)
	Fx.text(global_position + Vector2(0, -24), "+25 RECOVERED", Balance.COL_MOTE, 12)
	super.die()

func vel() -> Vector2:
	return _v

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	rotation = lerp_angle(rotation, _v.angle(), 8.0 * delta)

func _draw() -> void:
	var c := _flash_col(col)
	var r := radius
	draw_circle(Vector2.ZERO, r, Color(c.r, c.g, c.b, 0.2))
	draw_arc(Vector2.ZERO, r, 0, TAU, 24, c, 2.2, true)
	var horn := PackedVector2Array([Vector2(-r * 0.5, -r * 0.7), Vector2(-r * 0.9, -r * 1.6), Vector2(-r * 0.05, -r * 0.95)])
	draw_colored_polygon(horn, c)
	var horn2 := PackedVector2Array([Vector2(r * 0.5, -r * 0.7), Vector2(r * 0.9, -r * 1.6), Vector2(r * 0.05, -r * 0.95)])
	draw_colored_polygon(horn2, c)
	var look := _v.angle() if _v.length() > 10.0 else aim_at_player().angle()
	var eo := Vector2.from_angle(look) * r * 0.25
	draw_circle(eo + Vector2(-3.5, -3.0), 2.6, Color(1, 1, 1, 0.95))
	draw_circle(eo + Vector2(3.5, -3.0), 2.6, Color(1, 1, 1, 0.95))
	draw_arc(eo + Vector2(0, 3.0), 4.0, PI, TAU, 10, Color(1, 1, 1, 0.7), 1.5, true)
	if carried.size() > 0:
		draw_arc(Vector2.ZERO, 22.0, 0, TAU, 24, Color(Balance.COL_MOTE.r, Balance.COL_MOTE.g, Balance.COL_MOTE.b, 0.4), 1.5, true)
	if elite:
		draw_arc(Vector2.ZERO, r + 5.0, 0, TAU, 24, Color(1, 1, 1, 0.75), 1.6, true)

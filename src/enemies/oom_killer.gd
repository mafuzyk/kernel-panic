class_name OomKiller
extends EnemyBase

enum St { SEEK, FLEE }

var st: int = St.SEEK
var _v := Vector2.ZERO
var carried_ids: Array = []

func _field() -> MoteField:
	var f := get_tree().get_first_node_in_group("mote_field") if get_tree() != null else null
	return f

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
			var target_idx: int = _nearest_free_mote()
			if target_idx >= 0:
				var f := _field()
				var tp := f.pos_of(target_idx)
				var target_uid := f.uid_of(target_idx)
				var desired := (tp - global_position).normalized()
				desired += steer_separation(2.4) * 0.7
				_v = _v.move_toward(desired.limit_length(1.0) * speed, 500.0 * delta)
				if global_position.distance_to(tp) < 18.0 and f.uid_of(target_idx) == target_uid:
					_steal(target_idx, target_uid)
			else:
				_v = _v.move_toward(aim_at_player() * speed * 0.7, 400.0 * delta)
			if carried_ids.size() >= 2:
				st = St.FLEE
		St.FLEE:
			var r := Balance.arena_rect()
			var edge := _nearest_edge_point()
			var escape_dir := (edge - global_position).normalized()
			escape_dir += steer_separation(2.4) * 0.7
			_v = _v.move_toward(escape_dir.limit_length(1.0) * 245.0, 600.0 * delta)
			if not r.grow(26.0).has_point(global_position):
				_escape()
	_v = _v.limit_length(400.0)
	var f := _field()
	if f != null:
		for i in range(carried_ids.size() - 1, -1, -1):
			var idx: int = f.idx_of_uid(int(carried_ids[i]))
			if idx < 0:
				carried_ids.remove_at(i)
				continue
			f.set_slot_position(idx, global_position + Vector2.from_angle(t * 4.0 + TAU * i / maxi(carried_ids.size(), 1)) * 22.0)

func _nearest_free_mote() -> int:
	var f := _field()
	if f == null:
		return -1
	return f.nearest_free(global_position)

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

func _steal(idx: int, expected_uid: int = -1) -> void:
	var f := _field()
	if f == null or f.is_stolen(idx):
		return
	if expected_uid >= 0 and f.uid_of(idx) != expected_uid:
		return
	if f.steal(idx) < 0:
		return
	f.set_slot_position(idx, f.pos_of(idx))
	carried_ids.append(f.uid_of(idx))
	Fx.sparks(f.pos_of(idx), col, 5, 140.0, 0.3, 2.5)
	Sfx.play("hit", 1.6, -10.0, 0.1)
	Fx.text(global_position + Vector2(0, -22), "STOLEN", col, 11)

func _escape() -> void:
	var f := _field()
	if f != null:
		f.free_all_stolen()
	carried_ids.clear()
	Fx.ring(global_position, col, 6.0, 30.0, 0.3, 2.0)
	queue_free()

func die() -> void:
	var f := _field()
	if f != null:
		f.release_all_stolen()
	carried_ids.clear()
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
	if carried_ids.size() > 0:
		draw_arc(Vector2.ZERO, 22.0, 0, TAU, 24, Color(Balance.COL_MOTE.r, Balance.COL_MOTE.g, Balance.COL_MOTE.b, 0.4), 1.5, true)
	if elite:
		draw_arc(Vector2.ZERO, r + 5.0, 0, TAU, 24, Color(1, 1, 1, 0.75), 1.6, true)

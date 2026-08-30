class_name RecursorEnemy
extends EnemyBase

enum Phase { STALK, WIND, GONE, ARRIVE }

var phase: int = Phase.STALK
var phase_t := 0.0
var _v := Vector2.ZERO
var _dest := Vector2.ZERO

const COL_RECURSOR := Color("52ff7a")
const MAX_ZONES := 4
const TELEPORT_SAFE_DISTANCE := 90.0

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
			var to_player := player.global_position - global_position if is_instance_valid(player) else Vector2.ZERO
			var desired := steer_distance_band(to_player, 170.0, 330.0, 1.0, 0.55)
			desired += steer_separation(2.4) * 0.7
			_v = _v.move_toward(desired.limit_length(1.0) * speed * 0.8, 500.0 * delta)
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
	var player_position := player.global_position if is_instance_valid(player) else Vector2.ZERO
	var player_facing := Vector2.ZERO
	var player_movement := Vector2.ZERO
	if player is Player:
		player_facing = player.aim
		player_movement = player.vel
	_dest = select_teleport_candidate(player_position, player_facing, player_movement)
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
	Sfx.play("dash", 1.3, -12.0)

func score_teleport_candidate(candidate: Vector2, player_position: Vector2, player_facing: Vector2, player_movement: Vector2) -> float:
	var valid_rect := Balance.arena_rect().grow(-radius - 8.0)
	var offset := candidate - player_position
	var distance := offset.length()
	if not valid_rect.has_point(candidate) or distance <= TELEPORT_SAFE_DISTANCE:
		return -INF
	var score := (distance - TELEPORT_SAFE_DISTANCE) * 0.02
	var direction := offset / distance
	if player_facing.length_squared() > 0.0001:
		score += direction.dot(-player_facing.normalized()) * 100.0
	if player_movement.length_squared() > 0.0001:
		score += direction.dot(-player_movement.normalized()) * 30.0
	return score

func select_teleport_candidate(player_position: Vector2, player_facing: Vector2, player_movement: Vector2) -> Vector2:
	var facing_available := player_facing.length_squared() > 0.0001
	var movement_available := player_movement.length_squared() > 0.0001
	if not facing_available and not movement_available:
		return _random_teleport_candidate(player_position)
	var anchors: Array[Vector2] = []
	if facing_available:
		anchors.append(-player_facing.normalized())
	if movement_available:
		anchors.append(-player_movement.normalized())
	var turns := [0.0, PI * 0.5, -PI * 0.5]
	var distances := [120.0, 180.0, 220.0]
	var best := Vector2.ZERO
	var best_score := -INF
	for anchor: Vector2 in anchors:
		for turn: float in turns:
			var direction := anchor.rotated(turn)
			for distance: float in distances:
				var candidate := player_position + direction * distance
				var score := score_teleport_candidate(candidate, player_position, player_facing, player_movement)
				if score > best_score:
					best_score = score
					best = candidate
	if best_score > -INF:
		return best
	for i in 16:
		var candidate := player_position + Vector2.from_angle(TAU * float(i) / 16.0) * (TELEPORT_SAFE_DISTANCE + 30.0)
		var score := score_teleport_candidate(candidate, player_position, player_facing, player_movement)
		if score > best_score:
			best_score = score
			best = candidate
	if best_score > -INF:
		return best
	var safe_rect := Balance.arena_rect().grow(-radius - 8.0)
	for candidate in [
		Vector2(safe_rect.position.x, safe_rect.position.y),
		Vector2(safe_rect.end.x, safe_rect.position.y),
		Vector2(safe_rect.position.x, safe_rect.end.y),
		Vector2(safe_rect.end.x, safe_rect.end.y),
	]:
		var score := score_teleport_candidate(candidate, player_position, player_facing, player_movement)
		if score > best_score:
			best_score = score
			best = candidate
	return best

func _random_teleport_candidate(player_position: Vector2) -> Vector2:
	var r := Balance.arena_rect()
	var best := Vector2.ZERO
	var best_distance := -INF
	for attempt in 12:
		var candidate := Vector2(
			Game.rng.randf_range(r.position.x + radius + 8.0, r.end.x - radius - 8.0),
			Game.rng.randf_range(r.position.y + radius + 8.0, r.end.y - radius - 8.0)
		)
		var distance := candidate.distance_to(player_position)
		if distance > best_distance:
			best_distance = distance
			best = candidate
	var safe_rect := Balance.arena_rect().grow(-radius - 8.0)
	if safe_rect.size.x >= 0.0 and safe_rect.size.y >= 0.0:
		for candidate in [
			Vector2(safe_rect.position.x, safe_rect.position.y),
			Vector2(safe_rect.end.x, safe_rect.position.y),
			Vector2(safe_rect.position.x, safe_rect.end.y),
			Vector2(safe_rect.end.x, safe_rect.end.y),
		]:
			var distance: float = candidate.distance_to(player_position)
			if distance > best_distance:
				best_distance = distance
				best = candidate
	return best

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
	GlyphLib.draw_glyph(self, "recursor", Vector2.ZERO, r, _glyph_color(c), t)
	if phase == Phase.WIND:
		var a := 0.35 + 0.45 * absf(sin(t * 30.0))
		draw_arc(Vector2.ZERO, r + 6.0 + (1.0 - phase_t / 0.35) * 14.0, 0, TAU, 24, Color(c.r, c.g, c.b, a), 2.0, true)
	if elite:
		draw_arc(Vector2.ZERO, r + 5.0, 0, TAU, 24, Color(1, 1, 1, 0.75), 1.6, true)

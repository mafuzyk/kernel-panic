class_name EnemyBase
extends Area2D

signal died(enemy: EnemyBase)

static var shared_list: Array = []

var hp := 2
var max_hp := 2
var speed := 120.0
var pts := 50
var radius := 14.0
var col: Color = Balance.COL_DRONE
var kb := Vector2.ZERO
var t := 0.0
var hit_flash := 0.0
var elite := false
var elite_kind := ""
var threat_wave := 1
var _swift_ghost_cd := 0.0
var _volatile_pulse_t := 0.0
var spawn_t := 0.0
var mote_count := -1
var display_name := "DAEMON"
var last_pdash_id := -1
var player: Node2D
var glow: Sprite2D
var era_accent := Color(0, 0, 0, 0)

## Presentation-only snapshot. It reads simulation state but never owns or mutates it.
func presentation_snapshot() -> Dictionary:
	return {
		"display_name": display_name,
		"hp": hp,
		"max_hp": max_hp,
		"global_rotation": global_rotation,
		"elite": elite,
		"mote_count": mote_count,
		"era_accent": era_accent,
		"hit_flash": hit_flash,
		"visual_state": presentation_state(),
		"facing": presentation_facing(),
	}

func presentation_state() -> String:
	if hit_flash > 0.0:
		return "hit"
	return "elite" if elite else "idle"

func presentation_facing() -> Vector2:
	return Vector2.RIGHT.rotated(global_rotation)

func participates_in_enemy_pathing() -> bool:
	return true

func participates_in_kill_rewards() -> bool:
	return true

func configure(wave_scale_f: float, is_elite: bool) -> void:
	hp = int(ceil(hp * wave_scale_f * (2.0 if is_elite else 1.0)))
	max_hp = hp
	speed *= wave_scale_f * (1.22 if is_elite else 1.0)
	elite = is_elite
	if is_elite:
		pts *= 3
		elite_kind = "volatile" if Game.rng.randf() < 0.5 else "swift"
		if elite_kind == "swift":
			speed *= 1.3
		else:
			_volatile_pulse_t = 0.15

func elite_steering(to_target: Vector2, lateral_sign: float = 1.0) -> Vector2:
	var lateral_weight := 0.35
	if elite and elite_kind == "swift":
		lateral_weight = 0.9
	return steer_approach(to_target, lateral_sign, lateral_weight)

func elite_reacquire_interval(base_interval: float) -> float:
	if elite and elite_kind == "swift":
		return maxf(base_interval * Balance.difficulty_cadence(threat_wave) * 0.82, 0.35)
	return base_interval * Balance.difficulty_cadence(threat_wave)

func volatile_burst_count() -> int:
	return 6 if elite and elite_kind == "volatile" else 0

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = Balance.LAYER_ENEMY
	collision_mask = 0
	monitorable = true
	monitoring = false
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = radius
	cs.shape = sh
	add_child(cs)
	glow = Fx.make_glow(radius * 1.5, col)
	glow.modulate.a = 0.4
	add_child(glow)
	z_index = 11
	scale = Vector2.ONE * 0.05
	var players := get_tree().get_nodes_in_group("player")
	player = players[0] if players.size() > 0 else null
	_on_ready()

func _on_ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	t += delta
	spawn_t += delta
	if hit_flash > 0.0:
		hit_flash -= delta * 6.0
	_move(delta)
	var sep := _separation()
	position += (vel() + kb + sep) * delta
	kb = kb.move_toward(Vector2.ZERO, 700.0 * delta)
	var r := Balance.arena_rect()
	position.x = clampf(position.x, r.position.x + radius, r.end.x - radius)
	position.y = clampf(position.y, r.position.y + radius, r.end.y - radius)
	if is_in_group("oom") and get("st") == 1 and has_method("_escape"):
		var at_edge := position.x <= r.position.x + radius + 0.1 or position.x >= r.end.x - radius - 0.1 or position.y <= r.position.y + radius + 0.1 or position.y >= r.end.y - radius - 0.1
		if at_edge:
			call("_escape")
			return
	if glow != null:
		glow.modulate.a = 0.4 + 0.12 * sin(t * 6.0) + hit_flash
	var k: float = clampf(spawn_t / 0.32, 0.0, 1.0)
	var e := 1.0 + 2.7 * pow(k - 1.0, 3.0) + 1.7 * pow(k - 1.0, 2.0)
	scale = Vector2.ONE * maxf(0.05, e) * (1.22 if elite else 1.0)
	if elite and elite_kind == "swift":
		_swift_ghost_cd -= delta
		if _swift_ghost_cd <= 0.0:
			_swift_ghost_cd = 0.09
			Fx.ghost_dot(global_position, radius * 0.8, col, 0.22)
	if elite and elite_kind == "volatile":
		_volatile_pulse_t -= delta
		if _volatile_pulse_t <= 0.0:
			_volatile_pulse_t = 0.6
			Fx.ring(global_position, col, radius + 4.0, radius + 14.0, 0.22, 1.8)
	queue_redraw()

func vel() -> Vector2:
	return Vector2.ZERO

func _move(_delta: float) -> void:
	pass

func _separation() -> Vector2:
	var push := Vector2.ZERO
	for e in shared_list:
		if e == self or not is_instance_valid(e) or not e.participates_in_enemy_pathing():
			continue
		var d: Vector2 = global_position - e.global_position
		var dist := d.length()
		var min_d: float = radius + e.radius
		if dist < min_d and dist > 0.01:
			push += d / dist * (min_d - dist) * 6.0
	return push

func take_hit(dmg: int, from: Vector2) -> void:
	hp -= dmg
	hit_flash = 1.0
	var dir := (global_position - from).normalized()
	kb += dir * (140.0 if not is_in_group("boss") else 18.0)
	Sfx.play("hit", 1.0, -6.0)
	if hp <= 0:
		die()

func die() -> void:
	died.emit(self)
	if volatile_burst_count() > 0:
		for i in volatile_burst_count():
			var orb := EnemyOrb.new()
			orb.setup(global_position, Vector2.from_angle(TAU * i / 6.0 + Game.rng.randf() * 0.4), 230.0, col)
			get_parent().call_deferred("add_child", orb)
		Fx.ring(global_position, Color(1, 1, 1, 0.8), radius, radius + 44.0, 0.3, 2.5)
	Fx.burst(global_position, col, 1.0 if radius < 20.0 else 1.7)
	Fx.hitstop(35.0)
	Sfx.play("explode", Game.rng.randf_range(0.9, 1.1), -4.0)
	queue_free()

func aim_at_player() -> Vector2:
	if player == null or not is_instance_valid(player):
		return Vector2.RIGHT
	return (player.global_position - global_position).normalized()

func dist_to_player() -> float:
	if player == null or not is_instance_valid(player):
		return 99999.0
	return global_position.distance_to(player.global_position)

func steer_approach(to_target: Vector2, lateral_sign: float = 0.0, lateral_weight: float = 0.0) -> Vector2:
	if to_target.length_squared() <= 0.0001:
		return Vector2.ZERO
	var radial := to_target.normalized()
	return (radial + radial.orthogonal() * lateral_sign * lateral_weight).normalized()

func steer_distance_band(to_target: Vector2, min_distance: float, max_distance: float, lateral_sign: float, lateral_weight: float = 0.85) -> Vector2:
	if to_target.length_squared() <= 0.0001:
		return Vector2.ZERO
	var radial := to_target.normalized()
	var distance := to_target.length()
	if distance < min_distance:
		radial = -radial
	elif distance <= max_distance:
		radial = Vector2.ZERO
	return (radial + to_target.normalized().orthogonal() * lateral_sign * lateral_weight).normalized()

func steer_separation(radius_scale: float = 2.0) -> Vector2:
	var push := Vector2.ZERO
	for other in shared_list:
		if other == self or not is_instance_valid(other):
			continue
		var delta: Vector2 = global_position - other.global_position
		var distance: float = delta.length()
		var safe_radius: float = radius + other.radius
		var threshold: float = safe_radius * radius_scale
		if distance > 0.01 and distance < threshold:
			push += delta / distance * (1.0 - distance / threshold)
	return push.normalized() if push.length_squared() > 0.0001 else Vector2.ZERO

func steer_open_space(to_target: Vector2, min_distance: float, lateral_sign: float = 1.0) -> Vector2:
	var nearby_count := 0
	for other in shared_list:
		if other == self or not is_instance_valid(other):
			continue
		var delta: Vector2 = other.global_position - global_position
		var threshold: float = radius + other.radius + 80.0
		if delta.length_squared() < threshold * threshold:
			nearby_count += 1
	var too_close := to_target.length_squared() > 0.0001 and to_target.length() < min_distance
	if not too_close and nearby_count < 2:
		return Vector2.ZERO

	var retreat := -to_target.normalized() if to_target.length_squared() > 0.0001 else Vector2.ZERO
	var lateral := retreat.orthogonal() * (1.0 if lateral_sign >= 0.0 else -1.0)
	if lateral.length_squared() <= 0.0001:
		lateral = Vector2.RIGHT * (1.0 if lateral_sign >= 0.0 else -1.0)
	var candidates: Array[Vector2] = [lateral, -lateral, retreat, -retreat]
	var valid_rect := Balance.arena_rect().grow(-radius)
	var best := Vector2.ZERO
	var best_score := INF
	for candidate: Vector2 in candidates:
		if candidate.length_squared() <= 0.0001:
			continue
		var probe_position: Vector2 = global_position + candidate * 96.0
		if not valid_rect.has_point(probe_position):
			continue
		var congestion := 0.0
		for other in shared_list:
			if other == self or not is_instance_valid(other):
				continue
			var distance: float = probe_position.distance_to(other.global_position)
			var crowd_radius: float = radius + other.radius + 96.0
			if distance < crowd_radius:
				congestion += 1.0 - distance / crowd_radius
		if congestion < best_score:
			best_score = congestion
			best = candidate
	return best.normalized() if best.length_squared() > 0.0001 else Vector2.ZERO

func find_bulwark_cover(player_position: Vector2) -> Vector2:
	var player_to_self := global_position - player_position
	if player_to_self.length_squared() <= 0.0001:
		return Vector2.ZERO
	var forward := player_to_self.normalized()
	var lateral := forward.orthogonal()
	var self_distance := player_to_self.length()
	var valid_rect := Balance.arena_rect().grow(-radius)
	var best := Vector2.ZERO
	var best_score := INF
	for raw_ally in shared_list:
		if not (raw_ally is EnemyBase):
			continue
		var ally: EnemyBase = raw_ally
		if ally == self or not is_instance_valid(ally) or ally.display_name != "BULWARK":
			continue
		var player_to_ally := ally.global_position - player_position
		var projection := player_to_ally.dot(forward)
		if projection <= ally.radius or projection >= self_distance:
			continue
		var lateral_gap := absf(player_to_ally.dot(lateral))
		if lateral_gap > ally.radius + radius + 96.0:
			continue
		var offset := ally.radius + radius + 18.0
		var candidates: Array[Vector2] = [
				ally.global_position + forward * offset,
				ally.global_position + forward * offset + lateral * offset * 0.9,
				ally.global_position + forward * offset - lateral * offset * 0.9,
		]
		for candidate in candidates:
			if not valid_rect.has_point(candidate):
				continue
			var score := candidate.distance_to(global_position)
			if score < best_score:
				best_score = score
				best = candidate
	return best

func _flash_col(base: Color) -> Color:
	if hit_flash > 0.0:
		return base.lerp(Color(1, 1, 1, 1), clampf(hit_flash, 0.0, 1.0))
	return base

func _glyph_color(flash_col: Color) -> Color:
	return GlyphLib.era_mix(flash_col, era_accent, 0.25)

func _draw() -> void:
	pass

class_name RootBoss
extends EnemyBase

signal boss_hp_changed(frac: float)
signal split_started(minis: Array)

enum Phase { ONE = 1, TWO = 2, THREE = 3 }
enum Act { HOVER, BURST, SPIRAL, CHARGE_WIND, CHARGE_GO, STAGGER, TELEPORT_OUT, TELEPORT_IN, FREEZE_WIND, LANCE_WIND, LANCE_GO }

var act: int = Act.HOVER
var act_t := 0.0
var _v := Vector2.ZERO
var _burst_cd := 2.2
var _spiral_cd := 4.5
var _summon_cd := 7.0
var _charge_cd := 6.0
var _teleport_cd := 3.5
var _freeze_cd := 5.0
var _lance_cd := 6.0
var _lance_dir := Vector2.RIGHT
var _fan_cd := 4.5
var _corruption_cd := 3.2
var _shield_rebuilt := false
var _rebuild_warning_t := 0.0
var _spiral_angle := 0.0
var _spiral_shots := 0
var _charge_dir := Vector2.RIGHT
var phase: int = Phase.ONE
var _phase_flash := 0.0
var boss_index := 1
var boss_title := "ROOT.exe"
var boss_quote := ""
var _exposed := 0.0
var _recover_half_dropped := false
var mini := false
var split_done := false
var kind := 1
var _mini_side := 1.0
var _glitch_off := Vector2.ZERO
var desperation_active := false
var desperation_transition_t := 0.0
var desperation_trigger_count := 0
const TELEPORT_SAFE_DISTANCE := 240.0
const DESPERATION_THRESHOLD := 0.08
const DESPERATION_TRANSITION_DURATION := 0.75
const DESPERATION_CADENCE_MULTIPLIER := 0.72

const MK_DATA := [
	{"title": "ROOT.exe", "col": Color("ff3d81"), "quote": "you have 1 unread virus"},
	{"title": "SEGFAULT", "col": Color("ff9a3d"), "quote": "memory at 0xDEADBEEF could not be read"},
	{"title": "BLUE SCREEN", "col": Color("4f8cff"), "quote": ":( your run ran into a problem"},
	{"title": "PAGE FAULT", "col": Color("b46bff"), "quote": "paging too hard"},
]

static func title_for_index(i: int) -> String:
	var kind := kind_for_index(i)
	var base: String = MK_DATA[kind - 1]["title"]
	return base + (" MK-%d" % ceilf(i / 4.0)) if i > 4 else base

static func quote_for_index(i: int) -> String:
	return String(MK_DATA[kind_for_index(i) - 1]["quote"])

static func kind_for_index(i: int) -> int:
	return ((i - 1) % 4) + 1

func _init() -> void:
	display_name = "ROOT"
	hp = 130
	speed = 42.0
	pts = 2500
	radius = 52.0
	col = Balance.COL_DRONE
	mote_count = 26

func configure(wave_scale_f: float, is_elite: bool) -> void:
	desperation_active = false
	desperation_transition_t = 0.0
	desperation_trigger_count = 0
	kind = kind_for_index(boss_index)
	if mini:
		radius = 26.0
		speed = 95.0 * Balance.weekly_enemy_speed_multiplier()
		pts = 600
		mote_count = 6
		boss_title = "MINI-" + title_for_index(boss_index)
		col = MK_DATA[kind - 1]["col"].lerp(Color(1, 1, 1), 0.25)
		_teleport_cd = 99.0
		_summon_cd = 999.0
		_charge_cd = 4.5
		return
	hp = 120 + 42 * (boss_index - 1)
	max_hp = hp
	speed = (55.0 + 5.0 * (boss_index - 1)) * Balance.weekly_enemy_speed_multiplier()
	pts = 2500 * boss_index
	mote_count = 26 + 6 * (boss_index - 1)
	boss_title = title_for_index(boss_index)
	boss_quote = quote_for_index(boss_index)
	col = MK_DATA[kind - 1]["col"]
	if kind == 2:
		_teleport_cd = 3.0
	if kind == 3:
		_freeze_cd = 4.0

func presentation_snapshot() -> Dictionary:
	var snapshot := super.presentation_snapshot()
	snapshot["boss_title"] = boss_title
	snapshot["boss_variant"] = kind
	snapshot["mini"] = mini
	snapshot["desperation_active"] = desperation_active
	snapshot["desperation_transition_t"] = desperation_transition_t
	return snapshot

func desperation_transition_duration() -> float:
	return DESPERATION_TRANSITION_DURATION

func desperation_cadence_multiplier() -> float:
	return DESPERATION_CADENCE_MULTIPLIER if desperation_active else 1.0

func _step_desperation(delta: float) -> void:
	if desperation_transition_t > 0.0:
		desperation_transition_t = maxf(desperation_transition_t - delta, 0.0)
	if desperation_active or hp <= 0 or max_hp <= 0:
		return
	if float(hp) / float(max_hp) > DESPERATION_THRESHOLD:
		return
	desperation_active = true
	desperation_trigger_count += 1
	desperation_transition_t = DESPERATION_TRANSITION_DURATION
	act = Act.STAGGER
	act_t = DESPERATION_TRANSITION_DURATION
	Fx.ring(global_position, Color.WHITE, radius, radius + 150.0, 0.65, 6.0, true)
	Fx.text(global_position + Vector2(0, -radius - 28.0), "DESPERATION // CADENCE UP", Color.WHITE, 14)
	Sfx.play("charge", 1.2, -3.0)

func _desperation_interval(base_interval: float) -> float:
	return base_interval * desperation_cadence_multiplier()

func _ready() -> void:
	super._ready()
	add_to_group("boss")
	z_index = 13
	glow.scale = Vector2.ONE * (radius * 3.2 / 128.0)

func _move(delta: float) -> void:
	_step_desperation(delta)
	act_t -= delta
	if _exposed > 0.0:
		_exposed -= delta
	if mini:
		_move_mini(delta)
		return
	var frac := float(hp) / float(max_hp)
	var new_phase := Phase.ONE
	if frac < 0.33:
		new_phase = Phase.THREE
	elif frac < 0.66:
		new_phase = Phase.TWO
	if new_phase != phase:
		phase = new_phase
		_enter_phase()
	if scale.x > 0.5 and act != Act.CHARGE_GO:
		var breathe := 1.0 + 0.022 * sin(t * 2.1)
		scale = Vector2.ONE * breathe
		rotation = 0.035 * sin(t * 0.85)
	_burst_cd -= delta
	_spiral_cd -= delta
	_summon_cd -= delta
	_charge_cd -= delta
	_teleport_cd -= delta
	_freeze_cd -= delta
	_lance_cd -= delta
	_fan_cd -= delta
	_corruption_cd -= delta
	match act:
		Act.HOVER:
			var to_p := player.global_position - global_position if player != null and is_instance_valid(player) else Vector2.ZERO
			var target := hover_direction(to_p) * speed
			if not is_ranged_profile():
				target += hover_direction(to_p).orthogonal() * sin(t * 1.3) * 40.0
			_v = _v.move_toward(target, 300.0 * delta)
			_try_attacks()
		Act.BURST:
			_v = _v.move_toward(Vector2.ZERO, 500.0 * delta)
			if act_t <= 0.0:
				act = Act.HOVER
		Act.SPIRAL:
			_v = _v.move_toward(Vector2.ZERO, 500.0 * delta)
			if act_t <= 0.0:
				act = Act.HOVER
		Act.CHARGE_WIND:
			_v = _v.move_toward(Vector2.ZERO, 800.0 * delta)
			_charge_dir = aim_at_player()
			if act_t <= 0.0:
				act = Act.CHARGE_GO
				act_t = 0.5
				_v = _charge_dir * (760.0 + 40.0 * boss_index)
				Sfx.play("dash", 0.5, -4.0)
				Fx.shake(0.3)
		Act.CHARGE_GO:
			if act_t <= 0.0:
				act = Act.STAGGER
				act_t = 0.7
				if kind == 1 and boss_index >= 3:
					_exposed = 2.5
					Fx.ring(global_position, Color(1, 1, 1, 0.9), radius, radius + 40.0, 0.4, 3.0)
		Act.STAGGER:
			_v = _v.move_toward(Vector2.ZERO, 600.0 * delta)
			if act_t <= 0.0:
				act = Act.HOVER
		Act.TELEPORT_OUT:
			_v = Vector2.ZERO
			modulate.a = maxf(modulate.a - delta * 4.0, 0.0)
			if act_t <= 0.0:
				_do_teleport_in()
		Act.TELEPORT_IN:
			modulate.a = minf(modulate.a + delta * 5.0, 1.0)
			if act_t <= 0.0:
				act = Act.HOVER
				_volley(3)
		Act.FREEZE_WIND:
			_v = _v.move_toward(Vector2.ZERO, 500.0 * delta)
			if act_t <= 0.0:
				_apply_freeze()
				act = Act.HOVER
		Act.LANCE_WIND:
			_v = _v.move_toward(Vector2.ZERO, 700.0 * delta)
			_lance_dir = aim_at_player()
			if act_t <= 0.0:
				act = Act.LANCE_GO
				act_t = 0.3
				_v = _lance_dir * 900.0
				Sfx.play("dash", 0.7, -6.0)
				Fx.shake(0.25)
		Act.LANCE_GO:
			if act_t <= 0.0:
				act = Act.STAGGER
				act_t = 0.6
				Fx.sparks(global_position, col, 10, 300.0, 0.4, 3.0)
	var r := Balance.arena_rect()
	if position.x <= r.position.x + radius + 1 or position.x >= r.end.x - radius - 1 or position.y <= r.position.y + radius + 1 or position.y >= r.end.y - radius - 1:
		if act == Act.CHARGE_GO:
			act = Act.STAGGER
			act_t = 0.8
			Fx.shake(0.45)
			Fx.sparks(position, col, 16, 380.0, 0.5, 3.5)
			Sfx.play("hit", 0.5, -2.0)

func _move_mini(delta: float) -> void:
	_burst_cd -= delta
	_lance_cd -= delta
	match act:
		Act.HOVER:
			var to_player := player.global_position - global_position if player != null else Vector2.ZERO
			var desired := steer_distance_band(to_player, 150.0, 300.0, _mini_side, 0.8)
			desired += steer_separation(3.0) * 0.95
			_v = _v.move_toward(desired.limit_length(1.0) * speed * 2.0, 520.0 * delta)
			_try_attacks()
		Act.BURST:
			_v = _v.move_toward(Vector2.ZERO, 700.0 * delta)
			if act_t <= 0.0:
				act = Act.HOVER
		Act.LANCE_WIND:
			_v = _v.move_toward(Vector2.ZERO, 1000.0 * delta)
			_lance_dir = aim_at_player()
			if act_t <= 0.0:
				act = Act.LANCE_GO
				act_t = 0.28
				_v = _lance_dir * 980.0
				Sfx.play("dash", 0.55, -7.0)
		Act.LANCE_GO:
			if act_t <= 0.0:
				act = Act.STAGGER
				act_t = 0.35
		Act.STAGGER:
			_v = _v.move_toward(Vector2.ZERO, 800.0 * delta)
			if act_t <= 0.0:
				act = Act.HOVER

func _try_attacks() -> void:
	if desperation_transition_t > 0.0:
		return
	if mini:
		if act != Act.HOVER:
			return
		if _burst_cd <= 0.0:
			_burst_cd = _desperation_interval(3.4)
			_do_burst(6, 180.0)
		if _lance_cd <= 0.0:
			_lance_cd = _desperation_interval(5.0)
			act = Act.LANCE_WIND
			act_t = 0.42
			_lance_dir = aim_at_player()
			Sfx.play("charge", 0.55, -7.0)
		return
	var mk := clampi(boss_index, 1, 8)
	if act != Act.HOVER:
		return
	match kind:
		1:
			if _burst_cd <= 0.0:
				_burst_cd = _desperation_interval(2.5 if phase == Phase.ONE else (2.1 if phase == Phase.TWO else 1.7))
				_do_burst(14 + 4 * (phase - 1), 205.0 + 10.0 * phase)
			if not mini and phase >= Phase.TWO and _summon_cd <= 0.0 and _summons_alive() < 6:
				_summon_cd = _desperation_interval(8.5)
				_do_summon("drone")
			if phase >= Phase.THREE and _charge_cd <= 0.0:
				_start_charge()
		2:
			if _corruption_cd <= 0.0:
				_corruption_cd = repeated_cooldown(4.2)
				_corruption_volley(3)
			if _teleport_cd <= 0.0:
				_teleport_cd = repeated_cooldown(maxf(2.6, 4.0 - 0.3 * phase))
				act = Act.TELEPORT_OUT
				act_t = 0.35
				Sfx.play("charge", 1.6, -8.0)
			if _burst_cd <= 0.0:
				_burst_cd = repeated_cooldown(2.4)
				_do_burst(8, 240.0)
			if phase >= Phase.TWO and _lance_cd <= 0.0:
				_lance_cd = repeated_cooldown(maxf(4.5, 7.0 - phase))
				act = Act.LANCE_WIND
				act_t = 0.5
				Sfx.play("charge", 1.2, -8.0)
			if phase >= Phase.TWO and _summon_cd <= 0.0 and _summons_alive() < 6:
				_summon_cd = repeated_cooldown(9.0)
				_do_summon("lancer")
		3:
			if _freeze_cd <= 0.0:
				_freeze_cd = repeated_cooldown(maxf(4.5, 7.0 - 0.5 * phase))
				act = Act.FREEZE_WIND
				act_t = 0.7
				Sfx.play("charge", 0.8, -6.0)
			if _spiral_cd <= 0.0:
				_start_spiral(18 + 4 * phase, 1.8)
			if phase >= Phase.TWO and _fan_cd <= 0.0:
				_fan_cd = repeated_cooldown(maxf(3.8, 6.0 - phase * 0.7))
				_volley(5)
				Fx.ring(global_position, col, radius, radius + 90.0, 0.35, 2.5)
			if _burst_cd <= 0.0:
				_burst_cd = repeated_cooldown(2.6)
				_do_burst(10, 220.0)
			if phase >= Phase.TWO and _summon_cd <= 0.0 and _summons_alive() < 4:
				_summon_cd = repeated_cooldown(10.0)
				_do_summon("spewer")
		4:
			var pages := _pages_alive()
			if pages < 4 and _summon_cd <= 0.0:
				_summon_cd = repeated_cooldown(6.0)
				_do_pages()
			if pages == 0:
				if _burst_cd <= 0.0:
					_burst_cd = repeated_cooldown(1.9)
					_do_burst(16, 230.0)
				if _charge_cd <= 0.0 and phase >= Phase.TWO:
					_start_charge()
			if phase >= Phase.TWO and _summon_cd <= 0.0 and _summons_alive() < 4:
				_summon_cd = repeated_cooldown(11.0)
				_do_summon("trojan")
	if mk >= 4 and phase >= Phase.THREE and _charge_cd <= 0.0 and act == Act.HOVER and kind != 4:
		_charge_cd = _desperation_interval(5.2)
		_start_charge()

func _start_charge() -> void:
	_charge_cd = repeated_cooldown(5.2)
	act = Act.CHARGE_WIND
	act_t = 0.55
	Sfx.play("charge", 0.7, -4.0)

func vel() -> Vector2:
	return _v

func is_ranged_profile() -> bool:
	return kind != 1

func hover_direction(to_target: Vector2) -> Vector2:
	if not is_ranged_profile():
		return steer_approach(to_target)
	var lateral_sign := -1.0 if kind % 2 == 0 else 1.0
	var desired := steer_distance_band(to_target, 190.0, 360.0, lateral_sign, 0.7)
	if player != null and is_instance_valid(player):
		desired += steer_open_space(to_target, 190.0, lateral_sign) * 0.85
	return desired.limit_length(1.0)

func repeated_cooldown(base_interval: float) -> float:
	return _desperation_interval(base_interval) * Balance.difficulty_cadence(threat_wave) if is_ranged_profile() else _desperation_interval(base_interval)

func _start_spiral(shots: int, dur: float) -> void:
	_spiral_cd = repeated_cooldown(5.5)
	act = Act.SPIRAL
	act_t = dur
	_spiral_shots = shots
	_spiral_angle = Game.rng.randf() * TAU

func _do_teleport_in() -> void:
	var player_position := player.global_position if is_instance_valid(player) else Vector2.ZERO
	var player_facing := Vector2.ZERO
	var player_movement := Vector2.ZERO
	if player is Player:
		player_facing = player.aim
		player_movement = player.vel
	var p := select_teleport_candidate(player_position, player_facing, player_movement)
	position = p
	var z := CorruptionZone.new()
	z.position = p
	get_parent().call_deferred("add_child", z)
	Fx.ring(p, col, 8.0, radius + 30.0, 0.3, 3.0)
	Fx.sparks(p, col, 10, 240.0, 0.4, 3.0)
	act = Act.TELEPORT_IN
	act_t = 0.3

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
	var distances := [TELEPORT_SAFE_DISTANCE + 32.0, TELEPORT_SAFE_DISTANCE + 96.0, TELEPORT_SAFE_DISTANCE + 144.0]
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

func _apply_freeze() -> void:
	if player != null and is_instance_valid(player):
		player.apply_freeze(1.5)
	Fx.flash(Color(0.2, 0.45, 1.0), 0.22, 0.5)
	Fx.ring(global_position, Color(0.4, 0.6, 1.0), radius, 700.0, 0.7, 4.0)
	Fx.text(global_position + Vector2(0, -radius - 20.0), "SYSTEM FROZEN", Color(0.55, 0.75, 1.0), 16)
	Sfx.play("boss", 1.4, -6.0)
	Fx.shake(0.3)

func _volley(n: int) -> void:
	if player == null or not is_instance_valid(player):
		return
	var base := aim_at_player().angle()
	for i in n:
		_spawn_orb(Vector2.from_angle(base + (i - (n - 1) * 0.5) * 0.22), 260.0)
	Sfx.play("shoot", 0.5, -6.0)

func _corruption_volley(n: int) -> void:
	if player == null or not is_instance_valid(player) or get_parent() == null:
		return
	var shot_script: Script = load("res://src/enemies/corruption_shot.gd")
	if shot_script == null:
		return
	var target := player.global_position
	var base := aim_at_player().angle()
	for i in n:
		var shot: Node = shot_script.new()
		var dir := Vector2.from_angle(base + (i - (n - 1) * 0.5) * 0.16)
		shot.call("setup_corruption", global_position + dir * (radius + 8.0), target, 1, col, dir, player)
		get_parent().call_deferred("add_child", shot)
	Sfx.play("shoot", 0.6, -5.0)

func _pages_alive() -> int:
	var count := 0
	for p in get_tree().get_nodes_in_group("page"):
		if is_instance_valid(p):
			count += 1
	return count

func _do_pages() -> void:
	for i in 4:
		if _pages_alive() >= 4:
			break
		var pg := PageNode.new()
		pg.boss = self
		pg.orbit_idx = i
		pg.position = global_position + Vector2.from_angle(TAU * i / 4.0) * 90.0
		get_parent().call_deferred("add_child", pg)
	Fx.ring(global_position, col, radius, radius + 80.0, 0.4, 3.0, true)
	Sfx.play("wave", 0.8, -6.0)

func _process(delta: float) -> void:
	if _phase_flash > 0.0:
		_phase_flash = maxf(_phase_flash - delta * 2.4, 0.0)
	if act == Act.SPIRAL and _spiral_shots > 0:
		var fire_acc: float = get_meta("sp_acc", 0.0) + delta
		while fire_acc >= 0.085 and _spiral_shots > 0:
			fire_acc -= 0.085 * Balance.difficulty_cadence(threat_wave) * desperation_cadence_multiplier()
			_spiral_shots -= 1
			_spiral_angle += 0.47
			_spawn_orb(Vector2.from_angle(_spiral_angle), 235.0)
		set_meta("sp_acc", fire_acc)
	if kind == 2:
		_glitch_off = Vector2(Game.rng.randf_range(-3.0, 3.0), Game.rng.randf_range(-3.0, 3.0)) if Game.rng.randf() < 0.3 else _glitch_off.lerp(Vector2.ZERO, 0.2)
	queue_redraw()

func _do_burst(n: int, spd: float) -> void:
	var off := Game.rng.randf() * TAU
	for i in n:
		_spawn_orb(Vector2.from_angle(TAU * i / n + off), spd)
	Fx.ring(global_position, col, radius, radius + 70.0, 0.35, 3.0)
	Sfx.play("shoot", 0.4, -4.0, 0.05)
	Fx.shake(0.18)

func _summons_alive() -> int:
	var n := 0
	for s in get_tree().get_nodes_in_group("boss_summon"):
		if is_instance_valid(s):
			n += 1
	return n

func _do_summon(kind_name: String) -> void:
	for i in 3:
		var d: EnemyBase
		match kind_name:
			"lancer":
				d = LancerEnemy.new()
			"spewer":
				d = SpewerEnemy.new()
			"trojan":
				d = TrojanEnemy.new()
			_:
				d = DroneEnemy.new()
		d.position = global_position + Vector2.from_angle(TAU * i / 3.0 + Game.rng.randf()) * (radius + 26.0)
		d.add_to_group("boss_summon")
		get_parent().call_deferred("add_child", d)
	Fx.ring(global_position, Color(1, 1, 1, 0.7), radius, radius + 50.0, 0.3, 2.0)

func _spawn_orb(dir: Vector2, spd: float) -> void:
	if not EnemyOrb.can_spawn(self):
		return
	if player == null or not is_instance_valid(player):
		return
	var orb := EnemyOrb.new()
	orb.setup(global_position + dir * (radius + 8.0), dir, spd, col)
	get_parent().call_deferred("add_child", orb)

func _enter_phase() -> void:
	_phase_flash = 1.0
	if act != Act.CHARGE_WIND and act != Act.CHARGE_GO and act != Act.FREEZE_WIND and act != Act.TELEPORT_OUT and act != Act.TELEPORT_IN and act != Act.LANCE_WIND and act != Act.LANCE_GO:
		act = Act.STAGGER
		act_t = 0.8
	Fx.ring(global_position, col, radius, radius + 160.0, 0.5, 5.0, true)
	Fx.ring(global_position, Color(1, 1, 1, 0.8), radius, radius + 90.0, 0.35, 3.0)
	Fx.shake(0.5)
	Sfx.play("boss", 1.2, -2.0)
	var base: Color = MK_DATA[kind - 1]["col"]
	col = base.lerp(Color(1, 1, 1), 0.15 * phase)
	glow.self_modulate = col

func take_hit(dmg: int, from: Vector2) -> void:
	if kind == 4 and _pages_alive() > 0:
		Fx.sparks(from, Color(0.7, 0.5, 1.0), 4, 120.0, 0.25, 2.0)
		return
	if _exposed > 0.0:
		dmg *= 2
	if kind == 1 and not mini and not split_done and hp > max_hp / 2 and hp - dmg <= max_hp / 2:
		_split_into_minis()
		return
	super.take_hit(dmg, from)
	_step_desperation(0.0)
	boss_hp_changed.emit(float(maxf(hp, 0)) / float(max_hp))
	if kind == 4 and not mini and not _shield_rebuilt and hp > 0 and hp <= max_hp / 2 and _pages_alive() == 0:
		_shield_rebuilt = true
		_warn_and_rebuild_shield()
	if not _recover_half_dropped and hp > 0 and hp <= max_hp / 2:
		_recover_half_dropped = true
		arena_drop_recover.call_deferred()

func arena_drop_recover() -> void:
	if not is_instance_valid(self):
		return
	var walker := get_parent()
	while walker != null and not walker.has_method("spawn_boss_recover"):
		walker = walker.get_parent()
	if walker != null:
		walker.call_deferred("spawn_boss_recover", global_position)

func _warn_and_rebuild_shield() -> void:
	Fx.ring(global_position, Color(0.8, 0.65, 1.0), radius, radius + 140.0, 0.6, 5.0, true)
	Fx.ring(global_position, Color(1, 1, 1, 0.8), radius, radius + 70.0, 0.45, 3.0)
	Fx.text(global_position + Vector2(0, -radius - 24.0), "SHIELD RESTORING", Color(0.85, 0.7, 1.0), 16)
	Sfx.play("charge", 0.9, -4.0)
	Sfx.haptic(40)
	var tree := get_tree()
	if tree == null:
		return
	await tree.create_timer(0.8).timeout
	if not is_instance_valid(self):
		return
	for i in 6:
		if _pages_alive() >= 6:
			break
		var pg := PageNode.new()
		pg.boss = self
		pg.orbit_idx = i % 4
		pg.position = global_position + Vector2.from_angle(TAU * i / 6.0) * 90.0
		get_parent().call_deferred("add_child", pg)
	Fx.ring(global_position, Color(0.8, 0.65, 1.0), radius + 20.0, radius + 90.0, 0.4, 3.0, true)

func _split_into_minis() -> void:
	split_done = true
	var fragment_hp := maxi(6, int(max_hp * 0.18))
	Fx.flash(Color(1, 1, 1), 0.4, 0.4)
	Fx.burst(global_position, col, 2.4, 12)
	Fx.ring(global_position, col, 10.0, 220.0, 0.6, 5.0)
	Fx.shake(0.7)
	Sfx.play("explode_big", 0.9, -2.0)
	var minis: Array = []
	for i in 2:
		var m := RootBoss.new()
		m.mini = true
		m._mini_side = -1.0 if i == 0 else 1.0
		m.set_meta("mini_slot", i)
		m.split_done = true
		m.boss_index = boss_index
		m.configure(1.0, false)
		m.hp = fragment_hp
		m.max_hp = fragment_hp
		m.position = global_position + Vector2(-40.0 + 80.0 * i, 20.0)
		m.col = col.lerp(Color(1, 1, 1), 0.25)
		minis.append(m)
		get_parent().call_deferred("add_child", m)
	split_started.emit(minis)
	var arena_node: Node = null
	if get_tree() != null:
		arena_node = get_tree().get_first_node_in_group("arena")
	if arena_node == null:
		var walker := get_parent()
		while walker != null and arena_node == null:
			if walker.has_method("spawn_boss_recover"):
				arena_node = walker
			walker = walker.get_parent()
	if arena_node != null:
		arena_node.call_deferred("spawn_boss_recover", global_position)
	_split_silent = true
	died.emit(self)
	queue_free()

var _split_silent := false

func die() -> void:
	died.emit(self)
	var pos := global_position
	var c := col
	Fx.slowmo(0.18, 0.9)
	Fx.flash(Color(1, 1, 1), 0.55, 0.5)
	Fx.burst(pos, c, 3.4, 16)
	Fx.ring(pos, c, 10.0, 320.0, 0.8, 6.0)
	Fx.ring(pos, Color(1, 1, 1, 0.9), 10.0, 200.0, 0.5, 4.0)
	Fx.shards(pos, c, 14, 460.0)
	Fx.shake(1.0)
	Fx.zoom_punch(0.09)
	Sfx.play("explode_big", 0.7, 0.0)
	Sfx.play("gameover", 1.6, -6.0)
	for p in get_tree().get_nodes_in_group("page"):
		if is_instance_valid(p):
			p.queue_free()
	queue_free()

func _draw() -> void:
	var c := _flash_col(col)
	if _phase_flash > 0.0:
		c = c.lerp(Color(1, 1, 1), clampf(_phase_flash, 0.0, 1.0))
	var r := radius
	match kind:
		2:
			_draw_segfault(c, r)
		3:
			_draw_bluescreen(c, r)
		4:
			_draw_pagefault(c, r)
		_:
			_draw_root(c, r)
	_draw_desperation_telegraph()

func _draw_desperation_telegraph() -> void:
	if not desperation_active:
		return
	var pulse := 0.65 + 0.35 * absf(sin(t * 9.0))
	var border := Color(1.0, 1.0, 1.0, pulse)
	draw_arc(Vector2.ZERO, radius + 17.0, 0.0, TAU, 48, border, 5.0, true)
	for i in 8:
		var start := TAU * float(i) / 8.0 + t * 0.35
		draw_line(Vector2.from_angle(start) * (radius + 20.0), Vector2.from_angle(start + 0.16) * (radius + 30.0), border, 3.0)
	if desperation_transition_t > 0.0:
		var transition_alpha := clampf(desperation_transition_t / DESPERATION_TRANSITION_DURATION, 0.0, 1.0)
		draw_arc(Vector2.ZERO, radius + 25.0, -PI / 2.0, -PI / 2.0 + TAU * transition_alpha, 32, Color.WHITE, 3.0, true)

func _draw_root(c: Color, r: float) -> void:
	GlyphLib.draw_glyph(self, "root", Vector2.ZERO, r, _glyph_color(c), t)
	var look := aim_at_player().angle()
	var eye := Vector2.from_angle(look) * r * 0.1
	if _exposed > 0.0:
		var ea := 0.6 + 0.4 * sin(t * 20.0)
		draw_circle(eye, r * 0.22, Color(1, 1, 1, 0.35 * ea))
		draw_circle(eye, r * 0.18, Color(1, 1, 1, ea))
		draw_circle(eye, r * 0.09, Color(1, 0.3, 0.4, 0.9))
	else:
		draw_circle(eye, r * 0.16, c)
		draw_circle(eye, r * 0.07, Color(1, 1, 1, 0.95))
	var hp_frac := float(hp) / float(max_hp)
	draw_arc(Vector2.ZERO, r + 10.0, -PI / 2, -PI / 2 + TAU * hp_frac, 48, Color(c.r, c.g, c.b, 0.55), 2.5, true)
	if mini and act == Act.LANCE_WIND:
		var la := 0.3 + 0.45 * absf(sin(t * 28.0))
		draw_line(Vector2.ZERO, _lance_dir.rotated(-rotation) * 760.0, Color(1, 0.6, 0.24, la), 2.5)
		draw_line(Vector2.ZERO, _lance_dir.rotated(-rotation) * 760.0, Color(1, 1, 1, la * 0.4), 1.0)

func _draw_segfault(c: Color, r: float) -> void:
	var off := _glitch_off
	GlyphLib.draw_glyph(self, "segfault", Vector2.ZERO, r, _glyph_color(c), t)
	var blink := fmod(t, 1.0) < 0.12
	if blink:
		draw_circle(Vector2.ZERO, r * 0.18, Color(1, 1, 1, 0.8))
	else:
		draw_circle(Vector2.ZERO, r * 0.14, c)
	for i in 3:
		var ly := -r * 0.5 + i * r * 0.5
		draw_line(Vector2(-r, ly + off.y * 0.5), Vector2(r, ly + off.y * 0.5), Color(c.r, c.g, c.b, 0.12), 1.0)
	var hp_frac := float(hp) / float(max_hp)
	draw_arc(Vector2.ZERO, r + 10.0, -PI / 2, -PI / 2 + TAU * hp_frac, 48, Color(c.r, c.g, c.b, 0.55), 2.5, true)
	if act == Act.TELEPORT_OUT or act == Act.TELEPORT_IN:
		draw_arc(Vector2.ZERO, r * (1.4 - 0.4 * modulate.a), 0, TAU, 32, Color(1, 1, 1, 0.5), 2.0, true)
	if act == Act.LANCE_WIND:
		var la := 0.3 + 0.45 * absf(sin(t * 28.0))
		draw_line(Vector2.ZERO, _lance_dir.rotated(-rotation) * 860.0, Color(1, 0.6, 0.24, la), 2.5)
		draw_line(Vector2.ZERO, _lance_dir.rotated(-rotation) * 860.0, Color(1, 1, 1, la * 0.4), 1.0)

func _draw_bluescreen(c: Color, r: float) -> void:
	GlyphLib.draw_glyph(self, "bluescreen", Vector2.ZERO, r, _glyph_color(c), t)
	var rect := Rect2(-r * 0.92, -r * 0.6624, r * 1.84, r * 1.3248)
	var eye_h := r * 0.16
	var eye_w := r * 0.07
	var eye_y := -r * 0.18
	draw_rect(Rect2(Vector2(-r * 0.22 - eye_w * 0.5, eye_y - eye_h * 0.5), Vector2(eye_w, eye_h)), Color(1, 1, 1, 0.95))
	draw_rect(Rect2(Vector2(r * 0.22 - eye_w * 0.5, eye_y - eye_h * 0.5), Vector2(eye_w, eye_h)), Color(1, 1, 1, 0.95))
	draw_arc(Vector2(0, r * 0.22), r * 0.2, PI * 1.15, PI * 1.85, 16, Color(1, 1, 1, 0.95), 3.5, true)
	if act == Act.FREEZE_WIND:
		var a := 0.3 + 0.5 * absf(sin(t * 24.0))
		draw_rect(rect.grow(6.0 + 6.0 * absf(sin(t * 12.0))), Color(0.4, 0.6, 1.0, a), false, 2.5)
	var hp_frac := float(hp) / float(max_hp)
	draw_arc(Vector2.ZERO, r + 10.0, -PI / 2, -PI / 2 + TAU * hp_frac, 48, Color(c.r, c.g, c.b, 0.55), 2.5, true)

func _draw_pagefault(c: Color, r: float) -> void:
	var pages := _pages_alive()
	GlyphLib.draw_glyph(self, "pagefault", Vector2.ZERO, r, _glyph_color(c), t)
	if pages > 0:
		draw_arc(Vector2.ZERO, r * 0.55, 0, TAU, 32, Color(0.8, 0.65, 1.0, 0.5 + 0.3 * sin(t * 6.0)), 3.0, true)
		draw_string(Fx.mono_font, Vector2(-14, 6), "%d" % pages, HORIZONTAL_ALIGNMENT_CENTER, 28, 20, Color(1, 1, 1, 0.9))
	else:
		var look := aim_at_player().angle()
		var eye := Vector2.from_angle(look) * r * 0.08
		draw_circle(eye, r * 0.14, c)
		draw_circle(eye, r * 0.06, Color(1, 1, 1, 0.95))
	var hp_frac := float(hp) / float(max_hp)
	draw_arc(Vector2.ZERO, r + 10.0, -PI / 2, -PI / 2 + TAU * hp_frac, 48, Color(c.r, c.g, c.b, 0.55), 2.5, true)

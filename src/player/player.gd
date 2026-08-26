class_name Player
extends Area2D

signal hp_changed(hp: int, max_hp: int)
signal meter_changed(v: float, ready_flag: bool)
signal overclock_changed(active: bool)
signal died

var hp := Balance.PLAYER_MAX_HP
var max_hp := Balance.PLAYER_MAX_HP
var vel := Vector2.ZERO
var aim := Vector2.RIGHT
var fire_cd := 0.0
var dash_cd := 0.0
var dash_t := 0.0
var invuln := 0.0
var meter := 0.0
var oc_ready := false
var overclock_active := false
var oc_t := 0.0
var pickup_streak := 0
var streak_t := 0.0
var dead := false
var touch_move := Vector2.ZERO
var touch_fire := false
var touch_aim := Vector2.ZERO

var _ghost_cd := 0.0
var _aura: Node2D
var _trail: CPUParticles2D
var _muzzle_t := 0.0
var touch_mode := false
var aim_assist_dir := Vector2.ZERO
var slow_factor := 1.0
var _freeze_t := 0.0
var lockon_active := false
var lockon_target: Node2D
var _lockon_pulse := 0.0
var dash_id := 0
var _static_tick := 0.0
var _ext_count := 0
var prog: Dictionary = {}
var dash_charges := 1
var dash_recharge_t := 0.0
var shield_ready := false
var shield_meter := 0.0
var second_wind_used := false
var thorns_cd := 0.0
var scrap_count := 0

func _scrap_threshold() -> int:
	return 25 - 5 * Game.patch_level("scrapdiet")

func _register_scrap_overflow() -> void:
	if Game.patch_level("scrapdiet") <= 0 or Game.mode == "onehp":
		return
	scrap_count += 1
	if scrap_count >= _scrap_threshold():
		scrap_count = 0
		heal(1)
		Game.register_heal("scrap")
		Fx.text(global_position + Vector2(0, -30), "SCRAP +1", Color(1.0, 0.75, 0.4), 14)
		Sfx.play("ready", 1.1, -6.0)

func _ready() -> void:
	touch_mode = DisplayServer.is_touchscreen_available() or OS.get_environment("KP_FORCE_TOUCH") != ""
	prog = Game.program_def()
	dash_charges = int(prog.get("dash_charges", 1))
	shield_ready = bool(prog.get("shield_mode", false))
	max_hp = 1 if Game.mode == "onehp" else int(prog.get("hp", Balance.PLAYER_MAX_HP))
	hp = max_hp
	add_to_group("player")
	collision_layer = Balance.LAYER_PLAYER
	collision_mask = Balance.LAYER_ENEMY | Balance.LAYER_EORB
	monitoring = true
	monitorable = false
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = Balance.PLAYER_RADIUS
	cs.shape = sh
	add_child(cs)
	var glow := Fx.make_glow(16.0, Balance.COL_PLAYER)
	glow.modulate.a = 0.62
	add_child(glow)
	_aura = AuraRing.new()
	_aura.visible = false
	add_child(_aura)
	_trail = CPUParticles2D.new()
	_trail.amount = 26
	_trail.lifetime = 0.4
	_trail.local_coords = false
	_trail.gravity = Vector2.ZERO
	_trail.initial_velocity_min = 4.0
	_trail.initial_velocity_max = 14.0
	_trail.scale_amount_min = 1.5
	_trail.scale_amount_max = 3.2
	_trail.scale_amount_curve = _fade_curve()
	_trail.color = Balance.COL_PLAYER
	_trail.material = Fx.add_material()
	_trail.emitting = false
	add_child(_trail)
	z_index = 15
	area_entered.connect(_on_area_entered)

func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var bd := 1e9
	for e in EnemyBase.shared_list:
		if is_instance_valid(e):
			var d: float = global_position.distance_squared_to(e.global_position)
			if d < bd:
				bd = d
				best = e
	return best

func _fade_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	return c

func _physics_process(delta: float) -> void:
	if dead:
		return
	var input_vec := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if touch_move.length() > 0.15:
		input_vec = touch_move.limit_length(1.0)
	var target_speed := Balance.PLAYER_SPEED * (1.15 if overclock_active else 1.0) * slow_factor
	target_speed *= 1.0 + 0.12 * Game.patch_level("light")
	target_speed *= float(prog.get("speed_mul", 1.0))
	if dash_t > 0.0:
		dash_t -= delta
		_ghost_cd -= delta
		if _ghost_cd <= 0.0:
			_ghost_cd = 0.035
			Fx.ghost(global_position, rotation, _ship_draw, Balance.COL_PLAYER, 0.26, 1.0)
		if Game.patch_level("mdash") > 0 and get_tree() != null:
			var field := get_tree().get_first_node_in_group("mote_field")
			if field != null:
				field.magnet_all_near(global_position, 160.0)
		if Game.patch_level("pdash") > 0:
			for e in EnemyBase.shared_list:
				if is_instance_valid(e) and e.last_pdash_id != dash_id and global_position.distance_to(e.global_position) < Balance.PLAYER_RADIUS + e.radius + 10.0:
					e.last_pdash_id = dash_id
					e.take_hit(2, global_position)
					Fx.sparks(e.global_position, Balance.COL_PLAYER_HOT, 6, 200.0, 0.3, 2.5)
	else:
		if input_vec.length() > 0.1:
			vel = vel.move_toward(input_vec * target_speed, Balance.PLAYER_ACCEL * delta)
		else:
			vel = vel.move_toward(Vector2.ZERO, Balance.PLAYER_FRICTION * delta)
	position += vel * delta
	var r := Balance.arena_rect()
	position.x = clampf(position.x, r.position.x + Balance.PLAYER_RADIUS, r.end.x - Balance.PLAYER_RADIUS)
	position.y = clampf(position.y, r.position.y + Balance.PLAYER_RADIUS, r.end.y - Balance.PLAYER_RADIUS)
	var manual_touch_aim := touch_aim.length() > 0.2
	var desktop := DisplayServer.get_name() == "windows" or DisplayServer.get_name() == "x11" or DisplayServer.get_name() == "macos"
	if manual_touch_aim:
		aim = touch_aim.normalized() * 100.0
	elif lockon_active:
		var tgt := _nearest_enemy()
		lockon_target = tgt
		if tgt != null and is_instance_valid(tgt):
			aim = (tgt.global_position - global_position)
			if _lockon_pulse <= 0.0:
				_lockon_pulse = 0.18
				Fx.ring(tgt.global_position, Color(1, 0.4, 0.5), 14.0, 24.0, 0.18, 2.0)
	elif touch_mode and not desktop:
		# Touchscreen without active aim: keep last heading, never chase a stale pointer.
		aim = Vector2.ZERO
		lockon_target = null
	else:
		aim = get_global_mouse_position() - global_position
		lockon_target = null
	if aim.length() > 4.0:
		rotation = lerp_angle(rotation, aim.angle(), 18.0 * delta)
	aim_assist_dir = Vector2.from_angle(rotation) if manual_touch_aim else Vector2.ZERO
	if dash_cd > 0.0:
		dash_cd -= delta
	if dash_charges > 1 and dash_recharge_t > 0.0:
		dash_recharge_t -= delta
	if thorns_cd > 0.0:
		thorns_cd -= delta
	if invuln > 0.0:
		invuln -= delta
		visible = fmod(invuln, 0.14) > 0.055 or invuln <= 0.0
	else:
		visible = true
	if fire_cd > 0.0:
		fire_cd -= delta
	if _muzzle_t > 0.0:
		_muzzle_t -= delta
	var want_fire := Input.is_action_pressed("fire") or touch_fire
	if want_fire and fire_cd <= 0.0:
		_shoot()
	if Input.is_action_just_pressed("dash"):
		request_dash(input_vec)
	if Input.is_action_just_pressed("overclock"):
		try_overclock()
	if overclock_active:
		oc_t -= delta
		meter = Balance.OC_METER_MAX * maxf(oc_t, 0.0) / Balance.OC_DURATION
		meter_changed.emit(meter, false)
		if oc_t <= 0.0:
			overclock_active = false
			_aura.visible = false
			meter = 0.0
			meter_changed.emit(0.0, false)
			overclock_changed.emit(false)
	if _lockon_pulse > 0.0:
		_lockon_pulse -= delta
	if _freeze_t > 0.0:
		_freeze_t -= delta
		if _freeze_t <= 0.0:
			slow_factor = 1.0
	if streak_t > 0.0:
		streak_t -= delta
		if streak_t <= 0.0:
			pickup_streak = 0
	var sf := Game.patch_level("staticf")
	if sf > 0:
		_static_tick -= delta
		if _static_tick <= 0.0:
			_static_tick = 0.4
			for e in EnemyBase.shared_list:
				if is_instance_valid(e) and global_position.distance_to(e.global_position) < 70.0 + 12.0 * sf:
					e.take_hit(1, global_position)
					Fx.sparks(e.global_position, Balance.COL_PLAYER, 3, 100.0, 0.2, 2.0)
	for z in get_tree().get_nodes_in_group("corruption"):
		if z.can_hurt() and global_position.distance_to(z.global_position) < z.radius:
			z.hurt_cd = 1.2
			take_damage(z.global_position, "CORRUPTION")
			break
	_trail.emitting = vel.length() > 120.0 or dash_t > 0.0
	_trail.color = Balance.COL_PLAYER_HOT if overclock_active else Balance.COL_PLAYER
	queue_redraw()

func magnet_radius() -> float:
	var base := Balance.MOTE_MAGNET_OC if overclock_active else Balance.MOTE_MAGNET
	return base * (1.0 + 0.45 * Game.patch_level("magnet"))

func fire_interval() -> float:
	var rate := Balance.FIRE_RATE_OC if overclock_active else Balance.FIRE_RATE
	rate *= float(prog.get("rate_mul", 1.0))
	rate *= pow(0.9, Game.patch_level("splitshot"))
	if prog.has("close_rate_mul"):
		var nearest: Node2D = _nearest_enemy()
		if nearest != null and is_instance_valid(nearest) and global_position.distance_to(nearest.global_position) < float(prog.get("close_range", 160.0)):
			rate *= float(prog["close_rate_mul"])
	rate *= 1.0 + 0.18 * Game.patch_level("rapid")
	rate *= pow(0.9, Game.patch_level("heavy"))
	return 1.0 / (rate * slow_factor)

func oc_duration() -> float:
	return Balance.OC_DURATION + 2.0 * Game.patch_level("cell")

func _shoot() -> void:
	var fire_cd_len := fire_interval()
	fire_cd = fire_cd_len
	var dir := Vector2.from_angle(rotation)
	var spread := Balance.BULLET_SPREAD
	var b := PlayerBullet.new()
	var bspeed := Balance.BULLET_SPEED * (1.0 + 0.22 * Game.patch_level("threads"))
	var shot_dir := dir.rotated(Game.rng.randf_range(-spread, spread))
	for k in range(1 + Game.patch_level("splitshot")):
		var bullet := PlayerBullet.new()
		var sdir := shot_dir.rotated(0.0 if k == 0 else (0.28 * ceilf(k / 2.0) * (1 if k % 2 == 1 else -1)))
		bullet.setup(global_position + dir * 18.0, sdir, overclock_active)
		bullet.vel = sdir * bspeed
		bullet.life = Balance.BULLET_LIFE * float(prog.get("range_mul", 1.0)) * (1.0 + 0.12 * Game.patch_level("threads"))
		bullet.pierce += Game.patch_level("core")
		bullet.dmg = 1 + int(prog.get("dmg_bonus", 0)) + Game.patch_level("heavy")
		bullet.bounces = Game.patch_level("ricochet")
		get_parent().add_child(bullet)
	vel -= dir * 26.0
	_muzzle_t = 0.06
	Sfx.play("shoot", 1.25 if overclock_active else 1.0, -10.0, 0.07)
	Game.stats["shots"] += 1

func request_dash(input_vec: Vector2) -> void:
	if dead or dash_t > 0.0:
		return
	if dash_charges > 1 and _avail_charges() <= 0:
		return
	if dash_charges <= 1 and dash_cd > 0.0:
		return
	var dir := input_vec
	if dir.length() < 0.2:
		dir = Vector2.from_angle(rotation)
	dir = dir.normalized()
	vel = dir * Balance.DASH_SPEED * (1.0 + 0.12 * Game.patch_level("turbo"))
	dash_id += 1
	dash_t = Balance.DASH_TIME
	dash_cd = Balance.DASH_CD * pow(0.82, Game.patch_level("dash"))
	invuln = maxf(invuln, Balance.DASH_IFRAMES)
	if dash_charges > 1:
		dash_recharge_t = Balance.DASH_CD
	Sfx.play("dash", 1.0, -6.0)
	Fx.ring(global_position, Balance.COL_PLAYER, 6.0, 30.0, 0.25, 2.0)
	Fx.shake(0.08)

func _avail_charges() -> int:
	var n := 1
	if dash_recharge_t <= 0.0:
		n = dash_charges
	else:
		n = maxf(dash_charges - 1.0, 1.0)
	return int(n)

func notify_kill() -> void:
	if Game.patch_level("turbo") > 0 and dash_cd > 0.0:
		dash_cd = maxf(dash_cd - 0.35 * Game.patch_level("turbo"), 0.0)
	if prog.has("kill_dash_refund"):
		dash_cd = minf(dash_cd, dash_cd * (1.0 - float(prog["kill_dash_refund"])))
		if dash_charges > 1 and dash_recharge_t > 0.0:
			dash_recharge_t *= (1.0 - float(prog["kill_dash_refund"]))

func try_overclock() -> void:
	if prog.get("shield_mode", false):
		return
	if oc_ready and not overclock_active and not dead:
		oc_ready = false
		overclock_active = true
		oc_t = oc_duration()
		_aura.visible = true
		overclock_changed.emit(true)
		meter_changed.emit(meter, false)
		Sfx.play("overclock", 1.0, -2.0)
		Fx.flash(Balance.COL_PLAYER, 0.22, 0.35)
		Fx.ring(global_position, Balance.COL_PLAYER_HOT, 10.0, 120.0, 0.45, 4.0)
		Fx.ring(global_position, Balance.COL_PLAYER, 10.0, 200.0, 0.6, 3.0, true)
		Fx.slowmo(0.3, 0.22)
		Fx.shake(0.35)
		Fx.zoom_punch(0.055)

func collect_mote() -> void:
	if dead:
		return
	if shield_ready:
		if not shield_ready_full():
			shield_meter = minf(shield_meter + Balance.MOTE_VALUE, Balance.OC_METER_MAX)
			if shield_meter >= Balance.OC_METER_MAX:
				shield_ready = true
				Sfx.play("ready", 1.0, -4.0)
				Sfx.haptic(25)
				Fx.text(global_position + Vector2(0, -26), "SHIELD READY", Color(0.6, 1.0, 0.8), 13)
			meter_changed.emit(shield_meter, shield_ready)
			return
	if overclock_active:
		Game.add_score(5)
		_register_scrap_overflow()
		return
	pickup_streak += 1
	streak_t = 1.0
	Sfx.play("pickup", 1.0 + minf(pickup_streak, 14) * 0.045, -8.0)
	Sfx.haptic(8)
	if oc_ready:
		Game.add_score(5)
		_register_scrap_overflow()
		return
	meter = minf(meter + Balance.MOTE_VALUE, Balance.OC_METER_MAX)
	if meter >= Balance.OC_METER_MAX:
		oc_ready = true
		Sfx.play("ready", 1.0, -4.0)
		Sfx.haptic(25)
		Fx.text(global_position + Vector2(0, -26), "OVERCLOCK READY", Balance.COL_PLAYER_HOT, 13)
	meter_changed.emit(meter, oc_ready)

func shield_ready_full() -> bool:
	return bool(prog.get("shield_mode", false)) and shield_meter >= Balance.OC_METER_MAX

func apply_freeze(dur: float) -> void:
	if dead:
		return
	_freeze_t = maxf(_freeze_t, dur)
	slow_factor = 0.45

func heal(n: int) -> void:
	hp = mini(hp + n, max_hp)
	hp_changed.emit(hp, max_hp)

func add_max_hp(n: int) -> void:
	max_hp += n
	heal(n)

func add_kill_mote_bonus() -> void:
	if shield_ready:
		if not shield_ready_full():
			shield_meter = minf(shield_meter + Balance.MOTE_KILL_VALUE, Balance.OC_METER_MAX)
			meter_changed.emit(shield_meter, false)
		return
	if overclock_active:
		if oc_t < oc_duration() + 3.0:
			oc_t = minf(oc_t + 0.35, oc_duration() + 3.0)
			_ext_count += 1
			if _ext_count % 3 == 0:
				Fx.text(global_position + Vector2(0, -28), "+0.35s", Balance.COL_PLAYER_HOT, 12)
		return
	meter = minf(meter + Balance.MOTE_KILL_VALUE, Balance.OC_METER_MAX)
	if meter >= Balance.OC_METER_MAX and not oc_ready:
		oc_ready = true
		Sfx.play("ready", 1.0, -4.0)
	meter_changed.emit(meter, oc_ready)

func _on_area_entered(a: Area2D) -> void:
	if dead:
		return
	if a is EnemyOrb:
		a.pop()
		take_damage(a.global_position, "CORRUPTED ORB")
	elif a is EnemyBase:
		var push := (global_position - a.global_position).normalized() * 240.0
		vel += push
		a.kb += -push * 0.5
		if Game.patch_level("thorns") > 0 and thorns_cd <= 0.0:
			thorns_cd = 0.6
			a.take_hit(1, global_position)
			Fx.sparks(a.global_position, Balance.COL_PLAYER_HOT, 4, 140.0, 0.25, 2.0)
		take_damage(a.global_position, a.display_name)

func take_damage(from: Vector2, killer := "DAEMON") -> void:
	if dead or invuln > 0.0 or dash_t > 0.0:
		return
	if bool(prog.get("shield_mode", false)) and shield_ready:
		shield_ready = false
		shield_meter = 0.0
		invuln = maxf(invuln, 0.8)
		Sfx.play("hit", 1.2, -4.0)
		Fx.ring(global_position, Color(0.6, 1.0, 0.8), 8.0, 60.0, 0.35, 3.0)
		Fx.text(global_position + Vector2(0, -26), "SHIELD DOWN", Color(0.6, 1.0, 0.8), 13)
		Sfx.haptic(30)
		meter_changed.emit(0.0, false)
		return
	hp -= 1
	Game.stats["damage"] += 1
	Game.stats["killer"] = killer
	Sfx.haptic(45)
	Game.break_combo()
	invuln = Balance.HURT_IFRAMES
	vel += (global_position - from).normalized() * 330.0
	Sfx.play("hurt", 1.0, -2.0)
	Fx.shake(0.55)
	Fx.hitstop(80.0)
	Fx.flash(Balance.COL_DANGER, 0.16, 0.3)
	Fx.sparks(global_position, Balance.COL_DANGER, 12, 300.0, 0.45, 3.0)
	Fx.ring(global_position, Balance.COL_DANGER, 6.0, 60.0, 0.3, 3.0)
	get_tree().call_group("overlay", "hurt_pulse")
	hp_changed.emit(hp, max_hp)
	if hp <= 0:
		if Game.patch_level("secondwind") > 0 and not second_wind_used and Game.mode != "onehp":
			second_wind_used = true
			hp = 1
			invuln = maxf(invuln, 2.0)
			Sfx.play("ready", 0.9, -2.0)
			Fx.flash(Color(0.6, 1.0, 0.8), 0.3, 0.5)
			Fx.ring(global_position, Color(0.6, 1.0, 0.8), 10.0, 140.0, 0.5, 4.0)
			Fx.text(global_position + Vector2(0, -30), "SECOND WIND", Color(0.6, 1.0, 0.8), 16)
			Sfx.haptic(60)
			hp_changed.emit(hp, max_hp)
			return
		_die()

func _die() -> void:
	dead = true
	visible = true
	remove_from_group("player")
	_trail.emitting = false
	_aura.visible = false
	Fx.burst(global_position, Balance.COL_PLAYER, 2.6, 12)
	Fx.ring(global_position, Balance.COL_PLAYER_HOT, 8.0, 180.0, 0.6, 4.0)
	Fx.slowmo(0.22, 1.1)
	Fx.shake(0.9)
	Sfx.play("explode_big", 0.85, 0.0)
	died.emit()

func _ship_draw(node: Node2D, c: Color) -> void:
	var r := Balance.PLAYER_RADIUS
	var pts := PackedVector2Array([
		Vector2(r * 1.5, 0), Vector2(-r, r), Vector2(-r * 0.45, 0), Vector2(-r, -r)
	])
	node.draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.3))
	node.draw_polyline(pts + PackedVector2Array([pts[0]]), c, 2.2, true)
	node.draw_circle(Vector2(r * 0.25, 0), r * 0.32, c)

func _draw() -> void:
	var c := Balance.COL_PLAYER_HOT if overclock_active else Balance.COL_PLAYER
	_ship_draw(self, c)
	if touch_mode and aim_assist_dir.length() > 0.5 and not dead:
		var a := aim_assist_dir
		for i in 4:
			var p0 := a * (22.0 + i * 14.0)
			var p1 := a * (30.0 + i * 14.0)
			draw_line(p0, p1, Color(c.r, c.g, c.b, 0.4 - i * 0.07), 2.0)
	if _muzzle_t > 0.0:
		var m := 1.0 + 9.0 * (_muzzle_t / 0.06)
		draw_circle(Vector2(20.0, 0), 3.2 * m * 0.4, Color(1, 1, 1, 0.9 * _muzzle_t / 0.06))
	if invuln > 0.0 and not dead:
		draw_arc(Vector2.ZERO, Balance.PLAYER_RADIUS + 6.0, 0, TAU, 24, Color(c.r, c.g, c.b, 0.35), 1.5, true)

class AuraRing extends Node2D:
	var t := 0.0
	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
	func _draw() -> void:
		var a := 0.5 + 0.3 * sin(t * 9.0)
		var col := Balance.COL_PLAYER_HOT
		col.a = a
		var segs := 5
		for i in segs:
			var a0 := t * 2.4 + TAU * i / segs
			draw_arc(Vector2.ZERO, 24.0, a0, a0 + TAU / segs * 0.5, 8, col, 2.0, true)
		col.a = a * 0.5
		draw_arc(Vector2.ZERO, 30.0 + 3.0 * sin(t * 5.0), 0, TAU, 40, col, 1.2, true)

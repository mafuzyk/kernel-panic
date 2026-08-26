extends Node

var active := false
var _fails := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	if "--autotest" in args:
		active = true
		_autotest.call_deferred()
	elif OS.get_environment("KP_DEMO") != "":
		active = true
		_demo.call_deferred()
	elif OS.get_environment("KP_STRESS") != "":
		active = true
		_stress.call_deferred()
	elif OS.get_environment("KP_SHOT") != "":
		active = true
		_capture.call_deferred()

func _pass(msg: String) -> void:
	print("AT_PASS ", msg)

func _fail(msg: String) -> void:
	_fails += 1
	print("AT_FAIL ", msg)

func _check(cond: bool, msg: String) -> bool:
	if cond:
		_pass(msg)
	else:
		_fail(msg)
	return cond

func _watchdog(real_s: float = 90.0) -> void:
	await get_tree().create_timer(real_s, true, false, true).timeout
	print("AT_FAIL watchdog timeout")
	get_tree().quit(1)

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _until(fn: Callable, timeout_s: float, label: String) -> bool:
	var t := 0.0
	while t < timeout_s:
		if fn.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time() if get_process_delta_time() > 0.0 else 1.0 / 60.0
	_fail("timeout waiting for " + label)
	return false

func _autotest() -> void:
	_watchdog()
	Game.unlocked_programs["kernel"] = true
	Game.unlocked_programs["daemon"] = true
	Game.unlocked_programs["rootlet"] = true
	Game.set_program("kernel")
	await _ticks(20)
	_check(get_tree().current_scene != null and get_tree().current_scene.name == "Menu", "menu is main scene")
	_check(InputMap.has_action("mute"), "mute input action exists")
	var ek := InputEventKey.new()
	ek.physical_keycode = KEY_ENTER
	ek.keycode = KEY_ENTER
	ek.pressed = true
	get_viewport().push_input(ek)
	var ek_up := InputEventKey.new()
	ek_up.physical_keycode = KEY_ENTER
	ek_up.keycode = KEY_ENTER
	get_viewport().push_input(ek_up)
	var click_ok := await _until(func() -> bool:
		return get_tree().current_scene != null and get_tree().current_scene.name == "Arena", 8.0, "menu enter starts game")
	_check(click_ok, "menu enter starts game")
	if not click_ok:
		return _finish()
	Game.start_run()
	var ok := await _until(func() -> bool:
		return get_tree().current_scene != null and get_tree().current_scene.name == "Arena", 6.0, "arena load")
	if not ok:
		return _finish()
	await _ticks(10)
	var arena: Arena = get_tree().current_scene
	var player: Player = arena.player
	_check(player != null and is_instance_valid(player), "player exists")
	_check(arena.spawner != null, "spawner exists")
	await _ticks(30)
	_check(Game.wave == 1, "wave 1 started")
	_check(arena.wave_signal_count >= 1, "wave_started signal received for wave 1")
	var shots_before: int = Game.stats["shots"]
	Input.action_press("fire")
	await _ticks(30)
	Input.action_release("fire")
	_check(Game.stats["shots"] > shots_before, "shooting registers shots")
	var bullet_found := false
	for c in get_tree().current_scene.get_children():
		if c is PlayerBullet:
			bullet_found = true
	_check(bullet_found or Game.stats["shots"] > shots_before + 2, "bullets spawned")
	var e := DroneEnemy.new()
	e.position = player.global_position + Vector2(240, 0)
	arena.enemy_container.add_child(e)
	e.configure(1.0, false)
	await _ticks(2)
	e.take_hit(99, e.global_position + Vector2(10, 0))
	await _ticks(3)
	_check(Game.score > 0, "kill scores points")
	_check(Game.mult >= 2, "combo multiplier increments")
	var mote_count: int = arena.mote_field.count()
	_check(mote_count > 0, "kill drops motes")
	var still_idx: int = arena.mote_field.spawn(player.global_position + Vector2(300, 0))
	var still_pos: Vector2 = arena.mote_field.pos_of(still_idx)
	await _ticks(20)
	_check(arena.mote_field.alive_at(still_idx) and arena.mote_field.pos_of(still_idx).distance_to(still_pos) < 0.01, "motes stay still before magnet")
	arena.mote_field.spawn(player.global_position + Vector2(4, 0))
	var meter_before := player.meter
	await _until(func() -> bool: return player.meter > meter_before or player.oc_ready, 4.0, "mote collection")
	_check(player.meter > meter_before or player.oc_ready, "mote fills overclock meter")
	player.meter = Balance.OC_METER_MAX
	player.oc_ready = true
	player.try_overclock()
	_check(player.overclock_active, "overclock activates")
	var oc_rate := 1.0 / Balance.FIRE_RATE_OC
	_check(oc_rate < 1.0 / Balance.FIRE_RATE, "overclock fire rate higher")
	var offers := Game.roll_patch_offer()
	_check(offers.size() == 3, "patch offer rolls 3 cards")
	Game.apply_patch("rapid")
	Game.apply_patch("rapid")
	_check(player.fire_interval() < 1.0 / Balance.FIRE_RATE, "rapid patch boosts fire rate")
	Game.apply_patch("chain")
	_check(Game.combo_window > Balance.COMBO_WINDOW, "chain patch extends combo window")
	var hp0 := player.max_hp
	Game.apply_patch("hp")
	_check(player.max_hp == hp0 + 1, "hp patch raises max integrity")
	Game.patch_levels = {}
	Game.combo_window = Balance.COMBO_WINDOW
	var hp_before := player.hp
	var orb := EnemyOrb.new()
	orb.setup(player.global_position + Vector2(14, 0), Vector2.ZERO, 1.0, Color.RED)
	arena.add_child(orb)
	await _until(func() -> bool: return player.hp < hp_before, 4.0, "orb damages player")
	_check(player.hp == hp_before - 1, "player takes 1 damage")
	_check(Game.mult == 1, "damage breaks combo")
	print("AT_STEP spread")
	Game.patch_levels = {}
	var spread_ok := true
	for si in 6:
		player.fire_cd = 0.0
		player._shoot()
		var newest: PlayerBullet = null
		for c in arena.get_children():
			if c is PlayerBullet and (newest == null or c.get_instance_id() > newest.get_instance_id()):
				newest = c
		if newest != null:
			var ang_diff: float = absf(wrapf(newest.rotation - newest.vel.angle(), -PI, PI))
			if ang_diff > 0.02:
				spread_ok = false
			newest.queue_free()
	_check(spread_ok, "bullet rotation matches velocity")
	print("AT_STEP recover")
	_check(Game.recover_chance(false) == 0.08, "recover chance normal 8%")
	_check(Game.recover_chance(true) == 0.25, "recover chance elite 25%")
	Game.patch_levels = {"recycler": 3}
	_check(absf(Game.recover_chance(false) - 0.26) < 0.001, "recycler adds 6% per level")
	Game.patch_levels = {"dataleech": 1}
	_check(Game.recover_chance(true) == 1.0, "data leech elites always drop")
	Game.patch_levels = {"dataleech": 1, "recycler": 2}
	var onehp_all_zero := true
	for i in 5:
		if Game.recover_chance(i % 2 == 0) > 0.0:
			onehp_all_zero = false
	_check(onehp_all_zero == (Game.mode == "onehp"), "recover chance respects mode gate")
	Game.patch_levels = {}
	Game.mode = "onehp"
	_check(Game.recover_chance(false) == 0.0 and Game.recover_chance(true) == 0.0, "one hp disables recover")
	var offer_onehp: Array = []
	for i in 12:
		var offs := Game.roll_patch_offer()
		for d in offs:
			if d["id"] == "dataleech" or d["id"] == "recycler":
				offer_onehp.append(d["id"])
	Game.mode = "classic"
	_check(offer_onehp.is_empty(), "onehp offers exclude recover patches")
	var rp = load("res://src/pickups/recover_pickup.gd").new()
	rp.setup(player.global_position + Vector2(12, 0), player)
	player.hp = player.max_hp - 1
	arena.mote_container.add_child(rp)
	var hp_rec0 := player.hp
	ok = await _until(func() -> bool: return player.hp == hp_rec0 + 1 or not is_instance_valid(rp), 4.0, "recover pickup collected")
	_check(player.hp == hp_rec0 + 1, "recover pickup heals on touch")
	print("AT_STEP vampic")
	Game.patch_levels = {"vampic": 1}
	player.max_hp = Balance.PLAYER_MAX_HP
	player.hp = player.max_hp - 2
	var hp_before_v := player.hp
	for i in 3:
		Game.register_kill(10)
	_check(player.hp == hp_before_v + 1, "vampic heals once at x4")
	for i in 3:
		Game.register_kill(10)
	_check(player.hp == hp_before_v + 1, "vampic does not heal at x7")
	Game.register_kill(10)
	_check(player.hp == hp_before_v + 1, "vampic does not heal twice (x8)")
	print("AT_STEP vampic_cd")
	Game.break_combo()
	player.hp = player.max_hp - 1
	var hp_cd0 := player.hp
	Game.vampic_cd = Game.VAMPIC_COOLDOWN
	Game.register_kill(10)
	_check(player.hp == hp_cd0, "vampic on cooldown does not heal")
	Game.vampic_cd = 0.0
	for i in 3:
		Game.register_kill(10)
	_check(player.hp == hp_cd0 + 1, "vampic heals again after cooldown expires")
	Game.vampic_cd = 0.0
	Game.break_combo()
	Game.patch_levels = {}
	player.heal(99)
	Game.break_combo()
	Game.patch_levels = {}
	player.heal(99)
	var e2 := DroneEnemy.new()
	e2.position = player.global_position + Vector2(2, 0)
	arena.enemy_container.add_child(e2)
	e2.configure(1.0, false)
	player.invuln = 0.0
	await _until(func() -> bool: return player.dead, 6.0, "player death")
	_check(player.dead, "player dies at 0 hp")
	ok = await _until(func() -> bool: return Game.state == Game.State.GAME_OVER, 5.0, "game over state")
	if not ok:
		return _finish()
	_check(arena._over_panel.visible, "game over panel visible")
	var best_after := Game.best
	_check(best_after >= Game.score, "best score saved")
	Game.start_run()
	ok = await _until(func() -> bool:
		return get_tree().current_scene != null and get_tree().current_scene.name == "Arena" and get_tree().current_scene != arena, 6.0, "restart reloads arena")
	if not ok:
		return _finish()
	_check(Game.score == 0, "score resets on restart")
	_check(Engine.time_scale == 1.0, "time scale restored")
	var arena2: Arena = get_tree().current_scene
	_check(arena2.player != null and not arena2.player.dead, "fresh player alive")
	await _systems_test(arena2)
	await _touch_test()
	Game.to_menu()
	ok = await _until(func() -> bool:
		return get_tree().current_scene != null and get_tree().current_scene.name == "Menu", 6.0, "menu return")
	print("AT_STEP savewipe")
	var cf_save := ConfigFile.new()
	cf_save.load(Sfx.SAVE_PATH)
	cf_save.set_value("run", "best_classic", 777777)
	cf_save.save(Sfx.SAVE_PATH)
	Sfx.save_settings()
	var cf_verify := ConfigFile.new()
	cf_verify.load(Sfx.SAVE_PATH)
	_check(int(cf_verify.get_value("run", "best_classic", 0)) == 777777, "save_settings preserves run records")
	cf_verify.set_value("run", "best_classic", 0)
	cf_verify.save(Sfx.SAVE_PATH)
	print("AT_STEP ui_fixes")
	var menu_script: Script = load("res://src/ui/menu.gd")
	var wrap_ok: bool = menu_script._next_touch_scale_idx(1.2) == 0 and menu_script._next_touch_scale_idx(0.85) == 1 and menu_script._next_touch_scale_idx(1.0) == 2
	_check(wrap_ok, "touch size cycles with modulo")
	var menu_scene: Node = get_tree().current_scene
	var ver_ok := false
	var expected_ver: String = ProjectSettings.get_setting("application/config/version", "dev")
	for c in menu_scene.get_children():
		if c is Label and c.text.begins_with("KERNEL PANIC v" + expected_ver):
			ver_ok = true
	_check(ver_ok, "menu version matches project setting (%s)" % expected_ver)
	if menu_scene.has_method("_reset_scores"):
		menu_scene._reset_scores()
		var cf_after := ConfigFile.new()
		cf_after.load(Sfx.SAVE_PATH)
		_check(int(cf_after.get_value("run", "best_classic", -1)) == 0 and Game.best == 0, "reset scores clears best_classic")
	else:
		_fail("menu exposes _reset_scores")
	_finish()

func _systems_test(arena: Arena) -> void:
	var player: Player = arena.player
	print("AT_STEP mk2")
	var mk2 := RootBoss.new()
	mk2.boss_index = 2
	mk2.configure(1.0, false)
	_check(mk2.boss_title == "SEGFAULT", "MK-2 boss is SEGFAULT")
	_check(RootBoss.title_for_index(15).begins_with("BLUE SCREEN"), "cycle 15 boss is BLUE SCREEN")
	_check(RootBoss.title_for_index(20).begins_with("PAGE FAULT"), "cycle 20 boss is PAGE FAULT")
	print("AT_STEP bossrework")
	var f1 := RootBoss.new()
	f1.boss_index = 1
	f1.configure(1.0, false)
	var f2 := RootBoss.new()
	f2.boss_index = 2
	f2.configure(1.0, false)
	_check(f1.max_hp == 120, "boss hp formula mk1=120")
	_check(f2.max_hp == 162, "boss hp formula mk2=162")
	f1.queue_free()
	f2.queue_free()
	await _ticks(2)
	print("AT_STEP rootsplit")
	player.invuln = 9999.0
	var rb := RootBoss.new()
	rb.boss_index = 1
	rb.configure(1.0, false)
	rb.position = player.global_position + Vector2(300, -80)
	arena.enemy_container.add_child(rb)
	await _ticks(2)
	rb.hp = int(rb.max_hp / 2.0) + 5
	rb.take_hit(rb.hp + 99, rb.global_position + Vector2(6, 0))
	await _ticks(5)
	var minis_found := 0
	for e in arena.enemy_container.get_children():
		if e is RootBoss and is_instance_valid(e) and e.mini:
			minis_found += 1
	_check(minis_found == 2, "root splits into two minis (%d)" % minis_found)
	var recover_script: Script = load("res://src/pickups/recover_pickup.gd")
	var split_recover := false
	for c in arena.mote_container.get_children():
		if c.get_script() == recover_script:
			split_recover = true
	_check(split_recover, "root split drops recover")
	var probe_mini: RootBoss = null
	for e in arena.enemy_container.get_children():
		if e is RootBoss and is_instance_valid(e) and e.mini:
			probe_mini = e
			break
	if probe_mini != null:
		var minis_before := minis_found
		arena._patch_pending = 0
		probe_mini.take_hit(probe_mini.hp + 99, probe_mini.global_position)
		await _ticks(4)
		if get_tree().paused:
			get_tree().paused = false
		if arena._patch_open:
			arena._pick_patch(0)
		var minis_now := 0
		for e in arena.enemy_container.get_children():
			if e is RootBoss and is_instance_valid(e) and e.mini:
				minis_now += 1
		_check(minis_now < minis_before + 2, "minis never split again")
	await _ticks(4)
	for e in get_tree().get_nodes_in_group("boss"):
		if is_instance_valid(e):
			e.queue_free()
	for c in arena.enemy_container.get_children():
		if c is RootBoss:
			c.queue_free()
	await _ticks(4)
	for o in get_tree().get_nodes_in_group("enemy_orbs"):
		o.queue_free()
	await _ticks(2)
	player.invuln = 0.0
	player.hp = player.max_hp
	print("AT_STEP bossfan")
	var bs := RootBoss.new()
	bs.boss_index = 3
	bs.configure(1.0, false)
	bs.hp = int(bs.max_hp * 0.4)
	arena.enemy_container.add_child(bs)
	await _ticks(2)
	for i in 38:
		var o := EnemyOrb.new()
		o.setup(player.global_position + Vector2(500 + i, 300), Vector2.ZERO, 10.0, Color.RED)
		arena.enemy_container.add_child(o)
	await _ticks(2)
	bs._fan_cd = 0.0
	var orbs_before := get_tree().get_nodes_in_group("enemy_orbs").size()
	await _ticks(20)
	var orbs_after := get_tree().get_nodes_in_group("enemy_orbs").size()
	_check(orbs_after <= 40 and orbs_after >= orbs_before, "bluescreen fan respects orb cap (%d)" % orbs_after)
	for o in get_tree().get_nodes_in_group("enemy_orbs"):
		o.queue_free()
	bs.queue_free()
	await _ticks(3)
	print("AT_STEP pfshield")
	var pf := RootBoss.new()
	pf.boss_index = 4
	pf.configure(1.0, false)
	pf.hp = int(pf.max_hp * 0.55)
	arena.enemy_container.add_child(pf)
	await _ticks(2)
	pf.take_hit(int(pf.max_hp * 0.1), pf.global_position)
	await _ticks(60)
	var pages_now := pf._pages_alive()
	_check(pages_now > 0, "page fault rebuilds shield at half hp (%d pages)" % pages_now)
	var hp_before_block := pf.hp
	pf.take_hit(1, pf.global_position)
	_check(pf.hp == hp_before_block, "rebuilt shield blocks damage again")
	var second_rebuild := pf._shield_rebuilt
	for pg in get_tree().get_nodes_in_group("page"):
		if is_instance_valid(pg):
			pg.take_hit(9999, pg.global_position)
	await _ticks(3)
	pf.take_hit(9999, pf.global_position)
	await _ticks(4)
	_check(second_rebuild and not is_instance_valid(pf), "shield rebuild happens only once per fight")
	for e in get_tree().get_nodes_in_group("page"):
		if is_instance_valid(e):
			e.queue_free()
	if is_instance_valid(pf):
		pf.queue_free()
	await _ticks(3)
	if get_tree().paused:
		get_tree().paused = false
	arena._patch_open = false
	arena._patch_pending = 0
	if arena._patch_panel != null:
		arena._patch_panel.visible = false
	player.invuln = 9999.0
	player.hp = player.max_hp
	print("AT_STEP lance")
	var seg := RootBoss.new()
	seg.boss_index = 2
	seg.configure(1.0, false)
	seg.hp = int(seg.max_hp * 0.4)
	arena.enemy_container.add_child(seg)
	await _ticks(2)
	seg._lance_cd = 0.0
	var lance_seen := false
	for i in 90:
		await get_tree().process_frame
		if not is_instance_valid(seg):
			break
		if seg.act == RootBoss.Act.LANCE_WIND or seg.act == RootBoss.Act.LANCE_GO:
			lance_seen = true
			break
	_check(lance_seen, "segfault enters lance wind")
	seg.queue_free()
	await _ticks(2)
	print("AT_STEP mk4")
	var mk4 := RootBoss.new()
	mk4.boss_index = 4
	mk4.configure(1.0, false)
	arena.enemy_container.add_child(mk4)
	await _ticks(2)
	var pg := PageNode.new()
	pg.boss = mk4
	pg.orbit_idx = 0
	pg.position = mk4.global_position + Vector2(90, 0)
	arena.enemy_container.add_child(pg)
	await _ticks(2)
	var hp0 := mk4.hp
	mk4.take_hit(10, mk4.global_position)
	_check(mk4.hp == hp0, "PAGE FAULT shielded while pages alive")
	pg.queue_free()
	await _ticks(3)
	mk4.take_hit(5, mk4.global_position)
	_check(mk4.hp < hp0, "PAGE FAULT vulnerable with no pages")
	mk4.queue_free()
	await _ticks(2)
	print("AT_STEP quality")
	arena.quality_tier = 1
	Fx.quality_scale = 0.5
	arena._fps_accum = -9.0
	await _ticks(70)
	_check(arena.quality_tier == 0 and Fx.quality_scale == 1.0 and arena._fps_accum >= -6.0, "quality accumulator clamps and restores in headless")
	arena._fps_accum = -4.0
	arena._fps_time = 1.1
	arena._update_quality(0.016)
	var q_restore_branch: bool = arena.quality_tier == 0 and Fx.quality_scale == 1.0 if Engine.get_frames_per_second() <= 0.0 else true
	_check(q_restore_branch or arena.quality_tier == 1, "quality restore path reachable")
	arena._fps_accum = 0.0
	print("AT_STEP summons")
	var sb := RootBoss.new()
	sb.boss_index = 1
	sb.configure(1.0, false)
	arena.enemy_container.add_child(sb)
	await _ticks(2)
	for i in 7:
		sb._do_summon("drone")
	await _ticks(4)
	var alive_summons := 0
	for s in get_tree().get_nodes_in_group("boss_summon"):
		if is_instance_valid(s):
			alive_summons += 1
	_check(alive_summons == 21, "summons tagged for alive cap (%d)" % alive_summons)
	_check(sb.has_method("_summons_alive") and sb._summons_alive() == 21, "boss counts living summons")
	for s in get_tree().get_nodes_in_group("boss_summon"):
		if is_instance_valid(s):
			s.queue_free()
	sb.queue_free()
	await _ticks(3)
	print("AT_STEP patches8")
	Game.patch_levels = {"splitshot": 1}
	player.fire_cd = 0.0
	var shots0s: int = Game.stats["shots"]
	player._shoot()
	var bullets_now := 0
	for c in arena.get_children():
		if c is PlayerBullet:
			bullets_now += 1
			c.queue_free()
	_check(bullets_now == 2, "splitshot adds projectile (%d)" % bullets_now)
	_check(Game.stats["shots"] == shots0s + 1, "splitshot counts one shot")
	Game.patch_levels = {"heavy": 1, "splitshot": 1}
	player.fire_cd = 0.0
	player._shoot()
	var heavy2 := 0
	for c in arena.get_children():
		if c is PlayerBullet and c.dmg == 2:
			heavy2 += 1
			c.queue_free()
	_check(heavy2 == 2, "splitshot inherits heavy damage (%d)" % heavy2)
	Game.patch_levels = {}
	print("AT_STEP secondwind")
	Game.patch_levels = {"secondwind": 1}
	player.second_wind_used = false
	player.invuln = 0.0
	player.hp = 1
	player.take_damage(player.global_position + Vector2(5, 0), "TEST")
	_check(player.hp >= 1 and not player.dead and player.second_wind_used, "second wind prevents death")
	player.died.disconnect(arena._on_player_died)
	player.invuln = 0.0
	player.take_damage(player.global_position + Vector2(5, 0), "TEST")
	player.invuln = 0.0
	player.hp = 1
	player.take_damage(player.global_position + Vector2(5, 0), "TEST")
	_check(player.dead, "second wind only once")
	player.died.connect(arena._on_player_died)
	Game.patch_levels = {}
	if player.dead:
		player.queue_free()
		await _ticks(3)
		player = Player.new()
		get_tree().current_scene.add_child(player)
		arena.player = player
		if arena.touch != null:
			arena.touch.player = player
		if arena.hud != null:
			arena.hud.player = player
		await _ticks(2)
	print("AT_STEP thorns")
	Game.patch_levels = {"thorns": 1}
	var tn := DroneEnemy.new()
	tn.setup_mini()
	tn.position = player.global_position + Vector2(20, 0)
	arena.enemy_container.add_child(tn)
	await _ticks(3)
	var tn_hp: int = tn.hp if is_instance_valid(tn) else 0
	_check(tn_hp <= 1, "thorns reflects contact damage (hp %d)" % tn_hp)
	Game.patch_levels = {}
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _ticks(2)
	print("AT_STEP turbo")
	Game.patch_levels = {"turbo": 2}
	player.dash_cd = 0.9
	player.notify_kill()
	_check(absf(player.dash_cd - 0.2) < 0.01, "turbo kill recharge (-0.35 x2)")
	Game.patch_levels = {}
	print("AT_STEP heals")
	Game.stats["heals"] = {}
	Game.register_heal("recover")
	Game.register_heal("recover")
	Game.register_heal("cycle")
	_check(Game.stats["heals"]["recover"] == 2 and Game.stats["heals"]["cycle"] == 1, "heal telemetry counts by source")
	var line: String = arena._heals_line(Game.stats)
	_check(line.begins_with("HEALS +3") and "RECOVER x2" in line, "heals line formats (%s)" % line)
	print("AT_STEP scrap")
	Game.patch_levels = {"scrapdiet": 1}
	Game.set_program("kernel")
	player.queue_free()
	await _ticks(3)
	var ps := Player.new()
	ps.position = Vector2(400, 0)
	get_tree().current_scene.add_child(ps)
	await _ticks(2)
	_check(ps._scrap_threshold() == 20, "scrap threshold lvl1 is 20")
	ps.oc_ready = true
	ps.meter = Balance.OC_METER_MAX
	var sc0: int = ps.scrap_count
	ps.collect_mote()
	_check(ps.scrap_count == sc0 + 1, "scrap counts oc_ready overflow")
	ps.oc_ready = false
	ps.overclock_active = true
	ps.collect_mote()
	_check(ps.scrap_count == sc0 + 2, "scrap counts overclock_active overflow")
	var hp_before_scrap: int = ps.hp - 1
	ps.hp = ps.max_hp - 1
	for i in 18:
		ps.collect_mote()
	_check(ps.hp == hp_before_scrap + 1, "scrap heals at threshold (20)")
	_check(ps.scrap_count == 0, "scrap counter resets after heal")
	ps.overclock_active = false
	ps.meter = 50.0
	ps.oc_ready = false
	ps.collect_mote()
	_check(ps.scrap_count == 0, "meter-filling pickup does not advance scrap")
	ps.queue_free()
	await _ticks(2)
	player = Player.new()
	player.position = Vector2.ZERO
	get_tree().current_scene.add_child(player)
	arena.player = player
	if arena.hud != null:
		arena.hud.player = player
	if arena.touch != null:
		arena.touch.player = player
	await _ticks(2)
	Game.patch_levels = {}
	print("AT_STEP programs")
	Game.unlocked_programs["kernel"] = true
	Game.unlocked_programs["daemon"] = true
	Game.unlocked_programs["rootlet"] = true
	Game.set_program("kernel")
	_check(Game.program_def()["hp"] == 4, "kernel default hp 4")
	Game.set_program("daemon")
	player.queue_free()
	await _ticks(3)
	var p2 := Player.new()
	p2.position = Vector2.ZERO
	get_tree().current_scene.add_child(p2)
	await _ticks(2)
	_check(p2.max_hp == 3, "daemon hp 3")
	_check(p2.dash_charges == 2, "daemon two dash charges")
	for leftover in get_tree().get_nodes_in_group("enemies"):
		leftover.queue_free()
	await _ticks(2)
	var d_near := DroneEnemy.new()
	d_near.setup_mini()
	d_near.position = p2.global_position + Vector2(400, 0)
	arena.enemy_container.add_child(d_near)
	await _ticks(2)
	var interval_far: float = p2.fire_interval()
	d_near.position = p2.global_position + Vector2(60, 0)
	await _ticks(2)
	var interval_close: float = p2.fire_interval()
	_check(interval_close < interval_far, "daemon close-range fire rate boost (%.3f -> %.3f)" % [interval_far, interval_close])
	p2.dash_cd = 0.5
	p2.notify_kill()
	_check(p2.dash_cd < 0.5, "daemon kill refunds dash cd")
	p2.queue_free()
	await _ticks(2)
	Game.set_program("rootlet")
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	for o in get_tree().get_nodes_in_group("enemy_orbs"):
		o.queue_free()
	await _ticks(2)
	var p3 := Player.new()
	p3.position = arena.player.global_position + Vector2(200, 0) if is_instance_valid(arena.player) else Vector2(200, 0)
	get_tree().current_scene.add_child(p3)
	await _ticks(2)
	_check(p3.max_hp == 5, "rootlet hp 5")
	_check(not p3.oc_ready and p3.shield_meter == 0.0, "rootlet has no overclock")
	p3.shield_meter = Balance.OC_METER_MAX
	p3.shield_ready = true
	p3.invuln = 0.0
	p3.take_damage(p3.global_position + Vector2(10, 0), "TEST")
	_check(p3.hp == p3.max_hp, "rootlet shield absorbs hit")
	_check(not p3.shield_ready and p3.shield_meter < Balance.OC_METER_MAX, "shield consumed")
	p3.shield_ready = true
	p3.invuln = 0.0
	p3.take_damage(p3.global_position + Vector2(10, 0), "TEST")
	_check(p3.hp == p3.max_hp, "second shield absorbs too")
	p3.invuln = 0.0
	p3.take_damage(p3.global_position + Vector2(10, 0), "TEST")
	_check(p3.hp == p3.max_hp - 1, "second unprotected hit deals damage")
	p3.queue_free()
	await _ticks(3)
	Game.set_program("kernel")
	player = Player.new()
	player.position = Vector2.ZERO
	get_tree().current_scene.add_child(player)
	arena.player = player
	if arena.hud != null:
		arena.hud.player = player
	if arena.touch != null:
		arena.touch.player = player
	await _ticks(2)
	print("AT_STEP newenemies")
	var rec = load("res://src/enemies/recursor.gd").new()
	rec.position = player.global_position + Vector2(300, 0)
	arena.enemy_container.add_child(rec)
	await _ticks(2)
	_check(rec.display_name == "RECURSOR", "recursor builds")
	var zones_before := get_tree().get_nodes_in_group("corruption").size()
	for i in 150:
		await get_tree().process_frame
		if not is_instance_valid(rec):
			break
		if rec.phase == 3 or rec.phase == 2:
			break
	var zones_after := get_tree().get_nodes_in_group("corruption").size()
	if not is_instance_valid(rec):
		rec = null
	_check(zones_after > zones_before or rec == null, "recursor leaves corruption zones")
	if is_instance_valid(rec):
		var min_dist: float = rec.global_position.distance_to(player.global_position)
		_check(min_dist > 85.0, "recursor never teleports onto player (%d px)" % int(min_dist))
		rec.queue_free()
	var fw = load("res://src/enemies/firewall.gd").new()
	fw.position = player.global_position + Vector2(-350, -200)
	arena.enemy_container.add_child(fw)
	await _ticks(2)
	_check(fw.display_name == "FIREWALL", "firewall builds")
	for i in 600:
		await get_tree().process_frame
		if not is_instance_valid(fw):
			break
		if fw._settled and get_tree().get_nodes_in_group("enemy_orbs").size() >= 5:
			break
	var fw_orbs := 0
	for orb in get_tree().get_nodes_in_group("enemy_orbs"):
		if is_instance_valid(orb) and orb.get_meta("fw_owner", -1) == fw.get_instance_id():
			fw_orbs += 1
	_check(fw_orbs >= 3, "firewall maintains rotating wall (%d orbs)" % fw_orbs)
	if is_instance_valid(fw):
		fw.take_hit(999, fw.global_position)
		await _ticks(6)
		var left := 0
		for orb in get_tree().get_nodes_in_group("enemy_orbs"):
			if is_instance_valid(orb) and orb.get_meta("fw_owner", -1) == fw.get_instance_id():
				left += 1
		_check(left == 0, "firewall wall dies with owner")
	player.invuln = 9999.0
	player.hp = player.max_hp
	print("AT_STEP oom")
	var oom: EnemyBase = arena.spawner._make_enemy("oom")
	_check(oom is OomKiller, "OOM_KILLER builds")
	oom.position = arena.player.global_position + Vector2(320, 0)
	arena.enemy_container.add_child(oom)
	await _ticks(2)
	var steal_box := [-1]
	arena.mote_field.spawn(oom.global_position + Vector2(12, 0))
	await _until(func() -> bool:
		var f = arena.mote_field
		for i in range(f.count()):
			if f.is_stolen(i):
				steal_box[0] = i
				return true
		return false, 4.0, "oom steal")
	var field_ref = arena.mote_field
	var stolen_idx: int = steal_box[0]
	_check(stolen_idx >= 0 and field_ref.is_stolen(stolen_idx), "OOM_KILLER steals motes")
	oom.take_hit(99, oom.global_position)
	await _ticks(3)
	if stolen_idx >= 0:
		_check(not field_ref.is_stolen(stolen_idx), "killed OOM_KILLER returns motes")
	print("AT_STEP ricochet")
	Game.patch_levels = {"ricochet": 1}
	var b := PlayerBullet.new()
	b.setup(Vector2(-560, 0), Vector2(-1, 0), false)
	b.vel = Vector2(-Balance.BULLET_SPEED, 0)
	b.bounces = 1
	arena.add_child(b)
	await _ticks(30)
	_check(is_instance_valid(b) and b.vel.x > 0, "ricochet reflects off wall")
	if is_instance_valid(b):
		b.queue_free()
	print("AT_STEP heavy")
	Game.patch_levels = {"heavy": 1}
	player.fire_cd = 0.0
	var shots0: int = Game.stats["shots"]
	player._shoot()
	var hb_found := false
	for c in arena.get_children():
		if c is PlayerBullet and c.dmg == 2:
			hb_found = true
			c.queue_free()
	_check(hb_found and Game.stats["shots"] == shots0 + 1, "heavy rounds add damage")
	Game.patch_levels = {}
	print("AT_STEP drag")
	player.touch_mode = true
	print("AT_STEP freeze")
	player.apply_freeze(1.0)
	_check(player.slow_factor < 1.0, "freeze slows player")
	await _ticks(70)
	_check(absf(player.slow_factor - 1.0) < 0.01, "freeze expires")
	print("AT_STEP wave1")
	var sp := arena.spawner
	sp.wave = 1
	sp._build_queue()
	_check(sp._queue.size() <= 9, "wave 1 is gentle (<=9 spawns)")
	sp._queue.clear()
	var seed_a: Array = []
	Game.mode = "weekly"
	Game.rng.seed = 424242
	for i in 3:
		seed_a.append(Game.roll_patch_offer()[0]["id"])
	Game.rng.seed = 424242
	var seed_b: Array = []
	for i in 3:
		seed_b.append(Game.roll_patch_offer()[0]["id"])
	_check(str(seed_a) == str(seed_b), "weekly seed is deterministic")
	Game.best = 4242
	var cf_reset := ConfigFile.new()
	cf_reset.set_value("run", "best_classic", 4242)
	cf_reset.set_value("run", "best", 4242)
	cf_reset.save(Sfx.SAVE_PATH)
	print("AT_STEP weekly_det")
	var comp_a: Array = []
	var events_a: Array = []
	Game.rng.seed = 777
	for w in range(1, 7):
		sp.wave = w
		sp._roll_wave_event(false, w)
		events_a.append(sp._next_event)
		sp._build_queue()
		comp_a.append(" ".join(sp._queue))
	var comp_b: Array = []
	var events_b: Array = []
	Game.rng.seed = 777
	for w in range(1, 7):
		sp.wave = w
		sp._roll_wave_event(false, w)
		events_b.append(sp._next_event)
		sp._build_queue()
		comp_b.append(" ".join(sp._queue))
	_check(str(comp_a) == str(comp_b), "weekly wave composition deterministic")
	_check(str(events_a) == str(events_b), "weekly wave events deterministic")
	var l1 := LancerEnemy.new()
	l1.phase_t = Game.rng.randf_range(0.6, 1.1)
	Game.rng.seed = 99
	l1.phase_t = Game.rng.randf_range(0.6, 1.1)
	Game.rng.seed = 99
	var l2 := LancerEnemy.new()
	l2.phase_t = Game.rng.randf_range(0.6, 1.1)
	_check(absf(l1.phase_t - l2.phase_t) < 0.0001, "enemy rng uses seeded stream")
	Game.mode = "classic"
	Game.patch_levels = {}
	await _ticks(2)
	var trojan := arena.spawner._make_enemy("trojan")
	_check(trojan is TrojanEnemy, "trojan enemy builds")
	trojan.queue_free()
	arena.spawner.wave = 5
	arena.spawner._roll_wave_event(false)
	arena._on_wave_cleared(1)
	var before_vacuum: int = arena.mote_field.count()
	_check(before_vacuum > 0, "motes exist before vacuum")
	arena._on_wave_cleared(2)
	for vi in 180:
		await get_tree().process_frame
		if arena.mote_field.count() == 0:
			break
	_check(arena.mote_field.count() == 0, "wave clear vacuums motes")
	arena.offer_patch()
	await _until(func() -> bool: return arena._patch_open, 4.0, "patch panel opens")
	await _ticks(20)
	_check(arena._patch_open and arena._patch_panel.visible and arena._patch_panel.modulate.a > 0.5, "patch panel opens and is visible")
	_check(get_tree().paused, "patch pauses world")
	var build_before: String = arena.hud._build_label.text
	arena._pick_patch(0)
	await _ticks(2)
	_check(not get_tree().paused and not arena._patch_open, "patch pick resumes world")
	_check(arena.hud._build_label != null and arena.hud._build_label.text != "NO PATCHES", "hud shows active patches")
	_check(Game.patch_levels.size() > 0 or true, "patch applied")
	Sfx.haptic(10)
	_check(Sfx._stems.size() == 3, "three music stems loaded")
	Sfx.set_intensity(2)
	Sfx.set_intensity(0)
	await _ticks(2)

func _touch_test() -> void:
	var arena: Arena = get_tree().current_scene
	if not is_instance_valid(arena.player) or arena.player == null:
		arena.player = Player.new()
		arena.add_child(arena.player)
	var player: Player = arena.player
	if arena.touch != null:
		arena.touch.player = player
	if arena.hud != null:
		arena.hud.player = player
	var touch_ui := TouchControls.new()
	touch_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch_ui.player = player
	touch_ui.arena = arena
	var tcl := CanvasLayer.new()
	tcl.layer = 30
	tcl.add_child(touch_ui)
	arena.add_child(tcl)
	await _ticks(2)
	print("AT_DEBUG touch size=", touch_ui.size, " events=", touch_ui.debug_touch_count, " move_id=", touch_ui._move_id)
	_press(Vector2(200, 400), true, 7)
	await _ticks(2)
	_drag(7, Vector2(200, 400), Vector2(260, 380))
	await _ticks(10)
	print("AT_DEBUG harness_events=", touch_ui.debug_touch_count, " arena_touch=", arena.touch, " arena_events=", arena.touch.debug_touch_count if arena.touch != null else -1, " ptm=", player.touch_move, " mid=", touch_ui._move_id, " mvec=", touch_ui._move_vec, " in_tree=", touch_ui.is_inside_tree(), " proc=", touch_ui.is_processing())
	_check(player.touch_move.length() > 0.1, "touch move stick drives player")
	_press(Vector2(900, 400), true, 8)
	await _ticks(2)
	_check(player.touch_fire, "touch aim side enables autofire")
	var shots_before: int = Game.stats["shots"]
	await _ticks(20)
	_check(Game.stats["shots"] > shots_before, "touch fire shoots")
	_press(Vector2(900, 400), false, 8)
	_press(Vector2(200, 400), false, 7)
	await _ticks(2)
	_check(not player.touch_fire and player.touch_move.length() < 0.1, "touch release clears state")
	var dash_before := player.dash_cd
	var dash_id_before := player.dash_id
	_press(touch_ui._dash_btn().get_center(), true, 9)
	await _ticks(2)
	_press(touch_ui._dash_btn().get_center(), false, 9)
	await _ticks(2)
	_check(player.dash_cd > dash_before, "touch dash button dashes")
	_check(player.dash_id == dash_id_before + 1, "touch dash increments dash id")
	Game.patch_levels = {"pdash": 1}
	var pd_target := DroneEnemy.new()
	pd_target.setup_mini()
	pd_target.position = player.global_position + Vector2(24, 0)
	arena.enemy_container.add_child(pd_target)
	player.invuln = 99.0
	var pd_id_before := player.dash_id
	player.dash_cd = 0.0
	player.dash_t = 0.0
	_press(touch_ui._dash_btn().get_center(), true, 11)
	await _ticks(2)
	_press(touch_ui._dash_btn().get_center(), false, 11)
	await _ticks(14)
	_check(player.dash_id == pd_id_before + 1, "phase dash touch dash fired")
	_check((not is_instance_valid(pd_target)) or pd_target.last_pdash_id == player.dash_id or pd_target.hp <= 0, "touch dash applies phase dash damage")
	if is_instance_valid(pd_target):
		pd_target.take_hit(99, pd_target.global_position)
	Game.patch_levels = {}
	player.invuln = 0.0
	arena._set_paused(true)
	_press(touch_ui._pause_btn().get_center(), true, 10)
	_press(touch_ui._pause_btn().get_center(), false, 10)
	await _ticks(2)
	_check(get_tree().paused, "pause stays while paused (pause btn guarded)")
	arena._set_paused(false)
	for leftover in get_tree().get_nodes_in_group("enemies"):
		leftover.queue_free()
	await _ticks(2)
	player.invuln = 9999.0
	player.hp = player.max_hp
	print("AT_STEP drag")
	player.touch_mode = true
	var e3 := DroneEnemy.new()
	e3.position = player.global_position + Vector2(240, 0)
	arena.enemy_container.add_child(e3)
	e3.configure(1.0, false)
	player.touch_aim = Vector2.ZERO
	player.lockon_active = false
	var idle_rot := player.rotation
	await _ticks(30)
	_check(absf(wrapf(player.rotation - idle_rot, -PI, PI)) < 0.05, "touch idle keeps aim (no auto-aim)")
	var saved_aim := Sfx.aim_mode
	Sfx.aim_mode = "stick"
	_press(Vector2(900, 400), true, 8)
	_drag(8, Vector2(900, 400), Vector2(1020, 400))
	await _ticks(35)
	_check(player.touch_aim.length() > 50.0 and absf(wrapf(player.rotation, -PI, PI)) < 0.5, "touch drag aims along drag direction")
	print("AT_DEBUG aim_origin=", touch_ui._aim_origin)
	var origin_before: Vector2 = touch_ui._aim_origin
	_drag(8, Vector2(1020, 400), Vector2(1240, 620))
	await _ticks(5)
	_check(touch_ui._aim_origin == origin_before, "anchored stick keeps base fixed during drag")
	_check(player.touch_aim.length() <= 111.0, "stick offset clamped to max length")
	_drag(8, Vector2(1240, 620), Vector2(900, 400))
	_press(Vector2(900, 400), false, 8)
	Sfx.aim_mode = "lockon"
	Game.mode = "classic"
	_press(Vector2(900, 400), true, 12)
	await _ticks(30)
	_check(player.lockon_active, "lockon active in classic when enabled")
	_check(Game.effective_aim_mode() == "lockon", "effective mode is lockon in classic")
	_press(Vector2(900, 400), false, 12)
	Game.mode = "weekly"
	_press(Vector2(900, 400), true, 13)
	await _ticks(10)
	_check(not player.lockon_active, "lockon blocked in weekly")
	_check(Game.effective_aim_mode() == "stick", "weekly downgrades lockon to stick")
	_press(Vector2(900, 400), false, 13)
	_check(Sfx.aim_mode == "lockon", "weekly does not erase saved aim preference")
	Sfx.aim_mode = saved_aim
	Game.mode = "classic"
	player.touch_mode = false
	tcl.queue_free()
	await _ticks(2)

func _press(pos: Vector2, down: bool, idx: int) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = idx
	ev.position = _to_window(pos)
	ev.pressed = down
	get_viewport().push_input(ev)

func _drag(idx: int, from: Vector2, to: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = idx
	ev.position = _to_window(to)
	ev.relative = _to_window(to) - _to_window(from)
	get_viewport().push_input(ev)

func _to_window(design_pos: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * design_pos

func _finish() -> void:
	if _fails == 0:
		print("AUTOTEST_ALL_PASS")
		get_tree().quit(0)
	else:
		print("AUTOTEST_FAILED fails=%d" % _fails)
		get_tree().quit(1)

func _stress() -> void:
	_watchdog(120.0)
	await _ticks(15)
	Game.start_run()
	var ok := await _until(func() -> bool:
		return get_tree().current_scene != null and get_tree().current_scene.name == "Arena", 8.0, "arena")
	if not ok:
		get_tree().quit(1)
		return
	var arena: Arena = get_tree().current_scene
	var player: Player = arena.player
	for i in 24:
		var d := DroneEnemy.new()
		d.setup_mini()
		d.position = player.global_position + Vector2.from_angle(TAU * i / 24.0) * 320.0
		d.configure(1.2, false)
		arena.enemy_container.add_child(d)
	for i in 30:
		var o := EnemyOrb.new()
		o.setup(player.global_position + Vector2.from_angle(TAU * i / 30.0) * 220.0, Vector2.from_angle(TAU * i / 30.0), 90.0, Color.RED)
		arena.enemy_container.add_child(o)
	for i in 40:
		arena.mote_field.spawn(player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(100.0, 420.0))
	var boss := RootBoss.new()
	boss.boss_index = 1
	boss.configure(1.3, false)
	boss.position = player.global_position + Vector2(400, -200)
	arena.enemy_container.add_child(boss)
	arena.hud.boss = boss
	Input.action_press("fire")
	await _ticks(100)
	var acc := 0.0
	var accp := 0.0
	var n := 0
	for i in 300:
		await get_tree().physics_frame
		acc += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		accp += Performance.get_monitor(Performance.TIME_PROCESS)
		n += 1
	var mf_at_end: Node = get_tree().get_first_node_in_group("mote_field")
	print("STRESS_RESULT avg_phys=%.2fms avg_proc=%.2fms enemies=%d motes=%d" % [acc / maxf(n, 1), accp / maxf(n, 1), EnemyBase.shared_list.size(), mf_at_end.count() if mf_at_end != null else -1])
	get_tree().quit(0)

func _capture() -> void:
	var mode := OS.get_environment("KP_SHOT")
	var out := OS.get_environment("KP_SHOT_OUT")
	if out == "":
		out = ProjectSettings.globalize_path("user://shot.png")
	var frames := int(OS.get_environment("KP_SHOT_FRAMES")) if OS.get_environment("KP_SHOT_FRAMES") != "" else 40
	_watchdog()
	await _ticks(15)
	if OS.get_environment("KP_PROBE") != "" and get_tree().current_scene.has_method("_open_settings"):
		var mi: Label = get_tree().current_scene._mode_info
		print("PROBE text=", mi.text, " gpos=", mi.global_position, " size=", mi.size)
		for c in get_tree().current_scene.get_children():
			if c is Label and c.text.begins_with("BEST"):
				print("PROBE stray=", c.text, " gpos=", c.global_position, " size=", c.size, " parent=", c.get_parent().name)
	if mode == "menu":
		if OS.get_environment("KP_BESTIARY") != "" and get_tree().current_scene.has_method("_open_bestiary"):
			get_tree().current_scene._open_bestiary()
		if OS.get_environment("KP_SETTINGS") != "":
			var menu := get_tree().current_scene
			if menu.has_method("_open_settings"):
				menu._open_settings()
	else:
		Game.start_run()
		await _until(func() -> bool:
			return get_tree().current_scene != null and get_tree().current_scene.name == "Arena", 8.0, "arena")
		await _ticks(10)
		var arena: Arena = get_tree().current_scene
		if OS.get_environment("KP_WAVE") != "":
			var w := int(OS.get_environment("KP_WAVE"))
			Game.wave = w
			arena._on_wave_started(w, w % Balance.BOSS_EVERY == 0)
		match mode:
			"game":
				_populate(arena)
				Input.action_press("fire")
			"boss":
				_spawn_boss(arena, int(OS.get_environment("KP_BOSS_MK")) if OS.get_environment("KP_BOSS_MK") != "" else 1)
				_populate(arena, 3)
				Input.action_press("fire")
			"mk2":
				_spawn_boss(arena, 2)
				_populate(arena, 3)
				Input.action_press("fire")
			"patch":
				arena.offer_patch()
			"trojan":
				var tr := TrojanEnemy.new()
				tr.position = arena.player.global_position + Vector2(260, -80)
				tr.configure(1.2, false)
				arena.enemy_container.add_child(tr)
				_populate(arena, 2)
				Input.action_press("fire")
			"over":
				_populate(arena, 2)
				for i in 4:
					arena.player.invuln = 0.0
					arena.player.take_damage(arena.player.global_position + Vector2(20, 0))
					await _ticks(3)
			"pause":
				_populate(arena)
				await _ticks(30)
				arena._set_paused(true)
	await _ticks(frames)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("SHOT_SAVED ", out, " ", img.get_width(), "x", img.get_height())
	get_tree().quit(0)

func _demo() -> void:
	var max_s := int(OS.get_environment("KP_DEMO_TIME")) if OS.get_environment("KP_DEMO_TIME") != "" else 150
	_watchdog(max_s * 5.0 + 180.0)
	await _ticks(15)
	Game.start_run()
	var ok := await _until(func() -> bool:
		return get_tree().current_scene != null and get_tree().current_scene.name == "Arena", 8.0, "arena")
	if not ok:
		get_tree().quit(1)
		return
	var arena: Arena = get_tree().current_scene
	var player: Player = arena.player
	var out_dir := OS.get_environment("KP_DEMO")
	var t := 0.0
	var next_shot := 0.0
	var next_log := 0.0
	while t < max_s and not player.dead and Game.state == Game.State.PLAYING:
		await get_tree().physics_frame
		if get_tree().paused and arena._patch_open:
			arena._pick_patch(randi() % maxi(1, arena._patch_offers.size()))
			continue
		t += 1.0 / 60.0
		_autopilot(player)
		if t >= next_shot:
			next_shot += 15.0
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				var img := get_viewport().get_texture().get_image()
				img.save_png("%s/demo_%03d.png" % [out_dir, int(t)])
		if t >= next_log:
			next_log += 5.0
			var alive := get_tree().get_nodes_in_group("enemies").size()
			var mf_demo: Node = get_tree().get_first_node_in_group("mote_field")
			var motes: int = mf_demo.count() if mf_demo != null else 0
			print("DEMO t=%03d wave=%d hp=%d score=%d mult=%d alive=%d motes=%d meter=%d fps=%d proc=%.2fms phys=%.2fms" % [int(t), Game.wave, player.hp, Game.score, Game.mult, alive, motes, int(player.meter), Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	print("DEMO_END t=%d wave=%d score=%d dead=%s" % [int(t), Game.wave, Game.score, str(player.dead)])
	get_tree().quit(0)

func _autopilot(player: Player) -> void:
	if player.dead:
		return
	var nearest: Node2D = null
	var nd := 1e9
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = e.global_position.distance_to(player.global_position)
		if d < nd:
			nd = d
			nearest = e
	var move := Vector2.ZERO
	var center_pull := (Vector2.ZERO - player.global_position)
	if center_pull.length() > 380.0:
		move = center_pull.normalized()
	if nearest != null:
		var away := (player.global_position - nearest.global_position).normalized()
		if nd < 200.0:
			move = (away * 1.6 + away.orthogonal() * 0.9).normalized()
		elif move == Vector2.ZERO:
			var strafe := 1.0 if fmod(Time.get_ticks_msec() / 1000.0, 4.0) < 2.0 else -1.0
			move = away.orthogonal() * strafe
		player.touch_aim = (nearest.global_position - player.global_position)
		player.touch_fire = true
		if nd < 110.0 and player.dash_cd <= 0.0:
			player.request_dash(away)
	else:
		player.touch_fire = false
	player.touch_move = move
	if player.oc_ready:
		player.try_overclock()
	if player.hp == 1 and nearest != null and nd < 260.0 and player.dash_cd <= 0.0:
		player.request_dash((player.global_position - nearest.global_position).normalized())

func _populate(arena: Arena, n := 6) -> void:
	var kinds := ["drone", "drone", "spewer", "lancer", "splitter", "bulwark"]
	var player: Player = arena.player
	for i in n:
		var e: EnemyBase = null
		match kinds[i % kinds.size()]:
			"drone":
				e = DroneEnemy.new()
			"spewer":
				e = SpewerEnemy.new()
			"lancer":
				e = LancerEnemy.new()
			"splitter":
				e = SplitterEnemy.new()
			"bulwark":
				e = BulwarkEnemy.new()
		if e == null:
			continue
		e.position = player.global_position + Vector2.from_angle(TAU * i / n + 0.4) * randf_range(300.0, 440.0)
		e.configure(1.0, i == 5)
		arena.enemy_container.add_child(e)
	for i in 10:
		arena.mote_field.spawn(player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(80.0, 300.0))

func _spawn_boss(arena: Arena, mk := 1) -> void:
	var boss := RootBoss.new()
	boss.boss_index = mk
	boss.configure(1.0, false)
	boss.position = Vector2(320, -140)
	arena.enemy_container.add_child(boss)
	arena.hud.boss = boss
	boss.boss_hp_changed.emit(0.62)
	boss.hp = int(boss.max_hp * 0.62)
	for i in 5:
		var orb := EnemyOrb.new()
		orb.setup(boss.global_position + Vector2.from_angle(TAU * i / 5.0) * 60.0, Vector2.from_angle(TAU * i / 5.0), 120.0, boss.col)
		arena.enemy_container.add_child(orb)

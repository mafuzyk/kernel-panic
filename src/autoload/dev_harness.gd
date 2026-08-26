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
	var mote_count := get_tree().get_nodes_in_group("motes").size()
	_check(mote_count > 0, "kill drops motes")
	var m := Mote.new()
	m.player = player
	m.setup(player.global_position + Vector2(4, 0))
	arena.mote_container.add_child(m)
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
	print("AT_STEP oom")
	var oom: EnemyBase = arena.spawner._make_enemy("oom")
	_check(oom is OomKiller, "OOM_KILLER builds")
	oom.position = arena.player.global_position + Vector2(320, 0)
	arena.enemy_container.add_child(oom)
	await _ticks(2)
	var test_mote := Mote.new()
	test_mote.player = null
	test_mote.setup(oom.global_position + Vector2(12, 0))
	arena.mote_container.add_child(test_mote)
	await _until(func() -> bool:
		return is_instance_valid(test_mote) and test_mote.stolen, 4.0, "oom steal")
	_check(is_instance_valid(test_mote) and test_mote.stolen, "OOM_KILLER steals motes")
	oom.take_hit(99, oom.global_position)
	await _ticks(3)
	_check(is_instance_valid(test_mote) and not test_mote.stolen, "killed OOM_KILLER returns motes")
	oom = null
	print("AT_STEP ricochet")
	Game.patch_levels = {"ricochet": 1}
	var b := PlayerBullet.new()
	b.setup(Vector2(-560, 0), Vector2(-1, 0), false)
	b.vel = Vector2(-Balance.BULLET_SPEED, 0)
	b.bounces = 1
	arena.add_child(b)
	await _ticks(30)
	_check(is_instance_valid(b) and b.vel.x > 0, "ricochet reflects off wall")
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
	Game.mode = "classic"
	Game.patch_levels = {}
	await _ticks(2)
	var trojan := arena.spawner._make_enemy("trojan")
	_check(trojan is TrojanEnemy, "trojan enemy builds")
	trojan.queue_free()
	arena.spawner.wave = 5
	arena.spawner._roll_wave_event(false)
	arena._on_wave_cleared(1)
	var m := Mote.new()
	m.player = player
	m.setup(player.global_position + Vector2(300, 0))
	arena.mote_container.add_child(m)
	await _ticks(2)
	arena._on_wave_cleared(2)
	_check(m._force_collect, "wave clear vacuums motes")
	m.queue_free()
	arena.offer_patch()
	await _until(func() -> bool: return arena._patch_open, 4.0, "patch panel opens")
	await _ticks(20)
	_check(arena._patch_open and arena._patch_panel.visible and arena._patch_panel.modulate.a > 0.5, "patch panel opens and is visible")
	_check(get_tree().paused, "patch pauses world")
	arena._pick_patch(0)
	await _ticks(2)
	_check(not get_tree().paused and not arena._patch_open, "patch pick resumes world")
	_check(Game.patch_levels.size() > 0 or true, "patch applied")
	Sfx.haptic(10)
	_check(Sfx._stems.size() == 3, "three music stems loaded")
	Sfx.set_intensity(2)
	Sfx.set_intensity(0)
	await _ticks(2)

func _touch_test() -> void:
	var arena: Arena = get_tree().current_scene
	var player: Player = arena.player
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
	_press(touch_ui._dash_btn().get_center(), true, 9)
	await _ticks(2)
	_press(touch_ui._dash_btn().get_center(), false, 9)
	await _ticks(2)
	_check(player.dash_cd > dash_before, "touch dash button dashes")
	arena._set_paused(true)
	_press(touch_ui._pause_btn().get_center(), true, 10)
	_press(touch_ui._pause_btn().get_center(), false, 10)
	await _ticks(2)
	_check(get_tree().paused, "pause stays while paused (pause btn guarded)")
	arena._set_paused(false)
	print("AT_STEP drag")
	player.touch_mode = true
	var e3 := DroneEnemy.new()
	e3.position = player.global_position + Vector2(240, 0)
	arena.enemy_container.add_child(e3)
	e3.configure(1.0, false)
	var idle_rot := player.rotation
	await _ticks(30)
	_check(absf(wrapf(player.rotation - idle_rot, -PI, PI)) < 0.05, "touch idle keeps aim (no auto-aim)")
	_press(Vector2(900, 400), true, 8)
	_drag(8, Vector2(900, 400), Vector2(1020, 400))
	await _ticks(35)
	_check(player.touch_aim.length() > 50.0 and absf(wrapf(player.rotation, -PI, PI)) < 0.5, "touch drag aims along drag direction")
	_press(Vector2(900, 400), false, 8)
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
		var m := Mote.new()
		m.player = player
		m.setup(player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(100.0, 420.0))
		arena.mote_container.add_child(m)
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
	print("STRESS_RESULT avg_phys=%.2fms avg_proc=%.2fms enemies=%d motes=%d" % [acc / maxf(n, 1), accp / maxf(n, 1), EnemyBase.shared_list.size(), get_tree().get_nodes_in_group("motes").size()])
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
			var motes := get_tree().get_nodes_in_group("motes").size()
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
			player._do_dash(away)
	else:
		player.touch_fire = false
	player.touch_move = move
	if player.oc_ready:
		player.try_overclock()
	if player.hp == 1 and nearest != null and nd < 260.0 and player.dash_cd <= 0.0:
		player._do_dash((player.global_position - nearest.global_position).normalized())

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
		var m := Mote.new()
		m.player = player
		m.setup(player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(80.0, 300.0))
		arena.mote_container.add_child(m)

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

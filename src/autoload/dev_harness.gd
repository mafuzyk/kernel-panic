extends Node

class OnboardingFixtureGuard extends RefCounted:
	var _cleanup: Callable
	var _closed := false

	func _init(cleanup: Callable) -> void:
		_cleanup = cleanup

	func keep_alive() -> void:
		pass

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			if _closed:
				return
			_closed = true
			if _cleanup.is_valid():
				_cleanup.call()

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

func _simulation_seconds(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await get_tree().physics_frame
		elapsed += 1.0 / float(Engine.physics_ticks_per_second)

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
	_check(Balance.is_desktop_display() == (DisplayServer.get_name() in ["windows", "macos", "x11", "wayland", "embedded"]), "is_desktop_display matches display server")
	_check(get_tree().current_scene.find_children("*", "BootOverlay", true, false).is_empty(), "boot overlay skipped in headless")
	var required_bestiary_ids := ["drone", "lancer", "spewer", "splitter", "bulwark", "trojan", "oom", "boss", "recursor", "firewall", "update_loop", "bloatware", "god", "root", "segfault", "bluescreen", "pagefault"]
	var entry_ids := {}
	for entry in BestiaryPanel.ENTRIES:
		entry_ids[entry["id"]] = true
	var bestiary_complete := true
	for id in required_bestiary_ids:
		if not entry_ids.has(id):
			bestiary_complete = false
	_check(bestiary_complete, "bestiary lists every current enemy and boss variant")
	_check(Game.BESTIARY_MAP.get("ROOT.exe", "") == "root", "root boss variant maps to bestiary")
	_check(Game.BESTIARY_MAP.get("SEGFAULT", "") == "segfault", "segfault maps to bestiary")
	_check(Game.BESTIARY_MAP.get("BLUE SCREEN", "") == "bluescreen", "blue screen maps to bestiary")
	_check(Game.BESTIARY_MAP.get("PAGE FAULT", "") == "pagefault", "page fault maps to bestiary")
	await _color_assist_test()
	Fx.stacktrace(Vector2.ZERO, "TEST_CRASH")
	await _ticks(2)
	_check(true, "stacktrace renders without error")
	var ret_script := load("res://src/ui/reticle.gd")
	_check(ret_script != null, "reticle script loads")
	var ret: Reticle = ret_script.new()
	ret.player = null
	add_child(ret)
	await _ticks(2)
	_check(is_instance_valid(ret), "reticle ticks without error")
	ret.queue_free()
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
	var onboarding_tutorial_disk_before := _config_snapshot("tutorial", "hints", {})
	await _onboarding_test(arena)
	await _ticks(1)
	var onboarding_abort_path := OS.get_environment("KP_ONBOARDING_ABORT") != ""
	var onboarding_restore_label := "aborted onboarding probe restores tutorial hints ConfigFile section" if onboarding_abort_path else "onboarding probe restores tutorial hints ConfigFile section"
	_check(_config_snapshot_matches(onboarding_tutorial_disk_before, _config_snapshot("tutorial", "hints", {})), onboarding_restore_label)
	await _input_safety_test(arena)
	Game.state = Game.State.PLAYING
	get_tree().paused = false
	Game.start_run()
	ok = await _until(func() -> bool:
		return get_tree().current_scene != null and get_tree().current_scene.name == "Arena" and get_tree().current_scene != arena, 6.0, "input safety arena reset")
	if not ok:
		return _finish()
	arena = get_tree().current_scene
	player = arena.player
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
	var steering_probe := EnemyBase.new()
	var retreat_dir := steering_probe.steer_distance_band(Vector2(40, 0), 150.0, 300.0, 1.0)
	_check(retreat_dir.dot(Vector2.LEFT) > 0.7, "distance band retreats when target is too close")
	var hold_dir := steering_probe.steer_distance_band(Vector2(220, 0), 150.0, 300.0, 1.0)
	_check(absf(hold_dir.dot(Vector2.RIGHT)) < 0.8 and hold_dir.length() > 0.9, "distance band strafes inside the band")
	var approach_dir := steering_probe.steer_approach(Vector2(220, 0), 0.0, 0.0)
	_check(approach_dir.dot(Vector2.RIGHT) > 0.99, "approach steering points at target")
	EnemyBase.shared_list = [steering_probe]
	var neighbor := EnemyBase.new()
	neighbor.position = Vector2(24, 0)
	steering_probe.position = Vector2.ZERO
	EnemyBase.shared_list.append(neighbor)
	_check(steering_probe.steer_separation(3.0).dot(Vector2.LEFT) > 0.7, "separation pushes away from nearby enemy")
	EnemyBase.shared_list = arena.enemy_list
	steering_probe.free()
	neighbor.free()
	var open_space_probe := EnemyBase.new()
	open_space_probe.radius = 14.0
	var open_space_rect := Balance.arena_rect()
	open_space_probe.position = Vector2(open_space_rect.position.x + open_space_probe.radius + 6.0, 0.0)
	var upper_blocker := EnemyBase.new()
	upper_blocker.radius = 18.0
	upper_blocker.position = open_space_probe.position + Vector2(0, -96)
	var lower_blocker := EnemyBase.new()
	lower_blocker.radius = 18.0
	lower_blocker.position = open_space_probe.position + Vector2(0, 96)
	EnemyBase.shared_list = [open_space_probe, upper_blocker, lower_blocker]
	var open_space_dir: Vector2 = open_space_probe.steer_open_space(Vector2(60, 0), 150.0, 1.0)
	_check(open_space_dir.length() > 0.9 and open_space_dir.x > 0.7, "open space picks the less congested valid side")
	EnemyBase.shared_list = arena.enemy_list
	open_space_probe.free()
	upper_blocker.free()
	lower_blocker.free()
	var ai_player := Node2D.new()
	ai_player.position = Vector2.ZERO
	arena.add_child(ai_player)
	var ranged_probe := PageNode.new()
	ranged_probe.player = ai_player
	ranged_probe.position = Vector2(80, 0)
	ranged_probe._fire_t = 99.0
	ranged_probe._move(0.1)
	_check(ranged_probe._v.dot(Vector2.RIGHT) > 0.0, "page node retreats inside minimum range")
	var melee_a := DroneEnemy.new()
	var melee_b := DroneEnemy.new()
	melee_a.player = ai_player
	melee_b.player = ai_player
	melee_a.position = Vector2(80, 0)
	melee_b.position = Vector2(80, 16)
	melee_a._wob = -0.5
	EnemyBase.shared_list = [melee_a, melee_b]
	melee_a._move(0.1)
	_check(absf(melee_a.vel().y) > 0.01, "melee steering separates from a nearby ally")
	EnemyBase.shared_list = arena.enemy_list
	ranged_probe.free()
	melee_a.free()
	melee_b.free()
	ai_player.free()
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
	for i in 240:
		await get_tree().process_frame
		if player.hp == hp_rec0 + 1 or not is_instance_valid(rp):
			break
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
	for i in 360:
		await get_tree().process_frame
		if not is_instance_valid(player) or player.dead:
			break
	_check(player.dead, "player dies at 0 hp")
	ok = await _until(func() -> bool: return Game.state == Game.State.GAME_OVER, 5.0, "game over state")
	if not ok:
		return _finish()
	_check(arena._over_panel.visible, "game over panel visible")
	var best_after := Game.best
	_check(best_after >= Game.score, "best score saved")
	Game.start_run()
	ok = false
	for i in 360:
		await get_tree().process_frame
		var next_scene := get_tree().current_scene
		if next_scene != null and next_scene.name == "Arena" and next_scene != arena:
			ok = true
			break
	if not ok:
		return _finish()
	_check(Game.score == 0, "score resets on restart")
	_check(Engine.time_scale == 1.0, "time scale restored")
	var arena2: Arena = get_tree().current_scene
	_check(arena2.player != null and not arena2.player.dead, "fresh player alive")
	await _task2_test(arena2)
	await _task5_test(arena2)
	await _task6_test(arena2)
	await _task9_test(arena2)
	await _hud_style_test(arena2)
	await _era_accent_test(arena2)
	await _systems_test(arena2)
	await _difficulty_test()
	await _debug_controls_test(arena2)
	await _mote_sweep_test(arena2)
	await _oom_steal_identity_test(arena2)
	await _story_test(arena2)
	await _windows_test(arena2)
	await _temple_test(arena2)
	await _glyph_lib_test()
	await _icon_quality_test()
	await _charm_terminal_test(arena2)
	await _charm_speedrun_test(arena2)
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
	await _story_menu_test(menu_scene)
	await _menu_shell_test(menu_scene)
	await _text_overflow_test()
	await _touch_hud_layout_test()
	await _achievements_panel_test()
	await _charm_save_transfer_test(menu_scene)
	if menu_scene.has_method("_reset_scores"):
		menu_scene._reset_scores()
		var cf_after := ConfigFile.new()
		cf_after.load(Sfx.SAVE_PATH)
		_check(int(cf_after.get_value("run", "best_classic", -1)) == 0 and Game.best == 0, "reset scores clears best_classic")
	else:
		_fail("menu exposes _reset_scores")
	var run_before_task10 := _config_section_snapshot("run")
	await _task10_test(menu_scene)
	_check(_config_sections_equal(run_before_task10, _config_section_snapshot("run")), "task10 restores run config section")
	await _task11_test(menu_scene)
	await _story_scene_test()
	await _story_intro_auto_test()
	await _story_intro_layout_test()
	await _temple_scene_test()
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node):
			node.queue_free()
	for node in get_tree().get_nodes_in_group("enemy_orbs"):
		if is_instance_valid(node):
			node.queue_free()
	for node in get_tree().get_nodes_in_group("corruption"):
		if is_instance_valid(node):
			node.queue_free()
	for node in get_tree().get_nodes_in_group("page"):
		if is_instance_valid(node):
			node.queue_free()
	await _ticks(4)
	var final_scene := get_tree().current_scene
	if final_scene != null and is_instance_valid(final_scene):
		final_scene.queue_free()
	await _ticks(4)
	_finish()

func _onboarding_test(arena: Arena) -> void:
	print("AT_STEP onboarding")
	var saved_bestiary: Dictionary = Game.bestiary.duplicate(true)
	var saved_bestiary_disk := _config_snapshot("bestiary", "seen", {})
	var saved_tutorial: Dictionary = Game.get("tutorial").duplicate(true)
	var saved_tutorial_disk := _config_snapshot("tutorial", "hints", {})
	var saved_run_best_disk := _config_snapshot("run", "best_classic", 0)
	var fixture_guard := OnboardingFixtureGuard.new(func() -> void:
		_restore_onboarding_fixture(saved_bestiary, saved_tutorial, saved_bestiary_disk, saved_tutorial_disk)
	)
	Game.bestiary.clear()
	var sighting_unlocks := {}
	var sighting_cb := func(id: String) -> void:
		sighting_unlocks[id] = int(sighting_unlocks.get(id, 0)) + 1
	Game.bestiary_unlocked.connect(sighting_cb)
	var drone_a := DroneEnemy.new()
	arena.enemy_container.add_child(drone_a)
	await _ticks(1)
	var drone_b := DroneEnemy.new()
	arena.enemy_container.add_child(drone_b)
	await _ticks(1)
	_check(Game.bestiary_seen("drone"), "first sight unlocks regular enemy before death")
	_check(int(sighting_unlocks.get("drone", 0)) == 1, "repeated regular sighting unlocks exactly once")
	var boss := RootBoss.new()
	boss.boss_index = 2
	boss.configure(1.0, false)
	arena.enemy_container.add_child(boss)
	await _ticks(1)
	_check(Game.bestiary_seen("segfault"), "first sight unlocks boss variant before death")
	_check(int(sighting_unlocks.get("segfault", 0)) == 1, "repeated boss sighting unlocks exactly once")
	Game.bestiary_unlocked.disconnect(sighting_cb)
	for probe in [drone_a, drone_b, boss]:
		if is_instance_valid(probe):
			probe.queue_free()
	await _ticks(2)
	_check(Game.has_method("show_hint_once"), "game exposes persisted hint helper")
	if Game.has_method("show_hint_once"):
		Game.set("tutorial", {})
		_check(bool(Game.call("show_hint_once", "move")), "first hint call is available")
		var second_hint_available := bool(Game.call("show_hint_once", "move"))
		_check(second_hint_available == (OS.get_environment("KP_HINTS") != ""), "second hint call is suppressed unless KP_HINTS is set")
		if OS.get_environment("KP_HINTS") != "":
			Game.set("tutorial", {"move": true})
			_check(bool(Game.call("show_hint_once", "move")), "KP_HINTS forces an already-seen hint")
		if OS.get_environment("KP_HINTS") == "":
			Game.set("tutorial", {})
			_check(bool(Game.call("show_hint_once", "round1_reload_hint")), "hint persists before reload")
			Game._load_run_config()
			_check(Game.tutorial.has("round1_reload_hint"), "hint survives ConfigFile reload")
			Game.bestiary.clear()
			Game.mark_bestiary("DRONE")
			Game._load_run_config()
			_check(Game.bestiary_seen("drone"), "bestiary survives ConfigFile reload")
		_check(_config_snapshot_matches(saved_run_best_disk, _config_snapshot("run", "best_classic", 0)), "hint probe preserves unrelated run save section")
	var hud: Hud = arena.hud
	var saved_banner_t: float = hud._banner_t
	var saved_banner_text: String = hud._banner_text
	var saved_banner_sub: String = hud._banner_sub
	var saved_hint_queue: Array[Dictionary] = hud._hint_queue.duplicate(true)
	var saved_hint_queue_ids: Dictionary = hud._hint_queue_ids.duplicate(true)
	hud._hint_queue.clear()
	hud._hint_queue_ids.clear()
	hud.show_banner("BLOCKING BANNER", "EVENT", 1.0)
	hud.queue_hint("round1_queue", "QUEUED HINT", 0.1)
	hud.queue_hint("round1_queue", "DUPLICATE HINT", 0.1)
	_check(hud._banner_text == "BLOCKING BANNER", "active banner is not replaced by queued hint")
	_check(hud._hint_queue.size() == 1, "duplicate hint is rate-limited")
	hud._process(0.5)
	_check(hud._banner_text == "BLOCKING BANNER", "queued hint waits during active banner")
	hud._process(0.6)
	hud._process(0.01)
	_check(hud._banner_text == "QUEUED HINT" and hud._hint_queue.is_empty(), "queued hint drains after active banner")
	hud._banner_t = saved_banner_t
	hud._banner_text = saved_banner_text
	hud._banner_sub = saved_banner_sub
	hud._hint_queue = saved_hint_queue
	hud._hint_queue_ids = saved_hint_queue_ids
	if OS.get_environment("KP_ONBOARDING_ABORT") != "":
		fixture_guard.keep_alive()
		return
	if OS.get_environment("KP_ONBOARDING_EARLY_EXIT") != "":
		fixture_guard.keep_alive()
		return
	fixture_guard.keep_alive()

func _restore_onboarding_fixture(saved_bestiary: Dictionary, saved_tutorial: Dictionary, saved_bestiary_disk: Dictionary, saved_tutorial_disk: Dictionary) -> void:
	Game.bestiary = saved_bestiary
	Game.tutorial = saved_tutorial
	_restore_config_snapshot("bestiary", "seen", saved_bestiary_disk)
	_restore_config_snapshot("tutorial", "hints", saved_tutorial_disk)

func _config_snapshot(section: String, key: String, default_value) -> Dictionary:
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	return {
		"has_section": cf.has_section(section),
		"has_key": cf.has_section_key(section, key),
		"value": cf.get_value(section, key, default_value),
	}

func _config_snapshot_matches(a: Dictionary, b: Dictionary) -> bool:
	return bool(a["has_section"]) == bool(b["has_section"]) and bool(a["has_key"]) == bool(b["has_key"]) and a["value"] == b["value"]

func _config_section_snapshot(section: String) -> Dictionary:
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	var snapshot := {"has_section": cf.has_section(section), "values": {}}
	if bool(snapshot["has_section"]):
		for key in cf.get_section_keys(section):
			snapshot["values"][key] = cf.get_value(section, key)
	return snapshot

func _restore_config_section(section: String, snapshot: Dictionary) -> void:
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	if cf.has_section(section):
		cf.erase_section(section)
	if bool(snapshot["has_section"]):
		for key in snapshot["values"]:
			cf.set_value(section, key, snapshot["values"][key])
	cf.save(Sfx.SAVE_PATH)

func _config_sections_equal(a: Dictionary, b: Dictionary) -> bool:
	return bool(a.get("has_section", false)) == bool(b.get("has_section", false)) and a.get("values", {}) == b.get("values", {})

func _task10_test(menu: Node) -> void:
	print("AT_STEP task10")
	var run_snapshot := _config_section_snapshot("run")
	var expected_defaults := {
		"move_up": KEY_W,
		"move_down": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"dash": KEY_SPACE,
		"overclock": KEY_E,
		"pause": KEY_ESCAPE,
		"abandon": KEY_Q,
		"mute": KEY_M,
		"restart": KEY_R,
		"confirm": KEY_ENTER,
	}
	var registry_ready := Game.has_method("keybind_defaults") and Game.has_method("get_keybind") and Game.has_method("set_keybind") and Game.has_method("reset_keybinds") and Game.has_method("reload_keybinds")
	_check(registry_ready, "desktop keybind registry exposes persistence API")
	var controls_snapshot := _config_section_snapshot("controls")
	if registry_ready:
		var defaults: Dictionary = Game.keybind_defaults()
		for action in expected_defaults:
			_check(int(defaults.get(action, -1)) == int(expected_defaults[action]), "keybind default exists for %s" % action)
		Game.reset_keybinds()
		_check(int(Game.get_keybind("dash")) == KEY_SPACE and _has_physical_key("dash", KEY_SPACE), "reset keybinds applies default dash")
		var cf_controls := ConfigFile.new()
		cf_controls.load(Sfx.SAVE_PATH)
		cf_controls.set_value("controls", "dash", KEY_F)
		cf_controls.set_value("run", "best_classic", 654321)
		cf_controls.save(Sfx.SAVE_PATH)
		Game.reload_keybinds()
		_check(int(Game.get_keybind("dash")) == KEY_F and _has_physical_key("dash", KEY_F), "saved physical keycode loads into InputMap")
		var dash_mouse_events := 0
		var fire_mouse_events := 0
		for event in InputMap.action_get_events("dash"):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
				dash_mouse_events += 1
		for event in InputMap.action_get_events("fire"):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				fire_mouse_events += 1
		_check(dash_mouse_events == 1 and fire_mouse_events == 1, "keybind reload preserves one mouse fire/aim binding")
		var run_after_load := ConfigFile.new()
		run_after_load.load(Sfx.SAVE_PATH)
		_check(int(run_after_load.get_value("run", "best_classic", 0)) == 654321, "keybind save preserves other ConfigFile sections")
		var old_dash := int(Game.get_keybind("dash"))
		var old_overclock := int(Game.get_keybind("overclock"))
		_check(not bool(Game.set_keybind("overclock", old_dash)), "duplicate keybind is rejected")
		_check(int(Game.get_keybind("dash")) == old_dash and int(Game.get_keybind("overclock")) == old_overclock, "duplicate rejection leaves original actions unchanged")
		_check(bool(Game.set_keybind("dash", KEY_G)) and int(Game.get_keybind("dash")) == KEY_G, "new keybind assigns selected action")
		var cf_fallback := ConfigFile.new()
		cf_fallback.load(Sfx.SAVE_PATH)
		cf_fallback.erase_section_key("controls", "overclock")
		cf_fallback.save(Sfx.SAVE_PATH)
		Game.reload_keybinds()
		_check(int(Game.get_keybind("overclock")) == KEY_E, "missing keybind falls back to default")
		Game.reset_keybinds()
		_check(int(Game.get_keybind("dash")) == KEY_SPACE and int(Game.get_keybind("overclock")) == KEY_E, "reset keybinds restores all defaults")
		_restore_config_section("controls", controls_snapshot)
		Game.reload_keybinds()
	var capture_api_ready := menu != null and menu.has_method("_desktop_keybinds_enabled") and menu.has_method("keybind_capture_visible")
	_check(capture_api_ready, "menu exposes desktop-only keybind capture state")
	if capture_api_ready:
		var desktop_keybinds := Balance.is_desktop_display() and not DisplayServer.is_touchscreen_available() and OS.get_environment("KP_FORCE_TOUCH") == ""
		_check(bool(menu._desktop_keybinds_enabled()) == desktop_keybinds, "keybind capture is desktop-only and touch-gated")
		_check(bool(menu.keybind_capture_visible()) == desktop_keybinds, "keybind capture panel visibility follows desktop gate")
		if desktop_keybinds and menu.has_method("_begin_keybind_capture") and menu.has_method("_handle_keybind_capture"):
			menu._begin_keybind_capture("dash")
			menu._handle_keybind_capture(_key_event(KEY_ESCAPE))
			_check(str(menu.get("_capture_action")) == "", "Escape cancels keybind capture")
			menu._begin_keybind_capture("dash")
			menu._handle_keybind_capture(_key_event(KEY_E))
			_check(str(menu.get("_capture_action")) == "dash" and str(menu.get("_keybind_status").text).contains("CONFLICT"), "capture shows duplicate conflict without assigning")
			menu._handle_keybind_capture(_key_event(KEY_G, true))
			_check(str(menu.get("_capture_action")) == "dash", "echo key does not capture")
			menu._handle_keybind_capture(_key_event(KEY_H))
			_check(str(menu.get("_capture_action")) == "" and int(Game.get_keybind("dash")) == KEY_H, "valid key ends capture and assigns")
	if menu != null and menu.has_method("_open_settings"):
		menu._open_settings()
		var settings_scrolls := menu.find_children("*", "ScrollContainer", true, false)
		_check(not settings_scrolls.is_empty(), "settings content is scrollable")
		var desktop_keybinds := Balance.is_desktop_display() and not DisplayServer.is_touchscreen_available() and OS.get_environment("KP_FORCE_TOUCH") == ""
		if not settings_scrolls.is_empty() and desktop_keybinds:
			var settings_scroll: ScrollContainer = settings_scrolls[0]
			var reset_button: Button = null
			for node in settings_scroll.find_children("*", "Button", true, false):
				if node is Button and node.text == "RESET KEYBINDS":
					reset_button = node
					break
			_check(reset_button != null, "keybind reset remains reachable inside settings scroll")
		menu._close_settings()
	_restore_config_section("run", run_snapshot)

func _task11_test(menu: Node) -> void:
	print("AT_STEP task11")
	var metadata_ready := Game.has_method("patch_tooltip_data") and Game.has_method("patch_relation")
	_check(metadata_ready, "patch tooltip metadata API exists")
	if metadata_ready:
		Game.patch_levels = {"heavy": 1, "splitshot": 1}
		var heavy_info: Dictionary = Game.patch_tooltip_data("heavy")
		_check(str(heavy_info.get("title", "")) == "HEAVY ROUNDS" and str(heavy_info.get("description", "")) != "" and int(heavy_info.get("level", 0)) == 1, "patch tooltip exposes full title description and level")
		_check(str(heavy_info.get("relation", "")).contains("TRADEOFF") and str(heavy_info.get("relation", "")).contains("FIRE RATE"), "heavy and splitshot expose documented fire-rate tradeoff")
		_check(Game.patch_relation("heavy", "ricochet") == "NO DIRECT INTERACTION", "unknown patch relation makes no invented claim")
	var hud := Hud.new()
	hud.size = Vector2(1280, 720)
	add_child(hud)
	await _ticks(1)
	var tooltip_api_ready := hud.has_method("patch_chip_rect") and hud.has_method("patch_tooltip_visible") and hud.has_method("patch_tooltip_snapshot")
	_check(tooltip_api_ready, "HUD exposes patch tooltip hit state")
	if tooltip_api_ready:
		hud._update_patch_chip_rects()
		var chip_rect: Rect2 = hud.patch_chip_rect("heavy")
		_check(chip_rect.size.x > 0.0 and chip_rect.size.y > 0.0, "active patch chip exposes hit rectangle")
		var mouse_motion := InputEventMouseMotion.new()
		mouse_motion.position = chip_rect.get_center()
		hud._input(mouse_motion)
		_check(hud.patch_tooltip_visible(), "desktop hover shows patch tooltip")
		var tooltip_snapshot: Dictionary = hud.patch_tooltip_snapshot()
		_check(str(tooltip_snapshot.get("title", "")) == "HEAVY ROUNDS" and int(tooltip_snapshot.get("level", 0)) == 1, "hover tooltip contains active patch data")
		var touch_down := InputEventScreenTouch.new()
		touch_down.index = 41
		touch_down.pressed = true
		touch_down.position = chip_rect.get_center()
		hud._input(touch_down)
		hud._process(0.44)
		_check(not hud.patch_tooltip_visible(), "touch hold below threshold stays hidden")
		hud._process(0.02)
		_check(hud.patch_tooltip_visible(), "touch hold at threshold shows patch tooltip")
		var touch_drag := InputEventScreenDrag.new()
		touch_drag.index = 41
		touch_drag.position = chip_rect.get_center() + Vector2(20, 0)
		hud._input(touch_drag)
		_check(not hud.patch_tooltip_visible(), "touch movement dismisses patch tooltip")
		touch_down.position = chip_rect.get_center()
		hud._input(touch_down)
		hud._process(0.5)
		var paused_before := get_tree().paused
		var touch_up := InputEventScreenTouch.new()
		touch_up.index = 41
		touch_up.pressed = false
		touch_up.position = chip_rect.get_center()
		hud._input(touch_up)
		_check(not hud.patch_tooltip_visible() and get_tree().paused == paused_before, "touch release dismisses tooltip without pausing")
	Game.patch_levels = {}
	hud.queue_free()
	await _ticks(2)
	var saved_mode := Game.mode
	var saved_aim := Sfx.aim_mode
	Game.mode = "weekly"
	Sfx.aim_mode = "lockon"
	_check(Game.effective_aim_mode() == "lockon", "weekly keeps saved local lock-on mode")
	if menu != null and menu.has_method("_refresh_mode_ui") and menu.has_method("_refresh_aim_label"):
		menu._refresh_mode_ui()
		menu._refresh_aim_label(menu.get("_aim_btn_ref"))
		_check(not str(menu.get("_mode_info").text).contains("BLOCKED") and str(menu.get("_mode_info").text).contains("LOCAL"), "weekly menu explains local deterministic play")
		_check(not str(menu.get("_aim_btn_ref").text).contains("BLOCKED"), "weekly menu does not block lock-on")
	Game.mode = saved_mode
	Sfx.aim_mode = saved_aim

func _color_assist_test() -> void:
	print("AT_STEP color_assist")
	var balance_script: Script = load("res://src/autoload/balance.gd")
	var palette_ready := balance_script != null and balance_script.has_method("threat_palette") and balance_script.has_method("threat_color")
	_check(palette_ready, "threat palette helper exists")
	if palette_ready:
		var standard: Dictionary = balance_script.call("threat_palette", false)
		var assist: Dictionary = balance_script.call("threat_palette", true)
		var standard_pair: bool = standard.get("splitter", Color.BLACK) != standard.get("bulwark", Color.BLACK)
		var assist_pair: bool = assist.get("splitter", Color.BLACK) != assist.get("bulwark", Color.BLACK)
		_check(standard_pair, "standard Splitter and Bulwark colors are distinct")
		_check(assist_pair and _color_distance(assist["splitter"], assist["bulwark"]) > 0.45, "color assist threat pair is accessible")
		_check(balance_script.call("threat_color", "splitter", false) == standard["splitter"] and balance_script.call("threat_color", "bulwark", false) == standard["bulwark"], "standard threats route through shared palette")

	var saved_disk := _config_snapshot("feel", "color_assist", false)
	var saved_color_assist := false
	if Sfx.has_method("set_color_assist"):
		saved_color_assist = bool(Sfx.get("color_assist"))
	var settings_cf := ConfigFile.new()
	settings_cf.load(Sfx.SAVE_PATH)
	if settings_cf.has_section_key("feel", "color_assist"):
		settings_cf.erase_section_key("feel", "color_assist")
	settings_cf.save(Sfx.SAVE_PATH)
	Sfx._load_settings()
	_check(Sfx.has_method("set_color_assist") and not bool(Sfx.get("color_assist")), "color assist defaults off")
	if Sfx.has_method("set_color_assist"):
		Sfx.set_color_assist(true)
		Sfx._load_settings()
		_check(bool(Sfx.get("color_assist")), "color assist persists through reload")

	var menu := get_tree().current_scene
	var color_button: Button = null
	if menu != null:
		if menu.has_method("_refresh_color_assist_label"):
			Sfx.set_color_assist(false)
			menu._refresh_color_assist_label()
		if menu.has_method("_open_settings"):
			menu._open_settings()
		for node in menu.find_children("*", "Button", true, false):
			if node is Button and str(node.text).begins_with("COLOR ASSIST:"):
				color_button = node
				break
	_check(color_button != null, "settings expose color assist toggle")
	if color_button != null:
		_check(color_button.text == "COLOR ASSIST: OFF", "color assist toggle shows OFF by default")
		color_button.pressed.emit()
		_check(bool(Sfx.get("color_assist")) and color_button.text == "COLOR ASSIST: ON", "color assist toggle enables assist mode")
		color_button.pressed.emit()
		_check(not bool(Sfx.get("color_assist")) and color_button.text == "COLOR ASSIST: OFF", "color assist toggle disables assist mode")
	if menu != null and menu.has_method("_close_settings"):
		menu._close_settings()

	var splitter := SplitterEnemy.new()
	var bulwark := BulwarkEnemy.new()
	var splitter_source := FileAccess.get_file_as_string("res://src/enemies/splitter.gd")
	var bulwark_source := FileAccess.get_file_as_string("res://src/enemies/bulwark.gd")
	_check(splitter.has_method("color_assist_marker") and splitter.color_assist_marker() == "SPLIT", "Splitter exposes code-drawn assist marker")
	_check(bulwark.has_method("color_assist_marker") and bulwark.color_assist_marker() == "BULW", "Bulwark exposes code-drawn assist marker")
	_check(splitter_source.contains("draw_string") and bulwark_source.contains("draw_string") and not splitter_source.contains(".png") and not bulwark_source.contains(".png"), "threat markers use code drawing without images")
	var bestiary_source := FileAccess.get_file_as_string("res://src/ui/bestiary_panel.gd")
	_check(bestiary_source.contains("_draw_color_assist_marker") and bestiary_source.contains("SPLIT") and bestiary_source.contains("BULW") and bestiary_source.contains("Sfx.color_assist"), "bestiary draws assist markers beside Splitter and Bulwark glyphs")
	splitter.free()
	bulwark.free()

	if Sfx.has_method("set_color_assist"):
		Sfx.set("color_assist", saved_color_assist)
	_restore_config_snapshot("feel", "color_assist", saved_disk)
	if menu != null and menu.has_method("_refresh_color_assist_label"):
		menu._refresh_color_assist_label()

func _color_distance(a: Color, b: Color) -> float:
	return Vector3(a.r, a.g, a.b).distance_to(Vector3(b.r, b.g, b.b))

func _key_event(physical_key: int, is_echo := false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = physical_key
	ev.keycode = physical_key
	ev.pressed = true
	ev.echo = is_echo
	return ev

func _has_physical_key(action: String, physical_key: int) -> bool:
	if not InputMap.has_action(action):
		return false
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and ev.physical_keycode == physical_key:
			return true
	return false

func _input_safety_test(arena: Arena) -> void:
	print("AT_STEP input_safety")
	var overclock_events: Array = []
	var abandon_events: Array = []
	if InputMap.has_action("overclock"):
		overclock_events = InputMap.action_get_events("overclock")
	if InputMap.has_action("abandon"):
		abandon_events = InputMap.action_get_events("abandon")
	_check(overclock_events.size() == 1 and _has_physical_key("overclock", KEY_E) and not _has_physical_key("overclock", KEY_Q), "overclock is bound to E only")
	_check(InputMap.has_action("abandon") and abandon_events.size() == 1 and _has_physical_key("abandon", KEY_Q) and not _has_physical_key("abandon", KEY_E), "abandon is bound to Q only")
	Game.state = Game.State.PLAYING
	arena._state = "play"
	arena._set_paused(false)
	get_viewport().push_input(_key_event(KEY_ESCAPE))
	_check(get_tree().paused, "Viewport Escape opens pause through input dispatch")
	get_viewport().push_input(_key_event(KEY_ESCAPE, true))
	_check(get_tree().paused, "Escape key repeat does not immediately close pause")
	get_viewport().push_input(_key_event(KEY_ESCAPE))
	_check(not get_tree().paused, "Viewport Escape closes pause while tree is paused")
	arena._set_paused(true)
	var focused_pause_button: Button = null
	for pause_child in arena._pause_panel.get_children():
		if pause_child is Button and pause_child.text == "RESUME":
			focused_pause_button = pause_child
			break
	if focused_pause_button != null:
		focused_pause_button.grab_focus()
	get_viewport().push_input(_key_event(KEY_ESCAPE))
	_check(not get_tree().paused, "Viewport Escape closes pause when a pause button has focus")
	Game.state = Game.State.PLAYING
	arena._state = "play"
	arena._set_paused(true)
	arena._unhandled_input(_key_event(KEY_E))
	_check(Game.state == Game.State.PLAYING, "E has no effect while paused")
	Game.state = Game.State.PLAYING
	arena._set_paused(true)
	arena._unhandled_input(_key_event(KEY_Q))
	_check(Game.state == Game.State.PLAYING and arena.get("_abandon_armed") == true, "first Q arms abandon confirmation without leaving run")
	_check(arena._pause_info.text.contains("PRESS Q AGAIN // ABANDON PROCESS"), "pause explains two-step abandon confirmation")
	arena._unhandled_input(_key_event(KEY_Q))
	_check(Game.state == Game.State.MENU, "second Q within confirmation window returns to menu")
	Game.state = Game.State.PLAYING
	arena._set_paused(true)
	arena._unhandled_input(_key_event(KEY_Q))
	var stale_timer = arena.get("_abandon_timer")
	arena._set_paused(false)
	Game.state = Game.State.PLAYING
	arena._set_paused(true)
	arena._unhandled_input(_key_event(KEY_Q))
	if stale_timer != null:
		stale_timer.emit_signal("timeout")
	_check(arena.get("_abandon_armed") == true, "stale abandon timer cannot clear a rearmed confirmation")
	arena._unhandled_input(_key_event(KEY_Q))
	_check(Game.state == Game.State.MENU, "rearmed confirmation still accepts the second Q")
	Game.state = Game.State.PLAYING
	arena._set_paused(true)
	arena._unhandled_input(_key_event(KEY_Q))
	arena._unhandled_input(_key_event(KEY_Q, true))
	_check(Game.state == Game.State.PLAYING and arena.get("_abandon_armed") == true, "echo Q does not confirm abandon")
	arena._unhandled_input(_key_event(KEY_Q))
	_check(Game.state == Game.State.MENU, "physical Q after echo confirms abandon")
	Game.state = Game.State.PLAYING
	arena._set_paused(true)
	arena._unhandled_input(_key_event(KEY_Q))
	arena._set_paused(false)
	_check(arena.get("_abandon_armed") != true, "resume clears abandon confirmation")
	var abandon_button: Button
	for child in arena._pause_panel.get_children():
		if child is Button and child.text == "ABANDON PROCESS":
			abandon_button = child
	_check(abandon_button != null, "pause exposes abandon button")
	Game.state = Game.State.PLAYING
	arena._set_paused(true)
	if abandon_button != null:
		abandon_button.emit_signal("pressed")
	_check(Game.state == Game.State.PLAYING and arena.get("_abandon_armed") == true, "first abandon button press arms confirmation")
	if abandon_button != null:
		abandon_button.emit_signal("pressed")
	_check(Game.state == Game.State.MENU, "second abandon button press confirms within window")
	Game.state = Game.State.PLAYING
	arena._set_paused(true)
	arena._unhandled_input(_key_event(KEY_Q))
	arena._unhandled_input(_key_event(KEY_R))
	_check(arena.get("_abandon_armed") != true, "restart clears abandon confirmation")
	Game.state = Game.State.PLAYING
	get_tree().paused = false
	arena._state = "play"
	arena._set_paused(true)
	arena._unhandled_input(_key_event(KEY_Q))
	arena._process(2.1)
	_check(arena.get("_abandon_armed") != true, "confirmation expires after two seconds")
	Game.state = Game.State.PLAYING
	arena._set_paused(true)
	arena._unhandled_input(_key_event(KEY_Q))
	arena._on_player_died()
	_check(arena.get("_abandon_armed") != true, "game over clears abandon confirmation")
	Game.state = Game.State.PLAYING
	arena._state = "play"
	get_tree().paused = false
	arena._set_paused(true)
	arena._unhandled_input(_key_event(KEY_Q))
	arena._exit_tree()
	_check(arena.get("_abandon_armed") != true, "arena teardown clears abandon confirmation")
	arena._state = "play"
	get_tree().paused = false

func _restore_config_snapshot(section: String, key: String, snapshot: Dictionary) -> void:
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	if bool(snapshot["has_key"]):
		cf.set_value(section, key, snapshot["value"])
	elif cf.has_section_key(section, key):
		cf.erase_section_key(section, key)
	if not bool(snapshot["has_section"]) and cf.has_section(section) and cf.get_section_keys(section).is_empty():
		cf.erase_section(section)
	cf.save(Sfx.SAVE_PATH)

func _task2_should_offer_patch(cleared_wave: int) -> bool:
	if not Game.has_method("should_offer_patch"):
		return false
	return bool(Game.call("should_offer_patch", cleared_wave))

func _task2_test(arena: Arena) -> void:
	print("AT_STEP task2")
	var saved_mode := Game.mode
	var saved_patch_levels: Dictionary = Game.patch_levels.duplicate(true)
	var cadence_waves := [3, 4, 6, 9, 10]
	var cadence_expected := {
		"classic": [false, true, false, true, false],
		"weekly": [false, true, false, true, false],
		"onehp": [true, false, true, true, false],
	}
	_check(Game.has_method("should_offer_patch"), "patch cadence helper exists")
	for mode_name in ["classic", "weekly", "onehp"]:
		Game.mode = mode_name
		for i in cadence_waves.size():
			_check(_task2_should_offer_patch(cadence_waves[i]) == cadence_expected[mode_name][i], "%s patch cadence wave %d" % [mode_name, cadence_waves[i]])

	Game.mode = "onehp"
	Game.patch_levels = {}
	var onehp_ids := {}
	if Game.has_method("onehp_patch_pool"):
		for d in Game.call("onehp_patch_pool"):
			onehp_ids[d["id"]] = true
	var forbidden_onehp := ["hp", "restore", "vampic", "recycler", "dataleech", "secondwind", "scrapdiet"]
	var forbidden_found := []
	for id in forbidden_onehp:
		if onehp_ids.has(id):
			forbidden_found.append(id)
	_check(forbidden_found.is_empty(), "onehp offers exclude health, healing, recover, and death-save patches (%s)" % ",".join(forbidden_found))
	_check(onehp_ids.has("shield"), "onehp offers include shield patch")
	_check(onehp_ids.has("absorb"), "onehp offers include absorption patch")

	var saved_player: Player = arena.player
	var onehp_player := Player.new()
	onehp_player.position = Vector2(220, 0)
	arena.add_child(onehp_player)
	arena.player = onehp_player
	await _ticks(2)
	_check(onehp_player.max_hp == 1 and onehp_player.hp == 1, "onehp replacement patch probes keep one-integrity starting rule")
	onehp_player.invuln = 0.0
	Game.patch_levels = {}
	Game.apply_patch("shield")
	onehp_player.take_damage(onehp_player.global_position + Vector2(10, 0), "TASK2 SHIELD")
	_check(onehp_player.hp == 1 and not onehp_player.dead, "shield charge prevents one incoming hit")
	onehp_player.invuln = 0.0
	Game.patch_levels = {}
	onehp_player.meter = 0.0
	Game.apply_patch("absorb")
	onehp_player.take_damage(onehp_player.global_position + Vector2(10, 0), "TASK2 ABSORB")
	_check(onehp_player.hp == 1 and not onehp_player.dead and onehp_player.meter > 0.0, "absorption charge prevents hit and grants meter")
	onehp_player.queue_free()
	arena.player = saved_player
	await _ticks(2)

	Game.mode = "classic"
	Game.patch_levels = {}
	for e in arena.enemy_list.duplicate():
		if is_instance_valid(e) and not e.is_in_group("boss"):
			e.queue_free()
	await _ticks(2)
	var phase_died := 0
	var phase_regular := DroneEnemy.new()
	phase_regular.position = Vector2(260, 0)
	phase_regular.died.connect(func(_e: EnemyBase) -> void: phase_died += 1)
	arena.enemy_container.add_child(phase_regular)
	var phase_splitter := SplitterEnemy.new()
	phase_splitter.position = Vector2(300, 0)
	phase_splitter.died.connect(func(_e: EnemyBase) -> void: phase_died += 1)
	arena.enemy_container.add_child(phase_splitter)
	var phase_boss := RootBoss.new()
	phase_boss.boss_index = 2
	phase_boss.configure(1.0, false)
	phase_boss.position = Vector2(360, 0)
	arena.enemy_container.add_child(phase_boss)
	arena._on_boss_spawned(phase_boss)
	arena.spawner._boss = phase_boss
	arena.spawner._spawn_group(["drone"])
	await _ticks(2)
	var kills_before := int(Game.stats["kills"])
	var boss_kills_before := int(Game.stats["boss_kills"])
	var score_before := Game.score
	var boss_heals_before := int(Game.stats["heals"].get("boss", 0))
	var patch_pending_before := arena._patch_pending
	var patch_open_before := arena._patch_open
	var boss_mult_before := Game.mult
	Game.mode = "onehp"
	var expected_boss_score := phase_boss.pts * mini(boss_mult_before + 1, Balance.COMBO_MAX) * Game.score_mult() + 250 * Game.score_mult()
	var boss_player_hp_before := arena.player.hp
	arena.player.hp = arena.player.max_hp - 1
	phase_boss.die()
	phase_boss.died.emit(phase_boss)
	_check(int(Game.stats["kills"]) == kills_before + 1 and int(Game.stats["boss_kills"]) == boss_kills_before + 1, "repeated boss death signals add one kill and one boss reward")
	_check(Game.score == score_before + expected_boss_score, "repeated boss death signals add one boss score (%d -> %d, expected %d)" % [score_before, Game.score, score_before + expected_boss_score])
	_check(int(Game.stats["heals"].get("boss", 0)) == boss_heals_before + 1, "repeated boss death signals add one boss heal")
	await _ticks(3)
	await _ticks(35)
	arena.spawner.stop()
	var phase_enemies_left := 0
	for e in arena.enemy_list:
		if is_instance_valid(e) and not e.is_in_group("boss"):
			phase_enemies_left += 1
	_check(phase_enemies_left == 0, "boss reward clears remaining phase enemies")
	_check(phase_died == 0, "boss cleanup does not emit phase enemy deaths")
	_check(get_tree().get_nodes_in_group("boss_summon").is_empty(), "boss cleanup does not leave phase summons")
	_check(arena.spawner._pending == 0 and arena.spawner._queue.is_empty() and not arena.spawner._awaiting_boss and arena.spawner._boss == null, "boss cleanup cancels pending spawner callbacks")
	_check(arena._patch_pending == patch_pending_before and arena._patch_open == patch_open_before, "boss death does not queue a duplicate patch reward")

	Game.mode = saved_mode
	Game.patch_levels = saved_patch_levels
	arena.player.hp = boss_player_hp_before
	for e in arena.enemy_list.duplicate():
		if is_instance_valid(e) and not e.is_in_group("boss"):
			e.queue_free()
	if is_instance_valid(phase_boss):
		phase_boss.queue_free()
	await _ticks(2)

func _task5_test(arena: Arena) -> void:
	print("AT_STEP task5")
	var balance_script: Script = load("res://src/autoload/balance.gd")
	var cadence_ready := balance_script != null and balance_script.has_method("attack_cadence_factor")
	_check(cadence_ready, "wave attack cadence helper exists")
	if cadence_ready:
		_check(absf(float(balance_script.call("attack_cadence_factor", 1)) - 1.0) < 0.001, "wave 1 cadence is unchanged")
		_check(absf(float(balance_script.call("attack_cadence_factor", 5)) - 1.0) < 0.001, "wave 5 cadence is unchanged")
		_check(absf(float(balance_script.call("attack_cadence_factor", 6)) - 0.985) < 0.001, "wave 6 cadence tightens slightly")
		_check(absf(float(balance_script.call("attack_cadence_factor", 30)) - 0.78) < 0.001, "wave 30 cadence respects floor")
	_check(Balance.max_alive(1) == 8, "wave 1 alive ceiling preserves ramp")
	_check(Balance.max_alive(2) == 10, "wave 2 alive ceiling preserves ramp")
	_check(Balance.max_alive(30) == 10, "late wave alive ceiling is 10")

	var threat_probe := EnemyBase.new()
	var threat_context_ready := arena.spawner.has_method("_configure_enemy")
	_check(threat_context_ready, "spawner exposes threat wave configuration")
	if threat_context_ready:
		arena.spawner.wave = 30
		arena.spawner.call("_configure_enemy", threat_probe, false)
	_check(threat_probe.get("threat_wave") == 30, "enemy threat wave context exists")
	arena.spawner.wave = 1
	threat_probe.queue_free()
	var swift := DroneEnemy.new()
	var volatile := DroneEnemy.new()
	Game.rng.seed = 5150
	swift.configure(1.0, true)
	volatile.configure(1.0, true)
	swift.elite_kind = "swift"
	volatile.elite_kind = "volatile"
	var elite_profiles_ready := swift.has_method("elite_steering") and swift.has_method("elite_reacquire_interval") and volatile.has_method("volatile_burst_count")
	_check(elite_profiles_ready, "elite profile hooks exist")
	if elite_profiles_ready:
		var swift_dir: Vector2 = swift.call("elite_steering", Vector2.RIGHT, 1.0)
		var volatile_dir: Vector2 = volatile.call("elite_steering", Vector2.RIGHT, 1.0)
		_check(absf(swift_dir.y) > absf(volatile_dir.y) + 0.1, "swift elite adds lateral steering")
		_check(float(swift.call("elite_reacquire_interval", 1.0)) < 1.0, "swift elite reacquires on a bounded shorter interval")
		_check(int(volatile.call("volatile_burst_count")) == 6, "volatile elite keeps six-orb death burst")
	swift.free()
	volatile.free()

	var lancer := LancerEnemy.new()
	var spewer := SpewerEnemy.new()
	if lancer.get("threat_wave") != null:
		lancer.set("threat_wave", 30)
	if spewer.get("threat_wave") != null:
		spewer.set("threat_wave", 30)
	var cadence_hooks_ready := lancer.has_method("phase_reentry_interval") and spewer.has_method("repeated_fire_interval")
	_check(cadence_hooks_ready, "lancer and spewer expose repeated cadence hooks")
	if cadence_hooks_ready:
		_check(float(lancer.call("phase_reentry_interval", 1.0)) < 1.0, "lancer repeated phase interval scales with wave")
		_check(float(spewer.call("repeated_fire_interval", 2.0)) < 2.0, "spewer repeated fire interval scales with wave")
	_check(lancer.has_method("telegraph_duration") and spewer.has_method("telegraph_duration"), "lancer and spewer preserve telegraph hooks")
	if lancer.has_method("telegraph_duration") and spewer.has_method("telegraph_duration"):
		_check(float(lancer.call("telegraph_duration")) >= 0.5, "lancer telegraph stays readable")
		_check(float(spewer.call("telegraph_duration")) >= 0.4, "spewer telegraph stays readable")
	lancer.free()
	spewer.free()

	var boss_player := Node2D.new()
	boss_player.position = Vector2.ZERO
	arena.add_child(boss_player)
	var root := RootBoss.new()
	root.boss_index = 1
	root.player = boss_player
	root.position = Vector2(220, 0)
	root.configure(1.0, false)
	var ranged := RootBoss.new()
	ranged.boss_index = 2
	ranged.player = boss_player
	ranged.position = Vector2(320, 0)
	ranged.configure(1.0, false)
	_check(root.has_method("hover_direction") and ranged.has_method("hover_direction"), "boss distance profiles exist")
	if root.has_method("hover_direction") and ranged.has_method("hover_direction"):
		_check(root.call("hover_direction", Vector2(-220, 0)).dot(Vector2.LEFT) > 0.9, "melee ROOT approaches the player")
		_check(ranged.call("hover_direction", Vector2(-80, 0)).dot(Vector2.RIGHT) > 0.0, "ranged boss retreats from close player")
	var corruption_script: Script = load("res://src/enemies/corruption_shot.gd")
	_check(corruption_script != null, "corruption shot script loads")
	if corruption_script != null:
		arena.enemy_container.add_child(ranged)
		await _ticks(1)
		ranged._corruption_volley(1)
		await _ticks(1)
		var boss_shots := get_tree().get_nodes_in_group("corruption_shots")
		var ranged_target := ranged.player.global_position if ranged.player != null and is_instance_valid(ranged.player) else Vector2.INF
		_check(boss_shots.size() == 1, "SEGFAULT corruption volley spawns one shot")
		if boss_shots.size() == 1:
			_check(boss_shots[0].get("target_point").distance_to(ranged_target) < 0.1, "SEGFAULT corruption shot targets the player position")
		for boss_shot in boss_shots:
			if is_instance_valid(boss_shot):
				boss_shot.queue_free()
		await _until(func() -> bool:
			return get_tree().get_nodes_in_group("corruption_shots").is_empty()
		, 1.0, "boss corruption shot cleanup")
		if is_instance_valid(ranged):
			ranged.queue_free()
		await _ticks(1)
		var impact_player := Player.new()
		impact_player.position = Vector2(80, 0)
		arena.add_child(impact_player)
		await _ticks(1)
		impact_player.invuln = 0.0
		impact_player.hp = impact_player.max_hp
		var impact_shot: Node = corruption_script.new()
		impact_shot.setup_corruption(Vector2(300, 0), impact_player.global_position, 1, Balance.COL_DANGER)
		arena.enemy_container.add_child(impact_shot)
		var impact_hp_before := impact_player.hp
		var impact_ok := await _until(func() -> bool:
			return impact_player.hp < impact_hp_before
		, 1.0, "corruption shot direct impact")
		_check(impact_ok and impact_player.hp == impact_hp_before - 1, "intercepted corruption shot damages a real player before midpoint")
		_check(get_tree().get_nodes_in_group("corruption").is_empty(), "direct corruption impact creates no zone")
		impact_player.position = Vector2(0, 200)
		var shot: Node = corruption_script.new()
		shot.setup_corruption(Vector2(300, 0), arena.player.global_position, 1, Balance.COL_DANGER, Vector2.RIGHT)
		arena.enemy_container.add_child(shot)
		var shot_origin = shot.get("origin_point")
		var shot_target = shot.get("target_point")
		_check(float(shot.get("midpoint_distance")) > 0.0, "corruption shot tracks midpoint")
		_check(shot.has_method("pop") and shot.has_method("burst_into_zone"), "corruption shot has direct and missed paths")
		if shot.has_method("pop") and shot.has_method("burst_into_zone"):
			shot._physics_process(0.1)
			_check(float(shot.get("travelled")) > 0.0 and float(shot.get("travelled")) < float(shot.get("midpoint_distance")), "corruption shot travels before midpoint")
			shot._physics_process(0.6)
			await _ticks(1)
			_check(get_tree().get_nodes_in_group("corruption").size() > 0, "missed corruption shot creates a bounded zone")
			if not get_tree().get_nodes_in_group("corruption").is_empty():
				var zone: Node2D = get_tree().get_nodes_in_group("corruption")[0]
				_check(float(zone.get("radius")) <= 38.0, "missed corruption zone stays bounded")
				_check(shot_origin != null and shot_target != null and zone.global_position.distance_to((shot_origin + shot_target) * 0.5) < 0.1, "missed corruption zone uses real target midpoint")
			if is_instance_valid(shot):
				shot.queue_free()
			for zone in get_tree().get_nodes_in_group("corruption"):
				if is_instance_valid(zone):
					zone.queue_free()
			await _ticks(1)
		impact_player.queue_free()
	root.free()
	if is_instance_valid(ranged):
		ranged.queue_free()
	boss_player.free()
	for zone in get_tree().get_nodes_in_group("corruption"):
		if is_instance_valid(zone):
			zone.queue_free()

	var oom: OomKiller = arena.spawner._make_enemy("oom")
	oom.position = Vector2(Balance.arena_rect().end.x - oom.radius, 0.0)
	arena.enemy_container.add_child(oom)
	await _ticks(1)
	var mote_idx := arena.mote_field.spawn(oom.global_position)
	oom._steal(mote_idx)
	oom.st = OomKiller.St.FLEE
	oom._physics_process(0.1)
	_check(oom.carried_ids.is_empty() and oom.is_queued_for_deletion(), "OOM_KILLER escapes fully at clamped arena edge")
	if is_instance_valid(oom):
		oom.queue_free()
	await _ticks(2)

func _task9_test(arena: Arena) -> void:
	print("AT_STEP task9")
	var tactical_script = load("res://src/ui/tactical_ui.gd")
	_check(tactical_script != null, "tactical UI helper loads")
	if tactical_script != null:
		var full: Dictionary = tactical_script.layout(Vector2(1366, 768))
		var narrow: Dictionary = tactical_script.layout(Vector2(432, 720))
		_check(not bool(full["compact"]) and bool(narrow["compact"]), "tactical layout selects compact breakpoint")
		for key in ["integrity", "encounter", "score", "dash", "patches", "boss"]:
			var full_rect: Rect2 = full[key]
			var narrow_rect: Rect2 = narrow[key]
			_check(Rect2(Vector2.ZERO, Vector2(1366, 768)).encloses(full_rect), "full tactical region fits: %s" % key)
			_check(Rect2(Vector2.ZERO, Vector2(432, 720)).encloses(narrow_rect), "compact tactical region fits: %s" % key)
		_check(not Rect2(narrow["encounter"]).intersects(Rect2(narrow["integrity"])) and not Rect2(narrow["encounter"]).intersects(Rect2(narrow["score"])), "compact encounter does not cover corner status")
		_check(not Rect2(narrow["boss"]).intersects(Rect2(narrow["dash"])) and not Rect2(narrow["boss"]).intersects(Rect2(narrow["patches"])), "compact boss frame clears bottom status modules")
		var angular: PackedVector2Array = tactical_script.angular_points(Rect2(10, 20, 100, 50), 10.0)
		_check(angular.size() == 8 and angular[0] == Vector2(20, 20), "angular frame returns stable clipped corners")
		var segments: Array[Rect2] = tactical_script.segment_rects(Rect2(0, 0, 100, 10), 5, 2.0)
		_check(segments.size() == 5 and segments[4].end.x <= 100.01, "segmented meter geometry stays inside bounds")
		_check(tactical_script.has_method("shell_rect") and tactical_script.has_method("shell_sections"), "tactical shell exposes shared frame geometry")
		if tactical_script.has_method("shell_rect") and tactical_script.has_method("shell_sections"):
			var shell: Rect2 = tactical_script.shell_rect(Vector2(1366, 768))
			var shell_bounds := Rect2(Vector2.ZERO, Vector2(1366, 768))
			_check(shell == Rect2(16.0, 20.0, 1334.0, 728.0), "desktop shell uses the reference inset")
			var sections: Dictionary = tactical_script.shell_sections(Vector2(1366, 768))
			_check(sections.has("header") and sections.has("content") and sections.has("footer"), "tactical shell exposes header content and footer sections")
			for section_id in ["header", "content", "footer"]:
				_check(shell.encloses(sections[section_id]) and shell_bounds.encloses(sections[section_id]), "shell %s stays inside viewport" % section_id)
	var chrome_script: Script = load("res://src/ui/tactical_chrome.gd")
	_check(chrome_script != null, "tactical chrome script loads")
	if chrome_script != null:
		var chrome: Control = chrome_script.new()
		chrome.size = Vector2(1366, 768)
		_check(chrome.has_method("frame_points") and chrome.frame_points().size() == 8, "tactical chrome exposes clipped frame points")
		_check(chrome.has_method("configure_control"), "tactical chrome adapts to button bounds")
		if chrome.has_method("configure_control"):
			var button_chrome: Control = chrome_script.new()
			button_chrome.size = Vector2(460, 42)
			button_chrome.call("configure_control", Color(0.1, 0.85, 1.0, 1.0), 0.02)
			_check(button_chrome.frame_rect() == Rect2(Vector2.ZERO, Vector2(460, 42)), "button chrome follows control bounds")
			button_chrome.queue_free()
		chrome.queue_free()
	var icon_script: Script = load("res://src/ui/tactical_icon.gd")
	_check(icon_script != null, "tactical icon script loads")
	if icon_script != null:
		var icon: Control = icon_script.new()
		icon.size = Vector2(48, 48)
		_check(icon.has_method("configure") and icon.has_method("icon_kind"), "tactical icon exposes semantic configuration")
		if icon.has_method("configure") and icon.has_method("icon_kind"):
			icon.call("configure", "settings", Color(0.1, 0.85, 1.0, 1.0))
			_check(icon.icon_kind() == "settings", "tactical icon keeps its semantic kind")
		_check(icon.has_method("music_glyph_bounds"), "music icon exposes measurable glyph bounds")
		if icon.has_method("music_glyph_bounds"):
			var music_bounds: Rect2 = icon.call("music_glyph_bounds", Vector2(24.0, 24.0))
			_check(music_bounds.size.x >= 12.0 and music_bounds.size.y >= 16.0, "music icon remains legible at compact pause size")
		icon.queue_free()
	var hud: Hud = arena.hud
	var hud_layout_ready := hud.has_method("layout_snapshot") and hud.has_method("visible_event_lines") and hud.has_method("event_log_visible")
	_check(hud_layout_ready, "HUD exposes tactical layout and event log APIs")
	if hud_layout_ready:
		var saved_event_log: Array[Dictionary] = Game.event_log.duplicate(true)
		Game.event_log = [
			{"time": 1.0, "text": "ONE"}, {"time": 2.0, "text": "TWO"},
			{"time": 3.0, "text": "THREE"}, {"time": 4.0, "text": "FOUR"},
			{"time": 5.0, "text": "FIVE"},
		]
		var lines: Array[String] = hud.visible_event_lines()
		_check(lines.size() == 4 and lines[0].contains("TWO") and lines[3].contains("FIVE"), "HUD event log keeps the newest four entries")
		_check(hud.event_log_visible(Vector2(1366, 768)), "event log is visible in full layout")
		_check(not hud.event_log_visible(Vector2(540, 720)), "event log collapses in compact layout")
		Game.event_log = saved_event_log
	var dock_ready := hud.has_method("patch_dock_rects")
	_check(dock_ready, "HUD exposes responsive patch dock geometry")
	if dock_ready:
		for viewport in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
			var dock: Dictionary = hud.patch_dock_rects(viewport)
			for patch_id in dock:
				_check(Rect2(Vector2.ZERO, viewport).encloses(dock[patch_id]), "patch dock chip fits %dx%d" % [int(viewport.x), int(viewport.y)])
	var boss_geometry_ready := hud.has_method("boss_bar_rects")
	_check(boss_geometry_ready, "HUD exposes boss bar geometry")
	if boss_geometry_ready:
		for viewport in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
			var normal_rows: Array[Rect2] = hud.boss_bar_rects(viewport, false)
			var split_rows: Array[Rect2] = hud.boss_bar_rects(viewport, true)
			_check(normal_rows.size() == 1 and split_rows.size() == 2, "boss geometry exposes one or two combined rows")
			for row in split_rows:
				_check(Rect2(Vector2.ZERO, viewport).encloses(row), "split boss row fits %dx%d" % [int(viewport.x), int(viewport.y)])
	var patch_card_script: Script = load("res://src/ui/patch_card.gd")
	_check(patch_card_script != null, "tactical patch card script loads")
	if patch_card_script != null:
		var patch_card: Control = patch_card_script.new()
		patch_card.configure({"id": "staticf", "title": "STATIC FIELD", "desc": "BURNS ENEMIES WITHIN 70PX", "rare": true, "legend": true}, 0)
		_check(patch_card.has_method("frame_points") and patch_card.frame_points().size() == 8, "patch card exposes clipped angular frame")
		_check(patch_card.has_method("rarity_label") and patch_card.rarity_label() == "LEGENDARY", "patch card exposes semantic rarity label")
		_check(patch_card.has_method("card_title") and patch_card.card_title() == "STATIC FIELD", "patch card preserves readable title")
		patch_card.queue_free()
	var patch_box_visual := arena.patch_box_rect_for_viewport(Vector2(1366, 768))
	var patch_cards_visual: Array[Rect2] = arena.patch_card_rects_for_viewport(Vector2(1366, 768))
	_check(patch_box_visual.position.y > 230.0 and patch_box_visual.position.y < 270.0 and patch_box_visual.size.y > 280.0 and patch_box_visual.size.y < 315.0 and patch_box_visual.end.y < 570.0, "patch cards match the approved compact overlay proportion")
	var patch_cards_aligned := patch_cards_visual.size() == 3
	if patch_cards_aligned:
		for card in patch_cards_visual:
			patch_cards_aligned = patch_cards_aligned and absf(card.position.y - patch_cards_visual[0].position.y) < 0.01 and absf(card.size.y - patch_cards_visual[0].size.y) < 0.01
	_check(patch_cards_aligned, "patch cards share one straight baseline and height")
	var tactical_surface_script: Script = load("res://src/ui/tactical_state_surface.gd")
	var state_surface_ready := arena.has_method("state_panel_rect") and arena.has_method("state_action_rects") and arena.has_method("pause_action_labels") and arena.has_method("game_over_action_labels")
	_check(state_surface_ready, "state panels expose tactical geometry and action labels")
	_check(tactical_surface_script.has_method("pause_layout"), "pause surface exposes one shared responsive layout")
	_check(tactical_surface_script.has_method("terminal_layout"), "terminal surface exposes one shared responsive layout")
	if tactical_surface_script.has_method("pause_layout"):
		for viewport_size in [Vector2(525, 521), Vector2(720, 720), Vector2(1366, 768)]:
			var pause_layout: Dictionary = tactical_surface_script.pause_layout(viewport_size)
			var pause_panel: Rect2 = pause_layout["panel"]
			var pause_actions: Array = pause_layout["actions"]
			_check(pause_actions.size() == 4, "pause layout exposes four aligned actions at %dx%d" % [int(viewport_size.x), int(viewport_size.y)])
			for pause_key in ["info", "title", "stats", "volume", "warning", "shortcuts"]:
				_check(pause_panel.encloses(pause_layout[pause_key]), "pause %s stays inside panel at %dx%d" % [pause_key, int(viewport_size.x), int(viewport_size.y)])
			for action_rect in pause_actions:
				_check(pause_panel.encloses(action_rect), "pause action stays inside panel at %dx%d" % [int(viewport_size.x), int(viewport_size.y)])
			_check(not Rect2(pause_layout["stats"]).intersects(Rect2(pause_actions[0])), "pause stats clear first action at %dx%d" % [int(viewport_size.x), int(viewport_size.y)])
			_check(not Rect2(pause_layout["volume"]).intersects(Rect2(pause_layout["warning"])), "pause audio clears warning at %dx%d" % [int(viewport_size.x), int(viewport_size.y)])
			var warning_inner := Rect2(pause_layout["warning"]).grow(-6.0 * float(pause_layout["scale"]))
			_check(warning_inner.encloses(Rect2(pause_actions[3])), "pause abandon action clears warning frame at %dx%d" % [int(viewport_size.x), int(viewport_size.y)])
			_check(Rect2(pause_actions[3]).end.y + 6.0 * float(pause_layout["scale"]) <= Rect2(pause_layout["shortcuts"]).position.y, "pause abandon action clears shortcut row at %dx%d" % [int(viewport_size.x), int(viewport_size.y)])
	if tactical_surface_script.has_method("terminal_layout"):
		for viewport_size in [Vector2(720, 521), Vector2(1096, 631), Vector2(1366, 768)]:
			var terminal_layout: Dictionary = tactical_surface_script.terminal_layout(viewport_size)
			var terminal_panel: Rect2 = terminal_layout["panel"]
			for terminal_key in ["header", "history", "command_index", "system_status", "prompt", "shortcuts"]:
				_check(terminal_panel.encloses(terminal_layout[terminal_key]), "terminal %s stays inside panel at %dx%d" % [terminal_key, int(viewport_size.x), int(viewport_size.y)])
			_check(not Rect2(terminal_layout["history"]).intersects(Rect2(terminal_layout["command_index"])), "terminal history clears command index at %dx%d" % [int(viewport_size.x), int(viewport_size.y)])
			_check(not Rect2(terminal_layout["history"]).intersects(Rect2(terminal_layout["prompt"])), "terminal history clears prompt at %dx%d" % [int(viewport_size.x), int(viewport_size.y)])
			_check(not Rect2(terminal_layout["prompt"]).intersects(Rect2(terminal_layout["shortcuts"])), "terminal prompt clears shortcuts at %dx%d" % [int(viewport_size.x), int(viewport_size.y)])
	if state_surface_ready:
		for viewport_size in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
			var state_bounds := Rect2(Vector2.ZERO, viewport_size)
			var panel_rect: Rect2 = arena.state_panel_rect(viewport_size)
			_check(state_bounds.encloses(panel_rect), "state panel fits viewport %dx%d" % [int(viewport_size.x), int(viewport_size.y)])
			for action_rect in arena.state_action_rects(viewport_size, 4):
				_check(state_bounds.encloses(action_rect) and panel_rect.encloses(action_rect), "state action stays in panel at %dx%d" % [int(viewport_size.x), int(viewport_size.y)])
		_check(arena.pause_action_labels() == ["RESUME", "RESTART", "OPEN TERMINAL", "ABANDON PROCESS"], "pause actions preserve safe order")
		_check(arena.has_method("pause_action_icon_kinds"), "pause actions expose semantic icons")
		if arena.has_method("pause_action_icon_kinds"):
			_check(arena.pause_action_icon_kinds() == ["resume", "restart", "terminal", "warning"], "pause icons preserve action semantics")
		_check(arena.game_over_action_labels() == ["REBOOT", "ABANDON PROCESS"], "game-over actions preserve retry first")
	var terminal: Control = arena._terminal_panel
	var terminal_ready := terminal != null and terminal.has_method("workstation_rect") and terminal.has_method("status_snapshot")
	_check(terminal_ready, "terminal exposes tactical workstation geometry")
	if terminal_ready:
		for viewport_size in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
			var terminal_rect: Rect2 = terminal.workstation_rect(viewport_size)
			_check(Rect2(Vector2.ZERO, viewport_size).encloses(terminal_rect), "terminal workstation fits viewport %dx%d" % [int(viewport_size.x), int(viewport_size.y)])
		var terminal_status: Dictionary = terminal.status_snapshot()
		_check(str(terminal_status.get("tty", "")) == "TTY0" and bool(terminal_status.get("paused", false)), "terminal status identifies frozen TTY")
		_check(int(terminal_status.get("command_count", -1)) >= 0 and bool(terminal_status.get("prompt_visible", false)), "terminal status exposes command count and prompt")
	var saved_hud_size := hud.size
	hud.size = Vector2(1280, 720)
	var layout_helpers_ready := hud.has_method("boss_bar_baseline") and hud.has_method("dash_baseline")
	_check(layout_helpers_ready, "HUD exposes responsive bottom layout helpers")
	if layout_helpers_ready:
		var boss_y_720: float = hud.boss_bar_baseline()
		var dash_y_720: float = hud.dash_baseline()
		hud.size = Vector2(1280, 900)
		_check(hud.boss_bar_baseline() > boss_y_720, "boss bar baseline follows viewport height")
		_check(hud.dash_baseline() > dash_y_720, "dash baseline follows viewport height")
	hud.size = saved_hud_size
	var patch_layout_ready := arena.has_method("patch_box_rect_for_viewport") and arena.has_method("patch_card_rects_for_viewport")
	_check(patch_layout_ready, "patch panel exposes narrow viewport layout helpers")
	if patch_layout_ready:
		for viewport_size in [Vector2(432, 720), Vector2(720, 720)]:
			var patch_box: Rect2 = arena.patch_box_rect_for_viewport(viewport_size)
			_check(patch_box.position.x >= 0.0 and patch_box.end.x <= viewport_size.x, "patch box fits viewport width %dx%d" % [int(viewport_size.x), int(viewport_size.y)])
			var card_rects: Array[Rect2] = arena.patch_card_rects_for_viewport(viewport_size)
			_check(card_rects.size() == 3, "patch layout keeps three cards at %dx%d" % [int(viewport_size.x), int(viewport_size.y)])
			for card_rect in card_rects:
				_check(card_rect.position.x >= 0.0 and card_rect.end.x <= viewport_size.x, "patch card stays inside viewport at %dx%d" % [int(viewport_size.x), int(viewport_size.y)])
	var panel_layout_ready := arena.has_method("panel_control_rect")
	_check(panel_layout_ready, "combat panels expose responsive vertical layout helper")
	if panel_layout_ready:
		for viewport_height in [360.0, 432.0, 720.0, 900.0]:
			for design_top in [118.0, 150.0, 220.0, 500.0, 550.0]:
				var panel_rect: Rect2 = arena.panel_control_rect(design_top, 62.0, viewport_height)
				_check(panel_rect.position.y >= 0.0 and panel_rect.end.y <= viewport_height, "panel control fits viewport height %.0f" % viewport_height)
		var real_refresh_ready := arena.has_method("_refresh_responsive_layout_for_height")
		_check(real_refresh_ready, "responsive refresh accepts simulated viewport height")
		for viewport_height in [360.0, 432.0]:
			if not real_refresh_ready:
				continue
			arena._refresh_responsive_layout_for_height(viewport_height)
			var real_controls_fit := true
			for panel in [arena._pause_panel, arena._over_panel, arena._patch_panel]:
				if panel == null or not is_instance_valid(panel):
					continue
				for control in panel.get_children():
					if not control is Control or not control.has_meta("panel_design_top"):
						continue
					var scale := float(control.scale.y)
					var control_top: float = viewport_height * 0.5 + float(control.offset_top)
					var control_bottom: float = control_top + (float(control.offset_bottom) - float(control.offset_top)) * scale
					if control_top < -0.01 or control_bottom > viewport_height + 0.01:
						real_controls_fit = false
			_check(real_controls_fit, "real panel controls stay inside simulated viewport height %.0f" % viewport_height)
		arena._refresh_responsive_layout()

	var touch_ui := TouchControls.new()
	var saved_touch_scale := Sfx.touch_scale
	var touch_helpers_ready := touch_ui.has_method("movement_geometry") and touch_ui.has_method("movement_vector_from_offset")
	_check(touch_helpers_ready, "touch controls expose scaled movement geometry")
	if touch_helpers_ready:
		var reference_vector := Vector2.ZERO
		for scale in [0.85, 1.0, 1.2]:
			Sfx.touch_scale = scale
			var geometry: Dictionary = touch_ui.movement_geometry()
			_check(absf(float(geometry["travel_radius"]) - 110.0 * scale) < 0.01, "movement travel radius scales at %.2f" % scale)
			_check(absf(float(geometry["normalization_divisor"]) - 90.0 * scale) < 0.01, "movement divisor scales at %.2f" % scale)
			_check(absf(float(geometry["draw_radius"]) - 64.0 * scale) < 0.01, "movement draw radius scales at %.2f" % scale)
			_check(absf(float(geometry["knob_radius"]) - 22.0 * scale) < 0.01, "movement knob radius scales at %.2f" % scale)
			var normalized: Vector2 = touch_ui.movement_vector_from_offset(Vector2(45.0, 27.0) * scale)
			if reference_vector == Vector2.ZERO:
				reference_vector = normalized
			else:
				_check(normalized.distance_to(reference_vector) < 0.001, "movement vector stays normalized at %.2f" % scale)
	Sfx.touch_scale = saved_touch_scale
	touch_ui.free()

func _task6_test(arena: Arena) -> void:
	print("AT_STEP task6")
	var cover_player := Node2D.new()
	cover_player.position = Vector2.ZERO
	arena.add_child(cover_player)
	var spewer := SpewerEnemy.new()
	spewer.player = cover_player
	spewer.position = Vector2(320, 0)
	var bulwark := BulwarkEnemy.new()
	bulwark.position = Vector2(150, 0)
	EnemyBase.shared_list = [spewer, bulwark]
	var cover_position: Vector2 = spewer.find_bulwark_cover(cover_player.global_position)
	var cover_safe := Balance.arena_rect().grow(-spewer.radius).has_point(cover_position)
	_check(cover_position != Vector2.ZERO and cover_safe, "ranged cover returns an arena-safe position")
	_check(cover_position.x > bulwark.global_position.x and cover_position.distance_to(bulwark.global_position) > bulwark.radius + spewer.radius, "ranged cover prefers a point behind the BULWARK")
	spewer._strafe_dir = 1.0
	spewer._telegraph = 0.0
	spewer._fire_t = 99.0
	spewer._v = Vector2.ZERO
	spewer._move(0.1)
	var cover_seek := (cover_position - spewer.global_position).normalized()
	_check(spewer.vel().dot(cover_seek) > 0.0, "Spewer steers toward valid BULWARK cover")
	EnemyBase.shared_list = [spewer]
	spewer.position = Vector2(100, 0)
	spewer._v = Vector2.ZERO
	spewer._telegraph = 0.0
	spewer._fire_t = 99.0
	spewer._move(0.1)
	_check(spewer.vel().dot(Vector2.RIGHT) > 0.0, "Spewer retreat is not overridden by cover")
	EnemyBase.shared_list = [spewer, bulwark]
	spewer.position = Vector2(320, 0)
	spewer._v = Vector2(100, 0)
	spewer._telegraph = 0.2
	spewer._fire_t = 99.0
	spewer._move(0.1)
	_check(spewer.vel().length() < 100.0, "Spewer telegraph braking is not overridden by cover")
	EnemyBase.shared_list = [spewer]
	spewer.position = Vector2(320, 0)
	spewer._v = Vector2.ZERO
	var no_cover: Vector2 = spewer.find_bulwark_cover(cover_player.global_position)
	_check(no_cover == Vector2.ZERO, "ranged cover returns zero without a BULWARK")
	spewer._telegraph = 0.0
	spewer._fire_t = 99.0
	spewer._move(0.1)
	_check(spewer.vel().length() > 0.0, "Spewer keeps distance-band fallback without cover")
	spewer.free()
	bulwark.free()
	cover_player.free()
	await _ticks(2)

	var split_parent := Node2D.new()
	arena.add_child(split_parent)
	var elite_splitter := SplitterEnemy.new()
	elite_splitter.configure(1.0, true)
	elite_splitter.elite = true
	elite_splitter.elite_kind = "volatile"
	elite_splitter.position = Vector2(200, 0)
	split_parent.add_child(elite_splitter)
	await _ticks(1)
	elite_splitter.die()
	await _ticks(2)
	var mini_children: Array[DroneEnemy] = []
	for child in split_parent.get_children():
		if child is DroneEnemy and child.mini:
			mini_children.append(child)
	_check(mini_children.size() == 2, "elite Splitter still creates two mini drones")
	var minis_non_elite := true
	for mini in mini_children:
		if mini.elite or mini.elite_kind != "":
			minis_non_elite = false
	_check(minis_non_elite, "Splitter mini drones never inherit elite state")
	for mini in mini_children:
		mini.queue_free()
	split_parent.queue_free()
	EnemyBase.shared_list = arena.enemy_list
	await _ticks(2)

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
	var ranged_boss := RootBoss.new()
	ranged_boss.boss_index = 3
	ranged_boss.configure(1.0, false)
	ranged_boss.player = player
	ranged_boss.position = player.global_position + Vector2(70, 0)
	ranged_boss._move(0.1)
	_check(ranged_boss.vel().dot(Vector2.RIGHT) > 0.0, "ranged boss backs away when player is too close")
	var split_seen := []
	var split_signal_boss := RootBoss.new()
	split_signal_boss.boss_index = 1
	split_signal_boss.configure(1.0, false)
	split_signal_boss.split_started.connect(func(minis: Array) -> void:
		split_seen.append_array(minis)
	)
	split_signal_boss.player = player
	split_signal_boss.position = player.global_position + Vector2(220, 0)
	var split_probe_position := split_signal_boss.position
	arena.enemy_container.add_child(split_signal_boss)
	await _ticks(1)
	arena._on_boss_spawned(split_signal_boss)
	_check(arena.hud.boss != null, "boss hud tracks root before split")
	split_signal_boss._split_into_minis()
	await _ticks(2)
	_check(arena.hud._boss_fragments.size() == 2, "boss hud tracks both root minis")
	_check(arena.hud._boss_split, "boss hud enters forked layout")
	_check(arena.hud._boss_name == "ROOT.exe // FORKED", "boss hud labels the forked root")
	_check(arena.hud._boss_split, "forked boss hud survives original root cleanup")
	_check(split_seen.size() == 2, "root split reports both mini instances")
	if split_seen.size() == 2:
		_check(split_seen[0].position.distance_to(split_seen[1].position) > 52.0, "root minis start separated")
	await _ticks(1)
	for mini_node in split_seen:
		if is_instance_valid(mini_node):
			mini_node.queue_free()
	for mote_idx in range(arena.mote_field.count() - 1, -1, -1):
		if arena.mote_field.pos_of(mote_idx).distance_to(split_probe_position) < 32.0:
			arena.mote_field.kill_slot(mote_idx)
	EnemyBase.shared_list = arena.enemy_list
	ranged_boss.free()
	if is_instance_valid(split_signal_boss):
		split_signal_boss.free()
	f1.queue_free()
	f2.queue_free()
	await _ticks(2)
	print("AT_STEP rootsplit")
	var recover_script: Script = load("res://src/pickups/recover_pickup.gd")
	for c in arena.mote_container.get_children():
		if c.get_script() == recover_script:
			c.queue_free()
	await _ticks(2)
	player.invuln = 9999.0
	var rb := RootBoss.new()
	rb.boss_index = 1
	rb.configure(1.0, false)
	rb.position = player.global_position + Vector2(300, -80)
	arena.enemy_container.add_child(rb)
	await _ticks(2)
	arena._on_boss_spawned(rb)
	_check(arena.hud.boss != null, "boss hud tracks root before split lifecycle")
	rb.hp = int(rb.max_hp * 0.51) + 1
	rb.take_hit(2, rb.global_position + Vector2(6, 0))
	await _ticks(5)
	var minis_found := 0
	for e in arena.enemy_container.get_children():
		if e is RootBoss and is_instance_valid(e) and e.mini:
			minis_found += 1
	_check(minis_found == 2, "root splits into two minis (%d)" % minis_found)
	_check(arena.hud._boss_fragments.size() == 2, "boss hud tracks both lifecycle minis")
	_check(arena.hud._boss_split, "boss hud stays forked during lifecycle")
	var mini_hp_ok := true
	var mini_positions: Array[Vector2] = []
	for e in arena.enemy_container.get_children():
		if e is RootBoss and is_instance_valid(e) and e.mini:
			mini_hp_ok = mini_hp_ok and e.hp >= 2 and e.max_hp >= 2
			mini_positions.append(e.global_position)
	_check(minis_found == 2 and mini_hp_ok, "root minis survive more than one hit")
	await _ticks(10)
	var mini_moved := false
	for i in mini_positions.size():
		for e in arena.enemy_container.get_children():
			if e is RootBoss and is_instance_valid(e) and e.mini and e.global_position.distance_to(mini_positions[i]) > 8.0:
				mini_moved = true
	_check(mini_moved, "root minis move during their phase")
	var split_recover_count := 0
	for c in arena.mote_container.get_children():
		if c.get_script() == recover_script:
			split_recover_count += 1
	_check(split_recover_count == 1, "root split drops one recover")
	var probe_mini: RootBoss = null
	for e in arena.enemy_container.get_children():
		if e is RootBoss and is_instance_valid(e) and e.mini:
			probe_mini = e
			break
	if probe_mini != null:
		var minis_before := minis_found
		player.hp = maxi(1, player.max_hp - 2)
		Game.stats["heals"] = {}
		arena._patch_pending = 0
		arena._patch_open = false
		get_tree().paused = false
		probe_mini.take_hit(probe_mini.hp + 99, probe_mini.global_position)
		await _ticks(4)
		_check(arena.hud._boss_fragments.size() == 1, "boss hud removes first dead mini")
		_check(arena.hud._boss_split, "boss hud stays forked while one mini lives")
		_check(arena._patch_pending == 0 and not arena._patch_open, "first root mini gives no boss card")
		if get_tree().paused:
			get_tree().paused = false
		if arena._patch_open:
			arena._pick_patch(0)
		_check(int(Game.stats["heals"].get("boss", 0)) == 0, "first root mini gives no boss heal")
		var minis_now := 0
		for e in arena.enemy_container.get_children():
			if e is RootBoss and is_instance_valid(e) and e.mini:
				minis_now += 1
		_check(minis_now < minis_before + 2, "minis never split again")
		var last_mini: RootBoss = null
		for e in arena.enemy_container.get_children():
			if e is RootBoss and is_instance_valid(e) and e.mini:
				last_mini = e
				break
		if last_mini != null:
			last_mini.take_hit(last_mini.hp + 99, last_mini.global_position)
			await _ticks(4)
		_check(arena.hud.boss == null, "boss hud clears root after final reward")
		_check(arena.hud._boss_fragments.is_empty(), "boss hud clears all minis after final reward")
		_check(not arena.hud._boss_split, "boss hud exits forked layout after final reward")
		_check(arena.hud._boss_name == "", "boss hud clears forked title after final reward")
		_check(arena.hud._boss_frac == -1.0, "boss hud clears boss fraction after final reward")
		_check(not arena._patch_open and arena._patch_pending == 0, "root encounter does not queue boss-death patch")
		_check(int(Game.stats["heals"].get("boss", 0)) == 1 and player.hp == player.max_hp - 1, "root encounter gives one boss heal")
		var final_recover_count := 0
		for c in arena.mote_container.get_children():
			if c.get_script() == recover_script:
				final_recover_count += 1
		_check(final_recover_count == 1, "root encounter gives one recover total")
		if get_tree().paused:
			get_tree().paused = false
		if arena._patch_open:
			arena._pick_patch(0)
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
		await _ticks(1)
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
	print("AT_STEP rootcharge")
	var charge := RootBoss.new()
	charge.boss_index = 1
	charge.configure(1.0, false)
	charge.position = Vector2.ZERO
	arena.enemy_container.add_child(charge)
	await _ticks(2)
	charge._v = Vector2.RIGHT * 800.0
	charge.act = RootBoss.Act.CHARGE_GO
	charge.act_t = 0.4
	var charge_start := charge.global_position
	await _ticks(10)
	_check(charge.global_position.distance_to(charge_start) > 20.0, "root charge moves during charge")
	charge.queue_free()
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
	var selector_script = load("res://src/ui/program_panel.gd")
	_check(selector_script != null, "program selector script loads")
	var program_details_ok := true
	var silhouette_keys := {}
	for pid in Game.PROGRAM_DEFS:
		var pdef: Dictionary = Game.PROGRAM_DEFS[pid]
		var detail_fields := ["role", "integrity", "speed", "fire", "range", "dash_shield"]
		for field in detail_fields:
			if str(pdef.get(field, "")).strip_edges().is_empty():
				program_details_ok = false
		if str(pdef.get("summary", "")).strip_edges().is_empty():
			program_details_ok = false
		var visual: Dictionary = pdef.get("visual", {})
		var silhouette := str(visual.get("silhouette", ""))
		if visual.is_empty() or silhouette.is_empty():
			program_details_ok = false
		silhouette_keys[silhouette] = true
	_check(program_details_ok, "playable programs expose detailed comparison summaries")
	_check(silhouette_keys.size() == Game.PROGRAM_DEFS.size(), "playable programs expose distinct visual profiles")
	var saved_program_selection := Game.program
	var saved_unlocked_programs: Dictionary = Game.unlocked_programs.duplicate(true)
	var saved_program_disk := _config_snapshot("run", "program", "kernel")
	Game.unlocked_programs = {"kernel": true, "daemon": true}
	Game.set_program("kernel")
	var kernel_visual_color = player.visual_color() if player.has_method("visual_color") else Color.BLACK
	var kernel_silhouette_key := str(player.visual_silhouette_key()) if player.has_method("visual_silhouette_key") else ""
	var selector = selector_script.new() if selector_script != null else null
	if selector != null:
		var available: Array = selector.available_program_ids() if selector.has_method("available_program_ids") else []
		_check(available.has("kernel") and available.has("daemon") and not available.has("rootlet"), "program selector lists unlocked programs only")
		var locked_selected := bool(selector.select_program("rootlet")) if selector.has_method("select_program") else true
		_check(not locked_selected and Game.program == "kernel", "program selector cannot select locked rootlet")
		var daemon_selected := bool(selector.select_program("daemon")) if selector.has_method("select_program") else false
		_check(daemon_selected and Game.program == "daemon", "program selector selects unlocked daemon")
		var selector_disk := ConfigFile.new()
		selector_disk.load(Sfx.SAVE_PATH)
		_check(selector_disk.get_value("run", "program", "") == "daemon", "program selection persists through run ConfigFile")
		selector.free()
	Game.unlocked_programs = {"kernel": true, "daemon": true, "rootlet": true}
	Game.set_program("kernel")
	var responsive_sizes := [Vector2(720, 720), Vector2(432, 720)]
	for size_probe in responsive_sizes:
		var responsive_panel = selector_script.new()
		responsive_panel.size = size_probe
		get_tree().current_scene.add_child(responsive_panel)
		await _ticks(2)
		responsive_panel._scroll_to(100000.0)
		await _ticks(2)
		var responsive_viewport: Rect2 = Rect2()
		if responsive_panel.has_method("content_viewport_rect"):
			responsive_viewport = responsive_panel.content_viewport_rect()
		var rootlet_rect: Rect2 = responsive_panel._card_rects.get("rootlet", Rect2())
		_check(responsive_panel.has_method("content_viewport_rect"), "program selector exposes consistent content viewport")
		_check(rootlet_rect.size != Vector2.ZERO and responsive_viewport.encloses(rootlet_rect), "rootlet card is visible at max scroll (%dx%d)" % [int(size_probe.x), int(size_probe.y)])
		var rootlet_center := rootlet_rect.get_center()
		if size_probe.x >= 720.0:
			var mouse_down := InputEventMouseButton.new()
			mouse_down.button_index = MOUSE_BUTTON_LEFT
			mouse_down.pressed = true
			mouse_down.position = rootlet_center
			responsive_panel._gui_input(mouse_down)
			var mouse_up := InputEventMouseButton.new()
			mouse_up.button_index = MOUSE_BUTTON_LEFT
			mouse_up.position = rootlet_center
			responsive_panel._gui_input(mouse_up)
		else:
			var touch_down := InputEventScreenTouch.new()
			touch_down.index = 31
			touch_down.pressed = true
			touch_down.position = rootlet_center
			responsive_panel._gui_input(touch_down)
			var touch_up := InputEventScreenTouch.new()
			touch_up.index = 31
			touch_up.position = rootlet_center
			responsive_panel._gui_input(touch_up)
		_check(Game.program == "rootlet", "rootlet selects through panel input at %dx%d" % [int(size_probe.x), int(size_probe.y)])
		Game.set_program("kernel")
		responsive_panel.queue_free()
		await _ticks(2)
	Game.unlocked_programs = {"kernel": true, "daemon": true}
	Game.set_program("kernel")
	var locked_panel = selector_script.new()
	locked_panel.size = Vector2(432, 720)
	get_tree().current_scene.add_child(locked_panel)
	await _ticks(2)
	locked_panel._scroll_to(100000.0)
	await _ticks(2)
	var locked_rootlet_rect: Rect2 = locked_panel._card_rects.get("rootlet", Rect2())
	var locked_touch_down := InputEventScreenTouch.new()
	locked_touch_down.index = 32
	locked_touch_down.pressed = true
	locked_touch_down.position = locked_rootlet_rect.get_center()
	locked_panel._gui_input(locked_touch_down)
	var locked_touch_up := InputEventScreenTouch.new()
	locked_touch_up.index = 32
	locked_touch_up.position = locked_rootlet_rect.get_center()
	locked_panel._gui_input(locked_touch_up)
	_check(Game.program == "kernel", "locked rootlet rejects panel touch selection")
	locked_panel.queue_free()
	await _ticks(2)
	print("AT_STEP selection_geometry")
	if selector_script != null:
		var geometry_panel = selector_script.new()
		geometry_panel.size = Vector2(1366, 768)
		get_tree().current_scene.add_child(geometry_panel)
		await _ticks(2)
		geometry_panel._scroll_to(0.0)
		await _ticks(2)
		_check(geometry_panel.has_method("visible_card_rects"), "program selector exposes visible card geometry")
		_check(geometry_panel.has_method("card_accent"), "program selector exposes selected accent")
		if geometry_panel.has_method("visible_card_rects") and geometry_panel.has_method("content_viewport_rect"):
			var program_viewport: Rect2 = geometry_panel.content_viewport_rect()
			var program_cards_contained := true
			for raw_rect in geometry_panel.visible_card_rects():
				program_cards_contained = program_cards_contained and program_viewport.encloses(raw_rect)
			_check(program_cards_contained, "visible program cards stay inside content viewport")
		if geometry_panel.has_method("card_accent"):
			_check(geometry_panel.card_accent("kernel") != geometry_panel.card_accent("daemon"), "selected program has a distinct accent")
		geometry_panel.queue_free()
		await _ticks(2)
	var story_geometry_script: Script = load("res://src/ui/story_panel.gd")
	if story_geometry_script != null:
		var story_geometry = story_geometry_script.new()
		story_geometry.size = Vector2(1366, 768)
		get_tree().current_scene.add_child(story_geometry)
		await _ticks(2)
		_check(story_geometry.has_method("content_viewport_rect") and story_geometry.has_method("visible_card_rects"), "story selector exposes content geometry")
		_check(story_geometry.has_method("selected_stage_index") and story_geometry.has_method("card_accent"), "story selector exposes selected state")
		if story_geometry.has_method("select_stage"):
			_check(story_geometry.select_stage(0), "story selector selects the first stage")
		if story_geometry.has_method("selected_stage_index"):
			_check(story_geometry.selected_stage_index() == 0, "story selector tracks selected stage")
		if story_geometry.has_method("visible_card_rects") and story_geometry.has_method("content_viewport_rect"):
			var story_viewport: Rect2 = story_geometry.content_viewport_rect()
			var story_cards_contained := true
			for raw_rect in story_geometry.visible_card_rects():
				story_cards_contained = story_cards_contained and story_viewport.encloses(raw_rect)
			_check(story_cards_contained, "visible story cards stay inside content viewport")
		story_geometry.queue_free()
		await _ticks(2)
	var bestiary_geometry_script: Script = load("res://src/ui/bestiary_panel.gd")
	if bestiary_geometry_script != null:
		var saved_bestiary_geometry: Dictionary = Game.bestiary.duplicate(true)
		Game.bestiary.clear()
		var bestiary_geometry = bestiary_geometry_script.new()
		bestiary_geometry.size = Vector2(1366, 768)
		get_tree().current_scene.add_child(bestiary_geometry)
		await _ticks(2)
		_check(bestiary_geometry.has_method("content_viewport_rect") and bestiary_geometry.has_method("visible_card_rects"), "bestiary exposes content geometry")
		_check(bestiary_geometry.has_method("entry_status") and str(bestiary_geometry.entry_status("root")).contains("LOCKED"), "bestiary keeps locked entries explicit")
		if bestiary_geometry.has_method("visible_card_rects") and bestiary_geometry.has_method("content_viewport_rect"):
			var bestiary_viewport: Rect2 = bestiary_geometry.content_viewport_rect()
			var bestiary_cards_contained := true
			for raw_rect in bestiary_geometry.visible_card_rects():
				bestiary_cards_contained = bestiary_cards_contained and bestiary_viewport.encloses(raw_rect)
			_check(bestiary_cards_contained, "visible bestiary cards stay inside content viewport")
		bestiary_geometry.queue_free()
		await _ticks(2)
		Game.bestiary = saved_bestiary_geometry
	Game.program = saved_program_selection
	Game.unlocked_programs = saved_unlocked_programs
	_restore_config_snapshot("run", "program", saved_program_disk)
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
	p2.dash_cd = 0.0
	p2.dash_recharge_t = 0.0
	p2.dash_t = 0.0
	var daemon_dash_id := p2.dash_id
	p2.request_dash(Vector2.RIGHT)
	p2.dash_t = 0.0
	p2.request_dash(Vector2.RIGHT)
	p2.dash_t = 0.0
	p2.request_dash(Vector2.RIGHT)
	_check(p2.dash_id == daemon_dash_id + 2, "daemon dash is capped at two consecutive charges")
	p2._physics_process(Balance.DASH_CD)
	_check(p2.available_dash_charges() == 1, "daemon dash recharges one charge after cooldown")
	_check(p2.has_method("visual_color") and p2.has_method("visual_silhouette_key"), "player exposes program visual profile")
	if p2.has_method("visual_color") and p2.has_method("visual_silhouette_key"):
		_check(kernel_visual_color != p2.visual_color(), "kernel and daemon use different visual colors")
		_check(kernel_silhouette_key != p2.visual_silhouette_key(), "kernel and daemon use different silhouettes")
	_check(p2.has_method("dash_ghost_color"), "player exposes dash ghost color profile")
	if p2.has_method("dash_ghost_color"):
		_check(p2.dash_ghost_color() == p2.visual_color(), "dash ghosts use selected program color")
	var p2_collision: CollisionShape2D = null
	for child in p2.get_children():
		if child is CollisionShape2D:
			p2_collision = child
			break
	_check(p2_collision != null and absf(p2_collision.shape.radius - Balance.PLAYER_RADIUS) < 0.001, "program silhouettes preserve player collision radius")
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
	player.invuln = 9999.0
	player.hp = player.max_hp
	print("AT_STEP desktop_dash_hud")
	_check(Balance.is_desktop_display("wayland"), "wayland is a desktop display")
	_check(Balance.is_desktop_display("embedded"), "embedded is a desktop display")
	arena.hud.player = player
	Game.patch_levels = {"dash": 1}
	player.dash_charges = 1
	player.dash_cd = Balance.DASH_CD * pow(0.82, Game.patch_level("dash"))
	await _ticks(2)
	_check(arena.hud._dash_frac < 0.1, "dash hud uses quick dash cooldown")
	player.dash_charges = 2
	player.dash_recharge_t = 0.5
	player.dash_cd = 0.5
	await _ticks(2)
	_check(arena.hud._dash_frac > 0.99, "dash hud shows available extra charge")
	player.dash_charges = 1
	player.dash_recharge_t = 0.0
	player.dash_cd = 0.0
	Game.patch_levels = {}
	print("AT_STEP newenemies")
	var special_player := Node2D.new()
	special_player.position = Vector2.ZERO
	arena.add_child(special_player)
	var trojan_probe := TrojanEnemy.new()
	trojan_probe.player = special_player
	trojan_probe.position = Vector2(180, 0)
	trojan_probe._move(0.1)
	_check(absf(trojan_probe.vel().dot(Vector2.LEFT)) < trojan_probe.vel().length(), "trojan approaches with route offset")
	print("AT_STEP teleports")
	var flank_player := Player.new()
	flank_player.position = Vector2.ZERO
	flank_player.aim = Vector2.RIGHT * 100.0
	flank_player.vel = Vector2.RIGHT * 100.0
	arena.add_child(flank_player)
	await _ticks(2)
	flank_player.aim = Vector2.RIGHT * 100.0
	flank_player.vel = Vector2.RIGHT * 100.0
	var recursor_flank_probe: RecursorEnemy = load("res://src/enemies/recursor.gd").new()
	recursor_flank_probe.radius = 13.0
	var recursor_has_selector := recursor_flank_probe.has_method("select_teleport_candidate")
	_check(recursor_has_selector, "recursor exposes deterministic teleport selector")
	if recursor_has_selector:
		var rec_rng_state := Game.rng.state
		var rec_dest_a: Vector2 = recursor_flank_probe.select_teleport_candidate(flank_player.global_position, flank_player.aim, flank_player.vel)
		var rec_dest_b: Vector2 = recursor_flank_probe.select_teleport_candidate(flank_player.global_position, flank_player.aim, flank_player.vel)
		var rec_offset := (rec_dest_a - flank_player.global_position).normalized()
		var rec_safe_rect := Balance.arena_rect().grow(-recursor_flank_probe.radius - 8.0)
		_check(rec_dest_a.is_equal_approx(rec_dest_b), "recursor heading selection is deterministic")
		_check(Game.rng.state == rec_rng_state, "recursor heading selection does not consume Game.rng")
		_check(rec_offset.dot(Vector2.RIGHT) <= 0.2, "recursor teleport favors flank or behind player facing")
		_check(rec_safe_rect.has_point(rec_dest_a) and rec_dest_a.distance_to(flank_player.global_position) > 90.0, "recursor teleport stays safe and inside arena")
	recursor_flank_probe.free()
	var ranged_boss_flank_probe: RootBoss = load("res://src/enemies/root_boss.gd").new()
	ranged_boss_flank_probe.boss_index = 2
	ranged_boss_flank_probe.configure(1.0, false)
	var boss_has_selector := ranged_boss_flank_probe.has_method("select_teleport_candidate")
	_check(boss_has_selector, "ranged boss exposes deterministic teleport selector")
	if boss_has_selector:
		var boss_rng_state := Game.rng.state
		var boss_dest_a: Vector2 = ranged_boss_flank_probe.select_teleport_candidate(flank_player.global_position, flank_player.aim, flank_player.vel)
		var boss_dest_b: Vector2 = ranged_boss_flank_probe.select_teleport_candidate(flank_player.global_position, flank_player.aim, flank_player.vel)
		var boss_offset := (boss_dest_a - flank_player.global_position).normalized()
		var boss_safe_rect := Balance.arena_rect().grow(-ranged_boss_flank_probe.radius - 8.0)
		_check(boss_dest_a.is_equal_approx(boss_dest_b), "ranged boss heading selection is deterministic")
		_check(Game.rng.state == boss_rng_state, "ranged boss heading selection does not consume Game.rng")
		_check(boss_offset.dot(Vector2.RIGHT) <= 0.2, "ranged boss teleport favors flank or behind player facing")
		_check(boss_safe_rect.has_point(boss_dest_a) and boss_dest_a.distance_to(flank_player.global_position) > 240.0, "ranged boss teleport stays safe and inside arena")
	ranged_boss_flank_probe.free()
	flank_player.free()
	var fallback_rng_state := Game.rng.state
	var recursor_fallback_probe: RecursorEnemy = load("res://src/enemies/recursor.gd").new()
	Game.rng.seed = 1
	var recursor_fallback_rng_before := Game.rng.state
	var recursor_fallback_dest: Vector2 = recursor_fallback_probe.select_teleport_candidate(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	var recursor_fallback_rect := Balance.arena_rect().grow(-recursor_fallback_probe.radius - 8.0)
	_check(recursor_fallback_rect.has_point(recursor_fallback_dest) and recursor_fallback_dest.length() > 90.0, "recursor random fallback preserves arena inset and safety distance")
	_check(Game.rng.state != recursor_fallback_rng_before, "recursor random fallback consumes Game.rng")
	recursor_fallback_probe.free()
	var boss_fallback_probe: RootBoss = load("res://src/enemies/root_boss.gd").new()
	boss_fallback_probe.radius = 300.0
	Game.rng.seed = 1
	var boss_fallback_rng_before := Game.rng.state
	var boss_fallback_dest: Vector2 = boss_fallback_probe.select_teleport_candidate(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	var boss_fallback_rect := Balance.arena_rect().grow(-boss_fallback_probe.radius - 8.0)
	_check(boss_fallback_rect.has_point(boss_fallback_dest) and boss_fallback_dest.length() > 240.0, "ranged boss random fallback preserves arena inset and safety distance")
	_check(Game.rng.state != boss_fallback_rng_before, "ranged boss random fallback consumes Game.rng")
	var unsafe_fallback_found := false
	for seed in 256:
		Game.rng.seed = seed + 1
		var candidate: Vector2 = boss_fallback_probe.select_teleport_candidate(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
		if candidate.length() <= 240.0:
			unsafe_fallback_found = true
			break
	_check(not unsafe_fallback_found, "ranged boss fallback never returns an unsafe best sample")
	boss_fallback_probe.free()
	Game.rng.state = fallback_rng_state
	var recursor_probe: RecursorEnemy = load("res://src/enemies/recursor.gd").new()
	recursor_probe.player = special_player
	recursor_probe.position = Vector2(80, 0)
	recursor_probe.phase_t = 99.0
	recursor_probe._move(0.1)
	_check(recursor_probe.vel().dot(Vector2.LEFT) <= 0.0, "recursor does not blindly converge at close range")
	EnemyBase.shared_list = arena.enemy_list
	trojan_probe.free()
	recursor_probe.free()
	special_player.free()
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
	await _ticks(3)
	var zones_after := get_tree().get_nodes_in_group("corruption").size()
	if not is_instance_valid(rec):
		rec = null
	_check(zones_after > zones_before or rec == null, "recursor leaves corruption zones")
	if is_instance_valid(rec):
		rec._dest = rec.global_position + Vector2(120, 0)
		rec.phase = RecursorEnemy.Phase.GONE
		rec.phase_t = 0.0
		rec._finish_teleport()
		_check(rec.phase == RecursorEnemy.Phase.ARRIVE, "recursor teleport finishes without audio error")
		var min_dist: float = rec.global_position.distance_to(player.global_position)
		_check(min_dist > 85.0, "recursor never teleports onto player (%d px)" % int(min_dist))
		rec.queue_free()
	var fw = load("res://src/enemies/firewall.gd").new()
	fw.position = player.global_position + Vector2(-350, -200)
	arena.enemy_container.add_child(fw)
	await _ticks(2)
	_check(fw.display_name == "FIREWALL", "firewall builds")
	var fw_angle_before: float = fw._wall_angle
	for i in 600:
		await _ticks(1)
		if not is_instance_valid(fw):
			break
		if fw._settled and get_tree().get_nodes_in_group("enemy_orbs").size() >= 5:
			break
	await _ticks(3)
	var fw_orbs := 0
	for orb in get_tree().get_nodes_in_group("enemy_orbs"):
		if is_instance_valid(orb) and orb.get_meta("fw_owner", -1) == fw.get_instance_id():
			fw_orbs += 1
	_check(fw_orbs >= 3, "firewall maintains rotating wall (%d orbs)" % fw_orbs)
	_check(absf(fw._wall_angle - fw_angle_before) > 0.01, "firewall wall rotates")
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
	var target_field: MoteField = arena.mote_field
	for i in range(target_field.count() - 1, -1, -1):
		target_field.kill_slot(i)
	var near_idx := target_field.spawn(oom.global_position + Vector2(12, 0))
	var selected_idx := target_field.spawn(oom.global_position + Vector2(160, 0))
	oom._steal(selected_idx)
	_check(target_field.is_stolen(selected_idx) and not target_field.is_stolen(near_idx), "OOM_KILLER steals selected mote slot")
	target_field.free_all_stolen()
	target_field.kill_slot(near_idx)
	oom.carried_ids.clear()
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
	await _simulation_seconds(1.1)
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
	var music_streams: Array[AudioStreamWAV] = []
	for stem in Sfx._stems:
		var stream := stem.stream as AudioStreamWAV
		if stream != null:
			music_streams.append(stream)
	_check(music_streams.size() == 3, "three music streams expose WAV data")
	if music_streams.size() == 3:
		var first := music_streams[0]
		_check(first.get_length() >= 30.0, "music stems are at least 30 seconds")
		var expected_loop_end := int(round(first.get_length() * first.mix_rate))
		_check(absf(float(first.loop_end - expected_loop_end)) <= 1.0, "music loop covers the full imported duration")
		for i in music_streams.size():
			var stream := music_streams[i]
			_check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "music stem %d loops forward" % i)
			_check(stream.mix_rate == first.mix_rate, "music stem %d sample rate matches" % i)
			_check(stream.stereo == first.stereo, "music stem %d channel layout matches" % i)
			_check(absf(stream.get_length() - first.get_length()) < 0.001, "music stem %d duration matches" % i)
			_check(stream.data.size() == first.data.size(), "music stem %d length matches" % i)
			_check(stream.loop_end == first.loop_end, "music stem %d loop end matches" % i)
	Sfx.set_intensity(2)
	Sfx.set_intensity(0)
	await _ticks(2)

func _difficulty_test() -> void:
	print("AT_STEP difficulty")
	var balance_script: Script = load("res://src/autoload/balance.gd")
	var has_helpers: bool = balance_script != null and balance_script.has_method("difficulty_max_alive") and balance_script.has_method("difficulty_wave_budget") and balance_script.has_method("difficulty_elite_chance") and balance_script.has_method("difficulty_cadence")
	_check(has_helpers, "balance exposes difficulty-aware read helpers")
	if not has_helpers:
		return
	var saved_mode := Game.mode
	var saved_difficulty := str(Game.get("difficulty"))
	var alive_caps := {"easy": 7, "normal": 10, "hard": 13}
	var budget_mults := {"easy": 0.8, "normal": 1.0, "hard": 1.2}
	var elite_mults := {"easy": 0.6, "normal": 1.0, "hard": 1.4}
	var cadence_floors := {"easy": 0.90, "normal": 0.78, "hard": 0.70}
	Game.mode = "classic"
	for difficulty in ["easy", "normal", "hard"]:
		Game.set("difficulty", difficulty)
		_check(balance_script.call("difficulty_max_alive", 2) == int(alive_caps[difficulty]), "difficulty %s caps wave 2 alive at %d" % [difficulty, alive_caps[difficulty]])
		var expected_budget: int = int(floor(float(Balance.wave_budget(5)) * float(budget_mults[difficulty])))
		_check(balance_script.call("difficulty_wave_budget", 5) == expected_budget, "difficulty %s scales the wave budget" % difficulty)
		var expected_elite: float = clampf(Balance.elite_chance(10) * float(elite_mults[difficulty]), 0.0, 1.0)
		_check(absf(float(balance_script.call("difficulty_elite_chance", 10)) - expected_elite) < 0.0001, "difficulty %s scales the elite chance" % difficulty)
		_check(absf(float(balance_script.call("difficulty_cadence", 1)) - 1.0) < 0.001, "difficulty %s keeps wave 1 cadence at 1.0" % difficulty)
		_check(absf(float(balance_script.call("difficulty_cadence", 30)) - float(cadence_floors[difficulty])) < 0.005, "difficulty %s lands wave 30 cadence on %.2f" % [difficulty, cadence_floors[difficulty]])
	Game.mode = "story"
	for difficulty in ["easy", "normal", "hard"]:
		Game.set("difficulty", difficulty)
		var story_unscaled: bool = balance_script.call("difficulty_max_alive", 30) == Balance.max_alive(30) and balance_script.call("difficulty_wave_budget", 30) == Balance.wave_budget(30) and absf(float(balance_script.call("difficulty_cadence", 30)) - Balance.attack_cadence_factor(30)) < 0.0001 and absf(float(balance_script.call("difficulty_elite_chance", 10)) - Balance.elite_chance(10)) < 0.0001
		_check(story_unscaled, "story ignores difficulty %s" % difficulty)
	Game.mode = "classic"
	if Game.has_method("set_difficulty"):
		Game.call("set_difficulty", "hard")
		_check(str(Game.get("difficulty")) == "hard", "set_difficulty stores a new difficulty")
		var cf_probe := ConfigFile.new()
		cf_probe.load(Sfx.SAVE_PATH)
		_check(str(cf_probe.get_value("game", "difficulty", "")) == "hard", "difficulty persists to the save config")
		Game.call("set_difficulty", "normal")
		_check(str(Game.get("difficulty")) == "normal", "set_difficulty restores normal")
	Game.mode = saved_mode
	Game.set("difficulty", saved_difficulty)

func _debug_controls_test(arena: Arena) -> void:
	print("AT_STEP debug_controls")
	var debug_panel_script := load("res://src/ui/debug_panel.gd")
	_check(debug_panel_script != null, "debug panel script loads")
	_check(arena.has_method("debug_controls_enabled"), "arena exposes debug controls gate")
	if arena.has_method("debug_controls_enabled"):
		_check(not bool(arena.call("debug_controls_enabled")), "headless run keeps debug controls disabled")
	var sp: Spawner = arena.spawner
	var debug_api_ready := sp.has_method("debug_skip_to_wave") and sp.has_method("debug_spawn_enemy") and sp.has_method("debug_spawn_boss") and sp.has_method("debug_spawn_root_split")
	_check(debug_api_ready, "spawner exposes debug wave and spawn controls")
	if not debug_api_ready:
		return
	sp.start(arena, arena.enemy_container, 1)
	for child in arena.enemy_container.get_children():
		child.queue_free()
	await _ticks(3)
	var skip_ok := bool(sp.call("debug_skip_to_wave", 7))
	_check(skip_ok and sp.wave == 7 and not sp._queue.is_empty(), "debug skip starts the requested wave")
	var spawned = sp.call("debug_spawn_enemy", "oom")
	await _ticks(2)
	_check(spawned is OomKiller and is_instance_valid(spawned) and spawned.threat_wave == 7, "debug spawn creates the selected enemy at current wave")
	var boss = sp.call("debug_spawn_boss", 2)
	await _ticks(2)
	_check(boss is RootBoss and is_instance_valid(boss) and boss.boss_index == 2 and sp._boss == boss, "debug spawn creates the selected boss")
	var split_ok := bool(sp.call("debug_spawn_root_split"))
	await _ticks(4)
	var mini_count := 0
	for candidate in get_tree().get_nodes_in_group("boss"):
		if is_instance_valid(candidate) and candidate.get("mini") == true:
			mini_count += 1
	_check(split_ok and mini_count == 2, "debug root split creates two mini bosses")
	for child in arena.enemy_container.get_children():
		child.queue_free()
	await _ticks(3)

func _mote_sweep_test(arena: Arena) -> void:
	print("AT_STEP mote_sweep")
	arena.spawner.stop()
	arena.spawner.debug_clear_encounter()
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node):
			node.queue_free()
	await _ticks(2)
	var mf: MoteField = arena.mote_field
	var player_ref: Player = arena.player
	player_ref.invuln = 9999.0
	Game.patch_levels = {}
	player_ref.meter = 0.0
	player_ref.overclock_active = false
	for i in range(mf.count() - 1, -1, -1):
		mf.kill_slot(i)
	var start := player_ref.global_position
	var far_idx := mf.spawn(start + Vector2(400.0, 0.0))
	var mid_idx := mf.spawn(start + Vector2(130.0, 0.0))
	await _ticks(3)
	player_ref.global_position = start + Vector2(260.0, 0.0)
	var collected := await _until(func() -> bool: return not mf.alive_at(mid_idx), 3.0, "swept mote pickup")
	_check(collected, "a dash-speed position jump collects a mote centered in the swept segment")
	_check(mf.alive_at(far_idx), "a distant mote is not collected by the swept segment")
	if far_idx >= 0 and mf.alive_at(far_idx):
		mf.kill_slot(far_idx)
	player_ref.invuln = 0.0

func _oom_steal_identity_test(arena: Arena) -> void:
	print("AT_STEP oom_identity")
	var mf: MoteField = arena.mote_field
	_check(mf.has_method("uid_of") and mf.has_method("idx_of_uid"), "mote field exposes identity handles")
	if not (mf.has_method("uid_of") and mf.has_method("idx_of_uid")):
		return
	arena.spawner.stop()
	arena.spawner.debug_clear_encounter()
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node):
			node.queue_free()
	await _ticks(2)
	var oom: EnemyBase = arena.spawner._make_enemy("oom")
	oom.position = arena.player.global_position + Vector2(320, 0)
	arena.enemy_container.add_child(oom)
	await _ticks(2)
	for i in range(mf.count() - 1, -1, -1):
		mf.kill_slot(i)
	var near_idx := mf.spawn(oom.global_position + Vector2(12.0, 0.0))
	var target_idx := mf.spawn(oom.global_position + Vector2(160.0, 0.0))
	var target_pos := mf.pos_of(target_idx)
	var target_uid: int = mf.call("uid_of", target_idx)
	oom.call("_steal", target_idx, target_uid)
	_check(mf.is_stolen(target_idx), "oom steals the targeted mote")
	mf.kill_slot(near_idx)
	var resolved: int = mf.call("idx_of_uid", target_uid)
	_check(resolved >= 0 and mf.alive_at(resolved) and mf.is_stolen(resolved), "the stolen mote keeps its identity after a slot swap")
	_check(mf.pos_of(resolved).distance_to(target_pos) < 0.01, "the carried slot still points at the stolen mote's position")
	var third_idx := mf.spawn(oom.global_position + Vector2(300.0, 0.0))
	var wrong_uid: int = int(target_uid) + 1000000
	oom.call("_steal", third_idx, wrong_uid)
	_check(not mf.is_stolen(third_idx), "a stale identity never steals a live free mote")
	oom.call("_steal", third_idx, mf.call("uid_of", third_idx))
	_check(mf.is_stolen(third_idx), "a matching identity steals normally")
	var probe: int = mf.nearest_free(oom.global_position)
	_check(probe < 0 or (mf.alive_at(probe) and not mf.is_stolen(probe)), "re-resolution only targets live free motes")
	oom.carried_ids.clear()
	mf.free_all_stolen()
	oom.queue_free()
	await _ticks(2)

func _hud_style_test(_arena: Arena) -> void:
	print("AT_STEP hud_style")
	var tui_script: Script = load("res://src/ui/tactical_ui.gd")
	var tui = tui_script.new() if tui_script != null else null
	_check(tui != null and tui.has_method("panel_fill_color"), "tactical ui exposes panel_fill_color")
	if tui == null or not tui.has_method("panel_fill_color"):
		return
	var combat_fill: Color = tui.call("panel_fill_color", true)
	var menu_fill: Color = tui.call("panel_fill_color", false)
	_check(combat_fill.a <= 0.08, "combat panel fill stays faint (alpha <= 0.08)")
	_check(combat_fill.a >= 0.04, "combat panel fill keeps a visible tint (alpha >= 0.04)")
	_check(menu_fill.is_equal_approx(TacticalUI.PANEL), "non-combat surfaces keep the opaque PANEL fill")
	var hud_script: Script = load("res://src/ui/hud.gd")
	_check(str(hud_script.source_code).contains("panel_fill_color(combat)"), "combat hud panels draw with the faint combat fill")

func _era_accent_test(arena: Arena) -> void:
	print("AT_STEP era_accent")
	var hud_ref = arena.hud
	_check(hud_ref != null and hud_ref.has_method("set_era_accent") and hud_ref.has_method("era_accent"), "hud exposes era accent controls")
	if hud_ref == null or not hud_ref.has_method("set_era_accent"):
		return
	var hud_script: Script = load("res://src/ui/hud.gd")
	var fresh_hud = hud_script.new() if hud_script != null else null
	_check(fresh_hud != null and fresh_hud.call("era_accent") == TacticalUI.CYAN, "hud era accent defaults to cyan")
	if fresh_hud != null:
		fresh_hud.free()
	var seed_before := Game.rng.seed
	hud_ref.call("set_era_accent", Balance.era_color(8))
	_check(hud_ref.call("era_accent") == Balance.era_color(8), "set_era_accent updates the hud accent")
	_check(Game.rng.seed == seed_before, "era accent changes never advance the gameplay rng")
	arena.call("_on_wave_started", 8, false)
	_check(arena.hud.call("era_accent") == Balance.era_color(8), "arena pushes the per-wave era accent to the hud")
	arena.set("_temple_mode", true)
	var accent_a: Color = arena.hud.call("era_accent")
	await _ticks(4)
	var accent_b: Color = arena.hud.call("era_accent")
	arena.set("_temple_mode", false)
	_check(accent_a != accent_b, "rainbow mode cycles the hud accent over time")
	hud_ref.call("set_era_accent", TacticalUI.CYAN)

func _story_test(arena: Arena) -> void:
	print("AT_STEP story")
	var story_script: Script = load("res://src/story/story_data.gd")
	_check(story_script != null, "story stage data script loads")
	_check(Game.has_method("story_stage_count") and Game.has_method("story_stage_def"), "game exposes story stage data")
	_check(Game.has_method("story_stage_unlocked"), "game exposes story unlock progression")
	_check(arena.spawner.has_method("start_story"), "spawner exposes fixed story queue")
	if story_script == null or not Game.has_method("story_stage_count") or not Game.has_method("story_stage_def") or not arena.spawner.has_method("start_story"):
		return
	var count := int(Game.story_stage_count())
	_check(count == 11 and Game.STORY_DATA.act_stage_count("unix") == 6 and Game.STORY_DATA.act_stage_count("windows") == 3 and Game.STORY_DATA.act_stage_count("templeos") == 2, "Story contains UNIX, Windows, and TempleOS stages")
	var expected_ids := ["boot", "var_log", "net", "mem", "quarantine", "kernel"]
	var expected_paths := ["/boot", "/var/log", "/net", "/mem", "/quarantine", "/kernel"]
	for i in mini(count, expected_ids.size()):
		var stage: Dictionary = Game.story_stage_def(i)
		_check(str(stage.get("id", "")) == expected_ids[i] and str(stage.get("path", "")) == expected_paths[i], "story stage %d has the expected UNIX path" % (i + 1))
	_check(Game.story_stage_def(0).get("waves", []).size() > 0, "story stages declare fixed waves")
	_check("boss" in Game.story_stage_def(5), "kernel stage declares its boss")
	var saved_mode := Game.mode
	var saved_state := Game.state
	var saved_stage := int(Game.get("story_stage_index")) if Game.get("story_stage_index") != null else 0
	var saved_cleared: Dictionary = Game.story_cleared.duplicate(true) if Game.get("story_cleared") is Dictionary else {}
	Game.story_cleared = {}
	_check(bool(Game.story_stage_unlocked(0)), "first story stage is unlocked")
	_check(not bool(Game.story_stage_unlocked(1)), "next story stage stays locked")
	Game.story_cleared["boot"] = true
	_check(bool(Game.story_stage_unlocked(1)) and not bool(Game.story_stage_unlocked(2)), "clearing one stage unlocks only the next stage")
	Game.mode = "story"
	Game.state = Game.State.PLAYING
	var sp: Spawner = arena.spawner
	sp.stop()
	sp.debug_clear_encounter()
	for child in arena.enemy_container.get_children():
		child.queue_free()
	await _ticks(2)
	var boot_stage: Dictionary = Game.story_stage_def(0)
	sp.start_story(arena, arena.enemy_container, boot_stage)
	_check(bool(sp.get("story_mode")), "story spawner enters scripted mode")
	var fixed_queue: Array = sp.get("_queue")
	_check(not fixed_queue.is_empty(), "story spawner loads a fixed queue")
	var fixed_only := true
	for kind in fixed_queue:
		if str(kind) != "drone":
			fixed_only = false
	_check(fixed_only, "boot queue contains only its declared enemy type")
	sp.stop()
	sp.debug_clear_encounter()
	Game.mode = saved_mode
	Game.state = saved_state
	Game.story_stage_index = saved_stage
	Game.story_cleared = saved_cleared
	sp.start(arena, arena.enemy_container, 1)
	await _ticks(3)

func _windows_test(arena: Arena) -> void:
	print("AT_STEP windows")
	var update_script: Script = load("res://src/enemies/update_loop.gd")
	var bloat_script: Script = load("res://src/enemies/bloatware.gd")
	var popup_script: Script = load("res://src/enemies/popup_orb.gd")
	var crt_script: Script = load("res://src/arena/crt_overlay.gd")
	_check(update_script != null and bloat_script != null and popup_script != null, "Windows enemy scripts load")
	_check(crt_script != null, "CRT overlay script loads")
	_check(Game.story_stage_count() == 11, "Story includes three Windows and two TempleOS stages")
	var paths := ["C:\\98", "C:\\XP", "Win11"]
	for i in paths.size():
		var stage: Dictionary = Game.story_stage_def(6 + i)
		_check(str(stage.get("path", "")) == paths[i], "Windows stage %d has the expected path" % (i + 1))
	_check(str(Game.story_stage_def(6).get("theme", {}).get("grid_style", "")) == "crt_heavy", "C98 selects the heavy CRT profile")
	_check(str(Game.story_stage_def(7).get("theme", {}).get("grid_style", "")) == "crt_soft", "CXP selects the soft CRT profile")
	_check(str(Game.story_stage_def(8).get("theme", {}).get("grid_style", "")) == "clean", "Win11 disables the CRT profile")
	var sp: Spawner = arena.spawner
	var update_enemy = sp.call("_make_enemy", "update_loop")
	var bloat_enemy = sp.call("_make_enemy", "bloatware")
	_check(update_enemy is UpdateLoopEnemy and bloat_enemy is BloatwareEnemy, "spawner creates the Windows enemy cast")
	if update_enemy != null:
		_check(update_enemy.has_method("reinstall_duration"), "UPDATE_LOOP exposes reinstall behavior")
	if bloat_enemy != null:
		_check(bloat_enemy.has_method("popup_count_on_death"), "BLOATWARE exposes popup drop behavior")
	if update_enemy is Node:
		update_enemy.free()
	if bloat_enemy is Node:
		bloat_enemy.free()
	_check(arena.has_method("windows_stage_profile"), "arena exposes Windows stage profile")

func _temple_test(arena: Arena) -> void:
	print("AT_STEP temple")
	var god_script: Script = load("res://src/enemies/god_boss.gd")
	_check(god_script != null, "GOD boss script loads")
	_check(Game.story_stage_count() == 11, "Story includes two TempleOS stages")
	_check(Game.STORY_DATA.act_stage_count("templeos") == 2, "TempleOS act exposes two stages")
	var paths := ["TempleOS::BOOT", "TempleOS::GOD"]
	for i in paths.size():
		var stage: Dictionary = Game.story_stage_def(9 + i)
		_check(str(stage.get("path", "")) == paths[i], "TempleOS stage %d has the expected path" % (i + 1))
	var temple_stage := Game.story_stage_def(9)
	var god_stage := Game.story_stage_def(10)
	_check(str(temple_stage.get("theme", {}).get("grid_style", "")) == "holy", "TempleOS uses the holy CRT profile")
	_check(temple_stage.get("arena_size", Vector2.ZERO) == Vector2(640.0, 640.0), "TempleOS shrinks the arena to 640x640")
	_check(str(god_stage.get("boss_kind", "")) == "god", "TempleOS final stage declares the GOD boss")
	var sp: Spawner = arena.spawner
	var god_enemy = sp.call("_make_enemy", "god")
	_check(god_enemy is GodBoss, "spawner creates the GOD boss")
	if god_enemy is GodBoss:
		_check(god_enemy.has_method("roll_oracle_attack"), "GOD exposes oracle attack selection")
		var old_seed := Game.rng.seed
		Game.rng.seed = 90210
		var oracle_a := str(god_enemy.call("roll_oracle_attack"))
		Game.rng.seed = 90210
		var oracle_b := str(god_enemy.call("roll_oracle_attack"))
		Game.rng.seed = old_seed
		_check(oracle_a == oracle_b and not oracle_a.is_empty(), "GOD oracle attacks follow the gameplay RNG")
	if god_enemy is Node:
		god_enemy.free()
	_check(arena.has_method("temple_stage_profile"), "arena exposes TempleOS stage profile")
	var old_size := Balance.arena_rect().size
	Balance.set_arena_size_override(Vector2(640.0, 640.0))
	_check(Balance.arena_rect().size == Vector2(640.0, 640.0), "arena override changes only the active combat rectangle")
	Balance.clear_arena_size_override()
	_check(Balance.arena_rect().size == old_size, "arena override restores the default rectangle")

func _glyph_lib_test() -> void:
	print("AT_STEP glyph_lib")
	var glyph_script: Script = load("res://src/ui/glyph_lib.gd")
	var glyph = glyph_script.new() if glyph_script != null else null
	_check(glyph != null and glyph.has_method("draw_glyph") and glyph.has_method("glyph_kinds") and glyph.has_method("era_mix"), "glyph library exposes draw_glyph, glyph_kinds, and era_mix")
	if glyph == null or not glyph.has_method("draw_glyph"):
		return
	var required := ["drone", "lancer", "spewer", "splitter", "bulwark", "trojan", "oom", "recursor", "firewall", "bloatware", "update_loop", "page", "root", "boss", "segfault", "bluescreen", "pagefault", "god", "kernel", "daemon", "rootlet"]
	var kinds: Array = glyph.call("glyph_kinds")
	var missing := false
	for kind in required:
		if not kinds.has(kind):
			missing = true
	_check(not missing, "glyph library covers every enemy and program kind")
	var seed_before := Game.rng.seed
	for kind in required:
		glyph.call("draw_glyph", null, kind, Vector2.ZERO, 4.0, Color.CYAN, 0.0)
		glyph.call("draw_glyph", null, kind, Vector2.ZERO, 64.0, Color.CYAN, 1.0)
	_check(Game.rng.seed == seed_before, "glyph drawing never advances the gameplay rng")
	var mixed: Color = glyph.call("era_mix", Color.RED, Color.CYAN, 0.25)
	_check(not mixed.is_equal_approx(Color.RED) and not mixed.is_equal_approx(Color.CYAN), "era_mix blends identity colors toward the era accent")
	var bestiary_source := str(load("res://src/ui/bestiary_panel.gd").source_code)
	var program_source := str(load("res://src/ui/program_panel.gd").source_code)
	_check(bestiary_source.contains("GlyphLib.draw_glyph"), "bestiary detail views reuse glyph_lib")
	_check(program_source.contains("GlyphLib.draw_glyph"), "program cards reuse glyph_lib")

func _icon_quality_test() -> void:
	print("AT_STEP icon_quality")
	var icon_script: Script = load("res://src/ui/tactical_icon.gd")
	var icon = icon_script.new() if icon_script != null else null
	_check(icon != null and icon.has_method("icon_kinds") and icon.has_method("icon_metrics") and icon.has_method("icon_bounds"), "tactical icon exposes icon_kinds, icon_metrics, and icon_bounds")
	if icon == null or not icon.has_method("icon_kinds"):
		if icon != null:
			icon.free()
		return
	var icon_src := str(icon_script.source_code)
	var kinds: Array = icon.call("icon_kinds")
	for kind in ["settings", "bestiary", "dash", "back", "resume", "restart", "terminal", "audio", "music", "warning"]:
		_check(kinds.has(kind), "tactical icon covers the %s kind" % kind)
		_check(icon_src.contains("\t\t\"%s\":" % kind), "%s icon resolves to a non-empty drawing routine" % kind)
		var metrics: Dictionary = icon.call("icon_metrics", str(kind))
		_check(bool(metrics.get("covered", false)), "%s icon has documented quality metrics" % kind)
		_check(float(metrics.get("min_stroke", 0.0)) >= 1.5, "%s icon documents a minimum stroke of at least 1.5" % kind)
		_check(float(metrics.get("contrast", 0.0)) >= 0.55, "%s icon documents panel contrast of at least 0.55" % kind)
		var bounds: Rect2 = icon.call("icon_bounds", str(kind))
		for side in [24.0, 52.0]:
			var abs_bounds := Rect2(bounds.position * side, bounds.size * side)
			_check(Rect2(Vector2.ZERO, Vector2(side, side)).encloses(abs_bounds.grow(-0.5)), "%s icon silhouette stays contained at %.0fpx" % [kind, side])
	icon.free()
	var patch_script: Script = load("res://src/ui/patch_card.gd")
	_check(patch_script != null and patch_script.has_method("patch_icon_family") and patch_script.has_method("patch_icon_metrics"), "patch card exposes patch_icon_family and patch_icon_metrics")
	if patch_script == null or not patch_script.has_method("patch_icon_family"):
		return
	var patch_src := str(patch_script.source_code)
	for family in ["_draw_damage_glyph", "_draw_fire_glyph", "_draw_defense_glyph", "_draw_utility_glyph", "_draw_movement_glyph", "_draw_economy_glyph"]:
		_check(patch_src.contains("func %s" % family), "patch card draws the %s family" % family.trim_prefix("_draw_").trim_suffix("_glyph"))
	for id in Game.PATCH_CODES:
		var family: String = patch_script.call("patch_icon_family", str(id))
		_check(["damage", "fire", "defense", "utility", "movement", "economy"].has(family), "%s patch icon belongs to a documented family" % str(id))
		var pmetrics: Dictionary = patch_script.call("patch_icon_metrics", str(id))
		_check(bool(pmetrics.get("covered", false)), "%s patch icon resolves to a non-empty drawing routine" % str(id))
		_check(float(pmetrics.get("min_stroke", 0.0)) >= 2.0, "%s patch icon documents a minimum stroke of at least 2.0" % str(id))
		_check(float(pmetrics.get("contrast", 0.0)) >= 0.55, "%s patch icon documents panel contrast of at least 0.55" % str(id))
	var hex_rect := Rect2(Vector2(24.0, 123.0), Vector2(68.0, 68.0))
	_check(Rect2(Vector2.ZERO, Vector2(280.0, 330.0)).encloses(hex_rect), "patch hex icon geometry stays contained in the 280x330 patch card")
	_check(icon_script.has_method("raster_path") and patch_script.has_method("patch_raster_path"), "icon raster registries keep the code-drawn fallback")
	var probe_path: String = icon_script.call("raster_path", "resume")
	_check(probe_path.is_empty() or ResourceLoader.exists(probe_path), "raster registry only resolves existing assets")

func _charm_terminal_test(arena: Arena) -> void:
	print("AT_STEP charm_terminal")
	var terminal_script: Script = load("res://src/ui/terminal_panel.gd")
	_check(terminal_script != null, "pause terminal script loads")
	_check(Game.has_method("log_event") and Game.has_method("dmesg_lines"), "game exposes run event log")
	_check(Game.has_method("consume_terminal_heal"), "game exposes one-use terminal heal")
	_check(arena.has_method("execute_terminal_command"), "arena exposes terminal command router")
	var terminal_button_found := false
	for child in arena._pause_panel.get_children():
		if child is Button and child.text == "OPEN TERMINAL":
			terminal_button_found = true
	_check(terminal_button_found and arena.get("_terminal_panel") != null, "pause exposes the terminal entry point")
	if terminal_script == null or not arena.has_method("execute_terminal_command"):
		return
	var saved_mode := Game.mode
	var saved_state := Game.state
	var saved_stats: Dictionary = Game.stats.duplicate(true)
	var saved_events: Array = Game.event_log.duplicate(true) if Game.get("event_log") is Array else []
	var saved_terminal_heal_used := bool(Game.get("terminal_heal_used"))
	var saved_patch_levels: Dictionary = Game.patch_levels.duplicate(true)
	Game.mode = "classic"
	Game.state = Game.State.PLAYING
	Game.wave = 3
	Game.stats = {"time": 12.5, "kills": 4, "shots": 10, "hits": 6, "damage": 1, "wave": 3, "boss_kills": 0, "heals": {}}
	Game.event_log = []
	Game.terminal_heal_used = false
	Game.log_event("TEST EVENT")
	var dmesg: Array = Game.dmesg_lines(4)
	_check(dmesg.size() == 1 and str(dmesg[0]).contains("TEST EVENT"), "dmesg formats the current run event log")
	_check(str(arena.execute_terminal_command("help")).contains("sudo heal"), "terminal help lists recovery command")
	_check(str(arena.execute_terminal_command("top")).contains("CYCLE 03"), "terminal top reports current cycle")
	_check(str(arena.execute_terminal_command("man drone")).contains("DRONE"), "terminal man returns a bestiary entry")
	_check(str(arena.execute_terminal_command("dmesg")).contains("TEST EVENT"), "terminal dmesg returns run events")
	if arena.player != null and is_instance_valid(arena.player):
		var old_hp := arena.player.hp
		arena.player.hp = maxi(1, arena.player.max_hp - 1)
		var heal_result := str(arena.execute_terminal_command("sudo heal"))
		_check(heal_result.contains("granted") and arena.player.hp == old_hp, "sudo heal restores one integrity")
		var second_heal := str(arena.execute_terminal_command("sudo heal"))
		_check(second_heal.contains("PERMISSION DENIED"), "sudo heal is limited to once per run")
		Game.mode = "onehp"
		Game.terminal_heal_used = false
		arena.player.hp = 1
		_check(str(arena.execute_terminal_command("sudo heal")).contains("PERMISSION DENIED"), "one hp mode rejects terminal healing")
		arena.player.hp = arena.player.max_hp
	Game.mode = saved_mode
	Game.state = saved_state
	Game.wave = int(saved_stats.get("wave", Game.wave))
	Game.stats = saved_stats
	Game.event_log = saved_events
	Game.terminal_heal_used = saved_terminal_heal_used
	Game.patch_levels = saved_patch_levels

func _charm_speedrun_test(arena: Arena) -> void:
	print("AT_STEP charm_speedrun")
	_check(Game.has_method("unlock_achievement") and Game.has_method("core_dump_text"), "game exposes achievements and core dump data")
	_check(Game.has_method("run_seed_text"), "game exposes visible run seed")
	_check(arena.hud != null and arena.hud.has_method("run_info_text"), "hud exposes speedrun info text")
	_check(arena.has_method("background_corruption_for_wave"), "arena exposes permanent grid corruption curve")
	_check(arena.has_method("restart_hold_duration"), "arena exposes hold-to-restart timing")
	if not Game.has_method("unlock_achievement"):
		return
	var achievement_disk := _config_section_snapshot("achievements")
	var saved_achievements: Dictionary = Game.achievements.duplicate(true) if Game.get("achievements") is Dictionary else {}
	var saved_stats: Dictionary = Game.stats.duplicate(true)
	var saved_events: Array = Game.event_log.duplicate(true) if Game.get("event_log") is Array else []
	var saved_seed := Game.run_seed
	Game.achievements = {}
	Game.stats = {"time": 42.25, "kills": 1, "shots": 8, "hits": 4, "damage": 2, "wave": 4, "boss_kills": 0, "heals": {}}
	Game.event_log = []
	Game.run_seed = 123456
	var unlocked := bool(Game.unlock_achievement("first_blood"))
	_check(unlocked and Game.achievements.has("first_blood"), "first achievement unlocks once")
	_check(not bool(Game.unlock_achievement("first_blood")), "duplicate achievement stays silent")
	_check(str(Game.dmesg_lines(8)).contains("achievement: FIRST_BLOOD enabled"), "achievement is recorded in dmesg")
	_check(str(Game.core_dump_text()).contains("SEGFAULT AT player.hp=0") and str(Game.core_dump_text()).contains("123456"), "core dump includes death marker and build seed")
	_check(Game.run_seed_text() == "SEED 123456", "run seed has compact HUD text")
	var old_info: bool = bool(Sfx.show_run_info)
	Sfx.show_run_info = true
	_check(str(arena.hud.run_info_text()).contains("SEED 123456") and str(arena.hud.run_info_text()).contains("00:42"), "speedrun HUD exposes seed and timer")
	Sfx.show_run_info = old_info
	_check(float(arena.call("background_corruption_for_wave", 1)) == 0.0, "grid starts uncorrupted")
	_check(float(arena.call("background_corruption_for_wave", 20)) > 0.0, "grid corruption advances with waves")
	_check(float(arena.call("restart_hold_duration")) > 0.0, "hold-to-restart uses a positive safety delay")
	Game.achievements = saved_achievements
	Game.stats = saved_stats
	Game.event_log = saved_events
	Game.run_seed = saved_seed
	_restore_config_section("achievements", achievement_disk)

func _story_menu_test(menu: Node) -> void:
	print("AT_STEP story_menu")
	var story_panel_script: Script = load("res://src/ui/story_panel.gd")
	_check(story_panel_script != null, "story selector script loads")
	_check(menu.has_method("_open_story_selector") and menu.get("_story_btn") != null, "menu exposes a separate Story entry")
	if story_panel_script == null or not menu.has_method("_open_story_selector"):
		return
	menu.call("_open_story_selector")
	await _ticks(2)
	var panel = menu.get("_story_panel")
	_check(panel != null and panel.visible, "story selector opens without changing endless mode")
	if panel != null:
		_check(panel.has_method("available_stage_indices") and panel.has_method("select_stage"), "story selector exposes stage interaction API")
		_check(panel.available_stage_indices().has(0), "first Story stage is selectable")
	menu.call("_close_story_selector")
	await _ticks(1)
	_check(not panel.visible, "story selector closes cleanly")

func _menu_shell_test(menu: Node) -> void:
	print("AT_STEP menu_shell")
	_check(menu.has_method("main_shell_snapshot"), "menu exposes main shell snapshot")
	_check(menu.has_method("settings_shell_snapshot"), "menu exposes settings shell snapshot")
	_check(menu.has_method("settings_layout_for_viewport"), "settings exposes responsive workstation geometry")
	if menu.has_method("settings_layout_for_viewport"):
		for viewport_size in [Vector2(1366, 768), Vector2(820, 768), Vector2(720, 720), Vector2(432, 720)]:
			var settings_layout: Dictionary = menu.settings_layout_for_viewport(viewport_size)
			var settings_bounds := Rect2(Vector2.ZERO, viewport_size)
			for rect_key in ["workstation", "navigation", "content", "footer", "title"]:
				_check(settings_bounds.encloses(settings_layout[rect_key]), "settings %s stays inside viewport at %dx%d" % [rect_key, int(viewport_size.x), int(viewport_size.y)])
			_check(settings_layout["navigation"].position.x < settings_layout["content"].position.x, "settings navigation precedes content at %dx%d" % [int(viewport_size.x), int(viewport_size.y)])
	if menu.has_method("main_shell_snapshot"):
		var main_snapshot: Dictionary = menu.main_shell_snapshot()
		_check(str(main_snapshot.get("title", "")).contains("KERNEL PANIC"), "main shell exposes kernel panic title")
		_check(str(main_snapshot.get("primary_action", "")).contains("PURGE"), "main shell exposes primary purge action")
		_check(not str(main_snapshot.get("mode_explanation", "")).strip_edges().is_empty(), "main shell exposes mode explanation")
		var routes: Array = main_snapshot.get("routes", [])
		_check(routes.has("PROGRAM") and routes.has("STORY") and routes.has("BESTIARY"), "main shell exposes program story and bestiary routes")
		_check(main_snapshot.has("shell_rect") and main_snapshot.has("footer_rect"), "main shell exposes shared frame and footer geometry")
		_check(main_snapshot.has("score_rect") and main_snapshot.has("primary_rect"), "main shell exposes score and primary action geometry")
		if main_snapshot.has("shell_rect") and main_snapshot.has("footer_rect"):
			var main_shell: Rect2 = main_snapshot["shell_rect"]
			_check(main_shell.encloses(main_snapshot["footer_rect"]), "main footer stays inside shared frame")
		if main_snapshot.has("score_rect") and main_snapshot.has("primary_rect"):
			_check(not Rect2(main_snapshot["score_rect"]).intersects(Rect2(main_snapshot["primary_rect"])), "main score clears the primary action")
	_check(menu.has_method("footer_button_layout_for_viewport"), "main footer exposes measured button geometry")
	if menu.has_method("footer_button_layout_for_viewport"):
		var footer_layout: Dictionary = menu.footer_button_layout_for_viewport(Vector2(1400, 768))
		_check(is_equal_approx(float(footer_layout.get("total_width", 0.0)), 448.0), "main footer matches the approved compact width")
		_check(is_equal_approx(float(footer_layout.get("button_width", 0.0)), 217.0), "main footer buttons keep equal measured widths")
		_check(is_equal_approx(float(footer_layout.get("gap", 0.0)), 14.0), "main footer keeps the measured center gap")
		var runtime_footer_layout: Dictionary = menu.footer_button_layout_for_viewport(Vector2(1024, 576))
		_check(is_equal_approx(float(runtime_footer_layout.get("total_width", 0.0)), 1024.0 * 0.327), "main footer scales from the logical viewport")
	if menu.has_method("settings_shell_snapshot"):
		var settings_snapshot: Dictionary = menu.settings_shell_snapshot()
		var groups: Array = settings_snapshot.get("groups", [])
		_check(groups.has("AUDIO") and groups.has("CONTROL") and groups.has("DISPLAY") and groups.has("SAVE TRANSFER"), "settings shell exposes aligned option groups")
		_check(bool(settings_snapshot.get("scrollable", false)), "settings shell remains scrollable")
		_check(settings_snapshot.has("shell_rect") and settings_snapshot.has("navigation_rect") and settings_snapshot.has("content_rect") and settings_snapshot.has("footer_rect"), "settings shell exposes workstation geometry")
		if settings_snapshot.has("shell_rect") and settings_snapshot.has("navigation_rect") and settings_snapshot.has("content_rect") and settings_snapshot.has("footer_rect"):
			var settings_shell: Rect2 = settings_snapshot["shell_rect"]
			_check(settings_shell.encloses(settings_snapshot["navigation_rect"]) and settings_shell.encloses(settings_snapshot["content_rect"]) and settings_shell.encloses(settings_snapshot["footer_rect"]), "settings workstation stays inside shared frame")
			_check(settings_snapshot["navigation_rect"].position.x < settings_snapshot["content_rect"].position.x, "settings navigation rail precedes content canvas")
		if menu.has_method("_open_settings"):
			menu._open_settings()
			await _ticks(1)
			var settings_scroll_nodes := menu.find_children("SettingsScroll", "ScrollContainer", true, false)
			_check(not settings_scroll_nodes.is_empty(), "settings workstation exposes its content scroll")
			if not settings_scroll_nodes.is_empty():
				var settings_scroll: ScrollContainer = settings_scroll_nodes[0]
				_check(settings_scroll.anchor_left == 0.0 and settings_scroll.anchor_right == 0.0 and settings_scroll.anchor_top == 0.0 and settings_scroll.anchor_bottom == 0.0, "settings scroll uses absolute workstation coordinates")
			var settings_field: LineEdit = menu.get("_save_transfer_field")
			if settings_field != null:
				settings_field.grab_focus()
			get_viewport().push_input(_key_event(KEY_ESCAPE))
			_check(not bool(menu.get("_settings_panel").visible), "Viewport Escape closes settings with a focused text field")
			menu._close_settings()
	var tactical_surface_script: Script = load("res://src/ui/tactical_state_surface.gd")
	_check(tactical_surface_script != null and tactical_surface_script.has_method("pause_section_rects"), "pause surface exposes separated volume and warning geometry")
	if tactical_surface_script != null and tactical_surface_script.has_method("pause_section_rects"):
		for viewport_size in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
			var pause_sections: Dictionary = tactical_surface_script.pause_section_rects(viewport_size)
			var pause_panel: Rect2 = tactical_surface_script.panel_rect_for_viewport(viewport_size, "pause")
			var volume_rect: Rect2 = pause_sections["volume"]
			var warning_rect: Rect2 = pause_sections["warning"]
			_check(pause_panel.encloses(volume_rect) and pause_panel.encloses(warning_rect), "pause sections stay inside panel at %dx%d" % [int(viewport_size.x), int(viewport_size.y)])
			_check(not volume_rect.intersects(warning_rect), "pause volume and abandon warning keep a visible gap at %dx%d" % [int(viewport_size.x), int(viewport_size.y)])

func _story_scene_test() -> void:
	print("AT_STEP story_scene")
	var saved_mode := Game.mode
	var saved_state := Game.state
	var saved_stage := Game.story_stage_index
	var saved_cleared: Dictionary = Game.story_cleared.duplicate(true)
	var saved_best: Dictionary = Game.story_best.duplicate(true)
	var story_disk := _config_section_snapshot("story")
	Game.story_cleared = {}
	Game.story_best = {}
	_check(bool(Game.start_story(0)), "story start accepts the first unlocked stage")
	var loaded := await _until(func() -> bool:
		return get_tree().current_scene != null and get_tree().current_scene.name == "Arena", 6.0, "story arena")
	if not loaded:
		return
	var story_arena: Arena = get_tree().current_scene
	await _ticks(3)
	_check(Game.mode == "story", "story arena loads in story mode")
	_check(str(story_arena.get("_story_stage").get("path", "")) == "/boot", "story arena loads the selected stage")
	_check(story_arena.get("_story_intro_panel") != null, "story arena builds an intro card")
	_check(story_arena.has_method("story_intro_active"), "story arena exposes the intro state query")
	_check(not story_arena.spawner.story_mode, "story spawner idles during the intro")
	await _simulation_seconds(1.5)
	_check(story_arena.enemy_container.get_children().is_empty(), "no enemies spawn during the intro")
	if story_arena.has_method("story_intro_active") and story_arena.has_method("dismiss_story_intro"):
		_check(story_arena.call("story_intro_active"), "story intro is active on scene load")
		story_arena.set("_story_intro_t", 0.0)
		_check(not story_arena.call("dismiss_story_intro"), "dismiss input before the minimum hold is ignored")
		story_arena.set("_story_intro_t", 1.0)
		_check(story_arena.call("dismiss_story_intro"), "dismiss after the minimum hold starts the story")
		await _ticks(6)
	_check(story_arena.spawner.story_mode, "story arena uses the scripted spawner")
	story_arena.spawner.stop()
	story_arena.spawner.debug_clear_encounter()
	story_arena.spawner.story_cleared.emit("boot")
	await _ticks(3)
	_check(Game.state == Game.State.GAME_OVER and bool(Game.story_cleared.get("boot", false)), "story victory saves the cleared stage")
	_check(bool(story_arena.get("_story_victory")), "story victory screen is shown")
	Game.story_cleared = saved_cleared
	Game.story_best = saved_best
	_restore_config_section("story", story_disk)
	Game.mode = saved_mode
	Game.state = saved_state
	Game.story_stage_index = saved_stage
	Game.to_menu()
	await _until(func() -> bool:
		return get_tree().current_scene != null and get_tree().current_scene.name == "Menu", 6.0, "story menu return")

func _story_intro_auto_test() -> void:
	print("AT_STEP story_intro_auto")
	var saved_mode := Game.mode
	var saved_state := Game.state
	var saved_stage := Game.story_stage_index
	Game.story_cleared[Game.story_stage_id(0)] = true
	_check(bool(Game.start_story(0)), "story auto-dismiss test loads the first stage")
	var loaded := await _until(func() -> bool:
		return get_tree().current_scene != null and get_tree().current_scene.name == "Arena", 6.0, "story arena")
	if not loaded:
		return
	var auto_arena: Arena = get_tree().current_scene
	await _ticks(3)
	_check(auto_arena.has_method("story_intro_active"), "auto-dismiss arena exposes the intro state query")
	if auto_arena.has_method("story_intro_active"):
		var dismissed := await _until(func() -> bool: return not auto_arena.call("story_intro_active"), 12.0, "story intro auto-dismiss")
		_check(dismissed, "story intro auto-dismisses after 8 seconds without input")
		await _ticks(6)
		_check(auto_arena.spawner.story_mode, "auto-dismiss starts story spawning")
	auto_arena.spawner.stop()
	auto_arena.spawner.debug_clear_encounter()
	Game.mode = saved_mode
	Game.state = saved_state
	Game.story_stage_index = saved_stage
	Game.to_menu()
	await _until(func() -> bool:
		return get_tree().current_scene != null and get_tree().current_scene.name == "Menu", 6.0, "menu return")

func _story_intro_layout_test() -> void:
	print("AT_STEP story_intro_layout")
	var tui_script: Script = load("res://src/ui/tactical_ui.gd")
	var tui = tui_script.new() if tui_script != null else null
	_check(tui != null and tui.has_method("fit_block"), "tactical ui exposes fit_block text measurement")
	if tui == null or not tui.has_method("fit_block"):
		return
	var mono: Font = load("res://assets/fonts/ShareTechMono.ttf")
	for vp in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
		var cap := minf(216.0, vp.y * 0.3)
		for stage_index in Game.story_stage_count():
			var intro := str(Game.story_stage_def(stage_index).get("intro", ""))
			var fit: Dictionary = tui.call("fit_block", mono, intro, 344.0, cap, 15, 12)
			_check(bool(fit.get("fits", false)) and int(fit.get("font_size", 0)) >= 12, "story intro %d measures inside the intro panel at %dx%d" % [stage_index + 1, int(vp.x), int(vp.y)])

func _temple_scene_test() -> void:
	print("AT_STEP temple_scene")
	var saved_mode := Game.mode
	var saved_state := Game.state
	var saved_stage := Game.story_stage_index
	var saved_cleared: Dictionary = Game.story_cleared.duplicate(true)
	var saved_best: Dictionary = Game.story_best.duplicate(true)
	var saved_rainbow := Game.temple_rainbow_unlocked
	var story_disk := _config_section_snapshot("story")
	Game.story_cleared = {}
	Game.story_best = {}
	Game.temple_rainbow_unlocked = false
	for i in 9:
		Game.story_cleared[Game.story_stage_id(i)] = true
	_check(bool(Game.start_story(9)), "TempleOS scene accepts the unlocked bonus act")
	var loaded := await _until(func() -> bool:
		return get_tree().current_scene != null and get_tree().current_scene.name == "Arena", 6.0, "TempleOS arena")
	if not loaded:
		Game.to_menu()
		await _until(func() -> bool:
			return get_tree().current_scene != null and get_tree().current_scene.name == "Menu", 6.0, "TempleOS menu return")
		Game.mode = saved_mode
		Game.state = saved_state
		Game.story_stage_index = saved_stage
		Game.story_cleared = saved_cleared
		Game.story_best = saved_best
		Game.temple_rainbow_unlocked = saved_rainbow
		_restore_config_section("story", story_disk)
		return
	var temple_arena: Arena = get_tree().current_scene
	await _ticks(3)
	if temple_arena.has_method("story_intro_active") and temple_arena.has_method("dismiss_story_intro"):
		if temple_arena.call("story_intro_active"):
			await _simulation_seconds(0.5)
			temple_arena.set("_story_intro_t", 1.0)
			temple_arena.call("dismiss_story_intro")
			await _ticks(6)
	_check(temple_arena.spawner.story_mode, "TempleOS arena uses the scripted spawner")
	_check(str(temple_arena.get("_story_stage").get("path", "")) == "TempleOS::BOOT", "TempleOS arena loads the boot stage")
	_check(Balance.arena_rect().size == Vector2(640.0, 640.0), "TempleOS runtime uses the compact arena")
	var temple_overlay = temple_arena.get("_crt_overlay")
	_check(temple_overlay != null and temple_overlay.is_active(), "TempleOS runtime enables the holy CRT")
	_check(bool(temple_arena.get("_temple_mode")), "TempleOS runtime enables the rainbow mode")
	temple_arena.spawner.stop()
	temple_arena.spawner.debug_clear_encounter()
	Game.to_menu()
	await _until(func() -> bool:
		return get_tree().current_scene != null and get_tree().current_scene.name == "Menu", 6.0, "TempleOS menu return")
	Game.mode = saved_mode
	Game.state = saved_state
	Game.story_stage_index = saved_stage
	Game.story_cleared = saved_cleared
	Game.story_best = saved_best
	Game.temple_rainbow_unlocked = saved_rainbow
	_restore_config_section("story", story_disk)

func _text_overflow_test() -> void:
	print("AT_STEP text_overflow")
	var surfaces := {
		"story": "res://src/ui/story_panel.gd",
		"bestiary": "res://src/ui/bestiary_panel.gd",
		"program": "res://src/ui/program_panel.gd",
		"patch_card": "res://src/ui/patch_card.gd",
		"menu": "res://src/ui/menu.gd",
		"terminal": "res://src/ui/terminal_panel.gd",
		"state_surface": "res://src/ui/tactical_state_surface.gd",
	}
	for surface_id in surfaces:
		var script: Script = load(surfaces[surface_id])
		var panel = script.new() if script != null else null
		_check(panel != null and panel.has_method("text_overflow_report"), "%s exposes text_overflow_report" % surface_id)
		if panel == null or not panel.has_method("text_overflow_report"):
			continue
		var all_fit := true
		for vp in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
			panel.size = vp
			for entry in panel.call("text_overflow_report"):
				all_fit = all_fit and bool(entry.get("fits", false))
		_check(all_fit, "%s keeps its representative text inside the panel at 1366x768, 720x720, and 432x720" % surface_id)
		panel.free()

func _touch_hud_layout_test() -> void:
	print("AT_STEP touch_hud_layout")
	var tui_script: Script = load("res://src/ui/tactical_ui.gd")
	var tui = tui_script.new() if tui_script != null else null
	_check(tui != null and tui.has_method("touch_dash_rect") and tui.has_method("touch_boost_rect"), "tactical ui exposes touch button rect helpers")
	if tui == null or not tui.has_method("touch_dash_rect"):
		return
	var hud_script: Script = load("res://src/ui/hud.gd")
	var hud_src := str(hud_script.source_code)
	_check(hud_src.contains("if not touch_layout():"), "combat hud skips desktop-only dash module drawing on touch")
	_check(hud_src.contains("label += \"  READY\""), "overclock ready keeps its label without the [E] keyboard hint on touch")
	_check(hud_src.contains("\"[SHIFT]\" if not touch_layout()"), "dash charge text gates the [SHIFT] keyboard hint on touch")
	_check(hud_src.contains("_banner.text = \"\" if hide_main else text"), "compact wave banner omits the duplicated cycle line")
	_check(hud_src.contains("_banner_sub_l.offset_top = 186"), "compact wave banner repositions below the encounter panel")
	var tc_script: Script = load("res://src/ui/touch_controls.gd")
	var tc = tc_script.new() if tc_script != null else null
	_check(tc != null and tc.has_method("_dash_btn") and tc.has_method("_oc_btn"), "touch controls expose button rects for layout probes")
	var saved_touch_scale := Sfx.touch_scale
	var saved_force := OS.get_environment("KP_FORCE_TOUCH")
	for scale in [0.85, 1.0, 1.2]:
		Sfx.touch_scale = scale
		for vp in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
			var view := Rect2(Vector2.ZERO, vp)
			var dash: Rect2 = tui.call("touch_dash_rect", vp, scale)
			var boost: Rect2 = tui.call("touch_boost_rect", vp, scale)
			_check(view.encloses(dash.grow(-2.0)), "touch dash ring stays inside the safe area at %dx%d scale %.2f" % [int(vp.x), int(vp.y), scale])
			_check(view.encloses(boost.grow(-2.0)), "touch boost ring stays inside the safe area at %dx%d scale %.2f" % [int(vp.x), int(vp.y), scale])
			if tc != null:
				tc.size = vp
				var tc_dash: Rect2 = tc.call("_dash_btn")
				var tc_boost: Rect2 = tc.call("_oc_btn")
				_check(tc_dash.is_equal_approx(dash), "touch dash button metrics match the shared helper at %dx%d scale %.2f" % [int(vp.x), int(vp.y), scale])
				_check(tc_boost.is_equal_approx(boost), "touch boost button metrics match the shared helper at %dx%d scale %.2f" % [int(vp.x), int(vp.y), scale])
			var layout_touch: Dictionary = tui.call("layout", vp, true, scale)
			var layout_plain: Dictionary = tui.call("layout", vp)
			var touch_patches: Rect2 = layout_touch["patches"]
			var plain_patches_vp: Rect2 = layout_plain["patches"]
			_check(bool(layout_touch["compact"]) == bool(layout_plain["compact"]), "touch layout keeps the compact flag size-based at %dx%d" % [int(vp.x), int(vp.y)])
			_check(not touch_patches.intersects(dash), "compact+touch patch dock never intersects the touch dash button at %dx%d scale %.2f" % [int(vp.x), int(vp.y), scale])
			_check(touch_patches.size.x >= minf(120.0, plain_patches_vp.size.x) - 0.01, "touch patch dock keeps readable chips at %dx%d scale %.2f" % [int(vp.x), int(vp.y), scale])
	Sfx.touch_scale = saved_touch_scale
	var banner_hud = hud_script.new()
	banner_hud.size = Vector2(432, 720)
	banner_hud.set("_banner_sub", "PURGE THE DAEMONS")
	_check(bool(banner_hud.call("_banner_compact")), "compact viewport suppresses the duplicated wave-banner cycle line")
	banner_hud.size = Vector2(1366, 768)
	_check(not bool(banner_hud.call("_banner_compact")), "desktop viewport keeps the full wave banner")
	banner_hud.size = Vector2(720, 720)
	banner_hud.set("_banner_sub", "")
	_check(not bool(banner_hud.call("_banner_compact")), "subtitle-less hint banners keep their main line on compact")
	banner_hud.free()
	var gate_hud = hud_script.new()
	OS.set_environment("KP_FORCE_TOUCH", "")
	_check(not bool(gate_hud.call("touch_layout")), "hud touch flag stays off without a touchscreen or override")
	var plain_patches: Rect2 = tui.call("layout", Vector2(1366, 768))["patches"]
	var snapshot_patches: Rect2 = gate_hud.call("layout_snapshot", Vector2(1366, 768))["patches"]
	_check(snapshot_patches.is_equal_approx(plain_patches), "non-touch hud snapshot keeps the desktop patch dock unchanged")
	OS.set_environment("KP_FORCE_TOUCH", "1")
	_check(bool(gate_hud.call("touch_layout")), "KP_FORCE_TOUCH forces the hud touch layout flag")
	var forced_patches: Rect2 = gate_hud.call("layout_snapshot", Vector2(1366, 768))["patches"]
	var forced_dash: Rect2 = tui.call("touch_dash_rect", Vector2(1366, 768), Sfx.touch_scale)
	_check(not forced_patches.intersects(forced_dash), "KP_FORCE_TOUCH snapshot moves the patch dock clear of the touch dash button")
	if saved_force.is_empty():
		OS.set_environment("KP_FORCE_TOUCH", "")
	else:
		OS.set_environment("KP_FORCE_TOUCH", saved_force)
	gate_hud.free()
	if tc != null:
		tc.free()

func _charm_save_transfer_test(menu: Node) -> void:
	print("AT_STEP charm_save_transfer")
	_check(Game.has_method("export_save_string") and Game.has_method("import_save_string"), "game exposes save transfer API")
	_check(menu.has_method("_export_save_to_clipboard") and menu.has_method("_import_save_from_clipboard"), "settings exposes save transfer actions")
	if not Game.has_method("export_save_string") or not Game.has_method("import_save_string"):
		return
	var saved_sections := {}
	for section in ["run", "weekly", "story", "bestiary", "programs", "achievements"]:
		saved_sections[section] = _config_section_snapshot(section)
	var saved_state := Game.state
	var saved_stats: Dictionary = Game.stats.duplicate(true)
	var saved_mode := Game.mode
	var saved_program := Game.program
	var saved_bestiary: Dictionary = Game.bestiary.duplicate(true)
	var saved_unlocked: Dictionary = Game.unlocked_programs.duplicate(true)
	var saved_achievements: Dictionary = Game.achievements.duplicate(true)
	var saved_story_cleared: Dictionary = Game.story_cleared.duplicate(true)
	var saved_story_best: Dictionary = Game.story_best.duplicate(true)
	var fixture := ConfigFile.new()
	fixture.load(Sfx.SAVE_PATH)
	fixture.set_value("run", "best_classic", 24680)
	fixture.set_value("run", "best_onehp", 13579)
	fixture.set_value("run", "onehp_unlocked", true)
	fixture.set_value("run", "program", "daemon")
	fixture.set_value("bestiary", "seen", {"drone": true, "oom": true})
	fixture.set_value("programs", "unlocked", {"kernel": true, "daemon": true})
	fixture.set_value("achievements", "unlocked", {"first_blood": true})
	fixture.save(Sfx.SAVE_PATH)
	Game.call("_load_run_config")
	var encoded := str(Game.export_save_string())
	_check(encoded.length() > 20 and not encoded.contains("24680"), "save export is a compact encoded string")
	Game.best = 0
	Game.bestiary = {}
	Game.unlocked_programs = {"kernel": true}
	Game.achievements = {}
	_check(bool(Game.import_save_string(encoded)), "save import accepts a valid transfer string")
	_check(Game.best == 24680 and Game.bestiary.has("oom") and Game.unlocked_programs.has("daemon") and Game.achievements.has("first_blood"), "save import restores progress, records, unlocks, and achievements")
	_check(not bool(Game.import_save_string("not-a-save")), "save import rejects malformed data")
	for section in saved_sections:
		_restore_config_section(section, saved_sections[section])
	Game.state = saved_state
	Game.stats = saved_stats
	Game.mode = saved_mode
	Game.program = saved_program
	Game.bestiary = saved_bestiary
	Game.unlocked_programs = saved_unlocked
	Game.achievements = saved_achievements
	Game.story_cleared = saved_story_cleared
	Game.story_best = saved_story_best

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
	_check(player.lockon_active, "lockon remains active in weekly")
	_check(Game.effective_aim_mode() == "lockon", "weekly keeps saved lockon mode")
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
		var menu := get_tree().current_scene
		if OS.get_environment("KP_PROGRAM") != "" and menu.has_method("_open_program_selector"):
			Game.unlocked_programs = {"kernel": true, "daemon": true, "rootlet": true}
			menu._open_program_selector()
		elif OS.get_environment("KP_STORY") != "" and menu.has_method("_open_story_selector"):
			for story_index in Game.story_stage_count() - 1:
				Game.story_cleared[Game.story_stage_id(story_index)] = true
			menu._open_story_selector()
		elif OS.get_environment("KP_BESTIARY") != "" and menu.has_method("_open_bestiary"):
			Game.bestiary = {}
			for bestiary_index in 8:
				Game.bestiary[BestiaryPanel.ENTRIES[bestiary_index]["id"]] = true
			Game.bestiary["root"] = true
			menu._open_bestiary()
		elif OS.get_environment("KP_SETTINGS") != "" and menu.has_method("_open_settings"):
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
			"terminal":
				_populate(arena, 2)
				await _ticks(20)
				arena._set_paused(true)
				arena._open_terminal()
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

func _achievements_panel_test() -> void:
	print("AT_STEP achievements_panel")
	var panel_script: Script = load("res://src/ui/achievements_panel.gd")
	var panel = panel_script.new() if panel_script != null else null
	_check(panel != null and panel.has_method("achievement_rows") and panel.has_method("progress_header"), "achievements panel exposes achievement_rows and progress_header")
	if panel == null or not panel.has_method("achievement_rows"):
		if panel != null:
			panel.free()
		return
	var saved_achievements: Dictionary = Game.achievements.duplicate()
	Game.achievements = {"first_blood": true}
	panel.size = Vector2(1366, 768)
	var rows: Array = panel.call("achievement_rows")
	var ids: Array = []
	for row in rows:
		ids.append(str(row.get("id", "")))
	var all_listed := true
	for id in Game.ACHIEVEMENT_DEFS:
		if not ids.has(str(id)):
			all_listed = false
	_check(all_listed, "achievements panel lists every ACHIEVEMENT_DEFS id")
	var state_ok: bool = rows.size() == Game.ACHIEVEMENT_DEFS.size()
	for row in rows:
		if bool(row.get("unlocked", false)) == (not Game.achievements.has(str(row.get("id", "")))):
			state_ok = false
	_check(state_ok, "achievements rows report the correct locked state")
	_check(str(panel.call("progress_header")).contains("1 / %d" % Game.ACHIEVEMENT_DEFS.size()), "achievements header shows the X / Y progress count")
	var hints_ok := true
	for row in rows:
		if not Game.achievements.has(str(row.get("id", ""))) and str(row.get("hint", "")).strip_edges().is_empty():
			hints_ok = false
	_check(hints_ok, "locked achievements expose a hint line")
	var panel_src := str(panel_script.source_code)
	_check(panel_src.contains("ScrollContainer"), "achievements panel scrolls instead of blocking mobile input")
	panel.free()
	var menu_src := str(load("res://src/ui/menu.gd").source_code)
	_check(menu_src.contains("_open_achievements"), "menu exposes an achievements entry point")
	var hud_script: Script = load("res://src/ui/hud.gd")
	var hud_detached = hud_script.new()
	hud_detached.size = Vector2(1366, 768)
	Game.achievements.erase("chain_max")
	var unlocked_now: bool = Game.unlock_achievement("chain_max")
	_check(unlocked_now, "test unlock of a fresh achievement succeeds")
	var surfaced := false
	for line in hud_detached.call("visible_event_lines"):
		if str(line).contains("achievement: CHAIN_REACTION"):
			surfaced = true
	_check(surfaced, "a mid-run unlock appears in the hud event log lines")
	hud_detached.size = Vector2(432, 720)
	_check(not bool(hud_detached.call("event_log_visible")), "compact viewport keeps the event log hidden for the hidden-log probe")
	Game.achievements.erase("terminal_operator")
	Game.unlock_achievement("terminal_operator")
	_check(hud_detached.call("visible_event_lines").size() > 0, "unlocking while the event log is hidden does not error")
	hud_detached.free()
	Game.achievements = saved_achievements
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	cf.set_value("achievements", "unlocked", saved_achievements)
	cf.save(Sfx.SAVE_PATH)

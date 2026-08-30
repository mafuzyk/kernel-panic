extends Node
const HSectionBoot = preload("res://src/autoload/harness/sections_boot.gd")
const HSectionTasksA = preload("res://src/autoload/harness/sections_tasks_a.gd")
const HSectionTasksB = preload("res://src/autoload/harness/sections_tasks_b.gd")
const HSectionSystemsA = preload("res://src/autoload/harness/sections_systems_a.gd")
const HSectionSystemsB1 = preload("res://src/autoload/harness/sections_systems_b1.gd")
const HSectionSystemsB2 = preload("res://src/autoload/harness/sections_systems_b2.gd")
const HSectionMisc = preload("res://src/autoload/harness/sections_misc.gd")
const HSectionVisual = preload("res://src/autoload/harness/sections_visual.gd")

var active := false
var _fails := 0
var _sec_boot
var _sec_tasks_a
var _sec_tasks_b
var _sec_systems_a
var _sec_systems_b1
var _sec_systems_b2
var _sec_misc
var _sec_visual

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

func _init_sections() -> void:
	_sec_boot = HSectionBoot.new(self)
	_sec_tasks_a = HSectionTasksA.new(self)
	_sec_tasks_b = HSectionTasksB.new(self)
	_sec_systems_a = HSectionSystemsA.new(self)
	_sec_systems_b1 = HSectionSystemsB1.new(self)
	_sec_systems_b2 = HSectionSystemsB2.new(self)
	_sec_misc = HSectionMisc.new(self)
	_sec_visual = HSectionVisual.new(self)

func _autotest() -> void:
	_watchdog()
	_init_sections()
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
	await _sec_boot._color_assist_test()
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
	await _sec_boot._onboarding_test(arena)
	await _ticks(1)
	var onboarding_abort_path := OS.get_environment("KP_ONBOARDING_ABORT") != ""
	var onboarding_restore_label := "aborted onboarding probe restores tutorial hints ConfigFile section" if onboarding_abort_path else "onboarding probe restores tutorial hints ConfigFile section"
	_check(_config_snapshot_matches(onboarding_tutorial_disk_before, _config_snapshot("tutorial", "hints", {})), onboarding_restore_label)
	await _sec_tasks_a._input_safety_test(arena)
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
	await _sec_tasks_a._task2_test(arena2)
	await _sec_tasks_a._task5_test(arena2)
	await _sec_tasks_b._task6_test(arena2)
	await _sec_tasks_b._task9_test(arena2)
	await _sec_visual._hud_style_test(arena2)
	await _sec_visual._era_accent_test(arena2)
	await _sec_systems_a._systems_test_a(arena2)
	await _sec_systems_b1._systems_test_b1(arena2)
	await _sec_systems_b2._systems_test_b2(arena2)
	await _sec_misc._difficulty_test()
	await _sec_misc._debug_controls_test(arena2)
	await _sec_misc._mote_sweep_test(arena2)
	await _sec_misc._oom_steal_identity_test(arena2)
	await _sec_visual._story_test(arena2)
	await _sec_visual._windows_test(arena2)
	await _sec_visual._temple_test(arena2)
	await _sec_visual._glyph_lib_test()
	await _sec_visual._icon_quality_test()
	await _sec_visual._raster_trial_test()
	await _sec_visual._charm_terminal_test(arena2)
	await _sec_visual._charm_speedrun_test(arena2)
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
	await _sec_boot._task10_test(menu_scene)
	_check(_config_sections_equal(run_before_task10, _config_section_snapshot("run")), "task10 restores run config section")
	await _sec_boot._task11_test(menu_scene)
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

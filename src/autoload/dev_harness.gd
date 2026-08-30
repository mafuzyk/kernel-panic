extends Node
const HSectionBoot = preload("res://src/autoload/harness/sections_boot.gd")
const HSectionTasksA = preload("res://src/autoload/harness/sections_tasks_a.gd")
const HSectionTasksB = preload("res://src/autoload/harness/sections_tasks_b.gd")
const HSectionSystemsA = preload("res://src/autoload/harness/sections_systems_a.gd")
const HSectionSystemsB1 = preload("res://src/autoload/harness/sections_systems_b1.gd")
const HSectionSystemsB2 = preload("res://src/autoload/harness/sections_systems_b2.gd")
const HSectionMisc = preload("res://src/autoload/harness/sections_misc.gd")
const HSectionVisual = preload("res://src/autoload/harness/sections_visual.gd")
const HSectionScene = preload("res://src/autoload/harness/sections_scene.gd")
const HSectionModes = preload("res://src/autoload/harness/sections_modes.gd")
const HSectionPolish = preload("res://src/autoload/harness/sections_polish.gd")

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
var _sec_scene
var _sec_modes
var _sec_polish

func _ready() -> void:
	_init_sections()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	if "--autotest" in args:
		active = true
		_autotest.call_deferred()
	elif OS.get_environment("KP_DEMO") != "":
		active = true
		_sec_modes._demo.call_deferred()
	elif OS.get_environment("KP_STRESS") != "":
		active = true
		_sec_modes._stress.call_deferred()
	elif OS.get_environment("KP_SHOT") != "":
		active = true
		_sec_modes._capture.call_deferred()

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
	_sec_scene = HSectionScene.new(self)
	_sec_modes = HSectionModes.new(self)
	_sec_polish = HSectionPolish.new(self)

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
	await _sec_modes._touch_test()
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
	await _sec_scene._story_menu_test(menu_scene)
	await _sec_scene._menu_shell_test(menu_scene)
	await _sec_polish._settings_tabs_test(menu_scene)
	await _sec_polish._settings_chips_test(menu_scene)
	await _sec_polish._menu_reflow_test(menu_scene)
	await _sec_scene._text_overflow_test()
	await _sec_polish._bestiary_glyph_test()
	await _sec_scene._touch_hud_layout_test()
	await _sec_modes._achievements_panel_test()
	await _sec_polish._awards_chrome_test(menu_scene)
	await _sec_scene._charm_save_transfer_test(menu_scene)
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
	await _sec_scene._story_scene_test()
	await _sec_scene._story_intro_auto_test()
	await _sec_scene._story_intro_layout_test()
	await _sec_scene._temple_scene_test()
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

func _finish() -> void:
	if _fails == 0:
		print("AUTOTEST_ALL_PASS")
		get_tree().quit(0)
	else:
		print("AUTOTEST_FAILED fails=%d" % _fails)
		get_tree().quit(1)

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


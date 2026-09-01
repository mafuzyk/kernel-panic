extends RefCounted

## Autotest section script. Function bodies below are moved verbatim from
## src/autoload/dev_harness.gd; only harness-helper references are prefixed
## with `h` per plan section G3. No behavior changes. AT_STEP labels and
## message strings are byte-identical to the originals.

var h: Node


func _init(harness: Node) -> void:
	h = harness

func _difficulty_test() -> void:
	print("AT_STEP difficulty")
	var balance_script: Script = load("res://src/autoload/balance.gd")
	var has_helpers: bool = balance_script != null and balance_script.has_method("difficulty_max_alive") and balance_script.has_method("difficulty_wave_budget") and balance_script.has_method("difficulty_elite_chance") and balance_script.has_method("difficulty_cadence")
	h._check(has_helpers, "balance exposes difficulty-aware read helpers")
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
		h._check(balance_script.call("difficulty_max_alive", 2) == int(alive_caps[difficulty]), "difficulty %s caps wave 2 alive at %d" % [difficulty, alive_caps[difficulty]])
		var expected_budget: int = int(floor(float(Balance.wave_budget(5)) * float(budget_mults[difficulty])))
		h._check(balance_script.call("difficulty_wave_budget", 5) == expected_budget, "difficulty %s scales the wave budget" % difficulty)
		var expected_elite: float = clampf(Balance.elite_chance(10) * float(elite_mults[difficulty]), 0.0, 1.0)
		h._check(absf(float(balance_script.call("difficulty_elite_chance", 10)) - expected_elite) < 0.0001, "difficulty %s scales the elite chance" % difficulty)
		h._check(absf(float(balance_script.call("difficulty_cadence", 1)) - 1.0) < 0.001, "difficulty %s keeps wave 1 cadence at 1.0" % difficulty)
		h._check(absf(float(balance_script.call("difficulty_cadence", 30)) - float(cadence_floors[difficulty])) < 0.005, "difficulty %s lands wave 30 cadence on %.2f" % [difficulty, cadence_floors[difficulty]])
	Game.mode = "story"
	for difficulty in ["easy", "normal", "hard"]:
		Game.set("difficulty", difficulty)
		var story_unscaled: bool = balance_script.call("difficulty_max_alive", 30) == Balance.max_alive(30) and balance_script.call("difficulty_wave_budget", 30) == Balance.wave_budget(30) and absf(float(balance_script.call("difficulty_cadence", 30)) - Balance.attack_cadence_factor(30)) < 0.0001 and absf(float(balance_script.call("difficulty_elite_chance", 10)) - Balance.elite_chance(10)) < 0.0001
		h._check(story_unscaled, "story ignores difficulty %s" % difficulty)
	Game.mode = "classic"
	if Game.has_method("set_difficulty"):
		Game.call("set_difficulty", "hard")
		h._check(str(Game.get("difficulty")) == "hard", "set_difficulty stores a new difficulty")
		var cf_probe := ConfigFile.new()
		cf_probe.load(Sfx.SAVE_PATH)
		h._check(str(cf_probe.get_value("game", "difficulty", "")) == "hard", "difficulty persists to the save config")
		Game.call("set_difficulty", "normal")
		h._check(str(Game.get("difficulty")) == "normal", "set_difficulty restores normal")
	Game.mode = saved_mode
	Game.set("difficulty", saved_difficulty)

func _debug_controls_test(arena: Arena) -> void:
	print("AT_STEP debug_controls")
	var debug_panel_script := load("res://src/ui/debug_panel.gd")
	h._check(debug_panel_script != null, "debug panel script loads")
	h._check(arena.has_method("debug_controls_enabled"), "arena exposes debug controls gate")
	if arena.has_method("debug_controls_enabled"):
		h._check(not bool(arena.call("debug_controls_enabled")), "headless run keeps debug controls disabled")
	var sp: Spawner = arena.spawner
	var debug_api_ready := sp.has_method("debug_skip_to_wave") and sp.has_method("debug_spawn_enemy") and sp.has_method("debug_spawn_boss") and sp.has_method("debug_spawn_root_split")
	h._check(debug_api_ready, "spawner exposes debug wave and spawn controls")
	if not debug_api_ready:
		return
	sp.start(arena, arena.enemy_container, 1)
	for child in arena.enemy_container.get_children():
		child.queue_free()
	await h._ticks(3)
	var skip_ok := bool(sp.call("debug_skip_to_wave", 7))
	h._check(skip_ok and sp.wave == 7 and not sp._queue.is_empty(), "debug skip starts the requested wave")
	var spawned = sp.call("debug_spawn_enemy", "oom")
	await h._ticks(2)
	h._check(spawned is OomKiller and is_instance_valid(spawned) and spawned.threat_wave == 7, "debug spawn creates the selected enemy at current wave")
	var boss = sp.call("debug_spawn_boss", 2)
	await h._ticks(2)
	h._check(boss is RootBoss and is_instance_valid(boss) and boss.boss_index == 2 and sp._boss == boss, "debug spawn creates the selected boss")
	var split_ok := bool(sp.call("debug_spawn_root_split"))
	await h._ticks(4)
	var mini_count := 0
	for candidate in h.get_tree().get_nodes_in_group("boss"):
		if is_instance_valid(candidate) and candidate.get("mini") == true:
			mini_count += 1
	h._check(split_ok and mini_count == 2, "debug root split creates two mini bosses")
	for child in arena.enemy_container.get_children():
		child.queue_free()
	await h._ticks(3)

func _mote_sweep_test(arena: Arena) -> void:
	print("AT_STEP mote_sweep")
	arena.spawner.stop()
	arena.spawner.debug_clear_encounter()
	for node in h.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node):
			node.queue_free()
	await h._ticks(2)
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
	await h._ticks(3)
	player_ref.global_position = start + Vector2(260.0, 0.0)
	var collected: bool = await h._until(func() -> bool: return not mf.alive_at(mid_idx), 3.0, "swept mote pickup")
	h._check(collected, "a dash-speed position jump collects a mote centered in the swept segment")
	h._check(mf.alive_at(far_idx), "a distant mote is not collected by the swept segment")
	if far_idx >= 0 and mf.alive_at(far_idx):
		mf.kill_slot(far_idx)
	player_ref.invuln = 0.0

func _mote_center_test(arena: Arena) -> void:
	print("AT_STEP mote_center")
	var mf: MoteField = arena.mote_field
	var player_ref: Player = arena.player
	player_ref.invuln = 9999.0
	for i in range(mf.count() - 1, -1, -1):
		mf.kill_slot(i)
	var center := player_ref.global_position
	for distance in [0.0, 0.5, 1.0, 2.0]:
		var idx := mf.spawn(center + Vector2(distance, 0.0))
		await h._ticks(2)
		h._check(idx >= 0 and not mf.alive_at(idx), "mote at %.1fpx from player is collected" % distance)
	player_ref.invuln = 0.0

func _oom_steal_identity_test(arena: Arena) -> void:
	print("AT_STEP oom_identity")
	var mf: MoteField = arena.mote_field
	h._check(mf.has_method("uid_of") and mf.has_method("idx_of_uid"), "mote field exposes identity handles")
	if not (mf.has_method("uid_of") and mf.has_method("idx_of_uid")):
		return
	arena.spawner.stop()
	arena.spawner.debug_clear_encounter()
	for node in h.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node):
			node.queue_free()
	await h._ticks(2)
	var oom: EnemyBase = arena.spawner._make_enemy("oom")
	oom.position = arena.player.global_position + Vector2(320, 0)
	arena.enemy_container.add_child(oom)
	await h._ticks(2)
	for i in range(mf.count() - 1, -1, -1):
		mf.kill_slot(i)
	var near_idx := mf.spawn(oom.global_position + Vector2(12.0, 0.0))
	var target_idx := mf.spawn(oom.global_position + Vector2(160.0, 0.0))
	var target_pos := mf.pos_of(target_idx)
	var target_uid: int = mf.call("uid_of", target_idx)
	oom.call("_steal", target_idx, target_uid)
	h._check(mf.is_stolen(target_idx), "oom steals the targeted mote")
	mf.kill_slot(near_idx)
	var resolved: int = mf.call("idx_of_uid", target_uid)
	h._check(resolved >= 0 and mf.alive_at(resolved) and mf.is_stolen(resolved), "the stolen mote keeps its identity after a slot swap")
	h._check(mf.pos_of(resolved).distance_to(target_pos) < 0.01, "the carried slot still points at the stolen mote's position")
	var third_idx := mf.spawn(oom.global_position + Vector2(300.0, 0.0))
	var wrong_uid: int = int(target_uid) + 1000000
	oom.call("_steal", third_idx, wrong_uid)
	h._check(not mf.is_stolen(third_idx), "a stale identity never steals a live free mote")
	oom.call("_steal", third_idx, mf.call("uid_of", third_idx))
	h._check(mf.is_stolen(third_idx), "a matching identity steals normally")
	var probe: int = mf.nearest_free(oom.global_position)
	h._check(probe < 0 or (mf.alive_at(probe) and not mf.is_stolen(probe)), "re-resolution only targets live free motes")
	oom.carried_ids.clear()
	mf.free_all_stolen()
	oom.queue_free()
	await h._ticks(2)

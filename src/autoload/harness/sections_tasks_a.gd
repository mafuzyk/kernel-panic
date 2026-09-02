extends RefCounted

## Autotest section script. Function bodies below are moved verbatim from
## src/autoload/dev_harness.gd; only harness-helper references are prefixed
## with `h` per plan section G3. No behavior changes. AT_STEP labels and
## message strings are byte-identical to the originals.

var h: Node


func _init(harness: Node) -> void:
	h = harness

func _input_safety_test(arena: Arena) -> void:
	print("AT_STEP input_safety")
	var overclock_events: Array = []
	var abandon_events: Array = []
	if InputMap.has_action("overclock"):
		overclock_events = InputMap.action_get_events("overclock")
	if InputMap.has_action("abandon"):
		abandon_events = InputMap.action_get_events("abandon")
	h._check(overclock_events.size() == 1 and h._has_physical_key("overclock", KEY_E) and not h._has_physical_key("overclock", KEY_Q), "overclock is bound to E only")
	h._check(InputMap.has_action("abandon") and abandon_events.size() == 1 and h._has_physical_key("abandon", KEY_Q) and not h._has_physical_key("abandon", KEY_E), "abandon is bound to Q only")
	Game.state = Game.State.PLAYING
	arena._state = "play"
	arena._set_paused(false)
	h.get_viewport().push_input(h._key_event(KEY_ESCAPE))
	h._check(h.get_tree().paused, "Viewport Escape opens pause through input dispatch")
	h.get_viewport().push_input(h._key_event(KEY_ESCAPE, true))
	h._check(h.get_tree().paused, "Escape key repeat does not immediately close pause")
	h.get_viewport().push_input(h._key_event(KEY_ESCAPE))
	h._check(not h.get_tree().paused, "Viewport Escape closes pause while tree is paused")
	arena._set_paused(true)
	var focused_pause_button: Button = null
	for pause_child in arena._pause_panel.get_children():
		if pause_child is Button and pause_child.text == "RESUME":
			focused_pause_button = pause_child
			break
	if focused_pause_button != null:
		focused_pause_button.grab_focus()
	h.get_viewport().push_input(h._key_event(KEY_ESCAPE))
	h._check(not h.get_tree().paused, "Viewport Escape closes pause when a pause button has focus")
	Game.state = Game.State.PLAYING
	arena._state = "play"
	arena._set_paused(true)
	arena._unhandled_input(h._key_event(KEY_E))
	h._check(Game.state == Game.State.PLAYING, "E has no effect while paused")
	Game.state = Game.State.PLAYING
	arena._set_paused(true)
	arena._unhandled_input(h._key_event(KEY_Q))
	h._check(Game.state == Game.State.PLAYING and arena.get("_abandon_armed") == true, "first Q arms abandon confirmation without leaving run")
	h._check(arena._pause_info.text.contains("PRESS Q AGAIN // ABANDON PROCESS"), "pause explains two-step abandon confirmation")
	arena._unhandled_input(h._key_event(KEY_Q))
	# The scene-transition harness keeps this Arena reference alive; the real
	# monotonic interval is covered by input_dispatch_probe. Age the armed state
	# here so this unit section can continue without yielding into a freed scene.
	arena.set("_pause_destructive_started_msec", Time.get_ticks_msec() - 600)
	arena._unhandled_input(h._key_event(KEY_Q))
	h._check(Game.state == Game.State.MENU, "second Q after the safety interval returns to menu")
	Game.state = Game.State.PLAYING
	arena._set_paused(true)
	arena._unhandled_input(h._key_event(KEY_Q))
	var stale_timer = arena.get("_abandon_timer")
	arena._set_paused(false)
	Game.state = Game.State.PLAYING
	arena._set_paused(true)
	arena._unhandled_input(h._key_event(KEY_Q))
	if stale_timer != null:
		stale_timer.emit_signal("timeout")
	h._check(arena.get("_abandon_armed") == true, "stale abandon timer cannot clear a rearmed confirmation")
	arena.set("_pause_destructive_started_msec", Time.get_ticks_msec() - 600)
	arena._unhandled_input(h._key_event(KEY_Q))
	h._check(Game.state == Game.State.MENU, "rearmed confirmation accepts a deliberate second Q")
	Game.state = Game.State.PLAYING
	arena._set_paused(true)
	arena._unhandled_input(h._key_event(KEY_Q))
	arena._unhandled_input(h._key_event(KEY_Q, true))
	h._check(Game.state == Game.State.PLAYING and arena.get("_abandon_armed") == true, "echo Q does not confirm abandon")
	arena.set("_pause_destructive_started_msec", Time.get_ticks_msec() - 600)
	arena._unhandled_input(h._key_event(KEY_Q))
	h._check(Game.state == Game.State.MENU, "physical Q after echo confirms abandon after the safety interval")
	Game.state = Game.State.PLAYING
	arena._set_paused(true)
	arena._unhandled_input(h._key_event(KEY_Q))
	arena._set_paused(false)
	h._check(arena.get("_abandon_armed") != true, "resume clears abandon confirmation")
	var abandon_button: Button
	for child in arena._pause_panel.get_children():
		if child is Button and child.text == "ABANDON PROCESS":
			abandon_button = child
	h._check(abandon_button != null, "pause exposes abandon button")
	Game.state = Game.State.PLAYING
	arena._set_paused(true)
	if abandon_button != null:
		abandon_button.emit_signal("pressed")
	h._check(Game.state == Game.State.PLAYING and arena.get("_abandon_armed") == true, "first abandon button press arms confirmation")
	if abandon_button != null:
		abandon_button.emit_signal("pressed")
	h._check(Game.state == Game.State.PLAYING and arena.get("_abandon_armed") == true, "rapid second abandon button press is ignored")
	arena.set("_pause_destructive_started_msec", Time.get_ticks_msec() - 600)
	if abandon_button != null:
		abandon_button.emit_signal("pressed")
	h._check(Game.state == Game.State.MENU, "deliberate abandon button press confirms after the safety interval")
	Game.state = Game.State.PLAYING
	arena._set_paused(true)
	arena._unhandled_input(h._key_event(KEY_Q))
	arena._unhandled_input(h._key_event(KEY_R))
	h._check(arena.get("_abandon_armed") != true, "restart clears abandon confirmation")
	Game.state = Game.State.PLAYING
	h.get_tree().paused = false
	arena._state = "play"
	arena._set_paused(true)
	arena._unhandled_input(h._key_event(KEY_Q))
	arena._process(2.1)
	h._check(arena.get("_abandon_armed") != true, "confirmation expires after two seconds")
	Game.state = Game.State.PLAYING
	arena._set_paused(true)
	arena._unhandled_input(h._key_event(KEY_Q))
	arena._on_player_died()
	h._check(arena.get("_abandon_armed") != true, "game over clears abandon confirmation")
	Game.state = Game.State.PLAYING
	arena._state = "play"
	h.get_tree().paused = false
	arena._set_paused(true)
	arena._unhandled_input(h._key_event(KEY_Q))
	arena._exit_tree()
	h._check(arena.get("_abandon_armed") != true, "arena teardown clears abandon confirmation")
	arena._state = "play"
	h.get_tree().paused = false

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
	h._check(Game.has_method("should_offer_patch"), "patch cadence helper exists")
	for mode_name in ["classic", "weekly", "onehp"]:
		Game.mode = mode_name
		for i in cadence_waves.size():
			h._check(_task2_should_offer_patch(cadence_waves[i]) == cadence_expected[mode_name][i], "%s patch cadence wave %d" % [mode_name, cadence_waves[i]])

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
	h._check(forbidden_found.is_empty(), "onehp offers exclude health, healing, recover, and death-save patches (%s)" % ",".join(forbidden_found))
	h._check(onehp_ids.has("shield"), "onehp offers include shield patch")
	h._check(onehp_ids.has("absorb"), "onehp offers include absorption patch")

	var saved_player: Player = arena.player
	var onehp_player := Player.new()
	onehp_player.position = Vector2(220, 0)
	arena.add_child(onehp_player)
	arena.player = onehp_player
	await h._ticks(2)
	h._check(onehp_player.max_hp == 1 and onehp_player.hp == 1, "onehp replacement patch probes keep one-integrity starting rule")
	onehp_player.invuln = 0.0
	Game.patch_levels = {}
	Game.apply_patch("shield")
	onehp_player.take_damage(onehp_player.global_position + Vector2(10, 0), "TASK2 SHIELD")
	h._check(onehp_player.hp == 1 and not onehp_player.dead, "shield charge prevents one incoming hit")
	onehp_player.invuln = 0.0
	Game.patch_levels = {}
	onehp_player.meter = 0.0
	Game.apply_patch("absorb")
	onehp_player.take_damage(onehp_player.global_position + Vector2(10, 0), "TASK2 ABSORB")
	h._check(onehp_player.hp == 1 and not onehp_player.dead and onehp_player.meter > 0.0, "absorption charge prevents hit and grants meter")
	onehp_player.queue_free()
	arena.player = saved_player
	await h._ticks(2)

	Game.mode = "classic"
	Game.patch_levels = {}
	for e in arena.enemy_list.duplicate():
		if is_instance_valid(e) and not e.is_in_group("boss"):
			e.queue_free()
	await h._ticks(2)
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
	await h._ticks(2)
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
	h._check(int(Game.stats["kills"]) == kills_before + 1 and int(Game.stats["boss_kills"]) == boss_kills_before + 1, "repeated boss death signals add one kill and one boss reward")
	h._check(Game.score == score_before + expected_boss_score, "repeated boss death signals add one boss score (%d -> %d, expected %d)" % [score_before, Game.score, score_before + expected_boss_score])
	h._check(int(Game.stats["heals"].get("boss", 0)) == boss_heals_before + 1, "repeated boss death signals add one boss heal")
	await h._ticks(3)
	await h._ticks(35)
	arena.spawner.stop()
	var phase_enemies_left := 0
	for e in arena.enemy_list:
		if is_instance_valid(e) and not e.is_in_group("boss"):
			phase_enemies_left += 1
	h._check(phase_enemies_left == 0, "boss reward clears remaining phase enemies")
	h._check(phase_died == 0, "boss cleanup does not emit phase enemy deaths")
	h._check(h.get_tree().get_nodes_in_group("boss_summon").is_empty(), "boss cleanup does not leave phase summons")
	h._check(arena.spawner._pending == 0 and arena.spawner._queue.is_empty() and not arena.spawner._awaiting_boss and arena.spawner._boss == null, "boss cleanup cancels pending spawner callbacks")
	h._check(arena._patch_pending == patch_pending_before and arena._patch_open == patch_open_before, "boss death does not queue a duplicate patch reward")

	Game.mode = saved_mode
	Game.patch_levels = saved_patch_levels
	arena.player.hp = boss_player_hp_before
	for e in arena.enemy_list.duplicate():
		if is_instance_valid(e) and not e.is_in_group("boss"):
			e.queue_free()
	if is_instance_valid(phase_boss):
		phase_boss.queue_free()
	await h._ticks(2)

func _task5_test(arena: Arena) -> void:
	print("AT_STEP task5")
	var balance_script: Script = load("res://src/autoload/balance.gd")
	var cadence_ready := balance_script != null and balance_script.has_method("attack_cadence_factor")
	h._check(cadence_ready, "wave attack cadence helper exists")
	if cadence_ready:
		h._check(absf(float(balance_script.call("attack_cadence_factor", 1)) - 1.0) < 0.001, "wave 1 cadence is unchanged")
		h._check(absf(float(balance_script.call("attack_cadence_factor", 5)) - 1.0) < 0.001, "wave 5 cadence is unchanged")
		h._check(absf(float(balance_script.call("attack_cadence_factor", 6)) - 0.985) < 0.001, "wave 6 cadence tightens slightly")
		h._check(absf(float(balance_script.call("attack_cadence_factor", 30)) - 0.78) < 0.001, "wave 30 cadence respects floor")
	h._check(Balance.max_alive(1) == 8, "wave 1 alive ceiling preserves ramp")
	h._check(Balance.max_alive(2) == 10, "wave 2 alive ceiling preserves ramp")
	h._check(Balance.max_alive(30) == 10, "late wave alive ceiling is 10")

	var threat_probe := EnemyBase.new()
	var threat_context_ready := arena.spawner.has_method("_configure_enemy")
	h._check(threat_context_ready, "spawner exposes threat wave configuration")
	if threat_context_ready:
		arena.spawner.wave = 30
		arena.spawner.call("_configure_enemy", threat_probe, false)
	h._check(threat_probe.get("threat_wave") == 30, "enemy threat wave context exists")
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
	h._check(elite_profiles_ready, "elite profile hooks exist")
	if elite_profiles_ready:
		var swift_dir: Vector2 = swift.call("elite_steering", Vector2.RIGHT, 1.0)
		var volatile_dir: Vector2 = volatile.call("elite_steering", Vector2.RIGHT, 1.0)
		h._check(absf(swift_dir.y) > absf(volatile_dir.y) + 0.1, "swift elite adds lateral steering")
		h._check(float(swift.call("elite_reacquire_interval", 1.0)) < 1.0, "swift elite reacquires on a bounded shorter interval")
		h._check(int(volatile.call("volatile_burst_count")) == 6, "volatile elite keeps six-orb death burst")
	swift.free()
	volatile.free()

	var lancer := LancerEnemy.new()
	var spewer := SpewerEnemy.new()
	if lancer.get("threat_wave") != null:
		lancer.set("threat_wave", 30)
	if spewer.get("threat_wave") != null:
		spewer.set("threat_wave", 30)
	var cadence_hooks_ready := lancer.has_method("phase_reentry_interval") and spewer.has_method("repeated_fire_interval")
	h._check(cadence_hooks_ready, "lancer and spewer expose repeated cadence hooks")
	if cadence_hooks_ready:
		h._check(float(lancer.call("phase_reentry_interval", 1.0)) < 1.0, "lancer repeated phase interval scales with wave")
		h._check(float(spewer.call("repeated_fire_interval", 2.0)) < 2.0, "spewer repeated fire interval scales with wave")
	h._check(lancer.has_method("telegraph_duration") and spewer.has_method("telegraph_duration"), "lancer and spewer preserve telegraph hooks")
	if lancer.has_method("telegraph_duration") and spewer.has_method("telegraph_duration"):
		h._check(float(lancer.call("telegraph_duration")) >= 0.5, "lancer telegraph stays readable")
		h._check(float(spewer.call("telegraph_duration")) >= 0.4, "spewer telegraph stays readable")
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
	h._check(root.has_method("hover_direction") and ranged.has_method("hover_direction"), "boss distance profiles exist")
	if root.has_method("hover_direction") and ranged.has_method("hover_direction"):
		h._check(root.call("hover_direction", Vector2(-220, 0)).dot(Vector2.LEFT) > 0.9, "melee ROOT approaches the player")
		h._check(ranged.call("hover_direction", Vector2(-80, 0)).dot(Vector2.RIGHT) > 0.0, "ranged boss retreats from close player")
	var corruption_script: Script = load("res://src/enemies/corruption_shot.gd")
	h._check(corruption_script != null, "corruption shot script loads")
	if corruption_script != null:
		arena.enemy_container.add_child(ranged)
		await h._ticks(1)
		ranged._corruption_volley(1)
		await h._ticks(1)
		var boss_shots := h.get_tree().get_nodes_in_group("corruption_shots")
		var ranged_target := ranged.player.global_position if ranged.player != null and is_instance_valid(ranged.player) else Vector2.INF
		h._check(boss_shots.size() == 1, "SEGFAULT corruption volley spawns one shot")
		if boss_shots.size() == 1:
			h._check(boss_shots[0].get("target_point").distance_to(ranged_target) < 0.1, "SEGFAULT corruption shot targets the player position")
		for boss_shot in boss_shots:
			if is_instance_valid(boss_shot):
				boss_shot.queue_free()
		await h._until(func() -> bool:
			return h.get_tree().get_nodes_in_group("corruption_shots").is_empty()
		, 1.0, "boss corruption shot cleanup")
		if is_instance_valid(ranged):
			ranged.queue_free()
		await h._ticks(1)
		var impact_player := Player.new()
		impact_player.position = Vector2(80, 0)
		arena.add_child(impact_player)
		await h._ticks(1)
		impact_player.invuln = 0.0
		impact_player.hp = impact_player.max_hp
		var impact_shot: Node = corruption_script.new()
		impact_shot.setup_corruption(Vector2(300, 0), impact_player.global_position, 1, Balance.COL_DANGER)
		arena.enemy_container.add_child(impact_shot)
		var impact_hp_before := impact_player.hp
		var impact_ok: bool = await h._until(func() -> bool:
			return impact_player.hp < impact_hp_before
		, 1.0, "corruption shot direct impact")
		h._check(impact_ok and impact_player.hp == impact_hp_before - 1, "intercepted corruption shot damages a real player before midpoint")
		h._check(h.get_tree().get_nodes_in_group("corruption").is_empty(), "direct corruption impact creates no zone")
		impact_player.position = Vector2(0, 200)
		var shot: Node = corruption_script.new()
		shot.setup_corruption(Vector2(300, 0), arena.player.global_position, 1, Balance.COL_DANGER, Vector2.RIGHT)
		arena.enemy_container.add_child(shot)
		var shot_origin = shot.get("origin_point")
		var shot_target = shot.get("target_point")
		h._check(float(shot.get("midpoint_distance")) > 0.0, "corruption shot tracks midpoint")
		h._check(shot.has_method("pop") and shot.has_method("burst_into_zone"), "corruption shot has direct and missed paths")
		if shot.has_method("pop") and shot.has_method("burst_into_zone"):
			shot._physics_process(0.1)
			h._check(float(shot.get("travelled")) > 0.0 and float(shot.get("travelled")) < float(shot.get("midpoint_distance")), "corruption shot travels before midpoint")
			shot._physics_process(0.6)
			await h._ticks(1)
			h._check(h.get_tree().get_nodes_in_group("corruption").size() > 0, "missed corruption shot creates a bounded zone")
			if not h.get_tree().get_nodes_in_group("corruption").is_empty():
				var zone: Node2D = h.get_tree().get_nodes_in_group("corruption")[0]
				h._check(float(zone.get("radius")) <= 38.0, "missed corruption zone stays bounded")
				h._check(shot_origin != null and shot_target != null and zone.global_position.distance_to((shot_origin + shot_target) * 0.5) < 0.1, "missed corruption zone uses real target midpoint")
			if is_instance_valid(shot):
				shot.queue_free()
			for zone in h.get_tree().get_nodes_in_group("corruption"):
				if is_instance_valid(zone):
					zone.queue_free()
			await h._ticks(1)
		impact_player.queue_free()
	root.free()
	if is_instance_valid(ranged):
		ranged.queue_free()
	boss_player.free()
	for zone in h.get_tree().get_nodes_in_group("corruption"):
		if is_instance_valid(zone):
			zone.queue_free()

	var oom: OomKiller = arena.spawner._make_enemy("oom")
	oom.position = Vector2(Balance.arena_rect().end.x - oom.radius, 0.0)
	arena.enemy_container.add_child(oom)
	await h._ticks(1)
	var mote_idx := arena.mote_field.spawn(oom.global_position)
	oom._steal(mote_idx)
	oom.st = OomKiller.St.FLEE
	oom._physics_process(0.1)
	h._check(oom.carried_ids.is_empty() and oom.is_queued_for_deletion(), "OOM_KILLER escapes fully at clamped arena edge")
	if is_instance_valid(oom):
		oom.queue_free()
	await h._ticks(2)

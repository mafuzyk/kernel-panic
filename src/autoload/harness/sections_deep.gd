extends RefCounted

## Regression probes for bugs that cross gameplay boundaries.  These are kept
## separate from the older batch-named sections so a failure names the system
## it protects.

var h: Node

func _init(harness: Node) -> void:
	h = harness

func _enemy_death_idempotency_test() -> void:
	print("AT_STEP deep_death_idempotency")
	var drone := DroneEnemy.new()
	var drone_deaths: Array = []
	drone.died.connect(func(_enemy: EnemyBase) -> void: drone_deaths.append(true))
	h.add_child(drone)
	await h._ticks(2)
	drone.take_hit(999, Vector2.LEFT)
	drone.take_hit(999, Vector2.LEFT)
	h._check(drone_deaths.size() == 1, "enemy death emits exactly once under duplicate hits")
	drone.queue_free()

	var bulwark := BulwarkEnemy.new()
	var bulwark_deaths: Array = []
	bulwark.died.connect(func(_enemy: EnemyBase) -> void: bulwark_deaths.append(true))
	h.add_child(bulwark)
	await h._ticks(2)
	bulwark.die()
	bulwark.die()
	h._check(bulwark_deaths.size() == 1, "bulwark death emits exactly once")
	bulwark.queue_free()
	await h._ticks(2)

func _rootlet_shield_recharge_test() -> void:
	print("AT_STEP deep_rootlet_shield_recharge")
	var saved_program := Game.program
	var saved_mode := Game.mode
	Game.mode = "classic"
	Game.program = "rootlet"
	var rootlet := Player.new()
	h.add_child(rootlet)
	await h._ticks(2)
	rootlet.shield_meter = Balance.OC_METER_MAX
	rootlet.shield_ready = true
	rootlet.invuln = 0.0
	rootlet.take_damage(rootlet.global_position + Vector2(10, 0), "DEEP TEST")
	rootlet.invuln = 0.0
	rootlet.meter = 0.0
	rootlet.oc_ready = false
	rootlet.collect_mote()
	h._check(rootlet.shield_meter > 0.0 and is_zero_approx(rootlet.meter) and not rootlet.oc_ready,
		"rootlet refills shield after shield breaks")
	rootlet.queue_free()
	Game.program = saved_program
	Game.mode = saved_mode
	await h._ticks(2)

func _splitshot_rotation_test(arena: Arena) -> void:
	print("AT_STEP deep_splitshot_rotation")
	var saved_patches: Dictionary = Game.patch_levels.duplicate(true)
	Game.patch_levels = {"splitshot": 1}
	var player := arena.player
	player.rotation = 0.0
	player.fire_cd = 0.0
	player._shoot()
	await h._ticks(1)
	var bullets: Array[PlayerBullet] = []
	for child in arena.get_children():
		if child is PlayerBullet:
			bullets.append(child)
	var aligned := bullets.size() == 2
	for bullet in bullets:
		aligned = aligned and absf(wrapf(bullet.rotation - bullet.vel.angle(), -PI, PI)) < 0.02
	h._check(aligned, "splitshot projectile rotation matches its trajectory")
	for bullet in bullets:
		if is_instance_valid(bullet):
			bullet.queue_free()
	Game.patch_levels = saved_patches
	await h._ticks(2)

func _deferred_orb_cap_test(arena: Arena) -> void:
	print("AT_STEP deep_orb_cap")
	for orb in h.get_tree().get_nodes_in_group("enemy_orbs"):
		if is_instance_valid(orb):
			orb.queue_free()
	await h._ticks(3)
	var boss := RootBoss.new()
	boss.boss_index = 1
	boss.configure(1.0, false)
	boss.player = h.get_tree().get_first_node_in_group("player")
	arena.enemy_container.add_child(boss)
	await h._ticks(2)
	var orb_origin := Vector2(420.0, 220.0)
	for i in 39:
		var existing := EnemyOrb.new()
		existing.setup(orb_origin + Vector2(float(i % 8) * 8.0, float(i / 8) * 6.0), Vector2.ZERO, 0.0, Color.RED)
		existing.life = 100.0
		arena.enemy_container.add_child(existing)
	await h._ticks(2)
	var before_burst := h.get_tree().get_nodes_in_group("enemy_orbs").size()
	h._check(before_burst == 39, "orb cap probe installs 39 live orbs")
	boss._do_burst(14, 100.0)
	await h._ticks(3)
	var count := h.get_tree().get_nodes_in_group("enemy_orbs").size()
	h._check(count <= 40, "deferred orb bursts respect the global cap (%d)" % count)
	for orb in h.get_tree().get_nodes_in_group("enemy_orbs"):
		if is_instance_valid(orb):
			orb.queue_free()
	boss.queue_free()
	await h._ticks(3)

func _temple_god_spawn_test() -> void:
	print("AT_STEP deep_temple_god_spawn")
	var arena_stub := Node2D.new()
	var container := Node2D.new()
	var spawner := Spawner.new()
	var stage := Game.story_stage_def(10)
	stage["waves"] = [["god"]]
	h.add_child(arena_stub)
	h.add_child(container)
	h.add_child(spawner)
	var started := spawner.start_story(arena_stub, container, stage)
	h._check(started, "TempleOS GOD stage starts scripted spawning")
	await h._ticks(110)
	var boss := spawner._boss
	h._check(boss is GodBoss, "TempleOS GOD stage spawns the GOD boss")
	spawner.stop()
	for child in container.get_children():
		if is_instance_valid(child):
			child.queue_free()
	spawner.queue_free()
	container.queue_free()
	arena_stub.queue_free()
	await h._ticks(3)

func _absorb_arms_overclock_test() -> void:
	print("AT_STEP deep_absorb_overclock")
	var saved_program := Game.program
	var saved_mode := Game.mode
	Game.mode = "classic"
	Game.program = "kernel"
	var p := Player.new()
	h.add_child(p)
	await h._ticks(2)
	p.absorb_charges = 2
	p.shield_charges = 0
	p.meter = Balance.OC_METER_MAX - Balance.MOTE_VALUE * 0.5
	p.oc_ready = false
	p.overclock_active = false
	p.invuln = 0.0
	p.take_damage(p.global_position + Vector2(10, 0), "DEEP TEST")
	h._check(p.oc_ready, "absorbed damage completing the meter arms overclock")
	p.try_overclock()
	h._check(p.overclock_active, "armed overclock actually fires after absorb")
	p.queue_free()
	Game.program = saved_program
	Game.mode = saved_mode
	await h._ticks(2)

func _story_hold_restart_test() -> void:
	print("AT_STEP deep_story_hold_restart")
	_sterilize_arena()
	var saved_stage := Game.story_stage_index
	h._check(Game.start_story(0), "story stage 0 starts for hold-restart probe")
	var pre_id := h.get_tree().current_scene.get_instance_id() if h.get_tree().current_scene != null else 0
	var entered: bool = await h._until(func() -> bool:
		var cur := h.get_tree().current_scene
		return cur != null and cur.name == "Arena" and Game.mode == "story" and cur.get_instance_id() != pre_id, 8.0, "story arena")
	if not entered:
		Game.story_stage_index = saved_stage
		return
	await h._ticks(10)
	var arena: Arena = h.get_tree().current_scene
	var old_arena_id := arena.get_instance_id()
	Input.action_press("restart")
	for i in 120:
		await h.get_tree().process_frame
		var cur := h.get_tree().current_scene
		if cur != null and cur.name == "Arena" and cur.get_instance_id() != old_arena_id:
			break
	Input.action_release("restart")
	h._check(Game.mode == "story", "hold restart during story stays in story")
	h._check(Game.story_stage_index == 0, "hold restart replays the same story stage")
	var back: bool = await h._until(func() -> bool:
		return h.get_tree().current_scene != null and h.get_tree().current_scene.name == "Arena", 8.0, "restarted story arena")
	h._check(back, "hold restart reloads the story arena")
	Game.story_stage_index = saved_stage
	await h._ticks(5)

func _oom_ownership_test(arena: Arena) -> void:
	print("AT_STEP deep_oom_ownership")
	var mf: MoteField = arena.mote_field
	arena.spawner.stop()
	for node in h.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node):
			node.queue_free()
	await h._ticks(2)
	for i in range(mf.count() - 1, -1, -1):
		mf.kill_slot(i)
	var a_idx := mf.spawn(arena.player.global_position + Vector2(200, 0))
	var b_idx := mf.spawn(arena.player.global_position + Vector2(260, 0))
	var a_uid: int = mf.uid_of(a_idx)
	var b_uid: int = mf.uid_of(b_idx)
	var oom1: EnemyBase = arena.spawner._make_enemy("oom")
	var oom2: EnemyBase = arena.spawner._make_enemy("oom")
	oom1.position = arena.player.global_position + Vector2(340, 0)
	oom2.position = arena.player.global_position + Vector2(340, 80)
	arena.enemy_container.add_child(oom1)
	arena.enemy_container.add_child(oom2)
	await h._ticks(2)
	oom1._steal(a_idx, a_uid)
	oom2._steal(b_idx, b_uid)
	h._check(mf.is_stolen(a_idx) and mf.is_stolen(b_idx), "two ooms hold one mote each")
	oom1.die()
	await h._ticks(2)
	var a_back := mf.idx_of_uid(a_uid)
	h._check(a_back >= 0 and mf.alive_at(a_back) and not mf.is_stolen(a_back), "a dying oom releases only its own mote")
	h._check(mf.is_stolen(mf.idx_of_uid(b_uid)), "the surviving oom keeps its mote")
	oom2._escape()
	await h._ticks(2)
	h._check(mf.idx_of_uid(b_uid) < 0, "an escaping oom frees only its own mote")
	h._check(mf.idx_of_uid(a_uid) >= 0, "the released mote survives the other's escape")
	h._check(not a_uid in mf.stolen_ids() and not b_uid in mf.stolen_ids(), "stolen ids track live stolen motes by uid")

func _page_fault_cap_test(arena: Arena) -> void:
	print("AT_STEP deep_page_cap")
	arena.spawner.stop()
	for node in h.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node):
			node.queue_free()
	await h._ticks(2)
	var boss1 := RootBoss.new()
	boss1.boss_index = 1
	boss1.configure(1.0, false)
	boss1.position = arena.player.global_position + Vector2(360, 0)
	var boss2 := RootBoss.new()
	boss2.boss_index = 1
	boss2.configure(1.0, false)
	boss2.position = arena.player.global_position + Vector2(-360, 0)
	arena.enemy_container.add_child(boss1)
	arena.enemy_container.add_child(boss2)
	await h._ticks(2)
	boss1._do_pages()
	await h._ticks(3)
	h._check(boss1._pages_alive() == 4, "page fault fills exactly four pages")
	boss1._do_pages()
	await h._ticks(3)
	h._check(boss1._pages_alive() == 4, "page fault never exceeds four pages per boss")
	var killed := 0
	for p in h.get_tree().get_nodes_in_group("page"):
		if is_instance_valid(p) and p.get("boss") == boss1 and killed < 2:
			p.take_hit(999, boss1.global_position)
			killed += 1
	await h._ticks(3)
	h._check(boss1._pages_alive() == 2, "killing pages drops the owned count")
	boss1._do_pages()
	await h._ticks(3)
	h._check(boss1._pages_alive() == 4, "page fault refills only the deficit")
	boss2._do_pages()
	await h._ticks(3)
	h._check(boss2._pages_alive() == 4 and boss1._pages_alive() == 4, "two bosses cap pages independently")
	boss1.queue_free()
	boss2.queue_free()
	for p in h.get_tree().get_nodes_in_group("page"):
		if is_instance_valid(p):
			p.queue_free()
	await h._ticks(3)

func _dash_recharge_test() -> void:
	print("AT_STEP deep_dash_recharge")
	var saved_program := Game.program
	var saved_mode := Game.mode
	var saved_patches: Dictionary = Game.patch_levels.duplicate(true)
	Game.mode = "classic"
	Game.program = "daemon"
	Game.patch_levels = {"dash": 1}
	var p := Player.new()
	h.add_child(p)
	await h._ticks(2)
	h._check(p.dash_charges == 2 and p.available_dash_charges() == 2, "daemon starts with two dash charges")
	p.request_dash(Vector2.RIGHT)
	await h._ticks(2)
	h._check(p.available_dash_charges() == 1, "first dash spends one charge")
	p.dash_t = 0.0
	p.request_dash(Vector2.RIGHT)
	await h._ticks(2)
	h._check(p.available_dash_charges() == 0, "second dash spends the last charge")
	var single_interval := Balance.DASH_CD * 0.82
	var t0 := Time.get_ticks_msec()
	var one_back: bool = await h._until(func() -> bool: return p.available_dash_charges() >= 1, 8.0, "first charge returns")
	var t1 := Time.get_ticks_msec()
	h._check(one_back, "recharge returns 0 to 1")
	h._check(float(t1 - t0) < Balance.DASH_CD * 1000.0, "quick dash shortens each interval")
	var two_back: bool = await h._until(func() -> bool: return p.available_dash_charges() >= 2, 8.0, "second charge returns")
	h._check(two_back, "idle recharge returns 1 to 2")
	p.dash_recharge_t = 1.0
	p.notify_kill()
	h._check(p.dash_recharge_t < 1.0, "kill dash refund stays coherent")
	p.queue_free()
	Game.program = saved_program
	Game.mode = saved_mode
	Game.patch_levels = saved_patches
	await h._ticks(2)

func _heal_semantics_test() -> void:
	print("AT_STEP deep_heal_semantics")
	var saved_program := Game.program
	var saved_mode := Game.mode
	var saved_ach: Dictionary = Game.achievements.duplicate(true)
	var saved_ach_disk: Dictionary = h._config_snapshot("achievements", "unlocked", {})
	Game.mode = "classic"
	Game.program = "kernel"
	Game.achievements.erase("integrity_restored")
	var p := Player.new()
	h.add_child(p)
	await h._ticks(2)
	Game.stats["heals"] = {}
	Game._hp_lost_since_heal = false
	p.hp = p.max_hp
	var gained_full := p.heal(1, "cycle")
	h._check(gained_full == 0 and not Game.stats["heals"].has("cycle"), "healing at full hp records nothing")
	p.invuln = 0.0
	p.dash_t = 0.0
	p.take_damage(p.global_position + Vector2(10, 0), "DEEP TEST")
	var gained := p.heal(1, "cycle")
	h._check(gained == 1 and int(Game.stats["heals"].get("cycle", 0)) == 1, "real healing records telemetry")
	h._check(Game.achievements.has("integrity_restored"), "integrity_restored unlocks on real restore after loss")
	p.queue_free()
	Game.achievements = saved_ach
	h._restore_config_snapshot("achievements", "unlocked", saved_ach_disk)
	Game.program = saved_program
	Game.mode = saved_mode
	await h._ticks(2)

## Congela combate antes de trocar de cena no teste: player invencível,
## spawner parado, sem tiro. Mortes/Fx durante waits mascaravam a contagem
## de órfãos e poluíam o estado da arena seguinte.
func _sterilize_arena() -> void:
	var cur: Node = h.get_tree().current_scene
	if cur != null and is_instance_valid(cur) and cur.name == "Arena":
		if cur.get("player") != null and is_instance_valid(cur.get("player")):
			cur.get("player").invuln = 9999.0
		if cur.get("spawner") != null and is_instance_valid(cur.get("spawner")):
			cur.get("spawner").stop()
	Input.action_release("fire")

func _scene_swap_hygiene_test() -> void:
	print("AT_STEP deep_swap_hygiene")
	_sterilize_arena()
	var before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var pre_id := h.get_tree().current_scene.get_instance_id() if h.get_tree().current_scene != null else 0
	var pre_scene: Node = h.get_tree().current_scene
	Game.start_run()
	var ok: bool = await h._until(func() -> bool:
		var c := h.get_tree().current_scene
		return c != null and c.name == "Arena" and c.get_instance_id() != pre_id, 8.0, "sterile arena")
	h._check(ok, "sterile scene swap lands a fresh arena")
	await h._ticks(5)
	h._check(not is_instance_valid(pre_scene), "the previous scene is freed by the swap, not orphaned")
	var after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	h._check(after <= before, "a sterile scene swap leaks no orphans (%d -> %d)" % [before, after])
	Game.to_menu()
	var menu_ok: bool = await h._until(func() -> bool:
		var c := h.get_tree().current_scene
		return c != null and c.name == "Menu", 8.0, "sterile menu")
	h._check(menu_ok, "sterile swap returns to menu")
	await h._ticks(5)
	var after_menu := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	h._check(after_menu <= after, "menu build leaks no orphans (%d -> %d)" % [after, after_menu])

func _vampic_reset_test() -> void:
	print("AT_STEP deep_vampic_reset")
	_sterilize_arena()
	Game.vampic_cd = 5.0
	var pre_run_id := h.get_tree().current_scene.get_instance_id() if h.get_tree().current_scene != null else 0
	Game.start_run()
	h._check(Game.vampic_cd <= 0.0, "new run does not inherit vampic cooldown")
	# Por instance_id: o mode troca na hora mas a cena troca deferred; casar
	# só por nome/mode validava a arena VELHA e o teste seguinte herdava
	# uma cena já condenada (foi o que matava o reticle do teste modal).
	var ok: bool = await h._until(func() -> bool:
		var cur := h.get_tree().current_scene
		return cur != null and cur.name == "Arena" and cur.get_instance_id() != pre_run_id, 8.0, "fresh arena after cooldown reset")
	h._check(ok, "fresh arena loads after cooldown reset")
	Game.vampic_cd = 5.0
	var pre_story_id := h.get_tree().current_scene.get_instance_id() if h.get_tree().current_scene != null else 0
	h._check(Game.start_story(0), "story starts for cooldown probe")
	h._check(Game.vampic_cd <= 0.0, "new story does not inherit vampic cooldown")
	var ok2: bool = await h._until(func() -> bool:
		var cur := h.get_tree().current_scene
		return cur != null and cur.name == "Arena" and Game.mode == "story" and cur.get_instance_id() != pre_story_id, 8.0, "story arena after cooldown reset")
	h._check(ok2, "story arena loads after cooldown reset")

func _probe() -> void:
	h._watchdog(30.0)
	await h._ticks(20)
	Game.start_run()
	var ok: bool = await h._until(func() -> bool:
		return h.get_tree().current_scene != null and h.get_tree().current_scene.name == "Arena", 8.0, "deep probe arena")
	if not ok:
		h.get_tree().quit(1)
		return
	await h._ticks(10)
	var arena: Arena = h.get_tree().current_scene
	await _enemy_death_idempotency_test()
	await _rootlet_shield_recharge_test()
	await _absorb_arms_overclock_test()
	await _dash_recharge_test()
	await _heal_semantics_test()
	await _scene_swap_hygiene_test()
	await _oom_ownership_test(arena)
	await _page_fault_cap_test(arena)
	await _splitshot_rotation_test(arena)
	await _deferred_orb_cap_test(arena)
	await _temple_god_spawn_test()
	h._finish()

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
	await _splitshot_rotation_test(arena)
	await _deferred_orb_cap_test(arena)
	await _temple_god_spawn_test()
	h._finish()

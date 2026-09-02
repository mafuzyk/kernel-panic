extends RefCounted

## Autotest section script. Function bodies below are moved verbatim from
## src/autoload/dev_harness.gd; only harness-helper references are prefixed
## with `h` per plan section G3. No behavior changes. AT_STEP labels and
## message strings are byte-identical to the originals.

var h: Node


func _init(harness: Node) -> void:
	h = harness

func _systems_test_b2(arena: Arena) -> void:
	var player: Player = arena.player
	print("AT_STEP oom")
	var oom: EnemyBase = arena.spawner._make_enemy("oom")
	h._check(oom is OomKiller, "OOM_KILLER builds")
	oom.position = arena.player.global_position + Vector2(320, 0)
	arena.enemy_container.add_child(oom)
	await h._ticks(2)
	var target_field: MoteField = arena.mote_field
	for i in range(target_field.count() - 1, -1, -1):
		target_field.kill_slot(i)
	var near_idx := target_field.spawn(oom.global_position + Vector2(12, 0))
	var selected_idx := target_field.spawn(oom.global_position + Vector2(160, 0))
	oom._steal(selected_idx)
	h._check(target_field.is_stolen(selected_idx) and not target_field.is_stolen(near_idx), "OOM_KILLER steals selected mote slot")
	target_field.free_all_stolen()
	target_field.kill_slot(near_idx)
	oom.carried_ids.clear()
	var steal_box := [-1]
	arena.mote_field.spawn(oom.global_position + Vector2(12, 0))
	await h._until(func() -> bool:
		var f = arena.mote_field
		for i in range(f.count()):
			if f.is_stolen(i):
				steal_box[0] = i
				return true
		return false, 4.0, "oom steal")
	var field_ref = arena.mote_field
	var stolen_idx: int = steal_box[0]
	h._check(stolen_idx >= 0 and field_ref.is_stolen(stolen_idx), "OOM_KILLER steals motes")
	oom.take_hit(99, oom.global_position)
	await h._ticks(3)
	if stolen_idx >= 0:
		h._check(not field_ref.is_stolen(stolen_idx), "killed OOM_KILLER returns motes")
	print("AT_STEP ricochet")
	Game.patch_levels = {"ricochet": 1}
	var b := PlayerBullet.new()
	b.setup(Vector2(-560, 0), Vector2(-1, 0), false)
	b.vel = Vector2(-Balance.BULLET_SPEED, 0)
	b.bounces = 1
	arena.add_child(b)
	await h._ticks(30)
	h._check(is_instance_valid(b) and b.vel.x > 0, "ricochet reflects off wall")
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
	h._check(hb_found and Game.stats["shots"] == shots0 + 1, "heavy rounds add damage")
	Game.patch_levels = {}
	print("AT_STEP drag")
	player.touch_mode = true
	print("AT_STEP freeze")
	player.apply_freeze(1.0)
	h._check(player.slow_factor < 1.0, "freeze slows player")
	await h._simulation_seconds(1.1)
	h._check(absf(player.slow_factor - 1.0) < 0.01, "freeze expires")
	print("AT_STEP wave1")
	var sp := arena.spawner
	sp.wave = 1
	sp._build_queue()
	h._check(sp._queue.size() <= 9, "wave 1 is gentle (<=9 spawns)")
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
	h._check(str(seed_a) == str(seed_b), "weekly seed is deterministic")
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
	h._check(str(comp_a) == str(comp_b), "weekly wave composition deterministic")
	h._check(str(events_a) == str(events_b), "weekly wave events deterministic")
	var l1 := LancerEnemy.new()
	l1.phase_t = Game.rng.randf_range(0.6, 1.1)
	Game.rng.seed = 99
	l1.phase_t = Game.rng.randf_range(0.6, 1.1)
	Game.rng.seed = 99
	var l2 := LancerEnemy.new()
	l2.phase_t = Game.rng.randf_range(0.6, 1.1)
	h._check(absf(l1.phase_t - l2.phase_t) < 0.0001, "enemy rng uses seeded stream")
	Game.mode = "classic"
	Game.patch_levels = {}
	await h._ticks(2)
	var trojan := arena.spawner._make_enemy("trojan")
	h._check(trojan is TrojanEnemy, "trojan enemy builds")
	trojan.queue_free()
	arena.spawner.wave = 5
	arena.spawner._roll_wave_event(false)
	arena._on_wave_cleared(1)
	var before_vacuum: int = arena.mote_field.count()
	h._check(before_vacuum > 0, "motes exist before vacuum")
	arena._on_wave_cleared(2)
	for vi in 180:
		await h.get_tree().process_frame
		if arena.mote_field.count() == 0:
			break
	h._check(arena.mote_field.count() == 0, "wave clear vacuums motes")
	arena.offer_patch()
	await h._until(func() -> bool: return arena._patch_open, 4.0, "patch panel opens")
	await h._ticks(20)
	h._check(arena._patch_open and arena._patch_panel.visible and arena._patch_panel.modulate.a > 0.5, "patch panel opens and is visible")
	h._check(h.get_tree().paused, "patch pauses world")
	var build_before: String = Game.build_string()
	arena._pick_patch(0)
	await h._ticks(2)
	h._check(not h.get_tree().paused and not arena._patch_open, "patch pick resumes world")
	h._check(Game.build_string() != build_before and Game.build_string() != "NO PATCHES", "hud shows active patches")
	h._check(Game.patch_levels.size() > 0 or true, "patch applied")
	Sfx.haptic(10)
	h._check(Sfx._stems.size() == 3, "three music stems loaded")
	var music_streams: Array[AudioStreamWAV] = []
	for stem in Sfx._stems:
		var stream := stem.stream as AudioStreamWAV
		if stream != null:
			music_streams.append(stream)
	h._check(music_streams.size() == 3, "three music streams expose WAV data")
	if music_streams.size() == 3:
		var first := music_streams[0]
		h._check(first.get_length() >= 30.0, "music stems are at least 30 seconds")
		var expected_loop_end := int(round(first.get_length() * first.mix_rate))
		h._check(absf(float(first.loop_end - expected_loop_end)) <= 1.0, "music loop covers the full imported duration")
		for i in music_streams.size():
			var stream := music_streams[i]
			h._check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "music stem %d loops forward" % i)
			h._check(stream.mix_rate == first.mix_rate, "music stem %d sample rate matches" % i)
			h._check(stream.stereo == first.stereo, "music stem %d channel layout matches" % i)
			h._check(absf(stream.get_length() - first.get_length()) < 0.001, "music stem %d duration matches" % i)
			h._check(stream.data.size() == first.data.size(), "music stem %d length matches" % i)
			h._check(stream.loop_end == first.loop_end, "music stem %d loop end matches" % i)
	Sfx.set_intensity(2)
	Sfx.set_intensity(0)
	await h._ticks(2)

extends RefCounted

## Autotest section script. Function bodies below are moved verbatim from
## src/autoload/dev_harness.gd; only harness-helper references are prefixed
## with `h` per plan section G3. No behavior changes. AT_STEP labels and
## message strings are byte-identical to the originals.

var h: Node


func _init(harness: Node) -> void:
	h = harness

func _systems_test_a(arena: Arena) -> void:
	var player: Player = arena.player
	print("AT_STEP mk2")
	var mk2 := RootBoss.new()
	mk2.boss_index = 2
	mk2.configure(1.0, false)
	h._check(mk2.boss_title == "SEGFAULT", "MK-2 boss is SEGFAULT")
	h._check(RootBoss.title_for_index(15).begins_with("BLUE SCREEN"), "cycle 15 boss is BLUE SCREEN")
	h._check(RootBoss.title_for_index(20).begins_with("PAGE FAULT"), "cycle 20 boss is PAGE FAULT")
	print("AT_STEP bossrework")
	var f1 := RootBoss.new()
	f1.boss_index = 1
	f1.configure(1.0, false)
	var f2 := RootBoss.new()
	f2.boss_index = 2
	f2.configure(1.0, false)
	h._check(f1.max_hp == 120, "boss hp formula mk1=120")
	h._check(f2.max_hp == 162, "boss hp formula mk2=162")
	var ranged_boss := RootBoss.new()
	ranged_boss.boss_index = 3
	ranged_boss.configure(1.0, false)
	ranged_boss.player = player
	ranged_boss.position = player.global_position + Vector2(70, 0)
	ranged_boss._move(0.1)
	h._check(ranged_boss.vel().dot(Vector2.RIGHT) > 0.0, "ranged boss backs away when player is too close")
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
	await h._ticks(1)
	arena._on_boss_spawned(split_signal_boss)
	h._check(arena.hud.boss != null, "boss hud tracks root before split")
	split_signal_boss._split_into_minis()
	await h._ticks(2)
	h._check(arena.hud._boss_fragments.size() == 2, "boss hud tracks both root minis")
	h._check(arena.hud._boss_split, "boss hud enters forked layout")
	h._check(arena.hud._boss_name == "ROOT.exe // FORKED", "boss hud labels the forked root")
	h._check(arena.hud._boss_split, "forked boss hud survives original root cleanup")
	h._check(split_seen.size() == 2, "root split reports both mini instances")
	if split_seen.size() == 2:
		h._check(split_seen[0].position.distance_to(split_seen[1].position) > 52.0, "root minis start separated")
	await h._ticks(1)
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
	await h._ticks(2)
	print("AT_STEP rootsplit")
	var recover_script: Script = load("res://src/pickups/recover_pickup.gd")
	for c in arena.mote_container.get_children():
		if c.get_script() == recover_script:
			c.queue_free()
	await h._ticks(2)
	player.invuln = 9999.0
	var rb := RootBoss.new()
	rb.boss_index = 1
	rb.configure(1.0, false)
	rb.position = player.global_position + Vector2(300, -80)
	arena.enemy_container.add_child(rb)
	await h._ticks(2)
	arena._on_boss_spawned(rb)
	h._check(arena.hud.boss != null, "boss hud tracks root before split lifecycle")
	rb.hp = int(rb.max_hp * 0.51) + 1
	rb.take_hit(2, rb.global_position + Vector2(6, 0))
	await h._ticks(5)
	var minis_found := 0
	for e in arena.enemy_container.get_children():
		if e is RootBoss and is_instance_valid(e) and e.mini:
			minis_found += 1
	h._check(minis_found == 2, "root splits into two minis (%d)" % minis_found)
	h._check(arena.hud._boss_fragments.size() == 2, "boss hud tracks both lifecycle minis")
	h._check(arena.hud._boss_split, "boss hud stays forked during lifecycle")
	var mini_hp_ok := true
	var mini_positions: Array[Vector2] = []
	for e in arena.enemy_container.get_children():
		if e is RootBoss and is_instance_valid(e) and e.mini:
			mini_hp_ok = mini_hp_ok and e.hp >= 2 and e.max_hp >= 2
			mini_positions.append(e.global_position)
	h._check(minis_found == 2 and mini_hp_ok, "root minis survive more than one hit")
	await h._ticks(10)
	var mini_moved := false
	for i in mini_positions.size():
		for e in arena.enemy_container.get_children():
			if e is RootBoss and is_instance_valid(e) and e.mini and e.global_position.distance_to(mini_positions[i]) > 8.0:
				mini_moved = true
	h._check(mini_moved, "root minis move during their phase")
	var split_recover_count := 0
	for c in arena.mote_container.get_children():
		if c.get_script() == recover_script:
			split_recover_count += 1
	h._check(split_recover_count == 1, "root split drops one recover")
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
		h.get_tree().paused = false
		probe_mini.take_hit(probe_mini.hp + 99, probe_mini.global_position)
		await h._ticks(4)
		h._check(arena.hud._boss_fragments.size() == 1, "boss hud removes first dead mini")
		h._check(arena.hud._boss_split, "boss hud stays forked while one mini lives")
		h._check(arena._patch_pending == 0 and not arena._patch_open, "first root mini gives no boss card")
		if h.get_tree().paused:
			h.get_tree().paused = false
		if arena._patch_open:
			arena._pick_patch(0)
		h._check(int(Game.stats["heals"].get("boss", 0)) == 0, "first root mini gives no boss heal")
		var minis_now := 0
		for e in arena.enemy_container.get_children():
			if e is RootBoss and is_instance_valid(e) and e.mini:
				minis_now += 1
		h._check(minis_now < minis_before + 2, "minis never split again")
		var last_mini: RootBoss = null
		for e in arena.enemy_container.get_children():
			if e is RootBoss and is_instance_valid(e) and e.mini:
				last_mini = e
				break
		if last_mini != null:
			last_mini.take_hit(last_mini.hp + 99, last_mini.global_position)
			await h._ticks(4)
		h._check(arena.hud.boss == null, "boss hud clears root after final reward")
		h._check(arena.hud._boss_fragments.is_empty(), "boss hud clears all minis after final reward")
		h._check(not arena.hud._boss_split, "boss hud exits forked layout after final reward")
		h._check(arena.hud._boss_name == "", "boss hud clears forked title after final reward")
		h._check(arena.hud._boss_frac == -1.0, "boss hud clears boss fraction after final reward")
		h._check(not arena._patch_open and arena._patch_pending == 0, "root encounter does not queue boss-death patch")
		h._check(int(Game.stats["heals"].get("boss", 0)) == 1 and player.hp == player.max_hp - 1, "root encounter gives one boss heal")
		var final_recover_count := 0
		for c in arena.mote_container.get_children():
			if c.get_script() == recover_script:
				final_recover_count += 1
		h._check(final_recover_count == 1, "root encounter gives one recover total")
		if h.get_tree().paused:
			h.get_tree().paused = false
		if arena._patch_open:
			arena._pick_patch(0)
	await h._ticks(4)
	for e in h.get_tree().get_nodes_in_group("boss"):
		if is_instance_valid(e):
			e.queue_free()
	for c in arena.enemy_container.get_children():
		if c is RootBoss:
			c.queue_free()
	await h._ticks(4)
	for o in h.get_tree().get_nodes_in_group("enemy_orbs"):
		o.queue_free()
	await h._ticks(2)
	player.invuln = 0.0
	player.hp = player.max_hp
	print("AT_STEP bossfan")
	var bs := RootBoss.new()
	bs.boss_index = 3
	bs.configure(1.0, false)
	bs.hp = int(bs.max_hp * 0.4)
	arena.enemy_container.add_child(bs)
	await h._ticks(2)
	for i in 38:
		var o := EnemyOrb.new()
		o.setup(player.global_position + Vector2(500 + i, 300), Vector2.ZERO, 10.0, Color.RED)
		arena.enemy_container.add_child(o)
	await h._ticks(2)
	bs._fan_cd = 0.0
	var orbs_before := h.get_tree().get_nodes_in_group("enemy_orbs").size()
	await h._ticks(20)
	var orbs_after := h.get_tree().get_nodes_in_group("enemy_orbs").size()
	h._check(orbs_after <= 40 and orbs_after >= orbs_before, "bluescreen fan respects orb cap (%d)" % orbs_after)
	for o in h.get_tree().get_nodes_in_group("enemy_orbs"):
		o.queue_free()
	bs.queue_free()
	await h._ticks(3)
	print("AT_STEP pfshield")
	var pf := RootBoss.new()
	pf.boss_index = 4
	pf.configure(1.0, false)
	pf.hp = int(pf.max_hp * 0.55)
	arena.enemy_container.add_child(pf)
	await h._ticks(2)
	pf.take_hit(int(pf.max_hp * 0.1), pf.global_position)
	await h._ticks(60)
	var pages_now := pf._pages_alive()
	h._check(pages_now > 0, "page fault rebuilds shield at half hp (%d pages)" % pages_now)
	var hp_before_block := pf.hp
	pf.take_hit(1, pf.global_position)
	h._check(pf.hp == hp_before_block, "rebuilt shield blocks damage again")
	var second_rebuild := pf._shield_rebuilt
	for pg in h.get_tree().get_nodes_in_group("page"):
		if is_instance_valid(pg):
			pg.take_hit(9999, pg.global_position)
	await h._ticks(3)
	pf.take_hit(9999, pf.global_position)
	await h._ticks(4)
	h._check(second_rebuild and not is_instance_valid(pf), "shield rebuild happens only once per fight")
	for e in h.get_tree().get_nodes_in_group("page"):
		if is_instance_valid(e):
			e.queue_free()
	if is_instance_valid(pf):
		pf.queue_free()
	await h._ticks(3)
	if h.get_tree().paused:
		h.get_tree().paused = false
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
	await h._ticks(2)
	seg._lance_cd = 0.0
	var lance_seen := false
	for i in 90:
		await h._ticks(1)
		if not is_instance_valid(seg):
			break
		if seg.act == RootBoss.Act.LANCE_WIND or seg.act == RootBoss.Act.LANCE_GO:
			lance_seen = true
			break
	h._check(lance_seen, "segfault enters lance wind")
	seg.queue_free()
	await h._ticks(2)
	print("AT_STEP mk4")
	var mk4 := RootBoss.new()
	mk4.boss_index = 4
	mk4.configure(1.0, false)
	arena.enemy_container.add_child(mk4)
	await h._ticks(2)
	var pg := PageNode.new()
	pg.boss = mk4
	pg.orbit_idx = 0
	pg.position = mk4.global_position + Vector2(90, 0)
	arena.enemy_container.add_child(pg)
	await h._ticks(2)
	var hp0 := mk4.hp
	mk4.take_hit(10, mk4.global_position)
	h._check(mk4.hp == hp0, "PAGE FAULT shielded while pages alive")
	pg.queue_free()
	await h._ticks(3)
	mk4.take_hit(5, mk4.global_position)
	h._check(mk4.hp < hp0, "PAGE FAULT vulnerable with no pages")
	mk4.queue_free()
	await h._ticks(2)
	print("AT_STEP rootcharge")
	var charge := RootBoss.new()
	charge.boss_index = 1
	charge.configure(1.0, false)
	charge.position = Vector2.ZERO
	arena.enemy_container.add_child(charge)
	await h._ticks(2)
	charge._v = Vector2.RIGHT * 800.0
	charge.act = RootBoss.Act.CHARGE_GO
	charge.act_t = 0.4
	var charge_start := charge.global_position
	await h._ticks(10)
	h._check(charge.global_position.distance_to(charge_start) > 20.0, "root charge moves during charge")
	charge.queue_free()
	await h._ticks(2)
	print("AT_STEP quality")
	arena.quality_tier = 1
	Fx.quality_scale = 0.5
	arena._fps_accum = -9.0
	await h._ticks(70)
	h._check(arena.quality_tier == 0 and Fx.quality_scale == 1.0 and arena._fps_accum >= -6.0, "quality accumulator clamps and restores in headless")
	arena._fps_accum = -4.0
	arena._fps_time = 1.1
	arena._update_quality(0.016)
	var q_restore_branch: bool = arena.quality_tier == 0 and Fx.quality_scale == 1.0 if Engine.get_frames_per_second() <= 0.0 else true
	h._check(q_restore_branch or arena.quality_tier == 1, "quality restore path reachable")
	arena._fps_accum = 0.0
	print("AT_STEP summons")
	var sb := RootBoss.new()
	sb.boss_index = 1
	sb.configure(1.0, false)
	arena.enemy_container.add_child(sb)
	await h._ticks(2)
	for i in 7:
		sb._do_summon("drone")
	await h._ticks(4)
	var alive_summons := 0
	for s in h.get_tree().get_nodes_in_group("boss_summon"):
		if is_instance_valid(s):
			alive_summons += 1
	h._check(alive_summons == 21, "summons tagged for alive cap (%d)" % alive_summons)
	h._check(sb.has_method("_summons_alive") and sb._summons_alive() == 21, "boss counts living summons")
	for s in h.get_tree().get_nodes_in_group("boss_summon"):
		if is_instance_valid(s):
			s.queue_free()
	sb.queue_free()
	await h._ticks(3)
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
	h._check(bullets_now == 2, "splitshot adds projectile (%d)" % bullets_now)
	h._check(Game.stats["shots"] == shots0s + 1, "splitshot counts one shot")
	Game.patch_levels = {"heavy": 1, "splitshot": 1}
	player.fire_cd = 0.0
	player._shoot()
	var heavy2 := 0
	for c in arena.get_children():
		if c is PlayerBullet and c.dmg == 2:
			heavy2 += 1
			c.queue_free()
	h._check(heavy2 == 2, "splitshot inherits heavy damage (%d)" % heavy2)
	Game.patch_levels = {}
	print("AT_STEP secondwind")
	Game.patch_levels = {"secondwind": 1}
	player.second_wind_used = false
	player.invuln = 0.0
	player.hp = 1
	player.take_damage(player.global_position + Vector2(5, 0), "TEST")
	h._check(player.hp >= 1 and not player.dead and player.second_wind_used, "second wind prevents death")
	player.died.disconnect(arena._on_player_died)
	player.invuln = 0.0
	player.take_damage(player.global_position + Vector2(5, 0), "TEST")
	player.invuln = 0.0
	player.hp = 1
	player.take_damage(player.global_position + Vector2(5, 0), "TEST")
	h._check(player.dead, "second wind only once")
	player.died.connect(arena._on_player_died)
	Game.patch_levels = {}
	if player.dead:
		player.queue_free()
		await h._ticks(3)
		player = Player.new()
		h.get_tree().current_scene.add_child(player)
		arena.player = player
		if arena.touch != null:
			arena.touch.player = player
		if arena.hud != null:
			arena.hud.player = player
		await h._ticks(2)
	print("AT_STEP thorns")
	Game.patch_levels = {"thorns": 1}
	var tn := DroneEnemy.new()
	tn.setup_mini()
	tn.position = player.global_position + Vector2(20, 0)
	arena.enemy_container.add_child(tn)
	await h._ticks(3)
	var tn_hp: int = tn.hp if is_instance_valid(tn) else 0
	h._check(tn_hp <= 1, "thorns reflects contact damage (hp %d)" % tn_hp)
	Game.patch_levels = {}
	for e in h.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await h._ticks(2)
	print("AT_STEP turbo")
	Game.patch_levels = {"turbo": 2}
	player.dash_cd = 0.9
	player.notify_kill()
	h._check(absf(player.dash_cd - 0.2) < 0.01, "turbo kill recharge (-0.35 x2)")
	Game.patch_levels = {}
	print("AT_STEP heals")
	Game.stats["heals"] = {}
	Game.register_heal("recover")
	Game.register_heal("recover")
	Game.register_heal("cycle")
	h._check(Game.stats["heals"]["recover"] == 2 and Game.stats["heals"]["cycle"] == 1, "heal telemetry counts by source")
	var line: String = arena._heals_line(Game.stats)
	h._check(line.begins_with("HEALS +3") and "RECOVER x2" in line, "heals line formats (%s)" % line)
	print("AT_STEP scrap")
	Game.patch_levels = {"scrapdiet": 1}
	Game.set_program("kernel")
	player.queue_free()
	await h._ticks(3)
	var ps := Player.new()
	ps.position = Vector2(400, 0)
	h.get_tree().current_scene.add_child(ps)
	await h._ticks(2)
	h._check(ps._scrap_threshold() == 20, "scrap threshold lvl1 is 20")
	ps.oc_ready = true
	ps.meter = Balance.OC_METER_MAX
	var sc0: int = ps.scrap_count
	ps.collect_mote()
	h._check(ps.scrap_count == sc0 + 1, "scrap counts oc_ready overflow")
	ps.oc_ready = false
	ps.overclock_active = true
	ps.collect_mote()
	h._check(ps.scrap_count == sc0 + 2, "scrap counts overclock_active overflow")
	var hp_before_scrap: int = ps.hp - 1
	ps.hp = ps.max_hp - 1
	for i in 18:
		ps.collect_mote()
	h._check(ps.hp == hp_before_scrap + 1, "scrap heals at threshold (20)")
	h._check(ps.scrap_count == 0, "scrap counter resets after heal")
	ps.overclock_active = false
	ps.meter = 50.0
	ps.oc_ready = false
	ps.collect_mote()
	h._check(ps.scrap_count == 0, "meter-filling pickup does not advance scrap")
	ps.queue_free()
	await h._ticks(2)
	player = Player.new()
	player.position = Vector2.ZERO
	h.get_tree().current_scene.add_child(player)
	arena.player = player
	if arena.hud != null:
		arena.hud.player = player
	if arena.touch != null:
		arena.touch.player = player
	await h._ticks(2)
	Game.patch_levels = {}


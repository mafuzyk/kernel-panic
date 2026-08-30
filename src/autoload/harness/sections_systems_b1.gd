extends RefCounted

## Autotest section script. Function bodies below are moved verbatim from
## src/autoload/dev_harness.gd; only harness-helper references are prefixed
## with `h` per plan section G3. No behavior changes. AT_STEP labels and
## message strings are byte-identical to the originals.

var h: Node


func _init(harness: Node) -> void:
	h = harness

func _systems_test_b1(arena: Arena) -> void:
	var player: Player = arena.player
	print("AT_STEP programs")
	var selector_script = load("res://src/ui/program_panel.gd")
	h._check(selector_script != null, "program selector script loads")
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
	h._check(program_details_ok, "playable programs expose detailed comparison summaries")
	h._check(silhouette_keys.size() == Game.PROGRAM_DEFS.size(), "playable programs expose distinct visual profiles")
	var saved_program_selection := Game.program
	var saved_unlocked_programs: Dictionary = Game.unlocked_programs.duplicate(true)
	var saved_program_disk: Dictionary = h._config_snapshot("run", "program", "kernel")
	Game.unlocked_programs = {"kernel": true, "daemon": true}
	Game.set_program("kernel")
	var kernel_visual_color = player.visual_color() if player.has_method("visual_color") else Color.BLACK
	var kernel_silhouette_key := str(player.visual_silhouette_key()) if player.has_method("visual_silhouette_key") else ""
	var selector = selector_script.new() if selector_script != null else null
	if selector != null:
		var available: Array = selector.available_program_ids() if selector.has_method("available_program_ids") else []
		h._check(available.has("kernel") and available.has("daemon") and not available.has("rootlet"), "program selector lists unlocked programs only")
		var locked_selected := bool(selector.select_program("rootlet")) if selector.has_method("select_program") else true
		h._check(not locked_selected and Game.program == "kernel", "program selector cannot select locked rootlet")
		var daemon_selected := bool(selector.select_program("daemon")) if selector.has_method("select_program") else false
		h._check(daemon_selected and Game.program == "daemon", "program selector selects unlocked daemon")
		var selector_disk := ConfigFile.new()
		selector_disk.load(Sfx.SAVE_PATH)
		h._check(selector_disk.get_value("run", "program", "") == "daemon", "program selection persists through run ConfigFile")
		selector.free()
	Game.unlocked_programs = {"kernel": true, "daemon": true, "rootlet": true}
	Game.set_program("kernel")
	var responsive_sizes := [Vector2(720, 720), Vector2(432, 720)]
	for size_probe in responsive_sizes:
		var responsive_panel = selector_script.new()
		responsive_panel.size = size_probe
		h.get_tree().current_scene.add_child(responsive_panel)
		await h._ticks(2)
		responsive_panel._scroll_to(100000.0)
		await h._ticks(2)
		var responsive_viewport: Rect2 = Rect2()
		if responsive_panel.has_method("content_viewport_rect"):
			responsive_viewport = responsive_panel.content_viewport_rect()
		var rootlet_rect: Rect2 = responsive_panel._card_rects.get("rootlet", Rect2())
		h._check(responsive_panel.has_method("content_viewport_rect"), "program selector exposes consistent content viewport")
		h._check(rootlet_rect.size != Vector2.ZERO and responsive_viewport.encloses(rootlet_rect), "rootlet card is visible at max scroll (%dx%d)" % [int(size_probe.x), int(size_probe.y)])
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
		h._check(Game.program == "rootlet", "rootlet selects through panel input at %dx%d" % [int(size_probe.x), int(size_probe.y)])
		Game.set_program("kernel")
		responsive_panel.queue_free()
		await h._ticks(2)
	Game.unlocked_programs = {"kernel": true, "daemon": true}
	Game.set_program("kernel")
	var locked_panel = selector_script.new()
	locked_panel.size = Vector2(432, 720)
	h.get_tree().current_scene.add_child(locked_panel)
	await h._ticks(2)
	locked_panel._scroll_to(100000.0)
	await h._ticks(2)
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
	h._check(Game.program == "kernel", "locked rootlet rejects panel touch selection")
	locked_panel.queue_free()
	await h._ticks(2)
	print("AT_STEP selection_geometry")
	if selector_script != null:
		var geometry_panel = selector_script.new()
		geometry_panel.size = Vector2(1366, 768)
		h.get_tree().current_scene.add_child(geometry_panel)
		await h._ticks(2)
		geometry_panel._scroll_to(0.0)
		await h._ticks(2)
		h._check(geometry_panel.has_method("visible_card_rects"), "program selector exposes visible card geometry")
		h._check(geometry_panel.has_method("card_accent"), "program selector exposes selected accent")
		if geometry_panel.has_method("visible_card_rects") and geometry_panel.has_method("content_viewport_rect"):
			var program_viewport: Rect2 = geometry_panel.content_viewport_rect()
			var program_cards_contained := true
			for raw_rect in geometry_panel.visible_card_rects():
				program_cards_contained = program_cards_contained and program_viewport.encloses(raw_rect)
			h._check(program_cards_contained, "visible program cards stay inside content viewport")
		if geometry_panel.has_method("card_accent"):
			h._check(geometry_panel.card_accent("kernel") != geometry_panel.card_accent("daemon"), "selected program has a distinct accent")
		geometry_panel.queue_free()
		await h._ticks(2)
	var story_geometry_script: Script = load("res://src/ui/story_panel.gd")
	if story_geometry_script != null:
		var story_geometry = story_geometry_script.new()
		story_geometry.size = Vector2(1366, 768)
		h.get_tree().current_scene.add_child(story_geometry)
		await h._ticks(2)
		h._check(story_geometry.has_method("content_viewport_rect") and story_geometry.has_method("visible_card_rects"), "story selector exposes content geometry")
		h._check(story_geometry.has_method("selected_stage_index") and story_geometry.has_method("card_accent"), "story selector exposes selected state")
		if story_geometry.has_method("select_stage"):
			h._check(story_geometry.select_stage(0), "story selector selects the first stage")
		if story_geometry.has_method("selected_stage_index"):
			h._check(story_geometry.selected_stage_index() == 0, "story selector tracks selected stage")
		if story_geometry.has_method("visible_card_rects") and story_geometry.has_method("content_viewport_rect"):
			var story_viewport: Rect2 = story_geometry.content_viewport_rect()
			var story_cards_contained := true
			for raw_rect in story_geometry.visible_card_rects():
				story_cards_contained = story_cards_contained and story_viewport.encloses(raw_rect)
			h._check(story_cards_contained, "visible story cards stay inside content viewport")
		story_geometry.queue_free()
		await h._ticks(2)
	var bestiary_geometry_script: Script = load("res://src/ui/bestiary_panel.gd")
	if bestiary_geometry_script != null:
		var saved_bestiary_geometry: Dictionary = Game.bestiary.duplicate(true)
		Game.bestiary.clear()
		var bestiary_geometry = bestiary_geometry_script.new()
		bestiary_geometry.size = Vector2(1366, 768)
		h.get_tree().current_scene.add_child(bestiary_geometry)
		await h._ticks(2)
		h._check(bestiary_geometry.has_method("content_viewport_rect") and bestiary_geometry.has_method("visible_card_rects"), "bestiary exposes content geometry")
		h._check(bestiary_geometry.has_method("entry_status") and str(bestiary_geometry.entry_status("root")).contains("LOCKED"), "bestiary keeps locked entries explicit")
		if bestiary_geometry.has_method("visible_card_rects") and bestiary_geometry.has_method("content_viewport_rect"):
			var bestiary_viewport: Rect2 = bestiary_geometry.content_viewport_rect()
			var bestiary_cards_contained := true
			for raw_rect in bestiary_geometry.visible_card_rects():
				bestiary_cards_contained = bestiary_cards_contained and bestiary_viewport.encloses(raw_rect)
			h._check(bestiary_cards_contained, "visible bestiary cards stay inside content viewport")
		bestiary_geometry.queue_free()
		await h._ticks(2)
		Game.bestiary = saved_bestiary_geometry
	Game.program = saved_program_selection
	Game.unlocked_programs = saved_unlocked_programs
	h._restore_config_snapshot("run", "program", saved_program_disk)
	Game.unlocked_programs["kernel"] = true
	Game.unlocked_programs["daemon"] = true
	Game.unlocked_programs["rootlet"] = true
	Game.set_program("kernel")
	h._check(Game.program_def()["hp"] == 4, "kernel default hp 4")
	Game.set_program("daemon")
	player.queue_free()
	await h._ticks(3)
	var p2 := Player.new()
	p2.position = Vector2.ZERO
	h.get_tree().current_scene.add_child(p2)
	await h._ticks(2)
	h._check(p2.max_hp == 3, "daemon hp 3")
	h._check(p2.dash_charges == 2, "daemon two dash charges")
	p2.dash_cd = 0.0
	p2.dash_recharge_t = 0.0
	p2.dash_t = 0.0
	var daemon_dash_id := p2.dash_id
	p2.request_dash(Vector2.RIGHT)
	p2.dash_t = 0.0
	p2.request_dash(Vector2.RIGHT)
	p2.dash_t = 0.0
	p2.request_dash(Vector2.RIGHT)
	h._check(p2.dash_id == daemon_dash_id + 2, "daemon dash is capped at two consecutive charges")
	p2._physics_process(Balance.DASH_CD)
	h._check(p2.available_dash_charges() == 1, "daemon dash recharges one charge after cooldown")
	h._check(p2.has_method("visual_color") and p2.has_method("visual_silhouette_key"), "player exposes program visual profile")
	if p2.has_method("visual_color") and p2.has_method("visual_silhouette_key"):
		h._check(kernel_visual_color != p2.visual_color(), "kernel and daemon use different visual colors")
		h._check(kernel_silhouette_key != p2.visual_silhouette_key(), "kernel and daemon use different silhouettes")
	h._check(p2.has_method("dash_ghost_color"), "player exposes dash ghost color profile")
	if p2.has_method("dash_ghost_color"):
		h._check(p2.dash_ghost_color() == p2.visual_color(), "dash ghosts use selected program color")
	var p2_collision: CollisionShape2D = null
	for child in p2.get_children():
		if child is CollisionShape2D:
			p2_collision = child
			break
	h._check(p2_collision != null and absf(p2_collision.shape.radius - Balance.PLAYER_RADIUS) < 0.001, "program silhouettes preserve player collision radius")
	for leftover in h.get_tree().get_nodes_in_group("enemies"):
		leftover.queue_free()
	await h._ticks(2)
	var d_near := DroneEnemy.new()
	d_near.setup_mini()
	d_near.position = p2.global_position + Vector2(400, 0)
	arena.enemy_container.add_child(d_near)
	await h._ticks(2)
	var interval_far: float = p2.fire_interval()
	d_near.position = p2.global_position + Vector2(60, 0)
	await h._ticks(2)
	var interval_close: float = p2.fire_interval()
	h._check(interval_close < interval_far, "daemon close-range fire rate boost (%.3f -> %.3f)" % [interval_far, interval_close])
	p2.dash_cd = 0.5
	p2.notify_kill()
	h._check(p2.dash_cd < 0.5, "daemon kill refunds dash cd")
	p2.queue_free()
	await h._ticks(2)
	Game.set_program("rootlet")
	for e in h.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	for o in h.get_tree().get_nodes_in_group("enemy_orbs"):
		o.queue_free()
	await h._ticks(2)
	var p3 := Player.new()
	p3.position = arena.player.global_position + Vector2(200, 0) if is_instance_valid(arena.player) else Vector2(200, 0)
	h.get_tree().current_scene.add_child(p3)
	await h._ticks(2)
	h._check(p3.max_hp == 5, "rootlet hp 5")
	h._check(not p3.oc_ready and p3.shield_meter == 0.0, "rootlet has no overclock")
	p3.shield_meter = Balance.OC_METER_MAX
	p3.shield_ready = true
	p3.invuln = 0.0
	p3.take_damage(p3.global_position + Vector2(10, 0), "TEST")
	h._check(p3.hp == p3.max_hp, "rootlet shield absorbs hit")
	h._check(not p3.shield_ready and p3.shield_meter < Balance.OC_METER_MAX, "shield consumed")
	p3.shield_ready = true
	p3.invuln = 0.0
	p3.take_damage(p3.global_position + Vector2(10, 0), "TEST")
	h._check(p3.hp == p3.max_hp, "second shield absorbs too")
	p3.invuln = 0.0
	p3.take_damage(p3.global_position + Vector2(10, 0), "TEST")
	h._check(p3.hp == p3.max_hp - 1, "second unprotected hit deals damage")
	p3.queue_free()
	await h._ticks(3)
	Game.set_program("kernel")
	player = Player.new()
	player.position = Vector2.ZERO
	h.get_tree().current_scene.add_child(player)
	arena.player = player
	if arena.hud != null:
		arena.hud.player = player
	if arena.touch != null:
		arena.touch.player = player
	await h._ticks(2)
	player.invuln = 9999.0
	player.hp = player.max_hp
	print("AT_STEP desktop_dash_hud")
	h._check(Balance.is_desktop_display("wayland"), "wayland is a desktop display")
	h._check(Balance.is_desktop_display("embedded"), "embedded is a desktop display")
	arena.hud.player = player
	Game.patch_levels = {"dash": 1}
	player.dash_charges = 1
	player.dash_cd = Balance.DASH_CD * pow(0.82, Game.patch_level("dash"))
	await h._ticks(2)
	h._check(arena.hud._dash_frac < 0.1, "dash hud uses quick dash cooldown")
	player.dash_charges = 2
	player.dash_recharge_t = 0.5
	player.dash_cd = 0.5
	await h._ticks(2)
	h._check(arena.hud._dash_frac > 0.99, "dash hud shows available extra charge")
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
	h._check(absf(trojan_probe.vel().dot(Vector2.LEFT)) < trojan_probe.vel().length(), "trojan approaches with route offset")
	print("AT_STEP teleports")
	var flank_player := Player.new()
	flank_player.position = Vector2.ZERO
	flank_player.aim = Vector2.RIGHT * 100.0
	flank_player.vel = Vector2.RIGHT * 100.0
	arena.add_child(flank_player)
	await h._ticks(2)
	flank_player.aim = Vector2.RIGHT * 100.0
	flank_player.vel = Vector2.RIGHT * 100.0
	var recursor_flank_probe: RecursorEnemy = load("res://src/enemies/recursor.gd").new()
	recursor_flank_probe.radius = 13.0
	var recursor_has_selector := recursor_flank_probe.has_method("select_teleport_candidate")
	h._check(recursor_has_selector, "recursor exposes deterministic teleport selector")
	if recursor_has_selector:
		var rec_rng_state := Game.rng.state
		var rec_dest_a: Vector2 = recursor_flank_probe.select_teleport_candidate(flank_player.global_position, flank_player.aim, flank_player.vel)
		var rec_dest_b: Vector2 = recursor_flank_probe.select_teleport_candidate(flank_player.global_position, flank_player.aim, flank_player.vel)
		var rec_offset := (rec_dest_a - flank_player.global_position).normalized()
		var rec_safe_rect := Balance.arena_rect().grow(-recursor_flank_probe.radius - 8.0)
		h._check(rec_dest_a.is_equal_approx(rec_dest_b), "recursor heading selection is deterministic")
		h._check(Game.rng.state == rec_rng_state, "recursor heading selection does not consume Game.rng")
		h._check(rec_offset.dot(Vector2.RIGHT) <= 0.2, "recursor teleport favors flank or behind player facing")
		h._check(rec_safe_rect.has_point(rec_dest_a) and rec_dest_a.distance_to(flank_player.global_position) > 90.0, "recursor teleport stays safe and inside arena")
	recursor_flank_probe.free()
	var ranged_boss_flank_probe: RootBoss = load("res://src/enemies/root_boss.gd").new()
	ranged_boss_flank_probe.boss_index = 2
	ranged_boss_flank_probe.configure(1.0, false)
	var boss_has_selector := ranged_boss_flank_probe.has_method("select_teleport_candidate")
	h._check(boss_has_selector, "ranged boss exposes deterministic teleport selector")
	if boss_has_selector:
		var boss_rng_state := Game.rng.state
		var boss_dest_a: Vector2 = ranged_boss_flank_probe.select_teleport_candidate(flank_player.global_position, flank_player.aim, flank_player.vel)
		var boss_dest_b: Vector2 = ranged_boss_flank_probe.select_teleport_candidate(flank_player.global_position, flank_player.aim, flank_player.vel)
		var boss_offset := (boss_dest_a - flank_player.global_position).normalized()
		var boss_safe_rect := Balance.arena_rect().grow(-ranged_boss_flank_probe.radius - 8.0)
		h._check(boss_dest_a.is_equal_approx(boss_dest_b), "ranged boss heading selection is deterministic")
		h._check(Game.rng.state == boss_rng_state, "ranged boss heading selection does not consume Game.rng")
		h._check(boss_offset.dot(Vector2.RIGHT) <= 0.2, "ranged boss teleport favors flank or behind player facing")
		h._check(boss_safe_rect.has_point(boss_dest_a) and boss_dest_a.distance_to(flank_player.global_position) > 240.0, "ranged boss teleport stays safe and inside arena")
	ranged_boss_flank_probe.free()
	flank_player.free()
	var fallback_rng_state := Game.rng.state
	var recursor_fallback_probe: RecursorEnemy = load("res://src/enemies/recursor.gd").new()
	Game.rng.seed = 1
	var recursor_fallback_rng_before := Game.rng.state
	var recursor_fallback_dest: Vector2 = recursor_fallback_probe.select_teleport_candidate(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	var recursor_fallback_rect := Balance.arena_rect().grow(-recursor_fallback_probe.radius - 8.0)
	h._check(recursor_fallback_rect.has_point(recursor_fallback_dest) and recursor_fallback_dest.length() > 90.0, "recursor random fallback preserves arena inset and safety distance")
	h._check(Game.rng.state != recursor_fallback_rng_before, "recursor random fallback consumes Game.rng")
	recursor_fallback_probe.free()
	var boss_fallback_probe: RootBoss = load("res://src/enemies/root_boss.gd").new()
	boss_fallback_probe.radius = 300.0
	Game.rng.seed = 1
	var boss_fallback_rng_before := Game.rng.state
	var boss_fallback_dest: Vector2 = boss_fallback_probe.select_teleport_candidate(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	var boss_fallback_rect := Balance.arena_rect().grow(-boss_fallback_probe.radius - 8.0)
	h._check(boss_fallback_rect.has_point(boss_fallback_dest) and boss_fallback_dest.length() > 240.0, "ranged boss random fallback preserves arena inset and safety distance")
	h._check(Game.rng.state != boss_fallback_rng_before, "ranged boss random fallback consumes Game.rng")
	var unsafe_fallback_found := false
	for seed in 256:
		Game.rng.seed = seed + 1
		var candidate: Vector2 = boss_fallback_probe.select_teleport_candidate(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
		if candidate.length() <= 240.0:
			unsafe_fallback_found = true
			break
	h._check(not unsafe_fallback_found, "ranged boss fallback never returns an unsafe best sample")
	boss_fallback_probe.free()
	Game.rng.state = fallback_rng_state
	var recursor_probe: RecursorEnemy = load("res://src/enemies/recursor.gd").new()
	recursor_probe.player = special_player
	recursor_probe.position = Vector2(80, 0)
	recursor_probe.phase_t = 99.0
	recursor_probe._move(0.1)
	h._check(recursor_probe.vel().dot(Vector2.LEFT) <= 0.0, "recursor does not blindly converge at close range")
	EnemyBase.shared_list = arena.enemy_list
	trojan_probe.free()
	recursor_probe.free()
	special_player.free()
	var rec = load("res://src/enemies/recursor.gd").new()
	rec.position = player.global_position + Vector2(300, 0)
	arena.enemy_container.add_child(rec)
	await h._ticks(2)
	h._check(rec.display_name == "RECURSOR", "recursor builds")
	var zones_before := h.get_tree().get_nodes_in_group("corruption").size()
	for i in 150:
		await h.get_tree().process_frame
		if not is_instance_valid(rec):
			break
		if rec.phase == 3 or rec.phase == 2:
			break
	await h._ticks(3)
	var zones_after := h.get_tree().get_nodes_in_group("corruption").size()
	if not is_instance_valid(rec):
		rec = null
	h._check(zones_after > zones_before or rec == null, "recursor leaves corruption zones")
	if is_instance_valid(rec):
		rec._dest = rec.global_position + Vector2(120, 0)
		rec.phase = RecursorEnemy.Phase.GONE
		rec.phase_t = 0.0
		rec._finish_teleport()
		h._check(rec.phase == RecursorEnemy.Phase.ARRIVE, "recursor teleport finishes without audio error")
		var min_dist: float = rec.global_position.distance_to(player.global_position)
		h._check(min_dist > 85.0, "recursor never teleports onto player (%d px)" % int(min_dist))
		rec.queue_free()
	var fw = load("res://src/enemies/firewall.gd").new()
	fw.position = player.global_position + Vector2(-350, -200)
	arena.enemy_container.add_child(fw)
	await h._ticks(2)
	h._check(fw.display_name == "FIREWALL", "firewall builds")
	var fw_angle_before: float = fw._wall_angle
	for i in 600:
		await h._ticks(1)
		if not is_instance_valid(fw):
			break
		if fw._settled and h.get_tree().get_nodes_in_group("enemy_orbs").size() >= 5:
			break
	await h._ticks(3)
	var fw_orbs := 0
	for orb in h.get_tree().get_nodes_in_group("enemy_orbs"):
		if is_instance_valid(orb) and orb.get_meta("fw_owner", -1) == fw.get_instance_id():
			fw_orbs += 1
	h._check(fw_orbs >= 3, "firewall maintains rotating wall (%d orbs)" % fw_orbs)
	h._check(absf(fw._wall_angle - fw_angle_before) > 0.01, "firewall wall rotates")
	if is_instance_valid(fw):
		fw.take_hit(999, fw.global_position)
		await h._ticks(6)
		var left := 0
		for orb in h.get_tree().get_nodes_in_group("enemy_orbs"):
			if is_instance_valid(orb) and orb.get_meta("fw_owner", -1) == fw.get_instance_id():
				left += 1
		h._check(left == 0, "firewall wall dies with owner")
	player.invuln = 9999.0
	player.hp = player.max_hp


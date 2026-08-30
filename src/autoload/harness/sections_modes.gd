extends RefCounted

## Autotest section script. Function bodies below are moved verbatim from
## src/autoload/dev_harness.gd; only harness-helper references are prefixed
## with `h` per plan section G3. No behavior changes. AT_STEP labels and
## message strings are byte-identical to the originals.

var h: Node


func _init(harness: Node) -> void:
	h = harness

func _touch_test() -> void:
	var arena: Arena = h.get_tree().current_scene
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
	await h._ticks(2)
	print("AT_DEBUG touch size=", touch_ui.size, " events=", touch_ui.debug_touch_count, " move_id=", touch_ui._move_id)
	_press(Vector2(200, 400), true, 7)
	await h._ticks(2)
	_drag(7, Vector2(200, 400), Vector2(260, 380))
	await h._ticks(10)
	print("AT_DEBUG harness_events=", touch_ui.debug_touch_count, " arena_touch=", arena.touch, " arena_events=", arena.touch.debug_touch_count if arena.touch != null else -1, " ptm=", player.touch_move, " mid=", touch_ui._move_id, " mvec=", touch_ui._move_vec, " in_tree=", touch_ui.is_inside_tree(), " proc=", touch_ui.is_processing())
	h._check(player.touch_move.length() > 0.1, "touch move stick drives player")
	_press(Vector2(900, 400), true, 8)
	await h._ticks(2)
	h._check(player.touch_fire, "touch aim side enables autofire")
	var shots_before: int = Game.stats["shots"]
	await h._ticks(20)
	h._check(Game.stats["shots"] > shots_before, "touch fire shoots")
	_press(Vector2(900, 400), false, 8)
	_press(Vector2(200, 400), false, 7)
	await h._ticks(2)
	h._check(not player.touch_fire and player.touch_move.length() < 0.1, "touch release clears state")
	var dash_before := player.dash_cd
	var dash_id_before := player.dash_id
	_press(touch_ui._dash_btn().get_center(), true, 9)
	await h._ticks(2)
	_press(touch_ui._dash_btn().get_center(), false, 9)
	await h._ticks(2)
	h._check(player.dash_cd > dash_before, "touch dash button dashes")
	h._check(player.dash_id == dash_id_before + 1, "touch dash increments dash id")
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
	await h._ticks(2)
	_press(touch_ui._dash_btn().get_center(), false, 11)
	await h._ticks(14)
	h._check(player.dash_id == pd_id_before + 1, "phase dash touch dash fired")
	h._check((not is_instance_valid(pd_target)) or pd_target.last_pdash_id == player.dash_id or pd_target.hp <= 0, "touch dash applies phase dash damage")
	if is_instance_valid(pd_target):
		pd_target.take_hit(99, pd_target.global_position)
	Game.patch_levels = {}
	player.invuln = 0.0
	arena._set_paused(true)
	_press(touch_ui._pause_btn().get_center(), true, 10)
	_press(touch_ui._pause_btn().get_center(), false, 10)
	await h._ticks(2)
	h._check(h.get_tree().paused, "pause stays while paused (pause btn guarded)")
	arena._set_paused(false)
	for leftover in h.get_tree().get_nodes_in_group("enemies"):
		leftover.queue_free()
	await h._ticks(2)
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
	await h._ticks(30)
	h._check(absf(wrapf(player.rotation - idle_rot, -PI, PI)) < 0.05, "touch idle keeps aim (no auto-aim)")
	var saved_aim := Sfx.aim_mode
	Sfx.aim_mode = "stick"
	_press(Vector2(900, 400), true, 8)
	_drag(8, Vector2(900, 400), Vector2(1020, 400))
	await h._ticks(35)
	h._check(player.touch_aim.length() > 50.0 and absf(wrapf(player.rotation, -PI, PI)) < 0.5, "touch drag aims along drag direction")
	print("AT_DEBUG aim_origin=", touch_ui._aim_origin)
	var origin_before: Vector2 = touch_ui._aim_origin
	_drag(8, Vector2(1020, 400), Vector2(1240, 620))
	await h._ticks(5)
	h._check(touch_ui._aim_origin == origin_before, "anchored stick keeps base fixed during drag")
	h._check(player.touch_aim.length() <= 111.0, "stick offset clamped to max length")
	_drag(8, Vector2(1240, 620), Vector2(900, 400))
	_press(Vector2(900, 400), false, 8)
	Sfx.aim_mode = "lockon"
	Game.mode = "classic"
	_press(Vector2(900, 400), true, 12)
	await h._ticks(30)
	h._check(player.lockon_active, "lockon active in classic when enabled")
	h._check(Game.effective_aim_mode() == "lockon", "effective mode is lockon in classic")
	_press(Vector2(900, 400), false, 12)
	Game.mode = "weekly"
	_press(Vector2(900, 400), true, 13)
	await h._ticks(10)
	h._check(player.lockon_active, "lockon remains active in weekly")
	h._check(Game.effective_aim_mode() == "lockon", "weekly keeps saved lockon mode")
	_press(Vector2(900, 400), false, 13)
	h._check(Sfx.aim_mode == "lockon", "weekly does not erase saved aim preference")
	Sfx.aim_mode = saved_aim
	Game.mode = "classic"
	player.touch_mode = false
	tcl.queue_free()
	await h._ticks(2)

func _press(pos: Vector2, down: bool, idx: int) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = idx
	ev.position = _to_window(pos)
	ev.pressed = down
	h.get_viewport().push_input(ev)

func _drag(idx: int, from: Vector2, to: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = idx
	ev.position = _to_window(to)
	ev.relative = _to_window(to) - _to_window(from)
	h.get_viewport().push_input(ev)

func _to_window(design_pos: Vector2) -> Vector2:
	return h.get_viewport().get_final_transform() * design_pos

func _stress() -> void:
	h._watchdog(120.0)
	await h._ticks(15)
	Game.start_run()
	var ok: bool = await h._until(func() -> bool:
		return h.get_tree().current_scene != null and h.get_tree().current_scene.name == "Arena", 8.0, "arena")
	if not ok:
		h.get_tree().quit(1)
		return
	var arena: Arena = h.get_tree().current_scene
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
	await h._ticks(100)
	var acc := 0.0
	var accp := 0.0
	var n := 0
	for i in 300:
		await h.get_tree().physics_frame
		acc += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		accp += Performance.get_monitor(Performance.TIME_PROCESS)
		n += 1
	var mf_at_end: Node = h.get_tree().get_first_node_in_group("mote_field")
	print("STRESS_RESULT avg_phys=%.2fms avg_proc=%.2fms enemies=%d motes=%d" % [acc / maxf(n, 1), accp / maxf(n, 1), EnemyBase.shared_list.size(), mf_at_end.count() if mf_at_end != null else -1])
	h.get_tree().quit(0)

func _capture() -> void:
	var mode := OS.get_environment("KP_SHOT")
	var out := OS.get_environment("KP_SHOT_OUT")
	if out == "":
		out = ProjectSettings.globalize_path("user://shot.png")
	var frames := int(OS.get_environment("KP_SHOT_FRAMES")) if OS.get_environment("KP_SHOT_FRAMES") != "" else 40
	h._watchdog()
	await h._ticks(15)
	if OS.get_environment("KP_PROBE") != "" and h.get_tree().current_scene.has_method("_open_settings"):
		var mi: Label = h.get_tree().current_scene._mode_info
		print("PROBE text=", mi.text, " gpos=", mi.global_position, " size=", mi.size)
		for c in h.get_tree().current_scene.get_children():
			if c is Label and c.text.begins_with("BEST"):
				print("PROBE stray=", c.text, " gpos=", c.global_position, " size=", c.size, " parent=", c.get_parent().name)
	if mode == "menu":
		var menu := h.get_tree().current_scene
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
		await h._until(func() -> bool:
			return h.get_tree().current_scene != null and h.get_tree().current_scene.name == "Arena", 8.0, "arena")
		await h._ticks(10)
		var arena: Arena = h.get_tree().current_scene
		if OS.get_environment("KP_WAVE") != "":
			var w := int(OS.get_environment("KP_WAVE"))
			Game.wave = w
			arena._on_wave_started(w, w % Balance.BOSS_EVERY == 0)
		match mode:
			"game":
				h._populate(arena)
				Input.action_press("fire")
			"boss":
				h._spawn_boss(arena, int(OS.get_environment("KP_BOSS_MK")) if OS.get_environment("KP_BOSS_MK") != "" else 1)
				h._populate(arena, 3)
				Input.action_press("fire")
			"mk2":
				h._spawn_boss(arena, 2)
				h._populate(arena, 3)
				Input.action_press("fire")
			"patch":
				arena.offer_patch()
			"trojan":
				var tr := TrojanEnemy.new()
				tr.position = arena.player.global_position + Vector2(260, -80)
				tr.configure(1.2, false)
				arena.enemy_container.add_child(tr)
				h._populate(arena, 2)
				Input.action_press("fire")
			"over":
				h._populate(arena, 2)
				for i in 4:
					arena.player.invuln = 0.0
					arena.player.take_damage(arena.player.global_position + Vector2(20, 0))
					await h._ticks(3)
			"pause":
				h._populate(arena)
				await h._ticks(30)
				arena._set_paused(true)
			"terminal":
				h._populate(arena, 2)
				await h._ticks(20)
				arena._set_paused(true)
				arena._open_terminal()
	await h._ticks(frames)
	await RenderingServer.frame_post_draw
	var img := h.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("SHOT_SAVED ", out, " ", img.get_width(), "x", img.get_height())
	h.get_tree().quit(0)

func _demo() -> void:
	var max_s := int(OS.get_environment("KP_DEMO_TIME")) if OS.get_environment("KP_DEMO_TIME") != "" else 150
	h._watchdog(max_s * 5.0 + 180.0)
	await h._ticks(15)
	Game.start_run()
	var ok: bool = await h._until(func() -> bool:
		return h.get_tree().current_scene != null and h.get_tree().current_scene.name == "Arena", 8.0, "arena")
	if not ok:
		h.get_tree().quit(1)
		return
	var arena: Arena = h.get_tree().current_scene
	var player: Player = arena.player
	var out_dir := OS.get_environment("KP_DEMO")
	var t := 0.0
	var next_shot := 0.0
	var next_log := 0.0
	while t < max_s and not player.dead and Game.state == Game.State.PLAYING:
		await h.get_tree().physics_frame
		if h.get_tree().paused and arena._patch_open:
			arena._pick_patch(randi() % maxi(1, arena._patch_offers.size()))
			continue
		t += 1.0 / 60.0
		h._autopilot(player)
		if t >= next_shot:
			next_shot += 15.0
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				var img := h.get_viewport().get_texture().get_image()
				img.save_png("%s/demo_%03d.png" % [out_dir, int(t)])
		if t >= next_log:
			next_log += 5.0
			var alive := h.get_tree().get_nodes_in_group("enemies").size()
			var mf_demo: Node = h.get_tree().get_first_node_in_group("mote_field")
			var motes: int = mf_demo.count() if mf_demo != null else 0
			print("DEMO t=%03d wave=%d hp=%d score=%d mult=%d alive=%d motes=%d meter=%d fps=%d proc=%.2fms phys=%.2fms" % [int(t), Game.wave, player.hp, Game.score, Game.mult, alive, motes, int(player.meter), Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	print("DEMO_END t=%d wave=%d score=%d dead=%s" % [int(t), Game.wave, Game.score, str(player.dead)])
	h.get_tree().quit(0)

func _achievements_panel_test() -> void:
	print("AT_STEP achievements_panel")
	var panel_script: Script = load("res://src/ui/achievements_panel.gd")
	var panel = panel_script.new() if panel_script != null else null
	h._check(panel != null and panel.has_method("achievement_rows") and panel.has_method("progress_header"), "achievements panel exposes achievement_rows and progress_header")
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
	h._check(all_listed, "achievements panel lists every ACHIEVEMENT_DEFS id")
	var state_ok: bool = rows.size() == Game.ACHIEVEMENT_DEFS.size()
	for row in rows:
		if bool(row.get("unlocked", false)) == (not Game.achievements.has(str(row.get("id", "")))):
			state_ok = false
	h._check(state_ok, "achievements rows report the correct locked state")
	h._check(str(panel.call("progress_header")).contains("1 / %d" % Game.ACHIEVEMENT_DEFS.size()), "achievements header shows the X / Y progress count")
	var hints_ok := true
	for row in rows:
		if not Game.achievements.has(str(row.get("id", ""))) and str(row.get("hint", "")).strip_edges().is_empty():
			hints_ok = false
	h._check(hints_ok, "locked achievements expose a hint line")
	var panel_src := str(panel_script.source_code)
	h._check(panel_src.contains("ScrollContainer"), "achievements panel scrolls instead of blocking mobile input")
	panel.free()
	var menu_src := str(load("res://src/ui/menu.gd").source_code)
	h._check(menu_src.contains("_open_achievements"), "menu exposes an achievements entry point")
	var hud_script: Script = load("res://src/ui/hud.gd")
	var hud_detached = hud_script.new()
	hud_detached.size = Vector2(1366, 768)
	Game.achievements.erase("chain_max")
	var unlocked_now: bool = Game.unlock_achievement("chain_max")
	h._check(unlocked_now, "test unlock of a fresh achievement succeeds")
	var surfaced := false
	for line in hud_detached.call("visible_event_lines"):
		if str(line).contains("achievement: CHAIN_REACTION"):
			surfaced = true
	h._check(surfaced, "a mid-run unlock appears in the hud event log lines")
	hud_detached.size = Vector2(432, 720)
	h._check(not bool(hud_detached.call("event_log_visible")), "compact viewport keeps the event log hidden for the hidden-log probe")
	Game.achievements.erase("terminal_operator")
	Game.unlock_achievement("terminal_operator")
	h._check(hud_detached.call("visible_event_lines").size() > 0, "unlocking while the event log is hidden does not error")
	hud_detached.free()
	Game.achievements = saved_achievements
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	cf.set_value("achievements", "unlocked", saved_achievements)
	cf.save(Sfx.SAVE_PATH)

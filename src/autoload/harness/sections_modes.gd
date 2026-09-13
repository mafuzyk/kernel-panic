extends RefCounted

## Autotest section script. Function bodies below are moved verbatim from
## src/autoload/dev_harness.gd; only harness-helper references are prefixed
## with `h` per plan section G3. No behavior changes. AT_STEP labels and
## message strings are byte-identical to the originals.

var h: Node


func _init(harness: Node) -> void:
	h = harness

func _reticle_modal_test(arena: Arena) -> void:
	print("AT_STEP reticle_modal")
	# Headless não monta reticle (sem cursor real; ver KP_FORCE_RETICLE): o
	# contrato modal é exercido num reticle próprio, vivo na arena real.
	var r := Reticle.new()
	r.player = arena.player
	arena.add_child(r)
	# A arena dirige o cursor pelo próprio reticle: sem dono, ela o mantém
	# visível e o teste lutaria contra a cena em vez do contrato.
	arena.reticle = r
	await h._ticks(2)
	h._check(r != null and is_instance_valid(r), "arena owns a reticle")
	if r == null or not is_instance_valid(r):
		return
	h._check(r.process_mode == Node.PROCESS_MODE_ALWAYS, "reticle processes while paused")
	# O predicado dirige o cursor em qualquer ambiente; a visibilidade final
	# depende do cursor do SO, que o headless ignora (sempre VISIBLE).
	var e2e := DisplayServer.get_name() != "headless"
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	await h._ticks(2)
	h._check(arena._wants_hidden_cursor(), "gameplay wants the os cursor hidden")
	if e2e:
		h._check(r.visible, "hidden os cursor shows the reticle in gameplay")
	else:
		print("AT_SKIP reticle visibility needs a real cursor; the driving predicate is asserted")
	arena._set_paused(true)
	await h._ticks(2)
	h._check(not arena._wants_hidden_cursor(), "pause wants the os cursor back")
	if e2e:
		h._check(not r.visible, "pause hides the reticle")
	arena.call("_open_terminal")
	await h._ticks(2)
	h._check(not arena._wants_hidden_cursor(), "terminal wants the os cursor back")
	if e2e:
		h._check(not r.visible, "terminal keeps the reticle hidden")
	arena.call("_close_terminal")
	await h._ticks(2)
	arena._set_paused(false)
	await h._ticks(2)
	h._check(arena._wants_hidden_cursor(), "resume wants the os cursor hidden again")
	if e2e:
		h._check(r.visible, "resume restores the reticle")
	arena._patch_pending = 1
	arena.call("_try_show_patch")
	await h._ticks(2)
	h._check(bool(arena.get("_patch_open")) and not arena._wants_hidden_cursor(), "patch offer wants the os cursor back")
	if e2e:
		h._check(bool(arena.get("_patch_open")) and not r.visible, "patch offer hides the reticle")
	arena.call("_pick_patch", 0)
	await h._ticks(2)
	h._check(not bool(arena.get("_patch_open")) and arena._wants_hidden_cursor(), "patch pick wants the os cursor hidden again")
	if e2e:
		h._check(not bool(arena.get("_patch_open")) and r.visible, "patch pick restores the reticle")
	r.queue_free()
	arena.reticle = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await h._ticks(1)

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
	if not Balance.is_desktop_display():
		h._check(absf(wrapf(player.rotation - idle_rot, -PI, PI)) < 0.05, "touch idle keeps aim (no auto-aim)")
	else:
		print("AT_SKIP touch idle heading requires a non-desktop display; desktop follows the mouse")
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

func _multitouch_test() -> void:
	print("AT_STEP multitouch")
	var arena: Arena = h.get_tree().current_scene
	var player: Player = arena.player
	var touch_ui := TouchControls.new()
	touch_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch_ui.player = player
	touch_ui.arena = arena
	var tcl := CanvasLayer.new()
	tcl.layer = 30
	tcl.add_child(touch_ui)
	arena.add_child(tcl)
	await h._ticks(2)
	player.invuln = 9999.0
	player.dash_cd = 0.0
	player.dash_t = 0.0
	player.oc_ready = false
	player.overclock_active = false
	_press(Vector2(200, 400), true, 20)
	_drag(20, Vector2(200, 400), Vector2(260, 380))
	_press(Vector2(900, 400), true, 21)
	await h._ticks(5)
	h._check(player.touch_move.length() > 0.1 and player.touch_fire, "move and aim fingers held")
	var dash_id_before := player.dash_id
	var move_id_before: int = touch_ui._move_id
	var aim_id_before: int = touch_ui._aim_id
	h._check(aim_id_before == 21, "aim finger owns the aim channel")
	_press(touch_ui._dash_btn().get_center(), true, 22)
	await h._ticks(3)
	_press(touch_ui._dash_btn().get_center(), false, 22)
	await h._ticks(2)
	h._check(player.dash_id == dash_id_before + 1, "third finger dashes while move and aim are held")
	h._check(touch_ui._move_id == move_id_before and touch_ui._aim_id == aim_id_before, "dash does not steal move or aim channels")
	h._check(player.touch_move.length() > 0.1 and player.touch_fire, "move and aim survive the dash")
	_press(Vector2(900, 400), false, 21)
	_press(Vector2(200, 400), false, 20)
	await h._ticks(2)
	player.oc_ready = false
	_press(touch_ui._oc_btn().get_center(), true, 23)
	await h._ticks(2)
	h._check(touch_ui._aim_id == -1, "disabled boost never steals the aim channel")
	_press(touch_ui._oc_btn().get_center(), false, 23)
	await h._ticks(2)
	player.oc_ready = true
	_press(Vector2(900, 400), true, 24)
	await h._ticks(2)
	_press(touch_ui._oc_btn().get_center(), true, 25)
	await h._ticks(3)
	h._check(player.overclock_active, "third finger boosts while aim is held")
	h._check(touch_ui._aim_id == 24, "boost does not steal the aim channel")
	_press(touch_ui._oc_btn().get_center(), false, 25)
	_press(Vector2(900, 400), false, 24)
	await h._ticks(2)
	player.touch_move = Vector2.ZERO
	player.touch_fire = false
	player.touch_aim = Vector2.ZERO
	player.overclock_active = false
	player.oc_ready = false
	player.invuln = 0.0
	tcl.queue_free()
	await h._ticks(2)

func _touch_layout_test() -> void:
	print("AT_STEP touch_layout")
	var cut := Design.safe_margins_from(Vector2(1280, 720), Rect2i(0, 0, 1280, 720), Vector2(1280, 720))
	h._check(cut["left"] == 0.0 and cut["top"] == 0.0 and cut["right"] == 0.0 and cut["bottom"] == 0.0, "full-bleed display reports zero safe insets")
	var notch := Design.safe_margins_from(Vector2(1280, 720), Rect2i(80, 0, 1200, 700), Vector2(1280, 720))
	h._check(notch["left"] == 80.0 and notch["top"] == 0.0 and notch["right"] == 0.0 and notch["bottom"] == 20.0, "cutout insets convert to canvas units")
	h._check(Design.safe_margins(Vector2(1280, 720))["left"] == 0.0, "desktop reports no safe insets")
	OS.set_environment("KP_FORCE_TOUCH", "1")
	var shell := MenuShell.new()
	h.add_child(shell)
	await h._ticks(2)
	var enter_hidden := true
	var ring_ok := true
	for label in shell.find_children("*", "Label", true, false):
		var l := label as Label
		if l.text == "ENTER" and l.visible:
			enter_hidden = false
	for host in shell.footer_hosts():
		for flabel in (host as Control).find_children("*", "Label", true, false):
			if not (host as Control).get_global_rect().encloses((flabel as Control).get_global_rect()):
				ring_ok = false
	h._check(enter_hidden, "touch menu hides the keyboard hint")
	h._check(ring_ok, "touch menu keeps the footer ring contract")
	shell.queue_free()
	var pause := PausePanel.new()
	h.add_child(pause)
	await h._ticks(2)
	var pause_labels: Array = pause.action_labels()
	h._check(not pause_labels.has(tr("PAUSE_TERMINAL")), "touch pause hides the desktop-only terminal entry")
	var key_leak := false
	for node in pause.find_children("*", "Label", true, false):
		var text := str((node as Label).text)
		if text.begins_with("[") and text.ends_with("]"):
			key_leak = true
	h._check(not key_leak, "touch pause shows no keyboard hints")
	pause.queue_free()
	OS.set_environment("KP_FORCE_TOUCH", "")
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
		elif OS.get_environment("KP_AWARDS") != "" and menu.has_method("_open_achievements"):
			menu._open_achievements()
	else:
		if mode == "story_intro":
			Game.story_cleared = {}
			Game.start_story(0)
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
			"god":
				var god: GodBoss = GodBoss.new()
				god.configure(1.0, false)
				god.position = arena.player.global_position + Vector2(0, -170)
				arena.enemy_container.add_child(god)
				arena.hud.boss = god
				h._populate(arena, 3)
				Input.action_press("fire")
			"batch1":
				var kinds_b1: Array[String] = ["oom", "trojan", "update_loop"]
				var player_b1: Player = arena.player
				for i in kinds_b1.size():
					var e_b1: EnemyBase = arena.spawner.call("_make_enemy", kinds_b1[i])
					if e_b1 != null:
						e_b1.position = player_b1.global_position + Vector2(-240 + i * 240, -130)
						e_b1.configure(1.2, false)
						arena.enemy_container.add_child(e_b1)
				h._populate(arena, 2)
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

## Percorre a árvore inteira abaixo de um nó.
func _descendants(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	for child in root.get_children():
		out.append(child)
		out.append_array(_descendants(child))
	return out


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
	# Comportamento em vez de grep: o painel precisa conter um ScrollContainer
	# de verdade na árvore, não a string "ScrollContainer" no arquivo.
	panel._build()
	var scrolls := 0
	for node in _descendants(panel):
		if node is ScrollContainer:
			scrolls += 1
	h._check(scrolls >= 1, "achievements panel scrolls instead of blocking input")
	panel.free()
	# Contrato runtime em vez de grep no fonte: o menu vivo expõe a entrada.
	var live_menu: Node = h.get_tree().current_scene
	h._check(live_menu != null and live_menu.has_method("_open_achievements"), "menu exposes an achievements entry point")
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

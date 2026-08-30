extends RefCounted

## Autotest section script. Function bodies below are moved verbatim from
## src/autoload/dev_harness.gd; only harness-helper references are prefixed
## with `h` per plan section G3. No behavior changes. AT_STEP labels and
## message strings are byte-identical to the originals.

var h: Node


func _init(harness: Node) -> void:
	h = harness

func _hud_style_test(_arena: Arena) -> void:
	print("AT_STEP hud_style")
	var tui_script: Script = load("res://src/ui/tactical_ui.gd")
	var tui = tui_script.new() if tui_script != null else null
	h._check(tui != null and tui.has_method("panel_fill_color"), "tactical ui exposes panel_fill_color")
	if tui == null or not tui.has_method("panel_fill_color"):
		return
	var combat_fill: Color = tui.call("panel_fill_color", true)
	var menu_fill: Color = tui.call("panel_fill_color", false)
	h._check(combat_fill.a <= 0.08, "combat panel fill stays faint (alpha <= 0.08)")
	h._check(combat_fill.a >= 0.04, "combat panel fill keeps a visible tint (alpha >= 0.04)")
	h._check(menu_fill.is_equal_approx(TacticalUI.PANEL), "non-combat surfaces keep the opaque PANEL fill")
	var hud_script: Script = load("res://src/ui/hud.gd")
	h._check(str(hud_script.source_code).contains("panel_fill_color(combat)"), "combat hud panels draw with the faint combat fill")

func _era_accent_test(arena: Arena) -> void:
	print("AT_STEP era_accent")
	var hud_ref = arena.hud
	h._check(hud_ref != null and hud_ref.has_method("set_era_accent") and hud_ref.has_method("era_accent"), "hud exposes era accent controls")
	if hud_ref == null or not hud_ref.has_method("set_era_accent"):
		return
	var hud_script: Script = load("res://src/ui/hud.gd")
	var fresh_hud = hud_script.new() if hud_script != null else null
	h._check(fresh_hud != null and fresh_hud.call("era_accent") == TacticalUI.CYAN, "hud era accent defaults to cyan")
	if fresh_hud != null:
		fresh_hud.free()
	var seed_before := Game.rng.seed
	hud_ref.call("set_era_accent", Balance.era_color(8))
	h._check(hud_ref.call("era_accent") == Balance.era_color(8), "set_era_accent updates the hud accent")
	h._check(Game.rng.seed == seed_before, "era accent changes never advance the gameplay rng")
	arena.call("_on_wave_started", 8, false)
	h._check(arena.hud.call("era_accent") == Balance.era_color(8), "arena pushes the per-wave era accent to the hud")
	arena.set("_temple_mode", true)
	var accent_a: Color = arena.hud.call("era_accent")
	await h._ticks(4)
	var accent_b: Color = arena.hud.call("era_accent")
	arena.set("_temple_mode", false)
	h._check(accent_a != accent_b, "rainbow mode cycles the hud accent over time")
	hud_ref.call("set_era_accent", TacticalUI.CYAN)

func _story_test(arena: Arena) -> void:
	print("AT_STEP story")
	var story_script: Script = load("res://src/story/story_data.gd")
	h._check(story_script != null, "story stage data script loads")
	h._check(Game.has_method("story_stage_count") and Game.has_method("story_stage_def"), "game exposes story stage data")
	h._check(Game.has_method("story_stage_unlocked"), "game exposes story unlock progression")
	h._check(arena.spawner.has_method("start_story"), "spawner exposes fixed story queue")
	if story_script == null or not Game.has_method("story_stage_count") or not Game.has_method("story_stage_def") or not arena.spawner.has_method("start_story"):
		return
	var count := int(Game.story_stage_count())
	h._check(count == 11 and Game.STORY_DATA.act_stage_count("unix") == 6 and Game.STORY_DATA.act_stage_count("windows") == 3 and Game.STORY_DATA.act_stage_count("templeos") == 2, "Story contains UNIX, Windows, and TempleOS stages")
	var expected_ids := ["boot", "var_log", "net", "mem", "quarantine", "kernel"]
	var expected_paths := ["/boot", "/var/log", "/net", "/mem", "/quarantine", "/kernel"]
	for i in mini(count, expected_ids.size()):
		var stage: Dictionary = Game.story_stage_def(i)
		h._check(str(stage.get("id", "")) == expected_ids[i] and str(stage.get("path", "")) == expected_paths[i], "story stage %d has the expected UNIX path" % (i + 1))
	h._check(Game.story_stage_def(0).get("waves", []).size() > 0, "story stages declare fixed waves")
	h._check("boss" in Game.story_stage_def(5), "kernel stage declares its boss")
	var saved_mode := Game.mode
	var saved_state := Game.state
	var saved_stage := int(Game.get("story_stage_index")) if Game.get("story_stage_index") != null else 0
	var saved_cleared: Dictionary = Game.story_cleared.duplicate(true) if Game.get("story_cleared") is Dictionary else {}
	Game.story_cleared = {}
	h._check(bool(Game.story_stage_unlocked(0)), "first story stage is unlocked")
	h._check(not bool(Game.story_stage_unlocked(1)), "next story stage stays locked")
	Game.story_cleared["boot"] = true
	h._check(bool(Game.story_stage_unlocked(1)) and not bool(Game.story_stage_unlocked(2)), "clearing one stage unlocks only the next stage")
	Game.mode = "story"
	Game.state = Game.State.PLAYING
	var sp: Spawner = arena.spawner
	sp.stop()
	sp.debug_clear_encounter()
	for child in arena.enemy_container.get_children():
		child.queue_free()
	await h._ticks(2)
	var boot_stage: Dictionary = Game.story_stage_def(0)
	sp.start_story(arena, arena.enemy_container, boot_stage)
	h._check(bool(sp.get("story_mode")), "story spawner enters scripted mode")
	var fixed_queue: Array = sp.get("_queue")
	h._check(not fixed_queue.is_empty(), "story spawner loads a fixed queue")
	var fixed_only := true
	for kind in fixed_queue:
		if str(kind) != "drone":
			fixed_only = false
	h._check(fixed_only, "boot queue contains only its declared enemy type")
	sp.stop()
	sp.debug_clear_encounter()
	Game.mode = saved_mode
	Game.state = saved_state
	Game.story_stage_index = saved_stage
	Game.story_cleared = saved_cleared
	sp.start(arena, arena.enemy_container, 1)
	await h._ticks(3)

func _windows_test(arena: Arena) -> void:
	print("AT_STEP windows")
	var update_script: Script = load("res://src/enemies/update_loop.gd")
	var bloat_script: Script = load("res://src/enemies/bloatware.gd")
	var popup_script: Script = load("res://src/enemies/popup_orb.gd")
	var crt_script: Script = load("res://src/arena/crt_overlay.gd")
	h._check(update_script != null and bloat_script != null and popup_script != null, "Windows enemy scripts load")
	h._check(crt_script != null, "CRT overlay script loads")
	h._check(Game.story_stage_count() == 11, "Story includes three Windows and two TempleOS stages")
	var paths := ["C:\\98", "C:\\XP", "Win11"]
	for i in paths.size():
		var stage: Dictionary = Game.story_stage_def(6 + i)
		h._check(str(stage.get("path", "")) == paths[i], "Windows stage %d has the expected path" % (i + 1))
	h._check(str(Game.story_stage_def(6).get("theme", {}).get("grid_style", "")) == "crt_heavy", "C98 selects the heavy CRT profile")
	h._check(str(Game.story_stage_def(7).get("theme", {}).get("grid_style", "")) == "crt_soft", "CXP selects the soft CRT profile")
	h._check(str(Game.story_stage_def(8).get("theme", {}).get("grid_style", "")) == "clean", "Win11 disables the CRT profile")
	var sp: Spawner = arena.spawner
	var update_enemy = sp.call("_make_enemy", "update_loop")
	var bloat_enemy = sp.call("_make_enemy", "bloatware")
	h._check(update_enemy is UpdateLoopEnemy and bloat_enemy is BloatwareEnemy, "spawner creates the Windows enemy cast")
	if update_enemy != null:
		h._check(update_enemy.has_method("reinstall_duration"), "UPDATE_LOOP exposes reinstall behavior")
	if bloat_enemy != null:
		h._check(bloat_enemy.has_method("popup_count_on_death"), "BLOATWARE exposes popup drop behavior")
	if update_enemy is Node:
		update_enemy.free()
	if bloat_enemy is Node:
		bloat_enemy.free()
	h._check(arena.has_method("windows_stage_profile"), "arena exposes Windows stage profile")

func _temple_test(arena: Arena) -> void:
	print("AT_STEP temple")
	var god_script: Script = load("res://src/enemies/god_boss.gd")
	h._check(god_script != null, "GOD boss script loads")
	h._check(Game.story_stage_count() == 11, "Story includes two TempleOS stages")
	h._check(Game.STORY_DATA.act_stage_count("templeos") == 2, "TempleOS act exposes two stages")
	var paths := ["TempleOS::BOOT", "TempleOS::GOD"]
	for i in paths.size():
		var stage: Dictionary = Game.story_stage_def(9 + i)
		h._check(str(stage.get("path", "")) == paths[i], "TempleOS stage %d has the expected path" % (i + 1))
	var temple_stage := Game.story_stage_def(9)
	var god_stage := Game.story_stage_def(10)
	h._check(str(temple_stage.get("theme", {}).get("grid_style", "")) == "holy", "TempleOS uses the holy CRT profile")
	h._check(temple_stage.get("arena_size", Vector2.ZERO) == Vector2(640.0, 640.0), "TempleOS shrinks the arena to 640x640")
	h._check(str(god_stage.get("boss_kind", "")) == "god", "TempleOS final stage declares the GOD boss")
	var sp: Spawner = arena.spawner
	var god_enemy = sp.call("_make_enemy", "god")
	h._check(god_enemy is GodBoss, "spawner creates the GOD boss")
	if god_enemy is GodBoss:
		h._check(god_enemy.has_method("roll_oracle_attack"), "GOD exposes oracle attack selection")
		var old_seed := Game.rng.seed
		Game.rng.seed = 90210
		var oracle_a := str(god_enemy.call("roll_oracle_attack"))
		Game.rng.seed = 90210
		var oracle_b := str(god_enemy.call("roll_oracle_attack"))
		Game.rng.seed = old_seed
		h._check(oracle_a == oracle_b and not oracle_a.is_empty(), "GOD oracle attacks follow the gameplay RNG")
	if god_enemy is Node:
		god_enemy.free()
	h._check(arena.has_method("temple_stage_profile"), "arena exposes TempleOS stage profile")
	var old_size := Balance.arena_rect().size
	Balance.set_arena_size_override(Vector2(640.0, 640.0))
	h._check(Balance.arena_rect().size == Vector2(640.0, 640.0), "arena override changes only the active combat rectangle")
	Balance.clear_arena_size_override()
	h._check(Balance.arena_rect().size == old_size, "arena override restores the default rectangle")

func _glyph_lib_test() -> void:
	print("AT_STEP glyph_lib")
	var glyph_script: Script = load("res://src/ui/glyph_lib.gd")
	var glyph = glyph_script.new() if glyph_script != null else null
	h._check(glyph != null and glyph.has_method("draw_glyph") and glyph.has_method("glyph_kinds") and glyph.has_method("era_mix"), "glyph library exposes draw_glyph, glyph_kinds, and era_mix")
	if glyph == null or not glyph.has_method("draw_glyph"):
		return
	var required := ["drone", "lancer", "spewer", "splitter", "bulwark", "trojan", "oom", "recursor", "firewall", "bloatware", "update_loop", "page", "root", "boss", "segfault", "bluescreen", "pagefault", "god", "kernel", "daemon", "rootlet"]
	var kinds: Array = glyph.call("glyph_kinds")
	var missing := false
	for kind in required:
		if not kinds.has(kind):
			missing = true
	h._check(not missing, "glyph library covers every enemy and program kind")
	var seed_before := Game.rng.seed
	for kind in required:
		glyph.call("draw_glyph", null, kind, Vector2.ZERO, 4.0, Color.CYAN, 0.0)
		glyph.call("draw_glyph", null, kind, Vector2.ZERO, 64.0, Color.CYAN, 1.0)
	h._check(Game.rng.seed == seed_before, "glyph drawing never advances the gameplay rng")
	var mixed: Color = glyph.call("era_mix", Color.RED, Color.CYAN, 0.25)
	h._check(not mixed.is_equal_approx(Color.RED) and not mixed.is_equal_approx(Color.CYAN), "era_mix blends identity colors toward the era accent")
	var bestiary_source := str(load("res://src/ui/bestiary_panel.gd").source_code)
	var program_source := str(load("res://src/ui/program_panel.gd").source_code)
	h._check(bestiary_source.contains("GlyphLib.draw_glyph"), "bestiary detail views reuse glyph_lib")
	h._check(program_source.contains("GlyphLib.draw_glyph"), "program cards reuse glyph_lib")

func _icon_quality_test() -> void:
	print("AT_STEP icon_quality")
	var icon_script: Script = load("res://src/ui/tactical_icon.gd")
	var icon = icon_script.new() if icon_script != null else null
	h._check(icon != null and icon.has_method("icon_kinds") and icon.has_method("icon_metrics") and icon.has_method("icon_bounds"), "tactical icon exposes icon_kinds, icon_metrics, and icon_bounds")
	if icon == null or not icon.has_method("icon_kinds"):
		if icon != null:
			icon.free()
		return
	var icon_src := str(icon_script.source_code)
	var kinds: Array = icon.call("icon_kinds")
	for kind in ["settings", "bestiary", "dash", "back", "resume", "restart", "terminal", "audio", "music", "warning"]:
		h._check(kinds.has(kind), "tactical icon covers the %s kind" % kind)
		h._check(icon_src.contains("\t\t\"%s\":" % kind), "%s icon resolves to a non-empty drawing routine" % kind)
		var metrics: Dictionary = icon.call("icon_metrics", str(kind))
		h._check(bool(metrics.get("covered", false)), "%s icon has documented quality metrics" % kind)
		h._check(float(metrics.get("min_stroke", 0.0)) >= 1.5, "%s icon documents a minimum stroke of at least 1.5" % kind)
		h._check(float(metrics.get("contrast", 0.0)) >= 0.55, "%s icon documents panel contrast of at least 0.55" % kind)
		var bounds: Rect2 = icon.call("icon_bounds", str(kind))
		for side in [24.0, 52.0]:
			var abs_bounds := Rect2(bounds.position * side, bounds.size * side)
			h._check(Rect2(Vector2.ZERO, Vector2(side, side)).encloses(abs_bounds.grow(-0.5)), "%s icon silhouette stays contained at %.0fpx" % [kind, side])
	icon.free()
	var patch_script: Script = load("res://src/ui/patch_card.gd")
	h._check(patch_script != null and patch_script.has_method("patch_icon_family") and patch_script.has_method("patch_icon_metrics"), "patch card exposes patch_icon_family and patch_icon_metrics")
	if patch_script == null or not patch_script.has_method("patch_icon_family"):
		return
	var patch_src := str(patch_script.source_code)
	for family in ["_draw_damage_glyph", "_draw_fire_glyph", "_draw_defense_glyph", "_draw_utility_glyph", "_draw_movement_glyph", "_draw_economy_glyph"]:
		h._check(patch_src.contains("func %s" % family), "patch card draws the %s family" % family.trim_prefix("_draw_").trim_suffix("_glyph"))
	for id in Game.PATCH_CODES:
		var family: String = patch_script.call("patch_icon_family", str(id))
		h._check(["damage", "fire", "defense", "utility", "movement", "economy"].has(family), "%s patch icon belongs to a documented family" % str(id))
		var pmetrics: Dictionary = patch_script.call("patch_icon_metrics", str(id))
		h._check(bool(pmetrics.get("covered", false)), "%s patch icon resolves to a non-empty drawing routine" % str(id))
		h._check(float(pmetrics.get("min_stroke", 0.0)) >= 2.0, "%s patch icon documents a minimum stroke of at least 2.0" % str(id))
		h._check(float(pmetrics.get("contrast", 0.0)) >= 0.55, "%s patch icon documents panel contrast of at least 0.55" % str(id))
	var hex_rect := Rect2(Vector2(24.0, 123.0), Vector2(68.0, 68.0))
	h._check(Rect2(Vector2.ZERO, Vector2(280.0, 330.0)).encloses(hex_rect), "patch hex icon geometry stays contained in the 280x330 patch card")
	h._check(icon_script.has_method("raster_path") and patch_script.has_method("patch_raster_path"), "icon raster registries keep the code-drawn fallback")
	var probe_path: String = icon_script.call("raster_path", "resume")
	h._check(probe_path.is_empty() or ResourceLoader.exists(probe_path), "raster registry only resolves existing assets")

func _raster_trial_test() -> void:
	print("AT_STEP raster_trial")
	var icon_script: Script = load("res://src/ui/tactical_icon.gd")
	var patch_script: Script = load("res://src/ui/patch_card.gd")
	h._check(icon_script != null and icon_script.has_method("raster_path"), "tactical icon exposes the raster registry")
	h._check(patch_script != null and patch_script.has_method("patch_raster_path"), "patch card exposes the raster registry")
	if icon_script == null or patch_script == null or not icon_script.has_method("raster_path") or not patch_script.has_method("patch_raster_path"):
		return
	var icon_resolved := 0
	var icon_fallback := 0
	for kind in icon_script.call("icon_kinds"):
		var path: String = icon_script.call("raster_path", str(kind))
		if path.is_empty():
			icon_fallback += 1
			continue
		icon_resolved += 1
		var tex: Texture2D = load(path)
		h._check(tex != null, "%s raster resolves to a loadable texture" % str(kind))
	h._check(icon_resolved > 0, "generated ui icon rasters resolve through the registry when the asset exists")
	h._check(icon_fallback > 0, "ui icon kinds without a generated asset keep the code-drawn fallback")
	var patch_resolved := 0
	var patch_fallback := 0
	for id in Game.PATCH_CODES:
		var path: String = patch_script.call("patch_raster_path", str(id))
		if path.is_empty():
			patch_fallback += 1
			continue
		patch_resolved += 1
		var tex: Texture2D = load(path)
		h._check(tex != null, "patch %s raster resolves to a loadable texture" % str(id))
	h._check(patch_resolved >= 6, "the six generated patch-family rasters resolve through the registry")
	h._check(patch_fallback > 0, "patch ids without a generated asset keep the code-drawn fallback")
	h._check(str(icon_script.source_code).contains("match _kind"), "tactical icon keeps the code-drawn draw dispatch")
	h._check(str(patch_script.source_code).contains("match patch_icon_family"), "patch card keeps the code-drawn family dispatch")
	h._check(str(icon_script.source_code).contains("framed: bool = false"), "tactical icon configure exposes the framed overlay switch (default off)")

func _charm_terminal_test(arena: Arena) -> void:
	print("AT_STEP charm_terminal")
	var terminal_script: Script = load("res://src/ui/terminal_panel.gd")
	h._check(terminal_script != null, "pause terminal script loads")
	h._check(Game.has_method("log_event") and Game.has_method("dmesg_lines"), "game exposes run event log")
	h._check(Game.has_method("consume_terminal_heal"), "game exposes one-use terminal heal")
	h._check(arena.has_method("execute_terminal_command"), "arena exposes terminal command router")
	var terminal_button_found := false
	for child in arena._pause_panel.get_children():
		if child is Button and child.text == "OPEN TERMINAL":
			terminal_button_found = true
	h._check(terminal_button_found and arena.get("_terminal_panel") != null, "pause exposes the terminal entry point")
	if terminal_script == null or not arena.has_method("execute_terminal_command"):
		return
	var saved_mode := Game.mode
	var saved_state := Game.state
	var saved_stats: Dictionary = Game.stats.duplicate(true)
	var saved_events: Array = Game.event_log.duplicate(true) if Game.get("event_log") is Array else []
	var saved_terminal_heal_used := bool(Game.get("terminal_heal_used"))
	var saved_patch_levels: Dictionary = Game.patch_levels.duplicate(true)
	Game.mode = "classic"
	Game.state = Game.State.PLAYING
	Game.wave = 3
	Game.stats = {"time": 12.5, "kills": 4, "shots": 10, "hits": 6, "damage": 1, "wave": 3, "boss_kills": 0, "heals": {}}
	Game.event_log = []
	Game.terminal_heal_used = false
	Game.log_event("TEST EVENT")
	var dmesg: Array = Game.dmesg_lines(4)
	h._check(dmesg.size() == 1 and str(dmesg[0]).contains("TEST EVENT"), "dmesg formats the current run event log")
	h._check(str(arena.execute_terminal_command("help")).contains("sudo heal"), "terminal help lists recovery command")
	h._check(str(arena.execute_terminal_command("top")).contains("CYCLE 03"), "terminal top reports current cycle")
	h._check(str(arena.execute_terminal_command("man drone")).contains("DRONE"), "terminal man returns a bestiary entry")
	h._check(str(arena.execute_terminal_command("dmesg")).contains("TEST EVENT"), "terminal dmesg returns run events")
	if arena.player != null and is_instance_valid(arena.player):
		var old_hp := arena.player.hp
		arena.player.hp = maxi(1, arena.player.max_hp - 1)
		var heal_result := str(arena.execute_terminal_command("sudo heal"))
		h._check(heal_result.contains("granted") and arena.player.hp == old_hp, "sudo heal restores one integrity")
		var second_heal := str(arena.execute_terminal_command("sudo heal"))
		h._check(second_heal.contains("PERMISSION DENIED"), "sudo heal is limited to once per run")
		Game.mode = "onehp"
		Game.terminal_heal_used = false
		arena.player.hp = 1
		h._check(str(arena.execute_terminal_command("sudo heal")).contains("PERMISSION DENIED"), "one hp mode rejects terminal healing")
		arena.player.hp = arena.player.max_hp
	Game.mode = saved_mode
	Game.state = saved_state
	Game.wave = int(saved_stats.get("wave", Game.wave))
	Game.stats = saved_stats
	Game.event_log = saved_events
	Game.terminal_heal_used = saved_terminal_heal_used
	Game.patch_levels = saved_patch_levels

func _charm_speedrun_test(arena: Arena) -> void:
	print("AT_STEP charm_speedrun")
	h._check(Game.has_method("unlock_achievement") and Game.has_method("core_dump_text"), "game exposes achievements and core dump data")
	h._check(Game.has_method("run_seed_text"), "game exposes visible run seed")
	h._check(arena.hud != null and arena.hud.has_method("run_info_text"), "hud exposes speedrun info text")
	h._check(arena.has_method("background_corruption_for_wave"), "arena exposes permanent grid corruption curve")
	h._check(arena.has_method("restart_hold_duration"), "arena exposes hold-to-restart timing")
	if not Game.has_method("unlock_achievement"):
		return
	var achievement_disk: Dictionary = h._config_section_snapshot("achievements")
	var saved_achievements: Dictionary = Game.achievements.duplicate(true) if Game.get("achievements") is Dictionary else {}
	var saved_stats: Dictionary = Game.stats.duplicate(true)
	var saved_events: Array = Game.event_log.duplicate(true) if Game.get("event_log") is Array else []
	var saved_seed := Game.run_seed
	Game.achievements = {}
	Game.stats = {"time": 42.25, "kills": 1, "shots": 8, "hits": 4, "damage": 2, "wave": 4, "boss_kills": 0, "heals": {}}
	Game.event_log = []
	Game.run_seed = 123456
	var unlocked := bool(Game.unlock_achievement("first_blood"))
	h._check(unlocked and Game.achievements.has("first_blood"), "first achievement unlocks once")
	h._check(not bool(Game.unlock_achievement("first_blood")), "duplicate achievement stays silent")
	h._check(str(Game.dmesg_lines(8)).contains("achievement: FIRST_BLOOD enabled"), "achievement is recorded in dmesg")
	h._check(str(Game.core_dump_text()).contains("SEGFAULT AT player.hp=0") and str(Game.core_dump_text()).contains("123456"), "core dump includes death marker and build seed")
	h._check(Game.run_seed_text() == "SEED 123456", "run seed has compact HUD text")
	var old_info: bool = bool(Sfx.show_run_info)
	Sfx.show_run_info = true
	h._check(str(arena.hud.run_info_text()).contains("SEED 123456") and str(arena.hud.run_info_text()).contains("00:42"), "speedrun HUD exposes seed and timer")
	Sfx.show_run_info = old_info
	h._check(float(arena.call("background_corruption_for_wave", 1)) == 0.0, "grid starts uncorrupted")
	h._check(float(arena.call("background_corruption_for_wave", 20)) > 0.0, "grid corruption advances with waves")
	h._check(float(arena.call("restart_hold_duration")) > 0.0, "hold-to-restart uses a positive safety delay")
	Game.achievements = saved_achievements
	Game.stats = saved_stats
	Game.event_log = saved_events
	Game.run_seed = saved_seed
	h._restore_config_section("achievements", achievement_disk)


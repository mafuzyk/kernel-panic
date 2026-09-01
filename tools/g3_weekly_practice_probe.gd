extends Node

## G3 focused probe. It starts as a contract probe so the requested weekly and
## practice boundaries fail closed before production code exists.

var _fails := 0

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PROBE_PASS ", message)
	else:
		_fails += 1
		print("PROBE_FAIL ", message)

func _run() -> void:
	var catalog_script: Script = load("res://src/gameplay/weekly_mutator_catalog.gd")
	_check(catalog_script != null, "weekly mutator catalog loads")
	_check(Game.has_method("weekly_seed"), "Game exposes the deterministic weekly seed")
	_check(Game.has_method("weekly_mutator"), "Game exposes the weekly preview")
	_check(Game.has_method("weekly_mutator_id"), "Game exposes the active weekly mutator id")
	_check(Game.has_method("practice_unlocked"), "Game exposes Practice unlock state")
	_check(Game.has_method("practice_max_wave"), "Game exposes the Practice wave ceiling")
	_check(Game.has_method("set_practice_wave"), "Game exposes Practice wave selection")

	if catalog_script != null:
		var definitions: Array = catalog_script.definitions()
		_check(definitions.size() >= 2, "weekly catalog has more than one conservative mutator")
		var ids: Array[String] = []
		for definition in definitions:
			var id := str(definition.get("id", ""))
			ids.append(id)
			_check(not id.is_empty(), "every weekly mutator has an id")
			_check(str(definition.get("tag", "")) in ["spawn", "movement", "damage", "cooldown", "rewards"], "mutator tag uses the contract vocabulary")
			_check(float(definition.get("multiplier", 0.0)) > 1.0, "mutator multiplier is explicit")
		_check(ids.size() == definitions.size() and ids.size() == ids.duplicate().size(), "weekly mutator ids are unique")
		var seed_a: Dictionary = catalog_script.for_seed(12345)
		var seed_b: Dictionary = catalog_script.for_seed(12345)
		_check(seed_a.get("id", "") == seed_b.get("id", ""), "the same weekly seed selects the same mutator")
		_check(not catalog_script.for_seed(12345).is_empty(), "every valid weekly seed has a preview")

	var saved_mode := Game.mode
	var saved_best_wave := int(Game.get("best_endless_wave") if Game.get("best_endless_wave") != null else 0)
	var saved_practice_wave := int(Game.get("practice_wave") if Game.get("practice_wave") != null else 1)
	Game.mode = "weekly"
	if Game.has_method("weekly_mutator_id"):
		var weekly_id: String = str(Game.weekly_mutator_id())
		_check(not weekly_id.is_empty(), "weekly mode has exactly one active mutator")
		var weekly_context := Game.run_context()
		_check(weekly_context.mutators() == [weekly_id], "weekly RunContext carries the selected mutator")
		_check(weekly_context.uses_deterministic_seed(), "weekly context remains deterministic")
	var menu_source := FileAccess.get_file_as_string("res://src/ui/menu.gd")
	_check(menu_source.contains("PRACTICE") and menu_source.contains("weekly_mutator"), "menu exposes Practice and weekly preview behavior")
	var balance_source := FileAccess.get_file_as_string("res://src/autoload/balance.gd")
	_check(balance_source.contains("weekly_enemy_speed_multiplier"), "Balance owns the weekly movement modifier boundary")
	_check(balance_source.contains("weekly_wave_budget_multiplier"), "Balance owns the weekly spawn modifier boundary")
	_check(is_equal_approx(Balance.weekly_enemy_speed_multiplier("swift_daemons"), 1.2), "movement mutator resolves to the declared 20 percent speed multiplier")
	_check(is_equal_approx(Balance.weekly_enemy_speed_multiplier("rush_hour"), 1.0), "spawn mutator does not leak into movement")
	_check(is_equal_approx(Balance.weekly_wave_budget_multiplier("rush_hour"), 1.2), "spawn mutator resolves to the declared 20 percent budget multiplier")
	_check(is_equal_approx(Balance.weekly_wave_budget_multiplier("swift_daemons"), 1.0), "movement mutator does not leak into spawn budget")
	var probe_enemy := DroneEnemy.new()
	Game.mode = "weekly"
	probe_enemy.configure(1.0, false)
	var active_mutator: Dictionary = Game.weekly_mutator()
	if active_mutator.get("tag", "") == "movement":
		_check(is_equal_approx(probe_enemy.speed, 125.0 * 1.2), "active movement mutator changes regular enemy speed")
	else:
		_check(is_equal_approx(probe_enemy.speed, 125.0), "inactive movement mutator leaves regular enemy speed unchanged")
	var probe_boss := RootBoss.new()
	probe_boss.configure(1.0, false)
	if active_mutator.get("tag", "") == "movement":
		_check(is_equal_approx(probe_boss.speed, 55.0 * 1.2), "active movement mutator changes boss speed")
	else:
		_check(is_equal_approx(probe_boss.speed, 55.0), "inactive movement mutator leaves boss speed unchanged")
	var normal_budget := Balance.wave_budget(3)
	var expected_budget := int(floor(float(normal_budget) * 1.2)) if active_mutator.get("tag", "") == "spawn" else normal_budget
	_check(Balance.difficulty_wave_budget(3) == expected_budget, "active weekly spawn mutator changes only the wave budget")
	probe_enemy.free()
	probe_boss.free()

	if Game.has_method("practice_unlocked") and Game.has_method("practice_max_wave") and Game.has_method("set_practice_wave"):
		Game.mode = "practice"
		Game.best_endless_wave = 0
		Game.practice_wave = 1
		_check(not Game.practice_unlocked(), "Practice stays locked before an Endless wave is reached")
		Game.best_endless_wave = 4
		_check(Game.practice_unlocked() and Game.practice_max_wave() == 4, "Practice unlock and ceiling follow the highest Endless wave")
		Game.set_practice_wave(99)
		_check(Game.practice_wave == 4, "Practice selection clamps to the unlocked ceiling")
		Game.set_practice_wave(2)
		_check(Game.practice_wave == 2, "Practice selection accepts an unlocked wave")
		var practice_context := Game.run_context()
		_check(not practice_context.writes_records(), "Practice is explicitly non-recording")
		_check(practice_context.mutators().is_empty(), "Practice does not inherit the weekly mutator")

	var menu_scene: PackedScene = load("res://src/ui/menu.tscn")
	var menu: Control = menu_scene.instantiate() if menu_scene != null else null
	if menu != null:
		add_child(menu)
		await get_tree().process_frame
		Game.mode = "weekly"
		menu._refresh_mode_ui()
		_check(menu._mode_info.visible and menu._mode_info.text.contains(Game.weekly_mutator_title()), "main menu visibly previews the current Weekly mutator")
		Game.mode = "practice"
		Game.best_endless_wave = 4
		Game.practice_wave = 2
		menu._refresh_mode_ui()
		_check(menu._practice_wave_btn.visible and menu._practice_wave_btn.text == "PRACTICE WAVE: 02 / 04", "main menu exposes the unlocked Practice wave selector")
		var compact_layout: Dictionary = menu.menu_layout_for_viewport(Vector2(432.0, 720.0))
		var compact_info: Rect2 = compact_layout["mode_info"]
		_check(compact_info.position.x >= 0.0 and compact_info.end.x <= 432.0, "Practice selector remains inside the compact viewport")
		menu.size = Vector2(432.0, 720.0)
		Game.mode = "weekly"
		menu._refresh_mode_ui()
		_check(menu._mode_info.text.length() < 64 and menu._mode_info.text.contains(Game.weekly_mutator_description()), "Weekly preview compresses its copy on compact screens")
		var overflow: Array = menu.text_overflow_report()
		for entry in overflow:
			_check(bool(entry.get("fits", false)), "menu text overflow report passes")
		menu.queue_free()
		await get_tree().process_frame

	var old_save_override := Sfx._settings_path_override
	Sfx._settings_path_override = "user://g3-practice-records.cfg"
	var isolated_save := ConfigFile.new()
	isolated_save.set_value("run", "best_classic", 321)
	isolated_save.set_value("run", "best_endless_wave", 2)
	isolated_save.save(Sfx.SAVE_PATH)
	var before_practice_file := FileAccess.get_file_as_string(Sfx.SAVE_PATH)
	var saved_state := Game.state
	var saved_score := Game.score
	var saved_wave := Game.wave
	var saved_stats: Dictionary = Game.stats.duplicate(true)
	Game.mode = "practice"
	Game.state = Game.State.PLAYING
	Game.score = 999999
	Game.wave = 8
	Game.stats = {"wave": 8, "time": 2.0, "kills": 1, "shots": 1, "hits": 1, "damage": 0, "boss_kills": 0, "heals": {}}
	Game.end_run()
	var after_practice_file := FileAccess.get_file_as_string(Sfx.SAVE_PATH)
	_check(before_practice_file == after_practice_file, "Practice run leaves records untouched")
	Game.mode = "classic"
	Game.state = Game.State.PLAYING
	Game.score = 0
	Game.wave = 6
	Game.stats = {"wave": 6, "time": 2.0, "kills": 1, "shots": 1, "hits": 1, "damage": 0, "boss_kills": 0, "heals": {}}
	Game.best_endless_wave = 2
	Game.end_run()
	var classic_save := ConfigFile.new()
	classic_save.load(Sfx.SAVE_PATH)
	_check(int(classic_save.get_value("run", "best_endless_wave", 0)) == 6, "Classic run persists the highest Endless wave reached")
	Game.state = saved_state
	Game.score = saved_score
	Game.wave = saved_wave
	Game.stats = saved_stats
	Sfx._settings_path_override = old_save_override

	if Game.has_method("weekly_mutator_id"):
		Game.mode = "weekly"
		var weekly_context_again := Game.run_context()
		_check(weekly_context_again.mutators().size() == 1, "switching back to Weekly restores its single mutator")

	Game.mode = saved_mode
	if Game.get("best_endless_wave") != null:
		Game.best_endless_wave = saved_best_wave
	if Game.get("practice_wave") != null:
		Game.practice_wave = saved_practice_wave
	_finish()

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

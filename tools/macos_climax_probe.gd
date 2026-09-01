extends Node

## M4 focused probe: the macOS climax must spawn its named boss and commit a
## stable reward atomically enough that a failed story save cannot grant it.

var _fails := 0

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PROBE_PASS ", message)
	else:
		_fails += 1
		print("PROBE_FAIL ", message)

func _until(condition: Callable, timeout_s: float, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await get_tree().process_frame
	_check(false, "timeout waiting for " + label)
	return false

func _find_script_child(container: Node, script_path: String) -> Node:
	for child in container.get_children():
		if child.get_script() != null and child.get_script().resource_path == script_path:
			return child
	return null

func _run() -> void:
	var boss_script: Script = load("res://src/enemies/permission_root_boss.gd")
	var spawner_source := FileAccess.get_file_as_string("res://src/arena/spawner.gd")
	var game_source := FileAccess.get_file_as_string("res://src/autoload/game.gd")
	_check(boss_script != null, "Permission Root boss script loads")
	_check(spawner_source.contains("PermissionRootBoss") and spawner_source.contains("boss_variant"), "story spawner selects the named climax variant")
	_check(game_source.contains("story_rewards") and game_source.contains("_persist_story_completion"), "Game owns a persisted story reward transaction")
	var final_stage := Game.story_stage_def(14)
	_check(str(final_stage.get("id", "")) == "mac_modern", "macOS climax is the final story node")
	_check(str(final_stage.get("boss_variant", "")) == "permission_root" and str(final_stage.get("reward_id", "")) == "macos_modern_clear", "climax declares a stable boss variant and reward id")

	if boss_script != null:
		var boss = boss_script.new()
		boss.boss_index = 3
		boss.configure(1.0, false)
		_check(str(boss.boss_title) == "PERMISSION ROOT", "variant owns its player-facing boss identity")
		_check(str(boss.boss_quote) != "" and boss.has_method("permission_telegraph_snapshot"), "variant exposes a readable permission attack contract")
		boss.hp = 1
		boss._step_desperation(0.0)
		_check(bool(boss.desperation_active) and int(boss.desperation_trigger_count) == 1, "variant inherits the shared desperation transition")
		boss.free()

	var container := Node2D.new()
	var arena := Node2D.new()
	var spawner := Spawner.new()
	add_child(container)
	add_child(arena)
	add_child(spawner)
	var boss_stage := final_stage.duplicate(true)
	boss_stage["waves"] = [["boss"]]
	_check(spawner.start_story(arena, container, boss_stage), "real story spawner accepts the climax definition")
	var spawned: Node = null
	await _until(func() -> bool:
		return _find_script_child(container, boss_script.resource_path) != null
	, 5.0, "Permission Root spawn")
	spawned = _find_script_child(container, boss_script.resource_path)
	print("PROBE_INFO boss_children=%d running=%s awaiting=%s names=%s scripts=%s" % [container.get_child_count(), str(spawner.get("_running")), str(spawner.get("_awaiting_boss")), str(container.get_children().map(func(child: Node) -> String: return child.name + ":" + child.get_class())), str(container.get_children().map(func(child: Node) -> String: return str(child.get_script().resource_path) if child.get_script() != null else "none"))])
	_check(spawned != null, "climax creates a boss on the real story path")
	if spawned != null:
		_check(spawned.get_script() == boss_script and str(spawned.boss_title) == "PERMISSION ROOT", "real story path preserves the Permission Root variant")
		_check(spawned.has_method("permission_telegraph_snapshot"), "spawned boss exposes the telegraph snapshot")
	spawner.stop()
	container.queue_free()
	arena.queue_free()
	spawner.queue_free()

	var saved_mode = Game.mode
	var saved_state = Game.state
	var saved_index := Game.story_stage_index
	var saved_score := Game.score
	var saved_stats: Dictionary = Game.stats.duplicate(true)
	var saved_cleared: Dictionary = Game.story_cleared.duplicate(true)
	var saved_best: Dictionary = Game.story_best.duplicate(true)
	var saved_rewards: Dictionary = Game.story_rewards.duplicate(true)
	var saved_temple := Game.temple_rainbow_unlocked
	var saved_new_best := Game.new_best

	Game.mode = "story"
	Game.state = Game.State.PLAYING
	Game.story_stage_index = 14
	Game.score = 4321
	Game.stats = {"kills": 7, "time": 12.3}
	Game.story_cleared = {"boot": true}
	Game.story_best = {}
	Game.story_rewards = {}
	Game.new_best = false
	_check(Game.complete_story_stage(), "story completion accepts the macOS climax")
	_check(bool(Game.story_cleared.get("mac_modern", false)), "climax marks its stable stage id")
	_check(bool(Game.story_rewards.get("macos_modern_clear", false)), "climax grants its stable reward id")
	var transferred := Game.export_save_string()
	Game.story_rewards = {}
	_check(Game.import_save_string(transferred), "save transfer accepts the reward-bearing payload")
	_check(bool(Game.story_rewards.get("macos_modern_clear", false)), "reward survives save export and import")

	Game.mode = "story"
	Game.state = Game.State.PLAYING
	Game.story_stage_index = 14
	Game.score = 9999
	Game.stats = {"kills": 1, "time": 1.0}
	Game.story_cleared = {"boot": true}
	Game.story_best = {"boot": 111}
	Game.story_rewards = {"macos_history_route": true}
	var prior_cleared := Game.story_cleared.duplicate(true)
	var prior_best := Game.story_best.duplicate(true)
	var prior_rewards: Dictionary = Game.story_rewards.duplicate(true)
	var prior_save_override := Sfx._settings_path_override
	Sfx._settings_path_override = "/proc/kernel_panic_m4_missing/save.cfg"
	_check(not Game.complete_story_stage(), "failed story save rejects completion")
	_check(Game.story_cleared == prior_cleared and Game.story_best == prior_best and Game.story_rewards == prior_rewards, "failed story save preserves prior progress and grants no reward")
	Sfx._settings_path_override = prior_save_override

	Game.mode = saved_mode
	Game.state = saved_state
	Game.story_stage_index = saved_index
	Game.score = saved_score
	Game.stats = saved_stats
	Game.story_cleared = saved_cleared
	Game.story_best = saved_best
	Game.story_rewards = saved_rewards
	Game.temple_rainbow_unlocked = saved_temple
	Game.new_best = saved_new_best
	_finish()

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

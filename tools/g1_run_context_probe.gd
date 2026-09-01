extends Node

## G1 contract probe. It is intentionally added before RunContext so the
## first execution fails closed when the boundary does not exist yet.

const RunContextScript = preload("res://src/gameplay/run_context.gd")

var _fails := 0

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PROBE_PASS ", message)
	else:
		_fails += 1
		print("PROBE_FAIL ", message)

func _context(mode_id: String, stage_id := "", mutators: Array[String] = []) -> RefCounted:
	return RunContextScript.new(mode_id, stage_id, mutators)

func _run() -> void:
	_check(RunContextScript != null, "run context script loads")
	if RunContextScript == null:
		_finish()
		return
	var classic := _context("classic")
	_check(classic.mode_id() == "classic", "classic mode identity is explicit")
	_check(classic.stage_id().is_empty(), "classic has no story stage identity")
	_check(classic.mutators().is_empty(), "classic has no implicit mutators")
	_check(classic.writes_records(), "classic preserves record writing")
	_check(not classic.uses_deterministic_seed(), "classic remains randomly seeded")

	var story := _context("story", "boot")
	_check(story.mode_id() == "story" and story.stage_id() == "boot", "story carries its stage identity")
	_check(story.writes_records(), "story preserves progression persistence")
	_check(not story.uses_deterministic_seed(), "story remains randomly seeded")

	var weekly := _context("weekly")
	_check(weekly.mode_id() == "weekly" and weekly.writes_records(), "weekly identity and records are explicit")
	_check(weekly.uses_deterministic_seed(), "weekly deterministic seed capability is explicit")

	var onehp := _context("onehp")
	_check(onehp.mode_id() == "onehp" and onehp.writes_records(), "onehp preserves record writing")

	var practice := _context("practice")
	_check(practice.mode_id() == "practice" and not practice.writes_records(), "practice is reserved and record-safe")
	_check(not practice.uses_deterministic_seed(), "practice has no unimplemented seed promise")

	var unknown := _context("not-a-mode", "phantom", ["speed", "speed", "", "damage"])
	_check(unknown.mode_id() == "classic" and unknown.stage_id().is_empty(), "unknown mode normalizes to safe classic")
	_check(unknown.mutators() == ["speed", "damage"], "mutators normalize order and remove duplicates")

	var source := {"mode": "story", "stage_id": "mem", "mutators": ["speed", "armor", "speed"], "writes_records": true, "deterministic": false}
	var from_snapshot: RefCounted = RunContextScript.from_snapshot(source)
	_check(from_snapshot.mode_id() == "story" and from_snapshot.stage_id() == "mem", "snapshot restores mode and stage")
	_check(from_snapshot.mutators() == ["speed", "armor"], "snapshot restores normalized mutators")
	var copy: Dictionary = from_snapshot.snapshot()
	copy["mode"] = "practice"
	copy["mutators"].append("corrupt")
	_check(from_snapshot.mode_id() == "story" and from_snapshot.mutators() == ["speed", "armor"], "snapshot mutation cannot alter live context")
	var mutator_copy: Array[String] = from_snapshot.mutators()
	mutator_copy.append("corrupt")
	_check(from_snapshot.mutators() == ["speed", "armor"], "mutator accessor returns a copy")

	var saved_mode := Game.mode
	var saved_stage := Game.story_stage_index
	Game.mode = "story"
	Game.story_stage_index = 3
	var game_context: RefCounted = RunContextScript.from_game(Game)
	_check(game_context.mode_id() == "story" and game_context.stage_id() == Game.story_stage_id(3), "Game adapter resolves active story stage")
	Game.mode = "weekly"
	var weekly_context: RefCounted = RunContextScript.from_game(Game)
	_check(weekly_context.mode_id() == "weekly" and weekly_context.uses_deterministic_seed(), "Game adapter resolves weekly determinism")
	Game.mode = saved_mode
	Game.story_stage_index = saved_stage

	var delegated: RefCounted = Game.run_context()
	_check(delegated.mode_id() == RunContextScript.from_game(Game).mode_id(), "Game exposes compatibility context accessor")
	_check(Game.mode_id() == delegated.mode_id(), "Game mode_id delegates to context")
	_check(Game.stage_id() == delegated.stage_id(), "Game stage_id delegates to context")
	_check(Game.mutators() == delegated.mutators(), "Game mutators delegates to context")
	_check(Game.writes_records() == delegated.writes_records(), "Game writes_records delegates to context")
	_check(Game.uses_deterministic_seed() == delegated.uses_deterministic_seed(), "Game deterministic seed delegates to context")

	var saved_file := FileAccess.get_file_as_string(Sfx.SAVE_PATH) if FileAccess.file_exists(Sfx.SAVE_PATH) else "<missing>"
	var saved_state := Game.state
	var saved_score := Game.score
	var saved_stats: Dictionary = Game.stats.duplicate(true)
	var saved_achievements: Dictionary = Game.achievements.duplicate(true)
	Game.mode = "practice"
	Game.state = Game.State.PLAYING
	Game.score = 999999
	Game.stats = {"wave": 7, "time": 3.0, "kills": 1, "shots": 1, "hits": 1, "damage": 0, "boss_kills": 0, "heals": {}}
	Game.achievements = {}
	var practice_achievement := Game.unlock_achievement("first_blood")
	Game.end_run()
	var practice_file := FileAccess.get_file_as_string(Sfx.SAVE_PATH) if FileAccess.file_exists(Sfx.SAVE_PATH) else "<missing>"
	_check(not practice_achievement and saved_file == practice_file, "practice run and achievements do not write records")
	Game.state = saved_state
	Game.score = saved_score
	Game.stats = saved_stats
	Game.achievements = saved_achievements
	Game.mode = saved_mode
	_finish()

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

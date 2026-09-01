extends Node

## M1 red/green probe for the separate macOS history act catalog and unlock
## contract. It does not claim the route is playable until the later M4 probe.

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
	var act_script: Script = load("res://src/story/acts/macos_act.gd") as Script
	var dialogue_script: Script = load("res://src/story/acts/macos_dialogue.gd") as Script
	var profiles_script: Script = load("res://src/story/acts/macos_profiles.gd") as Script
	var story_source := FileAccess.get_file_as_string("res://src/story/story_data.gd")
	var game_source := FileAccess.get_file_as_string("res://src/autoload/game.gd")
	_check(act_script != null, "macOS act catalog exists")
	_check(dialogue_script != null and profiles_script != null, "macOS dialogue and era profile catalogs exist")
	_check(story_source.contains("macos_act.gd"), "StoryData aggregates the macOS act through a compatibility facade")
	_check(game_source.contains("story_act_unlocked") and game_source.contains("macos"), "Game exposes an explicit macOS act unlock contract")
	if act_script == null:
		_finish()
		return
	_check(int(act_script.stage_count()) == 4, "macOS act contains four authored stages")
	var game := get_node_or_null("/root/Game")
	if game != null and game.has_method("story_stage_count"):
		_check(int(game.story_stage_count()) == 15, "live StoryData exposes the original route plus four macOS stages")
	var expected_ids := ["mac_classic", "mac_aqua", "mac_darwin", "mac_modern"]
	_check(act_script.stage_ids() == expected_ids, "macOS stages have stable ordered IDs")
	for index in int(act_script.stage_count()):
		var stage: Dictionary = act_script.stage_at(index)
		_check(str(stage.get("act", "")) == "macos", "stage %d belongs to the macOS act" % index)
		_check(not str(stage.get("title", "")).is_empty() and not str(stage.get("intro", "")).is_empty(), "stage %d resolves player-facing narrative copy" % index)
		_check(stage.get("klog", []).size() >= 3 and stage.get("theme", {}).has("grid_style"), "stage %d has klog and era profile" % index)
		_check(stage.get("waves", []).size() >= 4, "stage %d has a fixed teachable wave list" % index)
	_check(str(act_script.stage_at(3).get("boss_kind", "")) == "boss", "final macOS stage declares a compatible boss kind")
	_check(str(act_script.stage_at(3).get("reward_id", "")) == "macos_modern_clear", "final macOS stage declares a stable reward ID")
	if game != null and game.has_method("story_act_unlocked"):
		var old_cleared: Dictionary = game.story_cleared.duplicate(true)
		game.story_cleared = {}
		_check(not bool(game.story_act_unlocked("macos")), "macOS remains locked before the prerequisite act")
		game.story_cleared["temple_god"] = true
		_check(bool(game.story_act_unlocked("macos")), "TempleOS completion unlocks the macOS act")
		_check(bool(game.story_stage_unlocked(11)), "TempleOS completion unlocks the first macOS stage")
		game.story_cleared = old_cleared
	else:
		_check(false, "Game exposes the live macOS unlock query")
	_finish()

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

extends Node

## A5 compatibility checkpoint. Exercises the live ConfigFile path and the
## public Game transfer helpers under an isolated XDG user-data directory.

var _fails := 0
var _finished := false
var _watchdog_fired := false

const PROGRESS_BYTES := """[run]
best_classic=420
best_onehp=17
onehp_unlocked=true
program="daemon"

[game]
mode="story"
difficulty="hard"

[weekly]
id="W-test"
best=77
last_id="W-old"
last_best=66

[story]
cleared={"boot":true}
best={"boot":420}
temple_rainbow_unlocked=true

[programs]
unlocked={"kernel":true,"daemon":true}

[achievements]
unlocked={"first_blood":true}

[bestiary]
seen={"drone":true}
"""
const OPTIONAL_OLD_BYTES := """[run]
best=99

[game]
mode="classic"
"""

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PROBE_PASS ", message)
	else:
		_fails += 1
		print("PROBE_FAIL ", message)

func _run() -> void:
	_watchdog.call_deferred()
	var game: Node = get_node_or_null("/root/Game")
	var sfx: Node = get_node_or_null("/root/Sfx")
	_check(game != null and sfx != null, "real Game and Sfx autoloads are available")
	if game == null or sfx == null:
		_finish()
		return

	var save_path := str(sfx.SAVE_PATH)
	_check(save_path == "user://kernel_panic.cfg", "probe uses the real save path")
	_check(OS.get_environment("XDG_DATA_HOME") != "", "probe runs with isolated XDG_DATA_HOME")

	_run_fresh_profile(game, save_path)
	_run_progress_profile(game, save_path)
	_run_optional_compatibility(game, save_path)
	_run_round_trip(game, save_path)
	_run_invalid_inputs(game, save_path)
	_finish()

func _run_fresh_profile(game: Node, save_path: String) -> void:
	_remove_save(save_path)
	game._load_run_config()
	_check(not FileAccess.file_exists(save_path), "fresh profile does not require a save file")
	_check(int(game.best) == 0 and str(game.program) == "kernel", "fresh profile uses safe defaults")
	_check(game.story_cleared == {} and game.story_best == {}, "fresh profile has empty story progress")

func _run_progress_profile(game: Node, save_path: String) -> void:
	_write_bytes(save_path, PROGRESS_BYTES.to_utf8_buffer())
	game._load_run_config()
	_check(int(game.best) == 420 and str(game.program) == "daemon", "progress profile loads real run fields")
	_check(bool(game.story_cleared.get("boot", false)) and int(game.story_best.get("boot", 0)) == 420, "progress profile loads story progress")
	_check(bool(game.temple_rainbow_unlocked), "progress profile loads story unlock")

func _run_optional_compatibility(game: Node, save_path: String) -> void:
	_write_bytes(save_path, OPTIONAL_OLD_BYTES.to_utf8_buffer())
	game._load_run_config()
	_check(int(game.best) == 99, "old best key remains readable")
	_check(str(game.program) == "kernel" and game.story_cleared == {} and game.story_best == {}, "missing optional keys use current defaults")
	_check(not bool(game.onehp_unlocked), "missing optional unlock uses safe default")

func _run_round_trip(game: Node, save_path: String) -> void:
	_write_bytes(save_path, PROGRESS_BYTES.to_utf8_buffer())
	game._load_run_config()
	var exported := str(game.export_save_string())
	_check(not exported.is_empty(), "current profile exports through the public helper")
	var exported_payload = _decode(exported)
	_check(exported_payload is Dictionary and int(exported_payload.get("version", 0)) == int(game.SAVE_TRANSFER_VERSION), "export keeps the current transfer contract")
	var imported: bool = game.import_save_string(exported)
	_check(imported, "export/import round-trip succeeds")
	game._load_run_config()
	var round_trip: Variant = _decode(game.export_save_string())
	_check(_stable_projection(round_trip) == _stable_projection(exported_payload), "export/import round-trip preserves stable transfer fields")
	_check(int(game.best) == 420 and bool(game.story_cleared.get("boot", false)), "round-trip restores run and story state")
	_check(round_trip.get("weekly", {}) == exported_payload.get("weekly", {}), "round-trip preserves weekly fields")
	_check(round_trip.get("bestiary", {}) == exported_payload.get("bestiary", {}), "round-trip preserves bestiary fields")

func _run_invalid_inputs(game: Node, save_path: String) -> void:
	_write_bytes(save_path, PROGRESS_BYTES.to_utf8_buffer())
	game._load_run_config()
	var source_bytes := _read_bytes(save_path)
	var valid_payload := {
		"format": game.SAVE_TRANSFER_FORMAT,
		"version": game.SAVE_TRANSFER_VERSION,
		"run": {},
		"weekly": {},
		"story": {"cleared": {}, "best": {}},
		"bestiary": {},
		"programs": {},
		"achievements": {},
	}
	var nested_wrong_types := [
		{"run": "wrong"},
		{"weekly": []},
		{"story": "wrong"},
		{"story": {"cleared": []}},
		{"story": {"best": "wrong"}},
		{"bestiary": []},
		{"programs": "wrong"},
		{"achievements": []},
	]
	var malformed: Array = ["not base64", "eyJmb3JtYXQiOiJrZXJuZWwtcGFuaWMtc2F2ZSJ"]
	for override in nested_wrong_types:
		var invalid_payload: Dictionary = valid_payload.duplicate(true)
		for key in override:
			invalid_payload[key] = override[key]
		malformed.append(_encode(invalid_payload))
	for i in malformed.size():
		var accepted: bool = game.import_save_string(str(malformed[i]))
		_check(not accepted, "malformed/truncated input %d is rejected" % i)
		_check(_read_bytes(save_path) == source_bytes, "invalid import %d leaves source save byte-for-byte unchanged" % i)

func _encode(value) -> String:
	return Marshalls.raw_to_base64(JSON.stringify(value).to_utf8_buffer())

func _decode(value: String):
	var raw := Marshalls.base64_to_raw(value)
	return JSON.parse_string(raw.get_string_from_utf8())

func _stable_projection(payload: Variant) -> Dictionary:
	if not payload is Dictionary:
		return {}
	var story: Variant = payload.get("story", {})
	var story_cleared: Dictionary = story.get("cleared", {}) if story is Dictionary and story.get("cleared", {}) is Dictionary else {}
	var story_best: Dictionary = story.get("best", {}) if story is Dictionary and story.get("best", {}) is Dictionary else {}
	var positive_story_best := {}
	for stage_id in story_best:
		if int(story_best[stage_id]) > 0:
			positive_story_best[stage_id] = int(story_best[stage_id])
	return {
		"format": payload.get("format", ""),
		"version": payload.get("version", 0),
		"run": payload.get("run", {}),
		"weekly": payload.get("weekly", {}),
		"story_cleared": story_cleared,
		"story_best": positive_story_best,
		"story_unlock": story.get("temple_rainbow_unlocked", false) if story is Dictionary else false,
		"bestiary": payload.get("bestiary", {}),
		"programs": payload.get("programs", {}),
		"achievements": payload.get("achievements", {}),
	}

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
		file.close()

func _read_bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()

func _remove_save(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _watchdog() -> void:
	await get_tree().create_timer(10.0, true, false, true).timeout
	if _finished:
		return
	_watchdog_fired = true
	print("PROBE_FAIL watchdog timeout")
	get_tree().quit(2)

func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("SAVE_PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 or _watchdog_fired else 0)

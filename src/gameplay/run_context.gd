class_name RunContext
extends RefCounted

## Stable, serializable description of the current run's rule context.
##
## This is intentionally not an autoload and does not own gameplay state. Game
## remains authoritative; callers receive a fresh context or a copied snapshot
## whenever they ask for one.

const DEFAULT_MODE := "classic"
const KNOWN_MODES: Array[String] = ["classic", "story", "weekly", "onehp", "practice"]

var _mode := DEFAULT_MODE
var _stage := ""
var _mutator_ids: Array[String] = []

func _init(mode_id: String = DEFAULT_MODE, stage_id: String = "", mutators: Array[String] = []) -> void:
	_mode = _normalize_mode(mode_id)
	_stage = stage_id.strip_edges() if _mode == "story" else ""
	_mutator_ids = _normalize_mutators(mutators)

static func from_game(game: Object) -> RefCounted:
	if game == null:
		return load("res://src/gameplay/run_context.gd").new()
	var raw_mode: Variant = game.get("mode")
	var mode_id := _normalize_mode(DEFAULT_MODE if raw_mode == null else str(raw_mode))
	var stage_id := ""
	if mode_id == "story" and game.has_method("story_stage_id"):
		var raw_stage_index: Variant = game.get("story_stage_index")
		stage_id = str(game.call("story_stage_id", int(raw_stage_index if raw_stage_index != null else 0)))
	return load("res://src/gameplay/run_context.gd").new(mode_id, stage_id)

static func from_snapshot(snapshot: Dictionary) -> RefCounted:
	var raw_mutators: Array = snapshot.get("mutators", []) if snapshot.get("mutators", []) is Array else []
	var context = load("res://src/gameplay/run_context.gd").new(
		str(snapshot.get("mode", DEFAULT_MODE)),
		str(snapshot.get("stage_id", "")),
		_normalize_mutators(raw_mutators),
	)
	return context

func mode_id() -> String:
	return _mode

func stage_id() -> String:
	return _stage

func mutators() -> Array[String]:
	return _mutator_ids.duplicate()

func writes_records() -> bool:
	# Practice is reserved by the contract as a non-record mode. All modes that
	# currently exist in Game keep their existing persistence behavior.
	return _mode != "practice"

func uses_deterministic_seed() -> bool:
	# Weekly is the only current mode whose Game.start_run() seed is fixed. This
	# reports the current configuration, not a promise about future Practice.
	return _mode == "weekly"

func snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"owner": "RunContext",
		"mode": _mode,
		"stage_id": _stage,
		"mutators": _mutator_ids.duplicate(),
		"writes_records": writes_records(),
		"deterministic_seed": uses_deterministic_seed(),
	}

static func _normalize_mode(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	return normalized if normalized in KNOWN_MODES else DEFAULT_MODE

static func _normalize_mutators(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		var id := str(value).strip_edges().to_lower()
		if id.is_empty() or id in result:
			continue
		result.append(id)
	return result

extends Node

## G6 red/green probe for local, bounded death-position history.

const Context = preload("res://src/ui/vnext/ui_context.gd")
const GameOverSurface = preload("res://src/ui/vnext/surfaces/game_over_surface.gd")
const HeatmapView = preload("res://src/ui/death_heatmap_view.gd")

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
	var game_source := FileAccess.get_file_as_string("res://src/autoload/game.gd")
	var arena_source := FileAccess.get_file_as_string("res://src/arena/arena.gd")
	var over_source := FileAccess.get_file_as_string("res://src/ui/vnext/surfaces/game_over_surface.gd")
	_check(Game.has_method("record_death_position"), "Game exposes a death-position recorder")
	_check(Game.has_method("death_heatmap_snapshot"), "Game exposes a bounded heatmap snapshot")
	_check(game_source.contains("DEATH_HEATMAP_MAX_RUNS") and game_source.contains("death_heatmaps"), "Game declares versioned heatmap storage")
	_check(arena_source.contains("Game.record_death_position"), "Arena records the player position at the real death boundary")
	_check(over_source.contains("death_heatmap"), "game-over surface reserves a heatmap diagnostic layer")
	if not Game.has_method("record_death_position") or not Game.has_method("death_heatmap_snapshot"):
		_finish()
		return

	var original_mode := Game.mode
	var original_state := Game.state
	var original_heatmaps: Dictionary = Game.get("death_heatmaps").duplicate(true) if Game.get("death_heatmaps") is Dictionary else {}
	Game.mode = "classic"
	Game.state = Game.State.PLAYING
	Game.set("death_heatmaps", {})
	Game.set("_death_heatmap_run_recorded", false)
	Game.record_death_position(Vector2(100.0, 100.0))
	Game.record_death_position(Vector2(1100.0, 600.0))
	var once: Dictionary = Game.death_heatmap_snapshot()
	_check(int(once.get("run_count", 0)) == 1, "one run records at most one death cell")
	_check(int(once.get("version", 0)) == 1, "heatmap snapshot carries a schema version")
	_check(int(once.get("columns", 0)) >= 8 and int(once.get("rows", 0)) >= 5, "coordinates are quantized into a bounded grid")
	_check((once.get("cells", []) as Array).size() == 1, "snapshot exposes aggregate cells instead of screenshots")

	for i in 55:
		Game.set("_death_heatmap_run_recorded", false)
		Game.record_death_position(Vector2(60.0 + float(i % 12) * 96.0, 70.0 + float(i % 7) * 76.0))
	var capped: Dictionary = Game.death_heatmap_snapshot()
	_check(int(capped.get("run_count", 0)) == 50, "history is bounded to approximately fifty runs")
	_check(int(capped.get("run_count", 0)) <= int(capped.get("capacity", 0)), "stored history never exceeds declared capacity")
	for cell in capped.get("cells", []):
		_check(int(cell.get("x", -1)) >= 0 and int(cell.get("x", -1)) < int(capped.get("columns", 0)) and int(cell.get("y", -1)) >= 0 and int(cell.get("y", -1)) < int(capped.get("rows", 0)), "every heatmap cell stays within the declared grid")
	_check(int(capped.get("max_cell_count", 0)) > 0, "aggregate counts preserve repeated death locations")
	var sanitized: Dictionary = Game.call("_normalize_death_heatmaps", {"classic": {"version": 999, "runs": [{"x": 1, "y": 1}]}, "weekly": {"version": 1, "runs": [{"x": 1, "y": 1}, {"x": 99, "y": 1}]}, "unknown": {"version": 1, "runs": [{"x": 1, "y": 1}]}})
	_check(not sanitized.has("classic") and not sanitized.has("unknown") and sanitized.has("weekly") and (sanitized["weekly"]["runs"] as Array).size() == 1, "invalid versions, scopes and coordinates are rejected on load")
	var view := HeatmapView.new()
	add_child(view)
	view.configure(capped)
	await get_tree().process_frame
	_check(bool(view.text_overflow_report().get("title", {}).get("fits", false)), "legacy heatmap label fits its bounded diagnostic view")
	view.free()
	var surface := GameOverSurface.new()
	add_child(surface)
	surface.configure_adapter({"variant": "death", "title": "PROCESS TERMINATED", "diagnosis": "DIAGNOSIS // PROCESS TERMINATED", "stats": "TERMINATED BY DAEMON\nFINAL SCORE 0000123\nDAEMONS PURGED 12", "death_heatmap": capped, "primary_available": true}, Context.from_viewport(Vector2(1280, 720)))
	await get_tree().process_frame
	var layout: Dictionary = surface.layout_snapshot()
	_check(layout.get("regions", {}).has("heatmap") and not surface.text_overflow_report().get("has_overflow", true), "vNext game-over keeps heatmap low-priority without overflowing primary content")
	surface.free()

	Game.mode = "weekly"
	Game.set("_death_heatmap_run_recorded", false)
	Game.record_death_position(Vector2(640.0, 360.0))
	var weekly: Dictionary = Game.death_heatmap_snapshot()
	_check(int(weekly.get("run_count", 0)) == 1, "weekly history has its own mode scope")
	Game.mode = "classic"
	_check(int(Game.death_heatmap_snapshot().get("run_count", 0)) == 50, "switching mode does not mix heatmap histories")

	Game.set("death_heatmaps", original_heatmaps)
	Game.mode = original_mode
	Game.state = original_state
	_finish()

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

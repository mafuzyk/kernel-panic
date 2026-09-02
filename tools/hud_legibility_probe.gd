extends Node

## H2 regression probe: low-priority HUD copy must remain readable and bounded
## by its panel instead of relying on clipping or a barely visible alpha.

var _fails := 0
var _finished := false

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PROBE_PASS ", message)
	else:
		_fails += 1
		print("PROBE_FAIL ", message)

func _ticks(count: int) -> void:
	for _i in count:
		await get_tree().process_frame

func _run() -> void:
	var hud_script: Script = load("res://src/ui/hud.gd")
	_check(hud_script != null, "legacy HUD script loads for the legibility probe")
	if hud_script == null:
		_finish()
		return
	var hud: Node = hud_script.new()
	hud.set("size", Vector2(1366, 768))
	add_child(hud)
	await _ticks(2)
	var saved_event_log: Array = Game.event_log.duplicate(true)
	Game.event_log = [
		{"time": 1.0, "text": "SHORT EVENT"},
		{"time": 2.0, "text": "A VERY LONG EVENT PAYLOAD THAT MUST NOT ESCAPE THE SCORE REGISTER OR BECOME INVISIBLE"},
	]
	var normal_lines: Array = hud.call("visible_event_lines", 4)
	_check(normal_lines.size() == 2 and str(normal_lines[0]).contains("SHORT EVENT"), "event log keeps ordinary entries intact")
	var fitted_lines: Array = hud.call("visible_event_lines", 4, 180.0, 11)
	_check(fitted_lines.size() == 2, "event log keeps the newest entries after fitting")
	var mono: Font = hud.get("_mono")
	var fitted_width := mono.get_string_size(str(fitted_lines[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x if mono != null else 9999.0
	_check(fitted_width <= 180.01, "long event line is ellipsized inside its real width")
	_check(str(fitted_lines[1]).contains("…"), "long event line exposes an explicit truncation marker")
	hud.set("_tooltip_data", {
		"title": "AN EXTREMELY LONG PATCH TITLE THAT CANNOT FIT",
		"level": 2,
		"description": "A very long patch description that must be clipped to the tooltip register instead of entering the playfield.",
		"relation": "NO DIRECT INTERACTION WITH THIS PROGRAM",
	})
	var tooltip: Dictionary = hud.call("tooltip_text_snapshot", 180.0)
	_check(tooltip.size() == 3, "tooltip exposes fitted title, detail and relation lines")
	var tooltip_fit := true
	for key in ["title", "detail", "relation"]:
		var text := str(tooltip.get(key, ""))
		tooltip_fit = tooltip_fit and mono != null and mono.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13 if key == "title" else 11 if key == "detail" else 10).x <= 160.01
	_check(tooltip_fit, "tooltip copy stays inside the measured content width")
	_check(str(tooltip.get("title", "")).contains("…") and str(tooltip.get("detail", "")).contains("…"), "tooltip uses visible truncation for long copy")
	Game.event_log = saved_event_log
	hud.queue_free()
	await _ticks(1)
	_finish()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

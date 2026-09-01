extends Node

var fails := 0
var _finished := false

func _check(ok: bool, label: String) -> void:
	if ok:
		print("PROBE_PASS ", label)
	else:
		fails += 1
		print("PROBE_FAIL ", label)

func _ready() -> void:
	_watchdog.call_deferred()
	var program_script: Script = load("res://src/ui/vnext/surfaces/program_surface.gd")
	var story_script: Script = load("res://src/ui/vnext/surfaces/story_surface.gd")
	_check(program_script != null, "program surface script loads")
	_check(story_script != null, "story surface script loads")
	if program_script == null or story_script == null:
		_finish()
		return
	await _probe_program(program_script)
	await _probe_story(story_script)
	_finish()

func _probe_program(script: Script) -> void:
	var surface = script.new()
	add_child(surface)
	var required := ["configure", "layout_snapshot", "action_regions", "text_overflow_report", "semantic_snapshot", "handle_input", "set_focus_id", "focus_id"]
	for method_name in required:
		_check(surface.has_method(method_name), "program exposes %s" % method_name)
	_check(surface.has_signal("action_requested"), "program exposes action signal")
	var actions := []
	surface.action_requested.connect(func(id: String, payload: Dictionary) -> void: actions.append({"id": id, "payload": payload}))
	for viewport in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
		surface.size = viewport
		surface.configure({"selected": "kernel", "unlocked": ["kernel"]}, script.context_for_viewport(viewport, viewport.x < 800.0, true, true, 1.15))
		var layout: Dictionary = surface.layout_snapshot()
		var regions: Dictionary = surface.action_regions()
		_check(str(layout.get("density", "")) in ["wide", "compact", "narrow"], "program density %s" % viewport)
		_check(regions.has("back") and regions.has("launch_program"), "program actions %s" % viewport)
		for raw in regions.values():
			var rect: Rect2 = raw["rect"]
			_check((layout["safe_rect"] as Rect2).encloses(rect), "program action inside safe area %s" % viewport)
		_check(surface.text_overflow_report().all(func(item): return bool(item.get("fits", false)) and item.has("measured_width")), "program text fits %s" % viewport)
		_check(surface.semantic_snapshot().get("selected") == "kernel", "program selection semantic %s" % viewport)
	_check(surface.get_node_or_null("ProgramList") is VBoxContainer, "program has focusable list")
	_check(surface.get_node_or_null("LaunchAction") is Button and surface.get_node_or_null("BackAction") is Button, "program has real actions")
	_check(surface.set_focus_id("daemon"), "program can focus locked item")
	_check(not surface.handle_input(_key(KEY_ENTER)), "locked program cannot launch")
	_check(actions.is_empty(), "locked program emits no launch")
	_check(surface.set_focus_id("kernel"), "program focuses unlocked item")
	var before := actions.size()
	_check(surface.handle_input(_key(KEY_ENTER)), "program launch handles enter")
	_check(actions.size() == before + 1 and actions.back()["id"] == "launch_program", "program launch emits once")
	surface.queue_free()

func _probe_story(script: Script) -> void:
	var surface = script.new()
	add_child(surface)
	var actions := []
	surface.action_requested.connect(func(id: String, payload: Dictionary) -> void: actions.append({"id": id, "payload": payload}))
	for viewport in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
		surface.size = viewport
		surface.configure({"selected": 0}, script.context_for_viewport(viewport, viewport.x < 800.0, true, true, 1.15))
		var layout: Dictionary = surface.layout_snapshot()
		var regions: Dictionary = surface.action_regions()
		_check(regions.has("back") and regions.has("launch_story"), "story actions %s" % viewport)
		_check(regions.has("stage_0") and regions.has("stage_1"), "story stage map %s" % viewport)
		for raw in regions.values():
			var rect: Rect2 = raw["rect"]
			_check((layout["safe_rect"] as Rect2).encloses(rect), "story action inside safe area %s" % viewport)
		_check(surface.text_overflow_report().all(func(item): return bool(item.get("fits", false)) and item.has("measured_width")), "story text fits %s" % viewport)
	_check(surface.get_node_or_null("StoryList") is VBoxContainer and surface.get_node_or_null("LaunchAction") is Button, "story has real controls")
	_check(surface.semantic_snapshot().get("stage_1", {}).get("state") == "locked", "story locked state explains itself")
	_check(surface.set_focus_id("stage_1"), "story focuses locked stage")
	_check(not surface.handle_input(_key(KEY_ENTER)), "locked story cannot launch")
	_check(actions.is_empty(), "locked story emits no launch")
	_check(surface.set_focus_id("stage_0"), "story focuses unlocked stage")
	var before := actions.size()
	_check(surface.handle_input(_key(KEY_ENTER)), "story launch handles enter")
	_check(actions.size() == before + 1 and actions.back()["id"] == "launch_story", "story launch emits once")
	surface.queue_free()

func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event

func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("PROBE_DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _watchdog() -> void:
	await get_tree().create_timer(8.0, true, false, true).timeout
	if _finished:
		return
	print("PROBE_FAIL watchdog timeout")
	get_tree().quit(2)

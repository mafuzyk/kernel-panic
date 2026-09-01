extends Node

var fails := 0

func _check(ok: bool, label: String) -> void:
	if ok:
		print("PROBE_PASS ", label)
	else:
		fails += 1
		print("PROBE_FAIL ", label)

func _ready() -> void:
	var surface_script: Script = load("res://src/ui/vnext/surfaces/boot_surface.gd")
	_check(surface_script != null, "boot surface script loads")
	if surface_script == null:
		_finish()
		return
	var surface = surface_script.new()
	add_child(surface)
	for viewport in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
		surface.size = viewport
		surface.configure({"program": "kernel", "best": 42}, surface_script.context_for_viewport(viewport))
		var layout: Dictionary = surface.layout_snapshot()
		var regions: Dictionary = surface.action_regions()
		_check(str(layout.get("density", "")) in ["wide", "compact", "narrow"], "density exists for %s" % viewport)
		_check(regions.has("boot") and regions.has("back"), "boot/back actions exist for %s" % viewport)
		_check(float((regions["boot"] as Dictionary)["rect"].size.x) >= 44.0 and float((regions["boot"] as Dictionary)["rect"].size.y) >= 44.0, "boot target is touch safe for %s" % viewport)
		_check(surface.text_overflow_report().all(func(item): return bool(item.get("fits", false))), "text fits for %s" % viewport)
		_check(surface.semantic_snapshot().has("markers"), "semantic markers exist for %s" % viewport)
	var boot: Dictionary = surface.action_regions()["boot"]
	_check(surface.handle_input(_key(KEY_ENTER)), "ENTER activates boot")
	_check(surface.activation_count == 1, "ENTER activates once")
	surface.activation_count = 0
	_check(surface.handle_input(_mouse((boot["rect"] as Rect2).get_center())), "mouse activates boot")
	_check(surface.activation_count == 1, "mouse has no duplicate activation")
	surface.activation_count = 0
	_check(surface.handle_input(_touch((boot["rect"] as Rect2).get_center())), "touch activates boot")
	_check(surface.activation_count == 1, "touch has no duplicate activation")
	surface.queue_free()
	_finish()

func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func _mouse(at: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event

func _touch(at: Vector2) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.position = at
	event.pressed = true
	return event

func _finish() -> void:
	print("PROBE_DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)

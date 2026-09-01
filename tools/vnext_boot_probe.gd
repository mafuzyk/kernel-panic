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
	var surface_script: Script = load("res://src/ui/vnext/surfaces/boot_surface.gd")
	_check(surface_script != null, "boot surface script loads")
	if surface_script == null:
		_finish()
		return
	var surface = surface_script.new()
	add_child(surface)
	var required_api := ["configure", "layout_snapshot", "action_regions", "text_overflow_report", "semantic_snapshot", "handle_input", "set_focus_id", "focus_id"]
	for method_name in required_api:
		_check(surface.has_method(method_name), "boot surface exposes %s" % method_name)
	_check(surface.has_signal("action_requested"), "boot surface exposes action_requested")
	if fails > 0:
		_finish()
		return
	var actions: Array[String] = []
	surface.action_requested.connect(func(action_id: String, _payload: Dictionary) -> void:
		actions.append(action_id)
	)
	for viewport in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
		surface.size = viewport
		var context: RefCounted = surface_script.context_for_viewport(viewport, viewport.x < 800.0, true, true, 1.15)
		surface.configure({"program": "kernel", "best": 42}, context)
		var layout: Dictionary = surface.layout_snapshot()
		var regions: Dictionary = surface.action_regions()
		_check(str(layout.get("density", "")) in ["wide", "compact", "narrow"], "density exists for %s" % viewport)
		_check(regions.has("boot") and regions.has("back"), "boot/back actions exist for %s" % viewport)
		_check(float((regions["boot"] as Dictionary)["rect"].size.x) >= 44.0 and float((regions["boot"] as Dictionary)["rect"].size.y) >= 44.0, "boot target is touch safe for %s" % viewport)
		for action_id in regions:
			var action_rect: Rect2 = regions[action_id]["rect"]
			_check((layout["safe_rect"] as Rect2).encloses(action_rect), "%s target stays inside safe area for %s" % [action_id, viewport])
		_check(surface.text_overflow_report().all(func(item): return bool(item.get("fits", false)) and item.has("measured_width") and item.has("available_width")), "text is measured and fits for %s" % viewport)
		_check(surface.semantic_snapshot().has("markers"), "semantic markers exist for %s" % viewport)
	_check(surface.get_node_or_null("BootAction") is Button and surface.get_node_or_null("BackAction") is Button, "actions have real focusable controls")
	_check(str(surface.context.input_mode) == "touch" and bool(surface.context.reduce_motion) and bool(surface.context.high_contrast) and is_equal_approx(float(surface.context.text_scale), 1.15), "context carries input and accessibility preferences")
	surface.set_focus_id("back")
	_check(str(surface.focus_id()) == "back", "focus can move to back action")
	_check(surface.handle_input(_key(KEY_ENTER)), "ENTER activates focused back action")
	_check(not actions.is_empty() and actions.back() == "back", "focused ENTER dispatches back")
	surface.set_focus_id("boot")
	_check(surface.handle_input(_key(KEY_TAB)), "TAB advances focus")
	_check(str(surface.focus_id()) == "back", "TAB follows declared focus order")
	_check(surface.handle_input(_key(KEY_ENTER)), "ENTER dispatches focused action")
	_check(actions.back() == "back", "keyboard action is not redirected to boot")
	surface.configure({"program": "kernel", "best": 42}, surface_script.context_for_viewport(Vector2(432, 720), true))
	surface.set_focus_id("boot")
	var boot: Dictionary = surface.action_regions()["boot"]
	_check(surface.handle_input(_mouse((boot["rect"] as Rect2).get_center())), "mouse activates boot")
	_check(actions.back() == "boot", "mouse dispatches boot")
	_check(surface.handle_input(_touch((boot["rect"] as Rect2).get_center())), "touch activates boot")
	_check(actions.back() == "boot", "touch dispatches boot")
	var boot_button: Button = surface.get_node("BootAction")
	boot_button.emit_signal("pressed")
	_check(actions.back() == "boot", "real button signal dispatches once")
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

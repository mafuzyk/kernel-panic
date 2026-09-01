extends Node

var fails := 0
var done := false

func _check(ok: bool, label: String) -> void:
	if ok:
		print("PROBE_PASS ", label)
	else:
		fails += 1
		print("PROBE_FAIL ", label)

func _ready() -> void:
	var script: Script = load("res://src/ui/vnext/surfaces/patch_surface.gd")
	_check(script != null and script.can_instantiate(), "patch surface script loads")
	if script == null or not script.can_instantiate():
		_finish()
		return
	var surface = script.new()
	add_child(surface)
	for method_name in ["configure", "configure_adapter", "layout_snapshot", "action_regions", "text_overflow_report", "semantic_snapshot", "handle_input", "set_focus_id", "focus_id"]:
		_check(surface.has_method(method_name), "patch exposes %s" % method_name)
	_check(surface.has_signal("action_requested"), "patch exposes action signal")
	var offers := [
		{"id": "rapid", "title": "RAPID FIRE", "desc": "SHORTER FIRE INTERVAL", "max": 3, "rare": false},
		{"id": "chain", "title": "CHAIN", "desc": "EXTENDS COMBO WINDOW", "max": 3, "rare": false},
		{"id": "hp", "title": "INTEGRITY", "desc": "INCREASES MAX INTEGRITY", "max": 2, "rare": false},
	]
	var actions: Array = []
	surface.action_requested.connect(func(id: String, payload: Dictionary) -> void: actions.append({"id": id, "payload": payload}))
	var context = script.context_for_viewport(Vector2(432, 720), true, true, true, 1.15)
	surface.size = context.viewport_size
	surface.configure({"offers": offers, "active_ids": ["rapid"], "build": "RF1", "paused": true}, context)
	var snapshot: Dictionary = surface.semantic_snapshot()
	_check(snapshot.get("offers", []).size() == 3, "patch preserves deterministic offer order")
	_check(snapshot.get("conflict", "") != "", "patch previews relevant conflict")
	_check(surface.get_node_or_null("ConfirmAction") is Button and surface.get_node_or_null("SkipAction") is Button and surface.get_node_or_null("CloseAction") is Button, "patch uses real action controls")
	_check(surface.get_node_or_null("PreviousAction") is Button and surface.get_node_or_null("NextAction") is Button, "narrow patch has deliberate navigation")
	_check(surface.text_overflow_report().all(func(item): return bool(item.get("fits", false))), "patch text fits at scale")
	for raw in surface.action_regions().values():
		_check(context.safe_rect.encloses(raw["rect"]), "patch action remains inside safe area")
	_check(surface.set_focus_id("confirm"), "patch focus is addressable")
	_check(surface.handle_input(_key(KEY_ENTER)), "keyboard confirm dispatches")
	_check(actions.size() == 1 and actions[0]["id"] == "confirm", "confirm dispatches once")
	_check(not surface.handle_input(_key(KEY_ENTER)), "duplicate confirm is ignored")
	_check(actions.size() == 1, "duplicate selection does not emit")
	var next_rect: Rect2 = surface.action_regions()["next"]["rect"]
	_check(surface.handle_input(_mouse(next_rect.get_center())), "mouse navigation uses action geometry")
	_check(surface.semantic_snapshot().get("selected") == 1, "mouse navigation advances one offer")
	var touch_rect: Rect2 = surface.action_regions()["previous"]["rect"]
	_check(surface.handle_input(_touch(touch_rect.get_center())), "touch navigation uses action geometry")
	surface.size = Vector2(1366, 768)
	surface.configure(surface.snapshot, script.context_for_viewport(Vector2(1366, 768), false, true, true, 1.15))
	_check(not surface.action_regions().has("previous"), "wide layout hides narrow navigation")
	_check(surface.text_overflow_report().all(func(item): return bool(item.get("fits", false))), "resize during offer preserves overflow safety")
	surface.queue_free()
	var skip_surface = script.new()
	add_child(skip_surface)
	skip_surface.size = Vector2(432, 720)
	skip_surface.configure({"offers": offers, "active_ids": [], "paused": true}, context)
	var skip_actions: Array = []
	skip_surface.action_requested.connect(func(id: String, _payload: Dictionary) -> void: skip_actions.append(id))
	_check(skip_surface.set_focus_id("skip") and skip_surface.handle_input(_key(KEY_ENTER)), "keyboard skip dispatches")
	_check(skip_actions == ["skip"], "skip preserves one command")
	skip_surface.queue_free()
	var close_surface = script.new()
	add_child(close_surface)
	close_surface.size = Vector2(432, 720)
	close_surface.configure({"offers": offers, "paused": true}, context)
	var close_actions: Array = []
	close_surface.action_requested.connect(func(id: String, _payload: Dictionary) -> void: close_actions.append(id))
	_check(close_surface.set_focus_id("close") and close_surface.handle_input(_key(KEY_ENTER)), "keyboard close dispatches")
	_check(close_actions == ["close"], "close preserves one command")
	close_surface.queue_free()
	_finish()

func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
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
	event.index = 0
	event.pressed = true
	return event

func _finish() -> void:
	if done:
		return
	done = true
	print("PROBE_DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)

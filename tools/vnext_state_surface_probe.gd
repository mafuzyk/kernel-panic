extends Node

const Context = preload("res://src/ui/vnext/ui_context.gd")

var fails := 0
var finished := false

func _check(ok: bool, label: String) -> void:
	if ok:
		print("PROBE_PASS ", label)
	else:
		fails += 1
		print("PROBE_FAIL ", label)

func _ready() -> void:
	_watchdog.call_deferred()
	_check(ResourceLoader.exists("res://src/ui/vnext/core/ui_state.gd"), "state contract exists")
	_check(ResourceLoader.exists("res://src/ui/vnext/core/ui_focus_model.gd"), "focus model exists")
	_check(ResourceLoader.exists("res://src/ui/vnext/surfaces/state_surface.gd"), "state surface exists")
	if fails > 0:
		_finish()
		return
	var UIState = load("res://src/ui/vnext/core/ui_state.gd")
	var UIFocusModel = load("res://src/ui/vnext/core/ui_focus_model.gd")
	var StateSurface = load("res://src/ui/vnext/surfaces/state_surface.gd")

	var states := {
		"loading": UIState.make("loading", {"title": "LOADING", "message": "Syncing catalog.", "source": "catalog", "back_action": "back", "back_label": "BACK"}),
		"error": UIState.make("error", {"title": "RECOVERY REQUIRED", "message": "The catalog could not be read.", "reason_code": "catalog_missing", "primary_action": "retry", "primary_label": "RETRY", "back_action": "back", "back_label": "BACK", "can_retry": true, "source": "catalog"}),
		"empty": UIState.make("empty", {"title": "NO CONTENT", "message": "No entries are available yet.", "back_action": "back", "back_label": "BACK", "source": "catalog"}),
		"transition": UIState.make("transition", {"title": "MOVING TO ARENA", "message": "Preparing the next route.", "destination": "ARENA", "back_action": "cancel_transition", "back_label": "CANCEL", "source": "route"}),
	}
	for kind in states:
		var state: Dictionary = states[kind]
		_check(state.get("kind") == kind, "valid %s state kind" % kind)
		for key in ["title", "message", "reason_code", "primary_action", "primary_label", "back_action", "back_label", "can_retry", "busy", "semantic_label", "pattern", "recoverable", "source"]:
			_check(state.has(key), "%s snapshot has %s" % [kind, key])
		_check(not str(state.get("title", "")).is_empty() and not str(state.get("message", "")).is_empty(), "%s has visible copy" % kind)
		var copy := state.duplicate(true)
		copy["message"] = "changed"
		_check(state.get("message") != "changed", "%s snapshot is deep copied" % kind)

	var malformed: Dictionary = UIState.make("wat", {"title": "", "message": "", "reason_code": "locale_missing", "source": "fixture"})
	_check(malformed.get("kind") == "error", "unknown kind falls back to error")
	_check(not str(malformed.get("title", "")).is_empty() and not str(malformed.get("message", "")).is_empty(), "malformed state gets actionable fallback")
	_check(not str(malformed.get("message", "")).contains("locale_missing"), "raw reason key is not visible")
	var no_retry: Dictionary = UIState.make("error", {"title": "FAILED", "message": "Retry is unavailable.", "can_retry": false, "primary_action": "retry", "primary_label": "RETRY", "back_action": "back", "back_label": "BACK"})
	_check(str(no_retry.get("primary_action", "")).is_empty(), "unsafe retry cannot leave inert primary")

	var focus: RefCounted = UIFocusModel.new()
	_check(focus.set_focus_order(["retry", "back"]), "focus order is accepted")
	_check(focus.set_focus("retry") and focus.move_focus(1) == "back", "focus moves deterministically")
	_check(focus.set_focus("retry") and focus.snapshot().get("focus_id") == "retry", "focus snapshot restores by action id")
	_check(focus.begin_dispatch("retry") and not focus.begin_dispatch("retry"), "duplicate dispatch is guarded")
	focus.end_dispatch()
	_check(focus.begin_dispatch("retry"), "dispatch guard releases")
	focus.end_dispatch()

	var surface: Control = StateSurface.new()
	surface.size = Vector2(1366, 768)
	add_child(surface)
	var emitted: Array[String] = []
	surface.action_requested.connect(func(action_id: String, _payload: Dictionary) -> void: emitted.append(action_id))
	for viewport in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720), Vector2(390, 844)]:
		surface.size = viewport
		surface.configure(states["error"], Context.from_viewport(viewport, viewport.x < 500))
		_check(surface.layout_snapshot().has("safe_rect"), "safe layout reports at %s" % viewport)
		_check(surface.action_regions().has("retry") and surface.action_regions().has("back"), "error actions use stable ids at %s" % viewport)
		_check(_regions_are_safe(surface.action_regions()), "targets do not overlap and meet floor at %s" % viewport)
		_check(surface.text_overflow_report().all(func(item: Dictionary) -> bool: return bool(item.get("measured", false)) and bool(item.get("fits", false))), "all text is measured at %s" % viewport)
		surface.set_focus_id("back")
		_check(surface.focus_id() == "back", "focus restored by id after reflow at %s" % viewport)
	_check(surface.handle_input(_key(KEY_ESCAPE)), "escape emits back")
	_check(emitted == ["back"], "escape emits exactly one owned action")
	_check(surface.handle_input(_key(KEY_ENTER)), "enter emits focused action")
	_check(emitted == ["back", "back"], "rapid dispatch remains exactly once per input")

	surface.configure(states["empty"], Context.from_viewport(Vector2(720, 720)))
	_check(surface.action_regions().has("back") and not surface.action_regions().has("retry"), "empty exposes back only")
	surface.configure(states["loading"], Context.from_viewport(Vector2(720, 720)))
	_check(not surface.action_regions().has("cancel"), "loading without safe cancel has no cancel button")
	surface.configure(UIState.make("loading", {"title": "LOADING", "message": "Working.", "back_action": "cancel", "back_label": "CANCEL", "cancel_safe": true}), Context.from_viewport(Vector2(720, 720)))
	_check(surface.action_regions().has("cancel"), "loading safe cancel is real action")
	_check(surface.handle_input(_mouse(surface.action_regions()["cancel"]["rect"].get_center())), "pointer dispatch uses action id")
	_check(surface.handle_input(_touch(surface.action_regions()["cancel"]["rect"].get_center())), "touch dispatch uses action id")
	_check(emitted[-2] == "cancel" and emitted[-1] == "cancel", "pointer and touch preserve action ownership")

	_finish()

func _regions_are_safe(regions: Dictionary) -> bool:
	var ids: Array = regions.keys()
	for i in ids.size():
		var left: Rect2 = regions[ids[i]].get("rect", Rect2())
		if left.size.x < 44.0 or left.size.y < 44.0:
			return false
		for j in range(i + 1, ids.size()):
			if left.intersects(regions[ids[j]].get("rect", Rect2())):
				return false
	return true

func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event

func _mouse(position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event

func _touch(position: Vector2) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.position = position
	event.pressed = true
	return event

func _finish() -> void:
	if finished:
		return
	finished = true
	print("PROBE_DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _watchdog() -> void:
	await get_tree().create_timer(8.0, true, false, true).timeout
	if not finished:
		print("PROBE_FAIL watchdog timeout")
		get_tree().quit(2)

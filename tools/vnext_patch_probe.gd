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
	for method_name in ["configure", "configure_adapter", "reflow_for_viewport", "layout_snapshot", "action_regions", "text_overflow_report", "semantic_snapshot", "handle_input", "set_focus_id", "focus_id"]:
		_check(surface.has_method(method_name), "patch exposes %s" % method_name)
	_check(surface.has_signal("action_requested"), "patch exposes action signal")
	var offers := _offers()
	var context = script.context_for_viewport(Vector2(1280, 720), false, true, true, 1.15)
	surface.size = context.viewport_size
	var actions: Array = []
	surface.action_requested.connect(func(id: String, payload: Dictionary) -> void: actions.append({"id": id, "payload": payload}))
	surface.configure({"offers": offers, "active_ids": ["heavy"], "build": "HV1", "paused": true}, context)
	var snapshot: Dictionary = surface.semantic_snapshot()
	var selected_offer: Dictionary = snapshot.get("selected_offer", {})
	_check(snapshot.get("offers", []).size() == 3, "patch preserves deterministic offer order")
	_check(str(selected_offer.get("id", "")) == "splitshot", "patch selects first offer deterministically")
	_check(str(selected_offer.get("effect", "")) != "" and str(selected_offer.get("cost_benefit", "")) != "", "patch exposes effect and cost-benefit")
	_check(str(selected_offer.get("relation", "")) != "" and str(selected_offer.get("state", "")) == "conflict", "patch exposes real conflict state")
	_check(str(selected_offer.get("build_impact", "")) != "" and str(snapshot.get("build", "")) == "HV1", "patch exposes current build impact")
	_check(surface.get_node_or_null("ConfirmAction") is Button and surface.get_node_or_null("SkipAction") is Button and surface.get_node_or_null("CloseAction") is Button, "patch uses real action controls")
	var wide_regions: Dictionary = surface.action_regions()
	_check(bool(selected_offer.get("available", false)) and wide_regions.get("offer_0", {}).get("state", "") == "conflict", "tradeoff warning remains selectable under current gameplay rules")
	_check(wide_regions.has("offer_0") and wide_regions.has("offer_1") and wide_regions.has("offer_2"), "desktop shows every offer independently")
	_check(_regions_do_not_overlap(wide_regions, ["offer_0", "offer_1", "offer_2"]), "desktop offer cards do not overlap")
	_check(surface.text_overflow_report().all(func(item): return bool(item.get("fits", false))), "patch text and action labels fit at scale")
	for raw in wide_regions.values():
		_check(context.safe_rect.encloses(raw["rect"]), "patch action remains inside safe area")
	_check(surface.set_focus_id("offer_1") and surface.focus_id() == "offer_1", "desktop offer focus is addressable")
	_check(surface.handle_input(_key(KEY_ENTER)), "offer focus selects without confirming")
	_check(actions.is_empty() and surface.semantic_snapshot().get("selected", -1) == 1, "offer selection does not apply patch")
	_check(surface.set_focus_id("confirm") and surface.handle_input(_key(KEY_ENTER)), "keyboard confirm dispatches")
	_check(actions.size() == 1 and actions[0]["id"] == "confirm" and int(actions[0]["payload"]["index"]) == 1, "confirm dispatches selected offer once")
	_check(not surface.handle_input(_key(KEY_ENTER)), "duplicate confirm is ignored")
	_check(actions.size() == 1, "duplicate selection does not emit")
	surface.reject_action()
	_check(surface.set_focus_id("confirm") and surface.handle_input(_key(KEY_ENTER)) and actions.size() == 2, "rejected adapter action can be retried")
	var gui_event := _key(KEY_ENTER)
	surface._on_button_gui_input(gui_event)
	_check(surface.handle_input(gui_event) and actions.size() == 2, "GUI-routed event is not dispatched a second time")

	var empty_surface = script.new()
	add_child(empty_surface)
	empty_surface.size = Vector2(432, 720)
	empty_surface.configure({"offers": [], "paused": true}, script.context_for_viewport(Vector2(432, 720), true, true, true, 1.15))
	_check(not empty_surface.set_focus_id("confirm"), "empty patch cannot focus confirm")
	var empty_actions: Array = []
	empty_surface.action_requested.connect(func(id: String, _payload: Dictionary) -> void: empty_actions.append(id))
	_check(not empty_surface._dispatch("confirm") and empty_actions.is_empty(), "empty patch rejects keyboard confirm")
	_check(not empty_surface.handle_input(_key(KEY_RIGHT)), "empty patch rejects navigation")
	empty_surface.queue_free()

	var locked_surface = script.new()
	add_child(locked_surface)
	locked_surface.size = Vector2(432, 720)
	locked_surface.configure({"offers": [{"id": "secret", "title": "SECRET", "desc": "LOCKED", "locked": true, "reason": "REQUIRES ROOT ACCESS"}], "paused": true}, script.context_for_viewport(Vector2(432, 720), true, true, true, 1.15))
	var locked_region: Dictionary = locked_surface.action_regions().get("offer_0", {})
	_check(locked_region.get("state", "") == "locked" and not bool(locked_region.get("available", true)), "locked patch exposes explicit unavailable state")
	_check(not locked_surface.set_focus_id("offer_0") and not locked_surface.handle_input(_key(KEY_ENTER)), "locked patch cannot be confirmed")
	locked_surface.queue_free()

	var narrow = script.new()
	add_child(narrow)
	narrow.size = Vector2(432, 720)
	narrow.configure({"offers": offers, "active_ids": ["heavy"], "build": "HV1", "paused": true}, script.context_for_viewport(Vector2(432, 720), true, true, true, 1.15))
	var narrow_regions: Dictionary = narrow.action_regions()
	_check(narrow_regions.has("offer_0") and not narrow_regions.has("offer_1"), "narrow layout presents one offer at a time")
	_check(narrow_regions.has("previous") and narrow_regions.has("next"), "narrow patch has deliberate navigation")
	_check(_regions_do_not_overlap(narrow_regions, ["confirm", "skip", "previous", "next", "close"]), "narrow actions do not overlap")
	_check(narrow.text_overflow_report().all(func(item): return bool(item.get("fits", false))), "narrow patch text fits at scale")
	var next_rect: Rect2 = narrow_regions["next"]["rect"]
	_check(narrow.handle_input(_mouse(narrow.get_viewport().get_final_transform() * next_rect.get_center())) and narrow.semantic_snapshot().get("selected") == 1, "mouse navigation uses action geometry")
	var previous_rect: Rect2 = narrow.action_regions()["previous"]["rect"]
	_check(narrow.handle_input(_touch(narrow.get_viewport().get_final_transform() * previous_rect.get_center())) and narrow.semantic_snapshot().get("selected") == 0, "touch navigation uses action geometry")
	narrow.reflow_for_viewport(Vector2(1366, 768))
	_check(narrow.context.density == "wide" and narrow.action_regions().has("offer_2") and not narrow.action_regions().has("previous"), "real reflow switches narrow to desktop layout")
	_check(_regions_do_not_overlap(narrow.action_regions(), ["offer_0", "offer_1", "offer_2"]), "reflowed desktop offers do not overlap")
	narrow.queue_free()

	var long_surface = script.new()
	add_child(long_surface)
	long_surface.size = Vector2(432, 720)
	long_surface.configure({"offers": [{"id": "long", "title": "LONG", "desc": ("DETAIL ").repeat(80)}], "paused": true}, script.context_for_viewport(Vector2(432, 720), true, true, true, 1.15))
	_check(long_surface.text_overflow_report().any(func(item): return not bool(item.get("fits", true))), "long patch text is reported instead of falsely marked safe")
	long_surface.queue_free()

	var source := [{"id": "rapid", "title": "RAPID", "desc": "+ FIRE", "meta": {"nested": [1]}}]
	var isolated = script.new()
	add_child(isolated)
	isolated.size = Vector2(1280, 720)
	isolated.configure_adapter(source, [], "", script.context_for_viewport(Vector2(1280, 720)))
	source[0]["meta"]["nested"][0] = 99
	_check(int(isolated.semantic_snapshot()["offers"][0]["meta"]["nested"][0]) == 1, "patch snapshot is deeply isolated from caller data")
	isolated.queue_free()
	surface.queue_free()
	_finish()

func _offers() -> Array:
	return [
		{"id": "splitshot", "title": "SPLITSHOT", "desc": "+1 ANGLED PROJECTILE, -10% FIRE RATE", "max": 2, "rare": true, "level": 1},
		{"id": "rapid", "title": "RAPID LOOPS", "desc": "+18% FIRE RATE", "max": 5, "rare": false, "level": 0},
		{"id": "hp", "title": "REINTEGRATION", "desc": "+1 MAX INTEGRITY, HEAL 1", "max": 3, "rare": false, "level": 0},
	]

func _regions_do_not_overlap(regions: Dictionary, ids: Array) -> bool:
	for left_index in ids.size():
		if not regions.has(ids[left_index]):
			continue
		var left: Rect2 = regions[ids[left_index]]["rect"]
		for right_index in range(left_index + 1, ids.size()):
			if not regions.has(ids[right_index]):
				continue
			var right: Rect2 = regions[ids[right_index]]["rect"]
			if left.intersects(right):
				return false
	return true

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

extends Node

const Tokens = preload("res://src/ui/vnext/ui_tokens.gd")

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
	_check(program_script != null and program_script.can_instantiate(), "program surface script loads")
	_check(story_script != null and story_script.can_instantiate(), "story surface script loads")
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
		var visual_regions: Dictionary = layout.get("regions", {})
		for required_region in ["shell", "shell_meta", "header", "list", "detail", "detail_illustration", "footer"]:
			_check(visual_regions.has(required_region), "program reference shell region %s %s" % [required_region, viewport])
		_check((surface.semantic_snapshot().get("visual_system", "") == "reference_shell"), "program reference shell semantic %s" % viewport)
		_check((surface.semantic_snapshot().get("route", "") == "KP://PROGRAMS"), "program route semantic %s" % viewport)
		_check((visual_regions.get("detail_illustration", Rect2()) as Rect2).size.x >= 100.0 or str(layout.get("density", "")) == "narrow", "program dossier illustration allocation %s" % viewport)
		_check(regions.has("back") and (regions.has("launch_program") or str(layout.get("density", "")) == "narrow"), "program actions %s" % viewport)
		for raw in regions.values():
			var rect: Rect2 = raw["rect"]
			_check((layout["safe_rect"] as Rect2).encloses(rect), "program action inside safe area %s" % viewport)
		var program_overflow: Array = surface.text_overflow_report()
		_check(program_overflow.all(func(item): return bool(item.get("fits", false)) and item.has("measured_width")), "program text fits %s" % viewport)
		for item in program_overflow:
			if not item.get("fits", false):
				print("PROBE_INFO program_overflow ", viewport, " ", item)
		_check(surface.semantic_snapshot().get("selected") == "kernel", "program selection semantic %s" % viewport)
	_check(surface.get_node_or_null("ProgramList") is VBoxContainer, "program has focusable list")
	_check(surface.get_node_or_null("LaunchAction") is Button and surface.get_node_or_null("BackAction") is Button, "program has real actions")
	var narrow_program = script.new()
	add_child(narrow_program)
	narrow_program.size = Vector2(432, 720)
	narrow_program.configure({"selected": "kernel"}, script.context_for_viewport(Vector2(432, 720), true, true, true, 1.15))
	var narrow_program_layout: Dictionary = narrow_program.layout_snapshot()["regions"]
	_check(narrow_program.semantic_snapshot().get("view") == "list", "narrow program starts on list state")
	_check(narrow_program.get_node("ProgramList").visible and not narrow_program.get_node("LaunchAction").visible, "narrow program exposes list state only")
	_check(narrow_program.text_overflow_report().all(func(item): return bool(item.get("fits", false))), "narrow program complete text fits")
	_check(narrow_program.get_node("LaunchAction").visible == false, "narrow program launch waits for detail state")
	narrow_program.set_focus_id("kernel")
	_check(narrow_program.handle_input(_key(KEY_ENTER)), "narrow program opens selected detail")
	_check(narrow_program.semantic_snapshot().get("view") == "detail", "narrow program enters detail state")
	_check(narrow_program.get_node("LaunchAction").visible, "narrow program exposes launch in detail state")
	narrow_program.set_focus_id("list_view")
	_check(narrow_program.handle_input(_key(KEY_ENTER)), "narrow program returns to list")
	_check(narrow_program.semantic_snapshot().get("view") == "list", "narrow program returns to list state")
	narrow_program.queue_free()
	surface.size = Vector2(1366, 768)
	surface.configure({"selected": "kernel"}, script.context_for_viewport(Vector2(1366, 768), false, true, true, 1.15))
	var launch_color: Color = surface.get_node("LaunchAction").get_theme_color("font_color")
	_check(launch_color == Tokens.role_color("ready"), "enabled program launch uses ready color")
	_check(surface.set_focus_id("daemon"), "program can focus locked item")
	_check(not surface.handle_input(_key(KEY_ENTER)), "locked program cannot launch")
	_check(actions.is_empty(), "locked program emits no launch")
	_check(surface.set_focus_id("kernel"), "program focuses unlocked item")
	var before := actions.size()
	_check(surface.handle_input(_key(KEY_ENTER)), "program selection handles enter")
	_check(actions.size() == before, "program selection stays separate from launch")
	surface.set_focus_id("launch_program")
	_check(surface.handle_input(_key(KEY_ENTER)), "program launch handles focused enter")
	_check(actions.size() == before + 1 and actions.back()["id"] == "launch_program", "program launch emits once")
	var launch_button: Button = surface.get_node("LaunchAction")
	var gui_before := actions.size()
	launch_button.grab_focus()
	get_viewport().push_input(_key(KEY_ENTER))
	get_viewport().push_input(_key(KEY_ENTER, false))
	await get_tree().process_frame
	_check(actions.size() == gui_before + 1 and actions.back()["id"] == "launch_program", "program Button ENTER dispatches once through viewport")
	surface.set_focus_id("kernel")
	var kernel_rect: Rect2 = surface.action_regions()["kernel"]["rect"]
	_check(surface.handle_input(_mouse(_window_point(kernel_rect.get_center()))), "program mouse selects through shared geometry")
	_check(surface.handle_input(_touch(_window_point(kernel_rect.get_center()))), "program touch selects through shared geometry")
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
		var visual_regions: Dictionary = layout.get("regions", {})
		for required_region in ["shell", "shell_meta", "header", "list", "detail", "footer", "signature_rail", "evidence_band"]:
			_check(visual_regions.has(required_region), "story incident shell region %s %s" % [required_region, viewport])
		_check((visual_regions["evidence_band"] as Rect2).size.y >= 64.0, "story evidence has readable height %s" % viewport)
		_check((visual_regions["detail"] as Rect2).encloses(visual_regions["evidence_band"] as Rect2), "story evidence stays inside dossier %s" % viewport)
		_check(not (visual_regions["detail_content"] as Rect2).intersects(visual_regions["evidence_band"] as Rect2), "story dossier content reserves evidence %s" % viewport)
		var story_semantic: Dictionary = surface.semantic_snapshot()
		_check(story_semantic.get("visual_system", "") == "reference_shell", "story reference shell semantic %s" % viewport)
		_check(story_semantic.get("route", "") == "KP://STORY", "story route semantic %s" % viewport)
		_check(story_semantic.get("composition", {}).get("chrome", "") == "incident_console", "story chrome semantic %s" % viewport)
		_check(story_semantic.get("evidence", {}).has("node"), "story evidence semantic %s" % viewport)
		_check(regions.has("back") and (regions.has("launch_story") or str(layout.get("density", "")) == "narrow"), "story actions %s" % viewport)
		_check(regions.has("stage_0") and regions.has("stage_1"), "story stage map %s" % viewport)
		for region_id in regions:
			var raw = regions[region_id]
			var rect: Rect2 = raw["rect"]
			if not (layout["safe_rect"] as Rect2).encloses(rect):
				print("PROBE_INFO story_rect ", region_id, " ", rect, " safe=", layout["safe_rect"])
			_check((layout["safe_rect"] as Rect2).encloses(rect), "story %s inside safe area %s" % [region_id, viewport])
		var overflow: Array = surface.text_overflow_report()
		_check(overflow.all(func(item): return bool(item.get("fits", false)) and item.has("measured_width")), "story text fits %s" % viewport)
		for item in overflow:
			if not item.get("fits", false):
				print("PROBE_INFO story_overflow ", viewport, " ", item)
	_check(surface.get_node_or_null("StoryList") is VBoxContainer and surface.get_node_or_null("LaunchAction") is Button, "story has real controls")
	_check(surface.get_node_or_null("ActWindows") is Button and surface.get_node_or_null("ActTempleos") is Button and surface.get_node_or_null("ActMacos") is Button, "story act tabs are real controls")
	for act in ["unix", "windows", "templeos", "macos"]:
		_check((surface.get_node("Act" + act.capitalize()) as Button).size.y >= 44.0, "story tab touch target %s" % act)
	var narrow_story = script.new()
	add_child(narrow_story)
	narrow_story.size = Vector2(432, 720)
	narrow_story.configure({"selected": 0}, script.context_for_viewport(Vector2(432, 720), true, true, true, 1.15))
	var narrow_story_layout: Dictionary = narrow_story.layout_snapshot()["regions"]
	_check(narrow_story.semantic_snapshot().get("view") == "list", "narrow story starts on list state")
	_check(narrow_story.get_node("StoryList").visible and not narrow_story.get_node("LaunchAction").visible, "narrow story exposes list state only")
	_check(narrow_story.text_overflow_report().all(func(item): return bool(item.get("fits", false))), "narrow story complete text fits")
	_check(narrow_story.get_node("LaunchAction").visible == false, "narrow story launch waits for briefing state")
	narrow_story.set_focus_id("stage_0")
	_check(narrow_story.handle_input(_key(KEY_ENTER)), "narrow story opens selected briefing")
	_check(narrow_story.semantic_snapshot().get("view") == "detail", "narrow story enters briefing state")
	_check(narrow_story.get_node("LaunchAction").visible, "narrow story exposes launch in briefing state")
	narrow_story.set_focus_id("list_view")
	_check(narrow_story.handle_input(_key(KEY_ENTER)), "narrow story returns to list")
	_check(narrow_story.semantic_snapshot().get("view") == "list", "narrow story returns to list state")
	narrow_story.queue_free()
	_check(surface.semantic_snapshot().get("stage_1", {}).get("state") == "locked", "story locked state explains itself")
	_check(surface.set_focus_id("act_windows"), "story keyboard can focus act tab")
	_check(surface.handle_input(_key(KEY_ENTER)), "story keyboard activates act tab")
	_check(surface.semantic_snapshot().get("act") == "windows", "story keyboard act updates state")
	surface.set_focus_id("act_unix")
	surface.handle_input(_key(KEY_ENTER))
	_check(surface.set_focus_id("stage_1"), "story focuses locked stage")
	_check(not surface.handle_input(_key(KEY_ENTER)), "locked story cannot launch")
	_check(actions.is_empty(), "locked story emits no launch")
	_check(surface.set_focus_id("stage_0"), "story focuses unlocked stage")
	var before := actions.size()
	_check(surface.handle_input(_key(KEY_ENTER)), "story selection handles enter")
	_check(actions.size() == before, "story selection stays separate from launch")
	surface.set_focus_id("launch_story")
	_check(surface.handle_input(_key(KEY_ENTER)), "story launch handles focused enter")
	_check(actions.size() == before + 1 and actions.back()["id"] == "launch_story", "story launch emits once")
	var launch_button: Button = surface.get_node("LaunchAction")
	var gui_before := actions.size()
	launch_button.grab_focus()
	get_viewport().push_input(_key(KEY_ENTER))
	get_viewport().push_input(_key(KEY_ENTER, false))
	await get_tree().process_frame
	_check(actions.size() == gui_before + 1 and actions.back()["id"] == "launch_story", "story Button ENTER dispatches once through viewport")
	var tab_rect: Rect2 = surface.action_regions()["act_windows"]["rect"]
	_check(surface.handle_input(_mouse(_window_point(tab_rect.get_center()))), "story mouse selects act through shared geometry")
	_check(surface.semantic_snapshot().get("act") == "windows", "story mouse act updates state")
	var temple_rect: Rect2 = surface.action_regions()["act_templeos"]["rect"]
	_check(surface.handle_input(_touch(_window_point(temple_rect.get_center()))), "story touch selects act through shared geometry")
	_check(surface.semantic_snapshot().get("act") == "templeos", "story touch act updates state")
	var mac_rect: Rect2 = surface.action_regions()["act_macos"]["rect"]
	_check(surface.handle_input(_mouse(_window_point(mac_rect.get_center()))), "story mouse selects macOS act through shared geometry")
	_check(surface.semantic_snapshot().get("act") == "macos", "story macOS tab updates state")
	for act_spec in [{"act": "unix", "selected": 0}, {"act": "windows", "selected": 6}, {"act": "templeos", "selected": 9}, {"act": "macos", "selected": 11}]:
		surface.configure(act_spec, script.context_for_viewport(Vector2(1366, 768), false, true, true, 1.15))
		var act_semantic: Dictionary = surface.semantic_snapshot()
		_check(act_semantic.get("act", "") == act_spec["act"], "story config selects act %s" % act_spec["act"])
		_check(int(act_semantic.get("selected", -1)) == int(act_spec["selected"]), "story config selects node %s" % act_spec["act"])
		_check(surface.text_overflow_report().all(func(item): return bool(item.get("fits", false))), "story %s dossier text fits" % act_spec["act"])
	surface.queue_free()

func _key(code: int, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
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

func _window_point(point: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * point

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

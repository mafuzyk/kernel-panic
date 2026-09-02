extends Node

var fails := 0
var _finished := false
var _bestiary_before := {}

func _check(ok: bool, label: String) -> void:
	if ok:
		print("PROBE_PASS ", label)
	else:
		fails += 1
		print("PROBE_FAIL ", label)

func _ready() -> void:
	_watchdog.call_deferred()
	_bestiary_before = Game.bestiary.duplicate(true)
	Game.bestiary["drone"] = true
	var surface_script: Script = load("res://src/ui/vnext/surfaces/bestiary_surface.gd")
	_check(surface_script != null and surface_script.can_instantiate(), "bestiary surface loads")
	if surface_script == null:
		_finish()
		return
	var surface = surface_script.new()
	add_child(surface)
	var required := ["configure", "layout_snapshot", "action_regions", "text_overflow_report", "semantic_snapshot", "handle_input", "set_focus_id", "focus_id"]
	for method_name in required:
		_check(surface.has_method(method_name), "bestiary exposes %s" % method_name)
	_check(surface.has_signal("action_requested"), "bestiary exposes action signal")
	for viewport in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
		surface.size = viewport
		surface.configure({"selected": "drone"}, surface_script.context_for_viewport(viewport, viewport.x < 800.0, true, true, 1.15))
		var layout: Dictionary = surface.layout_snapshot()
		var regions: Dictionary = layout.get("regions", {})
		for required_region in ["shell", "shell_meta", "header", "list", "detail", "detail_illustration", "footer"]:
			_check(regions.has(required_region), "bestiary reference shell region %s %s" % [required_region, viewport])
		var semantic: Dictionary = surface.semantic_snapshot()
		_check(str(semantic.get("visual_system", "")) == "reference_shell", "bestiary reference shell semantic %s" % viewport)
		_check(str(semantic.get("route", "")) == "KP://BESTIARY", "bestiary route semantic %s" % viewport)
		_check(str(semantic.get("selected", "")) == "drone", "bestiary selected identity %s" % viewport)
		_check(regions.get("detail_illustration", Rect2()).size.x >= 100.0 or str(layout.get("density", "")) == "narrow", "bestiary identity allocation %s" % viewport)
		var actions: Dictionary = surface.action_regions()
		_check(actions.has("drone") and actions.has("lancer") and actions.has("back"), "bestiary actions %s" % viewport)
		for raw in actions.values():
			_check((layout["safe_rect"] as Rect2).encloses(raw["rect"]), "bestiary action inside safe area %s" % viewport)
		var overflow: Array = surface.text_overflow_report()
		_check(overflow.all(func(item): return bool(item.get("fits", false)) and item.has("measured_width") and item.has("available_width")), "bestiary text fits %s" % viewport)
		for item in overflow:
			if not item.get("fits", false):
				print("PROBE_INFO bestiary_overflow ", viewport, " ", item)
	_check(surface.get_node_or_null("BestiaryScroll/BestiaryList") is VBoxContainer, "bestiary has focusable list")
	_check(surface.get_node_or_null("BackAction") is Button, "bestiary has real back action")
	_check(surface.semantic_snapshot().get("seen") == true, "bestiary exposes seen state")
	_check(surface.handle_input(_key(KEY_ENTER)), "bestiary selection handles enter")
	_check(surface.last_action_id == "", "bestiary selection is not a destructive action")
	_check(surface.set_focus_id("lancer"), "bestiary can focus another process")
	_check(surface.semantic_snapshot().get("selected") == "lancer", "bestiary focus updates dossier")
	_check(surface.semantic_snapshot().get("seen") == false, "bestiary locked state is explicit")
	var narrow = surface_script.new()
	add_child(narrow)
	narrow.size = Vector2(432, 720)
	narrow.configure({"selected": "drone"}, surface_script.context_for_viewport(Vector2(432, 720), true, true, true, 1.15))
	_check(narrow.semantic_snapshot().get("view") == "list", "narrow bestiary starts on list")
	_check(narrow.get_node("BestiaryScroll/BestiaryList").visible and not narrow.get_node("ListAction").visible, "narrow bestiary exposes list only")
	narrow.set_focus_id("drone")
	_check(narrow.handle_input(_key(KEY_ENTER)), "narrow bestiary opens dossier")
	_check(narrow.semantic_snapshot().get("view") == "detail", "narrow bestiary enters dossier")
	_check(narrow.get_node("ListAction").visible, "narrow bestiary exposes list return")
	_check(narrow.handle_input(_key(KEY_ENTER)), "narrow bestiary activates focused dossier action")
	narrow.set_focus_id("list_view")
	_check(narrow.handle_input(_key(KEY_ENTER)), "narrow bestiary returns to list")
	_check(narrow.semantic_snapshot().get("view") == "list", "narrow bestiary returns to list")
	narrow.queue_free()
	surface.queue_free()
	Game.bestiary = _bestiary_before
	_finish()

func _key(code: int, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
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

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
	_check(OS.get_environment("KP_VNEXT_U4") == "1", "probe runs with U4 opt-in")
	var pause_script: Script = load("res://src/ui/vnext/surfaces/pause_surface.gd")
	var terminal_script: Script = load("res://src/ui/vnext/surfaces/terminal_surface.gd")
	var over_script: Script = load("res://src/ui/vnext/surfaces/game_over_surface.gd")
	_check(pause_script != null, "pause surface script exists")
	_check(terminal_script != null, "terminal surface script exists")
	_check(over_script != null, "game-over surface script exists")
	if pause_script == null or terminal_script == null or over_script == null:
		_finish()
		return
	for surface_script in [pause_script, terminal_script, over_script]:
		var surface: Control = surface_script.new()
		add_child(surface)
		_check(surface.has_method("layout_snapshot"), "%s exposes layout snapshot" % surface_script.resource_path)
		_check(surface.has_method("semantic_snapshot"), "%s exposes semantic snapshot" % surface_script.resource_path)
		_check(surface.has_method("action_regions"), "%s exposes action regions" % surface_script.resource_path)
		_check(surface.has_method("text_overflow_report"), "%s exposes overflow report" % surface_script.resource_path)
		surface.queue_free()
	await get_tree().process_frame
	var arena_script: Script = load("res://src/arena/arena.gd")
	var arena: Node = arena_script.new()
	get_tree().root.call_deferred("add_child", arena)
	await get_tree().process_frame
	_check(arena.has_method("vnext_u4_enabled") and bool(arena.call("vnext_u4_enabled")), "Arena exposes U4 opt-in adapter")
	_check(arena.has_method("vnext_u4_surface") and arena.call("vnext_u4_surface") != null, "Arena mounts one U4 surface adapter")
	_check(arena.get("_pause_panel") != null and arena.get("_terminal_panel") != null and arena.get("_over_panel") != null, "legacy panel APIs remain present")
	if arena.has_method("vnext_u4_surface"):
		var surface: Control = arena.call("vnext_u4_surface") as Control
		_check(surface != null and surface.has_method("configure_adapter"), "U4 surface accepts Arena snapshot adapter")
		for viewport in [Vector2(432, 720), Vector2(720, 720), Vector2(1280, 720)]:
			if surface != null and surface.has_method("reflow_for_viewport"):
				surface.call("reflow_for_viewport", viewport)
				var layout: Dictionary = surface.call("layout_snapshot")
				_check(_layout_is_safe(layout, viewport), "U4 layout is safe at %s" % viewport)
				_check(not bool(surface.call("text_overflow_report").get("has_unmeasured_fields", true)), "U4 fields are measured at %s" % viewport)
		arena.call("_set_paused", true)
		_check(get_tree().paused, "real Arena pause freezes tree")
		_check(bool(arena.call("vnext_u4_visible")), "pause opens U4 surface")
		var before_score := int(Game.score)
		get_viewport().push_input(_key(KEY_Q, true))
		get_viewport().push_input(_key(KEY_Q, false))
		await get_tree().process_frame
		_check(int(Game.score) == before_score, "pause input does not mutate gameplay")
		get_viewport().push_input(_key(KEY_ESCAPE, true))
		get_viewport().push_input(_key(KEY_ESCAPE, false))
		await get_tree().process_frame
		_check(not get_tree().paused, "real Escape resumes exactly once")
	arena.queue_free()
	_finish()

func _layout_is_safe(layout: Dictionary, viewport: Vector2) -> bool:
	var safe: Rect2 = layout.get("safe", Rect2())
	if safe.size.x <= 0.0 or safe.size.y <= 0.0 or safe.end.x > viewport.x or safe.end.y > viewport.y:
		return false
	var regions: Array[Rect2] = []
	for value in layout.get("regions", {}).values():
		if value is Rect2:
			var rect := value as Rect2
			if rect.size.x > 0.0 and rect.size.y > 0.0:
				regions.append(rect)
	for i in regions.size():
		for j in range(i + 1, regions.size()):
			if regions[i].intersects(regions[j], true):
				return false
	return true

func _key(code: int, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	return event

func _finish() -> void:
	if done:
		return
	done = true
	print("PROBE_DONE fails=%d" % fails)
	get_tree().paused = false
	get_tree().quit(1 if fails > 0 else 0)

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
	process_mode = Node.PROCESS_MODE_ALWAYS
	_check(OS.get_environment("KP_VNEXT_U4") == "1", "probe runs with vnext U4 opt-in")
	_check(OS.get_environment("KP_VNEXT_PATCH") == "1", "probe runs with vnext patch opt-in")
	Game.mode = "classic"
	Game.state = Game.State.PLAYING
	Game.patch_levels = {}
	Game.stats = {"kills": 0, "shots": 0, "hits": 0, "damage": 0, "time": 0.0, "wave": 1, "boss_kills": 0, "heals": {}}
	var arena_script: Script = load("res://src/arena/arena.gd")
	var arena: Node = arena_script.new()
	get_tree().root.call_deferred("add_child", arena)
	await get_tree().process_frame
	_check(arena != null and arena.is_inside_tree(), "real Arena mounts for physical resize")
	if arena == null or not arena.is_inside_tree():
		_finish()
		return
	get_window().size = Vector2i(432, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	var layout_size: Vector2 = arena.call("_vnext_layout_viewport")
	_check(layout_size == Vector2(432.0, 720.0), "Arena reads the physical narrow window")
	arena.call("_set_paused", true)
	await get_tree().process_frame
	var u4_surface: Control = arena.call("vnext_u4_surface") as Control
	_check(u4_surface != null and u4_surface.visible, "physical resize still opens U4 pause")
	if u4_surface != null:
		var pause_context: RefCounted = u4_surface.get("context")
		_check(pause_context != null and pause_context.viewport_size == Vector2(432.0, 720.0), "U4 pause receives physical narrow context")
		_check(u4_surface.size == Vector2(432.0, 720.0), "U4 pause surface keeps physical dimensions")
		_check(str(u4_surface.call("layout_snapshot").get("narrow", false)) == "true", "U4 pause selects narrow composition")
	arena.call("_set_paused", false)
	arena.call("offer_patch")
	await _until_patch_open(arena)
	var patch_surface: Control = arena.call("vnext_patch_surface") as Control
	_check(patch_surface != null and patch_surface.visible, "physical resize still opens patch decision")
	if patch_surface != null and patch_surface.visible:
		var patch_context: RefCounted = patch_surface.get("context")
		_check(patch_context != null and patch_context.viewport_size == Vector2(432.0, 720.0), "patch receives physical narrow context")
		_check(patch_surface.size == Vector2(432.0, 720.0), "patch surface keeps physical dimensions")
		_check(patch_context != null and patch_context.density == "narrow", "patch selects one-card narrow composition")
	arena.call("_close_vnext_patch")
	arena.queue_free()
	await get_tree().process_frame
	_finish()

func _until_patch_open(arena: Node) -> void:
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline and not bool(arena.get("_patch_open")):
		await get_tree().process_frame

func _finish() -> void:
	if done:
		return
	done = true
	print("PROBE_DONE fails=%d" % fails)
	get_tree().paused = false
	get_tree().quit(1 if fails > 0 else 0)

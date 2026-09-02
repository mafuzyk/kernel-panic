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
	var menu_scene: PackedScene = load("res://src/ui/menu.tscn")
	_check(menu_scene != null, "menu scene loads")
	if menu_scene == null:
		_finish()
		return
	var menu := menu_scene.instantiate()
	add_child(menu)
	await get_tree().process_frame
	var surface = menu.get("_vnext_boot")
	_check(surface != null and is_instance_valid(surface), "menu owns the vnext boot surface")
	if surface == null or not is_instance_valid(surface):
		_finish()
		return
	get_window().size = Vector2i(432, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	var context = surface.get("context")
	var layout: Dictionary = surface.layout_snapshot()
	_check(context != null and context.viewport_size == Vector2(432.0, 720.0), "window resize feeds physical layout size")
	_check(context != null and context.density == "narrow", "physical portrait width selects narrow composition")
	_check(surface.size == Vector2(432.0, 720.0), "surface keeps physical layout dimensions")
	_check(surface.scale.x > 1.0 and is_equal_approx(surface.scale.x, surface.scale.y), "surface is fitted back into the logical canvas")
	_check((layout["safe_rect"] as Rect2).size.x == 384.0, "narrow safe area uses the physical width")
	_check(surface.text_overflow_report().all(func(item: Dictionary) -> bool: return bool(item.get("fits", false))), "narrow physical layout reports no text overflow")
	_finish()

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

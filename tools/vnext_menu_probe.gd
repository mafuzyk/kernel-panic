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
	_check(surface != null and is_instance_valid(surface), "menu routes to opt-in vnext boot surface")
	if surface == null or not is_instance_valid(surface):
		_finish()
		return
	_check(surface.has_signal("action_requested"), "menu vnext surface keeps action signal")
	_check(surface.get_node_or_null("BootAction") is Button, "menu vnext surface exposes boot control")
	var menu_actions := []
	surface.action_requested.connect(func(action_id: String, _payload: Dictionary) -> void: menu_actions.append(action_id))
	var first_layout: Dictionary = surface.layout_snapshot()
	menu.size = Vector2(432, 720)
	menu._configure_vnext_boot(Vector2(432, 720))
	await get_tree().process_frame
	var resized_layout: Dictionary = surface.layout_snapshot()
	_check(resized_layout.has("safe_rect") and resized_layout["safe_rect"] != first_layout["safe_rect"], "menu resize recomputes the safe area")
	_check(surface.action_regions()["boot"]["rect"].size.x <= (resized_layout["safe_rect"] as Rect2).size.x, "menu resize keeps boot action inside the safe width")
	_check(surface.focus_id() == "boot", "menu resize preserves default focus")
	var boot_button: Button = surface.get_node("BootAction")
	boot_button.grab_focus()
	get_viewport().push_input(_key(KEY_ENTER))
	get_viewport().push_input(_key(KEY_ENTER, false))
	_check(Game.state == Game.State.PLAYING and menu_actions.size() == 1 and menu_actions[0] == "boot", "menu boot action enters playing state once")
	_finish()

func _key(code: int, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
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

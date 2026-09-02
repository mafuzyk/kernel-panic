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
	surface.set_focus_id("program")
	_check(surface.handle_input(_key(KEY_ENTER)), "menu opens vnext program route")
	await get_tree().process_frame
	var program_surface = menu.get("_vnext_surface")
	_check(program_surface != null and program_surface.get_node_or_null("ProgramList") is VBoxContainer, "menu owns program surface")
	var program_actions := []
	var program_button_events := []
	program_surface.action_requested.connect(func(action_id: String, _payload: Dictionary) -> void: program_actions.append(action_id))
	var program_back_button: Button = program_surface.get_node("BackAction")
	program_back_button.pressed.connect(func() -> void: program_button_events.append("pressed"))
	program_surface.set_focus_id("back")
	get_viewport().push_input(_key(KEY_ENTER))
	get_viewport().push_input(_key(KEY_ENTER, false))
	_check(program_actions.size() == 1 and program_actions[0] == "back", "program real back emits one route action")
	_check(program_button_events.size() == 1, "program real back is owned by Button")
	await get_tree().process_frame
	surface = menu.get("_vnext_surface")
	_check(surface != null and surface.get_node_or_null("BootAction") is Button, "program back returns to boot route")
	_check(Game.state == Game.State.MENU, "program back cannot fall through into boot")
	surface.set_focus_id("story")
	_check(surface.handle_input(_key(KEY_ENTER)), "menu opens vnext story route")
	await get_tree().process_frame
	var story_surface = menu.get("_vnext_surface")
	_check(story_surface != null and story_surface.get_node_or_null("StoryList") is VBoxContainer, "menu owns story surface")
	story_surface.set_focus_id("back")
	_check(story_surface.handle_input(_key(KEY_ENTER)), "story back emits route action")
	await get_tree().process_frame
	surface = menu.get("_vnext_surface")
	_check(Game.state == Game.State.MENU, "story back cannot fall through into boot")
	surface.set_focus_id("bestiary")
	_check(surface.handle_input(_key(KEY_ENTER)), "menu opens vnext bestiary route")
	await get_tree().process_frame
	var bestiary_surface = menu.get("_vnext_surface")
	_check(bestiary_surface != null and bestiary_surface.get_node_or_null("BestiaryScroll/BestiaryList") is VBoxContainer, "menu owns bestiary surface")
	var bestiary_actions := []
	bestiary_surface.action_requested.connect(func(action_id: String, _payload: Dictionary) -> void: bestiary_actions.append(action_id))
	bestiary_surface.set_focus_id("back")
	_check(bestiary_surface.handle_input(_key(KEY_ENTER)), "bestiary back emits route action")
	await get_tree().process_frame
	surface = menu.get("_vnext_surface")
	_check(Game.state == Game.State.MENU and surface != null and surface.get_node_or_null("BootAction") is Button, "bestiary back returns to boot route")
	var boot_actions := []
	surface.action_requested.connect(func(action_id: String, _payload: Dictionary) -> void: boot_actions.append(action_id))
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
	_check(Game.state == Game.State.PLAYING and boot_actions.size() == 1 and boot_actions[0] == "boot", "menu boot action enters playing state once")
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

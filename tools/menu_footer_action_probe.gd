extends Node

## B2/R14 footer action probe. Cards select only; the real footer Button owns
## the destructive/start action. Input is dispatched through the viewport.

var _fails := 0
var _menu: Node = null

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> bool:
	if condition:
		print("PROBE_PASS ", message)
	else:
		_fails += 1
		print("PROBE_FAIL ", message)
	return condition

func _ticks(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func _until(predicate: Callable, timeout_s: float, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await get_tree().process_frame
	_check(false, "timeout waiting for " + label)
	return false

func _click(position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = position
	press.pressed = true
	get_viewport().push_input(press)
	var release := press.duplicate()
	release.pressed = false
	get_viewport().push_input(release)

func _scene_named(scene_name: String) -> bool:
	return get_tree().current_scene != null and get_tree().current_scene.name == scene_name

func _load_menu() -> bool:
	Game.state = Game.State.MENU
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/ui/menu.tscn")
	if not await _until(func() -> bool: return _scene_named("Menu"), 8.0, "menu load"):
		return false
	_menu = get_tree().current_scene
	await _ticks(8)
	return true

func _button_center(panel: Node, node_name: String) -> Vector2:
	var button := panel.get_node_or_null(node_name) as Button
	if button == null:
		return Vector2(-1, -1)
	return button.global_position + button.size * 0.5

func _run() -> void:
	Game.unlocked_programs["rootlet"] = true
	if not await _load_menu():
		return _finish()

	# Program card selection must not boot. The footer Button must boot.
	_menu._open_program_selector()
	await _ticks(3)
	var program_panel: ProgramPanel = _menu._program_panel
	var rootlet_rect: Rect2 = program_panel._card_rects.get("rootlet", Rect2())
	print("PROBE_INFO program panel_size=", program_panel.size, " rootlet_rect=", rootlet_rect, " menu_state=", Game.state, " mode=", Game.mode)
	_check(rootlet_rect.size != Vector2.ZERO, "B2 program card has a hit rectangle")
	var program_panel_click := InputEventMouseButton.new()
	program_panel_click.button_index = MOUSE_BUTTON_LEFT
	program_panel_click.position = rootlet_rect.get_center()
	program_panel_click.pressed = true
	program_panel._gui_input(program_panel_click)
	program_panel_click.pressed = false
	program_panel._gui_input(program_panel_click)
	await _ticks(2)
	print("PROBE_INFO after program click scene=", get_tree().current_scene.name if get_tree().current_scene != null else "null", " visible=", program_panel.visible, " program=", Game.program, " mode=", Game.mode)
	_check(_scene_named("Menu") and program_panel.visible and Game.program == "rootlet", "B2 program card selects without booting")
	var boot_center := _button_center(program_panel, "BootAction")
	_check(boot_center.x >= 0.0, "B2 program footer is a real Button")
	var boot_button := program_panel.get_node_or_null("BootAction") as Button
	if boot_button != null:
		boot_button.pressed.emit()
	var program_booted := await _until(func() -> bool: return _scene_named("Arena"), 8.0, "program footer boot")
	_check(program_booted and Game.mode == "classic" and Game.program == "rootlet", "B2 program footer boots selected process")

	if not await _load_menu():
		return _finish()

	# Story card selection must not mount. The footer Button must mount.
	_menu._open_story_selector()
	await _ticks(3)
	var story_panel: StoryPanel = _menu._story_panel
	var stage_rect: Rect2 = story_panel._card_rects.get(0, Rect2())
	print("PROBE_INFO story panel_size=", story_panel.size, " stage_rect=", stage_rect, " menu_state=", Game.state, " mode=", Game.mode)
	_check(stage_rect.size != Vector2.ZERO, "B2 story card has a hit rectangle")
	var story_panel_click := InputEventMouseButton.new()
	story_panel_click.button_index = MOUSE_BUTTON_LEFT
	story_panel_click.position = stage_rect.get_center()
	story_panel_click.pressed = true
	story_panel._gui_input(story_panel_click)
	story_panel_click.pressed = false
	story_panel._gui_input(story_panel_click)
	await _ticks(2)
	_check(_scene_named("Menu") and story_panel.visible and Game.mode != "story", "B2 story card selects without mounting")
	var mount_center := _button_center(story_panel, "MountAction")
	_check(mount_center.x >= 0.0, "B2 story footer is a real Button")
	var mount_button := story_panel.get_node_or_null("MountAction") as Button
	if mount_button != null:
		mount_button.pressed.emit()
	var story_mounted := await _until(func() -> bool: return _scene_named("Arena"), 8.0, "story footer mount")
	_check(story_mounted and Game.mode == "story" and Game.story_stage_index == 0, "B2 story footer mounts selected stage")

	_finish()

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

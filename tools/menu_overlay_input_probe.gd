extends Node

## B1/R13/R14 menu overlay input regression probe. Uses real Viewport input
## dispatch so every overlay owns ENTER/ESC explicitly instead of relying on
## fallthrough to the main menu action.

var _fails := 0
var _menu: Node = null

func _ready() -> void:
	_watchdog.call_deferred()
	_run.call_deferred()

func _watchdog() -> void:
	await get_tree().create_timer(90.0, true, false, true).timeout
	print("PROBE_FAIL watchdog timeout")
	get_tree().quit(1)

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

func _push_key(code: int) -> void:
	var press := InputEventKey.new()
	press.physical_keycode = code
	press.keycode = code
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

func _overlay_visible(property: String) -> bool:
	var panel = _menu.get(property)
	return panel != null and panel.visible

func _run() -> void:
	Game.unlocked_programs["rootlet"] = true
	if not await _load_menu():
		return _finish()

	# Settings: ENTER is contained; ESC closes.
	_menu._open_settings()
	await _ticks(2)
	_push_key(KEY_ENTER)
	await _ticks(2)
	_check(_scene_named("Menu") and _overlay_visible("_settings_panel"), "B1 settings contains ENTER")
	_push_key(KEY_ESCAPE)
	await _ticks(2)
	_check(not _overlay_visible("_settings_panel"), "B1 settings ESC closes only settings")

	# Bestiary: ENTER is contained; ESC closes.
	_menu._open_bestiary()
	await _ticks(2)
	_push_key(KEY_ENTER)
	await _ticks(2)
	_check(_scene_named("Menu") and _overlay_visible("_bestiary_panel"), "B1 bestiary contains ENTER")
	_push_key(KEY_ESCAPE)
	await _ticks(2)
	_check(not _overlay_visible("_bestiary_panel"), "B1 bestiary ESC closes only bestiary")

	# Awards: ENTER is contained; ESC closes.
	_menu._open_achievements()
	await _ticks(2)
	_push_key(KEY_ENTER)
	await _ticks(2)
	_check(_scene_named("Menu") and _overlay_visible("_ach_panel"), "B1 awards contains ENTER")
	_push_key(KEY_ESCAPE)
	await _ticks(2)
	_check(not _overlay_visible("_ach_panel"), "B1 awards ESC closes only awards")

	# Program: ESC closes. ENTER explicitly boots the selected program.
	_menu._open_program_selector()
	await _ticks(2)
	_push_key(KEY_ESCAPE)
	await _ticks(2)
	_check(not _overlay_visible("_program_panel"), "B1 program ESC closes without booting")
	_menu._open_program_selector()
	_menu._program_panel.select_program("rootlet")
	Game.mode = "classic"
	_push_key(KEY_ENTER)
	var program_booted := await _until(func() -> bool: return _scene_named("Arena"), 8.0, "program ENTER boot")
	_check(program_booted and Game.mode == "classic" and Game.program == "rootlet", "B1 program ENTER explicitly boots selected program")

	if not await _load_menu():
		return _finish()

	# Story: ESC closes. ENTER explicitly mounts the selected stage.
	_menu._open_story_selector()
	await _ticks(2)
	_push_key(KEY_ESCAPE)
	await _ticks(2)
	_check(not _overlay_visible("_story_panel"), "B1 story ESC closes without mounting")
	_menu._open_story_selector()
	await _ticks(2)
	_push_key(KEY_ENTER)
	var story_mounted := await _until(func() -> bool: return _scene_named("Arena"), 8.0, "story ENTER mount")
	_check(story_mounted and Game.mode == "story" and Game.story_stage_index == 0, "B1 story ENTER explicitly mounts selected stage")

	_finish()

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

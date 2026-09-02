extends Node

## B6 regression probe: the legacy menu's primary instruction must be a real,
## visible, laid-out prompt. It must not remain over an overlay or lose its
## text after the two-step ESC quit guard expires.

var _fails := 0
var _finished := false

func _ready() -> void:
	_watchdog.call_deferred()
	_run.call_deferred()

func _watchdog() -> void:
	await get_tree().create_timer(12.0, true, false, true).timeout
	if _finished:
		return
	print("PROBE_FAIL watchdog timeout")
	get_tree().quit(1)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PROBE_PASS ", message)
	else:
		_fails += 1
		print("PROBE_FAIL ", message)

func _ticks(count: int) -> void:
	for _i in count:
		await get_tree().process_frame

func _key(code: int, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	return event

func _push_key(code: int) -> void:
	get_viewport().push_input(_key(code, true))
	get_viewport().push_input(_key(code, false))

func _run() -> void:
	Game.state = Game.State.MENU
	get_tree().paused = false
	var menu_scene: PackedScene = load("res://src/ui/menu.tscn")
	_check(menu_scene != null, "legacy menu scene loads")
	if menu_scene == null:
		_finish()
		return
	var menu := menu_scene.instantiate()
	add_child(menu)
	await _ticks(5)
	var prompt: Label = menu.get("_prompt") as Label
	_check(prompt != null and is_instance_valid(prompt), "legacy menu owns the launch prompt")
	if prompt == null or not is_instance_valid(prompt):
		_finish()
		return
	_check(prompt.visible, "launch prompt is visible on the idle menu")
	_check(prompt.text == "PRESS [ENTER] OR HIT >> PURGE", "launch prompt gives the real keyboard instruction")
	_check(prompt.get_global_rect().size.x > 1.0 and prompt.get_global_rect().size.y > 1.0, "launch prompt has a non-empty layout rect")

	_push_key(KEY_ESCAPE)
	await _ticks(2)
	_check(prompt.visible and prompt.text == "PRESS ESC AGAIN TO QUIT", "ESC guard replaces the prompt without hiding it")
	await get_tree().create_timer(2.2, true, false, true).timeout
	await _ticks(2)
	_check(prompt.visible and prompt.text == "PRESS [ENTER] OR HIT >> PURGE", "launch prompt restores after ESC guard expiry")

	menu._open_program_selector()
	await _ticks(2)
	_check(not prompt.visible, "launch prompt hides while a menu overlay is open")
	menu._close_program_selector()
	await _ticks(2)
	_check(prompt.visible, "launch prompt returns after the menu overlay closes")
	_finish()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

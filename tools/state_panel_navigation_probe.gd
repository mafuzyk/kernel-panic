extends Node

## N1 red/green probe: legacy pause, terminal and game-over panels must expose
## real keyboard focus, a deterministic vertical order and an ESC return path.

var _fails := 0
var _finished := false

func _ready() -> void:
	_run.call_deferred()

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
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	return event

func _focus_owner() -> Control:
	return get_viewport().gui_get_focus_owner()

func _button_text(control: Control) -> String:
	return control.text if control is Button else control.name

func _run() -> void:
	var arena_script: Script = load("res://src/arena/arena.gd")
	_check(arena_script != null, "Arena script loads for state-panel navigation")
	if arena_script == null:
		_finish()
		return

	Game.mode = "classic"
	Game.program = "kernel"
	Game.patch_levels = {}
	Game.state = Game.State.PLAYING
	Game.stats = {"time": 0.0, "wave": 1, "kills": 0, "shots": 0, "hits": 0, "damage": 0, "boss_kills": 0, "heals": {}}
	get_tree().paused = false
	var arena: Node = arena_script.new()
	add_child(arena)
	await _ticks(3)

	var pause_buttons: Array = arena.get("_pause_buttons")
	_check(pause_buttons.size() == 4, "legacy pause exposes four actions")
	var focus_styles := true
	for button in pause_buttons:
		focus_styles = focus_styles and button is Button and button.focus_mode == Control.FOCUS_ALL and button.has_theme_stylebox_override("focus")
	_check(focus_styles, "legacy pause actions expose keyboard focus and a visible focus style")

	arena.call("_set_paused", true)
	await _ticks(1)
	_check(_focus_owner() == pause_buttons[0], "pause focuses RESUME when opened")
	get_viewport().push_input(_key(KEY_DOWN)); get_viewport().push_input(_key(KEY_DOWN, false)); await _ticks(1)
	_check(_focus_owner() == pause_buttons[1], "pause DOWN focuses RESTART")
	get_viewport().push_input(_key(KEY_DOWN)); get_viewport().push_input(_key(KEY_DOWN, false)); await _ticks(1)
	_check(_focus_owner() == pause_buttons[2], "pause DOWN focuses OPEN TERMINAL")
	get_viewport().push_input(_key(KEY_ENTER)); get_viewport().push_input(_key(KEY_ENTER, false)); await _ticks(1)
	var terminal: Control = arena.get("_terminal_panel")
	_check(terminal != null and terminal.visible, "pause Enter opens terminal from the focused action")
	var line_edit: LineEdit = terminal.get("_input") if terminal != null else null
	_check(line_edit != null and line_edit.has_focus(), "terminal returns focus to its command prompt")
	get_viewport().push_input(_key(KEY_ESCAPE)); get_viewport().push_input(_key(KEY_ESCAPE, false)); await _ticks(1)
	_check(terminal != null and not terminal.visible, "terminal ESC closes the terminal")
	_check(bool(arena.get("_pause_panel").visible), "terminal ESC restores the pause panel")
	_check(_focus_owner() == pause_buttons[2], "terminal ESC returns focus to OPEN TERMINAL")

	arena.call("_set_paused", false)
	arena.call("_show_game_over")
	await _ticks(1)
	var over_primary: Button = arena.get("_over_primary")
	var over_menu: Button = arena.get("_over_menu")
	_check(over_primary != null and over_menu != null, "legacy game-over exposes both actions")
	_check(over_primary != null and over_primary.focus_mode == Control.FOCUS_ALL and over_primary.has_theme_stylebox_override("focus"), "game-over primary exposes keyboard focus and focus style")
	_check(_focus_owner() == over_primary, "game-over focuses REBOOT when opened")
	get_viewport().push_input(_key(KEY_DOWN)); get_viewport().push_input(_key(KEY_DOWN, false)); await _ticks(1)
	_check(_focus_owner() == over_menu, "game-over DOWN focuses ABANDON PROCESS")
	get_viewport().push_input(_key(KEY_UP)); get_viewport().push_input(_key(KEY_UP, false)); await _ticks(1)
	_check(_focus_owner() == over_primary, "game-over UP returns to REBOOT")

	arena.queue_free()
	get_tree().paused = false
	await _ticks(1)
	_finish()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().paused = false
	get_tree().quit(1 if _fails > 0 else 0)

extends Node

## B5 terminal probe — real TerminalPanel, paused Arena, and Viewport input.
## Verifies the behavior promised by the terminal shortcut legend.

var _fails := 0
var _arena: Arena = null

func _ready() -> void:
	_watchdog.call_deferred()
	_run.call_deferred()

func _watchdog() -> void:
	await get_tree().create_timer(60.0, true, false, true).timeout
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

func _key(pressed: bool, code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	if code >= KEY_0 and code <= KEY_Z:
		event.unicode = code
	return event

func _push_key(code: int) -> void:
	get_viewport().push_input(_key(true, code))
	get_viewport().push_input(_key(false, code))

func _arena_loaded() -> bool:
	return get_tree().current_scene != null and get_tree().current_scene.name == "Arena"

func _wait_arena(label: String) -> bool:
	return await _until(func() -> bool: return _arena_loaded(), 8.0, label)

func _run() -> void:
	Game.unlocked_programs["kernel"] = true
	Game.set_program("kernel")
	await _ticks(3)
	Game.start_run()
	if not await _wait_arena("terminal arena load"):
		return _finish()
	_arena = get_tree().current_scene
	await _ticks(10)
	Game.state = Game.State.PLAYING
	_arena._state = "play"
	_arena.spawner.stop()
	get_tree().paused = true
	_arena._panel_kit._open_terminal()
	await _ticks(5)

	var terminal: TerminalPanel = _arena._terminal_panel
	_check(terminal != null and terminal.visible, "B5 terminal opens on the paused Arena path")
	if terminal == null:
		return _finish()
	_check(terminal.has_method("history_snapshot"), "B5 terminal exposes command history")
	_check(terminal.has_method("autocomplete_text"), "B5 terminal exposes command autocomplete")
	if not terminal.has_method("history_snapshot") or not terminal.has_method("autocomplete_text"):
		return _finish()

	# Submit through the real terminal command path. Consecutive duplicate is
	# intentionally collapsed so a held/accidental repeat does not pollute UX.
	terminal.submit_command("help")
	terminal.submit_command("top")
	terminal.submit_command("top")
	var history: Array = terminal.history_snapshot()
	_check(history == ["help", "top"], "B5 history stores nonempty commands without consecutive duplicates")

	var line_edit: LineEdit = terminal.get("_input")
	_check(line_edit != null and line_edit.has_focus(), "B5 terminal prompt owns focus")
	if line_edit == null:
		return _finish()
	line_edit.grab_focus()
	line_edit.text = "draft"
	_push_key(KEY_UP)
	await _ticks(1)
	_check(line_edit.text == "top" and line_edit.has_focus(), "B5 UP recalls the newest command and keeps focus")
	_push_key(KEY_UP)
	await _ticks(1)
	_check(line_edit.text == "help", "B5 repeated UP walks toward older commands")
	_push_key(KEY_DOWN)
	await _ticks(1)
	_check(line_edit.text == "top", "B5 DOWN walks toward newer commands")
	_push_key(KEY_DOWN)
	await _ticks(1)
	_check(line_edit.text == "draft", "B5 DOWN past newest restores the saved draft")

	line_edit.text = "he"
	_push_key(KEY_TAB)
	await _ticks(1)
	_check(line_edit.text == "help" and line_edit.has_focus(), "B5 TAB completes a unique indexed command")
	line_edit.text = "not-a-command"
	_push_key(KEY_TAB)
	await _ticks(1)
	_check(line_edit.text == "not-a-command", "B5 TAB leaves an unmatched prefix unchanged")

	terminal.close_terminal()
	get_tree().paused = false
	_finish()

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

extends Node

## Input dispatch probe — regression coverage for R01/R02/R03 via real
## Viewport.push_input dispatch (press + release, echo, focus, paused tree,
## real scene transitions). Reusable: exit code 1 on any failure.
## T01: direct handler calls are NOT used as evidence of dispatch; the only
## direct arena calls here are state preparation (matches the review probe).

var _fails := 0
var _arena: Arena = null

func _ready() -> void:
	_watchdog.call_deferred()
	_run.call_deferred()

func _watchdog() -> void:
	await get_tree().create_timer(150.0, true, false, true).timeout
	print("PROBE_FAIL watchdog timeout")
	get_tree().quit(1)

func _check(cond: bool, msg: String) -> bool:
	if cond:
		print("PROBE_PASS ", msg)
	else:
		_fails += 1
		print("PROBE_FAIL ", msg)
	return cond

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _until(fn: Callable, timeout_s: float, label: String) -> bool:
	# Monotonic real-time deadline: frame counting drifts with pause/load hitches.
	var deadline := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if fn.call():
			return true
		await get_tree().process_frame
	_check(false, "timeout waiting for " + label)
	return false

func _key(press: bool, code: int, echo := false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = press
	ev.echo = echo
	if code >= KEY_0 and code <= KEY_Z:
		ev.unicode = code
	return ev

func _push_key(code: int, echo := false) -> void:
	get_viewport().push_input(_key(true, code, echo))
	get_viewport().push_input(_key(false, code))

func _arena_loaded() -> bool:
	return get_tree().current_scene != null and get_tree().current_scene.name == "Arena"

func _wait_arena_change(label: String) -> bool:
	var prev := get_tree().current_scene
	return await _until(func() -> bool:
		return _arena_loaded() and get_tree().current_scene != prev, 8.0, label)

func _pause_button(text: String) -> Button:
	if _arena == null or _arena._pause_panel == null:
		return null
	for child in _arena._pause_panel.get_children():
		if child is Button and child.text == text:
			return child
	return null

func _load_classic() -> bool:
	Game.start_run()
	if not await _wait_arena_change("classic arena load"):
		return false
	_arena = get_tree().current_scene
	await _ticks(10)
	Game.state = Game.State.PLAYING
	_arena._state = "play"
	return true

func _run() -> void:
	Game.unlocked_programs["kernel"] = true
	Game.set_program("kernel")
	await _ticks(5)

	# ---- R01: Q arms/echo/expire, second Q confirms with a real scene change
	if not await _load_classic():
		return _finish()
	_push_key(KEY_ESCAPE)
	_check(get_tree().paused, "R01 ESC opens pause via viewport dispatch")
	var resume := _pause_button("RESUME")
	if resume != null:
		resume.grab_focus()
	_push_key(KEY_Q)
	_check(get_tree().paused and Game.state == Game.State.PLAYING and _arena._abandon_armed, "R01 first Q arms abandon while a pause button holds focus")
	_push_key(KEY_Q, true)
	_check(_arena._abandon_armed and Game.state == Game.State.PLAYING, "R01 echo Q does not confirm abandon")
	await get_tree().create_timer(2.3, true, false, true).timeout
	_check(not _arena._abandon_armed, "R01 armed abandon expires after the confirmation window")
	_push_key(KEY_Q)
	_check(_arena._abandon_armed, "R01 Q rearms after expiry")
	_push_key(KEY_Q)
	var abandon_ok := await _until(func() -> bool:
		return get_tree().current_scene != null and get_tree().current_scene.name == "Menu", 8.0, "abandon returns to menu")
	_check(abandon_ok and Game.state == Game.State.MENU, "R01 second Q confirms abandon with a real scene transition")
	get_tree().paused = false
	await _ticks(2)

	# ---- R01: R restarts while paused and preserves story mode
	Game.start_story(0)
	if not await _wait_arena_change("story arena load"):
		return _finish()
	_arena = get_tree().current_scene
	await get_tree().create_timer(1.5, true, false, true).timeout
	_check(Game.mode == "story", "story run started")
	_check(_arena._story_intro_state == 2, "story intro is holding before dismissal")
	_push_key(KEY_ESCAPE)
	await _until(func() -> bool:
		return _arena._story_intro_state != 2, 4.0, "ESC dismisses story intro")
	_push_key(KEY_ESCAPE)
	_check(get_tree().paused, "R01 ESC pauses after story intro dismissal")
	var story_arena := _arena
	_push_key(KEY_R)
	var restart_ok := await _until(func() -> bool:
		return _arena_loaded() and get_tree().current_scene != story_arena, 8.0, "R restart reloads the stage")
	_check(restart_ok, "R01 R restarts while paused with a real scene transition")
	await _ticks(2)
	if restart_ok:
		_arena = get_tree().current_scene
		await _ticks(10)
		_check(not get_tree().paused, "R01 restart resumes unpaused")
		_check(Game.mode == "story" and Game.story_stage_index == 0, "R01 R preserves story mode and stage")

	# ---- R02: 1/2/3 pick exactly the announced patch while the tree is paused
	if not await _load_classic():
		return _finish()
	for pick in [0, 1, 2]:
		_arena.offer_patch()
		if not await _until(func() -> bool:
			return _arena._patch_open and get_tree().paused, 4.0, "patch offer opens"):
			continue
		var before: Dictionary = Game.patch_levels.duplicate(true)
		var offered: Array = (_arena._patch_offers as Array).duplicate(true)
		if pick == 0:
			_push_key(KEY_1, true)
			_check(_arena._patch_open and Game.patch_levels == before, "R02 echo digit does not pick a patch")
			_push_key(KEY_1)
		else:
			_push_key(KEY_2 if pick == 1 else KEY_3)
		var want_id: String = offered[pick]["id"]
		var ok_pick: bool = not _arena._patch_open and not get_tree().paused
		var grew_exact: bool = int(Game.patch_levels.get(want_id, 0)) == int(before.get(want_id, 0)) + 1 and _dict_total(Game.patch_levels) == _dict_total(before) + 1
		_check(ok_pick, "R02 digit %d closes the offer and unpauses" % (pick + 1))
		_check(grew_exact, "R02 digit %d applied exactly %s" % [pick + 1, want_id])

	# ---- terminal precedence: Q/R/1 inside the terminal LineEdit must not act
	_push_key(KEY_ESCAPE)
	_check(get_tree().paused, "terminal setup pause")
	_arena._panel_kit._open_terminal()
	await _ticks(4)
	_check(_arena._terminal_panel.visible, "terminal opened while paused")
	var line_edit: LineEdit = _arena._terminal_panel.get("_input")
	_push_key(KEY_Q)
	_check(not _arena._abandon_armed and _arena._terminal_panel.visible, "R01 terminal: Q is not routed to abandon")
	_push_key(KEY_R)
	_check(_arena_loaded() and get_tree().current_scene == _arena, "R01 terminal: R does not restart")
	_push_key(KEY_1)
	_check(_arena._patch_open == false and get_tree().paused, "R02 terminal: digits do not pick patches")
	if line_edit != null:
		_check(str(line_edit.text).length() >= 3, "terminal: typed keys reached the LineEdit")
	_push_key(KEY_ESCAPE)
	await _ticks(2)
	_check(not _arena._terminal_panel.visible and _arena._pause_panel.visible and get_tree().paused, "terminal: ESC closes only the terminal, pause stays")
	_push_key(KEY_Q)
	_check(_arena._abandon_armed, "terminal: Q after closing routes to the pause flow")
	_push_key(KEY_ESCAPE)
	_check(not get_tree().paused, "terminal: ESC resumes from pause")

	# ---- R03: debug block must not swallow ESC; F1/F2 keep working
	var debug_on: bool = _arena.debug_controls_enabled()
	print("PROBE_INFO debug_controls_enabled=", debug_on)
	_push_key(KEY_ESCAPE)
	await _ticks(2)
	_check(get_tree().paused, "R03 ESC opens pause under desktop debug dispatch")
	_push_key(KEY_ESCAPE)
	await _ticks(2)
	_check(not get_tree().paused, "R03 ESC closes pause under desktop debug dispatch")
	if debug_on:
		var f1_visible_before: bool = _arena._debug_panel != null and _arena._debug_panel.visible
		_push_key(KEY_F1)
		await _ticks(2)
		var f1_visible_after: bool = _arena._debug_panel != null and _arena._debug_panel.visible
		_check(f1_visible_before != f1_visible_after, "R03 F1 still toggles the debug panel")
		_push_key(KEY_F1)
		await _ticks(2)
		var wave_before: int = Game.wave
		_push_key(KEY_F2)
		await _until(func() -> bool:
			return Game.wave == wave_before + 1, 4.0, "F2 skips to next wave")
		_check(Game.wave == wave_before + 1, "R03 F2 still skips a wave")

	# ---- R03: game-over ENTER reboots and ESC abandons (real transitions)
	_arena._on_player_died()
	if not await _until(func() -> bool:
		return _arena._over_panel != null and _arena._over_panel.visible, 6.0, "game over panel"):
		return _finish()
	var dead_arena := _arena
	_push_key(KEY_ENTER)
	if not await _until(func() -> bool:
		return _arena_loaded() and get_tree().current_scene != dead_arena, 8.0, "game-over ENTER reboots"):
		return _finish()
	_arena = get_tree().current_scene
	await _ticks(10)
	_check(not get_tree().paused and Game.state == Game.State.PLAYING, "R03 game-over ENTER starts a fresh run")
	_arena._on_player_died()
	if not await _until(func() -> bool:
		return _arena._over_panel != null and _arena._over_panel.visible, 6.0, "second game over panel"):
		return _finish()
	dead_arena = _arena
	_push_key(KEY_ESCAPE)
	if not await _until(func() -> bool:
		return get_tree().current_scene != null and get_tree().current_scene.name == "Menu", 8.0, "game-over ESC returns to menu"):
		return _finish()
	_check(Game.state == Game.State.MENU, "R03 game-over ESC abandons to menu")
	_finish()

func _dict_total(d: Dictionary) -> int:
	var total := 0
	for k in d:
		total += int(d[k])
	return total

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

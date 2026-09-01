extends Node

var _fails := 0
var _controls: TouchControls
var _player: Player

func _ready() -> void:
	_player = Player.new()
	_player.position = Vector2(640, 360)
	add_child(_player)
	_controls = TouchControls.new()
	_controls.size = Vector2(1280, 720)
	_controls.player = _player
	add_child(_controls)
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PROBE_PASS ", message)
	else:
		_fails += 1
		print("PROBE_FAIL ", message)

func _run() -> void:
	await get_tree().process_frame
	_player.dash_cd = 0.0
	_player.dash_t = 0.0
	_player.invuln = 999.0
	_touch(Vector2(900, 400), true, 1)
	_check(_controls._aim_id == 1 and _controls._aim_active, "first finger owns the aim stick")
	var dash_before := _player.dash_id
	print("PROBE_INFO controls_size=", _controls.size, " dash_rect=", _controls._dash_btn())
	_touch(_controls._dash_btn().get_center(), true, 2)
	print("PROBE_INFO after_dash_touch dash_id=", _player.dash_id, " dash_cd=", _player.dash_cd, " dash_t=", _player.dash_t, " touches=", _controls.debug_touch_count)
	_check(_player.dash_id == dash_before + 1, "second finger can activate DASH while aim finger is held")
	_check(_controls._aim_id == 1 and _controls._aim_active, "DASH does not steal the aim finger")
	_touch(_controls._dash_btn().get_center(), false, 2)
	_touch(Vector2(900, 400), false, 1)
	_check(_controls._aim_id == -1 and not _controls._aim_active, "both touch lifecycles release cleanly")
	_player.oc_ready = true
	_touch(Vector2(900, 400), true, 3)
	var overclock_before := _player.overclock_active
	_touch(_controls._oc_btn().get_center(), true, 4)
	_check(_player.overclock_active and not overclock_before, "second finger can activate BOOST while aim finger is held")
	_check(_controls._aim_id == 3 and _controls._aim_active, "BOOST does not steal the aim finger")
	_touch(_controls._oc_btn().get_center(), false, 4)
	_touch(Vector2(900, 400), false, 3)
	_finish()

func _touch(position: Vector2, pressed: bool, index: int) -> void:
	var event := InputEventScreenTouch.new()
	event.position = get_viewport().get_final_transform() * position
	event.pressed = pressed
	event.index = index
	get_viewport().push_input(event)

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

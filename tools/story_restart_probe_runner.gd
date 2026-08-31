extends Node

var _fails := 0

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PROBE_PASS ", message)
	else:
		_fails += 1
		print("PROBE_FAIL ", message)

func _until(condition: Callable, timeout_s: float, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await get_tree().process_frame
	print("PROBE_FAIL timeout ", label)
	_fails += 1
	return false

func _run() -> void:
	Game.unlocked_programs["kernel"] = true
	var started := Game.start_story(0)
	_check(started, "story run starts")
	if not started:
		_finish()
		return
	if not await _until(func() -> bool:
		return get_tree().current_scene != null and get_tree().current_scene.name == "Arena", 8.0, "story arena load"):
		_finish()
		return
	await get_tree().create_timer(0.3).timeout
	Game.state = Game.State.PLAYING
	get_tree().current_scene._state = "play"
	var old_stage := Game.story_stage_index
	Input.action_press("restart")
	await get_tree().create_timer(0.95).timeout
	Input.action_release("restart")
	_check(Game.mode == "story", "hold R preserves story mode")
	_check(Game.story_stage_index == old_stage, "hold R preserves story stage")
	_check(await _until(func() -> bool:
		return get_tree().current_scene != null and get_tree().current_scene.name == "Arena" and Game.state == Game.State.PLAYING, 8.0, "story restart") , "hold R starts another arena")
	_finish()

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

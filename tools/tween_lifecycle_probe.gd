extends Node

## P3 red/green probe: retriggering a tip or boss intro must not leave two
## timelines writing the same presentation nodes at once.

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

func _active_tweens() -> int:
	return get_tree().get_processed_tweens().size()

func _run() -> void:
	var arena_script: Script = load("res://src/arena/arena.gd")
	_check(arena_script != null, "Arena script loads for tween lifecycle audit")
	if arena_script == null:
		_finish()
		return

	Game.mode = "classic"
	Game.state = Game.State.PLAYING
	Game.patch_levels = {}
	Game.stats = {"time": 0.0, "wave": 1, "kills": 0, "shots": 0, "hits": 0, "damage": 0, "boss_kills": 0, "heals": {}}
	var arena: Node = arena_script.new()
	add_child(arena)
	await _ticks(4)

	var tip_before := _active_tweens()
	arena.call("_show_tip")
	var tip_first := _active_tweens()
	arena.call("_show_tip")
	await _ticks(1)
	var tip_second := _active_tweens()
	_check(tip_first > tip_before, "tip trigger creates its presentation timeline")
	_check(tip_second <= tip_first, "repeated tip trigger replaces the previous timeline")

	var intro = arena.get("_intro_kit")
	_check(intro != null and intro.has_method("_run_boss_intro"), "boss intro exposes its lifecycle entrypoint")
	if intro != null and intro.has_method("_run_boss_intro"):
		var boss_before := _active_tweens()
		intro.call("_run_boss_intro")
		var boss_first := _active_tweens()
		intro.call("_run_boss_intro")
		await _ticks(1)
		var boss_second := _active_tweens()
		_check(boss_first > boss_before, "boss intro trigger creates its presentation timelines")
		_check(boss_second <= boss_first, "repeated boss intro replaces the previous timelines")

	arena.queue_free()
	await _ticks(1)
	_finish()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().paused = false
	get_tree().quit(1 if _fails > 0 else 0)

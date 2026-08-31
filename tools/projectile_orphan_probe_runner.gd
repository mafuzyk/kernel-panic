extends Node

## Projectile orphan probe — regression coverage for R04 via the real arena
## scene and the real player fire path (arena.player._shoot()). R04: a leaked
## `var b := PlayerBullet.new()` inside _shoot() adds one orphan Node per shot.
## Reusable: exit code 1 on any failure.
## Direct arena/player calls here are state preparation and the fire method
## itself (the bug is internal to _shoot, not dispatch-bound).

var _fails := 0
var _arena: Arena = null

func _ready() -> void:
	_watchdog.call_deferred()
	_run.call_deferred()

func _watchdog() -> void:
	await get_tree().create_timer(90.0, true, false, true).timeout
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

func _orphans() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

func _live_bullets(arena: Arena) -> int:
	var count := 0
	for c in arena.get_children():
		if is_instance_valid(c) and c is PlayerBullet:
			count += 1
	return count

func _arena_loaded() -> bool:
	return get_tree().current_scene != null and get_tree().current_scene.name == "Arena"

func _wait_arena_change(label: String) -> bool:
	var prev_id := get_tree().current_scene.get_instance_id() if get_tree().current_scene != null else 0
	return await _until(func() -> bool:
		return _arena_loaded() and get_tree().current_scene.get_instance_id() != prev_id, 8.0, label)

func _load_classic() -> bool:
	Game.start_run()
	if not await _wait_arena_change("classic arena load"):
		return false
	_arena = get_tree().current_scene
	await _ticks(20)
	Game.state = Game.State.PLAYING
	_arena._state = "play"
	return true

func _run() -> void:
	Game.unlocked_programs["kernel"] = true
	Game.set_program("kernel")
	await _ticks(5)

	if not await _load_classic():
		return _finish()
	Game.patch_levels = {}

	# ---- R04 control period: idle PLAYING ticks must not shift the orphan count
	var o_a := _orphans()
	await _ticks(30)
	var o_b := _orphans()
	print("PROBE_INFO orphans idle before=", o_a, " after=", o_b)
	_check(o_b - o_a == 0, "R04 idle control period adds no orphans")

	# ---- R04 simple shots: 10 synchronous _shoot() calls, counted in-frame.
	# Live bullets are counted immediately after the calls (no await): a bullet
	# only expires via life/collision once physics resumes, so the same-frame
	# count is deterministic.
	var o0 := _orphans()
	for i in 10:
		_arena.player._shoot()
	var o1 := _orphans()
	print("PROBE_INFO orphans shots before=", o0, " after=", o1, " delta=", o1 - o0)
	_check(o1 - o0 == 0, "R04 ten shots add no orphan nodes")
	var live0 := _live_bullets(_arena)
	print("PROBE_INFO live bullets after 10 shots=", live0)
	_check(live0 == 10, "R04 ten shots keep ten live bullets in the tree")

	# ---- R04 splitshot: level 2 -> three projectiles per shot, still no leak
	Game.patch_levels["splitshot"] = 2
	var before := _live_bullets(_arena)
	var o2 := _orphans()
	for i in 5:
		_arena.player._shoot()
	var o3 := _orphans()
	var after := _live_bullets(_arena)
	print("PROBE_INFO splitshot orphans before=", o2, " after=", o3, " delta=", o3 - o2, " live before=", before, " live after=", after)
	_check(o3 - o2 == 0, "R04 splitshot bursts add no orphan nodes")
	_check(after - before == 15, "R04 splitshot keeps three live bullets per shot")
	Game.patch_levels["splitshot"] = 0

	# ---- R04 restart: a fresh run/stage must not leak per-shot either
	Game.start_run()
	if not await _wait_arena_change("restarted arena load"):
		return _finish()
	_arena = get_tree().current_scene
	await _ticks(20)
	Game.state = Game.State.PLAYING
	_arena._state = "play"
	var o4 := _orphans()
	for i in 10:
		_arena.player._shoot()
	var o5 := _orphans()
	print("PROBE_INFO restart orphans before=", o4, " after=", o5, " delta=", o5 - o4)
	_check(o5 - o4 == 0, "R04 shots after a restart add no orphan nodes")
	var live1 := _live_bullets(_arena)
	print("PROBE_INFO restart live bullets=", live1)
	_check(live1 == 10, "R04 restart run spawns ten live bullets")

	_finish()

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

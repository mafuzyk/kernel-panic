extends Node

## Temple_god boss probe — regression coverage for R06 via the REAL boss path:
## real story intro dismissal (ESC), real spawner wave progression (wave_started
## signal), real boss spawn timer, real death chain (died -> arena handler ->
## complete_story_stage). R06: _spawn_story_boss() instantiates RootBoss
## unconditionally, so TempleOS ends with ROOT.exe instead of GOD.
## Reusable: exit code 1 on any failure.
## The reaper loop (take_hit 999 on every enemy each physics frame) only
## advances waves and keeps the player safe; it never touches spawner internals.

var _fails := 0
var _arena: Arena = null
var _last_wave := -1
var _last_is_boss := false

func _ready() -> void:
	_watchdog.call_deferred()
	_run.call_deferred()

func _watchdog() -> void:
	# Boss + split + clear takes time; 240s headroom.
	await get_tree().create_timer(240.0, true, false, true).timeout
	print("PROBE_FAIL watchdog timeout")
	get_tree().quit(1)

func _check(cond: bool, msg: String) -> bool:
	if cond:
		print("PROBE_PASS ", msg)
	else:
		_fails += 1
		print("PROBE_FAIL ", msg)
	return cond

func _precond(cond: bool, msg: String) -> bool:
	if not cond:
		_fails += 1
		print("PROBE_FAIL precondition: ", msg)
		return false
	return true

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

func _reap() -> void:
	# Ceifador: kill every enemy each physics frame. Advances story waves the
	# real way (queue drains, alive==0, intermission, next wave) and keeps the
	# player safe. Never touches spawner internals.
	if _arena == null or not is_instance_valid(_arena):
		return
	for e in _arena.enemy_list.duplicate():
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			e.take_hit(999, e.global_position)

func _reap_until(cond: Callable, timeout_s: float, label: String) -> bool:
	# _until cannot host the reaper (sync callable): loop manually. Cond is
	# checked BEFORE reaping so a freshly spawned boss is never killed before
	# the checks below run in the same frame.
	var deadline := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		_reap()
		await get_tree().physics_frame
	_check(false, "timeout waiting for " + label)
	return false

func _arena_loaded() -> bool:
	return get_tree().current_scene != null and get_tree().current_scene.name == "Arena"

func _wait_arena_change(label: String) -> bool:
	var prev := get_tree().current_scene
	return await _until(func() -> bool:
		return _arena_loaded() and get_tree().current_scene != prev, 8.0, label)

func _push_escape() -> void:
	var press := InputEventKey.new()
	press.physical_keycode = KEY_ESCAPE
	press.keycode = KEY_ESCAPE
	press.pressed = true
	get_viewport().push_input(press)
	var release := InputEventKey.new()
	release.physical_keycode = KEY_ESCAPE
	release.keycode = KEY_ESCAPE
	release.pressed = false
	get_viewport().push_input(release)

func _run() -> void:
	# ---- boot: kernel program, unlock the final stage the way the save would
	Game.unlocked_programs["kernel"] = true
	Game.set_program("kernel")
	await _ticks(5)

	# State prep (documented): story_stage_unlocked() requires the previous
	# stage cleared, so mark the stage before temple_god cleared in the save
	# dictionary — same shape the real save writes.
	var idx := -1
	for i in Game.story_stage_count():
		if Game.story_stage_id(i) == "temple_god":
			idx = i
	if not _precond(idx > 0, "temple_god stage exists at index > 0 (idx=%d)" % idx):
		return _finish()
	Game.story_cleared[str(Game.story_stage_def(idx - 1).get("id", ""))] = true
	if not _check(Game.start_story(idx), "R06 temple_god story run starts"):
		return _finish()
	if not await _wait_arena_change("temple_god arena load"):
		return _finish()
	_arena = get_tree().current_scene
	await _ticks(10)
	Game.state = Game.State.PLAYING
	_arena._state = "play"

	# Track real wave progression from the spawner signal.
	_arena.spawner.wave_started.connect(func(wave: int, is_boss: bool) -> void:
		_last_wave = wave
		_last_is_boss = is_boss)
	var waves_n := int(Game.story_stage_def(idx)["waves"].size())
	print("PROBE_INFO waves_n=", waves_n, " boss_kind=", str(Game.story_stage_def(idx).get("boss_kind", "")))

	# ---- intro: real ESC dismissal (calls _begin_story_spawning for real)
	if not await _until(func() -> bool:
		return _arena._story_intro_state == 2 and _arena._story_intro_t >= _arena.STORY_INTRO_MIN_HOLD, 6.0, "story intro reaches hold"):
		return _finish()
	_push_escape()
	if not await _until(func() -> bool:
		return _arena._story_intro_state != 2, 4.0, "story intro dismissed"):
		return _finish()
	print("PROBE_INFO intro dismissed, story spawning started")

	# ---- real wave progression: reap each physics frame until the boss wave
	if not await _reap_until(func() -> bool:
		return _last_is_boss and _last_wave == waves_n, 60.0, "temple_god boss wave starts"):
		return _finish()
	_check(_last_is_boss and _last_wave == waves_n, "R06 final wave is the GOD boss wave")

	# ---- boss spawn (nucleus of the RED): internal 1.5s timer in _spawn_story_boss
	if not await _reap_until(func() -> bool:
		return _arena.spawner._boss != null and is_instance_valid(_arena.spawner._boss), 20.0, "temple_god boss spawns"):
		return _finish()
	var boss = _arena.spawner._boss
	print("PROBE_INFO boss_title=", str(boss.boss_title), " isGodBoss=", boss is GodBoss, " isRootBoss=", boss is RootBoss)
	_check(boss is GodBoss, "R06 temple_god final wave spawns the GOD boss (GodBoss)")
	_check(str(boss.boss_title) == "GOD", "R06 boss title is GOD, not ROOT.exe")
	_check(_arena.hud.boss == boss, "R06 HUD tracks the spawned boss")

	# ---- reward through the real death chain (passes on both: the reward is
	# keyed on the stage id, which is exactly what the review flagged — the red
	# unlocks it even with the wrong boss).
	if not await _reap_until(func() -> bool:
		return bool(Game.story_cleared.get("temple_god", false)), 60.0, "temple_god story clears"):
		return _finish()
	_check(bool(Game.story_cleared.get("temple_god", false)), "R06 temple_god clears through the real boss path")
	_check(Game.temple_rainbow_unlocked, "R06 temple reward unlocks after the stage clears")

	_finish()

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

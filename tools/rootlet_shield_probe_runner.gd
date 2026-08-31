extends Node

## Rootlet shield probe — regression coverage for R05 via the real gameplay
## path: motes are collected by MoteField's physics sweep (spawn at +10px,
## collected next physics frame) and kill bonuses arrive through the real
## died signal chain (DroneEnemy.take_hit -> died -> arena._on_enemy_died ->
## player.add_kill_mote_bonus()). R05: after the shield is consumed, mote
## collection must recharge the shield instead of leaking into the overclock
## meter. Reusable: exit code 1 on any failure.
## Direct player calls here are state preparation only (take_damage is the
## real damage routine; try_overclock exercises the real guards).

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

func _precond(cond: bool, msg: String) -> bool:
	# Unexpected state (e.g. external damage consumed the shield) is reported
	# separately so cascading behavior failures stay distinguishable.
	if not cond:
		_fails += 1
		print("PROBE_FAIL precondition: ", msg)
		return false
	return true

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _physics_ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _until(fn: Callable, timeout_s: float, label: String) -> bool:
	# Monotonic real-time deadline: frame counting drifts with pause/load hitches.
	var deadline := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if fn.call():
			return true
		await get_tree().process_frame
	_check(false, "timeout waiting for " + label)
	return false

func _arena_loaded() -> bool:
	return get_tree().current_scene != null and get_tree().current_scene.name == "Arena"

func _wait_arena_change(label: String) -> bool:
	var prev := get_tree().current_scene
	return await _until(func() -> bool:
		return _arena_loaded() and get_tree().current_scene != prev, 8.0, label)

func _prep_arena(arena: Arena) -> void:
	# Deterministic playfield: play state, no new spawns, no residual enemies.
	Game.state = Game.State.PLAYING
	arena._state = "play"
	arena.spawner.stop()
	for e in arena.enemy_list.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	await _ticks(2)

func _spawn_motes(arena: Arena, n: int, at: Vector2) -> void:
	# +10px off the player: inside the 20px collect sweep, outside the <=1px
	# borderline case; zero velocity so the first physics frame collects them.
	for i in n:
		arena.mote_field.spawn(at + Vector2(10, 0))

func _kill_drone(arena: Arena, at: Vector2) -> bool:
	# Real kill path: died signal -> arena._on_enemy_died -> kill bonus.
	# 260px away: outside the 115px magnet radius and out of contact range.
	var e := DroneEnemy.new()
	e.position = at + Vector2(260, 0)
	arena.enemy_container.add_child(e)
	await _physics_ticks(2)
	if not _precond(is_instance_valid(e) and not e.is_queued_for_deletion(), "drone alive before the killing blow"):
		return false
	e.take_hit(999, e.global_position)
	return true

func _run() -> void:
	# ---- boot: ROOTLET program, fresh run, deterministic playfield
	Game.unlocked_programs["rootlet"] = true
	Game.set_program("rootlet")
	await _ticks(5)
	Game.start_run()
	if not await _wait_arena_change("rootlet arena load"):
		return _finish()
	_arena = get_tree().current_scene
	await _ticks(10)
	await _prep_arena(_arena)
	var p: Player = _arena.player
	print("PROBE_INFO boot shield_mode=", bool(p.prog.get("shield_mode", false)), " shield_ready=", p.shield_ready, " shield_meter=", p.shield_meter, " meter=", p.meter, " oc_ready=", p.oc_ready)
	_check(bool(p.prog.get("shield_mode", false)) and p.shield_ready and is_zero_approx(p.shield_meter), "R05 rootlet boots with passive shield ready")

	# ---- FASE 1: one real hit consumes the passive shield
	p.take_damage(p.global_position)
	_check(not p.shield_ready and is_zero_approx(p.shield_meter), "R05 one hit consumes the shield")
	_check(p.invuln > 0.0, "R05 shield consumption grants brief invuln")

	# ---- FASE 2: 17 real mote collections recharge the shield (core of R05)
	_spawn_motes(_arena, 17, p.global_position)
	await _physics_ticks(12)
	print("PROBE_INFO fase2 shield_ready=", p.shield_ready, " shield_meter=", p.shield_meter, " meter=", p.meter, " oc_ready=", p.oc_ready)
	_check(p.shield_ready and is_equal_approx(p.shield_meter, Balance.OC_METER_MAX), "R05 shield recharges from real mote collection after consumption")
	_check(not p.oc_ready and is_zero_approx(p.meter), "R05 rootlet motes never feed the overclock meter")

	# ---- FASE 3: excess motes with a full shield overflow as score
	var score_before: int = Game.score
	_spawn_motes(_arena, 3, p.global_position)
	await _physics_ticks(12)
	print("PROBE_INFO fase3 shield_ready=", p.shield_ready, " shield_meter=", p.shield_meter, " meter=", p.meter, " oc_ready=", p.oc_ready, " score_delta=", Game.score - score_before)
	_check(is_equal_approx(p.shield_meter, Balance.OC_METER_MAX) and p.shield_ready, "R05 full shield stays full with excess motes")
	_check(not p.oc_ready and is_zero_approx(p.meter), "R05 full shield does not feed the overclock meter")
	_check(Game.score - score_before == 15, "R05 full shield excess motes score as scrap overflow")

	# ---- FASE 4: kill bonus with a full shield leaves the meter untouched
	if await _kill_drone(_arena, p.global_position):
		print("PROBE_INFO fase4 same-frame shield_meter=", p.shield_meter, " meter=", p.meter, " oc_ready=", p.oc_ready)
		_check(is_equal_approx(p.shield_meter, Balance.OC_METER_MAX), "R05 kill bonus with full shield does not change the meter")
	await get_tree().create_timer(1.0, true, false, true).timeout
	print("PROBE_INFO fase4 post-drain shield_meter=", p.shield_meter, " meter=", p.meter, " oc_ready=", p.oc_ready, " score=", Game.score)

	# ---- FASE 5: second hit consumes the recharged shield
	await _until(func() -> bool:
		return p.invuln <= 0.0, 3.0, "invuln window expires")
	if not _precond(p.shield_ready and is_equal_approx(p.shield_meter, Balance.OC_METER_MAX), "shield is recharged before the second hit"):
		return _finish()
	p.take_damage(p.global_position)
	_check(not p.shield_ready and is_zero_approx(p.shield_meter), "R05 second hit consumes the recharged shield")

	# ---- FASE 6: kill bonus charges the shield after consumption
	await _until(func() -> bool:
		return p.invuln <= 0.0, 3.0, "invuln window expires before kill bonus")
	if await _kill_drone(_arena, p.global_position):
		print("PROBE_INFO fase6 same-frame shield_meter=", p.shield_meter, " meter=", p.meter, " oc_ready=", p.oc_ready)
		_check(is_equal_approx(p.shield_meter, Balance.MOTE_KILL_VALUE), "R05 kill bonus charges the shield after consumption")
		_check(not p.oc_ready and is_zero_approx(p.meter), "R05 kill bonus never feeds the overclock meter for rootlet")

	# ---- FASE 7: finish the recharge and consume once more
	var need := int(ceil((Balance.OC_METER_MAX - p.shield_meter) / Balance.MOTE_VALUE))
	print("PROBE_INFO fase7 need=", need, " motes already drifting=", _arena.mote_field.count())
	_spawn_motes(_arena, need, p.global_position)
	await _until(func() -> bool:
		return p.shield_ready, 6.0, "shield full recharge")
	print("PROBE_INFO fase7 shield_ready=", p.shield_ready, " shield_meter=", p.shield_meter)
	_check(p.shield_ready and is_equal_approx(p.shield_meter, Balance.OC_METER_MAX), "R05 shield fully recharges from motes and kill bonus")
	await _until(func() -> bool:
		return p.invuln <= 0.0, 3.0, "invuln window expires before third hit")
	p.take_damage(p.global_position)
	_check(not p.shield_ready and is_zero_approx(p.shield_meter), "R05 third hit consumes the again-recharged shield")

	# ---- FASE 8: rootlet guard — overclock never activates
	p.try_overclock()
	_check(not p.overclock_active, "R05 rootlet never overclocks")

	# ---- FASE 8B — KILL COMPLETA A RECARGA (bloqueador Codex) ----
	# A carga por motes ativa o escudo ao atingir o cap; o kill bonus precisa
	# fazer o mesmo, senão o escudo fica cheio mas desativado para sempre.
	await _until(func() -> bool:
		return p.invuln <= 0.0, 3.0, "invuln window expires before kill-completion cycle")
	if not _precond(not p.shield_ready and is_zero_approx(p.shield_meter), "shield consumed before the kill-completion cycle"):
		return _finish()
	_spawn_motes(_arena, 16, p.global_position)
	await _physics_ticks(12)
	print("PROBE_INFO fase8b partial shield_meter=", p.shield_meter, " shield_ready=", p.shield_ready)
	_check(is_equal_approx(p.shield_meter, 96.0) and not p.shield_ready, "R05 partial mote recharge leaves the shield inactive")
	if await _kill_drone(_arena, p.global_position):
		print("PROBE_INFO fase8b post-kill1 shield_meter=", p.shield_meter, " shield_ready=", p.shield_ready)
		_check(is_equal_approx(p.shield_meter, 98.0) and not p.shield_ready, "R05 kill bonus below the cap does not activate the shield")
	var emissions: Array = []
	var on_meter := func(v: float, rdy: bool) -> void:
		emissions.append([v, rdy])
	p.meter_changed.connect(on_meter)
	if await _kill_drone(_arena, p.global_position):
		print("PROBE_INFO fase8b post-kill2 shield_meter=", p.shield_meter, " shield_ready=", p.shield_ready, " emissions=", emissions)
		_check(p.shield_ready and is_equal_approx(p.shield_meter, Balance.OC_METER_MAX), "R05 kill bonus activates the shield at full charge")
		_check(not emissions.is_empty() and is_equal_approx(float(emissions[emissions.size() - 1][0]), Balance.OC_METER_MAX) and bool(emissions[emissions.size() - 1][1]), "R05 kill completion emits the ready state on meter_changed")
	var score_before_8b: int = Game.score
	_spawn_motes(_arena, 1, p.global_position)
	await _physics_ticks(12)
	print("PROBE_INFO fase8b post-mote shield_meter=", p.shield_meter, " shield_ready=", p.shield_ready, " score_delta=", Game.score - score_before_8b)
	_check(p.shield_ready and is_equal_approx(p.shield_meter, Balance.OC_METER_MAX), "R05 mote after kill-completed recharge does not deadlock")
	_check(Game.score - score_before_8b == 5, "R05 mote with kill-recharged shield overflows to scrap")
	var count_before := emissions.size()
	if await _kill_drone(_arena, p.global_position):
		print("PROBE_INFO fase8b post-kill3 shield_meter=", p.shield_meter, " shield_ready=", p.shield_ready, " emissions=", emissions.size())
		_check(p.shield_ready and is_equal_approx(p.shield_meter, Balance.OC_METER_MAX) and emissions.size() == count_before, "R05 kill bonus with full shield emits nothing and keeps the meter")
	await _until(func() -> bool:
		return p.invuln <= 0.0, 3.0, "invuln window expires before kill-recharged hit")
	var hp_before: int = p.hp
	p.take_damage(p.global_position)
	print("PROBE_INFO fase8b post-hit hp=", p.hp, " shield_meter=", p.shield_meter, " shield_ready=", p.shield_ready)
	_check(p.hp == hp_before, "R05 kill-recharged shield absorbs a hit without HP loss")
	_check(not p.shield_ready and is_zero_approx(p.shield_meter), "R05 kill-recharged shield is consumed by the hit")
	_spawn_motes(_arena, 17, p.global_position)
	await _until(func() -> bool:
		return p.shield_ready, 6.0, "shield recharge after kill-recharged consume")
	print("PROBE_INFO fase8b recharge2 shield_meter=", p.shield_meter, " shield_ready=", p.shield_ready)
	_check(p.shield_ready and is_equal_approx(p.shield_meter, Balance.OC_METER_MAX), "R05 shield recharges again after the kill-recharged consume")
	p.meter_changed.disconnect(on_meter)

	# ---- FASE 9: kernel control — motes keep charging overclock there
	Game.set_program("kernel")
	Game.start_run()
	if not await _wait_arena_change("kernel arena load"):
		return _finish()
	_arena = get_tree().current_scene
	await _ticks(10)
	await _prep_arena(_arena)
	var p2: Player = _arena.player
	print("PROBE_INFO fase9 shield_mode=", bool(p2.prog.get("shield_mode", false)), " shield_ready=", p2.shield_ready, " shield_meter=", p2.shield_meter, " meter=", p2.meter, " oc_ready=", p2.oc_ready)
	_spawn_motes(_arena, 17, p2.global_position)
	await _physics_ticks(12)
	print("PROBE_INFO fase9 post-collect shield_ready=", p2.shield_ready, " shield_meter=", p2.shield_meter, " meter=", p2.meter, " oc_ready=", p2.oc_ready)
	_check(not p2.shield_ready and is_zero_approx(p2.shield_meter), "R05 kernel never charges the shield")
	_check(p2.oc_ready and is_equal_approx(p2.meter, Balance.OC_METER_MAX), "R05 kernel keeps overclock charging from motes")
	p2.try_overclock()
	_check(p2.overclock_active, "R05 kernel overclock still activates")

	_finish()

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

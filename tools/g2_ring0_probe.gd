extends Node

## G2B focused probe. Ring-0 is treated as an explicit optional patch: the
## second press extends the active overclock window once, then imposes a full
## base overclock recovery lock. The probe also checks that DAEMON dash state
## survives the re-press.

var _fails := 0
var _players: Array[Player] = []

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PROBE_PASS ", message)
	else:
		_fails += 1
		print("PROBE_FAIL ", message)

func _new_player(program_id: String) -> Player:
	Game.program = program_id
	var player := Player.new()
	player.position = Vector2(640, 360)
	add_child(player)
	_players.append(player)
	return player

func _run() -> void:
	Game.state = Game.State.PLAYING
	Game.mode = "classic"
	Game.score = 0
	Game.mult = 1
	Game.patch_levels = {"ring0": 1}
	Game.stats = {"kills": 0, "shots": 0, "hits": 0, "damage": 0, "time": 0.0, "wave": 1, "boss_kills": 0, "heals": {}}
	var kernel := _new_player("kernel")
	await _ticks(2)
	kernel.oc_ready = true
	kernel.meter = Balance.OC_METER_MAX
	var hp_before := kernel.hp
	kernel.try_overclock()
	var first_duration := kernel.oc_t
	_check(kernel.overclock_active and kernel.overclock_stack_count() == 1, "Ring-0 first press starts one overclock stack")
	kernel.try_overclock()
	_check(kernel.overclock_active and kernel.overclock_stack_count() == 2, "Ring-0 re-press stacks the active overclock once")
	_check(kernel.oc_t > first_duration and is_equal_approx(kernel.oc_t, first_duration + kernel.oc_duration()), "Ring-0 second press extends the active window by one existing duration")
	_check(kernel.hp == hp_before, "Ring-0 double overclock has no integrity cost")

	var daemon := _new_player("daemon")
	await _ticks(2)
	daemon.oc_ready = true
	daemon.meter = Balance.OC_METER_MAX
	daemon.try_overclock()
	var dash_before := daemon.dash_id
	var charges_before := daemon.available_dash_charges()
	daemon.request_dash(Vector2.RIGHT)
	_check(daemon.dash_id == dash_before + 1 and daemon.available_dash_charges() == charges_before - 1, "DAEMON can dash during the first Ring-0 overclock stack")
	var dash_t_before := daemon.dash_t
	daemon.try_overclock()
	_check(daemon.overclock_stack_count() == 2 and daemon.overclock_active, "DAEMON re-press stacks without cancelling its dash overclock")
	_check(daemon.dash_t >= dash_t_before and daemon.hp == daemon.max_hp, "DAEMON dash state and integrity survive the Ring-0 re-press")

	kernel.oc_t = 0.001
	await _ticks(2)
	_check(not kernel.overclock_active and kernel.overclock_stack_count() == 0, "double-stack overclock still ends normally")
	_check(kernel.overclock_recharge_lock() >= Balance.OC_DURATION - 0.1, "double-stack overclock retains its recovery lock after expiry")
	daemon.oc_t = 0.001
	await _ticks(2)
	_check(not daemon.overclock_active and daemon.overclock_stack_count() == 0, "double-stack overclock ends and clears stack state")
	_check(daemon.overclock_recharge_lock() >= Balance.OC_DURATION - 0.1, "double-stack overclock imposes a significantly longer post-use cooldown")
	daemon.oc_ready = true
	daemon.meter = Balance.OC_METER_MAX
	daemon.try_overclock()
	_check(not daemon.overclock_active, "post-double cooldown blocks immediate reactivation")

	Game.patch_levels = {}
	var plain := _new_player("kernel")
	await _ticks(2)
	plain.oc_ready = true
	plain.meter = Balance.OC_METER_MAX
	plain.try_overclock()
	var plain_duration := plain.oc_t
	plain.try_overclock()
	_check(plain.overclock_active and plain.overclock_stack_count() == 1 and is_equal_approx(plain.oc_t, plain_duration), "without Ring-0 the second press is inert")

	Game.program = "rootlet"
	Game.patch_levels = {"ring0": 1}
	var rootlet := _new_player("rootlet")
	await _ticks(2)
	rootlet.try_overclock()
	_check(not rootlet.overclock_active and rootlet.overclock_stack_count() == 0, "Ring-0 cannot bypass Rootlet shield mode")
	_finish()

func _ticks(count: int) -> void:
	for _i in count:
		await get_tree().process_frame

func _finish() -> void:
	for player in _players:
		if is_instance_valid(player):
			player.queue_free()
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

extends Node

## H1 regression probe: the live encounter register owns the continuous cycle
## label, while the large banner announces the event without repeating it.

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

func _run() -> void:
	Game.mode = "classic"
	Game.state = Game.State.PLAYING
	Game.wave = 1
	Game.stats = {"time": 0.0, "wave": 1, "kills": 0, "shots": 0, "hits": 0, "damage": 0, "boss_kills": 0, "heals": {}}
	var arena_script: Script = load("res://src/arena/arena.gd")
	_check(arena_script != null, "arena script loads for the live H1 path")
	if arena_script == null:
		_finish()
		return
	var arena: Node = arena_script.new()
	add_child(arena)
	await _ticks(3)
	var hud: Node = arena.get("hud")
	_check(hud != null and is_instance_valid(hud), "live arena exposes the legacy HUD adapter")
	if hud == null or not is_instance_valid(hud):
		arena.queue_free()
		await _ticks(1)
		_finish()
		return
	_check(not bool(hud.call("vnext_hud_enabled")), "H1 probe runs against the legacy HUD composition")
	arena.call("_on_wave_started", 2, false)
	_check(str(hud.get("_banner_text")) == "WAVE INBOUND", "normal wave banner names the event instead of repeating the cycle")
	_check(not str(hud.get("_banner_text")).contains("CYCLE"), "normal wave banner has no continuous cycle label")
	_check(str(hud.get("_banner_sub")) == "PURGE THE DAEMONS", "normal wave banner retains its actionable event copy")
	_check(Game.wave == 2, "encounter state still owns the live cycle number")
	arena.call("_on_wave_started", 4, true)
	_check(str(hud.get("_banner_text")) == "ANOMALY INBOUND", "boss banner names the anomaly event")
	_check(not str(hud.get("_banner_text")).contains("CYCLE"), "boss banner does not duplicate the continuous cycle label")
	_check(str(hud.get("_banner_sub")) == "ROOT DAEMON INBOUND", "boss banner retains the boss event copy")
	arena.queue_free()
	await _ticks(1)
	_finish()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

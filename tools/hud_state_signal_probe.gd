extends Node

## H4 regression probe: state labels must communicate health, ability, dash and
## damage direction without requiring the player to decode color alone.

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
	var hud_script: Script = load("res://src/ui/hud.gd")
	_check(hud_script != null, "legacy HUD script loads for state signaling")
	if hud_script == null:
		_finish()
		return
	var hud: Node = hud_script.new()
	hud.set("size", Vector2(1366, 768))
	add_child(hud)
	await _ticks(2)
	hud.set("_hp", 1)
	hud.set("_max_hp", 4)
	hud.set("_dash_frac", 0.0)
	hud.set("_oc_ready", false)
	hud.set("_oc_active", false)
	var critical: Dictionary = hud.call("state_signal_snapshot")
	_check(str(critical.get("integrity_state", "")) == "CRITICAL", "critical health has an explicit state label")
	_check(str(critical.get("integrity", "")).contains("INTEGRITY // CRITICAL"), "critical health label is readable without color")
	_check(str(critical.get("ability", "")) == "OVERCLOCK CHARGING", "empty overclock has an explicit charging state")
	_check(str(critical.get("dash", "")) == "DASH // COOLDOWN", "dash cooldown has an explicit state label")
	_check(str(critical.get("damage_direction", "")) == "NONE", "no damage keeps the direction marker neutral")
	hud.queue_free()
	await _ticks(1)

	Game.mode = "classic"
	Game.program = "kernel"
	Game.patch_levels = {}
	Game.state = Game.State.PLAYING
	Game.stats = {"time": 0.0, "wave": 1, "kills": 0, "shots": 0, "hits": 0, "damage": 0, "boss_kills": 0, "heals": {}}
	var arena_script: Script = load("res://src/arena/arena.gd")
	var arena: Node = arena_script.new()
	add_child(arena)
	await _ticks(3)
	var player: Node = arena.get("player")
	var live_hud: Node = arena.get("hud")
	_check(player != null and live_hud != null, "live Arena exposes player and HUD for damage direction")
	if player != null and live_hud != null:
		player.call("take_damage", player.get("global_position") + Vector2(100.0, 0.0), "H4 PROBE")
		await _ticks(1)
		var damaged: Dictionary = live_hud.call("state_signal_snapshot")
		_check(str(damaged.get("damage_direction", "")) == "E", "live damage publishes a cardinal direction label")
		_check(str(damaged.get("integrity", "")).contains("HIT FROM E"), "live HUD includes damage direction in text")
	arena.queue_free()
	await _ticks(1)

	Game.program = "rootlet"
	Game.state = Game.State.PLAYING
	Game.stats = {"time": 0.0, "wave": 1, "kills": 0, "shots": 0, "hits": 0, "damage": 0, "boss_kills": 0, "heals": {}}
	var rootlet_arena: Node = arena_script.new()
	add_child(rootlet_arena)
	await _ticks(3)
	var rootlet_hud: Node = rootlet_arena.get("hud")
	var rootlet_player: Node = rootlet_arena.get("player")
	if rootlet_hud != null and rootlet_player != null:
		var shield: Dictionary = rootlet_hud.call("state_signal_snapshot")
		_check(bool(rootlet_player.get("shield_ready")), "Rootlet starts with its shield ready")
		_check(str(shield.get("ability", "")) == "SHIELD READY", "legacy HUD exposes Rootlet shield readiness text")
		_check(str(shield.get("meter_state", "")) == "READY", "Rootlet readiness is represented semantically")
	rootlet_arena.queue_free()
	await _ticks(1)
	_finish()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

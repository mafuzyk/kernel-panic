extends Node

## H3 audit probe: the legacy HUD intentionally compensates for Godot's
## canvas_items stretch. This records the physical/logical transform instead of
## assuming that different local coordinate spaces are automatically a bug.

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
	Game.stats = {"time": 0.0, "wave": 1, "kills": 0, "shots": 0, "hits": 0, "damage": 0, "boss_kills": 0, "heals": {}}
	var arena_script: Script = load("res://src/arena/arena.gd")
	_check(arena_script != null, "arena script loads for the scale matrix")
	if arena_script == null:
		_finish()
		return
	var arena: Node = arena_script.new()
	add_child(arena)
	await _ticks(3)
	var hud: Node = arena.get("hud")
	_check(hud != null and is_instance_valid(hud), "live Arena exposes the legacy HUD for scale inspection")
	if hud == null or not is_instance_valid(hud):
		_finish()
		return
	var physical_display := DisplayServer.get_name().to_lower() != "headless"
	var targets := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(432, 720), Vector2i(720, 720)]
	for target in targets:
		get_window().size = target
		await _ticks(3)
		var window_size := Vector2(get_window().size)
		var viewport_size := get_viewport().get_visible_rect().size
		var hud_size := Vector2(hud.get("size"))
		var hud_scale := Vector2(hud.get("scale"))
		var transform: Transform2D = hud.get_global_transform_with_canvas()
		var origin := transform * Vector2.ZERO
		var right := transform * Vector2(hud_size.x, 0.0)
		var bottom := transform * Vector2(0.0, hud_size.y)
		var effective_size := Vector2(origin.distance_to(right), origin.distance_to(bottom))
		print("PROBE_INFO target=%s window=%s viewport=%s hud_size=%s hud_scale=%s effective=%s" % [target, window_size, viewport_size, hud_size, hud_scale, effective_size])
		if physical_display:
			_check(window_size == Vector2(target), "physical window accepts %dx%d" % [target.x, target.y])
		_check(hud_size.x > 0.0 and hud_size.y > 0.0, "HUD has a positive local surface at %dx%d" % [target.x, target.y])
		_check(hud_scale.x > 0.0 and hud_scale.y > 0.0 and is_equal_approx(hud_scale.x, hud_scale.y), "HUD compensation stays uniform at %dx%d" % [target.x, target.y])
		_check(effective_size.x > 0.0 and effective_size.y > 0.0, "HUD remains renderable after %dx%d resize" % [target.x, target.y])
		_check(absf(effective_size.x - viewport_size.x) <= 1.0 and absf(effective_size.y - viewport_size.y) <= 1.0, "HUD effective canvas matches the stretched viewport at %dx%d" % [target.x, target.y])
	var legacy_layout: Dictionary = hud.call("layout_snapshot", Vector2(1280, 720))
	var wide_layout: Dictionary = hud.call("layout_snapshot", Vector2(1920, 1080))
	_check((legacy_layout["integrity"] as Rect2).size.x != (wide_layout["integrity"] as Rect2).size.x, "HUD layout responds to viewport width instead of freezing 1280 metrics")
	_check((wide_layout["score"] as Rect2).end.x <= 1920.01, "wide HUD score register stays inside its authored viewport")
	arena.queue_free()
	await _ticks(1)
	_finish()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

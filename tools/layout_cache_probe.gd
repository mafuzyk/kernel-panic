extends Node

## P1 red/green probe: repeated HUD layout requests should reuse the same
## viewport/platform result, and Arena panel geometry should not be reapplied
## every frame when neither the viewport nor the requested height changed.

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
	var arena_script: Script = load("res://src/arena/arena.gd")
	_check(hud_script != null, "HUD script loads for layout cache audit")
	_check(arena_script != null, "Arena script loads for responsive cache audit")
	if hud_script == null or arena_script == null:
		_finish()
		return

	var hud: Control = hud_script.new()
	hud.size = Vector2(1280, 720)
	add_child(hud)
	await _ticks(3)
	_check(hud.has_method("layout_cache_snapshot"), "HUD exposes layout cache telemetry")
	if hud.has_method("layout_cache_snapshot"):
		var viewport := Vector2(1280, 720)
		hud.call("layout_snapshot", viewport)
		var after_first: Dictionary = hud.call("layout_cache_snapshot")
		var first_builds := int(after_first.get("builds", -1))
		for _i in 8:
			hud.call("layout_snapshot", viewport)
		var after_repeated: Dictionary = hud.call("layout_cache_snapshot")
		_check(int(after_repeated.get("builds", -1)) == first_builds, "HUD reuses layout for repeated viewport requests")
		_check(int(after_repeated.get("hits", 0)) >= int(after_first.get("hits", 0)) + 8, "HUD records cache hits for repeated layout requests")
		var resized := Vector2(1920, 1080)
		hud.call("layout_snapshot", resized)
		var after_resize: Dictionary = hud.call("layout_cache_snapshot")
		_check(int(after_resize.get("builds", -1)) == first_builds + 1, "HUD rebuilds layout when viewport changes")
		var old_touch_scale := Sfx.touch_scale
		Sfx.touch_scale = 1.2 if is_equal_approx(old_touch_scale, 1.0) else 1.0
		hud.call("layout_snapshot", resized)
		var after_touch_scale: Dictionary = hud.call("layout_cache_snapshot")
		_check(int(after_touch_scale.get("builds", -1)) == int(after_resize.get("builds", -1)) + 1, "HUD rebuilds layout when touch scale changes")
		Sfx.touch_scale = old_touch_scale
		Game.patch_levels = {"heavy": 1, "reclaimer": 1}
		hud.call("patch_dock_rects", resized)
		var after_patch_first: Dictionary = hud.call("layout_cache_snapshot")
		for _i in 8:
			hud.call("patch_dock_rects", resized)
		var after_patch_repeated: Dictionary = hud.call("layout_cache_snapshot")
		_check(int(after_patch_repeated.get("patch_builds", -1)) == int(after_patch_first.get("patch_builds", -1)), "HUD reuses patch chip geometry for repeated state")
		Game.patch_levels["heavy"] = 2
		hud.call("patch_dock_rects", resized)
		var after_patch_change: Dictionary = hud.call("layout_cache_snapshot")
		_check(int(after_patch_change.get("patch_builds", -1)) == int(after_patch_repeated.get("patch_builds", -1)) + 1, "HUD rebuilds patch chip geometry when patch state changes")
		Game.patch_levels = {}
	hud.queue_free()
	await _ticks(1)

	Game.mode = "classic"
	Game.state = Game.State.PLAYING
	Game.patch_levels = {}
	Game.stats = {"time": 0.0, "wave": 1, "kills": 0, "shots": 0, "hits": 0, "damage": 0, "boss_kills": 0, "heals": {}}
	var arena: Node = arena_script.new()
	add_child(arena)
	await _ticks(4)
	_check(arena.has_method("responsive_layout_snapshot"), "Arena exposes responsive layout telemetry")
	if arena.has_method("responsive_layout_snapshot"):
		arena.call("_refresh_responsive_layout")
		var before_idle: Dictionary = arena.call("responsive_layout_snapshot")
		arena.call("_on_responsive_viewport_size_changed")
		arena.call("_on_vnext_window_size_changed")
		var after_resize_signals: Dictionary = arena.call("responsive_layout_snapshot")
		_check(int(after_resize_signals.get("refreshes", -1)) == int(before_idle.get("refreshes", -1)), "Arena deduplicates repeated resize signals without geometry change")
		await _ticks(8)
		var after_idle: Dictionary = arena.call("responsive_layout_snapshot")
		_check(int(after_idle.get("refreshes", -1)) == int(before_idle.get("refreshes", -1)), "Arena skips responsive relayout while idle")
		arena.call("_refresh_responsive_layout_for_height", 480.0)
		var after_height: Dictionary = arena.call("responsive_layout_snapshot")
		_check(int(after_height.get("refreshes", -1)) == int(after_idle.get("refreshes", -1)) + 1, "Arena relayouts when requested height changes")
		arena.call("_refresh_responsive_layout", 480.0)
		var after_same_height: Dictionary = arena.call("responsive_layout_snapshot")
		_check(int(after_same_height.get("refreshes", -1)) == int(after_height.get("refreshes", -1)), "Arena reuses responsive geometry for repeated height requests")
		arena.call("_refresh_responsive_layout", 481.0)
		var after_new_height: Dictionary = arena.call("responsive_layout_snapshot")
		_check(int(after_new_height.get("refreshes", -1)) == int(after_same_height.get("refreshes", -1)) + 1, "Arena invalidates responsive geometry for a new height")
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

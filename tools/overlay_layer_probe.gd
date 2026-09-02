extends Node

## H6 red/green probe: modal state surfaces must not sit beneath active CRT
## distortion, low-health vignette or the Windows watermark. The probe checks
## both the overlay's own visual contract and the real Arena transitions.

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

func _visual_effect_visible(overlay: Node) -> bool:
	if overlay == null or not is_instance_valid(overlay) or not overlay.has_method("visual_effect_visible"):
		return false
	return overlay.call("visual_effect_visible") == true

func _run() -> void:
	var overlay_script: Script = load("res://src/arena/arena_overlay.gd")
	var arena_script: Script = load("res://src/arena/arena.gd")
	_check(overlay_script != null, "Arena overlay script loads for layer audit")
	_check(arena_script != null, "Arena script loads for layer audit")
	if overlay_script == null or arena_script == null:
		_finish()
		return

	var overlay: Node = overlay_script.new()
	add_child(overlay)
	await _ticks(1)
	_check(int(overlay.get("layer")) == 80, "CRT effect keeps its documented overlay layer")
	_check(overlay.has_method("set_state_panel_active"), "overlay exposes a modal-state visibility contract")
	_check(overlay.has_method("visual_effect_visible"), "overlay exposes its effective visual visibility")
	if overlay.has_method("set_state_panel_active"):
		_check(overlay.call("state_panel_active") != true, "overlay starts in gameplay visual state")
		_check(_visual_effect_visible(overlay), "gameplay visual effects remain visible outside a modal")
		overlay.call("set_state_panel_active", true)
		_check(overlay.call("state_panel_active") == true, "overlay records an active modal state")
		_check(not _visual_effect_visible(overlay), "modal state hides CRT and low-health effects")
		overlay.call("set_state_panel_active", false)
		_check(overlay.call("state_panel_active") != true, "overlay restores gameplay state after modal closes")
		_check(_visual_effect_visible(overlay), "gameplay effects restore after modal closes")
	overlay.queue_free()
	await _ticks(1)

	Game.mode = "classic"
	Game.program = "kernel"
	Game.patch_levels = {}
	Game.state = Game.State.PLAYING
	Game.stats = {"time": 0.0, "wave": 1, "kills": 0, "shots": 0, "hits": 0, "damage": 0, "boss_kills": 0, "heals": {}}
	get_tree().paused = false
	var arena: Node = arena_script.new()
	add_child(arena)
	await _ticks(3)
	var arena_overlay: Node = arena.get("overlay")
	_check(arena_overlay != null and arena_overlay.has_method("visual_effect_visible"), "real Arena wires the modal-aware overlay")
	_check(arena.get("_state_panel_active") != true, "real Arena starts without a state panel")
	if arena.has_method("_set_paused"):
		arena.call("_set_paused", true)
		_check(arena.get("_state_panel_active") == true, "pause transition marks the state panel active")
		_check(not _visual_effect_visible(arena_overlay), "pause transition hides active screen effects")
		var pause_panel: Control = arena.get("_pause_panel")
		_check(pause_panel != null and pause_panel.visible, "pause panel remains visible after overlay suppression")
		var panel_kit = arena.get("_panel_kit")
		if panel_kit != null:
			panel_kit.call("_open_terminal")
			_check(arena.get("_state_panel_active") == true, "terminal keeps the modal suppression active")
			_check(not _visual_effect_visible(arena_overlay), "terminal remains readable without screen distortion")
			panel_kit.call("_close_terminal")
		arena.call("_set_paused", false)
		_check(arena.get("_state_panel_active") != true, "resume clears modal suppression")
		_check(_visual_effect_visible(arena_overlay), "resume restores gameplay screen effects")
	else:
		_check(false, "real Arena exposes its pause transition")
	arena.call("_show_game_over")
	_check(arena.get("_state_panel_active") == true, "game-over transition marks the state panel active")
	_check(not _visual_effect_visible(arena_overlay), "game-over panel is not distorted by the CRT overlay")
	arena.queue_free()
	await _ticks(1)
	get_tree().paused = false

	Game.mode = "story"
	Game.story_stage_index = 6
	Game.state = Game.State.PLAYING
	Game.stats = {"time": 0.0, "wave": 1, "kills": 0, "shots": 0, "hits": 0, "damage": 0, "boss_kills": 0, "heals": {}}
	var story_arena: Node = arena_script.new()
	add_child(story_arena)
	await _ticks(3)
	var watermark: Label = story_arena.get("_windows_watermark")
	_check(watermark != null, "Windows story stage mounts its watermark")
	if watermark != null and story_arena.has_method("_set_state_panel_active"):
		story_arena.call("_set_state_panel_active", true)
		_check(not watermark.visible, "modal state hides the Windows watermark")
		story_arena.call("_set_state_panel_active", false)
		_check(watermark.visible, "watermark can return when gameplay resumes")
	else:
		_check(false, "Windows watermark participates in the modal-state contract")
	story_arena.queue_free()
	await _ticks(1)
	get_tree().paused = false
	_finish()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

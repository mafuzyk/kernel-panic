extends Node

## Regression probe for the physical-window composition of the legacy combat HUD.
## The wide desktop case must calculate its panel positions from the physical
## window before the surface is fitted into the logical canvas.

const SAME_ASPECT_WINDOW := Vector2i(1600, 900)
const WIDE_WINDOW := Vector2i(1776, 975)

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
	_check(arena_script != null, "real Arena script loads for the wide HUD audit")
	if arena_script == null:
		_finish()
		return
	var arena: Node = arena_script.new()
	add_child(arena)
	await _ticks(3)
	var hud: Control = arena.get("hud") as Control
	_check(hud != null and is_instance_valid(hud), "real Arena exposes the legacy HUD")
	if hud == null or not is_instance_valid(hud):
		_finish()
		return
	var physical_display := DisplayServer.get_name().to_lower() != "headless"
	await _audit_resize(hud, SAME_ASPECT_WINDOW, physical_display, "same-aspect")
	await _audit_resize(hud, WIDE_WINDOW, physical_display, "wide")
	var capture_out := OS.get_environment("KP_LEGACY_HUD_CAPTURE_OUT")
	if not capture_out.is_empty():
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var capture_error := image.save_png(capture_out)
		print("PROBE_CAPTURE ", capture_out, " ", image.get_width(), "x", image.get_height(), " error=", capture_error)
	arena.queue_free()
	await _ticks(1)
	_finish()

func _audit_resize(hud: Control, target: Vector2i, physical_display: bool, label: String) -> void:
	get_window().size = target
	await _ticks(4)
	var window_size := Vector2(get_window().size)
	var viewport_size := get_viewport().get_visible_rect().size
	var hud_size := hud.size
	var hud_transform := hud.get_global_transform_with_canvas()
	var origin := hud_transform * Vector2.ZERO
	var right := hud_transform * Vector2(hud_size.x, 0.0)
	var bottom := hud_transform * Vector2(0.0, hud_size.y)
	var effective_size := Vector2(origin.distance_to(right), origin.distance_to(bottom))
	var layout: Dictionary = hud.call("layout_snapshot", hud_size)
	var score: Rect2 = layout.get("score", Rect2())
	var patches: Rect2 = layout.get("patches", Rect2())
	print("PROBE_INFO %s window=%s viewport=%s hud_size=%s hud_scale=%s effective=%s score=%s patches=%s" % [label, window_size, viewport_size, hud_size, hud.scale, effective_size, score, patches])
	if physical_display:
		_check(window_size == Vector2(target), "%s physical window accepts %dx%d" % [label, target.x, target.y])
		_check(absf(effective_size.x - viewport_size.x) <= 1.0 and absf(effective_size.y - viewport_size.y) <= 1.0, "%s HUD fits the logical canvas uniformly" % label)
		_check(absf(hud_size.x - window_size.x) <= 1.0 and absf(hud_size.y - window_size.y) <= 1.0, "%s HUD local surface follows the physical window" % label)
		_check(score.end.x >= hud_size.x - 24.0, "%s score register is authored against the right safe edge" % label)
		_check(patches.end.x >= hud_size.x - 24.0, "%s patch dock is authored against the right safe edge" % label)
	_check(hud_size.x >= target.x - 1.0 or not physical_display, "%s HUD receives the physical window width" % label)

func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

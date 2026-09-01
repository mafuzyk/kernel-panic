extends Node

## A11/A14 focused probe for persisted, live accessibility controls and the
## mirrored touch layout. It deliberately tests effect ownership, not only the
## labels in the settings surface.

var _fails := 0

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PROBE_PASS ", message)
	else:
		_fails += 1
		print("PROBE_FAIL ", message)

func _run() -> void:
	var defaults: Dictionary = Sfx.accessibility_defaults() if Sfx.has_method("accessibility_defaults") else {}
	_check(defaults.has("reduced_motion") and defaults.has("reduced_flashes") and defaults.has("left_handed_touch"), "accessibility defaults expose motion, flash and handedness controls")
	var snapshot: Dictionary = Sfx.accessibility_snapshot() if Sfx.has_method("accessibility_snapshot") else {}
	var supported: Dictionary = snapshot.get("supported", {})
	_check(bool(supported.get("reduced_motion", false)) and bool(supported.get("reduced_flashes", false)) and bool(supported.get("left_handed_touch", false)), "live snapshot advertises implemented accessibility controls")
	var previous: Dictionary = defaults.duplicate(true)
	var applied: Dictionary = Sfx.apply_accessibility_profile({"reduced_motion": true, "reduced_flashes": true, "left_handed_touch": true}, false)
	_check(bool(applied.get("reduced_motion", false)) and bool(applied.get("reduced_flashes", false)) and bool(applied.get("left_handed_touch", false)), "profile applies all three new controls in memory")
	var camera := CameraRig.new()
	add_child(camera)
	await get_tree().process_frame
	Fx.shake(1.0)
	_check(is_zero_approx(camera.trauma), "reduced motion suppresses camera trauma")
	var original_zoom := camera.zoom
	Fx.zoom_punch(0.2)
	_check(camera.zoom == original_zoom, "reduced motion suppresses zoom punch")
	_check(Fx.get("_flash_layer") == null, "reduced flashes suppresses the flash layer before it is created")
	Fx.flash(Color.WHITE, 1.0, 0.1)
	_check(Fx.get("_flash_layer") == null, "reduced flashes suppresses new screen flashes")
	camera.queue_free()

	var touch := TouchControls.new()
	touch.size = Vector2(1000, 700)
	add_child(touch)
	await get_tree().process_frame
	var dash: Rect2 = touch.call("_dash_btn")
	var move_zone: Rect2 = touch.call("movement_zone_rect")
	_check(dash.position.x < touch.size.x * 0.5 and move_zone.position.x > touch.size.x * 0.5, "left-handed touch mirrors action buttons and movement zone")
	touch.queue_free()

	Sfx.apply_accessibility_profile(previous, false)
	_check(Sfx.accessibility_snapshot().get("profile", {}) == previous, "probe restores the prior accessibility profile")
	_finish()

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

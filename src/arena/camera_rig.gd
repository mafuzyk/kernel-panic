class_name CameraRig
extends Camera2D

var trauma := 0.0
var _lean := Vector2.ZERO

func _ready() -> void:
	add_to_group("cam_rig")
	make_current()
	position = Vector2.ZERO

func add_trauma(amount: float) -> void:
	if bool(Sfx.reduced_motion):
		return
	trauma = minf(trauma + amount, 1.0)

func zoom_punch(amount: float) -> void:
	if bool(Sfx.reduced_motion):
		return
	var tw := create_tween()
	tw.tween_property(self, "zoom", Vector2.ONE * (1.0 - amount), 0.09).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "zoom", Vector2.ONE, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	trauma = maxf(trauma - delta * 1.9, 0.0)
	var desktop := Balance.is_desktop_display()
	var lean_target := Vector2.ZERO
	if desktop and not DisplayServer.is_touchscreen_available():
		var mouse := get_global_mouse_position()
		lean_target = (mouse - global_position) * 0.055
		lean_target = lean_target.limit_length(42.0)
	_lean = _lean.lerp(lean_target, 3.0 * delta)
	var shake_amt: float = 0.0 if bool(Sfx.reduced_motion) else trauma * trauma * [0.0, 0.45, 1.0][clampi(Sfx.shake_level, 0, 2)]
	var off := Vector2(
		randf_range(-1.0, 1.0) * 24.0 * shake_amt,
		randf_range(-1.0, 1.0) * 24.0 * shake_amt
	)
	offset = _lean + off
	rotation = randf_range(-1.0, 1.0) * 0.024 * shake_amt

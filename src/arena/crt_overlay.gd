class_name CrtOverlay
extends CanvasLayer

var _mat: ShaderMaterial
var profile: Dictionary = {}

func _ready() -> void:
	layer = 75
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/crt.gdshader")
	rect.material = _mat
	add_child(rect)

func configure(next_profile: Dictionary) -> void:
	profile = next_profile.duplicate(true)
	if _mat == null:
		return
	_mat.set_shader_parameter("curvature", float(profile.get("curvature", 0.0)))
	_mat.set_shader_parameter("noise", float(profile.get("noise", 0.0)))
	_mat.set_shader_parameter("scanline", float(profile.get("scanline", 0.0)))
	_mat.set_shader_parameter("aberration", float(profile.get("aberration", 0.0)))

func is_active() -> bool:
	return not profile.is_empty() and (float(profile.get("scanline", 0.0)) > 0.0 or float(profile.get("curvature", 0.0)) > 0.0)

class_name ArenaOverlay
extends CanvasLayer

var _mat: ShaderMaterial
var aberr := 0.0
var hurt := 0.0
var low_hp := 0.0

func _ready() -> void:
	layer = 80
	add_to_group("overlay")
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/overlay.gdshader")
	rect.material = _mat
	add_child(rect)

func hurt_pulse() -> void:
	hurt = 1.0
	aberr = minf(aberr + 0.9, 1.2)

func aberrate(amount: float) -> void:
	aberr = maxf(aberr, amount)

func set_low_hp(frac: float) -> void:
	low_hp = frac

func _process(delta: float) -> void:
	hurt = maxf(hurt - delta * 2.4, 0.0)
	aberr = maxf(aberr - delta * 2.6, 0.0)
	_mat.set_shader_parameter("aberr", aberr)
	_mat.set_shader_parameter("hurt", hurt)
	_mat.set_shader_parameter("low_hp", low_hp)
	_mat.set_shader_parameter("flash_white", 0.0)

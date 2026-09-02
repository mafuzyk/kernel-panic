class_name ArenaOverlay
extends CanvasLayer

var _mat: ShaderMaterial
var _screen_rect: ColorRect
var _state_panel_active := false
var aberr := 0.0
var hurt := 0.0
var low_hp := 0.0

func _ready() -> void:
	layer = 80
	add_to_group("overlay")
	_screen_rect = ColorRect.new()
	_screen_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/overlay.gdshader")
	_screen_rect.material = _mat
	add_child(_screen_rect)

func set_state_panel_active(active: bool) -> void:
	_state_panel_active = active
	if _screen_rect != null and is_instance_valid(_screen_rect):
		_screen_rect.visible = not active

func state_panel_active() -> bool:
	return _state_panel_active

func visual_effect_visible() -> bool:
	return _screen_rect != null and is_instance_valid(_screen_rect) and _screen_rect.visible

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

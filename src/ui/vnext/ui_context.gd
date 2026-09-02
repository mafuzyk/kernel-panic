class_name VNextUIContext
extends RefCounted

const Tokens = preload("res://src/ui/vnext/ui_tokens.gd")

var viewport_size := Vector2.ZERO
var safe_rect := Rect2()
var density := "wide"
var input_mode := "desktop"
var reduce_motion := false
var high_contrast := false
var text_scale := 1.0

static func from_viewport(viewport: Vector2, touch := false, reduced := false, contrast := false, scale := 1.0) -> RefCounted:
	var context = load("res://src/ui/vnext/ui_context.gd").new()
	if viewport.x < 1.0 or viewport.y < 1.0:
		viewport = Tokens.BASE_VIEWPORT
	context.viewport_size = viewport
	context.safe_rect = Tokens.safe_rect(viewport, Tokens.SAFE_MARGIN)
	context.density = "wide" if viewport.x >= 1000 else ("compact" if viewport.x >= 600 else "narrow")
	context.input_mode = "touch" if touch else "desktop"
	context.reduce_motion = reduced
	context.high_contrast = contrast
	context.text_scale = clampf(scale, 0.8, 2.0)
	return context

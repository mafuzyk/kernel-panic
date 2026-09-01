class_name VNextUIContext
extends RefCounted

var viewport_size := Vector2.ZERO
var safe_rect := Rect2()
var density := "wide"
var input_mode := "desktop"
var reduce_motion := false
var high_contrast := false
var text_scale := 1.0

static func from_viewport(viewport: Vector2, touch := false) -> RefCounted:
	var context = load("res://src/ui/vnext/ui_context.gd").new()
	context.viewport_size = viewport
	context.safe_rect = Rect2(Vector2(20, 20), Vector2(maxf(viewport.x - 40, 0), maxf(viewport.y - 40, 0)))
	context.density = "wide" if viewport.x >= 1000 else ("compact" if viewport.x >= 600 else "narrow")
	context.input_mode = "touch" if touch else "desktop"
	return context

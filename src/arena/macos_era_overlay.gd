class_name MacOSEraOverlay
extends Control

## Minimal code-drawn era dressing. It is deliberately abstract: no Apple
## marks, screenshots or copied proprietary UI are used.

var _stage := {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func configure(stage: Dictionary) -> void:
	_stage = stage.duplicate(true)
	queue_redraw()

func _draw() -> void:
	if _stage.is_empty():
		return
	var theme: Dictionary = _stage.get("theme", {})
	var accent: Color = theme.get("accent", Balance.COL_PLAYER)
	var style := str(theme.get("grid_style", "mac_classic"))
	var w := minf(size.x * 0.31, 390.0)
	var rail := Rect2(size.x - w - 22.0, 18.0, w, 32.0)
	var alpha := 0.30 if style == "mac_aqua" else 0.22
	draw_polyline(PackedVector2Array([Vector2(22.0, 18.0), Vector2(size.x - 22.0, 18.0)]), Color(accent.r, accent.g, accent.b, alpha), 1.0, true)
	draw_polyline(PackedVector2Array([Vector2(22.0, 50.0), Vector2(size.x - 22.0, 50.0)]), Color(accent.r, accent.g, accent.b, alpha * 0.7), 1.0, true)
	var panel := Rect2(rail.position + Vector2(0.0, 8.0), rail.size)
	if bool(theme.get("layered", false)):
		draw_colored_polygon(PackedVector2Array([panel.position, panel.position + Vector2(panel.size.x - 12.0, 0.0), panel.end - Vector2(0.0, 8.0), panel.position + Vector2(12.0, panel.size.y)]), Color(accent.r, accent.g, accent.b, 0.035))
		draw_polyline(PackedVector2Array([panel.position, panel.position + Vector2(panel.size.x - 12.0, 0.0), panel.end - Vector2(0.0, 8.0), panel.position + Vector2(12.0, panel.size.y), panel.position]), Color(accent.r, accent.g, accent.b, 0.28), 1.0, true)
	for index in 3:
		var x := rail.position.x + 12.0 + float(index) * 12.0
		draw_circle(Vector2(x, rail.position.y + 24.0), 2.5, Color(accent.r, accent.g, accent.b, 0.7))
	var font: Font = load("res://assets/fonts/ShareTechMono.ttf")
	draw_string(font, Vector2(rail.position.x + 58.0, rail.position.y + 27.0), str(_stage.get("path", "MACOS")), HORIZONTAL_ALIGNMENT_LEFT, rail.size.x - 70.0, 11, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.58))

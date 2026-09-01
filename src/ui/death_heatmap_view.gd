class_name DeathHeatmapView
extends Control

const TacticalStateSurface = preload("res://src/ui/tactical_state_surface.gd")
const TacticalUI = preload("res://src/ui/tactical_ui.gd")
const Mono: Font = preload("res://assets/fonts/ShareTechMono.ttf")

var snapshot: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func configure(next_snapshot: Dictionary) -> void:
	snapshot = next_snapshot.duplicate(true)
	queue_redraw()

func _map_rect() -> Rect2:
	if snapshot.is_empty() or int(snapshot.get("run_count", 0)) <= 0:
		return Rect2()
	var panel := TacticalStateSurface.panel_rect_for_viewport(get_viewport_rect().size, "game_over")
	var narrow := get_viewport_rect().size.x < 760.0
	var width := 142.0 if narrow else minf(176.0, panel.size.x - 56.0)
	var height := 58.0 if narrow else 64.0
	return Rect2(panel.get_center().x - width * 0.5, panel.end.y - (176.0 if narrow else 178.0), width, height)

func _draw() -> void:
	var rect := _map_rect()
	if rect.size.x <= 2.0 or rect.size.y <= 2.0:
		return
	var columns := maxi(int(snapshot.get("columns", 1)), 1)
	var rows := maxi(int(snapshot.get("rows", 1)), 1)
	var max_count := maxi(int(snapshot.get("max_cell_count", 1)), 1)
	var danger := Balance.COL_DANGER
	var title := "DEATH MAP // %d" % int(snapshot.get("run_count", 0)) if rect.size.x < 160.0 else "LOCAL DEATH MAP // %d RUNS" % int(snapshot.get("run_count", 0))
	draw_string(Mono, rect.position + Vector2(0, 10), title, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 10, TacticalUI.MUTED)
	var grid := Rect2(rect.position + Vector2(0, 15), Vector2(rect.size.x, rect.size.y - 15.0))
	draw_colored_polygon(TacticalUI.angular_points(grid, 4.0), Color(0.02, 0.03, 0.07, 0.92))
	var cell_size := Vector2(grid.size.x / columns, grid.size.y / rows)
	for y in rows:
		for x in columns:
			draw_rect(Rect2(grid.position + Vector2(x, y) * cell_size, cell_size), Color(danger.r, danger.g, danger.b, 0.16), false, 0.5)
	for raw_cell in snapshot.get("cells", []):
		if not raw_cell is Dictionary:
			continue
		var x := clampi(int(raw_cell.get("x", -1)), 0, columns - 1)
		var y := clampi(int(raw_cell.get("y", -1)), 0, rows - 1)
		var intensity := clampf(float(raw_cell.get("count", 0)) / max_count, 0.0, 1.0)
		var cell := Rect2(grid.position + Vector2(x, y) * cell_size + Vector2(1.0, 1.0), cell_size - Vector2(2.0, 2.0))
		draw_rect(cell, Color(danger.r, danger.g, danger.b, 0.22 + intensity * 0.72), true)

func text_overflow_report() -> Dictionary:
	var rect := _map_rect()
	var title := "DEATH MAP // %d" % int(snapshot.get("run_count", 0)) if rect.size.x < 160.0 else "LOCAL DEATH MAP // %d RUNS" % int(snapshot.get("run_count", 0))
	return {"title": {"fits": rect.size.x <= 0.0 or Mono.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x <= rect.size.x}}

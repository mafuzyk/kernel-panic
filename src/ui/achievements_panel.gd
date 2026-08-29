class_name AchievementsPanel
extends Control

## Code-drawn ACHIEVEMENTS overlay for the menu shell.
## Lists every Game.ACHIEVEMENT_DEFS entry with unlocked/locked state, a hint
## for locked rows, and an X / Y progress header. Persistence is untouched.

const TacticalUIHelper = preload("res://src/ui/tactical_ui.gd")

const ACHIEVEMENT_HINTS := {
	"first_blood": "Terminate your first daemon.",
	"boss_purge": "Take down a ROOT-class boss.",
	"chain_max": "Push the combo meter to its maximum multiplier.",
	"terminal_operator": "Grant a sudo heal in the terminal.",
	"integrity_restored": "Recover integrity after it drops.",
}

var _header: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Game.achievement_unlocked.connect(_on_achievement_unlocked)
	_build()

func achievement_rows() -> Array:
	var rows: Array = []
	for id in Game.ACHIEVEMENT_DEFS:
		rows.append({
			"id": str(id),
			"label": str(Game.ACHIEVEMENT_DEFS[id]),
			"unlocked": Game.achievements.has(id),
			"hint": str(ACHIEVEMENT_HINTS.get(id, "")),
		})
	return rows

func progress_header() -> String:
	var unlocked := 0
	for id in Game.ACHIEVEMENT_DEFS:
		if Game.achievements.has(id):
			unlocked += 1
	return "ACHIEVEMENTS // %d / %d UNLOCKED" % [unlocked, Game.ACHIEVEMENT_DEFS.size()]

func refresh() -> void:
	_build()
	queue_redraw()

func _on_achievement_unlocked(_id: String, _label: String) -> void:
	if visible:
		refresh()

func _build() -> void:
	for child in get_children():
		if child is Button:
			continue
		remove_child(child)
		child.queue_free()
	var mono: Font = load("res://assets/fonts/ShareTechMono.ttf")
	_header = Label.new()
	_header.text = progress_header()
	_header.add_theme_font_override("font", mono)
	_header.add_theme_font_size_override("font_size", 17)
	_header.add_theme_color_override("font_color", TacticalUIHelper.CYAN)
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.anchor_left = 0.0
	_header.anchor_right = 1.0
	_header.offset_top = 118.0
	_header.offset_bottom = 148.0
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_header)
	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.0
	scroll.anchor_right = 1.0
	scroll.anchor_top = 0.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 40.0
	scroll.offset_right = -40.0
	scroll.offset_top = 160.0
	scroll.offset_bottom = -116.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var rows_box := VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", 14)
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows_box)
	for row in achievement_rows():
		rows_box.add_child(_make_row(row, mono))

func _make_row(row: Dictionary, mono: Font) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", mono)
	label.add_theme_font_size_override("font_size", 14)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if bool(row.get("unlocked", false)):
		label.text = "[OK] %s" % str(row.get("label", ""))
		label.add_theme_color_override("font_color", TacticalUIHelper.LIME)
	else:
		label.text = "[  ] %s  //  %s" % [str(row.get("label", "")), str(row.get("hint", ""))]
		label.add_theme_color_override("font_color", Color(TacticalUIHelper.TEXT.r, TacticalUIHelper.TEXT.g, TacticalUIHelper.TEXT.b, 0.45))
	return label

func _draw() -> void:
	var panel := Rect2(Vector2(36.0, 102.0), Vector2(size.x - 72.0, size.y - 216.0))
	if panel.size.x <= 0.0 or panel.size.y <= 0.0:
		return
	var points := TacticalUIHelper.angular_points(panel, 14.0)
	draw_colored_polygon(points, TacticalUIHelper.PANEL)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, Color(TacticalUIHelper.CYAN.r, TacticalUIHelper.CYAN.g, TacticalUIHelper.CYAN.b, 0.72), 1.4, true)

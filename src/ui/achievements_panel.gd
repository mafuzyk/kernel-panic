class_name AchievementsPanel
extends Control

## Code-drawn ACHIEVEMENTS overlay for the menu shell.
## Lists every Game.ACHIEVEMENT_DEFS entry with unlocked/locked state, a hint
## for locked rows, and an X / Y progress header. Persistence is untouched.

const TacticalUIHelper = preload("res://src/ui/tactical_ui.gd")
const TacticalChromeScript = preload("res://src/ui/tactical_chrome.gd")
const TacticalIconScript = preload("res://src/ui/tactical_icon.gd")
const ContentCatalogScript = preload("res://src/data/content_catalog.gd")
const ACHIEVEMENT_HINTS = ContentCatalogScript.ACHIEVEMENT_HINTS

var _header: Label
var _row_controls: Array[Control] = []

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
		if child is Button or child.name == "AwardsDim" or child.name == "AwardsChrome":
			continue
		remove_child(child)
		child.queue_free()
	_row_controls.clear()
	if get_node_or_null("AwardsDim") == null:
		var dim := ColorRect.new()
		dim.name = "AwardsDim"
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.color = Color(0.01, 0.012, 0.03, 0.88)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dim)
	if get_node_or_null("AwardsChrome") == null:
		var chrome: Control = TacticalChromeScript.new()
		chrome.name = "AwardsChrome"
		chrome.position = awards_panel_rect(size).position
		chrome.size = awards_panel_rect(size).size
		chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chrome.call("configure_panel", Rect2(Vector2.ZERO, awards_panel_rect(size).size), TacticalUIHelper.CYAN, 0.03)
		add_child(chrome)
	var mono: Font = load("res://assets/fonts/ShareTechMono.ttf")
	_header = Label.new()
	_header.text = progress_header()
	_header.add_theme_font_override("font", mono)
	_header.add_theme_font_size_override("font_size", 17)
	_header.add_theme_color_override("font_color", TacticalUIHelper.CYAN)
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rect := awards_panel_rect(size)
	_header.position = rect.position + Vector2(0.0, 12.0)
	_header.size = Vector2(rect.size.x, 30.0)
	add_child(_header)
	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.0
	scroll.anchor_right = 0.0
	scroll.anchor_top = 0.0
	scroll.anchor_bottom = 0.0
	scroll.offset_left = rect.position.x + 20.0
	scroll.offset_right = rect.end.x - 20.0
	scroll.offset_top = rect.position.y + 46.0
	scroll.offset_bottom = rect.end.y - 16.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var rows_box := VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", 14)
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows_box)
	for row in achievement_rows():
		var row_control: Control = _make_row(row, mono)
		_row_controls.append(row_control)
		rows_box.add_child(row_control)

func _make_row(row: Dictionary, mono: Font) -> Control:
	var row_control := Control.new()
	row_control.custom_minimum_size = Vector2(0.0, 44.0)
	row_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var unlocked := bool(row.get("unlocked", false))
	var accent: Color = TacticalUIHelper.LIME if unlocked else Color(TacticalUIHelper.MUTED.r, TacticalUIHelper.MUTED.g, TacticalUIHelper.MUTED.b, 0.5)
	var chrome: Control = TacticalChromeScript.new()
	chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome.call("configure_panel", Rect2(Vector2.ZERO, Vector2(0.0, 44.0)), accent, 0.05 if unlocked else 0.015)
	row_control.add_child(chrome)
	var text_x := 12.0
	if unlocked:
		var icon: Control = TacticalIconScript.new()
		icon.position = Vector2(8.0, 8.0)
		icon.size = Vector2(28.0, 28.0)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_control.add_child(icon)
		icon.call("configure", "check", TacticalUIHelper.LIME)
		text_x = 44.0
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", mono)
	label.add_theme_font_size_override("font_size", 13)
	label.position = Vector2(text_x, 0.0)
	label.size = Vector2(360.0, 44.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if unlocked:
		label.text = str(row.get("label", ""))
		label.add_theme_color_override("font_color", TacticalUIHelper.LIME)
	else:
		label.text = "%s  //  %s" % [str(row.get("label", "")), str(row.get("hint", ""))]
		label.add_theme_color_override("font_color", Color(TacticalUIHelper.TEXT.r, TacticalUIHelper.TEXT.g, TacticalUIHelper.TEXT.b, 0.45))
	row_control.add_child(label)
	return row_control

func _draw() -> void:
	pass

func awards_panel_rect(viewport: Vector2) -> Rect2:
	var w := minf(680.0, maxf(viewport.x - 56.0, 240.0))
	var h := maxf(viewport.y - 216.0, 220.0)
	return Rect2((viewport.x - w) * 0.5, 102.0, w, h)

func award_row_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for row in _row_controls:
		if row != null and is_instance_valid(row):
			out.append(Rect2(row.global_position, row.size))
	return out

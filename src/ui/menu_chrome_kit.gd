extends RefCounted

const TacticalUIHelper = preload("res://src/ui/tactical_ui.gd")
const TacticalChromeScript = preload("res://src/ui/tactical_chrome.gd")
const TacticalIconScript = preload("res://src/ui/tactical_icon.gd")

## Menu shell/chrome kit: card buttons, frames, button row, overlay back
## styling, decorative `_draw` output. Moved verbatim from src/ui/menu.gd;
## Menu-owned state and non-moved calls prefixed `m.` (plan G5). Untyped
## owner reference avoids a preload cycle. No behavior changes.

var m
var _layout: Dictionary = {}


func _init(menu) -> void:
	m = menu

func _settings_nav_style(border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(border.r, border.g, border.b, 0.0 if border.a < 0.5 else 0.055)
	style.border_color = Color(border.r, border.g, border.b, 0.0)
	style.set_border_width_all(0)
	style.content_margin_left = 8.0
	return style

func _add_button_chrome(button: Button, accent: Color, alpha: float = 0.02) -> void:
	var frame: Control = TacticalChromeScript.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.z_index = 1
	button.add_child(frame)
	frame.call("configure_control", accent, alpha)
	button.z_index = 2

func _add_button_icon(button: Button, kind: String, accent: Color, icon_size: float = 52.0) -> void:
	var icon: Control = TacticalIconScript.new()
	icon.position = Vector2(10.0, (button.custom_minimum_size.y - icon_size) * 0.5)
	icon.size = Vector2(icon_size, icon_size)
	icon.z_index = 2
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	icon.call("configure", kind, accent)

func _style_settings_footer_button(button: Button, border: Color) -> void:
	button.flat = false
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	button.add_theme_font_size_override("font_size", Design.px(Design.TEXT_BODY))
	button.add_theme_color_override("font_color", border if border != TacticalUIHelper.CYAN else TacticalUIHelper.TEXT)
	button.add_theme_color_override("font_hover_color", TacticalUIHelper.TEXT)
	button.add_theme_stylebox_override("normal", _settings_nav_style(Color(border.r, border.g, border.b, 0.55)))
	button.add_theme_stylebox_override("hover", _settings_nav_style(border))
	button.add_theme_stylebox_override("pressed", _settings_nav_style(border))
	_set_button_text_inset(button, 54.0)
	_add_button_chrome(button, border, 0.02)

## Recuo do texto para o ícone caber à esquerda do rótulo.
func _set_button_text_inset(button: Button, inset: float) -> void:
	var style: StyleBox = button.get_theme_stylebox("normal")
	if style != null:
		style.content_margin_left = inset


func footer_button_layout_for_viewport(viewport_size: Vector2) -> Dictionary:
	var total_width := minf(448.0, maxf(viewport_size.x * 0.327, 280.0))
	var gap := 14.0
	return {
		"total_width": total_width,
		"gap": gap,
		"button_width": (total_width - gap) * 0.5,
	}

func menu_layout_for_viewport(viewport: Vector2) -> Dictionary:
	var compact := viewport.x < 760.0
	var title_size := 76
	if viewport.x < 1100.0:
		title_size = 58
	if compact:
		title_size = 44
	var title_top := 104.0 if not compact else 84.0
	var title_h := float(title_size) * 1.45
	var title := Rect2(0.0, title_top, viewport.x, title_h)
	var klog := Rect2(16.0, 12.0, minf(340.0, maxf(viewport.x - 32.0, 0.0)), 68.0)
	var subtitle := Rect2(0.0, title.end.y + 4.0, viewport.x, 30.0)
	var controls := Rect2(0.0, subtitle.end.y + 4.0, viewport.x, 26.0)
	var best := Rect2(0.0, controls.end.y + 4.0, viewport.x, 24.0)
	var mi_h := 44.0 if viewport.y >= 700.0 else 24.0
	var mode_info := Rect2(24.0, viewport.y - 95.0 - 8.0 - mi_h, viewport.x - 48.0, mi_h)
	var center := Vector2(viewport.x * 0.5, viewport.y * 0.5)
	var purge_w := minf(430.0, maxf(viewport.x * 0.30, 280.0))
	var purge := Rect2(center.x - purge_w * 0.5, center.y - 52.0, purge_w, 88.0)
	var story_w := minf(360.0, purge_w * 0.84)
	var story := Rect2(center.x - story_w * 0.5, center.y + 44.0, story_w, 58.0)
	var mode_w := minf(440.0, maxf(viewport.x * 0.42, 300.0))
	var mode := Rect2(center.x - mode_w * 0.5, center.y + 112.0, mode_w, 50.0)
	var program_w := minf(178.0, maxf(viewport.x - (center.x + 42.0) - 6.0, 0.0))
	var program := Rect2(center.x + 42.0, center.y + 112.0, program_w, 50.0)
	var diff := Rect2(center.x - 110.0, center.y + 166.0, 220.0, 26.0)
	var footer_layout := footer_button_layout_for_viewport(viewport)
	var row_w: float = footer_layout["total_width"]
	var button_row := Rect2((viewport.x - row_w) * 0.5, viewport.y - 95.0, row_w, 48.0)
	var ring_center := Vector2(maxf(150.0, center.x - 470.0), viewport.y * 0.44)
	var mode_dot := Vector2(center.x, center.y + 130.0)
	return {"viewport": viewport, "compact": compact, "title": title, "title_size": title_size, "klog": klog, "subtitle": subtitle, "controls": controls, "best": best, "mode_info": mode_info, "purge": purge, "story": story, "mode": mode, "program": program, "diff": diff, "button_row": button_row, "button_width": float(footer_layout["button_width"]), "gap": float(footer_layout["gap"]), "ring_center": ring_center, "mode_dot": mode_dot}

func menu_layout() -> Dictionary:
	return _layout if not _layout.is_empty() else menu_layout_for_viewport(m.size)

func _style_overlay_back(back: Button) -> void:
	back.text = "BACK // ESC"
	back.custom_minimum_size = Vector2(154.0, 42.0)
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	back.add_theme_font_size_override("font_size", Design.px(Design.TEXT_CAPTION))
	back.add_theme_color_override("font_color", Balance.COL_PLAYER)
	back.add_theme_color_override("font_hover_color", Balance.COL_TEXT)
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.anchor_left = 1.0
	back.anchor_right = 1.0
	back.anchor_top = 0.0
	back.anchor_bottom = 0.0
	back.offset_left = -190.0
	back.offset_right = -36.0
	back.offset_top = 58.0
	back.offset_bottom = 100.0
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(Balance.COL_PLAYER.r, Balance.COL_PLAYER.g, Balance.COL_PLAYER.b, 0.0)
	normal.border_color = Color(Balance.COL_PLAYER.r, Balance.COL_PLAYER.g, Balance.COL_PLAYER.b, 0.0)
	normal.set_border_width_all(0)
	normal.content_margin_left = 42.0
	normal.content_margin_right = 8.0
	back.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(Balance.COL_PLAYER.r, Balance.COL_PLAYER.g, Balance.COL_PLAYER.b, 0.08)
	hover.border_color = Color(Balance.COL_PLAYER.r, Balance.COL_PLAYER.g, Balance.COL_PLAYER.b, 0.0)
	hover.set_border_width_all(0)
	back.add_theme_stylebox_override("hover", hover)
	back.add_theme_stylebox_override("pressed", hover)
	_add_button_chrome(back, Balance.COL_PLAYER, 0.018)
	_add_button_icon(back, "back", Balance.COL_PLAYER, 30.0)

func draw_shell(m) -> void:
	if m._settings_panel != null and m._settings_panel.visible:
		return
	for d in m._drifters:
		var c: Color = d["col"]
		c.a = 0.16
		var s: float = d["scale"]
		var pts := PackedVector2Array()
		match int(d["kind"]):
			0:
				pts = PackedVector2Array([Vector2(s * 1.2, 0), Vector2(-s, s * 0.85), Vector2(-s * 0.3, 0), Vector2(-s, -s * 0.85)])
			1:
				for i in 6:
					pts.push_back(Vector2.from_angle(TAU * i / 6.0) * s)
			2:
				pts = PackedVector2Array([Vector2(s * 1.5, 0), Vector2(-s, s * 0.8), Vector2(-s * 0.4, 0), Vector2(-s, -s * 0.8)])
		m.draw_set_transform(d["pos"], d["rot"], Vector2.ONE)
		m.draw_polyline(pts + PackedVector2Array([pts[0]]), c, 1.6, true)
	m.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var center_x: float = m.size.x * 0.5
	if m._best_label != null and m._purge_btn != null:
		var score_rect: Rect2 = m._best_label.get_global_rect()
		var score_y := score_rect.position.y + score_rect.size.y * 0.58
		m.draw_line(Vector2(center_x - 112.0, score_y), Vector2(center_x - 72.0, score_y), Color(Balance.COL_PLAYER.r, Balance.COL_PLAYER.g, Balance.COL_PLAYER.b, 0.72), 1.2)
		m.draw_line(Vector2(center_x + 72.0, score_y), Vector2(center_x + 112.0, score_y), Color(Balance.COL_PLAYER.r, Balance.COL_PLAYER.g, Balance.COL_PLAYER.b, 0.72), 1.2)
	var ring_center: Vector2 = menu_layout()["ring_center"]
	for arc_index in 3:
		var start := -PI * 0.82 + arc_index * TAU / 3.0
		m.draw_arc(ring_center, 64.0, start, start + PI * 0.48, 18, Color(Balance.COL_DANGER.r, Balance.COL_DANGER.g, Balance.COL_DANGER.b, 0.5), 5.0, true)
	var ring_triangle := PackedVector2Array([
		ring_center + Vector2(0.0, -24.0),
		ring_center + Vector2(27.0, 22.0),
		ring_center + Vector2(-27.0, 22.0),
	])
	m.draw_polyline(ring_triangle + PackedVector2Array([ring_triangle[0]]), Color(Balance.COL_DANGER.r, Balance.COL_DANGER.g, Balance.COL_DANGER.b, 0.58), 2.0, true)
	m.draw_circle(ring_center, 9.0, Color(Balance.COL_DANGER.r, Balance.COL_DANGER.g, Balance.COL_DANGER.b, 0.42))
	m.draw_circle(menu_layout()["mode_dot"], 4.0, Balance.COL_MOTE)


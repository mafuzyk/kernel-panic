extends RefCounted

const TacticalUIHelper = preload("res://src/ui/tactical_ui.gd")
const TacticalChromeScript = preload("res://src/ui/tactical_chrome.gd")
const TacticalIconScript = preload("res://src/ui/tactical_icon.gd")

## Menu shell/chrome kit: card buttons, frames, button row, overlay back
## styling, decorative `_draw` output. Moved verbatim from src/ui/menu.gd;
## Menu-owned state and non-moved calls prefixed `m.` (plan G5). Untyped
## owner reference avoids a preload cycle. No behavior changes.

var m


func _init(menu) -> void:
	m = menu

func _style_card_button(b: Button, border: Color, button_size := Vector2(270, 84)) -> void:
	b.custom_minimum_size = button_size
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(border.r, border.g, border.b, 0.0)
	sb.border_color = Color(border.r, border.g, border.b, 0.0)
	sb.set_border_width_all(0)
	sb.set_corner_radius_all(0)
	b.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	sbh.bg_color = Color(border.r, border.g, border.b, 0.08)
	sbh.border_color = Color(border.r, border.g, border.b, 0.0)
	sbh.set_border_width_all(0)
	b.add_theme_stylebox_override("hover", sbh)
	var sbp := sb.duplicate()
	sbp.bg_color = Color(border.r, border.g, border.b, 0.16)
	sbp.border_color = Color(border.r, border.g, border.b, 0.0)
	sbp.set_border_width_all(0)
	b.add_theme_stylebox_override("pressed", sbp)
	b.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Balance.COL_TEXT)
	b.add_theme_color_override("font_hover_color", Balance.COL_PLAYER_HOT)
	b.add_theme_color_override("font_pressed_color", Balance.COL_PLAYER_HOT)
	b.z_index = 2
	b.pivot_offset = button_size * 0.5
	b.button_down.connect(func() -> void:
		b.scale = Vector2(0.96, 0.96)
		Sfx.play("ui", 1.0, -10.0)
	)
	b.button_up.connect(func() -> void:
		b.scale = Vector2.ONE
	)

func _add_menu_frame(rect: Rect2, accent: Color, alpha: float = 0.025) -> Control:
	var frame: Control = TacticalChromeScript.new()
	frame.set_anchors_preset(Control.PRESET_TOP_LEFT)
	frame.position = rect.position
	frame.size = rect.size
	frame.z_index = 1
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.call("configure_panel", Rect2(Vector2.ZERO, rect.size), accent, alpha)
	m.add_child(frame)
	return frame

func _set_button_text_inset(button: Button, inset: float) -> void:
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for state in ["normal", "hover", "pressed"]:
		var base: StyleBox = button.get_theme_stylebox(state)
		if base == null:
			continue
		var adjusted: StyleBox = base.duplicate()
		adjusted.content_margin_left = inset
		button.add_theme_stylebox_override(state, adjusted)

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
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", border if border != TacticalUIHelper.CYAN else TacticalUIHelper.TEXT)
	button.add_theme_color_override("font_hover_color", TacticalUIHelper.TEXT)
	button.add_theme_stylebox_override("normal", _settings_nav_style(Color(border.r, border.g, border.b, 0.55)))
	button.add_theme_stylebox_override("hover", _settings_nav_style(border))
	button.add_theme_stylebox_override("pressed", _settings_nav_style(border))
	_set_button_text_inset(button, 54.0)
	_add_button_chrome(button, border, 0.02)

func footer_button_layout_for_viewport(viewport_size: Vector2) -> Dictionary:
	var total_width := minf(448.0, maxf(viewport_size.x * 0.327, 280.0))
	var gap := 14.0
	return {
		"total_width": total_width,
		"gap": gap,
		"button_width": (total_width - gap) * 0.5,
	}

func _build_button_row() -> void:
	var purge_width := minf(430.0, maxf(m.size.x * 0.30, 280.0))
	m._purge_btn = Button.new()
	_style_card_button(m._purge_btn, Balance.COL_PLAYER, Vector2(purge_width, 88.0))
	m._purge_btn.text = ">> PURGE"
	m._purge_btn.add_theme_font_size_override("font_size", 30)
	m._purge_btn.anchor_left = 0.5
	m._purge_btn.anchor_right = 0.5
	m._purge_btn.anchor_top = 0.5
	m._purge_btn.anchor_bottom = 0.5
	m._purge_btn.offset_left = -purge_width * 0.5
	m._purge_btn.offset_right = purge_width * 0.5
	m._purge_btn.offset_top = -52.0
	m._purge_btn.offset_bottom = 36.0
	m._purge_btn.pressed.connect(m._start)
	m.add_child(m._purge_btn)
	_add_menu_frame(Rect2(Vector2((m.size.x - purge_width) * 0.5, m.size.y * 0.5 - 52.0), Vector2(purge_width, 88.0)), Balance.COL_PLAYER, 0.035)
	m._story_btn = Button.new()
	_style_card_button(m._story_btn, Balance.COL_PLAYER, Vector2(minf(360.0, purge_width * 0.84), 58.0))
	m._story_btn.text = "STORY // ACTS"
	m._story_btn.add_theme_font_size_override("font_size", 19)
	m._story_btn.anchor_left = 0.5
	m._story_btn.anchor_right = 0.5
	m._story_btn.anchor_top = 0.5
	m._story_btn.anchor_bottom = 0.5
	var story_width := minf(360.0, purge_width * 0.84)
	m._story_btn.offset_left = -story_width * 0.5
	m._story_btn.offset_right = story_width * 0.5
	m._story_btn.offset_top = 44.0
	m._story_btn.offset_bottom = 102.0
	m._story_btn.pressed.connect(m._open_story_selector)
	m.add_child(m._story_btn)
	_add_menu_frame(Rect2(Vector2((m.size.x - story_width) * 0.5, m.size.y * 0.5 + 44.0), Vector2(story_width, 58.0)), Balance.COL_PLAYER, 0.025)
	m._mode_btn = Button.new()
	_style_card_button(m._mode_btn, Balance.COL_MOTE, Vector2(minf(440.0, maxf(m.size.x * 0.42, 300.0)), 50.0))
	m._mode_btn.text = "MODE: CLASSIC"
	m._mode_btn.add_theme_font_size_override("font_size", 16)
	m._mode_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	m._mode_btn.anchor_left = 0.5
	m._mode_btn.anchor_right = 0.5
	m._mode_btn.anchor_top = 0.5
	m._mode_btn.anchor_bottom = 0.5
	var mode_width := minf(440.0, maxf(m.size.x * 0.42, 300.0))
	m._mode_btn.offset_left = -mode_width * 0.5
	m._mode_btn.offset_right = mode_width * 0.5
	m._mode_btn.offset_top = 112.0
	m._mode_btn.offset_bottom = 162.0
	m._mode_btn.pressed.connect(m._cycle_mode)
	m.add_child(m._mode_btn)
	var mode_normal: StyleBox = m._mode_btn.get_theme_stylebox("normal").duplicate()
	mode_normal.content_margin_left = 40.0
	m._mode_btn.add_theme_stylebox_override("normal", mode_normal)
	var mode_hover: StyleBox = m._mode_btn.get_theme_stylebox("hover").duplicate()
	mode_hover.content_margin_left = 40.0
	m._mode_btn.add_theme_stylebox_override("hover", mode_hover)
	var mode_pressed: StyleBox = m._mode_btn.get_theme_stylebox("pressed").duplicate()
	mode_pressed.content_margin_left = 40.0
	m._mode_btn.add_theme_stylebox_override("pressed", mode_pressed)
	_add_menu_frame(Rect2(Vector2((m.size.x - mode_width) * 0.5, m.size.y * 0.5 + 112.0), Vector2(mode_width, 50.0)), Balance.COL_MOTE, 0.03)
	m._program_btn = Button.new()
	m._program_btn.flat = true
	m._program_btn.z_index = 2
	m._program_btn.focus_mode = Control.FOCUS_NONE
	m._program_btn.anchor_left = 0.5
	m._program_btn.anchor_right = 0.5
	m._program_btn.anchor_top = 0.5
	m._program_btn.anchor_bottom = 0.5
	m._program_btn.offset_left = 42.0
	m._program_btn.offset_right = 220.0
	m._program_btn.offset_top = 112.0
	m._program_btn.offset_bottom = 162.0
	m._program_btn.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	m._program_btn.add_theme_font_size_override("font_size", 15)
	m._program_btn.add_theme_color_override("font_color", Color(0.6, 1.0, 0.8, 0.9))
	m._program_btn.add_theme_color_override("font_hover_color", TacticalUIHelper.LIME)
	m._program_btn.pressed.connect(m._open_program_selector)
	m.add_child(m._program_btn)
	m._diff_btn = Button.new()
	m._diff_btn.flat = true
	m._diff_btn.z_index = 2
	m._diff_btn.focus_mode = Control.FOCUS_NONE
	m._diff_btn.anchor_left = 0.5
	m._diff_btn.anchor_right = 0.5
	m._diff_btn.anchor_top = 0.5
	m._diff_btn.anchor_bottom = 0.5
	m._diff_btn.offset_left = -110.0
	m._diff_btn.offset_right = 110.0
	m._diff_btn.offset_top = 166.0
	m._diff_btn.offset_bottom = 192.0
	m._diff_btn.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	m._diff_btn.add_theme_font_size_override("font_size", 13)
	m._diff_btn.add_theme_color_override("font_color", Color(0.6, 1.0, 0.8, 0.9))
	m._diff_btn.add_theme_color_override("font_hover_color", TacticalUIHelper.LIME)
	m._diff_btn.pressed.connect(m._cycle_difficulty)
	m.add_child(m._diff_btn)
	m._refresh_difficulty_label()
	var footer_layout := footer_button_layout_for_viewport(m.size)
	var bottom_width: float = footer_layout["total_width"]
	var bottom_gap: float = footer_layout["gap"]
	var bottom_button_w: float = footer_layout["button_width"]
	var row := HBoxContainer.new()
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = -bottom_width * 0.5
	row.offset_right = bottom_width * 0.5
	row.offset_top = -95.0
	row.offset_bottom = -47.0
	row.add_theme_constant_override("separation", int(bottom_gap))
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(row)
	m._refresh_program_label()
	var settings_btn := Button.new()
	_style_card_button(settings_btn, Balance.COL_TEXT, Vector2(bottom_button_w, 48.0))
	settings_btn.text = "SETTINGS"
	_set_button_text_inset(settings_btn, 92.0)
	_add_button_icon(settings_btn, "settings", Balance.COL_PLAYER, 52.0)
	settings_btn.z_index = 2
	settings_btn.pressed.connect(m._open_settings)
	row.add_child(settings_btn)
	var best_btn := Button.new()
	_style_card_button(best_btn, Balance.COL_SPEWER, Vector2(bottom_button_w, 48.0))
	best_btn.text = "BESTIARY"
	_set_button_text_inset(best_btn, 92.0)
	_add_button_icon(best_btn, "bestiary", Balance.COL_SPEWER, 52.0)
	best_btn.z_index = 2
	best_btn.pressed.connect(m._open_bestiary)
	row.add_child(best_btn)
	var ach_btn := Button.new()
	_style_card_button(ach_btn, TacticalUIHelper.LIME, Vector2(bottom_button_w, 48.0))
	ach_btn.text = "AWARDS"
	ach_btn.z_index = 2
	ach_btn.pressed.connect(m._open_achievements)
	row.add_child(ach_btn)
	var bottom_y: float = m.size.y - 95.0
	var bottom_x: float = (m.size.x - bottom_width) * 0.5
	_add_menu_frame(Rect2(Vector2(bottom_x, bottom_y), Vector2(bottom_button_w, 48.0)), Balance.COL_TEXT, 0.015)
	_add_menu_frame(Rect2(Vector2(bottom_x + bottom_button_w + bottom_gap, bottom_y), Vector2(bottom_button_w, 48.0)), Balance.COL_SPEWER, 0.02)
	_add_menu_frame(Rect2(Vector2(bottom_x + (bottom_button_w + bottom_gap) * 2.0, bottom_y), Vector2(bottom_button_w, 48.0)), TacticalUIHelper.LIME, 0.02)
	m._mode_info = Label.new()
	m._mode_info.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	m._mode_info.add_theme_font_size_override("font_size", 12)
	m._mode_info.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.6))
	m._mode_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m._mode_info.anchor_left = 0.0
	m._mode_info.anchor_right = 0.0
	m._mode_info.anchor_top = 0.5
	m._mode_info.anchor_bottom = 0.5
	m._mode_info.offset_left = 24.0
	m._mode_info.offset_right = m.size.x - 24.0
	m._mode_info.offset_top = 190.0
	m._mode_info.offset_bottom = 234.0
	m._mode_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m._mode_info.visible = false
	m.add_child(m._mode_info)
	m._refresh_mode_ui()

func _style_overlay_back(back: Button) -> void:
	back.text = "BACK // ESC"
	back.custom_minimum_size = Vector2(154.0, 42.0)
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	back.add_theme_font_size_override("font_size", 13)
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

func _mk_title(f: Font, col: Color) -> Label:
	var l := Label.new()
	l.text = "KERNEL PANIC"
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", 76)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.offset_left = 0.0
	l.offset_right = 0.0
	l.offset_top = 125.0
	l.offset_bottom = 235.0
	m.add_child(l)
	return l

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
	var ring_center := Vector2(maxf(150.0, center_x - 470.0), m.size.y * 0.44)
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
	var mode_y: float = m.size.y * 0.5 + 130.0
	m.draw_circle(Vector2(center_x, mode_y), 4.0, Balance.COL_MOTE)


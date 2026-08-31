extends RefCounted

const TacticalUIHelper = preload("res://src/ui/tactical_ui.gd")
const TacticalChromeScript = preload("res://src/ui/tactical_chrome.gd")
const TacticalIconScript = preload("res://src/ui/tactical_icon.gd")

## ─────────────────────────────────────────────────────────────────────────────
## MENU GRID SPEC — the single source of menu geometry.
##
## Margens-base: TacticalUI.frame_margins(viewport) — the shared shell grid every
## surface mounts on. The menu column is that shell inset by GUTTER. Vertical
## structure hangs from two anchors and stacks with declared gaps:
##
##   top anchor    — the meta band (klog + version stamp) rides the shell's top
##                   rail by META_RIDE; the header stack (title → subtitle →
##                   controls → best) chains down from it with ROW_GAP.
##   bottom anchor — the footer rides the shell's bottom rail by FOOTER_RIDE:
##                   three equal slots from footer_button_layout_for_viewport,
##                   equal gaps, one shared baseline.
##   centered unit — the action column (PURGE → STORY → MODE/PROGRAM pair →
##                   DIFFICULTY, plus the hidden mode_info annotation) centers
##                   as one unit in the free zone between the anchors. The pair
##                   is a single framed card: mode text inset PAIR_INSET from
##                   the left rail, program text anchored inside the right half
##                   (dot clearance PAIR_DOT_CLEAR), mode dot at the card's
##                   center — the pair reads as one unit at any width.
##
## When the free zone cannot fit the unit, compression applies in declared
## order: action gaps 12→6, mode_info 32→24, meta band 68→48, footer ride
## 24→12. No block owns coordinates; nothing outside this spec positions the
## menu. Nodes are built once and resize only reapplies rects — no rebuilds.
## ─────────────────────────────────────────────────────────────────────────────

const GUTTER := 10.0            # content inset inside the shell frame
const META_RIDE := 8.0          # meta band hangs over the shell top rail
const META_H := 68.0            # klog terminal box (three log lines)
const META_H_COMPACT := 44.0
const TITLE_DROP := 24.0        # air between the meta band and the title row
const VERSION_DROP := 16.0      # version stamp hangs under the meta band
const VERSION_H := 20.0
const VERSION_W := 500.0
const ROW_GAP := 4.0            # header stack rhythm
const SUBTITLE_H := 30.0
const CONTROLS_H := 26.0
const BEST_H := 24.0
const ACTION_W_RATIO := 0.36    # hero column width from the viewport
const ACTION_W_MIN := 300.0
const ACTION_W_MAX := 470.0     # wider than the footer row: hierarchy
const PRIMARY_H := 88.0
const SECONDARY_H := 58.0
const PAIR_H := 50.0
const DIFF_H := 26.0
const DIFF_W := 240.0
const ACTION_GAP := 12.0        # rhythm inside the action column
const ACTION_GAP_TIGHT := 6.0
const STORY_RATIO := 0.82       # secondary width from the hero column
const PAIR_RATIO := 0.94        # pair card width from the hero column
const PAIR_INSET := 40.0        # symmetric text insets on the pair card
const PAIR_DOT_CLEAR := 12.0    # program text clears the center dot
const MODE_INFO_H := 32.0       # hidden annotation row under the pair
const MODE_INFO_H_TIGHT := 24.0
const MODE_INFO_GAP := 8.0
const FOOTER_H := 48.0
const FOOTER_RIDE := 24.0       # footer bottom rides the shell bottom rail
const FOOTER_RIDE_TIGHT := 12.0
const FOOTER_TEXT_INSET := 92.0 # footer label clears its icon slot
const STACK_AIR_MIN := 4.0      # minimum air around the centered unit
const PROMPT_H := 26.0          # transient prompt rides the annotation band
const RING_PULL := 470.0        # warning ring pull from the column axis
const RING_RIDE := 70.0         # ring never crosses the left rail
const RING_R := 64.0

var m
var _layout: Dictionary = {}


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

func _add_menu_frame(_rect: Rect2, accent: Color, alpha: float = 0.025) -> Control:
	# Frames are created geometry-free: with a zero panel rect the chrome falls
	# back to its control size, and apply_menu_layout owns position/size.
	var frame: Control = TacticalChromeScript.new()
	frame.set_anchors_preset(Control.PRESET_TOP_LEFT)
	frame.size = Vector2.ZERO
	frame.z_index = 1
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.call("configure_panel", Rect2(), accent, alpha)
	m.add_child(frame)
	m._menu_frames.append(frame)
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
	# Keep the slot inside the button and its center on the button's optical
	# midline: a slot taller than the button used to straddle the border lines.
	var slot := minf(icon_size, maxf(button.custom_minimum_size.y - 4.0, 12.0))
	icon.position = Vector2(10.0, (button.custom_minimum_size.y - slot) * 0.5)
	icon.size = Vector2(slot, slot)
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

## The whole menu geometry from one spec. Every rect below derives from the
## shared frame margins, the declared constants above, and the two rail
## anchors — no per-block coordinates.
func menu_layout_for_viewport(viewport: Vector2) -> Dictionary:
	var compact := viewport.x < 760.0
	var title_size := 76
	if viewport.x < 1100.0:
		title_size = 58
	if compact:
		title_size = 44
	var frame := TacticalUIHelper.frame_margins(viewport)
	var shell := Rect2(frame.x, frame.y, maxf(viewport.x - frame.x * 2.0, 0.0), maxf(viewport.y - frame.y * 2.0, 0.0))
	var content_x := shell.position.x + GUTTER
	var content_w := maxf(shell.size.x - GUTTER * 2.0, 0.0)
	var center_x := viewport.x * 0.5

	# Declared compression cascade: the first level that fits wins.
	var action_gap := ACTION_GAP
	var mi_h := MODE_INFO_H_TIGHT if compact else MODE_INFO_H
	var meta_h := META_H_COMPACT if compact else META_H
	var footer_ride := FOOTER_RIDE
	var level := 0
	var title_h := float(title_size) * 1.45
	var header_end := 0.0
	var footer_top := 0.0
	var zone := 0.0
	var unit_h := 0.0
	var action_h := 0.0
	while true:
		var meta_end := shell.position.y - META_RIDE + meta_h
		var title_top := meta_end + TITLE_DROP
		header_end = title_top + title_h + ROW_GAP + SUBTITLE_H + ROW_GAP + CONTROLS_H + ROW_GAP + BEST_H
		footer_top = shell.end.y - footer_ride - FOOTER_H
		action_h = PRIMARY_H + action_gap + SECONDARY_H + action_gap + PAIR_H + action_gap + DIFF_H
		unit_h = action_h + MODE_INFO_GAP + mi_h
		zone = footer_top - STACK_AIR_MIN - (header_end + STACK_AIR_MIN)
		if zone >= unit_h or level == 4:
			break
		level += 1
		match level:
			1:
				action_gap = ACTION_GAP_TIGHT
			2:
				mi_h = MODE_INFO_H_TIGHT
			3:
				meta_h = META_H_COMPACT if compact else 48.0
			4:
				footer_ride = FOOTER_RIDE_TIGHT

	var meta_end := shell.position.y - META_RIDE + meta_h
	var title_top := meta_end + TITLE_DROP
	var title := Rect2(0.0, title_top, viewport.x, title_h)
	var klog := Rect2(shell.position.x, shell.position.y - META_RIDE, minf(340.0, content_w), meta_h)
	var version := Rect2(0.0, meta_end + VERSION_DROP, minf(VERSION_W, content_w), VERSION_H)
	version.position.x = shell.end.x - version.size.x
	var subtitle := Rect2(content_x, title.end.y + ROW_GAP, content_w, SUBTITLE_H)
	var controls := Rect2(content_x, subtitle.end.y + ROW_GAP, content_w, CONTROLS_H)
	var best := Rect2(content_x, controls.end.y + ROW_GAP, content_w, BEST_H)

	# Action column: centered unit in the free zone between the anchors.
	var air := maxf((zone - unit_h) * 0.5, 0.0)
	var action_top := header_end + STACK_AIR_MIN + air
	var action_w := clampf(viewport.x * ACTION_W_RATIO, ACTION_W_MIN, ACTION_W_MAX)
	var col_x := center_x - action_w * 0.5
	var purge := Rect2(col_x, action_top, action_w, PRIMARY_H)
	var story_w := action_w * STORY_RATIO
	var story := Rect2(center_x - story_w * 0.5, purge.end.y + action_gap, story_w, SECONDARY_H)
	var pair_w := action_w * PAIR_RATIO
	var pair_x := center_x - pair_w * 0.5
	var mode := Rect2(pair_x, story.end.y + action_gap, pair_w, PAIR_H)
	var program_w := maxf(pair_w * 0.5 - PAIR_INSET - PAIR_DOT_CLEAR, 60.0)
	var program := Rect2(mode.get_center().x + PAIR_DOT_CLEAR, mode.position.y, program_w, PAIR_H)
	var diff := Rect2(center_x - DIFF_W * 0.5, mode.end.y + action_gap, DIFF_W, DIFF_H)
	var mode_info := Rect2(content_x, diff.end.y + MODE_INFO_GAP, content_w, mi_h)
	var prompt := Rect2(content_x, mode_info.position.y, content_w, minf(PROMPT_H, maxf(mi_h, 0.0)))

	# Footer: three equal slots on the bottom rail, equal gaps, one baseline.
	var footer_layout := footer_button_layout_for_viewport(viewport)
	var row_w: float = footer_layout["total_width"]
	var button_row := Rect2((viewport.x - row_w) * 0.5, footer_top, row_w, FOOTER_H)

	# Decor tracks the spec: ring hangs left of the column at the action zone's
	# optical center; dot sits at the pair card's center.
	var ring_center := Vector2(maxf(shell.position.x + RING_RIDE, center_x - RING_PULL), (action_top + diff.end.y) * 0.5)
	var mode_dot := mode.get_center()
	var frames: Array = [purge, story, mode]
	var slot_x := button_row.position.x
	for i in 3:
		frames.append(Rect2(slot_x, button_row.position.y, float(footer_layout["button_width"]), FOOTER_H))
		slot_x += float(footer_layout["button_width"]) + float(footer_layout["gap"])
	return {"viewport": viewport, "compact": compact, "title_size": title_size, "title": title, "klog": klog, "version": version, "subtitle": subtitle, "controls": controls, "best": best, "mode_info": mode_info, "prompt": prompt, "purge": purge, "story": story, "mode": mode, "program": program, "diff": diff, "button_row": button_row, "button_width": float(footer_layout["button_width"]), "gap": float(footer_layout["gap"]), "ring_center": ring_center, "mode_dot": mode_dot, "frames": frames, "shell": shell, "footer_ride": footer_ride}

func menu_layout() -> Dictionary:
	return _layout if not _layout.is_empty() else menu_layout_for_viewport(m.size)

func apply_menu_layout() -> void:
	_layout = menu_layout_for_viewport(m.size)
	var lay := _layout
	for title_label in [m._title, m._title_r, m._title_b]:
		if title_label != null and is_instance_valid(title_label):
			title_label.offset_top = (lay["title"] as Rect2).position.y
			title_label.offset_bottom = (lay["title"] as Rect2).end.y
			title_label.add_theme_font_size_override("font_size", int(lay["title_size"]))
	if m._subtitle != null and is_instance_valid(m._subtitle):
		m._subtitle.offset_left = (lay["subtitle"] as Rect2).position.x
		m._subtitle.offset_right = (lay["subtitle"] as Rect2).end.x
		m._subtitle.offset_top = (lay["subtitle"] as Rect2).position.y
		m._subtitle.offset_bottom = (lay["subtitle"] as Rect2).end.y
	if m._controls_line != null and is_instance_valid(m._controls_line):
		m._controls_line.anchor_top = 0.0
		m._controls_line.anchor_bottom = 0.0
		m._controls_line.offset_left = (lay["controls"] as Rect2).position.x
		m._controls_line.offset_right = (lay["controls"] as Rect2).end.x
		m._controls_line.offset_top = (lay["controls"] as Rect2).position.y
		m._controls_line.offset_bottom = (lay["controls"] as Rect2).end.y
	if m._best_label != null and is_instance_valid(m._best_label):
		m._best_label.offset_left = (lay["best"] as Rect2).position.x
		m._best_label.offset_right = (lay["best"] as Rect2).end.x
		m._best_label.offset_top = (lay["best"] as Rect2).position.y
		m._best_label.offset_bottom = (lay["best"] as Rect2).end.y
	if m._klog != null and is_instance_valid(m._klog):
		m._klog.offset_left = (lay["klog"] as Rect2).position.x
		m._klog.offset_right = (lay["klog"] as Rect2).end.x
		m._klog.offset_top = (lay["klog"] as Rect2).position.y
		m._klog.offset_bottom = (lay["klog"] as Rect2).end.y
	if m._version_tag != null and is_instance_valid(m._version_tag):
		m._version_tag.offset_left = (lay["version"] as Rect2).position.x - m.size.x
		m._version_tag.offset_right = (lay["version"] as Rect2).end.x - m.size.x
		m._version_tag.offset_top = (lay["version"] as Rect2).position.y
		m._version_tag.offset_bottom = (lay["version"] as Rect2).end.y
	if m._mode_info != null and is_instance_valid(m._mode_info):
		m._mode_info.anchor_top = 0.0
		m._mode_info.anchor_bottom = 0.0
		m._mode_info.offset_left = (lay["mode_info"] as Rect2).position.x
		m._mode_info.offset_right = (lay["mode_info"] as Rect2).end.x
		m._mode_info.offset_top = (lay["mode_info"] as Rect2).position.y
		m._mode_info.offset_bottom = (lay["mode_info"] as Rect2).end.y
	if m._prompt != null and is_instance_valid(m._prompt):
		m._prompt.offset_left = (lay["prompt"] as Rect2).position.x
		m._prompt.offset_right = (lay["prompt"] as Rect2).end.x
		m._prompt.offset_top = (lay["prompt"] as Rect2).position.y
		m._prompt.offset_bottom = (lay["prompt"] as Rect2).end.y
	_place_center_button(m._purge_btn, lay["purge"])
	_place_center_button(m._story_btn, lay["story"])
	_place_center_button(m._mode_btn, lay["mode"])
	_place_center_button(m._program_btn, lay["program"])
	_place_center_button(m._diff_btn, lay["diff"])
	_set_button_min(m._purge_btn, (lay["purge"] as Rect2).size)
	_set_button_min(m._story_btn, (lay["story"] as Rect2).size)
	_set_button_min(m._mode_btn, (lay["mode"] as Rect2).size)
	_set_button_min(m._program_btn, (lay["program"] as Rect2).size)
	_set_button_min(m._diff_btn, (lay["diff"] as Rect2).size)
	var row_rect := lay["button_row"] as Rect2
	if m._footer_row != null and is_instance_valid(m._footer_row):
		m._footer_row.anchor_left = 0.0
		m._footer_row.anchor_right = 0.0
		m._footer_row.anchor_top = 0.0
		m._footer_row.anchor_bottom = 0.0
		m._footer_row.position = row_rect.position
		m._footer_row.size = row_rect.size
		m._footer_row.add_theme_constant_override("separation", int(lay["gap"]))
		for footer_button in m._footer_row.get_children():
			if footer_button is Button:
				_set_button_min(footer_button, Vector2(float(lay["button_width"]), FOOTER_H))
				footer_button.pivot_offset = Vector2(float(lay["button_width"]), FOOTER_H) * 0.5
	for i in mini(m._menu_frames.size(), (lay["frames"] as Array).size()):
		var frame: Control = m._menu_frames[i]
		if frame != null and is_instance_valid(frame):
			var frame_rect: Rect2 = (lay["frames"] as Array)[i]
			frame.position = frame_rect.position
			frame.size = frame_rect.size

func _set_button_min(button: Button, size: Vector2) -> void:
	if button == null or not is_instance_valid(button):
		return
	button.custom_minimum_size = size

func _place_center_button(button: Button, rect: Rect2) -> void:
	if button == null or not is_instance_valid(button):
		return
	var center := Vector2(m.size.x, m.size.y) * 0.5
	button.anchor_left = 0.5
	button.anchor_right = 0.5
	button.anchor_top = 0.5
	button.anchor_bottom = 0.5
	button.offset_left = rect.position.x - center.x
	button.offset_right = rect.end.x - center.x
	button.offset_top = rect.position.y - center.y
	button.offset_bottom = rect.end.y - center.y
	button.pivot_offset = rect.size * 0.5

func _build_button_row() -> void:
	# Geometry-free build: styling and wiring only — menu_layout_for_viewport +
	# apply_menu_layout own every rect, so resize never rebuilds nodes.
	m._purge_btn = Button.new()
	_style_card_button(m._purge_btn, Balance.COL_PLAYER, Vector2(0, PRIMARY_H))
	m._purge_btn.text = ">> PURGE"
	m._purge_btn.add_theme_font_size_override("font_size", 30)
	m._purge_btn.pressed.connect(m._start)
	m.add_child(m._purge_btn)
	_add_menu_frame(Rect2(), Balance.COL_PLAYER, 0.035)
	m._story_btn = Button.new()
	_style_card_button(m._story_btn, Balance.COL_PLAYER, Vector2(0, SECONDARY_H))
	m._story_btn.text = "STORY // ACTS"
	m._story_btn.add_theme_font_size_override("font_size", 19)
	m._story_btn.pressed.connect(m._open_story_selector)
	m.add_child(m._story_btn)
	_add_menu_frame(Rect2(), Balance.COL_PLAYER, 0.025)
	m._mode_btn = Button.new()
	_style_card_button(m._mode_btn, Balance.COL_MOTE, Vector2(0, PAIR_H))
	m._mode_btn.text = "MODE: CLASSIC"
	m._mode_btn.add_theme_font_size_override("font_size", 16)
	m._mode_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	m._mode_btn.pressed.connect(m._cycle_mode)
	m.add_child(m._mode_btn)
	var mode_normal: StyleBox = m._mode_btn.get_theme_stylebox("normal").duplicate()
	mode_normal.content_margin_left = PAIR_INSET
	m._mode_btn.add_theme_stylebox_override("normal", mode_normal)
	var mode_hover: StyleBox = m._mode_btn.get_theme_stylebox("hover").duplicate()
	mode_hover.content_margin_left = PAIR_INSET
	m._mode_btn.add_theme_stylebox_override("hover", mode_hover)
	var mode_pressed: StyleBox = m._mode_btn.get_theme_stylebox("pressed").duplicate()
	mode_pressed.content_margin_left = PAIR_INSET
	m._mode_btn.add_theme_stylebox_override("pressed", mode_pressed)
	_add_menu_frame(Rect2(), Balance.COL_MOTE, 0.03)
	m._program_btn = Button.new()
	m._program_btn.flat = true
	m._program_btn.z_index = 2
	m._program_btn.focus_mode = Control.FOCUS_NONE
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
	m._diff_btn.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	m._diff_btn.add_theme_font_size_override("font_size", 13)
	m._diff_btn.add_theme_color_override("font_color", Color(0.6, 1.0, 0.8, 0.9))
	m._diff_btn.add_theme_color_override("font_hover_color", TacticalUIHelper.LIME)
	m._diff_btn.pressed.connect(m._cycle_difficulty)
	m.add_child(m._diff_btn)
	m._refresh_difficulty_label()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	m._footer_row = row
	m.add_child(row)
	m._refresh_program_label()
	var settings_btn := Button.new()
	_style_card_button(settings_btn, Balance.COL_TEXT, Vector2(0, FOOTER_H))
	settings_btn.text = "SETTINGS"
	_set_button_text_inset(settings_btn, FOOTER_TEXT_INSET)
	_add_button_icon(settings_btn, "settings", Balance.COL_PLAYER, 52.0)
	settings_btn.z_index = 2
	settings_btn.pressed.connect(m._open_settings)
	row.add_child(settings_btn)
	var best_btn := Button.new()
	_style_card_button(best_btn, Balance.COL_SPEWER, Vector2(0, FOOTER_H))
	best_btn.text = "BESTIARY"
	_set_button_text_inset(best_btn, FOOTER_TEXT_INSET)
	_add_button_icon(best_btn, "bestiary", Balance.COL_SPEWER, 52.0)
	best_btn.z_index = 2
	best_btn.pressed.connect(m._open_bestiary)
	row.add_child(best_btn)
	var ach_btn := Button.new()
	_style_card_button(ach_btn, TacticalUIHelper.LIME, Vector2(0, FOOTER_H))
	ach_btn.text = "AWARDS"
	_set_button_text_inset(ach_btn, FOOTER_TEXT_INSET)
	_add_button_icon(ach_btn, "awards", TacticalUIHelper.LIME, 52.0)
	ach_btn.z_index = 2
	ach_btn.pressed.connect(m._open_achievements)
	row.add_child(ach_btn)
	m._mode_info = Label.new()
	m._mode_info.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	m._mode_info.add_theme_font_size_override("font_size", 12)
	m._mode_info.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.6))
	m._mode_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m._mode_info.anchor_left = 0.0
	m._mode_info.anchor_right = 0.0
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
	var ring_center: Vector2 = menu_layout()["ring_center"]
	for arc_index in 3:
		var start := -PI * 0.82 + arc_index * TAU / 3.0
		m.draw_arc(ring_center, RING_R, start, start + PI * 0.48, 18, Color(Balance.COL_DANGER.r, Balance.COL_DANGER.g, Balance.COL_DANGER.b, 0.5), 5.0, true)
	var ring_triangle := PackedVector2Array([
		ring_center + Vector2(0.0, -24.0),
		ring_center + Vector2(27.0, 22.0),
		ring_center + Vector2(-27.0, 22.0),
	])
	m.draw_polyline(ring_triangle + PackedVector2Array([ring_triangle[0]]), Color(Balance.COL_DANGER.r, Balance.COL_DANGER.g, Balance.COL_DANGER.b, 0.58), 2.0, true)
	m.draw_circle(ring_center, 9.0, Color(Balance.COL_DANGER.r, Balance.COL_DANGER.g, Balance.COL_DANGER.b, 0.42))
	m.draw_circle(menu_layout()["mode_dot"], 4.0, Balance.COL_MOTE)

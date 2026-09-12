class_name StoryIntroPanel
extends Control

## Intro narrativa sobre a arena. Usa a gramática editorial como uma variante
## de combate: scrim contextual, coluna tipográfica forte e nenhuma carcaça
## TacticalStateSurface. O estado/fade continua pertencendo ao IntroKit.

var path_label: Label
var title_label: Label
var body_label: Label
var hint_label: Label
var footer_label: Label

var _page: MarginContainer
var _content: VBoxContainer
var _rule: ColorRect


func _ready() -> void:
	theme = UiTheme.shared()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_apply_layout_mode()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_layout_mode()


func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "StoryIntroScrim"
	dim.color = Design.SCRIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_page = MarginContainer.new()
	_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_page)

	var vertical := VBoxContainer.new()
	vertical.add_theme_constant_override("separation", 0)
	vertical.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(vertical)
	ScreenKit.grow_v(vertical)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vertical.add_child(row)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", Design.SPACE_SM)
	_content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_content)
	ScreenKit.grow_h(row)

	path_label = ScreenKit.mono("", Design.TEXT_CAPTION, Design.ACCENT)
	_content.add_child(path_label)

	title_label = ScreenKit.grot("", Design.TEXT_TITLE, Design.WEIGHT_BLACK, Design.TEXT_PRIMARY)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_content.add_child(title_label)

	ScreenKit.gap(_content, Design.SPACE_SM)
	_rule = ColorRect.new()
	_rule.color = Design.alpha(Design.ACCENT, 0.52)
	_rule.custom_minimum_size = Vector2(0.0, Design.STROKE_HAIRLINE)
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_rule)
	ScreenKit.gap(_content, Design.SPACE_MD)

	body_label = ScreenKit.mono("", Design.TEXT_BODY, Design.TEXT_SECONDARY)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(body_label)

	ScreenKit.gap(_content, Design.SPACE_LG)
	var footer_row := HBoxContainer.new()
	footer_row.add_theme_constant_override("separation", Design.SPACE_LG)
	footer_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(footer_row)
	footer_label = ScreenKit.mono("", Design.TEXT_MICRO, Design.TEXT_MUTED)
	footer_row.add_child(footer_label)
	ScreenKit.grow_h(footer_row)
	hint_label = ScreenKit.mono("PRESS ANY KEY", Design.TEXT_MICRO, Design.TEXT_MUTED)
	hint_label.modulate.a = 0.0
	footer_row.add_child(hint_label)

	ScreenKit.grow_v(vertical)


func set_story(path_text: String, title_text: String, body_text: String, footer_text: String) -> void:
	path_label.text = path_text
	title_label.text = title_text
	body_label.text = body_text
	footer_label.text = footer_text


func fit_body(max_height: float, font_floor: int) -> int:
	if not is_instance_valid(body_label):
		return font_floor
	var width := body_label.size.x
	if width <= 1.0:
		width = minf(Design.CONTENT_MAX_PROSE, maxf(size.x - float(Design.SPACE_4XL) * 2.0, 240.0))
	var font := body_label.get_theme_font("font")
	var chosen := font_floor
	for fs in [Design.TEXT_BODY, Design.TEXT_CAPTION, font_floor]:
		if TacticalUI.wrapped_height(font, body_label.text, width, fs) <= max_height:
			chosen = fs
			break
	body_label.add_theme_font_size_override("font_size", chosen)
	return chosen


func content_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for node in [path_label, title_label, _rule, body_label, footer_label, hint_label]:
		if node != null and is_instance_valid(node) and node.is_visible_in_tree():
			out.append(Rect2(node.global_position - global_position, node.size))
	return out


func _apply_layout_mode() -> void:
	if not is_instance_valid(_page) or not is_instance_valid(_content):
		return
	var step := Design.breakpoint_for(size.x)
	var narrow := step == "compact" or step == "medium"
	var side := Design.SPACE_XL if narrow else Design.SPACE_4XL
	var vertical := Design.SPACE_XL if size.y < 700.0 else Design.SPACE_2XL
	_page.add_theme_constant_override("margin_left", side)
	_page.add_theme_constant_override("margin_right", side)
	_page.add_theme_constant_override("margin_top", vertical)
	_page.add_theme_constant_override("margin_bottom", vertical)
	var available := maxf(size.x - float(side) * 2.0, 240.0)
	_content.custom_minimum_size.x = minf(Design.CONTENT_MAX_PROSE, available)
	title_label.add_theme_font_size_override("font_size", Design.TEXT_HEADING if narrow else Design.TEXT_TITLE)

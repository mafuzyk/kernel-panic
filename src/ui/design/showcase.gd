extends Control

## Style guide vivo do design system. Renderiza todos os tokens e estados de
## componente numa página só, para inspeção visual e captura de regressão.
##
## Rodar:
##     tools/virtual-session/kp-virtual.sh showcase /tmp/showcase.png
##
## Serve a dois propósitos: prova que o Theme está correto, e vira a referência
## que substitui "procurar no código qual cinza é o certo".

const _SWATCHES := [
	["ACCENT", Design.ACCENT], ["ACCENT_HOT", Design.ACCENT_HOT],
	["DANGER", Design.DANGER], ["WARNING", Design.WARNING],
	["SUCCESS", Design.SUCCESS], ["INFO", Design.INFO],
]
const _TEXT_LEVELS := [
	["TEXT_PRIMARY", Design.TEXT_PRIMARY], ["TEXT_SECONDARY", Design.TEXT_SECONDARY],
	["TEXT_MUTED", Design.TEXT_MUTED], ["TEXT_FAINT", Design.TEXT_FAINT],
	["TEXT_GHOST", Design.TEXT_GHOST],
]
const _TYPE_SCALE := [
	["DisplayLabel", "76 / display"], ["TitleLabel", "44 / title"],
	["HeadingLabel", "32 / heading"], ["SubheadLabel", "18 / subhead"],
	["BodyLabel", "15 / body"], ["CaptionLabel", "13 / caption"],
	["MicroLabel", "11 / micro"],
]
const _SPACE_SCALE := [
	["XS", Design.SPACE_XS], ["SM", Design.SPACE_SM], ["MD", Design.SPACE_MD],
	["LG", Design.SPACE_LG], ["XL", Design.SPACE_XL], ["2XL", Design.SPACE_2XL],
	["3XL", Design.SPACE_3XL],
]


func _ready() -> void:
	theme = UiTheme.build()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Design.SURFACE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var page := MarginContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(page)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", Design.SPACE_XL)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(col)

	_heading(col, "KERNEL PANIC // DESIGN SYSTEM")
	_section(col, "ESCALA DE TIPO", _build_type_scale())
	_section(col, "COR SEMANTICA", _build_swatches())
	_section(col, "NIVEIS DE TEXTO", _build_text_levels())
	_section(col, "ESPACAMENTO (base 4)", _build_space_scale())
	_section(col, "BOTOES // PAPEIS E ESTADOS", _build_buttons())
	_section(col, "PAINEIS", _build_panels())
	_capture_if_requested()


func _heading(parent: Node, text: String) -> void:
	var l := Label.new()
	l.theme_type_variation = "HeadingLabel"
	l.text = text
	parent.add_child(l)


func _section(parent: Node, title: String, body: Control) -> void:
	var head := Label.new()
	head.theme_type_variation = "MicroLabel"
	head.text = "── %s" % title
	parent.add_child(head)
	parent.add_child(body)


func _build_type_scale() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Design.SPACE_SM)
	for entry in _TYPE_SCALE:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", Design.SPACE_LG)
		var sample := Label.new()
		sample.theme_type_variation = str(entry[0])
		sample.text = "PURGE"
		row.add_child(sample)
		var tag := Label.new()
		tag.theme_type_variation = "FaintLabel"
		tag.text = str(entry[1])
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tag)
		box.add_child(row)
	return box


func _build_swatches() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Design.SPACE_MD)
	for entry in _SWATCHES:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", Design.SPACE_XS)
		var chip := ColorRect.new()
		chip.color = entry[1]
		chip.custom_minimum_size = Vector2(120, 44)
		cell.add_child(chip)
		var name_label := Label.new()
		name_label.theme_type_variation = "MicroLabel"
		name_label.text = str(entry[0])
		cell.add_child(name_label)
		row.add_child(cell)
	return row


func _build_text_levels() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Design.SPACE_XS)
	for entry in _TEXT_LEVELS:
		var l := Label.new()
		l.theme_type_variation = "BodyLabel"
		l.add_theme_color_override("font_color", entry[1])
		l.text = "%s — the daemons send their regards" % str(entry[0])
		box.add_child(l)
	return box


func _build_space_scale() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Design.SPACE_XS)
	for entry in _SPACE_SCALE:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", Design.SPACE_SM)
		var bar := ColorRect.new()
		bar.color = Design.ACCENT
		bar.custom_minimum_size = Vector2(float(entry[1]), 14)
		row.add_child(bar)
		var tag := Label.new()
		tag.theme_type_variation = "MicroLabel"
		tag.text = "%s = %dpx" % [str(entry[0]), int(entry[1])]
		row.add_child(tag)
		box.add_child(row)
	return box


func _build_buttons() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Design.SPACE_MD)
	for variation in ["", "PrimaryButton", "DangerButton", "GhostButton"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", Design.SPACE_MD)
		var tag := Label.new()
		tag.theme_type_variation = "MicroLabel"
		tag.text = variation if variation != "" else "Button (base)"
		tag.custom_minimum_size = Vector2(150, 0)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tag)
		# normal / disabled lado a lado; hover e pressed não dá para forçar
		# numa captura estática, mas o Theme os define.
		for state in ["NORMAL", "DISABLED"]:
			var b := Button.new()
			if variation != "":
				b.theme_type_variation = variation
			b.text = state
			b.custom_minimum_size = Vector2(220, Design.CLICK_TARGET_MIN)
			b.disabled = state == "DISABLED"
			row.add_child(b)
		box.add_child(row)
	return box


func _build_panels() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Design.SPACE_LG)
	for variation in ["TacticalPanel", "OverlayPanel", "ScrimPanel"]:
		var wrap := VBoxContainer.new()
		wrap.add_theme_constant_override("separation", Design.SPACE_XS)
		# fundo de xadrez claro atrás: painel opaco sobre fundo escuro é
		# invisível e não prova nada sobre a opacidade.
		var stage := Control.new()
		stage.custom_minimum_size = Vector2(300, 110)
		var probe := ColorRect.new()
		probe.color = Design.ACCENT
		probe.set_anchors_preset(Control.PRESET_FULL_RECT)
		stage.add_child(probe)
		var p := Panel.new()
		p.theme_type_variation = variation
		p.set_anchors_preset(Control.PRESET_FULL_RECT)
		stage.add_child(p)
		wrap.add_child(stage)
		var tag := Label.new()
		tag.theme_type_variation = "MicroLabel"
		tag.text = variation
		wrap.add_child(tag)
		row.add_child(wrap)
	return row


func _capture_if_requested() -> void:
	var out := OS.get_environment("KP_SHOT_OUT")
	if out == "":
		return
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("SHOT_SAVED ", out, " ", img.get_width(), "x", img.get_height())
	get_tree().quit(0)

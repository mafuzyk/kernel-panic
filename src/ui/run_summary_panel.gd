class_name RunSummaryPanel
extends Control

## Tela de fim de run (morte e vitória de stage), na direção editorial aprovada
## em 2026-09-11.
##
## É um componente de verdade sobre o design system: recebe os dados prontos e
## monta o layout. Não conhece `Arena` nem `Game` — quem chama preenche o
## dicionário. Isso é o oposto dos "kits", que são o mesmo objeto espalhado em
## vários arquivos com 688 acessos de volta ao dono.
##
## Corrige dois bugs da auditoria de forma ESTRUTURAL, não por ajuste:
##
##   B2 — `SEED          SEED -1999920091431960591`. O valor vinha de
##        `Game.run_seed_text()`, que já embute o prefixo, e o chamador
##        prefixava de novo. Aqui rótulo e valor são campos separados; não há
##        como duplicar.
##   B3 — sete linhas em três colunas diferentes, porque o alinhamento era
##        espaço contado à mão em `%s`. Aqui a coluna é layout.

signal primary_pressed
signal secondary_pressed

const BADGE_GAP := 34.0

var _title: Label
var _subtitle: Label
var _score_value: Label
var _score_caption: Label
var _badge: Label
var _meta: Label
var _stats_row: HBoxContainer
var _primary_label: Label
var _secondary_label: Label
var _accent := Design.DANGER

## Preenchidos em _ready a partir das chaves de tradução: como inicializador
## de membro eles rodariam antes do TranslationServer estar no locale certo.
var _primary_text := ""
var _secondary_text := ""


func _ready() -> void:
	theme = UiTheme.shared()
	# anchors_AND_offsets: só `set_anchors_preset` ajusta as âncoras e deixa os
	# offsets como estavam. Sob um CanvasLayer isso deixa o Control com tamanho
	# zero, os containers colapsam no mínimo e o título quebra letra por letra.
	_primary_text = tr("OVER_REBOOT")
	_secondary_text = tr("OVER_ABANDON")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_resize_to_viewport()
	get_viewport().size_changed.connect(_resize_to_viewport)
	_build()


func _resize_to_viewport() -> void:
	var vp := get_viewport_rect().size
	if vp.x > 0.0 and vp.y > 0.0:
		size = vp


## Rótulos das ações, na ordem. Contrato verificado pelo autotest: a ação de
## repetir vem primeiro.
func action_labels() -> Array[String]:
	return [_primary_text, _secondary_text]


## Preenche a tela. Campos aceitos:
##   title, subtitle, accent, score_caption, score_value, badge,
##   stats (Array de [rótulo, valor]), meta, primary, primary_key,
##   secondary, secondary_key
func show_summary(data: Dictionary) -> void:
	_accent = data.get("accent", Design.DANGER)

	_title.text = str(data.get("title", "PROCESS TERMINATED"))
	_title.add_theme_color_override("font_color", Design.TEXT_PRIMARY)
	_subtitle.text = str(data.get("subtitle", ""))

	_score_caption.text = str(data.get("score_caption", "SCORE"))
	_score_value.text = str(data.get("score_value", ""))

	var badge := str(data.get("badge", ""))
	_badge.text = badge
	_badge.visible = not badge.is_empty()
	_badge.add_theme_color_override("font_color", _accent)

	_meta.text = str(data.get("meta", ""))
	_meta.visible = not _meta.text.is_empty()

	_primary_text = str(data.get("primary", "REBOOT"))
	_secondary_text = str(data.get("secondary", "ABANDON PROCESS"))
	_primary_label.text = _primary_text
	_secondary_label.text = _secondary_text

	_rebuild_stats(data.get("stats", []))
	queue_redraw()


func _rebuild_stats(stats: Array) -> void:
	for child in _stats_row.get_children():
		_stats_row.remove_child(child)
		child.queue_free()
	for entry in stats:
		if not (entry is Array) or entry.size() < 2:
			continue
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", Design.SPACE_XS)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var caption := Label.new()
		caption.theme_type_variation = "CaptionLabel"
		caption.add_theme_color_override("font_color", Design.TEXT_MUTED)
		caption.text = str(entry[0])
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(caption)

		var value := Label.new()
		value.add_theme_font_override("font", Design.grotesk(Design.WEIGHT_BLACK))
		value.add_theme_font_size_override("font_size", 46)
		value.add_theme_color_override("font_color", Design.TEXT_PRIMARY)
		value.text = str(entry[1])
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(value)

		_stats_row.add_child(cell)


# ── construção ────────────────────────────────────────────────────────

func _grot(size: int, weight: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", Design.grotesk(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _mono(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.theme_type_variation = "BodyLabel"
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Design.SURFACE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override("margin_left", Design.SPACE_4XL)
	pad.add_theme_constant_override("margin_right", Design.SPACE_4XL)
	pad.add_theme_constant_override("margin_top", Design.SPACE_2XL)
	pad.add_theme_constant_override("margin_bottom", Design.SPACE_2XL)
	add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	pad.add_child(col)

	_build_masthead(col)
	_gap(col, Design.SPACE_3XL)
	_build_hero(col)
	_gap(col, Design.SPACE_2XL)
	_rule(col)
	_gap(col, Design.SPACE_XL)

	_stats_row = HBoxContainer.new()
	_stats_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_stats_row)

	_gap(col, Design.SPACE_LG)
	_meta = _mono("", Design.TEXT_CAPTION, Design.TEXT_MUTED)
	col.add_child(_meta)

	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grow)

	_build_actions(col)


func _gap(parent: Node, h: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(s)


func _rule(parent: Node) -> void:
	var r := ColorRect.new()
	r.color = Design.alpha(Design.TEXT_PRIMARY, 0.22)
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)


func _build_masthead(parent: Node) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)

	var mark := VBoxContainer.new()
	mark.add_theme_constant_override("separation", -6)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l1 := _grot(28, Design.WEIGHT_BLACK, Design.TEXT_PRIMARY); l1.text = "KERNEL"
	var l2 := _grot(28, Design.WEIGHT_BLACK, Design.TEXT_PRIMARY); l2.text = "PANIC"
	mark.add_child(l1); mark.add_child(l2)
	mark.add_child(_mono(tr("TAGLINE"), Design.TEXT_MICRO, Design.TEXT_MUTED))
	row.add_child(mark)

	var grow := Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(grow)

	var tag := HBoxContainer.new()
	tag.add_theme_constant_override("separation", Design.SPACE_MD)
	tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(_mono(tr("OVER_CORE_DUMP"), Design.TEXT_CAPTION, Design.TEXT_SECONDARY))
	var dash := ColorRect.new()
	dash.color = Design.alpha(Design.TEXT_PRIMARY, 0.5)
	dash.custom_minimum_size = Vector2(34, 1)
	dash.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.add_child(dash)
	row.add_child(tag)


func _build_hero(parent: Node) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Design.SPACE_4XL)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", Design.SPACE_SM)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_title = _grot(74, Design.WEIGHT_BLACK, Design.TEXT_PRIMARY)
	# WORD, não WORD_SMART: SMART quebra DENTRO da palavra quando ela não cabe,
	# e "TERMINATED" em 74px vira uma coluna de sílabas.
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	left.add_child(_title)
	_subtitle = _mono("", Design.TEXT_SUBHEAD, Design.TEXT_SECONDARY)
	left.add_child(_subtitle)
	row.add_child(left)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", Design.SPACE_XS)
	right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	right.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_caption = _mono(tr("STAT_SCORE"), Design.TEXT_SUBHEAD, Design.TEXT_SECONDARY)
	right.add_child(_score_caption)
	_score_value = _grot(66, Design.WEIGHT_BLACK, Design.TEXT_PRIMARY)
	right.add_child(_score_value)
	_badge = _mono("", Design.TEXT_SUBHEAD, Design.DANGER)
	right.add_child(_badge)
	row.add_child(right)


func _build_actions(parent: Node) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Design.SPACE_2XL)
	parent.add_child(row)
	row.add_child(_action_block(true))
	row.add_child(_action_block(false))
	var grow := Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(grow)


## Um bloco de ação. `Button` não dispõe filhos Control — quem dimensiona é o
## PanelContainer; o Button entra por cima, invisível, só para clique e foco.
## Sem isso o conteúdo fica com tamanho zero e o rótulo sai cortado ("REB").
func _action_block(primary: bool) -> Control:
	var stack := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	if primary:
		sb.bg_color = Design.ACCENT
	else:
		sb.bg_color = Design.alpha(Design.TEXT_PRIMARY, 0.0)
	sb.content_margin_left = Design.SPACE_2XL if primary else Design.SPACE_MD
	sb.content_margin_right = Design.SPACE_2XL if primary else Design.SPACE_MD
	sb.content_margin_top = Design.SPACE_LG
	sb.content_margin_bottom = Design.SPACE_LG
	stack.add_theme_stylebox_override("panel", sb)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", Design.SPACE_XL)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(line)

	var label := _grot(30 if primary else 25, Design.WEIGHT_HEAVY if primary else Design.WEIGHT_BOLD,
		Design.SURFACE if primary else Design.TEXT_PRIMARY)
	label.text = _primary_text if primary else _secondary_text
	line.add_child(label)
	line.add_child(_mono("[ENTER]" if primary else "[ESC]", Design.TEXT_CAPTION,
		Design.alpha(Design.SURFACE, 0.7) if primary else Design.TEXT_MUTED))

	if primary:
		_primary_label = label
	else:
		_secondary_label = label

	# Botão transparente por cima: recebe clique, hover e foco de teclado.
	var hit := Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_ALL
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ring := StyleBoxFlat.new()
	ring.bg_color = Color(0, 0, 0, 0)
	ring.border_width_left = int(Design.FOCUS_RING_WIDTH)
	ring.border_width_right = int(Design.FOCUS_RING_WIDTH)
	ring.border_width_top = int(Design.FOCUS_RING_WIDTH)
	ring.border_width_bottom = int(Design.FOCUS_RING_WIDTH)
	ring.border_color = Design.FOCUS_RING_COLOR
	hit.add_theme_stylebox_override("focus", ring)
	var glow := StyleBoxFlat.new()
	glow.bg_color = Design.alpha(Design.TEXT_PRIMARY, 0.10)
	hit.add_theme_stylebox_override("hover", glow)
	if primary:
		hit.pressed.connect(func() -> void: primary_pressed.emit())
	else:
		hit.pressed.connect(func() -> void: secondary_pressed.emit())
	stack.add_child(hit)
	return stack

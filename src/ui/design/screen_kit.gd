class_name ScreenKit
extends RefCounted

## Blocos compartilhados das telas de estado (pausa, fim de run).
##
## Existe para as duas telas não duplicarem masthead, linha de estatística e
## bloco de ação. São funções estáticas puras que recebem o que precisam e
## devolvem um Control — o oposto dos "kits" de `src/arena/`, que guardam uma
## referência ao dono e acessam o estado dele por `a.` (688 vezes, medido na
## auditoria).

## Rótulo na grotesca pesada. Todas as telas de estado usam esta fonte para
## números e títulos; o mono fica com a voz de terminal.
static func grot(text: String, size: int, weight: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", Design.grotesk(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func mono(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", Design.FONT_MONO)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func gap(parent: Node, h: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(s)


static func grow_h(parent: Node) -> void:
	var g := Control.new()
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(g)


static func grow_v(parent: Node) -> void:
	var g := Control.new()
	g.size_flags_vertical = Control.SIZE_EXPAND_FILL
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(g)


static func rule(parent: Node, opacity: float = 0.22) -> void:
	var r := ColorRect.new()
	r.color = Design.alpha(Design.TEXT_PRIMARY, opacity)
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)


## Coluna raiz com as margens da página.
static func page(parent: Control) -> VBoxContainer:
	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override("margin_left", Design.SPACE_4XL)
	pad.add_theme_constant_override("margin_right", Design.SPACE_4XL)
	pad.add_theme_constant_override("margin_top", Design.SPACE_2XL)
	pad.add_theme_constant_override("margin_bottom", Design.SPACE_2XL)
	parent.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	pad.add_child(col)
	return col


## Wordmark à esquerda, etiqueta de estado à direita.
static func masthead(parent: Node, tag_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)

	var mark := VBoxContainer.new()
	mark.add_theme_constant_override("separation", -6)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.add_child(grot("KERNEL", 28, Design.WEIGHT_BLACK, Design.TEXT_PRIMARY))
	mark.add_child(grot("PANIC", 28, Design.WEIGHT_BLACK, Design.TEXT_PRIMARY))
	mark.add_child(mono(TranslationServer.translate("TAGLINE"), Design.TEXT_MICRO, Design.TEXT_MUTED))
	row.add_child(mark)

	grow_h(row)

	var tag := HBoxContainer.new()
	tag.add_theme_constant_override("separation", Design.SPACE_MD)
	tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(mono(tag_text, Design.TEXT_CAPTION, Design.TEXT_SECONDARY))
	var dash := ColorRect.new()
	dash.color = Design.alpha(Design.TEXT_PRIMARY, 0.5)
	dash.custom_minimum_size = Vector2(34, 1)
	dash.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.add_child(dash)
	row.add_child(tag)
	return row


## Linha de estatística: rótulo pequeno em cima, número grande embaixo.
## É este bloco que substitui as colunas alinhadas com espaço contado à mão.
static func stat_row(parent: Node, entries: Array, value_size: int = 46) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	fill_stats(row, entries, value_size)
	return row


static func fill_stats(row: HBoxContainer, entries: Array, value_size: int = 46) -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	for entry in entries:
		if not (entry is Array) or entry.size() < 2:
			continue
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", Design.SPACE_XS)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(mono(str(entry[0]), Design.TEXT_CAPTION, Design.TEXT_MUTED))
		cell.add_child(grot(str(entry[1]), value_size, Design.WEIGHT_BLACK, Design.TEXT_PRIMARY))
		row.add_child(cell)


## Bloco de ação.
##
## `Button` não dispõe filhos Control, então quem dimensiona é o
## PanelContainer e o Button entra por cima, transparente, só para clique,
## hover e foco de teclado. Sem isso o conteúdo fica com tamanho zero e o
## rótulo sai cortado.
##
## `emphasis`: "primary" é bloco sólido de acento (a coisa mais forte que
## existe em fundo escuro, dispensa moldura); "text" é só tipo; "danger" é só
## tipo em vermelho — o perigo vem da cor e da distância, não de uma caixa.
static func action(label: String, key: String, emphasis: String, on_press: Callable) -> PanelContainer:
	var stack := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Design.ACCENT if emphasis == "primary" else Color(0, 0, 0, 0)
	var pad_x: int = Design.SPACE_2XL if emphasis == "primary" else Design.SPACE_MD
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = Design.SPACE_LG
	sb.content_margin_bottom = Design.SPACE_LG
	stack.add_theme_stylebox_override("panel", sb)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", Design.SPACE_LG)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(line)

	var color: Color = Design.SURFACE
	if emphasis == "danger":
		color = Design.DANGER
	elif emphasis == "text":
		color = Design.TEXT_PRIMARY
	var size: int = 30 if emphasis == "primary" else 25
	var weight: int = Design.WEIGHT_HEAVY if emphasis == "primary" else Design.WEIGHT_BOLD
	line.add_child(grot(label, size, weight, color))
	if key != "":
		var key_color: Color = Design.alpha(Design.SURFACE, 0.7) if emphasis == "primary" else Design.TEXT_MUTED
		line.add_child(mono(key, Design.TEXT_CAPTION, key_color))

	var hit := Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_ALL
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ring := StyleBoxFlat.new()
	ring.bg_color = Color(0, 0, 0, 0)
	for side in ["border_width_left", "border_width_right", "border_width_top", "border_width_bottom"]:
		ring.set(side, int(Design.FOCUS_RING_WIDTH))
	ring.border_color = Design.FOCUS_RING_COLOR
	hit.add_theme_stylebox_override("focus", ring)
	var glow := StyleBoxFlat.new()
	glow.bg_color = Design.alpha(Design.TEXT_PRIMARY, 0.10)
	hit.add_theme_stylebox_override("hover", glow)
	hit.pressed.connect(on_press)
	stack.add_child(hit)
	stack.set_meta("label_node", line.get_child(0))
	stack.set_meta("hit", hit)
	return stack


## Reaperta o respiro vertical de um bloco criado por `action()`. Em janela
## estreita as ações empilham e o padding original as faz estourar a altura.
static func set_action_density(block: PanelContainer, compact: bool) -> void:
	if block == null:
		return
	var sb: StyleBoxFlat = block.get_theme_stylebox("panel")
	if sb == null:
		return
	var pad: int = Design.SPACE_SM if compact else Design.SPACE_LG
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	if block.has_meta("label_node"):
		var node: Label = block.get_meta("label_node")
		if is_instance_valid(node):
			node.add_theme_font_size_override("font_size", 20 if compact else 30)


## Troca o rótulo de um bloco criado por `action()`.
static func set_action_label(block: PanelContainer, text: String) -> void:
	if block != null and block.has_meta("label_node"):
		var node: Label = block.get_meta("label_node")
		if is_instance_valid(node):
			node.text = text

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
	bind_feedback(hit, line.get_child(0), sb if emphasis == "primary" else null)
	return stack


## O hit transparente pinta o rótulo separado. Modulação preserva a cor
## semântica quando seletores atualizam texto/cor. O anel continua no Button.
static func bind_feedback(hit: Button, label: Label, primary_surface: StyleBoxFlat = null) -> void:
	var sync := func() -> void:
		var active := hit.is_visible_in_tree() and not hit.disabled and (hit.is_hovered() or hit.has_focus())
		if primary_surface != null:
			var fill: Color = Design.ACCENT_HOT if active else Design.ACCENT
			if primary_surface.bg_color != fill:
				primary_surface.bg_color = fill
		else:
			label.self_modulate = Color.WHITE if active else Design.alpha(Color.WHITE, Design.TEXT_SECONDARY.a)
	hit.mouse_entered.connect(sync)
	hit.mouse_exited.connect(sync)
	hit.focus_entered.connect(sync)
	hit.focus_exited.connect(sync)
	hit.visibility_changed.connect(sync)
	# BaseButton redesenha ao mudar disabled; não há sinal disabled_changed.
	hit.draw.connect(sync)
	sync.call()


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


## O painel guarda uma referência fraca ao acionador: fechar o overlay devolve
## o teclado ao mesmo ponto, sem manter a cena anterior viva.
static func open_focus(panel: Control, preferred: Control = null) -> void:
	var previous := panel.get_viewport().gui_get_focus_owner()
	if previous != null and not panel.is_ancestor_of(previous):
		panel.set_meta("return_focus", weakref(previous))
	focus_first.call_deferred(panel, preferred)


static func close_focus(panel: Control) -> void:
	if not panel.has_meta("return_focus"):
		return
	var previous: Control = panel.get_meta("return_focus").get_ref()
	panel.remove_meta("return_focus")
	if is_instance_valid(previous) and previous.is_visible_in_tree():
		previous.grab_focus()


## Adiado até os containers terminarem de abrir. Não inclui scrollbar nem
## controles desabilitados: o ponto de partida deve ser uma ação utilizável.
static func focus_first(root: Control, preferred: Control = null) -> void:
	if not is_instance_valid(root) or not root.is_inside_tree() or not root.is_visible_in_tree():
		return
	if is_instance_valid(preferred) and preferred.is_visible_in_tree() and root.is_ancestor_of(preferred):
		preferred.grab_focus()
		return
	for child in root.get_children():
		if not child is Control or child.is_queued_for_deletion() or not child.is_visible_in_tree():
			continue
		if child.focus_mode == Control.FOCUS_ALL and not child is ScrollBar:
			if not child is BaseButton or not child.disabled:
				child.grab_focus()
				return
		focus_first(child)
		var focused := root.get_viewport().gui_get_focus_owner()
		if focused != null and child.is_ancestor_of(focused):
			return


## Um Control que desenha um glyph da `GlyphLib`.
##
## Existe para as telas não reimplementarem desenho de entidade: o bestiário, o
## seletor de programa e o de fase mostram as MESMAS silhuetas que a arena, e é
## esse vínculo que faz a tela ensinar reconhecimento em vez de decorar.
##
## `portrait` escolhe o ponto de entrada de retrato (tamanho grande) em vez do
## de arena. A cor sai de um meta para poder mudar sem reconstruir o nó.
static func glyph(kind: String, color: Color, px: float, portrait: bool = false) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(px, px)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.set_meta("glyph_kind", kind)
	node.set_meta("glyph_color", color)
	node.set_meta("glyph_portrait", portrait)
	node.draw.connect(func() -> void:
		var radius: float = minf(node.size.x, node.size.y) * 0.44
		var tint: Color = node.get_meta("glyph_color")
		var id: String = str(node.get_meta("glyph_kind"))
		if bool(node.get_meta("glyph_portrait")):
			GlyphLib.draw_portrait(node, id, node.size * 0.5, radius, tint)
		else:
			GlyphLib.draw_glyph(node, id, node.size * 0.5, radius, tint)
	)
	return node


static func set_glyph_tint(node: Control, color: Color) -> void:
	if node == null or not is_instance_valid(node) or not node.has_meta("glyph_color"):
		return
	node.set_meta("glyph_color", color)
	node.queue_redraw()

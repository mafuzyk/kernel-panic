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
	l.add_theme_font_size_override("font_size", Design.px(size))
	l.add_theme_color_override("font_color", color)
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func mono(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", Design.FONT_MONO)
	l.add_theme_font_size_override("font_size", Design.px(size))
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
## `scrollable` embrulha a coluna num rolável. Telas de estado com muito
## conteúdo — a pausa, depois que ganhou ajustes — não cabem em 540px de
## altura, e cortar conteúdo pela borda é pior que rolar.
static func page(parent: Control, scrollable: bool = false) -> VBoxContainer:
	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override("margin_left", Design.SPACE_4XL)
	pad.add_theme_constant_override("margin_right", Design.SPACE_4XL)
	pad.add_theme_constant_override("margin_top", Design.SPACE_2XL)
	pad.add_theme_constant_override("margin_bottom", Design.SPACE_2XL)
	parent.add_child(pad)
	var host: Node = pad
	if scrollable:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		pad.add_child(scroll)
		host = scroll
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	if scrollable:
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.add_child(col)
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
	# O respiro vai para DENTRO, num MarginContainer, em vez de ficar na
	# margem do stylebox. `PanelContainer` encolhe TODOS os filhos pela margem
	# do painel — inclusive o botão invisível que recebe o toque. O bloco
	# aparentava 67px de altura e respondia em 35: o alvo era metade do que a
	# pessoa via.
	stack.add_theme_stylebox_override("panel", sb)

	var pad_x: int = Design.SPACE_2XL if emphasis == "primary" else Design.SPACE_MD
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", pad_x)
	pad.add_theme_constant_override("margin_right", pad_x)
	pad.add_theme_constant_override("margin_top", Design.SPACE_LG)
	pad.add_theme_constant_override("margin_bottom", Design.SPACE_LG)
	stack.add_child(pad)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", Design.SPACE_LG)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(line)

	var color: Color = Design.SURFACE
	if emphasis == "danger":
		color = Design.DANGER
	elif emphasis == "text":
		color = Design.TEXT_PRIMARY
	var size: int = 26 if emphasis == "primary" else 22
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
	# Alvos touch: fileiras de ação precisam de 56px (primária) e 48px
	# (secundárias) em viewport real de telefone. Só em touch — o desktop
	# mantém a densidade editorial atual.
	# 48px para ação secundária era um segundo mínimo, mais frouxo que o que o
	# próprio projeto declara em `TOUCH_TARGET_MIN`. Não há alvo de segunda.
	# Continua valendo só no toque: no desktop a densidade editorial é outra e
	# impor altura mínima empurraria o menu para fora da janela.
	if Design.touch_input() and stack.custom_minimum_size.y < Design.target_min():
		stack.custom_minimum_size.y = Design.target_min()
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
	# O respiro mora no MarginContainer desde que o alvo de toque passou a
	# ocupar o bloco inteiro; mexer no stylebox aqui não apertava mais nada.
	var pad: int = Design.SPACE_SM if compact else Design.SPACE_LG
	for child in block.get_children():
		if child is MarginContainer:
			(child as MarginContainer).add_theme_constant_override("margin_top", pad)
			(child as MarginContainer).add_theme_constant_override("margin_bottom", pad)
	if block.has_meta("label_node"):
		var node: Label = block.get_meta("label_node")
		if is_instance_valid(node):
			node.add_theme_font_size_override("font_size", Design.px(Design.step_down(Design.TEXT_HEADING) if compact else Design.TEXT_HEADING))


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


## Linha de settings em DUAS colunas: rótulo à esquerda, valor à direita.
##
## Antes era uma frase só ("MODO DE MIRA: DRAG") alinhada à esquerda. Numa
## tela de celular isso vira uma pilha de frases soltas: não há coluna de
## valor para percorrer com o olho, e justamente o que muda ao tocar fica
## enterrado no meio da frase.
##
## A linha continua sendo um `Button` — os tipos declarados em `menu.gd` e o
## que o harness afirma seguem valendo. O texto é distribuído por
## `_set_row_text()`, que parte no separador do próprio gabarito traduzido.
static func setting_row(label: String) -> Button:
	var button := Button.new()
	# `flat` faz o Godot pular o stylebox inteiro — inclusive o fio de baixo.
	# O fundo já é transparente nos cinco estados, então não há o que esconder.
	button.flat = false
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.clip_contents = true
	button.add_theme_font_override("font", Design.FONT_MONO)
	button.add_theme_font_size_override("font_size", Design.px(Design.TEXT_SUBHEAD))
	button.add_theme_color_override("font_color", Design.TEXT_PRIMARY)
	button.add_theme_color_override("font_focus_color", Design.ACCENT)
	button.add_theme_color_override("font_pressed_color", Design.ACCENT)
	if not Platform.is_touch():
		button.add_theme_color_override("font_hover_color", Design.ACCENT)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0.0, Design.target_min())
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Design.alpha(Design.TEXT_PRIMARY, 0.05) if state == "hover" else Color(0, 0, 0, 0)
		if state == "focus":
			for side in ["border_width_left", "border_width_right", "border_width_top", "border_width_bottom"]:
				box.set(side, int(Design.FOCUS_RING_WIDTH))
			box.border_color = Design.FOCUS_RING_COLOR
		box.content_margin_left = 0
		box.content_margin_right = Design.SPACE_MD
		box.content_margin_top = Design.SPACE_SM
		box.content_margin_bottom = Design.SPACE_SM
		# Fio embaixo de cada linha: sem ele a lista lê como frases soltas no
		# vazio, que é o que a tela de celular parecia.
		box.border_color = Design.alpha(Design.TEXT_PRIMARY, 0.14)
		box.border_width_bottom = 1
		button.add_theme_stylebox_override(state, box)

	# Os dois ocupam a linha inteira e se separam pelo ALINHAMENTO. Ancorar o
	# valor com `PRESET_RIGHT_WIDE` dava uma faixa de largura zero colada na
	# borda, e a coluna de valor simplesmente não aparecia.
	var name_label := ScreenKit.mono("", Design.TEXT_SUBHEAD, Design.TEXT_PRIMARY)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(name_label)
	var value_label := ScreenKit.mono("", Design.TEXT_SUBHEAD, Design.ACCENT)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	value_label.offset_right = -float(Design.SPACE_MD)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(value_label)
	button.set_meta(ROW_NAME_META, name_label)
	button.set_meta(ROW_VALUE_META, value_label)
	set_row_text(button, label)
	return button


const ROW_RULED_META := "kp_row_ruled"
const ROW_NAME_META := "kp_row_name"
const ROW_VALUE_META := "kp_row_value"


## Distribui "RÓTULO: VALOR" nas duas colunas da linha.
##
## O corte é no ÚLTIMO separador da frase traduzida, não numa posição fixa:
## os gabaritos do CSV usam ":" e "//", e as duas línguas põem o valor no fim.
## Sem separador, a frase inteira é rótulo — é o caso dos textos de ação.
static func split_row_text(text: String) -> Array:
	var cut := -1
	for sep in [": ", " // "]:
		cut = maxi(cut, text.rfind(sep))
	if cut < 0:
		return [text, ""]
	var sep_len := 2 if text.substr(cut, 2) == ": " else 4
	return [text.substr(0, cut).strip_edges(), text.substr(cut + sep_len).strip_edges()]


static func set_row_text(button: Button, text: String) -> void:
	if button == null or not button.has_meta(ROW_NAME_META):
		button.text = text
		return
	var parts := split_row_text(text)
	var name_label: Label = button.get_meta(ROW_NAME_META)
	var value_label: Label = button.get_meta(ROW_VALUE_META)
	if is_instance_valid(name_label):
		name_label.text = str(parts[0])
	if is_instance_valid(value_label):
		value_label.text = str(parts[1])













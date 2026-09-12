class_name ProgramPanel
extends Control

## Seleção de programa na direção editorial.
##
## Porte de 2026-09-12. A versão anterior era `_draw()` puro: cada card era uma
## moldura de canto cortado desenhada com offset absoluto de um palco de
## 1280x720 (`origin + Vector2(90.0, 38.0)`), Orbitron 17 para o nome, mono 9-13
## para todo o resto, e a cor de identidade do programa pintava moldura, fundo,
## régua, rodapé e texto ao mesmo tempo — três cards, três cores, arco-íris.
## Nenhum token de `Design` era usado além da dica de rolagem.
##
## O que mudou, e por quê:
##
## - Container no lugar de offset. Nada aqui sabe o tamanho da tela.
## - Escala de tipo real: o nome do programa na grotesca pesada lidera, o mono
##   fica com o papel de rótulo de terminal. Antes tudo tinha o mesmo peso, e
##   sem hierarquia o olho não sabe onde entrar.
## - A cor de identidade desceu a MARCADOR: glyph, sobrolho e uma régua fina.
##   Ela não some porque é informação — o ciano do KERNEL aqui é o ciano do
##   KERNEL na arena, e é assim que a tela ensina reconhecimento. Mas o texto
##   voltou para tinta neutra.
## - Seleção deixou de ser "mais uma moldura por cima": é a barra sólida na
##   borda esquerda do card, um estado só, legível de longe.
##
## O cabeçalho é DESTA tela. Antes o título e o subtítulo eram dois Labels
## injetados por `menu.gd` com Orbitron cru e offset fixo, então nem o topo da
## tela pertencia ao arquivo que a desenhava.

signal selection_changed(id: String)
signal boot_pressed
signal back_pressed

## Altura mínima de um card. Abaixo disto as cinco linhas de estatística
## começam a brigar com o resumo.
const CARD_MIN_HEIGHT := 300.0
const MARK_SIZE := 54.0

var scroll_y := 0.0
var _card_rects: Dictionary = {}

var _title: Label
var _subtitle: Label
var _scroll: ScrollContainer
var _grid: GridContainer
var _footer: BoxContainer
var _boot_block: PanelContainer
var _back_block: PanelContainer
var _hint: Label
var _cards: Dictionary = {}
var _columns_applied := 0


func _ready() -> void:
	theme = UiTheme.shared()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_apply_layout_mode()


# ── contrato de conteúdo ──────────────────────────────────────────────

func title_text() -> String:
	return tr("PROGRAM_TITLE")


## Exposto para o autotest afirmar que a tela usa a ponta alta da escala, que é
## o que separa esta linguagem da antiga (Orbitron 17 para tudo).
func title_font_size() -> int:
	return Design.TEXT_HEADING if Design.breakpoint_for(size.x) == "compact" else Design.TEXT_TITLE


## Papéis de tinta de um card. A cor de identidade aparece SÓ em "marker".
func card_ink(id: String) -> Dictionary:
	var definition: Dictionary = Game.PROGRAM_DEFS.get(id, {})
	var visual: Dictionary = definition.get("visual", {})
	var identity: Color = visual.get("color", Design.ACCENT)
	var unlocked := Game.unlocked_programs.has(id)
	var selected := Game.program == id and unlocked
	var status: Color = Design.TEXT_MUTED
	if not unlocked:
		status = Design.DANGER
	elif selected:
		status = identity
	return {
		"title": Design.TEXT_PRIMARY if unlocked else Design.TEXT_FAINT,
		"marker": identity,
		"body": Design.TEXT_SECONDARY if unlocked else Design.TEXT_GHOST,
		"label": Design.TEXT_MUTED if unlocked else Design.TEXT_GHOST,
		"status": status,
	}


## Mantido da versão anterior: `menu.gd` não usa, mas o harness afirma que a
## cor do card acompanha a seleção.
func card_accent(id: String) -> Color:
	var definition: Dictionary = Game.PROGRAM_DEFS.get(id, {})
	var visual: Dictionary = definition.get("visual", {})
	var accent: Color = visual.get("color", Design.ACCENT)
	if Game.program == id and Game.unlocked_programs.has(id):
		return accent
	return Design.alpha(accent, 0.46)


func available_program_ids() -> Array:
	var ids: Array = []
	for raw_id in Game.PROGRAM_DEFS.keys():
		var id := str(raw_id)
		if Game.unlocked_programs.has(id):
			ids.append(id)
	return ids


func select_program(id: String) -> bool:
	if not Game.PROGRAM_DEFS.has(id) or not Game.unlocked_programs.has(id):
		return false
	Game.set_program(id)
	selection_changed.emit(id)
	_refresh_cards()
	return true


## Dica de rolagem conforme o dispositivo. Era "SWIPE TO SCROLL" fixa, o que
## vazava no build de desktop (B7).
func scroll_hint_text() -> String:
	return Design.scroll_hint(Design.touch_input())


## Silhuetas que esta tela mostra. Exposto para o autotest afirmar que cada uma
## é um tipo que a `GlyphLib` sabe desenhar — antes isso era verificado
## procurando a string "GlyphLib.draw_" no código-fonte do painel, o que
## quebrava ao mover o desenho para um construtor compartilhado sem que nada
## tivesse regredido.
func glyph_kinds() -> Array[String]:
	var out: Array[String] = []
	for raw_id in Game.PROGRAM_DEFS.keys():
		out.append(str(raw_id))
	return out


# ── geometria consumida pelo autotest ─────────────────────────────────

## Retângulos do conteúdo que NÃO rola. O conteúdo rolável é representado pela
## janela de rolagem, não pelos cards: um card cortado pela janela é o
## comportamento esperado, não transbordamento.
func content_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for node in [_title, _subtitle, _scroll, _boot_block, _back_block, _footer]:
		if node != null and is_instance_valid(node) and node.is_visible_in_tree():
			out.append(Rect2(node.global_position, node.size))
	return out


func content_viewport_rect() -> Rect2:
	if is_instance_valid(_scroll):
		return Rect2(_scroll.global_position - global_position, _scroll.size)
	return Rect2()


func visible_card_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	var viewport := content_viewport_rect()
	for raw_rect in _card_rects.values():
		var rect: Rect2 = raw_rect
		if viewport.encloses(rect):
			result.append(rect)
	return result


func _card_metrics() -> Dictionary:
	var cols := _column_count()
	# As margens de página vêm de `ScreenKit.page()`, que usa SPACE_4XL dos dois
	# lados. Duplicar o número aqui com outro valor daria um card_w que não
	# corresponde ao card real, e o relatório de transbordamento mediria ficção.
	var pad: float = float(Design.SPACE_4XL) * 2.0
	var gap := float(Design.SPACE_XL)
	var card_w: float = maxf((size.x - pad - gap * float(cols - 1)) / float(cols), 120.0)
	return {"cols": cols, "gap": gap, "card_w": card_w}


## Abaixo disto a linha de estatística vira pilha.
const STAT_STACK_BELOW := 320.0


func _stats_are_stacked() -> bool:
	return float(_card_metrics().get("card_w", 300.0)) < STAT_STACK_BELOW


func _column_count() -> int:
	if size.x >= Design.BP_MEDIUM:
		return 3
	if size.x >= Design.BP_COMPACT:
		return 2
	return 1


## Os retângulos vêm dos nós vivos, não de aritmética paralela. Recalcular três
## Rect2 por quadro é barato; o custo da versão anterior era o `queue_redraw()`
## que ela disparava junto, redesenhando um menu estático a 60fps.
func _process(_delta: float) -> void:
	if not visible:
		return
	_sync_card_rects()
	_sync_scroll_hint()
	_stretch_grid()
	if is_instance_valid(_scroll):
		scroll_y = float(_scroll.scroll_vertical)


## A dica de rolagem só aparece quando existe rolagem. A versão anterior a
## desenhava junto com a barra, mas em janela estreita a barra sumia e a dica
## ficava — texto ensinando um gesto que não fazia nada.
func _sync_scroll_hint() -> void:
	if not is_instance_valid(_hint) or not is_instance_valid(_scroll):
		return
	var bar := _scroll.get_v_scroll_bar()
	var scrollable := bar != null and bar.max_value > bar.page
	# Só em tela larga. A 720 a dica soma ~130px a um rodapé que já ocupa
	# ~494px de uma coluna de 592, e empurra o bloco de ação para fora.
	_hint.visible = scrollable and Design.breakpoint_for(size.x) in ["wide", "ultra"]


## Um ScrollContainer dimensiona o filho pela altura MÍNIMA dele, então três
## cards de 300px deixavam ~120px de vazio abaixo em tela de 720. Elevar o piso
## do grid para a altura da janela faz os cards esticarem; quando o conteúdo é
## mais alto que a janela o piso não tem efeito (o mínimo efetivo é o maior dos
## dois) e a rolagem continua funcionando.
func _stretch_grid() -> void:
	if not is_instance_valid(_grid) or not is_instance_valid(_scroll):
		return
	if absf(_grid.custom_minimum_size.y - _scroll.size.y) > 1.0:
		_grid.custom_minimum_size.y = _scroll.size.y


func _sync_card_rects() -> void:
	for raw_id in _cards:
		var card: Control = _cards[raw_id]
		if is_instance_valid(card):
			_card_rects[str(raw_id)] = Rect2(card.global_position - global_position, card.size)


# ── entrada ───────────────────────────────────────────────────────────

## O clique real chega pelo Button transparente de cada card. Este caminho
## existe para arrasto (rolagem por toque) e porque o harness injeta eventos
## direto no painel, sem passar pela árvore de foco.
var _dragging := false
var _press_position := Vector2.ZERO
var _drag_start_y := 0.0
var _scroll_start := 0.0


func _scroll_to(value: float) -> void:
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(maxf(value, 0.0))
		scroll_y = float(_scroll.scroll_vertical)
	_sync_card_rects()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_scroll_to(scroll_y - 80.0)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_scroll_to(scroll_y + 80.0)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_press_position = event.position
				_drag_start_y = event.position.y
				_scroll_start = scroll_y
			else:
				if _dragging and event.position.distance_to(_press_position) < 14.0:
					_select_at(event.position)
				_dragging = false
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_scroll_to(_scroll_start - (event.position.y - _drag_start_y))
		accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_dragging = true
			_press_position = event.position
			_drag_start_y = event.position.y
			_scroll_start = scroll_y
		else:
			if _dragging and event.position.distance_to(_press_position) < 18.0:
				_select_at(event.position)
			_dragging = false
		accept_event()
	elif event is InputEventScreenDrag and _dragging:
		_scroll_to(_scroll_start - (event.position.y - _drag_start_y))
		accept_event()


## ENTER sem foco mantém o atalho de boot. Com foco, o Button seleciona no
## release; o press pode chegar aqui também e não deve iniciar uma run.
func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	if get_viewport().gui_get_focus_owner() != null:
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		boot_pressed.emit()
		get_viewport().set_input_as_handled()


func _select_at(position: Vector2) -> void:
	_sync_card_rects()
	for raw_id in _card_rects:
		var id := str(raw_id)
		var rect: Rect2 = _card_rects[id]
		if rect.has_point(position):
			if select_program(id):
				Sfx.play("ui", 1.05, -8.0)
			return


# ── construção ────────────────────────────────────────────────────────

func _build() -> void:
	var ground := ColorRect.new()
	ground.color = Design.SURFACE
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)

	var col := ScreenKit.page(self)
	# Sem masthead. O wordmark KERNEL/PANIC pertence ao menu e às interrupções
	# de jogo (pausa, fim de run), onde reancorar faz sentido. Numa subtela
	# alcançada A PARTIR do menu ele é repetição que custa ~79px de altura — e
	# era esse o custo que empurrava o detalhe para fora da tela a 720.
	ScreenKit.gap(col, Design.SPACE_LG)

	_title = ScreenKit.grot(title_text(), Design.TEXT_TITLE, Design.WEIGHT_BLACK, Design.TEXT_PRIMARY)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(_title)
	_subtitle = ScreenKit.mono(tr("PROGRAM_SUBTITLE"), Design.TEXT_CAPTION, Design.TEXT_SECONDARY)
	col.add_child(_subtitle)

	ScreenKit.gap(col, Design.SPACE_XL)
	ScreenKit.rule(col)
	ScreenKit.gap(col, Design.SPACE_XL)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_scroll)

	_grid = GridContainer.new()
	_grid.columns = _column_count()
	_grid.add_theme_constant_override("h_separation", Design.SPACE_XL)
	_grid.add_theme_constant_override("v_separation", Design.SPACE_XL)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_grid)

	for raw_id in Game.PROGRAM_DEFS.keys():
		var id := str(raw_id)
		var card := _make_card(id)
		_cards[id] = card
		_grid.add_child(card)

	ScreenKit.gap(col, Design.SPACE_XL)
	ScreenKit.rule(col)
	ScreenKit.gap(col, Design.SPACE_MD)
	_build_footer(col)


func _build_footer(parent: Node) -> void:
	# BoxContainer e não HBox: em janela estreita as duas ações empilham. Lado a
	# lado elas somam ~434px, e a coluna de página a 432 tem 304.
	_footer = BoxContainer.new()
	_footer.add_theme_constant_override("separation", Design.SPACE_XL)
	parent.add_child(_footer)

	_boot_block = ScreenKit.action(_boot_label(), "[ENTER]", "primary",
		func() -> void: boot_pressed.emit())
	_footer.add_child(_boot_block)

	_back_block = ScreenKit.action(tr("UI_BACK"), "[ESC]", "text",
		func() -> void: back_pressed.emit())
	_footer.add_child(_back_block)

	ScreenKit.grow_h(_footer)

	_hint = ScreenKit.mono(scroll_hint_text(), Design.TEXT_MICRO, Design.TEXT_FAINT)
	_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_footer.add_child(_hint)


func _boot_label() -> String:
	var definition: Dictionary = Game.PROGRAM_DEFS.get(Game.program, {})
	return tr("PROGRAM_BOOT").format([str(definition.get("name", "KERNEL"))])


## Um card. Sem moldura: o card É uma superfície, e a única coisa que muda de
## forma entre os estados é a barra de identidade na borda esquerda.
func _make_card(id: String) -> PanelContainer:
	var definition: Dictionary = Game.PROGRAM_DEFS.get(id, {})
	var visual: Dictionary = definition.get("visual", {})
	var identity: Color = visual.get("color", Design.ACCENT)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0.0, CARD_MIN_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", Design.SPACE_XL)
	pad.add_theme_constant_override("margin_right", Design.SPACE_XL)
	pad.add_theme_constant_override("margin_top", Design.SPACE_LG)
	pad.add_theme_constant_override("margin_bottom", Design.SPACE_LG)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", Design.SPACE_MD)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)

	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", Design.SPACE_XS)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(names)

	var role := ScreenKit.mono(_content(id, "role", "PROGRAM_ROLE_%s" % id.to_upper()), Design.TEXT_MICRO, identity)
	names.add_child(role)
	var name_label := ScreenKit.grot(str(definition.get("name", id.to_upper())), 30,
		Design.WEIGHT_BLACK, Design.TEXT_PRIMARY)
	names.add_child(name_label)

	var mark := ScreenKit.glyph(id, identity, MARK_SIZE, true)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(mark)

	ScreenKit.gap(col, Design.SPACE_MD)

	var summary := ScreenKit.mono(_content(id, "summary", "PROGRAM_SUMMARY_%s" % id.to_upper()), Design.TEXT_CAPTION,
		Design.TEXT_SECONDARY)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(summary)

	ScreenKit.gap(col, Design.SPACE_MD)

	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", Design.SPACE_SM)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(stats)
	var stat_lines: Array[BoxContainer] = []
	for spec in _stat_specs():
		stat_lines.append(_stat_line(stats, tr(str(spec[0])),
			_content(id, str(spec[1]), _value_key(id, str(spec[1])))))

	ScreenKit.grow_v(col)
	ScreenKit.gap(col, Design.SPACE_MD)

	# A régua na cor de identidade é o segundo marcador. Uma linha de 1px
	# carrega a cor sem que ela vire a moldura da versão anterior.
	var mark_rule := ColorRect.new()
	mark_rule.color = Design.alpha(identity, 0.55)
	mark_rule.custom_minimum_size = Vector2(0, 1)
	mark_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(mark_rule)

	ScreenKit.gap(col, Design.SPACE_MD)

	var tradeoff := ScreenKit.mono(_tradeoff(id), Design.TEXT_MICRO, Design.TEXT_FAINT)
	tradeoff.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(tradeoff)

	ScreenKit.gap(col, Design.SPACE_SM)
	var status := ScreenKit.mono("", Design.TEXT_MICRO, Design.TEXT_MUTED)
	col.add_child(status)

	# `Button` não dispõe filhos Control: ele entra por cima, transparente, só
	# para clique, hover e foco de teclado.
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
	glow.bg_color = Design.alpha(Design.TEXT_PRIMARY, 0.06)
	hit.add_theme_stylebox_override("hover", glow)
	hit.pressed.connect(func() -> void:
		if select_program(id):
			Sfx.play("ui", 1.05, -8.0)
	)
	card.add_child(hit)
	ScreenKit.bind_feedback(hit, name_label)

	card.set_meta("stats", stat_lines)
	card.set_meta("prose", [summary, tradeoff])
	card.set_meta("status", status)
	card.set_meta("name", name_label)
	card.set_meta("summary", summary)
	card.set_meta("role", role)
	card.set_meta("mark", mark)
	card.set_meta("hit", hit)
	_apply_card_state(id, card)
	return card


static func _stat_specs() -> Array:
	return [
		["PROGRAM_INTEGRITY", "integrity"],
		["PROGRAM_SPEED", "speed"],
		["PROGRAM_FIRE", "fire"],
		["PROGRAM_RANGE", "range"],
		["PROGRAM_CORE", "dash_shield"],
	]


## Uma linha de estatística.
##
## `BoxContainer` e não `HBoxContainer` porque em card estreito ela VIRA pilha:
## rótulo em cima, valor embaixo. Em duas colunas a 720px o card tem 236px
## úteis e "DASH // CORE" + "2 DASH // KILL RECHARGE" somam 264px — a linha
## horizontal não cabe, e encolher a fonte seria repetir o erro que levou o
## bestiário a 9px.
func _stat_line(parent: Node, label: String, value: String) -> BoxContainer:
	var line := BoxContainer.new()
	line.add_theme_constant_override("separation", Design.SPACE_MD)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)
	line.add_child(ScreenKit.mono(label, Design.TEXT_MICRO, Design.TEXT_MUTED))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(spacer)
	var value_label := ScreenKit.mono(value, Design.TEXT_CAPTION, Design.TEXT_PRIMARY)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(value_label)
	line.set_meta("value", value_label)
	return line


## Texto de conteúdo localizado, com queda para o valor em inglês de
## `Game.PROGRAM_DEFS`.
##
## O dicionário continua sendo a fonte: outros lugares leem dele, e um programa
## novo aparece na tela mesmo sem chave no CSV. Uma chave ausente volta como a
## própria chave — é esse o sinal de queda.
##
## Os VALORES perderam o substantivo repetido no caminho: "100% MOVE" virou
## "100%", "MEDIUM RANGE" virou "MEDIUM". O rótulo da linha já diz o eixo, e
## repeti-lo era o que fazia a linha não caber em card de duas colunas.
func _content(id: String, field: String, key: String) -> String:
	var definition: Dictionary = Game.PROGRAM_DEFS.get(id, {})
	var fallback := str(definition.get(field, ""))
	var translated := tr(key)
	return fallback if translated == key else translated


func _value_key(id: String, field: String) -> String:
	return "PROGRAM_VALUE_%s_%s" % [id.to_upper(), field.to_upper()]


func _tradeoff(id: String) -> String:
	match id:
		"kernel": return tr("PROGRAM_TRADEOFF_KERNEL")
		"daemon": return tr("PROGRAM_TRADEOFF_DAEMON")
		"rootlet": return tr("PROGRAM_TRADEOFF_ROOTLET")
		_: return tr("PROGRAM_TRADEOFF_GENERIC")


func _refresh_cards() -> void:
	for raw_id in _cards:
		_apply_card_state(str(raw_id), _cards[raw_id])
	if is_instance_valid(_boot_block):
		ScreenKit.set_action_label(_boot_block, _boot_label())


## Um estado visual por card, e ele muda a SUPERFÍCIE, não adiciona camada.
func _apply_card_state(id: String, card: PanelContainer) -> void:
	if card == null or not is_instance_valid(card):
		return
	var ink: Dictionary = card_ink(id)
	var unlocked := Game.unlocked_programs.has(id)
	var selected := Game.program == id and unlocked

	var box := StyleBoxFlat.new()
	box.bg_color = Design.SURFACE_RAISED if selected else Design.SURFACE_SUNKEN
	box.border_width_left = int(Design.STROKE_THICK) if selected else 0
	box.border_color = ink.get("marker", Design.ACCENT)
	card.add_theme_stylebox_override("panel", box)

	var status_text := tr("PROGRAM_SELECTED")
	if not unlocked:
		status_text = tr("PROGRAM_LOCKED")
	elif not selected:
		status_text = tr("PROGRAM_READY")
	_tint(card, "status", ink.get("status", Design.TEXT_MUTED), status_text)
	_tint(card, "name", ink.get("title", Design.TEXT_PRIMARY), "")
	_tint(card, "summary", ink.get("body", Design.TEXT_SECONDARY), "")
	_tint(card, "role", ink.get("marker", Design.ACCENT) if unlocked else Design.TEXT_GHOST, "")
	if card.has_meta("mark"):
		ScreenKit.set_glyph_tint(card.get_meta("mark"),
			ink.get("marker", Design.ACCENT) if unlocked else Design.TEXT_GHOST)


func _tint(card: PanelContainer, key: String, color: Color, text: String) -> void:
	if not card.has_meta(key):
		return
	var label: Label = card.get_meta(key)
	if not is_instance_valid(label):
		return
	label.add_theme_color_override("font_color", color)
	if text != "":
		label.text = text


# ── modo de layout ────────────────────────────────────────────────────

func _apply_layout_mode() -> void:
	if not is_instance_valid(_title):
		return
	var compact := Design.breakpoint_for(size.x) == "compact"
	_title.add_theme_font_size_override("font_size", title_font_size())
	_subtitle.visible = not compact
	if is_instance_valid(_hint):
		_hint.text = scroll_hint_text()
		_sync_scroll_hint()
	for block in [_boot_block, _back_block]:
		ScreenKit.set_action_density(block, compact)
	if is_instance_valid(_footer):
		_footer.vertical = compact
		_footer.add_theme_constant_override("separation",
			Design.SPACE_SM if compact else Design.SPACE_XL)
	var cols := _column_count()
	if is_instance_valid(_grid) and cols != _columns_applied:
		_grid.columns = cols
		_columns_applied = cols
	var stacked := _stats_are_stacked()
	# Card estreito perde a prosa. Com 284px de largura o resumo quebra em três
	# linhas e as estatísticas empilham em dez: o card passa de 410px e fica
	# mais alto que a janela de rolagem, então o ÚLTIMO card nunca é visto por
	# inteiro. Nome, papel, silhueta, as cinco estatísticas e o estado seguem
	# todos lá — some o que é secundário.
	for raw_id in _cards:
		var dense_card: PanelContainer = _cards[raw_id]
		if is_instance_valid(dense_card) and dense_card.has_meta("prose"):
			for node in dense_card.get_meta("prose"):
				var prose: Control = node
				if is_instance_valid(prose):
					prose.visible = not stacked
	for raw_id in _cards:
		var card: PanelContainer = _cards[raw_id]
		if not is_instance_valid(card) or not card.has_meta("stats"):
			continue
		for line in card.get_meta("stats"):
			var box: BoxContainer = line
			if not is_instance_valid(box):
				continue
			box.vertical = stacked
			box.add_theme_constant_override("separation", Design.SPACE_XS if stacked else Design.SPACE_MD)
			if box.has_meta("value"):
				var value_label: Label = box.get_meta("value")
				if is_instance_valid(value_label):
					value_label.horizontal_alignment = \
						HORIZONTAL_ALIGNMENT_LEFT if stacked else HORIZONTAL_ALIGNMENT_RIGHT


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_layout_mode()


# ── relatório de transbordamento ──────────────────────────────────────

## Com container e autowrap o texto corrido não transborda por construção. O
## que ainda pode estourar é um VALOR de estatística, que não quebra linha:
## é isso que este relatório mede.
func text_overflow_report() -> Array:
	var mono: Font = Design.FONT_MONO
	var card_w: float = float(_card_metrics().get("card_w", 300.0))
	var inner: float = card_w - float(Design.SPACE_XL) * 2.0
	var longest_value := ""
	var longest_label := ""
	for raw_id in Game.PROGRAM_DEFS:
		var id := str(raw_id)
		for spec in _stat_specs():
			var value := _content(id, str(spec[1]), _value_key(id, str(spec[1])))
			if value.length() > longest_value.length():
				longest_value = value
			var label := tr(str(spec[0]))
			if label.length() > longest_label.length():
				longest_label = label
	var value_w: float = mono.get_string_size(longest_value, HORIZONTAL_ALIGNMENT_LEFT, -1, Design.TEXT_CAPTION).x
	var label_w: float = mono.get_string_size(longest_label, HORIZONTAL_ALIGNMENT_LEFT, -1, Design.TEXT_MICRO).x
	var out: Array = []
	# Empilhada, só o valor precisa caber; lado a lado, rótulo + valor.
	var needed: float = value_w if _stats_are_stacked() else label_w + value_w + float(Design.SPACE_MD)
	out.append({"id": "program_stat_row", "fits": needed <= inner})
	out.append({"id": "program_boot_action",
		"fits": Design.grotesk(Design.WEIGHT_HEAVY).get_string_size(
			_boot_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x <= size.x * 0.6})
	return out

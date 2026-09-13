class_name MenuShell
extends Control

## Shell do menu principal na direção editorial aprovada em 2026-09-11.
##
## Substitui a pilha centralizada que `MenuChromeKit.apply_menu_layout()`
## posicionava por retângulos absolutos (title, klog, subtitle, controls, best,
## mode_info, button_row, purge, story, mode, program, diff).
##
## Só o shell: os overlays (settings, bestiário, story, programas, conquistas)
## continuam sendo de `menu.gd`. Este nó não os conhece — emite sinal e o menu
## decide o que abrir.
##
## O herói é desenhado em código (`GlyphLib`), não raster: em tamanho grande o
## vetor escala melhor, e mantém a arena e o menu mostrando a MESMA silhueta.

signal purge_pressed
signal story_pressed
signal archives_pressed
signal configure_pressed
signal settings_pressed
signal awards_pressed
signal quit_pressed
signal mode_cycled
signal difficulty_cycled

const HERO_RADIUS_WIDE := 120.0
const HERO_RADIUS_COMPACT := 90.0

var _hero: Control
var _purge_label: Label
var _mode_label: Label
var _best_label: Label
var _program_label: Label
var _version_label: Label
var _story_block: PanelContainer
var _archives_block: PanelContainer
var _mode_block: PanelContainer
var _diff_block: PanelContainer
var _cfg_row: BoxContainer
var _swap_hit: Button
var _swap_link: Control
var _footer_hosts: Array = []
var _purge_host: PanelContainer
var _body: BoxContainer
var _hero_wrap: Control
var _footer_row: BoxContainer
var _masthead_row: HBoxContainer
var _hero_kind := "kernel"
var _hero_color := Design.ACCENT


func _ready() -> void:
	theme = UiTheme.shared()
	# TOP_LEFT, não FULL_RECT: o tamanho vem de `_resize_to_viewport` (pronto +
	# size_changed). Com FULL_RECT, cada `size = vp` logava WARNING de anchors
	# opostos — e o teste de contenção também seta `shell.size` direto.
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_resize_to_viewport()
	get_viewport().size_changed.connect(_resize_to_viewport)
	_build()
	ScreenKit.focus_first.call_deferred(self)


func _resize_to_viewport() -> void:
	var vp := get_viewport_rect().size
	if vp.x > 0.0 and vp.y > 0.0:
		size = vp
	_apply_layout_mode()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_layout_mode()


## Empilha o herói acima do conteúdo em janela estreita e encolhe o tipo. Sem
## isto o PURGE de 118px e a arte lado a lado transbordam abaixo de ~1100px.
func _apply_layout_mode() -> void:
	if not is_instance_valid(_body) or not is_instance_valid(_purge_label):
		return
	var step := Design.breakpoint_for(size.x)
	var compact := step == "compact" or step == "medium"
	_body.vertical = compact
	_purge_label.add_theme_font_size_override("font_size", 32 if compact else 54)
	if is_instance_valid(_hero_wrap):
		var r: float = HERO_RADIUS_COMPACT if compact else HERO_RADIUS_WIDE
		_hero_wrap.custom_minimum_size = Vector2(r * 2.2, r * 2.2)
		# Em modo empilhado o herói come a altura que o conteúdo precisa —
		# 1024x640 transbordava com ele visível.
		_hero_wrap.visible = not compact
	if is_instance_valid(_cfg_row):
		# Lado a lado no wide; empilhadas no compacto, onde meia largura
		# cortaria "DIFICULDADE: CURVA FIXA".
		_cfg_row.vertical = compact
	for block in [_story_block, _archives_block, _mode_block, _diff_block]:
		ScreenKit.set_action_density(block, compact)
	# Em janela baixa o masthead é 110px de decoração que não cabe — mesma
	# decisão tomada na pausa.
	if is_instance_valid(_masthead_row):
		_masthead_row.visible = size.y > 700.0
	# Invalidação explícita: trocar densidade/tipo/vertical muda mínimos, e a
	# cadeia ancestral precisa resortear com os novos valores (sem isto, um
	# resize para viewport estreita mantinha a largura do modo anterior).
	if is_instance_valid(_body):
		_body.update_minimum_size()
	if is_instance_valid(_cfg_row):
		_cfg_row.update_minimum_size()
	# O rodapé horizontal tem mínimo de ~400px (ENTER + 3 links): no compacto
	# ele sozinho forçava a coluna inteira para fora de 432. Empilhado, o
	# mínimo cai para a largura do maior link.
	if is_instance_valid(_footer_row):
		_footer_row.vertical = compact
		_footer_row.update_minimum_size()
	if is_instance_valid(_body):
		_body.queue_sort()


# ── estado vindo do menu ──────────────────────────────────────────────

func set_run_config(mode_text: String, best_text: String, program_name: String) -> void:
	_mode_label.text = mode_text
	_best_label.text = best_text
	_program_label.text = program_name


## Rótulos das fileiras de MODE/DIFFICULTY, atualizados a cada refresh do menu.
func set_cycle_labels(mode_text: String, diff_text: String) -> void:
	ScreenKit.set_action_label(_mode_block, mode_text)
	ScreenKit.set_action_label(_diff_block, diff_text)


## Controles reais de run config, para o autotest acionar os mesmos botões
## que mouse e teclado alcançam.
func run_config_hits() -> Dictionary:
	return {
		"mode": _mode_block.get_meta("hit") if _mode_block != null else null,
		"difficulty": _diff_block.get_meta("hit") if _diff_block != null else null,
	}


## Botão de trocar programa (o link MENU_SWAP), para navegação por teclado.
func swap_hit() -> Button:
	if _swap_link != null and _swap_link.get_child_count() > 1 and _swap_link.get_child(1) is Button:
		return _swap_link.get_child(1)
	return null


## Células do rodapé (hosts com o botão de overlay como filho 1).
func footer_hosts() -> Array:
	return _footer_hosts


## Retângulo global do hit do PURGE. Por construção o hit cobre o host
## inteiro (FULL_RECT), então o host é a medida estável do anel — válida
## mesmo antes do primeiro sort headless do botão.
func primary_hit_rect() -> Rect2:
	if _purge_host != null and is_instance_valid(_purge_host):
		return _purge_host.get_global_rect()
	return Rect2()


## Foco inicial da navegação por teclado do menu.
func focus_primary() -> void:
	if _purge_host != null and _purge_host.has_meta("hit"):
		var hit: Button = _purge_host.get_meta("hit")
		if is_instance_valid(hit):
			hit.grab_focus()


func set_version(text: String) -> void:
	_version_label.text = text


## Qual programa desenhar como herói, e em que cor.
func set_hero(kind: String, color: Color) -> void:
	_hero_kind = kind
	_hero_color = color
	if is_instance_valid(_hero):
		_hero.queue_redraw()


## Semântica da tela, consumida pelo autotest. Mantém o contrato antigo: o que
## importa é que o shell exponha título, ação primária e as rotas — não onde
## cada retângulo cai.
func shell_snapshot() -> Dictionary:
	return {
		"title": "KERNEL PANIC",
		"primary_action": _purge_label.text if is_instance_valid(_purge_label) else tr("MENU_PURGE"),
		"mode_explanation": _mode_label.text if is_instance_valid(_mode_label) else "",
		"routes": ["PROGRAM", "STORY", "BESTIARY"],
		"primary_rect": Rect2(_purge_label.global_position, _purge_label.size) if is_instance_valid(_purge_label) else Rect2(),
		"score_rect": Rect2(_best_label.global_position, _best_label.size) if is_instance_valid(_best_label) else Rect2(),
	}


## Retângulos de tudo que é interativo ou textual, para o autotest afirmar
## contenção sem depender de um dicionário de layout absoluto.
func content_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	# O rodapé PRECISA estar aqui: sem ele a asserção de contenção passava com
	# "ENTER Start" e os botões de rodapé cortados pela borda inferior.
	for node in [_purge_label, _mode_label, _best_label, _program_label,
			_version_label, _mode_block, _diff_block, _story_block, _archives_block, _footer_row]:
		# is_visible_in_tree, não `visible`: um filho de container escondido mantém
		# `visible == true` e entrava na medição, acusando estouro falso.
		if node != null and is_instance_valid(node) and node.is_visible_in_tree():
			out.append(Rect2(node.global_position, node.size))
	return out


# ── construção ────────────────────────────────────────────────────────

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Design.SURFACE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var col := ScreenKit.page(self)
	_masthead_row = _build_masthead(col)
	ScreenKit.gap(col, Design.SPACE_LG)

	_body = BoxContainer.new()
	_body.add_theme_constant_override("separation", Design.SPACE_3XL)
	# SHRINK_CENTER, não EXPAND_FILL: expandindo, o corpo empurrava o rodapé
	# para fora da tela e o bloco de programa ativo saía cortado embaixo.
	_body.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(_body)
	_build_hero(_body)
	_build_actions(_body)

	ScreenKit.grow_v(col)
	_build_footer(col)
	_apply_layout_mode()


func _build_masthead(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)

	var mark := VBoxContainer.new()
	mark.add_theme_constant_override("separation", -8)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.add_child(ScreenKit.grot("KERNEL", 26, Design.WEIGHT_BLACK, Design.TEXT_PRIMARY))
	mark.add_child(ScreenKit.grot("PANIC", 26, Design.WEIGHT_BLACK, Design.TEXT_PRIMARY))
	mark.add_child(ScreenKit.mono(tr("TAGLINE"), Design.TEXT_MICRO, Design.TEXT_MUTED))
	row.add_child(mark)

	ScreenKit.grow_h(row)
	_version_label = ScreenKit.mono("", Design.TEXT_CAPTION, Design.TEXT_MUTED)
	_version_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_version_label)
	return row


func _build_hero(parent: Node) -> void:
	_hero_wrap = Control.new()
	_hero_wrap.custom_minimum_size = Vector2(HERO_RADIUS_WIDE * 2.2, HERO_RADIUS_WIDE * 2.2)
	_hero_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hero_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_hero_wrap)

	_hero = _HeroArt.new()
	_hero.shell = self
	_hero.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_wrap.add_child(_hero)


## Nó que desenha o programa ativo em código, no tamanho em que aparece.
class _HeroArt extends Control:
	var shell: MenuShell

	func _draw() -> void:
		if shell == null:
			return
		var r: float = minf(size.x, size.y) * 0.42
		if r <= 1.0:
			return
		GlyphLib.draw_glyph(self, shell._hero_kind, size * 0.5, r, shell._hero_color, 0.0)


func _build_actions(parent: Node) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", Design.SPACE_SM)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(col)

	# Ação primária: tipo enorme em acento, precedido de seta. Em fundo escuro
	# isto domina sem precisar de bloco sólido.
	# SHRINK_BEGIN: o host herdava FILL da coluna e o anel âmbar cobria a
	# largura inteira. O hit continua generoso (seta + wordmark + padding).
	var purge_row := HBoxContainer.new()
	purge_row.add_theme_constant_override("separation", Design.SPACE_LG)
	purge_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	purge_row.add_child(ScreenKit.grot("→", 44, Design.WEIGHT_BLACK, Design.ACCENT))
	_purge_label = ScreenKit.grot(tr("MENU_PURGE"), 54, Design.WEIGHT_BLACK, Design.ACCENT)
	purge_row.add_child(_purge_label)
	var purge_pad := Control.new()
	purge_pad.custom_minimum_size = Vector2(Design.SPACE_LG, 0)
	purge_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	purge_row.add_child(purge_pad)
	_purge_host = _overlay_button(purge_row, func() -> void: purge_pressed.emit())
	col.add_child(_purge_host)

	_mode_label = ScreenKit.mono("", Design.TEXT_SUBHEAD, Design.TEXT_SECONDARY)
	col.add_child(_mode_label)
	_best_label = ScreenKit.mono("", Design.TEXT_CAPTION, Design.TEXT_MUTED)
	col.add_child(_best_label)

	ScreenKit.gap(col, Design.SPACE_SM)
	# Run config real: MODE e DIFFICULTY são fileiras acionáveis, não texto.
	# O link ambíguo "Configurar partida" (segundo alias de trocar programa)
	# saiu daqui; programa continua em MENU_SWAP abaixo.
	# Lado a lado: duas fileiras empilhadas estouravam 1366x768.
	# BoxContainer puro (não HBox): só ele aceita trocar `vertical` — HBox
	# loga "Can't change orientation".
	_cfg_row = BoxContainer.new()
	_cfg_row.add_theme_constant_override("separation", Design.SPACE_MD)
	col.add_child(_cfg_row)
	_mode_block = ScreenKit.action(tr("MENU_MODE_CLASSIC"), "", "text", func() -> void: mode_cycled.emit())
	_mode_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cfg_row.add_child(_mode_block)
	_diff_block = ScreenKit.action(tr("MENU_DIFFICULTY") % "NORMAL", "", "text", func() -> void: difficulty_cycled.emit())
	_diff_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cfg_row.add_child(_diff_block)

	ScreenKit.gap(col, Design.SPACE_MD)
	ScreenKit.rule(col)
	ScreenKit.gap(col, Design.SPACE_SM)

	_story_block = ScreenKit.action(tr("MENU_STORY"), "", "text", func() -> void: story_pressed.emit())
	col.add_child(_story_block)
	_archives_block = ScreenKit.action(tr("MENU_ARCHIVES"), "", "text", func() -> void: archives_pressed.emit())
	col.add_child(_archives_block)

	ScreenKit.gap(col, Design.SPACE_MD)
	var prog := VBoxContainer.new()
	prog.add_theme_constant_override("separation", Design.SPACE_XS)
	col.add_child(prog)
	prog.add_child(ScreenKit.mono(tr("MENU_ACTIVE_PROGRAM"), Design.TEXT_MICRO, Design.TEXT_MUTED))
	var prog_row := HBoxContainer.new()
	prog_row.add_theme_constant_override("separation", Design.SPACE_MD)
	_program_label = ScreenKit.grot("", 22, Design.WEIGHT_BLACK, Design.TEXT_PRIMARY)
	prog_row.add_child(_program_label)
	_swap_link = _link(tr("MENU_SWAP"), func() -> void: configure_pressed.emit())
	prog_row.add_child(_swap_link)
	prog.add_child(prog_row)


## Link terciário: mono em acento com sublinhado colado ao texto.
func _link(text: String, on_press: Callable) -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 2)
	wrap.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	wrap.add_child(ScreenKit.mono(text, Design.TEXT_BODY, Design.ACCENT))
	var underline := ColorRect.new()
	underline.color = Design.ACCENT
	underline.custom_minimum_size = Vector2(0, 1)
	underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(underline)
	return _overlay_button(wrap, on_press)


## O PanelContainer sobrepõe conteúdo e hit. Dentro de HBox/VBox, o hit virava
## uma célula ao lado/abaixo do texto e clicar no rótulo não acionava nada.
func _overlay_button(content: Control, on_press: Callable) -> PanelContainer:
	var host := PanelContainer.new()
	host.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	host.size_flags_horizontal = content.size_flags_horizontal
	host.size_flags_vertical = content.size_flags_vertical
	host.add_child(content)
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
	glow.bg_color = Design.alpha(Design.TEXT_PRIMARY, 0.08)
	hit.add_theme_stylebox_override("hover", glow)
	hit.pressed.connect(on_press)
	host.add_child(hit)
	# Mesmo contrato de ScreenKit.action(): sem o meta "hit", acessores
	# (focus_primary/primary_hit_rect/run_config_hits) recebiam null e o
	# foco inicial do menu se perdia sem erro visível.
	host.set_meta("hit", hit)
	var first_labels := content.find_children("*", "Label", false, false)
	if not first_labels.is_empty():
		host.set_meta("label_node", first_labels[0])
	_bind_labels(hit, content)
	return host


func _bind_labels(hit: Button, content: Node) -> void:
	if content is Label:
		ScreenKit.bind_feedback(hit, content)
	for child in content.get_children():
		_bind_labels(hit, child)


func _build_footer(parent: Node) -> void:
	ScreenKit.rule(parent, 0.14)
	ScreenKit.gap(parent, Design.SPACE_MD)
	var row := BoxContainer.new()
	row.add_theme_constant_override("separation", Design.SPACE_MD)
	parent.add_child(row)
	_footer_row = row

	var enter_hint := ScreenKit.mono("ENTER", Design.TEXT_CAPTION, Design.ACCENT)
	enter_hint.visible = not Design.touch_input()
	# Duas sub-fileiras: no wide ficam lado a lado (como antes); no compacto
	# empilham em 2 linhas baixas em vez de 6 (o rodapé plano estourava 640
	# de altura e 432 de largura).
	var left_box := HBoxContainer.new()
	left_box.add_theme_constant_override("separation", Design.SPACE_MD)
	left_box.add_child(enter_hint)
	left_box.add_child(ScreenKit.mono(tr("MENU_START"), Design.TEXT_CAPTION, Design.TEXT_SECONDARY))
	row.add_child(left_box)
	ScreenKit.grow_h(row)

	var right_box := HBoxContainer.new()
	right_box.add_theme_constant_override("separation", Design.SPACE_MD)
	row.add_child(right_box)

	for spec in [
		[tr("MENU_SETTINGS"), func() -> void: settings_pressed.emit()],
		[tr("MENU_AWARDS"), func() -> void: awards_pressed.emit()],
		[tr("MENU_QUIT"), func() -> void: quit_pressed.emit()],
	]:
		# HBox dimensiona pelo conteúdo: medir `get_minimum_size()` aqui
		# (antes do layout) devolvia zero e o anel de foco saía menor que
		# o texto.
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		var pad_l := Control.new()
		pad_l.custom_minimum_size = Vector2(Design.SPACE_SM, 0)
		pad_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(pad_l)
		cell.add_child(ScreenKit.mono(str(spec[0]), Design.TEXT_CAPTION, Design.TEXT_PRIMARY))
		var pad_r := Control.new()
		pad_r.custom_minimum_size = Vector2(Design.SPACE_SM, 0)
		pad_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(pad_r)
		if Design.touch_input() and cell.custom_minimum_size.y < Design.TOUCH_TARGET_MIN:
			cell.custom_minimum_size.y = Design.TOUCH_TARGET_MIN
		var host := _overlay_button(cell, spec[1])
		_footer_hosts.append(host)
		right_box.add_child(host)

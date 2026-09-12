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

const HERO_RADIUS_WIDE := 150.0
const HERO_RADIUS_COMPACT := 90.0

var _hero: Control
var _purge_label: Label
var _mode_label: Label
var _best_label: Label
var _program_label: Label
var _version_label: Label
var _story_block: PanelContainer
var _archives_block: PanelContainer
var _body: BoxContainer
var _hero_wrap: Control
var _footer_row: HBoxContainer
var _masthead_row: HBoxContainer
var _hero_kind := "kernel"
var _hero_color := Design.ACCENT


func _ready() -> void:
	theme = UiTheme.shared()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_resize_to_viewport()
	get_viewport().size_changed.connect(_resize_to_viewport)
	_build()


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
	_purge_label.add_theme_font_size_override("font_size", 48 if compact else 92)
	if is_instance_valid(_hero_wrap):
		var r: float = HERO_RADIUS_COMPACT if compact else HERO_RADIUS_WIDE
		_hero_wrap.custom_minimum_size = Vector2(r * 2.2, r * 2.2)
		# Em modo empilhado o herói come a altura que o conteúdo precisa —
		# 1024x640 transbordava com ele visível.
		_hero_wrap.visible = not compact
	for block in [_story_block, _archives_block]:
		ScreenKit.set_action_density(block, compact)
	# Em janela baixa o masthead é 110px de decoração que não cabe — mesma
	# decisão tomada na pausa.
	if is_instance_valid(_masthead_row):
		_masthead_row.visible = size.y > 700.0


# ── estado vindo do menu ──────────────────────────────────────────────

func set_run_config(mode_text: String, best_text: String, program_name: String) -> void:
	_mode_label.text = mode_text
	_best_label.text = best_text
	_program_label.text = program_name


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
			_version_label, _story_block, _archives_block, _footer_row]:
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
	mark.add_child(ScreenKit.grot("KERNEL", 40, Design.WEIGHT_BLACK, Design.TEXT_PRIMARY))
	mark.add_child(ScreenKit.grot("PANIC", 40, Design.WEIGHT_BLACK, Design.TEXT_PRIMARY))
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
	var purge_row := HBoxContainer.new()
	purge_row.add_theme_constant_override("separation", Design.SPACE_LG)
	col.add_child(purge_row)
	purge_row.add_child(ScreenKit.grot("→", 72, Design.WEIGHT_BLACK, Design.ACCENT))
	_purge_label = ScreenKit.grot(tr("MENU_PURGE"), 92, Design.WEIGHT_BLACK, Design.ACCENT)
	purge_row.add_child(_purge_label)
	var purge_hit := _overlay_button(purge_row, func() -> void: purge_pressed.emit())
	purge_hit.focus_neighbor_bottom = purge_hit.get_path()

	_mode_label = ScreenKit.mono("", Design.TEXT_SUBHEAD, Design.TEXT_SECONDARY)
	col.add_child(_mode_label)
	_best_label = ScreenKit.mono("", Design.TEXT_CAPTION, Design.TEXT_MUTED)
	col.add_child(_best_label)

	ScreenKit.gap(col, Design.SPACE_SM)
	col.add_child(_link(tr("MENU_CONFIGURE"), func() -> void: configure_pressed.emit()))

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
	_program_label = ScreenKit.grot("", 26, Design.WEIGHT_BLACK, Design.TEXT_PRIMARY)
	prog_row.add_child(_program_label)
	prog_row.add_child(_link(tr("MENU_SWAP"), func() -> void: configure_pressed.emit()))
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
	_overlay_button(wrap, on_press)
	return wrap


## Botão transparente cobrindo um Control, para clique/hover/foco sem que o
## `Button` precise dispor filhos (ele não dispõe).
func _overlay_button(host: Control, on_press: Callable) -> Button:
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
	return hit


func _build_footer(parent: Node) -> void:
	ScreenKit.rule(parent, 0.14)
	ScreenKit.gap(parent, Design.SPACE_MD)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Design.SPACE_MD)
	parent.add_child(row)
	_footer_row = row

	row.add_child(ScreenKit.mono("ENTER", Design.TEXT_CAPTION, Design.ACCENT))
	row.add_child(ScreenKit.mono(tr("MENU_START"), Design.TEXT_CAPTION, Design.TEXT_SECONDARY))
	ScreenKit.grow_h(row)

	for spec in [
		[tr("MENU_SETTINGS"), func() -> void: settings_pressed.emit()],
		[tr("MENU_AWARDS"), func() -> void: awards_pressed.emit()],
		[tr("MENU_QUIT"), func() -> void: quit_pressed.emit()],
	]:
		var cell := Control.new()
		var label := ScreenKit.mono(str(spec[0]), Design.TEXT_CAPTION, Design.TEXT_SECONDARY)
		cell.custom_minimum_size = Vector2(label.get_minimum_size().x + Design.SPACE_LG, Design.SPACE_XL)
		label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
		label.position = Vector2(Design.SPACE_SM, 0)
		cell.add_child(label)
		_overlay_button(cell, spec[1])
		row.add_child(cell)

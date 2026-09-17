class_name PausePanel
extends Control

## Tela de pausa na direção editorial aprovada em 2026-09-11.
##
## Substitui o layout de `TacticalStateSurface.pause_layout()`, que posicionava
## tudo por retângulo absoluto derivado de um palco de 720px.
##
## Resolve o B6 por estrutura, não por ajuste: não existe mais moldura de
## perigo. O abandono é tipo em vermelho, no extremo oposto da fileira de
## ações. A separação física carrega o aviso melhor que a caixa carregava, e
## não sobra "dentro" onde uma dica de teclado possa cair por engano.
##
## A pausa fica SOBRE o jogo, então o fundo é véu translúcido (`Design.SCRIM`),
## não superfície opaca: você continua vendo a arena congelada atrás.

signal resume_pressed
signal restart_pressed
signal terminal_pressed
signal abandon_pressed
signal sfx_changed(value: float)
signal music_changed(value: float)

## Ordem segura: a ação destrutiva é sempre a última.
const ACTION_ICON_KINDS := ["resume", "restart", "terminal", "warning"]

var _title: Label
var _subtitle: Label
var _stats_row: HBoxContainer
var _meta: Label
var _abandon_block: PanelContainer
var _actions_row: BoxContainer
var _actions_spacer: Control
var _masthead: HBoxContainer
var _action_blocks: Array[PanelContainer] = []
var _sfx_slider: HSlider
var _music_slider: HSlider
var _abandon_armed := false
var _stats_data: Array = []


func _ready() -> void:
	theme = UiTheme.shared()
	# TOP_LEFT + sync manual (ver menu_shell): FULL_RECT + `size = vp` WARNING.
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
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


## Ajusta o layout ao degrau de largura. Sem isto o título de 74px e a fileira
## horizontal de ações transbordam abaixo de ~1100px — foi o que a asserção de
## contenção em 720x720 e 432x720 pegou.
func _apply_layout_mode() -> void:
	if not is_instance_valid(_title) or not is_instance_valid(_actions_row):
		return
	var step := Design.breakpoint_for(size.x)
	var compact := step == "compact" or step == "medium"
	_title.add_theme_font_size_override("font_size", Design.px(Design.step_down(Design.TEXT_DISPLAY) if compact else Design.TEXT_DISPLAY))
	_subtitle.visible = not compact
	# Em janela estreita o masthead é 70px de decoração que não cabe.
	if is_instance_valid(_masthead):
		_masthead.visible = not compact
	ScreenKit.fill_stats(_stats_row, _stats_data, 26 if compact else 42)
	for block in _action_blocks:
		ScreenKit.set_action_density(block, compact)
	_actions_row.vertical = compact
	if is_instance_valid(_actions_row):
		_actions_row.update_minimum_size()
	_actions_row.add_theme_constant_override("separation",
		Design.SPACE_MD if compact else Design.SPACE_2XL)
	if is_instance_valid(_actions_spacer):
		_actions_spacer.visible = not compact


# ── contrato consumido pelo autotest ──────────────────────────────────

func action_labels() -> Array[String]:
	# Derivado dos blocos CONSTRUÍDOS, não de lista fixa: no touch o
	# Terminal (desktop-only) nem nasce, e o contrato reflete a tela real.
	var out: Array[String] = []
	for block in _action_blocks:
		if is_instance_valid(block) and block.has_meta("label_node"):
			var node: Label = block.get_meta("label_node")
			if is_instance_valid(node):
				out.append(node.text)
	return out


func action_icon_kinds() -> Array[String]:
	var out: Array[String] = []
	for kind in ACTION_ICON_KINDS:
		out.append(str(kind))
	return out


## Texto que explica a confirmação em dois passos do abandono. Fica no próprio
## bloco de abandono — antes era uma linha solta desenhada dentro da moldura
## vermelha, o que fazia [ESC] e [R] parecerem parte do abandono (B6).
func abandon_hint_text() -> String:
	return tr("PAUSE_ABANDON_ARMED") if _abandon_armed else tr("PAUSE_ABANDON")


func set_abandon_armed(armed: bool) -> void:
	_abandon_armed = armed
	ScreenKit.set_action_label(_abandon_block, abandon_hint_text())


## Retângulos de todo conteúdo interativo, para o autotest afirmar contenção
## sem depender de um dicionário de layout absoluto.
func content_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for node in _interactive():
		out.append(Rect2(node.global_position, node.size))
	return out


func _interactive() -> Array[Control]:
	var out: Array[Control] = []
	for node in [_sfx_slider, _music_slider, _abandon_block]:
		if node != null and is_instance_valid(node):
			out.append(node)
	return out


func set_run_state(stats: Array, meta: String) -> void:
	_stats_data = stats
	ScreenKit.fill_stats(_stats_row, stats, 26 if Design.breakpoint_for(size.x) in ["compact", "medium"] else 42)
	_meta.text = meta
	_meta.visible = not meta.is_empty()


## `set_value_no_signal` não dispara `value_changed`, então o readout precisa
## ser atualizado à mão — sem isso os controles apareciam na posição certa com
## "0%" escrito ao lado.
func set_volumes(sfx: float, music: float) -> void:
	_apply_volume(_sfx_slider, sfx)
	_apply_volume(_music_slider, music)


func _apply_volume(slider: HSlider, value: float) -> void:
	if not is_instance_valid(slider):
		return
	slider.set_value_no_signal(value)
	if slider.has_meta("readout"):
		var readout: Label = slider.get_meta("readout")
		if is_instance_valid(readout):
			readout.text = "%d%%" % int(round(value * 100.0))


# ── construção ────────────────────────────────────────────────────────

func _build() -> void:
	# Véu, não superfície: a pausa acontece sobre a arena congelada e manter
	# esse contexto visível é intencional.
	var veil := ColorRect.new()
	veil.color = Design.SCRIM
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)

	var col := ScreenKit.page(self)
	_masthead = ScreenKit.masthead(col, tr("PAUSE_STATE"))
	ScreenKit.gap(col, Design.SPACE_3XL)

	_title = ScreenKit.grot(tr("PAUSE_TITLE"), 60, Design.WEIGHT_BLACK, Design.TEXT_PRIMARY)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(_title)
	_subtitle = ScreenKit.mono(tr("PAUSE_SUBTITLE"), Design.TEXT_SUBHEAD, Design.TEXT_SECONDARY)
	col.add_child(_subtitle)

	ScreenKit.gap(col, Design.SPACE_2XL)
	ScreenKit.rule(col)
	ScreenKit.gap(col, Design.SPACE_XL)

	_stats_row = ScreenKit.stat_row(col, [], 42)
	ScreenKit.gap(col, Design.SPACE_MD)
	_meta = ScreenKit.mono("", Design.TEXT_CAPTION, Design.TEXT_MUTED)
	col.add_child(_meta)

	ScreenKit.gap(col, Design.SPACE_2XL)
	_build_audio(col)
	ScreenKit.grow_v(col)
	_build_actions(col)


## Dois controles de volume compactos, lado a lado. O layout antigo esticava um
## slider de 0-100% por ~1000px em 1920 e deixava o rótulo a 1200px do controle.
func _build_audio(parent: Node) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Design.SPACE_3XL)
	parent.add_child(row)
	_sfx_slider = _volume_control(row, tr("AUDIO_SFX"), func(v: float) -> void: sfx_changed.emit(v))
	_music_slider = _volume_control(row, tr("AUDIO_MUSIC"), func(v: float) -> void: music_changed.emit(v))
	ScreenKit.grow_h(row)


func _volume_control(parent: Node, label: String, on_change: Callable) -> HSlider:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", Design.SPACE_XS)
	# Largura adaptativa: fixar ~400px fazia dois controles somarem 800px e
	# transbordar em janela de 432. Eles dividem o espaço disponível.
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.custom_minimum_size = Vector2(120, 0)
	parent.add_child(cell)

	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(ScreenKit.mono(label, Design.TEXT_CAPTION, Design.TEXT_MUTED))
	ScreenKit.grow_h(head)
	var readout := ScreenKit.mono("", Design.TEXT_CAPTION, Design.TEXT_SECONDARY)
	head.add_child(readout)
	cell.add_child(head)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size = Vector2(0, Design.SPACE_XL)
	slider.focus_mode = Control.FOCUS_ALL
	slider.value_changed.connect(func(v: float) -> void:
		readout.text = "%d%%" % int(round(v * 100.0))
		on_change.call(v)
	)
	cell.add_child(slider)
	slider.set_meta("readout", readout)
	readout.text = "%d%%" % int(round(slider.value * 100.0))
	return slider


func _build_actions(parent: Node) -> void:
	# BoxContainer (não HBox) para poder virar coluna em janela estreita.
	_actions_row = BoxContainer.new()
	_actions_row.add_theme_constant_override("separation", Design.SPACE_2XL)
	parent.add_child(_actions_row)

	# Touch: sem dicas de teclado e sem o Terminal (workstation desktop-only;
	# expor quebrada no telefone é pior que esconder a entrada).
	var touch := Design.touch_input()
	for spec in [
		[tr("PAUSE_RESUME"), "[ESC]", "primary", func() -> void: resume_pressed.emit()],
		[tr("PAUSE_RESTART"), "[R]", "text", func() -> void: restart_pressed.emit()],
		[tr("PAUSE_TERMINAL"), "[T]", "text", func() -> void: terminal_pressed.emit()],
	]:
		if touch and str(spec[0]) == tr("PAUSE_TERMINAL"):
			continue
		var key := "" if touch else str(spec[1])
		var block := ScreenKit.action(str(spec[0]), key, str(spec[2]), spec[3])
		_action_blocks.append(block)
		_actions_row.add_child(block)

	# O abandono vai para o extremo oposto. A distância é o aviso — em coluna
	# o espaçador some e a ordem (destrutiva por último) carrega sozinha.
	_actions_spacer = Control.new()
	_actions_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_actions_row.add_child(_actions_spacer)

	_abandon_block = ScreenKit.action(tr("PAUSE_ABANDON"), "" if touch else "[Q]", "danger",
		func() -> void: abandon_pressed.emit())
	_action_blocks.append(_abandon_block)
	_actions_row.add_child(_abandon_block)
	_apply_layout_mode()

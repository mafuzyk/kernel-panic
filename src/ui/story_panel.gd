class_name StoryPanel
extends Control

## Seleção de ponto de montagem na direção editorial.
##
## Porte de 2026-09-12. A versão anterior desenhava um "mapa de rota": uma grade
## de cards ligados por linhas, tudo em `_draw()` com offset absoluto. Numa
## coluna de ~538px com seis colunas os cards ficavam com 156px e o texto caía
## para 9px — a tela existia para você LER a fase antes de entrar, e não dava
## para ler.
##
## Aqui a rota virou uma LISTA vertical numerada. A progressão continua legível
## (01, 02, 03… de cima para baixo, estado ao lado), e cada linha tem largura de
## sobra para o caminho e o título. O painel de detalhe à direita passou a ser
## o corpo da tela em vez de um apêndice.
##
## Duas coisas que a tela antiga prometia e não cumpria:
##
## 1. Ela desenhava "MOUNT /boot [ENTER]" no rodapé, mas `stage_selected` estava
##    ligado direto em `_start_story`: clicar num card JÁ entrava na fase. O
##    rodapé era rótulo sem ação, e o painel de detalhe era impossível de ler,
##    porque o clique que o preencheria também iniciava a partida. Agora são
##    dois passos — `stage_selected` destaca, `stage_mounted` entra.
## 2. O "ARENA PREVIEW" era uma grade estática com um ponto no meio, igual para
##    todas as fases. Decoração fingindo informação. No lugar dele entram as
##    silhuetas reais das ameaças daquela fase, desenhadas pela mesma
##    `GlyphLib` que a arena usa.

signal stage_selected(index: int)
signal stage_mounted(index: int)
signal back_pressed

## Proporção da lista quando há espaço para as duas colunas.
const LIST_RATIO := 0.40
const ROW_HEIGHT := 72.0
const THREAT_GLYPH := 30.0
## Derivada do STAGES: um ato novo aparece na aba sem tocar nesta tela.
static var ACTS: Array = StoryData.act_ids()

var scroll_y := 0.0
var t := 0.0
var _card_rects: Dictionary = {}
var _tab_rects: Dictionary = {}
var _selected_stage := 0
var _last_narrow := false
var _act_filter := "unix"

var _title: Label
var _subtitle: Label
var _tabs_row: HBoxContainer
var _body: BoxContainer
var _scroll: ScrollContainer
var _rows_box: VBoxContainer
var _detail_scroll: ScrollContainer
var _detail: VBoxContainer
var _footer: BoxContainer
var _mount_block: PanelContainer
var _back_block: PanelContainer
var _hint: Label
var _rows: Dictionary = {}
var _tabs: Dictionary = {}

var _dragging := false
var _press_position := Vector2.ZERO
var _drag_start_y := 0.0
var _scroll_start := 0.0


func _ready() -> void:
	theme = UiTheme.shared()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_act_filter = _act_of(_selected_stage)
	_build()
	_apply_layout_mode()


# ── conteúdo ──────────────────────────────────────────────────────────

func title_text() -> String:
	return tr("STORY_TITLE")


func title_font_size() -> int:
	return Design.TEXT_HEADING if Design.breakpoint_for(size.x) == "compact" or Design.touch_input() else Design.TEXT_TITLE


func available_stage_indices() -> Array:
	var result: Array = []
	for i in Game.story_stage_count():
		if Game.story_stage_unlocked(i):
			result.append(i)
	return result


func select_stage(index: int) -> bool:
	if not Game.story_stage_unlocked(index):
		return false
	_selected_stage = index
	var act := _act_of(index)
	if act != _act_filter:
		_act_filter = act
		_rebuild_rows()
	stage_selected.emit(index)
	_refresh_rows()
	_fill_detail()
	return true


func selected_stage_index() -> int:
	return _selected_stage


## Estado de uma fase. Público porque é o que o autotest deve afirmar — a
## versão anterior era verificada procurando `_draw_state_glyph` no texto do
## arquivo, o que passava mesmo se a função nunca fosse chamada.
func stage_state(index: int) -> String:
	if not Game.story_stage_unlocked(index):
		return "LOCKED"
	if bool(Game.story_cleared.get(Game.story_stage_id(index), false)):
		return "CLEARED"
	return "CURRENT"


func state_label(state: String) -> String:
	match state:
		"CLEARED": return tr("STORY_STATE_CLEARED")
		"CURRENT": return tr("STORY_STATE_CURRENT")
		_: return tr("STORY_STATE_LOCKED")


## Os três estados têm tintas distintas — é isso que o teste de estado quer
## garantir, não a existência de uma função de desenho.
func state_ink(state: String, index: int = -1) -> Color:
	match state:
		"CLEARED": return Design.SUCCESS
		"CURRENT": return _stage_color(index) if index >= 0 else Design.ACCENT
		_: return Design.TEXT_GHOST


func card_accent(index: int) -> Color:
	var accent := _stage_color(index)
	if index == _selected_stage and Game.story_stage_unlocked(index):
		return accent
	return Design.alpha(accent, 0.46)


## Papéis de tinta de uma linha. A cor da fase fica no MARCADOR; o caminho e o
## título ficam em tinta neutra.
func card_ink(index: int) -> Dictionary:
	var unlocked := Game.story_stage_unlocked(index)
	var state := stage_state(index)
	return {
		"title": Design.TEXT_PRIMARY if unlocked else Design.TEXT_FAINT,
		"marker": _stage_color(index),
		"body": Design.TEXT_MUTED if unlocked else Design.TEXT_GHOST,
		"state": state_ink(state, index),
	}


## Silhuetas que esta tela mostra. Exposto para o autotest afirmar que cada uma
## é um tipo que a `GlyphLib` sabe desenhar, em vez de procurar a string
## "GlyphLib.draw_" no código-fonte.
func glyph_kinds() -> Array[String]:
	var out: Array[String] = []
	for kind in _threats(_selected_stage):
		out.append(str(kind))
	return out


func mount_label() -> String:
	return tr("STORY_MOUNT").format([str(Game.story_stage_def(_selected_stage).get("path", "/boot"))])


func scroll_hint_text() -> String:
	return Design.scroll_hint(Design.touch_input())


# ── geometria consumida pelo autotest ─────────────────────────────────

func content_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for node in [_title, _subtitle, _tabs_row, _body, _mount_block, _back_block, _footer]:
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


## Aritmética pura: o harness chama isto em painel fora da árvore.
func _content_metrics() -> Dictionary:
	var step := Design.breakpoint_for(size.x)
	var narrow := step == "compact" or step == "medium"
	var page_w: float = maxf(size.x - float(Design.SPACE_4XL) * 2.0, 160.0)
	var list_w: float = page_w if narrow else (page_w - float(Design.SPACE_XL)) * LIST_RATIO
	var visible := _visible_stage_indices().size()
	return {
		"cols": 1,
		"gap": float(Design.SPACE_SM),
		"card_w": maxf(list_w, 120.0),
		"card_h": ROW_HEIGHT,
		"rows": visible,
		"content_h": float(visible) * (ROW_HEIGHT + float(Design.SPACE_SM)),
		"compact": narrow,
	}


## O caminho da fase acompanha a largura da linha. A 272px úteis, 22px deixam
## "TempleOS::BOOT" sem espaço para o rótulo de estado ao lado.
func _path_font_size() -> int:
	return 18 if float(_content_metrics().get("card_w", 400.0)) < 360.0 else 22


func _visible_stage_indices() -> Array:
	var result: Array = []
	for index in Game.story_stage_count():
		if _act_of(index) == _act_filter:
			result.append(index)
	return result


func _act_of(index: int) -> String:
	return str(Game.story_stage_def(index).get("act", "unix"))


func _stage_color(index: int) -> Color:
	var stage := Game.story_stage_def(index)
	var theme_data: Dictionary = stage.get("theme", {})
	return theme_data.get("accent", Design.ACCENT)


static func _act_color(act: String) -> Color:
	match act:
		"windows": return Color("b46bff")
		"macos": return Color("5ac8fa")
		"templeos": return Design.WARNING
		_: return Design.ACCENT


func _threats(index: int) -> Array:
	var names: Array = []
	for wave in Game.story_stage_def(index).get("waves", []):
		for enemy in wave:
			if not names.has(enemy):
				names.append(enemy)
	return names


# ── processo ──────────────────────────────────────────────────────────

## Pulso cosmético do marcador da fase atual. Usa tempo de frame, nunca a rng
## de gameplay — é esse o invariante que o autotest afirma.
func _process(delta: float) -> void:
	if not visible:
		return
	t += delta
	_sync_card_rects()
	_sync_scroll_hint()
	if is_instance_valid(_scroll):
		scroll_y = float(_scroll.scroll_vertical)
	for raw_index in _rows:
		var row: PanelContainer = _rows[raw_index]
		if is_instance_valid(row) and row.has_meta("pulse") and stage_state(int(raw_index)) == "CURRENT":
			var dot: Control = row.get_meta("pulse")
			if is_instance_valid(dot):
				dot.modulate.a = 0.55 + sin(t * 4.0) * 0.35


func _sync_card_rects() -> void:
	_card_rects.clear()
	for raw_index in _rows:
		var row: Control = _rows[raw_index]
		if is_instance_valid(row):
			_card_rects[int(raw_index)] = Rect2(row.global_position - global_position, row.size)
	_tab_rects.clear()
	for raw_act in _tabs:
		var tab: Control = _tabs[raw_act]
		if is_instance_valid(tab):
			_tab_rects[str(raw_act)] = Rect2(tab.global_position - global_position, tab.size)


func _sync_scroll_hint() -> void:
	if not is_instance_valid(_hint) or not is_instance_valid(_scroll):
		return
	var bar := _scroll.get_v_scroll_bar()
	var scrollable := bar != null and bar.max_value > bar.page
	# Só em tela larga: a 720 a dica empurra o bloco de ação para fora da coluna.
	_hint.visible = scrollable and Design.breakpoint_for(size.x) in ["wide", "ultra"]


# ── entrada ───────────────────────────────────────────────────────────

func _scroll_to(value: float) -> void:
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(maxf(value, 0.0))
		scroll_y = float(_scroll.scroll_vertical)
	_sync_card_rects()


func _select_act(act_id: String) -> void:
	if act_id == "" or act_id == _act_filter or not ACTS.has(act_id):
		return
	_act_filter = act_id
	_rebuild_rows()
	_scroll_to(0.0)
	# A primeira fase do ato passa a ser o destaque: sem isso o detalhe mostra
	# uma fase que não está na lista visível.
	var visible := _visible_stage_indices()
	if not visible.is_empty():
		_selected_stage = int(visible[0])
		stage_selected.emit(_selected_stage)
		_refresh_rows()
		_fill_detail()


func _tab_for_position(position: Vector2) -> String:
	for raw_act in _tab_rects:
		var rect: Rect2 = _tab_rects[raw_act]
		if rect.has_point(position):
			return str(raw_act)
	return ""


## ENTER sem foco monta a fase destacada. Com foco, o Button aciona no release;
## tratar também o press aqui monta antes de selecionar ou monta duas vezes.
func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	if get_viewport().gui_get_focus_owner() != null:
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_mount()
		get_viewport().set_input_as_handled()


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
					_tap(event.position)
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
				_tap(event.position)
			_dragging = false
		accept_event()
	elif event is InputEventScreenDrag and _dragging:
		_scroll_to(_scroll_start - (event.position.y - _drag_start_y))
		accept_event()


func _tap(position: Vector2) -> void:
	_sync_card_rects()
	var act := _tab_for_position(position)
	if act != "":
		_select_act(act)
		Sfx.play("ui", 1.05, -8.0)
		return
	_select_at(position)


func _select_at(position: Vector2) -> void:
	for raw_index in _card_rects:
		var index := int(raw_index)
		var rect: Rect2 = _card_rects[index]
		if rect.has_point(position):
			if select_stage(index):
				Sfx.play("ui", 1.05, -8.0)
			return


func _mount() -> void:
	if Game.story_stage_unlocked(_selected_stage):
		stage_mounted.emit(_selected_stage)


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
	_subtitle = ScreenKit.mono(tr("STORY_SUBTITLE"), Design.TEXT_CAPTION, Design.TEXT_SECONDARY)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(_subtitle)

	ScreenKit.gap(col, Design.SPACE_XL)
	ScreenKit.rule(col)
	ScreenKit.gap(col, Design.SPACE_MD)
	_build_tabs(col)
	ScreenKit.gap(col, Design.SPACE_MD)
	ScreenKit.rule(col)
	ScreenKit.gap(col, Design.SPACE_XL)

	_body = BoxContainer.new()
	_body.add_theme_constant_override("separation", Design.SPACE_XL)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_body)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_stretch_ratio = LIST_RATIO
	_body.add_child(_scroll)

	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", Design.SPACE_SM)
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_rows_box)

	_detail_scroll = ScrollContainer.new()
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_stretch_ratio = 1.0 - LIST_RATIO
	_body.add_child(_detail_scroll)

	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 0)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.add_child(_detail)

	ScreenKit.gap(col, Design.SPACE_XL)
	ScreenKit.rule(col)
	ScreenKit.gap(col, Design.SPACE_MD)
	_build_footer(col)

	_rebuild_rows()
	_fill_detail()


## Abas de ato. Sem moldura: rótulo e uma barra na cor do ato embaixo do ativo.
## A versão anterior desenhava três caixas de canto cortado em três cores, todas
## acesas ao mesmo tempo.
func _build_tabs(parent: Node) -> void:
	_tabs_row = HBoxContainer.new()
	_tabs_row.add_theme_constant_override("separation", Design.SPACE_XL)
	parent.add_child(_tabs_row)
	for act in ACTS:
		var act_id := str(act)
		# PanelContainer e não VBox como raiz da aba: um `Button` filho de um
		# VBox é DISPOSTO como mais uma linha e empurra a altura da fileira em
		# ~31px de vazio. O PanelContainer estica todos os filhos para o mesmo
		# retângulo, que é o que faz o botão transparente ficar por cima.
		var cell := PanelContainer.new()
		var transparent := StyleBoxFlat.new()
		transparent.bg_color = Color(0, 0, 0, 0)
		cell.add_theme_stylebox_override("panel", transparent)
		_tabs_row.add_child(cell)

		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", Design.SPACE_SM)
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(stack)

		var label := ScreenKit.mono(tr("STORY_TAB_%s" % act_id.to_upper()), Design.TEXT_CAPTION,
			Design.TEXT_MUTED)
		stack.add_child(label)
		var bar := ColorRect.new()
		bar.color = _act_color(act_id)
		bar.custom_minimum_size = Vector2(0, 2)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(bar)

		var hit := Button.new()
		hit.flat = true
		hit.focus_mode = Control.FOCUS_ALL
		hit.add_theme_stylebox_override("focus", _focus_ring())
		hit.pressed.connect(func() -> void:
			_select_act(act_id)
			Sfx.play("ui", 1.05, -8.0)
		)
		cell.add_child(hit)
		ScreenKit.bind_feedback(hit, label)

		cell.set_meta("label", label)
		cell.set_meta("bar", bar)
		_tabs[act_id] = cell
	_refresh_tabs()
	ScreenKit.grow_h(_tabs_row)


func _refresh_tabs() -> void:
	for raw_act in _tabs:
		var act_id := str(raw_act)
		var cell: Control = _tabs[act_id]
		if not is_instance_valid(cell):
			continue
		var active := act_id == _act_filter
		var label: Label = cell.get_meta("label")
		var bar: ColorRect = cell.get_meta("bar")
		if is_instance_valid(label):
			label.add_theme_color_override("font_color",
				Design.TEXT_PRIMARY if active else Design.TEXT_MUTED)
		if is_instance_valid(bar):
			bar.color = _act_color(act_id) if active else Design.alpha(Design.TEXT_PRIMARY, 0.12)


func _build_footer(parent: Node) -> void:
	_footer = BoxContainer.new()
	_footer.add_theme_constant_override("separation", Design.SPACE_XL)
	parent.add_child(_footer)

	_mount_block = ScreenKit.action(mount_label(), "" if Design.touch_input() else "[ENTER]", "primary", _mount)
	_footer.add_child(_mount_block)
	_back_block = ScreenKit.action(tr("UI_BACK"), "" if Design.touch_input() else "[ESC]", "text",
		func() -> void: back_pressed.emit())
	_footer.add_child(_back_block)
	ScreenKit.grow_h(_footer)

	_hint = ScreenKit.mono(scroll_hint_text(), Design.TEXT_MICRO, Design.TEXT_FAINT)
	_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_footer.add_child(_hint)


static func _focus_ring() -> StyleBoxFlat:
	var ring := StyleBoxFlat.new()
	ring.bg_color = Color(0, 0, 0, 0)
	for side in ["border_width_left", "border_width_right", "border_width_top", "border_width_bottom"]:
		ring.set(side, int(Design.FOCUS_RING_WIDTH))
	ring.border_color = Design.FOCUS_RING_COLOR
	return ring


func _rebuild_rows() -> void:
	if not is_instance_valid(_rows_box):
		return
	for child in _rows_box.get_children():
		_rows_box.remove_child(child)
		child.queue_free()
	_rows.clear()
	for raw_index in _visible_stage_indices():
		var index := int(raw_index)
		var row := _make_row(index)
		_rows[index] = row
		_rows_box.add_child(row)
	_refresh_tabs()
	_refresh_rows()


## Uma linha da rota: número, caminho, título, estado e contagem de ondas.
func _make_row(index: int) -> PanelContainer:
	var stage := Game.story_stage_def(index)
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", Design.SPACE_LG)
	pad.add_theme_constant_override("margin_right", Design.SPACE_LG)
	pad.add_theme_constant_override("margin_top", Design.SPACE_MD)
	pad.add_theme_constant_override("margin_bottom", Design.SPACE_MD)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pad)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", Design.SPACE_LG)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(line)

	# Marcador da fase: o número e, na fase atual, um ponto que pulsa. É o que
	# sobrou do "nó da rota" da versão anterior — o mesmo sinal, sem os colchetes
	# e os arcos desenhados à mão em volta.
	var marker := HBoxContainer.new()
	marker.add_theme_constant_override("separation", Design.SPACE_SM)
	marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(marker)

	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(4, 4)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_child(dot)
	var number := ScreenKit.mono("%02d" % (index + 1), Design.TEXT_CAPTION, Design.TEXT_MUTED)
	number.custom_minimum_size = Vector2(24, 0)
	marker.add_child(number)

	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(names)
	var path_label := ScreenKit.grot(str(stage.get("path", "")), _path_font_size(),
		Design.WEIGHT_BOLD, Design.TEXT_PRIMARY)
	# "TempleOS::BOOT" não cabe em linha estreita. Reticências são degradação
	# honesta; corte no meio do glifo não é.
	path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(path_label)
	var title_label := ScreenKit.mono("", Design.TEXT_MICRO, Design.TEXT_MUTED)
	names.add_child(title_label)

	var meta := VBoxContainer.new()
	meta.add_theme_constant_override("separation", 0)
	meta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(meta)
	var state_label := ScreenKit.mono("", Design.TEXT_MICRO, Design.TEXT_MUTED)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meta.add_child(state_label)
	var waves_label := ScreenKit.mono("", Design.TEXT_MICRO, Design.TEXT_FAINT)
	waves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meta.add_child(waves_label)

	var hit := Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_ALL
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.add_theme_stylebox_override("focus", _focus_ring())
	var glow := StyleBoxFlat.new()
	glow.bg_color = Design.alpha(Design.TEXT_PRIMARY, 0.06)
	hit.add_theme_stylebox_override("hover", glow)
	hit.pressed.connect(func() -> void:
		if select_stage(index):
			Sfx.play("ui", 1.05, -8.0)
	)
	row.add_child(hit)
	ScreenKit.bind_feedback(hit, path_label)

	row.set_meta("path", path_label)
	row.set_meta("title", title_label)
	row.set_meta("state", state_label)
	row.set_meta("waves", waves_label)
	row.set_meta("number", number)
	row.set_meta("pulse", dot)
	return row


func _refresh_rows() -> void:
	for raw_index in _rows:
		var index := int(raw_index)
		var row: PanelContainer = _rows[index]
		if not is_instance_valid(row):
			continue
		var stage := Game.story_stage_def(index)
		var unlocked := Game.story_stage_unlocked(index)
		var selected := index == _selected_stage and unlocked
		var ink: Dictionary = card_ink(index)
		var state := stage_state(index)

		var box := StyleBoxFlat.new()
		box.bg_color = Design.SURFACE_RAISED if selected else Design.SURFACE_SUNKEN
		box.border_width_left = int(Design.STROKE_THICK) if selected else 0
		box.border_color = ink.get("marker", Design.ACCENT)
		row.add_theme_stylebox_override("panel", box)

		var path_text := str(stage.get("path", "")) if unlocked else tr("STORY_STATE_LOCKED")
		_set_label(row, "path", ink.get("title", Design.TEXT_PRIMARY), path_text)
		# No narrow o meta (estado + ondas) some: a linha precisa caber em
		# ~300px e o detalhe já mostra ondas e estado (precedente: bestiário
		# esconde pontos no narrow).
		var row_narrow := _last_narrow
		for meta_key in ["state", "waves"]:
			if row.has_meta(meta_key):
				var meta_label: Label = row.get_meta(meta_key)
				if is_instance_valid(meta_label):
					meta_label.visible = not row_narrow
		_set_label(row, "title", ink.get("body", Design.TEXT_MUTED),
			_stage_title(index) if unlocked else tr("STORY_STATUS_LOCKED"))
		_set_label(row, "state", ink.get("state", Design.TEXT_MUTED), state_label(state))
		_set_label(row, "waves", Design.TEXT_FAINT,
			"%02d %s" % [stage.get("waves", []).size(), tr("STORY_WAVES")])
		_set_label(row, "number", ink.get("marker", Design.ACCENT) if unlocked else Design.TEXT_GHOST, "")

		if row.has_meta("pulse"):
			var dot: ColorRect = row.get_meta("pulse")
			if is_instance_valid(dot):
				dot.color = ink.get("state", Design.TEXT_MUTED)
				dot.modulate.a = 1.0
	if is_instance_valid(_mount_block):
		ScreenKit.set_action_label(_mount_block, mount_label())


func _set_label(row: PanelContainer, key: String, color: Color, text: String) -> void:
	if not row.has_meta(key):
		return
	var label: Label = row.get_meta(key)
	if not is_instance_valid(label):
		return
	label.add_theme_color_override("font_color", color)
	if text != "":
		label.text = text


# ── detalhe ───────────────────────────────────────────────────────────

func _stage_title(index: int) -> String:
	return StoryData.localized_title(Game.story_stage_id(index))


func _stage_intro(index: int) -> String:
	return StoryData.localized_intro(Game.story_stage_id(index))


## Conteúdo localizado com queda para o texto em inglês de `StoryData`. Uma
## chave ausente volta como a própria chave — é esse o sinal de queda, e é o que
## faz uma fase nova aparecer na tela mesmo antes de entrar no CSV.
func _content(index: int, field: String, key: String) -> String:
	var fallback := str(Game.story_stage_def(index).get(field, ""))
	var translated := tr(key)
	return fallback if translated == key else translated


func _fill_detail() -> void:
	if not is_instance_valid(_detail):
		return
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()

	var index := _selected_stage
	var stage := Game.story_stage_def(index)
	var unlocked := Game.story_stage_unlocked(index)
	var accent := _stage_color(index)

	_detail.add_child(ScreenKit.mono(
		tr("STORY_DETAIL_TAG").format([str(stage.get("path", ""))]),
		Design.TEXT_MICRO, accent))
	ScreenKit.gap(_detail, Design.SPACE_SM)
	_detail.add_child(ScreenKit.grot(_stage_title(index), 28, Design.WEIGHT_BLACK,
		Design.TEXT_PRIMARY if unlocked else Design.TEXT_FAINT))
	ScreenKit.gap(_detail, Design.SPACE_XS)
	_detail.add_child(ScreenKit.mono(
		tr("STORY_STATUS_READY") if unlocked else tr("STORY_STATUS_LOCKED"),
		Design.TEXT_MICRO, accent if unlocked else Design.TEXT_MUTED))

	ScreenKit.gap(_detail, Design.SPACE_LG)
	ScreenKit.rule(_detail)
	ScreenKit.gap(_detail, Design.SPACE_LG)

	var intro := ScreenKit.mono(
		_stage_intro(index) if unlocked else tr("STORY_LOCKED_BODY"),
		Design.TEXT_CAPTION, Design.TEXT_SECONDARY if unlocked else Design.TEXT_GHOST)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail.add_child(intro)

	# O que a fase PEDE e o que ela PAGA. Sem isto o seletor só dizia quantas
	# ondas tem — nada que a jogadora pudesse perseguir ou levar embora.
	#
	# A nota entra na fileira que já existia, no lugar da escala, e o resto vem
	# como linhas de texto: uma segunda fileira de estatísticas alargava o
	# mínimo horizontal do detalhe e estourava a página inteira em 432px.
	var stage_id := str(stage.get("id", ""))
	var par := StoryData.stage_par_seconds(stage_id)
	var rank := Game.story_stage_rank(stage_id)
	ScreenKit.gap(_detail, Design.SPACE_LG)
	ScreenKit.stat_row(_detail, [
		[tr("STORY_WAVES"), "%02d" % stage.get("waves", []).size()],
		# Um traço, não "NOT RANKED": o valor da fileira é tipografia display de
		# 26px em três colunas que esticam, e uma palavra longa aqui alarga o
		# mínimo do detalhe até a página inteira estourar em 432px.
		[tr("STORY_STAT_RANK"), rank if rank != "" else "—"],
		[tr("STORY_BEST"), str(Game.story_stage_best(index))],
	], 26)
	ScreenKit.gap(_detail, Design.SPACE_SM)
	var target_line := ScreenKit.mono(
		"%s %.2fx   //   %s %d:%02d" % [tr("STORY_SCALE"), float(stage.get("scale", 1.0)),
			tr("STORY_STAT_TARGET"), int(par / 60.0), int(par) % 60],
		Design.TEXT_MICRO, Design.TEXT_MUTED)
	target_line.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail.add_child(target_line)
	# O que a fase IMPÕE e o que ela ENTREGA. As duas coisas que separam uma
	# fase de story de uma lista de ondas, e as duas que a jogadora precisa
	# saber antes de montar a cabeça para a tentativa.
	var hazard := StoryData.stage_hazard(stage_id)
	if hazard != "none" and hazard != "":
		var rule_line := ScreenKit.mono(
			"%s // %s — %s" % [tr("STORY_STAT_RULE"), tr("STORY_HAZARD_%s" % hazard.to_upper()),
				tr("STORY_HAZARD_DESC_%s" % hazard.to_upper())],
			Design.TEXT_MICRO, Design.WARNING)
		rule_line.autowrap_mode = TextServer.AUTOWRAP_WORD
		_detail.add_child(rule_line)
	var build_line := ScreenKit.mono(
		"%s // %s" % [tr("STORY_STAT_BUILD"), _build_text(stage_id)],
		Design.TEXT_MICRO, Design.TEXT_MUTED)
	build_line.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail.add_child(build_line)
	if StoryData.is_act_final_stage(stage_id):
		var reward := StoryData.act_reward(str(stage.get("act", "unix")))
		var reward_line := ScreenKit.mono(
			"%s // %s" % [tr("STORY_REWARD"), tr("TINT_%s" % reward.to_upper())],
			Design.TEXT_MICRO, _act_color(str(stage.get("act", "unix"))))
		reward_line.autowrap_mode = TextServer.AUTOWRAP_WORD
		_detail.add_child(reward_line)

	ScreenKit.gap(_detail, Design.SPACE_LG)
	_detail.add_child(ScreenKit.mono(tr("STORY_THREATS"), Design.TEXT_MICRO, Design.TEXT_MUTED))
	ScreenKit.gap(_detail, Design.SPACE_SM)
	_build_threats(_detail, index, unlocked)

	var klog: Array = stage.get("klog", [])
	if unlocked and not klog.is_empty():
		ScreenKit.gap(_detail, Design.SPACE_LG)
		_detail.add_child(ScreenKit.mono(tr("STORY_KLOG"), Design.TEXT_MICRO, Design.TEXT_MUTED))
		ScreenKit.gap(_detail, Design.SPACE_SM)
		for log_i in mini(klog.size(), 2):
			var log_line := ScreenKit.mono("> %s" % str(klog[log_i]), Design.TEXT_MICRO,
				Design.TEXT_FAINT)
			log_line.autowrap_mode = TextServer.AUTOWRAP_WORD
			_detail.add_child(log_line)


## As ameaças da fase, desenhadas pela mesma biblioteca que a arena usa, cada
## uma na cor de identidade que ela tem em jogo. Substitui o "ARENA PREVIEW",
## que era a mesma grade estática para todas as fases da corrente.
## Build da fase em uma linha, pelos títulos dos patches. Vazio tem nome
## próprio: "processo nu" diz que a fase é assim de propósito, enquanto uma
## linha em branco pareceria dado faltando.
func _build_text(stage_id: String) -> String:
	var build: Dictionary = StoryData.stage_build(stage_id)
	if build.is_empty():
		return tr("STORY_BUILD_NONE")
	var parts: Array[String] = []
	for patch_id in build:
		var title := str(patch_id).to_upper()
		for definition in Game.PATCH_DEFS:
			if str(definition["id"]) == str(patch_id):
				title = str(definition["title"])
				break
		var level := int(build[patch_id])
		parts.append(title if level <= 1 else "%s x%d" % [title, level])
	return ", ".join(parts)


func _build_threats(parent: Node, index: int, unlocked: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Design.SPACE_LG)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	for kind in _threats(index):
		var id := str(kind)
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", Design.SPACE_XS)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(cell)
		var tint: Color = BestiaryPanel.entry_color(id) if unlocked else Design.TEXT_GHOST
		var mark := ScreenKit.glyph(id, tint, THREAT_GLYPH)
		mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(mark)
		var name_label := ScreenKit.mono(id.to_upper(), Design.TEXT_MICRO,
			Design.TEXT_MUTED if unlocked else Design.TEXT_GHOST)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(name_label)
	ScreenKit.grow_h(row)


# ── modo de layout ────────────────────────────────────────────────────

func _apply_layout_mode() -> void:
	if not is_instance_valid(_title):
		return
	var step := Design.breakpoint_for(size.x)
	# Touch usa a composição empilhada mesmo em landscape largo: o split
	# desktop espreme lista e detalhe até virar microcópia no telefone.
	var narrow := step == "compact" or step == "medium" or Design.touch_input()
	_title.add_theme_font_size_override("font_size", title_font_size())
	_subtitle.visible = not narrow
	if is_instance_valid(_body):
		# Em compact/medium a soma dos mínimos da lista e do detalhe ultrapassa a
		# coluna útil (720px físicos deixam 592px após as margens de página). Empilhar
		# aqui evita que o mínimo horizontal do corpo alargue a página inteira.
		_body.vertical = narrow
	var path_size := _path_font_size()
	for raw_index in _rows:
		var row: PanelContainer = _rows[raw_index]
		if is_instance_valid(row) and row.has_meta("path"):
			var path_label: Label = row.get_meta("path")
			if is_instance_valid(path_label):
				path_label.add_theme_font_size_override("font_size", path_size)
	if is_instance_valid(_footer):
		_footer.vertical = narrow
		_body.update_minimum_size()
		_footer.update_minimum_size()
		_footer.add_theme_constant_override("separation",
			Design.SPACE_SM if narrow else Design.SPACE_XL)
	if narrow != _last_narrow:
		_last_narrow = narrow
		_refresh_rows()
	for block in [_mount_block, _back_block]:
		ScreenKit.set_action_density(block, narrow)
	_sync_scroll_hint()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_layout_mode()


# ── relatório de transbordamento ──────────────────────────────────────

## Com container e autowrap a prosa não transborda por construção. O que ainda
## pode estourar é um rótulo de linha única: o caminho da fase, o rótulo de
## estado e a contagem de ondas, que dividem a largura de uma linha da lista.
func text_overflow_report() -> Array:
	var mono: Font = Design.FONT_MONO
	var metrics := _content_metrics()
	var inner: float = float(metrics.get("card_w", 300.0)) - float(Design.SPACE_LG) * 2.0
	var longest_path := ""
	for index in Game.story_stage_count():
		var path := str(Game.story_stage_def(index).get("path", ""))
		if path.length() > longest_path.length():
			longest_path = path
	var longest_state := ""
	for state in ["CLEARED", "CURRENT", "LOCKED"]:
		var label := state_label(str(state))
		if label.length() > longest_state.length():
			longest_state = label
	var path_w: float = Design.grotesk(Design.WEIGHT_BOLD).get_string_size(
		longest_path, HORIZONTAL_ALIGNMENT_LEFT, -1, _path_font_size()).x
	var state_w: float = mono.get_string_size(longest_state, HORIZONTAL_ALIGNMENT_LEFT, -1,
		Design.TEXT_MICRO).x
	# Ponto (4) + número (24) + as duas separações internas. `inner` já
	# desconta o padding da linha — somá-lo de novo aqui media o dobro.
	var marker_w := 4.0 + 24.0 + float(Design.SPACE_SM) + float(Design.SPACE_LG)
	var out: Array = []
	out.append({"id": "story_row", "fits": marker_w + path_w + state_w <= inner})
	out.append({"id": "story_state_labels", "fits": state_w <= 120.0})
	out.append({"id": "story_mount_action",
		"fits": Design.grotesk(Design.WEIGHT_HEAVY).get_string_size(
			mount_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x <= size.x * 0.6})
	return out

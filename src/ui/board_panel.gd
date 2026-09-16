class_name BoardPanel
extends Control

## Placar semanal, na mesma gramática editorial dos outros painéis.
##
## Ele é OPCIONAL por natureza: sem servidor configurado, ou com o servidor
## fora do ar, a tela diz isso em uma linha e o jogo segue igual. Um placar é
## companhia para um jogo single-player, nunca requisito dele.

signal back_pressed

var _title: Label
var _subtitle: Label
var _status: Label
var _rows_box: VBoxContainer
var _back_block: PanelContainer
var _week := 0
var _asked := false


func _ready() -> void:
	theme = UiTheme.shared()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	if not Board.board_loaded.is_connected(_on_board_loaded):
		Board.board_loaded.connect(_on_board_loaded)

func _build() -> void:
	# Chão OPACO, igual ao dos outros painéis. Um escurecimento translúcido
	# deixava o menu inteiro legível por baixo do placar, e as duas telas
	# disputavam a leitura.
	var ground := ColorRect.new()
	ground.color = Design.SURFACE
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)

	var page := MarginContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right"]:
		page.add_theme_constant_override(side, Design.SPACE_4XL)
	page.add_theme_constant_override("margin_top", Design.SPACE_2XL)
	page.add_theme_constant_override("margin_bottom", Design.SPACE_2XL)
	add_child(page)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", Design.SPACE_MD)
	page.add_child(col)

	_title = ScreenKit.grot(tr("BOARD_TITLE"), Design.TEXT_TITLE, Design.WEIGHT_BLACK, Design.TEXT_PRIMARY)
	col.add_child(_title)
	_subtitle = ScreenKit.mono("", Design.TEXT_CAPTION, Design.TEXT_MUTED)
	col.add_child(_subtitle)
	ScreenKit.rule(col, 0.22)
	ScreenKit.gap(col, Design.SPACE_MD)

	_status = ScreenKit.mono("", Design.TEXT_CAPTION, Design.TEXT_SECONDARY)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", Design.SPACE_XS)
	scroll.add_child(_rows_box)

	ScreenKit.rule(col, 0.14)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", Design.SPACE_XL)
	col.add_child(footer)
	_back_block = ScreenKit.action(tr("UI_BACK"), "" if Design.touch_input() else "[ESC]", "text",
		func() -> void: back_pressed.emit())
	footer.add_child(_back_block)

## Chamada pelo menu ao abrir. Pergunta ao servidor uma vez por abertura — um
## placar semanal não muda entre dois piscares de olho.
func refresh() -> void:
	_week = Game.week_number()
	# O plano vem da SEMANA, não do modo corrente: o placar é sobre o Weekly
	# mesmo quando quem está olhando acabou de jogar Classic.
	_subtitle.text = "%s // %s" % [Game.week_id(), Weekly.summary_for_week(_week)]
	_clear_rows()
	if not Board.is_valid_url(Board.url):
		_status.text = tr("SET_BOARD_STATE_URL")
		return
	_status.text = tr("BOARD_LOADING")
	_asked = true
	Board.fetch_board(_week)

func _clear_rows() -> void:
	for child in _rows_box.get_children():
		child.queue_free()

func _on_board_loaded(week: int, entries: Array) -> void:
	if not is_inside_tree() or not visible:
		return
	_asked = false
	_clear_rows()
	if entries.is_empty():
		_status.text = tr("BOARD_OFFLINE") if not Board.is_valid_url(Board.url) else tr("BOARD_EMPTY")
		return
	_status.text = ""
	_week = week
	for raw in entries:
		if not (raw is Dictionary):
			continue
		_rows_box.add_child(_row(raw))

## Uma linha: posição, nome, pontuação. O nome é de outra pessoa e chega pela
## rede, então entra como TEXTO puro num Label — nada de bbcode.
func _row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Design.SPACE_LG)
	row.custom_minimum_size.y = 30.0
	var rank := ScreenKit.mono("%02d" % int(entry.get("rank", 0)), Design.TEXT_CAPTION, Design.ACCENT)
	rank.custom_minimum_size.x = 44.0
	row.add_child(rank)
	var who := ScreenKit.mono(str(entry.get("name", "")), Design.TEXT_CAPTION, Design.TEXT_PRIMARY)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.clip_text = true
	row.add_child(who)
	var score := ScreenKit.mono("%07d" % int(entry.get("score", 0)), Design.TEXT_CAPTION, Design.TEXT_SECONDARY)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score.custom_minimum_size.x = 96.0
	row.add_child(score)
	return row

func entry_count() -> int:
	return _rows_box.get_child_count() if is_instance_valid(_rows_box) else 0

func status_text() -> String:
	return _status.text if is_instance_valid(_status) else ""

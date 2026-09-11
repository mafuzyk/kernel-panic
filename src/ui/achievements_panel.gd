class_name AchievementsPanel
extends Control

## Overlay de conquistas do menu.
##
## Primeira tela migrada para o design system (`src/ui/design/`). O layout usa
## containers em vez de offsets absolutos, e toda cor, tamanho e espaçamento
## vem de `Design` — nenhum número mágico.
##
## Corrige B1 da auditoria de 2026-09-11: este era o único dos quatro overlays
## com fundo translúcido (alpha 0.88), então o menu inteiro vazava por trás e
## colidia com as linhas de conquista. Os irmãos (bestiary, story, program)
## sempre pintaram fundo opaco. Agora o contrato de opacidade é o token
## `Design.SURFACE`.

const TacticalIconScript = preload("res://src/ui/tactical_icon.gd")

const ACHIEVEMENT_HINTS := {
	"first_blood": "Terminate your first daemon.",
	"boss_purge": "Take down a ROOT-class boss.",
	"chain_max": "Push the combo meter to its maximum multiplier.",
	"terminal_operator": "Grant a sudo heal in the terminal.",
	"integrity_restored": "Recover integrity after it drops.",
}

## Altura mínima de uma linha. Acompanha o alvo de clique do design system.
const ROW_HEIGHT := 52.0
const ICON_SIZE := 26.0

var _header: Label
var _row_controls: Array[Control] = []
var _backdrop: ColorRect
var _frame: MarginContainer


func _ready() -> void:
	theme = UiTheme.shared()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Game.achievement_unlocked.connect(_on_achievement_unlocked)
	resized.connect(_layout_frame)
	_build()


# ── dados (API consumida pelo harness) ────────────────────────────────

func achievement_rows() -> Array:
	var rows: Array = []
	for id in Game.ACHIEVEMENT_DEFS:
		rows.append({
			"id": str(id),
			"label": str(Game.ACHIEVEMENT_DEFS[id]),
			"unlocked": Game.achievements.has(id),
			"hint": str(ACHIEVEMENT_HINTS.get(id, "")),
		})
	return rows


func progress_header() -> String:
	var unlocked := 0
	for id in Game.ACHIEVEMENT_DEFS:
		if Game.achievements.has(id):
			unlocked += 1
	return tr("AWARDS_HEADER").format([unlocked, Game.ACHIEVEMENT_DEFS.size()])


## Retângulo do painel. Contrato de geometria verificado pelo autotest: precisa
## caber no viewport e manter no mínimo 240x220 mesmo em janela estreita.
func awards_panel_rect(viewport: Vector2) -> Rect2:
	var w: float = minf(Design.CONTENT_MAX_FORM, maxf(viewport.x - Design.SPACE_3XL, 240.0))
	# A altura acompanha o CONTEÚDO, limitada pelo espaço disponível. Antes era
	# sempre `viewport.y - 216`, o que em 1080p deixava ~500px de vazio abaixo
	# de cinco linhas.
	var rows := float(Game.ACHIEVEMENT_DEFS.size())
	var content := Design.SPACE_LG * 2.0 + Design.TEXT_SUBHEAD * Design.LEADING_NORMAL \
		+ Design.SPACE_LG + rows * ROW_HEIGHT + maxf(rows - 1.0, 0.0) * Design.SPACE_MD \
		+ Design.SPACE_LG * 2.0
	var available: float = maxf(viewport.y - 216.0, 220.0)
	var h: float = clampf(content, 220.0, available)
	return Rect2((viewport.x - w) * 0.5, 102.0, w, h)


func award_row_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for row in _row_controls:
		if row != null and is_instance_valid(row):
			out.append(Rect2(row.global_position, row.size))
	return out


## O fundo é OPACO por contrato — ver B1 no cabeçalho. Exposto para o autotest
## poder afirmar isso como comportamento em vez de procurar string no código.
func backdrop_opacity() -> float:
	return _backdrop.color.a if is_instance_valid(_backdrop) else 0.0


func refresh() -> void:
	_build()
	queue_redraw()


func _on_achievement_unlocked(_id: String, _label: String) -> void:
	if visible:
		refresh()


# ── construção ────────────────────────────────────────────────────────

func _build() -> void:
	for child in get_children():
		if child is Button:
			continue
		remove_child(child)
		child.queue_free()
	_row_controls.clear()

	# Fundo opaco de tela cheia. O nome AwardsDim vem da versão anterior e é
	# mantido para não quebrar referências externas; o que mudou é a opacidade.
	_backdrop = ColorRect.new()
	_backdrop.name = "AwardsDim"
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Design.SURFACE
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	_frame = MarginContainer.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		_frame.add_theme_constant_override(side, Design.SPACE_LG)
	add_child(_frame)

	var panel := Panel.new()
	panel.theme_type_variation = "TacticalPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", Design.SPACE_LG)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(col)

	_header = Label.new()
	_header.theme_type_variation = "SubheadLabel"
	_header.add_theme_color_override("font_color", Design.ACCENT)
	_header.text = progress_header()
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_header)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)

	var rows_box := VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", Design.SPACE_MD)
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows_box)

	for row in achievement_rows():
		var row_control := _make_row(row)
		_row_controls.append(row_control)
		rows_box.add_child(row_control)

	_layout_frame()


func _layout_frame() -> void:
	if not is_instance_valid(_frame):
		return
	var rect := awards_panel_rect(size)
	_frame.position = rect.position
	_frame.size = rect.size


## Uma linha de conquista. Desbloqueada usa o acento de sucesso e ganha ícone;
## bloqueada fica rebaixada e mostra a dica na mesma linha.
func _make_row(row: Dictionary) -> Control:
	var unlocked := bool(row.get("unlocked", false))
	var accent: Color = Design.SUCCESS if unlocked else Design.ACCENT_MUTED

	var shell := PanelContainer.new()
	shell.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := TacticalStyleBox.new()
	style.accent = accent
	style.fill_alpha = 0.06 if unlocked else 0.015
	style.rail_length = 48.0
	shell.add_theme_stylebox_override("panel", style)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", Design.SPACE_MD)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(line)

	# A coluna do ícone é SEMPRE reservada, mesmo bloqueada. Sem isso o texto
	# das linhas sem ícone começa mais à esquerda e a margem esquerda da lista
	# fica serrilhada.
	var icon_slot := Control.new()
	icon_slot.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(icon_slot)
	if unlocked:
		var icon: Control = TacticalIconScript.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_slot.add_child(icon)
		icon.call("configure", "check", Design.SUCCESS)

	var label := Label.new()
	label.theme_type_variation = "CaptionLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if unlocked:
		label.text = str(row.get("label", ""))
		label.add_theme_color_override("font_color", Design.SUCCESS)
	else:
		label.text = "%s  //  %s" % [str(row.get("label", "")), str(row.get("hint", ""))]
		label.add_theme_color_override("font_color", Design.TEXT_FAINT)
	line.add_child(label)

	return shell

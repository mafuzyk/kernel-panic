class_name AchievementsPanel
extends Control

## Conquistas na direção editorial/suíça do menu.
##
## O primeiro porte para `Design` ainda mantinha a gramática antiga: um grande
## `TacticalPanel` central e uma moldura angular por conquista. Esta versão usa
## a mesma linguagem de Program/Story/Bestiary: título grotesco, mono para a voz
## de sistema, espaço + réguas como estrutura e cor semântica só como marcador.

signal back_pressed

const ACHIEVEMENT_HINT_KEYS := {
	"first_blood": "AWARDS_HINT_FIRST_BLOOD",
	"boss_purge": "AWARDS_HINT_BOSS_PURGE",
	"chain_max": "AWARDS_HINT_CHAIN_MAX",
	"terminal_operator": "AWARDS_HINT_TERMINAL_OPERATOR",
	"integrity_restored": "AWARDS_HINT_INTEGRITY_RESTORED",
}

const ACHIEVEMENT_HINT_FALLBACKS := {
	"first_blood": "Terminate your first daemon.",
	"boss_purge": "Take down a ROOT-class boss.",
	"chain_max": "Push the combo meter to its maximum multiplier.",
	"terminal_operator": "Grant a sudo heal in the terminal.",
	"integrity_restored": "Recover integrity after it drops.",
}

const ROW_MIN_HEIGHT := Design.CLICK_TARGET_MIN + Design.SPACE_XL

var _header: Label
var _title: Label
var _subtitle: Label
var _scroll: ScrollContainer
var _rows_box: VBoxContainer
var _footer: BoxContainer
var _back_block: PanelContainer
var _hint: Label
var _row_controls: Array[Control] = []
var _backdrop: ColorRect


func _ready() -> void:
	theme = UiTheme.shared()
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not Game.achievement_unlocked.is_connected(_on_achievement_unlocked):
		Game.achievement_unlocked.connect(_on_achievement_unlocked)
	_build()
	_apply_layout_mode()


# ── conteúdo / contratos ─────────────────────────────────────────────

func title_text() -> String:
	return tr("AWARDS_TITLE")


func title_font_size() -> int:
	return Design.TEXT_HEADING if Design.breakpoint_for(size.x) == "compact" else Design.TEXT_TITLE


func achievement_rows() -> Array:
	var rows: Array = []
	for id in Game.ACHIEVEMENT_DEFS:
		rows.append({
			"id": str(id),
			"label": str(Game.ACHIEVEMENT_DEFS[id]),
			"unlocked": Game.achievements.has(id),
			"hint": _hint_text(str(id)),
		})
	return rows


func progress_header() -> String:
	var unlocked := 0
	for id in Game.ACHIEVEMENT_DEFS:
		if Game.achievements.has(id):
			unlocked += 1
	return tr("AWARDS_PROGRESS").format([unlocked, Game.ACHIEVEMENT_DEFS.size()])


func row_ink(id: String) -> Dictionary:
	var unlocked := Game.achievements.has(id)
	return {
		"title": Design.TEXT_PRIMARY if unlocked else Design.TEXT_SECONDARY,
		"marker": Design.SUCCESS if unlocked else Design.TEXT_GHOST,
		"body": Design.TEXT_SECONDARY if unlocked else Design.TEXT_MUTED,
		"status": Design.SUCCESS if unlocked else Design.TEXT_MUTED,
	}


func _hint_text(id: String) -> String:
	var key := str(ACHIEVEMENT_HINT_KEYS.get(id, ""))
	if key != "":
		var localized := tr(key)
		if localized != key:
			return localized
	return str(ACHIEVEMENT_HINT_FALLBACKS.get(id, ""))


## Mantido como API de compatibilidade. O "panel" agora é a página editorial,
## não uma caixa tática centralizada.
func awards_panel_rect(viewport: Vector2) -> Rect2:
	var w := maxf(viewport.x - float(Design.SPACE_4XL) * 2.0, 240.0)
	var h := maxf(viewport.y - float(Design.SPACE_2XL) * 2.0, 220.0)
	return Rect2(Design.SPACE_4XL, Design.SPACE_2XL, w, h)


func award_row_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for row in _row_controls:
		if row != null and is_instance_valid(row):
			out.append(Rect2(row.global_position, row.size))
	return out


func content_viewport_rect() -> Rect2:
	if is_instance_valid(_scroll):
		return Rect2(_scroll.global_position - global_position, _scroll.size)
	return Rect2()


func content_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for node in [_title, _subtitle, _header, _scroll, _footer]:
		if node != null and is_instance_valid(node) and node.is_visible_in_tree():
			out.append(Rect2(node.global_position, node.size))
	return out


func backdrop_opacity() -> float:
	return _backdrop.color.a if is_instance_valid(_backdrop) else 0.0


func refresh() -> void:
	_build()
	_apply_layout_mode()


func _on_achievement_unlocked(_id: String, _label: String) -> void:
	if visible:
		refresh()


func _process(_delta: float) -> void:
	if visible:
		_sync_scroll_hint()


# ── construção ───────────────────────────────────────────────────────

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_row_controls.clear()

	_backdrop = ColorRect.new()
	_backdrop.name = "AwardsDim"
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Design.SURFACE
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	var col := ScreenKit.page(self)
	ScreenKit.gap(col, Design.SPACE_LG)

	_title = ScreenKit.grot(title_text(), Design.TEXT_TITLE, Design.WEIGHT_BLACK, Design.TEXT_PRIMARY)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(_title)

	_subtitle = ScreenKit.mono(tr("AWARDS_SUBTITLE"), Design.TEXT_CAPTION, Design.TEXT_SECONDARY)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(_subtitle)

	_header = ScreenKit.mono(progress_header(), Design.TEXT_MICRO, Design.TEXT_MUTED)
	col.add_child(_header)

	ScreenKit.gap(col, Design.SPACE_XL)
	ScreenKit.rule(col)
	ScreenKit.gap(col, Design.SPACE_LG)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_scroll)

	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", Design.SPACE_SM)
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_rows_box)

	for row in achievement_rows():
		var row_control := _make_row(row)
		_row_controls.append(row_control)
		_rows_box.add_child(row_control)

	ScreenKit.gap(col, Design.SPACE_LG)
	ScreenKit.rule(col)
	ScreenKit.gap(col, Design.SPACE_MD)
	_build_footer(col)


func _build_footer(parent: Node) -> void:
	_footer = BoxContainer.new()
	_footer.add_theme_constant_override("separation", Design.SPACE_XL)
	parent.add_child(_footer)

	_back_block = ScreenKit.action(tr("UI_BACK"), "" if Design.touch_input() else "[ESC]", "text",
		func() -> void: back_pressed.emit())
	_footer.add_child(_back_block)
	ScreenKit.grow_h(_footer)

	_hint = ScreenKit.mono(Design.scroll_hint(Design.touch_input()), Design.TEXT_MICRO, Design.TEXT_FAINT)
	_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_footer.add_child(_hint)


func _make_row(row: Dictionary) -> Control:
	var id := str(row.get("id", ""))
	var unlocked := bool(row.get("unlocked", false))
	var ink := row_ink(id)

	var shell := PanelContainer.new()
	shell.custom_minimum_size = Vector2(0.0, ROW_MIN_HEIGHT)
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Design.SURFACE_RAISED if unlocked else Design.SURFACE_SUNKEN
	style.border_width_left = int(Design.STROKE_THICK)
	style.border_color = ink.get("marker", Design.TEXT_GHOST)
	style.content_margin_left = Design.SPACE_LG
	style.content_margin_right = Design.SPACE_LG
	style.content_margin_top = Design.SPACE_MD
	style.content_margin_bottom = Design.SPACE_MD
	shell.add_theme_stylebox_override("panel", style)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", Design.SPACE_LG)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(line)

	var state_mark := ScreenKit.mono("✓" if unlocked else "·", Design.TEXT_SUBHEAD,
		ink.get("marker", Design.TEXT_GHOST))
	state_mark.custom_minimum_size.x = Design.SPACE_XL
	state_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(state_mark)

	var text_col := VBoxContainer.new()
	text_col.add_theme_constant_override("separation", Design.SPACE_XS)
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(text_col)

	var title := ScreenKit.grot(str(row.get("label", "")), Design.TEXT_SUBHEAD,
		Design.WEIGHT_BOLD, ink.get("title", Design.TEXT_PRIMARY))
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_col.add_child(title)

	var hint := ScreenKit.mono(str(row.get("hint", "")), Design.TEXT_CAPTION,
		ink.get("body", Design.TEXT_FAINT))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_child(hint)

	var status := ScreenKit.mono(tr("AWARDS_UNLOCKED") if unlocked else tr("AWARDS_LOCKED"),
		Design.TEXT_MICRO, ink.get("status", Design.TEXT_MUTED))
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(status)

	shell.set_meta("title", title)
	shell.set_meta("hint", hint)
	shell.set_meta("status", status)
	shell.set_meta("id", id)
	return shell


func _apply_layout_mode() -> void:
	if not is_instance_valid(_title):
		return
	var step := Design.breakpoint_for(size.x)
	var narrow := step == "compact" or step == "medium"
	_title.add_theme_font_size_override("font_size", title_font_size())
	_subtitle.visible = not narrow
	if is_instance_valid(_back_block):
		ScreenKit.set_action_density(_back_block, narrow)
	_sync_scroll_hint()


func _sync_scroll_hint() -> void:
	if not is_instance_valid(_hint) or not is_instance_valid(_scroll):
		return
	var bar := _scroll.get_v_scroll_bar()
	var scrollable := bar != null and bar.max_value > bar.page
	_hint.visible = scrollable and Design.breakpoint_for(size.x) in ["wide", "ultra"]


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_layout_mode()


## O hint quebra linha por construção. O que precisamos garantir é que, no
## menor viewport suportado pelo harness, ainda exista coluna útil suficiente
## para uma palavra longa e o título de máquina não precise sair do card.
func text_overflow_report() -> Array:
	var page_w := maxf(size.x - float(Design.SPACE_4XL) * 2.0, 120.0)
	var inner := page_w - float(Design.SPACE_LG) * 2.0 \
		- float(Design.SPACE_XL) - float(Design.SPACE_LG) * 2.0
	var longest_title := "INTEGRITY_RESTORED"
	var title_w := Design.grotesk(Design.WEIGHT_BOLD).get_string_size(
		longest_title, HORIZONTAL_ALIGNMENT_LEFT, -1, Design.TEXT_SUBHEAD).x
	return [
		{"id": "awards_title", "fits": title_w <= maxf(inner, 120.0)},
		{"id": "awards_hint_wrap", "fits": inner >= 120.0},
	]

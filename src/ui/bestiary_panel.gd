class_name BestiaryPanel
extends Control

## Bestiário na direção editorial compartilhada.
##
## O painel antigo era inteiramente `_draw()`: molduras angulares em cada item,
## Orbitron pequeno, coordenadas absolutas e a cor de cada entidade espalhada por
## moldura, texto e detalhe. Esta versão usa a mesma gramática de Program/Story:
## containers, grotesca pesada para hierarquia, mono para voz de sistema, espaço
## e réguas no lugar de caixas, e cor de gameplay restrita a MARCADORES.

signal back_pressed

const ENTRIES := [
	{"id": "drone", "name": "DRONE", "desc": "basic corrupted process. dash through packs.", "threat": 50, "bugs": "swarms without a scheduler. forever."},
	{"id": "lancer", "name": "LANCER", "desc": "telegraphs then lunges. sidestep the line, punish the stagger.", "threat": 90, "bugs": "lunges in a straight line. sidestep = fix."},
	{"id": "spewer", "name": "SPEWER", "desc": "keeps distance, spits orbs. shoot the orbs down.", "threat": 110, "bugs": "orbs are shootable. it has not learned this."},
	{"id": "splitter", "name": "SPLITTER", "desc": "splits on death. kill it away from you.", "threat": 100, "bugs": "death is a fork(). plan accordingly."},
	{"id": "bulwark", "name": "BULWARK", "desc": "armored and slow. dash past, never hug.", "threat": 300, "bugs": "armor does not cover the back. or manners."},
	{"id": "trojan", "name": "TROJAN", "desc": "leaves corruption pools. do not swim.", "threat": 140, "bugs": "leaves pools. calls them 'features'."},
	{"id": "oom", "name": "OOM_KILLER", "desc": "steals your motes and runs. hunt it first.", "threat": 150, "bugs": "steals motes. returns nothing. ever."},
	{"id": "boss", "name": "ROOT DAEMON", "desc": "every variant has a tell. learn it. respect it.", "threat": 2500, "bugs": "segfaults reproduce. two of them."},
	{"id": "root", "name": "ROOT.exe", "desc": "splits at half integrity. track both processes.", "threat": 2500, "bugs": "forks once. both children are real."},
	{"id": "segfault", "name": "SEGFAULT", "desc": "glitches, teleports, then opens a lance line.", "threat": 5000, "bugs": "address is invalid. movement is not."},
	{"id": "bluescreen", "name": "BLUE SCREEN", "desc": "freezes systems and floods the arena with fan shots.", "threat": 7500, "bugs": "the error is blue. the projectiles are not."},
	{"id": "pagefault", "name": "PAGE FAULT", "desc": "pages shield it until the orbiting nodes are purged.", "threat": 10000, "bugs": "read protection enabled. delete the pages."},
	{"id": "recursor", "name": "RECURSOR", "desc": "teleports and leaves corruption. pools mark where it was. keep moving.", "threat": 140, "bugs": "leaves corruption where it *was*. check behind you."},
	{"id": "firewall", "name": "FIREWALL", "desc": "rotating wall of orbs. kill the wall to drop the wall.", "threat": 180, "bugs": "wall persists after death of nearby processes."},
	{"id": "update_loop", "name": "UPDATE_LOOP", "desc": "reinstalls once after death. finish the update before celebrating.", "threat": 190, "bugs": "dies, says 'reinstalling', returns with fewer excuses."},
	{"id": "bloatware", "name": "BLOATWARE", "desc": "fat process. drops static popup orbs and spawns background drones.", "threat": 450, "bugs": "47 background processes terminated on exit."},
	{"id": "god", "name": "GOD", "desc": "oracle process. chooses its next attack by literal random roll.", "threat": 777, "bugs": "the attack pattern is not a pattern. it is a result."},
	{"id": "zombie", "name": "ZOMBIE", "desc": "dies into a defunct husk. shoot it again to reap it, or it comes back.", "threat": 150, "bugs": "exit status never collected. parent is busy."},
	{"id": "cron", "name": "CRON", "desc": "schedules reinforcements on a visible clock. kill it to clear the table.", "threat": 200, "bugs": "runs on time. that is the whole problem."},
	{"id": "swap", "name": "SWAP", "desc": "pulls you and loose motes toward it. dash ignores the well.", "threat": 320, "bugs": "thrashing. everything is slower and nothing is lost."},
	{"id": "beachball", "name": "BEACHBALL", "desc": "plants a spinning wheel under you. it does not hurt. the wave does.", "threat": 170, "bugs": "not responding. also not leaving."},
	{"id": "genius", "name": "GENIUS", "desc": "lancer that blinks to a better angle when you dodge too early.", "threat": 160, "bugs": "corrects your aim. was not asked to."},
	{"id": "kernel_task", "name": "KERNEL_TASK", "desc": "flips the field's colors mid-dodge and prints its stack at you.", "threat": 9000, "bugs": "you need to restart your computer."},
]

const ROW_HEIGHT := 68.0
const ROW_GLYPH := 42.0
const DETAIL_GLYPH := 96.0
const LIST_RATIO := 0.42

var scroll_y := 0.0
var _selected_id := ""
var _card_rects: Dictionary = {}
var _rows: Dictionary = {}
var _last_color_assist := false

var _title: Label
var _subtitle: Label
var _progress: Label
var _body: BoxContainer
var _scroll: ScrollContainer
var _rows_box: VBoxContainer
var _detail_scroll: ScrollContainer
var _detail: VBoxContainer
var _footer: BoxContainer
var _back_block: PanelContainer
var _hint: Label
var _detail_assist_label: Label


func _init() -> void:
	if not ENTRIES.is_empty():
		_selected_id = str(ENTRIES[0]["id"])


func _ready() -> void:
	theme = UiTheme.shared()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_last_color_assist = Sfx.color_assist
	_build()
	_apply_layout_mode()
	visibility_changed.connect(func() -> void:
		if visible:
			refresh(false)
	)


# ── conteúdo / contratos públicos ─────────────────────────────────────

func title_text() -> String:
	return tr("BESTIARY_TITLE")


func title_font_size() -> int:
	return Design.TEXT_HEADING if Design.breakpoint_for(size.x) == "compact" or Design.touch_input() else Design.TEXT_TITLE


static func entry_color(id: String) -> Color:
	match id:
		"drone": return Balance.COL_DRONE
		"lancer": return Balance.COL_LANCER
		"spewer": return Balance.COL_SPEWER
		"splitter", "bulwark": return Balance.threat_color(id, Sfx.color_assist)
		"trojan": return Color("c23a5e")
		"oom": return Color("9a4dff")
		"boss", "root": return Color("ff3d81")
		"segfault": return Color("ff9a3d")
		"bluescreen": return Color("4f8cff")
		"pagefault": return Color("b46bff")
		"recursor": return Color("52ff7a")
		"firewall": return Color("37d8ff")
		"update_loop": return Color("67b8ff")
		"bloatware": return Color("4b9ee8")
		_: return Design.TEXT_PRIMARY


func _entry_color(id: String) -> Color:
	return entry_color(id)


func entry_ink(id: String) -> Dictionary:
	var seen := Game.bestiary_seen(id)
	return {
		"title": Design.TEXT_PRIMARY if seen else Design.TEXT_FAINT,
		"marker": entry_color(id),
		"body": Design.TEXT_SECONDARY if seen else Design.TEXT_GHOST,
		"meta": Design.TEXT_MUTED if seen else Design.TEXT_GHOST,
	}


func assist_marker_text(id: String) -> String:
	if not Sfx.color_assist:
		return ""
	match id:
		"splitter": return "SPLIT"
		"bulwark": return "BULW"
		_: return ""


func select_entry(id: String) -> bool:
	if _entry_for(id).is_empty():
		return false
	_selected_id = id
	_refresh_rows()
	_fill_detail()
	return true


func detail_entry_id() -> String:
	return _selected_id


func entry_status(id: String) -> String:
	return tr("BESTIARY_STATUS_LOGGED") if Game.bestiary_seen(id) else tr("BESTIARY_STATUS_LOCKED")


func scroll_hint_text() -> String:
	return Design.scroll_hint(Design.touch_input())


func glyph_kinds() -> Array[String]:
	var out: Array[String] = []
	for entry in ENTRIES:
		out.append(str(entry["id"]))
	return out


func refresh(reset_scroll: bool = false) -> void:
	if reset_scroll:
		_scroll_to(0.0)
	_refresh_progress()
	_refresh_rows()
	_fill_detail()
	_apply_layout_mode()


# ── geometria consumida pelo autotest ─────────────────────────────────

func content_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for node in [_title, _subtitle, _progress, _body, _footer, _back_block]:
		if node != null and is_instance_valid(node) and node.is_visible_in_tree():
			out.append(Rect2(node.global_position - global_position, node.size))
	return out


func content_viewport_rect() -> Rect2:
	if is_instance_valid(_scroll):
		return Rect2(_scroll.global_position - global_position, _scroll.size)
	return Rect2()


func visible_card_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var viewport := content_viewport_rect()
	for raw_rect in _card_rects.values():
		var rect: Rect2 = raw_rect
		if viewport.encloses(rect):
			out.append(rect)
	return out


func _sync_card_rects() -> void:
	_card_rects.clear()
	for raw_id in _rows:
		var row: Control = _rows[raw_id]
		if is_instance_valid(row):
			_card_rects[str(raw_id)] = Rect2(row.global_position - global_position, row.size)


func _process(_delta: float) -> void:
	if not visible:
		return
	_sync_card_rects()
	_stretch_scroll_children()
	_sync_scroll_hint()
	if is_instance_valid(_scroll):
		scroll_y = float(_scroll.scroll_vertical)
	if _last_color_assist != Sfx.color_assist:
		_last_color_assist = Sfx.color_assist
		_refresh_rows()
		_fill_detail()


# ── entrada ────────────────────────────────────────────────────────────

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
			_scroll_to(scroll_y - ROW_HEIGHT)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_scroll_to(scroll_y + ROW_HEIGHT)
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


func _select_at(position: Vector2) -> void:
	_sync_card_rects()
	for raw_id in _card_rects:
		var id := str(raw_id)
		if _card_rects[id].has_point(position):
			if select_entry(id):
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
	ScreenKit.gap(col, Design.SPACE_LG)

	_title = ScreenKit.grot(title_text(), Design.TEXT_TITLE, Design.WEIGHT_BLACK, Design.TEXT_PRIMARY)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(_title)
	_subtitle = ScreenKit.mono(tr("BESTIARY_SUBTITLE"), Design.TEXT_CAPTION, Design.TEXT_SECONDARY)
	col.add_child(_subtitle)
	ScreenKit.gap(col, Design.SPACE_SM)
	_progress = ScreenKit.mono("", Design.TEXT_MICRO, Design.TEXT_MUTED)
	col.add_child(_progress)

	ScreenKit.gap(col, Design.SPACE_XL)
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

	for entry in ENTRIES:
		var id := str(entry["id"])
		var row := _make_row(entry)
		_rows[id] = row
		_rows_box.add_child(row)

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

	_footer = BoxContainer.new()
	_footer.add_theme_constant_override("separation", Design.SPACE_XL)
	col.add_child(_footer)
	_back_block = ScreenKit.action(tr("UI_BACK"), "" if Design.touch_input() else "[ESC]", "text", func() -> void: back_pressed.emit())
	_footer.add_child(_back_block)
	ScreenKit.grow_h(_footer)
	_hint = ScreenKit.mono(scroll_hint_text(), Design.TEXT_MICRO, Design.TEXT_FAINT)
	_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_footer.add_child(_hint)

	_refresh_progress()
	_refresh_rows()
	_fill_detail()


func _make_row(entry: Dictionary) -> PanelContainer:
	var id := str(entry["id"])
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", Design.SPACE_LG)
	pad.add_theme_constant_override("margin_right", Design.SPACE_LG)
	pad.add_theme_constant_override("margin_top", Design.SPACE_SM)
	pad.add_theme_constant_override("margin_bottom", Design.SPACE_SM)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pad)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", Design.SPACE_MD)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(line)

	var glyph := ScreenKit.glyph(id, entry_color(id), ROW_GLYPH, true)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(glyph)

	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(names)
	var name_label := ScreenKit.grot("", 20, Design.WEIGHT_BOLD, Design.TEXT_PRIMARY)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(name_label)
	var status_label := ScreenKit.mono("", Design.TEXT_MICRO, Design.TEXT_MUTED)
	names.add_child(status_label)

	var points := ScreenKit.mono("", Design.TEXT_MICRO, Design.TEXT_MUTED)
	points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	points.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(points)

	var hit := Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_ALL
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.add_theme_stylebox_override("focus", _focus_ring())
	var glow := StyleBoxFlat.new()
	glow.bg_color = Design.alpha(Design.TEXT_PRIMARY, 0.06)
	hit.add_theme_stylebox_override("hover", glow)
	hit.pressed.connect(func() -> void:
		if select_entry(id):
			Sfx.play("ui", 1.05, -8.0)
	)
	row.add_child(hit)
	ScreenKit.bind_feedback(hit, name_label)

	row.set_meta("glyph", glyph)
	row.set_meta("name", name_label)
	row.set_meta("status", status_label)
	row.set_meta("points", points)
	return row


static func _focus_ring() -> StyleBoxFlat:
	var ring := StyleBoxFlat.new()
	ring.bg_color = Color(0, 0, 0, 0)
	ring.border_width_left = int(Design.FOCUS_RING_WIDTH)
	ring.border_width_right = int(Design.FOCUS_RING_WIDTH)
	ring.border_width_top = int(Design.FOCUS_RING_WIDTH)
	ring.border_width_bottom = int(Design.FOCUS_RING_WIDTH)
	ring.border_color = Design.FOCUS_RING_COLOR
	return ring


# ── estados e detalhe ─────────────────────────────────────────────────

func _entry_for(id: String) -> Dictionary:
	for entry in ENTRIES:
		if str(entry.get("id")) == id:
			return entry
	return {}

## Prosa da entrada no idioma atual. O inglês do ENTRIES é o fallback quando
## a chave ainda não existe no CSV — nunca exibir a chave crua.
func _entry_text(entry: Dictionary, field: String) -> String:
	var key := "BEST_%s_%s" % [field.to_upper(), str(entry.get("id", "")).to_upper()]
	var translated := tr(key)
	if translated == key:
		return str(entry.get(field.to_lower(), ""))
	return translated


func _refresh_progress() -> void:
	if is_instance_valid(_progress):
		_progress.text = tr("BESTIARY_PROGRESS").format([Game.bestiary.size(), ENTRIES.size()])


func _refresh_rows() -> void:
	for raw_id in _rows:
		var id := str(raw_id)
		var row: PanelContainer = _rows[raw_id]
		if not is_instance_valid(row):
			continue
		var entry := _entry_for(id)
		var seen := Game.bestiary_seen(id)
		var selected := id == _selected_id
		var ink := entry_ink(id)

		var box := StyleBoxFlat.new()
		box.bg_color = Design.SURFACE_RAISED if selected else Design.SURFACE_SUNKEN
		box.border_width_left = int(Design.STROKE_THICK) if selected else 0
		box.border_color = ink.get("marker", Design.ACCENT)
		row.add_theme_stylebox_override("panel", box)

		_set_row_label(row, "name", ink.get("title", Design.TEXT_PRIMARY),
			str(entry.get("name", id.to_upper())) if seen else tr("BESTIARY_UNKNOWN_PROCESS"))
		_set_row_label(row, "status", ink.get("meta", Design.TEXT_MUTED), entry_status(id))
		_set_row_label(row, "points", ink.get("meta", Design.TEXT_MUTED),
			tr("BESTIARY_POINTS").format([int(entry.get("threat", 0))]) if seen else "—")
		if row.has_meta("glyph"):
			ScreenKit.set_glyph_tint(row.get_meta("glyph"),
				ink.get("marker", Design.ACCENT) if seen else Design.TEXT_GHOST)
	_refresh_progress()


func _set_row_label(row: PanelContainer, key: String, color: Color, text: String) -> void:
	if not row.has_meta(key):
		return
	var label: Label = row.get_meta(key)
	if not is_instance_valid(label):
		return
	label.add_theme_color_override("font_color", color)
	label.text = text


func _fill_detail() -> void:
	if not is_instance_valid(_detail):
		return
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()

	var entry := _entry_for(_selected_id)
	if entry.is_empty() and not ENTRIES.is_empty():
		entry = ENTRIES[0]
		_selected_id = str(entry["id"])
	var id := str(entry.get("id", "drone"))
	var seen := Game.bestiary_seen(id)
	var accent := entry_color(id)

	_detail.add_child(ScreenKit.mono(
		tr("BESTIARY_DETAIL_TAG").format([tr("BESTIARY_STATUS_LOGGED") if seen else tr("BESTIARY_LOCKED_SHORT")]),
		Design.TEXT_MICRO, accent if seen else Design.TEXT_MUTED))
	ScreenKit.gap(_detail, Design.SPACE_SM)

	var title := ScreenKit.grot(
		str(entry.get("name", id.to_upper())) if seen else tr("BESTIARY_UNKNOWN_PROCESS"),
		34, Design.WEIGHT_BLACK, Design.TEXT_PRIMARY if seen else Design.TEXT_FAINT)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail.add_child(title)
	ScreenKit.gap(_detail, Design.SPACE_XS)

	_detail_assist_label = ScreenKit.mono(assist_marker_text(id), Design.TEXT_MICRO, accent)
	_detail_assist_label.visible = _detail_assist_label.text != ""
	_detail.add_child(_detail_assist_label)

	ScreenKit.gap(_detail, Design.SPACE_LG)
	ScreenKit.rule(_detail)
	ScreenKit.gap(_detail, Design.SPACE_LG)

	var identity_row := HBoxContainer.new()
	identity_row.add_theme_constant_override("separation", Design.SPACE_XL)
	identity_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_child(identity_row)
	var portrait := ScreenKit.glyph(id, accent if seen else Design.TEXT_GHOST, DETAIL_GLYPH, true)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity_row.add_child(portrait)
	var stat := VBoxContainer.new()
	stat.add_theme_constant_override("separation", Design.SPACE_XS)
	stat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity_row.add_child(stat)
	stat.add_child(ScreenKit.mono(tr("BESTIARY_THREAT_LEVEL"), Design.TEXT_MICRO, Design.TEXT_MUTED))
	stat.add_child(ScreenKit.grot(
		str(int(entry.get("threat", 0))) if seen else "???",
		Design.TEXT_HEADING, Design.WEIGHT_BLACK, Design.TEXT_PRIMARY if seen else Design.TEXT_FAINT))
	stat.add_child(ScreenKit.mono(tr("BESTIARY_POINTS_UNIT"), Design.TEXT_MICRO, accent if seen else Design.TEXT_GHOST))

	ScreenKit.gap(_detail, Design.SPACE_LG)
	_detail.add_child(ScreenKit.mono(tr("BESTIARY_BEHAVIOR"), Design.TEXT_MICRO, Design.TEXT_MUTED))
	ScreenKit.gap(_detail, Design.SPACE_SM)
	var desc := ScreenKit.mono(
		"> " + (_entry_text(entry, "DESC") if seen else tr("BESTIARY_LOCKED_BODY")),
		Design.TEXT_CAPTION, Design.TEXT_SECONDARY if seen else Design.TEXT_GHOST)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail.add_child(desc)

	ScreenKit.gap(_detail, Design.SPACE_LG)
	_detail.add_child(ScreenKit.mono(tr("BESTIARY_BUG_REPORT"), Design.TEXT_MICRO, Design.TEXT_MUTED))
	ScreenKit.gap(_detail, Design.SPACE_SM)
	var bugs := ScreenKit.mono(
		"> " + (_entry_text(entry, "BUGS") if seen else tr("BESTIARY_LOCKED_NOTES")),
		Design.TEXT_CAPTION, Design.TEXT_FAINT if seen else Design.TEXT_GHOST)
	bugs.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail.add_child(bugs)


# ── layout responsivo ─────────────────────────────────────────────────

func _sync_scroll_hint() -> void:
	if not is_instance_valid(_hint) or not is_instance_valid(_scroll):
		return
	var bar := _scroll.get_v_scroll_bar()
	var scrollable := bar != null and bar.max_value > bar.page
	_hint.visible = scrollable and Design.breakpoint_for(size.x) in ["wide", "ultra"]


func _stretch_scroll_children() -> void:
	# Não fixe o mínimo ao tamanho atual do ScrollContainer. O harness redimensiona
	# o MESMO painel de 1920 -> 1366 -> 720 -> 432; copiar a largura anterior para
	# `custom_minimum_size` criava um ciclo de mínimo que impedia a página de
	# encolher. Com scroll horizontal desativado + EXPAND_FILL, o próprio
	# ScrollContainer estica o filho ao viewport sem esse estado pegajoso.
	if is_instance_valid(_rows_box):
		_rows_box.custom_minimum_size.x = 0.0
	if is_instance_valid(_detail):
		_detail.custom_minimum_size.x = 0.0


func _apply_layout_mode() -> void:
	if not is_instance_valid(_title):
		return
	var step := Design.breakpoint_for(size.x)
	var narrow := step == "compact" or step == "medium" or Design.touch_input()
	_title.add_theme_font_size_override("font_size", title_font_size())
	_subtitle.visible = step != "compact"
	if is_instance_valid(_body):
		_body.vertical = narrow
		_body.update_minimum_size()
		_body.add_theme_constant_override("separation", Design.SPACE_MD if narrow else Design.SPACE_XL)
	if is_instance_valid(_back_block):
		ScreenKit.set_action_density(_back_block, narrow)
	for raw_id in _rows:
		var row: PanelContainer = _rows[raw_id]
		if is_instance_valid(row) and row.has_meta("points"):
			var points: Label = row.get_meta("points")
			if is_instance_valid(points):
				points.visible = not narrow
	_stretch_scroll_children()
	_sync_scroll_hint()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_layout_mode()


# ── relatório de transbordamento ──────────────────────────────────────

func text_overflow_report() -> Array:
	var page_w := maxf(size.x - float(Design.SPACE_4XL) * 2.0, 160.0)
	var step := Design.breakpoint_for(size.x)
	var narrow := step == "compact" or step == "medium"
	var detail_w := page_w if narrow else (page_w - float(Design.SPACE_XL)) * (1.0 - LIST_RATIO)
	var detail_inner := maxf(detail_w - float(Design.SPACE_XL) * 2.0, 0.0)
	var row_inner := maxf((page_w if narrow else (page_w - float(Design.SPACE_XL)) * LIST_RATIO) - float(Design.SPACE_LG) * 2.0, 0.0)
	return [
		{"id": "glyph_contained", "fits": DETAIL_GLYPH <= detail_inner},
		{"id": "bestiary_detail_prose", "fits": detail_inner >= 160.0},
		{"id": "bestiary_row", "fits": row_inner >= ROW_GLYPH + float(Design.SPACE_MD) + 120.0},
	]

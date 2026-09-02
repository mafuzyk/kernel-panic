class_name VNextBestiarySurface
extends Control

const Context = preload("res://src/ui/vnext/ui_context.gd")
const Layout = preload("res://src/ui/vnext/ui_layout.gd")
const Tokens = preload("res://src/ui/vnext/ui_tokens.gd")
const Illustration = preload("res://src/ui/vnext/entity_illustration.gd")
const ContentCatalog = preload("res://src/data/content_catalog.gd")
const Balance = preload("res://src/autoload/balance.gd")
const Orbitron: Font = preload("res://assets/fonts/Orbitron.ttf")
const ShareTechMono: Font = preload("res://assets/fonts/ShareTechMono.ttf")

signal action_requested(action_id: String, payload: Dictionary)

var context: RefCounted
var snapshot := {}
var _layout := {}
var _entries: Array = ContentCatalog.BESTIARY_ENTRIES
var _selected := "drone"
var _focus := "drone"
var _narrow_detail := false
var _buttons := {}
var _illustration: Control
var activation_count := 0
var last_action_id := ""
var _gui_event_ids := {}

static func context_for_viewport(viewport: Vector2, touch := false, reduced := false, contrast := false, scale := 1.0) -> RefCounted:
	return Context.from_viewport(viewport, touch, reduced, contrast, scale)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scroll := ScrollContainer.new()
	scroll.name = "BestiaryScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "BestiaryList"
	list.add_theme_constant_override("separation", 4)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(list)
	for entry in _entries:
		var id := str(entry.get("id", ""))
		var button := Button.new()
		button.name = id
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.flat = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_override("font", ShareTechMono)
		_style_action_button(button, 30.0)
		button.pressed.connect(_on_entry_pressed.bind(id))
		button.focus_entered.connect(_on_entry_focus.bind(id))
		button.gui_input.connect(_on_button_gui_input)
		list.add_child(button)
		_buttons[id] = button
	for spec in [["back", "BackAction", "< BACK", 18.0], ["list_view", "ListAction", "< FIELD INDEX", 18.0]]:
		var button := Button.new()
		button.name = spec[1]
		button.text = spec[2]
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.flat = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_override("font", ShareTechMono)
		_style_action_button(button, 18.0)
		button.add_theme_font_size_override("font_size", spec[3])
		button.gui_input.connect(_on_button_gui_input)
		button.pressed.connect(_on_aux_pressed.bind(spec[0]))
		add_child(button)
		_buttons[spec[0]] = button

func _style_action_button(button: Button, left_margin: float) -> void:
	button.add_theme_color_override("font_color", Tokens.role_color("structure"))
	button.add_theme_color_override("font_hover_color", Tokens.role_color("focus"))
	button.add_theme_color_override("font_focus_color", Tokens.role_color("focus"))
	button.add_theme_color_override("font_pressed_color", Tokens.role_color("focus"))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		style.content_margin_left = left_margin
		style.content_margin_right = 12.0
		button.add_theme_stylebox_override(state, style)

func configure(next_snapshot: Dictionary, next_context: RefCounted) -> void:
	var was_narrow: bool = context != null and context.density == "narrow"
	var previous_view: bool = _narrow_detail
	snapshot = next_snapshot.duplicate(true)
	context = next_context
	_narrow_detail = previous_view if was_narrow and context.density == "narrow" else context.density != "narrow"
	_selected = str(snapshot.get("selected", _selected))
	if _find_entry(_selected).is_empty():
		_selected = str(_entries[0].get("id", "drone"))
	_focus = _selected
	_layout = Layout.selection(context.viewport_size, context)
	_apply_layout()
	_update_buttons()
	queue_redraw()

func _find_entry(id: String) -> Dictionary:
	for entry in _entries:
		if str(entry.get("id", "")) == id:
			return entry
	return {}

func _apply_layout() -> void:
	if _layout.is_empty():
		return
	var scroll: ScrollContainer = _buttons["drone"].get_parent().get_parent()
	var list: VBoxContainer = scroll.get_node("BestiaryList")
	scroll.position = _layout["list"].position + Vector2(0.0, 38.0)
	scroll.size = Vector2(_layout["list"].size.x, maxf(0.0, _layout["list"].size.y - 38.0))
	list.size = Vector2(_layout["list"].size.x, maxf(_layout["list"].size.y - 38.0, _entries.size() * 48.0))
	var row_h := maxf(44.0, minf(52.0, float(list.size.y) / maxf(_entries.size(), 1)))
	for button in list.get_children():
		button.custom_minimum_size = Vector2(_layout["list"].size.x, row_h)
		button.add_theme_font_size_override("font_size", int(round((13.0 if context.density == "wide" else 12.0) * float(context.text_scale))))
	var back: Button = _buttons["back"]
	back.position = _layout["back"].position
	back.size = _layout["back"].size
	back.add_theme_font_size_override("font_size", int(round(14.0 * float(context.text_scale))))
	var list_view: Button = _buttons["list_view"]
	list_view.position = _layout["detail"].position + Vector2(14.0, maxf(0.0, _layout["detail"].size.y - 48.0))
	list_view.size = Vector2(minf(190.0, _layout["detail"].size.x), 40.0)
	list_view.add_theme_font_size_override("font_size", int(round(14.0 * float(context.text_scale))))
	if _illustration == null:
		_illustration = Illustration.new()
		add_child(_illustration)
	_illustration.visible = not bool(_layout["narrow"]) or _narrow_detail
	list.visible = not bool(_layout["narrow"]) or not _narrow_detail
	scroll.visible = list.visible
	list_view.visible = bool(_layout["narrow"]) and _narrow_detail
	_illustration.position = _layout["detail_illustration"].position
	_illustration.size = _layout["detail_illustration"].size
	_illustration.set_quality_profile("mobile" if context.input_mode == "touch" else "desktop", context.reduce_motion, context.high_contrast)
	var entry := _find_entry(_selected)
	_illustration.configure_entity(str(entry.get("glyph_key", "drone")), "ready" if Game.bestiary_seen(_selected) else "locked", "ENEMY")

func _update_buttons() -> void:
	for entry in _entries:
		var id := str(entry.get("id", ""))
		var button: Button = _buttons[id]
		var seen := Game.bestiary_seen(id)
		var selected := _selected == id
		button.text = ("> " if selected else "  ") + (str(entry.get("name", "UNKNOWN")) if seen else "UNKNOWN PROCESS")
		button.tooltip_text = (str(entry.get("name", "UNKNOWN")) if seen else "UNKNOWN PROCESS") + (" // LOGGED" if seen else " // LOCKED")
		button.add_theme_color_override("font_color", Tokens.role_color("focus") if selected else Tokens.role_color("structure") if seen else Tokens.role_color("muted"))
	if _illustration != null:
		var current := _find_entry(_selected)
		_illustration.configure_entity(str(current.get("glyph_key", "drone")), "ready" if Game.bestiary_seen(_selected) else "locked", "ENEMY")

func layout_snapshot() -> Dictionary:
	return {"density": context.density, "safe_rect": context.safe_rect, "regions": _layout.duplicate(true)}

func _button_rect(id: String) -> Rect2:
	var button: Button = _buttons[id]
	var list: VBoxContainer = button.get_parent()
	var scroll: ScrollContainer = list.get_parent()
	return Rect2(scroll.position + button.position, button.size)

func action_regions() -> Dictionary:
	var result := {"back": {"rect": _layout.get("back", Rect2()), "label": "BACK", "state": "idle"}}
	var list_view: Button = _buttons["list_view"]
	if bool(_layout.get("narrow", false)) and _narrow_detail:
		result["list_view"] = {"rect": Rect2(list_view.position, list_view.size), "label": "FIELD INDEX", "state": "idle"}
	else:
		var viewport := Rect2(_layout["list"].position + Vector2(0.0, 38.0), Vector2(_layout["list"].size.x, maxf(0.0, _layout["list"].size.y - 38.0)))
		for entry in _entries:
			var id := str(entry.get("id", ""))
			var rect := _button_rect(id)
			if not viewport.intersects(rect):
				continue
			result[id] = {"rect": rect, "label": str(entry.get("name", "UNKNOWN")), "state": "logged" if Game.bestiary_seen(id) else "locked"}
	return result

func text_overflow_report() -> Array:
	if context == null or _layout.is_empty():
		return [{"id": "surface", "fits": false, "measured_width": 0.0, "available_width": 0.0}]
	var scale := float(context.text_scale)
	var entry := _find_entry(_selected)
	var shell_text := "ONLINE KP://BESTIARY GUEST" if context.density == "narrow" else "SYSTEM ONLINE    KP://BESTIARY    USER: GUEST"
	var entries := [
		{"id": "shell_meta", "text": shell_text, "rect": _layout["shell_meta"], "size": 12, "inset": 8.0},
		{"id": "title", "text": "BESTIARY // FIELD DATA", "rect": _layout["header"], "size": _layout["title_size"], "inset": 0.0},
		{"id": "subtitle", "text": "SELECT A PROCESS. READ ITS BEHAVIOR AND COUNTERPLAY.", "rect": _layout["header"], "size": 13, "inset": 0.0},
		{"id": "footer", "text": "FIELD ENTRIES    LOGGED    BUILD 0.2.3", "rect": _layout["footer"], "size": 11, "inset": 8.0},
	]
	if not bool(_layout["narrow"]) or not _narrow_detail:
		for id in _entries:
			var key := str(id.get("id", ""))
			var button: Button = _buttons[key]
			var rect := _button_rect(key)
			if _layout["list"].intersects(rect):
				entries.append({"id": key, "text": str(button.text), "rect": rect, "size": 12})
	if not bool(_layout["narrow"]) or _narrow_detail:
		var text_rect: Rect2 = _layout["detail_text"]
		entries.append({"id": "detail_header", "text": "FIELD DOSSIER // " + ("LOGGED" if Game.bestiary_seen(_selected) else "LOCKED"), "rect": text_rect, "size": 11, "inset": 0.0})
		entries.append({"id": "detail_name", "text": str(entry.get("name", "UNKNOWN PROCESS")) if Game.bestiary_seen(_selected) else "UNKNOWN PROCESS", "rect": text_rect, "size": 21, "inset": 0.0})
		entries.append({"id": "detail_desc", "text": str(entry.get("desc", "PURGE THIS PROCESS TO REVEAL FIELD DATA.")), "rect": text_rect, "size": 13, "inset": 0.0})
		entries.append({"id": "detail_bugs", "text": str(entry.get("bugs", "FIELD NOTES LOCKED UNTIL FIRST SIGHTING.")), "rect": text_rect, "size": 12, "inset": 0.0})
	if bool(_layout["narrow"]) and _narrow_detail:
		entries.append({"id": "list_view", "text": str(_buttons["list_view"].text), "rect": _button_rect("list_view") if _buttons["list_view"].visible else _layout["detail"], "size": 14})
	entries.append({"id": "back", "text": str(_buttons["back"].text), "rect": _layout["back"], "size": 14})
	var report := []
	for item in entries:
		var font: Font = Orbitron if int(item["size"]) >= 20 else ShareTechMono
		var available := maxf(float(item["rect"].size.x) - float(item.get("inset", 0.0)), 0.0)
		var measured := font.get_multiline_string_size(str(item["text"]), HORIZONTAL_ALIGNMENT_LEFT, maxf(available, 1.0), int(round(float(item["size"]) * scale)))
		report.append({"id": item["id"], "fits": measured.x <= available and measured.y <= float(item["rect"].size.y), "measured_width": measured.x, "available_width": available})
	return report

func semantic_snapshot() -> Dictionary:
	var entry := _find_entry(_selected)
	return {
		"screen": "bestiary",
		"visual_system": "reference_shell",
		"route": "KP://BESTIARY",
		"selected": _selected,
		"identity": entry.get("name", "UNKNOWN PROCESS") if Game.bestiary_seen(_selected) else "UNKNOWN PROCESS",
		"seen": Game.bestiary_seen(_selected),
		"threat_class": entry.get("threat_class", "standard"),
		"counterplay": entry.get("desc", ""),
		"focus": _focus,
		"view": "detail" if not bool(_layout.get("narrow", false)) or _narrow_detail else "list",
		"composition": {"shell": "persistent", "list": "field_index", "detail": "behavior_dossier", "illustration": "enemy_identity", "footer": "telemetry"},
	}

func focus_id() -> String:
	return _focus

func set_focus_id(id: String) -> bool:
	if not _buttons.has(id) or not _buttons[id] is Button:
		return false
	_focus = id
	(_buttons[id] as Button).grab_focus()
	if _find_entry(id).is_empty() == false:
		_selected = id
		_update_buttons()
	queue_redraw()
	return true

func handle_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_DOWN, KEY_TAB]:
			return _step_focus(1)
		if event.keycode == KEY_UP:
			return _step_focus(-1)
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			return _dispatch(_focus)
		if event.keycode == KEY_ESCAPE:
			return _dispatch("back")
	elif event is InputEventMouseButton and event.pressed:
		return _dispatch(_action_at(event.position))
	elif event is InputEventScreenTouch and event.pressed:
		return _dispatch(_action_at(event.position))
	return false

func _unhandled_input(event: InputEvent) -> void:
	var event_id := event.get_instance_id()
	if _gui_event_ids.has(event_id):
		_gui_event_ids.erase(event_id)
		get_viewport().set_input_as_handled()
		return
	if handle_input(event):
		get_viewport().set_input_as_handled()

func _on_button_gui_input(event: InputEvent) -> void:
	_gui_event_ids[event.get_instance_id()] = true

func _action_at(point: Vector2) -> String:
	point = get_viewport().get_final_transform().affine_inverse() * point
	for id in action_regions():
		if (action_regions()[id]["rect"] as Rect2).has_point(point):
			return id
	return ""

func _focus_ids() -> Array:
	var ids: Array = []
	if bool(_layout.get("narrow", false)) and _narrow_detail:
		ids = ["list_view", "back"]
	else:
		for entry in _entries:
			ids.append(str(entry.get("id", "")))
		ids.append("back")
	return ids

func _step_focus(delta: int) -> bool:
	var ids := _focus_ids()
	var index := ids.find(_focus)
	if index < 0:
		index = 0
	return set_focus_id(ids[wrapi(index + delta, 0, ids.size())])

func _dispatch(id: String) -> bool:
	if id.is_empty():
		return false
	if _find_entry(id).is_empty() == false:
		_selected = id
		_focus = id
		if bool(_layout.get("narrow", false)):
			_narrow_detail = true
			_focus = "list_view"
		_apply_layout()
		_update_buttons()
		queue_redraw()
		return true
	if id == "list_view":
		_narrow_detail = false
		_focus = _selected
		_apply_layout()
		_update_buttons()
		queue_redraw()
		return true
	if id == "back":
		last_action_id = id
		activation_count += 1
		action_requested.emit(id, {})
		return true
	return false

func _on_entry_pressed(id: String) -> void:
	_dispatch(id)

func _on_entry_focus(id: String) -> void:
	_focus = id
	_selected = id
	_update_buttons()
	queue_redraw()

func _on_aux_pressed(id: String) -> void:
	_dispatch(id)

func _draw() -> void:
	if context == null or _layout.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, size), Tokens.role_color("background"))
	var shell: Rect2 = _layout["shell"]
	var structure := Tokens.role_color("structure")
	_draw_ambient_grid(shell)
	draw_polyline(Tokens.frame_points(shell, 16.0), structure, 1.5, true)
	_draw_shell_meta(_layout["shell_meta"])
	draw_string(Orbitron, _layout["header"].position, "BESTIARY // FIELD DATA", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(float(_layout["title_size"]) * context.text_scale)), Tokens.role_color("focus"))
	draw_string(ShareTechMono, _layout["header"].position + Vector2(0.0, 27.0), "SELECT A PROCESS. READ ITS BEHAVIOR AND COUNTERPLAY.", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(13.0 * context.text_scale)), Tokens.role_color("muted"))
	draw_line(_layout["header"].position + Vector2(0.0, _layout["header"].size.y - 8.0), _layout["header"].end - Vector2(0.0, 8.0), Color(structure.r, structure.g, structure.b, 0.32), 1.0, true)
	_draw_footer()
	if not bool(_layout["narrow"]) or not _narrow_detail:
		_draw_list()
	if not bool(_layout["narrow"]) or _narrow_detail:
		_draw_dossier()
	if _buttons["back"].visible:
		draw_polyline(Tokens.frame_points(_layout["back"], 8.0), Tokens.role_color("focus") if _focus == "back" else structure, 1.7 if _focus == "back" else 1.0, true)
	if _buttons["list_view"].visible:
		draw_polyline(Tokens.frame_points(Rect2(_buttons["list_view"].position, _buttons["list_view"].size), 8.0), Tokens.role_color("focus"), 1.3, true)

func _draw_ambient_grid(shell: Rect2) -> void:
	var color := Tokens.role_color("structure")
	var step := 48.0 if context.density == "wide" else 36.0
	var x := shell.position.x + step
	while x < shell.end.x:
		draw_line(Vector2(x, shell.position.y + 42.0), Vector2(x, shell.end.y - 30.0), Color(color.r, color.g, color.b, 0.03), 1.0, true)
		x += step
	var y := shell.position.y + 42.0
	while y < shell.end.y - 30.0:
		draw_line(Vector2(shell.position.x + 18.0, y), Vector2(shell.end.x - 18.0, y), Color(color.r, color.g, color.b, 0.03), 1.0, true)
		y += step

func _draw_shell_meta(rect: Rect2) -> void:
	var color := Tokens.role_color("structure")
	var font_size := int(round(12.0 * context.text_scale))
	if context.density == "narrow":
		draw_string(ShareTechMono, rect.position, "■ ONLINE", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		draw_string(ShareTechMono, rect.get_center() - Vector2(40.0, 0.0), "KP://BESTIARY", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		draw_string(ShareTechMono, rect.end - Vector2(42.0, 4.0), "GUEST", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	else:
		draw_string(ShareTechMono, rect.position, "■  SYSTEM ONLINE", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		draw_string(ShareTechMono, rect.get_center() - Vector2(64.0, 0.0), "KP://BESTIARY", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		draw_string(ShareTechMono, rect.end - Vector2(108.0, 4.0), "USER: GUEST", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	draw_line(rect.position + Vector2(146.0, -4.0), rect.position + Vector2(244.0, -4.0), Color(color.r, color.g, color.b, 0.5), 1.0, true)

func _draw_footer() -> void:
	var rect: Rect2 = _layout["footer"]
	var color := Tokens.role_color("muted")
	var accent := Tokens.role_color("structure")
	draw_line(rect.position, rect.end, Color(accent.r, accent.g, accent.b, 0.42), 1.0, true)
	draw_string(ShareTechMono, rect.position + Vector2(0.0, 17.0), "FIELD ENTRIES  %02d" % _entries.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(11.0 * context.text_scale)), accent)
	draw_string(ShareTechMono, rect.position + Vector2(142.0, 17.0), "LOGGED  %02d" % Game.bestiary.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(11.0 * context.text_scale)), color)
	draw_string(ShareTechMono, rect.position + Vector2(rect.size.x - 178.0, 17.0), "BUILD 0.2.3", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(11.0 * context.text_scale)), color)

func _draw_list() -> void:
	var rect: Rect2 = _layout["list"]
	var color := Tokens.role_color("structure")
	draw_colored_polygon(Tokens.frame_points(rect, 11.0), Color(color.r, color.g, color.b, 0.025))
	draw_polyline(Tokens.frame_points(rect, 11.0) + PackedVector2Array([Tokens.frame_points(rect, 11.0)[0]]), Color(color.r, color.g, color.b, 0.62), 1.1, true)
	draw_string(ShareTechMono, rect.position + Vector2(18.0, 24.0), "FIELD INDEX // LOGGED PROCESSES", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(11.0 * context.text_scale)), color)
	draw_line(rect.position + Vector2(18.0, 34.0), rect.end - Vector2(18.0, rect.size.y - 34.0), Color(color.r, color.g, color.b, 0.26), 1.0, true)
	var viewport := Rect2(rect.position + Vector2(0.0, 38.0), Vector2(rect.size.x, maxf(0.0, rect.size.y - 38.0)))
	for entry in _entries:
		var id := str(entry.get("id", ""))
		var button: Button = _buttons[id]
		var row := _button_rect(id)
		if not viewport.intersects(row):
			continue
		var seen := Game.bestiary_seen(id)
		var selected := _selected == id
		var row_color := Tokens.role_color("focus") if selected else color if seen else Tokens.role_color("muted")
		if selected:
			draw_colored_polygon(Tokens.frame_points(row.grow(-2.0), 6.0), Color(row_color.r, row_color.g, row_color.b, 0.08))
		draw_line(row.position + Vector2(12.0, row.size.y - 1.0), row.end - Vector2(12.0, 1.0), Color(row_color.r, row_color.g, row_color.b, 0.2), 1.0, true)
		var marker := row.position + Vector2(16.0, row.size.y * 0.5)
		if selected:
			draw_colored_polygon(PackedVector2Array([marker + Vector2(-5.0, 0.0), marker + Vector2(4.0, -5.0), marker + Vector2(4.0, 5.0)]), row_color)
		else:
			draw_rect(Rect2(marker - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), Color(row_color.r, row_color.g, row_color.b, 0.6), false, 1.0)
		draw_string(ShareTechMono, row.end - Vector2(78.0, row.size.y * 0.5 - 3.0), "LOGGED" if seen else "LOCKED", HORIZONTAL_ALIGNMENT_RIGHT, 62.0, int(round(10.0 * context.text_scale)), row_color)

func _entry_color(entry: Dictionary) -> Color:
	match str(entry.get("id", "")):
		"drone": return Balance.COL_DRONE
		"lancer": return Balance.COL_LANCER
		"spewer": return Balance.COL_SPEWER
		"oom": return Color("9d72ff")
		"recursor": return Color("52ff7a")
		"firewall": return Color("37d8ff")
		"god": return Tokens.role_color("warning")
		"boss", "root", "segfault", "bluescreen", "pagefault", "permission_root": return Tokens.role_color("danger")
		_: return Tokens.role_color("structure")

func _draw_dossier() -> void:
	var rect: Rect2 = _layout["detail"]
	var color := _entry_color(_find_entry(_selected))
	var structure := Tokens.role_color("structure")
	draw_colored_polygon(Tokens.frame_points(rect, 11.0), Color(color.r, color.g, color.b, 0.018))
	draw_polyline(Tokens.frame_points(rect, 11.0) + PackedVector2Array([Tokens.frame_points(rect, 11.0)[0]]), Color(color.r, color.g, color.b, 0.72), 1.2, true)
	draw_string(ShareTechMono, rect.position + Vector2(18.0, 24.0), "FIELD DOSSIER // %s" % ("LOGGED" if Game.bestiary_seen(_selected) else "LOCKED"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(11.0 * context.text_scale)), color)
	var illustration_rect: Rect2 = _layout["detail_illustration"]
	draw_colored_polygon(Tokens.frame_points(illustration_rect, 9.0), Color(color.r, color.g, color.b, 0.045))
	draw_polyline(Tokens.frame_points(illustration_rect, 9.0) + PackedVector2Array([Tokens.frame_points(illustration_rect, 9.0)[0]]), Color(color.r, color.g, color.b, 0.65), 1.0, true)
	draw_string(ShareTechMono, illustration_rect.position + Vector2(12.0, 18.0), "ENEMY IDENTITY", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(10.0 * context.text_scale)), color)
	draw_line(illustration_rect.get_center() - Vector2(illustration_rect.size.x * 0.42, 0.0), illustration_rect.get_center() + Vector2(illustration_rect.size.x * 0.42, 0.0), Color(color.r, color.g, color.b, 0.16), 1.0, true)
	draw_line(illustration_rect.get_center() - Vector2(0.0, illustration_rect.size.y * 0.32), illustration_rect.get_center() + Vector2(0.0, illustration_rect.size.y * 0.32), Color(color.r, color.g, color.b, 0.16), 1.0, true)
	var entry := _find_entry(_selected)
	var text_rect: Rect2 = _layout["detail_text"]
	draw_line(text_rect.position - Vector2(12.0, -2.0), Vector2(text_rect.position.x - 12.0, rect.end.y - 18.0), Color(structure.r, structure.g, structure.b, 0.28), 1.0, true)
	var seen := Game.bestiary_seen(_selected)
	var name := str(entry.get("name", "UNKNOWN PROCESS")) if seen else "UNKNOWN PROCESS"
	draw_string(Orbitron, text_rect.position, name, HORIZONTAL_ALIGNMENT_LEFT, text_rect.size.x, int(round(22.0 * context.text_scale)), Tokens.role_color("focus") if seen else Tokens.role_color("muted"))
	draw_string(ShareTechMono, text_rect.position + Vector2(0.0, 26.0), "THREAT CLASS  %s" % str(entry.get("threat_class", "standard")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, text_rect.size.x, int(round(11.0 * context.text_scale)), color)
	draw_string(ShareTechMono, text_rect.position + Vector2(0.0, 48.0), ("%d THREAT POINTS" % int(entry.get("threat", 0))) if seen else "PURGE THIS PROCESS TO REVEAL", HORIZONTAL_ALIGNMENT_LEFT, text_rect.size.x, int(round(11.0 * context.text_scale)), Color(color.r, color.g, color.b, 0.8 if seen else 0.42))
	draw_line(text_rect.position + Vector2(0.0, 60.0), Vector2(text_rect.end.x, text_rect.position.y + 60.0), Color(color.r, color.g, color.b, 0.28), 1.0, true)
	draw_string(ShareTechMono, text_rect.position + Vector2(0.0, 84.0), "BEHAVIOR", HORIZONTAL_ALIGNMENT_LEFT, text_rect.size.x, int(round(11.0 * context.text_scale)), color)
	var desc := "> " + (str(entry.get("desc", "")) if seen else "No field data available. First sighting unlocks this report.")
	draw_multiline_string(ShareTechMono, text_rect.position + Vector2(0.0, 106.0), desc, HORIZONTAL_ALIGNMENT_LEFT, text_rect.size.x, int(round(13.0 * context.text_scale)), 5, Color(structure.r, structure.g, structure.b, 0.82 if seen else 0.42))
	draw_string(ShareTechMono, text_rect.position + Vector2(0.0, 184.0), "COUNTERPLAY // BUG REPORT", HORIZONTAL_ALIGNMENT_LEFT, text_rect.size.x, int(round(11.0 * context.text_scale)), color)
	var bugs := "> " + (str(entry.get("bugs", "")) if seen else "LOCKED // COMPLETE A SIGHTING TO ACCESS NOTES")
	draw_multiline_string(ShareTechMono, text_rect.position + Vector2(0.0, 206.0), bugs, HORIZONTAL_ALIGNMENT_LEFT, text_rect.size.x, int(round(12.0 * context.text_scale)), 6, Color(structure.r, structure.g, structure.b, 0.72 if seen else 0.36))

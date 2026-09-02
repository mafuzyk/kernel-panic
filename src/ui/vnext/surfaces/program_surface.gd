class_name VNextProgramSurface
extends Control

const Context = preload("res://src/ui/vnext/ui_context.gd")
const Layout = preload("res://src/ui/vnext/ui_layout.gd")
const Tokens = preload("res://src/ui/vnext/ui_tokens.gd")
const Illustration = preload("res://src/ui/vnext/entity_illustration.gd")
const Orbitron: Font = preload("res://assets/fonts/Orbitron.ttf")
const ShareTechMono: Font = preload("res://assets/fonts/ShareTechMono.ttf")
const Adapter = preload("res://src/ui/vnext/core/entity_presentation_adapter.gd")

signal action_requested(action_id: String, payload: Dictionary)

var context: RefCounted
var snapshot := {}
var _layout := {}
var _selected := "kernel"
var _focus := "kernel"
var _buttons := {}
var _illustration: Control
var _narrow_detail := false
var activation_count := 0
var last_action_id := ""
var _gui_event_ids := {}

static func context_for_viewport(viewport: Vector2, touch := false, reduced := false, contrast := false, scale := 1.0) -> RefCounted:
	return Context.from_viewport(viewport, touch, reduced, contrast, scale)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var list := VBoxContainer.new()
	list.name = "ProgramList"
	list.add_theme_constant_override("separation", 8)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(list)
	for id in Game.PROGRAM_DEFS.keys():
		var button := Button.new()
		button.name = str(id)
		button.text = str(Game.PROGRAM_DEFS[id].get("name", id)).to_upper()
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.flat = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_override("font", ShareTechMono)
		button.add_theme_font_size_override("font_size", 15)
		_style_action_button(button, 34.0)
		button.pressed.connect(_on_program_pressed.bind(str(id)))
		button.focus_entered.connect(_on_program_focus.bind(str(id)))
		button.gui_input.connect(_on_button_gui_input)
		list.add_child(button)
		_buttons[str(id)] = button
	var launch := Button.new()
	launch.name = "LaunchAction"
	launch.text = ">> BOOT PROCESS  [ENTER]"
	launch.focus_mode = Control.FOCUS_ALL
	launch.mouse_filter = Control.MOUSE_FILTER_STOP
	launch.flat = true
	launch.alignment = HORIZONTAL_ALIGNMENT_LEFT
	launch.add_theme_font_override("font", ShareTechMono)
	_style_action_button(launch, 26.0)
	launch.gui_input.connect(_on_button_gui_input)
	launch.pressed.connect(_on_launch_pressed)
	add_child(launch)
	_buttons["launch_program"] = launch
	var list_view := Button.new()
	list_view.name = "ListAction"
	list_view.text = "< PROGRAM LIST"
	list_view.focus_mode = Control.FOCUS_ALL
	list_view.mouse_filter = Control.MOUSE_FILTER_STOP
	list_view.flat = true
	list_view.alignment = HORIZONTAL_ALIGNMENT_LEFT
	list_view.add_theme_font_override("font", ShareTechMono)
	_style_action_button(list_view, 18.0)
	list_view.gui_input.connect(_on_button_gui_input)
	list_view.pressed.connect(_on_list_pressed)
	add_child(list_view)
	_buttons["list_view"] = list_view
	var back := Button.new()
	back.name = "BackAction"
	back.text = "< BACK"
	back.focus_mode = Control.FOCUS_ALL
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	back.flat = true
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.add_theme_font_override("font", ShareTechMono)
	_style_action_button(back, 18.0)
	back.gui_input.connect(_on_button_gui_input)
	back.pressed.connect(_on_back_pressed)
	add_child(back)
	_buttons["back"] = back

func _style_action_button(button: Button, left_margin: float) -> void:
	button.add_theme_color_override("font_color", Tokens.role_color("structure"))
	button.add_theme_color_override("font_hover_color", Tokens.role_color("focus"))
	button.add_theme_color_override("font_focus_color", Tokens.role_color("focus"))
	button.add_theme_color_override("font_pressed_color", Tokens.role_color("focus"))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		style.content_margin_left = left_margin
		style.content_margin_right = 14.0
		button.add_theme_stylebox_override(state, style)

func configure(next_snapshot: Dictionary, next_context: RefCounted) -> void:
	var was_narrow: bool = context != null and context.density == "narrow"
	var previous_view: bool = _narrow_detail
	snapshot = next_snapshot.duplicate(true)
	context = next_context
	_narrow_detail = previous_view if was_narrow and context.density == "narrow" else context.density != "narrow"
	_selected = str(snapshot.get("selected", Game.program))
	if not Game.PROGRAM_DEFS.has(_selected):
		_selected = "kernel"
	_focus = _selected
	_layout = _make_layout(context.viewport_size)
	_apply_layout()
	_update_buttons()
	queue_redraw()

func _make_layout(viewport: Vector2) -> Dictionary:
	return Layout.selection(viewport, context)

func _apply_layout() -> void:
	if _layout.is_empty():
		return
	var list: VBoxContainer = get_node("ProgramList")
	list.position = _layout["list"].position + Vector2(0.0, 38.0)
	list.size = Vector2(_layout["list"].size.x, maxf(0.0, _layout["list"].size.y - 38.0))
	var row_h := minf(58.0, maxf(46.0, _layout["list"].size.y / maxf(Game.PROGRAM_DEFS.size(), 1)))
	for button in list.get_children():
		button.custom_minimum_size = Vector2(0, row_h)
		button.add_theme_font_size_override("font_size", int(round((15.0 if context.density == "wide" else 13.0) * float(context.text_scale))))
	var launch: Button = _buttons["launch_program"]
	launch.position = _layout["launch_program"].position
	launch.size = _layout["launch_program"].size
	var back: Button = _buttons["back"]
	back.position = _layout["back"].position
	back.size = _layout["back"].size
	var list_view: Button = _buttons["list_view"]
	list_view.position = _layout["detail"].position + Vector2(14.0, maxf(0.0, _layout["detail"].size.y - 48.0))
	list_view.size = Vector2(minf(190.0, _layout["detail"].size.x), 40.0)
	if _illustration == null:
		_illustration = Illustration.new()
		add_child(_illustration)
	var narrow: bool = bool(_layout["narrow"])
	list.visible = not narrow or not _narrow_detail
	_illustration.visible = not narrow or _narrow_detail
	launch.visible = not narrow or _narrow_detail
	list_view.visible = narrow and _narrow_detail
	_illustration.set_quality_profile("mobile" if context.input_mode == "touch" else "desktop", context.reduce_motion, context.high_contrast)
	_illustration.configure_entity(Adapter.PROGRAM_KINDS.get(_selected, "kernel"), "ready", "PROGRAM")
	_illustration.position = _layout["detail_illustration"].position
	_illustration.size = _layout["detail_illustration"].size

func _update_buttons() -> void:
	for id in Game.PROGRAM_DEFS.keys():
		var key := str(id)
		var button: Button = _buttons[key]
		var unlocked := Game.unlocked_programs.has(key)
		button.text = ("> " if _selected == key else "  ") + str(Game.PROGRAM_DEFS[key].get("name", key)).to_upper()
		button.tooltip_text = str(Game.PROGRAM_DEFS[key].get("name", key)).to_upper() + (" // READY" if unlocked else " // LOCKED")
		button.add_theme_color_override("font_color", Tokens.role_color("focus") if _selected == key else Tokens.role_color("structure") if unlocked else Tokens.role_color("muted"))
	var definition: Dictionary = Game.PROGRAM_DEFS.get(_selected, Game.PROGRAM_DEFS["kernel"])
	if _illustration != null:
		_illustration.configure_entity(Adapter.PROGRAM_KINDS.get(_selected, "kernel"), "ready", "PROGRAM")
	var launch: Button = _buttons["launch_program"]
	launch.text = ">> BOOT %s  [ENTER]" % str(definition.get("name", "KERNEL"))
	launch.disabled = not Game.unlocked_programs.has(_selected)
	launch.add_theme_color_override("font_color", Tokens.role_color("ready") if not launch.disabled else Tokens.role_color("muted"))

func layout_snapshot() -> Dictionary:
	return {"density": context.density, "safe_rect": context.safe_rect, "regions": _layout.duplicate(true)}

func action_regions() -> Dictionary:
	var narrow: bool = bool(_layout.get("narrow", false))
	var result := {"back": {"rect": _layout.get("back", Rect2()), "label": "BACK", "state": "idle"}}
	if not narrow or not _narrow_detail:
		for id in Game.PROGRAM_DEFS.keys():
			var key := str(id)
			result[key] = {"rect": _local_button_rect(_buttons[key]), "label": str(Game.PROGRAM_DEFS[key].get("name", key)), "state": "ready" if Game.unlocked_programs.has(key) else "locked"}
	if not narrow or _narrow_detail:
		result["launch_program"] = {"rect": _layout.get("launch_program", Rect2()), "label": "BOOT SELECTED PROCESS", "state": "ready" if Game.unlocked_programs.has(_selected) else "locked"}
	if narrow and _narrow_detail:
		result["list_view"] = {"rect": _local_button_rect(_buttons["list_view"], false), "label": "PROGRAM LIST", "state": "idle"}
	return result

func text_overflow_report() -> Array:
	var scale := float(context.text_scale)
	var definition: Dictionary = Game.PROGRAM_DEFS.get(_selected, Game.PROGRAM_DEFS["kernel"])
	var entries := [
		{"id": "shell_meta", "text": "SYSTEM ONLINE    KP://PROGRAMS    USER: GUEST", "rect": _layout["shell_meta"], "size": 12, "inset": 8.0},
		{"id": "title", "text": "PROGRAM // PROCESS TABLE", "rect": _layout["header"], "size": _layout["title_size"], "inset": 0.0},
		{"id": "subtitle", "text": "SELECT A PROCESS. READ ITS COST BEFORE BOOT.", "rect": _layout["header"], "size": 14, "inset": 0.0},
	]
	for id in Game.PROGRAM_DEFS.keys():
		var key := str(id)
		if not bool(_layout["narrow"]) or not _narrow_detail:
			entries.append({"id": key, "text": str(_buttons[key].text), "rect": _local_button_rect(_buttons[key]), "size": 14})
	if not bool(_layout["narrow"]) or _narrow_detail:
		for detail_entry in _detail_entries(definition, scale):
			entries.append(detail_entry)
		entries.append({"id": "launch", "text": str(_buttons["launch_program"].text), "rect": _layout["launch_program"], "size": 16})
	if bool(_layout["narrow"]) and _narrow_detail:
		entries.append({"id": "list_view", "text": str(_buttons["list_view"].text), "rect": _local_button_rect(_buttons["list_view"], false), "size": 14})
	entries.append({"id": "back", "text": str(_buttons["back"].text), "rect": _layout["back"], "size": 14})
	entries.append({"id": "footer", "text": "PROGRAM INDEX    STATE    BUILD 0.2.3", "rect": _layout["footer"], "size": 11, "inset": 8.0})
	var result := []
	for entry in entries:
		var font: Font = Orbitron if int(entry["size"]) >= 24 else ShareTechMono
		var measured := font.get_multiline_string_size(entry["text"], HORIZONTAL_ALIGNMENT_LEFT, maxf(float(entry["rect"].size.x) - float(entry.get("inset", 20.0)), 1.0), int(round(float(entry["size"]) * scale)))
		var available := maxf(float(entry["rect"].size.x) - float(entry.get("inset", 20.0)), 0.0)
		result.append({"id": entry["id"], "fits": measured.x <= available and measured.y <= float(entry["rect"].size.y), "measured_width": measured.x, "available_width": available})
	return result

func semantic_snapshot() -> Dictionary:
	var selected_def: Dictionary = Game.PROGRAM_DEFS.get(_selected, {})
	return {
		"screen": "program_select",
		"visual_system": "reference_shell",
		"route": "KP://PROGRAMS",
		"selected": _selected,
		"identity": selected_def.get("name", ""),
		"role": selected_def.get("role", ""),
		"playstyle": selected_def.get("summary", ""),
		"risk": selected_def.get("fire", ""),
		"loadout": selected_def.get("dash_shield", ""),
		"locked": not Game.unlocked_programs.has(_selected),
		"focus": _focus,
		"view": "detail" if not bool(_layout.get("narrow", false)) or _narrow_detail else "list",
		"composition": {"shell": "persistent", "list": "process_index", "detail": "dossier", "illustration": "identity_glyph", "footer": "telemetry"},
	}

func focus_id() -> String:
	return _focus

func set_focus_id(id: String) -> bool:
	if not _buttons.has(id) or not _buttons[id] is Button:
		return false
	_focus = id
	(_buttons[id] as Button).grab_focus()
	if id in Game.PROGRAM_DEFS:
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

func _step_focus(delta: int) -> bool:
	var ids: Array = ["kernel", "daemon", "rootlet"] if not bool(_layout.get("narrow", false)) or not _narrow_detail else ["launch_program", "list_view", "back"]
	if bool(_layout.get("narrow", false)) and not _narrow_detail:
		ids.append("back")
	elif not bool(_layout.get("narrow", false)):
		ids.append_array(["launch_program", "back"])
	var index := ids.find(_focus)
	if index < 0:
		index = 0
	index = wrapi(index + delta, 0, ids.size())
	return set_focus_id(ids[index])

func _dispatch(id: String) -> bool:
	if id in Game.PROGRAM_DEFS and not Game.unlocked_programs.has(id):
		return false
	if id == "launch_program":
		if not Game.unlocked_programs.has(_selected):
			return false
		last_action_id = id
		activation_count += 1
		action_requested.emit(id, {"program": _selected})
		return true
	if id == "back":
		last_action_id = id
		activation_count += 1
		action_requested.emit(id, {})
		return true
	if id == "list_view":
		_narrow_detail = false
		_focus = _selected
		_apply_layout()
		_update_buttons()
		queue_redraw()
		return true
	_selected = id
	_focus = id
	if bool(_layout.get("narrow", false)):
		_narrow_detail = true
		_focus = "launch_program"
		_apply_layout()
	_update_buttons()
	return true

func _on_program_pressed(id: String) -> void:
	_dispatch(id)

func _on_program_focus(id: String) -> void:
	_focus = id
	_selected = id
	_update_buttons()
	queue_redraw()

func _on_launch_pressed() -> void:
	_dispatch("launch_program")

func _on_back_pressed() -> void:
	_dispatch("back")

func _on_list_pressed() -> void:
	_dispatch("list_view")

func _local_button_rect(button: Control, in_list := true) -> Rect2:
	var origin: Vector2 = get_node("ProgramList").position if in_list else Vector2.ZERO
	return Rect2(origin + button.position, button.size)

func _detail_entries(definition: Dictionary, scale: float) -> Array:
	var text_rect: Rect2 = _layout["detail_text"]
	var width := maxf(text_rect.size.x, 1.0)
	var y := text_rect.position.y
	var entries := []
	for item in [
		["identity", str(definition.get("name", "")), 22],
		["role", "ROLE       " + str(definition.get("role", "")), 13],
		["playstyle", "PLAYSTYLE  " + str(definition.get("summary", "")), 13],
		["integrity", "INTEGRITY  " + str(definition.get("integrity", "")) + "    MOVE  " + str(definition.get("speed", "")), 13],
		["risk", "FIRE       " + str(definition.get("fire", "")), 13],
		["range", "RANGE      " + str(definition.get("range", "")), 13],
		["loadout", "LOADOUT    " + str(definition.get("dash_shield", "")), 13],
	]:
		var font: Font = Orbitron if int(item[2]) >= 24 else ShareTechMono
		var height := maxf(24.0, font.get_multiline_string_size(item[1], HORIZONTAL_ALIGNMENT_LEFT, width, int(round(float(item[2]) * scale))).y + 4.0)
		entries.append({"id": item[0], "text": item[1], "rect": Rect2(Vector2(text_rect.position.x, y), Vector2(width, height)), "size": item[2], "inset": 0.0})
		y += height + 4.0
	return entries

func _draw() -> void:
	if context == null or _layout.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, size), Tokens.role_color("background"))
	_draw_ambient_grid(_layout["shell"])
	draw_polyline(Tokens.frame_points(_layout["shell"], 16.0), Tokens.role_color("structure"), 1.5, true)
	_draw_shell_meta(_layout["shell_meta"])
	draw_string(Orbitron, _layout["header"].position, "PROGRAM // PROCESS TABLE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(float(_layout["title_size"]) * context.text_scale)), Tokens.role_color("focus"))
	draw_string(ShareTechMono, _layout["header"].position + Vector2(0, 28), "SELECT A PROCESS. READ ITS COST BEFORE BOOT.", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(14.0 * context.text_scale)), Tokens.role_color("muted"))
	draw_line(_layout["header"].position + Vector2(0.0, _layout["header"].size.y - 8.0), _layout["header"].end - Vector2(0.0, 8.0), Color(Tokens.role_color("structure"), 0.32), 1.0, true)
	_draw_footer()
	if not bool(_layout["narrow"]) or not _narrow_detail:
		_draw_program_list()
	if not bool(_layout["narrow"]) or _narrow_detail:
		_draw_program_dossier()
	var launch_color := Tokens.role_color("focus") if _focus == "launch_program" else Tokens.role_color("ready")
	if (not bool(_layout["narrow"]) or _narrow_detail) and _buttons["launch_program"].visible:
		draw_polyline(Tokens.frame_points(_layout["launch_program"], 8.0), launch_color, 1.8 if _focus == "launch_program" else 1.0, true)
	if _buttons["back"].visible:
		draw_polyline(Tokens.frame_points(_layout["back"], 8.0), Tokens.role_color("focus") if _focus == "back" else Tokens.role_color("structure"), 1.8 if _focus == "back" else 1.0, true)
	if _buttons["list_view"].visible:
		draw_polyline(Tokens.frame_points(_local_button_rect(_buttons["list_view"], false), 8.0), Tokens.role_color("focus"), 1.3, true)

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
		draw_string(ShareTechMono, rect.get_center() - Vector2(35.0, 0.0), "KP://PROGRAMS", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		draw_string(ShareTechMono, rect.end - Vector2(42.0, 4.0), "GUEST", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	else:
		draw_string(ShareTechMono, rect.position, "■  SYSTEM ONLINE", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		draw_string(ShareTechMono, rect.get_center() - Vector2(62.0, 0.0), "KP://PROGRAMS", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		draw_string(ShareTechMono, rect.end - Vector2(108.0, 4.0), "USER: GUEST", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	draw_line(rect.position + Vector2(146.0, -4.0), rect.position + Vector2(244.0, -4.0), Color(color.r, color.g, color.b, 0.5), 1.0, true)

func _draw_footer() -> void:
	var rect: Rect2 = _layout["footer"]
	var color := Tokens.role_color("muted")
	var accent := Tokens.role_color("structure")
	draw_line(rect.position, rect.end, Color(accent.r, accent.g, accent.b, 0.42), 1.0, true)
	draw_string(ShareTechMono, rect.position + Vector2(0.0, 17.0), "PROGRAM INDEX", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(11.0 * context.text_scale)), accent)
	draw_string(ShareTechMono, rect.position + Vector2(132.0, 17.0), "STATE  %s" % ("READY" if Game.unlocked_programs.has(_selected) else "LOCKED"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(11.0 * context.text_scale)), color)
	draw_string(ShareTechMono, rect.position + Vector2(rect.size.x - 178.0, 17.0), "BUILD 0.2.3", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(11.0 * context.text_scale)), color)

func _draw_program_list() -> void:
	var rect: Rect2 = _layout["list"]
	var color := Tokens.role_color("structure")
	draw_colored_polygon(Tokens.frame_points(rect, 11.0), Color(color.r, color.g, color.b, 0.025))
	draw_polyline(Tokens.frame_points(rect, 11.0) + PackedVector2Array([Tokens.frame_points(rect, 11.0)[0]]), Color(color.r, color.g, color.b, 0.62), 1.1, true)
	draw_string(ShareTechMono, rect.position + Vector2(18.0, 24.0), "PROCESS INDEX // %02d ENTRIES" % Game.PROGRAM_DEFS.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(11.0 * context.text_scale)), color)
	draw_line(rect.position + Vector2(18.0, 34.0), rect.end - Vector2(18.0, rect.size.y - 34.0), Color(color.r, color.g, color.b, 0.26), 1.0, true)
	for id in Game.PROGRAM_DEFS.keys():
		var button: Button = _buttons[str(id)]
		if not button.visible:
			continue
		var row := _local_button_rect(button)
		var selected := str(id) == _selected
		var unlocked := Game.unlocked_programs.has(str(id))
		var row_color := Tokens.role_color("focus") if selected else color if unlocked else Tokens.role_color("muted")
		if selected:
			draw_colored_polygon(Tokens.frame_points(row.grow(-2.0), 6.0), Color(row_color.r, row_color.g, row_color.b, 0.08))
		draw_line(row.position + Vector2(12.0, row.size.y - 1.0), row.end - Vector2(12.0, 1.0), Color(row_color.r, row_color.g, row_color.b, 0.2), 1.0, true)
		var marker := row.position + Vector2(18.0, row.size.y * 0.5)
		if selected:
			draw_colored_polygon(PackedVector2Array([marker + Vector2(-5.0, 0.0), marker + Vector2(4.0, -5.0), marker + Vector2(4.0, 5.0)]), row_color)
		else:
			draw_rect(Rect2(marker - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), Color(row_color.r, row_color.g, row_color.b, 0.55), false, 1.0)
		draw_string(ShareTechMono, row.position + Vector2(row.size.x - 76.0, row.size.y * 0.5 + 4.0), "READY" if unlocked else "LOCKED", HORIZONTAL_ALIGNMENT_RIGHT, 58.0, int(round(10.0 * context.text_scale)), row_color)

func _draw_program_dossier() -> void:
	var rect: Rect2 = _layout["detail"]
	var color := Tokens.role_color("structure")
	var selected_def: Dictionary = Game.PROGRAM_DEFS.get(_selected, Game.PROGRAM_DEFS["kernel"])
	draw_colored_polygon(Tokens.frame_points(rect, 11.0), Color(color.r, color.g, color.b, 0.018))
	draw_polyline(Tokens.frame_points(rect, 11.0) + PackedVector2Array([Tokens.frame_points(rect, 11.0)[0]]), Color(color.r, color.g, color.b, 0.72), 1.2, true)
	draw_string(ShareTechMono, rect.position + Vector2(18.0, 24.0), "PROCESS DOSSIER // %s" % ("READY" if Game.unlocked_programs.has(_selected) else "LOCKED"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(11.0 * context.text_scale)), color)
	var illustration_rect: Rect2 = _layout["detail_illustration"]
	draw_colored_polygon(Tokens.frame_points(illustration_rect, 9.0), Color(color.r, color.g, color.b, 0.04))
	draw_polyline(Tokens.frame_points(illustration_rect, 9.0) + PackedVector2Array([Tokens.frame_points(illustration_rect, 9.0)[0]]), Color(color.r, color.g, color.b, 0.55), 1.0, true)
	draw_string(ShareTechMono, illustration_rect.position + Vector2(12.0, 18.0), "IDENTITY GLYPH", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(10.0 * context.text_scale)), color)
	draw_line(illustration_rect.get_center() - Vector2(illustration_rect.size.x * 0.42, 0.0), illustration_rect.get_center() + Vector2(illustration_rect.size.x * 0.42, 0.0), Color(color.r, color.g, color.b, 0.16), 1.0, true)
	draw_line(illustration_rect.get_center() - Vector2(0.0, illustration_rect.size.y * 0.32), illustration_rect.get_center() + Vector2(0.0, illustration_rect.size.y * 0.32), Color(color.r, color.g, color.b, 0.16), 1.0, true)
	var text_rect: Rect2 = _layout["detail_text"]
	draw_line(text_rect.position - Vector2(12.0, -2.0), Vector2(text_rect.position.x - 12.0, rect.end.y - 18.0), Color(color.r, color.g, color.b, 0.28), 1.0, true)
	for entry in _detail_entries(selected_def, context.text_scale):
		var entry_rect: Rect2 = entry["rect"]
		var entry_font: Font = Orbitron if int(entry["size"]) >= 24 else ShareTechMono
		var entry_color := Tokens.role_color("focus") if entry["id"] == "identity" else color
		draw_multiline_string(entry_font, entry_rect.position + Vector2(0, float(entry["size"])), str(entry["text"]), HORIZONTAL_ALIGNMENT_LEFT, entry_rect.size.x, int(round(float(entry["size"]) * context.text_scale)), 6, entry_color)
	var status := "READY TO MOUNT" if Game.unlocked_programs.has(_selected) else "LOCKED // CLEAR STORY NODES TO UNLOCK"
	draw_string(ShareTechMono, rect.position + Vector2(18.0, rect.size.y - 18.0), status, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 36.0, int(round(10.0 * context.text_scale)), Tokens.role_color("ready") if Game.unlocked_programs.has(_selected) else Tokens.role_color("muted"))

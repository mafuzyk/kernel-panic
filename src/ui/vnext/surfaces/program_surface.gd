class_name VNextProgramSurface
extends Control

const Context = preload("res://src/ui/vnext/ui_context.gd")
const Tokens = preload("res://src/ui/vnext/ui_tokens.gd")
const Illustration = preload("res://src/ui/vnext/entity_illustration.gd")
const Orbitron: Font = preload("res://assets/fonts/Orbitron.ttf")
const ShareTechMono: Font = preload("res://assets/fonts/ShareTechMono.ttf")

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
		button.add_theme_font_override("font", ShareTechMono)
		button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
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
	launch.add_theme_font_override("font", ShareTechMono)
	launch.gui_input.connect(_on_button_gui_input)
	launch.pressed.connect(_on_launch_pressed)
	add_child(launch)
	_buttons["launch_program"] = launch
	var list_view := Button.new()
	list_view.name = "ListAction"
	list_view.text = "< PROGRAM LIST"
	list_view.focus_mode = Control.FOCUS_ALL
	list_view.mouse_filter = Control.MOUSE_FILTER_STOP
	list_view.add_theme_font_override("font", ShareTechMono)
	list_view.gui_input.connect(_on_button_gui_input)
	list_view.pressed.connect(_on_list_pressed)
	add_child(list_view)
	_buttons["list_view"] = list_view
	var back := Button.new()
	back.name = "BackAction"
	back.text = "< BACK"
	back.focus_mode = Control.FOCUS_ALL
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	back.add_theme_font_override("font", ShareTechMono)
	back.gui_input.connect(_on_button_gui_input)
	back.pressed.connect(_on_back_pressed)
	add_child(back)
	_buttons["back"] = back

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
	var safe: Rect2 = context.safe_rect
	var narrow: bool = context.density == "narrow"
	var compact: bool = context.density == "compact"
	var pad := 16.0 if narrow else 24.0
	var header_h := 82.0 if narrow else 70.0
	var header := Rect2(safe.position + Vector2(pad, 18), Vector2(maxf(safe.size.x - pad * 2.0, 0.0), header_h))
	var list_ratio := 0.36 if compact else 0.42
	var list_w := maxf(180.0, minf(300.0, safe.size.x * (0.92 if narrow else list_ratio)))
	var list := Rect2(safe.position + Vector2(pad, 110), Vector2(minf(list_w, maxf(safe.size.x - pad * 2.0, 0.0)), maxf(0.0, safe.size.y - 220.0)))
	var detail_x := list.end.x + pad
	var detail := Rect2(Vector2(detail_x, list.position.y), Vector2(maxf(0.0, safe.end.x - detail_x - pad), list.size.y))
	if narrow:
		list = Rect2(safe.position + Vector2(pad, 126), Vector2(maxf(0.0, safe.size.x - pad * 2.0), maxf(0.0, safe.size.y - 270.0)))
		detail = Rect2(safe.position + Vector2(pad, 126), Vector2(maxf(0.0, safe.size.x - pad * 2.0), maxf(0.0, safe.size.y - 270.0)))
	var launch := Rect2(safe.end - Vector2(minf(360.0, safe.size.x - pad * 2.0) + pad, 104), Vector2(minf(360.0, maxf(0.0, safe.size.x - pad * 2.0)), 52.0))
	var back := Rect2(safe.position + Vector2(pad, safe.size.y - pad - 48), Vector2(minf(150.0, safe.size.x - pad * 2.0), 48.0))
	if narrow:
		launch = Rect2(safe.position + Vector2(pad, safe.size.y - pad - 112), Vector2(maxf(0.0, safe.size.x - pad * 2.0), 52.0))
	return {"safe": safe, "header": header, "list": list, "detail": detail, "launch_program": launch, "back": back, "narrow": narrow, "compact": compact, "title_size": 22 if narrow else 28}

func _apply_layout() -> void:
	if _layout.is_empty():
		return
	var list: VBoxContainer = get_node("ProgramList")
	list.position = _layout["list"].position
	list.size = _layout["list"].size
	var row_h := minf(52.0, maxf(44.0, _layout["list"].size.y / maxf(Game.PROGRAM_DEFS.size(), 1)))
	for button in list.get_children():
		button.custom_minimum_size = Vector2(0, row_h)
	var launch: Button = _buttons["launch_program"]
	launch.position = _layout["launch_program"].position
	launch.size = _layout["launch_program"].size
	var back: Button = _buttons["back"]
	back.position = _layout["back"].position
	back.size = _layout["back"].size
	var list_view: Button = _buttons["list_view"]
	list_view.position = _layout["detail"].position + Vector2(12.0, maxf(0.0, _layout["detail"].size.y - 52.0))
	list_view.size = Vector2(minf(190.0, _layout["detail"].size.x), 48.0)
	if _illustration == null:
		_illustration = Illustration.new()
		add_child(_illustration)
	var narrow: bool = bool(_layout["narrow"])
	list.visible = not narrow or not _narrow_detail
	_illustration.visible = not narrow or _narrow_detail
	launch.visible = not narrow or _narrow_detail
	list_view.visible = narrow and _narrow_detail
	_illustration.configure_entity(str(Game.PROGRAM_DEFS[_selected].get("visual", {}).get("silhouette", "kernel_arrow")).replace("_arrow", "").replace("_fork", "").replace("_block", ""), "ready", "PROGRAM")
	_illustration.position = _layout["detail"].position + Vector2(18, 18)
	_illustration.size = Vector2(minf(120.0, _layout["detail"].size.x * 0.32), minf(120.0, _layout["detail"].size.y))

func _update_buttons() -> void:
	for id in Game.PROGRAM_DEFS.keys():
		var key := str(id)
		var button: Button = _buttons[key]
		var unlocked := Game.unlocked_programs.has(key)
		button.text = ("> " if _selected == key else "  ") + str(Game.PROGRAM_DEFS[key].get("name", key)).to_upper() + ("  // READY" if unlocked else "  // LOCKED")
		button.add_theme_color_override("font_color", Tokens.role_color("focus") if _selected == key else Tokens.role_color("structure") if unlocked else Tokens.role_color("muted"))
	var definition: Dictionary = Game.PROGRAM_DEFS.get(_selected, Game.PROGRAM_DEFS["kernel"])
	if _illustration != null:
		_illustration.configure_entity(str(definition.get("visual", {}).get("silhouette", "kernel_arrow")).replace("_arrow", "").replace("_fork", "").replace("_block", ""), "ready", "PROGRAM")
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
	var entries := [{"id": "title", "text": "PROGRAM // PROCESS TABLE", "rect": _layout["header"], "size": _layout["title_size"]}, {"id": "subtitle", "text": "SELECT A PROCESS. READ ITS COST BEFORE BOOT.", "rect": _layout["header"], "size": 14}]
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
	var result := []
	for entry in entries:
		var font: Font = Orbitron if int(entry["size"]) >= 24 else ShareTechMono
		var measured := font.get_multiline_string_size(entry["text"], HORIZONTAL_ALIGNMENT_LEFT, maxf(float(entry["rect"].size.x) - float(entry.get("inset", 20.0)), 1.0), int(round(float(entry["size"]) * scale)))
		var available := maxf(float(entry["rect"].size.x) - float(entry.get("inset", 20.0)), 0.0)
		result.append({"id": entry["id"], "fits": measured.x <= available and measured.y <= float(entry["rect"].size.y), "measured_width": measured.x, "available_width": available})
	return result

func semantic_snapshot() -> Dictionary:
	var selected_def: Dictionary = Game.PROGRAM_DEFS.get(_selected, {})
	return {"screen": "program_select", "selected": _selected, "identity": selected_def.get("name", ""), "role": selected_def.get("role", ""), "playstyle": selected_def.get("summary", ""), "risk": selected_def.get("fire", ""), "loadout": selected_def.get("dash_shield", ""), "locked": not Game.unlocked_programs.has(_selected), "focus": _focus, "view": "detail" if not bool(_layout.get("narrow", false)) or _narrow_detail else "list"}

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
	var origin: Vector2 = _layout["list"].position if in_list else Vector2.ZERO
	return Rect2(origin + button.position, button.size)

func _detail_entries(definition: Dictionary, scale: float) -> Array:
	var detail: Rect2 = _layout["detail"]
	var x_offset := 150.0 if not bool(_layout["narrow"]) else 12.0
	var width := maxf(detail.size.x - x_offset - 12.0, 1.0)
	var y := detail.position.y + 18.0
	var entries := []
	for item in [["identity", str(definition.get("name", "")), 22], ["role", str(definition.get("role", "")), 14], ["playstyle", "PLAYSTYLE  " + str(definition.get("summary", "")), 14], ["risk", "RISK       " + str(definition.get("fire", "")), 14], ["loadout", "LOADOUT    " + str(definition.get("dash_shield", "")), 14]]:
		var font: Font = Orbitron if int(item[2]) >= 24 else ShareTechMono
		var height := maxf(24.0, font.get_multiline_string_size(item[1], HORIZONTAL_ALIGNMENT_LEFT, width, int(round(float(item[2]) * scale))).y + 4.0)
		entries.append({"id": item[0], "text": item[1], "rect": Rect2(detail.position + Vector2(x_offset, y - detail.position.y), Vector2(width, height)), "size": item[2], "inset": 0.0})
		y += height + 4.0
	return entries

func _draw() -> void:
	if context == null or _layout.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, size), Tokens.role_color("background"))
	draw_polyline(Tokens.frame_points(_layout["safe"], 16), Tokens.role_color("structure"), 1.5, true)
	draw_string(Orbitron, _layout["header"].position, "PROGRAM // PROCESS TABLE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(float(_layout["title_size"]) * context.text_scale)), Tokens.role_color("focus"))
	draw_string(ShareTechMono, _layout["header"].position + Vector2(0, 28), "SELECT A PROCESS. READ ITS COST BEFORE BOOT.", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(14.0 * context.text_scale)), Tokens.role_color("muted"))
	if not bool(_layout["narrow"]) or not _narrow_detail:
		draw_polyline(Tokens.frame_points(_layout["list"], 10), Tokens.role_color("structure"), 1.0, true)
	if not bool(_layout["narrow"]) or _narrow_detail:
		draw_polyline(Tokens.frame_points(_layout["detail"], 10), Tokens.role_color("structure"), 1.0, true)
	var d: Dictionary = Game.PROGRAM_DEFS.get(_selected, {})
	if not bool(_layout["narrow"]) or _narrow_detail:
		for entry in _detail_entries(d, context.text_scale):
			var entry_rect: Rect2 = entry["rect"]
			var entry_font: Font = Orbitron if int(entry["size"]) >= 24 else ShareTechMono
			draw_multiline_string(entry_font, entry_rect.position + Vector2(0, float(entry["size"])), str(entry["text"]), HORIZONTAL_ALIGNMENT_LEFT, entry_rect.size.x, int(round(float(entry["size"]) * context.text_scale)), 6, Tokens.role_color("focus") if entry["id"] == "identity" else Tokens.role_color("structure"))

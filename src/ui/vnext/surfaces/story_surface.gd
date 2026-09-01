class_name VNextStorySurface
extends Control

const Context = preload("res://src/ui/vnext/ui_context.gd")
const Tokens = preload("res://src/ui/vnext/ui_tokens.gd")
const Orbitron: Font = preload("res://assets/fonts/Orbitron.ttf")
const ShareTechMono: Font = preload("res://assets/fonts/ShareTechMono.ttf")
const ACT_IDS: Array[String] = ["unix", "windows", "templeos", "macos"]

signal action_requested(action_id: String, payload: Dictionary)

var context: RefCounted
var snapshot := {}
var _layout := {}
var _selected := 0
var _focus := "stage_0"
var _buttons := {}
var _tabs := {}
var _act := "unix"
var _narrow_detail := false
var activation_count := 0
var last_action_id := ""
var _gui_event_ids := {}

static func context_for_viewport(viewport: Vector2, touch := false, reduced := false, contrast := false, scale := 1.0) -> RefCounted:
	return Context.from_viewport(viewport, touch, reduced, contrast, scale)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var list := VBoxContainer.new()
	list.name = "StoryList"
	list.add_theme_constant_override("separation", 6)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(list)
	for act in ACT_IDS:
		var tab := Button.new()
		tab.name = "Act" + act.capitalize()
		tab.text = act.to_upper()
		tab.focus_mode = Control.FOCUS_ALL
		tab.mouse_filter = Control.MOUSE_FILTER_STOP
		tab.flat = true
		tab.add_theme_font_override("font", ShareTechMono)
		tab.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		tab.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		tab.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		tab.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		tab.pressed.connect(_on_act_pressed.bind(act))
		tab.gui_input.connect(_on_button_gui_input)
		add_child(tab)
		_tabs[act] = tab
		_buttons["act_" + act] = tab
	for i in Game.story_stage_count():
		var button := Button.new()
		button.name = "stage_%d" % i
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.flat = true
		button.add_theme_font_override("font", ShareTechMono)
		button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.pressed.connect(_on_stage_pressed.bind(i))
		button.focus_entered.connect(_on_stage_focus.bind(i))
		button.gui_input.connect(_on_button_gui_input)
		list.add_child(button)
		_buttons["stage_%d" % i] = button
	var launch := Button.new()
	launch.name = "LaunchAction"
	launch.focus_mode = Control.FOCUS_ALL
	launch.mouse_filter = Control.MOUSE_FILTER_STOP
	launch.add_theme_font_override("font", ShareTechMono)
	launch.gui_input.connect(_on_button_gui_input)
	launch.pressed.connect(_on_launch_pressed)
	add_child(launch)
	_buttons["launch_story"] = launch
	var list_view := Button.new()
	list_view.name = "ListAction"
	list_view.text = "< NODE LIST"
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
	_selected = clampi(int(snapshot.get("selected", 0)), 0, maxi(Game.story_stage_count() - 1, 0))
	_focus = "stage_%d" % _selected
	_layout = _make_layout()
	_apply_layout()
	_update_buttons()
	queue_redraw()

func _make_layout() -> Dictionary:
	var safe: Rect2 = context.safe_rect
	var pad := 16.0 if context.density == "narrow" else 24.0
	var header_h := 82.0 if context.density == "narrow" else 70.0
	var header := Rect2(safe.position + Vector2(pad, 18), Vector2(maxf(0.0, safe.size.x - pad * 2.0), header_h))
	var tabs := Rect2(safe.position + Vector2(pad, 86), Vector2(maxf(0.0, safe.size.x - pad * 2.0), 48))
	var list := Rect2(safe.position + Vector2(pad, 126), Vector2(maxf(180.0, safe.size.x * 0.38), maxf(0.0, safe.size.y - 236)))
	var detail := Rect2(Vector2(list.end.x + pad, list.position.y), Vector2(maxf(0.0, safe.end.x - list.end.x - pad * 2), list.size.y))
	var launch := Rect2(safe.end - Vector2(minf(360.0, safe.size.x - pad * 2) + pad, 104), Vector2(minf(360.0, maxf(0.0, safe.size.x - pad * 2)), 52))
	var back := Rect2(safe.position + Vector2(pad, safe.size.y - pad - 48), Vector2(minf(150.0, safe.size.x - pad * 2), 48))
	if context.density == "narrow":
		list = Rect2(safe.position + Vector2(pad, 148), Vector2(maxf(0.0, safe.size.x - pad * 2), maxf(0.0, safe.size.y - 270)))
		detail = Rect2(safe.position + Vector2(pad, 148), Vector2(maxf(0.0, safe.size.x - pad * 2), maxf(0.0, safe.size.y - 270)))
		launch = Rect2(safe.position + Vector2(pad, safe.size.y - pad - 112), Vector2(maxf(0.0, safe.size.x - pad * 2), 52))
	return {"safe": safe, "header": header, "tabs": tabs, "list": list, "detail": detail, "launch_story": launch, "back": back, "title_size": 24 if context.density == "narrow" else 28}

func _apply_layout() -> void:
	var list: VBoxContainer = get_node("StoryList")
	var tab_width: float = _layout["tabs"].size.x / float(ACT_IDS.size())
	var tab_index := 0
	for act in _tabs:
		var tab: Button = _tabs[act]
		tab.position = _layout["tabs"].position + Vector2(tab_width * tab_index, 0)
		tab.size = Vector2(tab_width, _layout["tabs"].size.y)
		var act_unlocked := Game.story_act_unlocked(act) if Game.has_method("story_act_unlocked") else true
		tab.add_theme_color_override("font_color", Tokens.role_color("focus") if act == _act else Tokens.role_color("muted") if not act_unlocked else Tokens.role_color("structure"))
		tab.text = _tab_label(act)
		tab_index += 1
	list.position = _layout["list"].position
	list.size = _layout["list"].size
	var visible_indices := _visible_stage_indices()
	var row_h := minf(48.0, maxf(44.0, _layout["list"].size.y / maxf(visible_indices.size(), 1)))
	for button in list.get_children():
		var index := int(button.name.trim_prefix("stage_"))
		button.visible = index in visible_indices and (context.density != "narrow" or not _narrow_detail)
		button.custom_minimum_size = Vector2(0, row_h)
	var launch: Button = _buttons["launch_story"]
	launch.position = _layout["launch_story"].position
	launch.size = _layout["launch_story"].size
	var back: Button = _buttons["back"]
	back.position = _layout["back"].position
	back.size = _layout["back"].size
	var list_view: Button = _buttons["list_view"]
	list_view.position = _layout["detail"].position + Vector2(12.0, maxf(0.0, _layout["detail"].size.y - 52.0))
	list_view.size = Vector2(minf(160.0, _layout["detail"].size.x), 48.0)
	var narrow: bool = context.density == "narrow"
	list.visible = not narrow or not _narrow_detail
	launch.visible = not narrow or _narrow_detail
	list_view.visible = narrow and _narrow_detail

func _stage_state(index: int) -> String:
	return "locked" if not Game.story_stage_unlocked(index) else "cleared" if Game.story_cleared.get(Game.story_stage_id(index), false) else "ready"

func _visible_stage_indices() -> Array:
	var result: Array = []
	for i in Game.story_stage_count():
		var stage: Dictionary = Game.story_stage_def(i)
		if str(stage.get("act", "unix")) == _act:
			result.append(i)
	return result

func _update_buttons() -> void:
	for i in Game.story_stage_count():
		var key := "stage_%d" % i
		var stage: Dictionary = Game.story_stage_def(i)
		var state := _stage_state(i)
		var marker := "LOCKED // CLEAR PREVIOUS NODE" if state == "locked" else "CLEARED" if state == "cleared" else "READY"
		var compact_label := "NODE %02d  %s" % [i + 1, marker]
		_buttons[key].text = compact_label if context.density == "narrow" else ("> " if _selected == i else "  ") + str(stage.get("path", "NODE")) + "  // " + marker
		_buttons[key].add_theme_color_override("font_color", Tokens.role_color("focus") if _selected == i else Tokens.role_color("ready") if state != "locked" else Tokens.role_color("muted"))
	var selected_stage: Dictionary = Game.story_stage_def(_selected)
	var launch: Button = _buttons["launch_story"]
	launch.text = ">> MOUNT %s  [ENTER]" % str(selected_stage.get("path", "/boot"))
	launch.disabled = not Game.story_stage_unlocked(_selected)

func layout_snapshot() -> Dictionary:
	return {"density": context.density, "safe_rect": context.safe_rect, "regions": _layout.duplicate(true)}

func action_regions() -> Dictionary:
	var narrow: bool = context.density == "narrow"
	var result := {"back": {"rect": _layout.get("back", Rect2()), "label": "BACK", "state": "idle"}}
	var tab_width: float = _layout.get("tabs", Rect2()).size.x / float(ACT_IDS.size())
	for index in ACT_IDS.size():
		var act: String = ACT_IDS[index]
		result["act_" + act] = {"rect": Rect2(_layout.get("tabs", Rect2()).position + Vector2(tab_width * index, 0), Vector2(tab_width, _layout.get("tabs", Rect2()).size.y)), "label": act.to_upper(), "state": "selected" if act == _act else "locked" if Game.has_method("story_act_unlocked") and not Game.story_act_unlocked(act) else "idle"}
	if not narrow or not _narrow_detail:
		for i in _visible_stage_indices():
			var key := "stage_%d" % i
			result[key] = {"rect": _local_button_rect(_buttons[key]), "label": Game.story_stage_def(i).get("title", key), "state": _stage_state(i)}
	if not narrow or _narrow_detail:
		result["launch_story"] = {"rect": _layout.get("launch_story", Rect2()), "label": "MOUNT SELECTED NODE", "state": "ready" if Game.story_stage_unlocked(_selected) else "locked"}
	if narrow and _narrow_detail:
		result["list_view"] = {"rect": _local_button_rect(_buttons["list_view"], false), "label": "NODE LIST", "state": "idle"}
	return result

func text_overflow_report() -> Array:
	var scale := float(context.text_scale)
	var stage: Dictionary = Game.story_stage_def(_selected)
	var title_size := 24 if context.density == "narrow" else 28
	var entries := [{"id": "title", "text": "STORY // MOUNT TABLE", "rect": _layout["header"], "size": _layout["title_size"]}, {"id": "subtitle", "text": "FOLLOW THE CLEAN PATH. LOCKED NODES EXPLAIN THE BLOCK.", "rect": _layout["header"], "size": 14}]
	var narrow: bool = context.density == "narrow"
	for act in ACT_IDS:
		var tab_index := ACT_IDS.find(act)
		entries.append({"id": "act_" + act, "text": _tab_label(act), "rect": Rect2(_layout["tabs"].position + Vector2(tab_index * _layout["tabs"].size.x / float(ACT_IDS.size()), 0), Vector2(_layout["tabs"].size.x / float(ACT_IDS.size()), _layout["tabs"].size.y)), "size": 14 if context.density != "narrow" else 12})
	if not narrow or not _narrow_detail:
		for i in _visible_stage_indices():
			var key := "stage_%d" % i
			entries.append({"id": key, "text": str(_buttons[key].text), "rect": _local_button_rect(_buttons[key]), "size": 14})
	if not narrow or _narrow_detail:
		for detail_entry in _detail_entries(stage, scale):
			entries.append(detail_entry)
		entries.append({"id": "launch", "text": str(_buttons["launch_story"].text), "rect": _layout["launch_story"], "size": 16})
	if narrow and _narrow_detail:
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
	var result := {"screen": "story_select", "selected": _selected, "act": _act, "focus": _focus, "tabs": ACT_IDS.duplicate(), "view": "detail" if context.density != "narrow" or _narrow_detail else "list"}
	for i in Game.story_stage_count():
		var stage: Dictionary = Game.story_stage_def(i)
		result["stage_%d" % i] = {"id": stage.get("id", ""), "title": stage.get("title", ""), "state": _stage_state(i), "reason": "clear previous node" if _stage_state(i) == "locked" else ""}
	return result

func _tab_label(act: String) -> String:
	if context != null and context.density == "narrow":
		return {"unix": "UNIX", "windows": "WIN", "templeos": "TEMPLE", "macos": "MAC"}.get(act, act.to_upper())
	return act.to_upper()

func focus_id() -> String:
	return _focus

func set_focus_id(id: String) -> bool:
	if not _buttons.has(id):
		return false
	_focus = id
	(_buttons[id] as Button).grab_focus()
	if id.begins_with("stage_"):
		_selected = int(id.trim_prefix("stage_"))
		_update_buttons()
	queue_redraw()
	return true

func _focus_order() -> Array[String]:
	var ids: Array[String] = []
	for act in ACT_IDS:
		ids.append("act_" + act)
	if context.density == "narrow" and _narrow_detail:
		ids.append_array(["launch_story", "list_view", "back"])
	else:
		for index in _visible_stage_indices():
			ids.append("stage_%d" % index)
		if context.density != "narrow":
			ids.append("launch_story")
		ids.append("back")
	return ids

func handle_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_DOWN or event.keycode == KEY_TAB:
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
	var ids := _focus_order()
	var index := ids.find(_focus)
	if index < 0:
		index = 0
	return set_focus_id(ids[wrapi(index + delta, 0, ids.size())])

func _dispatch(id: String) -> bool:
	if id.begins_with("act_"):
		_on_act_pressed(id.trim_prefix("act_"))
		return true
	if id.begins_with("stage_"):
		var index := int(id.trim_prefix("stage_"))
		if not Game.story_stage_unlocked(index):
			return false
		_selected = index
		_focus = id
		if context.density == "narrow":
			_narrow_detail = true
			_focus = "launch_story"
			_apply_layout()
		_update_buttons()
		return true
	if id == "launch_story":
		if not Game.story_stage_unlocked(_selected):
			return false
		last_action_id = id
		activation_count += 1
		action_requested.emit(id, {"index": _selected, "stage_id": Game.story_stage_id(_selected)})
		return true
	if id == "back":
		last_action_id = id
		activation_count += 1
		action_requested.emit(id, {})
		return true
	if id == "list_view":
		_narrow_detail = false
		_focus = "stage_%d" % _selected
		_apply_layout()
		_update_buttons()
		queue_redraw()
		return true
	return false

func _on_stage_pressed(index: int) -> void:
	_dispatch("stage_%d" % index)

func _on_stage_focus(index: int) -> void:
	_focus = "stage_%d" % index
	_selected = index
	_update_buttons()
	queue_redraw()

func _on_act_pressed(act_id: String) -> void:
	_act = act_id
	_focus = "act_" + act_id
	var visible := _visible_stage_indices()
	if not _selected in visible and not visible.is_empty():
		_selected = visible[0]
	_focus = "stage_%d" % _selected
	_apply_layout()
	_update_buttons()
	queue_redraw()

func _on_launch_pressed() -> void:
	_dispatch("launch_story")

func _on_back_pressed() -> void:
	_dispatch("back")

func _on_list_pressed() -> void:
	_dispatch("list_view")

func _local_button_rect(button: Control, in_list := true) -> Rect2:
	var origin: Vector2 = _layout["list"].position if in_list else Vector2.ZERO
	return Rect2(origin + button.position, button.size)

func _detail_entries(stage: Dictionary, scale: float) -> Array:
	var detail: Rect2 = _layout["detail"]
	var width := maxf(detail.size.x - 28.0, 1.0)
	var y := detail.position.y + 18.0
	var entries := []
	var rule_label := "RULE    " + str(stage.get("act_rule", "standard")).replace("_", " ").to_upper()
	var reward_label := "REWARD  " + str(stage.get("reward_id", "NONE")).to_upper()
	for item in [["identity", str(stage.get("title", "")), 22], ["path", str(stage.get("path", "")), 14], ["briefing", str(stage.get("intro", "")), 14], ["rule", rule_label, 14], ["reward", reward_label, 14], ["status", "STATUS  " + _stage_state(_selected).to_upper(), 14], ["best", "BEST    %07d" % Game.story_stage_best(_selected), 14]]:
		var font: Font = Orbitron if int(item[2]) >= 24 else ShareTechMono
		var height := maxf(24.0, font.get_multiline_string_size(item[1], HORIZONTAL_ALIGNMENT_LEFT, width, int(round(float(item[2]) * scale))).y + 4.0)
		entries.append({"id": item[0], "text": item[1], "rect": Rect2(detail.position + Vector2(14.0, y - detail.position.y), Vector2(width, height)), "size": item[2], "inset": 0.0})
		y += height + 4.0
	return entries

func _draw() -> void:
	if context == null or _layout.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, size), Tokens.role_color("background"))
	draw_polyline(Tokens.frame_points(_layout["safe"], 16), Tokens.role_color("structure"), 1.5, true)
	draw_string(Orbitron, _layout["header"].position, "STORY // MOUNT TABLE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(float(_layout["title_size"]) * context.text_scale)), Tokens.role_color("focus"))
	draw_string(ShareTechMono, _layout["header"].position + Vector2(0, 28), "FOLLOW THE CLEAN PATH. LOCKED NODES EXPLAIN THE BLOCK.", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(14.0 * context.text_scale)), Tokens.role_color("muted"))
	if not bool(_layout.get("density", context.density) == "narrow") or not _narrow_detail:
		draw_polyline(Tokens.frame_points(_layout["list"], 10), Tokens.role_color("structure"), 1.0, true)
	if not bool(_layout.get("density", context.density) == "narrow") or _narrow_detail:
		draw_polyline(Tokens.frame_points(_layout["detail"], 10), Tokens.role_color("structure"), 1.0, true)
	var stage: Dictionary = Game.story_stage_def(_selected)
	if not bool(_layout.get("density", context.density) == "narrow") or _narrow_detail:
		for entry in _detail_entries(stage, context.text_scale):
			var entry_rect: Rect2 = entry["rect"]
			var entry_font: Font = Orbitron if int(entry["size"]) >= 24 else ShareTechMono
			draw_multiline_string(entry_font, entry_rect.position + Vector2(0, float(entry["size"])), str(entry["text"]), HORIZONTAL_ALIGNMENT_LEFT, entry_rect.size.x, int(round(float(entry["size"]) * context.text_scale)), 6, Tokens.role_color("focus") if entry["id"] == "identity" else Tokens.role_color("structure"))

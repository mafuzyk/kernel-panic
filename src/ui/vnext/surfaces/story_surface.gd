class_name VNextStorySurface
extends Control

const Context = preload("res://src/ui/vnext/ui_context.gd")
const Chrome = preload("res://src/ui/vnext/ui_chrome.gd")
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
		tab.alignment = HORIZONTAL_ALIGNMENT_CENTER
		tab.add_theme_font_override("font", ShareTechMono)
		tab.add_theme_font_size_override("font_size", 14)
		_style_action_button(tab, 4.0, 4.0)
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
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_override("font", ShareTechMono)
		button.add_theme_font_size_override("font_size", 14)
		_style_action_button(button, 28.0, 94.0)
		button.pressed.connect(_on_stage_pressed.bind(i))
		button.focus_entered.connect(_on_stage_focus.bind(i))
		button.gui_input.connect(_on_button_gui_input)
		list.add_child(button)
		_buttons["stage_%d" % i] = button
	var launch := Button.new()
	launch.name = "LaunchAction"
	launch.focus_mode = Control.FOCUS_ALL
	launch.mouse_filter = Control.MOUSE_FILTER_STOP
	launch.flat = true
	launch.alignment = HORIZONTAL_ALIGNMENT_LEFT
	launch.add_theme_font_override("font", ShareTechMono)
	launch.add_theme_font_size_override("font_size", 16)
	_style_action_button(launch, 22.0, 14.0)
	launch.gui_input.connect(_on_button_gui_input)
	launch.pressed.connect(_on_launch_pressed)
	add_child(launch)
	_buttons["launch_story"] = launch
	var list_view := Button.new()
	list_view.name = "ListAction"
	list_view.text = "< NODE LIST"
	list_view.focus_mode = Control.FOCUS_ALL
	list_view.mouse_filter = Control.MOUSE_FILTER_STOP
	list_view.flat = true
	list_view.alignment = HORIZONTAL_ALIGNMENT_LEFT
	list_view.add_theme_font_override("font", ShareTechMono)
	list_view.add_theme_font_size_override("font_size", 14)
	_style_action_button(list_view, 12.0, 10.0)
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
	back.add_theme_font_size_override("font_size", 14)
	_style_action_button(back, 18.0, 12.0)
	back.gui_input.connect(_on_button_gui_input)
	back.pressed.connect(_on_back_pressed)
	add_child(back)
	_buttons["back"] = back

func _style_action_button(button: Button, left_margin: float, right_margin: float) -> void:
	button.add_theme_color_override("font_color", Tokens.role_color("structure"))
	button.add_theme_color_override("font_hover_color", Tokens.role_color("focus"))
	button.add_theme_color_override("font_focus_color", Tokens.role_color("focus"))
	button.add_theme_color_override("font_pressed_color", Tokens.role_color("focus"))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		style.content_margin_left = left_margin
		style.content_margin_right = right_margin
		button.add_theme_stylebox_override(state, style)

func configure(next_snapshot: Dictionary, next_context: RefCounted) -> void:
	var was_narrow: bool = context != null and context.density == "narrow"
	var previous_view: bool = _narrow_detail
	snapshot = next_snapshot.duplicate(true)
	context = next_context
	var requested_act := str(snapshot.get("act", _act)).to_lower()
	if requested_act in ACT_IDS:
		_act = requested_act
	_narrow_detail = previous_view if was_narrow and context.density == "narrow" else context.density != "narrow"
	_selected = clampi(int(snapshot.get("selected", 0)), 0, maxi(Game.story_stage_count() - 1, 0))
	var visible := _visible_stage_indices()
	if _selected not in visible and not visible.is_empty():
		_selected = visible[0]
	_focus = "stage_%d" % _selected
	_layout = _make_layout()
	_apply_layout()
	_update_buttons()
	queue_redraw()

func _make_layout() -> Dictionary:
	var safe: Rect2 = context.safe_rect
	var density: String = context.density
	var pad := 24.0 if density == "wide" else 16.0
	var shell_meta := Rect2(safe.position + Vector2(pad, 16.0), Vector2(maxf(0.0, safe.size.x - pad * 2.0), 30.0))
	var header_h := 68.0 if density == "wide" else 62.0
	var header := Rect2(safe.position + Vector2(pad, 54.0), Vector2(maxf(0.0, safe.size.x - pad * 2.0), header_h))
	var tabs := Rect2(safe.position + Vector2(pad, header.end.y - safe.position.y + 6.0), Vector2(maxf(0.0, safe.size.x - pad * 2.0), 44.0 if density != "narrow" else 48.0))
	var footer := Rect2(safe.position + Vector2(pad, safe.size.y - 100.0), Vector2(maxf(0.0, safe.size.x - pad * 2.0), 24.0))
	var back := Rect2(safe.position + Vector2(pad, safe.size.y - pad - 48.0), Vector2(minf(150.0, maxf(0.0, safe.size.x - pad * 2.0)), 48.0))
	var launch_width := minf(360.0, maxf(0.0, safe.size.x - pad * 2.0))
	var launch := Rect2(Vector2(safe.end.x - pad - launch_width, back.position.y), Vector2(launch_width, 52.0))
	var content_y := tabs.end.y + 14.0
	var list: Rect2
	var detail: Rect2
	if density == "narrow":
		launch = Rect2(safe.position + Vector2(pad, safe.size.y - pad - 112.0), Vector2(maxf(0.0, safe.size.x - pad * 2.0), 52.0))
		var content_height := maxf(0.0, launch.position.y - content_y - 12.0)
		list = Rect2(safe.position + Vector2(pad, content_y - safe.position.y), Vector2(maxf(0.0, safe.size.x - pad * 2.0), content_height))
		detail = list
	else:
		var content_height := maxf(120.0, footer.position.y - content_y - 14.0)
		var list_width := minf(340.0, maxf(220.0, safe.size.x * (0.27 if density == "wide" else 0.34)))
		list = Rect2(safe.position + Vector2(pad, content_y - safe.position.y), Vector2(list_width, content_height))
		var detail_x := list.end.x + (22.0 if density == "wide" else 16.0)
		detail = Rect2(Vector2(detail_x, content_y), Vector2(maxf(0.0, safe.end.x - detail_x - pad), content_height))
	var evidence_height := 96.0 if density == "narrow" else 100.0
	var evidence_band := Rect2(detail.position + Vector2(12.0 if density == "narrow" else 18.0, maxf(0.0, detail.size.y - evidence_height - 12.0)), Vector2(maxf(0.0, detail.size.x - (24.0 if density == "narrow" else 36.0)), evidence_height))
	var detail_content := Rect2(detail.position + Vector2(14.0 if density == "narrow" else 18.0, 42.0), Vector2(maxf(0.0, detail.size.x - (28.0 if density == "narrow" else 36.0)), maxf(0.0, evidence_band.position.y - detail.position.y - 54.0)))
	var signature_rail := Rect2(safe.position + Vector2(8.0, 52.0), Vector2(8.0, maxf(0.0, safe.size.y - 82.0)))
	return {
		"safe": safe,
		"shell": safe,
		"shell_meta": shell_meta,
		"header": header,
		"tabs": tabs,
		"list": list,
		"detail": detail,
		"detail_content": detail_content,
		"evidence_band": evidence_band,
		"signature_rail": signature_rail,
		"footer": footer,
		"launch_story": launch,
		"back": back,
		"narrow": density == "narrow",
		"compact": density == "compact",
		"title_size": 28 if density == "wide" else 24 if density == "compact" else 21,
	}

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
	list.position = _layout["list"].position + Vector2(0.0, 38.0)
	list.size = Vector2(_layout["list"].size.x, maxf(0.0, _layout["list"].size.y - 38.0))
	var visible_indices := _visible_stage_indices()
	var list_separation := 6.0
	var row_h := minf(52.0, maxf(46.0, (list.size.y - list_separation * maxf(visible_indices.size() - 1, 0)) / maxf(visible_indices.size(), 1)))
	for button in list.get_children():
		var index := int(button.name.trim_prefix("stage_"))
		button.visible = index in visible_indices and (context.density != "narrow" or not _narrow_detail)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(_layout["list"].size.x, row_h)
		button.add_theme_font_size_override("font_size", int(round((14.0 if context.density == "wide" else 13.0) * context.text_scale)))
	var launch: Button = _buttons["launch_story"]
	launch.position = _layout["launch_story"].position
	launch.size = _layout["launch_story"].size
	launch.add_theme_font_size_override("font_size", int(round((16.0 if context.density != "narrow" else 14.0) * context.text_scale)))
	var back: Button = _buttons["back"]
	back.position = _layout["back"].position
	back.size = _layout["back"].size
	back.add_theme_font_size_override("font_size", int(round((14.0 if context.density != "narrow" else 13.0) * context.text_scale)))
	var list_view: Button = _buttons["list_view"]
	if context.density == "narrow":
		list_view.position = _layout["detail"].position + Vector2(maxf(0.0, _layout["detail"].size.x - 166.0), 8.0)
		list_view.size = Vector2(minf(154.0, _layout["detail"].size.x), 34.0)
	else:
		list_view.position = _layout["detail"].position + Vector2(14.0, maxf(0.0, _layout["detail"].size.y - 48.0))
		list_view.size = Vector2(minf(190.0, _layout["detail"].size.x), 40.0)
	list_view.add_theme_font_size_override("font_size", int(round((13.0 if context.density == "narrow" else 14.0) * context.text_scale)))
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
		var compact_label := "NODE %02d  %s" % [i + 1, "LOCKED" if state == "locked" else "CLEARED" if state == "cleared" else "READY"]
		_buttons[key].text = compact_label if context.density == "narrow" else _display_path(stage)
		_buttons[key].add_theme_color_override("font_color", Tokens.role_color("focus") if _selected == i else Tokens.role_color("ready") if state != "locked" else Tokens.role_color("muted"))
		_buttons[key].tooltip_text = str(stage.get("title", "NODE")) + " // " + marker
	var selected_stage: Dictionary = Game.story_stage_def(_selected)
	var launch: Button = _buttons["launch_story"]
	launch.text = ">> MOUNT %s  [ENTER]" % str(selected_stage.get("path", "/boot"))
	launch.disabled = not Game.story_stage_unlocked(_selected)
	launch.add_theme_color_override("font_color", Tokens.role_color("ready") if not launch.disabled else Tokens.role_color("muted"))

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
	var shell_meta_text := "ONLINE    KP://STORY    GUEST" if context.density == "narrow" else "SYSTEM ONLINE    KP://STORY    USER: GUEST"
	var footer_text := "ACT %s    NODES %02d/%02d    BUILD %s" % [_act.to_upper(), _cleared_count(), _visible_stage_indices().size(), _build_string()]
	var evidence_text := "NODE STATUS    STATE %s    ACT %s    NEXT %s" % [_stage_state(_selected).to_upper(), str(stage.get("act", _act)).to_upper(), _next_action_text(stage)]
	var entries := [
		{"id": "shell_meta", "text": shell_meta_text, "rect": _layout["shell_meta"], "size": 12, "inset": 8.0},
		{"id": "title", "text": "STORY // MOUNT TABLE", "rect": _layout["header"], "size": _layout["title_size"]},
		{"id": "subtitle", "text": _subtitle_text(), "rect": _layout["header"], "size": 14},
		{"id": "evidence", "text": evidence_text, "rect": _layout["evidence_band"], "size": 10, "inset": 28.0},
	]
	var narrow: bool = context.density == "narrow"
	if not narrow or not _narrow_detail:
		entries.append({"id": "footer", "text": footer_text, "rect": _layout["footer"], "size": 11, "inset": 8.0})
	for act in ACT_IDS:
		var tab_index := ACT_IDS.find(act)
		entries.append({"id": "act_" + act, "text": _tab_label(act), "rect": Rect2(_layout["tabs"].position + Vector2(tab_index * _layout["tabs"].size.x / float(ACT_IDS.size()), 0), Vector2(_layout["tabs"].size.x / float(ACT_IDS.size()), _layout["tabs"].size.y)), "size": 14 if context.density != "narrow" else 12})
	if not narrow or not _narrow_detail:
		for i in _visible_stage_indices():
			var key := "stage_%d" % i
			entries.append({"id": key, "text": str(_buttons[key].text), "rect": _local_button_rect(_buttons[key]), "size": 14})
			var state := _stage_state(i)
			entries.append({"id": key + "_state", "text": "LOCKED" if state == "locked" else "CLEARED" if state == "cleared" else "READY", "rect": Rect2(_local_button_rect(_buttons[key]).end - Vector2(86.0, 0.0), Vector2(74.0, _local_button_rect(_buttons[key]).size.y)), "size": 10})
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
	var stage: Dictionary = Game.story_stage_def(_selected)
	var state := _stage_state(_selected)
	var result := {
		"screen": "story_select",
		"visual_system": "reference_shell",
		"route": "KP://STORY",
		"selected": _selected,
		"act": _act,
		"focus": _focus,
		"tabs": ACT_IDS.duplicate(),
		"view": "detail" if context.density != "narrow" or _narrow_detail else "list",
		"identity": stage.get("title", ""),
		"state": state,
		"next_action": _next_action_text(stage),
		"composition": {"shell": "persistent", "tabs": "act_index", "list": "node_index", "detail": "stage_dossier", "footer": "telemetry", "chrome": "incident_console", "density": "evidence_blocks"},
		"evidence": {"node": {"state": state, "act": str(stage.get("act", _act)), "next": _next_action_text(stage)}},
	}
	for i in Game.story_stage_count():
		var stage_def: Dictionary = Game.story_stage_def(i)
		result["stage_%d" % i] = {"id": stage_def.get("id", ""), "title": stage_def.get("title", ""), "state": _stage_state(i), "reason": "clear previous node" if _stage_state(i) == "locked" else ""}
	return result

func _next_action_text(stage: Dictionary) -> String:
	return "MOUNT " + str(stage.get("path", "/boot")) if Game.story_stage_unlocked(_selected) else "CLEAR PREVIOUS NODE"

func _cleared_count() -> int:
	var count := 0
	for index in _visible_stage_indices():
		if Game.story_cleared.get(Game.story_stage_id(index), false):
			count += 1
	return count

func _build_string() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "dev"))

func _subtitle_text() -> String:
	return "FOLLOW CLEAN PATH // READ THE BLOCK" if context.density == "narrow" else "FOLLOW THE CLEAN PATH. LOCKED NODES EXPLAIN THE BLOCK."

func _display_path(stage: Dictionary) -> String:
	return str(stage.get("path", "NODE"))

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
	var origin: Vector2 = get_node("StoryList").position if in_list else Vector2.ZERO
	return Rect2(origin + button.position, button.size)

func _detail_entries(stage: Dictionary, scale: float) -> Array:
	var content: Rect2 = _layout.get("detail_content", _layout["detail"])
	var width := maxf(content.size.x, 1.0)
	var y := content.position.y
	var entries := []
	var rule_label := "RULE    " + str(stage.get("act_rule", "standard")).replace("_", " ").to_upper()
	var reward_label := "REWARD  " + str(stage.get("reward_id", "NONE")).to_upper()
	var items: Array = [["identity", str(stage.get("title", "")), 22], ["path", str(stage.get("path", "")), 14], ["briefing", str(stage.get("intro", "")), 14], ["rule", rule_label, 14], ["reward", reward_label, 14], ["status", "STATUS  " + _stage_state(_selected).to_upper(), 14], ["best", "BEST    %07d" % Game.story_stage_best(_selected), 14]]
	if context.density == "narrow":
		items = items.slice(0, 5)
		items.append(["status", "STATUS  %s // BEST %07d" % [_stage_state(_selected).to_upper(), Game.story_stage_best(_selected)], 14])
	for item in items:
		var font: Font = Orbitron if int(item[2]) >= 24 else ShareTechMono
		var height := maxf(24.0, font.get_multiline_string_size(item[1], HORIZONTAL_ALIGNMENT_LEFT, width, int(round(float(item[2]) * scale))).y + 4.0)
		entries.append({"id": item[0], "text": item[1], "rect": Rect2(Vector2(content.position.x, y), Vector2(width, height)), "size": item[2], "inset": 0.0})
		y += height + 4.0
	return entries

func _draw() -> void:
	if context == null or _layout.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, size), Tokens.role_color("background"))
	Chrome.draw_shell(self, _layout["shell"], context.density, "KP://STORY", context.text_scale, context.high_contrast)
	draw_string(Orbitron, _layout["header"].position, "STORY // MOUNT TABLE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(float(_layout["title_size"]) * context.text_scale)), Tokens.role_color("focus"))
	draw_string(ShareTechMono, _layout["header"].position + Vector2(0, 28), _subtitle_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(14.0 * context.text_scale)), Tokens.role_color("muted"))
	draw_line(_layout["header"].position + Vector2(0.0, _layout["header"].size.y - 8.0), _layout["header"].end - Vector2(0.0, 8.0), Color(Tokens.role_color("structure"), 0.32), 1.0, true)
	if context.density != "narrow" or not _narrow_detail:
		_draw_footer()
	_draw_tabs()
	var stage: Dictionary = Game.story_stage_def(_selected)
	if not bool(_layout["narrow"]) or not _narrow_detail:
		_draw_stage_list()
	if not bool(_layout["narrow"]) or _narrow_detail:
		_draw_stage_dossier(stage)
	var launch_color := Tokens.role_color("focus") if _focus == "launch_story" else Tokens.role_color("ready") if not _buttons["launch_story"].disabled else Tokens.role_color("muted")
	if _buttons["launch_story"].visible:
		draw_polyline(Tokens.frame_points(_layout["launch_story"], 8.0), launch_color, 1.8 if _focus == "launch_story" else 1.0, true)
	if _buttons["back"].visible:
		draw_polyline(Tokens.frame_points(_layout["back"], 8.0), Tokens.role_color("focus") if _focus == "back" else Tokens.role_color("structure"), 1.8 if _focus == "back" else 1.0, true)
	if _buttons["list_view"].visible:
		draw_polyline(Tokens.frame_points(_local_button_rect(_buttons["list_view"], false), 7.0), Tokens.role_color("focus"), 1.3, true)

func _draw_footer() -> void:
	var rect: Rect2 = _layout["footer"]
	var accent := Tokens.role_color("structure")
	var muted := Tokens.role_color("muted")
	draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color(accent.r, accent.g, accent.b, 0.42), 1.0, true)
	var font_size := int(round(11.0 * context.text_scale))
	var visible_count := _visible_stage_indices().size()
	var node_text := "N %02d/%02d" % [_cleared_count(), visible_count] if context.density == "narrow" else "NODES %02d/%02d" % [_cleared_count(), visible_count]
	var act_text := "ACT " + _act.to_upper()
	var build_text := _build_string()
	draw_string(ShareTechMono, rect.position + Vector2(0.0, 17.0), act_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, accent)
	draw_string(ShareTechMono, Vector2(rect.get_center().x - 30.0 * context.text_scale, rect.position.y + 17.0), node_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, muted)
	draw_string(ShareTechMono, rect.end - Vector2((42.0 if context.density == "narrow" else 82.0) * context.text_scale, rect.size.y - 17.0), build_text if context.density == "narrow" else "BUILD " + build_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, muted)

func _draw_tabs() -> void:
	var rect: Rect2 = _layout["tabs"]
	var tab_width := rect.size.x / float(ACT_IDS.size())
	var structure := Tokens.role_color("structure")
	draw_line(rect.position + Vector2(0.0, rect.size.y - 1.0), Vector2(rect.end.x, rect.end.y - 1.0), Color(structure.r, structure.g, structure.b, 0.48), 1.0, true)
	for index in ACT_IDS.size():
		var act: String = ACT_IDS[index]
		var cell := Rect2(rect.position + Vector2(tab_width * index, 0.0), Vector2(tab_width, rect.size.y))
		var unlocked := Game.story_act_unlocked(act) if Game.has_method("story_act_unlocked") else true
		var color := Tokens.role_color("focus") if act == _act else Tokens.role_color("structure") if unlocked else Tokens.role_color("muted")
		if act == _act:
			draw_colored_polygon(Tokens.frame_points(cell.grow(-2.0), 5.0), Color(color.r, color.g, color.b, 0.055))
			draw_line(cell.position + Vector2(10.0, 1.0), Vector2(cell.end.x - 10.0, cell.position.y + 1.0), color, 1.5, true)
			draw_rect(Rect2(cell.get_center() - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), color)

func _draw_stage_list() -> void:
	var rect: Rect2 = _layout["list"]
	var structure := Tokens.role_color("structure")
	var points := Tokens.frame_points(rect, 11.0)
	draw_colored_polygon(points, Color(structure.r, structure.g, structure.b, 0.025))
	draw_polyline(points + PackedVector2Array([points[0]]), Color(structure.r, structure.g, structure.b, 0.68), 1.1, true)
	draw_string(ShareTechMono, rect.position + Vector2(18.0, 24.0), "NODE INDEX // %02d STAGES" % _visible_stage_indices().size(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(11.0 * context.text_scale)), structure)
	draw_line(rect.position + Vector2(18.0, 34.0), rect.end - Vector2(18.0, rect.size.y - 34.0), Color(structure.r, structure.g, structure.b, 0.26), 1.0, true)
	for index in _visible_stage_indices():
		var key := "stage_%d" % index
		var button: Button = _buttons[key]
		if not button.visible:
			continue
		var row := _local_button_rect(button)
		var state := _stage_state(index)
		var selected: bool = index == _selected
		var row_color := Tokens.role_color("focus") if selected else Tokens.role_color("ready") if state != "locked" else Tokens.role_color("muted")
		if selected:
			draw_colored_polygon(Tokens.frame_points(row.grow(-2.0), 6.0), Color(row_color.r, row_color.g, row_color.b, 0.08))
		draw_line(row.position + Vector2(12.0, row.size.y - 1.0), row.end - Vector2(12.0, 1.0), Color(row_color.r, row_color.g, row_color.b, 0.22), 1.0, true)
		var marker := row.position + Vector2(16.0, row.size.y * 0.5)
		if selected:
			draw_colored_polygon(PackedVector2Array([marker + Vector2(-5.0, 0.0), marker + Vector2(4.0, -5.0), marker + Vector2(4.0, 5.0)]), row_color)
		else:
			draw_rect(Rect2(marker - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), Color(row_color.r, row_color.g, row_color.b, 0.56), false, 1.0)
		if context.density != "narrow":
			var state_label := "LOCKED" if state == "locked" else "CLEARED" if state == "cleared" else "READY"
			draw_string(ShareTechMono, Vector2(row.end.x - 86.0, row.position.y + row.size.y * 0.5 + 4.0), state_label, HORIZONTAL_ALIGNMENT_RIGHT, 74.0, int(round(10.0 * context.text_scale)), row_color)

func _stage_accent(stage: Dictionary) -> Color:
	var theme: Variant = stage.get("theme", {})
	if theme is Dictionary and theme.get("accent", null) is Color:
		return theme["accent"]
	return Tokens.role_color("structure")

func _draw_stage_dossier(stage: Dictionary) -> void:
	var rect: Rect2 = _layout["detail"]
	var accent := _stage_accent(stage)
	var structure := Tokens.role_color("structure")
	var points := Tokens.frame_points(rect, 11.0)
	draw_colored_polygon(points, Color(accent.r, accent.g, accent.b, 0.018))
	draw_polyline(points + PackedVector2Array([points[0]]), Color(accent.r, accent.g, accent.b, 0.74), 1.2, true)
	draw_string(ShareTechMono, rect.position + Vector2(18.0, 24.0), "NODE DOSSIER // %s" % _stage_state(_selected).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(11.0 * context.text_scale)), accent)
	if context.density != "narrow":
		draw_string(ShareTechMono, Vector2(rect.end.x - 108.0, rect.position.y + 24.0), "WAVES %02d" % stage.get("waves", []).size(), HORIZONTAL_ALIGNMENT_RIGHT, 90.0, int(round(11.0 * context.text_scale)), structure)
	for entry in _detail_entries(stage, context.text_scale):
		var entry_rect: Rect2 = entry["rect"]
		var entry_font: Font = Orbitron if int(entry["size"]) >= 24 else ShareTechMono
		var entry_color := Tokens.role_color("focus") if entry["id"] == "identity" else accent if entry["id"] in ["path", "rule"] else structure
		draw_multiline_string(entry_font, entry_rect.position + Vector2(0, float(entry["size"])), str(entry["text"]), HORIZONTAL_ALIGNMENT_LEFT, entry_rect.size.x, int(round(float(entry["size"]) * context.text_scale)), 6, entry_color)
	var next_color := Tokens.role_color("ready") if Game.story_stage_unlocked(_selected) else Tokens.role_color("muted")
	Chrome.draw_evidence_block(self, _layout.get("evidence_band", Rect2()), "NODE STATUS", [
		{"label": "STATE", "value": _stage_state(_selected).to_upper(), "color": next_color},
		{"label": "ACT", "value": str(stage.get("act", _act)).to_upper(), "color": accent},
		{"label": "NEXT", "value": _next_action_text(stage), "color": next_color},
	], accent, context.text_scale)

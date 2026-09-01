class_name VNextAccessibilitySurface
extends Control

const Context = preload("res://src/ui/vnext/ui_context.gd")
const Tokens = preload("res://src/ui/vnext/ui_tokens.gd")
const Navigation = preload("res://src/ui/vnext/ui_navigation.gd")
const Orbitron: Font = preload("res://assets/fonts/Orbitron.ttf")
const ShareTechMono: Font = preload("res://assets/fonts/ShareTechMono.ttf")

signal action_requested(action_id: String, payload: Dictionary)

var context: RefCounted
var snapshot := {}
var _layout := {}
var _focus := "color_assist"
var _navigation: RefCounted
var _buttons: Dictionary = {}
var _gui_event_ids := {}
var activation_count := 0
var last_action_id := ""
var _reset_confirmed := false
var _reset_completed := false
var _status := "APPLIED IN MEMORY / PERSISTED"

static func context_for_viewport(viewport: Vector2, touch := false, reduced := false, contrast := false, scale := 1.0) -> RefCounted:
	return Context.from_viewport(viewport, touch, reduced, contrast, scale)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_navigation = Navigation.new()
	for action_id in ["color_assist", "haptics_enabled", "shake_level", "touch_scale", "offensive_music", "defensive_music", "reset_accessibility", "back"]:
		_create_button(action_id)

func configure(next_snapshot: Dictionary, next_context: RefCounted) -> void:
	snapshot = next_snapshot.duplicate(true)
	context = next_context
	_layout = _layout_for_context()
	_navigation.set_focus_order(_focus_ids())
	set_focus_id(_focus if _focus in _focus_ids() else "color_assist")
	_apply_layout()
	_update_labels()
	queue_redraw()

func layout_snapshot() -> Dictionary:
	return {"density": context.density, "safe_rect": context.safe_rect, "regions": _layout.duplicate(true)}

func action_regions() -> Dictionary:
	var regions := {}
	for action_id in _focus_ids():
		regions[action_id] = {"rect": _layout.get(action_id, Rect2()), "label": _label_for(action_id), "state": _state_for(action_id)}
	return regions

func semantic_snapshot() -> Dictionary:
	return {
		"screen": "settings/accessibility",
		"title": "ACCESSIBILITY",
		"selected_tab": "ACCESSIBILITY",
		"focus": _focus,
		"states": {
			"color_assist": "ON" if bool(Sfx.color_assist) else "OFF",
			"haptics_enabled": "ON" if bool(Sfx.haptics_enabled) else "OFF",
			"shake_level": ["OFF", "LOW", "FULL"][clampi(int(Sfx.shake_level), 0, 2)],
			"touch_scale": _touch_size_name(),
			"offensive_music": "ON" if bool(Sfx.offensive_music_enabled) else "OFF",
			"defensive_music": "ON" if bool(Sfx.defensive_music_enabled) else "OFF",
		},
		"status": _status,
		"reset_confirmed": _reset_completed,
		"reset_armed": _reset_confirmed,
		"unsupported_note": "NOT AVAILABLE YET: NATIVE SCREEN READERS / TEXT SCALING / HIGH CONTRAST",
		"navigation": _navigation.snapshot() if _navigation != null else {},
	}

func text_overflow_report() -> Array:
	if context == null or _layout.is_empty():
		return [{"id": "surface", "fits": false}]
	var entries := [
		{"id": "title", "text": "ACCESSIBILITY", "rect": _layout["title"], "font": Orbitron, "size": 28.0, "padding": 0.0},
		{"id": "explanation", "text": _explanation_text(), "rect": _layout["explanation"], "font": ShareTechMono, "size": 14.0, "padding": 0.0},
		{"id": "color_assist", "text": _label_for("color_assist"), "rect": _layout["color_assist"], "font": ShareTechMono, "size": 16.0, "padding": 24.0},
		{"id": "haptics_enabled", "text": _label_for("haptics_enabled"), "rect": _layout["haptics_enabled"], "font": ShareTechMono, "size": 16.0, "padding": 24.0},
		{"id": "shake_level", "text": _label_for("shake_level"), "rect": _layout["shake_level"], "font": ShareTechMono, "size": 16.0, "padding": 24.0},
		{"id": "touch_scale", "text": _label_for("touch_scale"), "rect": _layout["touch_scale"], "font": ShareTechMono, "size": 16.0, "padding": 24.0},
		{"id": "offensive_music", "text": _label_for("offensive_music"), "rect": _layout["offensive_music"], "font": ShareTechMono, "size": 16.0, "padding": 24.0},
		{"id": "defensive_music", "text": _label_for("defensive_music"), "rect": _layout["defensive_music"], "font": ShareTechMono, "size": 16.0, "padding": 24.0},
		{"id": "reset_accessibility", "text": _label_for("reset_accessibility"), "rect": _layout["reset_accessibility"], "font": ShareTechMono, "size": 15.0, "padding": 24.0},
		{"id": "back", "text": "< BACK", "rect": _layout["back"], "font": ShareTechMono, "size": 16.0, "padding": 24.0},
		{"id": "status", "text": _status, "rect": _layout["status"], "font": ShareTechMono, "size": 12.0, "padding": 0.0},
		{"id": "unsupported", "text": _unsupported_text(), "rect": _layout["unsupported"], "font": ShareTechMono, "size": 11.0, "padding": 0.0},
	]
	var report: Array = []
	for entry in entries:
		var font: Font = entry["font"]
		var measured := font.get_string_size(str(entry["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(float(entry["size"]) * context.text_scale)))
		var rect: Rect2 = entry["rect"]
		var available := maxf(rect.size.x - float(entry["padding"]), 0.0)
		report.append({"id": entry["id"], "fits": measured.x <= available and measured.y <= rect.size.y, "measured_width": measured.x, "available_width": available})
	return report

func handle_input(event: InputEvent) -> bool:
	var action := ""
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			action = _focus
		elif event.keycode in [KEY_TAB, KEY_DOWN]:
			set_focus_id(_navigation.move_focus(1))
			return true
		elif event.keycode == KEY_UP:
			set_focus_id(_navigation.move_focus(-1))
			return true
		elif event.keycode == KEY_ESCAPE:
			action = "back"
	elif event is InputEventMouseButton and event.pressed:
		action = _action_at(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		action = _action_at(event.position)
	if action.is_empty():
		return false
	return _dispatch_action(action)

func set_focus_id(id: String) -> bool:
	if _navigation == null or not _navigation.set_focus(id):
		return false
	_focus = id
	if _buttons.has(id) and is_inside_tree():
		(_buttons[id] as Button).grab_focus()
	queue_redraw()
	return true

func focus_id() -> String:
	return _focus

func _focus_ids() -> Array[String]:
	return ["color_assist", "haptics_enabled", "shake_level", "touch_scale", "offensive_music", "defensive_music", "reset_accessibility", "back"]

func _layout_for_context() -> Dictionary:
	var safe: Rect2 = context.safe_rect
	var width := minf(760.0, safe.size.x)
	var x := safe.position.x + (safe.size.x - width) * 0.5
	var y := safe.position.y + 24.0
	var gap := 8.0
	var h := 52.0
	var button_width := width
	var button_y := y + 104.0
	var actions := {}
	var ids := _focus_ids()
	for index in ids.size():
		actions[ids[index]] = Rect2(x, button_y + float(index) * (h + gap), button_width, h)
	return {
		"shell": safe,
		"title": Rect2(x, y, width, 42.0),
		"explanation": Rect2(x, y + 44.0, width, 24.0),
		"status": Rect2(x, y + 76.0, width, 20.0),
		"color_assist": actions["color_assist"],
		"haptics_enabled": actions["haptics_enabled"],
		"shake_level": actions["shake_level"],
		"touch_scale": actions["touch_scale"],
		"offensive_music": actions["offensive_music"],
		"defensive_music": actions["defensive_music"],
		"reset_accessibility": actions["reset_accessibility"],
		"back": actions["back"],
		"unsupported": Rect2(x, safe.end.y - 22.0, width, 18.0),
	}

func _create_button(action_id: String) -> void:
	var button := Button.new()
	button.name = action_id.capitalize()
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", ShareTechMono)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Tokens.role_color("structure"))
	button.add_theme_color_override("font_hover_color", Tokens.role_color("focus"))
	button.add_theme_color_override("font_focus_color", Tokens.role_color("focus"))
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.pressed.connect(_on_button_pressed.bind(action_id))
	button.focus_entered.connect(_on_button_focus.bind(action_id))
	button.gui_input.connect(_on_button_gui_input)
	add_child(button)
	_buttons[action_id] = button

func _apply_layout() -> void:
	for action_id in _focus_ids():
		var button: Button = _buttons[action_id]
		button.position = _layout[action_id].position
		button.size = _layout[action_id].size
		button.add_theme_font_size_override("font_size", int(round(16.0 * context.text_scale)))

func _update_labels() -> void:
	for action_id in _focus_ids():
		(_buttons[action_id] as Button).text = _label_for(action_id)

func _label_for(action_id: String) -> String:
	match action_id:
		"color_assist": return "COLOR ASSIST: %s" % ("ON" if Sfx.color_assist else "OFF")
		"haptics_enabled": return "HAPTICS: %s" % ("ON" if Sfx.haptics_enabled else "OFF")
		"shake_level": return "SCREEN SHAKE: %s" % ["OFF", "LOW", "FULL"][clampi(int(Sfx.shake_level), 0, 2)]
		"touch_scale": return "TOUCH SIZE: %s" % _touch_size_name()
		"offensive_music": return "PATCH PERCUSSION: %s" % ("ON" if Sfx.offensive_music_enabled else "OFF")
		"defensive_music": return "PATCH BASS: %s" % ("ON" if Sfx.defensive_music_enabled else "OFF")
		"reset_accessibility": return "CONFIRM RESET ACCESSIBILITY" if _reset_confirmed else "RESET ACCESSIBILITY"
	return "< BACK"

func _state_for(action_id: String) -> String:
	return "FOCUS" if action_id == _focus else "READY"

func _touch_size_name() -> String:
	return ["SMALL", "NORMAL", "BIG"][clampi([0.85, 1.0, 1.2].find(float(Sfx.touch_scale)), 0, 2)]

func _on_button_focus(action_id: String) -> void:
	_focus = action_id
	queue_redraw()

func _on_button_gui_input(event: InputEvent) -> void:
	_gui_event_ids[event.get_instance_id()] = true

func _on_button_pressed(action_id: String) -> void:
	_dispatch_action(action_id)

func _dispatch_action(action_id: String) -> bool:
	if _navigation == null:
		return false
	return _navigation.dispatch(action_id, _emit_action)

func _emit_action(action_id: String) -> void:
	activation_count += 1
	last_action_id = action_id
	_focus = action_id
	if action_id == "color_assist":
		Sfx.apply_accessibility_profile({"color_assist": not Sfx.color_assist})
		_status = "APPLIED / PERSISTED" if Sfx.last_accessibility_persisted else "SAVE FAILED / PREVIOUS VALUES RESTORED"
	elif action_id == "haptics_enabled":
		Sfx.apply_accessibility_profile({"haptics_enabled": not Sfx.haptics_enabled})
		_status = "APPLIED / PERSISTED" if Sfx.last_accessibility_persisted else "SAVE FAILED / PREVIOUS VALUES RESTORED"
	elif action_id == "shake_level":
		Sfx.apply_accessibility_profile({"shake_level": (int(Sfx.shake_level) + 1) % 3})
		_status = "APPLIED / PERSISTED" if Sfx.last_accessibility_persisted else "SAVE FAILED / PREVIOUS VALUES RESTORED"
	elif action_id == "touch_scale":
		var index := [0.85, 1.0, 1.2].find(float(Sfx.touch_scale))
		Sfx.apply_accessibility_profile({"touch_scale": [0.85, 1.0, 1.2][wrapi(index + 1, 0, 3)]})
		_status = "APPLIED / PERSISTED" if Sfx.last_accessibility_persisted else "SAVE FAILED / PREVIOUS VALUES RESTORED"
	elif action_id == "offensive_music":
		Sfx.apply_accessibility_profile({"offensive_music_enabled": not Sfx.offensive_music_enabled})
		_status = "APPLIED / PERSISTED" if Sfx.last_accessibility_persisted else "SAVE FAILED / PREVIOUS VALUES RESTORED"
	elif action_id == "defensive_music":
		Sfx.apply_accessibility_profile({"defensive_music_enabled": not Sfx.defensive_music_enabled})
		_status = "APPLIED / PERSISTED" if Sfx.last_accessibility_persisted else "SAVE FAILED / PREVIOUS VALUES RESTORED"
	elif action_id == "reset_accessibility":
		if _reset_confirmed:
			Sfx.reset_accessibility_profile()
			_reset_confirmed = false
			_reset_completed = true
			_status = "RESET / PERSISTED" if Sfx.last_accessibility_persisted else "RESET FAILED / PREVIOUS VALUES RESTORED"
		else:
			_reset_confirmed = true
			_reset_completed = false
			_status = "RESET ARMED — ACTIVATE AGAIN TO CONFIRM"
	_update_labels()
	queue_redraw()
	action_requested.emit(action_id, {"screen": "settings/accessibility", "status": _status})

func _action_at(point: Vector2) -> String:
	point = get_viewport().get_final_transform().affine_inverse() * point
	for action_id in _focus_ids():
		if (_layout[action_id] as Rect2).has_point(point):
			return action_id
	return ""

func _unhandled_input(event: InputEvent) -> void:
	var event_id := event.get_instance_id()
	if _gui_event_ids.has(event_id):
		_gui_event_ids.erase(event_id)
		get_viewport().set_input_as_handled()
		return
	if handle_input(event):
		get_viewport().set_input_as_handled()

func _draw() -> void:
	if context == null or _layout.is_empty():
		return
	var text_scale := float(context.text_scale)
	draw_rect(Rect2(Vector2.ZERO, size), Tokens.role_color("background"))
	draw_polyline(Tokens.frame_points(_layout["shell"], 16.0), Tokens.role_color("structure"), 1.5, true)
	draw_string(Orbitron, _layout["title"].position + Vector2(0, 28), "ACCESSIBILITY", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(28.0 * text_scale)), Tokens.role_color("focus"))
	draw_string(ShareTechMono, _layout["explanation"].position + Vector2(0, 16), _explanation_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(14.0 * text_scale)), Tokens.role_color("muted"))
	draw_string(ShareTechMono, _layout["status"].position + Vector2(0, 15), _status, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(12.0 * text_scale)), Tokens.role_color("muted"))
	draw_string(ShareTechMono, _layout["unsupported"].position + Vector2(0, 13), _unsupported_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(11.0 * text_scale)), Tokens.role_color("muted"))
	for action_id in _focus_ids():
		var color := Tokens.role_color("focus") if action_id == _focus else Tokens.role_color("structure")
		draw_polyline(Tokens.frame_points(_layout[action_id], 10.0), color, 2.0 if action_id == _focus else 1.0, true)

func _explanation_text() -> String:
	return "LIVE CONTROLS ONLY" if context != null and context.density == "narrow" else "REAL CONTROLS ONLY // VALUES APPLY TO THE LIVE GAME"

func _unsupported_text() -> String:
	return "NOT AVAILABLE YET: ASSISTIVE TECH" if context != null and context.density == "narrow" else "NOT AVAILABLE YET: NATIVE SCREEN READERS / TEXT SCALING / HIGH CONTRAST"

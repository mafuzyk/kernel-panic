class_name VNextBootSurface
extends Control

const Context = preload("res://src/ui/vnext/ui_context.gd")
const Layout = preload("res://src/ui/vnext/ui_layout.gd")
const Tokens = preload("res://src/ui/vnext/ui_tokens.gd")
const Illustration = preload("res://src/ui/vnext/entity_illustration.gd")
const Navigation = preload("res://src/ui/vnext/ui_navigation.gd")
const Orbitron: Font = preload("res://assets/fonts/Orbitron.ttf")
const ShareTechMono: Font = preload("res://assets/fonts/ShareTechMono.ttf")

signal action_requested(action_id: String, payload: Dictionary)

var context: RefCounted
var snapshot := {}
var _layout := {}
var _focus := "boot"
var activation_count := 0
var last_action_id := ""
var _illustration: Control
var _navigation: RefCounted
var _action_buttons: Dictionary = {}
var _gui_event_ids := {}

static func context_for_viewport(viewport: Vector2, touch := false, reduced := false, contrast := false, scale := 1.0) -> RefCounted:
	return Context.from_viewport(viewport, touch, reduced, contrast, scale)

func _ready() -> void:
	# The surface is a painted shell; child Buttons must receive pointer/touch
	# events instead of being shadowed by the parent Control.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_navigation = Navigation.new()
	_navigation.set_focus_order(_focus_ids())
	_create_action_button("boot", "BootAction")
	_create_action_button("program", "ProgramAction")
	_create_action_button("story", "StoryAction")
	_create_action_button("back", "BackAction")

func configure(next_snapshot: Dictionary, next_context: RefCounted) -> void:
	snapshot = next_snapshot.duplicate(true)
	context = next_context
	_layout = Layout.boot(context.viewport_size, context)
	_navigation.set_focus_order(_focus_ids())
	set_focus_id("boot")
	if _illustration == null:
		_illustration = Illustration.new()
		add_child(_illustration)
		_illustration.configure_entity("kernel", "ready", "PROCESS")
	_illustration.position = _layout["illustration"].position
	_illustration.size = _layout["illustration"].size
	_apply_action_layout()
	queue_redraw()

func layout_snapshot() -> Dictionary:
	return {"density": context.density, "safe_rect": context.safe_rect, "regions": _layout.duplicate(true)}

func action_regions() -> Dictionary:
	return {
		"boot": {"rect": _layout.get("boot", Rect2()), "label": "BOOT / RUN PROCESS", "state": "ready"},
		"program": {"rect": _layout.get("program", Rect2()), "label": "PROGRAMS", "state": "idle"},
		"story": {"rect": _layout.get("story", Rect2()), "label": "STORY", "state": "idle"},
		"back": {"rect": _layout.get("back", Rect2()), "label": "BACK", "state": "idle"},
	}

func text_overflow_report() -> Array:
	if context == null or _layout.is_empty():
		return [{"id": "surface", "fits": false, "measured_width": 0.0, "available_width": 0.0}]
	var text_scale := float(context.text_scale)
	var entries := [
		{"id": "title", "text": "KERNEL PANIC", "rect": _layout["title"], "font": Orbitron, "font_size": 32.0, "padding": 0.0},
		{"id": "subtitle", "text": "LAST PROCESS // READY TO MOUNT", "rect": _layout["title"], "font": ShareTechMono, "font_size": 16.0, "padding": 0.0},
		{"id": "telemetry", "text": "PROGRAM  %s    BEST  %07d" % [str(snapshot.get("program", "kernel")).to_upper(), int(snapshot.get("best", 0))], "rect": _layout["telemetry"], "font": ShareTechMono, "font_size": 17.0, "padding": 0.0},
		{"id": "boot", "text": str(_layout.get("boot_label", ">> BOOT / RUN PROCESS  [ENTER]")), "rect": _layout["boot"], "font": ShareTechMono, "font_size": 20.0, "padding": 44.0},
		{"id": "program", "text": "PROGRAMS", "rect": _layout["program"], "font": ShareTechMono, "font_size": 14.0, "padding": 20.0},
		{"id": "story", "text": "STORY", "rect": _layout["story"], "font": ShareTechMono, "font_size": 14.0, "padding": 20.0},
		{"id": "back", "text": "< BACK", "rect": _layout["back"], "font": ShareTechMono, "font_size": 16.0, "padding": 20.0},
	]
	var report: Array = []
	for entry in entries:
		var font: Font = entry["font"]
		var measured := font.get_string_size(str(entry["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(float(entry["font_size"]) * text_scale)))
		var available := maxf(float(entry["rect"].size.x) - float(entry["padding"]), 0.0)
		report.append({"id": entry["id"], "fits": measured.x <= available and measured.y <= float(entry["rect"].size.y), "measured_width": measured.x, "available_width": available})
	return report

func semantic_snapshot() -> Dictionary:
	return {
		"screen": "boot",
		"title": "KERNEL PANIC",
		"primary_action": "BOOT / RUN PROCESS",
		"markers": {"ready": "READY", "locked": "LOCKED", "selected": "FOCUS"},
		"focus": _focus,
		"navigation": _navigation.snapshot() if _navigation != null else {},
	}

func focus_id() -> String:
	return _focus

func _focus_ids() -> Array[String]:
	return ["boot", "back", "program", "story"]

func set_focus_id(id: String) -> bool:
	if _navigation == null or not _navigation.set_focus(id):
		return false
	_focus = id
	if is_inside_tree() and _action_buttons.has(id):
		(_action_buttons[id] as Button).grab_focus()
	queue_redraw()
	return true

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

func _unhandled_input(event: InputEvent) -> void:
	var event_id := event.get_instance_id()
	if _gui_event_ids.has(event_id):
		_gui_event_ids.erase(event_id)
		# The child Button has already processed this GUI event. Stop the
		# surface/menu fallback from dispatching it a second time.
		get_viewport().set_input_as_handled()
		return
	if handle_input(event):
		get_viewport().set_input_as_handled()

func _create_action_button(action_id: String, node_name: String) -> void:
	var button := Button.new()
	button.name = node_name
	button.text = action_id.to_upper()
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.tooltip_text = "Activate %s" % action_id
	button.add_theme_font_override("font", ShareTechMono)
	button.add_theme_font_size_override("font_size", 20 if action_id == "boot" else 16)
	button.add_theme_color_override("font_color", Tokens.role_color("ready") if action_id == "boot" else Tokens.role_color("structure"))
	button.add_theme_color_override("font_hover_color", Tokens.role_color("focus"))
	button.add_theme_color_override("font_focus_color", Tokens.role_color("focus"))
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(_on_button_pressed.bind(action_id))
	button.focus_entered.connect(_on_button_focus.bind(action_id))
	button.gui_input.connect(_on_button_gui_input)
	add_child(button)
	_action_buttons[action_id] = button

func _on_button_gui_input(event: InputEvent) -> void:
	# Record the GUI event after the Button receives it. The matching
	# _unhandled_input call runs later, after the Button has completed its own
	# activation, and can then stop the fallback route without suppressing it.
	_gui_event_ids[event.get_instance_id()] = true

func _apply_action_layout() -> void:
	if _layout.is_empty():
		return
	var boot_button: Button = _action_buttons.get("boot")
	var back_button: Button = _action_buttons.get("back")
	if boot_button != null:
		boot_button.position = _layout["boot"].position
		boot_button.size = _layout["boot"].size
		boot_button.text = str(_layout.get("boot_label", ">> BOOT / RUN PROCESS  [ENTER]"))
		boot_button.add_theme_font_size_override("font_size", int(round(20.0 * float(context.text_scale))))
	if back_button != null:
		back_button.position = _layout["back"].position
		back_button.size = _layout["back"].size
		back_button.text = "< BACK"
		back_button.add_theme_font_size_override("font_size", int(round(16.0 * float(context.text_scale))))
	for action_id in ["program", "story"]:
		var button: Button = _action_buttons.get(action_id)
		if button != null:
			button.position = _layout[action_id].position
			button.size = _layout[action_id].size
			button.text = action_id.to_upper()
			button.add_theme_font_size_override("font_size", int(round(14.0 * float(context.text_scale))))

func _on_button_focus(action_id: String) -> void:
	if _navigation != null and _navigation.set_focus(action_id):
		_focus = action_id
		queue_redraw()

func _on_button_pressed(action_id: String) -> void:
	_dispatch_action(action_id)

func _dispatch_action(action_id: String) -> bool:
	if _navigation == null:
		return false
	return _navigation.dispatch(action_id, _emit_action)

func _emit_action(action_id: String) -> void:
	_focus = action_id
	last_action_id = action_id
	activation_count += 1
	action_requested.emit(action_id, {"screen": "boot", "program": str(snapshot.get("program", "kernel"))})

func _action_at(point: Vector2) -> String:
	# InputEvent pointer coordinates arrive in window space when the project
	# uses a stretch transform; the registry is kept in viewport space.
	point = get_viewport().get_final_transform().affine_inverse() * point
	var regions := action_regions()
	for id in regions:
		if (regions[id]["rect"] as Rect2).has_point(point):
			return id
	return ""

func _draw() -> void:
	if context == null or _layout.is_empty():
		return
	var shell: Rect2 = _layout["shell"]
	var text_scale := float(context.text_scale)
	draw_rect(Rect2(Vector2.ZERO, size), Tokens.role_color("background"))
	draw_polyline(Tokens.frame_points(shell, 16.0), Tokens.role_color("structure"), 1.5, true)
	draw_string(ShareTechMono, shell.position + Vector2(16, 28), "SYS://BOOT   STATUS: ONLINE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(16.0 * text_scale)), Tokens.role_color("structure"))
	draw_string(Orbitron, _layout["title"].position, "KERNEL PANIC", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(32.0 * text_scale)), Tokens.role_color("focus"))
	draw_string(ShareTechMono, _layout["title"].position + Vector2(0, 28.0 * text_scale), "LAST PROCESS // READY TO MOUNT", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(16.0 * text_scale)), Tokens.role_color("muted"))
	draw_string(ShareTechMono, _layout["telemetry"].position + Vector2(0, 22.0 * text_scale), "PROGRAM  %s    BEST  %07d" % [str(snapshot.get("program", "kernel")).to_upper(), int(snapshot.get("best", 0))], HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(17.0 * text_scale)), Tokens.role_color("structure"))
	var boot_color := Tokens.role_color("focus") if _focus == "boot" else Tokens.role_color("ready")
	var program_color := Tokens.role_color("focus") if _focus == "program" else Tokens.role_color("structure")
	var story_color := Tokens.role_color("focus") if _focus == "story" else Tokens.role_color("structure")
	var back_color := Tokens.role_color("focus") if _focus == "back" else Tokens.role_color("structure")
	draw_polyline(Tokens.frame_points(_layout["boot"], 12.0), boot_color, 2.0 if _focus == "boot" else 1.0, true)
	draw_polyline(Tokens.frame_points(_layout["program"], 10.0), program_color, 2.0 if _focus == "program" else 1.0, true)
	draw_polyline(Tokens.frame_points(_layout["story"], 10.0), story_color, 2.0 if _focus == "story" else 1.0, true)
	draw_polyline(Tokens.frame_points(_layout["back"], 10.0), back_color, 2.0 if _focus == "back" else 1.0, true)

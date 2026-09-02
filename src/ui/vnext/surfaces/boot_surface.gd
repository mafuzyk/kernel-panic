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
	_create_action_button("bestiary", "BestiaryAction")
	_create_action_button("back", "BackAction")
	_create_action_button("settings", "SettingsAction")

func configure(next_snapshot: Dictionary, next_context: RefCounted) -> void:
	snapshot = next_snapshot.duplicate(true)
	context = next_context
	_layout = Layout.boot(context.viewport_size, context)
	if bool(snapshot.get("settings_enabled", false)):
		_layout["settings"] = _settings_rect()
	else:
		_layout.erase("settings")
	_navigation.set_focus_order(_focus_ids())
	set_focus_id("boot")
	if _illustration == null:
		_illustration = Illustration.new()
		add_child(_illustration)
		_illustration.configure_entity("kernel", "ready", "PROCESS")
	_illustration.set_quality_profile("mobile" if context.input_mode == "touch" else "desktop", context.reduce_motion, context.high_contrast)
	_illustration.position = _layout["illustration"].position
	_illustration.size = _layout["illustration"].size
	_apply_action_layout()
	queue_redraw()

func layout_snapshot() -> Dictionary:
	return {"density": context.density, "safe_rect": context.safe_rect, "regions": _layout.duplicate(true)}

func action_regions() -> Dictionary:
	var regions := {
		"boot": {"rect": _layout.get("boot", Rect2()), "label": "BOOT / RUN PROCESS", "state": "ready"},
		"program": {"rect": _layout.get("program", Rect2()), "label": "PROGRAMS", "state": "idle"},
		"story": {"rect": _layout.get("story", Rect2()), "label": "STORY", "state": "idle"},
		"bestiary": {"rect": _layout.get("bestiary_action", Rect2()), "label": "BESTIARY", "state": "idle"},
		"back": {"rect": _layout.get("back", Rect2()), "label": "BACK", "state": "idle"},
	}
	if _layout.has("settings"):
		regions["settings"] = {"rect": _layout["settings"], "label": "SETTINGS", "state": "idle"}
	return regions

func text_overflow_report() -> Array:
	if context == null or _layout.is_empty():
		return [{"id": "surface", "fits": false, "measured_width": 0.0, "available_width": 0.0}]
	var text_scale := float(context.text_scale)
	var shell_meta_text := "ONLINE    KP://MAIN_MENU    GUEST" if context.density == "narrow" else "SYSTEM ONLINE    KP://MAIN_MENU    USER: GUEST"
	var boot_font_size := 20.0 if context.density == "wide" else 17.0 if context.density == "compact" else 18.0
	var entries := [
		{"id": "shell_meta", "text": shell_meta_text, "rect": _layout["shell_meta"], "font": ShareTechMono, "font_size": 12.0, "padding": 8.0},
		{"id": "title", "text": "KERNEL PANIC", "rect": _layout["title"], "font": Orbitron, "font_size": 32.0, "padding": 0.0},
		{"id": "subtitle", "text": "LAST PROCESS // READY TO MOUNT", "rect": _layout["title"], "font": ShareTechMono, "font_size": 16.0, "padding": 0.0},
		{"id": "identity", "text": "// EXECUTE OR DIE", "rect": _layout["identity"], "font": ShareTechMono, "font_size": 14.0, "padding": 28.0},
		{"id": "telemetry", "text": "PROGRAM  %s    BEST  %07d" % [str(snapshot.get("program", "kernel")).to_upper(), int(snapshot.get("best", 0))], "rect": _layout["telemetry"], "font": ShareTechMono, "font_size": 17.0, "padding": 0.0},
		{"id": "boot", "text": str(_layout.get("boot_label", ">> BOOT / RUN PROCESS  [ENTER]")), "rect": _layout["boot"], "font": ShareTechMono, "font_size": boot_font_size, "padding": 44.0},
		{"id": "program", "text": "PROGRAMS", "rect": _layout["program"], "font": ShareTechMono, "font_size": 14.0, "padding": 20.0},
		{"id": "story", "text": "STORY", "rect": _layout["story"], "font": ShareTechMono, "font_size": 14.0, "padding": 20.0},
		{"id": "bestiary", "text": "BESTIARY", "rect": _layout["bestiary_action"], "font": ShareTechMono, "font_size": 13.0, "padding": 12.0},
		{"id": "back", "text": "< BACK", "rect": _layout["back"], "font": ShareTechMono, "font_size": 16.0, "padding": 20.0},
		{"id": "footer", "text": "BEST RUN    SCORE    RANK    TIME", "rect": _layout["footer"], "font": ShareTechMono, "font_size": 11.0, "padding": 8.0},
	]
	if _layout.has("settings"):
		entries.append({"id": "settings", "text": "SETTINGS", "rect": _layout["settings"], "font": ShareTechMono, "font_size": 16.0, "padding": 20.0})
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
		"visual_system": "reference_shell",
		"route": "KP://MAIN_MENU",
		"title": "KERNEL PANIC",
		"primary_action": "BOOT / RUN PROCESS",
		"markers": {"ready": "READY", "locked": "LOCKED", "selected": "FOCUS"},
		"composition": {"shell": "persistent", "identity": "left", "navigation": "command_rail", "footer": "telemetry"},
		"focus": _focus,
		"navigation": _navigation.snapshot() if _navigation != null else {},
	}

func focus_id() -> String:
	return _focus

func _focus_ids() -> Array[String]:
	var ids: Array[String] = ["boot", "back", "program", "story", "bestiary"]
	if _layout.has("settings"):
		ids.append("settings")
	return ids

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
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.tooltip_text = "Activate %s" % action_id
	button.add_theme_font_override("font", ShareTechMono)
	button.add_theme_font_size_override("font_size", 20 if action_id == "boot" else 16)
	button.add_theme_color_override("font_color", Tokens.role_color("ready") if action_id == "boot" else Tokens.role_color("structure"))
	button.add_theme_color_override("font_hover_color", Tokens.role_color("focus"))
	button.add_theme_color_override("font_focus_color", Tokens.role_color("focus"))
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		style.border_width_left = 0
		style.border_width_top = 0
		style.border_width_right = 0
		style.border_width_bottom = 0
		style.content_margin_left = 48.0 if action_id == "boot" else 42.0
		style.content_margin_right = 16.0
		button.add_theme_stylebox_override(state, style)
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
		var boot_size := 20.0 if context.density == "wide" else 17.0 if context.density == "compact" else 18.0
		boot_button.add_theme_font_size_override("font_size", int(round(boot_size * float(context.text_scale))))
	if back_button != null:
		back_button.position = _layout["back"].position
		back_button.size = _layout["back"].size
		back_button.text = "< BACK"
		back_button.add_theme_font_size_override("font_size", int(round((14.0 if context.density == "narrow" else 16.0) * float(context.text_scale))))
	for action_id in ["program", "story"]:
		var button: Button = _action_buttons.get(action_id)
		if button != null:
			button.position = _layout[action_id].position
			button.size = _layout[action_id].size
			button.text = action_id.to_upper()
			button.add_theme_font_size_override("font_size", int(round(14.0 * float(context.text_scale))))
	var bestiary_button: Button = _action_buttons.get("bestiary")
	if bestiary_button != null:
		bestiary_button.visible = _layout.has("bestiary_action")
		if _layout.has("bestiary_action"):
			bestiary_button.position = _layout["bestiary_action"].position
			bestiary_button.size = _layout["bestiary_action"].size
			bestiary_button.text = "BESTIARY"
			bestiary_button.add_theme_font_size_override("font_size", int(round(13.0 * float(context.text_scale))))
	var settings_button: Button = _action_buttons.get("settings")
	if settings_button != null:
		settings_button.visible = _layout.has("settings")
		if _layout.has("settings"):
			settings_button.position = _layout["settings"].position
			settings_button.size = _layout["settings"].size
			settings_button.text = "SETTINGS"
			settings_button.add_theme_font_size_override("font_size", int(round((13.0 if context.density == "narrow" else 16.0) * float(context.text_scale))))

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
	_draw_ambient_grid(shell)
	draw_polyline(Tokens.frame_points(shell, 16.0), Tokens.role_color("structure"), 1.5, true)
	_draw_shell_meta(_layout["shell_meta"], text_scale)
	_draw_section_frame(_layout["identity"], Tokens.role_color("structure"), 0.42)
	_draw_section_frame(_layout["telemetry"], Tokens.role_color("structure"), 0.26)
	_draw_section_frame(_layout["navigation"], Tokens.role_color("structure"), 0.42)
	_draw_footer(_layout["footer"], text_scale)
	var title_rect: Rect2 = _layout["title"]
	var title_color := Tokens.role_color("focus")
	var title_size := int(round((48.0 if context.density == "wide" else 38.0) * text_scale))
	draw_string(Orbitron, title_rect.position, "KERNEL", HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, title_color)
	draw_string(Orbitron, title_rect.position + Vector2(0.0, float(title_size) * 1.02), "PANIC_", HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, title_color)
	draw_string(ShareTechMono, title_rect.position + Vector2(0.0, title_rect.size.y - 18.0 * text_scale), "// EXECUTE OR DIE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(14.0 * text_scale)), Tokens.role_color("danger"))
	var identity_meta: Vector2 = _layout["identity"].position + Vector2(28.0, _layout["identity"].size.y - 40.0)
	draw_string(ShareTechMono, identity_meta, "VERSION   0.2.3", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(12.0 * text_scale)), Tokens.role_color("muted"))
	draw_string(ShareTechMono, identity_meta + Vector2(0.0, 18.0 * text_scale), "SYSTEM    ZB-52041.70", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(12.0 * text_scale)), Tokens.role_color("muted"))
	_draw_telemetry(_layout["telemetry"], text_scale)
	_draw_navigation_header(_layout["navigation"], text_scale)
	_draw_navigation_icons(text_scale)
	var boot_color := Tokens.role_color("focus") if _focus == "boot" else Tokens.role_color("ready")
	var program_color := Tokens.role_color("focus") if _focus == "program" else Tokens.role_color("structure")
	var story_color := Tokens.role_color("focus") if _focus == "story" else Tokens.role_color("structure")
	var bestiary_color := Tokens.role_color("focus") if _focus == "bestiary" else Tokens.role_color("structure")
	var back_color := Tokens.role_color("focus") if _focus == "back" else Tokens.role_color("structure")
	var settings_color := Tokens.role_color("focus") if _focus == "settings" else Tokens.role_color("structure")
	draw_polyline(Tokens.frame_points(_layout["boot"], 12.0), boot_color, 2.0 if _focus == "boot" else 1.0, true)
	draw_polyline(Tokens.frame_points(_layout["program"], 10.0), program_color, 2.0 if _focus == "program" else 1.0, true)
	draw_polyline(Tokens.frame_points(_layout["story"], 10.0), story_color, 2.0 if _focus == "story" else 1.0, true)
	draw_polyline(Tokens.frame_points(_layout["bestiary_action"], 10.0), bestiary_color, 2.0 if _focus == "bestiary" else 1.0, true)
	draw_polyline(Tokens.frame_points(_layout["back"], 10.0), back_color, 2.0 if _focus == "back" else 1.0, true)
	if _layout.has("settings"):
		draw_polyline(Tokens.frame_points(_layout["settings"], 10.0), settings_color, 2.0 if _focus == "settings" else 1.0, true)

func _draw_ambient_grid(shell: Rect2) -> void:
	var grid_color := Tokens.role_color("structure")
	var step := 48.0 if context.density == "wide" else 36.0
	var x := shell.position.x + step
	while x < shell.end.x:
		draw_line(Vector2(x, shell.position.y + 46.0), Vector2(x, shell.end.y - 28.0), Color(grid_color.r, grid_color.g, grid_color.b, 0.035), 1.0, true)
		x += step
	var y := shell.position.y + 46.0
	while y < shell.end.y - 28.0:
		draw_line(Vector2(shell.position.x + 22.0, y), Vector2(shell.end.x - 22.0, y), Color(grid_color.r, grid_color.g, grid_color.b, 0.035), 1.0, true)
		y += step

func _draw_shell_meta(rect: Rect2, text_scale: float) -> void:
	var color := Tokens.role_color("structure")
	if context.density == "narrow":
		draw_string(ShareTechMono, rect.position, "■ ONLINE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(12.0 * text_scale)), color)
		draw_string(ShareTechMono, rect.get_center() - Vector2(32.0 * text_scale, -0.0), "KP://MENU", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(12.0 * text_scale)), color)
		draw_string(ShareTechMono, rect.end - Vector2(48.0 * text_scale, -4.0), "GUEST", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(12.0 * text_scale)), color)
	else:
		draw_string(ShareTechMono, rect.position, "■  SYSTEM ONLINE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(12.0 * text_scale)), color)
		draw_string(ShareTechMono, rect.get_center() - Vector2(64.0 * text_scale, -0.0), "KP://MAIN_MENU", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(12.0 * text_scale)), color)
		draw_string(ShareTechMono, rect.end - Vector2(108.0 * text_scale, -4.0), "USER: GUEST", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(12.0 * text_scale)), color)
	draw_line(Vector2(rect.position.x + 146.0, rect.position.y - 4.0), Vector2(rect.position.x + 244.0, rect.position.y - 4.0), Color(color.r, color.g, color.b, 0.5), 1.0, true)

func _draw_section_frame(rect: Rect2, color: Color, alpha: float) -> void:
	var points := Tokens.frame_points(rect, minf(12.0, rect.size.y * 0.2))
	draw_polyline(points + PackedVector2Array([points[0]]), Color(color.r, color.g, color.b, alpha), 1.0, true)
	draw_line(rect.position + Vector2(18.0, 16.0), rect.position + Vector2(minf(rect.size.x * 0.32, 164.0), 16.0), Color(color.r, color.g, color.b, alpha + 0.12), 1.0, true)

func _draw_telemetry(rect: Rect2, text_scale: float) -> void:
	var color := Tokens.role_color("structure")
	var muted := Tokens.role_color("muted")
	draw_string(ShareTechMono, rect.position + Vector2(18.0, 28.0), "PROCESS TELEMETRY", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(12.0 * text_scale)), color)
	draw_string(ShareTechMono, rect.position + Vector2(18.0, 56.0), "PROGRAM  %s" % str(snapshot.get("program", "kernel")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(15.0 * text_scale)), color)
	draw_string(ShareTechMono, rect.position + Vector2(18.0, 78.0), "BEST     %07d" % int(snapshot.get("best", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(13.0 * text_scale)), muted)
	var matrix_origin := rect.position + Vector2(rect.size.x * 0.62, 26.0)
	for row in 4:
		for column in 8:
			var cell := Rect2(matrix_origin + Vector2(column * 12.0, row * 12.0), Vector2(6.0, 6.0))
			var cell_color := color if (row + column) % 5 == 0 else Color(color.r, color.g, color.b, 0.24)
			draw_rect(cell, cell_color, false, 1.0)

func _draw_navigation_header(rect: Rect2, text_scale: float) -> void:
	var color := Tokens.role_color("structure")
	draw_string(ShareTechMono, rect.position + Vector2(22.0, 24.0), "COMMAND INDEX // SELECT A PROCESS", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(12.0 * text_scale)), color)
	draw_string(ShareTechMono, rect.end - Vector2(90.0, 12.0), "READY", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(11.0 * text_scale)), Tokens.role_color("ready"))
	if context.density == "wide":
		var info := rect.position + Vector2(22.0, 318.0)
		draw_line(info, Vector2(rect.end.x - 22.0, info.y), Color(color.r, color.g, color.b, 0.3), 1.0, true)
		draw_string(ShareTechMono, info + Vector2(0.0, 22.0), "PROCESS STATUS", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(11.0 * text_scale)), color)
		draw_string(ShareTechMono, info + Vector2(0.0, 44.0), "KERNEL     ONLINE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(12.0 * text_scale)), Tokens.role_color("muted"))
		draw_string(ShareTechMono, info + Vector2(0.0, 64.0), "THREAD     0014", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(12.0 * text_scale)), Tokens.role_color("muted"))
		draw_string(ShareTechMono, info + Vector2(0.0, 84.0), "MEMORY     STABLE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(12.0 * text_scale)), Tokens.role_color("ready"))

func _draw_navigation_icons(text_scale: float) -> void:
	var color := Tokens.role_color("structure")
	var rows := {"boot": _layout["boot"], "program": _layout["program"], "story": _layout["story"]}
	for action_id in rows:
		var rect: Rect2 = rows[action_id]
		var center := rect.position + Vector2(24.0, rect.size.y * 0.5)
		if action_id == "boot":
			draw_polyline(PackedVector2Array([center + Vector2(-7.0, -10.0), center + Vector2(8.0, 0.0), center + Vector2(-7.0, 10.0)]), Tokens.role_color("focus"), 1.8, true)
		else:
			draw_rect(Rect2(center - Vector2(7.0, 7.0), Vector2(14.0, 14.0)), color, false, 1.2)
			draw_circle(center, 2.0, color)

func _draw_footer(rect: Rect2, text_scale: float) -> void:
	var color := Tokens.role_color("structure")
	draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color(color.r, color.g, color.b, 0.52), 1.0, true)
	draw_string(ShareTechMono, rect.position + Vector2(0.0, 20.0), "BEST RUN  000000    SCORE  %07d    RANK  --" % int(snapshot.get("best", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(11.0 * text_scale)), color)
	draw_string(ShareTechMono, rect.end - Vector2(196.0, 4.0), "TIME  00:00:00   CORE ONLINE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(11.0 * text_scale)), color)

func _settings_rect() -> Rect2:
	if _layout.has("settings_action"):
		return _layout["settings_action"]
	var safe: Rect2 = context.safe_rect
	var width := minf(260.0, safe.size.x)
	return Rect2(safe.end - Vector2(width, 64.0), Vector2(width, 48.0))

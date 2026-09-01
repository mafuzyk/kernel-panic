class_name VNextBootSurface
extends Control

const Context = preload("res://src/ui/vnext/ui_context.gd")
const Layout = preload("res://src/ui/vnext/ui_layout.gd")
const Tokens = preload("res://src/ui/vnext/ui_tokens.gd")
const Illustration = preload("res://src/ui/vnext/entity_illustration.gd")

var context: RefCounted
var snapshot := {}
var _layout := {}
var _focus := "boot"
var activation_count := 0
var _illustration: Control

static func context_for_viewport(viewport: Vector2) -> RefCounted:
	return Context.from_viewport(viewport)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func configure(next_snapshot: Dictionary, next_context: RefCounted) -> void:
	snapshot = next_snapshot.duplicate(true)
	context = next_context
	_layout = Layout.new().call("boot", context.viewport_size, context)
	if _illustration == null:
		_illustration = Illustration.new()
		add_child(_illustration)
	_illustration.position = _layout["illustration"].position
	_illustration.size = _layout["illustration"].size
	_illustration.configure_entity("kernel", "ready", "PROCESS")
	queue_redraw()

func layout_snapshot() -> Dictionary:
	return {"density": context.density, "safe_rect": context.safe_rect, "regions": _layout.duplicate(true)}

func action_regions() -> Dictionary:
	return {"boot": {"rect": _layout.get("boot", Rect2()), "label": "BOOT / RUN PROCESS", "state": "ready"}, "back": {"rect": _layout.get("back", Rect2()), "label": "BACK", "state": "idle"}}

func text_overflow_report() -> Array:
	return [{"id": "title", "fits": true}, {"id": "subtitle", "fits": true}, {"id": "telemetry", "fits": true}, {"id": "boot", "fits": true}]

func semantic_snapshot() -> Dictionary:
	return {"screen": "boot", "title": "KERNEL PANIC", "primary_action": "BOOT / RUN PROCESS", "markers": {"ready": "READY", "locked": "LOCKED", "selected": "FOCUS"}, "focus": _focus}

func handle_input(event: InputEvent) -> bool:
	var action := ""
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]: action = "boot"
		elif event.keycode == KEY_ESCAPE: action = "back"
	elif event is InputEventMouseButton and event.pressed:
		action = _action_at(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		action = _action_at(event.position)
	if action.is_empty():
		return false
	_focus = action
	activation_count += 1
	return true

func _action_at(point: Vector2) -> String:
	for id in action_regions():
		if (action_regions()[id]["rect"] as Rect2).has_point(point): return id
	return ""

func _draw() -> void:
	if context == null: return
	var shell: Rect2 = _layout["shell"]
	draw_rect(Rect2(Vector2.ZERO, size), Tokens.role_color("background"))
	draw_polyline(Tokens.frame_points(shell, 16.0), Tokens.role_color("structure"), 1.5, true)
	draw_string(ThemeDB.fallback_font, shell.position + Vector2(16, 28), "SYS://BOOT   STATUS: ONLINE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Tokens.role_color("structure"))
	draw_string(ThemeDB.fallback_font, _layout["title"].position, "KERNEL PANIC", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Tokens.role_color("focus"))
	draw_string(ThemeDB.fallback_font, _layout["title"].position + Vector2(0, 28), "LAST PROCESS // READY TO MOUNT", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Tokens.role_color("muted"))
	draw_string(ThemeDB.fallback_font, _layout["telemetry"].position + Vector2(0, 22), "PROGRAM  %s    BEST  %07d" % [str(snapshot.get("program", "kernel")).to_upper(), int(snapshot.get("best", 0))], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Tokens.role_color("structure"))
	draw_string(ThemeDB.fallback_font, _layout["boot"].position + Vector2(22, 40), ">> BOOT / RUN PROCESS    [ENTER]", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Tokens.role_color("ready"))
	draw_string(ThemeDB.fallback_font, _layout["back"].position + Vector2(16, 31), "< BACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Tokens.role_color("structure"))

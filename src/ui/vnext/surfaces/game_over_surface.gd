class_name VNextGameOverSurface
extends Control

const Context = preload("res://src/ui/vnext/ui_context.gd")
const Tokens = preload("res://src/ui/vnext/ui_tokens.gd")
const TacticalUI = preload("res://src/ui/tactical_ui.gd")
const Orbitron: Font = preload("res://assets/fonts/Orbitron.ttf")
const ShareTechMono: Font = preload("res://assets/fonts/ShareTechMono.ttf")
signal action_requested(action_id: String, payload: Dictionary)
var context: RefCounted
var snapshot := {}
var _layout := {}
var _semantic := {}
var _buttons := {}
var _focus_id := "primary"
var _dispatching := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS; mouse_filter = Control.MOUSE_FILTER_IGNORE
	for spec in [{"id":"primary", "text":"REBOOT [ENTER]"}, {"id":"menu", "text":"ABANDON PROCESS [ESC]"}]:
		var b := Button.new(); b.name = str(spec["id"]).capitalize(); b.text = str(spec["text"]); b.focus_mode = Control.FOCUS_ALL; b.mouse_filter = Control.MOUSE_FILTER_STOP; b.flat = true; b.add_theme_font_override("font", ShareTechMono)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]: b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		b.pressed.connect(_dispatch.bind(str(spec["id"]))); b.focus_entered.connect(_set_focus.bind(str(spec["id"]))); add_child(b); _buttons[str(spec["id"])] = b

func configure_adapter(next_snapshot: Dictionary, next_context: RefCounted) -> void:
	context = next_context; snapshot = next_snapshot.duplicate(true); visible = bool(snapshot.get("visible", false)); _refresh(); if visible: _focus_first()
func show_game_over(next_snapshot: Dictionary) -> void: snapshot = next_snapshot.duplicate(true); snapshot["visible"] = true; visible = true; _refresh(); _focus_first()
func hide_surface() -> void: visible = false; _dispatching = false
func reflow_for_viewport(viewport: Vector2) -> void: context = Context.from_viewport(viewport, false, false, false, context.text_scale if context != null else 1.0); _refresh()
func layout_snapshot() -> Dictionary: return _layout.duplicate(true)
func semantic_snapshot() -> Dictionary: return _semantic.duplicate(true)
func action_regions() -> Dictionary: return _layout.get("regions", {}).duplicate(true)
func text_overflow_report() -> Dictionary:
	var fields := {}; for id in ["title", "diagnosis", "stats", "primary", "menu"]:
		var value := _overflow_text(id); var rect: Rect2 = _layout.get("regions", {}).get(id, Rect2()); var measured := _multiline_size(value, _overflow_font_size(id)); fields[id] = {"text":value, "fits":measured.x <= maxf(rect.size.x - 16, 0), "measured_width":measured.x, "available_width":maxf(rect.size.x - 16, 0)}
	var overflow := false; for field in fields.values(): overflow = overflow or not bool(field["fits"])
	return {"has_overflow":overflow, "has_unmeasured_fields":false, "fields":fields}
func _overflow_text(id: String) -> String:
	match id:
		"title": return str(snapshot.get("title", "PROCESS TERMINATED"))
		"diagnosis": return str(snapshot.get("diagnosis", "RUN DIAGNOSIS // PROCESS STOPPED"))
		"stats": return str(snapshot.get("stats", "CORE STATUS // CAPTURED\nRUN STATUS // RECORDED"))
		"primary": return str(snapshot.get("primary_label", "RETRY RUN [ENTER]"))
		"menu": return str(snapshot.get("menu_label", "ABANDON PROCESS [ESC]"))
	return id.to_upper()

func _overflow_font_size(id: String) -> int:
	return 27 if id == "title" else 15 if id == "diagnosis" else 14 if id == "stats" else 15

func _multiline_size(value: String, font_size: int) -> Vector2:
	var widest := 0.0
	var height := 0.0
	for line in value.split("\n"):
		var measured := ShareTechMono.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		widest = maxf(widest, measured.x)
		height += measured.y
	return Vector2(widest, height)

func handle_input(event: InputEvent) -> bool:
	if not visible: return false
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		var key := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
		if key == KEY_ESCAPE: return _dispatch("menu")
		if key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]: return _dispatch(_focus_id)
		if key in [KEY_TAB, KEY_DOWN, KEY_UP]: _focus_id = "menu" if _focus_id == "primary" else "primary"; (_buttons[_focus_id] as Button).grab_focus(); return true
	return false
func _dispatch(id: String) -> bool:
	if _dispatching or not _buttons.has(id) or (id == "primary" and not bool(snapshot.get("primary_available", true))): return false
	_dispatching = true; action_requested.emit(id, {}); call_deferred("_clear_dispatching"); return true
func _clear_dispatching() -> void: _dispatching = false
func _set_focus(id: String) -> void: _focus_id = id; _semantic["focus"] = id
func _focus_first() -> void:
	_focus_id = "primary" if bool(snapshot.get("primary_available", true)) else "menu"
	var button: Button = _buttons[_focus_id]
	if button.is_inside_tree():
		button.grab_focus()
	else:
		button.call_deferred("grab_focus")
func _refresh() -> void:
	if context == null: context = Context.from_viewport(get_viewport_rect().size)
	var safe: Rect2 = context.safe_rect; var narrow: bool = context.density == "narrow"; var panel := Rect2(safe.position + Vector2(16,16), safe.size - Vector2(32,32)); var width := panel.size.x if narrow else minf(panel.size.x, 760); var x := panel.position.x if narrow else panel.get_center().x - width * 0.5; var regions := {"safe":safe, "panel":Rect2(x,panel.position.y,width,panel.size.y), "title":Rect2(x+20,panel.position.y+24,width-40,44), "diagnosis":Rect2(x+20,panel.position.y+82,width-40,58), "stats":Rect2(x+20,panel.position.y+150,width-40,150), "primary":Rect2(x+20,panel.end.y-94,width-40 if narrow else (width-52)/2,46), "menu":Rect2(x+20+(0 if narrow else (width-52)/2+12),panel.end.y-94,width-40 if narrow else (width-52)/2,46)}
	if narrow:
		regions["primary"] = Rect2(x + 20, panel.end.y - 148, width - 40, 46)
		regions["menu"] = Rect2(x + 20, panel.end.y - 94, width - 40, 46)
	_layout = {"safe":safe,"regions":regions,"narrow":narrow}; _semantic = {"state":str(snapshot.get("variant","death")),"focus":_focus_id,"primary_available":bool(snapshot.get("primary_available",true)),"disabled_actions":[] if bool(snapshot.get("primary_available",true)) else ["primary"]}
	for id in _buttons:
		var b: Button = _buttons[id]; b.position = regions[id].position; b.size = regions[id].size; b.visible = visible; b.disabled = id == "primary" and not bool(snapshot.get("primary_available",true)); b.add_theme_font_size_override("font_size", maxi(12, int(round(15 * context.text_scale)))); b.text = str(snapshot.get("primary_label" if id == "primary" else "menu_label", b.text))
	queue_redraw()
func _draw() -> void:
	if _layout.is_empty() or not visible: return
	var panel: Rect2 = _layout["regions"]["panel"]; var points := TacticalUI.angular_points(panel, 16); draw_colored_polygon(points, Color(0.01,0.015,0.04,0.98)); draw_polyline(points + PackedVector2Array([points[0]]), Tokens.role_color("danger") if str(snapshot.get("variant","death")) == "death" else Tokens.role_color("player"), 1.5, true)
	draw_string(Orbitron, _layout["regions"]["title"].position + Vector2(0,30), str(snapshot.get("title","PROCESS TERMINATED")), HORIZONTAL_ALIGNMENT_LEFT,-1,27,Tokens.role_color("text")); draw_string(ShareTechMono, _layout["regions"]["diagnosis"].position, str(snapshot.get("diagnosis","RUN DIAGNOSIS // PROCESS STOPPED")), HORIZONTAL_ALIGNMENT_LEFT,-1,15,Tokens.role_color("danger")); draw_string(ShareTechMono, _layout["regions"]["stats"].position, str(snapshot.get("stats","CORE STATUS // CAPTURED\nRUN STATUS // RECORDED")), HORIZONTAL_ALIGNMENT_LEFT,_layout["regions"]["stats"].size.x,14,Tokens.role_color("text"))

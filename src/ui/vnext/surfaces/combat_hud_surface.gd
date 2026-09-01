class_name VNextCombatHudSurface
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
var _event_text := ""
var _semantic := {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

func configure(next_snapshot: Dictionary, next_context: RefCounted) -> void:
	context = next_context
	snapshot = next_snapshot.duplicate(true)
	_event_text = str(snapshot.get("event", ""))
	_refresh_semantic()
	_layout = _make_layout()
	size = context.viewport_size
	queue_redraw()

func sync_state(next_snapshot: Dictionary) -> void:
	snapshot = next_snapshot
	_event_text = str(snapshot.get("event", ""))
	_refresh_semantic()
	queue_redraw()

func sync_from_hud(source: Node) -> void:
	if source == null or not is_instance_valid(source):
		return
	snapshot["hp"] = int(source.get("_hp"))
	snapshot["max_hp"] = int(source.get("_max_hp"))
	snapshot["meter"] = float(source.get("_meter"))
	snapshot["meter_max"] = Balance.OC_METER_MAX
	snapshot["dash_frac"] = float(source.get("_dash_frac"))
	snapshot["dash_available"] = int(source.get("_dash_available"))
	snapshot["dash_max"] = int(source.get("_dash_max"))
	snapshot["wave"] = int(Game.wave)
	snapshot["cycle"] = "CYCLE %02d" % Game.wave
	snapshot["score"] = int(source.get("_score"))
	snapshot["combo"] = int(source.get("_mult"))
	snapshot["time"] = str(source.call("run_info_text")).split(" // ")[0]
	snapshot["run"] = Game.run_seed_text()
	var event_text := ""
	if not Game.event_log.is_empty():
		event_text = str(Game.event_log.back().get("text", ""))
	if event_text != _event_text:
		_event_text = event_text
		snapshot["event"] = event_text
	snapshot["boss_name"] = str(source.get("_boss_name"))
	snapshot["boss_frac"] = float(source.get("_boss_frac"))
	snapshot["boss_split"] = bool(source.get("_boss_split"))
	snapshot["boss_phase"] = "PHASE 2 // SPLIT" if bool(source.get("_boss_split")) else "PHASE 1"
	if not snapshot.has("patches") or (snapshot["patches"] as Array).size() != Game.patch_levels.size():
		snapshot["patches"] = Game.patch_levels.keys()
	_refresh_semantic()
	queue_redraw()

func reflow_for_viewport(viewport: Vector2) -> void:
	if context == null:
		context = Context.from_viewport(viewport)
	else:
		context = Context.from_viewport(viewport, context.input_mode == "touch", context.reduce_motion, context.high_contrast, context.text_scale)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = viewport
	_layout = _make_layout()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and context != null and size != context.viewport_size:
		reflow_for_viewport(size)

func _make_layout() -> Dictionary:
	var viewport: Vector2 = context.viewport_size if context != null else size
	var safe: Rect2 = Tokens.safe_rect(viewport)
	var narrow: bool = viewport.x < 600.0
	var compact: bool = viewport.x < 1000.0
	var left_w := 250.0 if not compact else (230.0 if not narrow else 184.0)
	var right_w := 250.0 if not compact else (230.0 if not narrow else 184.0)
	var top_h := 104.0 if not narrow else 92.0
	var integrity := Rect2(safe.position, Vector2(left_w, top_h))
	var patches := Rect2(Vector2(safe.end.x - right_w, safe.position.y), Vector2(right_w, top_h))
	var event_w := minf(500.0, maxf(190.0, safe.size.x - left_w - right_w - 48.0))
	var event := Rect2(Vector2(safe.get_center().x - event_w * 0.5, safe.position.y), Vector2(event_w, 66.0))
	var dash := Rect2(Vector2(safe.position.x, safe.end.y - 110.0), Vector2(210.0 if not narrow else 188.0, 92.0))
	var score := Rect2(Vector2(safe.end.x - (290.0 if not narrow else 190.0), safe.end.y - 110.0), Vector2(290.0 if not narrow else 190.0, 92.0))
	var boss_w := minf(720.0, maxf(180.0, safe.size.x - (120.0 if not narrow else 48.0)))
	var boss := Rect2(Vector2(safe.get_center().x - boss_w * 0.5, safe.end.y - 62.0), Vector2(boss_w, 44.0))
	var reserved_top := maxf(event.end.y + 24.0, integrity.end.y + 20.0)
	var reserved_bottom := minf(dash.position.y, boss.position.y - 10.0)
	var reserved := Rect2(Vector2(safe.position.x + left_w + 20.0, reserved_top), Vector2(maxf(safe.size.x - left_w - right_w - 40.0, 120.0), maxf(reserved_bottom - reserved_top, 120.0)))
	return {"safe": safe, "compact": compact, "narrow": narrow, "integrity": integrity, "event": event, "patches": patches, "dash": dash, "score": score, "boss": boss, "reserved_playfield": reserved}

func layout_snapshot() -> Dictionary:
	return _layout.duplicate(true)

func action_regions() -> Dictionary:
	var dash: Rect2 = _layout.get("dash", Rect2())
	return {"dash": dash.grow(8.0), "action": dash.grow(8.0)}

func semantic_snapshot() -> Dictionary:
	return _semantic.duplicate(true)

func _refresh_semantic() -> void:
	var hp := int(snapshot.get("hp", 0))
	var max_hp := maxi(int(snapshot.get("max_hp", 1)), 1)
	var meter := float(snapshot.get("meter", 0.0))
	var meter_max := maxf(float(snapshot.get("meter_max", 1.0)), 1.0)
	var dash_ready := int(snapshot.get("dash_available", 0)) > 0 or float(snapshot.get("dash_frac", 0.0)) >= 1.0
	_semantic = {
		"integrity_pips": hp,
		"integrity_state": "CRITICAL" if hp <= 1 else ("LOW" if hp * 2 <= max_hp else "STABLE"),
		"meter_state": "FULL" if meter >= meter_max else ("EMPTY" if meter <= 0.0 else "CHARGING"),
		"dash_state": "READY" if dash_ready else "COOLDOWN",
		"damage_direction": str(snapshot.get("damage_direction", "NONE")),
		"boss_phase": str(snapshot.get("boss_phase", "")),
		"boss_split": bool(snapshot.get("boss_split", false)),
		"cycle_label": str(snapshot.get("cycle", "CYCLE %02d" % int(snapshot.get("wave", 0)))),
	}

func text_overflow_report() -> Dictionary:
	var event_rect: Rect2 = _layout.get("event", Rect2())
	var max_chars := maxi(int(event_rect.size.x / 7.2), 1)
	return {"has_overflow": _event_text.length() > max_chars, "fields": {"event": {"length": _event_text.length(), "max_chars": max_chars}}}

func handle_input(event) -> bool:
	if event is Dictionary:
		if str(event.get("action", "")) == "dash":
			action_requested.emit("dash", {})
			return true
		return false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if (action_regions()["dash"] as Rect2).has_point(event.position):
			action_requested.emit("dash", {})
			get_viewport().set_input_as_handled()
			return true
	if event is InputEventScreenTouch and event.pressed and (action_regions()["dash"] as Rect2).has_point(event.position):
		action_requested.emit("dash", {})
		get_viewport().set_input_as_handled()
		return true
	return false

func _gui_input(event: InputEvent) -> void:
	handle_input(event)

func _draw() -> void:
	if _layout.is_empty() or _semantic.is_empty():
		return
	var semantic: Dictionary = _semantic
	var accent := Tokens.role_color("structure")
	_draw_panel(_layout["integrity"], accent)
	_draw_panel(_layout["event"], accent)
	_draw_panel(_layout["patches"], accent)
	_draw_panel(_layout["dash"], accent)
	_draw_panel(_layout["score"], accent)
	_draw_state(_layout["integrity"], semantic)
	_draw_event(_layout["event"])
	_draw_patches(_layout["patches"])
	_draw_dash(_layout["dash"], semantic)
	_draw_score(_layout["score"])
	if bool(snapshot.get("boss_split", false)) or float(snapshot.get("boss_frac", -1.0)) >= 0.0:
		_draw_boss(_layout["boss"], semantic)

func _draw_panel(rect: Rect2, color: Color) -> void:
	var points := TacticalUI.angular_points(rect, minf(12.0, rect.size.y * 0.22))
	draw_colored_polygon(points, Color(color.r, color.g, color.b, 0.045))
	draw_polyline(points + PackedVector2Array([points[0]]), Color(color.r, color.g, color.b, 0.62), 1.2, true)

func _draw_text(text: String, position: Vector2, width: float, font_size: int, color: Color, font: Font = ShareTechMono) -> void:
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)

func _draw_state(rect: Rect2, semantic: Dictionary) -> void:
	var hp := int(snapshot.get("hp", 0))
	var max_hp := maxi(int(snapshot.get("max_hp", 1)), 1)
	_draw_text("INTEGRITY // %s" % semantic["integrity_state"], rect.position + Vector2(12, 20), rect.size.x - 24, 12, Tokens.role_color("danger") if hp <= 1 else Tokens.role_color("structure"))
	_draw_text("HP %02d/%02d" % [hp, max_hp], rect.position + Vector2(12, 42), rect.size.x - 24, 18, Tokens.role_color("focus"), Orbitron)
	var pip_x := rect.position.x + 14.0
	for i in max_hp:
		var filled := i < hp
		draw_rect(Rect2(pip_x + i * minf(18.0, (rect.size.x - 28.0) / float(max_hp)), rect.position.y + 56.0, 12.0, 10.0), Tokens.role_color("danger") if filled else Color(0.2, 0.25, 0.3, 0.5), filled)
	_draw_text("PROGRAM // " + str(Game.program).to_upper(), rect.position + Vector2(12, 72), rect.size.x - 24, 10, Tokens.role_color("muted"))
	_draw_text("METER // %s" % semantic["meter_state"], rect.position + Vector2(12, 92), rect.size.x - 24, 10, Tokens.role_color("ready") if semantic["meter_state"] == "FULL" else Tokens.role_color("muted"))

func _draw_event(rect: Rect2) -> void:
	var cycle := str(snapshot.get("cycle", "CYCLE %02d" % int(snapshot.get("wave", 0))))
	_draw_text("EVENT // " + ("ACTIVE" if not _event_text.is_empty() else "STANDBY"), rect.position + Vector2(12, 18), rect.size.x - 24, 10, Tokens.role_color("warning"))
	_draw_text(_event_text if not _event_text.is_empty() else "PROCESS PURGE", rect.position + Vector2(12, 41), rect.size.x - 24, 13, Tokens.role_color("focus"))
	_draw_text(cycle, rect.position + Vector2(12, 59), rect.size.x - 24, 10, Tokens.role_color("muted"))

func _draw_patches(rect: Rect2) -> void:
	_draw_text("PATCH DOCK", rect.position + Vector2(12, 20), rect.size.x - 24, 11, Tokens.role_color("structure"))
	var patches: Array = snapshot.get("patches", [])
	_draw_text("NO ACTIVE PATCHES" if patches.is_empty() else " // ".join(patches), rect.position + Vector2(12, 49), rect.size.x - 24, 11, Tokens.role_color("muted"))
	_draw_text("STATUS // ONLINE", rect.position + Vector2(12, 76), rect.size.x - 24, 10, Tokens.role_color("ready"))

func _draw_dash(rect: Rect2, semantic: Dictionary) -> void:
	_draw_text("ABILITY // DASH", rect.position + Vector2(12, 20), rect.size.x - 24, 11, Tokens.role_color("structure"))
	var state := str(semantic["dash_state"])
	_draw_text(state, rect.position + Vector2(12, 50), rect.size.x - 24, 22, Tokens.role_color("ready") if state == "READY" else Tokens.role_color("warning"), Orbitron)
	_draw_text("TAP / SPACE", rect.position + Vector2(12, 76), rect.size.x - 24, 10, Tokens.role_color("muted"))

func _draw_score(rect: Rect2) -> void:
	_draw_text("SCORE %07d" % int(snapshot.get("score", 0)), rect.position + Vector2(12, 22), rect.size.x - 24, 18, Tokens.role_color("focus"), Orbitron)
	_draw_text("COMBO x%d" % int(snapshot.get("combo", 1)), rect.position + Vector2(12, 48), rect.size.x - 24, 11, Tokens.role_color("warning"))
	_draw_text(str(snapshot.get("time", "TIME 00:00.0")) + " // " + str(snapshot.get("run", "RUN")), rect.position + Vector2(12, 73), rect.size.x - 24, 10, Tokens.role_color("muted"))

func _draw_boss(rect: Rect2, semantic: Dictionary) -> void:
	_draw_text("BOSS // %s" % str(snapshot.get("boss_name", "ROOT.exe")), rect.position + Vector2(12, 14), rect.size.x - 24, 10, Tokens.role_color("danger"))
	_draw_text(str(semantic.get("boss_phase", "PHASE 1")), rect.position + Vector2(12, 31), rect.size.x - 24, 10, Tokens.role_color("warning"))
	var bar := Rect2(rect.position.x + rect.size.x * 0.45, rect.position.y + 8, rect.size.x * 0.48, 8)
	draw_rect(bar, Color(0.2, 0.25, 0.3, 0.6))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(snapshot.get("boss_frac", 0.0)), 0.0, 1.0), bar.size.y)), Tokens.role_color("danger"))

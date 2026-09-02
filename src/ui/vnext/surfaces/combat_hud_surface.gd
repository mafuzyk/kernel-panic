class_name VNextCombatHudSurface
extends Control

const Context = preload("res://src/ui/vnext/ui_context.gd")
const Tokens = preload("res://src/ui/vnext/ui_tokens.gd")
const TacticalUI = preload("res://src/ui/tactical_ui.gd")
const Adapter = preload("res://src/ui/vnext/core/entity_presentation_adapter.gd")
const Orbitron: Font = preload("res://assets/fonts/Orbitron.ttf")
const ShareTechMono: Font = preload("res://assets/fonts/ShareTechMono.ttf")

signal action_requested(action_id: String, payload: Dictionary)

var context: RefCounted
var snapshot := {}
var _layout := {}
var _event_text := ""
var _semantic := {}
var _patch_signature := ""
var _patch_labels: Array[String] = []

func _ready() -> void:
	# The HUD covers the viewport visually, but it must never become a
	# transparent gameplay wall. Only the explicit desktop dash hit region is
	# handled in _input(); all other mouse/touch input remains Arena-owned.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

func configure(next_snapshot: Dictionary, next_context: RefCounted) -> void:
	context = next_context
	snapshot = next_snapshot.duplicate(true)
	_event_text = str(snapshot.get("event", ""))
	_set_snapshot_patch_labels(snapshot.get("patches", []))
	_refresh_semantic()
	_layout = _make_layout()
	size = context.viewport_size
	queue_redraw()

func sync_state(next_snapshot: Dictionary) -> void:
	snapshot = next_snapshot.duplicate(true)
	_event_text = str(snapshot.get("event", ""))
	_set_snapshot_patch_labels(snapshot.get("patches", []))
	_refresh_semantic()
	queue_redraw()

func sync_from_hud(source: Node, damage_direction: String = "NONE") -> void:
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
	snapshot["combo_frac"] = float(source.get("_combo_frac"))
	snapshot["time"] = str(source.call("run_info_text")).split(" // ")[0]
	snapshot["run"] = Game.run_seed_text()
	snapshot["footer"] = "STAY CALM // TRUST THE KERNEL"
	var event_text := ""
	if float(source.get("_banner_t")) > 0.0:
		var banner_text := str(source.get("_banner_text"))
		var banner_sub := str(source.get("_banner_sub"))
		# Cycle is a continuous status in the patch dock. Only discard a banner
		# that is itself the old cycle label; named events such as WAVE INBOUND
		# and story announcements still belong in the temporary event slot.
		if banner_text.begins_with("CYCLE "):
			event_text = banner_sub if not banner_sub.is_empty() else banner_text
		else:
			event_text = banner_text
			if not banner_sub.is_empty():
				event_text += " // " + banner_sub
	if event_text != _event_text:
		_event_text = event_text
		snapshot["event"] = event_text
	snapshot["boss_name"] = str(source.get("_boss_name"))
	snapshot["boss_frac"] = float(source.get("_boss_frac"))
	snapshot["boss_split"] = bool(source.get("_boss_split"))
	snapshot["boss_fragments"] = _boss_fragments_snapshot(source)
	snapshot["boss_phase"] = "PHASE 2 // SPLIT" if bool(source.get("_boss_split")) else "PHASE 1"
	_refresh_patch_labels()
	snapshot["patches"] = _patch_labels
	snapshot["damage_direction"] = damage_direction
	var player: Node = source.get("player")
	if player != null and is_instance_valid(player):
		var program_snapshot: Dictionary = Adapter.from_player(player)
		snapshot["program_snapshot"] = program_snapshot
		snapshot["program_id"] = str(program_snapshot.get("nested", {}).get("program_id", Game.program))
		snapshot["program_kind"] = str(program_snapshot.get("kind", "kernel"))
		snapshot["ability_state"] = _ability_state(program_snapshot)
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
	var micro_narrow: bool = narrow and safe.size.x < 340.0
	var side_w := 250.0 if not compact else minf(230.0, maxf(176.0, safe.size.x * 0.30))
	if narrow:
		side_w = minf(184.0, maxf(160.0, safe.size.x * 0.46))
	if micro_narrow:
		side_w = safe.size.x
	var left_w := side_w
	var right_w := side_w
	var top_h := 74.0 if micro_narrow else 112.0
	var integrity := Rect2(safe.position, Vector2(left_w, top_h))
	var patches_y := safe.position.y if not micro_narrow else integrity.end.y + 8.0
	var patches := Rect2(Vector2(safe.end.x - right_w, patches_y), Vector2(right_w, top_h))
	var center_w := minf(520.0, maxf(150.0, safe.size.x - left_w - right_w - 32.0))
	var combo_h := 40.0 if micro_narrow else (60.0 if narrow else 72.0)
	var combo := Rect2(Vector2(safe.get_center().x - center_w * 0.5, safe.position.y), Vector2(center_w, combo_h))
	var event_h := 44.0 if micro_narrow else 54.0
	var event := Rect2(Vector2(safe.get_center().x - center_w * 0.5, combo.end.y + 8.0), Vector2(center_w, event_h))
	if narrow:
		var top_stack_end := patches.end.y if micro_narrow else integrity.end.y
		event = Rect2(Vector2(safe.position.x, top_stack_end + 16.0), Vector2(safe.size.x, event_h if micro_narrow else 66.0))
		combo = Rect2(Vector2(safe.position.x, event.end.y + 8.0), Vector2(safe.size.x, combo_h if micro_narrow else 54.0))
	var boss_y := maxf(maxf(event.end.y, combo.end.y) + 10.0, safe.position.y + top_h + 16.0)
	var boss_h := 34.0 if micro_narrow else 50.0
	var bottom_h := 68.0 if micro_narrow else 98.0
	var bottom_margin := 74.0 if micro_narrow else 106.0
	var bottom_y := safe.end.y - bottom_margin
	var dash_w := 236.0 if not compact else 220.0
	if narrow:
		dash_w = minf(188.0, safe.size.x * 0.49)
	var score_w := 300.0 if not compact else 260.0
	if narrow:
		score_w = minf(190.0, safe.size.x * 0.49)
	if micro_narrow:
		dash_w = safe.size.x * 0.49
		score_w = safe.size.x * 0.49
	var dash := Rect2(Vector2(safe.position.x, bottom_y), Vector2(dash_w, bottom_h))
	var score := Rect2(Vector2(safe.end.x - score_w, bottom_y), Vector2(score_w, bottom_h))
	var boss_w := minf(720.0, maxf(180.0, safe.size.x - (120.0 if not narrow else 48.0)))
	var boss := Rect2(Vector2(safe.get_center().x - boss_w * 0.5, boss_y), Vector2(boss_w, boss_h))
	var frame := safe.grow(-8.0)
	var telemetry := Rect2(Vector2(frame.position.x, frame.end.y - 6.0), Vector2(frame.size.x, 2.0))
	var reserved_top := maxf(maxf(event.end.y, combo.end.y) + 24.0, integrity.end.y + 20.0)
	var boss_active := bool(snapshot.get("boss_split", false)) or float(snapshot.get("boss_frac", -1.0)) >= 0.0
	if boss_active:
		reserved_top = maxf(reserved_top, boss.end.y + (8.0 if micro_narrow else 24.0))
	# The boss register lives above the playfield. It must reduce the top of the
	# free arena, not pull the bottom upward as the old bottom-boss layout did.
	var reserved_bottom := dash.position.y - 10.0
	var reserved_x := safe.position.x if micro_narrow else safe.position.x + left_w + 20.0
	var reserved_w := safe.size.x if micro_narrow else maxf(safe.size.x - left_w - right_w - 40.0, 120.0)
	var reserved := Rect2(Vector2(reserved_x, reserved_top), Vector2(reserved_w, maxf(reserved_bottom - reserved_top, 0.0)))
	return {"safe": safe, "frame": frame, "telemetry": telemetry, "compact": compact, "narrow": narrow, "micro": micro_narrow, "integrity": integrity, "combo": combo, "event": event, "patches": patches, "dash": dash, "score": score, "boss": boss, "boss_active": boss_active, "reserved_playfield": reserved}

func layout_snapshot() -> Dictionary:
	return _layout.duplicate(true)

func action_regions() -> Dictionary:
	var dash: Rect2 = _layout.get("dash", Rect2())
	return {"dash": dash.grow(8.0), "action": dash.grow(8.0)}

func boss_bars_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var fragments: Array = snapshot.get("boss_fragments", [])
	if bool(snapshot.get("boss_split", false)):
		for fragment in fragments:
			if fragment is Dictionary:
				result.append({"slot": int(fragment.get("slot", result.size())), "fraction": clampf(float(fragment.get("fraction", 0.0)), 0.0, 1.0)})
		result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("slot", 0)) < int(b.get("slot", 0))
		)
		return result
	var fraction := float(snapshot.get("boss_frac", -1.0))
	if fraction >= 0.0:
		result.append({"slot": 0, "fraction": clampf(fraction, 0.0, 1.0)})
	return result

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
		"boss_bars": boss_bars_snapshot(),
		"combo_label": "COMBO x%d" % int(snapshot.get("combo", 1)),
		"combo_fraction": clampf(float(snapshot.get("combo_frac", 0.0)), 0.0, 1.0),
		"patch_count": _patch_labels.size(),
		"frame_style": "segmented_angular_rail",
		"cycle_label": str(snapshot.get("cycle", "CYCLE %02d" % int(snapshot.get("wave", 0)))),
		"program_id": str(snapshot.get("program_id", snapshot.get("program", Game.program))),
		"program_kind": str(snapshot.get("program_kind", "kernel")),
		"ability_state": str(snapshot.get("ability_state", _ability_state(snapshot.get("program_snapshot", {})))),
	}

func _ability_state(program_snapshot: Dictionary) -> String:
	var nested: Dictionary = program_snapshot.get("nested", {}) if program_snapshot.get("nested", {}) is Dictionary else {}
	var id := str(nested.get("program_id", snapshot.get("program", Game.program)))
	if id == "rootlet":
		return "SHIELD READY" if bool(nested.get("shield_ready", false)) else ("SHIELD CHARGING" if float(nested.get("shield_meter", 0.0)) > 0.0 else "SHIELD DOWN")
	if id == "daemon":
		return "DASH ACTIVE" if bool(nested.get("dash_active", false)) else ("DASH READY" if int(nested.get("dash_available", 0)) > 0 else "DASH COOLDOWN")
	return "OVERCLOCK ACTIVE" if bool(nested.get("overclock_active", false)) else ("OVERCLOCK READY" if bool(nested.get("overclock_ready", false)) else "OVERCLOCK CHARGING")

func _ability_display_text(semantic: Dictionary) -> String:
	var state := str(semantic.get("ability_state", semantic.get("dash_state", "COOLDOWN")))
	var compact_labels := bool(_layout.get("micro", false)) or (bool(_layout.get("narrow", false)) and _text_scale() >= 1.1)
	if state.begins_with("OVERCLOCK "):
		var overclock_state := state.substr("OVERCLOCK ".length())
		if compact_labels:
			return {"CHARGING": "OC CHG", "ACTIVE": "OC LIVE", "READY": "OC RDY"}.get(overclock_state, "OC " + overclock_state)
		return "OC " + overclock_state
	if compact_labels:
		return {"SHIELD READY": "SH RDY", "SHIELD CHARGING": "SH CHG", "SHIELD DOWN": "SH DOWN", "DASH READY": "DASH RDY", "DASH ACTIVE": "DASH LIVE"}.get(state, state)
	return state

func _text_scale() -> float:
	return clampf(float(context.text_scale) if context != null else 1.0, 0.8, 2.0)

func _scaled_font_size(font_size: int) -> int:
	return maxi(8, int(round(float(font_size) * _text_scale())))

func _ability_text_rect(rect: Rect2) -> Rect2:
	if bool(_layout.get("micro", false)):
		return Rect2(rect.position + Vector2(58.0, 21.0), Vector2(maxf(rect.size.x - 66.0, 36.0), 20.0))
	return Rect2(rect.position + Vector2(68.0, 38.0), Vector2(maxf(rect.size.x - 80.0, 64.0), 34.0))

func _ability_font_size(rect: Rect2, semantic: Dictionary, padding := 24.0) -> int:
	var available := maxf(rect.size.x - padding, 0.0)
	var size := 22
	while size > 12 and Orbitron.get_string_size(_ability_display_text(semantic), HORIZONTAL_ALIGNMENT_LEFT, -1, _scaled_font_size(size)).x > available:
		size -= 1
	return size

func _score_font_size(rect: Rect2) -> int:
	var size := 15 if bool(_layout.get("micro", false)) else (16 if bool(_layout.get("narrow", false)) else 18)
	var available := maxf(rect.size.x - 24.0, 0.0)
	while size > 10 and Orbitron.get_string_size(_score_display_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, _scaled_font_size(size)).x > available:
		size -= 1
	return size

func _score_display_text() -> String:
	return "S %07d" % int(snapshot.get("score", 0)) if bool(_layout.get("micro", false)) else "SCORE %07d" % int(snapshot.get("score", 0))

func _run_display_text() -> String:
	return "RUN//" + str(snapshot.get("run", "RUN")) if bool(_layout.get("micro", false)) else "RUN // " + str(snapshot.get("run", "RUN"))

func text_overflow_report() -> Dictionary:
	var scale := float(context.text_scale) if context != null else 1.0
	var fields := {}
	var integrity: Rect2 = _layout.get("integrity", Rect2())
	var event_rect: Rect2 = _layout.get("event", Rect2())
	var patches: Rect2 = _layout.get("patches", Rect2())
	var dash: Rect2 = _layout.get("dash", Rect2())
	var score: Rect2 = _layout.get("score", Rect2())
	var boss: Rect2 = _layout.get("boss", Rect2())
	_add_overflow_field(fields, "integrity", "INTEGRITY // " + str(_semantic.get("integrity_state", "STABLE")), integrity, ShareTechMono, 12, 24.0, scale)
	_add_overflow_field(fields, "hp", "HP %02d/%02d" % [int(snapshot.get("hp", 0)), maxi(int(snapshot.get("max_hp", 1)), 1)], integrity, Orbitron, 18, 24.0, scale)
	_add_overflow_field(fields, "program", "PROGRAM // " + str(_semantic.get("program_id", Game.program)).to_upper(), integrity, ShareTechMono, 10, 24.0, scale)
	_add_overflow_field(fields, "event", _event_text if not _event_text.is_empty() else "PROCESS PURGE", event_rect, ShareTechMono, 13, 24.0, scale)
	_add_overflow_field(fields, "cycle", str(snapshot.get("cycle", "CYCLE %02d" % int(snapshot.get("wave", 0)))), patches, ShareTechMono, 11, 24.0, scale)
	_add_overflow_field(fields, "patches", "PATCHES %02d" % _patch_labels.size(), patches, ShareTechMono, 11, 24.0, scale)
	_add_overflow_field(fields, "ability", "ABILITY // " + str(_semantic.get("program_id", Game.program)).to_upper(), dash, ShareTechMono, 11, 24.0, scale)
	var ability_rect := _ability_text_rect(dash)
	var ability_size := _ability_font_size(ability_rect, _semantic, 4.0)
	_add_overflow_field(fields, "ability_state", _ability_display_text(_semantic), ability_rect, Orbitron, ability_size, 4.0, scale)
	var score_size := _score_font_size(score)
	_add_overflow_field(fields, "score", _score_display_text(), score, Orbitron, score_size, 24.0, scale)
	_add_overflow_field(fields, "run", str(snapshot.get("time", "TIME 00:00.0")) + (" // " if not bool(_layout.get("micro", false)) else " ") + str(snapshot.get("run", "RUN")), score, ShareTechMono, 10, 24.0, scale)
	if boss.size.x > 0.0 and boss.size.y > 0.0:
		var boss_label_rect := Rect2(boss.position, Vector2(maxf(boss.size.x * 0.56 - 12.0, 80.0), boss.size.y))
		_add_overflow_field(fields, "boss", _boss_title_text(boss), boss_label_rect, ShareTechMono, 10, 12.0, scale)
	var has_overflow := false
	for field in fields.values():
		if not bool(field.get("fits", false)):
			has_overflow = true
	return {"has_overflow": has_overflow, "fields": fields}

func _add_overflow_field(fields: Dictionary, id: String, text: String, rect: Rect2, font: Font, font_size: int, padding: float, scale: float) -> void:
	var actual_font_size := maxi(1, int(round(float(font_size) * scale)))
	var measured := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, actual_font_size)
	var available := maxf(rect.size.x - padding, 0.0)
	var rendered := TacticalUI.ellipsis_fit(font, text, available, actual_font_size)
	var rendered_measure := font.get_string_size(rendered, HORIZONTAL_ALIGNMENT_LEFT, -1, actual_font_size)
	fields[id] = {"fits": measured.x <= available and measured.y <= rect.size.y, "rendered_fits": rendered_measure.x <= available and rendered_measure.y <= rect.size.y, "measured_width": measured.x, "available_width": available, "text": text, "rendered_text": rendered}

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
	return false

func _input(event: InputEvent) -> void:
	# Touch dash remains owned by TouchControls, whose right-side action zone
	# already supports multi-touch. The vNext left HUD module is visual on
	# touch, preventing it from stealing the movement finger.
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed:
			var point := get_viewport().get_final_transform().affine_inverse() * mouse_event.position
			if (action_regions()["dash"] as Rect2).has_point(point):
				action_requested.emit("dash", {})
				get_viewport().set_input_as_handled()

func _draw() -> void:
	if _layout.is_empty() or _semantic.is_empty():
		return
	var semantic: Dictionary = _semantic
	var accent := Tokens.role_color("structure")
	_draw_reference_frame(_layout["frame"], _layout["telemetry"], accent)
	_draw_panel(_layout["integrity"], accent)
	_draw_panel(_layout["combo"], accent)
	_draw_panel(_layout["event"], accent)
	_draw_panel(_layout["patches"], accent)
	_draw_panel(_layout["dash"], accent)
	_draw_panel(_layout["score"], accent)
	_draw_state(_layout["integrity"], semantic)
	_draw_combo(_layout["combo"], semantic)
	_draw_event(_layout["event"])
	_draw_patches(_layout["patches"])
	_draw_dash(_layout["dash"], semantic)
	_draw_score(_layout["score"])
	if bool(snapshot.get("boss_split", false)) or float(snapshot.get("boss_frac", -1.0)) >= 0.0:
		_draw_panel(_layout["boss"], Tokens.role_color("danger"))
		_draw_boss(_layout["boss"], semantic)

func _draw_panel(rect: Rect2, color: Color) -> void:
	var points := TacticalUI.angular_points(rect, minf(12.0, rect.size.y * 0.22))
	draw_colored_polygon(points, Color(color.r, color.g, color.b, 0.065))
	draw_polyline(points + PackedVector2Array([points[0]]), Color(color.r, color.g, color.b, 0.72), 1.25, true)

func _draw_reference_frame(rect: Rect2, telemetry: Rect2, color: Color) -> void:
	var points := Tokens.frame_points(rect, 12.0)
	if points.is_empty():
		return
	var line_color := Color(color.r, color.g, color.b, 0.55)
	draw_polyline(points + PackedVector2Array([points[0]]), line_color, 1.0, true)
	var tick_color := Color(color.r, color.g, color.b, 0.72)
	var tick := 18.0
	for corner in [
		Vector2(rect.position.x + tick, rect.position.y),
		Vector2(rect.end.x - tick, rect.position.y),
		Vector2(rect.position.x + tick, rect.end.y),
		Vector2(rect.end.x - tick, rect.end.y),
	]:
		draw_circle(corner, 1.6, tick_color)
	draw_line(Vector2(rect.position.x + 26.0, rect.position.y), Vector2(rect.position.x + 116.0, rect.position.y), tick_color, 1.0)
	draw_line(Vector2(rect.end.x - 116.0, rect.position.y), Vector2(rect.end.x - 26.0, rect.position.y), tick_color, 1.0)
	draw_line(Vector2(rect.position.x + 26.0, rect.end.y), Vector2(rect.position.x + 116.0, rect.end.y), tick_color, 1.0)
	draw_line(Vector2(rect.end.x - 116.0, rect.end.y), Vector2(rect.end.x - 26.0, rect.end.y), tick_color, 1.0)
	for y in range(int(rect.position.y + 36.0), int(rect.end.y - 24.0), 36):
		draw_line(Vector2(rect.position.x, y), Vector2(rect.position.x + 6.0, y), line_color, 1.0)
		draw_line(Vector2(rect.end.x - 6.0, y), Vector2(rect.end.x, y), line_color, 1.0)
	if telemetry.size.x > 0.0:
		draw_line(telemetry.position, Vector2(telemetry.end.x, telemetry.position.y), Color(color.r, color.g, color.b, 0.32), 1.0)
	if not bool(_layout.get("narrow", false)):
		var footer := str(snapshot.get("footer", "FIELD // LIVE"))
		var footer_rect := Rect2(Vector2(0.0, telemetry.position.y), Vector2(size.x, telemetry.size.y))
		_draw_centered_text(footer, footer_rect, -2.0, ShareTechMono, 9, Color(color.r, color.g, color.b, 0.72))

func _draw_centered_text(text: String, rect: Rect2, baseline: float, font: Font, font_size: int, color: Color) -> void:
	var actual_font_size := _scaled_font_size(font_size)
	var clipped := TacticalUI.ellipsis_fit(font, text, maxf(rect.size.x - 24.0, 0.0), actual_font_size)
	draw_string(font, Vector2(rect.position.x + 12.0, rect.position.y + baseline), clipped, HORIZONTAL_ALIGNMENT_CENTER, maxf(rect.size.x - 24.0, 0.0), actual_font_size, color)

func _draw_combo(rect: Rect2, semantic: Dictionary) -> void:
	var combo := maxi(int(snapshot.get("combo", 1)), 1)
	var fraction := clampf(float(semantic.get("combo_fraction", 0.0)), 0.0, 1.0)
	var combo_color := Tokens.role_color("ready") if combo > 1 else Tokens.role_color("structure")
	var micro := bool(_layout.get("micro", false))
	_draw_centered_text("COMBO  x%d" % combo, rect, 16.0 if micro else 22.0, Orbitron, 15 if micro else (18 if combo > 1 else 16), combo_color)
	_draw_centered_text("CHAIN // %s" % ("ACTIVE" if combo > 1 and fraction > 0.0 else "STANDBY"), rect, 29.0 if micro else 40.0, ShareTechMono, 8 if micro else 10, Tokens.role_color("muted"))
	var bar := Rect2(rect.position.x + 18.0 if micro else rect.position.x + 24.0, rect.end.y - 6.0 if micro else rect.end.y - 9.0, maxf(rect.size.x - (36.0 if micro else 48.0), 24.0), 3.0 if micro else 4.0)
	draw_rect(bar, Color(combo_color.r, combo_color.g, combo_color.b, 0.14))
	for segment in 12:
		var segment_rect := Rect2(bar.position.x + float(segment) * bar.size.x / 12.0 + 1.0, bar.position.y, maxf(bar.size.x / 12.0 - 2.0, 1.0), bar.size.y)
		draw_rect(segment_rect, Color(combo_color.r, combo_color.g, combo_color.b, 0.82 if float(segment) / 12.0 < fraction else 0.12))

func _draw_text(text: String, position: Vector2, width: float, font_size: int, color: Color, font: Font = ShareTechMono) -> void:
	var actual_font_size := _scaled_font_size(font_size)
	var clipped := TacticalUI.ellipsis_fit(font, text, maxf(width, 0.0), actual_font_size)
	draw_string(font, position, clipped, HORIZONTAL_ALIGNMENT_LEFT, width, actual_font_size, color)

func _draw_state(rect: Rect2, semantic: Dictionary) -> void:
	var hp := int(snapshot.get("hp", 0))
	var max_hp := maxi(int(snapshot.get("max_hp", 1)), 1)
	if bool(_layout.get("micro", false)):
		_draw_text("INTEGRITY // %s" % semantic["integrity_state"], rect.position + Vector2(12, 13), rect.size.x - 24, 10, Tokens.role_color("danger") if hp <= 1 else Tokens.role_color("structure"))
		_draw_text("HP %02d/%02d" % [hp, max_hp], rect.position + Vector2(12, 30), rect.size.x - 24, 15, Tokens.role_color("focus"), Orbitron)
		var pip_stride := minf(18.0, (rect.size.x - 28.0) / float(max_hp))
		var pip_w := maxf(minf(10.0, pip_stride - 2.0), 1.0)
		var pip_x := rect.position.x + 14.0
		for i in max_hp:
			var filled := i < hp
			draw_rect(Rect2(pip_x + i * pip_stride, rect.position.y + 37.0, pip_w, 6.0), Tokens.role_color("danger") if filled else Color(0.2, 0.25, 0.3, 0.5), filled)
		var direction := str(semantic.get("damage_direction", "NONE"))
		_draw_text("HIT // " + direction if direction != "NONE" else "PROGRAM // " + str(semantic.get("program_id", "kernel")).to_upper(), rect.position + Vector2(12, 53), rect.size.x - 24, 8, Tokens.role_color("warning") if direction != "NONE" else Tokens.role_color("muted"))
		var meter_rect := Rect2(rect.position.x + 12.0, rect.position.y + 58.0, maxf(rect.size.x - 24.0, 24.0), 5.0)
		var meter_max := maxf(float(snapshot.get("meter_max", 100.0)), 1.0)
		var meter_fraction := clampf(float(snapshot.get("meter", 0.0)) / meter_max, 0.0, 1.0)
		var meter_color := Tokens.role_color("ready") if semantic["meter_state"] == "FULL" else Tokens.role_color("structure")
		draw_rect(meter_rect, Color(meter_color.r, meter_color.g, meter_color.b, 0.12))
		for segment in 10:
			var segment_rect := Rect2(meter_rect.position.x + float(segment) * meter_rect.size.x / 10.0 + 1.0, meter_rect.position.y, maxf(meter_rect.size.x / 10.0 - 2.0, 1.0), meter_rect.size.y)
			draw_rect(segment_rect, Color(meter_color.r, meter_color.g, meter_color.b, 0.86 if float(segment) / 10.0 < meter_fraction else 0.12))
		_draw_text("METER // %s" % semantic["meter_state"], rect.position + Vector2(12, 70), rect.size.x - 24, 8, meter_color if semantic["meter_state"] == "FULL" else Tokens.role_color("muted"))
		return
	_draw_text("INTEGRITY // %s" % semantic["integrity_state"], rect.position + Vector2(12, 20), rect.size.x - 24, 12, Tokens.role_color("danger") if hp <= 1 else Tokens.role_color("structure"))
	_draw_text("HP %02d/%02d" % [hp, max_hp], rect.position + Vector2(12, 42), rect.size.x - 24, 18, Tokens.role_color("focus"), Orbitron)
	var pip_x := rect.position.x + 14.0
	for i in max_hp:
		var filled := i < hp
		draw_rect(Rect2(pip_x + i * minf(18.0, (rect.size.x - 28.0) / float(max_hp)), rect.position.y + 56.0, 12.0, 10.0), Tokens.role_color("danger") if filled else Color(0.2, 0.25, 0.3, 0.5), filled)
	var direction := str(semantic.get("damage_direction", "NONE"))
	_draw_text("HIT FROM // " + direction if direction != "NONE" else "PROGRAM // " + str(semantic.get("program_id", "kernel")).to_upper(), rect.position + Vector2(12, 78), rect.size.x - 24, 10, Tokens.role_color("warning") if direction != "NONE" else Tokens.role_color("muted"))
	var meter_rect := Rect2(rect.position.x + 12.0, rect.position.y + 86.0, maxf(rect.size.x - 24.0, 24.0), 7.0)
	var meter_max := maxf(float(snapshot.get("meter_max", 100.0)), 1.0)
	var meter_fraction := clampf(float(snapshot.get("meter", 0.0)) / meter_max, 0.0, 1.0)
	var meter_color := Tokens.role_color("ready") if semantic["meter_state"] == "FULL" else Tokens.role_color("structure")
	draw_rect(meter_rect, Color(meter_color.r, meter_color.g, meter_color.b, 0.12))
	for segment in 10:
		var segment_rect := Rect2(meter_rect.position.x + float(segment) * meter_rect.size.x / 10.0 + 1.0, meter_rect.position.y, maxf(meter_rect.size.x / 10.0 - 2.0, 1.0), meter_rect.size.y)
		draw_rect(segment_rect, Color(meter_color.r, meter_color.g, meter_color.b, 0.86 if float(segment) / 10.0 < meter_fraction else 0.12))
	_draw_text("METER // %s" % semantic["meter_state"], rect.position + Vector2(12, 106), rect.size.x - 24, 10, meter_color if semantic["meter_state"] == "FULL" else Tokens.role_color("muted"))

func _draw_event(rect: Rect2) -> void:
	var micro := bool(_layout.get("micro", false))
	_draw_text("EVENT // " + ("ACTIVE" if not _event_text.is_empty() else "STANDBY"), rect.position + Vector2(12, 14 if micro else 18), rect.size.x - 24, 9 if micro else 10, Tokens.role_color("warning"))
	_draw_text(_event_render_text(rect), rect.position + Vector2(12, 33 if micro else 41), rect.size.x - 24, 11 if micro else 13, Tokens.role_color("focus"))

func _draw_patches(rect: Rect2) -> void:
	var micro := bool(_layout.get("micro", false))
	_draw_text(str(snapshot.get("cycle", "CYCLE %02d" % int(snapshot.get("wave", 0)))), rect.position + Vector2(12, 13 if micro else 18), rect.size.x - 24, 9 if micro else 11, Tokens.role_color("warning"))
	_draw_text("PATCH DOCK", rect.position + Vector2(12, 27 if micro else 39), rect.size.x - 24, 9 if micro else 10, Tokens.role_color("structure"))
	_draw_patch_chips(rect)
	_draw_text("ONLINE" if micro else "STATUS // ONLINE", rect.position + Vector2(12, 68 if micro else 90), rect.size.x - 24, 8 if micro else 9, Tokens.role_color("ready"))

func _draw_patch_chips(rect: Rect2) -> void:
	if _patch_labels.is_empty():
		_draw_text("NO PATCHES" if bool(_layout.get("micro", false)) else "NO ACTIVE PATCHES", rect.position + Vector2(12, 48 if bool(_layout.get("micro", false)) else 64), rect.size.x - 24, 9 if bool(_layout.get("micro", false)) else 10, Tokens.role_color("muted"))
		return
	var visible_count := mini(_patch_labels.size(), 4)
	var gap := 4.0
	var micro := bool(_layout.get("micro", false))
	var chip_area := Rect2(rect.position + Vector2(12.0, 30.0 if micro else 47.0), Vector2(maxf(rect.size.x - 24.0, 24.0), 16.0 if micro else 28.0))
	var chip_w := maxf((chip_area.size.x - gap * float(visible_count - 1)) / float(visible_count), 8.0)
	for index in visible_count:
		var chip := Rect2(chip_area.position.x + float(index) * (chip_w + gap), chip_area.position.y, chip_w, chip_area.size.y)
		var chip_color := Tokens.role_color("structure") if index < 3 else Tokens.role_color("danger")
		var points := Tokens.frame_points(chip.grow(-1.0), 4.0)
		draw_colored_polygon(points, Color(chip_color.r, chip_color.g, chip_color.b, 0.08))
		draw_polyline(points + PackedVector2Array([points[0]]), Color(chip_color.r, chip_color.g, chip_color.b, 0.58), 1.0, true)
		var glyph_center := chip.get_center() + Vector2(-chip.size.x * 0.25, 0.0) if micro else chip.get_center() - Vector2(0.0, 3.0)
		_draw_patch_glyph(glyph_center, 3.0 if micro else 6.0, index, chip_color)
		var label := _patch_labels[index]
		label = TacticalUI.ellipsis_fit(ShareTechMono, label, maxf(chip.size.x - 4.0, 4.0), _scaled_font_size(7 if micro else 8))
		var label_rect := Rect2(chip.position.x + 2.0, chip.position.y + 4.0, maxf(chip.size.x - 4.0, 4.0), chip.size.y - 4.0) if not micro else Rect2(chip.position.x + chip.size.x * 0.30, chip.position.y + 4.0, maxf(chip.size.x * 0.64, 4.0), chip.size.y - 4.0)
		draw_string(ShareTechMono, Vector2(label_rect.position.x, label_rect.end.y - 1.0), label, HORIZONTAL_ALIGNMENT_CENTER, label_rect.size.x, _scaled_font_size(7 if micro else 8), Color(chip_color.r, chip_color.g, chip_color.b, 0.92))
	if _patch_labels.size() > visible_count:
		_draw_text("+%d" % (_patch_labels.size() - visible_count), rect.position + Vector2(rect.size.x - 42.0, 58.0 if micro else 90.0), 30.0, 8 if micro else 9, Tokens.role_color("warning"))

func _draw_patch_glyph(center: Vector2, radius: float, index: int, color: Color) -> void:
	var glyph := Color(color.r, color.g, color.b, 0.9)
	match index % 5:
		0:
			draw_rect(Rect2(center - Vector2(radius * 0.7, radius * 0.7), Vector2(radius * 1.4, radius * 1.4)), glyph, false, 1.2)
		1:
			var diamond := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)])
			draw_polyline(diamond + PackedVector2Array([diamond[0]]), glyph, 1.2, true)
		2:
			draw_circle(center, radius * 0.78, glyph, false, 1.2)
			draw_circle(center, radius * 0.22, glyph)
		3:
			draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), glyph, 1.2)
			draw_line(center - Vector2(0, radius), center + Vector2(0, radius), glyph, 1.2)
		4:
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var p: Vector2 = center + corner * radius
				draw_line(p, p - corner * Vector2(radius * 0.45, 0), glyph, 1.2)

func _event_render_text(rect: Rect2) -> String:
	var text := _event_text if not _event_text.is_empty() else "PROCESS PURGE"
	return TacticalUI.ellipsis_fit(ShareTechMono, text, maxf(rect.size.x - 24.0, 0.0), _scaled_font_size(13))

func _draw_dash(rect: Rect2, semantic: Dictionary) -> void:
	var micro := bool(_layout.get("micro", false))
	_draw_text("ABILITY // " + str(semantic.get("program_id", Game.program)).to_upper(), rect.position + Vector2(12, 13 if micro else 18), rect.size.x - 24, 9 if micro else 11, Tokens.role_color("structure"))
	var state := str(semantic.get("ability_state", semantic.get("dash_state", "COOLDOWN")))
	var display_state := _ability_display_text(semantic)
	var icon_center := rect.position + (Vector2(28.0, 35.0) if micro else Vector2(34.0, 57.0))
	var state_rect := _ability_text_rect(rect)
	var state_size := _ability_font_size(state_rect, semantic, 4.0)
	_draw_dash_glyph(icon_center, 11.0 if micro else 18.0, Tokens.role_color("ready") if state.contains("READY") else Tokens.role_color("warning"))
	_draw_text(display_state, state_rect.position, state_rect.size.x, state_size, Tokens.role_color("ready") if state.contains("READY") else Tokens.role_color("warning"), Orbitron)
	var hint := "TOUCH / ACTION" if context != null and context.input_mode == "touch" else "SHIFT / SPACE"
	_draw_text(hint, rect.position + Vector2(12, 51 if micro else 80), rect.size.x - 24, 8 if micro else 10, Tokens.role_color("muted"))
	var charge := Rect2(rect.position.x + (58.0 if micro else 68.0), rect.position.y + (58.0 if micro else 84.0), maxf(rect.size.x - (68.0 if micro else 80.0), 28.0 if micro else 48.0), 4.0 if micro else 5.0)
	var fraction := clampf(float(snapshot.get("dash_frac", 0.0)), 0.0, 1.0)
	draw_rect(charge, Color(0.25, 0.35, 0.4, 0.38))
	for segment in 5:
		var segment_rect := Rect2(charge.position.x + float(segment) * charge.size.x / 5.0 + 1.0, charge.position.y, maxf(charge.size.x / 5.0 - 2.0, 1.0), charge.size.y)
		draw_rect(segment_rect, Color(Tokens.role_color("ready").r, Tokens.role_color("ready").g, Tokens.role_color("ready").b, 0.88 if float(segment) / 5.0 < fraction else 0.16))

func _draw_dash_glyph(center: Vector2, radius: float, color: Color) -> void:
	var line_color := Color(color.r, color.g, color.b, 0.9)
	for index in 3:
		var x := center.x - radius * 0.9 + float(index) * radius * 0.65
		var chevron := PackedVector2Array([Vector2(x - radius * 0.34, center.y - radius * 0.55), Vector2(x + radius * 0.30, center.y), Vector2(x - radius * 0.34, center.y + radius * 0.55)])
		draw_polyline(chevron, line_color, 2.0, true)

func _draw_score(rect: Rect2) -> void:
	var micro := bool(_layout.get("micro", false))
	_draw_text(_score_display_text(), rect.position + Vector2(12, 15 if micro else 22), rect.size.x - 24, _score_font_size(rect), Tokens.role_color("focus"), Orbitron)
	_draw_text(str(snapshot.get("time", "TIME 00:00.0")), rect.position + Vector2(12, 36 if micro else 50), rect.size.x - 24, 9 if micro else 11, Tokens.role_color("warning"))
	_draw_text(_run_display_text(), rect.position + Vector2(12, 55 if micro else 76), rect.size.x - 24, 8 if micro else 10, Tokens.role_color("muted"))

func _draw_boss(rect: Rect2, semantic: Dictionary) -> void:
	var micro := bool(_layout.get("micro", false))
	_draw_text(str(semantic.get("boss_phase", "PHASE 1")), rect.position + Vector2(12, 28 if micro else 31), rect.size.x - 24, 8 if micro else 10, Tokens.role_color("warning"))
	var bars: Array = boss_bars_snapshot()
	var bar_x := rect.position.x + rect.size.x * 0.56
	var bar_w := rect.size.x * 0.39
	var label_width := maxf(bar_x - rect.position.x - 24.0, 80.0)
	_draw_text(_boss_title_text(rect), rect.position + Vector2(12, 12 if micro else 14), label_width, 8 if micro else 10, Tokens.role_color("danger"))
	for index in bars.size():
		var bar := Rect2(bar_x, rect.position.y + (4.0 if micro else 7.0) + index * (9.0 if micro else 13.0), bar_w, 5.0 if micro else 7.0)
		draw_rect(bar, Color(0.2, 0.25, 0.3, 0.6))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(bars[index].get("fraction", 0.0)), bar.size.y)), Tokens.role_color("danger"))

func _boss_title_text(rect: Rect2) -> String:
	var bar_x := rect.position.x + rect.size.x * 0.56
	var width := maxf(bar_x - rect.position.x - 24.0, 80.0)
	var title := "BOSS // %s" % str(snapshot.get("boss_name", "ROOT.exe"))
	return TacticalUI.ellipsis_fit(ShareTechMono, title, width, _scaled_font_size(10))

func _boss_fragments_snapshot(source: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw = source.get("_boss_fragments")
	if not raw is Array:
		return result
	for fragment in raw:
		if fragment is RootBoss and is_instance_valid(fragment):
			result.append({"slot": int(fragment.get_meta("mini_slot", result.size())), "fraction": clampf(float(fragment.hp) / maxf(float(fragment.max_hp), 1.0), 0.0, 1.0)})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("slot", 0)) < int(b.get("slot", 0))
	)
	return result

func _refresh_patch_labels() -> void:
	var signature := ""
	for id in Game.patch_levels:
		signature += str(id) + ":" + str(int(Game.patch_levels[id])) + ";"
	if signature == _patch_signature:
		return
	_patch_signature = signature
	_patch_labels.clear()
	for id in Game.patch_levels:
		var code: String = Game.PATCH_CODES.get(id, str(id).substr(0, 2).to_upper())
		_patch_labels.append("%s%d" % [code, int(Game.patch_levels[id])])

func _set_snapshot_patch_labels(raw) -> void:
	_patch_labels.clear()
	if not raw is Array:
		return
	for entry in raw:
		if entry is Dictionary:
			_patch_labels.append(str(entry.get("label", entry.get("id", "PATCH"))))
		else:
			_patch_labels.append(str(entry))

func _patch_text() -> String:
	if _patch_labels.is_empty():
		return "NO ACTIVE PATCHES"
	return " // ".join(_patch_labels)

extends Node

var fails := 0
var done := false

func _check(ok: bool, label: String) -> void:
	if ok:
		print("PROBE_PASS ", label)
	else:
		fails += 1
		print("PROBE_FAIL ", label)

func _ready() -> void:
	_check(OS.get_environment("KP_VNEXT_HUD") == "1", "probe runs with vnext hud opt-in")
	var surface_script: Script = load("res://src/ui/vnext/surfaces/combat_hud_surface.gd")
	_check(surface_script != null, "combat hud surface script exists")
	if surface_script == null:
		_finish()
		return
	var surface: Control = surface_script.new()
	add_child(surface)
	var context_script: Script = load("res://src/ui/vnext/ui_context.gd")
	var context: RefCounted = context_script.from_viewport(Vector2(1280, 720), false)
	var state := {
		"hp": 1, "max_hp": 12, "meter": 0.0, "meter_max": 100.0,
		"dash_frac": 0.0, "dash_available": 0, "dash_max": 1,
		"wave": 7, "cycle": "CYCLE 07", "score": 1234, "combo": 3, "combo_frac": 0.72,
		"time": "TIME 01:23.4", "run": "SEED 42", "event": "A".repeat(180),
		"patches": ["FR3", "R0", "SR1", "PG2"],
		"boss_name": "ROOT.exe // FORKED", "boss_frac": 0.42, "boss_split": true,
		"boss_fragments": [{"slot": 0, "fraction": 0.42}, {"slot": 1, "fraction": 0.31}],
		"boss_phase": "PHASE 2 // SPLIT", "damage_direction": "NORTH-EAST",
	}
	_check(surface.has_method("configure"), "surface exposes configure")
	_check(surface.has_method("layout_snapshot") and surface.has_method("text_overflow_report"), "surface exposes layout and overflow contracts")
	_check(surface.has_method("semantic_snapshot") and surface.has_method("action_regions") and surface.has_method("handle_input"), "surface exposes semantic and input contracts")
	_check(surface.mouse_filter == Control.MOUSE_FILTER_IGNORE, "hud surface does not block combat pointer input")
	_check(surface.has_method("boss_bars_snapshot"), "surface exposes boss bar fractions")
	surface.call("configure", state, context)
	for hp in range(1, 13):
		state["hp"] = hp
		surface.call("configure", state, context)
		var semantic: Dictionary = surface.call("semantic_snapshot")
		_check(int(semantic.get("integrity_pips", -1)) == hp, "integrity pips track %d hp" % hp)
	state["meter"] = 0.0
	surface.call("configure", state, context)
	_check(str(surface.call("semantic_snapshot").get("meter_state", "")) == "EMPTY", "empty meter has semantic marker")
	state["meter"] = 100.0
	surface.call("configure", state, context)
	_check(str(surface.call("semantic_snapshot").get("meter_state", "")) == "FULL", "full meter has semantic marker")
	state["dash_frac"] = 1.0
	state["dash_available"] = 1
	surface.call("configure", state, context)
	_check(str(surface.call("semantic_snapshot").get("dash_state", "")) == "READY", "ready dash has semantic marker")
	state["dash_frac"] = 0.25
	state["dash_available"] = 0
	surface.call("configure", state, context)
	_check(str(surface.call("semantic_snapshot").get("dash_state", "")) == "COOLDOWN", "cooldown dash has semantic marker")
	var layout: Dictionary = surface.call("layout_snapshot")
	var semantic_snapshot: Dictionary = surface.call("semantic_snapshot")
	_check(layout.has("frame") and layout.has("telemetry"), "reference frame and telemetry regions exist")
	_check(layout.has("combo") and (layout["combo"] as Rect2).size.y >= 70.0, "combo has a dedicated top-center region")
	_check(str(semantic_snapshot.get("combo_label", "")) == "COMBO x3", "combo exposes a readable semantic label")
	_check(int(semantic_snapshot.get("patch_count", -1)) == 4, "patch dock exposes each active patch")
	_check(_reserved_center(layout, Vector2(1280, 720)), "desktop reserves playfield center")
	_check(_boss_clear_of_player(layout, Vector2.ZERO), "desktop boss bar avoids player")
	_check(_panels_do_not_overlap(layout), "desktop hud panels do not overlap")
	_check(_regions_inside_safe(layout), "desktop hud regions stay inside the safe frame")
	var boss_bars: Array = surface.call("boss_bars_snapshot")
	_check(boss_bars.size() == 2 and float(boss_bars[0].get("fraction", -1.0)) > 0.0 and float(boss_bars[1].get("fraction", -1.0)) > 0.0, "split boss exposes both live bar fractions")
	var action_regions: Dictionary = surface.call("action_regions")
	_check(action_regions.has("dash") and (action_regions["dash"] as Rect2).size.x >= 96.0 and (action_regions["dash"] as Rect2).size.y >= 64.0, "dash action is touch-safe")
	state["event"] = "WAVE STARTED"
	surface.call("configure", state, context)
	var overflow: Dictionary = surface.call("text_overflow_report")
	_check(not bool(overflow.get("has_overflow", true)), "normal event text fits")
	state["event"] = "EVENT // " + "LONG_PAYLOAD_".repeat(40)
	surface.call("configure", state, context)
	overflow = surface.call("text_overflow_report")
	_check(bool(overflow.get("has_overflow", false)), "long event text is reported")
	_check(bool(overflow.get("fields", {}).get("event", {}).get("rendered_fits", false)), "long event text is ellipsized in the render path")
	for viewport in [Vector2(320, 568), Vector2(390, 844), Vector2(432, 720), Vector2(600, 600), Vector2(1280, 720), Vector2(1920, 720)]:
		var resized_context: RefCounted = context_script.from_viewport(viewport, true)
		surface.call("configure", state, resized_context)
		layout = surface.call("layout_snapshot")
		action_regions = surface.call("action_regions")
		_check(_reserved_center(layout, viewport), "viewport %s reserves center" % viewport)
		_check(_panels_do_not_overlap(layout), "viewport %s keeps hud panels separate" % viewport)
		_check(_regions_inside_safe(layout), "viewport %s keeps hud regions inside the safe frame" % viewport)
		_check((action_regions["dash"] as Rect2).size.x >= 96.0 and (action_regions["dash"] as Rect2).size.y >= 64.0, "viewport %s keeps touch-safe dash" % viewport)
	var scaled_context: RefCounted = context_script.from_viewport(Vector2(1280, 720), false, false, false, 1.15)
	state["event"] = "WAVE STARTED"
	surface.call("configure", state, scaled_context)
	overflow = surface.call("text_overflow_report")
	_check(not bool(overflow.get("has_overflow", true)), "reference HUD remains readable at 115 percent text scale")
	var scaled_narrow_context: RefCounted = context_script.from_viewport(Vector2(432, 720), true, false, false, 1.15)
	surface.call("configure", state, scaled_narrow_context)
	overflow = surface.call("text_overflow_report")
	_check(not bool(overflow.get("has_overflow", true)), "narrow HUD remains readable at 115 percent text scale")
	var micro_context: RefCounted = context_script.from_viewport(Vector2(320, 568), true, false, false, 1.0)
	surface.call("configure", state, micro_context)
	var micro_layout: Dictionary = surface.call("layout_snapshot")
	_check(bool(micro_layout.get("micro", false)), "micro narrow HUD opts into the stacked composition")
	overflow = surface.call("text_overflow_report")
	_check(not bool(overflow.get("has_overflow", true)), "micro narrow HUD keeps its rendered copy inside its panels")
	var before: Rect2 = (surface.call("layout_snapshot")["integrity"] as Rect2)
	surface.call("reflow_for_viewport", Vector2(900, 720))
	var after: Rect2 = (surface.call("layout_snapshot")["integrity"] as Rect2)
	_check(before != after, "layout reflows after viewport resize")
	_check(surface.call("handle_input", {"action": "dash"}), "dash input dispatches through surface")
	_check(str(surface.call("semantic_snapshot").get("damage_direction", "")) == "NORTH-EAST", "damage direction has semantic marker")
	surface.queue_free()
	Game.stats = {"time": 0.0, "wave": 1, "kills": 0, "shots": 0, "hits": 0, "damage": 0, "boss_kills": 0, "heals": {}}
	var arena_script: Script = load("res://src/arena/arena.gd")
	var arena: Node = arena_script.new()
	get_tree().root.call_deferred("add_child", arena)
	await get_tree().process_frame
	_check(arena.has_method("vnext_hud_enabled") and bool(arena.call("vnext_hud_enabled")), "real Arena enables vnext hud opt-in")
	_check(arena.has_method("vnext_hud_surface") and arena.call("vnext_hud_surface") != null, "real Arena mounts combat hud surface")
	_check(arena.get("player") != null and arena.get("hud") != null, "real Arena wires player and hud")
	var arena_player: Node = arena.get("player")
	var arena_hud: Node = arena.call("vnext_hud_surface")
	var arena_hud_adapter: Node = arena.get("hud")
	var legacy_dash: Control = arena_hud_adapter.get("_dash_icon")
	_check(legacy_dash == null or not legacy_dash.visible, "vnext hud hides the legacy dash icon")
	arena_hud_adapter.set("_mult", 5)
	arena_hud_adapter.set("_combo_frac", 0.5)
	arena_hud.call("sync_from_hud", arena_hud_adapter)
	var live_combo: Dictionary = arena_hud.call("semantic_snapshot")
	_check(str(live_combo.get("combo_label", "")) == "COMBO x5" and is_equal_approx(float(live_combo.get("combo_fraction", 0.0)), 0.5), "real HUD syncs combo state into the reference header")
	arena_hud_adapter.call("show_banner", "CYCLE 02", "PURGE THE DAEMONS", 2.0)
	arena_hud.call("sync_from_hud", arena_hud_adapter)
	var event_report: Dictionary = arena_hud.call("text_overflow_report")
	_check(str(event_report.get("fields", {}).get("event", {}).get("text", "")) == "PURGE THE DAEMONS", "cycle banner keeps cycle in continuous dock and event copy temporary")
	arena_hud_adapter.call("show_banner", "WAVE INBOUND", "PURGE THE DAEMONS", 2.0)
	arena_hud.call("sync_from_hud", arena_hud_adapter)
	event_report = arena_hud.call("text_overflow_report")
	_check(str(event_report.get("fields", {}).get("event", {}).get("text", "")) == "WAVE INBOUND // PURGE THE DAEMONS", "named wave event remains visible in the temporary event slot")
	arena_player.call("take_damage", Vector2(-100.0, 0.0), "PROBE DAMAGE")
	await get_tree().process_frame
	await get_tree().process_frame
	var live_semantic: Dictionary = arena_hud.call("semantic_snapshot")
	_check(float(arena_player.get("last_damage_direction_t")) > 0.0, "real damage records a direction lifetime")
	_check(str(live_semantic.get("damage_direction", "NONE")) != "NONE", "real damage publishes a direction marker")
	arena.queue_free()
	await get_tree().process_frame
	_finish()

func _reserved_center(layout: Dictionary, viewport: Vector2) -> bool:
	var reserved: Rect2 = layout.get("reserved_playfield", Rect2())
	return reserved.size.x >= minf(120.0, viewport.x * 0.25) and reserved.size.y >= minf(120.0, viewport.y * 0.25)

func _boss_clear_of_player(layout: Dictionary, player_position: Vector2) -> bool:
	var boss: Rect2 = layout.get("boss", Rect2())
	return boss.size == Vector2.ZERO or not boss.grow(8.0).has_point(player_position)

func _panels_do_not_overlap(layout: Dictionary) -> bool:
	var rects: Array[Rect2] = [layout.get("integrity", Rect2()), layout.get("event", Rect2()), layout.get("patches", Rect2()), layout.get("dash", Rect2()), layout.get("score", Rect2()), layout.get("combo", Rect2())]
	if bool(layout.get("boss_active", true)):
		rects.append(layout.get("boss", Rect2()))
	for i in rects.size():
		if rects[i].size.x <= 0.0 or rects[i].size.y <= 0.0:
			continue
		for j in range(i + 1, rects.size()):
			if rects[i].intersects(rects[j], true):
				return false
	return true

func _regions_inside_safe(layout: Dictionary) -> bool:
	var safe: Rect2 = layout.get("safe", Rect2())
	for id in ["integrity", "event", "patches", "dash", "score", "combo", "boss"]:
		var rect: Rect2 = layout.get(id, Rect2())
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		if not safe.encloses(rect):
			return false
	return true

func _finish() -> void:
	if done:
		return
	done = true
	print("PROBE_DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)

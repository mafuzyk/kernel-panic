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
		"wave": 7, "cycle": "CYCLE 07", "score": 1234, "combo": 3,
		"time": "TIME 01:23.4", "run": "SEED 42", "event": "A".repeat(180),
		"boss_name": "ROOT.exe // FORKED", "boss_frac": 0.42, "boss_split": true,
		"boss_phase": "PHASE 2 // SPLIT", "damage_direction": "NORTH-EAST",
	}
	_check(surface.has_method("configure"), "surface exposes configure")
	_check(surface.has_method("layout_snapshot") and surface.has_method("text_overflow_report"), "surface exposes layout and overflow contracts")
	_check(surface.has_method("semantic_snapshot") and surface.has_method("action_regions") and surface.has_method("handle_input"), "surface exposes semantic and input contracts")
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
	_check(_reserved_center(layout, Vector2(1280, 720)), "desktop reserves playfield center")
	_check(_boss_clear_of_player(layout, Vector2.ZERO), "desktop boss bar avoids player")
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
	for viewport in [Vector2(432, 720), Vector2(1280, 720), Vector2(1920, 720)]:
		var resized_context: RefCounted = context_script.from_viewport(viewport, true)
		surface.call("configure", state, resized_context)
		layout = surface.call("layout_snapshot")
		action_regions = surface.call("action_regions")
		_check(_reserved_center(layout, viewport), "viewport %s reserves center" % viewport)
		_check((action_regions["dash"] as Rect2).size.x >= 96.0 and (action_regions["dash"] as Rect2).size.y >= 64.0, "viewport %s keeps touch-safe dash" % viewport)
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
	arena.queue_free()
	await get_tree().process_frame
	_finish()

func _reserved_center(layout: Dictionary, viewport: Vector2) -> bool:
	var reserved: Rect2 = layout.get("reserved_playfield", Rect2())
	return reserved.size.x >= minf(120.0, viewport.x * 0.25) and reserved.size.y >= minf(120.0, viewport.y * 0.25)

func _boss_clear_of_player(layout: Dictionary, player_position: Vector2) -> bool:
	var boss: Rect2 = layout.get("boss", Rect2())
	return boss.size == Vector2.ZERO or not boss.grow(8.0).has_point(player_position)

func _finish() -> void:
	if done:
		return
	done = true
	print("PROBE_DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)

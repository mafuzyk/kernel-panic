extends Node

const Adapter = preload("res://src/ui/vnext/core/entity_presentation_adapter.gd")
const ContentCatalog = preload("res://src/data/content_catalog.gd")
const Renderer = preload("res://src/ui/vnext/core/entity_renderer.gd")
const ProgramSurface = preload("res://src/ui/vnext/surfaces/program_surface.gd")
const CombatHudSurface = preload("res://src/ui/vnext/surfaces/combat_hud_surface.gd")
const PauseSurface = preload("res://src/ui/vnext/surfaces/pause_surface.gd")
const Context = preload("res://src/ui/vnext/ui_context.gd")

var _passes := 0
var _fails := 0

func _ready() -> void:
	await get_tree().process_frame
	_check_player_contract()
	_check_real_renderer_path()
	await _check_consumers()
	print("PROBE_DONE fails=%d passes=%d" % [_fails, _passes])
	if _fails == 0:
		print("PROBE_DONE fails=0")
	get_tree().quit(1 if _fails > 0 else 0)

func _check_player_contract() -> void:
	var expected := {
		"kernel": {"aim": Vector2.RIGHT, "hp": 4, "max_hp": 4, "overclock_active": false, "oc_ready": true, "dash_available": 1, "shield_mode": false, "shield_ready": false, "shield_meter": 0.0},
		"daemon": {"aim": Vector2.UP, "hp": 2, "max_hp": 3, "overclock_active": false, "oc_ready": false, "dash_available": 1, "dash_t": 0.0, "shield_mode": false, "shield_ready": false, "shield_meter": 0.0},
		"rootlet": {"aim": Vector2.LEFT, "hp": 5, "max_hp": 5, "overclock_active": false, "oc_ready": false, "dash_available": 1, "dash_t": 0.0, "shield_mode": true, "shield_ready": false, "shield_meter": 0.0},
	}
	for id in expected:
		var player := Player.new()
		player.program_id = id
		player.prog = Game.PROGRAM_DEFS[id].duplicate(true)
		for key in expected[id]:
			player.set(key, expected[id][key])
		var before := _player_signature(player)
		var snapshot := Adapter.from_player(player)
		_check(str(snapshot.get("kind")) == id, "%s maps to distinct renderer kind" % id)
		var expected_color: Color = ContentCatalog.PROGRAM_DEFS[id]["visual"]["color"]
		_check(Renderer.color_for(snapshot).is_equal_approx(expected_color), "%s uses canonical program color" % id)
		_check(str(snapshot.get("nested", {}).get("program_id", "")) == id, "%s exposes stable program id" % id)
		_check(bool(snapshot.get("nested", {}).get("shield_mode", false)) == bool(expected[id]["shield_mode"]), "%s shield mode reflects Player" % id)
		_check(bool(snapshot.get("nested", {}).get("overclock_active", false)) == bool(expected[id]["overclock_active"]), "%s overclock reflects Player" % id)
		_check(int(snapshot.get("nested", {}).get("dash_available", -1)) == int(expected[id]["dash_available"]), "%s dash reflects Player" % id)
		_check(_player_signature(player) == before, "%s adapter is read-only" % id)
		player.free()

func _check_real_renderer_path() -> void:
	var player := Player.new()
	player.program_id = "rootlet"
	player.prog = Game.PROGRAM_DEFS["rootlet"].duplicate(true)
	player.aim = Vector2.LEFT
	player.shield_meter = 100.0
	var snapshot := Adapter.from_player(player)
	var host := _ProbeCanvas.new()
	host.snapshot = snapshot
	host.before = _player_signature(player)
	host.player = player
	add_child(host)
	host.queue_redraw()
	await get_tree().process_frame
	_check(host.drawn, "actual queued renderer path executed")
	_check(_player_signature(player) == host.before, "actual renderer path leaves Player unchanged")
	host.free()
	player.free()

func _check_consumers() -> void:
	var context := Context.from_viewport(Vector2(432.0, 720.0))
	var player := Player.new()
	player.program_id = "rootlet"
	player.prog = Game.PROGRAM_DEFS["rootlet"].duplicate(true)
	player.shield_ready = true
	player.shield_meter = Balance.OC_METER_MAX
	player.dash_available = 0
	var snapshot := Adapter.from_player(player)
	var program := ProgramSurface.new()
	add_child(program)
	program.size = context.viewport_size
	program.configure({"selected": "rootlet"}, context)
	_check(str(program.semantic_snapshot().get("selected")) == "rootlet", "program selector keeps selected identity")
	_check(program.text_overflow_report().all(func(item): return bool(item.get("fits", false))), "program selector narrow text fits")
	await get_tree().process_frame
	var illustration = program.get("_illustration")
	_check(illustration != null and str(illustration.visual_snapshot().get("kind", "")) == "rootlet", "program selector queues shared rootlet renderer")
	var hud := _CaptureCombatHud.new()
	add_child(hud)
	hud.configure({"program": snapshot.get("nested", {}).get("program_id"), "program_kind": snapshot.get("kind"), "program_snapshot": snapshot, "hp": player.hp, "max_hp": player.max_hp, "meter": player.shield_meter, "meter_max": Balance.OC_METER_MAX, "dash_available": player.dash_available, "dash_frac": 0.0, "patches": []}, context)
	_check(str(hud.semantic_snapshot().get("program_id", "")) == "rootlet", "combat HUD receives real program identity")
	_check(str(hud.semantic_snapshot().get("ability_state", "")) == "SHIELD READY", "combat HUD receives real shield state")
	hud.queue_redraw()
	await get_tree().process_frame
	_check(hud.drawn_text.has("PROGRAM // ROOTLET"), "combat HUD draws snapshot program identity")
	_check(hud.drawn_text.has("SHIELD READY"), "combat HUD draws program-specific ability state")
	var hud_overflow := hud.text_overflow_report()
	_check(not bool(hud_overflow.get("has_overflow", true)), "combat HUD narrow text fits")
	if bool(hud_overflow.get("has_overflow", false)):
		for field_id in hud_overflow.get("fields", {}):
			if not bool(hud_overflow["fields"][field_id].get("fits", false)):
				print("PROBE_INFO overflow_field=%s text=%s" % [field_id, hud_overflow["fields"][field_id].get("text", "")])
	var pause := PauseSurface.new()
	add_child(pause)
	pause.show_pause({"context": "ROOTLET // SHIELD READY", "program_snapshot": snapshot, "visible": true})
	_check(str(pause.semantic_snapshot().get("program_id", "")) == "rootlet", "pause receives real program identity")
	_check(str(pause.semantic_snapshot().get("ability_state", "")) == "SHIELD READY", "pause receives real shield state")
	_check(str(pause.call("_display_context")) == "ROOTLET // SHIELD READY", "pause draws snapshot program context")
	_check(not bool(pause.text_overflow_report().get("has_overflow", true)), "pause narrow text fits")
	program.free()
	hud.free()
	pause.free()
	player.free()

func _player_signature(player: Player) -> Dictionary:
	return {"prog": player.prog.duplicate(true), "aim": player.aim, "hp": player.hp, "max_hp": player.max_hp, "overclock_active": player.overclock_active, "oc_ready": player.oc_ready, "dash_available": player.dash_available, "dash_t": player.dash_t, "shield_mode": bool(player.prog.get("shield_mode", false)), "shield_ready": player.shield_ready, "shield_meter": player.shield_meter}

func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PROBE_PASS %s" % label)
	else:
		_fails += 1
		print("PROBE_FAIL %s" % label)

class _ProbeCanvas:
	extends Node2D
	var snapshot := {}
	var player: Player
	var before := {}
	var drawn := false

	func _draw() -> void:
		Renderer.draw(self, snapshot, Rect2(-96.0, -96.0, 192.0, 192.0), 0.0)
		drawn = true

class _CaptureCombatHud:
	extends CombatHudSurface
	var drawn_text: Array[String] = []

	func _draw_text(text: String, position: Vector2, width: float, font_size: int, color: Color, font: Font = null) -> void:
		drawn_text.append(text)

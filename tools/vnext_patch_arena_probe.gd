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
	_check(OS.get_environment("KP_VNEXT_PATCH") == "1", "probe runs with vnext patch opt-in")
	Game.mode = "classic"
	Game.state = Game.State.PLAYING
	Game.patch_levels = {}
	Game.stats = {"kills": 0, "shots": 0, "hits": 0, "damage": 0, "time": 0.0, "wave": 1, "boss_kills": 0, "heals": {}}
	var arena_script: Script = load("res://src/arena/arena.gd")
	var arena: Node = arena_script.new()
	get_tree().root.call_deferred("add_child", arena)
	await get_tree().process_frame
	_check(arena != null, "real Arena scene starts")
	if arena == null:
		_finish()
		return
	_check(arena.has_method("vnext_patch_enabled") and bool(arena.call("vnext_patch_enabled")), "Arena exposes opt-in patch route")
	var has_vnext_route := arena.has_method("vnext_patch_surface") and arena.has_method("vnext_patch_visible")
	_check(has_vnext_route and arena.call("vnext_patch_surface") != null, "Arena owns vnext patch surface")
	_check(has_vnext_route and not bool(arena.call("vnext_patch_visible")), "vnext patch starts hidden")
	var future_offer: Dictionary = arena.call("_snapshot_patch_offer", {"id": "secret", "title": "SECRET", "description": "REAL EFFECT", "effect": "REAL EFFECT", "cost_benefit": "COST // KEY", "build_impact": "BEFORE // HV1   AFTER // HV2", "locked": true, "reason": "REQUIRES ROOT ACCESS"})
	_check(str(future_offer.get("effect", "")) == "REAL EFFECT" and str(future_offer.get("cost_benefit", "")) == "COST // KEY", "Arena preserves explicit patch presentation data")
	_check(str(future_offer.get("state", "")) == "locked" and not bool(future_offer.get("available", true)) and str(future_offer.get("reason", "")) == "REQUIRES ROOT ACCESS", "Arena projects locked patch state and reason")
	if not has_vnext_route:
		arena.queue_free()
		_finish()
		return
	arena.call("offer_patch")
	var opened := await _until_patch_open(arena)
	_check(opened, "real patch offer opens through Arena")
	var surface: Control = arena.call("vnext_patch_surface") as Control
	_check(surface != null and surface.visible and get_tree().paused, "Arena pauses behind vnext patch surface")
	if surface != null:
		get_viewport().push_input(_key(KEY_ESCAPE, true))
		get_viewport().push_input(_key(KEY_ESCAPE, false))
		await get_tree().process_frame
		_check(not get_tree().paused and not bool(arena.call("vnext_patch_visible")), "real vnext patch close resumes Arena")
	arena.call("offer_patch")
	var skip_opened := await _until_patch_open(arena)
	_check(skip_opened, "Arena reopens after explicit close")
	surface = arena.call("vnext_patch_surface") as Control
	if surface != null and skip_opened:
		_check(surface.set_focus_id("skip"), "real vnext patch skip focus is addressable")
		get_viewport().push_input(_key(KEY_ENTER, true))
		get_viewport().push_input(_key(KEY_ENTER, false))
		await get_tree().process_frame
		_check(not get_tree().paused, "real vnext patch skip dispatches")
	_check(not get_tree().paused and not bool(arena.call("vnext_patch_visible")), "skip resumes Arena and closes surface")
	_check(int(arena.get("_patch_pending")) == 0, "skip consumes exactly one pending offer")
	arena.call("offer_patch")
	var reopened := await _until_patch_open(arena)
	_check(reopened, "Arena can reopen a fresh vnext patch offer")
	surface = arena.call("vnext_patch_surface") as Control
	if surface != null and reopened:
		var offered: Array = (arena.get("_patch_offers") as Array).duplicate(true)
		var patch_id := str(offered[0].get("id", "")) if not offered.is_empty() else ""
		var before_level := Game.patch_level(patch_id)
		_check(surface.set_focus_id("confirm"), "real vnext patch confirm focus is addressable")
		get_viewport().push_input(_key(KEY_ENTER, true))
		get_viewport().push_input(_key(KEY_ENTER, false))
		await get_tree().process_frame
		_check(Game.patch_level(patch_id) == before_level + 1, "real vnext confirm applies exactly one selected patch")
		_check(not get_tree().paused and not bool(arena.call("vnext_patch_visible")), "confirm resumes Arena and closes surface")
	arena.queue_free()
	_finish()

func _until_patch_open(arena: Node) -> bool:
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		if bool(arena.get("_patch_open")):
			return true
		await get_tree().process_frame
	return false

func _key(code: int, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	return event

func _finish() -> void:
	if done:
		return
	done = true
	print("PROBE_DONE fails=%d" % fails)
	get_tree().paused = false
	get_tree().quit(1 if fails > 0 else 0)

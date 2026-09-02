extends Node

const BootSurface = preload("res://src/ui/vnext/surfaces/boot_surface.gd")
const ProgramSurface = preload("res://src/ui/vnext/surfaces/program_surface.gd")
const BestiarySurface = preload("res://src/ui/vnext/surfaces/bestiary_surface.gd")
const AccessibilitySurface = preload("res://src/ui/vnext/surfaces/accessibility_surface.gd")
const StorySurface = preload("res://src/ui/vnext/surfaces/story_surface.gd")
const PatchSurface = preload("res://src/ui/vnext/surfaces/patch_surface.gd")
const CombatHudSurface = preload("res://src/ui/vnext/surfaces/combat_hud_surface.gd")
const Context = preload("res://src/ui/vnext/ui_context.gd")
const ContentCatalog = preload("res://src/data/content_catalog.gd")

func _ready() -> void:
	_capture.call_deferred()

func _capture() -> void:
	var viewport := _viewport_from_environment()
	var surface_id := OS.get_environment("KP_VNEXT_CAPTURE_SURFACE").to_lower()
	var output := OS.get_environment("KP_VNEXT_CAPTURE_OUT")
	if surface_id.is_empty() or output.is_empty():
		print("CAPTURE_FAIL missing KP_VNEXT_CAPTURE_SURFACE or KP_VNEXT_CAPTURE_OUT")
		get_tree().quit(2)
		return
	var script: Script = {
		"boot": BootSurface,
		"program": ProgramSurface,
		"bestiary": BestiarySurface,
		"accessibility": AccessibilitySurface,
		"story": StorySurface,
		"patch": PatchSurface,
		"combat_hud": CombatHudSurface,
	}.get(surface_id)
	if script == null:
		print("CAPTURE_FAIL unknown surface ", surface_id)
		get_tree().quit(2)
		return
	if surface_id == "program":
		Game.unlocked_programs = {"kernel": true, "daemon": true, "rootlet": true}
	if surface_id == "bestiary":
		Game.bestiary = {}
		for index in 8:
			Game.bestiary[ContentCatalog.BESTIARY_ENTRIES[index]["id"]] = true
	var selected := 0
	var act := "unix"
	if surface_id == "story":
		act = OS.get_environment("KP_VNEXT_CAPTURE_ACT").to_lower()
		if act.is_empty():
			act = "unix"
		selected = int(OS.get_environment("KP_VNEXT_CAPTURE_SELECTED"))
		for previous in selected:
			Game.story_cleared[Game.story_stage_id(previous)] = true
		if act == "macos":
			Game.story_cleared["temple_god"] = true
	elif surface_id == "patch":
		selected = int(OS.get_environment("KP_VNEXT_CAPTURE_SELECTED"))
	elif surface_id == "combat_hud":
		Game.patch_levels = {"splitshot": 1, "ring0": 1, "system_restore": 1, "pagecache": 2}
	var surface = script.new()
	surface.size = viewport
	add_child(surface)
	var touch := OS.get_environment("KP_VNEXT_CAPTURE_TOUCH") == "1"
	var surface_snapshot := {"program": "kernel", "best": 0, "selected": "kernel", "settings_enabled": true}
	if surface_id == "story":
		surface_snapshot = {"selected": selected, "act": act}
	elif surface_id == "patch":
		surface_snapshot = {
			"offers": [
				{"id": "splitshot", "title": "SPLITSHOT", "description": "+1 ANGLED PROJECTILE, -10% FIRE RATE", "effect": "KILLS DROP +1 MOTE", "cost_benefit": "COST // NONE   BENEFIT // EXTRA MOTE", "relation": "NO DIRECT INTERACTION", "build_impact": "BEFORE // NO PATCHES   AFTER // SPLITSHOT", "level": 0, "max": 2},
				{"id": "ring0", "title": "RING-0", "description": "REPRESS OVERCLOCK: DOUBLE WINDOW, LONG RECOVERY", "effect": "REPRESS OVERCLOCK", "cost_benefit": "COST // LONG RECOVERY   BENEFIT // DOUBLE WINDOW", "relation": "SYNERGY // KERNEL", "build_impact": "BEFORE // KERNEL   AFTER // RING-0", "level": 1, "max": 1},
				{"id": "system_restore", "title": "SYSTEM RESTORE", "description": "PURGE ALL ORBS, HEAL 1, 2S SHIELD", "effect": "PURGE FIELD + HEAL", "cost_benefit": "COST // NONE   BENEFIT // SURVIVAL", "relation": "NO DIRECT INTERACTION", "build_impact": "BEFORE // NO PATCHES   AFTER // RESTORE", "level": 0, "max": 1},
			],
			"active_ids": ["heavy"],
			"build": "KERNEL // CLEAN BOOT",
			"paused": true,
			"selected": selected,
		}
	elif surface_id == "combat_hud":
		surface_snapshot = {
			"hp": 10,
			"max_hp": 12,
			"meter": 78.0,
			"meter_max": 100.0,
			"dash_frac": 1.0,
			"dash_available": 1,
			"dash_max": 1,
			"wave": 7,
			"cycle": "CYCLE 07",
			"score": 54230,
			"combo": 12,
			"combo_frac": 0.72,
			"time": "TIME 02:13.4",
			"run": "SEED 3317210945781775166",
			"event": "ELITE: TRACE MINER",
			"patches": ["SP1", "R01", "SR1", "PC2"],
			"boss_name": "ELITE: TRACE MINER",
			"boss_frac": 0.72,
			"boss_split": false,
			"boss_phase": "PHASE 1",
			"damage_direction": "NORTH-EAST",
			"program_id": "kernel",
			"program_kind": "kernel",
			"ability_state": "OVERCLOCK READY",
		}
	surface.configure(surface_snapshot, script.context_for_viewport(viewport, touch, true, true, 1.0) if surface_id != "combat_hud" else Context.from_viewport(viewport, touch, true, true, 1.0))
	if surface_id == "story" and OS.get_environment("KP_VNEXT_CAPTURE_DETAIL") == "1" and viewport.x < 600.0:
		surface.set_focus_id("stage_%d" % selected)
		var open_event := InputEventKey.new()
		open_event.keycode = KEY_ENTER
		open_event.physical_keycode = KEY_ENTER
		open_event.pressed = true
		surface.handle_input(open_event)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var shot := image
	if image.get_width() != int(viewport.x) or image.get_height() != int(viewport.y):
		shot = image.get_region(Rect2i(Vector2i.ZERO, Vector2i(viewport)))
	var error := shot.save_png(output)
	print("CAPTURE_SAVED ", surface_id, " ", output, " ", shot.get_width(), "x", shot.get_height(), " error=", error)
	get_tree().quit(0 if error == OK else 1)

func _viewport_from_environment() -> Vector2:
	var raw := OS.get_environment("KP_VNEXT_CAPTURE_VIEWPORT")
	if raw.is_empty():
		return Vector2(1280.0, 720.0)
	var parts := raw.to_lower().split("x")
	if parts.size() != 2:
		return Vector2(1280.0, 720.0)
	var width := float(parts[0])
	var height := float(parts[1])
	return Vector2(width, height) if width > 0.0 and height > 0.0 else Vector2(1280.0, 720.0)

extends Node

const BootSurface = preload("res://src/ui/vnext/surfaces/boot_surface.gd")
const ProgramSurface = preload("res://src/ui/vnext/surfaces/program_surface.gd")
const BestiarySurface = preload("res://src/ui/vnext/surfaces/bestiary_surface.gd")
const AccessibilitySurface = preload("res://src/ui/vnext/surfaces/accessibility_surface.gd")
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
	var surface = script.new()
	surface.size = viewport
	add_child(surface)
	var touch := OS.get_environment("KP_VNEXT_CAPTURE_TOUCH") == "1"
	surface.configure({"program": "kernel", "best": 0, "selected": "kernel", "settings_enabled": true}, script.context_for_viewport(viewport, touch, true, true, 1.0))
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

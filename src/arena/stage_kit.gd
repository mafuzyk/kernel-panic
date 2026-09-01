extends RefCounted

## Arena stage/era visual kit: background dust, Windows and Temple stage
## dressing. Functions are moved verbatim from src/arena/arena.gd; Arena-owned
## state and non-moved calls are prefixed with `a.` (plan G5). Untyped owner
## reference avoids a preload cycle. No behavior changes.

var a


func _init(arena) -> void:
	a = arena

func _build_background() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a._bg_mat = ShaderMaterial.new()
	a._bg_mat.shader = load("res://shaders/bg_grid.gdshader")
	rect.material = a._bg_mat
	layer.add_child(rect)
	a.add_child(layer)
	a._dust = CPUParticles2D.new()
	a._dust.amount = 36
	a._dust.lifetime = 7.0
	a._dust.preprocess = 7.0
	a._dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	a._dust.emission_rect_extents = Vector2(700, 400)
	a._dust.gravity = Vector2.ZERO
	a._dust.initial_velocity_min = 6.0
	a._dust.initial_velocity_max = 22.0
	a._dust.scale_amount_min = 1.0
	a._dust.scale_amount_max = 2.4
	a._dust.color = Color(0.4, 0.55, 0.75, 0.22)
	a.add_child(a._dust)

func windows_stage_profile() -> Dictionary:
	if a._story_stage.is_empty():
		return {}
	return {"id": a._story_stage.get("id", ""), "path": a._story_stage.get("path", ""), "grid_style": a._story_stage.get("theme", {}).get("grid_style", "clean"), "crt": a._story_stage.get("theme", {}).get("crt", {})}

func _build_windows_visuals() -> void:
	if str(a._story_stage.get("act", "")) != "windows":
		return
	var theme: Dictionary = a._story_stage.get("theme", {})
	var style := str(theme.get("grid_style", "clean"))
	Sfx.set_music_variant(style)
	if style == "crt_heavy" or style == "crt_soft":
		a._crt_overlay = CrtOverlay.new()
		a.add_child(a._crt_overlay)
		a._crt_overlay.configure(theme.get("crt", {}))
	if bool(a._story_stage.get("watermark", false)):
		var watermark_layer := CanvasLayer.new()
		watermark_layer.layer = 76
		a._windows_watermark = Label.new()
		a._windows_watermark.text = "ACTIVATE WINDOWS // GO TO SETTINGS"
		a._windows_watermark.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
		a._windows_watermark.add_theme_font_size_override("font_size", 11)
		a._windows_watermark.add_theme_color_override("font_color", Color(0.2, 0.65, 0.85, 0.6))
		a._windows_watermark.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		a._windows_watermark.anchor_left = 1.0
		a._windows_watermark.anchor_right = 1.0
		a._windows_watermark.offset_left = -380.0
		a._windows_watermark.offset_right = -18.0
		a._windows_watermark.offset_top = 18.0
		a._windows_watermark.offset_bottom = 40.0
		a._windows_watermark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		watermark_layer.add_child(a._windows_watermark)
		a.add_child(watermark_layer)

func temple_stage_profile() -> Dictionary:
	if str(a._story_stage.get("act", "")) != "templeos":
		return {}
	return {"id": a._story_stage.get("id", ""), "path": a._story_stage.get("path", ""), "arena_size": a._story_stage.get("arena_size", Vector2.ZERO), "grid_style": a._story_stage.get("theme", {}).get("grid_style", "holy"), "crt": a._story_stage.get("theme", {}).get("crt", {})}

func _build_temple_visuals() -> void:
	if str(a._story_stage.get("act", "")) != "templeos":
		return
	a._temple_mode = true
	Sfx.set_music_variant("holy")
	a._crt_overlay = CrtOverlay.new()
	a.add_child(a._crt_overlay)
	a._crt_overlay.configure(a._story_stage.get("theme", {}).get("crt", {}))

func macos_stage_profile() -> Dictionary:
	if str(a._story_stage.get("act", "")) != "macos":
		return {}
	return {"id": a._story_stage.get("id", ""), "path": a._story_stage.get("path", ""), "profile": a._story_stage.get("profile", "classic"), "grid_style": a._story_stage.get("theme", {}).get("grid_style", "mac_classic"), "layered": bool(a._story_stage.get("theme", {}).get("layered", false))}

func _build_macos_visuals() -> void:
	if str(a._story_stage.get("act", "")) != "macos":
		return
	var overlay_script: Script = load("res://src/arena/macos_era_overlay.gd")
	if overlay_script == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 8
	var overlay: Control = overlay_script.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.configure(a._story_stage)
	layer.add_child(overlay)
	a.add_child(layer)

func background_corruption_for_wave(target_wave: int) -> float:
	return clampf(float(maxi(target_wave - 1, 0)) / 40.0, 0.0, 0.8)

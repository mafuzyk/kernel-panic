extends Node

## E5 probe: the renderer must keep identity/state structural while allowing
## finish-only work to disappear on mobile and when motion is reduced.

const Renderer = preload("res://src/ui/vnext/core/entity_renderer.gd")
const Glyphs = preload("res://src/ui/glyph_lib.gd")
const Quality = preload("res://src/ui/vnext/core/entity_quality.gd")
const SpriteRegistry = preload("res://src/ui/entity_sprite.gd")

class BenchCanvas:

	# Deliberately use a real CanvasItem draw callback instead of calling the
	# renderer from _ready; Godot only permits draw commands during this phase.
	extends Node2D

	var snapshots: Array[Dictionary] = []
	var quality: Dictionary = {}
	var cosmetic_time := 0.0
	var draw_count := 0
	var last_draw_us := 0

	func _draw() -> void:
		var started := Time.get_ticks_usec()
		for i in snapshots.size():
			var col := i % 5
			var row := i / 5
			var target := Rect2(Vector2(44.0 + col * 112.0, 44.0 + row * 112.0), Vector2(92.0, 92.0))
			Renderer.draw(self, snapshots[i], target, cosmetic_time, quality)
		last_draw_us = Time.get_ticks_usec() - started
		draw_count += 1

var _fails := 0

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PROBE_PASS ", message)
	else:
		_fails += 1
		print("PROBE_FAIL ", message)

func _run() -> void:
	_check(Quality != null, "entity quality contract loads")
	_check(not bool(SpriteRegistry.sprites_enabled()), "raster sprite registry remains disabled")
	if Quality == null:
		_finish()
		return

	var desktop: Dictionary = Renderer.quality_profile("desktop")
	var mobile: Dictionary = Renderer.quality_profile("mobile")
	var reduced: Dictionary = Renderer.quality_profile("desktop", true)
	var assist: Dictionary = Renderer.quality_profile("mobile", false, true, true, true)
	_check(str(desktop.get("tier", "")) == "desktop" and bool(desktop.get("finish", false)), "desktop quality keeps finish enabled")
	_check(str(mobile.get("tier", "")) == "mobile" and not bool(mobile.get("finish", true)), "mobile quality disables finish layer")
	_check(not bool(reduced.get("motion", true)) and bool(reduced.get("finish", false)), "reduced motion freezes phase without removing structure")
	_check(bool(assist.get("high_contrast", false)) and bool(assist.get("color_assist", false)) and bool(assist.get("grayscale", false)), "assist flags survive mobile normalization")
	_check(Quality.profile("unknown").get("tier", "") == "desktop", "unknown quality tier falls back to desktop")
	var malformed_quality: Dictionary = Quality.normalize({"tier": "mobile", "reduced_motion": "false", "high_contrast": "true", "color_assist": "off", "grayscale": "on"})
	_check(not bool(malformed_quality.get("reduced_motion", true)) and bool(malformed_quality.get("high_contrast", false)) and bool(malformed_quality.get("grayscale", false)), "malformed quality booleans normalize safely")
	var illustration_script: Script = load("res://src/ui/vnext/entity_illustration.gd")
	var illustration = illustration_script.new()
	illustration.set_quality_profile("mobile", true, true)
	var illustration_quality: Dictionary = illustration.visual_snapshot().get("quality", {})
	_check(str(illustration_quality.get("tier", "")) == "mobile" and bool(illustration_quality.get("reduced_motion", false)) and bool(illustration_quality.get("high_contrast", false)), "public entity illustration applies quality profile")
	illustration.free()

	var identity_snapshot := {"kind": "lancer", "visual_state": "attack", "facing": Vector2.RIGHT, "elite": true}
	var normal_plan: Dictionary = Renderer.finish_plan(desktop, 2.5)
	var mobile_plan: Dictionary = Renderer.finish_plan(mobile, 2.5)
	var reduced_plan: Dictionary = Renderer.finish_plan(reduced, 2.5)
	_check(bool(normal_plan.get("enabled", false)) and int(normal_plan.get("segments", 0)) >= 12, "desktop finish plan has bounded finish geometry")
	_check(not bool(mobile_plan.get("enabled", true)) and int(mobile_plan.get("segments", -1)) == 0, "mobile finish plan is empty")
	_check(float(reduced_plan.get("phase", -1.0)) == 0.0, "reduced motion finish phase is frozen")
	_check(Renderer.state_signature(identity_snapshot) == "forward-chevrons", "structural attack marker remains defined")
	_check(Renderer.draw_extent_factor(identity_snapshot) > 0.0, "structural extent remains measurable")

	var rng_before := Game.rng.state
	var score_before := Game.score
	var position := Vector2(120.0, 120.0)
	var bench := BenchCanvas.new()
	bench.snapshots = _stress_snapshots()
	bench.quality = desktop
	bench.cosmetic_time = 1.75
	add_child(bench)
	await _until(func() -> bool: return bench.draw_count > 0, 2.0)
	var desktop_samples: Array[int] = []
	for i in 4:
		bench.cosmetic_time = 1.75 + i * 0.1
		bench.queue_redraw()
		await _until(func() -> bool: return bench.draw_count >= i + 2, 2.0)
		desktop_samples.append(bench.last_draw_us)
	bench.quality = mobile
	for i in 4:
		bench.cosmetic_time = 1.75 + i * 0.1
		bench.queue_redraw()
		await _until(func() -> bool: return bench.draw_count >= i + 6, 2.0)
	var mobile_us := bench.last_draw_us
	_check(bench.snapshots.size() == 10, "stress set matches the current ten-entity maximum")
	_check(bench.draw_count >= 9 and desktop_samples.all(func(value: int) -> bool: return value >= 0) and mobile_us >= 0, "desktop and mobile draw timings are measured")
	bench.quality = reduced
	bench.queue_redraw()
	var reduced_ready := await _until(func() -> bool: return bench.draw_count >= 10, 2.0)
	_check(reduced_ready and bench.draw_count >= 10, "reduced-motion profile reaches the real draw callback")
	_check(Game.rng.state == rng_before and Game.score == score_before and position == Vector2(120.0, 120.0), "rendering does not mutate gameplay state")
	print("PROBE_INFO desktop_draw_us=%s mobile_draw_us=%d" % [str(desktop_samples), mobile_us])
	bench.free()
	_finish()

func _stress_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var kinds: Array = Glyphs.glyph_kinds()
	for i in 10:
		result.append({
			"kind": str(kinds[i % kinds.size()]),
			"visual_state": ["idle", "attack", "hit", "elite"][i % 4],
			"facing": Vector2.from_angle(float(i) * TAU / 10.0),
			"elite": i % 3 == 0,
		})
	return result

func _until(condition: Callable, timeout_s: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await get_tree().process_frame
	return bool(condition.call())

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

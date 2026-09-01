extends Node

## M5 integration gate for the macOS history slice. This is deliberately
## broader than the story-catalog probe: it verifies that authored Mac data is
## consumable by the story surface, bestiary, era dressing, and entity adapter
## without changing the simulation contract.

const StorySurfaceScript = preload("res://src/ui/vnext/surfaces/story_surface.gd")
const OverlayScript = preload("res://src/arena/macos_era_overlay.gd")
const AdapterScript = preload("res://src/ui/vnext/core/entity_presentation_adapter.gd")
const RendererScript = preload("res://src/ui/vnext/core/entity_renderer.gd")
const ProfilesScript = preload("res://src/story/acts/macos_profiles.gd")

var _fails := 0

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PROBE_PASS ", message)
	else:
		_fails += 1
		print("PROBE_FAIL ", message)

func _find_mac_stage_indices() -> Array[int]:
	var result: Array[int] = []
	for index in Game.story_stage_count():
		if str(Game.story_stage_def(index).get("act", "")) == "macos":
			result.append(index)
	return result

func _all_fit(report: Array) -> bool:
	return report.all(func(item: Dictionary) -> bool: return bool(item.get("fits", false)))

func _run() -> void:
	var indices := _find_mac_stage_indices()
	_check(indices.size() == 4, "live story catalog exposes four macOS stages")
	_check(ProfilesScript.ids().size() == 4, "four era profiles have stable IDs")
	_check(ProfilesScript.theme("classic").has("grid_style") and ProfilesScript.theme("modern").has("crt"), "era profiles expose code-drawn theme contracts")

	var catalog: Script = load("res://src/data/content_catalog.gd")
	var map: Dictionary = catalog.get("BESTIARY_MAP") if catalog != null else {}
	var entries: Array = catalog.get("BESTIARY_ENTRIES") if catalog != null else []
	var permission_entry: Dictionary = entries.filter(func(item: Dictionary) -> bool: return str(item.get("id", "")) == "permission_root")[0] if not entries.filter(func(item: Dictionary) -> bool: return str(item.get("id", "")) == "permission_root").is_empty() else {}
	_check(str(map.get("PERMISSION ROOT", "")) == "permission_root", "climax boss maps to a stable bestiary identity")
	_check(str(permission_entry.get("name", "")) == "PERMISSION ROOT" and str(permission_entry.get("desc", "")).length() >= 40, "climax bestiary entry includes readable counterplay copy")

	var story_surface: Control = StorySurfaceScript.new()
	add_child(story_surface)
	await get_tree().process_frame
	for viewport_size in [Vector2(1366.0, 768.0), Vector2(720.0, 720.0), Vector2(432.0, 720.0), Vector2(390.0, 844.0)]:
		story_surface.size = viewport_size
		var context: RefCounted = StorySurfaceScript.context_for_viewport(viewport_size, viewport_size.x <= 432.0)
		if not indices.is_empty():
			story_surface.set("_act", "macos")
			story_surface.configure({"selected": indices[0]}, context)
			await get_tree().process_frame
			_check(_all_fit(story_surface.text_overflow_report()), "macOS story detail fits at %.0fx%.0f" % [viewport_size.x, viewport_size.y])
			var regions: Dictionary = story_surface.layout_snapshot().get("regions", {})
			_check(regions.get("safe", Rect2()).encloses(regions.get("header", Rect2())) and regions.get("safe", Rect2()).encloses(regions.get("tabs", Rect2())), "macOS story chrome remains inside safe area at %.0fx%.0f" % [viewport_size.x, viewport_size.y])
		story_surface.set("_narrow_detail", false)
		story_surface.configure({"selected": indices[0]}, context)
		await get_tree().process_frame
		_check(_all_fit(story_surface.text_overflow_report()), "macOS story list state fits at %.0fx%.0f" % [viewport_size.x, viewport_size.y])
	story_surface.queue_free()

	var overlay: Control = OverlayScript.new()
	overlay.size = Vector2(1366.0, 768.0)
	add_child(overlay)
	if not indices.is_empty():
		var stage := Game.story_stage_def(indices[0])
		overlay.configure(stage)
		_check(str(overlay.get("_stage").get("act", "")) == "macos", "era overlay accepts authored macOS stage data")
		_check(str(overlay.get("_stage").get("theme", {}).get("grid_style", "")) == "mac_classic", "era overlay receives the selected profile rather than host OS state")
	overlay.queue_redraw()
	await get_tree().process_frame
	overlay.queue_free()

	var snapshot := AdapterScript.from_enemy_fixture({
		"display_name": "ROOT",
		"boss_title": "PERMISSION ROOT",
		"boss_variant_id": "permission_root",
		"permission_telegraph": {"active": true, "remaining": 0.9, "direction": Vector2.RIGHT, "label": "PERMISSION CHECK"},
		"visual_state": "attack",
		"facing": Vector2.RIGHT,
		"hp": 10,
		"max_hp": 10,
	})
	var nested: Dictionary = snapshot.get("nested", {})
	_check(str(nested.get("boss_variant_id", "")) == "permission_root", "entity adapter preserves the named boss variant")
	_check(bool((nested.get("permission_telegraph", {}) as Dictionary).get("active", false)), "entity adapter preserves the readable permission telegraph")
	for viewport_size in [Vector2(96.0, 96.0), Vector2(48.0, 72.0), Vector2(24.0, 24.0)]:
		var target := Rect2(Vector2.ZERO, viewport_size)
		_check(target.encloses(RendererScript.draw_bounds(snapshot, target)), "climax code-drawn marker fits its %.0fx%.0f allocation" % [viewport_size.x, viewport_size.y])
	_check(RendererScript.state_signature(snapshot) == "forward-chevrons", "climax attack state has a non-color renderer marker")

	_finish()

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

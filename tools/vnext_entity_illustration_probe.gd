extends Node

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
	var illustration_script: Script = load("res://src/ui/vnext/entity_illustration.gd")
	var glyph_script: Script = load("res://src/ui/glyph_lib.gd")
	_check(illustration_script != null and glyph_script != null, "vnext entity illustration and glyph library load")
	if illustration_script == null or glyph_script == null:
		_finish()
		return
	var illustration = illustration_script.new()
	_check(illustration.has_method("configure_entity") and illustration.has_method("visual_rect") and illustration.has_method("visual_snapshot"), "entity illustration exposes stateful code-drawn APIs")
	_check(illustration.has_method("text_overflow_report"), "entity illustration exposes an overflow contract")
	illustration.size = Vector2(432, 720)
	add_child(illustration)
	illustration.call("configure_entity", "god", "ready", "GOD")
	illustration.call("set_motion_phase", 0.75)
	await get_tree().process_frame
	_check(illustration.is_inside_tree(), "entity illustration draws as a live control")
	var kinds: Array = glyph_script.call("glyph_kinds")
	for kind in ["drone", "lancer", "oom", "god", "kernel", "rootlet"]:
		_check(kind in kinds, "illustration example kind exists in GlyphLib: %s" % kind)
		illustration.call("configure_entity", kind, "danger", "EXAMPLE")
		for viewport in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
			var rect: Rect2 = illustration.call("visual_rect", viewport)
			_check(Rect2(Vector2.ZERO, viewport).encloses(rect), "%s illustration stays inside %dx%d" % [kind, int(viewport.x), int(viewport.y)])
			var snapshot: Dictionary = illustration.call("visual_snapshot")
			_check(str(snapshot.get("kind", "")) == kind and str(snapshot.get("state", "")) == "danger", "%s snapshot carries identity and threat state" % kind)
			_check(float(snapshot.get("glyph_extent", 0.0)) >= 0.9, "%s snapshot publishes a usable silhouette extent" % kind)
	illustration.call("configure_entity", "rootlet", "locked", "ROOTLET")
	var locked: Dictionary = illustration.call("visual_snapshot")
	_check(str(locked.get("state_label", "")) == "LOCKED" and str(locked.get("state_pattern", "")) == "hatch", "locked entity publishes non-color state semantics")
	var overflow: Array = illustration.call("text_overflow_report")
	_check(not overflow.is_empty() and overflow.all(func(entry: Dictionary) -> bool: return bool(entry.get("fits", false))), "entity illustration text contract fits its example labels")
	illustration.call("configure_entity", "unknown", "unknown", "")
	var fallback: Dictionary = illustration.call("visual_snapshot")
	_check(str(fallback.get("kind", "")) == "drone" and str(fallback.get("state", "")) == "idle", "unknown entity inputs fall back to a safe drawable state")
	illustration.queue_free()
	await get_tree().process_frame
	_finish()

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

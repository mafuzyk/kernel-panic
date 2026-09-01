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
	var tokens: Script = load("res://src/ui/vnext/ui_tokens.gd")
	var primitives: Script = load("res://src/ui/vnext/ui_primitives.gd")
	_check(tokens != null and primitives != null, "vnext token and primitive scripts load")
	if tokens == null or primitives == null:
		_finish()
		return
	_check(tokens.has_method("safe_rect") and tokens.has_method("frame_points") and tokens.has_method("role_color"), "vnext tokens expose viewport geometry and semantic color APIs")
	var primitive_api = primitives.new()
	_check(primitive_api.has_method("frame_rect") and primitive_api.has_method("semantic_snapshot"), "vnext primitive exposes shared frame geometry and semantic snapshot")
	primitive_api.free()
	for viewport in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
		var safe: Rect2 = tokens.call("safe_rect", viewport)
		_check(Rect2(Vector2.ZERO, viewport).encloses(safe), "safe area stays inside %dx%d" % [int(viewport.x), int(viewport.y)])
		var points: PackedVector2Array = tokens.call("frame_points", safe, 18.0)
		_check(points.size() == 8, "angular frame keeps eight intentional corners at %dx%d" % [int(viewport.x), int(viewport.y)])
		var primitive = primitives.new()
		primitive.size = viewport
		primitive.call("configure_surface", "structure", "ready", "BOOT", 0.75)
		var frame: Rect2 = primitive.call("frame_rect", viewport)
		var snapshot: Dictionary = primitive.call("semantic_snapshot")
		_check(Rect2(Vector2.ZERO, viewport).encloses(frame), "primitive frame stays inside %dx%d" % [int(viewport.x), int(viewport.y)])
		_check(str(snapshot.get("state", "")) == "ready" and str(snapshot.get("label", "")) == "BOOT", "primitive snapshot preserves semantic state at %dx%d" % [int(viewport.x), int(viewport.y)])
		primitive.free()
	_check(tokens.call("role_color", "structure") != tokens.call("role_color", "danger"), "semantic roles keep structure and danger distinguishable")
	_check(str(tokens.call("state_label", "locked")) == "LOCKED", "state labels carry a non-color lock signal")
	_finish()

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

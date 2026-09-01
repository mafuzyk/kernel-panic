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
	var descriptor_script: Script = load("res://src/ui/vnext/core/entity_descriptor.gd")
	var renderer_script: Script = load("res://src/ui/vnext/core/entity_renderer.gd")
	var adapter_script: Script = load("res://src/ui/vnext/core/entity_presentation_adapter.gd")
	_check(illustration_script != null and glyph_script != null, "vnext entity illustration and glyph library load")
	_check(descriptor_script != null and renderer_script != null and adapter_script != null, "entity presentation foundation scripts load")
	if descriptor_script != null and renderer_script != null and adapter_script != null:
		var malformed: Dictionary = {"kind": "kernel", "visual_state": "attack", "facing": Vector2(-1, 0), "hp_fraction": 0.35, "elite": true, "era_accent": Color("ff7b9c"), "loot_count": 2, "feedback_count": 3, "nested": {"markers": ["aim", {"value": 7}]}, "label": "loc.entity.kernel.name"}
		var normalized: Dictionary = descriptor_script.call("normalize", malformed)
		_check(str(normalized.get("kind", "")) == "kernel" and str(normalized.get("visual_state", "")) == "attack", "descriptor preserves known identity and visual state")
		_check(normalized.get("facing", Vector2.ZERO) == Vector2(-1, 0) and is_equal_approx(float(normalized.get("hp_fraction", -1.0)), 0.35), "descriptor preserves orientation and normalized hp")
		_check(bool(normalized.get("elite", false)) and int(normalized.get("loot_count", -1)) == 2 and int(normalized.get("feedback_count", -1)) == 3, "descriptor preserves elite and feedback counts")
		_check(str(normalized.get("visible_label", "")) == "", "descriptor never exposes localization keys as visible copy")
		var nested: Dictionary = normalized.get("nested", {})
		malformed["nested"]["markers"][0] = "mutated"
		_check(str(nested["markers"][0]) == "aim", "descriptor deep-copies nested snapshot data")
		var safe: Dictionary = descriptor_script.call("normalize", {"kind": "missing", "facing": "bad", "hp_fraction": "bad", "loot_count": -4})
		_check(str(safe.get("kind", "")) == "drone" and safe.get("facing", Vector2.ZERO) == Vector2.RIGHT and is_equal_approx(float(safe.get("hp_fraction", -1.0)), 1.0), "malformed descriptor fields use safe defaults")
		var extent_ok := renderer_script.has_method("draw_extent_factor")
		_check(extent_ok, "renderer publishes the full marker-aware extent contract")
		for size in [24.0, 48.0, 96.0, 160.0]:
			var factor := float(renderer_script.call("draw_extent_factor", malformed)) if extent_ok else 1.0
			var glyph_extent := float(glyph_script.call("glyph_extent", "kernel"))
			for facing in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
				malformed["facing"] = facing
				var target := Rect2(Vector2.ZERO, Vector2(size, size))
				var fit: Rect2 = renderer_script.call("fit_rect", malformed, target)
				var bounds: Rect2 = renderer_script.call("draw_bounds", malformed, target)
				_check(target.encloses(fit) and target.encloses(bounds) and bounds.encloses(fit) and is_equal_approx(bounds.size.x, fit.size.x * factor), "extent contains %dpx %s silhouette without clipping" % [int(size), str(facing)])
			if extent_ok:
				var extent_target := Rect2(Vector2.ZERO, Vector2(size, size))
				var extent_fit: Rect2 = renderer_script.call("fit_rect", malformed, extent_target)
				var extent_bounds: Rect2 = renderer_script.call("draw_bounds", malformed, extent_target)
				var extent_radius := float(renderer_script.call("draw_radius", malformed, extent_target))
				_check(factor >= 1.38 and is_equal_approx(extent_bounds.size.x, extent_fit.size.x * factor) and extent_radius * glyph_extent * 2.0 <= extent_fit.size.x + 0.01 and extent_radius * factor * 2.0 <= extent_bounds.size.x + 0.01, "draw radius is bounded by the published full extent at %dpx" % int(size))
			for state in ["idle", "attack", "hit", "elite", "death"]:
				malformed["visual_state"] = state
				var state_fit: Rect2 = renderer_script.call("fit_rect", malformed, Rect2(Vector2.ZERO, Vector2(96, 96)))
				_check(state_fit.size.x > 0.0 and state_fit.size.y > 0.0, "state channel has valid fit: %s" % state)
		var render_host = illustration_script.new()
		render_host.size = Vector2(160, 160)
		render_host.call("configure_entity", "kernel", "attack", "")
		add_child(render_host)
		var before := malformed.duplicate(true)
		render_host.queue_redraw()
		await get_tree().process_frame
		_check(malformed == before, "rendering leaves descriptor fixture unchanged")
		render_host.queue_free()
		var player_fixture := {"prog": {"kind": "kernel"}, "aim": Vector2.UP, "hp": 4, "max_hp": 8, "overclock_active": true, "dash_available": 1}
		var enemy_fixture := {"display_name": "DRONE", "hp": 1, "max_hp": 2, "global_rotation": PI, "elite": true, "mote_count": 2, "era_accent": Color("42e8ff"), "hit_flash": 0.0}
		var program_snapshot: Dictionary = adapter_script.call("from_player_fixture", player_fixture)
		var enemy_snapshot: Dictionary = adapter_script.call("from_enemy_fixture", enemy_fixture)
		var adapter_source := FileAccess.get_file_as_string("res://src/ui/vnext/core/entity_presentation_adapter.gd")
		_check(adapter_source.contains("static func from_player(") and adapter_source.contains("static func from_enemy("), "production player and enemy adapter entry points exist")
		_check(str(program_snapshot.get("kind", "")) == "kernel" and str(program_snapshot.get("visual_state", "")) == "elite", "one existing player program reaches the descriptor adapter")
		_check(str(enemy_snapshot.get("kind", "")) == "drone" and bool(enemy_snapshot.get("elite", false)), "one existing enemy reaches the descriptor adapter")
		_check(player_fixture["hp"] == 4 and enemy_fixture["hp"] == 1, "adapter fixtures retain gameplay-like fields")
		var player_script: Script = load("res://src/player/player.gd")
		var enemy_script: Script = load("res://src/enemies/drone.gd")
		var real_player = player_script.new() if player_script != null else null
		var real_enemy = enemy_script.new() if enemy_script != null else null
		if real_player != null:
			real_player.prog = {"kind": "kernel"}
			real_player.aim = Vector2.UP
			real_player.hp = 4
			real_player.max_hp = 8
			real_player.overclock_active = true
			real_player.dash_available = 1
		var real_program_snapshot: Dictionary = adapter_script.call("from_player", real_player) if real_player != null else {}
		if real_enemy != null:
			real_enemy.hp = 1
			real_enemy.max_hp = 2
			real_enemy.rotation = PI
			real_enemy.elite = true
			real_enemy.mote_count = 2
		var real_enemy_snapshot: Dictionary = adapter_script.call("from_enemy", real_enemy) if real_enemy != null else {}
		_check(str(real_program_snapshot.get("kind", "")) == "kernel" and str(real_program_snapshot.get("visual_state", "")) == "elite", "real Player object reaches the descriptor adapter")
		_check(str(real_enemy_snapshot.get("kind", "")) == "drone" and bool(real_enemy_snapshot.get("elite", false)), "real DroneEnemy object reaches the descriptor adapter")
		if real_player != null:
			real_player.free()
		if real_enemy != null:
			real_enemy.free()
		var quality_a := {"grayscale": true, "color_assist": false, "reduced_motion": true}
		var quality_b := {"reduced_motion": true, "color_assist": false, "grayscale": true}
		_check(renderer_script.call("render_key", malformed, 1.25, quality_a) == renderer_script.call("render_key", malformed, 1.25, quality_b), "semantically equal quality dictionaries produce the same render key")
		_check(renderer_script.has_method("orientation_angle") and not is_equal_approx(float(renderer_script.call("orientation_angle", {"facing": Vector2.RIGHT})), float(renderer_script.call("orientation_angle", {"facing": Vector2.DOWN}))), "facing changes the glyph orientation transform")
		var accent_color: Color = renderer_script.call("color_for", {"kind": "kernel", "era_accent": Color("ff0000")}, {}) if renderer_script.has_method("color_for") else Color(0, 0, 0, 0)
		var base_color: Color = renderer_script.call("color_for", {"kind": "kernel"}, {}) if renderer_script.has_method("color_for") else Color(0, 0, 0, 0)
		_check(renderer_script.has_method("color_for") and accent_color != base_color, "era accent participates in resolved render color")
		var renderer_source := FileAccess.get_file_as_string("res://src/ui/vnext/core/entity_renderer.gd")
		_check(renderer_source.contains("draw_set_transform"), "renderer applies orientation to the identity glyph")
		_check(not renderer_source.contains("Game") and not renderer_source.contains("Sfx") and not renderer_source.contains("Arena") and not renderer_source.contains("rand"), "renderer has no gameplay, audio or random side effects")
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
	_check(illustration.has_method("set_quality") and illustration.has_method("set_facing"), "public illustration exposes quality and facing controls")
	if illustration.has_method("set_quality"):
		illustration.call("set_quality", {"grayscale": true, "color_assist": true, "reduced_motion": true})
	await get_tree().process_frame
	_check(illustration.is_inside_tree(), "entity illustration draws as a live control")
	var public_rect: Rect2 = illustration.call("visual_rect", Vector2(432, 720))
	var public_snapshot := {"kind": "god", "visual_state": "idle", "facing": Vector2.RIGHT}
	var public_radius := float(renderer_script.call("draw_radius", public_snapshot, public_rect))
	_check(is_equal_approx(float(illustration.call("glyph_radius", public_rect)), public_radius), "public glyph radius uses the shared renderer contract")
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

extends Node

var fails := 0
var _finished := false

func _check(ok: bool, label: String) -> void:
	if ok:
		print("PROBE_PASS ", label)
	else:
		fails += 1
		print("PROBE_FAIL ", label)

func _ready() -> void:
	_watchdog.call_deferred()
	var sfx = get_node_or_null("/root/Sfx")
	_check(sfx != null, "Sfx autoload exists")
	if sfx == null:
		_finish()
		return
	_check(sfx.has_method("accessibility_defaults"), "Sfx exposes accessibility_defaults")
	_check(sfx.has_method("apply_accessibility_profile"), "Sfx exposes profile apply")
	_check(sfx.has_method("reset_accessibility_profile"), "Sfx exposes profile reset")
	_check(sfx.has_method("accessibility_snapshot"), "Sfx exposes versioned accessibility snapshot")
	var defaults: Dictionary = sfx.accessibility_defaults() if sfx.has_method("accessibility_defaults") else {}
	_check(defaults.get("color_assist", null) == false, "defaults include color assist")
	_check(defaults.get("haptics_enabled", null) == true, "defaults include haptics")
	_check(defaults.get("shake_level", null) == 2, "defaults include full shake")
	_check(defaults.get("touch_scale", null) == 1.0, "defaults include normal touch size")
	_check(defaults.get("reduced_motion", null) == false and defaults.get("reduced_flashes", null) == false and defaults.get("left_handed_touch", null) == false, "defaults include reduced motion, flashes and handedness")
	var snap: Dictionary = sfx.accessibility_snapshot() if sfx.has_method("accessibility_snapshot") else {}
	_check(int(snap.get("schema_version", 0)) >= 2, "snapshot is versioned profile schema")
	_check(snap.get("supported", {}).has("native_screen_reader") and not bool(snap["supported"]["native_screen_reader"]), "unsupported assistive tech is explicit")
	_check(snap.get("supported", {}).has("text_scale") and not bool(snap["supported"]["text_scale"]), "unsupported text scaling is explicit")
	_check(snap.get("supported", {}).has("high_contrast") and not bool(snap["supported"]["high_contrast"]), "unsupported high contrast is explicit")
	var fixture := ConfigFile.new()
	fixture.set_value("progress", "u5_probe_marker", "preserve-me")
	fixture.set_value("progress", "u5_existing_value", 4242)
	fixture.set_value("feel", "u5_unrelated_setting", "keep-me")
	fixture.set_value("audio", "u5_unrelated_setting", "also-keep-me")
	_check(fixture.save(sfx.SAVE_PATH) == OK, "probe creates unrelated save fixture")
	var applied: Dictionary = sfx.apply_accessibility_profile({"color_assist": true, "haptics_enabled": false, "shake_level": 0, "touch_scale": 0.85, "reduced_motion": true, "reduced_flashes": true, "left_handed_touch": true})
	_check(applied == {"color_assist": true, "haptics_enabled": false, "shake_level": 0, "touch_scale": 0.85, "reduced_motion": true, "reduced_flashes": true, "left_handed_touch": true}, "profile applies all seven live fields")
	sfx.reload_settings()
	var reloaded: Dictionary = sfx.accessibility_snapshot()["profile"]
	_check(reloaded == applied, "profile persists and reloads through Sfx helper")
	_check((fixture.load(sfx.SAVE_PATH) == OK) and fixture.get_value("progress", "u5_probe_marker", "") == "preserve-me" and fixture.get_value("progress", "u5_existing_value", 0) == 4242 and fixture.get_value("feel", "u5_unrelated_setting", "") == "keep-me" and fixture.get_value("audio", "u5_unrelated_setting", "") == "also-keep-me", "profile save preserves unrelated save sections and keys")
	_check(sfx.reset_accessibility_profile(), "profile reset persists")
	sfx.reload_settings()
	_check(sfx.accessibility_snapshot()["profile"] == defaults, "profile reset restores only profile defaults")
	var malformed_fixture := ConfigFile.new()
	malformed_fixture.set_value("progress", "u5_probe_marker", "preserve-me")
	malformed_fixture.set_value("feel", "color_assist", "not-a-boolean")
	malformed_fixture.set_value("feel", "haptics", "not-a-boolean")
	malformed_fixture.set_value("feel", "shake", "not-a-number")
	malformed_fixture.set_value("feel", "touch_scale", 999.0)
	_check(malformed_fixture.save(sfx.SAVE_PATH) == OK, "probe writes malformed profile fixture")
	sfx.reload_settings()
	var loaded_profile: Dictionary = sfx.accessibility_snapshot()["profile"]
	_check(loaded_profile.get("color_assist") == false and loaded_profile.get("haptics_enabled") == true and loaded_profile.get("shake_level") == 2 and loaded_profile.get("touch_scale") == 1.2 and loaded_profile.get("reduced_motion") == false and loaded_profile.get("reduced_flashes") == false and loaded_profile.get("left_handed_touch") == false, "malformed profile values normalize during disk load")
	_check(sfx.reset_accessibility_profile(), "malformed fixture is repaired through reset")
	sfx.reload_settings()
	_check(sfx.accessibility_snapshot()["profile"] == defaults, "repaired malformed profile reloads as defaults")
	if sfx.has_method("apply_accessibility_profile"):
		var normalized: Dictionary = sfx.apply_accessibility_profile({"color_assist": "yes", "haptics_enabled": 0, "shake_level": 99, "touch_scale": 9.0}, false)
		_check(normalized.get("color_assist") == true and normalized.get("haptics_enabled") == false, "malformed booleans normalize")
		_check(normalized.get("shake_level") == 2 and normalized.get("touch_scale") == 1.2, "malformed numeric values clamp")
		_check(normalized.get("reduced_motion") == false and normalized.get("reduced_flashes") == false and normalized.get("left_handed_touch") == false, "malformed accessibility booleans use safe defaults")
	_check(sfx.apply_accessibility_profile({"shake_level": "unknown"}, false).get("shake_level") == 2, "unknown enum safely falls back")
	var stable_profile: Dictionary = sfx.accessibility_snapshot()["profile"]
	sfx.set("_settings_path_override", "res://")
	sfx.apply_accessibility_profile({"color_assist": not bool(stable_profile["color_assist"])})
	_check(not bool(sfx.get("last_accessibility_persisted")) and sfx.accessibility_snapshot()["profile"] == stable_profile, "failed profile save rolls back in-memory values")
	sfx.set("_settings_path_override", "")
	sfx.reload_settings()
	var menu_scene: PackedScene = load("res://src/ui/menu.tscn")
	_check(menu_scene != null, "menu scene loads")
	if menu_scene == null:
		_finish()
		return
	var menu := menu_scene.instantiate()
	add_child(menu)
	await get_tree().process_frame
	var surface = menu.get("_vnext_surface")
	_check(surface != null and is_instance_valid(surface), "settings opt-in reaches vnext boot route")
	if surface == null or not is_instance_valid(surface):
		_finish()
		return
	_check(surface.get_node_or_null("SettingsAction") is Button, "boot exposes settings action")
	surface.set_focus_id("settings")
	_check(surface.handle_input(_key(KEY_ENTER)), "settings route is dispatched through boot input")
	await get_tree().process_frame
	surface = menu.get("_vnext_surface")
	_check(surface.get_script().resource_path.ends_with("accessibility_surface.gd"), "surface is dedicated accessibility route")
	_check(surface.has_method("layout_snapshot") and surface.has_method("action_regions") and surface.has_method("semantic_snapshot") and surface.has_method("text_overflow_report") and surface.has_method("handle_input"), "surface exposes deterministic contract")
	var regions: Dictionary = surface.action_regions()
	for action_id in ["color_assist", "haptics_enabled", "shake_level", "touch_scale", "reduced_motion", "reduced_flashes", "left_handed_touch", "offensive_music", "defensive_music", "reset_accessibility", "back"]:
		_check(regions.has(action_id), "surface exposes real control " + action_id)
		if regions.has(action_id):
			_check((regions[action_id]["rect"] as Rect2).size.x >= 44.0 and (regions[action_id]["rect"] as Rect2).size.y >= 44.0, "control target meets minimum " + action_id)
	_check(not regions.has("text_scale") and not regions.has("high_contrast") and not regions.has("screen_reader"), "unsupported features are not inert controls")
	sfx.set("_settings_path_override", "res://")
	surface.set_focus_id("color_assist")
	var failed_status_count := int(surface.activation_count)
	_check(surface.handle_input(_key(KEY_ENTER)), "failed save control dispatches through input")
	_check(int(surface.activation_count) == failed_status_count + 1 and str(surface.semantic_snapshot().get("status", "")).contains("PREVIOUS VALUES RESTORED"), "failed save status describes rollback")
	sfx.set("_settings_path_override", "")
	sfx.reload_settings()
	var reset_before := int(surface.activation_count)
	surface.set_focus_id("reset_accessibility")
	_check(surface.handle_input(_key(KEY_ENTER)), "reset activation is dispatched through input")
	_check(int(surface.activation_count) == reset_before + 1, "first reset activation is observable")
	_check(bool(surface.semantic_snapshot().get("reset_armed", false)) and not bool(surface.semantic_snapshot().get("reset_confirmed", false)), "first reset activation arms but does not reset")
	_check(surface.handle_input(_key(KEY_ENTER)), "reset confirmation is dispatched through input")
	_check(bool(surface.semantic_snapshot().get("reset_confirmed", false)) and not bool(surface.semantic_snapshot().get("reset_armed", false)), "second reset activation confirms")
	var semantic: Dictionary = surface.semantic_snapshot()
	var gui_actions: Array[String] = []
	surface.action_requested.connect(func(action_id: String, _payload: Dictionary) -> void: gui_actions.append(action_id))
	for action_id in ["color_assist", "haptics_enabled", "shake_level", "touch_scale", "reduced_motion", "reduced_flashes", "left_handed_touch", "offensive_music", "defensive_music"]:
		surface.set_focus_id(action_id)
		get_viewport().push_input(_key(KEY_ENTER))
		get_viewport().push_input(_key(KEY_ENTER, false))
		await get_tree().process_frame
	print("PROBE_INFO gui_actions=%s" % str(gui_actions))
	_check(gui_actions.size() == 9 and gui_actions == ["color_assist", "haptics_enabled", "shake_level", "touch_scale", "reduced_motion", "reduced_flashes", "left_handed_touch", "offensive_music", "defensive_music"], "nine controls dispatch through GUI once each")
	semantic = surface.semantic_snapshot()
	_check(str(semantic.get("states", {}).get("color_assist", "")).contains("ON") or str(semantic.get("states", {}).get("color_assist", "")).contains("OFF"), "state is redundant semantic text")
	_check(surface.text_overflow_report().all(func(item: Dictionary) -> bool: return bool(item.get("fits", false))), "accessibility labels fit")
	for viewport in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720), Vector2(390, 844)]:
		menu.size = viewport
		menu._configure_vnext_surface(viewport)
		await get_tree().process_frame
		var report: Array = surface.text_overflow_report()
		_check(report.all(func(item: Dictionary) -> bool: return bool(item.get("fits", false))), "labels fit at " + str(viewport))
		var current_regions: Dictionary = surface.action_regions()
		_check(_regions_do_not_overlap(current_regions), "regions do not overlap at " + str(viewport))
	_check(surface.handle_input(_key(KEY_ESCAPE)), "escape returns from accessibility")
	await get_tree().process_frame
	var boot = menu.get("_vnext_surface")
	_check(boot != null and boot.get_node_or_null("SettingsAction") is Button, "escape returns to boot route")
	_finish()

func _regions_do_not_overlap(regions: Dictionary) -> bool:
	var ids := regions.keys()
	for i in ids.size():
		var left := regions[ids[i]].get("rect", Rect2()) as Rect2
		for j in range(i + 1, ids.size()):
			var right := regions[ids[j]].get("rect", Rect2()) as Rect2
			if left.intersects(right):
				return false
	return true

func _key(code: int, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	return event

func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("PROBE_DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _watchdog() -> void:
	await get_tree().create_timer(8.0, true, false, true).timeout
	if _finished:
		return
	print("PROBE_FAIL watchdog timeout")
	get_tree().quit(2)

extends Node

## G7 red/green probe for desktop-only patch music layers.
## The probe starts with source-contract checks so the pre-feature run is an
## honest failure, then exercises Sfx, Game and the accessibility surface.

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
	var sfx_source := FileAccess.get_file_as_string("res://src/autoload/sfx.gd")
	var game_source := FileAccess.get_file_as_string("res://src/autoload/game.gd")
	var menu_source := FileAccess.get_file_as_string("res://src/ui/menu_settings_kit.gd")
	var access_source := FileAccess.get_file_as_string("res://src/ui/vnext/surfaces/accessibility_surface.gd")
	var catalog_source := FileAccess.get_file_as_string("res://src/data/content_catalog.gd")
	_check(sfx_source.contains("PATCH_MUSIC_CROSSFADE_SECONDS"), "Sfx declares a patch-layer crossfade contract")
	_check(sfx_source.contains("patch_music_supported") and sfx_source.contains("set_patch_layers"), "Sfx owns platform-gated patch music routing")
	_check(sfx_source.contains("offensive_music_enabled") and sfx_source.contains("defensive_music_enabled"), "Sfx exposes independent accessibility stem toggles")
	_check(game_source.contains("Sfx.set_patch_layers(patch_levels)"), "Game refreshes music layers from the authoritative patch state")
	_check(catalog_source.contains("PATCH_MUSIC_LAYERS"), "content catalog declares patch music categories")
	_check(menu_source.contains("offensive_music_enabled") and menu_source.contains("defensive_music_enabled"), "legacy settings exposes independent music accessibility toggles")
	_check(access_source.contains("offensive_music") and access_source.contains("defensive_music"), "vNext accessibility surface exposes independent music toggles")

	var sfx := get_node_or_null("/root/Sfx")
	if sfx == null:
		_check(false, "Sfx autoload is available")
		_finish()
		return
	_check(sfx.has_method("patch_music_snapshot"), "Sfx exposes an inspectable patch music snapshot")
	_check(sfx.has_method("set_patch_layers"), "Sfx accepts patch level refreshes")
	_check(sfx.has_method("set_music_layer_enabled"), "Sfx exposes independent layer enablement")
	if not sfx.has_method("patch_music_snapshot") or not sfx.has_method("set_patch_layers"):
		_finish()
		return

	var snapshot: Dictionary = sfx.call("patch_music_snapshot")
	_check(snapshot.has("supported") and snapshot.has("offensive_active") and snapshot.has("defensive_active"), "patch snapshot reports support and both active states")
	_check(snapshot.get("crossfade_seconds", 0.0) == 0.5, "patch layer transition uses the planned half-second crossfade")
	_check(snapshot.get("offensive_enabled", null) is bool and snapshot.get("defensive_enabled", null) is bool, "patch snapshot reports both accessibility gates")

	var game := get_node_or_null("/root/Game")
	if game != null:
		game.patch_levels = {}
		game.apply_patch("rapid")
		var game_snapshot: Dictionary = sfx.call("patch_music_snapshot")
		_check(bool(game_snapshot.get("offensive_active", false)), "an offensive patch activates the percussion layer through Game")
		game.patch_levels = {}
		game.apply_patch("shield")
		var defense_snapshot: Dictionary = sfx.call("patch_music_snapshot")
		_check(bool(defense_snapshot.get("defensive_active", false)), "a defensive patch activates the bass layer through Game")
		game.patch_levels = {}
		sfx.call("set_patch_layers", {})

	var supported := bool(sfx.call("patch_music_supported"))
	print("PROBE_INFO patch_music_supported=%s display=%s" % [str(supported), DisplayServer.get_name()])
	if sfx.get("_stems").size() >= 3:
		sfx.call("set_intensity", 0)
		sfx.call("set_patch_layers", {"rapid": 1})
		await get_tree().create_timer(0.62).timeout
		var stems: Array = sfx.get("_stems")
		var offensive_db := float((stems[1] as AudioStreamPlayer).volume_db)
		var defensive_db := float((stems[2] as AudioStreamPlayer).volume_db)
		if supported:
			_check(offensive_db > -79.0 and defensive_db <= -79.0, "desktop offensive patch layer is audible without enabling the defensive layer")
		else:
			_check(offensive_db <= -79.0 and defensive_db <= -79.0, "mobile/headless path keeps patch layers silent")
		sfx.call("set_patch_layers", {"shield": 1})
		await get_tree().create_timer(0.62).timeout
		offensive_db = float((stems[1] as AudioStreamPlayer).volume_db)
		defensive_db = float((stems[2] as AudioStreamPlayer).volume_db)
		if supported:
			_check(offensive_db <= -79.0 and defensive_db > -79.0, "desktop defensive patch layer is distinct from the offensive layer")
		else:
			_check(offensive_db <= -79.0 and defensive_db <= -79.0, "mobile/headless defensive patch layer stays silent")
	else:
		_check(false, "three synchronized music stems are available")

	sfx.call("set_patch_layers", {"rapid": 1, "shield": 1})
	sfx.call("set_music_layer_enabled", "offensive", false)
	sfx.call("set_music_layer_enabled", "defensive", false)
	await get_tree().create_timer(0.62).timeout
	var disabled_snapshot: Dictionary = sfx.call("patch_music_snapshot")
	_check(not bool(disabled_snapshot.get("offensive_enabled", true)) and not bool(disabled_snapshot.get("defensive_enabled", true)), "both patch layers can be disabled independently")
	if sfx.get("_stems").size() >= 3:
		var disabled_stems: Array = sfx.get("_stems")
		_check(float((disabled_stems[1] as AudioStreamPlayer).volume_db) <= -79.0 and float((disabled_stems[2] as AudioStreamPlayer).volume_db) <= -79.0, "disabled layers do not remain audible")

	var before_profile: Dictionary = sfx.call("accessibility_snapshot").get("profile", {})
	sfx.call("apply_accessibility_profile", {"haptics_enabled": false, "shake_level": 0, "touch_scale": 0.85, "offensive_music_enabled": true, "defensive_music_enabled": false})
	sfx.call("apply_accessibility_profile", {"offensive_music_enabled": false})
	var partial_snapshot: Dictionary = sfx.call("accessibility_snapshot")
	var partial_profile: Dictionary = partial_snapshot.get("profile", {})
	_check(not bool(partial_snapshot.get("offensive_music_enabled", true)) and not bool(partial_snapshot.get("defensive_music_enabled", true)), "partial accessibility updates preserve the other stem setting")
	_check(not bool(partial_profile.get("haptics_enabled", true)) and int(partial_profile.get("shake_level", 2)) == 0 and is_equal_approx(float(partial_profile.get("touch_scale", 1.0)), 0.85), "partial accessibility updates do not reset unrelated preferences")
	sfx.call("reload_settings")
	var reloaded_snapshot: Dictionary = sfx.call("accessibility_snapshot")
	var reloaded_profile: Dictionary = reloaded_snapshot.get("profile", {})
	_check(reloaded_profile == partial_profile and not bool(reloaded_snapshot.get("offensive_music_enabled", true)) and not bool(reloaded_snapshot.get("defensive_music_enabled", true)), "independent stem preferences persist through settings reload")
	sfx.call("reset_accessibility_profile")
	sfx.call("set_patch_layers", {})
	if game != null:
		game.patch_levels = {}
	_check(before_profile is Dictionary, "probe captured a reversible accessibility profile")
	_finish()

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

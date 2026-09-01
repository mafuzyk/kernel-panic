extends Node

## G2C focused probe. Display controls are persisted under a dedicated display
## section while retaining a read of the legacy feel.target_fps key.

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
	_check(Sfx.has_method("default_target_fps"), "Sfx exposes platform-aware display defaults")
	_check(Sfx.has_method("display_snapshot"), "Sfx exposes a display settings snapshot")
	_check(Sfx.has_method("set_fullscreen"), "Sfx exposes a fullscreen setter")
	_check(Sfx.has_method("set_target_fps"), "Sfx exposes a target FPS setter")
	var settings_source := FileAccess.get_file_as_string("res://src/ui/menu_settings_kit.gd")
	_check(settings_source.contains("\"DISPLAY\""), "settings owns a separate DISPLAY section")
	_check(settings_source.contains("fullscreen") and settings_source.contains("target_fps"), "DISPLAY section exposes both required controls")
	if Sfx.has_method("default_target_fps"):
		var expected_default := 60 if DisplayServer.is_touchscreen_available() or OS.get_environment("KP_FORCE_TOUCH") != "" else 0
		_check(int(Sfx.default_target_fps()) == expected_default, "display default is 60 on touch and unlimited on desktop")
	var old_override := Sfx._settings_path_override
	Sfx._settings_path_override = "user://g2c-display-settings.cfg"
	Sfx.set_fullscreen(true)
	Sfx.set_target_fps(120)
	var saved: Dictionary = Sfx.display_snapshot() if Sfx.has_method("display_snapshot") else {}
	_check(bool(saved.get("fullscreen", false)) and int(saved.get("target_fps", -1)) == 120, "display setters update the live snapshot")
	_check(Engine.max_fps == 120, "target FPS applies to the engine")
	Sfx.fullscreen = false
	Sfx.target_fps = 30
	Sfx.reload_settings()
	_check(Sfx.fullscreen and Sfx.target_fps == 120, "display settings reload from the dedicated config section")
	var legacy := ConfigFile.new()
	legacy.set_value("feel", "target_fps", 30)
	legacy.save(Sfx._settings_path_override)
	Sfx.reload_settings()
	_check(Sfx.target_fps == 30, "legacy feel.target_fps remains readable")
	var malformed := ConfigFile.new()
	malformed.set_value("display", "target_fps", 999)
	malformed.set_value("display", "fullscreen", "false")
	malformed.save(Sfx._settings_path_override)
	Sfx.reload_settings()
	var expected_after_invalid := int(Sfx.default_target_fps())
	_check(Sfx.target_fps == expected_after_invalid and not Sfx.fullscreen, "invalid display values fall back safely")
	Sfx._settings_path_override = old_override
	Sfx.reload_settings()
	_finish()

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

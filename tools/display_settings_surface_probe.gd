extends Node

## N4 probe: the real legacy Settings surface exposes fullscreen only where it
## is meaningful (desktop), while target FPS remains available everywhere.

var _fails := 0
var _finished := false
var _tree: SceneTree
var _menu: Node
var _settings_panel: Control
var _fullscreen: CheckButton
var _old_settings_override := ""

func _ready() -> void:
	_tree = get_tree()
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PROBE_PASS ", message)
	else:
		_fails += 1
		print("PROBE_FAIL ", message)

func _ticks(count: int) -> void:
	for _i in count:
		await _tree.process_frame

func _find_button(panel: Node, type_name: String, prefix: String) -> Button:
	for raw_control in panel.find_children("*", type_name, true, false):
		var button := raw_control as Button
		if button != null and button.text.begins_with(prefix):
			return button
	return null

func _run() -> void:
	_old_settings_override = Sfx._settings_path_override
	Sfx._settings_path_override = "user://n4-display-surface.cfg"
	Sfx.set_fullscreen(false)
	Sfx.set_target_fps(60)
	var menu_scene := load("res://src/ui/menu.tscn") as PackedScene
	_check(menu_scene != null, "real Menu scene loads for display settings")
	if menu_scene == null:
		_finish()
		return
	_menu = menu_scene.instantiate()
	add_child(_menu)
	await _ticks(8)
	_menu.call("_open_settings")
	await _ticks(3)
	_settings_panel = _menu.get("_settings_panel") as Control
	_check(_settings_panel != null and _settings_panel.visible, "real Settings panel opens")
	var settings_kit = _menu.get("_settings_kit")
	_check(settings_kit != null and settings_kit.has_method("set_active_section"), "Settings exposes section navigation")
	if settings_kit != null and settings_kit.has_method("set_active_section"):
		settings_kit.set_active_section("DISPLAY")
	await _ticks(3)
	_check(settings_kit != null and settings_kit.active_section() == "DISPLAY", "Settings opens the DISPLAY section")
	if _settings_panel == null:
		_finish()
		return
	_fullscreen = _find_button(_settings_panel, "CheckButton", "FULLSCREEN") as CheckButton
	var target_fps := _find_button(_settings_panel, "Button", "TARGET FPS:")
	_check(_fullscreen != null, "DISPLAY exposes a real fullscreen control")
	_check(_fullscreen != null and _fullscreen.has_meta("desktop_only"), "fullscreen control declares desktop-only scope")
	_check(target_fps != null and target_fps.visible, "DISPLAY keeps target FPS available")
	var desktop := Balance.is_desktop_display() and not DisplayServer.is_touchscreen_available() and OS.get_environment("KP_FORCE_TOUCH") == ""
	if _fullscreen != null:
		_check(_fullscreen.visible == desktop, "fullscreen visibility matches the active platform")
		_check(_fullscreen.button_pressed == Sfx.fullscreen, "fullscreen control reflects the persisted live state")
		if desktop:
			print("PROBE_INFO fullscreen_rect=", _fullscreen.get_global_rect(), " disabled=", _fullscreen.disabled, " mouse_filter=", _fullscreen.mouse_filter, " parent_visible=", _fullscreen.get_parent().visible)
			_fullscreen.set_pressed_no_signal(true)
			_fullscreen.toggled.emit(true)
			await _ticks(3)
			print("PROBE_INFO fullscreen_after_toggle=", _fullscreen.button_pressed, " sfx=", Sfx.fullscreen, " mode=", DisplayServer.window_get_mode())
			_check(_fullscreen.button_pressed and Sfx.fullscreen, "fullscreen control wiring changes the live display state")
			_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "fullscreen control wiring applies the native window mode")
	Sfx.set_fullscreen(false)
	Sfx._settings_path_override = _old_settings_override
	Sfx.reload_settings()
	_finish()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("PROBE_DONE fails=%d" % _fails)
	_tree.quit(1 if _fails > 0 else 0)

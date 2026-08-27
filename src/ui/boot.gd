class_name BootOverlay
extends Control

signal finished

const LINE_TIME := 0.38
const TOTAL_TIME := 1.8

var _lines: Array[String] = []
var _label: Label
var _elapsed := 0.0
var _line_i := 0
var _done := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0196078, 0.0235294, 0.054902, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_lines = [
		"[    0.000000] kernel panic bootloader v%s" % ProjectSettings.get_setting("application/config/version", "dev"),
		"[    0.412331] checking save integrity ... %s" % ("OK" if FileAccess.file_exists(Sfx.SAVE_PATH) else "fresh install"),
		"[    0.718042] mounting /dev/purge ... OK",
		"[    1.001204] spawning last process ... done",
	]
	_label = Label.new()
	_label.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Balance.COL_TEXT)
	_label.position = Vector2(32, 32)
	_label.size = Vector2(900, 400)
	add_child(_label)

func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	while _line_i < _lines.size() and _elapsed > float(_line_i) * LINE_TIME:
		_label.text += _lines[_line_i] + "\n"
		_line_i += 1
	if _elapsed >= TOTAL_TIME:
		_finish()

func _input(event: InputEvent) -> void:
	if _done:
		return
	var pressed := (event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed()
	if pressed:
		_finish()
		get_viewport().set_input_as_handled()

func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)

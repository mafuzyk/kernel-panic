class_name DebugPanel
extends Control

const ENEMY_KINDS := [
	["drone", "DRONE"],
	["spewer", "SPEWER"],
	["lancer", "LANCER"],
	["splitter", "SPLITTER"],
	["bulwark", "BULWARK"],
	["trojan", "TROJAN"],
	["oom", "OOM_KILLER"],
	["recursor", "RECURSOR"],
	["firewall", "FIREWALL"],
]

var arena: Node
var _panel: PanelContainer
var _status: Label
var _notice: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _panel != null and is_instance_valid(_panel):
		_panel.size = _panel_size()

func _process(_delta: float) -> void:
	if visible:
		_refresh_status()

func toggle() -> void:
	visible = not visible
	if visible:
		_refresh_status()

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(16.0, 16.0)
	_panel.size = _panel_size()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	_panel.add_child(box)
	var header := _label("DEBUG CONSOLE // F1", 22, Balance.COL_TEXT)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(header)
	_status = _label("", 13, Balance.COL_MOTE)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(_status)
	_notice = _label("DEBUG BUILD ONLY // DESKTOP ONLY", 12, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.7))
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(_notice)
	box.add_child(_row([
		_button("NEXT WAVE [F2]", func() -> void: _skip_wave()),
		_button("ROOT SPLIT [F3]", func() -> void: _split_root()),
		_button("CLEAR [F4]", func() -> void: _clear()),
	]))
	var bosses := HBoxContainer.new()
	bosses.add_theme_constant_override("separation", 4)
	for i in 4:
		bosses.add_child(_button("BOSS MK-%d" % (i + 1), func(index := i + 1) -> void: _spawn_boss(index)))
	box.add_child(bosses)
	var enemy_label := _label("SPAWN REGULAR", 13, Balance.COL_PLAYER)
	enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(enemy_label)
	var enemies := GridContainer.new()
	enemies.columns = 3
	enemies.add_theme_constant_override("h_separation", 4)
	enemies.add_theme_constant_override("v_separation", 4)
	for entry in ENEMY_KINDS:
		var kind: String = entry[0]
		var title: String = entry[1]
		enemies.add_child(_button(title, func(selected := kind) -> void: _spawn_enemy(selected)))
	box.add_child(enemies)
	box.add_child(_button("CLOSE DEBUG PANEL [F1]", func() -> void: toggle()))

func _panel_size() -> Vector2:
	var viewport_size := get_viewport_rect().size
	return Vector2(minf(450.0, maxf(viewport_size.x - 32.0, 300.0)), minf(520.0, maxf(viewport_size.y - 32.0, 300.0)))

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.02, 0.055, 0.97)
	style.border_color = Color(Balance.COL_PLAYER.r, Balance.COL_PLAYER.g, Balance.COL_PLAYER.b, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style

func _row(buttons: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	for button in buttons:
		row.add_child(button)
	return row

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0.0, 30.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Balance.COL_TEXT)
	button.add_theme_color_override("font_hover_color", Balance.COL_PLAYER)
	button.add_theme_color_override("font_pressed_color", Balance.COL_PLAYER_HOT)
	button.pressed.connect(action)
	return button

func _refresh_status() -> void:
	if arena == null or not is_instance_valid(arena):
		return
	_status.text = "WAVE %02d // F2 NEXT // F3 ROOT SPLIT // F4 CLEAR" % Game.wave

func _set_notice(text: String) -> void:
	_notice.text = text

func _skip_wave() -> void:
	var ok := arena != null and bool(arena.call("debug_skip_to_wave", Game.wave + 1))
	_set_notice("SKIPPED TO WAVE %02d" % Game.wave if ok else "DEBUG COMMAND REJECTED")

func _spawn_enemy(kind: String) -> void:
	var enemy = arena.call("debug_spawn_enemy", kind) if arena != null else null
	_set_notice("SPAWNED %s" % kind.to_upper() if enemy != null else "UNKNOWN ENEMY: %s" % kind.to_upper())

func _spawn_boss(index: int) -> void:
	var boss = arena.call("debug_spawn_boss", index) if arena != null else null
	_set_notice("SPAWNED BOSS MK-%d" % index if boss != null else "BOSS SPAWN REJECTED")

func _split_root() -> void:
	var ok := arena != null and bool(arena.call("debug_spawn_root_split"))
	_set_notice("ROOT SPLIT // TWO MINIS" if ok else "ROOT SPLIT REJECTED")

func _clear() -> void:
	var ok := arena != null and bool(arena.call("debug_clear_combatants"))
	_set_notice("COMBATANTS CLEARED" if ok else "CLEAR REJECTED")

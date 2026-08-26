extends Control

var _title: Label
var _title_r: Label
var _title_b: Label
var _prompt: Label
var _best_label: Label
var _t := 0.0
var _glitch_t := 0.0
var _starting := false
var _drifters: Array = []
var _settings_panel: Control
var _mode_btn: Button
var _mode_info: Label
var _klog: Label
var _klog_t := 0.0
var _esc_armed := 0.0
var _bestiary_panel: BestiaryPanel
var _aim_btn_ref: Button

func _refresh_aim_label(btn: Button) -> void:
	if Game.mode == "weekly" and Sfx.aim_mode == "lockon":
		btn.text = "AIM MODE: LOCK-ON // BLOCKED IN WEEKLY"
	else:
		btn.text = "AIM MODE: %s" % Sfx.aim_mode.to_upper()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 5:
		_drifters.append({
			"pos": Vector2(randf_range(60, 1220), randf_range(80, 640)),
			"vel": Vector2.from_angle(randf() * TAU) * randf_range(9.0, 22.0),
			"rot": randf() * TAU,
			"rot_spd": randf_range(-0.5, 0.5),
			"kind": i % 3,
			"scale": randf_range(14.0, 26.0),
			"col": [Balance.COL_DRONE, Balance.COL_SPEWER, Balance.COL_LANCER][i % 3]
		})
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/bg_grid.gdshader")
	bg.material = mat
	add_child(bg)
	var dust := CPUParticles2D.new()
	dust.amount = 24
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(700, 420)
	dust.gravity = Vector2(0, -14)
	dust.initial_velocity_min = 4.0
	dust.initial_velocity_max = 14.0
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 2.2
	dust.color = Color(1.0, 0.85, 0.35, 0.14)
	add_child(dust)
	var mono: Font = load("res://assets/fonts/ShareTechMono.ttf")
	var orbitron: Font = load("res://assets/fonts/Orbitron.ttf")
	_title_r = _mk_title(orbitron, Color(1, 0.1, 0.3, 0.5))
	_title_b = _mk_title(orbitron, Color(0.1, 0.9, 1.0, 0.5))
	_title = _mk_title(orbitron, Balance.COL_TEXT)
	var sub := Label.new()
	sub.text = "// last process standing"
	sub.add_theme_font_override("font", mono)
	sub.add_theme_font_size_override("font_size", 17)
	sub.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.65))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.anchor_left = 0.0
	sub.anchor_right = 1.0
	sub.offset_top = 268.0
	sub.offset_bottom = 298.0
	add_child(sub)
	_prompt = Label.new()
	_prompt.text = "PRESS [ENTER] OR HIT >> PURGE"
	_prompt.add_theme_font_override("font", mono)
	_prompt.add_theme_font_size_override("font_size", 19)
	_prompt.add_theme_color_override("font_color", Balance.COL_PLAYER)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.anchor_left = 0.0
	_prompt.anchor_right = 1.0
	_prompt.offset_top = 400.0
	_prompt.offset_bottom = 430.0
	if DisplayServer.is_touchscreen_available():
		_prompt.text = "[TAP] TO PURGE"
	add_child(_prompt)
	var controls := RichTextLabel.new()
	controls.bbcode_enabled = true
	controls.fit_content = true
	controls.scroll_active = false
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls.text = "[center][color=#4ff2ff][WASD][/color] MOVE   [color=#4ff2ff][MOUSE][/color] AIM + FIRE   [color=#4ff2ff][SHIFT][/color] DASH\n[color=#4ff2ff][E][/color] OVERCLOCK   [color=#4ff2ff][ESC][/color] PAUSE   [color=#4ff2ff][M][/color] MUTE[/center]"
	controls.add_theme_font_override("normal_font", mono)
	controls.add_theme_font_size_override("normal_font_size", 15)
	controls.add_theme_color_override("default_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.6))
	controls.anchor_left = 0.0
	controls.anchor_right = 1.0
	controls.offset_top = 556.0
	controls.offset_bottom = 620.0
	add_child(controls)
	_best_label = Label.new()
	_best_label.add_theme_font_override("font", mono)
	_best_label.add_theme_font_size_override("font_size", 14)
	_best_label.add_theme_color_override("font_color", Color(Balance.COL_MOTE.r, Balance.COL_MOTE.g, Balance.COL_MOTE.b, 0.8))
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_best_label.anchor_left = 0.0
	_best_label.anchor_right = 1.0
	_best_label.offset_top = 330.0
	_best_label.offset_bottom = 354.0
	add_child(_best_label)
	var tag := Label.new()
	tag.text = "KERNEL PANIC v%s // purge loop online" % ProjectSettings.get_setting("application/config/version", "dev")
	tag.add_theme_font_override("font", mono)
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.3))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.anchor_left = 1.0
	tag.anchor_right = 1.0
	tag.offset_left = -500.0
	tag.offset_right = -16.0
	tag.offset_top = 686.0
	tag.offset_bottom = 706.0
	add_child(tag)
	var overlay_layer := CanvasLayer.new()
	overlay_layer.layer = 80
	var ov := ColorRect.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ov_mat := ShaderMaterial.new()
	ov_mat.shader = load("res://shaders/overlay.gdshader")
	ov.material = ov_mat
	overlay_layer.add_child(ov)
	add_child(overlay_layer)
	_update_best()
	Sfx.play_music()
	_build_button_row()
	_build_settings()
	_klog = Label.new()
	_klog.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	_klog.add_theme_font_size_override("font_size", 11)
	_klog.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.22))
	_klog.anchor_top = 0.0
	_klog.anchor_bottom = 0.0
	_klog.anchor_left = 0.0
	_klog.offset_left = 16.0
	_klog.offset_right = 620.0
	_klog.offset_top = 120.0
	_klog.offset_bottom = 190.0
	_klog.text = "[    0.000000] kernel panic daemon online"
	add_child(_klog)

func _style_card_button(b: Button, border: Color) -> void:
	b.custom_minimum_size = Vector2(270, 84)
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(border.r, border.g, border.b, 0.07)
	sb.border_color = Color(border.r, border.g, border.b, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	b.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	sbh.bg_color = Color(border.r, border.g, border.b, 0.18)
	sbh.set_border_width_all(3)
	b.add_theme_stylebox_override("hover", sbh)
	var sbp := sb.duplicate()
	sbp.bg_color = Color(border.r, border.g, border.b, 0.3)
	b.add_theme_stylebox_override("pressed", sbp)
	b.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Balance.COL_TEXT)
	b.add_theme_color_override("font_hover_color", Balance.COL_PLAYER_HOT)
	b.add_theme_color_override("font_pressed_color", Balance.COL_PLAYER_HOT)
	b.pivot_offset = b.custom_minimum_size * 0.5
	b.button_down.connect(func() -> void:
		b.scale = Vector2(0.96, 0.96)
		Sfx.play("ui", 1.0, -10.0)
	)
	b.button_up.connect(func() -> void:
		b.scale = Vector2.ONE
	)

func _build_button_row() -> void:
	var row := HBoxContainer.new()
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = -590.0
	row.offset_right = 590.0
	row.offset_top = -128.0
	row.offset_bottom = -34.0
	row.add_theme_constant_override("separation", 20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)
	var purge := Button.new()
	_style_card_button(purge, Balance.COL_PLAYER)
	purge.text = ">> PURGE"
	purge.pressed.connect(_start)
	row.add_child(purge)
	_mode_btn = Button.new()
	_style_card_button(_mode_btn, Balance.COL_MOTE)
	_mode_btn.text = "MODE: CLASSIC"
	_mode_btn.pressed.connect(_cycle_mode)
	row.add_child(_mode_btn)
	var settings_btn := Button.new()
	_style_card_button(settings_btn, Balance.COL_TEXT)
	settings_btn.text = "SETTINGS"
	settings_btn.pressed.connect(_open_settings)
	row.add_child(settings_btn)
	var best_btn := Button.new()
	_style_card_button(best_btn, Balance.COL_SPEWER)
	best_btn.text = "BESTIARY"
	best_btn.pressed.connect(_open_bestiary)
	row.add_child(best_btn)
	_mode_info = Label.new()
	_mode_info.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	_mode_info.add_theme_font_size_override("font_size", 12)
	_mode_info.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.6))
	_mode_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_info.anchor_left = 0.5
	_mode_info.anchor_right = 0.5
	_mode_info.anchor_top = 1.0
	_mode_info.anchor_bottom = 1.0
	_mode_info.offset_left = -590.0
	_mode_info.offset_right = -60.0
	_mode_info.offset_top = -30.0
	_mode_info.offset_bottom = -10.0
	add_child(_mode_info)
	_refresh_mode_ui()

func _open_bestiary() -> void:
	if _bestiary_panel == null:
		_bestiary_panel = BestiaryPanel.new()
		_bestiary_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		var title := Label.new()
		title.text = "BESTIARY // FIELD DATA"
		title.add_theme_font_override("font", load("res://assets/fonts/Orbitron.ttf"))
		title.add_theme_font_size_override("font_size", 28)
		title.add_theme_color_override("font_color", Balance.COL_TEXT)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.anchor_left = 0.0
		title.anchor_right = 1.0
		title.offset_top = 60.0
		title.offset_bottom = 110.0
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bestiary_panel.add_child(title)
		var hint := Label.new()
		hint.text = "purge a daemon to log its data"
		hint.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
		hint.add_theme_font_size_override("font_size", 13)
		hint.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.5))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.anchor_left = 0.0
		hint.anchor_right = 1.0
		hint.offset_top = 112.0
		hint.offset_bottom = 136.0
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bestiary_panel.add_child(hint)
		var back := Button.new()
		back.text = "BACK"
		back.flat = true
		back.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
		back.add_theme_font_size_override("font_size", 18)
		back.add_theme_color_override("font_color", Balance.COL_PLAYER)
		back.anchor_left = 0.5
		back.anchor_right = 0.5
		back.anchor_top = 1.0
		back.anchor_bottom = 1.0
		back.offset_left = -70.0
		back.offset_right = 70.0
		back.offset_top = -90.0
		back.offset_bottom = -50.0
		back.pressed.connect(_close_bestiary)
		_bestiary_panel.add_child(back)
		var layer := CanvasLayer.new()
		layer.layer = 70
		layer.add_child(_bestiary_panel)
		add_child(layer)
	_bestiary_panel.visible = true
	Sfx.play("ui", 1.1, -8.0)

func _close_bestiary() -> void:
	_bestiary_panel.visible = false
	Sfx.play("ui", 0.9, -8.0)

func _cycle_mode() -> void:
	var order := ["classic", "weekly", "onehp"]
	var idx := order.find(Game.mode)
	for step in 3:
		idx = (idx + 1) % 3
		if order[idx] != "onehp" or Game.onehp_unlocked:
			Game.mode = order[idx]
			break
	Sfx.play("ui", 1.1, -8.0)
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	cf.set_value("game", "mode", Game.mode)
	cf.save(Sfx.SAVE_PATH)
	_refresh_mode_ui()
	if _aim_btn_ref != null:
		_refresh_aim_label(_aim_btn_ref)

func _refresh_mode_ui() -> void:
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	match Game.mode:
		"weekly":
			_mode_btn.text = "MODE: WEEKLY RUN"
			var cur := int(cf.get_value("weekly", "best", 0)) if cf.get_value("weekly", "id", "") == Game.week_id() else 0
			var last := int(cf.get_value("weekly", "last_best", 0))
			_mode_info.text = "WEEK %s // BEST %d // LAST %d" % [Game.week_id(), cur, last]
		"onehp":
			_mode_btn.text = "MODE: ONE-HP"
			_mode_info.text = "1 INTEGRITY // SCORE x3 // BEST %d" % int(cf.get_value("run", "best_onehp", 0))
		_:
			_mode_btn.text = "MODE: CLASSIC"
			_mode_info.text = "BEST %d" % Game.best
	_update_best()

func _build_settings() -> void:
	_settings_panel = Control.new()
	_settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_panel.visible = false
	_settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.012, 0.03, 0.88)
	_settings_panel.add_child(dim)
	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -240.0
	box.offset_right = 240.0
	box.offset_top = -180.0
	box.offset_bottom = 180.0
	box.add_theme_constant_override("separation", 20)
	_settings_panel.add_child(box)
	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_override("font", load("res://assets/fonts/Orbitron.ttf"))
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Balance.COL_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(_make_slider_row("SFX", Sfx.sfx_vol, func(v: float) -> void:
		Sfx.set_sfx_vol(v)
		Sfx.play("ui", 1.0, -6.0)
	))
	box.add_child(_make_slider_row("MUSIC", Sfx.music_vol, func(v: float) -> void:
		Sfx.set_music_vol(v)
	))
	var mute := CheckButton.new()
	mute.text = "MUTE ALL"
	mute.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	mute.add_theme_font_size_override("font_size", 17)
	mute.add_theme_color_override("font_color", Balance.COL_TEXT)
	mute.button_pressed = Sfx.muted
	mute.toggled.connect(func(on: bool) -> void:
		Sfx.set_muted(on)
	)
	box.add_child(mute)
	var haptics := CheckButton.new()
	haptics.text = "HAPTICS"
	haptics.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	haptics.add_theme_font_size_override("font_size", 17)
	haptics.add_theme_color_override("font_color", Balance.COL_TEXT)
	haptics.button_pressed = Sfx.haptics_enabled
	haptics.toggled.connect(func(on: bool) -> void:
		Sfx.haptics_enabled = on
		Sfx.save_settings()
	)
	box.add_child(haptics)
	var aim_btn := Button.new()
	aim_btn.flat = true
	aim_btn.text = "AIM MODE: %s" % Sfx.aim_mode.to_upper()
	aim_btn.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	aim_btn.add_theme_font_size_override("font_size", 17)
	aim_btn.add_theme_color_override("font_color", Balance.COL_TEXT)
	aim_btn.add_theme_color_override("font_hover_color", Balance.COL_PLAYER)
	aim_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	aim_btn.pressed.connect(func() -> void:
		var order := ["drag", "stick", "lockon"]
		if Game.mode == "weekly":
			order = ["drag", "stick"]
		Sfx.aim_mode = order[(order.find(Sfx.aim_mode) + 1) % order.size()]
		_refresh_aim_label(aim_btn)
		Sfx.save_settings()
	)
	_aim_btn_ref = aim_btn
	_refresh_aim_label(aim_btn)
	box.add_child(aim_btn)
	var touch_sz := Button.new()
	touch_sz.flat = true
	touch_sz.text = "TOUCH SIZE: %s" % ["SMALL", "NORMAL", "BIG"][_touch_scale_idx(Sfx.touch_scale)]
	touch_sz.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	touch_sz.add_theme_font_size_override("font_size", 17)
	touch_sz.add_theme_color_override("font_color", Balance.COL_TEXT)
	touch_sz.add_theme_color_override("font_hover_color", Balance.COL_PLAYER)
	touch_sz.alignment = HORIZONTAL_ALIGNMENT_LEFT
	touch_sz.pressed.connect(func() -> void:
		var idx := _next_touch_scale_idx(Sfx.touch_scale)
		Sfx.touch_scale = [0.85, 1.0, 1.2][idx]
		touch_sz.text = "TOUCH SIZE: %s" % ["SMALL", "NORMAL", "BIG"][idx]
		Sfx.save_settings()
	)
	box.add_child(touch_sz)
	var shake_btn := Button.new()
	shake_btn.flat = true
	shake_btn.text = "SCREEN SHAKE: %s" % ["OFF", "LOW", "FULL"][clampi(Sfx.shake_level, 0, 2)]
	shake_btn.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	shake_btn.add_theme_font_size_override("font_size", 17)
	shake_btn.add_theme_color_override("font_color", Balance.COL_TEXT)
	shake_btn.add_theme_color_override("font_hover_color", Balance.COL_PLAYER)
	shake_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	shake_btn.pressed.connect(func() -> void:
		Sfx.shake_level = (Sfx.shake_level + 1) % 3
		shake_btn.text = "SCREEN SHAKE: %s" % ["OFF", "LOW", "FULL"][Sfx.shake_level]
		Sfx.save_settings()
	)
	box.add_child(shake_btn)
	var reset := Button.new()
	reset.flat = true
	reset.text = "RESET HIGH SCORE"
	reset.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	reset.add_theme_font_size_override("font_size", 14)
	reset.add_theme_color_override("font_color", Color(Balance.COL_DANGER.r, Balance.COL_DANGER.g, Balance.COL_DANGER.b, 0.8))
	reset.alignment = HORIZONTAL_ALIGNMENT_LEFT
	reset.pressed.connect(func() -> void:
		if reset.text == "RESET HIGH SCORE":
			reset.text = "TAP AGAIN TO CONFIRM"
			return
		_reset_scores()
		_update_best()
		reset.text = "CLEARED"
	)
	box.add_child(reset)
	var back := Button.new()
	back.text = "BACK"
	back.flat = true
	back.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	back.add_theme_font_size_override("font_size", 18)
	back.add_theme_color_override("font_color", Balance.COL_PLAYER)
	back.add_theme_color_override("font_hover_color", Balance.COL_PLAYER_HOT)
	back.pressed.connect(_close_settings)
	box.add_child(back)
	var hint := Label.new()
	hint.text = "M = MUTE IN GAME"
	hint.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.4))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	var stats := Label.new()
	stats.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	stats.add_theme_font_size_override("font_size", 12)
	stats.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.45))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cf2 := ConfigFile.new()
	cf2.load(Sfx.SAVE_PATH)
	var runs := int(cf2.get_value("lifetime", "runs", 0))
	var kills := int(cf2.get_value("lifetime", "kills", 0))
	var chain := int(cf2.get_value("lifetime", "best_chain", 0))
	var kd: Dictionary = cf2.get_value("lifetime", "killers", {})
	var top := "NONE"
	var tk := 0
	for k in kd:
		if int(kd[k]) > tk:
			tk = int(kd[k])
			top = str(k)
	stats.text = "LIFETIME  RUNS %d  KILLS %d  BEST CHAIN x%d  TOP THREAT %s" % [runs, kills, chain, top]
	box.add_child(stats)
	add_child(_settings_panel)

func _make_slider_row(label_text: String, value: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(86, 0)
	l.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Balance.COL_TEXT)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(220, 36)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.modulate = Color(0.55, 0.9, 1.0)
	s.value_changed.connect(on_change)
	row.add_child(s)
	var v := Label.new()
	v.text = "%d%%" % int(value * 100.0)
	v.custom_minimum_size = Vector2(56, 0)
	v.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	v.add_theme_font_size_override("font_size", 15)
	v.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.7))
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s.value_changed.connect(func(val: float) -> void:
		v.text = "%d%%" % int(val * 100.0)
	)
	row.add_child(v)
	return row

func _open_settings() -> void:
	_settings_panel.visible = true
	Sfx.play("ui", 1.1, -6.0)

func _close_settings() -> void:
	_settings_panel.visible = false
	Sfx.play("ui", 0.9, -6.0)

func _mk_title(f: Font, col: Color) -> Label:
	var l := Label.new()
	l.text = "KERNEL PANIC"
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", 76)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.offset_left = 0.0
	l.offset_right = 0.0
	l.offset_top = 150.0
	l.offset_bottom = 260.0
	add_child(l)
	return l

func _reset_scores() -> void:
	Game.best = 0
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	cf.set_value("run", "best", 0)
	cf.set_value("run", "best_classic", 0)
	cf.save(Sfx.SAVE_PATH)

static func _touch_scale_idx(v: float) -> int:
	return clampi(int(round((v - 0.85) / 0.175)), 0, 2)

static func _next_touch_scale_idx(v: float) -> int:
	return (_touch_scale_idx(v) + 1) % 3

func _update_best() -> void:
	var b := Game.best_for_mode()
	_best_label.text = ("HIGH SCORE  %07d" % b) if b > 0 else "NO RECORD YET"

const KLOG_POOL := [
	"daemon[666]: segfault at 0 ip 0xdeadbeef sp 0xffffd0 error 6",
	"systemd[1]: purge.service entered RUNNING state",
	"oom_killer: pressure high, harvesting loose motes",
	"root.exe: you have 1 unread virus",
	"mtrr: your free memory is a lie",
	"kswapd0: page steal successful lol",
	"watchdog: BUG: unable to handle kernel paging",
	"cron[424]: weekly defrag postponed forever",
]

func _process(delta: float) -> void:
	_t += delta
	if _esc_armed > 0.0:
		_esc_armed -= delta
		if _esc_armed <= 0.0 and not _starting:
			_prompt.text = "PRESS [ENTER] OR HIT >> PURGE" if not DisplayServer.is_touchscreen_available() else "HIT PURGE TO BEGIN"
			_prompt.add_theme_color_override("font_color", Balance.COL_PLAYER)
	_klog_t -= delta
	if _klog_t <= 0.0 and _klog != null:
		_klog_t = randf_range(2.2, 4.5)
		var lines := _klog.text.split("\n")
		var keep := lines.slice(maxi(lines.size() - 2, 0), lines.size())
		var ts := "%.6f" % (randf_range(1.0, 99.0))
		keep.append("[ %10s ] %s" % [ts, KLOG_POOL[randi() % KLOG_POOL.size()]])
		_klog.text = "\n".join(keep)
	_glitch_t -= delta
	_prompt.visible = fmod(_t, 1.1) < 0.72
	if _glitch_t <= 0.0:
		_glitch_t = randf_range(1.2, 3.4)
		var burst := randf_range(0.06, 0.16)
		set_meta("glitch_until", _t + burst)
		set_meta("glitch_off", Vector2(randf_range(-5, 5), randf_range(-3, 3)))
	var glitching: bool = _t < float(get_meta("glitch_until", 0.0))
	var off: Vector2 = get_meta("glitch_off", Vector2.ZERO) if glitching else Vector2.ZERO
	_title.offset_left = off.x
	_title.offset_right = off.x
	_title_r.offset_left = off.x * 0.4 - 4.0
	_title_r.offset_right = off.x * 0.4 - 4.0
	_title_b.offset_left = off.x * 0.4 + 4.0
	_title_b.offset_right = off.x * 0.4 + 4.0
	_title_r.visible = glitching
	_title_b.visible = glitching
	for d in _drifters:
		d["pos"] += d["vel"] * delta
		d["rot"] += d["rot_spd"] * delta
		var p: Vector2 = d["pos"]
		if p.x < -40:
			d["pos"] = Vector2(1320, d["pos"].y)
		elif p.x > 1320:
			d["pos"] = Vector2(-40, d["pos"].y)
		if p.y < -40:
			d["pos"] = Vector2(d["pos"].x, 760)
		elif p.y > 760:
			d["pos"] = Vector2(d["pos"].x, -40)
	queue_redraw()

func _draw() -> void:
	for d in _drifters:
		var c: Color = d["col"]
		c.a = 0.16
		var s: float = d["scale"]
		var pts := PackedVector2Array()
		match int(d["kind"]):
			0:
				pts = PackedVector2Array([Vector2(s * 1.2, 0), Vector2(-s, s * 0.85), Vector2(-s * 0.3, 0), Vector2(-s, -s * 0.85)])
			1:
				for i in 6:
					pts.push_back(Vector2.from_angle(TAU * i / 6.0) * s)
			2:
				pts = PackedVector2Array([Vector2(s * 1.5, 0), Vector2(-s, s * 0.8), Vector2(-s * 0.4, 0), Vector2(-s, -s * 0.8)])
		draw_set_transform(d["pos"], d["rot"], Vector2.ONE)
		draw_polyline(pts + PackedVector2Array([pts[0]]), c, 1.6, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _start() -> void:
	if _starting:
		return
	_starting = true
	Sfx.play("ui", 1.2, -4.0)
	Fx.flash(Balance.COL_PLAYER, 0.18, 0.4)
	Game.start_run()

func _unhandled_input(event: InputEvent) -> void:
	if _starting:
		return
	if _settings_panel != null and _settings_panel.visible:
		if event.is_action_pressed("pause"):
			_close_settings()
			get_viewport().set_input_as_handled()
		return
	if _bestiary_panel != null and _bestiary_panel.visible:
		if event.is_action_pressed("pause"):
			_close_bestiary()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		if _esc_armed > 0.0:
			get_tree().quit()
		else:
			_esc_armed = 2.0
			_prompt.text = "PRESS ESC AGAIN TO QUIT"
			_prompt.add_theme_color_override("font_color", Balance.COL_DANGER)
			Sfx.play("ui", 0.8, -8.0)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("confirm"):
		_start()

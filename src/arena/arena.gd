class_name Arena
extends Node2D

var player: Player
var cam: CameraRig
var spawner: Spawner
var hud: Hud
var overlay: ArenaOverlay
var walls: ArenaWalls
var enemy_container: Node2D
var mote_container: Node2D
var enemy_list: Array = []
var quality_tier := 0
var _fps_accum := 0.0
var _fps_time := 0.0
var _state := "play"
var _pause_panel: Control
var _pause_stats: Label
var _over_panel: Control
var _over_stats: Label
var _over_title: Label
var _over_sub: Label
var _intro_bars: Array[ColorRect] = []
var _intro_label: Label
var _intro_quote: Label
var touch: TouchControls
var _patch_panel: Control
var _patch_box: HBoxContainer
var _patch_offers: Array = []
var _patch_open := false
var _patch_pending := 0
var wave_signal_count := 0

func _ready() -> void:
	_build_background()
	walls = ArenaWalls.new()
	add_child(walls)
	mote_container = Node2D.new()
	add_child(mote_container)
	enemy_container = Node2D.new()
	add_child(enemy_container)
	player = Player.new()
	player.position = Vector2.ZERO
	add_child(player)
	cam = CameraRig.new()
	add_child(cam)
	spawner = Spawner.new()
	add_child(spawner)
	hud = Hud.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	hud_layer.add_child(hud)
	add_child(hud_layer)
	hud.player = player
	overlay = ArenaOverlay.new()
	add_child(overlay)
	_build_patch_ui()
	_build_pause_panel()
	_build_game_over_panel()
	_build_intro()
	if DisplayServer.is_touchscreen_available() or OS.get_environment("KP_FORCE_TOUCH") != "":
		touch = TouchControls.new()
		touch.set_anchors_preset(Control.PRESET_FULL_RECT)
		touch.player = player
		touch.arena = self
		var tcl := CanvasLayer.new()
		tcl.layer = 30
		tcl.add_child(touch)
		add_child(tcl)
	spawner.wave_started.connect(_on_wave_started)
	spawner.wave_cleared.connect(_on_wave_cleared)
	spawner.boss_spawned.connect(_on_boss_spawned)
	spawner.start(self, enemy_container, 1)
	enemy_container.child_entered_tree.connect(_on_enemy_child)
	enemy_container.child_exiting_tree.connect(_on_enemy_exit)
	player.hp_changed.connect(_on_player_hp)
	player.died.connect(_on_player_died)
	Game.combo_milestone.connect(_on_combo_milestone)
	Game.patch_picked.connect(_apply_patch_effects)
	Game.bestiary_unlocked.connect(_on_bestiary_unlocked)
	Sfx.play_music()
	Fx.flash(Color(0, 0, 0), 1.0, 0.6)
	if touch != null:
		_maybe_show_touch_hints()

func _maybe_show_touch_hints() -> void:
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	if cf.get_value("feel", "hints_shown", false) and OS.get_environment("KP_HINTS") == "":
		return
	cf.set_value("feel", "hints_shown", true)
	cf.save(Sfx.SAVE_PATH)
	var hint_layer := CanvasLayer.new()
	hint_layer.layer = 40
	add_child(hint_layer)
	var texts := [
		["LEFT THUMB // MOVE", Vector2(0, 560)],
		["RIGHT THUMB // AIM + FIRE", Vector2(640, 560)],
	]
	for h in texts:
		var l := Label.new()
		l.text = h[0]
		l.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
		l.add_theme_font_size_override("font_size", 16)
		l.add_theme_color_override("font_color", Balance.COL_PLAYER)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.anchor_left = h[1].x / 1280.0
		l.anchor_right = h[1].x / 1280.0 + 0.5
		l.offset_top = h[1].y
		l.offset_bottom = h[1].y + 30.0
		hint_layer.add_child(l)
		var tw := create_tween()
		tw.tween_interval(5.0)
		tw.tween_property(l, "modulate:a", 0.0, 1.5)
		tw.tween_callback(l.queue_free)

func _on_enemy_child(n: Node) -> void:
	if n is EnemyBase:
		n.died.connect(_on_enemy_died)
		if not enemy_list.has(n):
			enemy_list.append(n)

func _on_enemy_exit(n: Node) -> void:
	enemy_list.erase(n)

func _physics_process(_delta: float) -> void:
	EnemyBase.shared_list = enemy_list

func _update_quality(delta: float) -> void:
	var fps := Engine.get_frames_per_second()
	_fps_time += delta
	if _fps_time < 1.0:
		return
	_fps_time = 0.0
	if fps < 45.0 and fps > 0.0:
		_fps_accum += 1.0
	elif fps > 55.0 or fps <= 0.0:
		_fps_accum = maxf(_fps_accum - 1.0, -6.0)
	if _fps_accum >= 2.0 and quality_tier < 1:
		quality_tier = 1
		Fx.quality_scale = 0.5
		_fps_accum = 0.0
	elif _fps_accum <= -4.0 and quality_tier > 0:
		quality_tier = 0
		Fx.quality_scale = 1.0
		_fps_accum = 0.0

var _bg_mat: ShaderMaterial
var _era_color := Color("4ff2ff")

func _build_background() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_mat = ShaderMaterial.new()
	_bg_mat.shader = load("res://shaders/bg_grid.gdshader")
	rect.material = _bg_mat
	layer.add_child(rect)
	add_child(layer)
	var dust := CPUParticles2D.new()
	dust.amount = 36
	dust.lifetime = 7.0
	dust.preprocess = 7.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(700, 400)
	dust.gravity = Vector2.ZERO
	dust.initial_velocity_min = 6.0
	dust.initial_velocity_max = 22.0
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 2.4
	dust.color = Color(0.4, 0.55, 0.75, 0.22)
	add_child(dust)

func _build_pause_panel() -> void:
	_pause_panel = _make_panel()
	var title := _make_label("PAUSED", 42, Balance.COL_TEXT)
	title.offset_top = 220
	title.offset_bottom = 280
	_pause_panel.add_child(title)
	var info := _make_label("[ESC] RESUME      [R] RESTART      [Q] ABANDON PROCESS", 13, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.55))
	info.offset_top = 470
	info.offset_bottom = 500
	_pause_panel.add_child(info)
	_pause_stats = _make_label("", 14, Color(Balance.COL_MOTE.r, Balance.COL_MOTE.g, Balance.COL_MOTE.b, 0.85))
	_pause_stats.offset_top = 180
	_pause_stats.offset_bottom = 210
	_pause_panel.add_child(_pause_stats)
	var b_resume := _make_button("RESUME", 320)
	b_resume.pressed.connect(func() -> void:
		_set_paused(false)
	)
	_pause_panel.add_child(b_resume)
	var b_restart := _make_button("RESTART", 370)
	b_restart.pressed.connect(func() -> void:
		_set_paused(false)
		Game.start_run()
	)
	_pause_panel.add_child(b_restart)
	var b_menu := _make_button("ABANDON PROCESS", 420)
	b_menu.pressed.connect(func() -> void:
		_set_paused(false)
		Game.to_menu()
	)
	_pause_panel.add_child(b_menu)
	_pause_panel.add_child(_make_volume_row("SFX", Sfx.sfx_vol, 508.0, func(v: float) -> void:
		Sfx.set_sfx_vol(v)
	))
	_pause_panel.add_child(_make_volume_row("MUSIC", Sfx.music_vol, 556.0, func(v: float) -> void:
		Sfx.set_music_vol(v)
	))

func _make_volume_row(label_text: String, value: float, y: float, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.offset_left = -190.0
	row.offset_right = 190.0
	row.offset_top = y
	row.offset_bottom = y + 36.0
	row.add_theme_constant_override("separation", 14)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(70, 0)
	l.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Balance.COL_TEXT)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(220, 32)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.modulate = Color(0.55, 0.9, 1.0)
	s.value_changed.connect(on_change)
	row.add_child(s)
	return row

func _build_game_over_panel() -> void:
	_over_panel = _make_panel()
	_over_title = _make_label("PROCESS TERMINATED", 44, Balance.COL_DANGER)
	_over_title.offset_top = 150
	_over_title.offset_bottom = 212
	_over_panel.add_child(_over_title)
	_over_sub = _make_label("", 14, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.55))
	_over_sub.offset_top = 216
	_over_sub.offset_bottom = 242
	_over_panel.add_child(_over_sub)
	_over_stats = _make_label("", 17, Balance.COL_TEXT)
	_over_stats.offset_top = 252
	_over_stats.offset_bottom = 470
	_over_panel.add_child(_over_stats)
	var b_reboot := _make_button("REBOOT  [ENTER]", 500)
	b_reboot.pressed.connect(Game.start_run)
	_over_panel.add_child(b_reboot)
	var b_menu := _make_button("ABANDON PROCESS  [ESC]", 550)
	b_menu.pressed.connect(Game.to_menu)
	_over_panel.add_child(b_menu)

func _make_panel() -> Control:
	var p := Control.new()
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.visible = false
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.012, 0.03, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(dim)
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(p)
	add_child(layer)
	return p

func _make_button(txt: String, y: float) -> Button:
	var b := Button.new()
	b.text = txt
	b.flat = true
	b.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Balance.COL_TEXT)
	b.add_theme_color_override("font_hover_color", Balance.COL_PLAYER)
	b.add_theme_color_override("font_pressed_color", Balance.COL_PLAYER_HOT)
	b.add_theme_color_override("font_focus_color", Balance.COL_TEXT)
	b.anchor_left = 0.0
	b.anchor_right = 1.0
	b.offset_top = y
	b.offset_bottom = y + 40
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	return b

func _make_label(txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	var font: Font = load("res://assets/fonts/Orbitron.ttf") if size >= 24 else load("res://assets/fonts/ShareTechMono.ttf")
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.offset_left = 0.0
	l.offset_right = 0.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build_intro() -> void:
	for i in 2:
		var bar := ColorRect.new()
		bar.color = Color(0.005, 0.006, 0.015, 0.92)
		bar.set_anchors_preset(Control.PRESET_FULL_RECT)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cl := CanvasLayer.new()
		cl.layer = 55
		cl.add_child(bar)
		add_child(cl)
		bar.scale.y = 0.001
		bar.pivot_offset = Vector2(0, 0) if i == 0 else Vector2(0, 720)
		_intro_bars.append(bar)
	_intro_label = _make_label("", 30, Balance.COL_DANGER)
	_intro_label.offset_top = 290
	_intro_label.offset_bottom = 338
	_intro_label.modulate.a = 0.0
	_intro_quote = _make_label("", 15, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.8))
	_intro_quote.offset_top = 344
	_intro_quote.offset_bottom = 372
	_intro_quote.modulate.a = 0.0
	var il_layer := CanvasLayer.new()
	il_layer.layer = 56
	il_layer.add_child(_intro_label)
	add_child(il_layer)

func _on_wave_started(wave: int, is_boss: bool) -> void:
	wave_signal_count += 1
	Game.wave = wave
	Game.stats["wave"] = wave
	walls.pulse()
	_era_color = Balance.era_color(wave)
	walls.set_tint(_era_color)
	if is_boss:
		hud.show_banner("CYCLE %02d // ANOMALY" % wave, "ROOT DAEMON INBOUND", 2.2)
		Sfx.play("boss", 1.0, 0.0)
		_run_boss_intro()
	else:
		hud.show_banner("CYCLE %02d" % wave, "PURGE THE DAEMONS", 1.8)
		Sfx.play("wave", 1.0 + wave * 0.01, -6.0)
	if wave > 1 and (wave - 1) % Balance.HEAL_EVERY == 0 and player.hp < player.max_hp:
		player.heal(1)
		Fx.text(player.global_position + Vector2(0, -30), "+INTEGRITY", Balance.COL_PLAYER, 14)

func _run_boss_intro() -> void:
	var idx := int(Game.wave / float(Balance.BOSS_EVERY))
	_intro_label.text = RootBoss.title_for_index(idx) + " // KERNEL DAEMON"
	_intro_quote.text = '"' + RootBoss.quote_for_index(idx) + '"'
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_intro_bars[0], "scale:y", 1.0, 0.4).from(0.001).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_intro_bars[1], "scale:y", 1.0, 0.4).from(0.001).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_intro_label, "modulate:a", 1.0, 0.5).set_delay(0.3)
	tw.tween_property(_intro_quote, "modulate:a", 1.0, 0.5).set_delay(0.45)
	var tw2 := create_tween()
	tw2.tween_interval(2.0)
	tw2.tween_property(_intro_label, "modulate:a", 0.0, 0.4)
	tw2.parallel().tween_property(_intro_quote, "modulate:a", 0.0, 0.4)
	tw2.tween_callback(func() -> void:
		var tw3 := create_tween()
		tw3.set_parallel(true)
		tw3.tween_property(_intro_bars[0], "scale:y", 0.001, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw3.tween_property(_intro_bars[1], "scale:y", 0.001, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	)
	Fx.shake(0.25)

const TIPS := [
		"DASHING GRANTS INVULNERABILITY FRAMES",
		"CHAIN KILLS FAST FOR UP TO x8 SCORE",
		"MOTES CHARGE YOUR OVERCLOCK",
		"THE DAEMONS DO NOT ACCEPT COMPLAINTS",
		"ELITES HAVE NEW TRICKS. WATCH THE WHITE RING",
		"DASHING THROUGH ENEMIES BEATS APOLOGIZING",
		"OVERCLOCK LASTS LONGER IF YOU KEEP KILLING",
		"CORRUPTION POOLS ARE NOT POOLS",
		"OOM_KILLER WANTS YOUR MOTES. RUDE",
		"THE GRID REMEMBERS YOUR SCORES",
	]

var _tip_label: Label
var _tip_index := 0

func _on_wave_cleared(wave: int) -> void:
	hud.show_banner("CYCLE %02d CLEAR" % wave, "+%d // NEXT: %s" % [wave * 25, spawner.preview_next()], 2.2)
	Game.add_score(wave * 25)
	Sfx.play("ui", 1.3, -6.0)
	for m in get_tree().get_nodes_in_group("motes"):
		m.force_collect()
	_show_tip()
	if wave % 3 == 0:
		offer_patch()

func _show_tip() -> void:
	if _tip_label == null:
		_tip_label = _make_label("", 13, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.0))
		_tip_label.offset_top = 612
		_tip_label.offset_bottom = 640
		var tl := CanvasLayer.new()
		tl.layer = 45
		tl.add_child(_tip_label)
		add_child(tl)
	_tip_index = randi() % TIPS.size()
	_tip_label.text = "TIP // " + TIPS[_tip_index]
	_tip_label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_tip_label, "modulate:a", 0.85, 0.4)
	tw.tween_interval(2.2)
	tw.tween_property(_tip_label, "modulate:a", 0.0, 0.6)

func _build_patch_ui() -> void:
	_patch_panel = Control.new()
	_patch_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_patch_panel.visible = false
	_patch_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.012, 0.03, 0.86)
	_patch_panel.add_child(dim)
	var title := Label.new()
	title.text = "KERNEL PATCH DETECTED"
	title.add_theme_font_override("font", load("res://assets/fonts/Orbitron.ttf"))
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Balance.COL_MOTE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.offset_top = 130.0
	title.offset_bottom = 180.0
	_patch_panel.add_child(title)
	var sub := Label.new()
	sub.text = "SELECT ONE // [1] [2] [3]"
	sub.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.55))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.anchor_left = 0.0
	sub.anchor_right = 1.0
	sub.offset_top = 182.0
	sub.offset_bottom = 206.0
	_patch_panel.add_child(sub)
	_patch_box = HBoxContainer.new()
	_patch_box.anchor_left = 0.5
	_patch_box.anchor_right = 0.5
	_patch_box.anchor_top = 0.5
	_patch_box.anchor_bottom = 0.5
	_patch_box.offset_left = -465.0
	_patch_box.offset_right = 465.0
	_patch_box.offset_top = -110.0
	_patch_box.offset_bottom = 130.0
	_patch_box.add_theme_constant_override("separation", 24)
	_patch_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_patch_panel.add_child(_patch_box)
	var layer := CanvasLayer.new()
	layer.layer = 65
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(_patch_panel)
	add_child(layer)

func offer_patch() -> void:
	_patch_pending += 1
	_try_show_patch.call_deferred()

func _try_show_patch() -> void:
	if _patch_pending <= 0 or _patch_open or _state != "play" or player == null or player.dead:
		return
	if get_tree().paused:
		return
	_patch_pending -= 1
	_patch_open = true
	_patch_offers = Game.roll_patch_offer()
	if _patch_offers.is_empty():
		_patch_open = false
		return
	get_tree().paused = true
	for c in _patch_box.get_children():
		c.queue_free()
	for i in _patch_offers.size():
		_patch_box.add_child(_make_patch_card(_patch_offers[i], i))
	_patch_panel.modulate.a = 1.0
	_patch_panel.visible = true
	var cards := _patch_box.get_children()
	for i in cards.size():
		var card: Control = cards[i]
		card.modulate.a = 0.0
		card.position.y = 26.0
		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_interval(0.07 * i)
		tw.tween_property(card, "modulate:a", 1.0, 0.22)
		tw.parallel().tween_property(card, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Sfx.play("ready", 0.8, -4.0)
	Sfx.haptic(30)

func _make_patch_card(def: Dictionary, idx: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(280, 220)
	b.focus_mode = Control.FOCUS_NONE
	var lvl := Game.patch_level(def["id"])
	var border := Balance.COL_MOTE
	if def.get("legend", false):
		border = Color(1.0, 0.84, 0.3)
	elif not def["rare"]:
		border = Balance.COL_PLAYER
	b.add_theme_stylebox_override("normal", _card_style(Color(border.r, border.g, border.b, 0.12), border, 2.0))
	b.add_theme_stylebox_override("hover", _card_style(Color(border.r, border.g, border.b, 0.28), border, 3.0))
	b.add_theme_stylebox_override("pressed", _card_style(Color(border.r, border.g, border.b, 0.4), border, 3.0))
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 14.0
	vb.offset_right = -14.0
	vb.offset_top = 16.0
	vb.offset_bottom = -14.0
	vb.add_theme_constant_override("separation", 10)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(vb)
	var key := Label.new()
	key.text = "[%d]" % (idx + 1)
	key.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	key.add_theme_font_size_override("font_size", 13)
	key.add_theme_color_override("font_color", Color(border.r, border.g, border.b, 0.7))
	vb.add_child(key)
	var t := Label.new()
	t.text = def["title"]
	t.add_theme_font_override("font", load("res://assets/fonts/Orbitron.ttf"))
	t.add_theme_font_size_override("font_size", 19)
	t.add_theme_color_override("font_color", Balance.COL_TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(t)
	var d := Label.new()
	d.text = def["desc"]
	d.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	d.add_theme_font_size_override("font_size", 14)
	d.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.75))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(d)
	var lv := Label.new()
	lv.text = ("LV %d > %d" % [lvl, lvl + 1]) if lvl > 0 else "NEW"
	if def.get("legend", false):
		lv.text += "  // LEGENDARY"
	elif def["rare"]:
		lv.text += "  // RARE"
	lv.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	lv.add_theme_font_size_override("font_size", 12)
	lv.add_theme_color_override("font_color", border)
	vb.add_child(lv)
	b.pressed.connect(func() -> void:
		_pick_patch(idx)
	)
	return b

func _card_style(bg: Color, border: Color, bw: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(int(bw))
	sb.set_corner_radius_all(10)
	return sb

func _apply_patch_effects(id: String) -> void:
	match id:
		"hp":
			player.add_max_hp(1)
		"restore":
			for o in get_tree().get_nodes_in_group("enemy_orbs"):
				o.pop()
			player.invuln = maxf(player.invuln, 2.0)
			player.heal(1)

func _pick_patch(idx: int) -> void:
	if not _patch_open or idx >= _patch_offers.size():
		return
	var def: Dictionary = _patch_offers[idx]
	var id: String = def["id"]
	Game.apply_patch(id)
	_patch_open = false
	_patch_panel.visible = false
	get_tree().paused = false
	Fx.flash(Balance.COL_MOTE if def["rare"] else Balance.COL_PLAYER, 0.15, 0.35)
	Fx.ring(player.global_position, Balance.COL_PLAYER_HOT, 8.0, 90.0, 0.4, 3.0)
	Fx.text(player.global_position + Vector2(0, -34), def["title"], Balance.COL_MOTE, 16)
	Sfx.play("overclock", 1.3, -8.0)
	Sfx.haptic(20)
	_try_show_patch()

func _on_boss_spawned(boss: RootBoss) -> void:
	hud.boss = boss

func show_event_banner(txt: String) -> void:
	hud.show_banner("CYCLE %02d // %s" % [Game.wave, txt], "", 1.8)
	Sfx.play("charge", 0.8, -8.0)

func _on_player_hp(hp: int, _max_hp: int) -> void:
	overlay.set_low_hp(1.0 if hp <= 1 else (0.45 if hp == 2 else 0.0))

func _on_player_died() -> void:
	if _state != "play":
		return
	_state = "dead"
	spawner.stop()
	overlay.aberrate(1.4)
	var t := get_tree().create_timer(1.3, true, false, true)
	t.timeout.connect(_show_game_over)

func _show_game_over() -> void:
	Game.end_run()
	var s := Game.stats
	var acc := 0.0
	if s["shots"] > 0:
		acc = float(s["hits"]) / float(s["shots"]) * 100.0
	var lines := [
		"TERMINATED BY %s" % str(Game.stats.get("killer", "DAEMON")),
		"BUILD         %s" % Game.build_string(),
		"FINAL SCORE   %07d" % Game.score,
		"BEST          %07d" % Game.best,
		"",
		"CYCLES        %d" % s["wave"],
		"DAEMONS PURGED %d" % s["kills"],
		"ACCURACY      %d%%" % int(acc),
		"UPTIME        %02d:%02d" % [int(s["time"] / 60.0), int(s["time"]) % 60],
	]
	_over_sub.text = ["segmentation fault (core dumped)", "process has stopped responding", "kernel oops", "the daemons send their regards"][randi() % 4]
	_over_stats.text = "\n".join(lines)
	for c in _over_panel.get_children():
		if c is Label and c.text == "NEW RECORD":
			c.queue_free()
	if Game.new_best:
		var nb := _make_label("NEW RECORD", 20, Balance.COL_MOTE)
		nb.offset_top = 118
		nb.offset_bottom = 148
		_over_panel.add_child(nb)
		var ntw := nb.create_tween()
		ntw.set_loops()
		ntw.tween_property(nb, "modulate:a", 0.35, 0.5)
		ntw.tween_property(nb, "modulate:a", 1.0, 0.5)
	_over_panel.modulate.a = 0.0
	_over_panel.visible = true
	var tw := create_tween()
	tw.tween_property(_over_panel, "modulate:a", 1.0, 0.45)
	Sfx.play("gameover", 0.9, 0.0)
	Sfx.duck_music(-8.0, 2.0)

func _on_enemy_died(e: EnemyBase) -> void:
	Game.mark_bestiary(e.display_name)
	Game.register_kill(e.pts, e is RootBoss)
	player.add_kill_mote_bonus()
	var n := e.mote_count
	if n < 0:
		n = 1 if e.radius < 11.0 else (2 if e.radius < 17.0 else 3)
	if e.elite:
		n += 2
	n += Game.patch_level("frag")
	if spawner.wave_event == "rich":
		n *= 2
	var motes := get_tree().get_nodes_in_group("motes").size()
	n = mini(n, maxi(0, 90 - motes))
	for i in n:
		var m := Mote.new()
		m.player = player
		m.setup(e.global_position + Vector2.from_angle(Game.rng.randf() * TAU) * Game.rng.randf_range(4.0, 16.0))
		mote_container.call_deferred("add_child", m)
	if e is RootBoss:
		hud.boss = null
		overlay.aberrate(1.2)
		hud.show_banner("ROOT PURGED", "INTEGRITY +1  SCORE +250", 2.0)
		Game.add_score(250)
		Sfx.haptic(90)
		if e.boss_index >= 2:
			Game.unlock_onehp()
		if player.hp < player.max_hp:
			player.heal(1)
			Fx.text(player.global_position + Vector2(0, -30), "+INTEGRITY", Balance.COL_PLAYER, 14)
		offer_patch()
	Sfx.haptic(12)

func _on_bestiary_unlocked(id: String) -> void:
	if player == null or player.dead:
		return
	Fx.text(player.global_position + Vector2(0, -46), "NEW DATA: " + id.to_upper() + " LOGGED", Balance.COL_TEXT, 12)
	Sfx.play("ready", 1.5, -12.0)

func _on_combo_milestone(m: int) -> void:
	if (m != 4 and m != Balance.COMBO_MAX) or player == null or player.dead:
		return
	if m == 4 and Game.patch_level("vampic") > 0 and player.hp < player.max_hp:
		player.heal(1)
		Fx.text(player.global_position + Vector2(0, -52), "+1", Balance.COL_PLAYER, 13)
	Fx.text(player.global_position + Vector2(0, -40), "CHAIN x%d" % m, Balance.COL_MOTE, 18 if m < Balance.COMBO_MAX else 22)
	Fx.ring(player.global_position, Balance.COL_MOTE, 10.0, 60.0, 0.35, 2.5)
	Sfx.play("ready", 1.3 if m < Balance.COMBO_MAX else 1.6, -8.0)
	Sfx.haptic(15)

func _unhandled_input(event: InputEvent) -> void:
	if _patch_open:
		if event is InputEventKey and event.pressed and not event.echo:
			var k: int = event.physical_keycode
			if k == KEY_1:
				_pick_patch(0)
			elif k == KEY_2:
				_pick_patch(1)
			elif k == KEY_3:
				_pick_patch(2)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		if _state == "play" and not get_tree().paused:
			_set_paused(true)
		elif get_tree().paused:
			_set_paused(false)
		elif _state == "dead":
			Game.to_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart") and get_tree().paused and _state == "play":
		_set_paused(false)
		Game.start_run()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("confirm") and _state == "dead":
		Game.start_run()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("overclock") and get_tree().paused:
		Game.to_menu()
		get_viewport().set_input_as_handled()

func _set_paused(v: bool) -> void:
	get_tree().paused = v
	_pause_panel.visible = v
	if v:
		_pause_stats.text = "SCORE %07d   CYCLE %02d   COMBO x%d   BUILD: %s" % [Game.score, Game.wave, Game.mult, Game.build_string()]
	Sfx.play("ui", 1.0, -6.0)
	if not v:
		_try_show_patch()

func _notification(what: int) -> void:
	if is_inside_tree() and _state == "play" and not get_tree().paused:
		if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
			_set_paused(true)

func _process(delta: float) -> void:
	if _bg_mat != null:
		var c := _era_color
		if OS.get_environment("KP_NOTINT") == "":
			_bg_mat.set_shader_parameter("era_tint", Vector3(c.r, c.g, c.b))
		_bg_mat.set_shader_parameter("era_mix", 0.75)
	if _state == "play":
		Game.stats["time"] += delta
		var level := 0
		if hud.boss != null and is_instance_valid(hud.boss):
			level = 2
		elif player.overclock_active or Game.mult >= 4:
			level = 1
		Sfx.set_intensity(level)
		_update_quality(delta)

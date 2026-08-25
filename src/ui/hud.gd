class_name Hud
extends Control

var player: Player
var boss: RootBoss
var _score := 0
var _mult := 1
var _combo_frac := 0.0
var _hp := Balance.PLAYER_MAX_HP
var _max_hp := Balance.PLAYER_MAX_HP
var _meter := 0.0
var _oc_ready := false
var _oc_active := false
var _dash_frac := 1.0
var _banner_t := 0.0
var _banner_text := ""
var _banner_sub := ""
var _boss_frac := 1.0
var _boss_name := ""
var _score_font: Font
var _mono: Font
var _score_label: Label
var _best_label: Label
var _banner: Label
var _banner_sub_l: Label
var _score_pop := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_font = load("res://assets/fonts/Orbitron.ttf")
	_mono = load("res://assets/fonts/ShareTechMono.ttf")
	_score_label = _mk_label(30, Balance.COL_TEXT, Vector2(0, 14))
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_best_label = _mk_label(13, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.55), Vector2(0, 52))
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_best_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_banner = _mk_label(40, Balance.COL_TEXT, Vector2(0, 120))
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	_banner_sub_l = _mk_label(15, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.7), Vector2(0, 172))
	_banner_sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub_l.modulate.a = 0.0
	Game.score_changed.connect(_on_score)
	Game.combo_changed.connect(_on_combo)
	_on_score(Game.score, Game.mult)

func _mk_label(size: int, col: Color, pos: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", _score_font if size >= 24 else _mono)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.offset_left = 0.0
	l.offset_right = -14.0
	l.offset_top = pos.y
	l.offset_bottom = pos.y + size + 12
	add_child(l)
	return l

func _on_score(score: int, mult: int) -> void:
	if score > _score:
		_score_pop = 1.0
	_score = score
	_mult = mult
	_score_label.text = "%07d" % score
	_best_label.text = ("WEEK " + Game.week_id() + "  BEST %07d" % Game.best_for_mode()) if Game.mode == "weekly" else ("BEST %07d" % Game.best_for_mode())
	queue_redraw()

func _on_combo(mult: int, frac: float) -> void:
	_mult = mult
	_combo_frac = frac

func show_banner(text: String, sub: String, dur := 2.0) -> void:
	_banner_text = text
	_banner_sub = sub
	_banner_t = dur
	_banner.text = text
	_banner_sub_l.text = sub

func _process(delta: float) -> void:
	_score_pop = maxf(_score_pop - delta * 4.0, 0.0)
	if _banner_t > 0.0:
		_banner_t -= delta
		var k := _banner_t
		var a_in := clampf((2.0 - k) * 6.0, 0.0, 1.0) if k > 1.7 else 1.0
		var a_out := clampf(k * 2.5, 0.0, 1.0)
		_banner.modulate.a = minf(a_in, a_out)
		_banner_sub_l.modulate.a = _banner.modulate.a * 0.8
		_banner.offset_top = 120 + (1.0 - minf(a_in, 1.0)) * -14.0
		_banner.offset_bottom = _banner.offset_top + 52
	else:
		_banner.modulate.a = 0.0
		_banner_sub_l.modulate.a = 0.0
	if player != null and is_instance_valid(player):
		_hp = player.hp
		_max_hp = player.max_hp
		_meter = player.meter
		_oc_ready = player.oc_ready
		_oc_active = player.overclock_active
		_dash_frac = clampf(1.0 - player.dash_cd / Balance.DASH_CD, 0.0, 1.0)
	if boss != null and is_instance_valid(boss):
		_boss_frac = float(boss.hp) / float(boss.max_hp)
		_boss_name = boss.boss_title + " // KERNEL DAEMON"
	else:
		_boss_frac = -1.0
	queue_redraw()

func _draw() -> void:
	var f := _mono
	_hp_pips(f)
	_oc_bar(f)
	_mult_chip(f)
	_dash_pip(f)
	if _boss_frac >= 0.0:
		_boss_bar(f)

func _hp_pips(f: Font) -> void:
	var base := Vector2(24, 30)
	for i in _max_hp:
		var p := base + Vector2(i * 30.0, 0)
		var on := i < _hp
		var col := Balance.COL_PLAYER if on else Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.18)
		var s := 9.0
		if on and _hp == 1:
			col.a = 0.6 + 0.4 * absf(sin(Time.get_ticks_msec() / 1000.0 * 5.0))
		var pts := PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0)])
		if on:
			draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.28))
		draw_polyline(pts + PackedVector2Array([pts[0]]), col, 2.0, true)
		if on:
			draw_circle(p, 2.5, col)

func _oc_bar(f: Font) -> void:
	var r := Rect2(24, 52, 150, 8)
	var col := Balance.COL_PLAYER_HOT if _oc_active else Balance.COL_PLAYER
	if _oc_ready and not _oc_active:
		var pulse := 0.5 + 0.5 * absf(sin(Time.get_ticks_msec() / 90.0))
		col.a = 0.6 + 0.4 * pulse
		draw_rect(r.grow(3.0 + 2.0 * pulse), Color(col.r, col.g, col.b, 0.10 + 0.08 * pulse))
	draw_rect(r, Color(col.r, col.g, col.b, 0.14))
	var frac := clampf(_meter / Balance.OC_METER_MAX, 0.0, 1.0)
	draw_rect(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), Color(col.r, col.g, col.b, 0.85))
	draw_rect(r, Color(col.r, col.g, col.b, 0.5), false, 1.2)
	var label := "OVERCLOCK"
	var txt_col := col
	if _oc_ready and not _oc_active:
		label += "  READY [E]"
	if _oc_active:
		label += " ACTIVE"
	draw_string(f, Vector2(24, 78), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(txt_col.r, txt_col.g, txt_col.b, 0.85))
	_patch_chips(f)

func _patch_chips(f: Font) -> void:
	if Game.patch_levels.is_empty():
		return
	var x := 24.0
	for id in Game.patch_levels:
		var code: String = Game.PATCH_CODES.get(id, id.substr(0, 2).to_upper())
		var lvl := int(Game.patch_levels[id])
		var txt := "%s%d" % [code, lvl]
		var w := 30.0
		draw_rect(Rect2(x, 86, w, 15), Color(Balance.COL_PLAYER.r, Balance.COL_PLAYER.g, Balance.COL_PLAYER.b, 0.10))
		draw_rect(Rect2(x, 86, w, 15), Color(Balance.COL_PLAYER.r, Balance.COL_PLAYER.g, Balance.COL_PLAYER.b, 0.35), false, 1.0)
		draw_string(f, Vector2(x + 4, 97.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.75))
		x += w + 5.0

func _mult_chip(f: Font) -> void:
	if _mult <= 1:
		return
	var c := Balance.COL_MOTE
	var pop := 1.0 + 0.25 * _score_pop
	var rx := size.x - 24.0
	draw_string(f, Vector2(rx - 140.0, 84), "COMBO x%d" % _mult, HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * pop), c)
	var bar := Rect2(rx - 140.0, 90, 140, 4)
	draw_rect(bar, Color(c.r, c.g, c.b, 0.15))
	var hot := Color(Balance.COL_DANGER.r, Balance.COL_DANGER.g, Balance.COL_DANGER.b).lerp(c, _combo_frac)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _combo_frac, 4)), hot)

func _dash_pip(f: Font) -> void:
	if DisplayServer.is_touchscreen_available():
		return
	var col := Balance.COL_PLAYER if _dash_frac >= 1.0 else Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.35)
	draw_circle(Vector2(32, 688), 5.0, col)
	draw_string(f, Vector2(46, 693), "DASH [SHIFT]", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(col.r, col.g, col.b, 0.7))

func _boss_bar(f: Font) -> void:
	var w := 500.0
	var x0 := (size.x - w) * 0.5
	var r := Rect2(x0, 676, w, 10)
	var col := Balance.COL_DANGER
	draw_rect(r, Color(col.r, col.g, col.b, 0.15))
	var segs := 20
	var filled := int(ceil(_boss_frac * segs))
	for i in segs:
		var seg := Rect2(r.position.x + i * (r.size.x / segs) + 1, r.position.y, r.size.x / segs - 2, r.size.y)
		if i < filled:
			draw_rect(seg, Color(col.r, col.g, col.b, 0.9))
		else:
			draw_rect(seg, Color(col.r, col.g, col.b, 0.12))
	draw_string(f, Vector2(x0, 668), _boss_name, HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(col.r, col.g, col.b, 0.9))

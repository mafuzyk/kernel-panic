class_name Hud
extends Control

const TacticalUIHelper = preload("res://src/ui/tactical_ui.gd")

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
var _dash_available := 1
var _dash_max := 1
var _banner_t := 0.0
var _banner_text := ""
var _banner_sub := ""
var _hint_queue: Array[Dictionary] = []
var _hint_queue_ids := {}
var _boss_frac := 1.0
var _boss_name := ""
var _boss_fragments: Array[RootBoss] = []
var _boss_split := false
var _score_font: Font
var _mono: Font
var _score_label: Label
var _best_label: Label
var _banner: Label
var _banner_sub_l: Label
var _score_pop := 0.0
var _build_label: Label
var _run_info_label: Label
var _achievement_label: Label
var _achievement_t := 0.0
const PATCH_TOOLTIP_HOLD_TIME := 0.45
var _patch_chip_rects: Dictionary = {}
var _tooltip_patch_id := ""
var _tooltip_data: Dictionary = {}
var _tooltip_visible := false
var _tooltip_touch_index := -1
var _tooltip_hold_t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_font = load("res://assets/fonts/Orbitron.ttf")
	_mono = load("res://assets/fonts/ShareTechMono.ttf")
	_score_label = _mk_label(30, Balance.COL_TEXT, Vector2(0, 14))
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_score_label.visible = false
	_best_label = _mk_label(13, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.55), Vector2(0, 52))
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_best_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_best_label.visible = false
	_banner = _mk_label(40, Balance.COL_TEXT, Vector2(0, 120))
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	_banner_sub_l = _mk_label(15, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.7), Vector2(0, 172))
	_banner_sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub_l.modulate.a = 0.0
	_build_label = _mk_label(12, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.5), Vector2(14, 690))
	_build_label.anchor_left = 0.0
	_build_label.anchor_right = 0.6
	_build_label.anchor_top = 1.0
	_build_label.anchor_bottom = 1.0
	_build_label.offset_left = 14.0
	_build_label.offset_right = 0.0
	_build_label.offset_top = -30.0
	_build_label.offset_bottom = -6.0
	_build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_build_label.text = Game.build_string()
	_run_info_label = Label.new()
	_run_info_label.anchor_left = 1.0
	_run_info_label.anchor_right = 1.0
	_run_info_label.offset_left = -310.0
	_run_info_label.offset_right = -24.0
	_run_info_label.offset_top = 14.0
	_run_info_label.offset_bottom = 36.0
	_run_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_run_info_label.add_theme_font_override("font", _mono)
	_run_info_label.add_theme_font_size_override("font_size", 12)
	_run_info_label.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.62))
	add_child(_run_info_label)
	_achievement_label = Label.new()
	_achievement_label.anchor_left = 0.0
	_achievement_label.anchor_right = 0.0
	_achievement_label.offset_left = _safe_side_margin()
	_achievement_label.offset_right = 430.0
	_achievement_label.offset_top = 112.0
	_achievement_label.offset_bottom = 136.0
	_achievement_label.add_theme_font_override("font", _mono)
	_achievement_label.add_theme_font_size_override("font_size", 12)
	_achievement_label.add_theme_color_override("font_color", Balance.COL_MOTE)
	_achievement_label.modulate.a = 0.0
	add_child(_achievement_label)
	Game.score_changed.connect(_on_score)
	Game.combo_changed.connect(_on_combo)
	Game.achievement_unlocked.connect(_on_achievement_unlocked)
	Game.patch_picked.connect(func(_id: String) -> void:
		_build_label.text = Game.build_string()
	)
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

func _layout_height() -> float:
	return size.y if size.y > 0.0 else get_viewport_rect().size.y

func _safe_top_margin() -> float:
	return clampf(_layout_height() * 0.025, 18.0, 28.0)

func _safe_bottom_margin() -> float:
	return clampf(_layout_height() * 0.025, 18.0, 28.0)

func _safe_side_margin() -> float:
	return clampf(size.x * 0.01875, 16.0, 24.0)

func hud_top_y(gap: float) -> float:
	return _safe_top_margin() + gap

func hud_bottom_y(gap: float) -> float:
	return _layout_height() - _safe_bottom_margin() - gap

func layout_snapshot(viewport: Vector2 = size) -> Dictionary:
	return TacticalUIHelper.layout(viewport)

func event_log_visible(viewport: Vector2 = size) -> bool:
	return not bool(layout_snapshot(viewport)["compact"])

func visible_event_lines(limit: int = 4) -> Array[String]:
	var result: Array[String] = []
	var start := maxi(Game.event_log.size() - maxi(limit, 1), 0)
	for index in range(start, Game.event_log.size()):
		var entry: Dictionary = Game.event_log[index]
		result.append("[%05.1f] %s" % [float(entry.get("time", 0.0)), str(entry.get("text", ""))])
	return result

func dash_baseline() -> float:
	return hud_bottom_y(14.0)

func boss_bar_baseline() -> float:
	return hud_bottom_y(26.0)

func boss_title_baseline() -> float:
	return hud_bottom_y(34.0)

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

func run_info_text() -> String:
	var total_seconds := maxf(float(Game.stats.get("time", 0.0)), 0.0)
	var minutes := int(total_seconds / 60.0)
	var seconds := int(total_seconds) % 60
	var deciseconds := int(total_seconds * 10.0) % 10
	return "TIME %02d:%02d.%d // %s // HOLD R" % [minutes, seconds, deciseconds, Game.run_seed_text()]

func _on_achievement_unlocked(_id: String, label: String) -> void:
	show_achievement(label)

func show_achievement(label: String) -> void:
	if _achievement_label == null or not is_instance_valid(_achievement_label):
		return
	_achievement_label.text = "[ %07.3f ] achievement: %s enabled" % [float(Game.stats.get("time", 0.0)), label]
	_achievement_t = 4.0
	_achievement_label.modulate.a = 1.0

func show_banner(text: String, sub: String, dur := 2.0) -> void:
	_banner_text = text
	_banner_sub = sub
	_banner_t = dur
	_banner.text = text
	_banner_sub_l.text = sub

func queue_hint(id: String, text: String, dur := 1.35) -> void:
	if id.is_empty() or _hint_queue_ids.has(id):
		return
	_hint_queue_ids[id] = true
	_hint_queue.append({"text": text, "dur": dur})
	_show_next_hint()

func _show_next_hint() -> void:
	if _banner_t > 0.0 or _hint_queue.is_empty():
		return
	var hint: Dictionary = _hint_queue.pop_front()
	show_banner(str(hint["text"]), "", float(hint["dur"]))

func set_boss_fragments(minis: Array) -> void:
	_boss_fragments.clear()
	for mini in minis:
		if mini is RootBoss and is_instance_valid(mini):
			_boss_fragments.append(mini)
	_boss_fragments.sort_custom(func(a: RootBoss, b: RootBoss) -> bool:
		return int(a.get_meta("mini_slot", 0)) < int(b.get_meta("mini_slot", 0))
	)
	_boss_split = _boss_fragments.size() > 0
	if _boss_split:
		_boss_name = "ROOT.exe // FORKED"

func clear_boss_encounter() -> void:
	boss = null
	_boss_fragments.clear()
	_boss_split = false
	_boss_frac = -1.0
	_boss_name = ""

func _prune_boss_fragments() -> void:
	var valid_fragments: Array[RootBoss] = []
	for fragment in _boss_fragments:
		if is_instance_valid(fragment):
			valid_fragments.append(fragment)
	_boss_fragments = valid_fragments
	_boss_split = _boss_fragments.size() > 0

func _process(delta: float) -> void:
	_score_pop = maxf(_score_pop - delta * 4.0, 0.0)
	if _achievement_t > 0.0:
		_achievement_t = maxf(_achievement_t - delta, 0.0)
		_achievement_label.modulate.a = clampf(minf(_achievement_t, 1.0) * 2.0, 0.0, 1.0)
	if _tooltip_touch_index >= 0:
		_tooltip_hold_t += delta
		if _tooltip_hold_t >= PATCH_TOOLTIP_HOLD_TIME and not _tooltip_visible:
			_show_patch_tooltip(_tooltip_patch_id)
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
		_show_next_hint()
	if player != null and is_instance_valid(player):
		_hp = player.hp
		_max_hp = player.max_hp
		_meter = player.meter
		_oc_ready = player.oc_ready
		_oc_active = player.overclock_active
		_dash_available = player.available_dash_charges()
		_dash_max = maxi(player.dash_charges, 1)
		if _dash_available > 0:
			_dash_frac = 1.0
		else:
			_dash_frac = clampf(1.0 - player.dash_cd / player.dash_cooldown_duration(), 0.0, 1.0)
	if _build_label != null and Game.patch_level("vampic") > 0:
		var on_cd := Game.vampic_cd > 0.0
		var blink := 0.35 + 0.3 * absf(sin(Time.get_ticks_msec() / 180.0))
		_build_label.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, blink if on_cd else 0.5))
	if _run_info_label != null and is_instance_valid(_run_info_label):
		var compact := bool(layout_snapshot()["compact"])
		_run_info_label.text = run_info_text() if Sfx.show_run_info and Game.state == Game.State.PLAYING and not compact else ""
	_prune_boss_fragments()
	if _boss_split:
		_boss_frac = -1.0
	elif boss != null and is_instance_valid(boss):
		_boss_frac = float(boss.hp) / float(boss.max_hp)
		_boss_name = boss.boss_title + " // KERNEL DAEMON"
	else:
		_boss_frac = -1.0
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if DisplayServer.is_touchscreen_available():
			return
		var mouse_id := _patch_id_at(event.position)
		if mouse_id.is_empty():
			_dismiss_patch_tooltip()
		else:
			_show_patch_tooltip(mouse_id)
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_dismiss_patch_tooltip()
			var touch_id := _patch_id_at(touch.position)
			if not touch_id.is_empty():
				_tooltip_touch_index = touch.index
				_tooltip_patch_id = touch_id
				_tooltip_hold_t = 0.0
		elif touch.index == _tooltip_touch_index:
			_dismiss_patch_tooltip()
		return
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _tooltip_touch_index:
			_dismiss_patch_tooltip()

func _patch_id_at(position: Vector2) -> String:
	for id in _patch_chip_rects:
		if _patch_chip_rects[id].has_point(position):
			return str(id)
	return ""

func patch_chip_rect(id: String) -> Rect2:
	return _patch_chip_rects.get(id, Rect2())

func patch_tooltip_visible() -> bool:
	return _tooltip_visible

func patch_tooltip_snapshot() -> Dictionary:
	return _tooltip_data.duplicate(true)

func _show_patch_tooltip(id: String) -> void:
	if id.is_empty() or not Game.patch_levels.has(id):
		_dismiss_patch_tooltip()
		return
	_tooltip_patch_id = id
	_tooltip_data = Game.patch_tooltip_data(id)
	_tooltip_visible = true
	queue_redraw()

func _dismiss_patch_tooltip() -> void:
	_tooltip_patch_id = ""
	_tooltip_data.clear()
	_tooltip_visible = false
	_tooltip_touch_index = -1
	_tooltip_hold_t = 0.0
	queue_redraw()

func _draw() -> void:
	var f := _mono
	_draw_tactical_shell(f)
	_hp_pips(f)
	_oc_bar(f)
	_mult_chip(f)
	_dash_pip(f)
	if _boss_split:
		_boss_split_bar(f)
	elif _boss_frac >= 0.0:
		_boss_bar(f)
	_draw_patch_tooltip(f)

func _draw_angular_panel(rect: Rect2, color: Color, fill_alpha: float = 0.08) -> void:
	var points := TacticalUIHelper.angular_points(rect, minf(12.0, rect.size.y * 0.22))
	draw_colored_polygon(points, TacticalUIHelper.PANEL)
	draw_colored_polygon(points, Color(color.r, color.g, color.b, fill_alpha))
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(color.r, color.g, color.b, 0.72), 1.4, true)

func _draw_tactical_shell(f: Font) -> void:
	var layout := layout_snapshot()
	var compact := bool(layout["compact"])
	var integrity_rect: Rect2 = layout["integrity"]
	var encounter_rect: Rect2 = layout["encounter"]
	var score_rect: Rect2 = layout["score"]
	var dash_rect: Rect2 = layout["dash"]
	var patch_rect: Rect2 = layout["patches"]
	_draw_angular_panel(integrity_rect, TacticalUIHelper.CYAN, 0.055)
	_draw_angular_panel(encounter_rect, TacticalUIHelper.CYAN, 0.045)
	_draw_angular_panel(score_rect, TacticalUIHelper.CYAN, 0.055)
	_draw_angular_panel(dash_rect, TacticalUIHelper.CYAN, 0.045)
	_draw_angular_panel(patch_rect, TacticalUIHelper.CYAN, 0.045)
	draw_string(f, integrity_rect.position + Vector2(16.0, 22.0), "INTEGRITY", HORIZONTAL_ALIGNMENT_LEFT, integrity_rect.size.x - 32.0, 12, TacticalUIHelper.TEXT)
	var cycle_label := "CYCLE %02d" % Game.wave
	draw_string(_score_font, encounter_rect.position + Vector2(0.0, 28.0 if compact else 32.0), cycle_label, HORIZONTAL_ALIGNMENT_CENTER, encounter_rect.size.x, 20 if compact else 24, TacticalUIHelper.TEXT)
	var encounter_label := _boss_name if not _boss_name.is_empty() else "PROCESS PURGE"
	draw_string(f, encounter_rect.position + Vector2(0.0, 48.0 if compact else 58.0), encounter_label, HORIZONTAL_ALIGNMENT_CENTER, encounter_rect.size.x, 11, TacticalUIHelper.MUTED)
	draw_string(f, score_rect.position + Vector2(14.0, 22.0), "SCORE", HORIZONTAL_ALIGNMENT_LEFT, score_rect.size.x - 28.0, 12, TacticalUIHelper.CYAN)
	draw_string(_score_font, score_rect.position + Vector2(14.0, 47.0), "%07d" % _score, HORIZONTAL_ALIGNMENT_RIGHT, score_rect.size.x - 28.0, 20, TacticalUIHelper.TEXT)
	if event_log_visible():
		var event_rect := Rect2(score_rect.position.x, score_rect.end.y + 8.0, score_rect.size.x, 84.0)
		_draw_angular_panel(event_rect, TacticalUIHelper.CYAN, 0.025)
		var event_y := event_rect.position.y + 18.0
		draw_string(f, Vector2(score_rect.position.x + 14.0, event_y), "EVENT LOG", HORIZONTAL_ALIGNMENT_LEFT, score_rect.size.x - 28.0, 11, TacticalUIHelper.CYAN)
		for line in visible_event_lines():
			event_y += 15.0
			draw_string(f, Vector2(score_rect.position.x + 14.0, event_y), line, HORIZONTAL_ALIGNMENT_LEFT, score_rect.size.x - 28.0, 10, TacticalUIHelper.MUTED)

func _hp_pips(f: Font) -> void:
	var base := Vector2(_safe_side_margin(), hud_top_y(12.0))
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
	var x := _safe_side_margin()
	var y := hud_top_y(34.0)
	var r := Rect2(x, y, 150, 8)
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
	draw_string(f, Vector2(x, hud_top_y(60.0)), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(txt_col.r, txt_col.g, txt_col.b, 0.85))
	if Game.patch_level("scrapdiet") > 0 and player != null and is_instance_valid(player):
		var thr: int = player._scrap_threshold()
		var sc := Color(1.0, 0.75, 0.4, 0.9)
		var sx := x + 166.0
		draw_rect(Rect2(sx, y, 86, 8), Color(sc.r, sc.g, sc.b, 0.14))
		var sfrac: float = clampf(float(player.scrap_count) / float(thr), 0.0, 1.0)
		draw_rect(Rect2(sx, y, 86.0 * sfrac, 8), Color(sc.r, sc.g, sc.b, 0.8))
		draw_string(f, Vector2(sx, hud_top_y(60.0)), "SCRAP %d/%d" % [player.scrap_count, thr], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, sc)
	_patch_chips(f)

func _patch_chips(f: Font) -> void:
	_update_patch_chip_rects()
	if _patch_chip_rects.is_empty():
		return
	var x := _safe_side_margin()
	var y := hud_top_y(68.0)
	for id in Game.patch_levels:
		var code: String = Game.PATCH_CODES.get(id, id.substr(0, 2).to_upper())
		var lvl := int(Game.patch_levels[id])
		var txt := "%s%d" % [code, lvl]
		var chip_rect: Rect2 = _patch_chip_rects[id]
		draw_rect(chip_rect, Color(Balance.COL_PLAYER.r, Balance.COL_PLAYER.g, Balance.COL_PLAYER.b, 0.10))
		draw_rect(chip_rect, Color(Balance.COL_PLAYER.r, Balance.COL_PLAYER.g, Balance.COL_PLAYER.b, 0.35), false, 1.0)
		draw_string(f, Vector2(x + 4, y + 11.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.75))
		x += chip_rect.size.x + 5.0

func _update_patch_chip_rects() -> void:
	_patch_chip_rects.clear()
	if Game.patch_levels.is_empty():
		return
	var x := _safe_side_margin()
	var y := hud_top_y(68.0)
	for id in Game.patch_levels:
		var chip_rect := Rect2(x, y, 30.0, 15.0)
		_patch_chip_rects[id] = chip_rect
		x += chip_rect.size.x + 5.0

func _draw_patch_tooltip(f: Font) -> void:
	if not _tooltip_visible or _tooltip_data.is_empty() or not _patch_chip_rects.has(_tooltip_patch_id):
		return
	var width := minf(390.0, maxf(size.x - 24.0, 220.0))
	var height := 76.0
	var chip_rect: Rect2 = _patch_chip_rects[_tooltip_patch_id]
	var pos := chip_rect.position + Vector2(0, chip_rect.size.y + 8.0)
	if pos.y + height > size.y - 8.0:
		pos.y = chip_rect.position.y - height - 8.0
	pos.x = clampf(pos.x, 12.0, maxf(12.0, size.x - width - 12.0))
	var panel := Rect2(pos, Vector2(width, height))
	draw_rect(panel, Color(0.01, 0.02, 0.05, 0.96))
	draw_rect(panel, Color(Balance.COL_PLAYER.r, Balance.COL_PLAYER.g, Balance.COL_PLAYER.b, 0.8), false, 1.5)
	draw_string(f, pos + Vector2(10, 18), str(_tooltip_data.get("title", "PATCH")), HORIZONTAL_ALIGNMENT_LEFT, width - 20.0, 13, Balance.COL_TEXT)
	draw_string(f, pos + Vector2(10, 36), "LEVEL %d // %s" % [int(_tooltip_data.get("level", 0)), str(_tooltip_data.get("description", ""))], HORIZONTAL_ALIGNMENT_LEFT, width - 20.0, 11, Balance.COL_TEXT)
	draw_string(f, pos + Vector2(10, 57), str(_tooltip_data.get("relation", "NO DIRECT INTERACTION")), HORIZONTAL_ALIGNMENT_LEFT, width - 20.0, 10, Balance.COL_MOTE)

func _mult_chip(f: Font) -> void:
	if _mult <= 1:
		return
	var c := Balance.COL_MOTE
	var pop := 1.0 + 0.25 * _score_pop
	var rx := size.x - _safe_side_margin()
	var combo_y := hud_top_y(66.0)
	draw_string(f, Vector2(rx - 140.0, combo_y), "COMBO x%d" % _mult, HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * pop), c)
	var bar := Rect2(rx - 140.0, combo_y + 6.0, 140, 4)
	draw_rect(bar, Color(c.r, c.g, c.b, 0.15))
	var hot := Color(Balance.COL_DANGER.r, Balance.COL_DANGER.g, Balance.COL_DANGER.b).lerp(c, _combo_frac)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _combo_frac, 4)), hot)

func _dash_pip(f: Font) -> void:
	if not Balance.is_desktop_display() or DisplayServer.is_touchscreen_available():
		return
	var col := Balance.COL_PLAYER if _dash_frac >= 1.0 else Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.35)
	var baseline := dash_baseline()
	draw_circle(Vector2(_safe_side_margin() + 8.0, baseline), 5.0, col)
	var dash_text := "DASH x%d [SHIFT]" % _dash_max if _dash_max > 1 else "DASH [SHIFT]"
	draw_string(f, Vector2(_safe_side_margin() + 22.0, baseline + 5.0), dash_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(col.r, col.g, col.b, 0.7))

func _boss_bar(f: Font) -> void:
	var w := minf(500.0, maxf(160.0, size.x - _safe_side_margin() * 2.0))
	var x0 := (size.x - w) * 0.5
	var baseline := boss_bar_baseline()
	var r := Rect2(x0, baseline, w, 10)
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
	draw_string(f, Vector2(x0, boss_title_baseline()), _boss_name, HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(col.r, col.g, col.b, 0.9))

func _boss_split_bar(f: Font) -> void:
	var w := minf(500.0, maxf(160.0, size.x - _safe_side_margin() * 2.0))
	var x0 := (size.x - w) * 0.5
	var row_h := 7.0
	var row_gap := 3.0
	var bar_x := x0 + 64.0
	var bar_w := w - 64.0
	var col := Balance.COL_DANGER
	var container := Rect2(x0, boss_bar_baseline(), w, row_h * 2.0 + row_gap)
	draw_rect(container, Color(col.r, col.g, col.b, 0.08))
	draw_rect(container, Color(col.r, col.g, col.b, 0.42), false, 1.0)
	for fragment in _boss_fragments:
		if not is_instance_valid(fragment):
			continue
		var slot := clampi(int(fragment.get_meta("mini_slot", 0)), 0, 1)
		var y := container.position.y + slot * (row_h + row_gap)
		var label := "MINI-A" if slot == 0 else "MINI-B"
		draw_string(f, Vector2(x0, y + row_h), label, HORIZONTAL_ALIGNMENT_LEFT, 58.0, 10, Color(col.r, col.g, col.b, 0.9))
		var row := Rect2(bar_x, y, bar_w, row_h)
		draw_rect(row, Color(col.r, col.g, col.b, 0.12))
		var max_hp := maxf(float(fragment.max_hp), 1.0)
		var frac := clampf(float(fragment.hp) / max_hp, 0.0, 1.0)
		var filled := clampi(int(ceilf(frac * 20.0)), 0, 20)
		for i in 20:
			var seg := Rect2(row.position.x + i * (row.size.x / 20.0) + 1.0, row.position.y, row.size.x / 20.0 - 2.0, row.size.y)
			if i < filled:
				draw_rect(seg, Color(col.r, col.g, col.b, 0.9))
			else:
				draw_rect(seg, Color(col.r, col.g, col.b, 0.12))
	draw_string(f, Vector2(x0, boss_title_baseline()), _boss_name, HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(col.r, col.g, col.b, 0.9))

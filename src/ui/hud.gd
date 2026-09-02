class_name Hud
extends Control

const TacticalUIHelper = preload("res://src/ui/tactical_ui.gd")
const TacticalIconScript = preload("res://src/ui/tactical_icon.gd")
const VNextCombatHudScript = preload("res://src/ui/vnext/surfaces/combat_hud_surface.gd")

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
var _shield_ready := false
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
var _banner: Label
var _banner_sub_l: Label
var _score_pop := 0.0
var _run_info_label: Label
var _achievement_label: Label
var _achievement_t := 0.0
var _achievement_text := ""
const PATCH_TOOLTIP_HOLD_TIME := 0.45
var _patch_chip_rects: Dictionary = {}
var _tooltip_patch_id := ""
var _tooltip_data: Dictionary = {}
var _tooltip_visible := false
var _tooltip_touch_index := -1
var _tooltip_hold_t := 0.0
var _dash_icon: Control
var _era_accent: Color = TacticalUIHelper.CYAN
var _surface_scale := 1.0
var _surface_window_size := Vector2(-1.0, -1.0)
var _surface_viewport_size := Vector2(-1.0, -1.0)
var _physical_display := false
var _banner_base_y := 120.0
var _banner_elapsed := 0.0
var _aux_size := Vector2.ZERO
var _vnext_hud_surface: Control
var _vnext_hud_mode := false
var _layout_cache: Dictionary = {}
var _layout_cache_viewport := Vector2(-1.0, -1.0)
var _layout_cache_touch := false
var _layout_cache_touch_scale := -1.0
var _layout_cache_valid := false
var _layout_cache_builds := 0
var _layout_cache_hits := 0
var _patch_dock_cache: Dictionary = {}
var _patch_dock_cache_viewport := Vector2(-1.0, -1.0)
var _patch_dock_cache_touch := false
var _patch_dock_cache_touch_scale := -1.0
var _patch_dock_cache_signature := ""
var _patch_dock_cache_valid := false
var _patch_dock_cache_builds := 0
const BANNER_FADE_IN_SECONDS := 0.22
const BANNER_FADE_OUT_SECONDS := 0.32

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_physical_display = DisplayServer.get_name().to_lower() != "headless"
	_vnext_hud_mode = OS.get_environment("KP_VNEXT_HUD") == "1"
	if _vnext_hud_mode:
		_vnext_hud_surface = VNextCombatHudScript.new()
		_vnext_hud_surface.set_anchors_preset(Control.PRESET_FULL_RECT)
		_vnext_hud_surface.action_requested.connect(_on_vnext_hud_action)
		add_child(_vnext_hud_surface)
	_apply_surface_transform()
	if is_inside_tree():
		get_window().size_changed.connect(_apply_surface_transform)
	_score_font = load("res://assets/fonts/Orbitron.ttf")
	_mono = load("res://assets/fonts/ShareTechMono.ttf")
	_banner = _mk_label(40, Balance.COL_TEXT, Vector2(0, 120))
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	_banner.visible = not _vnext_hud_mode
	_banner_sub_l = _mk_label(15, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.7), Vector2(0, 172))
	_banner_sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub_l.modulate.a = 0.0
	_banner_sub_l.visible = not _vnext_hud_mode
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
	_run_info_label.visible = not _vnext_hud_mode
	add_child(_run_info_label)
	_dash_icon = TacticalIconScript.new()
	_dash_icon.size = Vector2(52.0, 52.0)
	_dash_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dash_icon.z_index = 2
	_dash_icon.call("configure", "dash", Balance.COL_PLAYER)
	_dash_icon.visible = not _vnext_hud_mode
	add_child(_dash_icon)
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
	_achievement_label.visible = not _vnext_hud_mode
	add_child(_achievement_label)
	Game.score_changed.connect(_on_score)
	Game.combo_changed.connect(_on_combo)
	Game.achievement_unlocked.connect(_on_achievement_unlocked)
	_refresh_aux_anchors()
	_on_score(Game.score, Game.mult)
	if _vnext_hud_surface != null:
		_vnext_hud_surface.reflow_for_viewport(get_viewport_rect().size)

## The combat HUD is authored in physical-window units, then fitted back into
## the logical canvas with one uniform factor. That keeps panel and font sizes
## stable while the project stretch maps the resulting canvas to the display.
## TacticalUI.layout() still receives the physical window size, so wide,
## compact and portrait compositions are selected from the real available area.
## The size signature is checked once per frame as a fallback because some
## window managers can maximize without changing the logical stretch viewport.
func _apply_surface_transform() -> void:
	var win := Vector2(DisplayServer.window_get_size())
	var vp := get_viewport_rect().size
	if win.x < 1.0 or win.y < 1.0 or vp.x < 1.0 or vp.y < 1.0:
		return
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = win
	_surface_scale = vp.x / win.x
	_surface_window_size = win
	_surface_viewport_size = vp
	scale = Vector2(_surface_scale, _surface_scale)
	_refresh_aux_anchors()

func _surface_transform_needs_refresh() -> bool:
	var vp := get_viewport_rect().size
	if vp.x < 1.0 or vp.y < 1.0:
		return false
	if not _physical_display:
		return not is_equal_approx(vp.x, _surface_viewport_size.x) \
			or not is_equal_approx(vp.y, _surface_viewport_size.y)
	var win := Vector2(DisplayServer.window_get_size())
	return not is_equal_approx(win.x, _surface_window_size.x) \
		or not is_equal_approx(win.y, _surface_window_size.y) \
		or not is_equal_approx(vp.x, _surface_viewport_size.x) \
		or not is_equal_approx(vp.y, _surface_viewport_size.y)

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
	return TacticalUIHelper.frame_margins(size).y

func _safe_bottom_margin() -> float:
	return TacticalUIHelper.frame_margins(size).y

func _safe_side_margin() -> float:
	return TacticalUIHelper.frame_margins(size).x

## Anchor the floating HUD labels to the panel grid instead of hard-coded
## offsets: announce below the encounter panel, achievement toast under the
## top-left stack, run info under the score/event column, build string above
## the dash module — all sharing the single 8px gutter.
func _refresh_aux_anchors() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	var lay := layout_snapshot()
	var integrity: Rect2 = lay["integrity"]
	var encounter: Rect2 = lay["encounter"]
	var score: Rect2 = lay["score"]
	var side := _safe_side_margin()
	var collision := collision_layout_snapshot(size, _max_hp)
	var banner: Rect2 = collision["banner"]
	var achievement: Rect2 = collision["achievement"]
	_banner_base_y = banner.position.y
	if _banner != null and is_instance_valid(_banner):
		_banner.offset_top = _banner_base_y
		_banner.offset_bottom = _banner_base_y + 52.0
	if _banner_sub_l != null and is_instance_valid(_banner_sub_l):
		_banner_sub_l.offset_top = _banner_base_y + (0.0 if bool(lay["compact"]) else 60.0)
		_banner_sub_l.offset_bottom = _banner_sub_l.offset_top + (22.0 if bool(lay["compact"]) else 22.0)
	if _achievement_label != null and is_instance_valid(_achievement_label):
		_achievement_label.offset_left = achievement.position.x
		_achievement_label.offset_right = achievement.end.x
		_achievement_label.offset_top = achievement.position.y
		_achievement_label.offset_bottom = achievement.end.y
		_refresh_achievement_text(achievement.size.x)
	if _run_info_label != null and is_instance_valid(_run_info_label):
		var stack_end := score.end.y + 92.0
		_run_info_label.offset_right = -side
		_run_info_label.offset_left = -side - 308.0
		_run_info_label.offset_top = stack_end + 8.0
		_run_info_label.offset_bottom = stack_end + 30.0
func hud_top_y(gap: float) -> float:
	return _safe_top_margin() + gap

func hud_bottom_y(gap: float) -> float:
	return _layout_height() - _safe_bottom_margin() - gap

func layout_snapshot(viewport: Vector2 = size) -> Dictionary:
	var touch := touch_layout()
	var touch_scale := float(Sfx.touch_scale)
	if _layout_cache_valid and viewport == _layout_cache_viewport and touch == _layout_cache_touch and is_equal_approx(touch_scale, _layout_cache_touch_scale):
		_layout_cache_hits += 1
		return _layout_cache
	_layout_cache_viewport = viewport
	_layout_cache_touch = touch
	_layout_cache_touch_scale = touch_scale
	_layout_cache = TacticalUIHelper.layout(viewport, touch, touch_scale)
	_layout_cache_valid = true
	_layout_cache_builds += 1
	return _layout_cache

func layout_cache_snapshot() -> Dictionary:
	return {
		"valid": _layout_cache_valid,
		"builds": _layout_cache_builds,
		"hits": _layout_cache_hits,
		"viewport": _layout_cache_viewport,
		"touch": _layout_cache_touch,
		"touch_scale": _layout_cache_touch_scale,
		"patch_builds": _patch_dock_cache_builds,
	}

func _banner_reserved_rect(viewport: Vector2 = size) -> Rect2:
	var lay := layout_snapshot(viewport)
	var encounter: Rect2 = lay["encounter"]
	var height := 22.0 if bool(lay["compact"]) else 82.0
	return Rect2(0.0, encounter.end.y + 16.0, viewport.x, height)

func hp_pip_rects(viewport: Vector2 = size, max_hp: int = _max_hp) -> Array[Rect2]:
	var integrity: Rect2 = layout_snapshot(viewport)["integrity"]
	var count := maxi(max_hp, 1)
	var base := integrity.position + Vector2(18.0, 48.0)
	var span := maxf(integrity.size.x - 36.0, 1.0)
	var spacing := 30.0 if count <= 1 else minf(30.0, span / float(count - 1))
	var radius := 9.0
	if spacing < 22.0:
		radius = clampf(spacing * 0.42, 3.0, 9.0)
	var result: Array[Rect2] = []
	for index in count:
		var center := base + Vector2(float(index) * spacing, 0.0)
		result.append(Rect2(center - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0)))
	return result

func scrap_layout(viewport: Vector2 = size) -> Dictionary:
	var lay := layout_snapshot(viewport)
	var integrity: Rect2 = lay["integrity"]
	var x := integrity.position.x + 16.0
	var y := integrity.position.y + integrity.size.y - 34.0
	var meter_width := maxf(integrity.size.x - 32.0, 80.0)
	var sx := x + meter_width + 12.0
	var right := viewport.x - _safe_side_margin_for_viewport(viewport)
	var width := clampf(right - sx, 0.0, 86.0)
	var bar := Rect2(sx, y, width, 8.0)
	return {
		"bar": bar,
		"label": Rect2(sx, y + 8.0, width, 18.0),
	}

func _safe_side_margin_for_viewport(viewport: Vector2) -> float:
	return TacticalUIHelper.frame_margins(viewport).x

func collision_layout_snapshot(viewport: Vector2 = size, max_hp: int = _max_hp) -> Dictionary:
	var lay := layout_snapshot(viewport)
	var safe_margin := TacticalUIHelper.frame_margins(viewport)
	var safe := Rect2(safe_margin.x, safe_margin.y, maxf(viewport.x - safe_margin.x * 2.0, 0.0), maxf(viewport.y - safe_margin.y * 2.0, 0.0))
	var banner := _banner_reserved_rect(viewport)
	var encounter: Rect2 = lay["encounter"]
	var integrity: Rect2 = lay["integrity"]
	var toast_y := maxf(maxf(integrity.end.y, encounter.end.y), banner.end.y) + 8.0
	var achievement := Rect2(safe_margin.x, toast_y, maxf(viewport.x - safe_margin.x * 2.0, 1.0), 24.0)
	return {
		"safe": safe,
		"banner": banner,
		"achievement": achievement,
		"integrity": integrity,
		"hp_pips": hp_pip_rects(viewport, max_hp),
		"scrap": scrap_layout(viewport),
	}

func touch_layout() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.get_environment("KP_FORCE_TOUCH") != ""

func event_log_visible(viewport: Vector2 = size) -> bool:
	return not bool(layout_snapshot(viewport)["compact"])

func visible_event_lines(limit: int = 4, max_width: float = -1.0, font_size: int = 11) -> Array[String]:
	var result: Array[String] = []
	var start := maxi(Game.event_log.size() - maxi(limit, 1), 0)
	for index in range(start, Game.event_log.size()):
		var entry: Dictionary = Game.event_log[index]
		var line := "[%05.1f] %s" % [float(entry.get("time", 0.0)), str(entry.get("text", ""))]
		if max_width > 0.0 and _mono != null:
			line = TacticalUIHelper.ellipsis_fit(_mono, line, max_width, font_size)
		result.append(line)
	return result

func dash_baseline() -> float:
	return hud_bottom_y(14.0)

func boss_bar_baseline() -> float:
	var rows := boss_bar_rects(size, false)
	return rows[0].position.y if not rows.is_empty() else hud_bottom_y(26.0)

func boss_title_baseline() -> float:
	var region: Rect2 = layout_snapshot()["boss"]
	return region.position.y + 20.0

func boss_bar_rects(viewport: Vector2 = size, split: bool = _boss_split) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var region: Rect2 = layout_snapshot(viewport)["boss"]
	var row_gap := 3.0
	var row_h := 7.0 if split else 10.0
	var row_y := region.position.y + 31.0
	var label_inset := 64.0 if split else 8.0
	var row_w := maxf(region.size.x - label_inset - 8.0, 80.0)
	if split:
		for index in 2:
			result.append(Rect2(region.position.x + label_inset, row_y + index * (row_h + row_gap), row_w, row_h))
	else:
		result.append(Rect2(region.position.x + label_inset, row_y, row_w, row_h))
	return result

func _on_score(score: int, mult: int) -> void:
	if score > _score:
		_score_pop = 1.0
	_score = score
	_mult = mult
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

func vnext_hud_enabled() -> bool:
	return _vnext_hud_mode

func vnext_hud_surface() -> Control:
	return _vnext_hud_surface

func _on_vnext_hud_action(action_id: String, _payload: Dictionary) -> void:
	if action_id == "dash" and player != null and is_instance_valid(player):
		player.request_dash(Vector2.ZERO)

func _on_achievement_unlocked(_id: String, label: String) -> void:
	show_achievement(label)

func show_achievement(label: String) -> void:
	if _achievement_label == null or not is_instance_valid(_achievement_label):
		return
	_achievement_text = "[ %07.3f ] achievement: %s enabled" % [float(Game.stats.get("time", 0.0)), label]
	_refresh_achievement_text(float(_achievement_label.size.x))
	_achievement_t = 4.0
	_achievement_label.modulate.a = 1.0

func _refresh_achievement_text(max_width: float) -> void:
	if _achievement_label == null or not is_instance_valid(_achievement_label) or _mono == null:
		return
	if _achievement_text.is_empty():
		return
	_achievement_label.text = TacticalUIHelper.ellipsis_fit(_mono, _achievement_text, maxf(max_width, 1.0), 12)

func show_banner(text: String, sub: String, dur := 2.0) -> void:
	_banner_text = text
	_banner_sub = sub
	_banner_t = maxf(dur, 0.0)
	_banner_elapsed = 0.0
	var hide_main := _banner_compact()
	if _banner != null and is_instance_valid(_banner):
		_banner.text = "" if hide_main else text
		_banner.modulate.a = 0.0
	if _banner_sub_l != null and is_instance_valid(_banner_sub_l):
		_banner_sub_l.text = sub
		_banner_sub_l.modulate.a = 0.0

func _banner_compact() -> bool:
	return bool(layout_snapshot()["compact"]) and not _banner_sub.is_empty()

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
		var fork_title := "ROOT.exe"
		if boss != null and is_instance_valid(boss) and not boss.boss_title.is_empty():
			fork_title = boss.boss_title
		elif not _boss_fragments.is_empty():
			var fragment_title := _boss_fragments[0].boss_title.trim_prefix("MINI-")
			if not fragment_title.is_empty():
				fork_title = fragment_title
		_boss_name = fork_title + " // FORKED"

func clear_boss_encounter() -> void:
	boss = null
	_boss_fragments.clear()
	_boss_split = false
	_boss_frac = -1.0
	_boss_name = ""

func _prune_boss_fragments() -> void:
	var needs_prune := false
	for fragment in _boss_fragments:
		if not is_instance_valid(fragment):
			needs_prune = true
	if not needs_prune:
		return
	var valid_fragments: Array[RootBoss] = []
	for fragment in _boss_fragments:
		if is_instance_valid(fragment):
			valid_fragments.append(fragment)
	_boss_fragments = valid_fragments
	_boss_split = _boss_fragments.size() > 0

func boss_split_rows_snapshot() -> Array[Dictionary]:
	_prune_boss_fragments()
	var result: Array[Dictionary] = []
	for fragment in _boss_fragments:
		if not is_instance_valid(fragment):
			continue
		var slot := clampi(int(fragment.get_meta("mini_slot", 0)), 0, 1)
		var max_hp := maxf(float(fragment.max_hp), 1.0)
		result.append({
			"slot": slot,
			"label": "MINI-A" if slot == 0 else "MINI-B",
			"fraction": clampf(float(fragment.hp) / max_hp, 0.0, 1.0),
		})
	return result

func _process(delta: float) -> void:
	if _surface_transform_needs_refresh():
		_apply_surface_transform()
	if size != _aux_size:
		_aux_size = size
		_refresh_aux_anchors()
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
		_banner_elapsed += delta
		var a_in := clampf(_banner_elapsed / BANNER_FADE_IN_SECONDS, 0.0, 1.0)
		var a_out := clampf(_banner_t / BANNER_FADE_OUT_SECONDS, 0.0, 1.0)
		_banner.modulate.a = minf(a_in, a_out)
		_banner_sub_l.modulate.a = _banner.modulate.a * 0.8
		if _banner_compact():
			_banner_sub_l.offset_top = _banner_base_y + (1.0 - minf(a_in, 1.0)) * -14.0
			_banner_sub_l.offset_bottom = _banner_sub_l.offset_top + 22
		else:
			_banner.offset_top = _banner_base_y + (1.0 - minf(a_in, 1.0)) * -14.0
			_banner.offset_bottom = _banner.offset_top + 52
	else:
		_banner.modulate.a = 0.0
		_banner_sub_l.modulate.a = 0.0
		_show_next_hint()
	if player != null and is_instance_valid(player):
		_hp = player.hp
		_max_hp = player.max_hp
		var shield_mode := bool(player.prog.get("shield_mode", false))
		_shield_ready = shield_mode and player.shield_ready
		_meter = player.shield_meter if shield_mode else player.meter
		if _shield_ready:
			_meter = Balance.OC_METER_MAX
		_oc_ready = player.oc_ready
		_oc_active = player.overclock_active
		_dash_available = player.available_dash_charges()
		_dash_max = maxi(player.dash_charges, 1)
		if _dash_available > 0:
			_dash_frac = 1.0
		else:
			_dash_frac = clampf(1.0 - player.dash_cd / player.dash_cooldown_duration(), 0.0, 1.0)
	if _run_info_label != null and is_instance_valid(_run_info_label):
		var compact := bool(layout_snapshot()["compact"])
		_run_info_label.text = run_info_text() if Sfx.show_run_info and Game.state == Game.State.PLAYING and not compact else ""
	if _dash_icon != null and is_instance_valid(_dash_icon):
		var dash_rect: Rect2 = layout_snapshot()["dash"]
		_dash_icon.position = dash_rect.end - Vector2(64.0, 60.0)
		_dash_icon.visible = not _vnext_hud_mode and Balance.is_desktop_display() and not touch_layout()
		var dash_col := Balance.COL_PLAYER if _dash_frac >= 1.0 else Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.35)
		_dash_icon.call("configure", "dash", dash_col)
	_prune_boss_fragments()
	if _boss_split:
		_boss_frac = -1.0
	elif boss != null and is_instance_valid(boss):
		_boss_frac = float(boss.hp) / float(boss.max_hp)
		_boss_name = boss.boss_title + " // KERNEL DAEMON"
	else:
		_boss_frac = -1.0
	if _vnext_hud_surface != null and is_instance_valid(_vnext_hud_surface):
		_vnext_hud_surface.sync_from_hud(self, _damage_direction_label())
	queue_redraw()

func _damage_direction_label() -> String:
	if player == null or not is_instance_valid(player) or player.last_damage_direction_t <= 0.0:
		return "NONE"
	var direction: Vector2 = player.last_damage_direction
	if direction.length_squared() < 0.01:
		return "NONE"
	var labels := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
	return labels[posmod(int(round(direction.angle() / (PI / 4.0))), labels.size())]

func _integrity_state_label() -> String:
	if _hp <= 1:
		return "CRITICAL"
	if _hp * 2 <= maxi(_max_hp, 1):
		return "LOW"
	return "STABLE"

func _integrity_status_text() -> String:
	var text := "INTEGRITY // %s" % _integrity_state_label()
	var direction := _damage_direction_label()
	if direction != "NONE":
		text += " // HIT FROM %s" % direction
	return text

func _ability_status_text() -> String:
	var shield_mode := player != null and is_instance_valid(player) and bool(player.prog.get("shield_mode", false))
	if shield_mode:
		if _shield_ready:
			return "SHIELD READY"
		return "SHIELD CHARGING" if _meter > 0.0 else "SHIELD DOWN"
	if _oc_active:
		return "OVERCLOCK ACTIVE"
	if _oc_ready:
		return "OVERCLOCK READY"
	return "OVERCLOCK CHARGING"

func _dash_status_text() -> String:
	return "DASH // READY" if _dash_frac >= 1.0 else "DASH // COOLDOWN"

## Read-only state labels for accessibility and deterministic visual tests.
## These strings supplement the color/pulse treatment; they do not drive play.
func state_signal_snapshot() -> Dictionary:
	return {
		"integrity": _integrity_status_text(),
		"integrity_state": _integrity_state_label(),
		"damage_direction": _damage_direction_label(),
		"ability": _ability_status_text(),
		"dash": _dash_status_text(),
		"meter_state": "READY" if _ability_status_text().contains("READY") else ("ACTIVE" if _oc_active else "CHARGING"),
	}

func _input(event: InputEvent) -> void:
	# The HUD surface is scaled (window-px local space), so map event
	# positions into local coordinates before hit-testing patch chips.
	if event is InputEventMouseMotion:
		if DisplayServer.is_touchscreen_available():
			return
		var mouse_id := _patch_id_at(make_input_local(event).position)
		if mouse_id.is_empty():
			_dismiss_patch_tooltip()
		else:
			_show_patch_tooltip(mouse_id)
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_dismiss_patch_tooltip()
			var touch_id := _patch_id_at(make_input_local(event).position)
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
	if _vnext_hud_mode:
		return
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

func _draw_angular_panel(rect: Rect2, color: Color, fill_alpha: float = 0.08, combat: bool = false) -> void:
	var points := TacticalUIHelper.angular_points(rect, minf(12.0, rect.size.y * 0.22))
	draw_colored_polygon(points, TacticalUIHelper.panel_fill_color(combat))
	draw_colored_polygon(points, Color(color.r, color.g, color.b, fill_alpha))
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(color.r, color.g, color.b, 0.72), 1.4, true)

func _draw_tactical_shell(f: Font) -> void:
	var layout := layout_snapshot()
	var compact := bool(layout["compact"])
	var outer := TacticalUIHelper.shell_rect(size)
	var outer_points := TacticalUIHelper.angular_points(outer, 14.0)
	draw_polyline(outer_points + PackedVector2Array([outer_points[0]]), Color(_era_accent.r, _era_accent.g, _era_accent.b, 0.68), 1.25, true)
	draw_line(outer.position + Vector2(26.0, 7.0), outer.position + Vector2(170.0, 7.0), Color(_era_accent.r, _era_accent.g, _era_accent.b, 0.52), 1.0)
	draw_line(Vector2(outer.end.x - 170.0, outer.position.y + 7.0), Vector2(outer.end.x - 26.0, outer.position.y + 7.0), Color(_era_accent.r, _era_accent.g, _era_accent.b, 0.52), 1.0)
	draw_line(outer.position + Vector2(26.0, -7.0 + outer.size.y), outer.position + Vector2(170.0, outer.size.y - 7.0), Color(_era_accent.r, _era_accent.g, _era_accent.b, 0.52), 1.0)
	draw_line(Vector2(outer.end.x - 170.0, outer.end.y - 7.0), outer.end - Vector2(26.0, 7.0), Color(_era_accent.r, _era_accent.g, _era_accent.b, 0.52), 1.0)
	for corner in [Vector2(outer.position.x + 28.0, outer.position.y + 14.0), Vector2(outer.end.x - 28.0, outer.position.y + 14.0), Vector2(outer.position.x + 28.0, outer.end.y - 14.0), Vector2(outer.end.x - 28.0, outer.end.y - 14.0)]:
		draw_circle(corner, 2.0, Color(_era_accent.r, _era_accent.g, _era_accent.b, 0.82))
	var integrity_rect: Rect2 = layout["integrity"]
	var encounter_rect: Rect2 = layout["encounter"]
	var score_rect: Rect2 = layout["score"]
	var dash_rect: Rect2 = layout["dash"]
	var patch_rect: Rect2 = layout["patches"]
	_draw_angular_panel(integrity_rect, _era_accent, 0.055, true)
	_draw_angular_panel(encounter_rect, _era_accent, 0.045, true)
	_draw_angular_panel(score_rect, _era_accent, 0.055, true)
	if not touch_layout():
		_draw_angular_panel(dash_rect, _era_accent, 0.045, true)
	_draw_angular_panel(patch_rect, _era_accent, 0.045, true)
	var integrity_text := TacticalUIHelper.ellipsis_fit(f, _integrity_status_text(), maxf(integrity_rect.size.x - 32.0, 1.0), 12)
	draw_string(f, integrity_rect.position + Vector2(16.0, 22.0), integrity_text, HORIZONTAL_ALIGNMENT_LEFT, integrity_rect.size.x - 32.0, 12, TacticalUIHelper.TEXT)
	var cycle_label := "CYCLE %02d" % Game.wave
	draw_string(_score_font, encounter_rect.position + Vector2(0.0, 30.0 if compact else 38.0), cycle_label, HORIZONTAL_ALIGNMENT_CENTER, encounter_rect.size.x, 24 if compact else 32, TacticalUIHelper.TEXT)
	var encounter_label := _boss_name if not _boss_name.is_empty() else "PROCESS PURGE"
	draw_string(f, encounter_rect.position + Vector2(0.0, 50.0 if compact else 62.0), encounter_label, HORIZONTAL_ALIGNMENT_CENTER, encounter_rect.size.x, 11 if compact else 12, TacticalUIHelper.MUTED)
	draw_string(f, score_rect.position + Vector2(14.0, 22.0), "SCORE", HORIZONTAL_ALIGNMENT_LEFT, score_rect.size.x - 28.0, 12, _era_accent)
	draw_string(_score_font, score_rect.position + Vector2(14.0, 52.0), "%07d" % _score, HORIZONTAL_ALIGNMENT_RIGHT, score_rect.size.x - 28.0, 24 if compact else 28, TacticalUIHelper.TEXT)
	if event_log_visible():
		var event_rect := Rect2(score_rect.position.x, score_rect.end.y + 8.0, score_rect.size.x, 84.0)
		_draw_angular_panel(event_rect, _era_accent, 0.025, true)
		var event_y := event_rect.position.y + 18.0
		draw_string(f, Vector2(score_rect.position.x + 14.0, event_y), "EVENT LOG", HORIZONTAL_ALIGNMENT_LEFT, score_rect.size.x - 28.0, 12, _era_accent)
		var event_text_width := maxf(score_rect.size.x - 28.0, 0.0)
		var event_color := Color(TacticalUIHelper.MUTED.r, TacticalUIHelper.MUTED.g, TacticalUIHelper.MUTED.b, 0.82)
		for line in visible_event_lines(4, event_text_width, 11):
			event_y += 15.0
			draw_string(f, Vector2(score_rect.position.x + 14.0, event_y), line, HORIZONTAL_ALIGNMENT_LEFT, event_text_width, 11, event_color)

func _hp_pips(f: Font) -> void:
	var pips := hp_pip_rects(size, _max_hp)
	for i in pips.size():
		var pip: Rect2 = pips[i]
		var p := pip.get_center()
		var on := i < _hp
		var col := Balance.COL_PLAYER if on else Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.18)
		var s := pip.size.x * 0.5
		if on and _hp == 1:
			col.a = 0.6 + 0.4 * absf(sin(Time.get_ticks_msec() / 1000.0 * 5.0))
		var pts := PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0)])
		if on:
			draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.28))
		draw_polyline(pts + PackedVector2Array([pts[0]]), col, 2.0, true)
		if on:
			draw_circle(p, 2.5, col)

func _oc_bar(f: Font) -> void:
	var integrity_rect: Rect2 = layout_snapshot()["integrity"]
	var x := integrity_rect.position.x + 16.0
	var y := integrity_rect.position.y + integrity_rect.size.y - 34.0
	var r := Rect2(x, y, maxf(integrity_rect.size.x - 32.0, 80.0), 8.0)
	var shield_mode := player != null and is_instance_valid(player) and bool(player.prog.get("shield_mode", false))
	var col := TacticalUIHelper.LIME if shield_mode else (Balance.COL_PLAYER_HOT if _oc_active else Balance.COL_PLAYER)
	if _oc_ready and not _oc_active:
		var pulse := 0.5 + 0.5 * absf(sin(Time.get_ticks_msec() / 90.0))
		col.a = 0.6 + 0.4 * pulse
		draw_rect(r.grow(3.0 + 2.0 * pulse), Color(col.r, col.g, col.b, 0.10 + 0.08 * pulse))
	draw_rect(r, Color(col.r, col.g, col.b, 0.14))
	var frac := clampf(_meter / Balance.OC_METER_MAX, 0.0, 1.0)
	draw_rect(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), Color(col.r, col.g, col.b, 0.85))
	draw_rect(r, Color(col.r, col.g, col.b, 0.5), false, 1.2)
	var label := _ability_status_text()
	var txt_col := col
	if _oc_ready and not _oc_active and not shield_mode:
		if not touch_layout():
			label += " [E]"
	label = TacticalUIHelper.ellipsis_fit(f, label, maxf(r.size.x, 1.0), 11)
	draw_string(f, Vector2(x, y + 24.0), label, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 11, Color(txt_col.r, txt_col.g, txt_col.b, 0.85))
	if Game.patch_level("scrapdiet") > 0 and player != null and is_instance_valid(player):
		var thr: int = player._scrap_threshold()
		var sc := Color(1.0, 0.75, 0.4, 0.9)
		var scrap := scrap_layout(size)
		var scrap_bar: Rect2 = scrap["bar"]
		var scrap_label: Rect2 = scrap["label"]
		if scrap_bar.size.x > 1.0:
			draw_rect(scrap_bar, Color(sc.r, sc.g, sc.b, 0.14))
			var sfrac: float = clampf(float(player.scrap_count) / float(thr), 0.0, 1.0)
			draw_rect(Rect2(scrap_bar.position, Vector2(scrap_bar.size.x * sfrac, scrap_bar.size.y)), Color(sc.r, sc.g, sc.b, 0.8))
			var scrap_text := TacticalUIHelper.ellipsis_fit(f, "SCRAP %d/%d" % [player.scrap_count, thr], maxf(scrap_label.size.x, 1.0), 11)
			draw_string(f, scrap_label.position + Vector2(0.0, 13.0), scrap_text, HORIZONTAL_ALIGNMENT_LEFT, scrap_label.size.x, 11, sc)
	_patch_chips(f)

func _patch_chips(f: Font) -> void:
	_update_patch_chip_rects()
	var patch_rect: Rect2 = layout_snapshot()["patches"]
	draw_string(f, patch_rect.position + Vector2(14.0, 20.0), "PATCH STACK", HORIZONTAL_ALIGNMENT_LEFT, patch_rect.size.x - 28.0, 11, _era_accent)
	if _patch_chip_rects.is_empty():
		draw_string(f, patch_rect.position + Vector2(14.0, 48.0), "NO ACTIVE PATCHES", HORIZONTAL_ALIGNMENT_LEFT, patch_rect.size.x - 28.0, 11, TacticalUIHelper.MUTED)
		return
	for id in Game.patch_levels:
		var code: String = Game.PATCH_CODES.get(id, id.substr(0, 2).to_upper())
		var lvl := int(Game.patch_levels[id])
		var txt := "%s%d" % [code, lvl]
		var chip_rect: Rect2 = _patch_chip_rects[id]
		var chip_points := TacticalUIHelper.angular_points(chip_rect, minf(4.0, chip_rect.size.y * 0.25))
		draw_colored_polygon(chip_points, Color(Balance.COL_PLAYER.r, Balance.COL_PLAYER.g, Balance.COL_PLAYER.b, 0.10))
		draw_polyline(chip_points + PackedVector2Array([chip_points[0]]), Color(Balance.COL_PLAYER.r, Balance.COL_PLAYER.g, Balance.COL_PLAYER.b, 0.35), 1.0, true)
		draw_string(f, chip_rect.position + Vector2(0.0, chip_rect.size.y * 0.68), txt, HORIZONTAL_ALIGNMENT_CENTER, chip_rect.size.x, 10, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.82))

func _update_patch_chip_rects() -> void:
	_patch_chip_rects = patch_dock_rects(size)

func patch_dock_rects(viewport: Vector2 = size) -> Dictionary:
	var touch := touch_layout()
	var touch_scale := float(Sfx.touch_scale)
	var signature := _patch_dock_signature()
	if _patch_dock_cache_valid and viewport == _patch_dock_cache_viewport and touch == _patch_dock_cache_touch and is_equal_approx(touch_scale, _patch_dock_cache_touch_scale) and signature == _patch_dock_cache_signature:
		return _patch_dock_cache
	var result: Dictionary = {}
	if not Game.patch_levels.is_empty():
		var panel: Rect2 = layout_snapshot(viewport)["patches"]
		var ids: Array = Game.patch_levels.keys()
		var compact := bool(layout_snapshot(viewport)["compact"])
		var available := Rect2(panel.position + Vector2(12.0, 26.0), Vector2(maxf(panel.size.x - 24.0, 24.0), maxf(panel.size.y - 34.0, 12.0)))
		var gap := 4.0
		var max_columns := 5 if not compact else 4
		var columns := mini(max_columns, maxi(ids.size(), 1))
		var rows := ceili(float(ids.size()) / float(columns))
		var chip_w := maxf((available.size.x - gap * float(columns - 1)) / float(columns), 8.0)
		var chip_h := maxf((available.size.y - gap * float(rows - 1)) / float(rows), 8.0)
		for index in ids.size():
			var col := index % columns
			var row := index / columns
			result[ids[index]] = Rect2(available.position + Vector2(col * (chip_w + gap), row * (chip_h + gap)), Vector2(chip_w, chip_h))
	_patch_dock_cache_viewport = viewport
	_patch_dock_cache_touch = touch
	_patch_dock_cache_touch_scale = touch_scale
	_patch_dock_cache_signature = signature
	_patch_dock_cache = result
	_patch_dock_cache_valid = true
	_patch_dock_cache_builds += 1
	return _patch_dock_cache

func _patch_dock_signature() -> String:
	var parts: Array[String] = []
	for id in Game.patch_levels:
		parts.append("%s=%d" % [str(id), int(Game.patch_levels[id])])
	return "|".join(parts)

func _draw_patch_tooltip(f: Font) -> void:
	if not _tooltip_visible or _tooltip_data.is_empty() or not _patch_chip_rects.has(_tooltip_patch_id):
		return
	var width := minf(390.0, maxf(size.x - _safe_side_margin() * 2.0, 1.0))
	var height := 76.0
	var chip_rect: Rect2 = _patch_chip_rects[_tooltip_patch_id]
	var pos := chip_rect.position + Vector2(0, chip_rect.size.y + 8.0)
	if pos.y + height > size.y - 8.0:
		pos.y = chip_rect.position.y - height - 8.0
	pos.x = clampf(pos.x, _safe_side_margin(), maxf(_safe_side_margin(), size.x - width - _safe_side_margin()))
	var panel := Rect2(pos, Vector2(width, height))
	draw_rect(panel, Color(0.01, 0.02, 0.05, 0.96))
	draw_rect(panel, Color(Balance.COL_PLAYER.r, Balance.COL_PLAYER.g, Balance.COL_PLAYER.b, 0.8), false, 1.5)
	var copy := tooltip_text_snapshot(width)
	draw_string(f, pos + Vector2(10, 18), str(copy.get("title", "PATCH")), HORIZONTAL_ALIGNMENT_LEFT, width - 20.0, 13, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.92))
	draw_string(f, pos + Vector2(10, 36), str(copy.get("detail", "")), HORIZONTAL_ALIGNMENT_LEFT, width - 20.0, 11, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.88))
	draw_string(f, pos + Vector2(10, 57), str(copy.get("relation", "NO DIRECT INTERACTION")), HORIZONTAL_ALIGNMENT_LEFT, width - 20.0, 10, Color(Balance.COL_MOTE.r, Balance.COL_MOTE.g, Balance.COL_MOTE.b, 0.86))

func tooltip_text_snapshot(max_width: float = -1.0) -> Dictionary:
	if _tooltip_data.is_empty() or _mono == null:
		return {}
	var width := minf(390.0, maxf(size.x - _safe_side_margin() * 2.0, 1.0)) if max_width <= 0.0 else maxf(max_width, 1.0)
	var copy_width := maxf(width - 20.0, 1.0)
	return {
		"title": TacticalUIHelper.ellipsis_fit(_mono, str(_tooltip_data.get("title", "PATCH")), copy_width, 13),
		"detail": TacticalUIHelper.ellipsis_fit(_mono, "LEVEL %d // %s" % [int(_tooltip_data.get("level", 0)), str(_tooltip_data.get("description", ""))], copy_width, 11),
		"relation": TacticalUIHelper.ellipsis_fit(_mono, str(_tooltip_data.get("relation", "NO DIRECT INTERACTION")), copy_width, 10),
	}

func _mult_chip(f: Font) -> void:
	if _mult <= 1:
		return
	var c := Balance.COL_MOTE
	var pop := 1.0 + 0.25 * _score_pop
	var rx := size.x - _safe_side_margin()
	var combo_y := hud_top_y(78.0)
	draw_string(f, Vector2(rx - 140.0, combo_y), "COMBO x%d" % _mult, HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * pop), c)
	var bar := Rect2(rx - 140.0, combo_y + 6.0, 140, 4)
	draw_rect(bar, Color(c.r, c.g, c.b, 0.15))
	var hot := Color(Balance.COL_DANGER.r, Balance.COL_DANGER.g, Balance.COL_DANGER.b).lerp(c, _combo_frac)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _combo_frac, 4)), hot)

func _dash_pip(f: Font) -> void:
	if not Balance.is_desktop_display() or touch_layout():
		return
	var col := Balance.COL_PLAYER if _dash_frac >= 1.0 else Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.35)
	var dash_rect: Rect2 = layout_snapshot()["dash"]
	var dash_text := _dash_status_text()
	draw_string(f, dash_rect.position + Vector2(16.0, 28.0), dash_text, HORIZONTAL_ALIGNMENT_LEFT, dash_rect.size.x - 88.0, 13, Color(col.r, col.g, col.b, 0.82))
	var charge_text := ("x%d" % _dash_max) if _dash_max > 1 else ("[SHIFT]" if not touch_layout() else "x1")
	draw_string(f, dash_rect.position + Vector2(16.0, 52.0), charge_text, HORIZONTAL_ALIGNMENT_LEFT, dash_rect.size.x - 88.0, 11, Color(col.r, col.g, col.b, 0.68))
	var cooldown := Rect2(dash_rect.position + Vector2(16.0, dash_rect.size.y - 16.0), Vector2(maxf(dash_rect.size.x - 32.0, 50.0), 4.0))
	draw_rect(cooldown, Color(col.r, col.g, col.b, 0.16))
	draw_rect(Rect2(cooldown.position, Vector2(cooldown.size.x * _dash_frac, cooldown.size.y)), Color(col.r, col.g, col.b, 0.76))

func _boss_bar(f: Font) -> void:
	var region: Rect2 = layout_snapshot()["boss"]
	var r: Rect2 = boss_bar_rects(size, false)[0]
	var col := Balance.COL_DANGER
	_draw_angular_panel(region, col, 0.045)
	draw_rect(r, Color(col.r, col.g, col.b, 0.15))
	var segs := 20
	var filled := int(ceil(_boss_frac * segs))
	for i in segs:
		var seg := Rect2(r.position.x + i * (r.size.x / segs) + 1, r.position.y, r.size.x / segs - 2, r.size.y)
		if i < filled:
			draw_rect(seg, Color(col.r, col.g, col.b, 0.9))
		else:
			draw_rect(seg, Color(col.r, col.g, col.b, 0.12))
	draw_string(f, Vector2(region.position.x, boss_title_baseline()), _boss_name, HORIZONTAL_ALIGNMENT_CENTER, region.size.x, 12, Color(col.r, col.g, col.b, 0.9))

func _boss_split_bar(f: Font) -> void:
	var region: Rect2 = layout_snapshot()["boss"]
	var rows := boss_bar_rects(size, true)
	var live_rows := boss_split_rows_snapshot()
	if live_rows.is_empty():
		return
	var col := Balance.COL_DANGER
	_draw_angular_panel(region, col, 0.045)
	for display_index in mini(live_rows.size(), rows.size()):
		var row: Rect2 = rows[display_index]
		var row_data: Dictionary = live_rows[display_index]
		var label := str(row_data.get("label", "MINI"))
		draw_string(f, Vector2(region.position.x, row.position.y + row.size.y), label, HORIZONTAL_ALIGNMENT_LEFT, 58.0, 10, Color(col.r, col.g, col.b, 0.9))
		draw_rect(row, Color(col.r, col.g, col.b, 0.12))
		var frac := float(row_data.get("fraction", 0.0))
		var filled := clampi(int(ceilf(frac * 20.0)), 0, 20)
		for i in 20:
			var seg := Rect2(row.position.x + i * (row.size.x / 20.0) + 1.0, row.position.y, row.size.x / 20.0 - 2.0, row.size.y)
			if i < filled:
				draw_rect(seg, Color(col.r, col.g, col.b, 0.9))
			else:
				draw_rect(seg, Color(col.r, col.g, col.b, 0.12))
	draw_string(f, Vector2(region.position.x, boss_title_baseline()), _boss_name, HORIZONTAL_ALIGNMENT_CENTER, region.size.x, 12, Color(col.r, col.g, col.b, 0.9))

func set_era_accent(color: Color) -> void:
	if color == _era_accent:
		return
	_era_accent = color
	queue_redraw()

func era_accent() -> Color:
	return _era_accent

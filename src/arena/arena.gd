class_name Arena
extends Node2D

const PatchCard = preload("res://src/ui/patch_card.gd")
const VNextPatchScript = preload("res://src/ui/vnext/surfaces/patch_surface.gd")
const TacticalStateSurfaceHelper = preload("res://src/ui/tactical_state_surface.gd")
const TacticalChromeScript = preload("res://src/ui/tactical_chrome.gd")
const TacticalIconScript = preload("res://src/ui/tactical_icon.gd")
const PauseInputRouterScript = preload("res://src/arena/pause_input_router.gd")
const PanelKitScript = preload("res://src/arena/panel_kit.gd")
const IntroKitScript = preload("res://src/arena/intro_kit.gd")
const StageKitScript = preload("res://src/arena/stage_kit.gd")
const VNextPauseScript = preload("res://src/ui/vnext/surfaces/pause_surface.gd")
const VNextTerminalScript = preload("res://src/ui/vnext/surfaces/terminal_surface.gd")
const VNextGameOverScript = preload("res://src/ui/vnext/surfaces/game_over_surface.gd")
const VNextTokens = preload("res://src/ui/vnext/ui_tokens.gd")

var player: Player
var cam: CameraRig
var spawner: Spawner
var hud: Hud
var overlay: ArenaOverlay
var walls: ArenaWalls
var enemy_container: Node2D
var mote_container: Node2D
var mote_field: MoteField
var enemy_list: Array = []
var quality_tier := 0
var _fps_accum := 0.0
var _fps_time := 0.0
var _state := "play"
var _pause_panel: Control
var _pause_stats: Label
var _over_panel: Control
var _over_stats: Label
var _over_core_stats: Label
var _over_run_stats: Label
var _over_title: Label
var _over_sub: Label
var _over_primary: Button
var _over_menu: Button
var _over_heatmap: Control
var _story_stage: Dictionary = {}
var _story_intro_panel: Control
var _story_intro_path: Label
var _story_intro_title: Label
var _story_intro_text: Label
var _story_victory := false
var _story_next_stage := -1
var _crt_overlay: CrtOverlay
var _windows_watermark: Label
var _temple_mode := false
var _intro_bars: Array[ColorRect] = []
var _intro_label: Label
var _intro_quote: Label
var touch: TouchControls
var reticle: Reticle
var _patch_panel: Control
var _patch_box: HBoxContainer
var _vnext_patch_surface: Control
var _vnext_patch_mode := false
var _patch_offers: Array = []
var _patch_open := false
var _patch_pending := 0
var _boss_fragments_pending := 0
var _boss_phase_clear_done := false
var _boss_rewards_claimed := {}
var wave_signal_count := 0
const ABANDON_CONFIRM_WINDOW := 2.0
const PAUSE_CONFIRM_MIN_INTERVAL := 0.5
const PAUSE_INFO_DEFAULT := "[ESC] RESUME      [R] ARM RESTART      [Q] ARM ABANDON PROCESS"
const PAUSE_INFO_RESTART_CONFIRM := "[ESC] RESUME      [R] PRESS R AGAIN // RESTART RUN"
const PAUSE_INFO_CONFIRM := "[ESC] RESUME      [R] ARM RESTART      [Q] PRESS Q AGAIN // ABANDON PROCESS"
const PANEL_REFERENCE_HEIGHT := 720.0
const PANEL_CONTENT_HEIGHT := 500.0
const PANEL_SAFE_MARGIN := 16.0
const PATCH_MAX_WIDTH := 930.0
const PATCH_BOX_HEIGHT := 295.0
var _abandon_armed := false
var _abandon_t := 0.0
var _abandon_timer: SceneTreeTimer
var _abandon_generation := 0
var _restart_armed := false
var _pause_destructive_action := ""
var _pause_destructive_started_msec := 0
var _pause_info: Label
var _pause_title: Label
var _pause_buttons: Array[Button] = []
var _pause_volume_rows: Array[Control] = []
var _debug_panel: Control
var _terminal_panel: Control
var _vnext_u4_surface: Control
var _vnext_u4_layer: CanvasLayer
var _vnext_u4_mode := false
var _vnext_u4_view := ""
var _dust: CPUParticles2D
var _restart_hold_t := 0.0
var _restart_triggered := false
var _panel_kit
var _intro_kit
var _stage_kit
const RESTART_HOLD_DURATION := 0.75

func _ready() -> void:
	add_to_group("arena")
	if is_inside_tree():
		get_window().size_changed.connect(_on_vnext_window_size_changed)
	_panel_kit = PanelKitScript.new(self)
	_intro_kit = IntroKitScript.new(self)
	_stage_kit = StageKitScript.new(self)
	if Game.mode == "story":
		var opening_stage := Game.story_stage_def(Game.story_stage_index)
		var opening_size = opening_stage.get("arena_size", Vector2.ZERO)
		if opening_size is Vector2 and opening_size.x > 0.0 and opening_size.y > 0.0:
			Balance.set_arena_size_override(opening_size)
	_stage_kit._build_background()
	walls = ArenaWalls.new()
	add_child(walls)
	mote_container = Node2D.new()
	add_child(mote_container)
	mote_field = MoteField.new()
	mote_container.add_child(mote_field)
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
	_panel_kit._build_pause_panel()
	_panel_kit._build_terminal_panel()
	_panel_kit._build_game_over_panel()
	_build_vnext_u4()
	_intro_kit._build_intro()
	if Game.mode == "story":
		_story_stage = Game.story_stage_def(Game.story_stage_index)
		_intro_kit._build_story_intro()
		_intro_kit._apply_story_theme(_story_stage.get("theme", {}))
		_stage_kit._build_windows_visuals()
		_stage_kit._build_temple_visuals()
		_stage_kit._build_macos_visuals()
	if debug_controls_enabled():
		var debug_panel = load("res://src/ui/debug_panel.gd").new()
		debug_panel.arena = self
		_debug_panel = debug_panel
		var debug_layer := CanvasLayer.new()
		debug_layer.layer = 80
		debug_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		debug_layer.add_child(_debug_panel)
		add_child(debug_layer)
	if DisplayServer.is_touchscreen_available() or OS.get_environment("KP_FORCE_TOUCH") != "":
		touch = TouchControls.new()
		touch.set_anchors_preset(Control.PRESET_FULL_RECT)
		touch.player = player
		touch.arena = self
		var tcl := CanvasLayer.new()
		tcl.layer = 30
		tcl.add_child(touch)
		add_child(tcl)
	if (Balance.is_desktop_display() and not DisplayServer.is_touchscreen_available()) or OS.get_environment("KP_FORCE_RETICLE") != "":
		var rl := CanvasLayer.new()
		rl.layer = 85
		reticle = Reticle.new()
		reticle.player = player
		rl.add_child(reticle)
		add_child(rl)
	spawner.wave_started.connect(_on_wave_started)
	spawner.wave_cleared.connect(_on_wave_cleared)
	spawner.boss_spawned.connect(_on_boss_spawned)
	spawner.story_cleared.connect(_on_story_cleared)
	if Game.mode == "story":
		_intro_kit._show_story_intro.call_deferred()
	else:
		var first_wave := Game.practice_wave if Game.mode == "practice" else 1
		spawner.start(self, enemy_container, first_wave)
	enemy_container.child_entered_tree.connect(_on_enemy_child)
	enemy_container.child_exiting_tree.connect(_on_enemy_exit)
	player.hp_changed.connect(_on_player_hp)
	player.died.connect(_on_player_died)
	Game.combo_milestone.connect(_on_combo_milestone)
	Game.patch_picked.connect(_apply_patch_effects)
	Game.bestiary_unlocked.connect(_on_bestiary_unlocked)
	Sfx.play_music()
	Fx.flash(Color(0, 0, 0), 1.0, 0.6)
	_queue_hint("move", "MOVE // WASD OR TOUCH")
	_queue_hint("dash", "DASH // SPACE / SHIFT")
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
	var hint_y := maxf(90.0, get_viewport_rect().size.y - 160.0)
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
		l.offset_top = hint_y
		l.offset_bottom = hint_y + 30.0
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
		Game.mark_bestiary_for_enemy(n)
		_route_enemy_hint(n)

func _queue_hint(id: String, text: String) -> void:
	if hud != null and Game.show_hint_once(id):
		hud.queue_hint(id, text)

func _route_enemy_hint(enemy: EnemyBase) -> void:
	if enemy is LancerEnemy:
		_queue_hint("lancer", "SIDESTEP THE LINE")
	elif enemy is SpewerEnemy:
		_queue_hint("spewer", "SHOOT THE ORBS DOWN")
	elif enemy is SplitterEnemy:
		_queue_hint("splitter", "KILL IT AWAY FROM YOU")
	elif enemy is BulwarkEnemy:
		_queue_hint("dash", "DASH // SPACE / SHIFT")
	elif enemy_list.size() == 1:
		_queue_hint("move", "MOVE // WASD OR TOUCH")

func _on_enemy_exit(n: Node) -> void:
	enemy_list.erase(n)

func _physics_process(_delta: float) -> void:
	EnemyBase.shared_list = enemy_list

func debug_controls_enabled() -> bool:
	return OS.is_debug_build() and Balance.is_desktop_display() and not DisplayServer.is_touchscreen_available() and OS.get_environment("KP_FORCE_TOUCH") == ""

func debug_skip_to_wave(target_wave: int) -> bool:
	if not debug_controls_enabled() or spawner == null:
		return false
	return spawner.debug_skip_to_wave(target_wave)

func debug_spawn_enemy(kind: String) -> EnemyBase:
	if not debug_controls_enabled() or spawner == null:
		return null
	return spawner.debug_spawn_enemy(kind)

func debug_spawn_boss(index: int) -> RootBoss:
	if not debug_controls_enabled() or spawner == null:
		return null
	return spawner.debug_spawn_boss(index)

func debug_spawn_root_split() -> bool:
	if not debug_controls_enabled() or spawner == null:
		return false
	return spawner.debug_spawn_root_split()

func debug_clear_combatants() -> bool:
	if not debug_controls_enabled() or spawner == null:
		return false
	spawner.debug_clear_encounter()
	return true

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

func patch_box_rect_for_viewport(viewport_size: Vector2) -> Rect2:
	var horizontal_margin := clampf(viewport_size.x * 0.04, 16.0, 48.0)
	var width := minf(PATCH_MAX_WIDTH, maxf(0.0, viewport_size.x - horizontal_margin * 2.0))
	var height := minf(PATCH_BOX_HEIGHT, maxf(180.0, viewport_size.y - 2.0 * PANEL_SAFE_MARGIN))
	var max_top := maxf(PANEL_SAFE_MARGIN, viewport_size.y - PANEL_SAFE_MARGIN - height)
	var top := clampf(viewport_size.y * 0.32, PANEL_SAFE_MARGIN, max_top)
	return Rect2((viewport_size.x - width) * 0.5, top, width, height)

func patch_card_rects_for_viewport(viewport_size: Vector2) -> Array[Rect2]:
	var box := patch_box_rect_for_viewport(viewport_size)
	var separation := clampf(box.size.x * 0.026, 10.0, 24.0)
	var card_width := maxf(0.0, (box.size.x - separation * 2.0) / 3.0)
	var rects: Array[Rect2] = []
	for i in 3:
		rects.append(Rect2(box.position.x + i * (card_width + separation), box.position.y, card_width, box.size.y))
	return rects

func _layout_patch_box() -> void:
	if _patch_box == null or not is_instance_valid(_patch_box):
		return
	var box := patch_box_rect_for_viewport(get_viewport_rect().size)
	_patch_box.anchor_left = 0.5
	_patch_box.anchor_right = 0.5
	_patch_box.anchor_top = 0.0
	_patch_box.anchor_bottom = 0.0
	_patch_box.offset_left = -box.size.x * 0.5
	_patch_box.offset_right = box.size.x * 0.5
	_patch_box.offset_top = box.position.y
	_patch_box.offset_bottom = box.end.y
	var separation := clampf(box.size.x * 0.026, 10.0, 24.0)
	_patch_box.add_theme_constant_override("separation", separation)
	var card_width := maxf(0.0, (box.size.x - separation * 2.0) / 3.0)
	for card in _patch_box.get_children():
		if card is Control:
			card.custom_minimum_size = Vector2(card_width, maxf(160.0, box.size.y - 20.0))
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _refresh_responsive_layout(viewport_height: float = -1.0) -> void:
	_panel_kit._layout_pause_panel()
	for panel in [_pause_panel, _over_panel, _patch_panel]:
		if panel == null or not is_instance_valid(panel):
			continue
		for control in panel.get_children():
			if control is Control and control.has_meta("panel_design_top"):
				_panel_kit._center_panel_control(control, float(control.get_meta("panel_design_top")), float(control.get_meta("panel_control_height")), viewport_height)
	_layout_patch_box()

func _refresh_responsive_layout_for_height(viewport_height: float) -> void:
	_refresh_responsive_layout(viewport_height)

func panel_scale_for_height(viewport_height: float = -1.0) -> float:
	return _panel_kit.panel_scale_for_height(viewport_height)


func panel_control_rect(design_top: float, control_height: float, viewport_height: float = -1.0) -> Rect2:
	return _panel_kit.panel_control_rect(design_top, control_height, viewport_height)


func state_panel_rect(viewport: Vector2, design_top: float = 0.0, control_size: Vector2 = Vector2.ZERO) -> Rect2:
	return _panel_kit.state_panel_rect(viewport, design_top, control_size)


func state_action_rects(viewport: Vector2, count: int) -> Array[Rect2]:
	return _panel_kit.state_action_rects(viewport, count)


func pause_action_labels() -> Array[String]:
	return _panel_kit.pause_action_labels()


func pause_action_icon_kinds() -> Array[String]:
	return _panel_kit.pause_action_icon_kinds()

func combat_snapshot() -> Dictionary:
	var required := ["state", "wave", "score", "player", "enemies", "spawner"]
	var optional := ["boss", "patch_offers", "arena_rect", "palette"]
	var enemies: Array = []
	for enemy in enemy_list:
		if not is_instance_valid(enemy):
			continue
		enemies.append({"id": str(enemy.display_name).to_lower(), "hp": int(enemy.hp), "max_hp": int(enemy.max_hp), "elite": bool(enemy.elite), "position": _snapshot_vector(enemy.global_position), "color": enemy.col.to_html(false)})
	var player_snapshot := {}
	if player != null and is_instance_valid(player):
		player_snapshot = {"hp": int(player.hp), "max_hp": int(player.max_hp), "meter": float(player.meter), "overclock_active": bool(player.overclock_active), "dash_available": int(player.dash_available), "position": _snapshot_vector(player.global_position)}
	var spawner_snapshot := {}
	if spawner != null and is_instance_valid(spawner):
		spawner_snapshot = {"wave": int(spawner.wave), "event": str(spawner.wave_event), "pending": int(spawner._pending), "running": bool(spawner._running)}
	var patch_offers: Array = []
	for raw_offer in _patch_offers:
		if raw_offer is Dictionary:
			patch_offers.append(_snapshot_patch_offer(raw_offer))
	var snapshot := {
		"schema_version": 1,
		"owner": "Arena",
		"required_fields": required.duplicate(true),
		"optional_fields": optional.duplicate(true),
		"state": str(_state),
		"wave": int(Game.wave),
		"score": int(Game.score),
		"player": player_snapshot,
		"enemies": enemies,
		"spawner": spawner_snapshot,
		"boss": {"name": str(hud._boss_name), "fraction": float(hud._boss_frac)} if hud != null and is_instance_valid(hud) else {},
		"patch_offers": patch_offers,
		"arena_rect": _snapshot_rect(Balance.arena_rect()),
		"palette": {"accent": _era_color.to_html(false), "danger": Balance.COL_DANGER.to_html(false)},
	}
	for field in required:
		assert(snapshot.has(field), "Arena combat_snapshot missing required field: " + str(field))
	return snapshot.duplicate(true)

func _snapshot_vector(value: Vector2) -> Dictionary:
	return {"x": float(value.x), "y": float(value.y)}

func _snapshot_rect(value: Rect2) -> Dictionary:
	return {"x": float(value.position.x), "y": float(value.position.y), "width": float(value.size.x), "height": float(value.size.y)}

func _snapshot_patch_offer(definition: Dictionary) -> Dictionary:
	var id := str(definition.get("id", ""))
	var level := Game.patch_level(id)
	var max_level := int(definition.get("max", 0))
	var relation := str(definition.get("relation", ""))
	if relation.is_empty():
		for active_id in Game.patch_levels.keys():
			if str(active_id) == id:
				continue
			var candidate := Game.patch_relation(id, str(active_id))
			if candidate != "NO DIRECT INTERACTION":
				relation = candidate
				break
	if relation == "NO DIRECT INTERACTION":
		relation = ""
	var state := str(definition.get("state", ""))
	if state.is_empty():
		state = "locked" if bool(definition.get("locked", false)) else "unavailable" if not bool(definition.get("available", true)) or (max_level > 0 and level >= max_level) else ("conflict" if not relation.is_empty() else "ready")
	var available := bool(definition.get("available", true))
	if state in ["locked", "unavailable"]:
		available = false
	var before_build := Game.build_string()
	var projected_levels: Dictionary = Game.patch_levels.duplicate(true)
	projected_levels[id] = level + 1
	var after_parts: Array[String] = []
	for projected_id in projected_levels:
		after_parts.append("%s%d" % [Game.PATCH_CODES.get(projected_id, str(projected_id).substr(0, 2).to_upper()), int(projected_levels[projected_id])])
	var after_build := " ".join(after_parts) if not after_parts.is_empty() else "NO PATCHES"
	var reason := str(definition.get("reason", ""))
	if reason.is_empty():
		reason = "MAX LEVEL REACHED" if state == "unavailable" else (relation if state == "conflict" else "UNLOCK CONDITION NOT MET" if state == "locked" else "")
	return {
		"id": id,
		"title": str(definition.get("title", id.to_upper())),
		"description": str(definition.get("description", definition.get("desc", ""))),
		"effect": str(definition.get("effect", definition.get("description", definition.get("desc", "")))),
		"benefit": str(definition.get("benefit", definition.get("description", definition.get("desc", "")))),
		"cost_benefit": str(definition.get("cost_benefit", "COST // NONE   BENEFIT // %s" % str(definition.get("description", definition.get("desc", ""))))),
		"build_impact": str(definition.get("build_impact", "BEFORE // %s   AFTER // %s" % [before_build, after_build])),
		"level": level,
		"max": max_level,
		"rare": bool(definition.get("rare", false)),
		"legend": bool(definition.get("legend", false)),
		"relation": relation,
		"state": state,
		"available": available,
		"reason": reason,
	}


func handle_pause_input(event: InputEvent) -> bool:
	if _vnext_u4_mode and _vnext_u4_surface != null and is_instance_valid(_vnext_u4_surface) and _vnext_u4_surface.visible:
		return _vnext_u4_surface.handle_input(event)
	return _panel_kit.handle_pause_input(event)


func game_over_action_labels() -> Array[String]:
	return _panel_kit.game_over_action_labels()


const STORY_INTRO_FADE_IN := 0.35
const STORY_INTRO_MIN_HOLD := 0.8
const STORY_INTRO_AUTO_DISMISS := 8.0
const STORY_INTRO_FADE_OUT := 0.5
const STORY_INTRO_MAX_HEIGHT := 216.0
const STORY_INTRO_FONT_FLOOR := 12

var _story_intro_state := 0 # 0 = off, 1 = fade in, 2 = hold, 3 = fade out
var _story_intro_t := 0.0
var _story_intro_hint: Label = null
var _story_spawn_started := false

func story_intro_active() -> bool:
	return _intro_kit.story_intro_active()


func dismiss_story_intro() -> bool:
	return _intro_kit.dismiss_story_intro()


func show_event_banner(txt: String) -> void:
	_intro_kit.show_event_banner(txt)


func windows_stage_profile() -> Dictionary:
	return _stage_kit.windows_stage_profile()


func temple_stage_profile() -> Dictionary:
	return _stage_kit.temple_stage_profile()


func background_corruption_for_wave(target_wave: int) -> float:
	return _stage_kit.background_corruption_for_wave(target_wave)


func _on_wave_started(wave: int, is_boss: bool) -> void:
	if Game.mode == "story":
		_on_story_wave_started(wave, is_boss)
		return
	wave_signal_count += 1
	Game.wave = wave
	Game.stats["wave"] = wave
	walls.pulse()
	_era_color = Balance.era_color(wave)
	if hud != null:
		hud.set_era_accent(_era_color)
	walls.set_tint(_era_color)
	if _bg_mat != null:
		_bg_mat.set_shader_parameter("corruption", _stage_kit.background_corruption_for_wave(wave))
	Game.log_event("CYCLE %02d START" % wave)
	if is_boss:
		Game.log_event("ANOMALY INBOUND // %s" % RootBoss.title_for_index(int(Game.wave / float(Balance.BOSS_EVERY))))
		hud.show_banner("CYCLE %02d // ANOMALY" % wave, "ROOT DAEMON INBOUND", 2.2)
		Sfx.play("boss", 1.0, 0.0)
		_intro_kit._run_boss_intro()
	else:
		hud.show_banner("CYCLE %02d" % wave, "PURGE THE DAEMONS", 1.8)
		Sfx.play("wave", 1.0 + wave * 0.01, -6.0)
	if wave >= 5 and not Game.unlocked_programs.has("daemon"):
		Game.unlock_program("daemon")
		hud.show_banner("PROGRAM UNLOCKED", "DAEMON AVAILABLE IN SETTINGS", 2.4)
		Sfx.play("ready", 1.2, -4.0)
	if wave > 1 and (wave - 1) % Balance.HEAL_EVERY == 0 and player.hp < player.max_hp:
		player.heal(1)
		Game.register_heal("cycle")
		Fx.text(player.global_position + Vector2(0, -30), "+INTEGRITY", Balance.COL_PLAYER, 14)

func _on_story_wave_started(current_wave: int, is_boss: bool) -> void:
	wave_signal_count += 1
	Game.wave = current_wave
	Game.stats["wave"] = current_wave
	walls.pulse()
	_intro_kit._apply_story_theme(_story_stage.get("theme", {}))
	Game.log_event("STORY // %s // WAVE %02d START" % [_story_stage.get("path", ""), current_wave])
	if is_boss:
		Game.log_event("STORY BOSS INBOUND // %s" % _story_stage.get("boss", "ROOT DAEMON"))
		hud.show_banner("%s // FINAL WAVE" % _story_stage.get("path", ""), str(_story_stage.get("boss", "ROOT DAEMON")), 2.2)
		Sfx.play("boss", 1.0, 0.0)
	else:
		hud.show_banner("%s // WAVE %02d" % [_story_stage.get("path", ""), current_wave], "PURGE THE DAEMONS", 1.8)
		Sfx.play("wave", 1.0 + current_wave * 0.01, -6.0)
	if current_wave > 1 and (current_wave - 1) % Balance.HEAL_EVERY == 0 and player.hp < player.max_hp:
		player.heal(1)
		Game.register_heal("story")
		Fx.text(player.global_position + Vector2(0, -30), "+INTEGRITY", Balance.COL_PLAYER, 14)

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
	if Game.mode == "story":
		_on_story_wave_cleared(wave)
		return
	hud.show_banner("CYCLE %02d CLEAR" % wave, "+%d // NEXT: %s" % [wave * 25, spawner.preview_next()], 2.2)
	Game.add_score(wave * 25)
	Sfx.play("ui", 1.3, -6.0)
	if mote_field != null and is_instance_valid(mote_field):
		mote_field.collect_all()
	_show_tip()
	if Game.should_offer_patch(wave):
		offer_patch()

func _on_story_wave_cleared(current_wave: int) -> void:
	var klog: Array = _story_stage.get("klog", [])
	var line := str(klog[(current_wave - 1) % klog.size()]) if not klog.is_empty() else "wave complete"
	hud.show_banner("%s // WAVE %02d CLEAR" % [_story_stage.get("path", ""), current_wave], "KLOG // " + line, 2.2)
	Game.log_event("KLOG // " + line)
	Game.add_score(current_wave * 50)
	Sfx.play("ui", 1.3, -6.0)
	if mote_field != null and is_instance_valid(mote_field):
		mote_field.collect_all()
	_show_tip()

func _on_story_cleared(stage_id: String) -> void:
	if Game.mode != "story" or _state != "play":
		return
	_state = "story_complete"
	if not Game.complete_story_stage():
		_show_story_save_failure(stage_id)
		return
	_show_story_victory(stage_id)

func _show_story_save_failure(stage_id: String) -> void:
	_story_victory = false
	_story_next_stage = -1
	_over_title.text = "STORY SAVE FAILED"
	_over_title.add_theme_color_override("font_color", Balance.COL_DANGER)
	_over_sub.text = "%s // progress not committed" % str(_story_stage.get("path", stage_id))
	_over_core_stats.text = "NO REWARD GRANTED\n\nThe run ended, but the story checkpoint could not be written.\nRetry the stage or return to story select."
	_over_run_stats.text = "STAGE SCORE      %07d\nDAEMONS PURGED   %d" % [Game.score, int(Game.stats.get("kills", 0))]
	_over_primary.text = "RETRY STAGE  [ENTER]"
	_over_menu.text = "STORY SELECT  [ESC]"
	_over_panel.modulate.a = 0.0
	_over_panel.visible = true
	if _vnext_u4_mode:
		_over_panel.visible = false
		_show_vnext_u4_game_over(false)
	var tw := create_tween()
	tw.tween_property(_over_panel, "modulate:a", 1.0, 0.45)


func _show_tip() -> void:
	if _tip_label == null:
		_tip_label = _panel_kit._make_label("", 13, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.0))
		_panel_kit._center_panel_control(_tip_label, 612.0, 28.0)
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
	_vnext_patch_mode = OS.get_environment("KP_VNEXT_PATCH") == "1"
	if _vnext_patch_mode:
		_vnext_patch_surface = VNextPatchScript.new()
		_vnext_patch_surface.set_anchors_preset(Control.PRESET_FULL_RECT)
		_vnext_patch_surface.visible = false
		_vnext_patch_surface.action_requested.connect(_on_vnext_patch_action)
		_patch_panel = _vnext_patch_surface
		var vnext_layer := CanvasLayer.new()
		vnext_layer.layer = 65
		vnext_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		vnext_layer.add_child(_vnext_patch_surface)
		add_child(vnext_layer)
		return
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
	_panel_kit._center_panel_control(title, 130.0, 50.0)
	_patch_panel.add_child(title)
	var sub := Label.new()
	sub.text = "SELECT ONE // [1] [2] [3]"
	sub.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.55))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.anchor_left = 0.0
	sub.anchor_right = 1.0
	_panel_kit._center_panel_control(sub, 182.0, 24.0)
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
	_layout_patch_box()
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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_patch_offers = Game.roll_patch_offer()
	if _patch_offers.is_empty():
		_patch_open = false
		return
	get_tree().paused = true
	if _vnext_patch_mode:
		var patch_snapshot: Array = []
		for definition in _patch_offers:
			patch_snapshot.append(_snapshot_patch_offer(definition))
		var viewport_size := _vnext_layout_viewport()
		var touch_input := DisplayServer.is_touchscreen_available() or OS.get_environment("KP_FORCE_TOUCH") != ""
		_fit_vnext_surface(_vnext_patch_surface, viewport_size)
		_vnext_patch_surface.configure({
			"offers": patch_snapshot,
			"active_ids": Game.patch_levels.keys(),
			"build": Game.build_string(),
			"paused": true,
		}, VNextPatchScript.context_for_viewport(viewport_size, touch_input))
		_vnext_patch_surface.visible = true
		return
	for c in _patch_box.get_children():
		c.queue_free()
	for i in _patch_offers.size():
		_patch_box.add_child(_make_patch_card(_patch_offers[i], i))
	_layout_patch_box()
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

func _make_patch_card(def: Dictionary, idx: int) -> Control:
	var card: Control = PatchCard.new()
	card.custom_minimum_size = Vector2(280.0, 330.0)
	card.configure(def, idx)
	card.selected.connect(func(selected_idx: int) -> void:
		_pick_patch(selected_idx)
	)
	return card

func vnext_patch_enabled() -> bool:
	return _vnext_patch_mode

func vnext_hud_enabled() -> bool:
	return hud != null and is_instance_valid(hud) and hud.vnext_hud_enabled()

func vnext_hud_surface() -> Control:
	return hud.vnext_hud_surface() if hud != null and is_instance_valid(hud) else null

func vnext_patch_surface() -> Control:
	return _vnext_patch_surface

func vnext_patch_visible() -> bool:
	return _patch_open and _vnext_patch_surface != null and is_instance_valid(_vnext_patch_surface) and _vnext_patch_surface.visible

func _vnext_layout_viewport() -> Vector2:
	var window_size := Vector2(get_window().size)
	if window_size.x < 320.0 or window_size.y < 240.0:
		var viewport_size := get_viewport_rect().size
		return viewport_size if viewport_size.x >= 320.0 and viewport_size.y >= 240.0 else VNextTokens.BASE_VIEWPORT
	return window_size

func _fit_vnext_surface(surface: Control, layout_viewport: Vector2) -> void:
	if surface == null or layout_viewport.x < 1.0 or layout_viewport.y < 1.0:
		return
	var logical_size := get_viewport_rect().size
	var fit_scale := minf(logical_size.x / layout_viewport.x, logical_size.y / layout_viewport.y)
	if fit_scale <= 0.0:
		fit_scale = 1.0
	surface.set_anchors_preset(Control.PRESET_TOP_LEFT)
	surface.position = Vector2.ZERO
	surface.size = layout_viewport
	surface.scale = Vector2.ONE * fit_scale

func _prepare_vnext_surface(surface: Control) -> void:
	if surface == null or not is_instance_valid(surface):
		return
	var viewport_size := _vnext_layout_viewport()
	_fit_vnext_surface(surface, viewport_size)
	if surface.has_method("reflow_for_viewport"):
		surface.reflow_for_viewport(viewport_size)

func _on_vnext_window_size_changed() -> void:
	if _vnext_patch_surface != null and is_instance_valid(_vnext_patch_surface) and _patch_open:
		_prepare_vnext_surface(_vnext_patch_surface)
	if _vnext_u4_surface != null and is_instance_valid(_vnext_u4_surface) and _vnext_u4_surface.visible:
		_prepare_vnext_surface(_vnext_u4_surface)

func vnext_u4_enabled() -> bool:
	return _vnext_u4_mode

func vnext_u4_surface() -> Control:
	return _vnext_u4_surface

func vnext_u4_visible() -> bool:
	return _vnext_u4_surface != null and is_instance_valid(_vnext_u4_surface) and _vnext_u4_surface.visible

func _build_vnext_u4() -> void:
	_vnext_u4_mode = OS.get_environment("KP_VNEXT_U4") == "1"
	if not _vnext_u4_mode:
		return
	_vnext_u4_surface = VNextPauseScript.new()
	_fit_vnext_surface(_vnext_u4_surface, _vnext_layout_viewport())
	_vnext_u4_surface.visible = false
	_vnext_u4_surface.action_requested.connect(_on_vnext_u4_action)
	var layer := CanvasLayer.new()
	layer.layer = 90
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_vnext_u4_layer = layer
	layer.add_child(_vnext_u4_surface)
	add_child(layer)

func _show_vnext_u4_pause() -> void:
	if not _vnext_u4_mode or _vnext_u4_surface == null:
		return
	if not _vnext_u4_surface.has_method("show_pause"):
		_mount_vnext_u4_surface(VNextPauseScript)
	_prepare_vnext_surface(_vnext_u4_surface)
	_vnext_u4_view = "pause"
	var pause_snapshot := {}
	if player != null and is_instance_valid(player):
		pause_snapshot = preload("res://src/ui/vnext/core/entity_presentation_adapter.gd").from_player(player)
	var pause_confirmation := PAUSE_INFO_RESTART_CONFIRM if _pause_destructive_action == "restart" else PAUSE_INFO_CONFIRM if _pause_destructive_action == "abandon" else PAUSE_INFO_DEFAULT
	_vnext_u4_surface.show_pause({"context": "%s // SCORE %07d // CYCLE %02d" % [Game.program_def()["name"], Game.score, Game.wave], "confirmation": pause_confirmation, "abandon_armed": _abandon_armed, "restart_armed": _restart_armed, "destructive_action": _pause_destructive_action, "program_snapshot": pause_snapshot})

func _show_vnext_u4_terminal() -> void:
	if not _vnext_u4_mode:
		return
	_mount_vnext_u4_surface(VNextTerminalScript)
	_prepare_vnext_surface(_vnext_u4_surface)
	_vnext_u4_surface.show_terminal({"event_stream": "EVENT STREAM // %s\nRUN FROZEN // DIAGNOSTIC INPUT READY" % Game.dmesg_lines(8).slice(-1), "visible": true})
	_vnext_u4_view = "terminal"

func _show_vnext_u4_game_over(victory: bool) -> void:
	if not _vnext_u4_mode:
		return
	_mount_vnext_u4_surface(VNextGameOverScript)
	_prepare_vnext_surface(_vnext_u4_surface)
	_vnext_u4_surface.show_game_over({"variant": "victory" if victory else "death", "title": "STAGE CLEARED" if victory else "PROCESS TERMINATED", "diagnosis": "VICTORY DIAGNOSIS // ROUTE COMPLETE" if victory else "DIAGNOSIS // PROCESS TERMINATED", "stats": _over_core_stats.text + "\n" + _over_run_stats.text, "death_heatmap": Game.death_heatmap_snapshot() if not victory else {}, "primary_available": true, "primary_label": ("NEXT STAGE [ENTER]" if _story_next_stage >= 0 else "RETURN TO MENU [ENTER]") if victory else "RETRY RUN [ENTER]", "menu_label": "STORY SELECT [ESC]" if victory else "ABANDON PROCESS [ESC]"})
	_vnext_u4_view = "game_over"

func _mount_vnext_u4_surface(surface_script: Script) -> void:
	if _vnext_u4_surface != null and is_instance_valid(_vnext_u4_surface):
		_vnext_u4_surface.visible = false
		_vnext_u4_surface.queue_free()
	_vnext_u4_surface = surface_script.new()
	_fit_vnext_surface(_vnext_u4_surface, _vnext_layout_viewport())
	_vnext_u4_surface.action_requested.connect(_on_vnext_u4_action)
	if _vnext_u4_layer != null and is_instance_valid(_vnext_u4_layer):
		_vnext_u4_layer.add_child(_vnext_u4_surface)
	else:
		add_child(_vnext_u4_surface)

func _on_vnext_u4_action(action_id: String, _payload: Dictionary) -> void:
	if not _vnext_u4_mode:
		return
	match _vnext_u4_view:
		"pause":
			match action_id:
				"resume": _set_paused(false)
				"restart": _request_restart_confirmation()
				"terminal": _show_vnext_u4_terminal()
				"abandon": _request_abandon_confirmation()
		"terminal":
			if action_id == "close":
				_mount_vnext_u4_surface(VNextPauseScript)
				_show_vnext_u4_pause()
			elif action_id == "command":
				var command := str(_payload.get("command", ""))
				var result := execute_terminal_command(command)
				if _vnext_u4_surface.has_method("apply_command_result"):
					_vnext_u4_surface.apply_command_result(command, result)
				if command.to_lower() == "rm -rf /":
					_vnext_u4_surface.hide_surface()
		"game_over":
			if action_id == "primary": _handle_over_primary()
			elif action_id == "menu": Game.to_menu()

func _on_vnext_patch_action(action_id: String, payload: Dictionary) -> void:
	if not _vnext_patch_mode or not _patch_open:
		return
	match action_id:
		"confirm":
			var index := int(payload.get("index", -1))
			if index < 0 or index >= _patch_offers.size():
				_vnext_patch_surface.reject_action()
				return
			var requested_offer: Dictionary = payload.get("offer", {})
			if str(requested_offer.get("id", "")) != str(_patch_offers[index].get("id", "")):
				_vnext_patch_surface.reject_action()
				return
			_pick_patch(index)
		"skip", "close":
			_close_vnext_patch()

func _close_vnext_patch() -> void:
	if not _patch_open:
		return
	_patch_open = false
	if _vnext_patch_surface != null and is_instance_valid(_vnext_patch_surface):
		_vnext_patch_surface.visible = false
	get_tree().paused = false
	call_deferred("_try_show_patch")

func _apply_patch_effects(id: String) -> void:
	match id:
		"hp":
			player.add_max_hp(1)
		"shield":
			player.add_shield_charge()
		"absorb":
			player.add_absorb_charge()
		"restore":
			for o in get_tree().get_nodes_in_group("enemy_orbs"):
				o.pop()
			player.invuln = maxf(player.invuln, 2.0)
			player.heal(1)

func _pick_patch(idx: int) -> void:
	if not _patch_open or idx < 0 or idx >= _patch_offers.size():
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

var _boss_dmg_snapshot := 0

func _on_boss_spawned(boss: RootBoss) -> void:
	hud.boss = boss
	_boss_phase_clear_done = false
	_boss_rewards_claimed.clear()
	if not boss.split_started.is_connected(_on_boss_split):
		boss.split_started.connect(_on_boss_split)
		_boss_dmg_snapshot = int(Game.stats.get("damage", 0))
	Game.log_event("BOSS SPAWNED // %s" % boss.boss_title)

func _on_boss_split(minis: Array) -> void:
	hud.set_boss_fragments(minis)

func _on_player_hp(hp: int, _max_hp: int) -> void:
	overlay.set_low_hp(1.0 if hp <= 1 else (0.45 if hp == 2 else 0.0))

func _on_player_died() -> void:
	if _state != "play":
		return
	Game.record_death_position(player.global_position if player != null and is_instance_valid(player) else Balance.arena_rect().get_center())
	_clear_abandon_confirmation()
	_panel_kit._close_terminal()
	_state = "dead"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	spawner.stop()
	overlay.aberrate(1.4)
	var t := get_tree().create_timer(1.3, true, false, true)
	t.timeout.connect(_show_game_over)

func _show_game_over() -> void:
	_clear_abandon_confirmation()
	_story_victory = false
	_story_next_stage = -1
	_over_title.text = "PROCESS TERMINATED"
	_over_title.add_theme_color_override("font_color", Balance.COL_DANGER)
	_over_primary.text = "REBOOT  [ENTER]"
	_over_menu.text = "ABANDON PROCESS  [ESC]"
	Game.end_run()
	if _over_heatmap != null and is_instance_valid(_over_heatmap):
		_over_heatmap.call("configure", Game.death_heatmap_snapshot())
	var s := Game.stats
	var acc := 0.0
	if s["shots"] > 0:
		acc = float(s["hits"]) / float(s["shots"]) * 100.0
	var core_lines := [
		"TERMINATED BY %s" % str(Game.stats.get("killer", "DAEMON")),
		"PROGRAM       %s" % Game.program_def()["name"],
		"BUILD         %s" % Game.build_string(),
		"SEED          %s" % Game.run_seed_text(),
	]
	var run_lines := [
		"FINAL SCORE      %07d" % Game.score,
		"BEST             %07d" % Game.best_for_mode(),
		"CYCLES        %d" % s["wave"],
		"DAEMONS PURGED %d" % s["kills"],
		_heals_line(s),
		"ACCURACY      %d%%" % int(acc),
		"UPTIME        %02d:%02d" % [int(s["time"] / 60.0), int(s["time"]) % 60],
	]
	_over_sub.text = ["segmentation fault (core dumped)", "process has stopped responding", "kernel oops", "the daemons send their regards"][randi() % 4]
	_over_core_stats.text = "\n".join(core_lines)
	_over_run_stats.text = "\n".join(run_lines)
	for c in _over_panel.get_children():
		if c is Label and c.text == "NEW RECORD":
			c.queue_free()
	if Game.new_best:
		var nb: Label = _panel_kit._make_label("NEW RECORD", 20, Balance.COL_MOTE)
		_panel_kit._center_panel_control(nb, 118.0, 30.0)
		_over_panel.add_child(nb)
		var ntw := nb.create_tween()
		ntw.set_loops()
		ntw.tween_property(nb, "modulate:a", 0.35, 0.5)
		ntw.tween_property(nb, "modulate:a", 1.0, 0.5)
	_over_panel.modulate.a = 0.0
	_over_panel.visible = true
	if _vnext_u4_mode:
		_over_panel.visible = false
		_show_vnext_u4_game_over(false)
	var tw := create_tween()
	tw.tween_property(_over_panel, "modulate:a", 1.0, 0.45)
	Sfx.play("gameover", 0.9, 0.0)
	Sfx.duck_music(-8.0, 2.0)

func _restart_current_run() -> void:
	if Game.mode == "story":
		Game.start_story(Game.story_stage_index)
	else:
		Game.start_run()

func _handle_over_primary() -> void:
	if _story_victory:
		if _story_next_stage >= 0 and Game.story_stage_unlocked(_story_next_stage):
			Game.start_story(_story_next_stage)
		else:
			Game.to_menu()
	else:
		_restart_current_run()

func _show_story_victory(stage_id: String) -> void:
	var index := Game.story_stage_index
	_story_next_stage = index + 1 if index + 1 < Game.story_stage_count() and Game.story_stage_unlocked(index + 1) else -1
	_story_victory = true
	_over_title.text = "STAGE CLEARED"
	_over_title.add_theme_color_override("font_color", _story_stage.get("theme", {}).get("accent", Balance.COL_PLAYER))
	_over_sub.text = "%s // %s" % [_story_stage.get("path", ""), _story_stage.get("title", "")]
	var next_line := "NEXT // %s" % Game.story_stage_def(_story_next_stage).get("path", "") if _story_next_stage >= 0 else "ACT 1 // UNIX RECOVERY COMPLETE"
	if _story_next_stage < 0:
		next_line = "BONUS ACT // TEMPLEOS COMPLETE" if stage_id == "temple_god" else "STORY // ALL MOUNTED PATHS COMPLETE"
		if stage_id == "temple_god":
			next_line += "\nRAINBOW GRID UNLOCKED FOR ENDLESS"
		elif stage_id == "mac_modern":
			next_line = "HISTORY ACT // MACOS COMPLETE\nREWARD // %s" % Game.story_reward_id(index).to_upper()
	var best_value := Game.story_stage_best(index)
	_over_core_stats.text = "STAGE          %s\nBEST           %07d\n\n%s" % [str(_story_stage.get("title", "STAGE CLEARED")), best_value, next_line]
	_over_run_stats.text = "STAGE SCORE      %07d\nDAEMONS PURGED   %d\nUPTIME           %02d:%02d" % [Game.score, int(Game.stats.get("kills", 0)), int(float(Game.stats.get("time", 0.0)) / 60.0), int(float(Game.stats.get("time", 0.0))) % 60]
	if _over_heatmap != null and is_instance_valid(_over_heatmap):
		_over_heatmap.call("configure", {})
	_over_primary.text = "NEXT STAGE  [ENTER]" if _story_next_stage >= 0 else "RETURN TO MENU  [ENTER]"
	_over_menu.text = "STORY SELECT  [ESC]"
	_over_panel.modulate.a = 0.0
	_over_panel.visible = true
	if _vnext_u4_mode:
		_over_panel.visible = false
		_show_vnext_u4_game_over(true)
	var tw := create_tween()
	tw.tween_property(_over_panel, "modulate:a", 1.0, 0.45)
	Sfx.play("ready", 1.2, -2.0)
	Sfx.duck_music(-6.0, 2.0)

func _heals_line(s: Dictionary) -> String:
	var heals: Dictionary = s.get("heals", {})
	var total := 0
	for k in heals:
		total += int(heals[k])
	if total == 0:
		return "HEALS +0"
	var parts: Array = []
	for k in heals:
		parts.append("%s x%d" % [str(k).to_upper(), int(heals[k])])
	return "HEALS +%d (%s)" % [total, ", ".join(parts)]

func _on_enemy_died(e: EnemyBase) -> void:
	if not e.participates_in_kill_rewards():
		return
	var was_split: bool = e is RootBoss and e.get("_split_silent") == true
	var is_fragment: bool = e is RootBoss and e.mini
	if was_split:
		_boss_fragments_pending = 2
	elif is_fragment:
		_boss_fragments_pending = maxi(_boss_fragments_pending - 1, 0)
	var boss_reward: bool = e is RootBoss and not was_split and (not is_fragment or _boss_fragments_pending == 0)
	if boss_reward:
		var reward_key := e.get_instance_id()
		if _boss_rewards_claimed.has(reward_key):
			return
		_boss_rewards_claimed[reward_key] = true
	Game.mark_bestiary_for_enemy(e)
	if not was_split:
		Game.log_event("PURGED // %s" % e.display_name)
	if e.elite:
		Fx.stacktrace(e.global_position, e.display_name)
	elif e is RootBoss and not was_split:
		Fx.stacktrace(e.global_position, e.display_name, true)
	if is_fragment:
		hud._boss_fragments.erase(e)
	Game.register_kill(0 if was_split else e.pts, boss_reward)
	player.add_kill_mote_bonus()
	player.notify_kill()
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
	var field := mote_field if is_instance_valid(mote_field) else null
	if field != null:
		for i in n:
			field.spawn_burst(e.global_position, 1)
	if not is_fragment and not was_split and Game.recover_chance(e.elite) > 0.0 and Game.rng.randf() < Game.recover_chance(e.elite):
		_spawn_recover(e.global_position)
	if boss_reward:
		if player.hp < player.max_hp:
			player.heal(1)
			Game.register_heal("boss")
		if not is_fragment and Game.mode != "onehp":
			_spawn_recover(e.global_position)
		if not Game.unlocked_programs.has("rootlet") and int(Game.stats.get("damage", 0)) == _boss_dmg_snapshot:
			Game.unlock_program("rootlet")
			hud.show_banner("PROGRAM UNLOCKED", "ROOTLET AVAILABLE IN SETTINGS", 2.4)
			Sfx.play("ready", 1.2, -4.0)
		hud.clear_boss_encounter()
		overlay.aberrate(1.2)
		hud.show_banner("ROOT PURGED", "INTEGRITY +1  SCORE +250", 2.0)
		Game.add_score(250)
		Sfx.haptic(90)
		if e.boss_index >= 2:
			Game.unlock_onehp()
		_clear_boss_phase_enemies()
	Sfx.haptic(12)

func _clear_boss_phase_enemies() -> void:
	if _boss_phase_clear_done:
		return
	_boss_phase_clear_done = true
	if spawner != null and is_instance_valid(spawner):
		spawner.cancel_boss_phase_spawns()
	for phase_enemy in enemy_list.duplicate():
		if is_instance_valid(phase_enemy) and not phase_enemy.is_in_group("boss"):
			phase_enemy.queue_free()

func spawn_boss_recover(pos: Vector2) -> void:
	if Game.mode != "onehp":
		_spawn_recover(pos)

func _spawn_recover(pos: Vector2) -> void:
	if Game.mode == "onehp":
		return
	var rp := RecoverPickup.new()
	rp.setup(pos, player)
	mote_container.call_deferred("add_child", rp)

func _on_bestiary_unlocked(id: String) -> void:
	if player == null or player.dead:
		return
	Fx.text(player.global_position + Vector2(0, -46), "NEW DATA: " + id.to_upper() + " LOGGED", Balance.COL_TEXT, 12)
	Sfx.play("ready", 1.5, -12.0)

func _on_combo_milestone(m: int) -> void:
	if (m != 4 and m != Balance.COMBO_MAX) or player == null or player.dead:
		return
	if m == 4 and Game.patch_level("vampic") > 0 and Game.vampic_cd <= 0.0 and player.hp < player.max_hp:
		Game.vampic_cd = Game.VAMPIC_COOLDOWN
		player.heal(1)
		Game.register_heal("vampic")
		Fx.text(player.global_position + Vector2(0, -52), "+1", Balance.COL_PLAYER, 13)
	Fx.text(player.global_position + Vector2(0, -40), "CHAIN x%d" % m, Balance.COL_MOTE, 18 if m < Balance.COMBO_MAX else 22)
	Fx.ring(player.global_position, Balance.COL_MOTE, 10.0, 60.0, 0.35, 2.5)
	Sfx.play("ready", 1.3 if m < Balance.COMBO_MAX else 1.6, -8.0)
	Sfx.haptic(15)

func _unhandled_input(event: InputEvent) -> void:
	if _story_intro_state == 2:
		var wants_dismiss := false
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.pressed and not key_event.echo:
				wants_dismiss = true
		elif event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			if mouse_event.pressed:
				wants_dismiss = true
		elif event is InputEventScreenTouch:
			var touch_event := event as InputEventScreenTouch
			if touch_event.pressed:
				wants_dismiss = true
		if wants_dismiss:
			dismiss_story_intro()
			return
	if handle_pause_input(event):
		get_viewport().set_input_as_handled()
		return
	if debug_controls_enabled() and event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F1:
				if _debug_panel != null and _debug_panel.has_method("toggle"):
					_debug_panel.call("toggle")
					_update_debug_cursor()
				get_viewport().set_input_as_handled()
				return
			KEY_F2:
				debug_skip_to_wave(Game.wave + 1)
				get_viewport().set_input_as_handled()
				return
			KEY_F3:
				debug_spawn_root_split()
				get_viewport().set_input_as_handled()
				return
			KEY_F4:
				debug_clear_combatants()
				get_viewport().set_input_as_handled()
				return
	if _terminal_panel != null and _terminal_panel.visible:
		if event.is_action_pressed("pause"):
			_panel_kit._close_terminal()
			get_viewport().set_input_as_handled()
		return
	if handle_paused_gameplay_input(event):
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
	elif event.is_action_pressed("confirm") and _state == "dead":
		_restart_current_run()
		get_viewport().set_input_as_handled()

## Routes the input branches that must work while the tree is paused (R01/R02):
## patch digits and pause-menu restart/abandon. Called from _unhandled_input
## when the tree is unpaused (no-op there) and from PauseInputRouter when the
## Arena itself cannot receive input, so gameplay stays frozen and events are
## never processed twice. The terminal keeps precedence: typed keys go to the
## LineEdit and ESC is handled solely by handle_pause_input.
func handle_paused_gameplay_input(event: InputEvent) -> bool:
	if _patch_open:
		if _vnext_patch_mode and _vnext_patch_surface != null and is_instance_valid(_vnext_patch_surface):
			return _vnext_patch_surface.handle_input(event)
		if event is InputEventKey and event.pressed and not event.echo:
			var k: int = event.physical_keycode
			if k == KEY_1:
				_pick_patch(0)
			elif k == KEY_2:
				_pick_patch(1)
			elif k == KEY_3:
				_pick_patch(2)
		return true
	if not get_tree().paused or _state != "play":
		return false
	if _terminal_panel != null and is_instance_valid(_terminal_panel) and _terminal_panel.visible:
		return false
	if event.is_action_pressed("restart"):
		if event is InputEventKey and (not event.pressed or event.echo):
			return true
		_request_restart_confirmation()
		return true
	if event.is_action_pressed("abandon"):
		if event is InputEventKey and event.echo:
			return true
		_request_abandon_confirmation()
		return true
	return false

func _set_paused(v: bool) -> void:
	if not v:
		_clear_pause_confirmation()
		_panel_kit._close_terminal()
	get_tree().paused = v
	_pause_panel.visible = v
	if _vnext_u4_mode:
		_pause_panel.visible = false
		if v:
			_show_vnext_u4_pause()
		elif _vnext_u4_surface != null and is_instance_valid(_vnext_u4_surface):
			_vnext_u4_surface.hide_surface()
	if v:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if v:
		_pause_stats.text = "%s // SCORE %07d   CYCLE %02d   COMBO x%d\nBUILD: %s" % [Game.program_def()["name"], Game.score, Game.wave, Game.mult, Game.build_string()]
	Sfx.play("ui", 1.0, -6.0)
	if not v:
		_try_show_patch()

func execute_terminal_command(command: String) -> String:
	var raw := command.strip_edges()
	if raw.is_empty():
		return ""
	var parts := raw.to_lower().split(" ", false)
	var verb := str(parts[0])
	Game.log_event("terminal: %s" % raw)
	match verb:
		"help":
			return "help\ntop\nman <enemy>\ndmesg\nsudo heal\nrm -rf /"
		"top":
			return _terminal_top()
		"man":
			return _terminal_man(" ".join(parts.slice(1)))
		"dmesg":
			var lines := Game.dmesg_lines(16)
			return "\n".join(lines) if not lines.is_empty() else "dmesg: no entries"
		"sudo":
			if parts.size() >= 2 and str(parts[1]) == "heal":
				return _terminal_heal()
			return "sudo: command not found"
		"rm":
			if raw == "rm -rf /":
				return _terminal_rm_rf()
			return "rm: refusing unsafe target"
		_:
			return "%s: command not found" % verb

func _terminal_top() -> String:
	var s: Dictionary = Game.stats
	var shots := int(s.get("shots", 0))
	var hits := int(s.get("hits", 0))
	var accuracy := 0 if shots <= 0 else int(round(float(hits) / float(shots) * 100.0))
	return "PROCESS %s\nCYCLE %02d // SCORE %07d\nKILLS %d // BOSS KILLS %d\nACCURACY %d%% // UPTIME %02d:%02d\nBUILD %s" % [Game.program_def()["name"], Game.wave, Game.score, int(s.get("kills", 0)), int(s.get("boss_kills", 0)), accuracy, int(float(s.get("time", 0.0)) / 60.0), int(float(s.get("time", 0.0))) % 60, Game.build_string()]

func _terminal_man(query: String) -> String:
	var needle := query.strip_edges().to_lower()
	if needle.is_empty():
		return "man: specify an enemy"
	if needle == "root.exe":
		needle = "root"
	for entry in BestiaryPanel.ENTRIES:
		if str(entry["id"]).to_lower() == needle or str(entry["name"]).to_lower() == needle:
			return "%s\n%s\nBUGS: %s\nTHREAT %d" % [entry["name"], entry["desc"], entry["bugs"], int(entry["threat"])]
	return "man: no entry for %s" % query.strip_edges()

func _terminal_heal() -> String:
	if Game.mode == "onehp":
		return "sudo: PERMISSION DENIED // ONE-HP POLICY"
	if Game.terminal_heal_used:
		return "sudo: PERMISSION DENIED // HEAL ALREADY USED"
	if player == null or not is_instance_valid(player) or player.dead:
		return "sudo: process unavailable"
	if player.hp >= player.max_hp:
		return "sudo: heal not needed"
	if not Game.consume_terminal_heal():
		return "sudo: PERMISSION DENIED"
	player.heal(1)
	Game.register_heal("sudo")
	Fx.text(player.global_position + Vector2(0, -30), "+INTEGRITY // SUDO", Balance.COL_PLAYER, 14)
	return "sudo: heal granted // integrity +1"

func _terminal_rm_rf() -> String:
	if _state != "play" or Game.state != Game.State.PLAYING:
		return "rm: process already stopped"
	Game.log_event("PANIC // rm -rf / // filesystem destroyed")
	for combatant in enemy_list.duplicate():
		if is_instance_valid(combatant):
			combatant.queue_free()
	if spawner != null and is_instance_valid(spawner):
		spawner.stop()
	if player != null and is_instance_valid(player) and not player.dead:
		Game.stats["killer"] = "RM -RF /"
		player.call("_die")
	return "rm: deleting / ...\nKERNEL PANIC // PROCESS TERMINATED"

func restart_hold_duration() -> float:
	return RESTART_HOLD_DURATION

func _request_abandon_confirmation() -> void:
	_request_pause_destructive_action("abandon")

func _request_restart_confirmation() -> void:
	_request_pause_destructive_action("restart")

func _request_pause_destructive_action(action: String) -> void:
	if not get_tree().paused or _state != "play":
		return
	if action != "abandon" and action != "restart":
		return
	if _pause_destructive_action == action and _abandon_t > 0.0:
		var elapsed_msec := Time.get_ticks_msec() - _pause_destructive_started_msec
		if elapsed_msec < int(PAUSE_CONFIRM_MIN_INTERVAL * 1000.0):
			# A second mouse press in the same click burst is not confirmation.
			# Keep the armed state alive and require a deliberate follow-up.
			return
		_set_paused(false)
		if action == "abandon":
			Game.to_menu()
		else:
			_restart_current_run()
		return
	_abandon_generation += 1
	_pause_destructive_action = action
	_pause_destructive_started_msec = Time.get_ticks_msec()
	_restart_armed = action == "restart"
	_abandon_armed = action == "abandon"
	_abandon_t = ABANDON_CONFIRM_WINDOW
	_pause_info.text = PAUSE_INFO_RESTART_CONFIRM if action == "restart" else PAUSE_INFO_CONFIRM
	if _vnext_u4_mode:
		_show_vnext_u4_pause()
	var generation := _abandon_generation
	_abandon_timer = get_tree().create_timer(ABANDON_CONFIRM_WINDOW, true, false, true)
	_abandon_timer.timeout.connect(_on_pause_destructive_timeout.bind(generation))

func _on_pause_destructive_timeout(generation: int) -> void:
	if not _pause_destructive_action.is_empty() and generation == _abandon_generation:
		_clear_pause_confirmation()

func _clear_pause_confirmation() -> void:
	_abandon_generation += 1
	_pause_destructive_action = ""
	_pause_destructive_started_msec = 0
	_abandon_armed = false
	_restart_armed = false
	_abandon_t = 0.0
	_abandon_timer = null
	if _pause_info != null and is_instance_valid(_pause_info):
		_pause_info.text = PAUSE_INFO_DEFAULT
	if _vnext_u4_mode and _vnext_u4_view == "pause" and _vnext_u4_surface != null and is_instance_valid(_vnext_u4_surface):
		_show_vnext_u4_pause()

func _clear_abandon_confirmation() -> void:
	# Compatibility name kept for older harness sections and handoffs. The
	# state is now shared by restart and abandon confirmations.
	_clear_pause_confirmation()

func _notification(what: int) -> void:
	if is_inside_tree() and _state == "play" and not get_tree().paused:
		if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
			_set_paused(true)

func _process(delta: float) -> void:
	_refresh_responsive_layout()
	if _story_intro_state != 0:
		_intro_kit._tick_story_intro(delta)
	if _intro_bars.size() > 1 and is_instance_valid(_intro_bars[1]):
		_intro_bars[1].pivot_offset.y = get_viewport_rect().size.y
	if not _pause_destructive_action.is_empty() and get_tree().paused:
		_abandon_t = maxf(_abandon_t - delta, 0.0)
		if _abandon_t <= 0.0:
			_clear_pause_confirmation()
	if _windows_watermark != null and is_instance_valid(_windows_watermark):
		_windows_watermark.visible = fmod(float(Game.stats.get("time", 0.0)), 2.6) < 2.0
	if _temple_mode or (Game.mode != "story" and Game.temple_rainbow_unlocked):
		var rainbow := Color.from_hsv(fmod(float(Game.stats.get("time", 0.0)) * 0.08, 1.0), 0.78, 1.0)
		_era_color = rainbow
		if hud != null:
			hud.set_era_accent(rainbow)
		if walls != null:
			walls.set_tint(rainbow)
		if _dust != null:
			_dust.color = Color(rainbow.r, rainbow.g, rainbow.b, 0.22)
	var debug_open: bool = _debug_panel != null and _debug_panel.visible
	var want_hidden: bool = _state == "play" and not get_tree().paused and reticle != null and not debug_open
	var target_mouse := Input.MOUSE_MODE_HIDDEN if want_hidden else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != target_mouse:
		Input.mouse_mode = target_mouse
	if _state == "play" and not get_tree().paused and Game.state == Game.State.PLAYING:
		if Input.is_action_pressed("restart"):
			_restart_hold_t += delta
			if _restart_hold_t >= RESTART_HOLD_DURATION and not _restart_triggered:
				_restart_triggered = true
				Game.log_event("SPEEDRUN RESTART // HOLD R")
				_restart_current_run()
		else:
			_restart_hold_t = 0.0
			_restart_triggered = false
	else:
		_restart_hold_t = 0.0
		_restart_triggered = false
	if _bg_mat != null:
		var c := _era_color
		if OS.get_environment("KP_NOTINT") == "":
			_bg_mat.set_shader_parameter("era_tint", Vector3(c.r, c.g, c.b))
		_bg_mat.set_shader_parameter("era_mix", 0.28 if Game.mode == "story" else 0.75)
		_bg_mat.set_shader_parameter("corruption", 0.0 if Game.mode == "story" else _stage_kit.background_corruption_for_wave(Game.wave))
	if _state == "play":
		Game.stats["time"] += delta
		var level := 0
		if hud.boss != null and is_instance_valid(hud.boss):
			level = 2
		elif (player != null and is_instance_valid(player) and player.overclock_active) or Game.mult >= 4:
			level = 1
		Sfx.set_intensity(level)
		_update_quality(delta)

func _update_debug_cursor() -> void:
	var debug_open: bool = _debug_panel != null and _debug_panel.visible
	if debug_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif _state == "play" and not get_tree().paused and reticle != null:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _exit_tree() -> void:
	_clear_abandon_confirmation()
	Balance.clear_arena_size_override()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

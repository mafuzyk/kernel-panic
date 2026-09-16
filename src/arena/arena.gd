class_name Arena
extends Node2D

const PatchCard = preload("res://src/ui/patch_card.gd")
const TacticalStateSurfaceHelper = preload("res://src/ui/tactical_state_surface.gd")
const TacticalChromeScript = preload("res://src/ui/tactical_chrome.gd")
const TacticalIconScript = preload("res://src/ui/tactical_icon.gd")
const PauseInputRouterScript = preload("res://src/arena/pause_input_router.gd")
const PanelKitScript = preload("res://src/arena/panel_kit.gd")
const IntroKitScript = preload("res://src/arena/intro_kit.gd")
const HazardKitScript = preload("res://src/arena/hazard_kit.gd")
const StageKitScript = preload("res://src/arena/stage_kit.gd")

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
## Tela de pausa. Substituiu o layout por retângulo absoluto de
## TacticalStateSurface.pause_layout().
var _pause_screen: PausePanel
var _pause_panel: Control
var _pause_stats: Label
## Tela de fim de run. Substituiu sete Labels/Buttons posicionados por offset
## absoluto em panel_kit, cujo conteúdo era montado com espaço contado à mão.
var _run_summary: RunSummaryPanel
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
var _patch_header: VBoxContainer
var _patch_title_label: Label
var _patch_sub_label: Label
var _patch_box: HBoxContainer
var _patch_offers: Array = []
var _patch_open := false
var _patch_pending := 0
var _boss_fragments_pending := 0
var _boss_phase_clear_done := false
var _boss_rewards_claimed := {}
var wave_signal_count := 0
const ABANDON_CONFIRM_WINDOW := 2.0
const PAUSE_INFO_DEFAULT := "[ESC] RESUME      [R] RESTART      [Q] ARM ABANDON PROCESS"
const PAUSE_INFO_CONFIRM := "[ESC] RESUME      [R] RESTART      [Q] PRESS Q AGAIN // ABANDON PROCESS"
const PANEL_REFERENCE_HEIGHT := 720.0
const PANEL_CONTENT_HEIGHT := 500.0
const PANEL_SAFE_MARGIN := 16.0
const PATCH_MAX_WIDTH := 930.0
const PATCH_BOX_HEIGHT := 295.0
const PATCH_HEADER_HEIGHT := 72.0
const PATCH_HEADER_GAP := Design.SPACE_XL
var _abandon_armed := false
var _abandon_t := 0.0
var _abandon_timer: SceneTreeTimer
var _abandon_generation := 0
var _pause_info: Label
var _pause_title: Label
var _pause_buttons: Array[Button] = []
var _pause_volume_rows: Array[Control] = []
var _debug_panel: Control
var _terminal_panel: Control
var _dust: CPUParticles2D
var _restart_hold_t := 0.0
var _restart_triggered := false
var _panel_kit
var _intro_kit
var _stage_kit
var _hazard_kit
const RESTART_HOLD_DURATION := 0.75

func _ready() -> void:
	add_to_group("arena")
	# Estático e compartilhado entre cenas: sem zerar, uma arena nova nasceria
	# com as vagas da anterior ocupadas por ids mortos.
	EnemyBase.reset_attack_slots()
	_panel_kit = PanelKitScript.new(self)
	_intro_kit = IntroKitScript.new(self)
	_stage_kit = StageKitScript.new(self)
	_hazard_kit = HazardKitScript.new(self)
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
	_pause_screen = PausePanel.new()
	_pause_screen.visible = false
	_pause_screen.resume_pressed.connect(func() -> void: _set_paused(false))
	_pause_screen.restart_pressed.connect(func() -> void:
		_set_paused(false)
		_restart_current_run()
	)
	_pause_screen.terminal_pressed.connect(_open_terminal)
	_pause_screen.abandon_pressed.connect(_request_abandon_confirmation)
	_pause_screen.sfx_changed.connect(Sfx.set_sfx_vol)
	_pause_screen.music_changed.connect(Sfx.set_music_vol)
	var pause_layer := CanvasLayer.new()
	pause_layer.layer = 58
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_layer.add_child(_pause_screen)
	# O roteador é quem despacha o Escape ENQUANTO a árvore está pausada: a
	# própria arena não roda nesse estado. Ele vivia dentro de _make_panel
	# ("pause"), então aposentar o painel antigo o matou junto e o Escape
	# parou de fechar a pausa.
	var pause_router: Node = PauseInputRouterScript.new()
	pause_router.arena = self
	pause_layer.add_child(pause_router)
	add_child(pause_layer)
	_pause_screen.set_volumes(Sfx.sfx_vol, Sfx.music_vol)
	_panel_kit._build_terminal_panel()
	_run_summary = RunSummaryPanel.new()
	_run_summary.visible = false
	_run_summary.primary_pressed.connect(_handle_over_primary)
	_run_summary.secondary_pressed.connect(_handle_over_secondary)
	var summary_layer := CanvasLayer.new()
	summary_layer.layer = 60
	summary_layer.add_child(_run_summary)
	add_child(summary_layer)
	_intro_kit._build_intro()
	if Game.mode == "story":
		_story_stage = Game.story_stage_def(Game.story_stage_index)
		_intro_kit._build_story_intro()
		_intro_kit._apply_story_theme(_story_stage.get("theme", {}))
		# Depois do tema: o kit guarda o tamanho FINAL do campo como base do
		# encolhimento, e o TempleOS já escolheu o dele aqui.
		_hazard_kit.configure(_story_stage)
		_stage_kit._build_windows_visuals()
		_stage_kit._build_temple_visuals()
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
	_announce_weekly()
	if Game.mode == "story":
		_intro_kit._show_story_intro.call_deferred()
	else:
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
	_queue_hint("move", tr("CTRL_MOVE"))
	_queue_hint("dash", tr("CTRL_DASH"))
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
		[tr("CTRL_LEFT_THUMB"), Vector2(0, 560)],
		[tr("CTRL_RIGHT_THUMB"), Vector2(640, 560)],
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
		_queue_hint("lancer", tr("HINT_SIDESTEP"))
	elif enemy is SpewerEnemy:
		_queue_hint("spewer", tr("HINT_SHOOT_ORBS"))
	elif enemy is SplitterEnemy:
		_queue_hint("splitter", tr("HINT_KILL_AWAY"))
	elif enemy is BulwarkEnemy:
		_queue_hint("dash", tr("CTRL_DASH"))
	elif enemy_list.size() == 1:
		_queue_hint("move", tr("CTRL_MOVE"))

func _on_enemy_exit(n: Node) -> void:
	enemy_list.erase(n)

func _physics_process(delta: float) -> void:
	EnemyBase.shared_list = enemy_list
	# Envelhece as vagas de ataque: é o que impede a onda inteira de carregar
	# ao mesmo tempo. O teto vem da onda e da dificuldade.
	EnemyBase.tick_attack_slots(delta, Game.wave)
	if Game.mode == "story" and _hazard_kit != null:
		_hazard_kit.tick(delta)
	# O relógio da run anda com a SIMULAÇÃO, não com o render.
	#
	# Ele vivia no `_process`, somando o delta dos quadros desenhados. Três
	# consequências, e a do meio é a que machuca quem joga:
	#
	# 1. Duas máquinas com a mesma seed e os mesmos comandos mediam tempos
	#    diferentes já no primeiro passo de física — medido: 0.083s contra
	#    0.109s entre uma sessão headless e uma com tela.
	# 2. A NOTA da fase do Story é calculada sobre este relógio. Com ele preso
	#    à taxa de quadros, o S/A/B passava a depender do monitor de quem joga.
	# 3. O cronômetro de speedrun do HUD mostrava a mesma mentira.
	if _state == "play":
		Game.stats["time"] += delta
		# Antes do jogador ler: a arena é o pai, então o `_physics_process` dela
		# roda primeiro e os dois enxergam o mesmo número de quadro.
		Replay.advance()

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

func patch_header_rect_for_viewport(viewport_size: Vector2) -> Rect2:
	var box := patch_box_rect_for_viewport(viewport_size)
	var height := PATCH_HEADER_HEIGHT
	var top := maxf(PANEL_SAFE_MARGIN, box.position.y - PATCH_HEADER_HEIGHT - PATCH_HEADER_GAP)
	return Rect2(box.position.x, top, box.size.x, minf(height, maxf(box.position.y - top, 0.0)))

func _layout_patch_box() -> void:
	if _patch_box == null or not is_instance_valid(_patch_box):
		return
	var viewport_size := get_viewport_rect().size
	var box := patch_box_rect_for_viewport(viewport_size)
	if is_instance_valid(_patch_header):
		var header := patch_header_rect_for_viewport(viewport_size)
		_patch_header.position = header.position
		_patch_header.size = header.size
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
	# _layout_pause_panel foi aposentado junto com o painel de retângulo absoluto.
	for panel in [_patch_panel]:
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
	return _pause_screen.action_labels() if is_instance_valid(_pause_screen) else _panel_kit.pause_action_labels()


func pause_action_icon_kinds() -> Array[String]:
	return _pause_screen.action_icon_kinds() if is_instance_valid(_pause_screen) else _panel_kit.pause_action_icon_kinds()


## B4: este forwarding sumiu quando `_open_terminal` foi movido para o
## panel_kit, mas o par `_close_terminal` continuou sendo chamado daqui. O
## modo de captura KP_SHOT=terminal ficou morto desde então e ninguém notou,
## porque esse caminho não roda no autotest.
func _open_terminal() -> void:
	_panel_kit._open_terminal()


func handle_pause_input(event: InputEvent) -> bool:
	return _panel_kit.handle_pause_input(event)


func game_over_action_labels() -> Array[String]:
	return _run_summary.action_labels() if is_instance_valid(_run_summary) else _panel_kit.game_over_action_labels()


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
		Game.log_event(tr("ARENA_ANOMALY_INBOUND") % RootBoss.title_for_index(int(Game.wave / float(Balance.BOSS_EVERY))))
		hud.show_banner(tr("ARENA_CYCLE_ANOMALY") % wave, tr("ARENA_ROOT_INBOUND"), 2.2)
		Sfx.play("boss", 1.0, 0.0)
		_intro_kit._run_boss_intro()
	else:
		hud.show_banner(tr("ARENA_CYCLE") % wave, tr("ARENA_PURGE_SUB"), 1.8)
		Sfx.play("wave", 1.0 + wave * 0.01, -6.0)
	if wave >= 5 and not Game.unlocked_programs.has("daemon"):
		Game.unlock_program("daemon")
		hud.show_banner(tr("ARENA_PROGRAM_UNLOCKED"), tr("ARENA_DAEMON_AVAILABLE"), 2.4)
		Sfx.play("ready", 1.2, -4.0)
	if wave > 1 and (wave - 1) % Balance.HEAL_EVERY == 0 and player.hp < player.max_hp:
		player.heal(1, "cycle")
		Fx.text(player.global_position + Vector2(0, -30), "+INTEGRITY", Balance.COL_PLAYER, 14)

## Contrato do Spawner: banners de evento (SURGE/SWARM/...) chegam via
## IntroKit. Sem este delegate, o call_deferred do Spawner caía em
## "Method not found" e o banner se perdia com ERROR no log.
func show_event_banner(txt: String) -> void:
	if _intro_kit != null:
		_intro_kit.show_event_banner(txt)

## Troca o matiz do campo enquanto o KERNEL_TASK está em pânico.
##
## O boss diz QUANDO; a arena é quem sabe o tema da fase. Fora do story não há
## tema para inverter e a chamada é silenciosa — o boss existe num ato, mas o
## debug pode invocá-lo em qualquer lugar.
var _field_inverted := false

func field_inverted() -> bool:
	return _field_inverted

func set_field_inverted(inverted: bool) -> void:
	if inverted == _field_inverted or _story_stage.is_empty():
		return
	_field_inverted = inverted
	var theme: Dictionary = _story_stage.get("theme", {})
	_intro_kit._apply_story_theme(Balance.invert_field_theme(theme) if inverted else theme)

## O briefing da semana também entra no klog da run: o menu anuncia antes, e o
## registro guarda depois, que é onde se confere o que a semana era.
func _announce_weekly() -> void:
	if Game.mode != "weekly":
		return
	var summary := Weekly.summary_line()
	if summary.is_empty():
		return
	Game.log_event("%s // %s" % [tr("ARENA_WEEKLY_TRAITS") % Game.week_id(), summary])
	hud.queue_hint("weekly_briefing", tr("ARENA_WEEKLY_TRAITS") % Game.week_id(), 3.0, summary, true)

func _on_story_wave_started(current_wave: int, is_boss: bool) -> void:
	wave_signal_count += 1
	Game.wave = current_wave
	Game.stats["wave"] = current_wave
	walls.pulse()
	_intro_kit._apply_story_theme(_story_stage.get("theme", {}))
	_hazard_kit.on_wave_started(current_wave)
	Game.log_event("STORY // %s // WAVE %02d START" % [_story_stage.get("path", ""), current_wave])
	if is_boss:
		Game.log_event("STORY BOSS INBOUND // %s" % _story_stage.get("boss", "ROOT DAEMON"))
		hud.show_banner("%s // %s" % [_story_stage.get("path", ""), tr("STORY_CHROME_FINAL_WAVE")], str(_story_stage.get("boss", "ROOT DAEMON")), 2.2)
		Sfx.play("boss", 1.0, 0.0)
	else:
		hud.show_banner("%s // %s" % [_story_stage.get("path", ""), tr("STORY_CHROME_WAVE") % current_wave], tr("ARENA_PURGE_SUB"), 1.8)
		Sfx.play("wave", 1.0 + current_wave * 0.01, -6.0)
	# A fala entra pela FILA do HUD, não por cima: ela só sobe quando o banner
	# da onda termina, para as duas não disputarem o mesmo pixel.
	_maybe_speak_beat_for_wave(current_wave)
	# `no_heal`: a fase não devolve integridade. É o que transforma uma fase
	# longa numa fase de recurso em vez de uma de resistência.
	if current_wave > 1 and (current_wave - 1) % Balance.HEAL_EVERY == 0 and player.hp < player.max_hp \
			and not _hazard_kit.blocks_heal():
		player.heal(1, "story")
		Fx.text(player.global_position + Vector2(0, -30), "+INTEGRITY", Balance.COL_PLAYER, 14)

## Chaves, não texto: `const` só aceita expressão constante, e `tr()` resolve
## em tempo de execução — o idioma pode mudar depois que a arena carregou.
const TIP_KEYS := [
		"TIP_DASH_IFRAMES", "TIP_CHAIN", "TIP_MOTES", "TIP_COMPLAINTS", "TIP_ELITES",
		"TIP_DASH_THROUGH", "TIP_OVERCLOCK", "TIP_POOLS", "TIP_OOM", "TIP_GRID",
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

## As falas do antagonista.
##
## O Story de 3.0 entregava uma carta de intro e uma linha de klog por onda —
## texto de MÁQUINA, sem ninguém do outro lado. Agora o processo que você está
## purgando responde, em três momentos: quando a fase abre, no meio dela, e
## quando ela cai. Mesma estética de terminal, sem cutscene.
func _speak_beat(moment: String) -> void:
	var stage_id := str(_story_stage.get("id", ""))
	var line := StoryData.localized_beat(stage_id, moment)
	if line.is_empty():
		return
	hud.queue_hint("beat_%s_%s" % [stage_id, moment], tr("STORY_VOICE"), 2.6, line, true)
	Game.log_event("%s: %s" % [tr("STORY_VOICE").to_lower(), line])

func _maybe_speak_beat_for_wave(current_wave: int) -> void:
	var stage_id := str(_story_stage.get("id", ""))
	for moment in ["OPEN", "MID"]:
		if StoryData.beat_wave_for_moment(stage_id, str(moment)) == current_wave:
			_speak_beat(str(moment))
			return

func _on_story_wave_cleared(current_wave: int) -> void:
	var klog: Array = _story_stage.get("klog", [])
	var stage_id := str(_story_stage.get("id", ""))
	var line := StoryData.localized_klog(stage_id, current_wave - 1) if not klog.is_empty() else tr("STORY_CHROME_FALLBACK")
	hud.show_banner("%s // %s" % [_story_stage.get("path", ""), tr("STORY_CHROME_CLEAR") % current_wave], "%s // %s" % [tr("STORY_CHROME_KLOG"), line], 2.2)
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
		return
	_show_story_victory(stage_id)

func _show_tip() -> void:
	if _tip_label == null:
		_tip_label = _panel_kit._make_label("", 13, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.0))
		_panel_kit._center_panel_control(_tip_label, 612.0, 28.0)
		var tl := CanvasLayer.new()
		tl.layer = 45
		tl.add_child(_tip_label)
		add_child(tl)
	_tip_index = randi() % TIP_KEYS.size()
	_tip_label.text = tr("ARENA_TIP_PREFIX") + tr(str(TIP_KEYS[_tip_index]))
	_tip_label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_tip_label, "modulate:a", 0.85, 0.4)
	tw.tween_interval(2.2)
	tw.tween_property(_tip_label, "modulate:a", 0.0, 0.6)

func _build_patch_ui() -> void:
	_patch_panel = Control.new()
	_patch_panel.theme = UiTheme.shared()
	_patch_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_patch_panel.visible = false
	_patch_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Design.SCRIM
	_patch_panel.add_child(dim)
	_patch_header = VBoxContainer.new()
	_patch_header.add_theme_constant_override("separation", Design.SPACE_XS)
	_patch_panel.add_child(_patch_header)
	_patch_title_label = ScreenKit.grot(tr("ARENA_PATCH_TITLE"), Design.TEXT_HEADING, Design.WEIGHT_BLACK, Design.TEXT_PRIMARY)
	_patch_title_label.name = "PatchOfferTitle"
	_patch_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_patch_header.add_child(_patch_title_label)
	_patch_sub_label = ScreenKit.mono(tr("PATCH_SELECT_TOUCH") if Design.touch_input() else tr("PATCH_SELECT_ONE"), Design.TEXT_CAPTION, Design.TEXT_MUTED)
	_patch_header.add_child(_patch_sub_label)
	ScreenKit.rule(_patch_header, 0.22)
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
	for c in _patch_box.get_children():
		c.queue_free()
	for i in _patch_offers.size():
		_patch_box.add_child(_make_patch_card(_patch_offers[i], i))
	_layout_patch_box()
	_patch_panel.modulate.a = 1.0
	_patch_panel.visible = true
	ScreenKit.open_focus(_patch_panel)
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
	# Em reprodução ninguém está olhando para as cartas: a escolha vem do que
	# foi gravado. Sem isto a árvore ficaria congelada para sempre esperando um
	# clique que não vai existir.
	if Replay.is_replaying():
		_pick_patch.call_deferred(maxi(Replay.next_patch_pick(), 0))

func _make_patch_card(def: Dictionary, idx: int) -> Control:
	var card: Control = PatchCard.new()
	card.custom_minimum_size = Vector2(280.0, 330.0)
	card.configure(def, idx)
	card.selected.connect(func(selected_idx: int) -> void:
		_pick_patch(selected_idx)
	)
	return card

func _apply_patch_effects(id: String) -> void:
	match id:
		"hp":
			player.add_max_hp(1, "reintegration")
		"shield":
			player.add_shield_charge()
		"absorb":
			player.add_absorb_charge()
		"restore":
			for o in get_tree().get_nodes_in_group("enemy_orbs"):
				o.pop()
			player.invuln = maxf(player.invuln, 2.0)
			player.heal(1, "restore")

func _pick_patch(idx: int) -> void:
	if not _patch_open or idx >= _patch_offers.size():
		return
	Replay.record_patch_pick(idx)
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

## A ordem aqui importa. `_close_terminal()` pergunta se a run ainda é jogável
## para decidir se devolve o pause; rodando ANTES de `_state = "dead"` ela
## respondia que sim e ressuscitava o pause sobre a tela de fim. E a árvore
## precisa sair do pause explicitamente: a morte pode vir de dentro do terminal
## (`rm -rf /`), que só existe com a run congelada.
func _on_player_died() -> void:
	if _state != "play":
		return
	_state = "dead"
	_clear_abandon_confirmation()
	_panel_kit._close_terminal()
	if is_instance_valid(_pause_screen):
		_pause_screen.visible = false
		ScreenKit.close_focus(_pause_screen)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	spawner.stop()
	overlay.aberrate(1.4)
	var t := get_tree().create_timer(1.3, true, false, true)
	t.timeout.connect(_show_game_over)

func _show_game_over() -> void:
	_clear_abandon_confirmation()
	_story_victory = false
	_story_next_stage = -1
	Game.end_run()
	var s := Game.stats
	var acc := 0.0
	if s["shots"] > 0:
		acc = float(s["hits"]) / float(s["shots"]) * 100.0
	# Rótulo e valor são campos separados. Era aqui que nascia o B2
	# (`SEED          SEED -19999...`, porque run_seed_text() já traz o prefixo)
	# e o B3 (sete linhas em três colunas, alinhadas com espaço contado à mão).
	_run_summary.show_summary({
		"title": tr("OVER_TITLE"),
		"accent": Balance.COL_DANGER,
		"subtitle": tr("OVER_TERMINATED_BY").format([str(s.get("killer", "DAEMON"))]),
		"score_caption": tr("STAT_SCORE"),
		"score_value": "%07d" % Game.score,
		"badge": tr("OVER_NEW_RECORD") if Game.new_best else "",
		"stats": [
			[tr("STAT_CYCLES"), "%d" % int(s["wave"])],
			[tr("STAT_DAEMONS_PURGED"), "%d" % int(s["kills"])],
			[tr("STAT_UPTIME"), "%02d:%02d" % [int(s["time"] / 60.0), int(s["time"]) % 60]],
			[tr("STAT_ACCURACY"), "%d%%" % int(acc)],
		],
		"meta": "%s / %s / %s / %s / %s" % [
			Game.program_def()["name"], Game.build_string(),
			tr("SUMMARY_BEST") % Game.best_for_mode(), tr("SUMMARY_SEED") % Game.run_seed, _heals_line(s),
		],
		"primary": tr("OVER_REBOOT"),
		"secondary": tr("OVER_ABANDON"),
	})
	_show_run_summary()
	Sfx.play("gameover", 0.9, 0.0)
	Sfx.duck_music(-8.0, 2.0)


## Exibe o painel de fim de run com fade. Compartilhado por morte e vitória.
func _show_run_summary() -> void:
	_run_summary.modulate.a = 0.0
	_run_summary.visible = true
	ScreenKit.open_focus(_run_summary)
	var tw := create_tween()
	tw.tween_property(_run_summary, "modulate:a", 1.0, Design.MOTION_NORMAL)


func _restart_current_run() -> void:
	if Game.mode == "story":
		Game.start_story(Game.story_stage_index)
	else:
		Game.start_run()

## Ação secundária da tela de fim de run. Na morte volta ao menu; na vitória
## de stage volta ao seletor — o rótulo muda junto, em show_summary().
func _handle_over_secondary() -> void:
	Game.to_menu()


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
	var next_line := tr("ARENA_NEXT") % Game.story_stage_def(_story_next_stage).get("path", "") if _story_next_stage >= 0 else tr("STORY_ACT1_DONE")
	if _story_next_stage < 0:
		next_line = tr("STORY_BONUS_DONE") if stage_id == "temple_god" else tr("STORY_ALL_DONE")
		if stage_id == "temple_god":
			next_line += "  //  " + tr("STORY_RAINBOW_UNLOCKED")
	# Fim de ATO: a última fase do ato entrega a tinta de campo, e é ela que dá
	# um arco ao conjunto em vez de a corrente simplesmente continuar.
	if StoryData.is_act_final_stage(stage_id):
		var act_id := str(_story_stage.get("act", "unix"))
		next_line = tr("STORY_ACT_COMPLETE") % [StoryData.localized_act_label(act_id), tr("TINT_%s" % StoryData.act_reward(act_id).to_upper())]
	var victory_title := StoryData.localized_title(stage_id)
	var st := Game.stats
	var rank := Game.story_stage_rank(stage_id)
	var par := StoryData.stage_par_seconds(stage_id)
	_speak_beat("CLEAR")
	_run_summary.show_summary({
		"title": tr("VICTORY_TITLE"),
		"accent": _story_stage.get("theme", {}).get("accent", Balance.COL_PLAYER),
		"subtitle": "%s // %s" % [_story_stage.get("path", ""), victory_title],
		"score_caption": tr("STAT_STAGE_SCORE"),
		"score_value": "%07d" % Game.score,
		"badge": next_line,
		"stats": [
			[tr("STAT_RANK"), rank],
			[tr("STAT_DAEMONS_PURGED"), "%d" % int(st.get("kills", 0))],
			[tr("STAT_UPTIME"), "%02d:%02d / %02d:%02d" % [int(float(st.get("time", 0.0)) / 60.0), int(float(st.get("time", 0.0))) % 60, int(par / 60.0), int(par) % 60]],
			[tr("STAT_STAGE_BEST"), "%07d" % Game.story_stage_best(index)],
		],
		"meta": victory_title if victory_title != "" else tr("ARENA_STAGE_CLEARED"),
		"primary": tr("VICTORY_NEXT_STAGE") if _story_next_stage >= 0 else tr("VICTORY_RETURN"),
		"secondary": tr("VICTORY_STORY_SELECT"),
	})
	_show_run_summary()
	Sfx.play("ready", 1.2, -2.0)


func _heals_line(s: Dictionary) -> String:
	var heals: Dictionary = s.get("heals", {})
	var total := 0
	for k in heals:
		total += int(heals[k])
	if total == 0:
		return tr("ARENA_HEALS_NONE")
	var parts: Array = []
	for k in heals:
		parts.append("%s x%d" % [str(k).to_upper(), int(heals[k])])
	return tr("ARENA_HEALS") % [total, ", ".join(parts)]

func _on_enemy_died(e: EnemyBase) -> void:
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
	# O grupo "motes" foi esvaziado pela reescrita MultiMesh; contar por ele
	# devolvia sempre 0 e o teto nunca era aplicado. O campo sabe seu tamanho.
	var live_motes: int = mote_field.count() if is_instance_valid(mote_field) else 0
	n = mini(n, maxi(0, Balance.MOTE_CAP - live_motes))
	var field := mote_field if is_instance_valid(mote_field) else null
	if field != null:
		for i in n:
			field.spawn_burst(e.global_position, 1)
	if not is_fragment and not was_split and Game.recover_chance(e.elite) > 0.0 and Game.rng.randf() < Game.recover_chance(e.elite):
		_spawn_recover(e.global_position)
	if boss_reward:
		if player.hp < player.max_hp:
			player.heal(1, "boss")
		if not is_fragment and Game.mode != "onehp":
			_spawn_recover(e.global_position)
		if not Game.unlocked_programs.has("rootlet") and int(Game.stats.get("damage", 0)) == _boss_dmg_snapshot:
			Game.unlock_program("rootlet")
			hud.show_banner(tr("ARENA_PROGRAM_UNLOCKED"), tr("ARENA_ROOTLET_AVAILABLE"), 2.4)
			Sfx.play("ready", 1.2, -4.0)
		hud.clear_boss_encounter()
		overlay.aberrate(1.2)
		hud.show_banner(tr("ARENA_ROOT_PURGED"), tr("ARENA_RECOVER"), 2.0)
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
		player.heal(1, "vampic")
		Fx.text(player.global_position + Vector2(0, -52), "+1", Balance.COL_PLAYER, 13)
	Fx.text(player.global_position + Vector2(0, -40), tr("ARENA_CHAIN") % m, Balance.COL_MOTE, 18 if m < Balance.COMBO_MAX else 22)
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
		if event.physical_keycode in [KEY_F1, KEY_F2, KEY_F3, KEY_F4]:
			get_viewport().set_input_as_handled()
			return
	if _terminal_panel != null and _terminal_panel.visible:
		if event.is_action_pressed("pause"):
			_panel_kit._close_terminal()
			get_viewport().set_input_as_handled()
		return
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
		_restart_current_run()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("confirm") and _state == "dead":
		_restart_current_run()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("abandon") and get_tree().paused and _state == "play":
		if event is InputEventKey and event.echo:
			get_viewport().set_input_as_handled()
			return
		_request_abandon_confirmation()
		get_viewport().set_input_as_handled()

func _set_paused(v: bool) -> void:
	if not v:
		_clear_abandon_confirmation()
		_panel_kit._close_terminal()
	get_tree().paused = v
	_pause_screen.visible = v
	if v:
		ScreenKit.open_focus(_pause_screen, _pause_screen.get("_action_blocks")[0].get_meta("hit"))
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_pause_screen.set_volumes(Sfx.sfx_vol, Sfx.music_vol)
		_pause_screen.set_run_state([
			[tr("STAT_CYCLE"), "%02d" % Game.wave],
			[tr("STAT_SCORE"), "%07d" % Game.score],
			[tr("STAT_CHAIN"), "x%d" % Game.mult],
			[tr("STAT_INTEGRITY"), "%d/%d" % [player.hp, player.max_hp]],
		], "%s / %s" % [Game.program_def()["name"], Game.build_string()])
	Sfx.play("ui", 1.0, -6.0)
	if not v:
		ScreenKit.close_focus(_pause_screen)
		_try_show_patch()

## Rota usada pelo botão de fechar do TerminalPanel.
func _close_terminal() -> void:
	_panel_kit._close_terminal()


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
			var man_desc := _localized_entry_text(entry, "DESC")
			var man_bugs := _localized_entry_text(entry, "BUGS")
			return "%s\n%s\n%s: %s\n%s" % [entry["name"], man_desc, tr("TERM_MAN_BUGS"), man_bugs, tr("TERM_MAN_THREAT") % int(entry["threat"])]
	return "man: no entry for %s" % query.strip_edges()

## Mesma regra do painel: inglês do ENTRIES como fallback, nunca chave crua.
func _localized_entry_text(entry: Dictionary, field: String) -> String:
	var key := "BEST_%s_%s" % [field.to_upper(), str(entry.get("id", "")).to_upper()]
	var translated := TranslationServer.translate(key)
	if translated == key:
		return str(entry.get(field.to_lower(), ""))
	return translated

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
	player.heal(1, "sudo")
	Fx.text(player.global_position + Vector2(0, -30), "+INTEGRITY // SUDO", Balance.COL_PLAYER, 14)
	return "sudo: heal granted // integrity +1"

## O comando mata a run de dentro do terminal, que só existe com a árvore
## pausada. Ele desfaz esse estado ANTES de matar: fecha terminal e pause e
## despausa, para a morte seguir o mesmo caminho de qualquer outra morte.
func _terminal_rm_rf() -> String:
	if _state != "play" or Game.state != Game.State.PLAYING:
		return "rm: process already stopped"
	Game.log_event("PANIC // rm -rf / // filesystem destroyed")
	_clear_abandon_confirmation()
	_panel_kit._close_terminal()
	if is_instance_valid(_pause_screen):
		_pause_screen.visible = false
		ScreenKit.close_focus(_pause_screen)
	get_tree().paused = false
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
	if not get_tree().paused or _state != "play":
		return
	if _abandon_armed and _abandon_t > 0.0:
		_clear_abandon_confirmation()
		_set_paused(false)
		Game.to_menu()
		return
	_abandon_generation += 1
	_abandon_armed = true
	_abandon_t = ABANDON_CONFIRM_WINDOW
	# O aviso vive no PRÓPRIO bloco de abandono agora. Antes era uma linha
	# solta desenhada dentro da moldura vermelha, o que fazia [ESC] e [R]
	# parecerem parte do abandono (B6).
	if is_instance_valid(_pause_screen):
		_pause_screen.set_abandon_armed(true)
	if _pause_info != null and is_instance_valid(_pause_info):
		_pause_info.text = PAUSE_INFO_CONFIRM
	var generation := _abandon_generation
	_abandon_timer = get_tree().create_timer(ABANDON_CONFIRM_WINDOW, true, false, true)
	_abandon_timer.timeout.connect(_on_abandon_timeout.bind(generation))

func _on_abandon_timeout(generation: int) -> void:
	if _abandon_armed and generation == _abandon_generation:
		_clear_abandon_confirmation()

func _clear_abandon_confirmation() -> void:
	_abandon_generation += 1
	_abandon_armed = false
	_abandon_t = 0.0
	_abandon_timer = null
	if is_instance_valid(_pause_screen):
		_pause_screen.set_abandon_armed(false)
	if _pause_info != null and is_instance_valid(_pause_info):
		_pause_info.text = PAUSE_INFO_DEFAULT

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
	if _abandon_armed and get_tree().paused:
		_abandon_t = maxf(_abandon_t - delta, 0.0)
		if _abandon_t <= 0.0:
			_clear_abandon_confirmation()
	if _windows_watermark != null and is_instance_valid(_windows_watermark):
		_windows_watermark.visible = fmod(float(Game.stats.get("time", 0.0)), 2.6) < 2.0
	# Tinta cosmética: dentro do TempleOS é sempre o rainbow, que é a fase; fora
	# do story é a que a jogadora escolheu entre as que destravou limpando atos.
	var active_tint := "rainbow" if _temple_mode else (Game.field_tint if Game.mode != "story" else "")
	if active_tint != "":
		var tint := Balance.field_tint_color(active_tint, float(Game.stats.get("time", 0.0)))
		_era_color = tint
		if hud != null:
			hud.set_era_accent(tint)
		if walls != null:
			walls.set_tint(tint)
		if _dust != null:
			_dust.color = Color(tint.r, tint.g, tint.b, 0.22)
	var want_hidden: bool = _wants_hidden_cursor()
	var target_mouse := Input.MOUSE_MODE_HIDDEN if want_hidden else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != target_mouse:
		Input.mouse_mode = target_mouse
	if _state == "play" and not get_tree().paused and Game.state == Game.State.PLAYING:
		if Input.is_action_pressed("restart"):
			_restart_hold_t += delta
			if _restart_hold_t >= RESTART_HOLD_DURATION and not _restart_triggered:
				_restart_triggered = true
				Game.log_event(tr("CTRL_SPEEDRUN_RESTART"))
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
		_bg_mat.set_shader_parameter("era_mix",
			Balance.ERA_MIX_STORY if Game.mode == "story" else Balance.ERA_MIX_ENDLESS)
		_bg_mat.set_shader_parameter("corruption", 0.0 if Game.mode == "story" else _stage_kit.background_corruption_for_wave(Game.wave))
	if _state == "play":
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

## Predicado puro do cursor: gameplay com reticle pede cursor oculto; qualquer
## modal (pausa/patch/terminal/summary), debug aberto ou reticle ausente pede
## cursor visível. O _process só aplica; o teste cobre o contrato aqui.
func _wants_hidden_cursor() -> bool:
	var debug_open: bool = _debug_panel != null and _debug_panel.visible
	return _state == "play" and not get_tree().paused and reticle != null and not debug_open

func _exit_tree() -> void:
	_clear_abandon_confirmation()
	Balance.clear_arena_size_override()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

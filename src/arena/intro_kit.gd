extends RefCounted

const StoryIntroPanelScript = preload("res://src/ui/story_intro_panel.gd")

## Arena intro/story kit: wave-intro bars, story intro card, boss intro, event
## banner. Functions are moved verbatim from src/arena/arena.gd; Arena-owned
## state and non-moved calls are prefixed with `a.` (plan G5). Untyped owner
## reference avoids a preload cycle. No behavior changes.

var a


func _init(arena) -> void:
	a = arena

func _build_intro() -> void:
	for i in 2:
		var bar := ColorRect.new()
		bar.color = Color(0.005, 0.006, 0.015, 0.92)
		bar.set_anchors_preset(Control.PRESET_FULL_RECT)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cl := CanvasLayer.new()
		cl.layer = 55
		cl.add_child(bar)
		a.add_child(cl)
		bar.scale.y = 0.001
		bar.pivot_offset = Vector2(0, 0) if i == 0 else Vector2(0, a.get_viewport_rect().size.y)
		a._intro_bars.append(bar)
	a._intro_label = a._panel_kit._make_label("", 30, Balance.COL_DANGER)
	a._panel_kit._center_panel_control(a._intro_label, 290.0, 48.0)
	a._intro_label.modulate.a = 0.0
	a._intro_quote = a._panel_kit._make_label("", 15, Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.8))
	a._panel_kit._center_panel_control(a._intro_quote, 344.0, 28.0)
	a._intro_quote.modulate.a = 0.0
	var il_layer := CanvasLayer.new()
	il_layer.layer = 56
	il_layer.add_child(a._intro_label)
	a.add_child(il_layer)

func _build_story_intro() -> void:
	a._story_intro_panel = StoryIntroPanelScript.new()
	a._story_intro_panel.visible = false
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(a._story_intro_panel)
	a.add_child(layer)
	a._story_intro_path = a._story_intro_panel.path_label
	a._story_intro_title = a._story_intro_panel.title_label
	a._story_intro_text = a._story_intro_panel.body_label
	a._story_intro_hint = a._story_intro_panel.hint_label

func _show_story_intro() -> void:
	if a._story_intro_panel == null or a._story_stage.is_empty():
		return
	var act_label := "ACT 1 // UNIX RECOVERY LOG"
	if str(a._story_stage.get("act", "")) == "windows":
		act_label = "ACT 2 // WINDOWS RECOVERY LOG"
	elif str(a._story_stage.get("act", "")) == "templeos":
		act_label = "BONUS ACT // TEMPLEOS ORACLE LOG"
	a._story_intro_panel.set_story(
		str(a._story_stage.get("path", "")),
		str(a._story_stage.get("title", "STORY STAGE")),
		str(a._story_stage.get("intro", "")),
		act_label
	)
	_fit_story_intro_text()
	a._story_intro_panel.modulate.a = 0.0
	a._story_intro_panel.visible = true
	a._story_intro_state = 1
	a._story_intro_t = 0.0

func _fit_story_intro_text() -> void:
	var cap := minf(a.STORY_INTRO_MAX_HEIGHT, a.get_viewport_rect().size.y * 0.3)
	if a._story_intro_panel != null and a._story_intro_panel.has_method("fit_body"):
		a._story_intro_panel.fit_body(cap, a.STORY_INTRO_FONT_FLOOR)

func story_intro_active() -> bool:
	return a._story_intro_state != 0

func dismiss_story_intro() -> bool:
	if a._story_intro_state != 2 or a._story_intro_t < a.STORY_INTRO_MIN_HOLD:
		return false
	_finish_story_intro()
	return true

func _finish_story_intro() -> void:
	if a._story_intro_state != 2:
		return
	a._story_intro_state = 3
	a._story_intro_t = 0.0
	if a._story_intro_hint != null:
		a._story_intro_hint.modulate.a = 0.0
	_begin_story_spawning()

func _begin_story_spawning() -> void:
	if a._story_spawn_started or a._story_stage.is_empty():
		return
	a._story_spawn_started = true
	a.spawner.start_story(a, a.enemy_container, a._story_stage)

func _tick_story_intro(delta: float) -> void:
	a._story_intro_t += delta
	match a._story_intro_state:
		1:
			a._story_intro_panel.modulate.a = minf(a._story_intro_t / a.STORY_INTRO_FADE_IN, 1.0)
			if a._story_intro_t >= a.STORY_INTRO_FADE_IN:
				a._story_intro_state = 2
				a._story_intro_t = 0.0
		2:
			if a._story_intro_hint != null:
				a._story_intro_hint.modulate.a = 1.0 if a._story_intro_t >= a.STORY_INTRO_MIN_HOLD else 0.0
			if a._story_intro_t >= a.STORY_INTRO_AUTO_DISMISS:
				_finish_story_intro()
		3:
			a._story_intro_panel.modulate.a = maxf(1.0 - a._story_intro_t / a.STORY_INTRO_FADE_OUT, 0.0)
			if a._story_intro_t >= a.STORY_INTRO_FADE_OUT:
				if a._story_intro_panel != null and is_instance_valid(a._story_intro_panel):
					a._story_intro_panel.visible = false
				a._story_intro_state = 0

func _apply_story_theme(theme: Dictionary) -> void:
	if theme.is_empty():
		return
	var base_col: Color = theme.get("base_col", Color("080b18"))
	var grid_col: Color = theme.get("grid_col", Balance.COL_GRID)
	var glow_col: Color = theme.get("glow_col", Color("0d4160"))
	var accent: Color = theme.get("accent", Balance.COL_PLAYER)
	a._era_color = accent
	if a.hud != null:
		a.hud.set_era_accent(accent)
	if a._bg_mat != null:
		a._bg_mat.set_shader_parameter("base_col", base_col)
		a._bg_mat.set_shader_parameter("grid_col", grid_col)
		a._bg_mat.set_shader_parameter("glow_col", glow_col)
		a._bg_mat.set_shader_parameter("era_tint", Vector3(accent.r, accent.g, accent.b))
		a._bg_mat.set_shader_parameter("era_mix", 0.28)
		a._bg_mat.set_shader_parameter("corruption", 0.0)
	if a.walls != null:
		a.walls.set_tint(accent)
	if a._dust != null:
		a._dust.color = Color(accent.r, accent.g, accent.b, 0.18)

func _run_boss_intro() -> void:
	var idx := int(Game.wave / float(Balance.BOSS_EVERY))
	a._intro_label.text = RootBoss.title_for_index(idx) + " // KERNEL DAEMON"
	a._intro_quote.text = '"' + RootBoss.quote_for_index(idx) + '"'
	var tw: Tween = a.create_tween()
	tw.set_parallel(true)
	tw.tween_property(a._intro_bars[0], "scale:y", 1.0, 0.4).from(0.001).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(a._intro_bars[1], "scale:y", 1.0, 0.4).from(0.001).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(a._intro_label, "modulate:a", 1.0, 0.5).set_delay(0.3)
	tw.tween_property(a._intro_quote, "modulate:a", 1.0, 0.5).set_delay(0.45)
	var tw2: Tween = a.create_tween()
	tw2.tween_interval(2.0)
	tw2.tween_property(a._intro_label, "modulate:a", 0.0, 0.4)
	tw2.parallel().tween_property(a._intro_quote, "modulate:a", 0.0, 0.4)
	tw2.tween_callback(func() -> void:
		var tw3: Tween = a.create_tween()
		tw3.set_parallel(true)
		tw3.tween_property(a._intro_bars[0], "scale:y", 0.001, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw3.tween_property(a._intro_bars[1], "scale:y", 0.001, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	)
	Fx.shake(0.25)

func show_event_banner(txt: String) -> void:
	a.hud.show_banner("CYCLE %02d // %s" % [Game.wave, txt], "", 1.8)
	Sfx.play("charge", 0.8, -8.0)

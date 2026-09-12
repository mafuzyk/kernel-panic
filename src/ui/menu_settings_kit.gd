extends RefCounted

## Menu settings kit: settings panel build/layout, keybind capture e controles.
## A lógica continua separada de `menu.gd`, mas a superfície visual segue agora
## a direção editorial do MenuShell: grotesca para hierarquia, mono para estado,
## seleção por rail/underline e sem TacticalChrome decorativo.

var m

const SETTINGS_SECTIONS := ["AUDIO", "VIDEO", "GAMEPLAY", "CONTROLS", "ACCESSIBILITY", "SAVE DATA"]
const SECTION_CHIP_KEYS := {
	"AUDIO": "SET_CHIP_AUDIO", "VIDEO": "SET_CHIP_VIDEO", "GAMEPLAY": "SET_CHIP_GAMEPLAY", "CONTROLS": "SET_CHIP_CONTROLS",
	"ACCESSIBILITY": "SET_CHIP_ACCESSIBILITY", "SAVE DATA": "SET_CHIP_SAVEDATA",
}


static func section_chip_label(section: String) -> String:
	return TranslationServer.translate(str(SECTION_CHIP_KEYS.get(section, section)))

## As strings de `SETTINGS_SECTIONS` são IDENTIFICADORES — `assign_section()` e
## `set_active_section()` casam por elas. O que o jogador lê sai daqui, pelas
## chaves do CSV. Traduzir o identificador quebraria a navegação inteira.
const SECTION_KEYS := {
	"AUDIO": "SET_NAV_AUDIO",
	"VIDEO": "SET_NAV_VIDEO",
	"GAMEPLAY": "SET_NAV_GAMEPLAY",
	"CONTROLS": "SET_NAV_CONTROLS",
	"ACCESSIBILITY": "SET_NAV_ACCESSIBILITY",
	"SAVE DATA": "SET_NAV_SAVEDATA",
}


static func section_label(section: String) -> String:
	return TranslationServer.translate(str(SECTION_KEYS.get(section, section)))
const COMPACT_BREAKPOINT := 760.0
var _active_section := "AUDIO"
var _section_members := {}
var _viewport_override := Vector2.ZERO


func _init(menu) -> void:
	m = menu

func settings_layout_for_viewport(viewport: Vector2) -> Dictionary:
	var compact: bool = viewport.x < COMPACT_BREAKPOINT
	var margin_x := float(Design.SPACE_XL if compact else Design.SPACE_4XL)
	var margin_y := float(Design.SPACE_LG if compact else Design.SPACE_2XL)
	var workstation := Rect2(
		Vector2(margin_x, margin_y),
		Vector2(maxf(viewport.x - margin_x * 2.0, 280.0), maxf(viewport.y - margin_y * 2.0, 240.0))
	)
	var footer_h := 56.0
	var footer := Rect2(
		Vector2(workstation.position.x, workstation.end.y - footer_h),
		Vector2(workstation.size.x, footer_h)
	)
	var navigation := Rect2()
	var chips := Rect2()
	var content := Rect2()
	var content_top := workstation.position.y + (104.0 if compact else 124.0)
	if compact:
		chips = Rect2(Vector2(workstation.position.x, content_top), Vector2(workstation.size.x, 40.0))
		content = Rect2(Vector2(workstation.position.x, chips.end.y + Design.SPACE_LG), Vector2(workstation.size.x, maxf(footer.position.y - chips.end.y - Design.SPACE_XL, 0.0)))
	else:
		var navigation_width := minf(240.0, maxf(180.0, workstation.size.x * 0.20))
		navigation = Rect2(Vector2(workstation.position.x, content_top), Vector2(navigation_width, maxf(footer.position.y - content_top - Design.SPACE_LG, 0.0)))
		var content_x := navigation.end.x + Design.SPACE_2XL
		content = Rect2(Vector2(content_x, content_top), Vector2(maxf(workstation.end.x - content_x, 0.0), navigation.size.y))
	var title_height := 64.0 if not compact else 48.0
	var title_size := Design.TEXT_TITLE if not compact else Design.TEXT_HEADING
	var title := Rect2(workstation.position.x, workstation.position.y + Design.SPACE_SM, workstation.size.x, title_height)
	return {
		"workstation": workstation,
		"navigation": navigation,
		"content": content,
		"footer": footer,
		"title": title,
		"title_size": title_size,
		"compact": compact,
		"chips": chips,
	}

func _layout_settings() -> void:
	if m._settings_panel == null or not is_instance_valid(m._settings_panel):
		return
	var settings_layout := _live_settings_layout()
	var workstation: Rect2 = settings_layout["workstation"]
	var navigation: Rect2 = settings_layout["navigation"]
	var content: Rect2 = settings_layout["content"]
	var footer: Rect2 = settings_layout["footer"]
	var title: Rect2 = settings_layout["title"]
	if m._settings_frame != null and is_instance_valid(m._settings_frame):
		m._settings_frame.position = workstation.position
		m._settings_frame.size = workstation.size
	if m._settings_scroll != null and is_instance_valid(m._settings_scroll):
		m._settings_scroll.offset_left = content.position.x
		m._settings_scroll.offset_right = content.end.x
		m._settings_scroll.offset_top = content.position.y + 8.0
		m._settings_scroll.offset_bottom = footer.position.y - 8.0
	if m._settings_box != null and is_instance_valid(m._settings_box):
		# Mesmo teto do construtor. Esta linha reescrevia a largura a cada
		# passada de layout e desfazia o limite de coluna de formulário.
		m._settings_box.custom_minimum_size.x = clampf(content.size.x - 28.0, 240.0, Design.CONTENT_MAX_FORM)
	if m._settings_title != null and is_instance_valid(m._settings_title):
		m._settings_title.position = title.position
		m._settings_title.size = title.size
		m._settings_title.add_theme_font_size_override("font_size", int(settings_layout["title_size"]))
	if m._settings_footer_row != null and is_instance_valid(m._settings_footer_row):
		m._settings_footer_row.position = footer.position
		m._settings_footer_row.size = footer.size
	var compact: bool = bool(settings_layout.get("compact", false))
	if m._settings_nav_hint != null and is_instance_valid(m._settings_nav_hint):
		m._settings_nav_hint.visible = not compact
	if m._settings_chips_row != null and is_instance_valid(m._settings_chips_row):
		m._settings_chips_row.visible = compact
		m._settings_chips_row.position = (settings_layout["chips"] as Rect2).position
		m._settings_chips_row.size = (settings_layout["chips"] as Rect2).size
	for index in m._settings_nav_buttons.size():
		var nav_button: Button = m._settings_nav_buttons[index]
		if not is_instance_valid(nav_button):
			continue
		nav_button.visible = not compact
		if compact:
			continue
		nav_button.position = navigation.position + Vector2(10.0, 12.0 + float(index) * 48.0)
		nav_button.size = Vector2(maxf(navigation.size.x - 20.0, 96.0), 38.0)
	if m._settings_keybind_grid != null and is_instance_valid(m._settings_keybind_grid):
		m._settings_keybind_grid.columns = 1 if content.size.x < 600.0 else 2


func _nav_style(selected: bool, hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Design.SURFACE_RAISED if selected else (Design.alpha(Design.TEXT_PRIMARY, 0.06) if hover else Color(0, 0, 0, 0))
	style.border_color = Design.ACCENT if selected else Color(0, 0, 0, 0)
	style.border_width_left = int(Design.STROKE_THICK) if selected else 0
	style.content_margin_left = Design.SPACE_LG
	style.content_margin_right = Design.SPACE_MD
	style.content_margin_top = Design.SPACE_SM
	style.content_margin_bottom = Design.SPACE_SM
	return style


func _chip_style(selected: bool, hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Design.alpha(Design.TEXT_PRIMARY, 0.06) if hover else Color(0, 0, 0, 0)
	style.border_color = Design.ACCENT if selected else Color(0, 0, 0, 0)
	style.border_width_bottom = int(Design.STROKE_REGULAR) if selected else 0
	style.content_margin_left = Design.SPACE_SM
	style.content_margin_right = Design.SPACE_SM
	style.content_margin_top = Design.SPACE_SM
	style.content_margin_bottom = Design.SPACE_SM
	return style

func _build_settings() -> void:
	m._settings_panel = Control.new()
	m._settings_panel.theme = UiTheme.shared()
	m._settings_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m._settings_panel.visible = false
	m._settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.name = "SettingsDim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Opaco por contrato, como os outros overlays. Estava em 0.88 — o mesmo
	# defeito do painel de conquistas (B1 da auditoria), só que aqui o menu
	# atrás é o shell novo e o vazamento fica ainda mais evidente.
	dim.color = Design.SURFACE
	m._settings_panel.add_child(dim)
	var settings_layout := _live_settings_layout()
	var workstation: Rect2 = settings_layout["workstation"]
	var navigation: Rect2 = settings_layout["navigation"]
	var content: Rect2 = settings_layout["content"]
	var footer: Rect2 = settings_layout["footer"]
	var scroll := ScrollContainer.new()
	scroll.name = "SettingsScroll"
	scroll.anchor_left = 0.0
	scroll.anchor_right = 0.0
	scroll.anchor_top = 0.0
	scroll.anchor_bottom = 0.0
	m._settings_scroll = scroll
	var frame := Panel.new()
	frame.name = "SettingsFrame"
	frame.position = workstation.position
	frame.size = workstation.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	frame_style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	frame_style.set_border_width_all(0)
	frame.add_theme_stylebox_override("panel", frame_style)
	m._settings_frame = frame
	m._settings_panel.add_child(frame)
	m._settings_workstation_chrome = null
	m._settings_navigation_chrome = null
	scroll.offset_left = content.position.x
	scroll.offset_right = content.end.x
	scroll.offset_top = content.position.y + 8.0
	scroll.offset_bottom = footer.position.y - 8.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	m._settings_panel.add_child(scroll)
	# Largura MÁXIMA de formulário. Sem isto a coluna ocupava toda a área de
	# conteúdo (~1200px em 1920): os sliders esticavam de ponta a ponta e o
	# indicador do CheckButton — que o Godot ancora na borda direita — ficava a
	# mais de mil pixels do próprio rótulo. É o B5 da auditoria no settings.
	# O ScrollContainer estica o filho até a própria largura quando a rolagem
	# horizontal está desabilitada — `custom_minimum_size` é MÍNIMO, não máximo,
	# então limitar a coluna por ali não fazia efeito nenhum. A coluna vai dentro
	# de um HBox com espaçador: o Scroll estica o HBox, a coluna fica no teto.
	var form_wrap := HBoxContainer.new()
	form_wrap.name = "SettingsFormWrap"
	form_wrap.add_theme_constant_override("separation", 0)
	scroll.add_child(form_wrap)
	var box := VBoxContainer.new()
	m._settings_box = box
	box.custom_minimum_size.x = clampf(content.size.x - 28.0, 240.0, Design.CONTENT_MAX_FORM)
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_theme_constant_override("separation", Design.SPACE_XL)
	form_wrap.add_child(box)
	var form_spacer := Control.new()
	form_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	form_wrap.add_child(form_spacer)
	var title := ScreenKit.grot(tr("SET_TITLE") % section_label("AUDIO"), Design.TEXT_TITLE,
		Design.WEIGHT_BLACK, Design.TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var title_rect: Rect2 = settings_layout["title"]
	title.position = title_rect.position
	title.size = title_rect.size
	title.add_theme_font_size_override("font_size", int(settings_layout["title_size"]))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m._settings_title = title
	m._settings_panel.add_child(title)
	var audio_label := _settings_group_label(tr("SET_HEAD_AUDIO"))
	assign_section(audio_label, "AUDIO")
	box.add_child(audio_label)
	var sfx_row := _make_slider_row(tr("SET_SFX"), Sfx.sfx_vol, func(v: float) -> void:
		Sfx.set_sfx_vol(v)
		Sfx.play("ui", 1.0, -6.0)
	)
	assign_section(sfx_row, "AUDIO")
	box.add_child(sfx_row)
	var music_row := _make_slider_row(tr("SET_MUSIC"), Sfx.music_vol, func(v: float) -> void:
		Sfx.set_music_vol(v)
	)
	assign_section(music_row, "AUDIO")
	box.add_child(music_row)
	var mute := CheckButton.new()
	mute.text = tr("SET_MUTE_ALL")
	_style_toggle(mute)
	mute.button_pressed = Sfx.muted
	mute.toggled.connect(func(on: bool) -> void:
		Sfx.set_muted(on)
	)
	assign_section(mute, "AUDIO")
	box.add_child(_bounded_row(mute))
	var mute_hint := _settings_group_label(tr("SET_MUTE_HINT"))
	mute_hint.add_theme_font_size_override("font_size", 12)
	mute_hint.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.4))
	assign_section(mute_hint, "AUDIO")
	box.add_child(mute_hint)
	_build_video_section(box)
	var gameplay_label := _settings_group_label(tr("SET_HEAD_GAMEPLAY"))
	assign_section(gameplay_label, "GAMEPLAY")
	box.add_child(gameplay_label)
	var haptics := CheckButton.new()
	haptics.text = tr("SET_HAPTICS")
	_style_toggle(haptics)
	haptics.button_pressed = Sfx.haptics_enabled
	haptics.toggled.connect(func(on: bool) -> void:
		Sfx.haptics_enabled = on
		Sfx.save_settings()
	)
	assign_section(haptics, "GAMEPLAY")
	box.add_child(haptics)
	var aim_btn := Button.new()
	aim_btn.flat = true
	aim_btn.text = tr("SET_AIM") % Sfx.aim_mode.to_upper()
	aim_btn.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	aim_btn.add_theme_font_size_override("font_size", 17)
	aim_btn.add_theme_color_override("font_color", Balance.COL_TEXT)
	aim_btn.add_theme_color_override("font_hover_color", Balance.COL_PLAYER)
	aim_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	aim_btn.pressed.connect(func() -> void:
		var order := ["drag", "stick", "lockon"]
		Sfx.aim_mode = order[(order.find(Sfx.aim_mode) + 1) % order.size()]
		m._refresh_aim_label(aim_btn)
		Sfx.save_settings()
	)
	m._aim_btn_ref = aim_btn
	m._refresh_aim_label(aim_btn)
	assign_section(aim_btn, "GAMEPLAY")
	box.add_child(aim_btn)
	var touch_sz := Button.new()
	touch_sz.flat = true
	touch_sz.text = tr("SET_TOUCH_SIZE") % [tr("SET_VAL_SMALL"), tr("SET_VAL_NORMAL"), tr("SET_VAL_BIG")][m._touch_scale_idx(Sfx.touch_scale)]
	touch_sz.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	touch_sz.add_theme_font_size_override("font_size", 17)
	touch_sz.add_theme_color_override("font_color", Balance.COL_TEXT)
	touch_sz.add_theme_color_override("font_hover_color", Balance.COL_PLAYER)
	touch_sz.alignment = HORIZONTAL_ALIGNMENT_LEFT
	touch_sz.pressed.connect(func() -> void:
		var idx: int = m._next_touch_scale_idx(Sfx.touch_scale)
		Sfx.touch_scale = [0.85, 1.0, 1.2][idx]
		touch_sz.text = tr("SET_TOUCH_SIZE") % [tr("SET_VAL_SMALL"), tr("SET_VAL_NORMAL"), tr("SET_VAL_BIG")][idx]
		Sfx.save_settings()
	)
	touch_sz.set_meta("touch_only", true)
	assign_section(touch_sz, "GAMEPLAY")
	box.add_child(touch_sz)
	var shake_btn := Button.new()
	shake_btn.flat = true
	shake_btn.text = tr("SET_SHAKE") % [tr("SET_VAL_OFF"), tr("SET_VAL_LOW"), tr("SET_VAL_FULL")][clampi(Sfx.shake_level, 0, 2)]
	shake_btn.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	shake_btn.add_theme_font_size_override("font_size", 17)
	shake_btn.add_theme_color_override("font_color", Balance.COL_TEXT)
	shake_btn.add_theme_color_override("font_hover_color", Balance.COL_PLAYER)
	shake_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	shake_btn.pressed.connect(func() -> void:
		Sfx.shake_level = (Sfx.shake_level + 1) % 3
		shake_btn.text = tr("SET_SHAKE") % [tr("SET_VAL_OFF"), tr("SET_VAL_LOW"), tr("SET_VAL_FULL")][Sfx.shake_level]
		Sfx.save_settings()
	)
	assign_section(shake_btn, "GAMEPLAY")
	box.add_child(shake_btn)
	var run_info := Button.new()
	run_info.flat = true
	run_info.text = tr("SET_SPEEDRUN") % (tr("SET_VAL_ON") if Sfx.show_run_info else tr("SET_VAL_OFF"))
	run_info.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	run_info.add_theme_font_size_override("font_size", 17)
	run_info.add_theme_color_override("font_color", Balance.COL_TEXT)
	run_info.add_theme_color_override("font_hover_color", Balance.COL_PLAYER)
	run_info.alignment = HORIZONTAL_ALIGNMENT_LEFT
	run_info.pressed.connect(func() -> void:
		Sfx.show_run_info = not Sfx.show_run_info
		run_info.text = tr("SET_SPEEDRUN") % (tr("SET_VAL_ON") if Sfx.show_run_info else tr("SET_VAL_OFF"))
		Sfx.save_settings()
	)
	assign_section(run_info, "GAMEPLAY")
	box.add_child(run_info)
	var access_label := _settings_group_label(tr("SET_HEAD_VISION"))
	assign_section(access_label, "ACCESSIBILITY")
	box.add_child(access_label)
	m._color_assist_btn = Button.new()
	m._color_assist_btn.flat = true
	m._color_assist_btn.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	m._color_assist_btn.add_theme_font_size_override("font_size", 17)
	m._color_assist_btn.add_theme_color_override("font_color", Balance.COL_TEXT)
	m._color_assist_btn.add_theme_color_override("font_hover_color", Balance.COL_PLAYER)
	m._color_assist_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	m._color_assist_btn.pressed.connect(func() -> void:
		Sfx.set_color_assist(not Sfx.color_assist)
		_refresh_color_assist_label()
	)
	_refresh_color_assist_label()
	assign_section(m._color_assist_btn, "ACCESSIBILITY")
	box.add_child(m._color_assist_btn)
	var save_label := _settings_group_label("SAVE TRANSFER // PHONE ↔ PC")
	assign_section(save_label, "SAVE DATA")
	box.add_child(save_label)
	var transfer_title := Label.new()
	transfer_title.text = tr("SET_EXPORT_HEAD")
	transfer_title.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	transfer_title.add_theme_font_size_override("font_size", 14)
	transfer_title.add_theme_color_override("font_color", Balance.COL_MOTE)
	assign_section(transfer_title, "SAVE DATA")
	box.add_child(transfer_title)
	m._save_transfer_field = LineEdit.new()
	m._save_transfer_field.placeholder_text = tr("SET_IMPORT_PLACEHOLDER")
	m._save_transfer_field.custom_minimum_size = Vector2(0.0, 38.0)
	m._save_transfer_field.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	m._save_transfer_field.add_theme_font_size_override("font_size", 11)
	m._save_transfer_field.add_theme_color_override("font_color", Balance.COL_TEXT)
	assign_section(m._save_transfer_field, "SAVE DATA")
	box.add_child(m._save_transfer_field)
	var transfer_row := HBoxContainer.new()
	transfer_row.add_theme_constant_override("separation", 8)
	var export_btn := Button.new()
	export_btn.text = tr("SET_COPY_EXPORT")
	export_btn.flat = true
	export_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_btn.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	export_btn.add_theme_font_size_override("font_size", 13)
	export_btn.add_theme_color_override("font_color", Balance.COL_TEXT)
	export_btn.add_theme_color_override("font_hover_color", Balance.COL_PLAYER)
	export_btn.pressed.connect(m._export_save_to_clipboard)
	transfer_row.add_child(export_btn)
	var import_btn := Button.new()
	import_btn.text = tr("SET_IMPORT_PASTE")
	import_btn.flat = true
	import_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	import_btn.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	import_btn.add_theme_font_size_override("font_size", 13)
	import_btn.add_theme_color_override("font_color", Balance.COL_TEXT)
	import_btn.add_theme_color_override("font_hover_color", Balance.COL_PLAYER)
	import_btn.pressed.connect(m._import_save_from_clipboard)
	transfer_row.add_child(import_btn)
	assign_section(transfer_row, "SAVE DATA")
	box.add_child(transfer_row)
	m._save_transfer_status = Label.new()
	m._save_transfer_status.text = tr("SET_EXPORT_NOTE")
	m._save_transfer_status.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	m._save_transfer_status.add_theme_font_size_override("font_size", 10)
	m._save_transfer_status.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.5))
	m._save_transfer_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	assign_section(m._save_transfer_status, "SAVE DATA")
	box.add_child(m._save_transfer_status)
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
	var top := tr("SET_VAL_NONE")
	var tk := 0
	for k in kd:
		if int(kd[k]) > tk:
			tk = int(kd[k])
			top = str(k)
	stats.text = tr("SET_LIFETIME") % [runs, kills, chain, top]
	assign_section(stats, "SAVE DATA")
	box.add_child(stats)
	if m._desktop_keybinds_enabled():
		_build_keybind_settings(box)
	else:
		var controls_note := _settings_group_label(tr("SET_KEYBINDS_DESKTOP_ONLY"))
		assign_section(controls_note, "CONTROLS")
		box.add_child(controls_note)
	var reset := Button.new()
	reset.flat = true
	reset.text = tr("SET_RESET_SCORE")
	reset.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	reset.add_theme_font_size_override("font_size", 14)
	reset.add_theme_color_override("font_color", Color(Balance.COL_DANGER.r, Balance.COL_DANGER.g, Balance.COL_DANGER.b, 0.8))
	reset.alignment = HORIZONTAL_ALIGNMENT_LEFT
	reset.pressed.connect(func() -> void:
		if reset.text == tr("SET_RESET_SCORE"):
			reset.text = tr("SET_TAP_CONFIRM")
			return
		m._reset_scores()
		m._update_best()
		reset.text = tr("SET_CLEARED")
	)
	assign_section(reset, "SAVE DATA")
	box.add_child(reset)
	var footer_row := HBoxContainer.new()
	footer_row.position = footer.position
	footer_row.size = footer.size
	footer_row.add_theme_constant_override("separation", Design.SPACE_XL)
	var back_block := ScreenKit.action(tr("UI_BACK"), "[ESC]", "text", _close_settings)
	footer_row.add_child(back_block)
	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_row.add_child(footer_spacer)
	m._settings_panel.add_child(footer_row)
	m._settings_footer_row = footer_row
	m._settings_nav_buttons.clear()
	for index in SETTINGS_SECTIONS.size():
		var nav_button := Button.new()
		nav_button.text = section_label(str(SETTINGS_SECTIONS[index]))
		nav_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		nav_button.position = navigation.position + Vector2(10.0, 12.0 + float(index) * 48.0)
		nav_button.size = Vector2(navigation.size.x - 20.0, 38.0)
		nav_button.focus_mode = Control.FOCUS_ALL
		nav_button.add_theme_font_override("font", Design.grotesk(Design.WEIGHT_BOLD))
		nav_button.add_theme_font_size_override("font_size", Design.TEXT_SUBHEAD)
		nav_button.add_theme_color_override("font_color", Design.TEXT_SECONDARY)
		nav_button.add_theme_color_override("font_hover_color", Design.TEXT_PRIMARY)
		nav_button.add_theme_stylebox_override("normal", _nav_style(false, false))
		nav_button.add_theme_stylebox_override("hover", _nav_style(false, true))
		nav_button.add_theme_stylebox_override("pressed", _nav_style(true, false))
		m._settings_nav_buttons.append(nav_button)
		nav_button.pressed.connect(set_active_section.bind(str(SETTINGS_SECTIONS[index])))
		m._settings_panel.add_child(nav_button)
	var nav_hint := Label.new()
	nav_hint.text = tr("SET_FOOTER")
	nav_hint.position = navigation.position + Vector2(14.0, navigation.size.y - 28.0)
	nav_hint.size = Vector2(navigation.size.x - 28.0, 18.0)
	nav_hint.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	nav_hint.add_theme_font_size_override("font_size", 10)
	nav_hint.add_theme_color_override("font_color", Design.TEXT_FAINT)
	m._settings_nav_hint = nav_hint
	m._settings_panel.add_child(nav_hint)
	var chips_row := HBoxContainer.new()
	chips_row.name = "SettingsChips"
	chips_row.add_theme_constant_override("separation", 8)
	m._settings_chips_row = chips_row
	m._settings_panel.add_child(chips_row)
	for section in SETTINGS_SECTIONS:
		var chip := Button.new()
		chip.text = section_chip_label(str(section))
		chip.focus_mode = Control.FOCUS_ALL
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.size_flags_vertical = Control.SIZE_EXPAND_FILL
		chip.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
		chip.add_theme_font_size_override("font_size", 11)
		chip.add_theme_color_override("font_color", Design.TEXT_SECONDARY)
		chip.add_theme_color_override("font_hover_color", Design.TEXT_PRIMARY)
		chip.add_theme_stylebox_override("normal", _chip_style(false, false))
		chip.add_theme_stylebox_override("hover", _chip_style(false, true))
		chip.add_theme_stylebox_override("pressed", _chip_style(true, false))
		chip.pressed.connect(set_active_section.bind(str(section)))
		chips_row.add_child(chip)
		m._settings_chip_buttons.append(chip)
	# CanvasLayer acima do MenuShell (layer 5). Antes era filho direto do menu,
	# então o shell novo — que pinta fundo opaco — cobria o settings inteiro.
	var settings_layer := CanvasLayer.new()
	settings_layer.layer = 70
	settings_layer.add_child(m._settings_panel)
	m.add_child(settings_layer)
	_apply_section_visibility()
	_refresh_nav_selection()
	_layout_settings()
## Envolve um controle numa linha de largura limitada. O CheckButton do Godot
## ancora o indicador na BORDA DIREITA: numa coluna larga o botão ficava a mais
## de mil pixels do próprio rótulo.
func _bounded_row(control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	control.custom_minimum_size.x = Design.SLIDER_WIDTH
	control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(control)
	var tail := Control.new()
	tail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tail)
	return row


func _settings_group_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", Design.FONT_MONO)
	label.add_theme_font_size_override("font_size", Design.TEXT_CAPTION)
	label.add_theme_color_override("font_color", Design.TEXT_MUTED)
	label.custom_minimum_size = Vector2(0.0, 22.0)
	return label


func _style_toggle(toggle: CheckButton) -> void:
	toggle.add_theme_font_override("font", Design.FONT_MONO)
	toggle.add_theme_font_size_override("font_size", Design.TEXT_BODY)
	toggle.add_theme_color_override("font_color", Design.TEXT_PRIMARY)
	toggle.add_theme_color_override("font_hover_color", Design.TEXT_PRIMARY)
	for state in ["normal", "pressed"]:
		var empty := StyleBoxFlat.new()
		empty.bg_color = Color(0, 0, 0, 0)
		toggle.add_theme_stylebox_override(state, empty)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Design.alpha(Design.TEXT_PRIMARY, 0.05)
	toggle.add_theme_stylebox_override("hover", hover)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Design.FOCUS_RING_COLOR
	focus.set_border_width_all(int(Design.FOCUS_RING_WIDTH))
	toggle.add_theme_stylebox_override("focus", focus)
	toggle.focus_mode = Control.FOCUS_ALL

func _build_keybind_settings(parent: VBoxContainer) -> void:
	m._keybind_box = VBoxContainer.new()
	m._keybind_box.add_theme_constant_override("separation", 7)
	var title := Label.new()
	title.text = tr("SET_KEYBINDS")
	title.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Balance.COL_MOTE)
	m._keybind_box.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	m._settings_keybind_grid = grid
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 5)
	for action in Game.KEYBIND_DEFAULTS:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(220, 28)
		row.add_theme_constant_override("separation", 6)
		var label := Label.new()
		label.text = _keybind_action_label(action)
		label.custom_minimum_size = Vector2(92, 0)
		label.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.7))
		row.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(112, 28)
		button.flat = true
		button.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_color_override("font_color", Balance.COL_TEXT)
		button.add_theme_color_override("font_hover_color", Balance.COL_PLAYER)
		button.pressed.connect(_begin_keybind_capture.bind(action))
		m._keybind_buttons[action] = button
		row.add_child(button)
		grid.add_child(row)
	m._keybind_box.add_child(grid)
	m._keybind_status = Label.new()
	m._keybind_status.text = tr("SET_BIND_HINT")
	m._keybind_status.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	m._keybind_status.add_theme_font_size_override("font_size", 11)
	m._keybind_status.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.55))
	m._keybind_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m._keybind_box.add_child(m._keybind_status)
	var reset := Button.new()
	reset.text = tr("SET_BIND_RESET")
	reset.flat = true
	reset.alignment = HORIZONTAL_ALIGNMENT_LEFT
	reset.custom_minimum_size = Vector2(160.0, 28.0)
	reset.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	reset.add_theme_font_size_override("font_size", 12)
	reset.add_theme_color_override("font_color", Balance.COL_DANGER)
	reset.add_theme_color_override("font_hover_color", Balance.COL_PLAYER_HOT)
	reset.pressed.connect(func() -> void:
		Game.reset_keybinds()
		_refresh_keybind_buttons()
		m._capture_action = ""
		m._keybind_status.text = tr("SET_BIND_RESET_DONE")
	)
	m._keybind_box.add_child(reset)
	_refresh_keybind_buttons()
	parent.add_child(m._keybind_box)
	assign_section(m._keybind_box, "CONTROLS")

## O nome da AÇÃO é identificador do InputMap; o rótulo é o que o jogador lê.
## B12: modo de janela e vsync. O jogo não tinha opção de vídeo nenhuma.
##
## Os dois são botões de ciclo, o mesmo idioma dos outros ajustes desta tela —
## um clique avança, o rótulo mostra o estado atual. `Sfx` é quem aplica e
## persiste; aqui só se troca o índice.
func _build_video_section(box: Node) -> void:
	var head := _settings_group_label(tr("SET_HEAD_VIDEO"))
	assign_section(head, "VIDEO")
	box.add_child(head)

	var window_btn := _cycle_button(_window_label())
	window_btn.pressed.connect(func() -> void:
		Sfx.set_window_mode((Sfx.window_mode + 1) % Sfx.WINDOW_MODES.size())
		window_btn.text = _window_label()
	)
	assign_section(window_btn, "VIDEO")
	box.add_child(window_btn)

	var vsync_btn := _cycle_button(_vsync_label())
	vsync_btn.pressed.connect(func() -> void:
		Sfx.set_vsync_mode((Sfx.vsync_mode + 1) % Sfx.VSYNC_MODES.size())
		vsync_btn.text = _vsync_label()
	)
	assign_section(vsync_btn, "VIDEO")
	box.add_child(vsync_btn)

	var note := _settings_group_label(tr("SET_VIDEO_NOTE"))
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Design.TEXT_FAINT)
	assign_section(note, "VIDEO")
	box.add_child(note)


## Botão de ciclo no estilo desta tela. Extraído porque três ajustes já
## repetiam as mesmas oito linhas de tema.
func _cycle_button(label: String) -> Button:
	var button := Button.new()
	button.flat = true
	button.text = label
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Balance.COL_TEXT)
	button.add_theme_color_override("font_hover_color", Balance.COL_PLAYER)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return button


static func _window_label() -> String:
	var keys := ["SET_WINDOW_WINDOWED", "SET_WINDOW_FULLSCREEN", "SET_WINDOW_BORDERLESS"]
	var index: int = clampi(Sfx.window_mode, 0, keys.size() - 1)
	return TranslationServer.translate("SET_WINDOW_MODE") % TranslationServer.translate(keys[index])


static func _vsync_label() -> String:
	var keys := ["SET_VSYNC_OFF", "SET_VSYNC_ON", "SET_VSYNC_ADAPTIVE"]
	var index: int = clampi(Sfx.vsync_mode, 0, keys.size() - 1)
	return TranslationServer.translate("SET_VSYNC") % TranslationServer.translate(keys[index])


func _keybind_action_label(action: String) -> String:
	var key: String = {
		"move_up": "SET_BIND_UP",
		"move_down": "SET_BIND_DOWN",
		"move_left": "SET_BIND_LEFT",
		"move_right": "SET_BIND_RIGHT",
		"dash": "SET_BIND_DASH",
		"overclock": "SET_BIND_OVERCLOCK",
		"pause": "SET_BIND_PAUSE",
		"abandon": "SET_BIND_ABANDON",
		"mute": "SET_BIND_MUTE",
		"restart": "SET_BIND_RESTART",
		"confirm": "SET_BIND_CONFIRM",
	}.get(action, "")
	return tr(key) if key != "" else action.to_upper()

func _keybind_key_name(physical_key: int) -> String:
	var key_name := OS.get_keycode_string(physical_key)
	return key_name if not key_name.is_empty() else "KEY %d" % physical_key

func _refresh_keybind_buttons() -> void:
	for action in m._keybind_buttons:
		var button: Button = m._keybind_buttons[action]
		button.text = _keybind_key_name(Game.get_keybind(action))

func _begin_keybind_capture(action: String) -> void:
	if not m._desktop_keybinds_enabled() or not Game.KEYBIND_DEFAULTS.has(action):
		return
	m._capture_action = action
	m._keybind_status.text = tr("SET_BIND_CAPTURE") % _keybind_action_label(action)

func _handle_keybind_capture(event: InputEventKey) -> bool:
	if m._capture_action.is_empty():
		return false
	if not event.pressed or event.echo:
		return true
	var physical_key := int(event.physical_keycode)
	if physical_key <= 0:
		return true
	if physical_key == KEY_ESCAPE or int(event.keycode) == KEY_ESCAPE:
		m._capture_action = ""
		m._keybind_status.text = tr("SET_BIND_CANCELLED")
		return true
	var conflict := Game.keybind_conflict(physical_key, m._capture_action)
	if conflict != "":
		m._keybind_status.text = tr("SET_BIND_CONFLICT") % [_keybind_key_name(physical_key), _keybind_action_label(conflict)]
		return true
	var action: String = m._capture_action
	if not Game.set_keybind(action, physical_key):
		m._keybind_status.text = tr("SET_BIND_REJECTED")
		return true
	m._capture_action = ""
	_refresh_keybind_buttons()
	m._keybind_status.text = "%s BOUND TO %s" % [_keybind_action_label(action), _keybind_key_name(physical_key)]
	return true

func _make_slider_row(label_text: String, value: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Design.SPACE_LG)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(110, 0)
	l.add_theme_font_override("font", Design.FONT_MONO)
	l.add_theme_font_size_override("font_size", Design.TEXT_SUBHEAD)
	l.add_theme_color_override("font_color", Design.TEXT_PRIMARY)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	# Largura FIXA com espaçador depois, em vez de EXPAND_FILL. Tentar limitar
	# pela coluna não funciona: o ScrollContainer estica o filho até a própria
	# largura quando a rolagem horizontal está desabilitada, e `custom_minimum_size`
	# é mínimo, não máximo. Aqui o controle manda no próprio tamanho.
	s.custom_minimum_size = Vector2(Design.SLIDER_WIDTH, 36)
	s.focus_mode = Control.FOCUS_ALL
	s.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.modulate = Color(0.55, 0.9, 1.0)
	s.value_changed.connect(on_change)
	row.add_child(s)
	var v := Label.new()
	v.text = "%d%%" % int(value * 100.0)
	v.custom_minimum_size = Vector2(56, 0)
	v.add_theme_font_override("font", Design.FONT_MONO)
	v.add_theme_font_size_override("font_size", Design.TEXT_BODY)
	v.add_theme_color_override("font_color", Design.TEXT_SECONDARY)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s.value_changed.connect(func(val: float) -> void:
		v.text = "%d%%" % int(val * 100.0)
	)
	row.add_child(v)
	var tail := Control.new()
	tail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tail)
	return row

func _open_settings() -> void:
	_layout_settings()
	ScreenKit.open_focus(m._settings_panel)
	m._set_main_menu_controls_visible(false)
	m._settings_panel.visible = true
	Sfx.play("ui", 1.1, -6.0)

func _close_settings() -> void:
	m._capture_action = ""
	m._settings_panel.visible = false
	m._set_main_menu_controls_visible(true)
	ScreenKit.close_focus(m._settings_panel)
	Sfx.play("ui", 0.9, -6.0)

func _refresh_color_assist_label() -> void:
	if m._color_assist_btn != null:
		m._color_assist_btn.text = tr("SET_COLOR_ASSIST") % (tr("SET_VAL_ON") if Sfx.color_assist else tr("SET_VAL_OFF"))

func assign_section(control: Control, section: String) -> void:
	if control == null or not SETTINGS_SECTIONS.has(section):
		return
	if not _section_members.has(section):
		_section_members[section] = []
	_section_members[section].append(control)

func active_section() -> String:
	return _active_section

func section_names() -> Array:
	return SETTINGS_SECTIONS.duplicate()

func section_controls(section: String) -> Array:
	return _section_members.get(section, [])

func set_active_section(section: String) -> void:
	if not SETTINGS_SECTIONS.has(section):
		return
	_active_section = section
	_apply_section_visibility()
	_refresh_nav_selection()
	if m._settings_title != null and is_instance_valid(m._settings_title):
		m._settings_title.text = tr("SET_TITLE") % section_label(section)
	Sfx.play("ui", 1.0, -10.0)

func _touch_only_controls_ok() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.get_environment("KP_FORCE_TOUCH") != ""

func _apply_section_visibility() -> void:
	for section in _section_members:
		var active: bool = section == _active_section
		for control in _section_members[section]:
			if control == null or not is_instance_valid(control):
				continue
			control.visible = active
			if active and control.has_meta("touch_only") and not _touch_only_controls_ok():
				control.visible = false
	if m._keybind_box != null and is_instance_valid(m._keybind_box):
		m._keybind_box.visible = _active_section == "CONTROLS"

func _refresh_nav_selection() -> void:
	var index := SETTINGS_SECTIONS.find(_active_section)
	if not m._settings_nav_buttons.is_empty():
		for i in m._settings_nav_buttons.size():
			var nav_button: Button = m._settings_nav_buttons[i]
			if not is_instance_valid(nav_button):
				continue
			var selected: bool = i == index
			nav_button.text = section_label(str(SETTINGS_SECTIONS[i]))
			nav_button.add_theme_color_override("font_color", Design.TEXT_PRIMARY if selected else Design.TEXT_SECONDARY)
			nav_button.add_theme_stylebox_override("normal", _nav_style(selected, false))
	if not m._settings_chip_buttons.is_empty():
		for i in m._settings_chip_buttons.size():
			var chip: Button = m._settings_chip_buttons[i]
			if not is_instance_valid(chip):
				continue
			var chip_selected: bool = i == index
			chip.text = section_chip_label(str(SETTINGS_SECTIONS[i]))
			chip.add_theme_color_override("font_color", Design.TEXT_PRIMARY if chip_selected else Design.TEXT_SECONDARY)
			chip.add_theme_stylebox_override("normal", _chip_style(chip_selected, false))

func settings_section_snapshot() -> Dictionary:
	var visible_controls := 0
	for section in _section_members:
		for control in _section_members[section]:
			if control != null and is_instance_valid(control) and control.visible:
				visible_controls += 1
	return {"active": _active_section, "sections": section_names(), "visible_controls": visible_controls}


func apply_viewport(viewport: Vector2) -> void:
	_viewport_override = viewport
	_layout_settings()

func _current_viewport() -> Vector2:
	return _viewport_override if _viewport_override != Vector2.ZERO else m.size

func _physical_window_size() -> Vector2:
	var window_size := Vector2(DisplayServer.window_get_size())
	return window_size if window_size.x > 0.0 and window_size.y > 0.0 else Vector2.ZERO

## Layout for the live panel. Real windows render through canvas_items
## stretch, so the logical canvas never narrows below the 1280x720 base even
## in narrow windows — compact therefore has to come from the physical window,
## with its rects mapped back into canvas space (uniform stretch scale).
## The apply_viewport probe keeps full authority while an override is set.
func _live_settings_layout() -> Dictionary:
	var viewport := _current_viewport()
	if _viewport_override != Vector2.ZERO:
		return settings_layout_for_viewport(viewport)
	var window_size := _physical_window_size()
	if window_size == Vector2.ZERO or window_size.x >= COMPACT_BREAKPOINT or viewport.x < COMPACT_BREAKPOINT:
		return settings_layout_for_viewport(viewport)
	var design := settings_layout_for_viewport(window_size)
	# canvas_items stretch scales uniformly, so map with one factor even if the
	# canvas logical size has not caught up with the window yet.
	var factor := viewport.x / window_size.x
	for rect_key in ["workstation", "navigation", "content", "footer", "title", "chips"]:
		var rect: Rect2 = design[rect_key]
		design[rect_key] = Rect2(rect.position * factor, rect.size * factor)
	design["title_size"] = maxi(int(round(float(design["title_size"]) * factor)), 8)
	return design

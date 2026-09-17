extends RefCounted

## Menu settings kit: settings panel build/layout, keybind capture e controles.
## A lógica continua separada de `menu.gd`, mas a superfície visual segue agora
## a direção editorial do MenuShell: grotesca para hierarquia, mono para estado,
## seleção por rail/underline e sem TacticalChrome decorativo.

var m

const SETTINGS_SECTIONS := ["AUDIO", "VIDEO", "GAMEPLAY", "CONTROLS", "ACCESSIBILITY", "BOARD", "SAVE DATA"]
const SECTION_CHIP_KEYS := {
	"AUDIO": "SET_CHIP_AUDIO", "VIDEO": "SET_CHIP_VIDEO", "GAMEPLAY": "SET_CHIP_GAMEPLAY", "CONTROLS": "SET_CHIP_CONTROLS",
	"ACCESSIBILITY": "SET_CHIP_ACCESSIBILITY", "BOARD": "SET_CHIP_BOARD", "SAVE DATA": "SET_CHIP_SAVEDATA",
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
	"BOARD": "SET_NAV_BOARD",
	"SAVE DATA": "SET_NAV_SAVEDATA",
}


static func section_label(section: String) -> String:
	return TranslationServer.translate(str(SECTION_KEYS.get(section, section)))
const COMPACT_BREAKPOINT := 760.0
var _active_section := ""
var _section_members := {}
var _viewport_override := Vector2.ZERO


func _init(menu) -> void:
	m = menu
	var order: Array = SettingsManifest.sections_for(Platform.id())
	_active_section = str(order[0]) if not order.is_empty() else "AUDIO"

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
	var title := ScreenKit.grot(tr("SET_TITLE") % section_label(_active_section), Design.TEXT_TITLE,
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
	assign_section(sfx_row, "AUDIO", "sfx_vol")
	box.add_child(sfx_row)
	var music_row := _make_slider_row(tr("SET_MUSIC"), Sfx.music_vol, func(v: float) -> void:
		Sfx.set_music_vol(v)
	)
	assign_section(music_row, "AUDIO", "music_vol")
	box.add_child(music_row)
	var mute := CheckButton.new()
	mute.text = tr("SET_MUTE_ALL")
	_style_toggle(mute)
	mute.button_pressed = Sfx.muted
	mute.toggled.connect(func(on: bool) -> void:
		Sfx.set_muted(on)
	)
	assign_section(mute, "AUDIO", "mute")
	box.add_child(_bounded_row(mute))
	var mute_hint := _settings_group_label(tr("SET_MUTE_HINT"))
	mute_hint.add_theme_font_size_override("font_size", Design.TEXT_CAPTION)
	mute_hint.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.4))
	assign_section(mute_hint, "AUDIO")
	box.add_child(mute_hint)
	_build_video_section(box)
	# O cabeçalho segue a plataforma: "// TECLAS" não descreve nada num
	# celular, e "// TOQUE" não descreve nada num PC.
	var controls_label := _settings_group_label(
		tr("SET_HEAD_CONTROLS_TOUCH") if Platform.is_touch() else tr("SET_HEAD_CONTROLS"))
	assign_section(controls_label, "CONTROLS")
	box.add_child(controls_label)
	var haptics := CheckButton.new()
	haptics.text = tr("SET_HAPTICS")
	_style_toggle(haptics)
	haptics.button_pressed = Sfx.haptics_enabled
	haptics.toggled.connect(func(on: bool) -> void:
		Sfx.haptics_enabled = on
		Sfx.save_settings()
	)
	assign_section(haptics, "CONTROLS", "haptics")
	box.add_child(haptics)
	var aim_btn := _setting_button(tr("SET_AIM") % Sfx.aim_mode.to_upper())
	aim_btn.pressed.connect(func() -> void:
		var order := ["drag", "stick", "lockon"]
		Sfx.aim_mode = order[(order.find(Sfx.aim_mode) + 1) % order.size()]
		m._refresh_aim_label(aim_btn)
		Sfx.save_settings()
	)
	m._aim_btn_ref = aim_btn
	m._refresh_aim_label(aim_btn)
	assign_section(aim_btn, "CONTROLS", "aim_mode")
	box.add_child(aim_btn)
	var touch_sz := _setting_button(tr("SET_TOUCH_SIZE") % [tr("SET_VAL_SMALL"), tr("SET_VAL_NORMAL"), tr("SET_VAL_BIG")][m._touch_scale_idx(Sfx.touch_scale)])
	touch_sz.pressed.connect(func() -> void:
		var idx: int = m._next_touch_scale_idx(Sfx.touch_scale)
		Sfx.touch_scale = [0.85, 1.0, 1.2][idx]
		_set_row_text(touch_sz, tr("SET_TOUCH_SIZE") % [tr("SET_VAL_SMALL"), tr("SET_VAL_NORMAL"), tr("SET_VAL_BIG")][idx])
		Sfx.save_settings()
	)
	assign_section(touch_sz, "CONTROLS", "touch_scale")
	box.add_child(touch_sz)

	var handed := _setting_button(_touch_handed_label())
	handed.pressed.connect(func() -> void:
		var order: Array = Sfx.TOUCH_HANDED_MODES
		Sfx.touch_handed = str(order[(order.find(Sfx.touch_handed) + 1) % order.size()])
		_set_row_text(handed, _touch_handed_label())
		Sfx.save_settings()
	)
	assign_section(handed, "CONTROLS", "touch_handed")
	box.add_child(handed)

	var opacity := _setting_button(_touch_opacity_label())
	opacity.pressed.connect(func() -> void:
		var steps: Array = Sfx.TOUCH_OPACITY_STEPS
		Sfx.touch_opacity = float(steps[(_touch_opacity_idx() + 1) % steps.size()])
		_set_row_text(opacity, _touch_opacity_label())
		Sfx.save_settings()
	)
	assign_section(opacity, "CONTROLS", "touch_opacity")
	box.add_child(opacity)
	var motion_label := _settings_group_label(tr("SET_HEAD_MOTION"))
	assign_section(motion_label, "ACCESSIBILITY")
	box.add_child(motion_label)
	var shake_btn := _setting_button(tr("SET_SHAKE") % [tr("SET_VAL_OFF"), tr("SET_VAL_LOW"), tr("SET_VAL_FULL")][clampi(Sfx.shake_level, 0, 2)])
	shake_btn.pressed.connect(func() -> void:
		Sfx.shake_level = (Sfx.shake_level + 1) % 3
		_set_row_text(shake_btn, tr("SET_SHAKE") % [tr("SET_VAL_OFF"), tr("SET_VAL_LOW"), tr("SET_VAL_FULL")][Sfx.shake_level])
		Sfx.save_settings()
	)
	assign_section(shake_btn, "ACCESSIBILITY", "shake")
	box.add_child(shake_btn)

	var flash_btn := _setting_button(_flash_label())
	flash_btn.pressed.connect(func() -> void:
		Sfx.flash_level = (Sfx.flash_level + 1) % 3
		_set_row_text(flash_btn, _flash_label())
		Sfx.save_settings()
	)
	assign_section(flash_btn, "ACCESSIBILITY", "flash")
	box.add_child(flash_btn)
	var gameplay_label := _settings_group_label(tr("SET_HEAD_GAMEPLAY"))
	assign_section(gameplay_label, "GAMEPLAY")
	box.add_child(gameplay_label)
	var run_info := _setting_button(tr("SET_SPEEDRUN") % (tr("SET_VAL_ON") if Sfx.show_run_info else tr("SET_VAL_OFF")))
	run_info.pressed.connect(func() -> void:
		Sfx.show_run_info = not Sfx.show_run_info
		_set_row_text(run_info, tr("SET_SPEEDRUN") % (tr("SET_VAL_ON") if Sfx.show_run_info else tr("SET_VAL_OFF")))
		Sfx.save_settings()
	)
	assign_section(run_info, "GAMEPLAY", "run_info")
	box.add_child(run_info)
	var access_label := _settings_group_label(tr("SET_HEAD_VISION"))
	assign_section(access_label, "ACCESSIBILITY")
	box.add_child(access_label)
	m._color_assist_btn = _setting_button("")
	m._color_assist_btn.pressed.connect(func() -> void:
		Sfx.set_color_assist(not Sfx.color_assist)
		_refresh_color_assist_label()
	)
	_refresh_color_assist_label()
	assign_section(m._color_assist_btn, "ACCESSIBILITY", "color_assist")
	box.add_child(m._color_assist_btn)
	m._language_btn = _setting_button("")
	m._language_btn.pressed.connect(_cycle_language)
	_refresh_language_label()
	assign_section(m._language_btn, "ACCESSIBILITY", "language")
	box.add_child(m._language_btn)
	# ── placar semanal ────────────────────────────────────────────────
	#
	# Enviar uma pontuação manda a run inteira para um servidor. Isso sai da
	# máquina de quem joga, então a seção começa DESLIGADA e sem endereço, e o
	# aviso fica junto do interruptor em vez de escondido num README.
	var board_label := _settings_group_label(tr("SET_HEAD_BOARD"))
	assign_section(board_label, "BOARD")
	box.add_child(board_label)

	var board_note := _settings_group_label(tr("SET_BOARD_NOTE"))
	board_note.add_theme_font_size_override("font_size", Design.TEXT_CAPTION)
	board_note.add_theme_color_override("font_color", Design.TEXT_FAINT)
	assign_section(board_note, "BOARD")
	box.add_child(board_note)

	m._board_toggle_btn = _cycle_button(_board_enabled_label())
	m._board_toggle_btn.pressed.connect(func() -> void:
		Board.set_enabled(not Board.enabled)
		_set_row_text(m._board_toggle_btn, _board_enabled_label())
		_refresh_board_status()
	)
	assign_section(m._board_toggle_btn, "BOARD", "board_enabled")
	box.add_child(m._board_toggle_btn)

	var url_title := _settings_group_label(tr("SET_BOARD_URL"))
	url_title.add_theme_font_size_override("font_size", Design.TEXT_CAPTION)
	assign_section(url_title, "BOARD")
	box.add_child(url_title)
	m._board_url_field = LineEdit.new()
	m._board_url_field.text = Board.url
	m._board_url_field.placeholder_text = "https://"
	m._board_url_field.custom_minimum_size = Vector2(Design.SLIDER_WIDTH * 2.0, Design.target_min())
	m._board_url_field.add_theme_font_override("font", Design.FONT_MONO)
	m._board_url_field.add_theme_font_size_override("font_size", Design.TEXT_CAPTION)
	m._board_url_field.text_submitted.connect(func(value: String) -> void:
		Board.set_url(value)
		_refresh_board_status()
	)
	m._board_url_field.focus_exited.connect(func() -> void:
		Board.set_url(m._board_url_field.text)
		_refresh_board_status()
	)
	assign_section(m._board_url_field, "BOARD", "board_url")
	box.add_child(_bounded_row(m._board_url_field))

	var name_title := _settings_group_label(tr("SET_BOARD_NAME"))
	name_title.add_theme_font_size_override("font_size", Design.TEXT_CAPTION)
	assign_section(name_title, "BOARD")
	box.add_child(name_title)
	m._board_name_field = LineEdit.new()
	m._board_name_field.text = Board.player_name
	m._board_name_field.max_length = 24
	m._board_name_field.custom_minimum_size = Vector2(Design.SLIDER_WIDTH, Design.target_min())
	m._board_name_field.add_theme_font_override("font", Design.FONT_MONO)
	m._board_name_field.add_theme_font_size_override("font_size", Design.TEXT_CAPTION)
	m._board_name_field.text_submitted.connect(func(value: String) -> void:
		Board.set_player_name(value)
		_refresh_board_status()
	)
	m._board_name_field.focus_exited.connect(func() -> void:
		Board.set_player_name(m._board_name_field.text)
		_refresh_board_status()
	)
	assign_section(m._board_name_field, "BOARD", "board_name")
	box.add_child(_bounded_row(m._board_name_field))

	m._board_status = _settings_group_label("")
	m._board_status.add_theme_font_size_override("font_size", Design.TEXT_CAPTION)
	assign_section(m._board_status, "BOARD")
	box.add_child(m._board_status)
	_refresh_board_status()

	var save_label := _settings_group_label(tr("SET_TRANSFER_HEAD"))
	assign_section(save_label, "SAVE DATA")
	box.add_child(save_label)
	var transfer_title := Label.new()
	transfer_title.text = tr("SET_EXPORT_HEAD")
	transfer_title.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	transfer_title.add_theme_font_size_override("font_size", Design.TEXT_BODY)
	transfer_title.add_theme_color_override("font_color", Balance.COL_MOTE)
	assign_section(transfer_title, "SAVE DATA")
	box.add_child(transfer_title)
	m._save_transfer_field = LineEdit.new()
	m._save_transfer_field.placeholder_text = tr("SET_IMPORT_PLACEHOLDER")
	m._save_transfer_field.custom_minimum_size = Vector2(0.0, Design.target_min())
	m._save_transfer_field.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	m._save_transfer_field.add_theme_font_size_override("font_size", Design.TEXT_MICRO)
	m._save_transfer_field.add_theme_color_override("font_color", Balance.COL_TEXT)
	assign_section(m._save_transfer_field, "SAVE DATA", "save_transfer")
	box.add_child(m._save_transfer_field)
	var transfer_row := HBoxContainer.new()
	transfer_row.add_theme_constant_override("separation", 8)
	var export_btn := Button.new()
	export_btn.text = tr("SET_COPY_EXPORT")
	export_btn.flat = true
	export_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_btn.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	export_btn.add_theme_font_size_override("font_size", Design.TEXT_CAPTION)
	export_btn.add_theme_color_override("font_color", Balance.COL_TEXT)
	export_btn.add_theme_color_override("font_hover_color", Balance.COL_PLAYER)
	export_btn.pressed.connect(m._export_save_to_clipboard)
	transfer_row.add_child(export_btn)
	var import_btn := Button.new()
	import_btn.text = tr("SET_IMPORT_PASTE")
	import_btn.flat = true
	import_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	import_btn.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	import_btn.add_theme_font_size_override("font_size", Design.TEXT_CAPTION)
	import_btn.add_theme_color_override("font_color", Balance.COL_TEXT)
	import_btn.add_theme_color_override("font_hover_color", Balance.COL_PLAYER)
	import_btn.pressed.connect(m._import_save_from_clipboard)
	transfer_row.add_child(import_btn)
	assign_section(transfer_row, "SAVE DATA")
	box.add_child(transfer_row)
	m._save_transfer_status = Label.new()
	m._save_transfer_status.text = tr("SET_EXPORT_NOTE")
	m._save_transfer_status.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	m._save_transfer_status.add_theme_font_size_override("font_size", Design.TEXT_MICRO)
	m._save_transfer_status.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.5))
	m._save_transfer_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	assign_section(m._save_transfer_status, "SAVE DATA")
	box.add_child(m._save_transfer_status)
	var stats := Label.new()
	stats.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	stats.add_theme_font_size_override("font_size", Design.TEXT_CAPTION)
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
	assign_section(stats, "SAVE DATA", "lifetime_stats")
	box.add_child(stats)
	if m._desktop_keybinds_enabled():
		_build_keybind_settings(box)
	else:
		var controls_note := _settings_group_label(tr("SET_KEYBINDS_DESKTOP_ONLY"))
		assign_section(controls_note, "CONTROLS", "keybinds")
		box.add_child(controls_note)
	# Destrutivo: mantém a cor de perigo, mas herda alvo e tipografia da
	# fábrica em vez de montar a linha à mão outra vez.
	var reset := _setting_button(tr("SET_RESET_SCORE"))
	reset.add_theme_color_override("font_color", Design.alpha(Design.DANGER, 0.8))
	reset.add_theme_color_override("font_focus_color", Design.DANGER)
	reset.add_theme_color_override("font_pressed_color", Design.DANGER)
	if not Platform.is_touch():
		reset.add_theme_color_override("font_hover_color", Design.DANGER)
	reset.pressed.connect(func() -> void:
		if split_row_text(tr("SET_RESET_SCORE"))[0] == str((reset.get_meta(ROW_NAME_META) as Label).text):
			_set_row_text(reset, tr("SET_TAP_CONFIRM"))
			return
		m._reset_scores()
		m._update_best()
		_set_row_text(reset, tr("SET_CLEARED"))
	)
	assign_section(reset, "SAVE DATA", "reset_score")
	box.add_child(reset)
	var footer_row := HBoxContainer.new()
	footer_row.position = footer.position
	footer_row.size = footer.size
	footer_row.add_theme_constant_override("separation", Design.SPACE_XL)
	var back_block := ScreenKit.action(tr("UI_BACK"), "" if Design.touch_input() else "[ESC]", "text", _close_settings)
	footer_row.add_child(back_block)
	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_row.add_child(footer_spacer)
	m._settings_panel.add_child(footer_row)
	m._settings_footer_row = footer_row
	m._settings_nav_buttons.clear()
	for index in _visible_sections().size():
		var section_id := str(_visible_sections()[index])
		var nav_button := Button.new()
		nav_button.text = section_label(section_id)
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
		nav_button.pressed.connect(set_active_section.bind(section_id))
		m._settings_panel.add_child(nav_button)
	var nav_hint := Label.new()
	nav_hint.text = tr("SET_FOOTER")
	nav_hint.position = navigation.position + Vector2(14.0, navigation.size.y - 28.0)
	nav_hint.size = Vector2(navigation.size.x - 28.0, 18.0)
	nav_hint.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	nav_hint.add_theme_font_size_override("font_size", Design.TEXT_MICRO)
	nav_hint.add_theme_color_override("font_color", Design.TEXT_FAINT)
	m._settings_nav_hint = nav_hint
	m._settings_panel.add_child(nav_hint)
	var chips_row := HBoxContainer.new()
	chips_row.name = "SettingsChips"
	chips_row.add_theme_constant_override("separation", 8)
	m._settings_chips_row = chips_row
	m._settings_panel.add_child(chips_row)
	for section in _visible_sections():
		var chip := Button.new()
		chip.text = section_chip_label(str(section))
		chip.focus_mode = Control.FOCUS_ALL
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.size_flags_vertical = Control.SIZE_EXPAND_FILL
		chip.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
		chip.add_theme_font_size_override("font_size", Design.TEXT_MICRO)
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
	toggle.custom_minimum_size = Vector2(0.0, Design.target_min())
	toggle.set_meta(ROW_RULED_META, true)
	toggle.add_theme_font_override("font", Design.FONT_MONO)
	toggle.add_theme_font_size_override("font_size", Design.TEXT_BODY)
	toggle.add_theme_color_override("font_color", Design.TEXT_PRIMARY)
	toggle.add_theme_color_override("font_hover_color", Design.TEXT_PRIMARY)
	for state in ["normal", "pressed"]:
		var empty := StyleBoxFlat.new()
		empty.bg_color = Color(0, 0, 0, 0)
		empty.border_color = Design.alpha(Design.TEXT_PRIMARY, 0.14)
		empty.border_width_bottom = 1
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
	title.add_theme_font_size_override("font_size", Design.TEXT_BODY)
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
		label.add_theme_font_size_override("font_size", Design.TEXT_CAPTION)
		label.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.7))
		row.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(112, 28)
		button.flat = true
		button.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
		button.add_theme_font_size_override("font_size", Design.TEXT_CAPTION)
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
	m._keybind_status.add_theme_font_size_override("font_size", Design.TEXT_MICRO)
	m._keybind_status.add_theme_color_override("font_color", Color(Balance.COL_TEXT.r, Balance.COL_TEXT.g, Balance.COL_TEXT.b, 0.55))
	m._keybind_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m._keybind_box.add_child(m._keybind_status)
	var reset := Button.new()
	reset.text = tr("SET_BIND_RESET")
	reset.flat = true
	reset.alignment = HORIZONTAL_ALIGNMENT_LEFT
	reset.custom_minimum_size = Vector2(160.0, 28.0)
	reset.add_theme_font_override("font", load("res://assets/fonts/ShareTechMono.ttf"))
	reset.add_theme_font_size_override("font_size", Design.TEXT_CAPTION)
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
	assign_section(m._keybind_box, "CONTROLS", "keybinds")

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
		_set_row_text(window_btn, _window_label())
	)
	assign_section(window_btn, "VIDEO", "window_mode")
	box.add_child(window_btn)

	var vsync_btn := _cycle_button(_vsync_label())
	vsync_btn.pressed.connect(func() -> void:
		Sfx.set_vsync_mode((Sfx.vsync_mode + 1) % Sfx.VSYNC_MODES.size())
		_set_row_text(vsync_btn, _vsync_label())
	)
	assign_section(vsync_btn, "VIDEO", "vsync")
	box.add_child(vsync_btn)

	# Tinta de campo: a recompensa dos atos do Story. Só aparece com opções, e
	# só tem opções depois de limpar um ato — antes disso a linha explica como
	# se destrava, em vez de mostrar um botão que não faz nada.
	var tints: Array = Game.unlocked_field_tints()
	if tints.size() > 1:
		var tint_btn := _cycle_button(_field_tint_label())
		tint_btn.pressed.connect(func() -> void:
			var options: Array = Game.unlocked_field_tints()
			var current := options.find(Game.field_tint)
			Game.set_field_tint(str(options[(maxi(current, 0) + 1) % options.size()]))
			_set_row_text(tint_btn, _field_tint_label())
		)
		assign_section(tint_btn, "VIDEO", "field_tint")
		box.add_child(tint_btn)
		m._field_tint_btn = tint_btn
	else:
		var tint_hint := _settings_group_label(tr("SET_FIELD_TINT_LOCKED"))
		tint_hint.add_theme_font_size_override("font_size", Design.TEXT_CAPTION)
		tint_hint.add_theme_color_override("font_color", Design.TEXT_FAINT)
		assign_section(tint_hint, "VIDEO")
		box.add_child(tint_hint)

	var note := _settings_group_label(tr("SET_VIDEO_NOTE"))
	note.add_theme_font_size_override("font_size", Design.TEXT_CAPTION)
	note.add_theme_color_override("font_color", Design.TEXT_FAINT)
	assign_section(note, "VIDEO")
	box.add_child(note)


## Botão de ciclo no estilo desta tela. Extraído porque três ajustes já
## repetiam as mesmas oito linhas de tema.
## Fábrica ÚNICA das linhas de settings.
##
## Antes cada linha era montada à mão: 17px cravado, `font_hover_color` e
## nenhuma altura mínima. No celular isso dava linha abaixo do alvo de 56px e
## um estado de hover que não existe — dedo não passa por cima, ele pressiona.
##
## Agora tamanho e cor saem do `Design`, a altura vem de `Design.target_min()`
## (44 no clique, 56 no toque) e o realce segue a plataforma: hover só onde há
## ponteiro, pressão e foco nas duas.
## Linha de settings em DUAS colunas: rótulo à esquerda, valor à direita.
##
## Antes era uma frase só ("MODO DE MIRA: DRAG") alinhada à esquerda. Numa
## tela de celular isso vira uma pilha de frases soltas: não há coluna de
## valor para percorrer com o olho, e justamente o que muda ao tocar fica
## enterrado no meio da frase.
##
## A linha continua sendo um `Button` — os tipos declarados em `menu.gd` e o
## que o harness afirma seguem valendo. O texto é distribuído por
## `_set_row_text()`, que parte no separador do próprio gabarito traduzido.
func _setting_button(label: String) -> Button:
	var button := Button.new()
	# `flat` faz o Godot pular o stylebox inteiro — inclusive o fio de baixo.
	# O fundo já é transparente nos cinco estados, então não há o que esconder.
	button.flat = false
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.clip_contents = true
	button.add_theme_font_override("font", Design.FONT_MONO)
	button.add_theme_font_size_override("font_size", Design.TEXT_SUBHEAD)
	button.add_theme_color_override("font_color", Design.TEXT_PRIMARY)
	button.add_theme_color_override("font_focus_color", Design.ACCENT)
	button.add_theme_color_override("font_pressed_color", Design.ACCENT)
	if not Platform.is_touch():
		button.add_theme_color_override("font_hover_color", Design.ACCENT)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0.0, Design.target_min())
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Design.alpha(Design.TEXT_PRIMARY, 0.05) if state == "hover" else Color(0, 0, 0, 0)
		if state == "focus":
			for side in ["border_width_left", "border_width_right", "border_width_top", "border_width_bottom"]:
				box.set(side, int(Design.FOCUS_RING_WIDTH))
			box.border_color = Design.FOCUS_RING_COLOR
		box.content_margin_left = 0
		box.content_margin_right = Design.SPACE_MD
		box.content_margin_top = Design.SPACE_SM
		box.content_margin_bottom = Design.SPACE_SM
		# Fio embaixo de cada linha: sem ele a lista lê como frases soltas no
		# vazio, que é o que a tela de celular parecia.
		box.border_color = Design.alpha(Design.TEXT_PRIMARY, 0.14)
		box.border_width_bottom = 1
		button.add_theme_stylebox_override(state, box)

	# Os dois ocupam a linha inteira e se separam pelo ALINHAMENTO. Ancorar o
	# valor com `PRESET_RIGHT_WIDE` dava uma faixa de largura zero colada na
	# borda, e a coluna de valor simplesmente não aparecia.
	var name_label := ScreenKit.mono("", Design.TEXT_SUBHEAD, Design.TEXT_PRIMARY)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(name_label)
	var value_label := ScreenKit.mono("", Design.TEXT_SUBHEAD, Design.ACCENT)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	value_label.offset_right = -float(Design.SPACE_MD)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(value_label)
	button.set_meta(ROW_NAME_META, name_label)
	button.set_meta(ROW_VALUE_META, value_label)
	_set_row_text(button, label)
	return button


const ROW_RULED_META := "kp_row_ruled"
const ROW_NAME_META := "kp_row_name"
const ROW_VALUE_META := "kp_row_value"


## Distribui "RÓTULO: VALOR" nas duas colunas da linha.
##
## O corte é no ÚLTIMO separador da frase traduzida, não numa posição fixa:
## os gabaritos do CSV usam ":" e "//", e as duas línguas põem o valor no fim.
## Sem separador, a frase inteira é rótulo — é o caso dos textos de ação.
static func split_row_text(text: String) -> Array:
	var cut := -1
	for sep in [": ", " // "]:
		cut = maxi(cut, text.rfind(sep))
	if cut < 0:
		return [text, ""]
	var sep_len := 2 if text.substr(cut, 2) == ": " else 4
	return [text.substr(0, cut).strip_edges(), text.substr(cut + sep_len).strip_edges()]


func _set_row_text(button: Button, text: String) -> void:
	if button == null or not button.has_meta(ROW_NAME_META):
		button.text = text
		return
	var parts := split_row_text(text)
	var name_label: Label = button.get_meta(ROW_NAME_META)
	var value_label: Label = button.get_meta(ROW_VALUE_META)
	if is_instance_valid(name_label):
		name_label.text = str(parts[0])
	if is_instance_valid(value_label):
		value_label.text = str(parts[1])


## Rótulo da intensidade de luz, na mesma escala do shake.
func _flash_label() -> String:
	var names := [tr("SET_VAL_OFF"), tr("SET_VAL_LOW"), tr("SET_VAL_FULL")]
	return tr("SET_FLASH") % names[clampi(Sfx.flash_level, 0, 2)]


## Rótulo do lado que comanda. "DIREITA" é o histórico: ações à direita,
## movimento à esquerda.
func _touch_handed_label() -> String:
	var value := tr("SET_VAL_LEFT") if Sfx.touch_handed == "left" else tr("SET_VAL_RIGHT")
	return tr("SET_TOUCH_HANDED") % value


## Degrau de opacidade mais próximo do valor salvo — o valor em disco é
## contínuo e pode vir de uma versão futura com outra escala.
func _touch_opacity_idx() -> int:
	var steps: Array = Sfx.TOUCH_OPACITY_STEPS
	var best := 0
	for i in steps.size():
		if absf(float(steps[i]) - Sfx.touch_opacity) < absf(float(steps[best]) - Sfx.touch_opacity):
			best = i
	return best


func _touch_opacity_label() -> String:
	var names := [tr("SET_VAL_FAINT"), tr("SET_VAL_LOW"), tr("SET_VAL_FULL")]
	return tr("SET_TOUCH_OPACITY") % names[_touch_opacity_idx()]


func _cycle_button(label: String) -> Button:
	return _setting_button(label)


## Rótulo da tinta ativa. `""` é o estado normal e tem nome próprio na lista.
func _field_tint_label() -> String:
	var tint := Game.field_tint
	var name := tr("TINT_NONE") if tint == "" else tr("TINT_%s" % tint.to_upper())
	return tr("SET_FIELD_TINT") % name

func field_tint_button() -> Button:
	return m._field_tint_btn

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
	m._keybind_status.text = tr("SET_BOUND_TO") % [_keybind_action_label(action), _keybind_key_name(physical_key)]
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

func _board_enabled_label() -> String:
	return tr("SET_BOARD_ENABLED") % (tr("SET_VAL_ON") if Board.enabled else tr("SET_VAL_OFF"))

## Diz em uma linha o que falta para o envio funcionar, em vez de deixar a
## jogadora descobrir no fim de uma run que o endereço estava errado.
func _refresh_board_status() -> void:
	if m._board_status == null or not is_instance_valid(m._board_status):
		return
	if not Board.enabled:
		m._board_status.text = tr("SET_BOARD_STATE_OFF")
	elif not Board.is_valid_url(Board.url):
		m._board_status.text = tr("SET_BOARD_STATE_URL")
	elif not Board.is_valid_name(Board.player_name):
		m._board_status.text = tr("SET_BOARD_STATE_NAME")
	else:
		m._board_status.text = tr("SET_BOARD_STATE_READY")

func _refresh_color_assist_label() -> void:
	if m._color_assist_btn != null:
		_set_row_text(m._color_assist_btn, tr("SET_COLOR_ASSIST") % (tr("SET_VAL_ON") if Sfx.color_assist else tr("SET_VAL_OFF")))

func _cycle_language() -> void:
	var next := "pt_BR" if Game.language() == "en" else "en"
	if m != null and m.has_method("_apply_language"):
		m.call("_apply_language", next)

func _refresh_language_label() -> void:
	if m._language_btn != null and is_instance_valid(m._language_btn):
		var name := tr("SET_LANG_ENGLISH") if Game.language() == "en" else tr("SET_LANG_PORTUGUESE")
		_set_row_text(m._language_btn, tr("SET_LANGUAGE") % name)

func language_button() -> Button:
	return m._language_btn

func focus_language_control() -> void:
	if m._language_btn != null and is_instance_valid(m._language_btn):
		m._language_btn.grab_focus()

## Reconstrói o painel no idioma novo sem reiniciar o processo. O painel
## antigo esconde na hora e libera no fim do frame (seguro dentro do próprio
## `pressed`); o novo já nasce com `tr()` no idioma atual.
func rebuild_settings() -> void:
	_section_members.clear()
	if m._settings_chip_buttons != null:
		m._settings_chip_buttons.clear()
	m._capture_action = ""
	var was_open: bool = m._settings_panel != null and is_instance_valid(m._settings_panel) and m._settings_panel.visible
	if m._settings_panel != null and is_instance_valid(m._settings_panel):
		m._settings_panel.visible = false
		m._settings_panel.queue_free()
	_build_settings()
	_apply_section_visibility()
	_refresh_nav_selection()
	if was_open:
		_open_settings()

const SETTING_ID_META := "kp_setting_id"

## `id` é o identificador da opção no `SettingsManifest`. Quem passa id é um
## controle de verdade; rótulo, nota e dica são decoração e ficam sem id.
func assign_section(control: Control, section: String, id: String = "") -> void:
	if control == null or not SETTINGS_SECTIONS.has(section):
		return
	if id != "":
		control.set_meta(SETTING_ID_META, id)
	if not _section_members.has(section):
		_section_members[section] = []
	_section_members[section].append(control)

func active_section() -> String:
	return _active_section

func section_names() -> Array:
	return SETTINGS_SECTIONS.duplicate()

func section_controls(section: String) -> Array:
	return _section_members.get(section, [])

## Seções visíveis na navegação. Touch esconde CONTROLS (keybinds não
## existem no telefone); o idioma continua em ACCESSIBILITY.
## Quem decide é o manifesto: uma seção aparece quando tem ao menos uma opção
## servida nesta plataforma. Antes isto era um caso especial escrito à mão
## ("no toque, esconda CONTROLS"), que só valia para essa seção e não
## acompanhava opção nova nenhuma.
func _visible_sections() -> Array:
	return SettingsManifest.sections_for(Platform.id())

func set_active_section(section: String) -> void:
	if not SETTINGS_SECTIONS.has(section):
		return
	_active_section = section
	_apply_section_visibility()
	_refresh_nav_selection()
	if m._settings_title != null and is_instance_valid(m._settings_title):
		m._settings_title.text = tr("SET_TITLE") % section_label(section)
	Sfx.play("ui", 1.0, -10.0)

func _apply_section_visibility() -> void:
	var profile := Platform.id()
	for section in _section_members:
		var active: bool = section == _active_section
		for control in _section_members[section]:
			if control == null or not is_instance_valid(control):
				continue
			control.visible = active
			if active and control.has_meta(SETTING_ID_META) \
					and not SettingsManifest.shows(str(control.get_meta(SETTING_ID_META)), profile):
				control.visible = false
	if m._keybind_box != null and is_instance_valid(m._keybind_box):
		m._keybind_box.visible = _active_section == "CONTROLS"

func _refresh_nav_selection() -> void:
	var sections := _visible_sections()
	var index := sections.find(_active_section)
	if not m._settings_nav_buttons.is_empty():
		for i in m._settings_nav_buttons.size():
			var nav_button: Button = m._settings_nav_buttons[i]
			if not is_instance_valid(nav_button):
				continue
			var selected: bool = i == index
			nav_button.text = section_label(str(sections[i]))
			nav_button.add_theme_color_override("font_color", Design.TEXT_PRIMARY if selected else Design.TEXT_SECONDARY)
			nav_button.add_theme_stylebox_override("normal", _nav_style(selected, false))
	if not m._settings_chip_buttons.is_empty():
		for i in m._settings_chip_buttons.size():
			var chip: Button = m._settings_chip_buttons[i]
			if not is_instance_valid(chip):
				continue
			var chip_selected: bool = i == index
			chip.text = section_chip_label(str(sections[i]))
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

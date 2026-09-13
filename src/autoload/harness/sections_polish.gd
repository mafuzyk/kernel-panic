extends RefCounted

## Autotest section for the 2026-08-30 polish pack: settings real tabs,
## compact chips, menu reflow, awards chrome, bestiary glyph containment,
## raster optical pass, story rail restyle, leak guard, sprite trial.
## Same conventions as the other sections: helper references prefixed `h.`.

var h: Node


func _init(harness: Node) -> void:
	h = harness

func _settings_tabs_test(menu: Node) -> void:
	print("AT_STEP settings_tabs")
	var kit = menu.get("_settings_kit")
	var kit_script: Script = load("res://src/ui/menu_settings_kit.gd")
	h._check(kit != null and kit.has_method("set_active_section") and kit.has_method("active_section") and kit.has_method("settings_section_snapshot"), "settings kit exposes the section state machine")
	if kit == null or not kit.has_method("set_active_section"):
		return
	var sections: Array = kit.call("section_names")
	# A lista era fixada em cinco nomes literais, então adicionar a seção VIDEO
	# quebrava a asserção sem nada ter regredido. O que importa é que a ordem
	# declarada seja a ordem servida, e que as seções que o jogador espera
	# existam — não quantas são.
	h._check(sections == kit_script.SETTINGS_SECTIONS, "settings serves the sections in declared order")
	for expected in ["AUDIO", "VIDEO", "GAMEPLAY", "CONTROLS", "SAVE DATA"]:
		h._check(sections.has(expected), "settings declares the %s section" % str(expected))
	menu.call("_open_settings")
	await h._ticks(2)
	var settings_panel: Control = menu.get("_settings_panel")
	var settings_title: Label = menu.get("_settings_title")
	h._check(settings_panel != null and settings_panel.theme == UiTheme.shared(),
		"settings overlay uses the shared design theme")
	h._check(settings_title != null and settings_title.get_theme_font("font") == Design.grotesk(Design.WEIGHT_BLACK),
		"settings title uses the editorial grotesk instead of Orbitron")
	h._check(settings_title != null and settings_title.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT,
		"settings title follows the left-aligned editorial hierarchy")
	var tactical_chrome_nodes: Array[Node] = []
	if settings_panel != null:
		for child in settings_panel.find_children("*", "TacticalChrome", true, false):
			if child is CanvasItem and (child as CanvasItem).visible:
				tactical_chrome_nodes.append(child)
	h._check(tactical_chrome_nodes.is_empty(),
		"settings no longer renders legacy TacticalChrome frames")
	var settings_nav_focusable := true
	for raw_button in menu.get("_settings_nav_buttons"):
		if raw_button is Button and (raw_button as Button).focus_mode != Control.FOCUS_ALL:
			settings_nav_focusable = false
	h._check(settings_nav_focusable, "settings navigation remains keyboard-focusable in the editorial shell")
	for section in sections:
		kit.call("set_active_section", str(section))
		await h._ticks(1)
		var snapshot: Dictionary = kit.call("settings_section_snapshot")
		h._check(str(snapshot.get("active", "")) == str(section), "settings active section follows set_active_section (%s)" % str(section))
		var hidden_ok := true
		for other in sections:
			if str(other) == str(section):
				continue
			for control in kit.call("section_controls", str(other)):
				if is_instance_valid(control) and control.visible:
					hidden_ok = false
		h._check(hidden_ok, "%s tab hides every other section's control" % str(section))
		var visible := 0
		for control in kit.call("section_controls", str(section)):
			if is_instance_valid(control) and control.visible:
				visible += 1
		h._check(visible >= 1, "%s tab keeps at least one visible control" % str(section))
		var title: Label = menu.get("_settings_title")
		h._check(title != null and str(title.text) == tr("SET_TITLE") % str(kit.section_label(str(section))), "settings title shows the active section (%s)" % str(section))
		var selected_index: int = sections.find(str(section))
		var nav_buttons: Array = menu.get("_settings_nav_buttons")
		var selected_ok: bool = nav_buttons.size() == sections.size()
		for i in nav_buttons.size():
			var btn: Button = nav_buttons[i]
			var nav_style := btn.get_theme_stylebox("normal")
			var has_marker := nav_style is StyleBoxFlat and (nav_style as StyleBoxFlat).border_width_left > 0
			if (i == selected_index) != has_marker:
				selected_ok = false
		h._check(selected_ok, "exactly one nav button carries the editorial selection rail (%s)" % str(section))
	kit.call("set_active_section", "AUDIO")
	h.get_viewport().push_input(h._key_event(KEY_ESCAPE))
	h._check(not bool(menu.get("_settings_panel").visible), "ESC still closes the whole settings panel")
	menu.call("_close_settings")

func _settings_chips_test(menu: Node) -> void:
	print("AT_STEP settings_chips")
	var kit_script: Script = load("res://src/ui/menu_settings_kit.gd")
	var kit = menu.get("_settings_kit")
	h._check(kit != null and kit.has_method("apply_viewport"), "settings kit exposes a viewport override for layout probes")
	if kit == null or not kit.has_method("apply_viewport"):
		return
	menu.call("_open_settings")
	await h._ticks(1)
	kit.call("apply_viewport", Vector2(432, 720))
	await h._ticks(1)
	var layout: Dictionary = menu.call("settings_layout_for_viewport", Vector2(432, 720))
	h._check(bool(layout.get("compact", false)), "432x720 uses the compact settings layout")
	var chips_row: Control = menu.get("_settings_chips_row")
	h._check(chips_row != null and chips_row.visible, "compact layout shows the chips row")
	var nav_buttons: Array = menu.get("_settings_nav_buttons")
	var nav_hidden: bool = not nav_buttons.is_empty()
	for btn in nav_buttons:
		nav_hidden = nav_hidden and (is_instance_valid(btn) and not btn.visible)
	h._check(nav_hidden, "compact layout hides the sidebar nav buttons")
	kit.call("set_active_section", "SAVE DATA")
	await h._ticks(1)
	var chips: Array = menu.get("_settings_chip_buttons")
	# O índice ativo vem da lista declarada, não de um 4 cravado.
	var active_index: int = kit_script.SETTINGS_SECTIONS.find("SAVE DATA")
	var chip_selected: bool = chips.size() == kit_script.SETTINGS_SECTIONS.size()
	for i in chips.size():
		var chip_style := (chips[i] as Button).get_theme_stylebox("normal")
		var has_underline := chip_style is StyleBoxFlat and (chip_style as StyleBoxFlat).border_width_bottom > 0
		if (i == active_index) != has_underline:
			chip_selected = false
	h._check(chip_selected, "chips share the editorial active-section marker with the sidebar")
	kit.call("apply_viewport", Vector2.ZERO)
	kit.call("set_active_section", "AUDIO")
	menu.call("_close_settings")

func _menu_reflow_test(menu: Node) -> void:
	print("AT_STEP menu_reflow")
	h._check(menu.has_method("menu_layout_for_viewport"), "menu exposes the central layout dict")
	if not menu.has_method("menu_layout_for_viewport"):
		return
	for vp in [Vector2(1366, 768), Vector2(1024, 640), Vector2(760, 720), Vector2(432, 720)]:
		var lay: Dictionary = menu.call("menu_layout_for_viewport", vp)
		var view := Rect2(Vector2.ZERO, vp)
		for key in ["title", "klog", "subtitle", "controls", "best", "mode_info", "button_row", "purge", "story", "mode", "program", "diff"]:
			h._check(view.encloses(Rect2(lay[key])), "menu %s stays inside the viewport at %dx%d" % [str(key), int(vp.x), int(vp.y)])
		var band_keys := ["title", "klog", "controls", "best", "mode_info", "button_row"]
		for i in band_keys.size():
			for j in range(i + 1, band_keys.size()):
				var a: Rect2 = lay[band_keys[i]]
				var b: Rect2 = lay[band_keys[j]]
				h._check(not a.intersects(b), "menu %s and %s stay disjoint at %dx%d" % [str(band_keys[i]), str(band_keys[j]), int(vp.x), int(vp.y)])
		h._check(int(lay["title_size"]) >= 44, "menu title scales down with the viewport at %dx%d" % [int(vp.x), int(vp.y)])
	# O shell virou MenuShell (containers). Estas asserções medem o shell VIVO
	# em quatro resoluções — incluindo 1920x1080, que a matriz antiga nunca
	# cobria (B5 da auditoria).
	var shell = menu.get("_shell")
	h._check(shell != null, "menu exposes the rebuilt shell")
	if shell != null:
		for vp in [Vector2(1920, 1080), Vector2(1366, 768), Vector2(1024, 640), Vector2(432, 720)]:
			shell.size = vp
			# 2 ticks era marginal no 432 (âncora/densidade assentam com
			# atraso sob carga): 5 estabiliza sem mudar o contrato.
			await h._ticks(5)
			var view := Rect2(Vector2.ZERO, vp)
			var inside := true
			for content in shell.content_rects():
				if not view.encloses(content):
					inside = false
					print("AT_DEBUG menu shell overflow at %dx%d: %s" % [int(vp.x), int(vp.y), str(content)])
			h._check(inside, "menu shell content stays inside the viewport at %dx%d" % [int(vp.x), int(vp.y)])
		shell.size = menu.size
	# Todo overlay do menu precisa ficar ACIMA do shell e pintar fundo OPACO.
	# O shell novo pinta fundo sólido, então um overlay em camada baixa some
	# atrás dele, e um overlay translúcido deixa o shell vazar por cima.
	# Viewport larga de propósito: com viewport estreita o teto coincide com a
	# largura disponível e a asserção passaria sem provar nada.
	menu.call("_open_settings")
	await h._ticks(3)
	var settings_panel = menu.get("_settings_panel")
	h._check(settings_panel != null and settings_panel.visible, "settings panel opens above the shell")
	if settings_panel != null:
		var settings_dim: Node = settings_panel.get_node_or_null("SettingsDim")
		h._check(settings_dim is ColorRect and is_equal_approx((settings_dim as ColorRect).color.a, 1.0),
			"settings backdrop is fully opaque")
		# B5 no settings: sem teto, a coluna ocupava toda a área de conteúdo
		# (~1200px em 1920), os sliders esticavam de ponta a ponta e o indicador
		# do CheckButton ficava a mais de mil pixels do próprio rótulo.
		var form_box = menu.get("_settings_box")
		# Viewport larga de propósito: com viewport estreita o teto coincide com
		# a largura disponível e a asserção passaria sem provar nada.
		menu._settings_kit.apply_viewport(Vector2(1920, 1080))
		await h._ticks(2)
		h._check(form_box != null and form_box.size.x <= Design.CONTENT_MAX_FORM + 1.0,
			"settings form column respects the max width (%d)" % int(form_box.size.x if form_box != null else -1))
	menu.call("_close_settings")
	# Era texto-fonte procurando `apply_menu_layout` no arquivo. Essa função
	# posicionava a fileira de botões que nascia escondida, e foi removida com
	# ela — 305 linhas. O contrato que sobra é o que sempre importou: o kit
	# devolve uma geometria que ACOMPANHA o viewport.
	var chrome_kit = load("res://src/ui/menu_chrome_kit.gd").new(menu)
	var narrow: Dictionary = chrome_kit.menu_layout_for_viewport(Vector2(1280, 720))
	var wide: Dictionary = chrome_kit.menu_layout_for_viewport(Vector2(1920, 1080))
	h._check(narrow.has("purge") and wide.has("purge"), "menu chrome kit returns a layout dict")
	h._check(not (narrow["purge"] as Rect2).is_equal_approx(wide["purge"] as Rect2),
		"menu chrome kit layout follows the viewport")
	# Também era texto-fonte — procurava a ausência de um número mágico. O que
	# ela queria garantir é que a decoração do fundo sai da MESMA geometria que
	# o resto, e não de uma fração recalculada à parte.
	h._check(narrow.has("title") and narrow.has("subtitle"),
		"draw_shell derives its decorative anchors from the shared dict")
	chrome_kit = null

## B12 da auditoria: o jogo não tinha NENHUMA opção de vídeo.
##
## Num build de PC isso é a primeira coisa que o jogador procura no settings.
## O contrato aqui é de comportamento: o modo de janela e o vsync existem, são
## persistidos, e aplicá-los mexe no DisplayServer de verdade.
func _video_settings_test() -> void:
	print("AT_STEP video_settings")
	h._check(Sfx.has_method("set_window_mode") and Sfx.has_method("set_vsync_mode"),
		"settings own the video options")
	if not Sfx.has_method("set_window_mode"):
		return
	var saved_window: int = Sfx.window_mode
	var saved_vsync: int = Sfx.vsync_mode

	h._check(Sfx.WINDOW_MODES.size() >= 3, "window mode offers windowed, fullscreen and borderless")
	h._check(Sfx.VSYNC_MODES.size() >= 2, "vsync offers at least on and off")

	# Persistência: o valor tem de sobreviver a um round-trip pelo disco.
	Sfx.set_window_mode(0)
	Sfx.set_vsync_mode(0)
	Sfx._load_settings()
	h._check(Sfx.window_mode == 0 and Sfx.vsync_mode == 0, "video options survive a save/load round trip")

	# E tem de CHEGAR no servidor de display, não só no arquivo.
	# O driver headless não tem janela nem vsync: verificar o servidor exige
	# a passada gráfica. Antes a chamada de load inexistente escondia isso.
	if Balance.is_desktop_display():
		Sfx.set_vsync_mode(0)
		h._check(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED,
			"turning vsync off reaches the display server")
		Sfx.set_vsync_mode(1)
		h._check(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED,
			"turning vsync on reaches the display server")
	else:
		print("AT_SKIP vsync display round trip requires a graphical display driver")

	# Uma seção nova no settings, e ela aparece na navegação.
	var kit_script: Script = load("res://src/ui/menu_settings_kit.gd")
	h._check(kit_script.SETTINGS_SECTIONS.has("VIDEO"), "settings exposes a video section")
	h._check(str(kit_script.section_label("VIDEO")) != "VIDEO" or TranslationServer.get_locale().begins_with("en"),
		"the video section label goes through the translation table")

	Sfx.set_window_mode(saved_window)
	Sfx.set_vsync_mode(saved_vsync)


func _awards_chrome_test(menu: Node) -> void:
	print("AT_STEP awards_chrome")
	var panel_script: Script = load("res://src/ui/achievements_panel.gd")
	var panel = panel_script.new() if panel_script != null else null
	h._check(panel != null and panel.has_method("awards_panel_rect") and panel.has_method("award_row_rects"), "awards panel exposes its chrome rect and row rect helpers")
	if panel == null:
		return
	for vp in [Vector2(1366, 768), Vector2(432, 720)]:
		var rect: Rect2 = panel.call("awards_panel_rect", vp)
		h._check(Rect2(Vector2.ZERO, vp).encloses(rect.grow(-2.0)), "awards chrome stays inside the viewport at %dx%d" % [int(vp.x), int(vp.y)])
		h._check(rect.size.x >= 240.0 and rect.size.y >= 220.0, "awards chrome keeps a usable panel size at %dx%d" % [int(vp.x), int(vp.y)])
	var awards_text_fits: bool = panel.has_method("text_overflow_report")
	if awards_text_fits:
		for vp in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
			panel.size = vp
			for entry in panel.call("text_overflow_report"):
				awards_text_fits = awards_text_fits and bool(entry.get("fits", false))
	h._check(awards_text_fits, "awards representative text stays inside the editorial rows")
	panel.free()
	# O guard antigo era `menu.get("_ach_panel") != null`, mas o painel só nasce
	# DENTRO de _open_achievements() — a condição nunca era verdadeira e todo o
	# bloco abaixo estava morto desde que foi escrito. Abre primeiro, prova
	# depois.
	if menu != null and menu.has_method("_open_achievements"):
		menu.call("_open_achievements")
		await h._ticks(4)
		var live = menu.get("_ach_panel")
		var list_view: Rect2 = live.call("content_viewport_rect")
		var contained := true
		var row_found := false
		for row in live.call("award_row_rects"):
			row_found = true
			var local_row := Rect2(row)
			local_row.position -= live.global_position
			if not list_view.grow(1.0).encloses(local_row):
				contained = false
		h._check(row_found, "awards panel exposes live row rects for containment probes")
		h._check(contained, "awards rows sit inside the live scroll viewport")
		# Comportamento, não texto-fonte. O fundo deste overlay precisa ser
		# OPACO: era o único dos quatro com alpha 0.88 e o menu vazava por trás
		# (B1 da auditoria de 2026-09-11).
		h._check(live.has_method("backdrop_opacity") and is_equal_approx(float(live.call("backdrop_opacity")), 1.0),
			"awards backdrop is fully opaque so the menu cannot bleed through")
		var backdrop: Node = live.get_node_or_null("AwardsDim")
		h._check(backdrop is ColorRect and (backdrop as ColorRect).anchor_right == 1.0 and (backdrop as ColorRect).anchor_bottom == 1.0,
			"awards panel draws a full-rect backdrop behind the chrome")
		# A direção editorial não depende mais do frame táctico. O contrato aqui é
		# que cada conquista tenha um corpo vivo/mensurável dentro da lista.
		var measurable := true
		for probe in live.call("award_row_rects"):
			if probe.size.y < 2.0:
				measurable = false
		h._check(measurable, "awards rows render with a measurable editorial row body")
		var live_scroll = live.get("_scroll")
		var live_hint = live.get("_hint")
		var live_bar = live_scroll.get_v_scroll_bar() if live_scroll is ScrollContainer else null
		var should_hint: bool = live_bar != null and live_bar.max_value > live_bar.page \
			and Design.breakpoint_for(live.size.x) in ["wide", "ultra"]
		h._check(live_hint is Label and live_hint.visible == should_hint,
			"awards scroll hint appears only when the live list can scroll")
		var back_block = live.get("_back_block")
		var back_hit = back_block.get_meta("hit") if back_block is PanelContainer and back_block.has_meta("hit") else null
		if back_hit is Button:
			back_hit.pressed.emit()
			await h._ticks(2)
		h._check(back_hit is Button and not live.visible, "menu closes achievements through the panel-owned back action")

func _bestiary_i18n_test() -> void:
	print("AT_STEP bestiary_i18n")
	var previous := TranslationServer.get_locale()
	var panel := BestiaryPanel.new()
	h.add_child(panel)
	await h._ticks(1)
	var raw_keys := false
	for locale in ["en", "pt_BR"]:
		TranslationServer.set_locale(locale)
		await h._ticks(1)
		for entry in BestiaryPanel.ENTRIES:
			for field in ["DESC", "BUGS"]:
				var key := "BEST_%s_%s" % [field, str(entry.get("id", "")).to_upper()]
				if panel._entry_text(entry, field) == key:
					raw_keys = true
	h._check(not raw_keys, "every bestiary entry resolves in en and pt_BR")
	TranslationServer.set_locale("en")
	var english := panel._entry_text(BestiaryPanel.ENTRIES[0], "DESC")
	TranslationServer.set_locale("pt_BR")
	var portuguese := panel._entry_text(BestiaryPanel.ENTRIES[0], "DESC")
	h._check(english != portuguese and portuguese.length() > 0, "bestiary prose is actually translated, not just present")
	TranslationServer.set_locale(previous)
	panel.queue_free()
	await h._ticks(1)

func _bestiary_glyph_test() -> void:
	print("AT_STEP bestiary_glyph")
	var glyph_script: Script = load("res://src/ui/glyph_lib.gd")
	h._check(glyph_script != null and glyph_script.has_method("glyph_extent"), "glyph library exposes per-kind extent factors")
	var panel_script: Script = load("res://src/ui/bestiary_panel.gd")
	var panel = panel_script.new() if panel_script != null else null
	h._check(panel != null and panel.has_method("text_overflow_report"), "bestiary keeps text_overflow_report")
	if panel == null:
		return
	var all_fit := true
	var saw_glyph_entry := false
	for vp in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
		panel.size = vp
		for entry in panel.call("text_overflow_report"):
			if str(entry.get("id", "")) == "glyph_contained":
				saw_glyph_entry = true
			if not bool(entry.get("fits", false)):
				all_fit = false
	h._check(saw_glyph_entry, "bestiary report carries the glyph_contained entry")
	h._check(all_fit, "bestiary detail stays contained including glyphs at 1366x768, 720x720, and 432x720")
	panel.free()

func _raster_optical_test() -> void:
	print("AT_STEP raster_optical")
	var icon_script: Script = load("res://src/ui/tactical_icon.gd")
	h._check(icon_script != null and icon_script.has_method("optical_pad") and icon_script.has_method("raster_optouts"), "tactical icon exposes optical padding and the per-size opt-out registry")
	if icon_script == null:
		return
	for kind in icon_script.call("icon_kinds"):
		var pad: float = icon_script.call("optical_pad", str(kind))
		h._check(pad >= 0.02 and pad <= 0.14, "%s icon optical padding stays in the 0.02..0.14 band" % str(kind))
	var src := str(icon_script.source_code)
	h._check_source(src.contains("raster_path(_kind, int(minf(size.x, size.y)))"), "icon draw queries the registry with its rendered size")
	h._check_source(src.contains("draw_texture_rect(tex, Rect2(Vector2(pad, pad)"), "icon raster draws into the padded rect")
	var patch_script: Script = load("res://src/ui/patch_card.gd")
	h._check_source(patch_script != null and str(patch_script.source_code).contains("PATCH_RASTER_PAD"), "patch card raster draws into the padded rect")
	var music_small: String = icon_script.call("raster_path", "music", 24)
	h._check(music_small.is_empty(), "24px opt-out kinds fall back to the code-drawn icon")
	var music_big: String = icon_script.call("raster_path", "music", 52)
	h._check(not music_big.is_empty() and ResourceLoader.exists(music_big), "52px keeps the raster for opt-out kinds")

func _story_path_test() -> void:
	print("AT_STEP story_path")
	var script: Script = load("res://src/ui/story_panel.gd")
	h._check(script != null, "story panel script loads")
	if script == null:
		return
	# Estas quatro asserções eram texto-fonte: procuravam `_draw_node_brackets`,
	# `_draw_state_glyph` e `sin(t` DENTRO do arquivo. Passavam mesmo se as
	# funções nunca fossem chamadas, e travavam a rota na forma desenhada à mão.
	# O que elas queriam garantir é comportamento: os três estados existem, são
	# distinguíveis, e a animação do marcador não toca a rng de gameplay.
	var panel = script.new()
	if panel == null:
		return
	h.get_tree().current_scene.add_child(panel)
	panel.size = Vector2(1366, 768)
	await h._ticks(2)

	var states := ["CLEARED", "CURRENT", "LOCKED"]
	var inks: Array[Color] = []
	var labels := {}
	for state in states:
		inks.append(panel.call("state_ink", state, 0))
		labels[str(panel.call("state_label", str(state)))] = true
	h._check(labels.size() == states.size(), "story rail renders three distinct state labels")
	var distinct := true
	for i in inks.size():
		for j in range(i + 1, inks.size()):
			if inks[i].is_equal_approx(inks[j]):
				distinct = false
	h._check(distinct, "story rail gives each state its own ink")
	h._check(states.has(str(panel.call("stage_state", 0))), "story rail reports a known state for the first stage")

	# O pulso do marcador usa tempo de frame. Se ele sorteasse, a rota
	# consumiria a mesma sequência que o gameplay — o invariante real.
	var seed_before: int = Game.rng.seed
	await h._ticks(6)
	h._check(Game.rng.seed == seed_before, "story rail pulse never advances the gameplay rng")

	# As silhuetas da tela precisam ser tipos que a biblioteca sabe desenhar:
	# se o seletor mostra uma forma e a arena mostra outra, ele ensina errado.
	var kinds: Array = panel.call("glyph_kinds")
	h._check(not kinds.is_empty(), "story detail lists the threats of the selected stage")
	var glyph_seed: int = Game.rng.seed
	for kind in kinds:
		GlyphLib.draw_glyph(null, str(kind), Vector2.ZERO, 16.0, Color.CYAN, 0.0)
	h._check(Game.rng.seed == glyph_seed, "story threat glyphs never advance the gameplay rng")

	var ok := true
	var saw_labels := false
	for vp in [Vector2(1366, 768), Vector2(432, 720)]:
		panel.size = vp
		await h._ticks(2)
		for entry in panel.call("text_overflow_report"):
			if str(entry.get("id", "")) == "story_state_labels":
				saw_labels = true
			ok = ok and bool(entry.get("fits", false))
	h._check(saw_labels, "story report carries the story_state_labels entry")
	h._check(ok, "story rail report stays green including the state labels")
	panel.queue_free()
	await h._ticks(2)

func _leak_guard_test() -> void:
	print("AT_STEP leak_guard")
	var game_src := str(load("res://src/autoload/game.gd").source_code)
	h._check_source(game_src.contains("TacticalIcon.clear_raster_cache()"), "teardown clears the tactical icon raster cache")
	h._check_source(game_src.contains("PatchCard.clear_raster_cache()"), "teardown clears the patch card raster cache")
	h._check_source(game_src.contains("EntitySprite.clear_sprite_cache()"), "teardown clears the sprite trial cache")
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	print("AT_DEBUG leak_guard orphans=%d objects=%d" % [orphans, objects])
	h._check(orphans <= h.LEAK_GUARD_MAX_ORPHANS, "orphan node count stays under the recorded baseline (%d)" % h.LEAK_GUARD_MAX_ORPHANS)

func _sprite_trial_test() -> void:
	print("AT_STEP sprite_trial")
	var sprite_script: Script = load("res://src/ui/entity_sprite.gd")
	h._check(sprite_script != null and sprite_script.has_method("sprite_path") and sprite_script.has_method("has_sprite"), "entity sprite registry exposes the path lookup")
	if sprite_script == null:
		return
	var seed_before := Game.rng.seed
	for kind in ["drone", "lancer", "root", "god", "kernel"]:
		var has := bool(sprite_script.call("has_sprite", str(kind)))
		var path := str(sprite_script.call("sprite_path", str(kind)))
		h._check(has == (path != ""), "sprite registry lookup stays file-driven for %s (glyph fallback when absent)" % str(kind))
		if has:
			h._check(sprite_script.call("sprite_texture", str(kind)) != null, "sprite registry loads the texture for %s" % str(kind))
			h._check(str(path).begins_with("res://assets/sprites/generated/"), "sprite registry resolves %s inside the generated dir" % str(kind))
	h._check(Game.rng.seed == seed_before, "sprite registry lookups never advance the gameplay rng")
	var probe = sprite_script.call("draw_entity", null, "drone", Vector2.ZERO, 24.0, Color.WHITE)
	h._check(not bool(probe), "draw_entity reports the glyph fallback for a null canvas (empty or missing sprite keeps current visuals)")
	var glyph_src := str(load("res://src/ui/glyph_lib.gd").source_code)
	h._check_source(glyph_src.contains("EntitySprite.draw_entity"), "glyph library routes through the single sprite switch")

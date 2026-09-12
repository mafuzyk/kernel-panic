extends RefCounted

## Autotest section script. Function bodies below are moved verbatim from
## src/autoload/dev_harness.gd; only harness-helper references are prefixed
## with `h` per plan section G3. No behavior changes. AT_STEP labels and
## message strings are byte-identical to the originals.

var h: Node


func _init(harness: Node) -> void:
	h = harness

func _task9_test(arena: Arena) -> void:
	print("AT_STEP task9")
	var tactical_script = load("res://src/ui/tactical_ui.gd")
	h._check(tactical_script != null, "tactical UI helper loads")
	if tactical_script != null:
		var full: Dictionary = tactical_script.layout(Vector2(1366, 768))
		var narrow: Dictionary = tactical_script.layout(Vector2(432, 720))
		h._check(not bool(full["compact"]) and bool(narrow["compact"]), "tactical layout selects compact breakpoint")
		for key in ["integrity", "encounter", "score", "dash", "patches", "boss"]:
			var full_rect: Rect2 = full[key]
			var narrow_rect: Rect2 = narrow[key]
			h._check(Rect2(Vector2.ZERO, Vector2(1366, 768)).encloses(full_rect), "full tactical region fits: %s" % key)
			h._check(Rect2(Vector2.ZERO, Vector2(432, 720)).encloses(narrow_rect), "compact tactical region fits: %s" % key)
		h._check(not Rect2(narrow["encounter"]).intersects(Rect2(narrow["integrity"])) and not Rect2(narrow["encounter"]).intersects(Rect2(narrow["score"])), "compact encounter does not cover corner status")
		h._check(not Rect2(narrow["boss"]).intersects(Rect2(narrow["dash"])) and not Rect2(narrow["boss"]).intersects(Rect2(narrow["patches"])), "compact boss frame clears bottom status modules")
		var angular: PackedVector2Array = tactical_script.angular_points(Rect2(10, 20, 100, 50), 10.0)
		h._check(angular.size() == 8 and angular[0] == Vector2(20, 20), "angular frame returns stable clipped corners")
		var segments: Array[Rect2] = tactical_script.segment_rects(Rect2(0, 0, 100, 10), 5, 2.0)
		h._check(segments.size() == 5 and segments[4].end.x <= 100.01, "segmented meter geometry stays inside bounds")
		h._check(tactical_script.has_method("shell_rect") and tactical_script.has_method("shell_sections"), "tactical shell exposes shared frame geometry")
		if tactical_script.has_method("shell_rect") and tactical_script.has_method("shell_sections"):
			var shell: Rect2 = tactical_script.shell_rect(Vector2(1366, 768))
			var shell_bounds := Rect2(Vector2.ZERO, Vector2(1366, 768))
			h._check(shell == Rect2(16.0, 20.0, 1334.0, 728.0), "desktop shell uses the reference inset")
			var sections: Dictionary = tactical_script.shell_sections(Vector2(1366, 768))
			h._check(sections.has("header") and sections.has("content") and sections.has("footer"), "tactical shell exposes header content and footer sections")
			for section_id in ["header", "content", "footer"]:
				h._check(shell.encloses(sections[section_id]) and shell_bounds.encloses(sections[section_id]), "shell %s stays inside viewport" % section_id)
	var chrome_script: Script = load("res://src/ui/tactical_chrome.gd")
	h._check(chrome_script != null, "tactical chrome script loads")
	if chrome_script != null:
		var chrome: Control = chrome_script.new()
		chrome.size = Vector2(1366, 768)
		h._check(chrome.has_method("frame_points") and chrome.frame_points().size() == 8, "tactical chrome exposes clipped frame points")
		h._check(chrome.has_method("configure_control"), "tactical chrome adapts to button bounds")
		if chrome.has_method("configure_control"):
			var button_chrome: Control = chrome_script.new()
			button_chrome.size = Vector2(460, 42)
			button_chrome.call("configure_control", Color(0.1, 0.85, 1.0, 1.0), 0.02)
			h._check(button_chrome.frame_rect() == Rect2(Vector2.ZERO, Vector2(460, 42)), "button chrome follows control bounds")
			button_chrome.queue_free()
		chrome.queue_free()
	var icon_script: Script = load("res://src/ui/tactical_icon.gd")
	h._check(icon_script != null, "tactical icon script loads")
	if icon_script != null:
		var icon: Control = icon_script.new()
		icon.size = Vector2(48, 48)
		h._check(icon.has_method("configure") and icon.has_method("icon_kind"), "tactical icon exposes semantic configuration")
		if icon.has_method("configure") and icon.has_method("icon_kind"):
			icon.call("configure", "settings", Color(0.1, 0.85, 1.0, 1.0))
			h._check(icon.icon_kind() == "settings", "tactical icon keeps its semantic kind")
		h._check(icon.has_method("music_glyph_bounds"), "music icon exposes measurable glyph bounds")
		if icon.has_method("music_glyph_bounds"):
			var music_bounds: Rect2 = icon.call("music_glyph_bounds", Vector2(24.0, 24.0))
			h._check(music_bounds.size.x >= 12.0 and music_bounds.size.y >= 16.0, "music icon remains legible at compact pause size")
		icon.queue_free()
	var hud: Hud = arena.hud
	var hud_layout_ready := hud.has_method("layout_snapshot") and hud.has_method("visible_event_lines") and hud.has_method("event_log_visible")
	h._check(hud_layout_ready, "HUD exposes tactical layout and event log APIs")
	if hud_layout_ready:
		var saved_event_log: Array[Dictionary] = Game.event_log.duplicate(true)
		Game.event_log = [
			{"time": 1.0, "text": "ONE"}, {"time": 2.0, "text": "TWO"},
			{"time": 3.0, "text": "THREE"}, {"time": 4.0, "text": "FOUR"},
			{"time": 5.0, "text": "FIVE"},
		]
		var lines: Array[String] = hud.visible_event_lines()
		h._check(lines.size() == 4 and lines[0].contains("TWO") and lines[3].contains("FIVE"), "HUD event log keeps the newest four entries")
		h._check(hud.event_log_visible(Vector2(1366, 768)), "event log is visible in full layout")
		h._check(not hud.event_log_visible(Vector2(540, 720)), "event log collapses in compact layout")
		Game.event_log = saved_event_log
	var dock_ready := hud.has_method("patch_dock_rects")
	h._check(dock_ready, "HUD exposes responsive patch dock geometry")
	if dock_ready:
		for viewport in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
			var dock: Dictionary = hud.patch_dock_rects(viewport)
			for patch_id in dock:
				h._check(Rect2(Vector2.ZERO, viewport).encloses(dock[patch_id]), "patch dock chip fits %dx%d" % [int(viewport.x), int(viewport.y)])
	var boss_geometry_ready := hud.has_method("boss_bar_rects")
	h._check(boss_geometry_ready, "HUD exposes boss bar geometry")
	if boss_geometry_ready:
		for viewport in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
			var normal_rows: Array[Rect2] = hud.boss_bar_rects(viewport, false)
			var split_rows: Array[Rect2] = hud.boss_bar_rects(viewport, true)
			h._check(normal_rows.size() == 1 and split_rows.size() == 2, "boss geometry exposes one or two combined rows")
			for row in split_rows:
				h._check(Rect2(Vector2.ZERO, viewport).encloses(row), "split boss row fits %dx%d" % [int(viewport.x), int(viewport.y)])
	var patch_card_script: Script = load("res://src/ui/patch_card.gd")
	h._check(patch_card_script != null, "tactical patch card script loads")
	if patch_card_script != null:
		var patch_card: Control = patch_card_script.new()
		patch_card.configure({"id": "staticf", "title": "STATIC FIELD", "desc": "BURNS ENEMIES WITHIN 70PX", "rare": true, "legend": true}, 0)
		patch_card.size = Vector2(280.0, 330.0)
		h.get_tree().current_scene.add_child(patch_card)
		await h._ticks(2)
		h._check(patch_card.theme == UiTheme.shared(), "patch card uses the shared editorial theme")
		h._check(patch_card.has_method("card_ink"), "patch card exposes semantic ink roles")
		if patch_card.has_method("card_ink"):
			var patch_ink: Dictionary = patch_card.call("card_ink")
			h._check(patch_ink.get("title", Color.BLACK) == Design.TEXT_PRIMARY,
				"patch card title stays neutral instead of inheriting rarity colour")
			h._check(patch_ink.get("body", Color.BLACK) == Design.TEXT_SECONDARY,
				"patch card body stays neutral instead of inheriting rarity colour")
			h._check(patch_ink.get("marker", Color.BLACK) == Design.WARNING,
				"legendary patch keeps rarity colour as a marker")
		h._check(patch_card.has_method("content_rects"), "patch card exposes live content geometry")
		if patch_card.has_method("content_rects"):
			var patch_bounds := Rect2(Vector2.ZERO, patch_card.size)
			var patch_content_inside := true
			var patch_content_measurable := true
			for raw_rect in patch_card.call("content_rects"):
				patch_content_inside = patch_content_inside and patch_bounds.encloses(raw_rect)
				patch_content_measurable = patch_content_measurable and raw_rect.size.x > 0.0 and raw_rect.size.y > 0.0
			h._check(patch_content_inside, "patch card content stays inside the 280x330 card")
			h._check(patch_content_measurable, "patch card editorial content keeps measurable layout boxes")
			h._check(patch_card.has_method("rarity_label") and patch_card.rarity_label() == "LEGENDARY", "patch card exposes semantic rarity label")
			h._check(patch_card.has_method("card_title") and patch_card.card_title() == "STATIC FIELD", "patch card preserves readable title")
			var patch_title_node = patch_card.get("_title")
			h._check(patch_title_node is Label and patch_title_node.text == "STATIC FIELD" \
				and patch_title_node.size.y >= float(Design.TEXT_HEADING),
				"patch card renders its title as a visible editorial heading")
			var patch_icon_slot = patch_card.get("_icon_slot")
			var icon_inside := false
			if patch_icon_slot is Control:
				var icon_rect := Rect2(patch_icon_slot.global_position - patch_card.global_position, patch_icon_slot.size)
				icon_inside = Rect2(Vector2.ZERO, patch_card.size).encloses(icon_rect) \
					and icon_rect.size.x >= 52.0 and icon_rect.size.y >= 52.0
			h._check(icon_inside, "patch card keeps its live icon slot contained and large enough for the 52px glyph")
			var selected_indices: Array[int] = []
			patch_card.selected.connect(func(selected_index: int) -> void: selected_indices.append(selected_index))
			var patch_hit: Button = null
			for child in patch_card.get_children():
				if child is Button:
					patch_hit = child
					break
			h._check(patch_hit != null, "patch card exposes a full-card interactive hit target")
			if patch_hit != null:
				patch_hit.emit_signal("pressed")
			h._check(selected_indices == [0], "patch card click emits its configured selection index")
			patch_card.queue_free()
			await h._ticks(2)
			var long_card: Control = patch_card_script.new()
			long_card.configure({"id": "restore", "title": "REINTEGRATION", "desc": "RECOVER LOST INTEGRITY", "rare": false, "legend": false}, 1)
			long_card.size = Vector2(294.0, 295.0)
			h.get_tree().current_scene.add_child(long_card)
			await h._ticks(2)
			var long_title = long_card.get("_title")
			var long_title_fits := false
			if long_title is Label:
				var title_font: Font = long_title.get_theme_font("font")
				var title_size: int = long_title.get_theme_font_size("font_size")
				var measured := title_font.get_string_size("REINTEGRATION", HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
				long_title_fits = measured <= long_title.size.x + 0.5
			h._check(long_title_fits, "long patch titles stay on one editorial heading line")
			long_card.queue_free()
			await h._ticks(2)
		var patch_box_visual := arena.patch_box_rect_for_viewport(Vector2(1366, 768))
		var patch_cards_visual: Array[Rect2] = arena.patch_card_rects_for_viewport(Vector2(1366, 768))
		h._check(patch_box_visual.position.y > 230.0 and patch_box_visual.position.y < 270.0 and patch_box_visual.size.y > 280.0 and patch_box_visual.size.y < 315.0 and patch_box_visual.end.y < 570.0, "patch cards match the approved compact overlay proportion")
		var patch_cards_aligned := patch_cards_visual.size() == 3
		if patch_cards_aligned:
			for card in patch_cards_visual:
				patch_cards_aligned = patch_cards_aligned and absf(card.position.y - patch_cards_visual[0].position.y) < 0.01 and absf(card.size.y - patch_cards_visual[0].size.y) < 0.01
		h._check(patch_cards_aligned, "patch cards share one straight baseline and height")
		h._check(arena.has_method("patch_header_rect_for_viewport"), "patch offer exposes responsive editorial header geometry")
		if arena.has_method("patch_header_rect_for_viewport"):
			for vp in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
				var header: Rect2 = arena.patch_header_rect_for_viewport(vp)
				var box: Rect2 = arena.patch_box_rect_for_viewport(vp)
				h._check(Rect2(Vector2.ZERO, vp).encloses(header) and header.end.y <= box.position.y,
					"patch editorial header stays above the cards at %dx%d" % [int(vp.x), int(vp.y)])
		var live_patch_panel = arena.get("_patch_panel")
		var live_patch_title: Label = live_patch_panel.find_child("PatchOfferTitle", true, false) if live_patch_panel is Control else null
		h._check(live_patch_panel is Control and live_patch_panel.theme == UiTheme.shared(), "patch offer wrapper uses the shared design theme")
		h._check(live_patch_title != null and live_patch_title.get_theme_font("font") == Design.grotesk(Design.WEIGHT_BLACK),
			"patch offer title uses the editorial grotesk instead of Orbitron")
		h._check(live_patch_title != null and live_patch_title.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT,
			"patch offer title follows the left-aligned editorial hierarchy")
	var tactical_surface_script: Script = load("res://src/ui/tactical_state_surface.gd")
	var state_surface_ready := arena.has_method("state_panel_rect") and arena.has_method("state_action_rects") and arena.has_method("pause_action_labels") and arena.has_method("game_over_action_labels")
	h._check(state_surface_ready, "state panels expose tactical geometry and action labels")
	# A pausa virou PausePanel (containers), então a geometria não vem mais de
	# um dicionário de retângulos absolutos. Estas asserções medem o painel
	# VIVO e guardam os invariantes do desenho aprovado.
	h._check(tactical_surface_script.has_method("terminal_layout"), "terminal surface exposes one shared responsive layout")
	if is_instance_valid(arena._pause_screen):
		arena._set_paused(true)
		await h._ticks(3)
		var screen = arena._pause_screen
		# Mesma cobertura de resolução que as asserções aposentadas tinham, MAIS
		# 1920x1080 — que a matriz antiga nunca cobria (B5 da auditoria: nada
		# acima de 1366 de largura era testado, e é por isso que tudo quebrava lá).
		for viewport_size in [Vector2(1920, 1080), Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
			screen.size = viewport_size
			await h._ticks(2)
			var label := "%dx%d" % [int(viewport_size.x), int(viewport_size.y)]
			var screen_rect := Rect2(Vector2.ZERO, viewport_size)
			var all_inside := true
			var slider_ok := true
			for content in screen.content_rects():
				if not screen_rect.encloses(content):
					all_inside = false
				if content.size.x > Design.CONTENT_MAX_PROSE:
					slider_ok = false
			h._check(all_inside, "pause content stays inside the screen at %s" % label)
			# Os sliders pararam de esticar: antes um valor 0-100% ocupava
			# ~1000px em 1920 e o rótulo ficava a 1200px do controle.
			h._check(slider_ok, "pause controls respect the content max width at %s" % label)

			# B6 por estrutura: o abandono fica no extremo oposto das ações
			# seguras. A distância é o aviso — não existe mais moldura de perigo
			# onde uma dica de teclado possa cair dentro por engano.
			var abandon_block = screen.get("_abandon_block")
			var first_action: Button = h._first_button(screen)
			if abandon_block != null and first_action != null:
				# Em tela larga a separação é horizontal; em janela estreita a
				# fileira vira coluna e a separação passa a ser vertical. O
				# invariante é o mesmo: o abandono nunca encosta nas ações seguras.
				var safe := Rect2(first_action.global_position, first_action.size)
				var danger := Rect2(abandon_block.global_position, abandon_block.size)
				h._check(not safe.intersects(danger), "pause abandon stays clear of the safe actions at %s" % label)
		screen.size = arena.get_viewport_rect().size
		arena._set_paused(false)
	h._check(arena.pause_action_labels() == [tr("PAUSE_RESUME"), tr("PAUSE_RESTART"), tr("PAUSE_TERMINAL"), tr("PAUSE_ABANDON")], "pause actions preserve safe order")
	h._check(arena.has_method("pause_action_icon_kinds"), "pause actions expose semantic icons")
	if arena.has_method("pause_action_icon_kinds"):
		h._check(arena.pause_action_icon_kinds() == ["resume", "restart", "terminal", "warning"], "pause icons preserve action semantics")
	# Locale-independente: a direção editorial aprovada usa caixa de frase
	# ("Reboot"), então fixar a string em CAIXA ALTA passou a ser errado.
	# O que importa é a ordem — repetir vem antes de abandonar.
	h._check(arena.game_over_action_labels() == [tr("OVER_REBOOT"), tr("OVER_ABANDON")], "game-over actions preserve retry first")
	var terminal: Control = arena._terminal_panel
	var terminal_ready := terminal != null and terminal.has_method("workstation_rect") and terminal.has_method("status_snapshot")
	h._check(terminal_ready, "terminal exposes tactical workstation geometry")
	if terminal_ready:
		for viewport_size in [Vector2(1366, 768), Vector2(720, 720), Vector2(432, 720)]:
			var terminal_rect: Rect2 = terminal.workstation_rect(viewport_size)
			h._check(Rect2(Vector2.ZERO, viewport_size).encloses(terminal_rect), "terminal workstation fits viewport %dx%d" % [int(viewport_size.x), int(viewport_size.y)])
		var terminal_status: Dictionary = terminal.status_snapshot()
		h._check(str(terminal_status.get("tty", "")) == "TTY0" and bool(terminal_status.get("paused", false)), "terminal status identifies frozen TTY")
		h._check(int(terminal_status.get("command_count", -1)) >= 0 and bool(terminal_status.get("prompt_visible", false)), "terminal status exposes command count and prompt")
	var saved_hud_size := hud.size
	hud.size = Vector2(1280, 720)
	var layout_helpers_ready := hud.has_method("boss_bar_baseline") and hud.has_method("dash_baseline")
	h._check(layout_helpers_ready, "HUD exposes responsive bottom layout helpers")
	if layout_helpers_ready:
		var boss_y_720: float = hud.boss_bar_baseline()
		var dash_y_720: float = hud.dash_baseline()
		hud.size = Vector2(1280, 900)
		h._check(hud.boss_bar_baseline() > boss_y_720, "boss bar baseline follows viewport height")
		h._check(hud.dash_baseline() > dash_y_720, "dash baseline follows viewport height")
	hud.size = saved_hud_size
	var patch_layout_ready := arena.has_method("patch_box_rect_for_viewport") and arena.has_method("patch_card_rects_for_viewport")
	h._check(patch_layout_ready, "patch panel exposes narrow viewport layout helpers")
	if patch_layout_ready:
		for viewport_size in [Vector2(432, 720), Vector2(720, 720)]:
			var patch_box: Rect2 = arena.patch_box_rect_for_viewport(viewport_size)
			h._check(patch_box.position.x >= 0.0 and patch_box.end.x <= viewport_size.x, "patch box fits viewport width %dx%d" % [int(viewport_size.x), int(viewport_size.y)])
			var card_rects: Array[Rect2] = arena.patch_card_rects_for_viewport(viewport_size)
			h._check(card_rects.size() == 3, "patch layout keeps three cards at %dx%d" % [int(viewport_size.x), int(viewport_size.y)])
			for card_rect in card_rects:
				h._check(card_rect.position.x >= 0.0 and card_rect.end.x <= viewport_size.x, "patch card stays inside viewport at %dx%d" % [int(viewport_size.x), int(viewport_size.y)])
	var panel_layout_ready := arena.has_method("panel_control_rect")
	h._check(panel_layout_ready, "combat panels expose responsive vertical layout helper")
	if panel_layout_ready:
		for viewport_height in [360.0, 432.0, 720.0, 900.0]:
			for design_top in [118.0, 150.0, 220.0, 500.0, 550.0]:
				var panel_rect: Rect2 = arena.panel_control_rect(design_top, 62.0, viewport_height)
				h._check(panel_rect.position.y >= 0.0 and panel_rect.end.y <= viewport_height, "panel control fits viewport height %.0f" % viewport_height)
		var real_refresh_ready := arena.has_method("_refresh_responsive_layout_for_height")
		h._check(real_refresh_ready, "responsive refresh accepts simulated viewport height")
		for viewport_height in [360.0, 432.0]:
			if not real_refresh_ready:
				continue
			arena._refresh_responsive_layout_for_height(viewport_height)
			var real_controls_fit := true
			for panel in [arena._pause_screen, arena._run_summary, arena._patch_panel]:
				if panel == null or not is_instance_valid(panel):
					continue
				for control in panel.get_children():
					if not control is Control or not control.has_meta("panel_design_top"):
						continue
					var scale := float(control.scale.y)
					var control_top: float = viewport_height * 0.5 + float(control.offset_top)
					var control_bottom: float = control_top + (float(control.offset_bottom) - float(control.offset_top)) * scale
					if control_top < -0.01 or control_bottom > viewport_height + 0.01:
						real_controls_fit = false
			h._check(real_controls_fit, "real panel controls stay inside simulated viewport height %.0f" % viewport_height)
		arena._refresh_responsive_layout()

	var touch_ui := TouchControls.new()
	var saved_touch_scale := Sfx.touch_scale
	var touch_helpers_ready := touch_ui.has_method("movement_geometry") and touch_ui.has_method("movement_vector_from_offset")
	h._check(touch_helpers_ready, "touch controls expose scaled movement geometry")
	if touch_helpers_ready:
		var reference_vector := Vector2.ZERO
		for scale in [0.85, 1.0, 1.2]:
			Sfx.touch_scale = scale
			var geometry: Dictionary = touch_ui.movement_geometry()
			h._check(absf(float(geometry["travel_radius"]) - 110.0 * scale) < 0.01, "movement travel radius scales at %.2f" % scale)
			h._check(absf(float(geometry["normalization_divisor"]) - 90.0 * scale) < 0.01, "movement divisor scales at %.2f" % scale)
			h._check(absf(float(geometry["draw_radius"]) - 64.0 * scale) < 0.01, "movement draw radius scales at %.2f" % scale)
			h._check(absf(float(geometry["knob_radius"]) - 22.0 * scale) < 0.01, "movement knob radius scales at %.2f" % scale)
			var normalized: Vector2 = touch_ui.movement_vector_from_offset(Vector2(45.0, 27.0) * scale)
			if reference_vector == Vector2.ZERO:
				reference_vector = normalized
			else:
				h._check(normalized.distance_to(reference_vector) < 0.001, "movement vector stays normalized at %.2f" % scale)
	Sfx.touch_scale = saved_touch_scale
	touch_ui.free()

func _task6_test(arena: Arena) -> void:
	print("AT_STEP task6")
	var cover_player := Node2D.new()
	cover_player.position = Vector2.ZERO
	arena.add_child(cover_player)
	var spewer := SpewerEnemy.new()
	spewer.player = cover_player
	spewer.position = Vector2(320, 0)
	var bulwark := BulwarkEnemy.new()
	bulwark.position = Vector2(150, 0)
	EnemyBase.shared_list = [spewer, bulwark]
	var cover_position: Vector2 = spewer.find_bulwark_cover(cover_player.global_position)
	var cover_safe := Balance.arena_rect().grow(-spewer.radius).has_point(cover_position)
	h._check(cover_position != Vector2.ZERO and cover_safe, "ranged cover returns an arena-safe position")
	h._check(cover_position.x > bulwark.global_position.x and cover_position.distance_to(bulwark.global_position) > bulwark.radius + spewer.radius, "ranged cover prefers a point behind the BULWARK")
	spewer._strafe_dir = 1.0
	spewer._telegraph = 0.0
	spewer._fire_t = 99.0
	spewer._v = Vector2.ZERO
	spewer._move(0.1)
	var cover_seek := (cover_position - spewer.global_position).normalized()
	h._check(spewer.vel().dot(cover_seek) > 0.0, "Spewer steers toward valid BULWARK cover")
	EnemyBase.shared_list = [spewer]
	spewer.position = Vector2(100, 0)
	spewer._v = Vector2.ZERO
	spewer._telegraph = 0.0
	spewer._fire_t = 99.0
	spewer._move(0.1)
	h._check(spewer.vel().dot(Vector2.RIGHT) > 0.0, "Spewer retreat is not overridden by cover")
	EnemyBase.shared_list = [spewer, bulwark]
	spewer.position = Vector2(320, 0)
	spewer._v = Vector2(100, 0)
	spewer._telegraph = 0.2
	spewer._fire_t = 99.0
	spewer._move(0.1)
	h._check(spewer.vel().length() < 100.0, "Spewer telegraph braking is not overridden by cover")
	EnemyBase.shared_list = [spewer]
	spewer.position = Vector2(320, 0)
	spewer._v = Vector2.ZERO
	var no_cover: Vector2 = spewer.find_bulwark_cover(cover_player.global_position)
	h._check(no_cover == Vector2.ZERO, "ranged cover returns zero without a BULWARK")
	spewer._telegraph = 0.0
	spewer._fire_t = 99.0
	spewer._move(0.1)
	h._check(spewer.vel().length() > 0.0, "Spewer keeps distance-band fallback without cover")
	spewer.free()
	bulwark.free()
	cover_player.free()
	await h._ticks(2)

	var split_parent := Node2D.new()
	arena.add_child(split_parent)
	var elite_splitter := SplitterEnemy.new()
	elite_splitter.configure(1.0, true)
	elite_splitter.elite = true
	elite_splitter.elite_kind = "volatile"
	elite_splitter.position = Vector2(200, 0)
	split_parent.add_child(elite_splitter)
	await h._ticks(1)
	elite_splitter.die()
	await h._ticks(2)
	var mini_children: Array[DroneEnemy] = []
	for child in split_parent.get_children():
		if child is DroneEnemy and child.mini:
			mini_children.append(child)
	h._check(mini_children.size() == 2, "elite Splitter still creates two mini drones")
	var minis_non_elite := true
	for mini in mini_children:
		if mini.elite or mini.elite_kind != "":
			minis_non_elite = false
	h._check(minis_non_elite, "Splitter mini drones never inherit elite state")
	for mini in mini_children:
		mini.queue_free()
	split_parent.queue_free()
	EnemyBase.shared_list = arena.enemy_list
	await h._ticks(2)

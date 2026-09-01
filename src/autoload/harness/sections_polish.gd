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
	h._check(kit != null and kit.has_method("set_active_section") and kit.has_method("active_section") and kit.has_method("settings_section_snapshot"), "settings kit exposes the section state machine")
	if kit == null or not kit.has_method("set_active_section"):
		return
	var sections: Array = kit.call("section_names")
	h._check(sections == ["AUDIO", "GAMEPLAY", "CONTROLS", "ACCESSIBILITY", "SAVE DATA"], "settings kit declares the five sections in order")
	menu.call("_open_settings")
	await h._ticks(2)
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
		h._check(title != null and str(title.text).ends_with(str(section)), "settings title shows the active section (%s)" % str(section))
		var selected_index: int = sections.find(str(section))
		var nav_buttons: Array = menu.get("_settings_nav_buttons")
		var selected_ok: bool = nav_buttons.size() == sections.size()
		for i in nav_buttons.size():
			var btn: Button = nav_buttons[i]
			if (i == selected_index) != str(btn.text).begins_with("▸"):
				selected_ok = false
		h._check(selected_ok, "exactly one nav button carries the selected marker (%s)" % str(section))
	kit.call("set_active_section", "AUDIO")
	h.get_viewport().push_input(h._key_event(KEY_ESCAPE))
	h._check(not bool(menu.get("_settings_panel").visible), "ESC still closes the whole settings panel")
	menu.call("_close_settings")

func _settings_chips_test(menu: Node) -> void:
	print("AT_STEP settings_chips")
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
	var chip_selected: bool = chips.size() == 5
	for i in chips.size():
		if (i == 4) != str(chips[i].text).begins_with("▸"):
			chip_selected = false
	h._check(chip_selected, "chips share the active section state with the sidebar")
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
	var src := str(load("res://src/ui/menu_chrome_kit.gd").source_code)
	h._check(src.contains("apply_menu_layout"), "menu chrome kit applies the layout dict on resize")
	h._check(not src.contains("m.size.y * 0.44"), "draw_shell derives its decorative anchors from the shared dict")

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
	var src := str(panel_script.source_code)
	h._check(src.contains("AwardsDim"), "awards panel draws a full-rect dim behind the chrome")
	h._check(src.contains("configure_panel"), "awards rows use angular chrome frames")
	panel.free()
	if menu != null and menu.get("_ach_panel") != null:
		menu.call("_open_achievements")
		await h._ticks(2)
		var live = menu.get("_ach_panel")
		var chrome_rect: Rect2 = live.call("awards_panel_rect", live.size)
		var contained := true
		var row_found := false
		for row in live.call("award_row_rects"):
			row_found = true
			if not chrome_rect.grow(-4.0).encloses(Rect2(row)):
				contained = false
		h._check(row_found, "awards panel exposes live row rects for containment probes")
		h._check(contained, "awards rows sit inside the chrome at the live viewport")
		menu.call("_close_achievements")

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
	h._check(src.contains("raster_path(_kind, int(minf(size.x, size.y)))"), "icon draw queries the registry with its rendered size")
	h._check(src.contains("draw_texture_rect(tex, Rect2(Vector2(pad, pad)"), "icon raster draws into the padded rect")
	var patch_script: Script = load("res://src/ui/patch_card.gd")
	h._check(patch_script != null and str(patch_script.source_code).contains("PATCH_RASTER_PAD"), "patch card raster draws into the padded rect")
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
	var src := str(script.source_code)
	h._check(src.contains("_draw_node_brackets"), "story rail draws node brackets")
	h._check(src.contains("_draw_state_glyph"), "story rail draws state rings and glyphs")
	h._check(src.contains("\"CLEARED\"") and src.contains("\"CURRENT\"") and src.contains("\"LOCKED\""), "story rail renders the three state labels")
	h._check(src.contains("sin(t"), "story rail keeps the cosmetic-time pulse (no gameplay rng)")
	var panel = script.new()
	if panel == null:
		return
	var ok := true
	var saw_labels := false
	for vp in [Vector2(1366, 768), Vector2(432, 720)]:
		panel.size = vp
		for entry in panel.call("text_overflow_report"):
			if str(entry.get("id", "")) == "story_state_labels":
				saw_labels = true
			ok = ok and bool(entry.get("fits", false))
	h._check(saw_labels, "story report carries the story_state_labels entry")
	h._check(ok, "story rail report stays green including the state labels")
	panel.free()

func _leak_guard_test() -> void:
	print("AT_STEP leak_guard")
	var game_src := str(load("res://src/autoload/game.gd").source_code)
	var hud_src := str(load("res://src/ui/hud.gd").source_code)
	h._check(hud_src.contains("func _on_patch_picked") and hud_src.contains("Game.patch_picked.connect(_on_patch_picked)") and not hud_src.contains("Game.patch_picked.connect(func"), "HUD patch signal uses a lifecycle-safe bound method")
	h._check(game_src.contains("TacticalIcon.clear_raster_cache()"), "teardown clears the tactical icon raster cache")
	h._check(game_src.contains("PatchCard.clear_raster_cache()"), "teardown clears the patch card raster cache")
	h._check(game_src.contains("EntitySprite.clear_sprite_cache()"), "teardown clears the sprite trial cache")
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	print("AT_DEBUG leak_guard orphans=%d objects=%d" % [orphans, objects])
	h._check(orphans <= h.LEAK_GUARD_MAX_ORPHANS, "orphan node count stays under the recorded baseline (%d)" % h.LEAK_GUARD_MAX_ORPHANS)

func _sprite_trial_test() -> void:
	print("AT_STEP sprite_trial")
	var sprite_script: Script = load("res://src/ui/entity_sprite.gd")
	h._check(sprite_script != null and sprite_script.has_method("sprite_path") and sprite_script.has_method("has_sprite") and sprite_script.has_method("sprites_enabled"), "entity sprite registry exposes the path lookup and author gate")
	if sprite_script == null:
		return
	h._check(not bool(sprite_script.call("sprites_enabled")), "arena entity sprites remain disabled until behavior parity review")
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
	h._check(glyph_src.contains("EntitySprite.draw_entity"), "glyph library routes through the single sprite switch")

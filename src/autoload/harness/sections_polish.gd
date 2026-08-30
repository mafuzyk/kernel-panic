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

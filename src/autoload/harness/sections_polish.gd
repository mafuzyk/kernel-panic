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

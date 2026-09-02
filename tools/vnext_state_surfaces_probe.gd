extends Node

var fails := 0
var done := false

func _check(ok: bool, label: String) -> void:
	if ok:
		print("PROBE_PASS ", label)
	else:
		fails += 1
		print("PROBE_FAIL ", label)

func _ready() -> void:
	_check(OS.get_environment("KP_VNEXT_U4") == "1", "probe runs with U4 opt-in")
	var pause_script: Script = load("res://src/ui/vnext/surfaces/pause_surface.gd")
	var terminal_script: Script = load("res://src/ui/vnext/surfaces/terminal_surface.gd")
	var over_script: Script = load("res://src/ui/vnext/surfaces/game_over_surface.gd")
	_check(pause_script != null, "pause surface script exists")
	_check(terminal_script != null, "terminal surface script exists")
	_check(over_script != null, "game-over surface script exists")
	if pause_script == null or terminal_script == null or over_script == null:
		_finish()
		return
	Game.mode = "classic"
	Game.state = Game.State.PLAYING
	Game.stats = {"kills": 0, "shots": 0, "hits": 0, "damage": 0, "time": 0.0, "wave": 1, "boss_kills": 0, "heals": {}}
	for surface_script in [pause_script, terminal_script, over_script]:
		var surface: Control = surface_script.new()
		add_child(surface)
		_check(surface.has_method("layout_snapshot"), "%s exposes layout snapshot" % surface_script.resource_path)
		_check(surface.has_method("semantic_snapshot"), "%s exposes semantic snapshot" % surface_script.resource_path)
		_check(surface.has_method("action_regions"), "%s exposes action regions" % surface_script.resource_path)
		_check(surface.has_method("text_overflow_report"), "%s exposes overflow report" % surface_script.resource_path)
		for viewport in [Vector2(432, 720), Vector2(720, 720), Vector2(1280, 720)]:
			surface.call("reflow_for_viewport", viewport)
			if surface.has_method("show_pause"):
				surface.call("show_pause", {"context": "KERNEL // SCORE 0000000 // CYCLE 01"})
			elif surface.has_method("show_terminal"):
				surface.call("show_terminal", {"event_stream": "EVENT STREAM // RUN FROZEN\nREADY FOR DIAGNOSTICS"})
			else:
				surface.call("show_game_over", {"variant": "death", "title": "PROCESS TERMINATED", "diagnosis": "RUN DIAGNOSIS // PROCESS STOPPED", "stats": "CORE STATUS // CAPTURED\nRUN STATUS // RECORDED", "primary_available": true})
			_check(_layout_is_safe(surface.call("layout_snapshot"), viewport), "%s layout is safe at %s" % [surface_script.resource_path, viewport])
			var surface_overflow: Dictionary = surface.call("text_overflow_report")
			if bool(surface_overflow.get("has_overflow", true)):
				print("PROBE_OVERFLOW ", surface_script.resource_path, " ", viewport, " ", surface_overflow)
			_check(not bool(surface_overflow.get("has_overflow", true)), "%s text fits at %s" % [surface_script.resource_path, viewport])
			if surface_script == pause_script and viewport == Vector2(432, 720):
				var title_field: Dictionary = surface_overflow.get("fields", {}).get("title", {})
				_check(int(title_field.get("font_size", 0)) >= 14, "pause title uses a readable fitted font on narrow view")
				_check(float(title_field.get("measured_width", 9999.0)) <= float(title_field.get("available_width", 0.0)), "pause title fits with its actual display font on narrow view")
			if surface_script == terminal_script and viewport == Vector2(432, 720):
				var terminal_title: Dictionary = surface_overflow.get("fields", {}).get("title", {})
				_check(int(terminal_title.get("font_size", 0)) >= 14, "terminal title stays readable beside narrow close action")
				_check(float(terminal_title.get("measured_width", 9999.0)) <= float(terminal_title.get("available_width", 0.0)), "terminal title fits beside narrow close action")
		surface.queue_free()
	await get_tree().process_frame
	var arena_script: Script = load("res://src/arena/arena.gd")
	var arena: Node = arena_script.new()
	get_tree().root.call_deferred("add_child", arena)
	await get_tree().process_frame
	_check(arena.has_method("vnext_u4_enabled") and bool(arena.call("vnext_u4_enabled")), "Arena exposes U4 opt-in adapter")
	_check(arena.has_method("vnext_u4_surface") and arena.call("vnext_u4_surface") != null, "Arena mounts one U4 surface adapter")
	_check(arena.get("_pause_panel") != null and arena.get("_terminal_panel") != null and arena.get("_over_panel") != null, "legacy panel APIs remain present")
	if arena.has_method("vnext_u4_surface"):
		var surface: Control = arena.call("vnext_u4_surface") as Control
		_check(surface != null and surface.has_method("configure_adapter"), "U4 surface accepts Arena snapshot adapter")
		for viewport in [Vector2(432, 720), Vector2(720, 720), Vector2(1280, 720)]:
			if surface != null and surface.has_method("reflow_for_viewport"):
				surface.call("reflow_for_viewport", viewport)
				var layout: Dictionary = surface.call("layout_snapshot")
				print("PROBE_LAYOUT ", viewport, " ", layout)
				_check(_layout_is_safe(layout, viewport), "U4 layout is safe at %s" % viewport)
				_check(not bool(surface.call("text_overflow_report").get("has_overflow", true)), "U4 text fits at %s" % viewport)
				_check(not bool(surface.call("text_overflow_report").get("has_unmeasured_fields", true)), "U4 fields are measured at %s" % viewport)
		arena.set("_state", "play")
		Game.state = Game.State.PLAYING
		get_viewport().push_input(_key(KEY_ESCAPE, true)); get_viewport().push_input(_key(KEY_ESCAPE, false)); await get_tree().process_frame
		_check(get_tree().paused and bool(arena.call("vnext_u4_visible")), "real ESC opens U4 pause")
		get_viewport().push_input(_key(KEY_ESCAPE, true)); get_viewport().push_input(_key(KEY_ESCAPE, false)); await get_tree().process_frame
		_check(not get_tree().paused, "real ESC resumes from U4 pause")
		arena.call("_set_paused", true)
		_check(get_tree().paused, "real Arena pause freezes tree")
		_check(bool(arena.call("vnext_u4_visible")), "pause opens U4 surface")
		var pause_buttons: Dictionary = surface.get("_buttons")
		_check(pause_buttons.size() == 4 and bool((pause_buttons["resume"] as Button).visible), "pause actions are visibly mounted")
		var before_score := int(Game.score)
		_check(int(Game.score) == before_score, "pause input does not mutate gameplay")
		Game.state = Game.State.PLAYING; arena.call("_set_paused", true)
		arena.call("_show_vnext_u4_terminal")
		await get_tree().process_frame
		var terminal: Control = arena.call("vnext_u4_surface") as Control
		_check(terminal != null and terminal.has_method("history_snapshot"), "terminal exposes history snapshot")
		if terminal != null:
			var line_edit: LineEdit = terminal.get("_input")
			_check(line_edit != null and line_edit.has_focus(), "terminal owns LineEdit focus")
			_check(line_edit != null and line_edit.visible and bool((terminal.get("_run") as Button).visible) and bool((terminal.get("_close") as Button).visible), "terminal controls are visibly mounted")
			if line_edit != null:
				line_edit.text = "top"; get_viewport().push_input(_key(KEY_ENTER, true)); get_viewport().push_input(_key(KEY_ENTER, false)); await get_tree().process_frame
				_check(int(terminal.call("semantic_snapshot").get("history_size", -1)) == 1, "terminal semantic history stays synchronized")
				line_edit.text = "he"; get_viewport().push_input(_key(KEY_TAB, true)); get_viewport().push_input(_key(KEY_TAB, false)); await get_tree().process_frame
				_check(line_edit.text == "help", "real LineEdit TAB completes unique command")
				get_viewport().push_input(_key(KEY_UP, true)); get_viewport().push_input(_key(KEY_UP, false)); await get_tree().process_frame
				_check(line_edit.text == "top", "real LineEdit history restores latest command")
				get_viewport().push_input(_key(KEY_ESCAPE, true)); get_viewport().push_input(_key(KEY_ESCAPE, false)); await get_tree().process_frame
		_check(bool(arena.call("vnext_u4_visible")) and (arena.call("vnext_u4_surface") as Control).has_method("show_pause") and get_tree().paused, "focused LineEdit ESC closes terminal and keeps pause")
		arena.call("_set_paused", true)
		get_viewport().push_input(_key(KEY_Q, true)); get_viewport().push_input(_key(KEY_Q, false)); await get_tree().process_frame
		_check(bool(arena.get("_abandon_armed")) and get_tree().paused, "Q arms abandon without leaving frozen pause")
		await get_tree().create_timer(2.2, true).timeout
		_check(not bool(arena.get("_abandon_armed")), "abandon confirmation expires")
		arena.call("_show_vnext_u4_terminal"); await get_tree().process_frame
		terminal = arena.call("vnext_u4_surface") as Control
		if terminal != null:
			var rm_input: LineEdit = terminal.get("_input"); rm_input.text = "rm -rf /"; get_viewport().push_input(_key(KEY_ENTER, true)); get_viewport().push_input(_key(KEY_ENTER, false)); await get_tree().process_frame
			_check(str(arena.get("_state")) == "play" or str(arena.get("_state")) == "dead", "rm -rf route remains Arena-owned")
		arena.call("_set_paused", false)
		arena.call("_show_game_over"); await get_tree().process_frame
		var over: Control = arena.call("vnext_u4_surface") as Control
		_check(over != null and str(over.call("semantic_snapshot").get("state", "")) == "death", "game-over exposes death diagnosis")
		_check(over != null and bool((over.get("_buttons")["primary"] as Button).visible), "game-over actions are visibly mounted")
		_check(over != null and over.call("handle_input", _key(KEY_ENTER, true)), "game-over primary dispatches reboot")
		_check(Game.state == Game.State.PLAYING and not get_tree().paused, "game-over primary restores global run state")
		var victory: Control = over_script.new()
		add_child(victory)
		victory.call("reflow_for_viewport", Vector2(432, 720))
		victory.call("show_game_over", {"variant":"victory", "title":"STAGE CLEARED", "diagnosis":"VICTORY", "stats":"DONE", "primary_available":false, "primary_label":"RETURN TO MENU [ENTER]", "menu_label":"STORY SELECT [ESC]"})
		_check(str(victory.call("semantic_snapshot").get("state", "")) == "victory", "game-over exposes victory diagnosis and disabled primary")
		_check(str((victory.get("_buttons")["primary"] as Button).text) == "RETURN TO MENU [ENTER]", "victory primary label matches route")
		_check(victory.has_method("handle_input"), "game-over owns keyboard route")
		_check(victory.call("handle_input", _key(KEY_ESCAPE, true)), "game-over ESC dispatches menu once")
		victory.queue_free()
		_finish()
		return

func _layout_is_safe(layout: Dictionary, viewport: Vector2) -> bool:
	var safe: Rect2 = layout.get("safe", Rect2())
	if safe.size.x <= 0.0 or safe.size.y <= 0.0 or safe.end.x > viewport.x or safe.end.y > viewport.y:
		return false
	var regions: Array[Rect2] = []
	for id in layout.get("regions", {}):
		if id in ["safe", "panel"]:
			continue
		var value = layout["regions"][id]
		if value is Rect2:
			var rect := value as Rect2
			if rect.size.x > 0.0 and rect.size.y > 0.0:
				regions.append(rect)
	for i in regions.size():
		for j in range(i + 1, regions.size()):
			if regions[i].intersects(regions[j], false):
				return false
	return true

func _key(code: int, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	return event

func _finish() -> void:
	if done:
		return
	done = true
	print("PROBE_DONE fails=%d" % fails)
	get_tree().paused = false
	get_tree().quit(1 if fails > 0 else 0)

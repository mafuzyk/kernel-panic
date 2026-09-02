extends Node

## H7 probe: dead HUD nodes must not be created, scroll affordances must match
## the input device, and long banners must begin fading immediately instead of
## waiting in an invisible dead zone.

var _fails := 0
var _finished := false

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PROBE_PASS ", message)
	else:
		_fails += 1
		print("PROBE_FAIL ", message)

func _ticks(count: int) -> void:
	for _i in count:
		await get_tree().process_frame

func _run() -> void:
	var hud_script: Script = load("res://src/ui/hud.gd")
	var panel_kit_script: Script = load("res://src/arena/panel_kit.gd")
	var arena_script: Script = load("res://src/arena/arena.gd")
	_check(hud_script != null, "HUD script loads for dead-widget audit")
	_check(panel_kit_script != null, "panel kit loads for dead-widget audit")
	_check(arena_script != null, "Arena script loads for dead-widget audit")
	if hud_script == null or panel_kit_script == null or arena_script == null:
		_finish()
		return

	var hud_source := str(hud_script.source_code)
	var panel_kit_source := str(panel_kit_script.source_code)
	var arena_source := str(arena_script.source_code)
	_check(not hud_source.contains("var _score_label"), "HUD no longer declares the unused score label")
	_check(not hud_source.contains("var _best_label"), "HUD no longer declares the unused best label")
	_check(not hud_source.contains("_build_label"), "HUD no longer creates or updates the hidden build label")
	_check(not hud_source.contains("func _on_patch_picked") and not hud_source.contains("Game.patch_picked.connect"), "HUD no longer retains a callback for the removed build label")
	_check(not panel_kit_source.contains("_over_stats"), "game-over kit no longer creates the hidden stats label")
	_check(not arena_source.contains("_over_stats"), "Arena no longer carries the dead game-over stats reference")

	var panel_scripts := [
		load("res://src/ui/bestiary_panel.gd"),
		load("res://src/ui/program_panel.gd"),
		load("res://src/ui/story_panel.gd"),
	]
	var panel_names := ["Bestiary", "Program", "Story"]
	for index in panel_scripts.size():
		var script: Script = panel_scripts[index]
		_check(script != null, "%s panel loads for scroll affordance audit" % panel_names[index])
		if script == null:
			continue
		var source := str(script.source_code)
		_check(source.contains("func scroll_hint_visible()"), "%s exposes a device-aware scroll hint contract" % panel_names[index])
		_check(source.contains("if scroll_hint_visible():"), "%s gates its scroll hint by the input device" % panel_names[index])

	var saved_force := OS.get_environment("KP_FORCE_TOUCH")
	OS.set_environment("KP_FORCE_TOUCH", "")
	for index in panel_scripts.size():
		var script: Script = panel_scripts[index]
		if script == null:
			continue
		var panel: Control = script.new()
		add_child(panel)
		_check(panel.call("scroll_hint_visible") == false, "%s hides swipe-only guidance on desktop" % panel_names[index])
		panel.queue_free()
	await _ticks(1)

	OS.set_environment("KP_FORCE_TOUCH", "1")
	for index in panel_scripts.size():
		var script: Script = panel_scripts[index]
		if script == null:
			continue
		var panel: Control = script.new()
		add_child(panel)
		_check(panel.call("scroll_hint_visible") == true, "%s shows scroll guidance for touch input" % panel_names[index])
		panel.queue_free()
	await _ticks(1)
	OS.set_environment("KP_FORCE_TOUCH", saved_force)

	var hud: Control = hud_script.new()
	hud.size = Vector2(1280, 720)
	add_child(hud)
	await _ticks(1)
	hud.set_process(false)
	hud.call("show_banner", "LONG EVENT", "LONG SUBTITLE", 3.0)
	var banner: Label = hud.get("_banner")
	_check(banner != null, "legacy HUD keeps the live banner label")
	if banner != null:
		hud.call("_process", 0.05)
		_check(float(banner.modulate.a) > 0.0, "long banner starts fading in immediately")
		hud.call("_process", 0.25)
		_check(float(banner.modulate.a) >= 0.95, "long banner reaches full opacity after its short intro")
		hud.call("_process", 2.7)
		_check(float(banner.modulate.a) == 0.0, "banner clears after its duration without a stale alpha")
	hud.queue_free()
	await _ticks(1)
	_finish()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

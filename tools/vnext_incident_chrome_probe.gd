extends Node

var fails := 0
var _finished := false

func _check(ok: bool, label: String) -> void:
	if ok:
		print("PROBE_PASS ", label)
	else:
		fails += 1
		print("PROBE_FAIL ", label)

func _ready() -> void:
	_watchdog.call_deferred()
	var chrome_script: Script = load("res://src/ui/vnext/ui_chrome.gd")
	_check(chrome_script != null and chrome_script.can_instantiate(), "incident chrome script loads")
	if chrome_script == null:
		_finish()
		return
	var chrome = chrome_script.new()
	_check(chrome.has_method("signature_snapshot"), "incident chrome exposes signature snapshot")
	_check(chrome.has_method("draw_shell"), "incident chrome exposes shell renderer")
	_check(chrome.has_method("draw_evidence_block"), "incident chrome exposes evidence block renderer")
	chrome = null
	await _probe_surface(load("res://src/ui/vnext/surfaces/boot_surface.gd"), {"program": "kernel", "best": 0})
	await _probe_surface(load("res://src/ui/vnext/surfaces/program_surface.gd"), {"selected": "kernel"})
	await _probe_surface(load("res://src/ui/vnext/surfaces/bestiary_surface.gd"), {"selected": "drone"})
	await _probe_surface(load("res://src/ui/vnext/surfaces/accessibility_surface.gd"), {})
	_finish()

func _probe_surface(script: Script, snapshot: Dictionary) -> void:
	_check(script != null and script.can_instantiate(), "incident console surface script loads")
	if script == null:
		return
	var surface = script.new()
	add_child(surface)
	for viewport in [Vector2(1366, 768), Vector2(432, 720)]:
		surface.size = viewport
		surface.configure(snapshot, script.context_for_viewport(viewport, viewport.x < 800.0, true, true, 1.15))
		var semantic: Dictionary = surface.semantic_snapshot()
		var composition: Dictionary = semantic.get("composition", {})
		var regions: Dictionary = surface.layout_snapshot().get("regions", {})
		_check(composition.get("chrome", "") == "incident_console", "incident chrome semantic on %s" % viewport)
		_check(composition.get("density", "") == "evidence_blocks", "evidence density semantic on %s" % viewport)
		_check(regions.has("signature_rail"), "signature rail region on %s" % viewport)
		_check(regions.has("evidence_band"), "evidence band region on %s" % viewport)
		var overflow: Array = surface.text_overflow_report()
		_check(overflow.all(func(item): return bool(item.get("fits", false))), "incident chrome text fits on %s" % viewport)
		for item in overflow:
			if not bool(item.get("fits", false)):
				print("PROBE_INFO incident_overflow ", viewport, " ", item)
	surface.queue_free()
	await get_tree().process_frame

func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("PROBE_DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _watchdog() -> void:
	await get_tree().create_timer(8.0, true, false, true).timeout
	if _finished:
		return
	print("PROBE_FAIL watchdog timeout")
	get_tree().quit(2)

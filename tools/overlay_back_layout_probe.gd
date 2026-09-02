extends Node

## N2 red/green probe: every legacy menu overlay must use the same lower-left
## return slot, across the real Menu scene and all four overlay routes.

var _fails := 0
var _finished := false
var _menu: Node
var _tree: SceneTree
var _viewport: Viewport
var _reference_footer_rect := Rect2()

func _ready() -> void:
	# The probe changes the current scene to the real Menu. Keep stable engine
	# references because this probe root is detached during that transition.
	_tree = get_tree()
	_viewport = get_viewport()
	print("PROBE_INFO boot tree=", _tree != null, " viewport=", _viewport != null)
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PROBE_PASS ", message)
	else:
		_fails += 1
		print("PROBE_FAIL ", message)

func _ticks(count: int) -> void:
	for _i in count:
		await _tree.process_frame

func _find_back(panel: Node) -> Button:
	if panel == null or not is_instance_valid(panel):
		return null
	for raw_button in panel.find_children("*", "Button", true, false):
		var button := raw_button as Button
		if button != null and button.text.begins_with("BACK"):
			return button
	return null

func _check_back(panel: Node, route: String) -> void:
	var button := _find_back(panel)
	_check(button != null, "%s exposes a real BACK control" % route)
	if button == null:
		return
	var rect := button.get_global_rect()
	var viewport := _viewport.get_visible_rect().size
	print("PROBE_INFO ", route, " viewport=", viewport, " rect=", rect)
	_check(rect.position.x <= viewport.x * 0.15, "%s BACK is on the lower-left side" % route)
	_check(rect.end.y >= viewport.y * 0.80, "%s BACK is anchored in the lower footer" % route)
	if route == "Program":
		_reference_footer_rect = rect
	else:
		_check(rect == _reference_footer_rect, "%s BACK shares the common footer slot" % route)

func _run() -> void:
	print("PROBE_INFO run start")
	Game.state = Game.State.MENU
	_tree.paused = false
	var menu_scene := load("res://src/ui/menu.tscn") as PackedScene
	_check(menu_scene != null, "real Menu scene loads for overlay layout")
	if menu_scene == null:
		_finish()
		return
	# Keep this boot probe alive while exercising the real Menu instance. A
	# probe that is itself the current scene would be detached by a scene swap
	# before it could inspect all four lazy-created overlays.
	_menu = menu_scene.instantiate()
	add_child(_menu)
	await _ticks(8)
	_check(_menu.is_node_ready(), "real Menu scene is ready for overlay layout")

	_menu.call("_open_program_selector")
	await _ticks(2)
	_check_back(_menu.get("_program_panel"), "Program")
	_menu.call("_close_program_selector")

	_menu.call("_open_story_selector")
	await _ticks(2)
	_check_back(_menu.get("_story_panel"), "Story")
	_menu.call("_close_story_selector")

	_menu.call("_open_bestiary")
	await _ticks(2)
	_check_back(_menu.get("_bestiary_panel"), "Bestiary")
	_menu.call("_close_bestiary")

	_menu.call("_open_achievements")
	await _ticks(2)
	_check_back(_menu.get("_ach_panel"), "Awards")
	_menu.call("_close_achievements")
	_finish()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("PROBE_DONE fails=%d" % _fails)
	_tree.quit(1 if _fails > 0 else 0)

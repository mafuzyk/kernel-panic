extends Node

## N3 red/green probe: the selected legacy Bestiary entry must be visible in
## its list when the panel opens and whenever selection changes.

var _fails := 0
var _finished := false
var _tree: SceneTree
var _menu: Node

func _ready() -> void:
	_tree = get_tree()
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

func _selected_card_is_visible(panel: BestiaryPanel, label: String) -> void:
	var viewport := panel.content_viewport_rect()
	var card: Rect2 = panel._card_rects.get(panel.detail_entry_id(), Rect2())
	print("PROBE_INFO ", label, " selected=", panel.detail_entry_id(), " scroll=", panel.scroll_y, " viewport=", viewport, " card=", card)
	_check(card.size != Vector2.ZERO, "%s selected card has a measured rect" % label)
	_check(viewport.encloses(card), "%s selected card is inside the list viewport" % label)

func _run() -> void:
	Game.state = Game.State.MENU
	_tree.paused = false
	var menu_scene := load("res://src/ui/menu.tscn") as PackedScene
	_check(menu_scene != null, "real Menu scene loads for Bestiary visibility")
	if menu_scene == null:
		_finish()
		return
	_menu = menu_scene.instantiate()
	add_child(_menu)
	await _ticks(8)
	_check(_menu.is_node_ready(), "real Menu scene is ready for Bestiary visibility")

	_menu.call("_open_bestiary")
	await _ticks(3)
	var panel := _menu.get("_bestiary_panel") as BestiaryPanel
	_check(panel != null and panel.visible, "legacy Bestiary opens through the real menu route")
	if panel != null:
		# Headless canvas expansion can expose a 1280px logical height. Force the
		# reference desktop viewport so the historical ROOT-out-of-view bug is
		# exercised instead of being hidden by the test window.
		panel.size = Vector2(1280.0, 720.0)
		_check(panel.has_method("ensure_selected_visible"), "Bestiary exposes selection visibility contract")
		if panel.has_method("ensure_selected_visible"):
			panel.ensure_selected_visible()
		await _ticks(2)
		_selected_card_is_visible(panel, "desktop open")
		_check(panel.detail_entry_id() == "root", "Bestiary preserves the intended ROOT default selection")
		_check(panel.scroll_y > 0.0, "Bestiary scrolls its default ROOT selection into view")
		_check(panel.select_entry("drone"), "Bestiary selects the first entry")
		await _ticks(2)
		_selected_card_is_visible(panel, "desktop first selection")
		_check(is_zero_approx(panel.scroll_y), "Bestiary returns to the top for the first entry")
		_check(panel.select_entry("god"), "Bestiary selects the final entry")
		await _ticks(2)
		_selected_card_is_visible(panel, "desktop final selection")
		_check(panel.scroll_y > 0.0, "Bestiary scrolls a late selection into view")

	var narrow := BestiaryPanel.new()
	narrow.size = Vector2(432.0, 720.0)
	add_child(narrow)
	await _ticks(3)
	_check(narrow.has_method("ensure_selected_visible"), "narrow Bestiary exposes selection visibility contract")
	if narrow.has_method("ensure_selected_visible"):
		narrow.ensure_selected_visible()
		await _ticks(2)
	_selected_card_is_visible(narrow, "narrow open")
	_check(narrow.scroll_y > 0.0, "narrow Bestiary scrolls its default ROOT selection into view")
	_check(narrow.select_entry("drone"), "narrow Bestiary selects the first entry")
	await _ticks(2)
	_selected_card_is_visible(narrow, "narrow first selection")
	_check(is_zero_approx(narrow.scroll_y), "narrow Bestiary returns to the top for the first entry")
	_check(narrow.select_entry("god"), "narrow Bestiary selects the final entry")
	await _ticks(2)
	_selected_card_is_visible(narrow, "narrow final selection")
	_check(narrow.scroll_y > 0.0, "narrow Bestiary scrolls a late selection into view")
	_finish()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("PROBE_DONE fails=%d" % _fails)
	_tree.quit(1 if _fails > 0 else 0)

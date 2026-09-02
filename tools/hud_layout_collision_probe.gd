extends Node

## H5 red/green probe: verify that auxiliary HUD copy, health pips, scrap
## telemetry and legacy state panels have actual geometry at narrow sizes.
## The probe also records the touch pause target so a later HUD change cannot
## silently put it over the temporary banner.

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

func _rect_inside(rect: Rect2, bounds: Rect2, epsilon := 0.5) -> bool:
	return rect.position.x >= bounds.position.x - epsilon and rect.position.y >= bounds.position.y - epsilon and rect.end.x <= bounds.end.x + epsilon and rect.end.y <= bounds.end.y + epsilon

func _run() -> void:
	var hud_script: Script = load("res://src/ui/hud.gd")
	var touch_script: Script = load("res://src/ui/touch_controls.gd")
	var state_surface_script: Script = load("res://src/ui/tactical_state_surface.gd")
	_check(hud_script != null, "HUD script loads for collision audit")
	_check(touch_script != null, "touch controls load for collision audit")
	_check(state_surface_script != null, "state surface loads for collision audit")
	if hud_script == null or touch_script == null or state_surface_script == null:
		_finish()
		return

	var viewports := [Vector2(320, 568), Vector2(432, 720), Vector2(600, 600), Vector2(800, 600), Vector2(1280, 720)]
	for viewport in viewports:
		var hud: Control = hud_script.new()
		hud.size = viewport
		add_child(hud)
		await _ticks(2)
		hud.call("show_achievement", "LONG ACHIEVEMENT // MOBILE COLLISION AUDIT")
		hud.call("_refresh_aux_anchors")
		var has_collision_layout := hud.has_method("collision_layout_snapshot")
		_check(has_collision_layout, "HUD exposes collision layout at %s" % viewport)
		var banner := Rect2()
		if has_collision_layout:
			var snapshot: Dictionary = hud.call("collision_layout_snapshot", viewport, 12)
			var frame: Rect2 = snapshot.get("safe", Rect2(Vector2.ZERO, viewport))
			var toast: Rect2 = snapshot.get("achievement", Rect2())
			banner = snapshot.get("banner", Rect2())
			_check(_rect_inside(toast, frame), "achievement toast stays inside safe width at %s" % viewport)
			_check(not toast.intersects(banner), "achievement toast clears temporary banner at %s" % viewport)
			var pips: Array = snapshot.get("hp_pips", [])
			var integrity: Rect2 = hud.call("layout_snapshot", viewport).get("integrity", Rect2())
			_check(pips.size() == 12, "all high-integrity pips remain represented at %s" % viewport)
			var pips_inside := true
			for pip in pips:
				pips_inside = pips_inside and _rect_inside(pip, integrity)
			_check(pips_inside, "high-integrity pips stay inside the integrity panel at %s" % viewport)
			var scrap: Dictionary = snapshot.get("scrap", {})
			var scrap_bar: Rect2 = scrap.get("bar", Rect2())
			var scrap_label: Rect2 = scrap.get("label", Rect2())
			_check(scrap.has("bar") and _rect_inside(scrap_bar, frame), "scrap bar stays inside viewport at %s" % viewport)
			_check(scrap.has("label") and _rect_inside(scrap_label, frame), "scrap label stays inside viewport at %s" % viewport)
		var touch: Control = touch_script.new()
		touch.size = viewport
		add_child(touch)
		var pause_rect: Rect2 = touch.call("_pause_btn")
		_check(not pause_rect.intersects(banner), "touch pause target clears banner at %s" % viewport)
		touch.queue_free()
		hud.queue_free()
		await _ticks(1)

	var state_has_stats := state_surface_script.has_method("game_over_stat_rects_for_viewport")
	_check(state_has_stats, "legacy game-over exposes measured stat layout")
	var state_has_actions := state_surface_script.has_method("action_rects_for_viewport")
	_check(state_has_actions, "legacy game-over exposes measured action layout")
	if state_has_stats and state_has_actions:
		for viewport in [Vector2(432, 720), Vector2(600, 600), Vector2(800, 600), Vector2(1280, 720)]:
			var panel: Rect2 = state_surface_script.panel_rect_for_viewport(viewport, "game_over")
			var stats: Array = state_surface_script.game_over_stat_rects_for_viewport(viewport)
			var actions: Array = state_surface_script.action_rects_for_viewport(viewport, "game_over", 2)
			var safe := Rect2(Vector2.ZERO, viewport)
			_check(stats.size() == 2 and _rect_inside(stats[0], panel) and _rect_inside(stats[1], panel), "game-over stat columns stay inside panel at %s" % viewport)
			_check(actions.size() == 2 and _rect_inside(actions[0], panel) and _rect_inside(actions[1], panel), "game-over actions stay inside panel at %s" % viewport)
			_check(not stats[0].intersects(stats[1]), "game-over stat blocks do not overlap at %s" % viewport)
			_check(not actions[0].intersects(actions[1]), "game-over action blocks do not overlap at %s" % viewport)
			_check(_rect_inside(actions[0], safe) and _rect_inside(actions[1], safe), "game-over actions stay inside viewport at %s" % viewport)

	Game.mode = "classic"
	Game.state = Game.State.PLAYING
	Game.patch_levels = {}
	Game.stats = {"kills": 0, "shots": 0, "hits": 0, "damage": 0, "time": 0.0, "wave": 1, "boss_kills": 0, "heals": {}}
	var arena_script: Script = load("res://src/arena/arena.gd")
	var arena: Node = arena_script.new()
	add_child(arena)
	await _ticks(3)
	get_window().size = Vector2i(432, 720)
	await _ticks(2)
	arena.call("_show_game_over")
	await _ticks(1)
	var panel: Rect2 = state_surface_script.panel_rect_for_viewport(Vector2(432, 720), "game_over")
	var core: Control = arena.get("_over_core_stats")
	var run: Control = arena.get("_over_run_stats")
	var primary: Control = arena.get("_over_primary")
	var menu: Control = arena.get("_over_menu")
	var live_viewport: Vector2 = arena.get_viewport_rect().size
	var live_panel: Rect2 = state_surface_script.panel_rect_for_viewport(live_viewport, "game_over")
	var over_panel: Control = arena.get("_over_panel")
	print("PROBE_INFO window=", get_window().size, " logical_viewport=", live_viewport, " panel=", live_panel, " over_size=", over_panel.size if over_panel != null else Vector2(), " core=", core.get_global_rect() if core != null else Rect2(), " run=", run.get_global_rect() if run != null else Rect2(), " primary=", primary.get_global_rect() if primary != null else Rect2(), " menu=", menu.get_global_rect() if menu != null else Rect2())
	_check(core != null and _rect_inside(core.get_global_rect(), live_panel), "live game-over core stats follow measured panel")
	_check(run != null and _rect_inside(run.get_global_rect(), live_panel), "live game-over run stats follow measured panel")
	_check(primary != null and _rect_inside(primary.get_global_rect(), live_panel), "live game-over primary action follows measured panel")
	_check(menu != null and _rect_inside(menu.get_global_rect(), live_panel), "live game-over menu action follows measured panel")
	arena.queue_free()
	await _ticks(1)

	_finish()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

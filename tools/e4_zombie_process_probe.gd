extends Node

## E4 real-path probe. It intentionally starts with the missing ZOMBIE_PROCESS
## contract so the first run is a meaningful red probe, not a source grep.

const Adapter = preload("res://src/ui/vnext/core/entity_presentation_adapter.gd")
const Renderer = preload("res://src/ui/vnext/core/entity_renderer.gd")
const Glyphs = preload("res://src/ui/glyph_lib.gd")

class ProbeCanvas extends Node2D:
	var snapshot: Dictionary
	func _draw() -> void:
		Renderer.draw(self, snapshot, Rect2(Vector2(8, 8), Vector2(96, 96)), 0.0, {"reduced_motion": true, "color_assist": true})

var _fails := 0
var _arena: Arena

func _ready() -> void:
	if get_parent() == get_tree().root and get_tree().current_scene == self:
		return
	_watchdog.call_deferred()
	_run.call_deferred()

func _watchdog() -> void:
	await get_tree().create_timer(30.0, true, false, true).timeout
	print("PROBE_FAIL watchdog timeout")
	get_tree().quit(1)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PROBE_PASS ", message)
	else:
		_fails += 1
		print("PROBE_FAIL ", message)

func _ticks(count: int) -> void:
	for _i in count:
		await get_tree().process_frame

func _until(condition: Callable, timeout_s: float, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await get_tree().process_frame
	_check(false, "timeout waiting for %s" % label)
	return false

func _has_instance(instance_id: int) -> bool:
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node) and node.get_instance_id() == instance_id:
			return true
	return false

func _spawn_real_enemy(kind: String) -> EnemyBase:
	var enemy := _arena.spawner.call("_make_enemy", kind) as EnemyBase
	if enemy == null:
		return null
	enemy.position = Vector2(420.0, 280.0)
	enemy.configure(1.0, false)
	_arena.enemy_container.add_child(enemy)
	return enemy

func _run() -> void:
	var catalog := load("res://src/data/content_catalog.gd")
	var spawner := Spawner.new()
	var zombie: Node = spawner.call("_make_enemy", "zombie_process")
	_check(zombie != null, "Spawner factory constructs ZOMBIE_PROCESS")
	_check(Glyphs.glyph_kinds().has("zombie_process"), "GlyphLib registers zombie_process")
	var entries: Array = catalog.BESTIARY_ENTRIES if catalog != null else []
	var zombie_entry := entries.filter(func(entry: Dictionary) -> bool: return str(entry.get("id", "")) == "zombie_process")
	_check(not zombie_entry.is_empty(), "content catalog includes the zombie bestiary entry")
	_check(StoryData.stage_at(0).get("waves", []).size() > 0 and str(StoryData.stage_at(0)["waves"][0][0]) == "zombie_process", "first story teach wave is one zombie")

	Game.start_story(0)
	await _until(func() -> bool: return get_tree().current_scene is Arena, 8.0, "story arena")
	_arena = get_tree().current_scene as Arena
	if _arena == null:
		return _finish()
	await _ticks(8)
	await _ticks(55)
	await _until(func() -> bool: return _arena.dismiss_story_intro(), 3.0, "story intro dismissal")
	await _until(func() -> bool: return _arena.enemy_container.get_child_count() > 0, 4.0, "zombie teach spawn")
	Game.state = Game.State.PLAYING
	_arena._state = "play"
	var live_zombies := _arena.enemy_list.filter(func(enemy: Node) -> bool: return is_instance_valid(enemy) and str(enemy.get("display_name")) == "ZOMBIE_PROCESS")
	print("PROBE_INFO story_state=", _arena._story_intro_state, " enemies=", _arena.enemy_list.size(), " children=", _arena.enemy_container.get_child_count())
	_check(live_zombies.size() == 1, "story teach wave spawns one real zombie")
	if live_zombies.is_empty():
		return _finish()
	var enemy: EnemyBase = live_zombies[0]
	_check(enemy.collision_layer & Balance.LAYER_ENEMY != 0, "zombie blocks player projectile layer")
	_check(not enemy.participates_in_enemy_pathing(), "zombie is excluded from enemy pathing")
	var before := {"hp": enemy.hp, "position": enemy.position, "life": enemy.remaining_life, "seed": Game.rng.seed}
	var snapshot := Adapter.from_enemy(enemy)
	_check(snapshot.get("kind", "") == "zombie_process" and snapshot.has("remaining_life"), "zombie snapshot exposes stable kind and remaining life")
	_check(Renderer.draw_extent_factor(snapshot) <= 2.0, "zombie renderer extent is bounded")
	var draw_key := Renderer.render_key(snapshot, 0.0, {"reduced_motion": true, "color_assist": true})
	_check(not draw_key.is_empty(), "zombie reduced-motion color-assist render key is represented")
	_check(before.hp == enemy.hp and before.position == enemy.position and before.life == enemy.remaining_life and before.seed == Game.rng.seed, "presentation read does not mutate zombie simulation")
	var canvas := ProbeCanvas.new()
	canvas.snapshot = snapshot.duplicate(true)
	enemy.set_physics_process(false)
	add_child(canvas)
	canvas.queue_redraw()
	await _ticks(2)
	_check(before.hp == enemy.hp and before.position == enemy.position and before.life == enemy.remaining_life and before.seed == Game.rng.seed, "repeated reduced-motion draw leaves zombie simulation unchanged")
	canvas.queue_free()
	enemy.set_physics_process(true)
	var zombie_id := enemy.get_instance_id()
	await _until(func() -> bool: return not _has_instance(zombie_id), 8.0, "zombie expiry")
	_check(_arena.enemy_list.is_empty(), "expired zombie leaves the shared alive list")
	await _until(func() -> bool: return _arena.spawner._intermission > 0.0, 4.0, "teach wave clear")
	_check(_arena.spawner._intermission > 0.0, "story teach wave clears after zombie expiry")
	var score_before := Game.score
	var kills_before := int(Game.stats["kills"])
	var combo_before := Game.mult
	var damaged_zombie := _spawn_real_enemy("zombie_process")
	_check(damaged_zombie != null, "real arena path spawns a damage-test zombie")
	if damaged_zombie != null:
		var damaged_id := damaged_zombie.get_instance_id()
		damaged_zombie.take_hit(1, damaged_zombie.position - Vector2.RIGHT)
		await _until(func() -> bool: return not _has_instance(damaged_id), 2.0, "zombie damage destruction")
		_check(Game.score == score_before and int(Game.stats["kills"]) == kills_before and Game.mult == combo_before, "zombie damage grants no score, kill, combo, or chain reward")
	var drone := _spawn_real_enemy("drone")
	_check(drone != null, "same real arena still spawns an ordinary drone")
	if drone != null:
		var drone_id := drone.get_instance_id()
		var drone_kills_before := int(Game.stats["kills"])
		drone.take_hit(999, drone.position - Vector2.RIGHT)
		await _until(func() -> bool: return not _has_instance(drone_id), 2.0, "ordinary drone death")
		_check(int(Game.stats["kills"]) == drone_kills_before + 1 and Game.score > score_before, "ordinary drone still uses the normal reward path")
	_finish()

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

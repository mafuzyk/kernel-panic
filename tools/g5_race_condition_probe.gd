extends Node

## G5 red/green probe for the first new enemy in the plan.
## It deliberately loads the candidate script dynamically so a missing
## implementation produces an honest red result instead of a parse failure.

const Adapter = preload("res://src/ui/vnext/core/entity_presentation_adapter.gd")
const Glyphs = preload("res://src/ui/glyph_lib.gd")

var _fails := 0

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PROBE_PASS ", message)
	else:
		_fails += 1
		print("PROBE_FAIL ", message)

func _run() -> void:
	var race_script: Script = load("res://src/enemies/race_condition.gd") as Script
	var spawner_source := FileAccess.get_file_as_string("res://src/arena/spawner.gd")
	var catalog_source := FileAccess.get_file_as_string("res://src/data/content_catalog.gd")
	var glyph_source := FileAccess.get_file_as_string("res://src/ui/glyph_lib.gd")
	_check(race_script != null, "Race Condition enemy script exists")
	_check(spawner_source.contains("race_condition"), "Spawner knows the Race Condition kind")
	_check(catalog_source.contains('"race_condition"'), "content catalog documents Race Condition")
	_check(glyph_source.contains('"race_condition"'), "GlyphLib registers Race Condition")
	if race_script == null:
		_finish()
		return

	var first := race_script.new() as EnemyBase
	var second := race_script.new() as EnemyBase
	_check(first != null and second != null, "factory creates two independent Race Condition enemies")
	if first == null or second == null:
		_finish()
		return
	add_child(first)
	add_child(second)
	first.position = Vector2(400.0, 320.0)
	second.position = Vector2(500.0, 320.0)
	first.call("connect_partner", second, "g5-pair")
	first.call("update_pair_state")
	second.call("update_pair_state")
	_check(bool(first.get("pair_linked")) and bool(second.get("pair_linked")), "nearby pair enters the linked state")
	_check(float(first.get("pair_distance")) <= float(first.get("link_radius")), "linked state exposes the readable distance rule")
	_check(first.get("partner") == second and second.get("partner") == first, "pair relationship is bidirectional")
	_check(first.get("hp") == second.get("hp"), "linked enemies still have separate health pools")

	second.position = Vector2(760.0, 320.0)
	first.call("update_pair_state")
	second.call("update_pair_state")
	_check(not bool(first.get("pair_linked")) and not bool(second.get("pair_linked")), "separating the pair removes the proximity buff")
	_check(float(first.get("pair_distance")) > float(first.get("link_radius")), "separation is measured from live positions")

	var hp_before := int(first.get("hp"))
	var second_hp_before := int(second.get("hp"))
	first.take_hit(1, first.position - Vector2.RIGHT)
	_check(int(first.get("hp")) == hp_before - 1, "first linked enemy takes its own damage")
	_check(int(second.get("hp")) == second_hp_before, "damage does not leak across the pair")

	second.position = Vector2(500.0, 320.0)
	first.call("update_pair_state")
	var snapshot: Dictionary = Adapter.from_enemy(first)
	var nested: Dictionary = snapshot.get("nested", {})
	_check(snapshot.get("kind", "") == "race_condition", "adapter publishes the stable Race Condition kind")
	_check(bool(nested.get("pair_linked", false)) and float(nested.get("pair_distance", 0.0)) <= float(nested.get("link_radius", 0.0)), "adapter preserves live pair state for non-color telegraphing")
	_check(Glyphs.glyph_extent("race_condition") > 1.0, "Race Condition silhouette has a declared envelope")

	var spawner := Spawner.new()
	add_child(spawner)
	spawner.wave = 4
	spawner.wave_event = ""
	spawner.call("_build_queue")
	var first_wave_queue: Array = spawner.get("_queue")
	_check(first_wave_queue.count("race_condition") == 2, "first encounter is an isolated linked pair")
	spawner.wave = 6
	spawner.call("_build_queue")
	var second_wave_queue: Array = spawner.get("_queue")
	_check(second_wave_queue.count("race_condition") == 2 and second_wave_queue.count("drone") >= 1, "second encounter combines the pair with familiar pressure")
	_check(spawner_source.contains("wave >= 8") and spawner_source.contains("race_condition"), "later waves retain the candidate for mixed compositions")

	var arena_stub := Node2D.new()
	var spawn_container := Node2D.new()
	add_child(arena_stub)
	arena_stub.add_child(spawn_container)
	spawner.set("container", spawn_container)
	spawner.set("_running", true)
	spawner.set("_spawn_generation", 1)
	spawner.wave = 4
	spawner.call("_spawn_group", ["race_condition", "race_condition"])
	await get_tree().create_timer(0.72).timeout
	var spawned_race: Array = spawn_container.get_children().filter(func(child: Node) -> bool: return child is RaceConditionEnemy)
	_check(spawned_race.size() == 2, "real spawn group materializes exactly one linked pair")
	if spawned_race.size() == 2:
		var spawned_first: EnemyBase = spawned_race[0]
		var spawned_second: EnemyBase = spawned_race[1]
		_check(spawned_first.get("partner") == spawned_second and spawned_second.get("partner") == spawned_first, "real spawn callback links both spawned instances")
		_check(spawned_first.position.distance_to(spawned_second.position) <= float(spawned_first.get("link_radius")), "real spawn positions begin inside the link radius")
	for child in spawn_container.get_children():
		if is_instance_valid(child):
			child.free()
	arena_stub.free()

	first.free()
	second.free()
	spawner.free()
	_finish()

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

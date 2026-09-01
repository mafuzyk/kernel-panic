extends Node

## M3 red/green probe for the chosen macOS act rule: layered visibility with a
## stable, non-color reveal telegraph and an explicit safe reveal delay.

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
	var telegraph_script: Script = load("res://src/enemies/layered_reveal_telegraph.gd")
	var renderer_script: Script = load("res://src/ui/vnext/core/entity_renderer.gd")
	var enemy_source := FileAccess.get_file_as_string("res://src/enemies/enemy_base.gd")
	var spawner_source := FileAccess.get_file_as_string("res://src/arena/spawner.gd")
	_check(telegraph_script != null, "layered reveal telegraph script loads")
	_check(renderer_script != null and renderer_script.state_signature({"visual_state": "background"}) == "background-ring", "shared renderer has a non-color background state marker")
	_check(enemy_source.contains("configure_layered_reveal") and enemy_source.contains("layered_reveal_remaining"), "EnemyBase exposes the layered reveal contract")
	_check(spawner_source.contains("act_rule") and spawner_source.contains("configure_layered_reveal"), "Spawner applies stage rules at the generic spawn boundary")
	var stage: Dictionary = Game.story_stage_def(11)
	_check(str(stage.get("act_rule", "")) == "layered_reveal", "the first macOS node declares the chosen mechanic")
	_check(float(stage.get("reveal_delay", 0.0)) >= 0.8, "the first reveal delay leaves a readable reaction window")
	var container := Node2D.new()
	var arena := Node2D.new()
	var spawner := Spawner.new()
	add_child(container)
	add_child(arena)
	add_child(spawner)
	_check(spawner.start_story(arena, container, stage), "real story spawner accepts the mechanic stage")
	var spawned: EnemyBase = null
	for _i in 160:
		await get_tree().process_frame
		for child in container.get_children():
			if child is EnemyBase:
				spawned = child
				break
		if spawned != null:
			break
	_check(spawned != null, "real story path spawns a layered enemy")
	if spawned != null:
		var telegraph := spawned.get_node_or_null("LayeredRevealTelegraph")
		_check(spawned.get_process_mode() == Node.PROCESS_MODE_DISABLED, "enemy simulation is paused during the reveal warning")
		_check(telegraph != null and bool(telegraph.get("active")), "reveal warning remains an active child while simulation is paused")
		_check(spawned.layered_reveal_active() and str(spawned.presentation_snapshot().get("visual_state", "")) == "background", "presentation state distinguishes background from idle")
		for _i in 120:
			await get_tree().process_frame
			if spawned == null or not is_instance_valid(spawned) or spawned.get_process_mode() != Node.PROCESS_MODE_DISABLED:
				break
		_check(spawned != null and is_instance_valid(spawned) and spawned.get_process_mode() != Node.PROCESS_MODE_DISABLED, "enemy becomes active after the telegraph window")
		if spawned != null and is_instance_valid(spawned):
			_check(not spawned.layered_reveal_active() and str(spawned.presentation_snapshot().get("visual_state", "")) != "background", "active enemy leaves the background presentation state")
	spawner.stop()
	container.queue_free()
	arena.queue_free()
	spawner.queue_free()
	_finish()

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

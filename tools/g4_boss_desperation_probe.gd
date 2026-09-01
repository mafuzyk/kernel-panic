extends Node

## G4 focused probe. It exercises the shared boss threshold through real damage
## entry points, including RootBoss variants, GodBoss and split fragments.

const EntityAdapter = preload("res://src/ui/vnext/core/entity_presentation_adapter.gd")

var _fails := 0

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PROBE_PASS ", message)
	else:
		_fails += 1
		print("PROBE_FAIL ", message)

func _arm_boss(boss: RootBoss, label: String) -> void:
	add_child(boss)
	boss.configure(1.0, false)
	# Cross the threshold without killing the fixture or entering the ROOT split
	# transition. This mirrors a normal bullet hit at the end of a boss fight.
	boss.hp = int(floor(float(boss.max_hp) * RootBoss.DESPERATION_THRESHOLD)) + 1
	if boss.kind == 1 and not boss.mini:
		boss.split_done = true
	var hp_before := boss.hp
	boss.take_hit(1, Vector2(-100.0, 0.0))
	_check(boss.desperation_active, label + " enters desperation below eight percent")
	_check(boss.desperation_trigger_count == 1, label + " enters desperation exactly once")
	_check(boss.desperation_transition_t > Balance.DASH_IFRAMES, label + " leaves a dash-reactable transition window")
	_check(boss.desperation_cadence_multiplier() < 1.0, label + " accelerates cadence instead of damage")
	_check(boss.hp == hp_before - 1, label + " preserves the normal damage amount")
	var snapshot := boss.presentation_snapshot()
	_check(bool(snapshot.get("desperation_active", false)), label + " publishes a non-color desperation state")
	_check(float(snapshot.get("desperation_transition_t", 0.0)) > 0.0, label + " publishes the transition timer")
	var adapted := EntityAdapter.from_enemy(boss)
	var nested: Dictionary = adapted.get("nested", {})
	_check(bool(nested.get("desperation_active", false)), label + " adapter preserves desperation state")
	var act_before := boss.act
	boss._try_attacks()
	_check(boss.act == act_before, label + " transition window blocks an immediate attack")
	boss._step_desperation(10.0)
	boss._step_desperation(0.0)
	_check(boss.desperation_trigger_count == 1, label + " does not re-arm after the window")
	boss.free()

func _run() -> void:
	var root_source := FileAccess.get_file_as_string("res://src/enemies/root_boss.gd")
	var god_source := FileAccess.get_file_as_string("res://src/enemies/god_boss.gd")
	_check(root_source.contains("_draw_desperation_telegraph") and god_source.contains("_draw_desperation_telegraph"), "all boss draw paths mount the shared non-color telegraph")
	_check(RootBoss.DESPERATION_THRESHOLD == 0.08, "desperation threshold is exactly eight percent")
	_check(RootBoss.DESPERATION_TRANSITION_DURATION > Balance.DASH_IFRAMES, "transition duration exceeds the player dash invulnerability window")
	_check(RootBoss.DESPERATION_CADENCE_MULTIPLIER < 1.0, "desperation balance is cadence-only")
	for index in range(1, 5):
		var root := RootBoss.new()
		root.boss_index = index
		_arm_boss(root, "ROOT variant %d" % index)
	var fragment := RootBoss.new()
	add_child(fragment)
	fragment.mini = true
	fragment.max_hp = 100
	fragment.hp = 9
	fragment.configure(1.0, false)
	fragment.max_hp = 100
	fragment.hp = 9
	fragment.take_hit(1, Vector2(-100.0, 0.0))
	_check(fragment.desperation_active, "split fragment enters shared desperation")
	_check(fragment.desperation_trigger_count == 1, "split fragment desperation is one-shot")
	fragment.free()
	var god := GodBoss.new()
	add_child(god)
	god.configure(1.0, false)
	god.hp = 15
	god.take_hit(2, Vector2(-100.0, 0.0))
	_check(god.desperation_active, "GOD enters shared desperation below eight percent")
	_check(god.desperation_trigger_count == 1, "GOD desperation is one-shot")
	_check(god.desperation_transition_t > Balance.DASH_IFRAMES, "GOD leaves a dash-reactable transition window")
	_check(god.hp == 13, "GOD keeps normal damage in desperation")
	_check(god.presentation_snapshot().has("desperation_active"), "GOD exposes shared desperation presentation state")
	god.free()
	_check(RootBoss.DESPERATION_TRANSITION_DURATION >= Balance.DASH_IFRAMES * 3.0, "standard dash has a meaningful reaction margin")
	_finish()

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

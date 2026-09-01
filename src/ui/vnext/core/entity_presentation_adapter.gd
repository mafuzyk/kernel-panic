class_name VNextEntityPresentationAdapter
extends RefCounted

const Descriptor = preload("res://src/ui/vnext/core/entity_descriptor.gd")

static func from_player_fixture(player: Dictionary) -> Dictionary:
	var program: Dictionary = player.get("prog", {}) if player.get("prog", {}) is Dictionary else {}
	var kind := str(program.get("kind", "kernel"))
	var hp := float(player.get("hp", 1))
	var max_hp := maxf(float(player.get("max_hp", 1)), 1.0)
	var state := "elite" if bool(player.get("overclock_active", false)) else "idle"
	return Descriptor.normalize({
		"kind": kind,
		"visual_state": state,
		"facing": player.get("aim", Vector2.RIGHT),
		"hp_fraction": hp / max_hp,
		"elite": false,
		"loot_count": 0,
		"feedback_count": int(player.get("dash_available", 0)),
	})

static func from_player(player: Object) -> Dictionary:
	if player == null:
		return Descriptor.normalize({})
	var program: Dictionary = player.get("prog") if player.get("prog") is Dictionary else {}
	return from_player_fixture({
		"prog": program,
		"aim": player.get("aim"),
		"hp": player.get("hp"),
		"max_hp": player.get("max_hp"),
		"overclock_active": player.get("overclock_active"),
		"dash_available": player.get("dash_available"),
	})

static func from_enemy_fixture(enemy: Dictionary) -> Dictionary:
	var kind := str(enemy.get("display_name", "DRONE")).to_lower()
	if kind == "oom_killer":
		kind = "oom"
	var hp := float(enemy.get("hp", 1))
	var max_hp := maxf(float(enemy.get("max_hp", 1)), 1.0)
	var fallback_state := "hit" if float(enemy.get("hit_flash", 0.0)) > 0.0 else ("elite" if bool(enemy.get("elite", false)) else "idle")
	var state := str(enemy.get("visual_state", fallback_state))
	var facing: Variant = enemy.get("facing", Vector2.RIGHT.rotated(float(enemy.get("global_rotation", 0.0))))
	if not facing is Vector2:
		facing = Vector2.RIGHT.rotated(float(enemy.get("global_rotation", 0.0)))
	return Descriptor.normalize({
		"kind": kind,
		"visual_state": state,
		"facing": facing,
		"hp_fraction": hp / max_hp,
		"elite": bool(enemy.get("elite", false)),
		"era_accent": enemy.get("era_accent", Color(0, 0, 0, 0)),
		"loot_count": enemy.get("mote_count", 0),
		"feedback_count": 0,
	})

static func from_enemy(enemy: Object) -> Dictionary:
	if enemy == null:
		return Descriptor.normalize({})
	if enemy.has_method("presentation_snapshot"):
		return from_enemy_fixture(enemy.call("presentation_snapshot"))
	return from_enemy_fixture({
		"display_name": enemy.get("display_name"),
		"hp": enemy.get("hp"),
		"max_hp": enemy.get("max_hp"),
		"global_rotation": enemy.get("global_rotation"),
		"elite": enemy.get("elite"),
		"mote_count": enemy.get("mote_count"),
		"era_accent": enemy.get("era_accent"),
		"hit_flash": enemy.get("hit_flash"),
	})

class_name VNextEntityPresentationAdapter
extends RefCounted

const Descriptor = preload("res://src/ui/vnext/core/entity_descriptor.gd")

const PROGRAM_KINDS := {"kernel": "kernel", "daemon": "daemon", "rootlet": "rootlet"}

static func _program_kind(program_id: String) -> String:
	return str(PROGRAM_KINDS.get(program_id, "kernel"))

static func from_player_fixture(player: Dictionary) -> Dictionary:
	var program: Dictionary = player.get("prog", {}) if player.get("prog", {}) is Dictionary else {}
	var program_id := str(player.get("program_id", program.get("id", "kernel")))
	var kind := _program_kind(program_id)
	var hp := float(player.get("hp", 1))
	var max_hp := maxf(float(player.get("max_hp", 1)), 1.0)
	var state := "hit" if bool(player.get("dead", false)) else ("elite" if bool(player.get("overclock_active", false)) else "idle")
	return Descriptor.normalize({
		"kind": kind,
		"visual_state": state,
		"facing": player.get("facing", player.get("aim", Vector2.RIGHT)),
		"hp_fraction": hp / max_hp,
		"elite": false,
		"loot_count": 0,
		"feedback_count": int(player.get("dash_available", 0)),
		"nested": {
			"program_id": program_id,
			"overclock_ready": bool(player.get("overclock_ready", player.get("oc_ready", false))),
			"overclock_active": bool(player.get("overclock_active", false)),
			"shield_mode": bool(player.get("shield_mode", program.get("shield_mode", false))),
			"shield_meter": float(player.get("shield_meter", 0.0)),
			"shield_ready": bool(player.get("shield_ready", false)),
			"dash_available": int(player.get("dash_available", 0)),
			"dash_max": int(player.get("dash_max", 1)),
			"dash_active": bool(player.get("dash_active", false)),
			"invulnerable": bool(player.get("invulnerable", false)),
		},
	})

static func from_player(player: Object) -> Dictionary:
	if player == null:
		return Descriptor.normalize({})
	if player.has_method("presentation_snapshot"):
		var snapshot: Dictionary = player.call("presentation_snapshot")
		return from_player_fixture(snapshot)
	var program: Dictionary = player.get("prog") if player.get("prog") is Dictionary else {}
	return from_player_fixture({
		"prog": program,
		"program_id": Game.program,
		"aim": player.get("aim"),
		"hp": player.get("hp"),
		"max_hp": player.get("max_hp"),
		"overclock_active": player.get("overclock_active"),
		"oc_ready": player.get("oc_ready"),
		"shield_mode": program.get("shield_mode", false),
		"shield_meter": player.get("shield_meter"),
		"shield_ready": player.get("shield_ready"),
		"dash_available": player.get("dash_available"),
		"dash_max": player.get("dash_charges"),
		"dash_active": float(player.get("dash_t")) > 0.0,
		"dead": player.get("dead"),
		"invulnerable": float(player.get("invuln")) > 0.0,
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
		"remaining_life": float(enemy.get("remaining_life", 0.0)),
		"lifetime": float(enemy.get("lifetime", 0.0)),
		"timer_marker": str(enemy.get("timer_marker", "")),
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

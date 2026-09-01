class_name VNextEntityDescriptor
extends RefCounted

const Glyphs = preload("res://src/ui/glyph_lib.gd")

const DEFAULT_KIND := "drone"
const DEFAULT_STATE := "idle"
const VALID_STATES := ["idle", "attack", "hit", "elite", "death"]

static func normalize(snapshot: Dictionary) -> Dictionary:
	var source := snapshot.duplicate(true)
	var kind := str(source.get("kind", DEFAULT_KIND)).to_lower()
	if kind not in Glyphs.glyph_kinds():
		kind = DEFAULT_KIND
	var state := str(source.get("visual_state", DEFAULT_STATE)).to_lower()
	if state not in VALID_STATES:
		state = DEFAULT_STATE
	var facing: Variant = source.get("facing", Vector2.RIGHT)
	if not facing is Vector2 or facing.length_squared() <= 0.0001:
		facing = Vector2.RIGHT
	else:
		facing = facing.normalized()
	var hp_fraction := _number(source.get("hp_fraction", 1.0), 1.0)
	var visible_label := str(source.get("visible_label", ""))
	if _looks_like_localization_key(visible_label):
		visible_label = ""
	return {
		"kind": kind,
		"visual_state": state,
		"facing": facing,
		"hp_fraction": clampf(hp_fraction, 0.0, 1.0),
		"elite": bool(source.get("elite", false)),
		"era_accent": source.get("era_accent", Color(0, 0, 0, 0)) if source.get("era_accent", Color(0, 0, 0, 0)) is Color else Color(0, 0, 0, 0),
		"loot_count": maxi(int(source.get("loot_count", 0)), 0),
		"feedback_count": maxi(int(source.get("feedback_count", 0)), 0),
		"visible_label": visible_label,
		"nested": source.get("nested", {}).duplicate(true) if source.get("nested", {}) is Dictionary else {},
	}

static func _number(value: Variant, fallback: float) -> float:
	if value is int or value is float:
		return float(value)
	return fallback

static func _looks_like_localization_key(value: String) -> bool:
	var lowered := value.to_lower()
	return lowered.contains(".") or lowered.contains("_") or lowered.contains("-") or lowered.begins_with("loc")

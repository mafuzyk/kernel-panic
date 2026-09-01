class_name VNextEntityQuality
extends RefCounted

## Quality is a presentation policy, never a gameplay difficulty setting.
## Identity, orientation and state markers are structural and stay enabled in
## every profile. Finish-only accents can be removed for mobile or kept static
## when reduced motion is requested.

const DESKTOP_TIER := "desktop"
const MOBILE_TIER := "mobile"

static func profile(tier: String = DESKTOP_TIER, reduced_motion := false, high_contrast := false, color_assist := false, grayscale := false) -> Dictionary:
	var normalized_tier := MOBILE_TIER if tier.strip_edges().to_lower() == MOBILE_TIER else DESKTOP_TIER
	var reduced := _bool(reduced_motion, false)
	var contrast := _bool(high_contrast, false)
	var assist := _bool(color_assist, false)
	var mono := _bool(grayscale, false)
	return {
		"tier": normalized_tier,
		"finish": normalized_tier == DESKTOP_TIER,
		"motion": not reduced,
		"reduced_motion": reduced,
		"high_contrast": contrast,
		"color_assist": assist,
		"grayscale": mono,
		"finish_segments": 24 if normalized_tier == DESKTOP_TIER else 0,
	}

static func normalize(quality: Dictionary = {}) -> Dictionary:
	return profile(
		str(quality.get("tier", DESKTOP_TIER)),
		_bool(quality.get("reduced_motion", false), false),
		_bool(quality.get("high_contrast", false), false),
		_bool(quality.get("color_assist", false), false),
		_bool(quality.get("grayscale", false), false),
	)

static func _bool(value: Variant, fallback: bool) -> bool:
	if value is bool:
		return value
	if value is int or value is float:
		return not is_zero_approx(float(value))
	if value is String:
		var normalized: String = value.strip_edges().to_lower()
		if normalized in ["true", "1", "yes", "on"]:
			return true
		if normalized in ["false", "0", "no", "off", ""]:
			return false
	return fallback

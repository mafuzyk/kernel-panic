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
	return {
		"tier": normalized_tier,
		"finish": normalized_tier == DESKTOP_TIER,
		"motion": not reduced_motion,
		"reduced_motion": reduced_motion,
		"high_contrast": high_contrast,
		"color_assist": color_assist,
		"grayscale": grayscale,
		"finish_segments": 24 if normalized_tier == DESKTOP_TIER else 0,
	}

static func normalize(quality: Dictionary = {}) -> Dictionary:
	return profile(
		str(quality.get("tier", DESKTOP_TIER)),
		bool(quality.get("reduced_motion", false)),
		bool(quality.get("high_contrast", false)),
		bool(quality.get("color_assist", false)),
		bool(quality.get("grayscale", false)),
	)

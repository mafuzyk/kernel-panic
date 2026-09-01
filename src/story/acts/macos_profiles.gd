class_name MacOSProfiles
extends RefCounted

## Era profiles are fiction-facing visual data. They do not detect the host OS.

const PROFILES := {
	"classic": {
		"base_col": Color("101719"), "grid_col": Color("55777b"), "glow_col": Color("234f55"), "accent": Color("b4e6df"),
		"grid_style": "mac_classic", "crt": {"curvature": 0.015, "noise": 0.02, "scanline": 0.08, "aberration": 0.08}, "layered": false,
	},
	"aqua": {
		"base_col": Color("071b22"), "grid_col": Color("38bfc2"), "glow_col": Color("126d78"), "accent": Color("75f0e0"),
		"grid_style": "mac_aqua", "crt": {"curvature": 0.01, "noise": 0.015, "scanline": 0.05, "aberration": 0.04}, "layered": true,
	},
	"darwin": {
		"base_col": Color("0d111b"), "grid_col": Color("5461a0"), "glow_col": Color("242e68"), "accent": Color("9ba8ff"),
		"grid_style": "mac_darwin", "crt": {"curvature": 0.02, "noise": 0.025, "scanline": 0.10, "aberration": 0.10}, "layered": true,
	},
	"modern": {
		"base_col": Color("090d16"), "grid_col": Color("5e85b4"), "glow_col": Color("1c3b61"), "accent": Color("8fc8ff"),
		"grid_style": "mac_modern", "crt": {"curvature": 0.008, "noise": 0.01, "scanline": 0.035, "aberration": 0.02}, "layered": true,
	},
}

static func theme(profile_id: String) -> Dictionary:
	return PROFILES.get(profile_id, PROFILES["classic"]).duplicate(true)

static func ids() -> Array[String]:
	return ["classic", "aqua", "darwin", "modern"]

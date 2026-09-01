class_name VNextUITokens
extends RefCounted

const BASE_VIEWPORT := Vector2(1280.0, 720.0)
const SAFE_MARGIN := 24.0

const COLORS := {
	"background": Color("#050914"),
	"structure": Color("#42e8ff"),
	"danger": Color("#ff4e72"),
	"warning": Color("#f4b942"),
	"ready": Color("#9dff72"),
	"focus": Color("#e9f6ff"),
	"muted": Color("#71859d"),
}

const STATE_LABELS := {
	"idle": "STANDBY",
	"ready": "READY",
	"locked": "LOCKED",
	"danger": "ALERT",
}

const STATE_ROLES := {
	"idle": "structure",
	"ready": "ready",
	"locked": "muted",
	"danger": "danger",
}

const STATE_PATTERNS := {
	"idle": "steady",
	"ready": "pulse",
	"locked": "hatch",
	"danger": "break",
}

static func role_color(role: String) -> Color:
	return COLORS.get(role, COLORS["structure"])

static func state_label(state: String) -> String:
	return str(STATE_LABELS.get(state, STATE_LABELS["idle"]))

static func state_visual(state: String) -> Dictionary:
	return {
		"label": state_label(state),
		"role": str(STATE_ROLES.get(state, STATE_ROLES["idle"])),
		"pattern": str(STATE_PATTERNS.get(state, STATE_PATTERNS["idle"])),
	}

static func viewport_scale(viewport: Vector2) -> float:
	if viewport.x <= 0.0 or viewport.y <= 0.0:
		return 1.0
	return clampf(minf(viewport.x / BASE_VIEWPORT.x, viewport.y / BASE_VIEWPORT.y), 0.55, 1.25)

static func safe_rect(viewport: Vector2, margin: float = SAFE_MARGIN) -> Rect2:
	var inset := maxf(margin, 0.0)
	var max_inset := minf(viewport.x, viewport.y) * 0.5
	inset = minf(inset, max_inset)
	return Rect2(
		Vector2(inset, inset),
		Vector2(maxf(viewport.x - inset * 2.0, 0.0), maxf(viewport.y - inset * 2.0, 0.0))
	)

static func frame_points(rect: Rect2, cut: float = 18.0) -> PackedVector2Array:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return PackedVector2Array()
	var c := clampf(cut, 0.0, minf(rect.size.x, rect.size.y) * 0.5)
	return PackedVector2Array([
		rect.position + Vector2(c, 0.0),
		rect.position + Vector2(rect.size.x - c, 0.0),
		rect.position + Vector2(rect.size.x, c),
		rect.position + Vector2(rect.size.x, rect.size.y - c),
		rect.position + Vector2(rect.size.x - c, rect.size.y),
		rect.position + Vector2(c, rect.size.y),
		rect.position + Vector2(0.0, rect.size.y - c),
		rect.position + Vector2(0.0, c),
	])

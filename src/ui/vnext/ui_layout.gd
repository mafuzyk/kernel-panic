class_name VNextUILayout
extends RefCounted

static func boot(viewport: Vector2, context: RefCounted) -> Dictionary:
	var safe: Rect2 = context.get("safe_rect")
	var pad: float = 24.0 if context.get("density") == "wide" else 16.0
	var action_w: float = minf(420.0, safe.size.x - pad * 2.0)
	var action_x: float = safe.position.x + (safe.size.x - action_w) * 0.5
	var title: Rect2 = Rect2(safe.position + Vector2(pad, 72), Vector2(minf(600.0, safe.size.x - pad * 2.0), 76))
	var boot_y: float = safe.position.y + safe.size.y * (0.56 if context.get("density") == "wide" else 0.48)
	var boot: Rect2 = Rect2(action_x, boot_y, action_w, 64.0)
	var back: Rect2 = Rect2(safe.position + Vector2(pad, safe.size.y - pad - 48), Vector2(150, 48))
	var telemetry: Rect2 = Rect2(safe.position + Vector2(pad, 148), Vector2(minf(420.0, safe.size.x - pad * 2.0), 64))
	var illustration_side: float = minf(220.0, maxf(120.0, safe.size.x * 0.28))
	var illustration: Rect2 = Rect2(safe.end - Vector2(illustration_side + pad, illustration_side + pad + 40), Vector2(illustration_side, illustration_side))
	if context.get("density") == "narrow":
		title = Rect2(safe.position + Vector2(pad, 56), Vector2(safe.size.x - pad * 2.0, 92))
		telemetry = Rect2(safe.position + Vector2(pad, 166), Vector2(safe.size.x - pad * 2.0, 56))
		illustration = Rect2(safe.position + Vector2(pad, 238), Vector2(safe.size.x - pad * 2.0, 140))
		boot = Rect2(action_x, 400, action_w, 64)
	return {"shell": safe, "title": title, "telemetry": telemetry, "illustration": illustration, "boot": boot, "back": back}

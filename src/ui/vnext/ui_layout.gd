class_name VNextUILayout
extends RefCounted

static func boot(viewport: Vector2, context: RefCounted) -> Dictionary:
	var safe: Rect2 = context.get("safe_rect")
	var pad: float = 24.0 if context.get("density") == "wide" else 16.0
	var action_w: float = minf(safe.size.x, maxf(44.0, minf(420.0, safe.size.x - pad * 2.0)))
	var action_x: float = safe.position.x + (safe.size.x - action_w) * 0.5
	var title: Rect2 = Rect2(safe.position + Vector2(pad, 72), Vector2(maxf(0.0, minf(600.0, safe.size.x - pad * 2.0)), 76))
	var boot_y: float = safe.position.y + safe.size.y * (0.56 if context.get("density") == "wide" else 0.48)
	var boot: Rect2 = Rect2(action_x, boot_y, action_w, 64.0)
	var secondary_w: float = maxf(44.0, (action_w - 12.0) * 0.5)
	var program := Rect2(action_x, boot_y + 76.0, secondary_w, 48.0)
	var story := Rect2(action_x + secondary_w + 12.0, boot_y + 76.0, secondary_w, 48.0)
	var back: Rect2 = Rect2(safe.position + Vector2(pad, safe.size.y - pad - 48), Vector2(minf(150.0, safe.size.x), 48))
	var telemetry: Rect2 = Rect2(safe.position + Vector2(pad, 148), Vector2(maxf(0.0, minf(420.0, safe.size.x - pad * 2.0)), 64))
	var illustration_side: float = minf(220.0, maxf(120.0, safe.size.x * 0.28))
	var illustration: Rect2 = Rect2(safe.end - Vector2(illustration_side + pad, illustration_side + pad + 40), Vector2(illustration_side, illustration_side))
	if context.get("density") == "narrow":
		title = Rect2(safe.position + Vector2(pad, 56), Vector2(maxf(0.0, safe.size.x - pad * 2.0), 64))
		telemetry = Rect2(safe.position + Vector2(pad, 128), Vector2(maxf(0.0, safe.size.x - pad * 2.0), 52))
		var boot_height := minf(64.0, maxf(56.0, safe.size.y * 0.12))
		boot = Rect2(action_x, back.position.y - 12.0 - boot_height, action_w, boot_height)
		program = Rect2(action_x, boot.position.y - 60.0, secondary_w, 48.0)
		story = Rect2(action_x + secondary_w + 12.0, boot.position.y - 60.0, secondary_w, 48.0)
		var illustration_top := telemetry.end.y + 12.0
		var illustration_bottom := boot.position.y - 12.0
		var illustration_height := maxf(0.0, minf(180.0, illustration_bottom - illustration_top))
		illustration = Rect2(safe.position + Vector2(pad, illustration_top - safe.position.y), Vector2(maxf(0.0, safe.size.x - pad * 2.0), illustration_height))
	return {"shell": safe, "title": title, "telemetry": telemetry, "illustration": illustration, "boot": boot, "program": program, "story": story, "back": back, "boot_label": ">> BOOT PROCESS  [ENTER]" if context.get("density") == "narrow" else ">> BOOT / RUN PROCESS  [ENTER]"}

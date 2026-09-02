class_name VNextUILayout
extends RefCounted

static func boot(viewport: Vector2, context: RefCounted) -> Dictionary:
	var safe: Rect2 = context.get("safe_rect")
	var density := str(context.get("density"))
	var pad: float = 24.0 if density == "wide" else 16.0
	var shell_meta := Rect2(safe.position + Vector2(pad, 16.0), Vector2(maxf(0.0, safe.size.x - pad * 2.0), 30.0))
	var footer := Rect2(safe.position + Vector2(pad, safe.size.y - 66.0), Vector2(maxf(0.0, safe.size.x - pad * 2.0), 26.0))
	var identity: Rect2
	var telemetry: Rect2
	var navigation: Rect2
	var illustration: Rect2
	var title: Rect2
	var boot: Rect2
	var program: Rect2
	var story: Rect2
	var back: Rect2 = Rect2(footer.position + Vector2(0.0, footer.size.y + 8.0), Vector2(minf(150.0, footer.size.x), footer.size.y))
	var settings_action := Rect2(Vector2.ZERO, Vector2.ZERO)
	var bestiary_action := Rect2(Vector2.ZERO, Vector2.ZERO)
	var signature_rail := Rect2(safe.position + Vector2(8.0, 52.0), Vector2(8.0, maxf(0.0, safe.size.y - 82.0)))
	if density == "wide":
		var column_gap := 44.0
		var left_width := minf(520.0, safe.size.x * 0.43)
		var right_width := minf(500.0, safe.size.x * 0.42)
		identity = Rect2(safe.position + Vector2(pad, 94.0), Vector2(left_width, 236.0))
		telemetry = Rect2(identity.position + Vector2(0.0, identity.size.y + 24.0), Vector2(left_width, 150.0))
		navigation = Rect2(Vector2(safe.end.x - pad - right_width, identity.position.y + 18.0), Vector2(right_width, 414.0))
		illustration = Rect2(Vector2(identity.end.x + column_gap, telemetry.position.y - 12.0), Vector2(minf(220.0, right_width * 0.48), 190.0))
		title = Rect2(identity.position + Vector2(28.0, 38.0), Vector2(identity.size.x - 56.0, 112.0))
		boot = Rect2(navigation.position + Vector2(20.0, 44.0), Vector2(navigation.size.x - 40.0, 72.0))
		program = Rect2(navigation.position + Vector2(20.0, 144.0), Vector2(navigation.size.x - 40.0, 54.0))
		story = Rect2(navigation.position + Vector2(20.0, 216.0), Vector2(navigation.size.x - 40.0, 54.0))
		settings_action = Rect2(Vector2(safe.end.x - pad - 180.0, back.position.y), Vector2(180.0, footer.size.y))
		bestiary_action = Rect2(Vector2(settings_action.position.x - 164.0, back.position.y), Vector2(150.0, footer.size.y))
	elif density == "compact":
		identity = Rect2(safe.position + Vector2(pad, 66.0), Vector2(safe.size.x - pad * 2.0, 184.0))
		telemetry = Rect2(identity.position + Vector2(0.0, identity.size.y + 16.0), Vector2(safe.size.x * 0.52, 92.0))
		navigation = Rect2(Vector2(safe.position.x + safe.size.x * 0.48, telemetry.position.y - 8.0), Vector2(safe.end.x - pad - (safe.position.x + safe.size.x * 0.48), 270.0))
		illustration = Rect2(Vector2(safe.position.x + 18.0, telemetry.position.y + 14.0), Vector2(minf(190.0, safe.size.x * 0.32), 150.0))
		title = Rect2(identity.position + Vector2(24.0, 28.0), Vector2(identity.size.x * 0.56, 112.0))
		boot = Rect2(navigation.position + Vector2(16.0, 32.0), Vector2(navigation.size.x - 32.0, 64.0))
		program = Rect2(navigation.position + Vector2(16.0, 116.0), Vector2(navigation.size.x - 32.0, 50.0))
		story = Rect2(navigation.position + Vector2(16.0, 182.0), Vector2(navigation.size.x - 32.0, 50.0))
		settings_action = Rect2(Vector2(safe.end.x - pad - 160.0, back.position.y), Vector2(160.0, footer.size.y))
		bestiary_action = Rect2(Vector2(settings_action.position.x - 150.0, back.position.y), Vector2(136.0, footer.size.y))
	else:
		var content_width := maxf(0.0, safe.size.x - pad * 2.0)
		identity = Rect2(safe.position + Vector2(pad, 62.0), Vector2(content_width, 138.0))
		title = Rect2(identity.position + Vector2(18.0, 20.0), Vector2(content_width - 36.0, 78.0))
		telemetry = Rect2(safe.position + Vector2(pad, 210.0), Vector2(content_width, 58.0))
		illustration = Rect2(safe.position + Vector2(pad + content_width * 0.2, 282.0), Vector2(content_width * 0.6, 112.0))
		navigation = Rect2(safe.position + Vector2(pad, 410.0), Vector2(content_width, 214.0))
		boot = Rect2(navigation.position + Vector2(12.0, 28.0), Vector2(navigation.size.x - 24.0, 54.0))
		program = Rect2(navigation.position + Vector2(12.0, 98.0), Vector2((navigation.size.x - 30.0) * 0.5, 48.0))
		story = Rect2(program.position + Vector2(program.size.x + 6.0, 0.0), program.size)
		var footer_gap := 6.0
		var footer_action_width := maxf(0.0, (footer.size.x - footer_gap * 2.0) / 3.0)
		back = Rect2(footer.position + Vector2(0.0, footer.size.y + 8.0), Vector2(footer_action_width, footer.size.y))
		bestiary_action = Rect2(Vector2(back.end.x + footer_gap, back.position.y), Vector2(footer_action_width, footer.size.y))
		settings_action = Rect2(Vector2(bestiary_action.end.x + footer_gap, back.position.y), Vector2(footer_action_width, footer.size.y))
	return {
		"shell": safe,
		"shell_meta": shell_meta,
		"identity": identity,
		"title": title,
		"telemetry": telemetry,
		"navigation": navigation,
		"illustration": illustration,
		"footer": footer,
		"signature_rail": signature_rail,
		"evidence_band": telemetry,
		"settings_action": settings_action,
		"bestiary_action": bestiary_action,
		"boot": boot,
		"program": program,
		"story": story,
		"back": back,
		"boot_label": "> RUN PROCESS  [ENTER]" if density == "narrow" else ">> RUN PROCESS  [ENTER]",
	}

static func selection(viewport: Vector2, context: RefCounted) -> Dictionary:
	var safe: Rect2 = context.get("safe_rect")
	var density := str(context.get("density"))
	var pad: float = 24.0 if density == "wide" else 16.0
	var shell_meta := Rect2(safe.position + Vector2(pad, 16.0), Vector2(maxf(0.0, safe.size.x - pad * 2.0), 30.0))
	var header_h := 68.0 if density == "wide" else 62.0
	var header := Rect2(safe.position + Vector2(pad, 54.0), Vector2(maxf(0.0, safe.size.x - pad * 2.0), header_h))
	var footer := Rect2(safe.position + Vector2(pad, safe.size.y - 68.0), Vector2(maxf(0.0, safe.size.x - pad * 2.0), 24.0))
	var back := Rect2(safe.position + Vector2(pad, safe.size.y - 36.0), Vector2(minf(150.0, maxf(0.0, safe.size.x - pad * 2.0)), 28.0))
	var launch_w := minf(360.0, maxf(0.0, safe.size.x - pad * 2.0))
	var launch := Rect2(Vector2(safe.end.x - pad - launch_w, back.position.y), Vector2(launch_w, 28.0))
	var list: Rect2
	var detail: Rect2
	var detail_illustration: Rect2
	var detail_text: Rect2
	var evidence_band := Rect2()
	var signature_rail := Rect2(safe.position + Vector2(8.0, 52.0), Vector2(8.0, maxf(0.0, safe.size.y - 82.0)))
	if density == "wide":
		var content_y := header.end.y + 18.0
		var content_h := maxf(120.0, footer.position.y - content_y - 14.0)
		var list_w := minf(340.0, maxf(236.0, safe.size.x * 0.27))
		list = Rect2(safe.position + Vector2(pad, content_y - safe.position.y), Vector2(list_w, content_h))
		var detail_x := list.end.x + 22.0
		detail = Rect2(Vector2(detail_x, content_y), Vector2(maxf(0.0, safe.end.x - detail_x - pad), content_h))
		detail_illustration = Rect2(detail.position + Vector2(18.0, 66.0), Vector2(minf(202.0, detail.size.x * 0.31), minf(202.0, detail.size.y - 128.0)))
		evidence_band = Rect2(detail.position + Vector2(18.0, detail.size.y - 112.0), Vector2(maxf(0.0, detail.size.x - 36.0), 82.0))
		detail_text = Rect2(Vector2(detail_illustration.end.x + 24.0, detail.position.y + 40.0), Vector2(maxf(0.0, detail.end.x - detail_illustration.end.x - 42.0), maxf(0.0, detail.size.y - 162.0)))
	elif density == "compact":
		var content_y := header.end.y + 14.0
		var content_h := maxf(120.0, footer.position.y - content_y - 14.0)
		var list_w := minf(240.0, maxf(190.0, safe.size.x * 0.34))
		list = Rect2(safe.position + Vector2(pad, content_y - safe.position.y), Vector2(list_w, content_h))
		var detail_x := list.end.x + 16.0
		detail = Rect2(Vector2(detail_x, content_y), Vector2(maxf(0.0, safe.end.x - detail_x - pad), content_h))
		detail_illustration = Rect2(detail.position + Vector2(12.0, 52.0), Vector2(minf(126.0, detail.size.x * 0.44), minf(126.0, detail.size.y - 108.0)))
		evidence_band = Rect2(detail.position + Vector2(12.0, detail.size.y - 106.0), Vector2(maxf(0.0, detail.size.x - 24.0), 82.0))
		detail_text = Rect2(Vector2(detail_illustration.end.x + 14.0, detail.position.y + 40.0), Vector2(maxf(0.0, detail.end.x - detail_illustration.end.x - 26.0), maxf(0.0, detail.size.y - 136.0)))
	else:
		var content_y := header.end.y + 12.0
		var content_h := maxf(160.0, footer.position.y - content_y - 12.0)
		list = Rect2(safe.position + Vector2(pad, content_y - safe.position.y), Vector2(maxf(0.0, safe.size.x - pad * 2.0), content_h))
		detail = list
		detail_illustration = Rect2(detail.position + Vector2(14.0, 42.0), Vector2(maxf(0.0, detail.size.x - 28.0), minf(128.0, detail.size.y * 0.32)))
		detail_text = Rect2(detail.position + Vector2(14.0, detail_illustration.end.y - detail.position.y + 12.0), Vector2(maxf(0.0, detail.size.x - 28.0), maxf(0.0, detail.end.y - detail_illustration.end.y - 26.0)))
	return {
		"shell": safe,
		"shell_meta": shell_meta,
		"header": header,
		"list": list,
		"detail": detail,
		"detail_illustration": detail_illustration,
		"detail_text": detail_text,
		"signature_rail": signature_rail,
		"evidence_band": evidence_band,
		"footer": footer,
		"launch_program": launch,
		"back": back,
		"narrow": density == "narrow",
		"compact": density == "compact",
		"title_size": 30 if density == "wide" else 24 if density == "compact" else 21,
	}

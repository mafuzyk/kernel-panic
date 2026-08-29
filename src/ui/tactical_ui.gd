class_name TacticalUI
extends RefCounted

const BG := Color("050914")
const PANEL := Color(0.015, 0.035, 0.07, 0.90)
const CYAN := Color("28e7ff")
const TEXT := Color("d9efff")
const MUTED := Color(0.68, 0.78, 0.88, 0.62)
const MAGENTA := Color("ff386f")
const LIME := Color("9dff72")
const AMBER := Color("ffd24f")

static func angular_points(rect: Rect2, cut: float = 12.0) -> PackedVector2Array:
	var c := clampf(cut, 0.0, minf(rect.size.x, rect.size.y) * 0.5)
	return PackedVector2Array([
		rect.position + Vector2(c, 0.0),
		Vector2(rect.end.x - c, rect.position.y),
		Vector2(rect.end.x, rect.position.y + c),
		Vector2(rect.end.x, rect.end.y - c),
		Vector2(rect.end.x - c, rect.end.y),
		Vector2(rect.position.x + c, rect.end.y),
		Vector2(rect.position.x, rect.end.y - c),
		Vector2(rect.position.x, rect.position.y + c),
	])

static func segment_rects(rect: Rect2, count: int, gap: float = 2.0) -> Array[Rect2]:
	var result: Array[Rect2] = []
	if count <= 0:
		return result
	var width := maxf((rect.size.x - gap * float(count - 1)) / float(count), 0.0)
	for index in count:
		result.append(Rect2(rect.position + Vector2(float(index) * (width + gap), 0.0), Vector2(width, rect.size.y)))
	return result

static func layout(viewport: Vector2) -> Dictionary:
	var compact := viewport.x < 760.0
	var side := clampf(viewport.x * 0.012, 8.0, 16.0)
	var top := clampf(viewport.y * 0.025, 12.0, 20.0)
	var bottom := viewport.y - clampf(viewport.y * 0.025, 12.0, 20.0)
	var corner_w := minf(245.0, viewport.x * (0.46 if compact else 0.19))
	var center_w := minf(460.0, viewport.x - side * 2.0)
	var encounter_h := 58.0 if compact else 76.0
	var encounter_y := top + 100.0 if compact else top
	var boss_y := bottom - 152.0 if compact else bottom - 88.0
	return {
		"compact": compact,
		"integrity": Rect2(side, top, corner_w, 92.0 if compact else 112.0),
		"encounter": Rect2((viewport.x - center_w) * 0.5, encounter_y, center_w, encounter_h),
		"score": Rect2(viewport.x - side - corner_w, top, corner_w, 92.0 if compact else 120.0),
		"dash": Rect2(side, bottom - 76.0, minf(225.0, viewport.x * 0.45), 76.0),
		"patches": Rect2(viewport.x - side - minf(330.0, viewport.x * 0.48), bottom - 76.0, minf(330.0, viewport.x * 0.48), 76.0),
		"boss": Rect2((viewport.x - center_w) * 0.5, boss_y, center_w, 64.0),
	}

static func shell_rect(viewport: Vector2) -> Rect2:
	var compact := viewport.x < 760.0
	var side := 8.0 if compact else 16.0
	var top := 12.0 if compact else 20.0
	return Rect2(side, top, maxf(viewport.x - side * 2.0, 0.0), maxf(viewport.y - top * 2.0, 0.0))

static func shell_sections(viewport: Vector2) -> Dictionary:
	var shell := shell_rect(viewport)
	var compact := viewport.x < 760.0
	var header_h := 48.0 if compact else 68.0
	var footer_h := 42.0 if compact else 58.0
	var inset := 8.0 if compact else 10.0
	return {
		"header": Rect2(shell.position + Vector2(inset, inset), Vector2(maxf(shell.size.x - inset * 2.0, 0.0), header_h)),
		"content": Rect2(shell.position + Vector2(inset, header_h + inset), Vector2(maxf(shell.size.x - inset * 2.0, 0.0), maxf(shell.size.y - header_h - footer_h - inset * 2.0, 0.0))),
		"footer": Rect2(shell.position + Vector2(inset, shell.size.y - footer_h), Vector2(maxf(shell.size.x - inset * 2.0, 0.0), footer_h - inset)),
	}

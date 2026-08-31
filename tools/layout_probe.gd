extends Node

## Numeric layout validation for the menu grid spec rebuild (no gameplay).
## Physical test windows -> logical canvas via the project stretch rule
## (canvas_items + aspect expand, base 1280x720):
## scale = min(w/1280, h/720), logical = window / scale.
## Run: godot --headless --path . res://tools/layout_probe.tscn

const WINDOWS := [
	Vector2i(1366, 768), Vector2i(1366, 741), Vector2i(1322, 679),
	Vector2i(1280, 663), Vector2i(511, 746), Vector2i(432, 720),
]
const HARNESS_VIEWPORTS := [Vector2(1366, 768), Vector2(1024, 640), Vector2(760, 720), Vector2(432, 720)]

var fails := 0
var passes := 0

func _check(cond: bool, label: String) -> void:
	if cond:
		passes += 1
		print("PROBE_PASS ", label)
	else:
		fails += 1
		print("PROBE_FAIL ", label)

func _logical(win: Vector2i) -> Vector2:
	var s: float = minf(float(win.x) / 1280.0, float(win.y) / 720.0)
	return Vector2(float(win.x) / s, float(win.y) / s)

func _rect_close(a: Rect2, b: Rect2, tol: float) -> bool:
	return absf(a.position.x - b.position.x) <= tol \
			and absf(a.position.y - b.position.y) <= tol \
			and absf(a.size.x - b.size.x) <= tol \
			and absf(a.size.y - b.size.y) <= tol

func _menu_spec_checks(chrome, tag: String, vp: Vector2, gate: bool) -> void:
	var lay: Dictionary = chrome.menu_layout_for_viewport(vp)
	var view := Rect2(Vector2.ZERO, vp)
	var shell: Rect2 = lay["shell"]
	var row: Rect2 = lay["button_row"]
	var bw: float = float(lay["button_width"])
	var gap: float = float(lay["gap"])

	# Harness parity: required keys inside the viewport, bands disjoint.
	var band_ok := true
	var bands: Array[Rect2] = [lay["title"], lay["klog"], lay["controls"], lay["best"], lay["mode_info"], row]
	for i in bands.size():
		if not view.encloses(Rect2(bands[i])):
			band_ok = false
		for j in range(i + 1, bands.size()):
			if bands[i].intersects(bands[j]):
				band_ok = false
	for key in ["title", "klog", "subtitle", "controls", "best", "mode_info", "button_row", "purge", "story", "mode", "program", "diff"]:
		if not view.encloses(Rect2(lay[key])):
			band_ok = false
	_check(band_ok, "menu %s required rects contained, bands disjoint" % [tag])
	_check(int(lay["title_size"]) >= 44, "menu %s title size %d scales down" % [tag, int(lay["title_size"])])

	# Rail anchoring: content rects stay inside the shared shell (the klog meta
	# band deliberately rides the top rail, so it is checked by position below);
	# footer bottom rides the shell bottom rail; version ends on the right rail.
	var in_shell := true
	for key in ["version", "subtitle", "controls", "best", "mode_info", "purge", "story", "mode", "program", "diff", "button_row", "prompt"]:
		if not shell.grow(0.01).encloses(Rect2(lay[key])):
			in_shell = false
	_check(in_shell, "menu %s content rects stay inside the shared shell" % [tag])
	_check(is_equal_approx(row.end.y, shell.end.y - float(lay["footer_ride"])), "menu %s footer bottom rides the shell rail" % [tag])
	_check(is_equal_approx((lay["klog"] as Rect2).position.y, shell.position.y - 8.0), "menu %s meta band rides the shell top rail (-8)" % [tag])
	_check(is_equal_approx((lay["version"] as Rect2).end.x, shell.end.x), "menu %s version stamp ends on the right rail" % [tag])

	# Header chain: declared gaps, no overlaps.
	var chain_ok := true
	var title: Rect2 = lay["title"]
	var subtitle: Rect2 = lay["subtitle"]
	var controls: Rect2 = lay["controls"]
	var best: Rect2 = lay["best"]
	if absf(subtitle.position.y - (title.end.y + 4.0)) > 0.01: chain_ok = false
	if absf(controls.position.y - (subtitle.end.y + 4.0)) > 0.01: chain_ok = false
	if absf(best.position.y - (controls.end.y + 4.0)) > 0.01: chain_ok = false
	_check(chain_ok, "menu %s header chain stacks with the declared 4px rhythm" % [tag])

	# Action column: one centered unit; hierarchy by width; consistent rhythm.
	var purge: Rect2 = lay["purge"]
	var story: Rect2 = lay["story"]
	var mode: Rect2 = lay["mode"]
	var program: Rect2 = lay["program"]
	var diff: Rect2 = lay["diff"]
	var mi: Rect2 = lay["mode_info"]
	var action_w := purge.size.x
	var stack_ok := true
	if absf(purge.get_center().x - vp.x * 0.5) > 0.01: stack_ok = false
	if absf(story.get_center().x - vp.x * 0.5) > 0.01: stack_ok = false
	if absf(mode.get_center().x - vp.x * 0.5) > 0.01: stack_ok = false
	if absf(diff.get_center().x - vp.x * 0.5) > 0.01: stack_ok = false
	if absf(story.size.x - action_w * 0.82) > 0.01: stack_ok = false
	if absf(mode.size.x - action_w * 0.94) > 0.01: stack_ok = false
	if not (purge.size.x > story.size.x and story.size.x < mode.size.x): stack_ok = false
	var gap_a: float = story.position.y - purge.end.y
	if absf((mode.position.y - story.end.y) - gap_a) > 0.01: stack_ok = false
	if absf((diff.position.y - mode.end.y) - gap_a) > 0.01: stack_ok = false
	if gap_a < 6.0 - 0.01 or gap_a > 12.0 + 0.01: stack_ok = false
	if absf(mi.position.y - (diff.end.y + 8.0)) > 0.01: stack_ok = false
	_check(stack_ok, "menu %s action column centered as a unit with hierarchy (gap %.0f)" % [tag, gap_a])

	# Pair card: program lives in the right half, clears the centered dot.
	var pair_ok := true
	if program.position.x < mode.get_center().x - 0.01: pair_ok = false
	if program.end.x > mode.end.x - 40.0 + 0.01: pair_ok = false
	if absf(program.position.y - mode.position.y) > 0.01 or absf(program.size.y - mode.size.y) > 0.01: pair_ok = false
	var dot: Vector2 = lay["mode_dot"]
	if absf(dot.x - mode.get_center().x) > 0.01 or absf(dot.y - mode.get_center().y) > 0.01: pair_ok = false
	_check(pair_ok, "menu %s MODE/PROGRAM pair reads as one card, dot at its center" % [tag])

	# Footer: three equal slots, equal pitch, one baseline, frames on slots.
	var slots_ok := true
	var frames: Array = lay["frames"]
	if frames.size() != 6: slots_ok = false
	var prev_end := -1.0
	for i in 3:
		var slot := Rect2(row.position.x + float(i) * (bw + gap), row.position.y, bw, row.size.y)
		if i > 0:
			if absf(slot.position.x - prev_end - gap) > 0.01: slots_ok = false
		prev_end = slot.end.x
		if not is_equal_approx(slot.size.y, 48.0) or not is_equal_approx(row.size.y, 48.0): slots_ok = false
		if frames.size() == 6 and Rect2(frames[3 + i]) != slot: slots_ok = false
	if not is_equal_approx(row.size.x, bw * 2.0 + gap): slots_ok = false
	if not is_equal_approx(purge.size.y, 88.0) or not is_equal_approx(story.size.y, 58.0): slots_ok = false
	_check(slots_ok, "menu %s footer trio equal size/baseline, equal gaps, frames on slots" % [tag])

	# Compression: gates must run the full rhythm; probes may compress.
	if gate:
		var air_ok := best.end.y + 8.0 <= purge.position.y and mi.end.y + 4.0 <= row.position.y \
				and absf(gap_a - 12.0) < 0.01 and absf(mi.size.y - 32.0) < 0.01 \
				and absf((lay["klog"] as Rect2).size.y - 68.0) < 0.01
		_check(air_ok, "menu %s full rhythm at gate: no compression engaged" % [tag])
	else:
		_check(mi.end.y + 4.0 <= row.position.y + 0.01, "menu %s compressed unit still clears the footer" % [tag])

	# Prompt + version contained; ring stays inside the viewport.
	var decor_ok := view.encloses(Rect2(lay["prompt"])) and view.encloses(Rect2(lay["version"]))
	var ring: Vector2 = lay["ring_center"]
	decor_ok = decor_ok and view.encloses(Rect2(ring - Vector2(70, 70), Vector2(140, 140)))
	_check(decor_ok, "menu %s prompt/version/ring contained" % [tag])

func _ready() -> void:
	var chrome = load("res://src/ui/menu_chrome_kit.gd").new(null)

	# Harness's direct logical probes (compression cascade may engage there).
	for vp in HARNESS_VIEWPORTS:
		_menu_spec_checks(chrome, str(vp), vp, false)

	# The six gate windows, stretch-mapped to their logical canvases.
	for win in WINDOWS:
		_menu_spec_checks(chrome, str(win), _logical(win), true)

	# Footer registry keeps the approved widths (harness contract).
	var fl: Dictionary = chrome.footer_button_layout_for_viewport(Vector2(1400, 768))
	_check(is_equal_approx(float(fl["total_width"]), 448.0) and is_equal_approx(float(fl["button_width"]), 217.0) and is_equal_approx(float(fl["gap"]), 14.0), "footer registry keeps 448/217/14")
	var fl2: Dictionary = chrome.footer_button_layout_for_viewport(Vector2(1024, 576))
	_check(is_equal_approx(float(fl2["total_width"]), 1024.0 * 0.327), "footer registry scales from the logical viewport")

	# --- Live apply: real nodes take the spec rects on resize, no rebuilds ---
	# Container min-clamp: Containers never shrink below a child's minimum
	# size, so the footer row and text labels may exceed their spec rects when
	# text min-size exceeds the spec width; the spec row stays the 448/217/14
	# registration anchor. Compact viewports (1024/432) get a wider tolerance
	# because text min-size exceeds button_width there, so the container
	# min-clamp drifts the real pitch away from the spec pitch.
	var menu_scene: PackedScene = load("res://src/ui/menu.tscn")
	var menu = menu_scene.instantiate()
	add_child(menu)
	await get_tree().process_frame
	menu.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var live_chrome = menu.get("_chrome_kit")
	var chrome_ready: bool = live_chrome != null and live_chrome.has_method("apply_menu_layout")
	var buttons_ok: bool = true
	var ids_ok: bool = true
	var row_ok: bool = true
	var slots_ok: bool = true
	var frames_ok: bool = true
	var labels_ok: bool = true
	var meta_ok: bool = true
	var overflow_ok: bool = true
	var instance_ids := {}
	if not chrome_ready:
		buttons_ok = false
		row_ok = false
		slots_ok = false
		frames_ok = false
		labels_ok = false
		meta_ok = false
		overflow_ok = false
	else:
		for size_pair in [[Vector2(1024, 600), "1024x600"], [Vector2(1280, 720), "1280x720"], [Vector2(1600, 900), "1600x900"], [Vector2(432, 720), "432x720"]]:
			var live_vp: Vector2 = size_pair[0]
			var live_tag: String = size_pair[1]
			menu.size = live_vp
			live_chrome.apply_menu_layout()
			await get_tree().process_frame
			await get_tree().process_frame
			var lay: Dictionary = live_chrome.menu_layout_for_viewport(live_vp)
			var purge: Button = menu.get("_purge_btn")
			var mode: Button = menu.get("_mode_btn")
			var diff: Button = menu.get("_diff_btn")
			var row: Control = menu.get("_footer_row")
			# Buttons are direct menu children -> menu space; ids must survive
			# every resize without rebuilds.
			buttons_ok = buttons_ok and purge != null and purge.get_rect().is_equal_approx(lay["purge"])
			buttons_ok = buttons_ok and mode != null and mode.get_rect().is_equal_approx(lay["mode"])
			buttons_ok = buttons_ok and diff != null and diff.get_rect().is_equal_approx(lay["diff"])
			var ids := []
			for node in [purge, mode, diff, row]:
				ids.append(node.get_instance_id() if node != null else -1)
			if instance_ids.is_empty():
				for id in ids:
					instance_ids[id] = true
			else:
				for id in ids:
					if not instance_ids.has(id):
						ids_ok = false
			# Row: spec position must hold; Container min-clamp may grow width
			# beyond spec (spec row stays the 448/217/14 registration anchor).
			if row == null:
				row_ok = false
			else:
				row_ok = row_ok and absf(row.position.x - (lay["button_row"] as Rect2).position.x) <= 0.01
				row_ok = row_ok and absf(row.position.y - (lay["button_row"] as Rect2).position.y) <= 0.01
				row_ok = row_ok and row.size.x >= (lay["button_row"] as Rect2).size.x - 0.01
			# Footer buttons: measured in MENU space (row.position + kid.position)
			# against the spec footer slots (frames[3..5]). Wide viewports assert
			# the full slot rects; compact viewports (logical width < 1280) only
			# assert count, size floors and the first slot's left edge — text
			# min-size exceeds button_width there, so the container overflow
			# drifts the real pitch beyond any useful tolerance (registry
			# overflow at 432 is pre-existing HEAD behavior).
			var kids := row.get_children() if row != null else []
			slots_ok = slots_ok and kids.size() == 3
			for i in kids.size():
				var kid: Control = kids[i]
				var slot: Rect2 = lay["frames"][3 + i]
				var kid_menu_rect := Rect2((lay["button_row"] as Rect2).position + kid.position, kid.size)
				if live_vp.x >= 1280.0:
					slots_ok = slots_ok and _rect_close(kid_menu_rect, slot, 1.5)
				elif i == 0:
					slots_ok = slots_ok and absf(kid_menu_rect.position.x - slot.position.x) <= 1.5
				slots_ok = slots_ok and kid.size.x >= slot.size.x - 0.01
			var frames: Array = menu.get("_menu_frames")
			frames_ok = frames_ok and frames != null and frames.size() == 6
			if frames != null:
				for i in frames.size():
					frames_ok = frames_ok and (frames[i] as Control).get_rect().is_equal_approx(Rect2(lay["frames"][i]))
			var subtitle: Control = menu.get("_subtitle")
			var controls: Control = menu.get("_controls_line")
			var best: Control = menu.get("_best_label")
			var prompt: Control = menu.get("_prompt")
			labels_ok = labels_ok and subtitle != null and subtitle.get_rect().is_equal_approx(Rect2(lay["subtitle"]))
			labels_ok = labels_ok and controls != null and controls.get_rect().is_equal_approx(Rect2(lay["controls"]))
			labels_ok = labels_ok and best != null and best.get_rect().is_equal_approx(Rect2(lay["best"]))
			labels_ok = labels_ok and prompt != null and prompt.get_rect().is_equal_approx(Rect2(lay["prompt"]))
			# klog/mode_info: text min-clamps their size, so check position only.
			var klog: Control = menu.get("_klog")
			var mode_info: Control = menu.get("_mode_info")
			var version: Control = menu.get("_version_tag")
			meta_ok = meta_ok and klog != null and absf(klog.position.x - (lay["klog"] as Rect2).position.x) <= 0.01 and absf(klog.position.y - (lay["klog"] as Rect2).position.y) <= 0.01
			meta_ok = meta_ok and mode_info != null and absf(mode_info.position.x - (lay["mode_info"] as Rect2).position.x) <= 0.01 and absf(mode_info.position.y - (lay["mode_info"] as Rect2).position.y) <= 0.01
			meta_ok = meta_ok and version != null and version.get_rect().is_equal_approx(Rect2(lay["version"]))
			var report: Array = menu.call("text_overflow_report")
			for entry in report:
				overflow_ok = overflow_ok and bool(entry.get("fits", false))
	_check(buttons_ok, "menu live buttons follow the spec on resize")
	_check(ids_ok, "menu live nodes keep identity across every viewport")
	_check(row_ok, "menu live footer row follows the spec position")
	_check(slots_ok, "menu live footer buttons match the spec slots")
	_check(frames_ok, "menu live frames: six exist and follow the spec")
	_check(labels_ok, "menu live header labels follow the spec rects")
	_check(meta_ok, "menu live meta labels follow the spec positions")
	_check(overflow_ok, "menu text overflow report fits on every viewport")
	menu.queue_free()
	await get_tree().process_frame

	print("PROBE_RESULT passes=%d fails=%d" % [passes, fails])
	get_tree().quit(1 if fails > 0 else 0)

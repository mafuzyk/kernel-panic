class_name VNextPatchSurface
extends Control

const Context = preload("res://src/ui/vnext/ui_context.gd")
const Chrome = preload("res://src/ui/vnext/ui_chrome.gd")
const Tokens = preload("res://src/ui/vnext/ui_tokens.gd")
const Orbitron: Font = preload("res://assets/fonts/Orbitron.ttf")
const ShareTechMono: Font = preload("res://assets/fonts/ShareTechMono.ttf")

signal action_requested(action_id: String, payload: Dictionary)

var context: RefCounted
var snapshot := {}
var _layout := {}
var _buttons := {}
var _offer_buttons: Array[Button] = []
var _focus := "confirm"
var _selected := 0
var _dispatched := false
var _gui_event_ids := {}

static func context_for_viewport(viewport: Vector2, touch := false, reduced := false, contrast := false, scale := 1.0) -> RefCounted:
	return Context.from_viewport(viewport, touch, reduced, contrast, scale)

static func snapshot_from_offers(offers: Array, active_ids: Array = [], build := "") -> Dictionary:
	var copy: Array = []
	for raw_offer in offers:
		if not raw_offer is Dictionary:
			continue
		var offer: Dictionary = (raw_offer as Dictionary).duplicate(true)
		var id := str(offer.get("id", ""))
		var title := str(offer.get("title", id.to_upper()))
		var description := str(offer.get("description", offer.get("desc", "")))
		var level := int(offer.get("level", Game.patch_level(id)))
		var max_level := int(offer.get("max", 0))
		var relation := str(offer.get("relation", ""))
		if relation == "" and not active_ids.is_empty():
			for other_id in active_ids:
				if str(other_id) == id:
					continue
				var candidate := Game.patch_relation(id, str(other_id))
				if candidate != "NO DIRECT INTERACTION":
					relation = candidate
					break
		if relation == "NO DIRECT INTERACTION":
			relation = ""
		var explicit_state := str(offer.get("state", ""))
		var available := bool(offer.get("available", not bool(offer.get("locked", false))))
		var state := explicit_state
		if state.is_empty():
			if not available or bool(offer.get("locked", false)):
				state = "locked" if bool(offer.get("locked", false)) else "unavailable"
			elif max_level > 0 and level >= max_level:
				state = "unavailable"
			elif not relation.is_empty():
				state = "conflict"
			else:
				state = "ready"
		if state in ["locked", "unavailable"]:
			available = false
		var reason := str(offer.get("reason", ""))
		if reason.is_empty():
			match state:
				"locked": reason = "UNLOCK CONDITION NOT MET"
				"unavailable": reason = "MAX LEVEL REACHED" if max_level > 0 and level >= max_level else "OFFER UNAVAILABLE"
				"conflict": reason = relation
				_: reason = ""
		offer["id"] = id
		offer["title"] = title
		offer["description"] = description
		offer["effect"] = str(offer.get("effect", description))
		offer["benefit"] = str(offer.get("benefit", description))
		offer["cost_benefit"] = str(offer.get("cost_benefit", "COST // NONE   BENEFIT // %s" % description))
		offer["build_impact"] = str(offer.get("build_impact", "CURRENT BUILD // %s" % build if not build.is_empty() else "CURRENT BUILD // NO PATCHES"))
		offer["level"] = level
		offer["max"] = max_level
		offer["relation"] = relation
		offer["state"] = state
		offer["available"] = available
		offer["reason"] = reason
		copy.append(offer)
	return {"offers": copy, "active_ids": active_ids.duplicate(true), "build": build, "paused": true}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for spec in [
		{"name": "PreviousAction", "id": "previous", "text": "< PREVIOUS"},
		{"name": "NextAction", "id": "next", "text": "NEXT >"},
		{"name": "ConfirmAction", "id": "confirm", "text": ">> INSTALL PATCH"},
		{"name": "SkipAction", "id": "skip", "text": "SKIP OFFER"},
		{"name": "CloseAction", "id": "close", "text": "CLOSE"},
	]:
		var button := Button.new()
		button.name = spec["name"]
		button.text = spec["text"]
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.flat = true
		button.add_theme_font_override("font", ShareTechMono)
		_style_action_button(button, 14.0, 14.0)
		button.pressed.connect(_dispatch.bind(spec["id"]))
		button.focus_entered.connect(_on_fixed_focus.bind(spec["id"]))
		button.gui_input.connect(_on_button_gui_input)
		add_child(button)
		_buttons[spec["id"]] = button

func configure(next_snapshot: Dictionary, next_context: RefCounted) -> void:
	context = next_context
	var incoming := next_snapshot.duplicate(true)
	var normalized := snapshot_from_offers(incoming.get("offers", []), incoming.get("active_ids", []), str(incoming.get("build", "")))
	normalized["paused"] = bool(incoming.get("paused", false))
	normalized["selected"] = int(incoming.get("selected", 0))
	snapshot = normalized
	_selected = clampi(int(snapshot.get("selected", 0)), 0, maxi(0, _offers().size() - 1))
	_focus = "offer_%d" % _selected if not _offers().is_empty() else "skip"
	_dispatched = false
	_ensure_offer_buttons()
	_layout = _make_layout()
	_apply_layout()
	queue_redraw()

func configure_adapter(offers: Array, active_ids: Array, build: String, next_context: RefCounted) -> void:
	configure(snapshot_from_offers(offers, active_ids, build), next_context)

func reflow_for_viewport(viewport: Vector2) -> void:
	if context == null:
		return
	context = Context.from_viewport(viewport, context.input_mode == "touch", context.reduce_motion, context.high_contrast, context.text_scale)
	_layout = _make_layout()
	_apply_layout()
	queue_redraw()

func _notification(what: int) -> void:
	if what != NOTIFICATION_RESIZED or context == null:
		return
	var viewport := get_viewport_rect().size
	if viewport.x <= 0.0 or viewport.y <= 0.0:
		viewport = size
	if viewport.x > 0.0 and viewport.y > 0.0:
		reflow_for_viewport(viewport)

func _offers() -> Array:
	return snapshot.get("offers", []) as Array

func _ensure_offer_buttons() -> void:
	var offers := _offers()
	while _offer_buttons.size() < offers.size():
		var index := _offer_buttons.size()
		var button := Button.new()
		button.name = "OfferAction%d" % index
		button.text = ""
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.flat = true
		_style_action_button(button, 18.0, 14.0)
		button.pressed.connect(_select_offer.bind(index))
		button.focus_entered.connect(_on_offer_focus.bind(index))
		button.gui_input.connect(_on_button_gui_input)
		add_child(button)
		_offer_buttons.append(button)
	for index in _offer_buttons.size():
		_offer_buttons[index].visible = index < offers.size()

func _style_action_button(button: Button, left_margin: float, right_margin: float) -> void:
	button.add_theme_color_override("font_color", Tokens.role_color("structure"))
	button.add_theme_color_override("font_hover_color", Tokens.role_color("focus"))
	button.add_theme_color_override("font_focus_color", Tokens.role_color("focus"))
	button.add_theme_color_override("font_pressed_color", Tokens.role_color("focus"))
	button.add_theme_color_override("font_disabled_color", Tokens.role_color("muted"))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		style.content_margin_left = left_margin
		style.content_margin_right = right_margin
		button.add_theme_stylebox_override(state, style)

func _make_layout() -> Dictionary:
	var safe: Rect2 = context.safe_rect
	var density: String = context.density
	var narrow: bool = density == "narrow"
	var pad := 24.0 if density == "wide" else 16.0
	var shell_meta := Rect2(safe.position + Vector2(pad, 16.0), Vector2(maxf(safe.size.x - pad * 2.0, 0.0), 30.0))
	var header_h := 68.0 if density == "wide" else 62.0
	var header := Rect2(safe.position + Vector2(pad, 54.0), Vector2(maxf(safe.size.x - pad * 2.0, 0.0), header_h))
	var footer := Rect2(safe.position + Vector2(pad, safe.size.y - 76.0), Vector2(maxf(safe.size.x - pad * 2.0, 0.0), 24.0))
	var body_top := header.end.y + (12.0 if narrow else 14.0)
	var body_bottom := safe.end.y - (176.0 if narrow else 88.0)
	var body := Rect2(safe.position.x + pad, body_top, maxf(safe.size.x - pad * 2.0, 0.0), maxf(body_bottom - body_top, 120.0))
	var cards: Array = []
	var offer_count := maxi(1, _offers().size())
	if narrow:
		cards.append(body)
	else:
		var gap := 16.0
		var card_width := maxf((body.size.x - gap * float(offer_count - 1)) / float(offer_count), 1.0)
		for index in offer_count:
			cards.append(Rect2(body.position.x + float(index) * (card_width + gap), body.position.y, card_width, body.size.y))
	var evidence_bands: Array = []
	for card in cards:
		evidence_bands.append(_evidence_rect(card, narrow))
	var evidence_band: Rect2 = evidence_bands[mini(_selected, evidence_bands.size() - 1)] if not evidence_bands.is_empty() else Rect2()
	var signature_rail := Rect2(safe.position + Vector2(8.0, 52.0), Vector2(8.0, maxf(0.0, safe.size.y - 82.0)))
	return {
		"safe": safe,
		"shell": safe,
		"shell_meta": shell_meta,
		"header": header,
		"body": body,
		"cards": cards,
		"evidence_bands": evidence_bands,
		"evidence_band": evidence_band,
		"footer": footer,
		"signature_rail": signature_rail,
		"narrow": narrow,
		"compact": density == "compact",
		"title_size": 22 if narrow else 28,
	}

func _evidence_rect(card: Rect2, narrow: bool) -> Rect2:
	var height := 80.0 if narrow else 100.0
	var horizontal := 12.0 if narrow else 18.0
	return Rect2(card.position + Vector2(horizontal, maxf(0.0, card.size.y - height - 12.0)), Vector2(maxf(0.0, card.size.x - horizontal * 2.0), height))

func _evidence_rows(offer: Dictionary, accent: Color) -> Array:
	var state := _evidence_state_text(offer)
	var next := _selected_next_text(offer)
	if context.density == "narrow":
		return [
			{"label": "STATE", "value": state, "color": Tokens.role_color("ready") if bool(offer.get("available", false)) else Tokens.role_color("muted")},
			{"label": "NEXT", "value": next, "color": accent},
		]
	return [
		{"label": "STATE", "value": state, "color": Tokens.role_color("ready") if bool(offer.get("available", false)) else Tokens.role_color("muted")},
		{"label": "BUILD", "value": _build_text(), "color": accent},
		{"label": "NEXT", "value": next, "color": accent},
	]

func _evidence_state_text(offer: Dictionary) -> String:
	var state := str(offer.get("state", "empty")).to_upper()
	if context.density == "narrow":
		var max_level := int(offer.get("max", 0))
		var level := int(offer.get("level", 0))
		return "%s // LV %d%s" % [state, level, ("/%d" % max_level) if max_level > 0 else ""]
	return state

func _apply_layout() -> void:
	if _layout.is_empty():
		return
	var safe: Rect2 = _layout["safe"]
	var body: Rect2 = _layout["body"]
	var narrow: bool = _layout["narrow"]
	var cards: Array = _layout["cards"]
	for index in _offer_buttons.size():
		var button: Button = _offer_buttons[index]
		button.visible = index < _offers().size() and (not narrow or index == _selected)
		if button.visible:
			button.position = cards[0].position if narrow else cards[index].position
			button.size = cards[0].size if narrow else cards[index].size
			button.disabled = not _offer_available(index)
		button.tooltip_text = _offer_accessible_name(index)
	var nav_y := body.end.y + 8.0
	var nav_width := minf(170.0, maxf(body.size.x * 0.42, 1.0))
	_buttons["previous"].position = Vector2(body.position.x, nav_y)
	_buttons["previous"].size = Vector2(nav_width, 44.0)
	_buttons["next"].position = Vector2(body.end.x - nav_width, nav_y)
	_buttons["next"].size = Vector2(nav_width, 44.0)
	_buttons["previous"].visible = narrow and _offers().size() > 1
	_buttons["next"].visible = narrow and _offers().size() > 1
	_buttons["previous"].disabled = _offers().size() <= 1
	_buttons["next"].disabled = _offers().size() <= 1
	if narrow:
		_buttons["confirm"].position = Vector2(safe.position.x, safe.end.y - 94.0)
		_buttons["confirm"].size = Vector2(safe.size.x, 44.0)
		_buttons["skip"].position = Vector2(safe.position.x, safe.end.y - 44.0)
		_buttons["skip"].size = Vector2(safe.size.x, 44.0)
	else:
		var confirm_width := minf(300.0, safe.size.x * 0.5)
		var skip_width := minf(180.0, safe.size.x * 0.3)
		_buttons["confirm"].position = Vector2(safe.position.x, safe.end.y - 44.0)
		_buttons["confirm"].size = Vector2(confirm_width, 44.0)
		_buttons["skip"].position = Vector2(safe.end.x - skip_width, safe.end.y - 44.0)
		_buttons["skip"].size = Vector2(skip_width, 44.0)
	var close_width := 142.0 if not narrow else 88.0
	_buttons["close"].position = Vector2(safe.end.x - close_width, _layout["header"].position.y - (8.0 if not narrow else 2.0))
	_buttons["close"].size = Vector2(close_width, 34.0)
	_buttons["close"].text = _close_text()
	_buttons["close"].visible = true
	_buttons["confirm"].disabled = _offers().is_empty() or not _selected_offer_available()
	for id in _buttons:
		var button: Button = _buttons[id]
		button.add_theme_font_size_override("font_size", maxi(12, int(round(14.0 * context.text_scale))))
	_buttons["confirm"].add_theme_font_size_override("font_size", maxi(12, int(round(15.0 * context.text_scale))))
	queue_redraw()

func _offer_available(index: int) -> bool:
	if index < 0 or index >= _offers().size():
		return false
	return bool((_offers()[index] as Dictionary).get("available", true))

func _selected_offer_available() -> bool:
	return _offer_available(_selected)

func _title_text() -> String:
	return "PATCH // DECISION" if context != null and context.density == "narrow" else "PATCH OFFER // BUILD DECISION"

func _subtitle_text() -> String:
	return "READ THE COST BEFORE INSTALL" if context != null and context.density == "narrow" else "SELECT A CHANGE. READ THE CONSEQUENCE BEFORE INSTALL."

func _close_text() -> String:
	return "CLOSE" if context != null and context.density == "narrow" else "CLOSE [ESC]"

func _header_status_text() -> String:
	var count := _offers().size()
	if context != null and context.density == "narrow":
		return "PAUSED // %02d/%02d" % [_selected + 1, maxi(count, 1)]
	return "PAUSED // OFFER %02d/%02d" % [_selected + 1, maxi(count, 1)]

func _build_text() -> String:
	var build := str(snapshot.get("build", ""))
	return build if not build.is_empty() else "NO ACTIVE PATCHES"

func _selected_next_text(offer: Dictionary) -> String:
	return "INSTALL" if bool(offer.get("available", false)) else _state_reason(offer)

func _offer_accessible_name(index: int) -> String:
	if index < 0 or index >= _offers().size():
		return "PATCH OFFER"
	var offer: Dictionary = _offers()[index]
	return "PATCH %d: %s. %s. %s" % [index + 1, str(offer.get("title", "PATCH")), str(offer.get("description", "")), _state_reason(offer)]

func _state_reason(offer: Dictionary) -> String:
	var state := str(offer.get("state", "ready"))
	var reason := str(offer.get("reason", ""))
	if state == "ready":
		return "READY"
	return "%s: %s" % [state.to_upper(), reason]

func _on_fixed_focus(id: String) -> void:
	_focus = id
	queue_redraw()

func _on_offer_focus(index: int) -> void:
	if index < 0 or index >= _offers().size():
		return
	_selected = index
	_focus = "offer_%d" % index
	_apply_layout()
	queue_redraw()

func _select_offer(index: int) -> bool:
	if _dispatched or index < 0 or index >= _offers().size() or not _offer_available(index):
		return false
	_selected = index
	_focus = "offer_%d" % index
	_apply_layout()
	queue_redraw()
	return true

func _dispatch(id: String) -> bool:
	if id == "previous" or id == "next":
		if _offers().size() <= 1:
			return false
		var delta := -1 if id == "previous" else 1
		return _select_offer(posmod(_selected + delta, _offers().size()))
	if id.begins_with("offer_"):
		return _select_offer(int(id.trim_prefix("offer_")))
	if id not in ["confirm", "skip", "close"]:
		return false
	if _dispatched:
		return false
	if id == "confirm" and not _selected_offer_available():
		return false
	_dispatched = true
	var offer: Dictionary = _offers()[_selected] if not _offers().is_empty() else {}
	action_requested.emit(id, {"index": _selected, "offer": offer.duplicate(true), "state": str(offer.get("state", ""))})
	queue_redraw()
	return true

func reject_action() -> void:
	_dispatched = false
	queue_redraw()

func handle_input(event: InputEvent) -> bool:
	var event_id := event.get_instance_id()
	if _gui_event_ids.has(event_id):
		_gui_event_ids.erase(event_id)
		return true
	if _layout.is_empty():
		return false
	if event is InputEventMouseButton and event.pressed:
		return _dispatch(_action_at((event as InputEventMouseButton).position))
	if event is InputEventScreenTouch and event.pressed:
		return _dispatch(_action_at((event as InputEventScreenTouch).position))
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode in [KEY_TAB, KEY_DOWN]:
			return _step_focus(1)
		if key_event.keycode == KEY_UP:
			return _step_focus(-1)
		if key_event.keycode == KEY_LEFT:
			return _dispatch("previous") if bool(_layout["narrow"]) else _select_offer(posmod(_selected - 1, maxi(1, _offers().size())))
		if key_event.keycode == KEY_RIGHT:
			return _dispatch("next") if bool(_layout["narrow"]) else _select_offer(posmod(_selected + 1, maxi(1, _offers().size())))
		if key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			return _dispatch(_focus)
		if key_event.keycode == KEY_ESCAPE:
			return _dispatch("close")
	return false

func _step_focus(delta: int) -> bool:
	var ids: Array = []
	for index in _offers().size():
		if not bool(_layout["narrow"]) or index == _selected:
			ids.append("offer_%d" % index)
	if bool(_layout["narrow"]) and _offers().size() > 1:
		ids.append_array(["previous", "next"])
	ids.append_array(["confirm", "skip", "close"])
	if ids.is_empty():
		return false
	var index := ids.find(_focus)
	index = 0 if index < 0 else wrapi(index + delta, 0, ids.size())
	return set_focus_id(ids[index])

func _local_pointer(point: Vector2) -> Vector2:
	return get_viewport().get_final_transform().affine_inverse() * point

func _action_at(point: Vector2) -> String:
	point = _local_pointer(point)
	var regions := action_regions()
	for id in regions:
		var rect: Rect2 = regions[id]["rect"]
		if rect.has_point(point):
			return id
	return ""

func _on_button_gui_input(event: InputEvent) -> void:
	_gui_event_ids[event.get_instance_id()] = true

func _unhandled_input(event: InputEvent) -> void:
	if handle_input(event):
		get_viewport().set_input_as_handled()

func set_focus_id(id: String) -> bool:
	if id.begins_with("offer_"):
		var offer_index := int(id.trim_prefix("offer_"))
		if offer_index < 0 or offer_index >= _offers().size() or not _offer_available(offer_index):
			return false
		_selected = offer_index
		_focus = id
		_apply_layout()
		_offer_buttons[offer_index].grab_focus()
		queue_redraw()
		return true
	if not _buttons.has(id) or not _buttons[id].visible or _buttons[id].disabled:
		return false
	_focus = id
	(_buttons[id] as Button).grab_focus()
	queue_redraw()
	return true

func focus_id() -> String:
	return _focus

func layout_snapshot() -> Dictionary:
	return {"density": context.density, "safe_rect": context.safe_rect, "regions": _layout.duplicate(true)}

func action_regions() -> Dictionary:
	var result := {}
	var offers: Array = _offers()
	var cards: Array = _layout.get("cards", [])
	for index in offers.size():
		if index >= _offer_buttons.size() or not _offer_buttons[index].visible:
			continue
		var offer: Dictionary = offers[index]
		var rect: Rect2 = cards[0] if bool(_layout.get("narrow", false)) else cards[index]
		result["offer_%d" % index] = {"rect": rect, "label": _offer_accessible_name(index), "state": str(offer.get("state", "ready")), "available": _offer_available(index)}
	for id in _buttons:
		var button: Button = _buttons[id]
		if button.visible:
			result[id] = {"rect": Rect2(button.position, button.size), "label": button.text, "state": "unavailable" if button.disabled else "ready", "available": not button.disabled}
	return result

func semantic_snapshot() -> Dictionary:
	var offers: Array = _offers().duplicate(true)
	var selected_offer: Dictionary = offers[_selected] if not offers.is_empty() else {}
	var state := str(selected_offer.get("state", "empty"))
	return {
		"screen": "patch_offer",
		"visual_system": "reference_shell",
		"route": "KP://PATCH",
		"offers": offers,
		"selected": _selected,
		"selected_offer": selected_offer.duplicate(true),
		"focus": _focus,
		"build": snapshot.get("build", ""),
		"paused": snapshot.get("paused", false),
		"decision": "available" if _selected_offer_available() else "blocked",
		"composition": {"shell": "persistent", "cards": "offer_register", "detail": "consequence_dossier", "footer": "telemetry", "chrome": "incident_console", "density": "evidence_blocks"},
		"evidence": {"build": snapshot.get("build", ""), "state": state, "next": _selected_next_text(selected_offer)},
	}

func _text_entries_for_offer(rect: Rect2, offer: Dictionary) -> Array:
	var scale := float(context.text_scale)
	var inset := 16.0
	var width := maxf(rect.size.x - inset * 2.0, 1.0)
	var y := rect.position.y + inset
	var entries: Array = []
	var content := [
		["identity", str(offer.get("title", "PATCH")).to_upper(), 22, 30.0],
			["state", "STATUS // %s" % _state_reason(offer), 12, 22.0],
		["effect", "EFFECT // " + str(offer.get("effect", offer.get("description", ""))), 15, 38.0],
		["cost_benefit", str(offer.get("cost_benefit", "COST // NONE")), 13, 30.0],
		["relation", "RELATION // " + (str(offer.get("relation", "")) if not str(offer.get("relation", "")).is_empty() else "NO DIRECT INTERACTION"), 12, 30.0],
		["impact", "BUILD IMPACT // " + str(offer.get("build_impact", snapshot.get("build", "NO PATCHES"))), 12, 34.0],
		["level", "LEVEL %d → %d%s" % [int(offer.get("level", 0)), int(offer.get("level", 0)) + 1, (" / %d" % int(offer.get("max", 0))) if int(offer.get("max", 0)) > 0 else ""], 12, 22.0],
	]
	if context.density == "narrow":
		content = content.slice(0, 6)
	for item in content:
		var base_size: int = item[2]
		var font: Font = Orbitron if base_size >= 20 else ShareTechMono
		var font_size := maxi(10, int(round(float(base_size) * scale)))
		var measured := font.get_multiline_string_size(str(item[1]), HORIZONTAL_ALIGNMENT_LEFT, width, font_size)
		var height := maxf(float(item[3]) * scale, measured.y + 4.0)
		entries.append({"id": item[0], "text": str(item[1]), "rect": Rect2(Vector2(rect.position.x + inset, y), Vector2(width, height)), "size": font_size})
		y += height + (2.0 if context.density == "narrow" else 3.0) * scale
	return entries

func text_overflow_report() -> Array:
	if context == null or _layout.is_empty():
		return [{"id": "surface", "fits": false, "reason": "not configured"}]
	var result: Array = []
	var title_rect: Rect2 = _layout["header"]
	var title_size := maxi(12, int(round(float(_layout["title_size"]) * context.text_scale)))
	var title_measured := Orbitron.get_multiline_string_size(_title_text(), HORIZONTAL_ALIGNMENT_LEFT, maxf(title_rect.size.x - 20.0, 1.0), title_size)
	result.append({"id": "title", "fits": title_measured.x <= title_rect.size.x - 20.0 and title_measured.y <= title_rect.size.y, "measured_width": title_measured.x, "measured_height": title_measured.y, "available_width": title_rect.size.x - 20.0, "available_height": title_rect.size.y})
	var shell_meta_text := "ONLINE    KP://PATCH    GUEST" if context.density == "narrow" else "SYSTEM ONLINE    KP://PATCH    USER: GUEST"
	var shell_meta_measured := ShareTechMono.get_multiline_string_size(shell_meta_text, HORIZONTAL_ALIGNMENT_LEFT, maxf(_layout["shell_meta"].size.x - 16.0, 1.0), maxi(10, int(round(12.0 * context.text_scale))))
	result.append({"id": "shell_meta", "fits": shell_meta_measured.x <= _layout["shell_meta"].size.x - 16.0 and shell_meta_measured.y <= _layout["shell_meta"].size.y, "measured_width": shell_meta_measured.x, "measured_height": shell_meta_measured.y, "available_width": _layout["shell_meta"].size.x - 16.0, "available_height": _layout["shell_meta"].size.y})
	var subtitle_measured := ShareTechMono.get_multiline_string_size(_subtitle_text(), HORIZONTAL_ALIGNMENT_LEFT, maxf(title_rect.size.x - 20.0, 1.0), maxi(10, int(round(12.0 * context.text_scale))))
	result.append({"id": "subtitle", "fits": subtitle_measured.x <= title_rect.size.x - 20.0 and subtitle_measured.y <= title_rect.size.y, "measured_width": subtitle_measured.x, "measured_height": subtitle_measured.y, "available_width": title_rect.size.x - 20.0, "available_height": title_rect.size.y})
	var header_status := _header_status_text()
	var header_status_measured := ShareTechMono.get_multiline_string_size(header_status, HORIZONTAL_ALIGNMENT_LEFT, maxf(title_rect.size.x - 20.0, 1.0), maxi(10, int(round(11.0 * context.text_scale))))
	result.append({"id": "header_status", "fits": header_status_measured.x <= title_rect.size.x - 20.0 and header_status_measured.y <= title_rect.size.y, "measured_width": header_status_measured.x, "measured_height": header_status_measured.y, "available_width": title_rect.size.x - 20.0, "available_height": title_rect.size.y})
	var offers := _offers()
	var cards: Array = _layout["cards"]
	for index in offers.size():
		if bool(_layout["narrow"]) and index != _selected:
			continue
		for entry in _text_entries_for_offer(cards[0] if bool(_layout["narrow"]) else cards[index], offers[index]):
			var entry_rect: Rect2 = entry["rect"]
			var font: Font = Orbitron if int(entry["size"]) >= 20 else ShareTechMono
			var measured := font.get_multiline_string_size(str(entry["text"]), HORIZONTAL_ALIGNMENT_LEFT, maxf(entry_rect.size.x, 1.0), int(entry["size"]))
			var card_rect: Rect2 = cards[0] if bool(_layout["narrow"]) else cards[index]
			var content_limit := _evidence_rect(card_rect, bool(_layout["narrow"])).position.y - 8.0
			result.append({"id": "offer_%d_%s" % [index, entry["id"]], "fits": entry_rect.end.y <= content_limit and measured.x <= entry_rect.size.x and measured.y <= entry_rect.size.y, "measured_width": measured.x, "measured_height": measured.y, "available_width": entry_rect.size.x, "available_height": entry_rect.size.y, "content_limit": content_limit, "entry_bottom": entry_rect.end.y})
	var selected_offer: Dictionary = offers[_selected] if not offers.is_empty() else {}
	var evidence_rect: Rect2 = _layout["evidence_band"]
	if evidence_rect.size.x > 0.0 and evidence_rect.size.y > 0.0:
		var evidence_items := [
			{"id": "evidence_heading", "text": "PATCH REGISTER", "size": 10},
			{"id": "evidence_state", "text": "STATE " + _evidence_state_text(selected_offer), "size": 10},
		]
		if context.density != "narrow":
			evidence_items.append({"id": "evidence_build", "text": "BUILD " + _build_text(), "size": 10})
		evidence_items.append({"id": "evidence_next", "text": "NEXT " + _selected_next_text(selected_offer), "size": 10})
		for evidence_item in evidence_items:
			var evidence_size := maxi(10, int(round(float(evidence_item["size"]) * context.text_scale)))
			var evidence_measured := ShareTechMono.get_multiline_string_size(str(evidence_item["text"]), HORIZONTAL_ALIGNMENT_LEFT, maxf(evidence_rect.size.x - 28.0, 1.0), evidence_size)
			result.append({"id": evidence_item["id"], "fits": evidence_measured.x <= evidence_rect.size.x - 28.0 and evidence_measured.y <= evidence_rect.size.y, "measured_width": evidence_measured.x, "measured_height": evidence_measured.y, "available_width": evidence_rect.size.x - 28.0, "available_height": evidence_rect.size.y})
	if not bool(_layout["narrow"]):
		var footer_text := "BUILD %s    ACTIVE %02d    OFFER %02d/%02d" % [_build_text(), snapshot.get("active_ids", []).size(), _selected + 1, maxi(offers.size(), 1)]
		var footer_measured := ShareTechMono.get_multiline_string_size(footer_text, HORIZONTAL_ALIGNMENT_LEFT, maxf(_layout["footer"].size.x - 16.0, 1.0), maxi(10, int(round(11.0 * context.text_scale))))
		result.append({"id": "footer", "fits": footer_measured.x <= _layout["footer"].size.x - 16.0 and footer_measured.y <= _layout["footer"].size.y, "measured_width": footer_measured.x, "measured_height": footer_measured.y, "available_width": _layout["footer"].size.x - 16.0, "available_height": _layout["footer"].size.y})
	for id in action_regions():
		var action: Dictionary = action_regions()[id]
		var text := str(action.get("label", ""))
		var font_size := maxi(10, int(round(14.0 * context.text_scale)))
		var measured := ShareTechMono.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, maxf((action["rect"] as Rect2).size.x - 16.0, 1.0), font_size)
		var rect: Rect2 = action["rect"]
		result.append({"id": "action_%s" % id, "fits": measured.x <= rect.size.x - 16.0 and measured.y <= rect.size.y, "measured_width": measured.x, "measured_height": measured.y, "available_width": rect.size.x - 16.0, "available_height": rect.size.y})
	return result

func _draw() -> void:
	if context == null or _layout.is_empty():
		return
	var scale := float(context.text_scale)
	draw_rect(Rect2(Vector2.ZERO, size), Tokens.role_color("background"), true)
	Chrome.draw_shell(self, _layout["shell"], context.density, "KP://PATCH", context.text_scale, context.high_contrast)
	var header: Rect2 = _layout["header"]
	draw_string(Orbitron, header.position, _title_text(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(round(float(_layout["title_size"]) * scale)), Tokens.role_color("focus"))
	draw_string(ShareTechMono, header.position + Vector2(0.0, 28.0 * scale), _subtitle_text(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(round(12.0 * scale)), Tokens.role_color("muted"))
	draw_string(ShareTechMono, header.position + Vector2(0.0, 52.0 * scale), _header_status_text(), HORIZONTAL_ALIGNMENT_RIGHT, header.size.x, int(round(11.0 * scale)), Tokens.role_color("structure"))
	draw_line(header.position + Vector2(0.0, header.size.y - 8.0), header.end - Vector2(0.0, 8.0), Color(Tokens.role_color("structure"), 0.32), 1.0, true)
	var offers := _offers()
	var cards: Array = _layout["cards"]
	for index in offers.size():
		if bool(_layout["narrow"]) and index != _selected:
			continue
		_draw_offer_card(cards[0] if bool(_layout["narrow"]) else cards[index], offers[index], index)
	_draw_footer()
	_draw_action_frames()

func _draw_offer_card(rect: Rect2, offer: Dictionary, index: int) -> void:
	var selected := index == _selected
	var state := str(offer.get("state", "ready"))
	var role := "focus" if selected else ("danger" if state == "conflict" else "muted" if state in ["locked", "unavailable"] else "structure")
	var card_color := Tokens.role_color(role)
	draw_colored_polygon(Tokens.frame_points(rect, 14.0), Color(card_color.r, card_color.g, card_color.b, 0.08 if selected else 0.035))
	draw_polyline(Tokens.frame_points(rect, 14.0), card_color, 2.0 if selected else 1.0, true)
	draw_string(ShareTechMono, rect.position + Vector2(16.0, 18.0), "OFFER %02d/%02d" % [index + 1, maxi(_offers().size(), 1)], HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(round(10.0 * context.text_scale)), card_color)
	for entry in _text_entries_for_offer(rect, offer):
		var entry_rect: Rect2 = entry["rect"]
		var entry_font: Font = Orbitron if int(entry["size"]) >= 20 else ShareTechMono
		var entry_color := Tokens.role_color("focus") if entry["id"] == "identity" else card_color
		draw_multiline_string(entry_font, entry_rect.position + Vector2(0.0, float(entry["size"])), str(entry["text"]), HORIZONTAL_ALIGNMENT_LEFT, entry_rect.size.x, int(entry["size"]), 4, entry_color)
	if selected:
		Chrome.draw_evidence_block(self, _layout["evidence_band"], "PATCH REGISTER", _evidence_rows(offer, card_color), card_color, context.text_scale)

func _draw_footer() -> void:
	if bool(_layout["narrow"]):
		return
	var rect: Rect2 = _layout["footer"]
	var structure := Tokens.role_color("structure")
	var muted := Tokens.role_color("muted")
	draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color(structure.r, structure.g, structure.b, 0.42), 1.0, true)
	var font_size := int(round(11.0 * context.text_scale))
	draw_string(ShareTechMono, rect.position + Vector2(0.0, 17.0), "BUILD " + _build_text(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, structure)
	var right_text := "ACTIVE %02d    OFFER %02d/%02d" % [snapshot.get("active_ids", []).size(), _selected + 1, maxi(_offers().size(), 1)]
	draw_string(ShareTechMono, rect.end - Vector2(250.0, rect.size.y - 17.0), right_text, HORIZONTAL_ALIGNMENT_LEFT, 250.0, font_size, muted)

func _draw_action_frames() -> void:
	for id in _buttons:
		var button: Button = _buttons[id]
		if not button.visible:
			continue
		var rect := Rect2(button.position, button.size)
		var color := Tokens.role_color("focus") if _focus == id else Tokens.role_color("ready") if not button.disabled else Tokens.role_color("muted")
		draw_polyline(Tokens.frame_points(rect, 7.0), color, 1.6 if _focus == id else 0.9, true)

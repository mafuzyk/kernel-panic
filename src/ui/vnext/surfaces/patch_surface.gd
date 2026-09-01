class_name VNextPatchSurface
extends Control

const Context = preload("res://src/ui/vnext/ui_context.gd")
const Tokens = preload("res://src/ui/vnext/ui_tokens.gd")
const Orbitron: Font = preload("res://assets/fonts/Orbitron.ttf")
const ShareTechMono: Font = preload("res://assets/fonts/ShareTechMono.ttf")

signal action_requested(action_id: String, payload: Dictionary)

var context: RefCounted
var snapshot := {}
var _layout := {}
var _buttons := {}
var _focus := "confirm"
var _selected := 0
var _dispatched := false

static func context_for_viewport(viewport: Vector2, touch := false, reduced := false, contrast := false, scale := 1.0) -> RefCounted:
	return Context.from_viewport(viewport, touch, reduced, contrast, scale)

static func snapshot_from_offers(offers: Array, active_ids: Array = [], build := "") -> Dictionary:
	var copy: Array = []
	for offer in offers:
		copy.append((offer as Dictionary).duplicate(true))
	return {"offers": copy, "active_ids": active_ids.duplicate(true), "build": build, "paused": true}

func _ready() -> void:
	for spec in [{"name": "PreviousAction", "id": "previous", "text": "< PREVIOUS"}, {"name": "NextAction", "id": "next", "text": "NEXT >"}, {"name": "ConfirmAction", "id": "confirm", "text": ">> INSTALL PATCH"}, {"name": "SkipAction", "id": "skip", "text": "SKIP OFFER"}, {"name": "CloseAction", "id": "close", "text": "CLOSE"}]:
		var button := Button.new()
		button.name = spec["name"]
		button.text = spec["text"]
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.add_theme_font_override("font", ShareTechMono)
		button.pressed.connect(_dispatch.bind(spec["id"]))
		button.focus_entered.connect(func() -> void: _focus = spec["id"]; queue_redraw())
		add_child(button)
		_buttons[spec["id"]] = button

func configure(next_snapshot: Dictionary, next_context: RefCounted) -> void:
	snapshot = next_snapshot.duplicate(true)
	context = next_context
	_selected = clampi(_selected, 0, maxi(0, snapshot.get("offers", []).size() - 1))
	_dispatched = false
	_layout = _make_layout()
	_apply_layout()
	queue_redraw()

func configure_adapter(offers: Array, active_ids: Array, build: String, next_context: RefCounted) -> void:
	configure(snapshot_from_offers(offers, active_ids, build), next_context)

func _make_layout() -> Dictionary:
	var safe: Rect2 = context.safe_rect
	var narrow: bool = context.density == "narrow"
	var pad := 16.0 if narrow else 24.0
	var body := Rect2(safe.position + Vector2(pad, 108), Vector2(maxf(0.0, safe.size.x - pad * 2.0), maxf(0.0, safe.size.y - 250.0)))
	return {"safe": safe, "header": Rect2(safe.position + Vector2(pad, 18), Vector2(safe.size.x - pad * 2.0, 70.0)), "body": body, "narrow": narrow, "title_size": 22 if narrow else 28}

func _apply_layout() -> void:
	var body: Rect2 = _layout["body"]
	var narrow: bool = _layout["narrow"]
	var nav_y := body.end.y + 12.0
	_buttons["previous"].position = Vector2(body.position.x, nav_y)
	_buttons["previous"].size = Vector2(minf(170.0, body.size.x * 0.32), 44.0)
	_buttons["next"].position = Vector2(body.end.x - minf(170.0, body.size.x * 0.32), nav_y)
	_buttons["next"].size = Vector2(minf(170.0, body.size.x * 0.32), 44.0)
	_buttons["confirm"].position = Vector2(body.position.x, _layout["safe"].end.y - 56.0)
	_buttons["confirm"].size = Vector2(minf(260.0, body.size.x), 44.0)
	_buttons["skip"].position = Vector2(_layout["safe"].end.x - minf(150.0, body.size.x), _layout["safe"].end.y - 56.0)
	_buttons["skip"].size = Vector2(minf(150.0, body.size.x), 44.0)
	_buttons["close"].position = Vector2(_layout["safe"].end.x - 130.0, _layout["safe"].position.y)
	_buttons["close"].size = Vector2(130.0, 44.0)
	_buttons["previous"].visible = narrow
	_buttons["next"].visible = narrow
	_buttons["close"].visible = true
	_buttons["confirm"].disabled = snapshot.get("offers", []).is_empty()
	queue_redraw()

func _dispatch(id: String) -> bool:
	if _dispatched and id in ["confirm", "skip", "close"]:
		return false
	if id == "previous":
		_selected = posmod(_selected - 1, maxi(1, snapshot.get("offers", []).size()))
	elif id == "next":
		_selected = posmod(_selected + 1, maxi(1, snapshot.get("offers", []).size()))
	else:
		_dispatched = true
		action_requested.emit(id, {"index": _selected, "offer": snapshot.get("offers", [])[ _selected ] if not snapshot.get("offers", []).is_empty() else {}})
	queue_redraw()
	return true

func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed:
		return _action_at((event as InputEventMouseButton).position)
	if event is InputEventScreenTouch and event.pressed:
		return _action_at((event as InputEventScreenTouch).position)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_LEFT and _layout["narrow"]:
			return _dispatch("previous")
		if event.keycode == KEY_RIGHT and _layout["narrow"]:
			return _dispatch("next")
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			return _dispatch(_focus)
	return false

func _action_at(point: Vector2) -> bool:
	for id in _buttons:
		var button: Button = _buttons[id]
		if button.visible and Rect2(button.position, button.size).has_point(point):
			_focus = id
			return _dispatch(id)
	return false

func set_focus_id(id: String) -> bool:
	if not _buttons.has(id): return false
	_focus = id
	(_buttons[id] as Button).grab_focus()
	return true

func focus_id() -> String: return _focus
func layout_snapshot() -> Dictionary: return {"density": context.density, "safe_rect": context.safe_rect, "regions": _layout.duplicate(true)}

func action_regions() -> Dictionary:
	var result := {}
	for id in _buttons:
		if _buttons[id].visible: result[id] = {"rect": Rect2(_buttons[id].position, _buttons[id].size), "label": _buttons[id].text, "state": "ready"}
	return result

func semantic_snapshot() -> Dictionary:
	var offers: Array = snapshot.get("offers", [])
	var offer: Dictionary = offers[_selected] if not offers.is_empty() else {}
	var relation := ""
	if not offers.is_empty(): relation = Game.patch_tooltip_data(str(offer.get("id", "")), snapshot.get("active_ids", [])).get("relation", "")
	return {"screen": "patch_offer", "offers": offers.duplicate(true), "selected": _selected, "focus": _focus, "build": snapshot.get("build", ""), "conflict": relation, "paused": snapshot.get("paused", false)}

func text_overflow_report() -> Array:
	var entries := [{"id": "title", "text": "PATCH OFFER // BUILD DECISION", "rect": _layout["header"], "size": _layout["title_size"]}]
	var offers: Array = snapshot.get("offers", [])
	if not offers.is_empty(): entries.append({"id": "offer", "text": str(offers[_selected].get("title", "PATCH")) + "\n" + str(offers[_selected].get("desc", "")), "rect": _layout["body"], "size": 18})
	var result := []
	for entry in entries:
		var font: Font = Orbitron if entry["size"] >= 24 else ShareTechMono
		var measured := font.get_multiline_string_size(entry["text"], HORIZONTAL_ALIGNMENT_LEFT, maxf(entry["rect"].size.x - 24.0, 1.0), int(entry["size"] * context.text_scale))
		result.append({"id": entry["id"], "fits": measured.x <= entry["rect"].size.x - 24.0 and measured.y <= entry["rect"].size.y, "measured_width": measured.x})
	return result

func _draw() -> void:
	if _layout.is_empty(): return
	var safe: Rect2 = _layout["safe"]
	draw_rect(safe, Tokens.role_color("background"), true)
	draw_polyline(Tokens.frame_points(_layout["body"], 18.0), Tokens.role_color("structure"), 2.0, true)
	draw_string(Orbitron, _layout["header"].position, "PATCH OFFER // BUILD DECISION", HORIZONTAL_ALIGNMENT_LEFT, -1.0, _layout["title_size"], Tokens.role_color("focus"))
	var offers: Array = snapshot.get("offers", [])
	if not offers.is_empty():
		var offer: Dictionary = offers[_selected]
		draw_string(ShareTechMono, _layout["body"].position + Vector2(20, 48), str(offer.get("title", "PATCH")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Tokens.role_color("ready"))
		draw_multiline_string(ShareTechMono, _layout["body"].position + Vector2(20, 86), str(offer.get("desc", "")), HORIZONTAL_ALIGNMENT_LEFT, _layout["body"].size.x - 40.0, 18, 0, Tokens.role_color("structure"))

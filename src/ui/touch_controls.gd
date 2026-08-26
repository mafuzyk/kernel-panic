class_name TouchControls
extends Control

var player: Player
var arena: Arena
var debug_touch_count := 0
var _move_id := -1
var _move_origin := Vector2.ZERO
var _move_vec := Vector2.ZERO
var _aim_id := -1
var _aim_origin := Vector2.ZERO
var _aim_pos := Vector2.ZERO
var _aim_active := false
var t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		debug_touch_count += 1
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if _pause_btn().has_point(t.position):
				if arena != null and is_inside_tree() and not get_tree().paused:
					arena._set_paused(true)
				return
			if t.position.y <= 70.0:
				return
			if t.position.x < size.x * 0.4 and t.position.y > 70.0 and _move_id == -1:
				_move_id = t.index
				_move_origin = t.position
			elif t.position.x >= size.x * 0.4 and _aim_id == -1 and t.position.y > 70.0:
				if _dash_btn().has_point(t.position):
					_press_dash()
					return
				if _oc_btn().has_point(t.position) and player != null and player.oc_ready:
					player.try_overclock()
					return
				_aim_id = t.index
				_aim_origin = t.position
				_aim_pos = t.position
				_aim_active = true
				if player != null and is_instance_valid(player):
					var press_mode := Game.effective_aim_mode()
					if press_mode == "lockon":
						player.touch_aim = Vector2.ZERO
					elif press_mode == "stick":
						player.touch_aim = Vector2.ZERO
		else:
			if t.index == _move_id:
				_move_id = -1
				_move_vec = Vector2.ZERO
			elif t.index == _aim_id:
				_aim_id = -1
				_aim_active = false
				if player != null and is_instance_valid(player):
					player.touch_aim = Vector2.ZERO
					player.aim_assist_dir = Vector2.ZERO
			elif t.index == _move_id:
				pass
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _move_id:
			var off := d.position - _move_origin
			if off.length() > 110.0:
				_move_origin = d.position - off.normalized() * 110.0
				off = off.normalized() * 110.0
			_move_vec = off / 90.0
			if _move_vec.length() > 1.0:
				_move_vec = _move_vec.normalized()
		elif d.index == _aim_id:
			_aim_pos = d.position
			if player != null and is_instance_valid(player):
				var aim_mode := Game.effective_aim_mode()
				if aim_mode == "lockon":
					player.touch_aim = Vector2.ZERO
				elif aim_mode == "stick":
					var off := (_aim_pos - _aim_origin).limit_length(110.0)
					player.touch_aim = off if off.length() > 10.0 else Vector2.ZERO
				else:
					var raw := _aim_pos - _aim_origin
					player.touch_aim = raw if raw.length() > 14.0 else Vector2.ZERO

func _sc() -> float:
	return Sfx.touch_scale

func _dash_btn() -> Rect2:
	var s := 120.0 * _sc()
	return Rect2(size.x - s - 40.0 * _sc(), size.y - s - 36.0, s, s)

func _oc_btn() -> Rect2:
	var s := 120.0 * _sc()
	return Rect2(size.x - s - 40.0 * _sc(), size.y - s * 2 - 36.0 - 22.0, s, s)

func _pause_btn() -> Rect2:
	var w := 76.0 * _sc()
	return Rect2(size.x * 0.5 - w * 0.5, 12.0, w, 54.0 * _sc())

var _tex_dash: Texture2D = preload("res://assets/icons/icon_dash.png")
var _tex_pause: Texture2D = preload("res://assets/icons/icon_pause.png")
var _tex_oc: Texture2D = preload("res://assets/icons/icon_overclock.png")

func _press_dash() -> void:
	if player == null or not is_instance_valid(player):
		return
	player.request_dash(_move_vec)

func _process(delta: float) -> void:
	t += delta
	if player != null and is_instance_valid(player):
		player.touch_move = _move_vec
		player.touch_fire = _aim_active
		if _aim_active and Game.effective_aim_mode() == "lockon":
			player.lockon_active = true
		else:
			player.lockon_active = false
	queue_redraw()

func _draw() -> void:
	var c := Balance.COL_PLAYER
	var mono: Font = load("res://assets/fonts/ShareTechMono.ttf")
	var pb := _pause_btn()
	draw_arc(pb.get_center(), pb.size.y * 0.42, 0, TAU, 32, Color(c.r, c.g, c.b, 0.5), 2.0, true)
	var psize := pb.size.y * 0.5
	draw_texture_rect(_tex_pause, Rect2(pb.get_center() - Vector2(psize, psize) * 0.5, Vector2(psize, psize)), false, Color(1, 1, 1, 0.85))
	if _move_id != -1:
		draw_circle(_move_origin, 64.0, Color(c.r, c.g, c.b, 0.08))
		draw_arc(_move_origin, 64.0, 0, TAU, 40, Color(c.r, c.g, c.b, 0.4), 2.0, true)
		draw_circle(_move_origin + _move_vec * 48.0, 22.0, Color(c.r, c.g, c.b, 0.35))
	if not _aim_active:
		return
	var draw_mode := Game.effective_aim_mode()
	if draw_mode == "stick":
		draw_circle(_aim_origin, 44.0, Color(c.r, c.g, c.b, 0.07))
		draw_arc(_aim_origin, 44.0, 0, TAU, 32, Color(c.r, c.g, c.b, 0.45), 2.0, true)
		var knob := _aim_origin + (_aim_pos - _aim_origin).limit_length(44.0)
		draw_circle(knob, 16.0, Color(1, 1, 1, 0.2))
		draw_arc(knob, 16.0, 0, TAU, 20, Color(1, 1, 1, 0.6), 2.0, true)
		draw_line(_aim_origin, knob, Color(c.r, c.g, c.b, 0.3), 2.0)
	elif draw_mode == "lockon":
		draw_circle(_aim_origin, 26.0, Color(c.r, c.g, c.b, 0.06))
		draw_arc(_aim_origin, 26.0, 0, TAU, 32, Color(c.r, c.g, c.b, 0.45), 2.0, true)
		draw_string(mono, _aim_origin + Vector2(-34, -32), "LOCK", HORIZONTAL_ALIGNMENT_CENTER, 80, 12, Color(1, 0.4, 0.5, 0.8))
	else:
		draw_circle(_aim_origin, 26.0, Color(c.r, c.g, c.b, 0.06))
		draw_arc(_aim_origin, 26.0, 0, TAU, 32, Color(c.r, c.g, c.b, 0.45), 2.0, true)
		draw_line(_aim_origin, _aim_pos, Color(c.r, c.g, c.b, 0.3), 2.0)
		draw_circle(_aim_pos, 10.0, Color(1, 1, 1, 0.15))
		draw_arc(_aim_pos, 10.0, 0, TAU, 20, Color(1, 1, 1, 0.6), 2.0, true)
	var db := _dash_btn()
	var dash_ready := player == null or not is_instance_valid(player) or player.dash_cd <= 0.0
	var dc := Color(c.r, c.g, c.b, 0.4) if dash_ready else Color(c.r, c.g, c.b, 0.18)
	var dr := db.size.x * 0.44
	draw_arc(db.get_center(), dr, 0, TAU, 40, dc, 2.5, true)
	if not dash_ready and player != null and is_instance_valid(player):
		var frac := clampf(1.0 - player.dash_cd / (Balance.DASH_CD * pow(0.82, Game.patch_level("dash"))), 0.0, 1.0)
		draw_arc(db.get_center(), dr, -PI / 2.0, -PI / 2.0 + TAU * frac, 32, Color(c.r, c.g, c.b, 0.8), 3.5, true)
	var dsize := db.size.x * 0.46
	var dcol := Color(1, 1, 1, 1.0 if dash_ready else 0.35)
	draw_texture_rect(_tex_dash, Rect2(db.get_center() - Vector2(dsize, dsize) * 0.5, Vector2(dsize, dsize)), false, dcol)
	draw_string(mono, db.get_center() + Vector2(-30, db.size.y * 0.42), "DASH", HORIZONTAL_ALIGNMENT_CENTER, 60, 13 * _sc(), Color(c.r, c.g, c.b, 0.75))
	var ob := _oc_btn()
	if player != null and is_instance_valid(player) and player.oc_ready:
		var hot := Balance.COL_PLAYER_HOT
		hot.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() / 120.0))
		draw_arc(ob.get_center(), ob.size.x * 0.44, 0, TAU, 40, hot, 3.0, true)
	var osize := ob.size.x * 0.5
	var ocol := Color(1, 1, 1, 1.0 if (player != null and is_instance_valid(player) and player.oc_ready) else 0.4)
	draw_texture_rect(_tex_oc, Rect2(ob.get_center() - Vector2(osize, osize) * 0.5, Vector2(osize, osize)), false, ocol)
	draw_string(mono, ob.get_center() + Vector2(-34, ob.size.y * 0.42), "BOOST", HORIZONTAL_ALIGNMENT_CENTER, 80, 13 * _sc(), Color(c.r, c.g, c.b, 0.8 if (player != null and is_instance_valid(player) and player.oc_ready) else 0.4))

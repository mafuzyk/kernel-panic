class_name FirewallEnemy
extends EnemyBase

var _anchor := Vector2.ZERO
var _settled := false
var _wall_angle := 0.0
var _wall_t := 0.0

const COL_FIREWALL := Color("37d8ff")
const WALL_ARMS := 5
const WALL_RADIUS := 120.0
const ORB_SPEED := 170.0

func _init() -> void:
	display_name = "FIREWALL"
	hp = 6
	speed = 90.0
	pts = 180
	radius = 16.0
	col = COL_FIREWALL

func _on_ready() -> void:
	var r := Balance.arena_rect()
	for attempt in 12:
		_anchor = Vector2(Game.rng.randf_range(r.position.x + 80.0, r.end.x - 80.0), Game.rng.randf_range(r.position.y + 80.0, r.end.y - 80.0))
		if not is_instance_valid(player) or _anchor.distance_to(player.global_position) > 260.0:
			break
	add_to_group("firewall")

func die() -> void:
	for orb in get_tree().get_nodes_in_group("enemy_orbs"):
		if is_instance_valid(orb) and orb.get_meta("fw_owner", -1) == get_instance_id():
			orb.pop()
	super.die()

func _move(delta: float) -> void:
	if not _settled:
		var to_anchor := (_anchor - global_position)
		if to_anchor.length() < 12.0:
			_settled = true
		else:
			return  # vel handled below
	if _settled:
		_wall_t -= delta
		_wall_angle += delta * 0.6
		if _wall_t <= 0.0:
			_wall_t = 0.5
			_refresh_wall()

func vel() -> Vector2:
	if _settled:
		return Vector2.ZERO
	var desired := (_anchor - global_position).normalized()
	desired += steer_separation(2.4) * 0.7
	return desired.limit_length(1.0) * speed

func _refresh_wall() -> void:
	for i in WALL_ARMS:
		if not EnemyOrb.can_spawn(self):
			return
		var dir := Vector2.from_angle(_wall_angle + TAU * i / float(WALL_ARMS))
		var pos := global_position + dir * WALL_RADIUS
		var existing: Node = null
		for orb in get_tree().get_nodes_in_group("enemy_orbs"):
			if is_instance_valid(orb) and orb.get_meta("fw_owner", -1) == get_instance_id() and orb.get_meta("fw_arm", -1) == i:
				existing = orb
				break
		if existing != null and is_instance_valid(existing):
			continue
		var orb := EnemyOrb.new()
		orb.setup(pos, dir * 0.15, ORB_SPEED, col)
		orb.set_meta("fw_owner", get_instance_id())
		orb.set_meta("fw_arm", i)
		get_parent().call_deferred("add_child", orb)

func _draw() -> void:
	var c := _flash_col(col)
	var r := radius
	GlyphLib.draw_glyph(self, "firewall", Vector2.ZERO, r, _glyph_color(c), t)
	for i in WALL_ARMS:
		var p := Vector2.from_angle(_wall_angle + TAU * i / float(WALL_ARMS)) * (WALL_RADIUS - 14.0)
		draw_circle(p, 3.5, Color(c.r, c.g, c.b, 0.55))
		draw_line(Vector2.from_angle(_wall_angle + TAU * i / float(WALL_ARMS)) * (r + 6.0), p, Color(c.r, c.g, c.b, 0.25), 1.2)
	if elite:
		draw_arc(Vector2.ZERO, r + 5.0, 0, TAU, 24, Color(1, 1, 1, 0.75), 1.6, true)

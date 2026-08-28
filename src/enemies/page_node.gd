class_name PageNode
extends EnemyBase

var boss: RootBoss
var orbit_idx := 0
var _v := Vector2.ZERO
var _fire_t := 2.0

func _init() -> void:
	display_name = "PAGE"
	hp = 3
	speed = 0.0
	pts = 60
	radius = 13.0
	col = Color("b46bff")
	mote_count = 1

func _ready() -> void:
	super._ready()
	add_to_group("page")

func _move(delta: float) -> void:
	if boss == null or not is_instance_valid(boss):
		var to_player := player.global_position - global_position if player != null and is_instance_valid(player) else Vector2.ZERO
		var desired := steer_distance_band(to_player, 170.0, 300.0, 1.0, 0.65)
		if player != null and is_instance_valid(player):
			desired += steer_open_space(to_player, 170.0, 1.0) * 0.85
		_v = _v.move_toward(desired.limit_length(1.0) * 60.0, 200.0 * delta)
		position += _v * delta
		return
	var anchor: Vector2 = boss.global_position
	var target := anchor + Vector2.from_angle(t * 0.9 + TAU * orbit_idx / 4.0) * 92.0
	var dir := (target - global_position)
	_v = dir.limit_length(340.0)
	_fire_t -= delta
	if _fire_t <= 0.0:
		_fire_t = 2.4
		if player != null and is_instance_valid(player) and EnemyOrb.can_spawn(self):
			var orb := EnemyOrb.new()
			orb.setup(global_position, aim_at_player(), 250.0, col)
			get_parent().call_deferred("add_child", orb)
			Sfx.play("shoot", 0.7, -10.0)

func vel() -> Vector2:
	return Vector2.ZERO

func _draw() -> void:
	var c := _flash_col(col)
	var s := radius
	rotation = sin(t * 2.0 + orbit_idx) * 0.2
	var pts := PackedVector2Array([
		Vector2(-s, -s * 1.2), Vector2(s * 0.8, -s), Vector2(s, s * 1.2), Vector2(-s * 0.8, s)
	])
	draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.18))
	draw_polyline(pts + PackedVector2Array([pts[0]]), c, 2.0, true)
	for i in 2:
		draw_line(Vector2(-s * 0.5, -s * 0.4 + i * s * 0.6), Vector2(s * 0.5, -s * 0.4 + i * s * 0.6), Color(c.r, c.g, c.b, 0.5), 1.5)
	if hp <= 1:
		draw_arc(Vector2.ZERO, s + 4.0, 0, TAU, 20, Color(1, 1, 1, 0.4), 1.5, true)

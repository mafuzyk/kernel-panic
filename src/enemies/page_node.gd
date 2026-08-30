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
	GlyphLib.draw_glyph(self, "page", Vector2.ZERO, s, _glyph_color(c), t)
	if hp <= 1:
		draw_arc(Vector2.ZERO, s + 4.0, 0, TAU, 20, Color(1, 1, 1, 0.4), 1.5, true)

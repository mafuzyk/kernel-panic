class_name BulwarkEnemy
extends EnemyBase

var _v := Vector2.ZERO
var _nova_pending := false

func _init() -> void:
	display_name = "BULWARK"
	hp = 14
	speed = 55.0
	pts = 300
	radius = 26.0
	col = Balance.threat_color("bulwark", Sfx.color_assist)

func _move(delta: float) -> void:
	var desired := steer_approach(aim_at_player(), flank_sign, flank_weight)
	desired += steer_separation(2.2) * 0.7
	_v = _v.move_toward(desired.limit_length(1.0) * speed, 200.0 * delta)

func vel() -> Vector2:
	return _v

func take_hit(dmg: int, from: Vector2) -> void:
	super.take_hit(dmg, from)
	if hp > 0:
		Sfx.play("hit", 0.6, -8.0)

func die() -> void:
	if _nova_pending or dead:
		return
	_nova_pending = true
	dead = true
	died.emit(self)
	var pos := global_position
	var parent := get_parent()
	var c := col
	var wave_scale_f := 1.0
	Fx.burst(pos, c, 2.2, 12)
	Fx.hitstop(70.0)
	Sfx.play("explode_big", randf_range(0.9, 1.05), -2.0)
	Fx.ring(pos, c, 8.0, 130.0, 0.55, 4.0, true)
	for i in 8:
		if EnemyOrb.can_spawn(self):
			_spawn_nova_orb(parent, pos, TAU * i / 8.0 + 0.2, wave_scale_f)
	queue_free()

func _spawn_nova_orb(parent: Node, pos: Vector2, angle: float, _ws: float) -> void:
	var orb := EnemyOrb.new()
	orb.setup(pos + Vector2.from_angle(angle) * 30.0, Vector2.from_angle(angle), 210.0, col)
	parent.add_child(orb)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	rotation = lerp_angle(rotation, aim_at_player().angle(), 2.2 * delta)

func _draw() -> void:
	var c := _flash_col(col)
	var r := radius
	GlyphLib.draw_glyph(self, "bulwark", Vector2.ZERO, r, _glyph_color(c), t)
	var hp_frac := float(hp) / float(max_hp)
	draw_arc(Vector2.ZERO, r + 7.0, -PI / 2, -PI / 2 + TAU * hp_frac, 28, Color(c.r, c.g, c.b, 0.5), 2.0, true)
	if elite:
		draw_arc(Vector2.ZERO, r + 11.0, 0, TAU, 32, Color(1, 1, 1, 0.75), 1.8, true)

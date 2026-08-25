class_name Mote
extends Area2D

var vel := Vector2.ZERO
var life := Balance.MOTE_LIFE
var player: Node2D
var _t := 0.0
var _magnet := false
var _force_collect := false
var stolen := false

func setup(pos: Vector2) -> void:
	position = pos
	vel = Vector2.from_angle(randf() * TAU) * randf_range(50.0, 170.0)

func _ready() -> void:
	add_to_group("motes")
	collision_layer = Balance.LAYER_MOTE
	collision_mask = 0
	monitorable = true
	monitoring = false
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 10.0
	cs.shape = sh
	add_child(cs)
	var glow := Fx.make_glow(7.0, Balance.COL_MOTE)
	glow.modulate.a = 0.55
	add_child(glow)
	z_index = 8

func _physics_process(delta: float) -> void:
	_t += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if stolen:
		queue_redraw()
		return
	if player != null and is_instance_valid(player):
		var d := global_position.distance_to(player.global_position)
		var mag: float = player.magnet_radius()
		if _force_collect or d < mag:
			_magnet = true
		if _magnet and d > 1.0:
			var pull := (player.global_position - global_position).normalized()
			vel = vel.move_toward(pull * 560.0, 2600.0 * delta)
		if d < 20.0:
			player.collect_mote()
			Fx.sparks(global_position, Balance.COL_MOTE, 4, 120.0, 0.25, 2.0)
			queue_free()
			return
	vel = vel.move_toward(Vector2.ZERO, 260.0 * delta) if not _magnet else vel
	position += vel * delta
	queue_redraw()

func force_collect() -> void:
	_force_collect = true
	_magnet = true

func _draw() -> void:
	var blink := life < 2.5 and fmod(life, 0.22) < 0.11
	if blink:
		return
	var pulse := 1.0 + 0.18 * sin(_t * 7.0)
	var s := 5.2 * pulse
	var pts := PackedVector2Array([
		Vector2(0, -s), Vector2(s * 0.7, 0), Vector2(0, s), Vector2(-s * 0.7, 0)
	])
	draw_colored_polygon(pts, Balance.COL_MOTE)
	draw_circle(Vector2.ZERO, s * 0.45, Color(1, 1, 1, 0.85))

class_name RecoverPickup
extends Area2D

var life := 10.0
var player: Node2D
var _t := 0.0

const COL_RECOVER := Color("52ff7a")

func setup(pos: Vector2, target: Node2D) -> void:
	position = pos
	player = target

func _ready() -> void:
	collision_layer = Balance.LAYER_MOTE
	collision_mask = 0
	monitorable = true
	monitoring = false
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 22.0
	cs.shape = sh
	add_child(cs)
	var glow := Fx.make_glow(12.0, COL_RECOVER)
	glow.modulate.a = 0.6
	add_child(glow)
	z_index = 9

func _physics_process(delta: float) -> void:
	_t += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if player != null and is_instance_valid(player):
		if global_position.distance_to(player.global_position) < 24.0 and not player.dead:
			_collect()
			return
	queue_redraw()

func _collect() -> void:
	if player.has_method("heal"):
		player.heal(1)
		if player.has_method("get") and Game.stats.has("heals"):
			Game.register_heal("recover")
	Fx.text(global_position + Vector2(0, -26), "+1 INTEGRITY", COL_RECOVER, 14)
	Fx.sparks(global_position, COL_RECOVER, 8, 160.0, 0.35, 2.5)
	Fx.ring(global_position, COL_RECOVER, 6.0, 46.0, 0.3, 2.5)
	Sfx.play("ready", 1.25, -4.0)
	Sfx.haptic(30)
	queue_free()

func _draw() -> void:
	if life < 2.5 and fmod(life, 0.24) < 0.12:
		return
	var pulse := 1.0 + 0.16 * sin(_t * 7.0)
	var s := 9.0 * pulse
	var w := s * 0.32
	var c := COL_RECOVER
	draw_colored_polygon(PackedVector2Array([Vector2(-w, -s), Vector2(w, -s), Vector2(w, s), Vector2(-w, s)]), c)
	draw_colored_polygon(PackedVector2Array([Vector2(-s, -w), Vector2(s, -w), Vector2(s, w), Vector2(-s, w)]), c)
	draw_circle(Vector2.ZERO, s * 0.3, Color(1, 1, 1, 0.9))

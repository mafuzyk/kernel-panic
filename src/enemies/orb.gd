class_name EnemyOrb
extends Area2D

static func can_spawn(from: Node) -> bool:
	return from.get_tree().get_nodes_in_group("enemy_orbs").size() < 40

var vel := Vector2.ZERO
var life := 5.0
var col: Color = Balance.COL_SPEWER

func setup(pos: Vector2, dir: Vector2, speed: float, color: Color) -> void:
	position = pos
	vel = dir * speed
	col = color

func _ready() -> void:
	add_to_group("enemy_orbs")
	collision_layer = Balance.LAYER_EORB
	collision_mask = 0
	monitorable = true
	monitoring = false
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 8.0
	cs.shape = sh
	add_child(cs)
	var glow := Fx.make_glow(9.0, col)
	glow.modulate.a = 0.5
	add_child(glow)
	z_index = 10

func _physics_process(delta: float) -> void:
	position += vel * delta
	life -= delta
	if life <= 0.0 or not Balance.arena_rect().grow(24.0).has_point(position):
		queue_free()
		return
	queue_redraw()

func pop() -> void:
	Fx.sparks(global_position, col, 6, 180.0, 0.3, 2.2)
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 7.0, Color(col.r, col.g, col.b, 0.28))
	draw_circle(Vector2.ZERO, 4.6, col)
	draw_circle(Vector2.ZERO, 2.2, Color(1, 1, 1, 0.9))
	var tail := -vel.normalized() * 10.0
	draw_line(tail, tail * 0.4, Color(col.r, col.g, col.b, 0.5), 2.5)

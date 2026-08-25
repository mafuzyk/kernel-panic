class_name PlayerBullet
extends Area2D

var vel := Vector2.ZERO
var pierce := 0
var dmg := 1
var bounces := 0
var life := Balance.BULLET_LIFE
var _hit_done: Dictionary = {}

func setup(pos: Vector2, dir: Vector2, hot: bool) -> void:
	position = pos
	vel = dir * Balance.BULLET_SPEED
	pierce = 1 if hot else 0
	rotation = dir.angle()

func _ready() -> void:
	collision_layer = Balance.LAYER_PBULLET
	collision_mask = Balance.LAYER_ENEMY | Balance.LAYER_EORB
	monitoring = true
	monitorable = false
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 5.0
	cs.shape = sh
	add_child(cs)
	area_entered.connect(_on_area)
	z_index = 12

func _physics_process(delta: float) -> void:
	position += vel * delta
	life -= delta
	var r := Balance.arena_rect()
	if life <= 0.0:
		_die()
		return
	if not r.grow(6.0).has_point(position):
		if bounces > 0:
			bounces -= 1
			if position.x < r.position.x + 6.0 or position.x > r.end.x - 6.0:
				vel.x = -vel.x
				position.x = clampf(position.x, r.position.x + 7.0, r.end.x - 7.0)
			if position.y < r.position.y + 6.0 or position.y > r.end.y - 6.0:
				vel.y = -vel.y
				position.y = clampf(position.y, r.position.y + 7.0, r.end.y - 7.0)
			rotation = vel.angle()
			Fx.sparks(position, Balance.COL_BULLET, 3, 120.0, 0.2, 2.0)
			return
		if not r.grow(30.0).has_point(position):
			_die()
			return

func _on_area(a: Area2D) -> void:
	if a is EnemyOrb:
		a.pop()
		Fx.sparks(global_position, Balance.COL_BULLET, 4, 160.0, 0.25, 2.0)
		Game.stats["hits"] += 1
		Game.add_score(5)
		if pierce > 0:
			pierce -= 1
		else:
			_die()
		return
	if a.has_method("take_hit") and not _hit_done.has(a.get_instance_id()):
		_hit_done[a.get_instance_id()] = true
		a.take_hit(dmg, global_position)
		Fx.sparks(global_position, Balance.COL_BULLET, 4, 160.0, 0.25, 2.0)
		Game.stats["hits"] += 1
		if pierce > 0:
			pierce -= 1
		else:
			_die()

func _die() -> void:
	set_deferred("monitoring", false)
	queue_free()

func _draw() -> void:
	var c := Balance.COL_BULLET
	draw_line(Vector2(-13, 0), Vector2(5, 0), Color(c.r, c.g, c.b, 0.4), 4.5)
	draw_line(Vector2(-8, 0), Vector2(4, 0), c, 3.6)
	draw_circle(Vector2(4, 0), 3.0, Color(1, 1, 1, 0.95))

class_name CorruptionShot
extends EnemyOrb

var direction := Vector2.RIGHT
var target_point := Vector2.ZERO
var midpoint_distance := 0.0
var travelled := 0.0
var shot_speed := 280.0
var damage := 1
var resolved := false

func setup_corruption(pos: Vector2, target: Vector2, direct_damage: int, color: Color, forced_direction := Vector2.ZERO) -> void:
	position = pos
	target_point = target
	direction = forced_direction.normalized() if forced_direction.length_squared() > 0.0001 else (target - pos).normalized()
	if direction.length_squared() <= 0.0001:
		direction = Vector2.RIGHT
	vel = direction * shot_speed
	damage = direct_damage
	col = color
	midpoint_distance = pos.distance_to(target) * 0.5
	travelled = 0.0
	resolved = false
	life = 3.0

func _ready() -> void:
	super._ready()
	add_to_group("corruption_shots")
	collision_mask = Balance.LAYER_PLAYER
	monitoring = true
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if resolved:
		return
	var step := vel * delta
	position += step
	travelled += step.length()
	life -= delta
	if travelled >= midpoint_distance or life <= 0.0:
		burst_into_zone()
		return
	if not Balance.arena_rect().grow(36.0).has_point(position):
		burst_into_zone()
		return
	queue_redraw()

func _on_area_entered(area: Area2D) -> void:
	if resolved:
		return
	if area is Player:
		if travelled < midpoint_distance:
			resolved = true
			area.take_damage(global_position, "CORRUPTION SHOT")
			queue_free()
		else:
			burst_into_zone()

func pop() -> void:
	resolved = true
	queue_free()

func burst_into_zone() -> void:
	if resolved:
		return
	resolved = true
	if get_parent() != null:
		var zone := CorruptionZone.new()
		zone.position = global_position
		zone.radius = 38.0
		get_parent().call_deferred("add_child", zone)
	Fx.ring(global_position, col, 8.0, 48.0, 0.28, 2.4)
	Fx.sparks(global_position, col, 8, 180.0, 0.35, 2.4)
	queue_free()

func _draw() -> void:
	var c := col
	draw_line(Vector2(-16.0, 0), Vector2(8.0, 0), Color(c.r, c.g, c.b, 0.35), 5.0)
	draw_line(Vector2(-10.0, 0), Vector2(7.0, 0), c, 3.0)
	draw_circle(Vector2(8.0, 0), 4.0, Color(1, 0.8, 0.85, 0.9))
	draw_arc(Vector2.ZERO, 9.0, 0, TAU, 16, Color(c.r, c.g, c.b, 0.7), 1.4, true)

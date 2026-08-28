class_name CorruptionShot
extends EnemyOrb

var direction := Vector2.RIGHT
var origin_point := Vector2.ZERO
var target_point := Vector2.ZERO
var target_actor: Node2D
var midpoint_distance := 0.0
var target_distance := 0.0
var travelled := 0.0
var shot_speed := 280.0
var damage := 1
var resolved := false

func setup_corruption(pos: Vector2, target: Vector2, direct_damage: int, color: Color, forced_direction := Vector2.ZERO, target_node: Node2D = null) -> void:
	position = pos
	origin_point = pos
	target_point = target
	target_actor = target_node
	direction = forced_direction.normalized() if forced_direction.length_squared() > 0.0001 else (target - pos).normalized()
	if direction.length_squared() <= 0.0001:
		direction = Vector2.RIGHT
	vel = direction * shot_speed
	damage = direct_damage
	col = color
	target_distance = pos.distance_to(target)
	midpoint_distance = target_distance * 0.5
	travelled = 0.0
	resolved = false
	life = 3.0

func _ready() -> void:
	super._ready()
	add_to_group("corruption_shots")
	collision_mask = Balance.LAYER_PLAYER
	monitoring = true
	area_entered.connect(_on_area_entered)
	if not is_instance_valid(target_actor):
		var nearest: Node2D = null
		var nearest_distance := INF
		for candidate in get_tree().get_nodes_in_group("player"):
			if candidate is Node2D and is_instance_valid(candidate):
				var candidate_distance: float = candidate.global_position.distance_to(target_point)
				if candidate_distance < nearest_distance:
					nearest_distance = candidate_distance
					nearest = candidate
		target_actor = nearest

func _segment_intersects_player(candidate: Node2D) -> bool:
	if not is_instance_valid(candidate):
		return false
	var candidate_offset := candidate.global_position - origin_point
	var projection := candidate_offset.dot(direction)
	if projection < 0.0 or projection > target_distance:
		return false
	var closest := origin_point + direction * projection
	return closest.distance_to(candidate.global_position) <= Balance.PLAYER_RADIUS + 8.0

func _impact_player(player: Player) -> void:
	if resolved:
		return
	resolved = true
	player.take_damage(global_position, "CORRUPTION SHOT")
	queue_free()

func _physics_process(delta: float) -> void:
	if resolved:
		return
	var step := vel * delta
	position += step
	travelled += step.length()
	life -= delta
	if target_actor is Player:
		if _segment_intersects_player(target_actor):
			if global_position.distance_to(target_actor.global_position) <= Balance.PLAYER_RADIUS + 8.0 or travelled >= target_distance:
				_impact_player(target_actor)
				return
		else:
			target_actor = null
	if target_actor == null and travelled >= midpoint_distance:
		burst_into_zone()
		return
	if life <= 0.0:
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
		if _segment_intersects_player(area):
			_impact_player(area)
		else:
			burst_into_zone()

func pop() -> void:
	resolved = true
	queue_free()

func burst_into_zone() -> void:
	if resolved:
		return
	resolved = true
	var burst_position := origin_point.lerp(target_point, 0.5)
	global_position = burst_position
	if get_parent() != null:
		var zone := CorruptionZone.new()
		zone.radius = 38.0
		get_parent().add_child(zone)
		zone.global_position = burst_position
	Fx.ring(global_position, col, 8.0, 48.0, 0.28, 2.4)
	Fx.sparks(global_position, col, 8, 180.0, 0.35, 2.4)
	queue_free()

func _draw() -> void:
	var c := col
	draw_line(Vector2(-16.0, 0), Vector2(8.0, 0), Color(c.r, c.g, c.b, 0.35), 5.0)
	draw_line(Vector2(-10.0, 0), Vector2(7.0, 0), c, 3.0)
	draw_circle(Vector2(8.0, 0), 4.0, Color(1, 0.8, 0.85, 0.9))
	draw_arc(Vector2.ZERO, 9.0, 0, TAU, 16, Color(c.r, c.g, c.b, 0.7), 1.4, true)

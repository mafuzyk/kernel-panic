class_name EnemyBase
extends Area2D

signal died(enemy: EnemyBase)

static var shared_list: Array = []

var hp := 2
var max_hp := 2
var speed := 120.0
var pts := 50
var radius := 14.0
var col: Color = Balance.COL_DRONE
var kb := Vector2.ZERO
var t := 0.0
var hit_flash := 0.0
var elite := false
var elite_kind := ""
var _swift_ghost_cd := 0.0
var spawn_t := 0.0
var mote_count := -1
var display_name := "DAEMON"
var last_pdash_id := -1
var player: Node2D
var glow: Sprite2D

func configure(wave_scale_f: float, is_elite: bool) -> void:
	hp = int(ceil(hp * wave_scale_f * (2.0 if is_elite else 1.0)))
	max_hp = hp
	speed *= wave_scale_f * (1.22 if is_elite else 1.0)
	elite = is_elite
	if is_elite:
		pts *= 3
		elite_kind = "volatile" if Game.rng.randf() < 0.5 else "swift"
		if elite_kind == "swift":
			speed *= 1.3

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = Balance.LAYER_ENEMY
	collision_mask = 0
	monitorable = true
	monitoring = false
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = radius
	cs.shape = sh
	add_child(cs)
	glow = Fx.make_glow(radius * 1.5, col)
	glow.modulate.a = 0.4
	add_child(glow)
	z_index = 11
	scale = Vector2.ONE * 0.05
	var players := get_tree().get_nodes_in_group("player")
	player = players[0] if players.size() > 0 else null
	_on_ready()

func _on_ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	t += delta
	spawn_t += delta
	if hit_flash > 0.0:
		hit_flash -= delta * 6.0
	_move(delta)
	var sep := _separation()
	position += (vel() + kb + sep) * delta
	kb = kb.move_toward(Vector2.ZERO, 700.0 * delta)
	var r := Balance.arena_rect()
	position.x = clampf(position.x, r.position.x + radius, r.end.x - radius)
	position.y = clampf(position.y, r.position.y + radius, r.end.y - radius)
	if glow != null:
		glow.modulate.a = 0.4 + 0.12 * sin(t * 6.0) + hit_flash
	var k: float = clampf(spawn_t / 0.32, 0.0, 1.0)
	var e := 1.0 + 2.7 * pow(k - 1.0, 3.0) + 1.7 * pow(k - 1.0, 2.0)
	scale = Vector2.ONE * maxf(0.05, e) * (1.22 if elite else 1.0)
	if elite and elite_kind == "swift":
		_swift_ghost_cd -= delta
		if _swift_ghost_cd <= 0.0:
			_swift_ghost_cd = 0.09
			Fx.ghost_dot(global_position, radius * 0.8, col, 0.22)
	queue_redraw()

func vel() -> Vector2:
	return Vector2.ZERO

func _move(_delta: float) -> void:
	pass

func _separation() -> Vector2:
	var push := Vector2.ZERO
	for e in shared_list:
		if e == self or not is_instance_valid(e):
			continue
		var d: Vector2 = global_position - e.global_position
		var dist := d.length()
		var min_d: float = radius + e.radius
		if dist < min_d and dist > 0.01:
			push += d / dist * (min_d - dist) * 6.0
	return push

func take_hit(dmg: int, from: Vector2) -> void:
	hp -= dmg
	hit_flash = 1.0
	var dir := (global_position - from).normalized()
	kb += dir * (140.0 if not is_in_group("boss") else 18.0)
	Sfx.play("hit", 1.0, -6.0)
	if hp <= 0:
		die()

func die() -> void:
	died.emit(self)
	if elite and elite_kind == "volatile":
		for i in 6:
			var orb := EnemyOrb.new()
			orb.setup(global_position, Vector2.from_angle(TAU * i / 6.0 + Game.rng.randf() * 0.4), 230.0, col)
			get_parent().call_deferred("add_child", orb)
		Fx.ring(global_position, Color(1, 1, 1, 0.8), radius, radius + 44.0, 0.3, 2.5)
	Fx.burst(global_position, col, 1.0 if radius < 20.0 else 1.7)
	Fx.hitstop(35.0)
	Sfx.play("explode", Game.rng.randf_range(0.9, 1.1), -4.0)
	queue_free()

func aim_at_player() -> Vector2:
	if player == null or not is_instance_valid(player):
		return Vector2.RIGHT
	return (player.global_position - global_position).normalized()

func dist_to_player() -> float:
	if player == null or not is_instance_valid(player):
		return 99999.0
	return global_position.distance_to(player.global_position)

func _flash_col(base: Color) -> Color:
	if hit_flash > 0.0:
		return base.lerp(Color(1, 1, 1, 1), clampf(hit_flash, 0.0, 1.0))
	return base

func _draw() -> void:
	pass

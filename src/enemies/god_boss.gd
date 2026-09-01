class_name GodBoss
extends RootBoss

const ORACLE_ATTACKS := ["SUNBURST", "CROSS", "CHAOS"]

var oracle_cd := 2.0
var last_oracle_attack := ""
var oracle_roll_count := 0

func _init() -> void:
	display_name = "GOD"
	hp = 170
	speed = 48.0 * Balance.weekly_enemy_speed_multiplier()
	pts = 5000
	radius = 56.0
	col = Color("ffd24f")
	mote_count = 34

func configure(wave_scale_f: float, _is_elite: bool) -> void:
	boss_index = 1
	hp = int(ceil(170.0 * wave_scale_f))
	max_hp = hp
	speed = 48.0
	pts = 5000
	radius = 56.0
	boss_title = "GOD"
	boss_quote = "THE RANDOM NUMBER GENERATOR HAS SPOKEN"
	col = Color("ffd24f")
	mote_count = 34

func roll_oracle_attack() -> String:
	last_oracle_attack = ORACLE_ATTACKS[Game.rng.randi_range(0, ORACLE_ATTACKS.size() - 1)]
	oracle_roll_count += 1
	return last_oracle_attack

func _move(delta: float) -> void:
	var to_player := player.global_position - global_position if player != null and is_instance_valid(player) else Vector2.ZERO
	var desired := steer_distance_band(to_player, 190.0, 330.0, -1.0, 0.72)
	desired += steer_separation(2.4) * 0.7
	_v = _v.move_toward(desired.limit_length(1.0) * speed, 260.0 * delta)
	oracle_cd -= delta
	if oracle_cd <= 0.0:
		oracle_cd = maxf(2.2 - 0.18 * (3 - phase), 1.15)
		_oracle_cast(roll_oracle_attack())
	var frac := float(hp) / float(max_hp) if max_hp > 0 else 0.0
	phase = 3 if frac < 0.33 else (2 if frac < 0.66 else 1)

func _oracle_cast(attack: String) -> void:
	match attack:
		"SUNBURST":
			var offset := Game.rng.randf() * TAU
			for i in 10:
				_spawn_orb(Vector2.from_angle(offset + TAU * i / 10.0), 220.0)
		"CROSS":
			var offset := Game.rng.randf() * PI * 0.5
			for i in 4:
				_spawn_orb(Vector2.from_angle(offset + TAU * i / 4.0), 300.0)
		"CHAOS":
			for i in 7:
				_spawn_orb(Vector2.from_angle(Game.rng.randf() * TAU), 180.0 + Game.rng.randf() * 110.0)
	Fx.ring(global_position, col, radius, radius + 100.0, 0.38, 3.0, true)
	Fx.text(global_position + Vector2(0, -radius - 20.0), attack, Color(1.0, 0.84, 0.35), 12)
	Sfx.play("shoot", 0.55, -4.0)

func take_hit(dmg: int, from: Vector2) -> void:
	hp -= dmg
	hit_flash = 1.0
	kb += (global_position - from).normalized() * 18.0
	Sfx.play("hit", 1.0, -6.0)
	if hp <= 0:
		die()
	boss_hp_changed.emit(float(maxi(hp, 0)) / float(maxi(max_hp, 1)))

func vel() -> Vector2:
	return _v

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _v.length_squared() > 0.01:
		rotation = lerp_angle(rotation, _v.angle(), 3.0 * delta)

func _draw() -> void:
	var c := _flash_col(col)
	GlyphLib.draw_glyph(self, "god", Vector2.ZERO, radius, _glyph_color(c), t)
	var eye := aim_at_player().normalized() * radius * 0.16
	draw_circle(eye, radius * 0.18, Color(1.0, 0.92, 0.62, 0.94))
	draw_circle(eye, radius * 0.07, Color(1.0, 0.25, 0.35, 1.0))
	var hp_frac := float(maxi(hp, 0)) / float(maxi(max_hp, 1))
	draw_arc(Vector2.ZERO, radius + 10.0, -PI / 2.0, -PI / 2.0 + TAU * hp_frac, 48, c, 2.8, true)
	if elite:
		draw_arc(Vector2.ZERO, radius + 14.0, 0.0, TAU, 36, Color(1, 1, 1, 0.75), 1.8, true)

class_name SplitterEnemy
extends EnemyBase

var _v := Vector2.ZERO
var _pulse := 0.0

func _init() -> void:
	display_name = "SPLITTER"
	hp = 3
	speed = 82.0
	pts = 100
	radius = 18.0
	col = Balance.threat_color("splitter", Sfx.color_assist)

func _on_ready() -> void:
	_pulse = Game.rng.randf() * TAU

func _move(delta: float) -> void:
	_pulse += delta * 6.0
	var desired := steer_approach(aim_at_player(), 1.0, 0.35)
	desired += steer_separation(2.2) * 0.7
	_v = _v.move_toward(desired.limit_length(1.0) * speed, 380.0 * delta)

func vel() -> Vector2:
	return _v

func color_assist_marker() -> String:
	return "SPLIT"

func _draw_color_assist_marker(c: Color) -> void:
	if not Sfx.color_assist:
		return
	var center := Vector2(radius + 18.0, -radius - 10.0)
	draw_circle(center, 12.0, Color(c.r, c.g, c.b, 0.14))
	draw_arc(center, 12.0, 0.0, TAU, 20, c, 1.5, true)
	draw_string(ThemeDB.fallback_font, center + Vector2(-24.0, 4.0), color_assist_marker(), HORIZONTAL_ALIGNMENT_CENTER, 48.0, 9, c)

func die() -> void:
	for i in 2:
		var m := DroneEnemy.new()
		m.setup_mini()
		m.elite = false
		m.elite_kind = ""
		m.position = global_position + Vector2.from_angle(TAU * 0.5 * i + Game.rng.randf()) * 14.0
		get_parent().call_deferred("add_child", m)
	Fx.ring(global_position, col, 6.0, 60.0, 0.3, 2.5)
	super.die()

func _draw() -> void:
	var c := _flash_col(col)
	var r := radius * (1.0 + 0.06 * sin(_pulse))
	draw_circle(Vector2.ZERO, r, Color(c.r, c.g, c.b, 0.18))
	draw_arc(Vector2.ZERO, r, 0, TAU, 32, c, 2.2, true)
	var split := 0.5 + 0.5 * sin(_pulse * 0.7)
	draw_line(Vector2(-r * 0.55 * split, 0), Vector2(r * 0.55 * split, 0), c, 2.0)
	draw_circle(Vector2(-r * 0.3, 0), r * 0.22, c)
	draw_circle(Vector2(r * 0.3, 0), r * 0.22, c)
	if elite:
		draw_arc(Vector2.ZERO, r + 5.0, 0, TAU, 24, Color(1, 1, 1, 0.75), 1.6, true)
	_draw_color_assist_marker(c)

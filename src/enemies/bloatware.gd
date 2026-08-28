class_name BloatwareEnemy
extends BulwarkEnemy

var _death_done := false

func _init() -> void:
	display_name = "BLOATWARE"
	hp = 20
	speed = 38.0
	pts = 450
	radius = 34.0
	col = Color("4b9ee8")
	mote_count = 5

func popup_count_on_death() -> int:
	return 5

func die() -> void:
	if _death_done:
		return
	_death_done = true
	var pos := global_position
	var parent := get_parent()
	died.emit(self)
	Fx.burst(pos, col, 2.4, 14)
	Fx.hitstop(70.0)
	Sfx.play("explode_big", 0.92, -2.0)
	for i in popup_count_on_death():
		if not EnemyOrb.can_spawn(self):
			break
		var popup := PopupOrb.new()
		popup.setup_popup(pos + Vector2.from_angle(TAU * i / float(popup_count_on_death())) * 38.0, i)
		parent.call_deferred("add_child", popup)
	for i in 3:
		var mini := DroneEnemy.new()
		mini.setup_mini()
		mini.position = pos + Vector2.from_angle(TAU * i / 3.0) * 42.0
		mini.configure(1.0, false)
		parent.call_deferred("add_child", mini)
	queue_free()

func _draw() -> void:
	var c := _flash_col(col)
	var r := radius
	var body := Rect2(-r, -r * 0.78, r * 2.0, r * 1.56)
	draw_rect(body, Color(c.r, c.g, c.b, 0.18))
	draw_rect(body, c, false, 3.0)
	draw_line(Vector2(-r * 0.72, -r * 0.22), Vector2(r * 0.72, -r * 0.22), Color(c.r, c.g, c.b, 0.7), 2.0)
	draw_line(Vector2(-r * 0.72, r * 0.24), Vector2(r * 0.4, r * 0.24), Color(c.r, c.g, c.b, 0.6), 2.0)
	var spin := t * 3.2
	for i in 8:
		var a := spin + TAU * i / 8.0
		var alpha := 0.18 + 0.72 * float(i + 1) / 8.0
		draw_line(Vector2.from_angle(a) * (r * 0.72), Vector2.from_angle(a) * (r * 0.93), Color(c.r, c.g, c.b, alpha), 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(-28, r + 18), "LOADING", HORIZONTAL_ALIGNMENT_CENTER, 56.0, 9, c)
	if elite:
		draw_arc(Vector2.ZERO, r + 8.0, 0, TAU, 32, Color(1, 1, 1, 0.75), 1.8, true)

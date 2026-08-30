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
	GlyphLib.draw_glyph(self, "bloatware", Vector2.ZERO, r, _glyph_color(c), t)
	draw_string(ThemeDB.fallback_font, Vector2(-28, r + 18), "LOADING", HORIZONTAL_ALIGNMENT_CENTER, 56.0, 9, c)
	if elite:
		draw_arc(Vector2.ZERO, r + 8.0, 0, TAU, 32, Color(1, 1, 1, 0.75), 1.8, true)

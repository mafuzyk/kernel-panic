class_name PopupOrb
extends EnemyOrb

var popup_id := 0

func setup_popup(pos: Vector2, index: int) -> void:
	popup_id = index
	setup(pos, Vector2.ZERO, 0.0, Color("72d7ff"))
	life = 18.0

func _ready() -> void:
	super._ready()
	add_to_group("popup_orbs")
	var shape := get_node_or_null("CollisionShape2D")
	if shape != null and shape.shape is CircleShape2D:
		shape.shape.radius = 12.0

func _draw() -> void:
	var pulse := 0.65 + 0.2 * sin(Time.get_ticks_msec() * 0.004 + popup_id)
	var c := Color(col.r, col.g, col.b, pulse)
	draw_rect(Rect2(-10.0, -10.0, 20.0, 20.0), Color(c.r, c.g, c.b, 0.14))
	draw_rect(Rect2(-10.0, -10.0, 20.0, 20.0), c, false, 2.0)
	draw_line(Vector2(-6.0, 0), Vector2(6.0, 0), c, 1.5)
	draw_line(Vector2(0, -6.0), Vector2(0, 6.0), c, 1.5)

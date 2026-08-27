class_name Reticle
extends Node2D

var player: Player
var _spread := 0.0

func _process(delta: float) -> void:
	var firing := player != null and is_instance_valid(player) and player.fire_cd > 0.0
	if firing:
		_spread = minf(_spread + delta * 40.0, 10.0)
	else:
		_spread = maxf(_spread - delta * 30.0, 0.0)
	visible = Input.mouse_mode == Input.MOUSE_MODE_HIDDEN
	if visible:
		position = get_global_mouse_position()
	queue_redraw()

func _draw() -> void:
	var hot := player != null and is_instance_valid(player) and player.overclock_active
	var c := Balance.COL_PLAYER_HOT if hot else Balance.COL_PLAYER
	c.a = 0.9
	var s := 7.0 if hot else 5.0
	draw_rect(Rect2(-s * 0.5, -s * 0.5, s, s), c)
	c.a = 0.5
	var dirs := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	var off := 8.0 + _spread
	for d in dirs:
		draw_line(d * off, d * (off + 5.0), c, 1.6, true)

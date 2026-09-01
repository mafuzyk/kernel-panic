class_name ZombieProcessEnemy
extends EnemyBase

const LIFETIME := 4.0

var remaining_life := LIFETIME

func _init() -> void:
	display_name = "ZOMBIE_PROCESS"
	hp = 1
	speed = 0.0
	pts = 0
	radius = 16.0
	col = Balance.COL_ZOMBIE
	mote_count = 0

func participates_in_enemy_pathing() -> bool:
	return false

func participates_in_kill_rewards() -> bool:
	return false

func _move(delta: float) -> void:
	remaining_life -= delta
	if remaining_life <= 0.0:
		queue_free()

func vel() -> Vector2:
	return Vector2.ZERO

func take_hit(_dmg: int, _from: Vector2) -> void:
	queue_free()

func presentation_snapshot() -> Dictionary:
	var snapshot := super.presentation_snapshot()
	snapshot["remaining_life"] = maxf(remaining_life, 0.0)
	snapshot["lifetime"] = LIFETIME
	snapshot["timer_marker"] = "caret-and-ring"
	return snapshot

func presentation_state() -> String:
	return "death" if remaining_life < LIFETIME * 0.25 else "idle"

func _draw() -> void:
	var c := _flash_col(col)
	var r := radius
	VNextEntityRenderer.draw_enemy(self, "zombie_process", presentation_facing(), presentation_state(), false, r, t, _glyph_color(c))
	var ratio := clampf(remaining_life / LIFETIME, 0.0, 1.0)
	draw_arc(Vector2.ZERO, r + 8.0, -PI / 2.0, -PI / 2.0 + TAU * ratio, 24, Balance.COL_TEXT, 2.0, true)
	draw_line(Vector2(-r * 0.55, r + 5.0), Vector2(-r * 0.55 + r * ratio * 1.1, r + 5.0), Balance.COL_TEXT, 2.0, true)

class_name LayeredRevealTelegraph
extends Node2D

## Gameplay-independent child that remains active while its parent enemy is
## disabled. Shape, progress and label communicate the reveal without relying
## on hue or the parent simulation.

const ShareTechMono: Font = preload("res://assets/fonts/ShareTechMono.ttf")

var duration := 1.0
var remaining := 1.0
var accent := Balance.COL_PLAYER
var active := true
var revealed := false

signal reveal_finished

func configure(delay: float, color: Color) -> void:
	duration = maxf(delay, 0.2)
	remaining = duration
	accent = color
	active = true
	revealed = false
	queue_redraw()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = -1
	queue_redraw()

func _process(delta: float) -> void:
	if not active:
		return
	remaining = maxf(remaining - delta, 0.0)
	queue_redraw()
	if remaining <= 0.0:
		active = false
		revealed = true
		reveal_finished.emit()
		queue_redraw()

func _draw() -> void:
	if not active:
		return
	var ratio := clampf(remaining / maxf(duration, 0.2), 0.0, 1.0)
	var c := Color(accent.r, accent.g, accent.b, 0.68)
	var white := Color(1.0, 1.0, 1.0, 0.86)
	draw_arc(Vector2.ZERO, 25.0, -PI / 2.0, -PI / 2.0 + TAU * ratio, 28, white, 2.0, true)
	for i in 4:
		var angle := TAU * float(i) / 4.0 + PI / 4.0
		var direction := Vector2.from_angle(angle)
		draw_line(direction * 22.0, direction * 30.0, c, 2.0, true)
	draw_line(Vector2(-18.0, 18.0), Vector2(18.0, 18.0), white, 1.4, true)
	draw_string(ShareTechMono, Vector2(-36.0, 36.0), "BACKGROUND", HORIZONTAL_ALIGNMENT_LEFT, 72.0, 9, white)
	var seconds := "%.1f" % remaining
	draw_string(ShareTechMono, Vector2(-10.0, 4.0), seconds, HORIZONTAL_ALIGNMENT_CENTER, 20.0, 9, white)

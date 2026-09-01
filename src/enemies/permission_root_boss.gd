class_name PermissionRootBoss
extends RootBoss

## macOS climax variant. It keeps the shared RootBoss integrity, phases and
## desperation contract, but gives the final node one readable permission
## check: a short, directional wind-up followed by a three-shot denial burst.

const PERMISSION_WIND_DURATION := 0.9
const PERMISSION_CADENCE := 4.8
const PERMISSION_BURST_SPEED := 305.0
const PERMISSION_ACCENT := Color("a7f5ff")

var _permission_cd := 2.4
var _permission_wind_t := 0.0
var _permission_cast_pending := false
var _permission_dir := Vector2.RIGHT

func configure(wave_scale_f: float, is_elite: bool) -> void:
	super.configure(wave_scale_f, is_elite)
	_permission_cd = 2.4
	_permission_wind_t = 0.0
	_permission_cast_pending = false
	_permission_dir = Vector2.RIGHT
	boss_title = "PERMISSION ROOT"
	boss_quote = "background service requests elevated access"
	col = PERMISSION_ACCENT
	if glow != null:
		glow.self_modulate = col

func permission_telegraph_snapshot() -> Dictionary:
	return {
		"active": _permission_wind_t > 0.0,
		"remaining": maxf(_permission_wind_t, 0.0),
		"direction": _permission_dir,
		"label": "PERMISSION CHECK" if _permission_wind_t > 0.0 else "",
	}.duplicate(true)

func presentation_snapshot() -> Dictionary:
	var snapshot := super.presentation_snapshot()
	snapshot["boss_variant_id"] = "permission_root"
	snapshot["permission_telegraph"] = permission_telegraph_snapshot()
	return snapshot

func _ready() -> void:
	super._ready()
	boss_title = "PERMISSION ROOT"
	boss_quote = "background service requests elevated access"
	col = PERMISSION_ACCENT
	if glow != null:
		glow.self_modulate = col

func _move(delta: float) -> void:
	_permission_cd -= delta
	var was_winding := _permission_wind_t > 0.0
	if was_winding:
		_permission_wind_t = maxf(_permission_wind_t - delta, 0.0)
	super._move(delta)
	if was_winding and _permission_wind_t <= 0.0 and _permission_cast_pending:
		_permission_cast_pending = false
		_cast_permission_burst()

func _try_attacks() -> void:
	if desperation_transition_t > 0.0 or act != Act.HOVER:
		return
	if _permission_wind_t > 0.0 or _permission_cast_pending:
		return
	if _permission_cd <= 0.0:
		_permission_cd = _desperation_interval(PERMISSION_CADENCE)
		_permission_wind_t = PERMISSION_WIND_DURATION
		_permission_cast_pending = true
		_permission_dir = aim_at_player()
		Fx.ring(global_position, PERMISSION_ACCENT, radius, radius + 96.0, PERMISSION_WIND_DURATION, 2.5, true)
		Fx.text(global_position + Vector2(0, -radius - 24.0), "PERMISSION CHECK", PERMISSION_ACCENT, 14)
		Sfx.play("charge", 0.85, -5.0)
		return
	if _burst_cd <= 0.0:
		_burst_cd = _desperation_interval(3.0)
		_do_burst(10 + 2 * phase, PERMISSION_BURST_SPEED)

func _cast_permission_burst() -> void:
	if player == null or not is_instance_valid(player):
		return
	for i in 3:
		var offset := (float(i) - 1.0) * 0.24
		_spawn_orb(_permission_dir.rotated(offset), PERMISSION_BURST_SPEED)
	Fx.ring(global_position, Color.WHITE, radius, radius + 120.0, 0.32, 3.0, true)
	Fx.text(global_position + Vector2(0, radius + 28.0), "PERMISSION DENIED", Color.WHITE, 14)
	Sfx.play("shoot", 0.7, -5.0)

func _draw() -> void:
	super._draw()
	if _permission_wind_t <= 0.0:
		return
	var alpha := 0.72 + 0.28 * absf(sin(t * 12.0))
	var telegraph_col := Color(PERMISSION_ACCENT.r, PERMISSION_ACCENT.g, PERMISSION_ACCENT.b, alpha)
	var dir := _permission_dir.normalized()
	var start := dir * (radius + 18.0)
	var finish := dir * 560.0
	draw_line(start, finish, Color(1.0, 1.0, 1.0, alpha * 0.24), 7.0, true)
	draw_line(start, finish, telegraph_col, 2.0, true)
	for side in [-1.0, 1.0]:
		var side_dir := dir.rotated(side * 0.16)
		draw_line(finish - side_dir * 26.0, finish, telegraph_col, 2.5, true)
		draw_line(finish, finish - side_dir.rotated(side * 0.20) * 26.0, telegraph_col, 2.5, true)

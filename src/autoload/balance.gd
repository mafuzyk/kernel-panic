class_name Balance

const ARENA_W := 1208.0
const ARENA_H := 648.0
static var _arena_size_override := Vector2.ZERO

const PLAYER_MAX_HP := 4
const PLAYER_SPEED := 340.0
const PLAYER_ACCEL := 2800.0
const PLAYER_FRICTION := 2400.0
const PLAYER_RADIUS := 12.0
const FIRE_RATE := 8.0
const FIRE_RATE_OC := 14.0
const BULLET_SPEED := 950.0
const BULLET_LIFE := 1.05
const BULLET_SPREAD := 0.045
const DASH_SPEED := 1150.0
const DASH_TIME := 0.16
const DASH_CD := 0.85
const DASH_IFRAMES := 0.24
const HURT_IFRAMES := 0.95
const OC_DURATION := 6.0
const OC_METER_MAX := 100.0
const MOTE_VALUE := 6.0
const MOTE_KILL_VALUE := 2.0
const MOTE_MAGNET := 115.0
const MOTE_MAGNET_OC := 185.0
const MOTE_LIFE := 12.0

const COMBO_WINDOW := 3.0
const COMBO_MAX := 8

const WAVE_BUDGET_BASE := 6
const WAVE_BUDGET_GROWTH := 5
const WAVE_SPAWN_INTERVAL := 1.7
const WAVE_SPAWN_MIN := 0.6
const WAVE_SCALE_CAP := 1.65
const BOSS_EVERY := 5
const HEAL_EVERY := 3

const DIFFICULTY_ORDER := ["easy", "normal", "hard"]
const DIFF_ALIVE_MULT := {"easy": 0.7, "normal": 1.0, "hard": 1.3}
const DIFF_BUDGET_MULT := {"easy": 0.8, "normal": 1.0, "hard": 1.2}
const DIFF_ELITE_MULT := {"easy": 0.6, "normal": 1.0, "hard": 1.4}
const DIFF_CADENCE_SCALE := {"easy": 1.0, "normal": 1.0, "hard": 0.897}
const DIFF_CADENCE_FLOOR := {"easy": 0.90, "normal": 0.78, "hard": 0.70}

const LAYER_PLAYER := 2
const LAYER_ENEMY := 4
const LAYER_PBULLET := 8
const LAYER_EORB := 16
const LAYER_MOTE := 32

const COL_BG := Color("05060e")
const COL_GRID := Color("16233f")
const COL_PLAYER := Color("4ff2ff")
const COL_PLAYER_HOT := Color("d8ffff")
const COL_BULLET := Color("aefaff")
const COL_DRONE := Color("ff3d81")
const COL_LANCER := Color("ff9a3d")
const COL_SPEWER := Color("b46bff")
const COL_ZOMBIE := Color("8294a8")
const COL_SPLITTER := Color("ff5c5c")
const COL_BULWARK := Color("58b8ff")
const COL_SPLITTER_ASSIST := Color("ffb000")
const COL_BULWARK_ASSIST := Color("7b61ff")
const COL_MOTE := Color("ffd24f")
const COL_TEXT := Color("cfe9ff")
const COL_DANGER := Color("ff2a4d")

static func wave_scale(wave: int) -> float:
	return minf(1.0 + float(wave - 1) * 0.03, 1.7)

const ERA_TINTS := [
	Color("4ff2ff"),
	Color("ff9a3d"),
	Color("4f8cff"),
	Color("b46bff"),
	Color("ff2a4d"),
]

static func era_color(wave: int) -> Color:
	return ERA_TINTS[clampi((wave - 1) / 5, 0, ERA_TINTS.size() - 1)]

static func threat_palette(color_assist: bool = false) -> Dictionary:
	if color_assist:
		return {
			"splitter": COL_SPLITTER_ASSIST,
			"bulwark": COL_BULWARK_ASSIST,
		}
	return {
		"splitter": COL_SPLITTER,
		"bulwark": COL_BULWARK,
	}

static func threat_color(id: String, color_assist: bool = false) -> Color:
	return threat_palette(color_assist).get(id, COL_TEXT)

static func wave_budget(wave: int) -> int:
	return 8 + (wave - 1) * 5 + maxi(0, wave - 4) * 2

static func max_alive(wave: int) -> int:
	return mini(6 + wave * 2, 10)

static func attack_cadence_factor(wave: int) -> float:
	if wave <= 5:
		return 1.0
	return maxf(0.78, 1.0 - float(wave - 5) * 0.015)

static func elite_chance(wave: int) -> float:
	return clampf(float(wave - 7) * 0.045, 0.0, 0.4)

static func difficulty_applies() -> bool:
	return Game.mode != "story"

static func difficulty_max_alive(wave: int) -> int:
	if not difficulty_applies():
		return max_alive(wave)
	var mult: float = DIFF_ALIVE_MULT.get(Game.difficulty, 1.0)
	return maxi(1, int(ceil(float(max_alive(wave)) * mult)))

static func difficulty_wave_budget(wave: int) -> int:
	if not difficulty_applies():
		return wave_budget(wave)
	var mult: float = DIFF_BUDGET_MULT.get(Game.difficulty, 1.0)
	return maxi(1, int(floor(float(wave_budget(wave)) * mult)))

static func difficulty_elite_chance(wave: int) -> float:
	if not difficulty_applies():
		return elite_chance(wave)
	var mult: float = DIFF_ELITE_MULT.get(Game.difficulty, 1.0)
	return clampf(elite_chance(wave) * mult, 0.0, 1.0)

static func difficulty_cadence(wave: int) -> float:
	if not difficulty_applies():
		return attack_cadence_factor(wave)
	var base := attack_cadence_factor(wave)
	if base >= 1.0:
		return 1.0
	var scale: float = DIFF_CADENCE_SCALE.get(Game.difficulty, 1.0)
	var floor_v: float = DIFF_CADENCE_FLOOR.get(Game.difficulty, 0.78)
	return clampf(base * scale, floor_v, 1.0)

static func arena_rect() -> Rect2:
	var arena_size := Vector2(ARENA_W, ARENA_H)
	if _arena_size_override.x > 0.0 and _arena_size_override.y > 0.0:
		arena_size = _arena_size_override
	return Rect2(-arena_size * 0.5, arena_size)

static func set_arena_size_override(arena_size: Vector2) -> void:
	_arena_size_override = Vector2(maxf(arena_size.x, 0.0), maxf(arena_size.y, 0.0))

static func clear_arena_size_override() -> void:
	_arena_size_override = Vector2.ZERO

static func is_desktop_display(display_name: String = "") -> bool:
	var name := display_name.to_lower() if display_name != "" else DisplayServer.get_name().to_lower()
	return name in ["windows", "macos", "x11", "wayland", "embedded"]

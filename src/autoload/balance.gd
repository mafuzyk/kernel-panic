class_name Balance

const ARENA_W := 1208.0
const ARENA_H := 648.0

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
const COL_SPLITTER := Color("ff5c5c")
const COL_BULWARK := Color("ff5252")
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

static func wave_budget(wave: int) -> int:
	return 8 + (wave - 1) * 5 + maxi(0, wave - 4) * 2

static func max_alive(wave: int) -> int:
	return mini(6 + wave * 2, 16)

static func elite_chance(wave: int) -> float:
	return clampf(float(wave - 7) * 0.045, 0.0, 0.4)

static func arena_rect() -> Rect2:
	return Rect2(-ARENA_W * 0.5, -ARENA_H * 0.5, ARENA_W, ARENA_H)

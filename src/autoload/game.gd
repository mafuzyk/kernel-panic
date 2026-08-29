extends Node

const STORY_DATA = preload("res://src/story/story_data.gd")

signal score_changed(score: int, mult: int)
signal combo_changed(mult: int, frac: float)
signal run_ended(stats: Dictionary)
signal mute_changed(muted: bool)
signal patch_offered
signal patch_picked(id: String)
signal combo_milestone(mult: int)
signal bestiary_unlocked(id: String)
signal achievement_unlocked(id: String, label: String)

enum State { MENU, PLAYING, GAME_OVER }

var combo_window := Balance.COMBO_WINDOW
var patch_levels := {}
var mode := "classic"
var difficulty := "normal"
var program := "kernel"
var story_stage_index := 0
var story_cleared: Dictionary = {}
var story_best: Dictionary = {}
var temple_rainbow_unlocked := false
var vampic_cd := 0.0
const VAMPIC_COOLDOWN := 10.0
var unlocked_programs := {"kernel": true}
var onehp_unlocked := false
var bestiary := {}
var tutorial := {}
var rng := RandomNumberGenerator.new()
var _max_chain_seen := 1
const EVENT_LOG_MAX := 64
var event_log: Array[Dictionary] = []
var run_seed := 0
var terminal_heal_used := false
var achievements: Dictionary = {}

const ACHIEVEMENT_DEFS := {
	"first_blood": "FIRST_BLOOD",
	"boss_purge": "ROOT_ACCESS",
	"chain_max": "CHAIN_REACTION",
	"terminal_operator": "TERMINAL_OPERATOR",
	"integrity_restored": "INTEGRITY_RESTORED",
}
const SAVE_TRANSFER_FORMAT := "kernel-panic-save"
const SAVE_TRANSFER_VERSION := 1

const COMBO_WINDOW := Balance.COMBO_WINDOW

var state: int = State.MENU
var score := 0
var best := 0
var mult := 1
var combo_left := 0.0
var wave := 1
var stats := {}
var new_best := false
var keybinds: Dictionary = {}

const KEYBIND_DEFAULTS := {
	"move_up": KEY_W,
	"move_down": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"dash": KEY_SPACE,
	"overclock": KEY_E,
	"pause": KEY_ESCAPE,
	"abandon": KEY_Q,
	"mute": KEY_M,
	"restart": KEY_R,
	"confirm": KEY_ENTER,
}

const KEYBIND_ALTERNATES := {
	"move_up": [KEY_UP],
	"move_down": [KEY_DOWN],
	"move_left": [KEY_LEFT],
	"move_right": [KEY_RIGHT],
	"dash": [KEY_SHIFT],
	"pause": [KEY_P],
	"confirm": [KEY_KP_ENTER],
}

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()

func _ready() -> void:
	_load_run_config()

const PROGRAM_DEFS := {
	"kernel": {
		"name": "KERNEL", "desc": "balanced standard process", "hp": 4, "speed_mul": 1.0, "dmg_bonus": 0, "rate_mul": 1.0, "range_mul": 1.0, "dash_charges": 1,
		"summary": "Reliable all-round process for learning the purge loop.", "role": "BALANCED CORE", "integrity": "4 HP", "speed": "100% MOVE", "fire": "STANDARD FIRE", "range": "MEDIUM RANGE", "dash_shield": "1 DASH // OVERCLOCK",
		"visual": {"color": Color("4ff2ff"), "silhouette": "kernel_arrow"}
	},
	"daemon": {
		"name": "DAEMON", "desc": "3 HP. short range. hot close fire rate. kills recharge dash. 2 dash charges.", "hp": 3, "speed_mul": 1.0, "dmg_bonus": 0, "rate_mul": 1.0, "range_mul": 0.72, "dash_charges": 2, "close_rate_mul": 1.6, "close_range": 160.0, "kill_dash_refund": 0.7,
		"summary": "Aggressive close-range process that snowballs through kills.", "role": "CLOSE-RANGE HUNTER", "integrity": "3 HP", "speed": "100% MOVE", "fire": "HOT FIRE <160PX", "range": "72% RANGE", "dash_shield": "2 DASH // KILL RECHARGE",
		"visual": {"color": Color("ff5b88"), "silhouette": "daemon_fork"}
	},
	"rootlet": {
		"name": "ROOTLET", "desc": "5 HP. slow. heavy shots. shield instead of overclock.", "hp": 5, "speed_mul": 0.85, "dmg_bonus": 1, "rate_mul": 0.8, "range_mul": 1.0, "dash_charges": 1, "shield_mode": true,
		"summary": "Armored heavy process with a mote-powered shield.", "role": "ARMORED ANCHOR", "integrity": "5 HP", "speed": "85% MOVE", "fire": "HEAVY FIRE // +1 DMG", "range": "MEDIUM RANGE", "dash_shield": "1 DASH // SHIELD",
		"visual": {"color": Color("9dff72"), "silhouette": "rootlet_block"}
	},
}

func program_def() -> Dictionary:
	return PROGRAM_DEFS.get(program, PROGRAM_DEFS["kernel"])

func unlock_program(id: String) -> void:
	if unlocked_programs.has(id):
		return
	unlocked_programs[id] = true
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	cf.set_value("programs", "unlocked", unlocked_programs)
	cf.save(Sfx.SAVE_PATH)

func set_program(id: String) -> void:
	if unlocked_programs.has(id):
		program = id
		var cf := ConfigFile.new()
		cf.load(Sfx.SAVE_PATH)
		cf.set_value("run", "program", id)
		cf.save(Sfx.SAVE_PATH)

func set_difficulty(value: String) -> void:
	if value not in Balance.DIFFICULTY_ORDER:
		return
	difficulty = value
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	cf.set_value("game", "difficulty", value)
	cf.save(Sfx.SAVE_PATH)

func _load_run_config() -> void:
	var cf := ConfigFile.new()
	if cf.load(Sfx.SAVE_PATH) == OK:
		best = cf.get_value("run", "best_classic", cf.get_value("run", "best", 0))
		onehp_unlocked = cf.get_value("run", "onehp_unlocked", false)
		bestiary = cf.get_value("bestiary", "seen", {})
		tutorial = cf.get_value("tutorial", "hints", {})
		achievements = cf.get_value("achievements", "unlocked", {})
		mode = cf.get_value("game", "mode", "classic")
		if mode == "onehp" and not onehp_unlocked:
			mode = "classic"
		difficulty = str(cf.get_value("game", "difficulty", "normal"))
		if difficulty not in Balance.DIFFICULTY_ORDER:
			difficulty = "normal"
		unlocked_programs = cf.get_value("programs", "unlocked", {"kernel": true})
		if not unlocked_programs.has("kernel"):
			unlocked_programs["kernel"] = true
		var saved_prog: String = cf.get_value("run", "program", "kernel")
		if unlocked_programs.has(saved_prog):
			program = saved_prog
		story_cleared = cf.get_value("story", "cleared", {})
		story_best = cf.get_value("story", "best", {})
		temple_rainbow_unlocked = bool(cf.get_value("story", "temple_rainbow_unlocked", false))
		if not story_cleared is Dictionary:
			story_cleared = {}
		if not story_best is Dictionary:
			story_best = {}
	rng.randomize()

func week_number() -> int:
	var days := int(Time.get_unix_time_from_system() / 86400.0)
	return int(float(days + 3) / 7.0)

func week_id() -> String:
	return "W%d" % week_number()

func best_for_mode() -> int:
	match mode:
		"story":
			return story_stage_best(story_stage_index)
		"weekly":
			var cf := ConfigFile.new()
			cf.load(Sfx.SAVE_PATH)
			var wid := week_id()
			if cf.get_value("weekly", "id", "") != wid:
				return 0
			return cf.get_value("weekly", "best", 0)
		"onehp":
			var cf := ConfigFile.new()
			cf.load(Sfx.SAVE_PATH)
			return cf.get_value("run", "best_onehp", 0)
	return best

func unlock_onehp() -> void:
	if onehp_unlocked:
		return
	onehp_unlocked = true
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	cf.set_value("run", "onehp_unlocked", true)
	cf.save(Sfx.SAVE_PATH)

func effective_aim_mode() -> String:
	return Sfx.aim_mode

func score_mult() -> int:
	return 3 if mode == "onehp" else 1

func story_stage_count() -> int:
	return STORY_DATA.stage_count()

func story_stage_def(index: int) -> Dictionary:
	return STORY_DATA.stage_at(index)

func story_stage_id(index: int) -> String:
	return str(story_stage_def(index).get("id", ""))

func story_stage_best(index: int) -> int:
	return int(story_best.get(story_stage_id(index), 0))

func story_stage_unlocked(index: int) -> bool:
	if index < 0 or index >= story_stage_count():
		return false
	if index == 0:
		return true
	return bool(story_cleared.get(story_stage_id(index - 1), false))

func start_story(index: int = 0) -> bool:
	if not story_stage_unlocked(index):
		return false
	var stage := story_stage_def(index)
	if stage.is_empty():
		return false
	mode = "story"
	story_stage_index = index
	state = State.PLAYING
	score = 0
	mult = 1
	combo_left = 0.0
	combo_window = Balance.COMBO_WINDOW
	patch_levels = {}
	wave = 1
	_max_chain_seen = 1
	event_log.clear()
	terminal_heal_used = false
	rng.randomize()
	run_seed = int(rng.seed)
	new_best = false
	stats = {"kills": 0, "shots": 0, "hits": 0, "damage": 0, "time": 0.0, "wave": 1, "boss_kills": 0, "heals": {}}
	log_event("STORY // %s // %s" % [stage.get("path", ""), stage.get("title", "")])
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", "res://src/arena/arena.tscn")
	return true

func should_offer_patch(cleared_wave: int) -> bool:
	if mode == "onehp":
		return cleared_wave > 0 and cleared_wave % 3 == 0
	return cleared_wave > 0 and (cleared_wave + 1) % Balance.BOSS_EVERY == 0

const BESTIARY_MAP := {"DRONE": "drone", "LANCER": "lancer", "SPEWER": "spewer", "SPLITTER": "splitter", "BULWARK": "bulwark", "TROJAN": "trojan", "OOM_KILLER": "oom", "ROOT": "boss", "RECURSOR": "recursor", "FIREWALL": "firewall", "UPDATE_LOOP": "update_loop", "BLOATWARE": "bloatware", "GOD": "god", "ROOT.exe": "root", "SEGFAULT": "segfault", "BLUE SCREEN": "bluescreen", "PAGE FAULT": "pagefault"}

func _bestiary_id_for_display(display: String) -> String:
	var normalized := display.strip_edges()
	var direct_id: String = BESTIARY_MAP.get(normalized, "")
	if direct_id != "":
		return direct_id
	var longest_prefix := ""
	for raw_key in BESTIARY_MAP.keys():
		var key := String(raw_key)
		var suffix_prefix := key + " MK-"
		if not normalized.begins_with(suffix_prefix):
			continue
		var suffix := normalized.substr(suffix_prefix.length())
		if suffix.is_valid_int() and key.length() > longest_prefix.length():
			longest_prefix = key
	return BESTIARY_MAP.get(longest_prefix, "")

func mark_bestiary(display: String) -> void:
	var id: String = _bestiary_id_for_display(display)
	if id == "" or bestiary.has(id):
		return
	bestiary[id] = true
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	cf.set_value("bestiary", "seen", bestiary)
	cf.save(Sfx.SAVE_PATH)
	bestiary_unlocked.emit(id)

func mark_bestiary_for_enemy(enemy: EnemyBase) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if enemy is RootBoss:
		if enemy.mini:
			return
		mark_bestiary(enemy.display_name)
		mark_bestiary(enemy.boss_title)
		return
	mark_bestiary(enemy.display_name)

func show_hint_once(id: String) -> bool:
	if id.is_empty():
		return false
	if OS.get_environment("KP_HINTS") != "":
		return true
	if tutorial.has(id):
		return false
	tutorial[id] = true
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	cf.set_value("tutorial", "hints", tutorial)
	cf.save(Sfx.SAVE_PATH)
	return true

func bestiary_seen(id: String) -> bool:
	return bestiary.has(id)

const PATCH_CODES := {"rapid": "RP", "cell": "OC", "magnet": "MG", "hp": "HP", "dash": "PH", "frag": "FR", "threads": "TH", "chain": "CH", "core": "HC", "restore": "SR", "light": "LF", "mdash": "MD", "heavy": "HV", "ricochet": "RC", "pdash": "PD", "staticf": "SF", "vampic": "VP", "recycler": "RY", "dataleech": "DL", "splitshot": "SP", "secondwind": "SW", "thorns": "TN", "turbo": "TD", "scrapdiet": "SD", "shield": "SH", "absorb": "AB"}

const PATCH_RELATIONS := {
	"heavy": {"splitshot": "TRADEOFF: HEAVY + SPLITSHOT BOTH REDUCE FIRE RATE"},
	"splitshot": {"heavy": "TRADEOFF: HEAVY + SPLITSHOT BOTH REDUCE FIRE RATE"},
}

func patch_relation(id: String, other_id: String) -> String:
	return str(PATCH_RELATIONS.get(id, {}).get(other_id, "NO DIRECT INTERACTION"))

func patch_tooltip_data(id: String, active_ids: Array = []) -> Dictionary:
	var definition: Dictionary = {}
	for candidate in PATCH_DEFS:
		if str(candidate.get("id", "")) == id:
			definition = candidate
			break
	var active: Array = active_ids if not active_ids.is_empty() else patch_levels.keys()
	var relation := "NO DIRECT INTERACTION"
	for other_id in active:
		if str(other_id) == id:
			continue
		var candidate_relation := patch_relation(id, str(other_id))
		if candidate_relation != "NO DIRECT INTERACTION":
			relation = candidate_relation
			break
	return {
		"id": id,
		"title": str(definition.get("title", id.to_upper())),
		"description": str(definition.get("desc", "UNKNOWN PATCH")),
		"level": patch_level(id),
		"relation": relation,
	}

func build_string() -> String:
	if patch_levels.is_empty():
		return "NO PATCHES"
	var parts: Array = []
	for id in patch_levels:
		parts.append("%s%d" % [PATCH_CODES.get(id, id.substr(0, 2).to_upper()), int(patch_levels[id])])
	return " ".join(parts)

func _process(delta: float) -> void:
	if vampic_cd > 0.0:
		vampic_cd = maxf(vampic_cd - delta, 0.0)
	if combo_left > 0.0 and state == State.PLAYING:
		combo_left -= delta
		if combo_left <= 0.0:
			mult = 1
			combo_left = 0.0
		combo_changed.emit(mult, combo_left / combo_window)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mute"):
		Sfx.toggle_mute()
		mute_changed.emit(Sfx.muted)

const PATCH_DEFS := [
	{"id": "rapid", "title": "RAPID LOOPS", "desc": "+18% FIRE RATE", "max": 5, "rare": false, "legend": false},
	{"id": "cell", "title": "OVERCLOCK CELL", "desc": "+2.0s OVERCLOCK DURATION", "max": 3, "rare": false, "legend": false},
	{"id": "magnet", "title": "MAGNET ARRAY", "desc": "+45% MOTE PULL RANGE", "max": 3, "rare": false, "legend": false},
	{"id": "hp", "title": "REINTEGRATION", "desc": "+1 MAX INTEGRITY, HEAL 1", "max": 3, "rare": false, "legend": false},
	{"id": "dash", "title": "QUICK DASH", "desc": "-18% DASH COOLDOWN", "max": 3, "rare": false, "legend": false},
	{"id": "frag", "title": "FRAGMENTATION", "desc": "KILLS DROP +1 MOTE", "max": 2, "rare": false, "legend": false},
	{"id": "threads", "title": "LONG THREADS", "desc": "+22% BULLET VELOCITY", "max": 3, "rare": false, "legend": false},
	{"id": "chain", "title": "CHAIN DRIVER", "desc": "+0.8s COMBO WINDOW", "max": 3, "rare": false, "legend": false},
	{"id": "light", "title": "LIGHT FRAME", "desc": "+12% MOVE SPEED", "max": 3, "rare": false, "legend": false},
	{"id": "mdash", "title": "MAGNETIC DASH", "desc": "DASH PULLS NEARBY MOTES", "max": 1, "rare": false, "legend": false},
	{"id": "heavy", "title": "HEAVY ROUNDS", "desc": "+1 DAMAGE, -10% FIRE RATE", "max": 2, "rare": true, "legend": false},
	{"id": "core", "title": "HOT CORE", "desc": "BULLETS PIERCE +1 ENEMY", "max": 2, "rare": true, "legend": false},
	{"id": "restore", "title": "SYSTEM RESTORE", "desc": "PURGE ALL ORBS, HEAL 1, 2s SHIELD", "max": 1, "rare": true, "legend": false},
	{"id": "ricochet", "title": "RICOCHET", "desc": "BULLETS BOUNCE OFF WALLS +1", "max": 2, "rare": true, "legend": true},
	{"id": "pdash", "title": "PHASE DASH", "desc": "DASH DEALS 2 DAMAGE", "max": 1, "rare": true, "legend": true},
	{"id": "staticf", "title": "STATIC FIELD", "desc": "BURNS ENEMIES WITHIN 70PX", "max": 2, "legend": true, "rare": true},
	{"id": "vampic", "title": "VAMPIC PROTOCOL", "desc": "CHAIN x4 HEALS 1 INTEGRITY", "max": 1, "rare": true, "legend": true},
	{"id": "shield", "title": "BUFFER SHIELD", "desc": "BLOCKS ONE INCOMING HIT", "max": 3, "rare": true, "legend": false},
	{"id": "absorb", "title": "DAMAGE ABSORBER", "desc": "ABSORBS ONE HIT, +1 MOTE CHARGE", "max": 3, "rare": true, "legend": false},
	{"id": "recycler", "title": "RECYCLER", "desc": "+6% RECOVER CHANCE PER LEVEL", "max": 3, "rare": false, "legend": false},
	{"id": "dataleech", "title": "DATA LEECH", "desc": "ELITES ALWAYS DROP RECOVER", "max": 1, "rare": true, "legend": false},
	{"id": "splitshot", "title": "SPLITSHOT", "desc": "+1 ANGLED PROJECTILE, -10% FIRE RATE", "max": 2, "rare": true, "legend": false},
	{"id": "secondwind", "title": "SECOND WIND", "desc": "SURVIVE DEATH ONCE PER RUN, HEAL 1", "max": 1, "rare": true, "legend": true},
	{"id": "thorns", "title": "THORNS", "desc": "CONTACT REFLECTS 1 DAMAGE BACK", "max": 2, "rare": true, "legend": false},
	{"id": "turbo", "title": "TURBO DASH", "desc": "+12% DASH SPEED, KILLS SPEED RECHARGE", "max": 2, "rare": true, "legend": false},
	{"id": "scrapdiet", "title": "SCRAP DIET", "desc": "25 OVERFLOW MOTES HEAL 1 INTEGRITY", "max": 2, "rare": true, "legend": false},
]

const ONEHP_PATCH_EXCLUDED := ["hp", "restore", "vampic", "recycler", "dataleech", "secondwind", "scrapdiet"]

func onehp_patch_pool() -> Array:
	var pool: Array = []
	for d in PATCH_DEFS:
		if d["id"] not in ONEHP_PATCH_EXCLUDED:
			pool.append(d)
	return pool

func start_run() -> void:
	mode = mode if mode != "story" else "classic"
	Sfx.set_music_variant("normal")
	state = State.PLAYING
	score = 0
	mult = 1
	combo_left = 0.0
	combo_window = Balance.COMBO_WINDOW
	patch_levels = {}
	wave = 1
	_max_chain_seen = 1
	event_log.clear()
	terminal_heal_used = false
	Sfx.set_intensity(0)
	match mode:
		"weekly":
			run_seed = week_number() * 7919 + 13
			rng.seed = run_seed
		_:
			rng.randomize()
			run_seed = int(rng.seed)
	new_best = false
	stats = {"kills": 0, "shots": 0, "hits": 0, "damage": 0, "time": 0.0, "wave": 1, "boss_kills": 0, "heals": {}}
	log_event("BOOT // %s // SEED %d" % [program_def()["name"], run_seed])
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", "res://src/arena/arena.tscn")

func register_kill(base_pts: int, is_boss := false) -> void:
	mult = mini(mult + 1, Balance.COMBO_MAX)
	combo_left = combo_window
	score += base_pts * mult * score_mult()
	stats["kills"] += 1
	if int(stats["kills"]) == 1:
		log_event("FIRST BLOOD // daemon purged")
		unlock_achievement("first_blood")
	if is_boss:
		stats["boss_kills"] += 1
		log_event("BOSS PURGED // cycle %02d" % wave)
		unlock_achievement("boss_purge")
	_max_chain_seen = maxi(_max_chain_seen, mult)
	score_changed.emit(score, mult)
	combo_changed.emit(mult, 1.0)
	if mult == 4 or mult == Balance.COMBO_MAX:
		combo_milestone.emit(mult)
	if mult == Balance.COMBO_MAX:
		unlock_achievement("chain_max")

func recover_chance(is_elite: bool) -> float:
	if mode == "onehp":
		return 0.0
	var c := 0.25 if is_elite else 0.08
	c += 0.06 * patch_level("recycler")
	if is_elite and patch_level("dataleech") > 0:
		c = 1.0
	return minf(c, 1.0)

func register_heal(source: String) -> void:
	if not stats.has("heals"):
		stats["heals"] = {}
	stats["heals"][source] = int(stats["heals"].get(source, 0)) + 1
	log_event("INTEGRITY +1 // %s" % source.to_upper())

func log_event(message: String) -> void:
	var clean := message.strip_edges()
	if clean.is_empty():
		return
	event_log.append({"time": float(stats.get("time", 0.0)), "text": clean})
	while event_log.size() > EVENT_LOG_MAX:
		event_log.pop_front()

func dmesg_lines(limit: int = 14) -> Array[String]:
	var lines: Array[String] = []
	var start := maxi(event_log.size() - maxi(limit, 1), 0)
	for i in range(start, event_log.size()):
		var entry: Dictionary = event_log[i]
		lines.append("[%8.3f] %s" % [float(entry.get("time", 0.0)), str(entry.get("text", ""))])
	return lines

func consume_terminal_heal() -> bool:
	if state != State.PLAYING or mode == "onehp" or terminal_heal_used:
		return false
	terminal_heal_used = true
	log_event("sudo: heal permission granted")
	unlock_achievement("terminal_operator")
	return true

func unlock_achievement(id: String) -> bool:
	if not ACHIEVEMENT_DEFS.has(id) or achievements.has(id):
		return false
	var label := str(ACHIEVEMENT_DEFS[id])
	achievements[id] = true
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	cf.set_value("achievements", "unlocked", achievements)
	cf.save(Sfx.SAVE_PATH)
	log_event("achievement: %s enabled" % label)
	achievement_unlocked.emit(id, label)
	return true

func run_seed_text() -> String:
	return "SEED %d" % run_seed

func core_dump_text() -> String:
	var now := float(stats.get("time", 0.0))
	var tail: Array[String] = []
	for entry in event_log:
		var stamp := float(entry.get("time", 0.0))
		if stamp >= maxf(now - 5.0, 0.0):
			tail.append(str(entry.get("text", "")))
	var tail_text := " // ".join(tail.slice(maxi(tail.size() - 4, 0), tail.size()))
	if tail_text.is_empty():
		tail_text = "no recent events"
	return "SEGFAULT AT player.hp=0 // state dumped\nKILLER %s // HITS %d\nBUILD %s // %s // %s" % [str(stats.get("killer", "DAEMON")), int(stats.get("damage", 0)), build_string(), run_seed_text(), tail_text]

func export_save_string() -> String:
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	var payload := {
		"format": SAVE_TRANSFER_FORMAT,
		"version": SAVE_TRANSFER_VERSION,
		"run": {
			"best_classic": int(cf.get_value("run", "best_classic", best)),
			"best_onehp": int(cf.get_value("run", "best_onehp", 0)),
			"onehp_unlocked": bool(cf.get_value("run", "onehp_unlocked", onehp_unlocked)),
			"program": str(cf.get_value("run", "program", program)),
		},
		"weekly": {
			"id": str(cf.get_value("weekly", "id", "")),
			"best": int(cf.get_value("weekly", "best", 0)),
			"last_id": str(cf.get_value("weekly", "last_id", "")),
			"last_best": int(cf.get_value("weekly", "last_best", 0)),
		},
		"story": {
			"cleared": _known_bool_map(story_cleared, STORY_DATA.stage_ids()),
			"best": story_best.duplicate(true),
			"temple_rainbow_unlocked": temple_rainbow_unlocked,
		},
		"bestiary": _known_bool_map(bestiary, BESTIARY_MAP.values()),
		"programs": _known_bool_map(unlocked_programs, PROGRAM_DEFS.keys()),
		"achievements": _known_bool_map(achievements, ACHIEVEMENT_DEFS.keys()),
	}
	return Marshalls.raw_to_base64(JSON.stringify(payload).to_utf8_buffer())

func import_save_string(encoded: String) -> bool:
	var raw_text := encoded.strip_edges()
	if raw_text.is_empty() or raw_text.length() > 20000:
		return false
	var base64_re := RegEx.new()
	base64_re.compile("^[A-Za-z0-9+/]*={0,2}$")
	if raw_text.length() % 4 != 0 or base64_re.search(raw_text) == null:
		return false
	var raw := Marshalls.base64_to_raw(raw_text)
	if raw.is_empty():
		return false
	var parsed = JSON.parse_string(raw.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or parsed.get("format", "") != SAVE_TRANSFER_FORMAT or int(parsed.get("version", 0)) != SAVE_TRANSFER_VERSION:
		return false
	var run_data: Dictionary = parsed.get("run", {})
	var weekly_data: Dictionary = parsed.get("weekly", {})
	if not run_data is Dictionary or not weekly_data is Dictionary:
		return false
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	cf.set_value("run", "best_classic", maxi(int(run_data.get("best_classic", 0)), 0))
	cf.set_value("run", "best_onehp", maxi(int(run_data.get("best_onehp", 0)), 0))
	cf.set_value("run", "onehp_unlocked", bool(run_data.get("onehp_unlocked", false)))
	var imported_program := str(run_data.get("program", "kernel"))
	cf.set_value("run", "program", imported_program if PROGRAM_DEFS.has(imported_program) else "kernel")
	cf.set_value("weekly", "id", str(weekly_data.get("id", "")))
	cf.set_value("weekly", "best", maxi(int(weekly_data.get("best", 0)), 0))
	cf.set_value("weekly", "last_id", str(weekly_data.get("last_id", "")))
	cf.set_value("weekly", "last_best", maxi(int(weekly_data.get("last_best", 0)), 0))
	var imported_story: Dictionary = parsed.get("story", {})
	if imported_story is Dictionary:
		cf.set_value("story", "cleared", _known_bool_map(imported_story.get("cleared", {}), STORY_DATA.stage_ids()))
		var imported_story_best: Dictionary = imported_story.get("best", {})
		var clean_story_best := {}
		if imported_story_best is Dictionary:
			for stage_id in STORY_DATA.stage_ids():
				clean_story_best[stage_id] = maxi(int(imported_story_best.get(stage_id, 0)), 0)
		cf.set_value("story", "best", clean_story_best)
		cf.set_value("story", "temple_rainbow_unlocked", bool(imported_story.get("temple_rainbow_unlocked", false)))
	cf.set_value("bestiary", "seen", _known_bool_map(parsed.get("bestiary", {}), BESTIARY_MAP.values()))
	var imported_programs := _known_bool_map(parsed.get("programs", {}), PROGRAM_DEFS.keys())
	imported_programs["kernel"] = true
	cf.set_value("programs", "unlocked", imported_programs)
	cf.set_value("achievements", "unlocked", _known_bool_map(parsed.get("achievements", {}), ACHIEVEMENT_DEFS.keys()))
	if cf.save(Sfx.SAVE_PATH) != OK:
		return false
	_load_run_config()
	return true

func _known_bool_map(raw, allowed: Array) -> Dictionary:
	var result := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return result
	for key in allowed:
		var id := str(key)
		if bool(raw.get(id, false)):
			result[id] = true
	return result

func patch_level(id: String) -> int:
	return int(patch_levels.get(id, 0))

func roll_patch_offer() -> Array:
	var pool: Array = []
	var definitions: Array = onehp_patch_pool() if mode == "onehp" else PATCH_DEFS
	for d in definitions:
		if patch_level(d["id"]) < int(d["max"]):
			pool.append(d)
	var picks: Array = []
	var guard := 40
	while picks.size() < 3 and pool.size() > 0 and guard > 0:
		guard -= 1
		var rare_pool: Array = pool.filter(func(d): return d["rare"])
		var d: Dictionary
		var legend_pool: Array = pool.filter(func(d): return d.get("legend", false))
		if legend_pool.size() > 0 and rng.randf() < 0.10:
			d = legend_pool[rng.randi() % legend_pool.size()]
		elif rare_pool.size() > 0 and rng.randf() < 0.20:
			d = rare_pool[rng.randi() % rare_pool.size()]
		else:
			d = pool[rng.randi() % pool.size()]
		if not picks.has(d):
			picks.append(d)
			pool.erase(d)
	return picks

func apply_patch(id: String) -> void:
	patch_levels[id] = patch_level(id) + 1
	if id == "chain":
		combo_window = Balance.COMBO_WINDOW + 0.8 * patch_level("chain")
	patch_picked.emit(id)

func add_score(n: int) -> void:
	score += n * score_mult()
	score_changed.emit(score, mult)

func break_combo() -> void:
	if mult > 1:
		mult = 1
		combo_left = 0.0
		combo_changed.emit(mult, 0.0)

func end_run() -> void:
	if state != State.PLAYING:
		return
	state = State.GAME_OVER
	stats["wave"] = wave
	stats["time"] = snappedf(stats["time"], 0.1)
	if score > best_for_mode():
		new_best = true
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	match mode:
		"story":
			new_best = false
		"weekly":
			var wid := week_id()
			if cf.get_value("weekly", "id", "") != wid:
				cf.set_value("weekly", "last_id", cf.get_value("weekly", "id", ""))
				cf.set_value("weekly", "last_best", cf.get_value("weekly", "best", 0))
				cf.set_value("weekly", "id", wid)
				cf.set_value("weekly", "best", 0)
			if score > cf.get_value("weekly", "best", 0):
				cf.set_value("weekly", "best", score)
		"onehp":
			if score > cf.get_value("run", "best_onehp", 0):
				cf.set_value("run", "best_onehp", score)
			else:
				new_best = false
		_:
			if score > best:
				best = score
				cf.set_value("run", "best_classic", score)
			else:
				new_best = false
	cf.save(Sfx.SAVE_PATH)
	run_ended.emit(stats)
	var lf := ConfigFile.new()
	lf.load(Sfx.SAVE_PATH)
	lf.set_value("lifetime", "runs", int(lf.get_value("lifetime", "runs", 0)) + 1)
	lf.set_value("lifetime", "kills", int(lf.get_value("lifetime", "kills", 0)) + int(stats["kills"]))
	lf.set_value("lifetime", "best_chain", maxi(int(lf.get_value("lifetime", "best_chain", 0)), _max_chain_seen))
	var kd: Dictionary = lf.get_value("lifetime", "killers", {})
	var kname: String = stats.get("killer", "DAEMON")
	kd[kname] = int(kd.get(kname, 0)) + 1
	lf.set_value("lifetime", "killers", kd)
	lf.save(Sfx.SAVE_PATH)

func complete_story_stage() -> bool:
	if mode != "story" or state != State.PLAYING:
		return false
	var index := story_stage_index
	var id := story_stage_id(index)
	end_run()
	if id.is_empty():
		return false
	story_cleared[id] = true
	var previous_best := story_stage_best(index)
	if score > previous_best:
		story_best[id] = score
		new_best = true
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	cf.set_value("story", "cleared", story_cleared)
	cf.set_value("story", "best", story_best)
	if id == "temple_god":
		temple_rainbow_unlocked = true
		cf.set_value("story", "temple_rainbow_unlocked", true)
	cf.save(Sfx.SAVE_PATH)
	if id == "mem" and not unlocked_programs.has("rootlet"):
		unlock_program("rootlet")
	log_event("STORY CLEAR // %s" % id.to_upper())
	return true

func to_menu() -> void:
	state = State.MENU
	Sfx.set_music_variant("normal")
	Sfx.set_intensity(0)
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", "res://src/ui/menu.tscn")

func _setup_input() -> void:
	_load_keybinds()
	for action in KEYBIND_DEFAULTS:
		_apply_keybind_to_input(action)
	_add_mouse_action("fire", MOUSE_BUTTON_LEFT)
	_add_mouse_action("dash", MOUSE_BUTTON_RIGHT)

func keybind_defaults() -> Dictionary:
	return KEYBIND_DEFAULTS.duplicate()

func keybinds_snapshot() -> Dictionary:
	return keybinds.duplicate()

func get_keybind(action: String) -> int:
	return int(keybinds.get(action, KEYBIND_DEFAULTS.get(action, 0)))

func reload_keybinds() -> void:
	_setup_input()

func _load_keybinds() -> void:
	keybinds.clear()
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	for action in KEYBIND_DEFAULTS:
		var fallback := int(KEYBIND_DEFAULTS[action])
		var saved = cf.get_value("controls", action, fallback)
		var code := int(saved) if typeof(saved) == TYPE_INT else 0
		keybinds[action] = code if code > 0 else fallback

func keybind_conflict(physical_key: int, except_action: String = "") -> String:
	if physical_key <= 0:
		return "INVALID KEY"
	for action in KEYBIND_DEFAULTS:
		if action == except_action:
			continue
		if get_keybind(action) == physical_key:
			return action
		for alternate in KEYBIND_ALTERNATES.get(action, []):
			if int(alternate) == physical_key:
				return action
	return ""

func set_keybind(action: String, physical_key: int) -> bool:
	if not KEYBIND_DEFAULTS.has(action) or physical_key <= 0:
		return false
	if keybind_conflict(physical_key, action) != "":
		return false
	keybinds[action] = physical_key
	_apply_keybind_to_input(action)
	_save_keybinds()
	return true

func reset_keybinds() -> void:
	keybinds = KEYBIND_DEFAULTS.duplicate()
	for action in KEYBIND_DEFAULTS:
		_apply_keybind_to_input(action)
	_save_keybinds()

func _save_keybinds() -> void:
	var cf := ConfigFile.new()
	cf.load(Sfx.SAVE_PATH)
	for action in KEYBIND_DEFAULTS:
		cf.set_value("controls", action, get_keybind(action))
	cf.save(Sfx.SAVE_PATH)

func _apply_keybind_to_input(action: String) -> void:
	var keys: Array = [get_keybind(action)]
	for alternate in KEYBIND_ALTERNATES.get(action, []):
		if not keys.has(alternate):
			keys.append(alternate)
	_clear_key_events(action)
	_add_key_action(action, keys)

func _add_key_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		if int(k) <= 0:
			continue
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)

func _clear_key_events(action: String) -> void:
	if not InputMap.has_action(action):
		return
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)

func _add_mouse_action(action: String, btn: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = btn
	InputMap.action_add_event(action, ev)

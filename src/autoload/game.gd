extends Node

signal score_changed(score: int, mult: int)
signal combo_changed(mult: int, frac: float)
signal run_ended(stats: Dictionary)
signal mute_changed(muted: bool)
signal patch_offered
signal patch_picked(id: String)
signal combo_milestone(mult: int)
signal bestiary_unlocked(id: String)

enum State { MENU, PLAYING, GAME_OVER }

var combo_window := Balance.COMBO_WINDOW
var patch_levels := {}
var mode := "classic"
var program := "kernel"
var vampic_cd := 0.0
const VAMPIC_COOLDOWN := 10.0
var unlocked_programs := {"kernel": true}
var onehp_unlocked := false
var bestiary := {}
var rng := RandomNumberGenerator.new()
var _max_chain_seen := 1

const COMBO_WINDOW := Balance.COMBO_WINDOW

var state: int = State.MENU
var score := 0
var best := 0
var mult := 1
var combo_left := 0.0
var wave := 1
var stats := {}
var new_best := false

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()

func _ready() -> void:
	_load_run_config()

const PROGRAM_DEFS := {
	"kernel": {"name": "KERNEL", "desc": "balanced standard process", "hp": 4, "speed_mul": 1.0, "dmg_bonus": 0, "rate_mul": 1.0, "range_mul": 1.0, "dash_charges": 1},
	"daemon": {"name": "DAEMON", "desc": "3 HP. short range. hot close fire rate. kills recharge dash. 2 dash charges.", "hp": 3, "speed_mul": 1.0, "dmg_bonus": 0, "rate_mul": 1.0, "range_mul": 0.72, "dash_charges": 2, "close_rate_mul": 1.6, "close_range": 160.0, "kill_dash_refund": 0.7},
	"rootlet": {"name": "ROOTLET", "desc": "5 HP. slow. heavy shots. shield instead of overclock.", "hp": 5, "speed_mul": 0.85, "dmg_bonus": 1, "rate_mul": 0.8, "range_mul": 1.0, "dash_charges": 1, "shield_mode": true},
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

func _load_run_config() -> void:
	var cf := ConfigFile.new()
	if cf.load(Sfx.SAVE_PATH) == OK:
		best = cf.get_value("run", "best_classic", cf.get_value("run", "best", 0))
		onehp_unlocked = cf.get_value("run", "onehp_unlocked", false)
		bestiary = cf.get_value("bestiary", "seen", {})
		mode = cf.get_value("game", "mode", "classic")
		if mode == "onehp" and not onehp_unlocked:
			mode = "classic"
		unlocked_programs = cf.get_value("programs", "unlocked", {"kernel": true})
		if not unlocked_programs.has("kernel"):
			unlocked_programs["kernel"] = true
		var saved_prog: String = cf.get_value("run", "program", "kernel")
		if unlocked_programs.has(saved_prog):
			program = saved_prog
	rng.randomize()

func week_number() -> int:
	var days := int(Time.get_unix_time_from_system() / 86400.0)
	return int(float(days + 3) / 7.0)

func week_id() -> String:
	return "W%d" % week_number()

func best_for_mode() -> int:
	match mode:
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
	if mode == "weekly" and Sfx.aim_mode == "lockon":
		return "stick"
	return Sfx.aim_mode

func score_mult() -> int:
	return 3 if mode == "onehp" else 1

const BESTIARY_MAP := {"DRONE": "drone", "LANCER": "lancer", "SPEWER": "spewer", "SPLITTER": "splitter", "BULWARK": "bulwark", "TROJAN": "trojan", "OOM_KILLER": "oom", "ROOT": "boss", "RECURSOR": "recursor", "FIREWALL": "firewall", "ROOT.exe": "root", "SEGFAULT": "segfault", "BLUE SCREEN": "bluescreen", "PAGE FAULT": "pagefault"}

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

func bestiary_seen(id: String) -> bool:
	return bestiary.has(id)

const PATCH_CODES := {"rapid": "RP", "cell": "OC", "magnet": "MG", "hp": "HP", "dash": "PH", "frag": "FR", "threads": "TH", "chain": "CH", "core": "HC", "restore": "SR", "light": "LF", "mdash": "MD", "heavy": "HV", "ricochet": "RC", "pdash": "PD", "staticf": "SF", "vampic": "VP", "recycler": "RY", "dataleech": "DL", "splitshot": "SP", "secondwind": "SW", "thorns": "TN", "turbo": "TD", "scrapdiet": "SD"}

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
	{"id": "recycler", "title": "RECYCLER", "desc": "+6% RECOVER CHANCE PER LEVEL", "max": 3, "rare": false, "legend": false},
	{"id": "dataleech", "title": "DATA LEECH", "desc": "ELITES ALWAYS DROP RECOVER", "max": 1, "rare": true, "legend": false},
	{"id": "splitshot", "title": "SPLITSHOT", "desc": "+1 ANGLED PROJECTILE, -10% FIRE RATE", "max": 2, "rare": true, "legend": false},
	{"id": "secondwind", "title": "SECOND WIND", "desc": "SURVIVE DEATH ONCE PER RUN, HEAL 1", "max": 1, "rare": true, "legend": true},
	{"id": "thorns", "title": "THORNS", "desc": "CONTACT REFLECTS 1 DAMAGE BACK", "max": 2, "rare": true, "legend": false},
	{"id": "turbo", "title": "TURBO DASH", "desc": "+12% DASH SPEED, KILLS SPEED RECHARGE", "max": 2, "rare": true, "legend": false},
	{"id": "scrapdiet", "title": "SCRAP DIET", "desc": "25 OVERFLOW MOTES HEAL 1 INTEGRITY", "max": 2, "rare": true, "legend": false},
]

func start_run() -> void:
	state = State.PLAYING
	score = 0
	mult = 1
	combo_left = 0.0
	combo_window = Balance.COMBO_WINDOW
	patch_levels = {}
	wave = 1
	_max_chain_seen = 1
	Sfx.set_intensity(0)
	match mode:
		"weekly":
			rng.seed = week_number() * 7919 + 13
		_:
			rng.randomize()
	new_best = false
	stats = {"kills": 0, "shots": 0, "hits": 0, "damage": 0, "time": 0.0, "wave": 1, "boss_kills": 0, "heals": {}}
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", "res://src/arena/arena.tscn")

func register_kill(base_pts: int, is_boss := false) -> void:
	mult = mini(mult + 1, Balance.COMBO_MAX)
	combo_left = combo_window
	score += base_pts * mult * score_mult()
	stats["kills"] += 1
	if is_boss:
		stats["boss_kills"] += 1
	_max_chain_seen = maxi(_max_chain_seen, mult)
	score_changed.emit(score, mult)
	combo_changed.emit(mult, 1.0)
	if mult == 4 or mult == Balance.COMBO_MAX:
		combo_milestone.emit(mult)

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

func patch_level(id: String) -> int:
	return int(patch_levels.get(id, 0))

func roll_patch_offer() -> Array:
	var pool: Array = []
	for d in PATCH_DEFS:
		if mode == "onehp" and (d["id"] == "dataleech" or d["id"] == "recycler" or d["id"] == "secondwind" or d["id"] == "scrapdiet"):
			continue
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

func to_menu() -> void:
	state = State.MENU
	Sfx.set_intensity(0)
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", "res://src/ui/menu.tscn")

func _setup_input() -> void:
	_add_key_action("move_up", [KEY_W, KEY_UP])
	_add_key_action("move_down", [KEY_S, KEY_DOWN])
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("dash", [KEY_SPACE, KEY_SHIFT])
	_add_key_action("overclock", [KEY_E, KEY_Q])
	_add_key_action("pause", [KEY_ESCAPE, KEY_P])
	_add_key_action("mute", [KEY_M])
	_add_key_action("confirm", [KEY_ENTER, KEY_KP_ENTER])
	_add_key_action("restart", [KEY_R])
	_add_mouse_action("fire", MOUSE_BUTTON_LEFT)
	_add_mouse_action("dash", MOUSE_BUTTON_RIGHT)

func _add_key_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)

func _add_mouse_action(action: String, btn: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = btn
	InputMap.action_add_event(action, ev)

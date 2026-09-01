extends Node

var _fails := 0

const PROGRAM_IDS := ["kernel", "daemon", "rootlet"]
const BESTIARY_IDS := ["drone", "lancer", "spewer", "splitter", "bulwark", "trojan", "oom", "boss", "root", "segfault", "bluescreen", "pagefault", "recursor", "firewall", "update_loop", "bloatware", "god"]
const PATCH_IDS := ["rapid", "cell", "magnet", "hp", "dash", "frag", "threads", "chain", "light", "mdash", "heavy", "core", "restore", "ricochet", "pdash", "staticf", "vampic", "shield", "absorb", "recycler", "dataleech", "splitshot", "secondwind", "thorns", "turbo", "scrapdiet"]
const ACHIEVEMENT_IDS := ["first_blood", "boss_purge", "chain_max", "terminal_operator", "integrity_restored"]

## Independent compatibility fixtures. These intentionally duplicate the old
## public fields so a catalog edit cannot silently change runtime content while
## keeping only IDs and order stable.
const EXPECTED_PROGRAM_DEFS := {
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

const EXPECTED_BESTIARY_LEGACY_FIELDS := [
	{"id": "drone", "name": "DRONE", "desc": "basic corrupted process. dash through packs.", "threat": 50, "bugs": "swarms without a scheduler. forever."},
	{"id": "lancer", "name": "LANCER", "desc": "telegraphs then lunges. sidestep the line, punish the stagger.", "threat": 90, "bugs": "lunges in a straight line. sidestep = fix."},
	{"id": "spewer", "name": "SPEWER", "desc": "keeps distance, spits orbs. shoot the orbs down.", "threat": 110, "bugs": "orbs are shootable. it has not learned this."},
	{"id": "splitter", "name": "SPLITTER", "desc": "splits on death. kill it away from you.", "threat": 100, "bugs": "death is a fork(). plan accordingly."},
	{"id": "bulwark", "name": "BULWARK", "desc": "armored and slow. dash past, never hug.", "threat": 300, "bugs": "armor does not cover the back. or manners."},
	{"id": "trojan", "name": "TROJAN", "desc": "leaves corruption pools. do not swim.", "threat": 140, "bugs": "leaves pools. calls them 'features'."},
	{"id": "oom", "name": "OOM_KILLER", "desc": "steals your motes and runs. hunt it first.", "threat": 150, "bugs": "steals motes. returns nothing. ever."},
	{"id": "boss", "name": "ROOT DAEMON", "desc": "every variant has a tell. learn it. respect it.", "threat": 2500, "bugs": "segfaults reproduce. two of them."},
	{"id": "root", "name": "ROOT.exe", "desc": "splits at half integrity. track both processes.", "threat": 2500, "bugs": "forks once. both children are real."},
	{"id": "segfault", "name": "SEGFAULT", "desc": "glitches, teleports, then opens a lance line.", "threat": 5000, "bugs": "address is invalid. movement is not."},
	{"id": "bluescreen", "name": "BLUE SCREEN", "desc": "freezes systems and floods the arena with fan shots.", "threat": 7500, "bugs": "the error is blue. the projectiles are not."},
	{"id": "pagefault", "name": "PAGE FAULT", "desc": "pages shield it until the orbiting nodes are purged.", "threat": 10000, "bugs": "read protection enabled. delete the pages."},
	{"id": "recursor", "name": "RECURSOR", "desc": "teleports and leaves corruption. pools mark where it was. keep moving.", "threat": 140, "bugs": "leaves corruption where it *was*. check behind you."},
	{"id": "firewall", "name": "FIREWALL", "desc": "rotating wall of orbs. kill the wall to drop the wall.", "threat": 180, "bugs": "wall persists after death of nearby processes."},
	{"id": "update_loop", "name": "UPDATE_LOOP", "desc": "reinstalls once after death. finish the update before celebrating.", "threat": 190, "bugs": "dies, says 'reinstalling', returns with fewer excuses."},
	{"id": "bloatware", "name": "BLOATWARE", "desc": "fat process. drops static popup orbs and spawns background drones.", "threat": 450, "bugs": "47 background processes terminated on exit."},
	{"id": "god", "name": "GOD", "desc": "oracle process. chooses its next attack by literal random roll.", "threat": 777, "bugs": "the attack pattern is not a pattern. it is a result."},
]

const EXPECTED_PATCH_DEFS := [
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
	{"id": "staticf", "title": "STATIC FIELD", "desc": "BURNS ENEMIES WITHIN 70PX", "max": 2, "rare": true, "legend": true},
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

const EXPECTED_ACHIEVEMENT_HINTS := {
	"first_blood": "Terminate your first daemon.",
	"boss_purge": "Take down a ROOT-class boss.",
	"chain_max": "Push the combo meter to its maximum multiplier.",
	"terminal_operator": "Grant a sudo heal in the terminal.",
	"integrity_restored": "Recover integrity after it drops.",
}

const EXPECTED_BESTIARY_MAP := {"DRONE": "drone", "LANCER": "lancer", "SPEWER": "spewer", "SPLITTER": "splitter", "BULWARK": "bulwark", "TROJAN": "trojan", "OOM_KILLER": "oom", "ROOT": "boss", "RECURSOR": "recursor", "FIREWALL": "firewall", "UPDATE_LOOP": "update_loop", "BLOATWARE": "bloatware", "GOD": "god", "ROOT.exe": "root", "SEGFAULT": "segfault", "BLUE SCREEN": "bluescreen", "PAGE FAULT": "pagefault"}
const EXPECTED_PATCH_CODES := {"rapid": "RP", "cell": "OC", "magnet": "MG", "hp": "HP", "dash": "PH", "frag": "FR", "threads": "TH", "chain": "CH", "core": "HC", "restore": "SR", "light": "LF", "mdash": "MD", "heavy": "HV", "ricochet": "RC", "pdash": "PD", "staticf": "SF", "vampic": "VP", "recycler": "RY", "dataleech": "DL", "splitshot": "SP", "secondwind": "SW", "thorns": "TN", "turbo": "TD", "scrapdiet": "SD", "shield": "SH", "absorb": "AB"}
const EXPECTED_PATCH_RELATIONS := {"heavy": {"splitshot": "TRADEOFF: HEAVY + SPLITSHOT BOTH REDUCE FIRE RATE"}, "splitshot": {"heavy": "TRADEOFF: HEAVY + SPLITSHOT BOTH REDUCE FIRE RATE"}}
const EXPECTED_ONEHP_PATCH_EXCLUDED := ["hp", "restore", "vampic", "recycler", "dataleech", "secondwind", "scrapdiet"]

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PROBE_PASS ", message)
	else:
		_fails += 1
		print("PROBE_FAIL ", message)

func _run() -> void:
	var catalog_script: Script = load("res://src/data/content_catalog.gd")
	_check(catalog_script != null, "content catalog script loads")
	var catalog = catalog_script.new() if catalog_script != null else null
	_check(catalog != null and catalog.has_method("program_defs"), "catalog exposes program definitions")
	_check(catalog != null and catalog.has_method("bestiary_entries"), "catalog exposes bestiary entries")
	_check(catalog != null and catalog.has_method("patch_defs"), "catalog exposes patch definitions")
	_check(catalog != null and catalog.has_method("achievement_defs"), "catalog exposes achievement definitions")
	_check(catalog != null and catalog.has_method("bestiary_map"), "catalog exposes bestiary mapping")
	if catalog == null:
		_finish()
		return

	var programs: Dictionary = catalog.program_defs()
	var program_order: Array = programs.keys()
	_check(program_order == PROGRAM_IDS, "program IDs and order remain stable")
	_check(programs == EXPECTED_PROGRAM_DEFS, "program content remains byte-for-byte equivalent")
	_check(Game.PROGRAM_DEFS == programs, "Game program compatibility alias matches catalog")
	var program_copy: Dictionary = catalog.program_defs()
	program_copy["kernel"]["name"] = "MUTATED"
	_check(str(catalog.program_defs()["kernel"]["name"]) == "KERNEL", "program accessor returns a defensive deep copy")

	var entries: Array = catalog.bestiary_entries()
	var bestiary_order: Array = []
	for entry in entries:
		bestiary_order.append(str(entry.get("id", "")))
		_check(not str(entry.get("id", "")).is_empty() and not str(entry.get("name", "")).is_empty() and not str(entry.get("desc", "")).is_empty() and not str(entry.get("bugs", "")).is_empty(), "bestiary entry %s has display fields" % str(entry.get("id", "")))
		_check(entry.get("threat", 0) is int and int(entry.get("threat", 0)) > 0, "bestiary entry %s has numeric threat" % str(entry.get("id", "")))
		_check(not str(entry.get("threat_class", "")).is_empty() and not str(entry.get("glyph_key", "")).is_empty(), "bestiary entry %s has threat class and glyph key" % str(entry.get("id", "")))
	_check(bestiary_order == BESTIARY_IDS, "bestiary IDs and order remain stable")
	var bestiary_legacy_projection: Array = []
	for entry in entries:
		bestiary_legacy_projection.append({"id": entry.get("id", ""), "name": entry.get("name", ""), "desc": entry.get("desc", ""), "threat": entry.get("threat", 0), "bugs": entry.get("bugs", "")})
	_check(bestiary_legacy_projection == EXPECTED_BESTIARY_LEGACY_FIELDS, "bestiary legacy content remains byte-for-byte equivalent")
	_check(BestiaryPanel.ENTRIES == entries, "Bestiary compatibility alias matches catalog")
	var entry_copy: Array = catalog.bestiary_entries()
	entry_copy[0]["name"] = "MUTATED"
	_check(str(catalog.bestiary_entries()[0]["name"]) == "DRONE", "bestiary accessor returns a defensive deep copy")

	var patch_defs: Array = catalog.patch_defs()
	var patch_order: Array = []
	for definition in patch_defs:
		patch_order.append(str(definition.get("id", "")))
	_check(patch_order == PATCH_IDS, "patch IDs and order remain stable")
	_check(patch_defs == EXPECTED_PATCH_DEFS, "patch content remains byte-for-byte equivalent")
	_check(Game.PATCH_DEFS == patch_defs, "Game patch compatibility alias matches catalog")
	var patch_copy: Array = catalog.patch_defs()
	patch_copy[0]["title"] = "MUTATED"
	_check(str(catalog.patch_defs()[0]["title"]) == "RAPID LOOPS", "patch accessor returns a defensive deep copy")
	_check(Game.PATCH_CODES == EXPECTED_PATCH_CODES and Game.PATCH_CODES == catalog.patch_codes(), "patch codes remain equivalent and aliased")
	var patch_codes_copy: Dictionary = catalog.patch_codes()
	patch_codes_copy["rapid"] = "MUTATED"
	_check(str(catalog.patch_codes()["rapid"]) == "RP", "patch code accessor returns a defensive copy")
	_check(Game.PATCH_RELATIONS == EXPECTED_PATCH_RELATIONS and Game.PATCH_RELATIONS == catalog.patch_relations(), "patch relations remain equivalent and aliased")
	var patch_relations_copy: Dictionary = catalog.patch_relations()
	patch_relations_copy["heavy"]["splitshot"] = "MUTATED"
	_check(str(catalog.patch_relations()["heavy"]["splitshot"]) == "TRADEOFF: HEAVY + SPLITSHOT BOTH REDUCE FIRE RATE", "nested patch relation accessor is defensive")
	_check(Game.ONEHP_PATCH_EXCLUDED == EXPECTED_ONEHP_PATCH_EXCLUDED and Game.ONEHP_PATCH_EXCLUDED == catalog.onehp_patch_excluded(), "one-hp exclusions remain equivalent and aliased")
	var onehp_copy: Array = catalog.onehp_patch_excluded()
	onehp_copy[0] = "MUTATED"
	_check(str(catalog.onehp_patch_excluded()[0]) == "hp", "one-hp exclusion accessor returns a defensive copy")

	var achievement_defs: Dictionary = catalog.achievement_defs()
	_check(achievement_defs.keys() == ACHIEVEMENT_IDS, "achievement IDs and order remain stable")
	_check(achievement_defs == {"first_blood": "FIRST_BLOOD", "boss_purge": "ROOT_ACCESS", "chain_max": "CHAIN_REACTION", "terminal_operator": "TERMINAL_OPERATOR", "integrity_restored": "INTEGRITY_RESTORED"}, "achievement labels remain byte-for-byte equivalent")
	_check(Game.ACHIEVEMENT_DEFS == achievement_defs, "Game achievement compatibility alias matches catalog")
	_check(catalog.achievement_hints() == EXPECTED_ACHIEVEMENT_HINTS, "achievement hints remain byte-for-byte equivalent")
	_check(AchievementsPanel.ACHIEVEMENT_HINTS == catalog.achievement_hints(), "AchievementsPanel compatibility alias matches catalog")
	var hints_copy: Dictionary = catalog.achievement_hints()
	hints_copy["first_blood"] = "MUTATED"
	_check(str(catalog.achievement_hints()["first_blood"]) == "Terminate your first daemon.", "achievement hint accessor returns a defensive copy")

	var story_script: Script = load("res://src/story/story_data.gd")
	_check(story_script != null and Game.STORY_DATA == story_script, "StoryData remains the single stage source")
	_check(not _source_contains("res://src/autoload/game.gd", "const STAGES :="), "Game does not duplicate StoryData stages")
	_check(not _source_contains("res://src/ui/story_panel.gd", "const STAGES :="), "StoryPanel does not duplicate StoryData stages")
	_check(not _source_contains("res://src/ui/program_panel.gd", "RAPID LOOPS"), "program drawing code does not contain static content labels")
	_check(not _source_contains("res://src/ui/bestiary_panel.gd", "basic corrupted process"), "bestiary drawing code does not contain static content labels")
	_check(not _source_contains("res://src/autoload/game.gd", "const PROGRAM_DEFS := {"), "Game has no duplicate program table")
	_check(not _source_contains("res://src/autoload/game.gd", "const PATCH_DEFS := ["), "Game has no duplicate patch table")
	_check(not _source_contains("res://src/ui/bestiary_panel.gd", "const ENTRIES := ["), "BestiaryPanel has no duplicate bestiary table")

	_finish()

func _source_contains(path: String, needle: String) -> bool:
	return FileAccess.get_file_as_string(path).contains(needle)

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

class_name ContentCatalog
extends RefCounted

## Static content shared by runtime state and code-drawn presentation.
## Accessors return deep copies; compatibility constants point at these tables.

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

const BESTIARY_MAP := {"DRONE": "drone", "LANCER": "lancer", "SPEWER": "spewer", "SPLITTER": "splitter", "BULWARK": "bulwark", "TROJAN": "trojan", "OOM_KILLER": "oom", "ZOMBIE_PROCESS": "zombie_process", "RACE_CONDITION": "race_condition", "ROOT": "boss", "RECURSOR": "recursor", "FIREWALL": "firewall", "UPDATE_LOOP": "update_loop", "BLOATWARE": "bloatware", "GOD": "god", "ROOT.exe": "root", "SEGFAULT": "segfault", "BLUE SCREEN": "bluescreen", "PAGE FAULT": "pagefault"}

const BESTIARY_ENTRIES := [
	{"id": "drone", "name": "DRONE", "desc": "basic corrupted process. dash through packs.", "threat": 50, "threat_class": "standard", "glyph_key": "drone", "bugs": "swarms without a scheduler. forever."},
	{"id": "lancer", "name": "LANCER", "desc": "telegraphs then lunges. sidestep the line, punish the stagger.", "threat": 90, "threat_class": "standard", "glyph_key": "lancer", "bugs": "lunges in a straight line. sidestep = fix."},
	{"id": "spewer", "name": "SPEWER", "desc": "keeps distance, spits orbs. shoot the orbs down.", "threat": 110, "threat_class": "standard", "glyph_key": "spewer", "bugs": "orbs are shootable. it has not learned this."},
	{"id": "splitter", "name": "SPLITTER", "desc": "splits on death. kill it away from you.", "threat": 100, "threat_class": "standard", "glyph_key": "splitter", "bugs": "death is a fork(). plan accordingly."},
	{"id": "bulwark", "name": "BULWARK", "desc": "armored and slow. dash past, never hug.", "threat": 300, "threat_class": "elite", "glyph_key": "bulwark", "bugs": "armor does not cover the back. or manners."},
	{"id": "trojan", "name": "TROJAN", "desc": "leaves corruption pools. do not swim.", "threat": 140, "threat_class": "standard", "glyph_key": "trojan", "bugs": "leaves pools. calls them 'features'."},
	{"id": "oom", "name": "OOM_KILLER", "desc": "steals your motes and runs. hunt it first.", "threat": 150, "threat_class": "standard", "glyph_key": "oom", "bugs": "steals motes. returns nothing. ever."},
	{"id": "zombie_process", "name": "ZOMBIE_PROCESS", "desc": "temporary dead shell blocks player bullets. wait or reposition.", "threat": 80, "threat_class": "hazard", "glyph_key": "zombie_process", "bugs": "no pathing, no rewards, no resurrection. just clutter."},
	{"id": "race_condition", "name": "RACE_CONDITION", "desc": "linked pair moves faster while close. separate them, then purge each process.", "threat": 220, "threat_class": "hazard", "glyph_key": "race_condition", "bugs": "two valid processes share one bad timing assumption. distance is the fix."},
	{"id": "boss", "name": "ROOT DAEMON", "desc": "every variant has a tell. learn it. respect it.", "threat": 2500, "threat_class": "boss", "glyph_key": "boss", "bugs": "segfaults reproduce. two of them."},
	{"id": "root", "name": "ROOT.exe", "desc": "splits at half integrity. track both processes.", "threat": 2500, "threat_class": "boss", "glyph_key": "root", "bugs": "forks once. both children are real."},
	{"id": "segfault", "name": "SEGFAULT", "desc": "glitches, teleports, then opens a lance line.", "threat": 5000, "threat_class": "boss", "glyph_key": "segfault", "bugs": "address is invalid. movement is not."},
	{"id": "bluescreen", "name": "BLUE SCREEN", "desc": "freezes systems and floods the arena with fan shots.", "threat": 7500, "threat_class": "boss", "glyph_key": "bluescreen", "bugs": "the error is blue. the projectiles are not."},
	{"id": "pagefault", "name": "PAGE FAULT", "desc": "pages shield it until the orbiting nodes are purged.", "threat": 10000, "threat_class": "boss", "glyph_key": "pagefault", "bugs": "read protection enabled. delete the pages."},
	{"id": "recursor", "name": "RECURSOR", "desc": "teleports and leaves corruption. pools mark where it was. keep moving.", "threat": 140, "threat_class": "standard", "glyph_key": "recursor", "bugs": "leaves corruption where it *was*. check behind you."},
	{"id": "firewall", "name": "FIREWALL", "desc": "rotating wall of orbs. kill the wall to drop the wall.", "threat": 180, "threat_class": "standard", "glyph_key": "firewall", "bugs": "wall persists after death of nearby processes."},
	{"id": "update_loop", "name": "UPDATE_LOOP", "desc": "reinstalls once after death. finish the update before celebrating.", "threat": 190, "threat_class": "standard", "glyph_key": "update_loop", "bugs": "dies, says 'reinstalling', returns with fewer excuses."},
	{"id": "bloatware", "name": "BLOATWARE", "desc": "fat process. drops static popup orbs and spawns background drones.", "threat": 450, "threat_class": "elite", "glyph_key": "bloatware", "bugs": "47 background processes terminated on exit."},
	{"id": "god", "name": "GOD", "desc": "oracle process. chooses its next attack by literal random roll.", "threat": 777, "threat_class": "boss", "glyph_key": "god", "bugs": "the attack pattern is not a pattern. it is a result."},
]

const ACHIEVEMENT_DEFS := {
	"first_blood": "FIRST_BLOOD",
	"boss_purge": "ROOT_ACCESS",
	"chain_max": "CHAIN_REACTION",
	"terminal_operator": "TERMINAL_OPERATOR",
	"integrity_restored": "INTEGRITY_RESTORED",
}

const ACHIEVEMENT_HINTS := {
	"first_blood": "Terminate your first daemon.",
	"boss_purge": "Take down a ROOT-class boss.",
	"chain_max": "Push the combo meter to its maximum multiplier.",
	"terminal_operator": "Grant a sudo heal in the terminal.",
	"integrity_restored": "Recover integrity after it drops.",
}

const PATCH_CODES := {"rapid": "RP", "cell": "OC", "magnet": "MG", "pagecache": "PC", "ring0": "R0", "hp": "HP", "dash": "PH", "frag": "FR", "threads": "TH", "chain": "CH", "core": "HC", "restore": "SR", "light": "LF", "mdash": "MD", "heavy": "HV", "ricochet": "RC", "pdash": "PD", "staticf": "SF", "vampic": "VP", "recycler": "RY", "dataleech": "DL", "splitshot": "SP", "secondwind": "SW", "thorns": "TN", "turbo": "TD", "scrapdiet": "SD", "shield": "SH", "absorb": "AB"}

const PATCH_RELATIONS := {
	"heavy": {"splitshot": "TRADEOFF: HEAVY + SPLITSHOT BOTH REDUCE FIRE RATE"},
	"splitshot": {"heavy": "TRADEOFF: HEAVY + SPLITSHOT BOTH REDUCE FIRE RATE"},
}

## Optional desktop feedback layers. Neutral patches keep the existing music
## bed unchanged; these groups only describe presentation, never gameplay.
const PATCH_MUSIC_LAYERS := {
	"offensive": ["rapid", "heavy", "core", "ricochet", "pdash", "staticf", "splitshot", "turbo", "chain"],
	"defensive": ["hp", "restore", "shield", "absorb", "vampic", "recycler", "dataleech", "secondwind", "thorns", "scrapdiet"],
}

const PATCH_DEFS := [
	{"id": "rapid", "title": "RAPID LOOPS", "desc": "+18% FIRE RATE", "max": 5, "rare": false, "legend": false},
	{"id": "cell", "title": "OVERCLOCK CELL", "desc": "+2.0s OVERCLOCK DURATION", "max": 3, "rare": false, "legend": false},
	{"id": "magnet", "title": "MAGNET ARRAY", "desc": "+45% MOTE PULL RANGE", "max": 3, "rare": false, "legend": false},
	{"id": "pagecache", "title": "PAGE CACHE", "desc": "BANK 3 SPARE MOTES, AUTO-FLUSH BONUS", "max": 1, "rare": false, "legend": false},
	{"id": "ring0", "title": "RING-0", "desc": "RE-PRESS OVERCLOCK: DOUBLE WINDOW, LONG RECOVERY", "max": 1, "rare": true, "legend": true},
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

func program_defs() -> Dictionary:
	return PROGRAM_DEFS.duplicate(true)

func bestiary_entries() -> Array:
	return BESTIARY_ENTRIES.duplicate(true)

func bestiary_map() -> Dictionary:
	return BESTIARY_MAP.duplicate(true)

func achievement_defs() -> Dictionary:
	return ACHIEVEMENT_DEFS.duplicate(true)

func achievement_hints() -> Dictionary:
	return ACHIEVEMENT_HINTS.duplicate(true)

func patch_defs() -> Array:
	return PATCH_DEFS.duplicate(true)

func patch_codes() -> Dictionary:
	return PATCH_CODES.duplicate(true)

func patch_relations() -> Dictionary:
	return PATCH_RELATIONS.duplicate(true)

func patch_music_layers() -> Dictionary:
	return PATCH_MUSIC_LAYERS.duplicate(true)

func onehp_patch_excluded() -> Array:
	return ONEHP_PATCH_EXCLUDED.duplicate(true)

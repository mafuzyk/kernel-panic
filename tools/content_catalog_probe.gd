extends Node

var _fails := 0

const PROGRAM_IDS := ["kernel", "daemon", "rootlet"]
const BESTIARY_IDS := ["drone", "lancer", "spewer", "splitter", "bulwark", "trojan", "oom", "boss", "root", "segfault", "bluescreen", "pagefault", "recursor", "firewall", "update_loop", "bloatware", "god"]
const PATCH_IDS := ["rapid", "cell", "magnet", "hp", "dash", "frag", "threads", "chain", "light", "mdash", "heavy", "core", "restore", "ricochet", "pdash", "staticf", "vampic", "shield", "absorb", "recycler", "dataleech", "splitshot", "secondwind", "thorns", "turbo", "scrapdiet"]
const ACHIEVEMENT_IDS := ["first_blood", "boss_purge", "chain_max", "terminal_operator", "integrity_restored"]

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
	_check(BestiaryPanel.ENTRIES == entries, "Bestiary compatibility alias matches catalog")
	var entry_copy: Array = catalog.bestiary_entries()
	entry_copy[0]["name"] = "MUTATED"
	_check(str(catalog.bestiary_entries()[0]["name"]) == "DRONE", "bestiary accessor returns a defensive deep copy")

	var patch_defs: Array = catalog.patch_defs()
	var patch_order: Array = []
	for definition in patch_defs:
		patch_order.append(str(definition.get("id", "")))
	_check(patch_order == PATCH_IDS, "patch IDs and order remain stable")
	_check(Game.PATCH_DEFS == patch_defs, "Game patch compatibility alias matches catalog")
	_check(Game.PATCH_CODES == catalog.patch_codes(), "patch codes alias matches catalog")
	_check(Game.PATCH_RELATIONS == catalog.patch_relations(), "patch relations alias matches catalog")
	_check(Game.ONEHP_PATCH_EXCLUDED == catalog.onehp_patch_excluded(), "one-hp exclusions alias matches catalog")

	var achievement_defs: Dictionary = catalog.achievement_defs()
	_check(achievement_defs.keys() == ACHIEVEMENT_IDS, "achievement IDs and order remain stable")
	_check(Game.ACHIEVEMENT_DEFS == achievement_defs, "Game achievement compatibility alias matches catalog")
	_check(catalog.achievement_hints().has("first_blood"), "achievement hints remain catalog content")

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

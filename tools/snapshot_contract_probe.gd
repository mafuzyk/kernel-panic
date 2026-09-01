extends Node

var _fails := 0

func _ready() -> void:
	_persist_runner.call_deferred()

func _persist_runner() -> void:
	var root := get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PROBE_PASS ", message)
	else:
		_fails += 1
		print("PROBE_FAIL ", message)

func _run() -> void:
	var tree := get_tree()
	_watchdog.call_deferred()
	var game: Node = get_node("/root/Game")
	var sfx: Node = get_node("/root/Sfx")
	var menu := tree.current_scene
	if menu == null or menu.name != "Menu":
		tree.change_scene_to_file("res://src/ui/menu.tscn")
		await tree.process_frame
		await tree.process_frame
		menu = tree.current_scene
	_check(menu != null and menu.name == "Menu", "real Menu scene is available")

	var game_before_rng: int = game.rng.state
	var save_before := _save_bytes()
	var nodes_before := tree.get_node_count()
	var game_snapshot: Dictionary = {}
	if game.has_method("run_snapshot"):
		game_snapshot = game.run_snapshot()
	_check(game.has_method("run_snapshot"), "Game exposes run_snapshot")
	_check(_check_contract(game_snapshot, "Game"), "Game snapshot has contract metadata and required fields")
	_check(_check_json_safe(game_snapshot), "Game snapshot is recursively JSON-safe")
	_check(game.rng.state == game_before_rng, "Game snapshot preserves RNG state")
	_check(_save_bytes() == save_before, "Game snapshot preserves save bytes")
	_check(tree.get_node_count() == nodes_before, "Game snapshot does not create nodes")
	_check(_check_deep_copy(game_snapshot), "Game snapshot is isolated from nested mutation")

	game.start_run()
	await tree.process_frame
	await tree.process_frame
	var arena := tree.current_scene
	_check(arena != null and arena.name == "Arena", "real Arena starts through Game.start_run")
	var arena_rng_before: int = game.rng.state
	var arena_save_before := _save_bytes()
	var arena_nodes_before := tree.get_node_count()
	var combat_snapshot: Dictionary = {}
	arena.set("_patch_offers", [{"id": "rapid", "title": "RAPID LOOPS", "desc": "+18% FIRE RATE", "rare": false, "legend": false}])
	if arena != null and arena.has_method("combat_snapshot"):
		combat_snapshot = arena.combat_snapshot()
	_check(arena != null and arena.has_method("combat_snapshot"), "Arena exposes combat_snapshot")
	_check(_check_contract(combat_snapshot, "Arena"), "Arena snapshot has contract metadata and required fields")
	_check(_check_json_safe(combat_snapshot), "Arena snapshot is recursively JSON-safe")
	_check(game.rng.state == arena_rng_before, "Arena snapshot preserves RNG state")
	_check(_save_bytes() == arena_save_before, "Arena snapshot preserves save bytes")
	_check(tree.get_node_count() == arena_nodes_before, "Arena snapshot does not create gameplay nodes")
	_check(_check_deep_copy(combat_snapshot), "Arena snapshot is isolated from nested mutation")
	var patch_offers: Array = combat_snapshot.get("patch_offers", [])
	var patch_offer_valid := patch_offers.size() == 1 and patch_offers[0] is Dictionary and str(patch_offers[0].get("id", "")) == "rapid"
	_check(patch_offer_valid, "Arena snapshot projects live patch offers")
	_check(patch_offer_valid and str(patch_offers[0].get("description", "")) == "+18% FIRE RATE", "Arena snapshot sanitizes patch offer text")

	game.to_menu()
	await tree.process_frame
	await tree.process_frame
	menu = tree.current_scene
	var menu_rng_before: int = game.rng.state
	var menu_save_before := _save_bytes()
	var menu_nodes_before := tree.get_node_count()
	var menu_snapshot: Dictionary = {}
	if menu != null and menu.has_method("menu_snapshot"):
		menu_snapshot = menu.menu_snapshot()
	_check(menu != null and menu.has_method("menu_snapshot"), "Menu exposes menu_snapshot")
	_check(_check_contract(menu_snapshot, "Menu"), "Menu snapshot has contract metadata and required fields")
	_check(_check_json_safe(menu_snapshot), "Menu snapshot is recursively JSON-safe")
	_check(game.rng.state == menu_rng_before, "Menu snapshot preserves RNG state")
	_check(_save_bytes() == menu_save_before, "Menu snapshot preserves save bytes")
	_check(tree.get_node_count() == menu_nodes_before, "Menu snapshot does not create nodes")
	_check(_check_deep_copy(menu_snapshot), "Menu snapshot is isolated from nested mutation")

	var sfx_rng_before: int = game.rng.state
	var sfx_save_before := _save_bytes()
	var sfx_nodes_before := tree.get_node_count()
	var accessibility_snapshot: Dictionary = {}
	if sfx.has_method("accessibility_snapshot"):
		accessibility_snapshot = sfx.accessibility_snapshot()
	_check(sfx.has_method("accessibility_snapshot"), "Sfx exposes accessibility_snapshot")
	_check(_check_contract(accessibility_snapshot, "Sfx"), "Sfx snapshot has contract metadata and required fields")
	_check(_check_json_safe(accessibility_snapshot), "Sfx snapshot is recursively JSON-safe")
	_check(game.rng.state == sfx_rng_before, "Sfx snapshot preserves RNG state")
	_check(_save_bytes() == sfx_save_before, "Sfx snapshot preserves save bytes")
	_check(tree.get_node_count() == sfx_nodes_before, "Sfx snapshot does not create nodes")
	_check(_check_deep_copy(accessibility_snapshot), "Sfx snapshot is isolated from nested mutation")

	_finish()

func _check_contract(snapshot: Dictionary, expected_owner: String) -> bool:
	if snapshot.is_empty():
		return false
	if int(snapshot.get("schema_version", 0)) < 1 or str(snapshot.get("owner", "")) != expected_owner:
		return false
	var required: Array = snapshot.get("required_fields", [])
	var optional: Array = snapshot.get("optional_fields", [])
	if required.is_empty() or not (optional is Array):
		return false
	for field in required:
		if not snapshot.has(str(field)):
			return false
	return true

func _check_json_safe(value) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return true
		TYPE_ARRAY:
			for child in value:
				if not _check_json_safe(child):
					return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				if typeof(key) != TYPE_STRING or not _check_json_safe(value[key]):
					return false
			return true
	return false

func _check_deep_copy(snapshot: Dictionary) -> bool:
	var copy := snapshot.duplicate(true)
	var mutable_key := ""
	for key in copy:
		if copy[key] is Dictionary or copy[key] is Array:
			mutable_key = str(key)
			break
	if mutable_key.is_empty():
		return false
	var original := JSON.stringify(snapshot)
	if copy[mutable_key] is Dictionary:
		copy[mutable_key]["__probe_mutation"] = true
	else:
		copy[mutable_key].append("__probe_mutation")
	return JSON.stringify(snapshot) == original

func _save_bytes() -> PackedByteArray:
	var save_path := str(get_node("/root/Sfx").SAVE_PATH)
	if not FileAccess.file_exists(save_path):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(save_path)

func _watchdog() -> void:
	var timeout_s := 8.0
	if OS.get_environment("KP_A3_FORCE_WATCHDOG") != "":
		timeout_s = 0.0
	await get_tree().create_timer(timeout_s, true, false, true).timeout
	print("PROBE_FAIL watchdog timeout")
	get_tree().quit(2)

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

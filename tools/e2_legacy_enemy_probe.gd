extends Node

const Renderer = preload("res://src/ui/vnext/core/entity_renderer.gd")

class ProbeCanvas extends Node2D:
	var did_draw := false
	var snapshot: Dictionary = {}

	func _draw() -> void:
		Renderer.draw(self, snapshot, Rect2(Vector2(7, 11), Vector2(112, 80)), 1.25)
		did_draw = true

var _fails := 0

const BATCH := [
	{"id": "drone", "script": "res://src/enemies/drone.gd", "name": "DRONE"},
	{"id": "lancer", "script": "res://src/enemies/lancer.gd", "name": "LANCER"},
	{"id": "spewer", "script": "res://src/enemies/spewer.gd", "name": "SPEWER"},
]
const NON_BATCH := ["splitter", "bulwark", "trojan", "oom", "recursor", "firewall", "bloatware", "update_loop", "page", "root", "boss", "segfault", "bluescreen", "pagefault", "god", "kernel", "daemon", "rootlet"]
const GLYPH_LIB_BASELINE_SHA256 := "2846be481b0e43eab9e47708988baa72f75c7d87720d1a95423fa012d1932ce0"

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PROBE_PASS ", message)
	else:
		_fails += 1
		print("PROBE_FAIL ", message)

func _simulation_signature(enemy: Node) -> Dictionary:
	return {
		"position": enemy.position,
		"rotation": enemy.rotation,
		"hp": enemy.get("hp"),
		"max_hp": enemy.get("max_hp"),
		"t": enemy.get("t"),
		"elite": enemy.get("elite"),
		"phase": enemy.get("phase"),
		"aim": enemy.get("_aim"),
		"velocity": enemy.get("_v"),
		"telegraph": enemy.get("_telegraph"),
		"fire_timer": enemy.get("_fire_t"),
	}

func _run() -> void:
	var adapter: Script = load("res://src/ui/vnext/core/entity_presentation_adapter.gd")
	var renderer: Script = load("res://src/ui/vnext/core/entity_renderer.gd")
	var glyphs: Script = load("res://src/ui/glyph_lib.gd")
	_check(adapter != null and renderer != null and glyphs != null, "E2 presentation foundation loads")
	if adapter == null or renderer == null or glyphs == null:
		_finish()
		return

	var enemies: Dictionary = {}
	for spec: Dictionary in BATCH:
		var script: Script = load(str(spec["script"]))
		var enemy: Node = script.new() if script != null else null
		_check(enemy != null, "%s real enemy instance constructs without gameplay run" % spec["name"])
		if enemy == null:
			continue
		enemy.position = Vector2(321, 187)
		enemy.rotation = 0.0
		enemy.hp = 2
		enemy.max_hp = 2
		enemy.t = 1.25
		enemy.elite = false
		enemies[str(spec["id"])] = enemy
		var snapshot: Dictionary = adapter.call("from_enemy", enemy)
		_check(str(snapshot.get("kind", "")) == str(spec["id"]), "%s has stable presentation identity" % spec["name"])
		_check(snapshot.get("facing", Vector2.ZERO) is Vector2, "%s publishes facing" % spec["name"])
		_check(enemy.position == Vector2(321, 187) and enemy.hp == 2 and enemy.max_hp == 2 and enemy.t == 1.25 and not enemy.elite, "%s snapshot preserves gameplay-like fields" % spec["name"])

	var drone = enemies.get("drone")
	if drone != null:
		drone.rotation = PI * 0.5
		var facing_snapshot: Dictionary = adapter.call("from_enemy", drone)
		_check(facing_snapshot.get("facing", Vector2.ZERO).dot(Vector2.DOWN) > 0.99, "DRONE facing maps without changing position or velocity")
		drone.hit_flash = 1.0
		_check(str(adapter.call("from_enemy", drone).get("visual_state", "")) == "hit", "DRONE hit state has semantic channel")
		drone.hit_flash = 0.0
		drone.elite = true
		_check(str(adapter.call("from_enemy", drone).get("visual_state", "")) == "elite", "DRONE elite state has semantic channel")

	var lancer = enemies.get("lancer")
	if lancer != null:
		lancer.phase = lancer.Phase.AIM
		_check(str(adapter.call("from_enemy", lancer).get("visual_state", "")) == "attack", "LANCER aim state has semantic channel")
		lancer.phase = lancer.Phase.LUNGE
		_check(str(adapter.call("from_enemy", lancer).get("visual_state", "")) == "attack", "LANCER lunge state has semantic channel")

	var spewer = enemies.get("spewer")
	if spewer != null:
		spewer._telegraph = 0.2
		_check(str(adapter.call("from_enemy", spewer).get("visual_state", "")) == "attack", "SPEWER wind-up state has semantic channel")

	for spec: Dictionary in BATCH:
		var snapshot := {"kind": spec["id"], "visual_state": "idle", "facing": Vector2.RIGHT}
		for size in [24.0, 48.0, 96.0, 160.0]:
			var target := Rect2(Vector2(7, 11), Vector2(size * 1.4, size))
			var fit: Rect2 = renderer.call("fit_rect", snapshot, target)
			var bounds: Rect2 = renderer.call("draw_bounds", snapshot, target)
			_check(target.encloses(fit) and target.encloses(bounds), "%s silhouette extent fits non-square %dpx slot" % [spec["name"], int(size)])
		for state in ["idle", "attack", "hit", "elite"]:
			snapshot["visual_state"] = state
			_check(renderer.has_method("state_signature") and renderer.call("state_signature", snapshot) != "", "%s %s has non-color semantic signal" % [spec["name"], state])
		var key_a: String = renderer.call("render_key", snapshot, 1.25, {})
		var key_b: String = renderer.call("render_key", snapshot, 1.25, {})
		_check(key_a == key_b, "%s drawing contract is deterministic at fixed cosmetic time" % spec["name"])

	var source_guard := FileAccess.get_file_as_string("res://src/ui/glyph_lib.gd")
	var glyph_hash := HashingContext.new()
	glyph_hash.start(HashingContext.HASH_SHA256)
	glyph_hash.update(source_guard.to_utf8_buffer())
	_check(glyph_hash.finish().hex_encode() == GLYPH_LIB_BASELINE_SHA256, "GlyphLib is byte-identical outside the E2 batch")
	for kind: String in NON_BATCH:
		_check(source_guard.contains('\n\t\t\"%s\":' % kind) or source_guard.contains('\n\t\t\"%s\"' % kind), "non-batch glyph scope retains %s branch" % kind)
	var catalog: Script = load("res://src/data/content_catalog.gd")
	var entries: Array = catalog.get("BESTIARY_ENTRIES") if catalog != null else []
	for id: String in ["drone", "lancer", "spewer"]:
		var entry: Dictionary = entries.filter(func(item: Dictionary) -> bool: return str(item.get("id", "")) == id)[0] if not entries.filter(func(item: Dictionary) -> bool: return str(item.get("id", "")) == id).is_empty() else {}
		_check(str(entry.get("desc", "")).length() >= 20 and str(entry.get("bugs", "")).length() >= 20, "%s catalog entry exposes identity and counterplay copy" % id.to_upper())
		_check(not str(entry.get("desc", "")).contains(".") or not str(entry.get("desc", "")).contains("loc_"), "%s catalog copy is not a localization-looking key" % id.to_upper())

	var canvas := ProbeCanvas.new()
	canvas.snapshot = {"kind": "lancer", "visual_state": "attack", "facing": Vector2.RIGHT, "elite": true}
	var draw_before := canvas.snapshot.duplicate(true)
	add_child(canvas)
	canvas.queue_redraw()
	await get_tree().process_frame
	_check(canvas.did_draw, "focused probe executes the real CanvasItem draw path")
	_check(canvas.snapshot == draw_before, "real draw leaves presentation snapshot unchanged")
	canvas.free()

	var draw_host := Node2D.new()
	add_child(draw_host)
	for spec: Dictionary in BATCH:
		var enemy = enemies.get(str(spec["id"]))
		if enemy == null:
			continue
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		draw_host.add_child(enemy)
		enemy.set_physics_process(false)
		var enemy_draw_before := _simulation_signature(enemy)
		enemy.queue_redraw()
		await get_tree().process_frame
		_check(_simulation_signature(enemy) == enemy_draw_before, "%s actual _draw leaves simulation fields unchanged" % spec["name"])
		enemy.queue_free()
		await get_tree().process_frame
	draw_host.free()

	for enemy in enemies.values():
		if is_instance_valid(enemy):
			enemy.free()
	_finish()

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

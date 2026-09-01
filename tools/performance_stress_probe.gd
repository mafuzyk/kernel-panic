extends Node

## P1 fixed-seed stress gate. It uses real EnemyBase descendants and bullets,
## but does not enter a user run or write a save. Headless numbers measure
## simulation/runtime overhead; Xvfb adds the compatibility renderer path.

const ProfileScript = preload("res://src/gameplay/performance_profile.gd")
const ENEMY_SCRIPTS := [
	"res://src/enemies/drone.gd",
	"res://src/enemies/lancer.gd",
	"res://src/enemies/spewer.gd",
	"res://src/enemies/zombie_process.gd",
]
const ENEMY_COUNT := 48
const BULLET_COUNT := 96
const SAMPLE_FRAMES := 120
const P95_BUDGET_MS := 25.0
const P99_BUDGET_MS := 40.0
const WORST_BUDGET_MS := 100.0

var _fails := 0

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PROBE_PASS ", message)
	else:
		_fails += 1
		print("PROBE_FAIL ", message)

func _memory_mb() -> float:
	return float(Performance.get_monitor(Performance.MEMORY_STATIC)) / (1024.0 * 1024.0)

func _collect(profile: RefCounted, host: Node, frames: int) -> void:
	for _i in frames:
		var started := Time.get_ticks_usec()
		await get_tree().process_frame
		var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
		profile.sample(elapsed_ms, host.get_child_count(), _memory_mb())

func _run() -> void:
	var profile := ProfileScript.new()
	_check(profile != null and profile.has_method("sample") and profile.has_method("snapshot"), "performance profile exposes a reusable measurement contract")
	if profile == null:
		_finish()
		return
	Game.rng.seed = 0x4B504D35
	var host := Node2D.new()
	add_child(host)
	await get_tree().process_frame
	for _i in 30:
		await get_tree().process_frame
	var baseline := ProfileScript.new()
	await _collect(baseline, host, SAMPLE_FRAMES)
	_check(baseline.frame_count() == SAMPLE_FRAMES, "baseline records the requested frame window")

	var actors := 0
	for index in ENEMY_COUNT:
		var enemy_script: Script = load(ENEMY_SCRIPTS[index % ENEMY_SCRIPTS.size()])
		var enemy: EnemyBase = enemy_script.new()
		enemy.position = Vector2(-420.0 + float(index % 12) * 72.0, -260.0 + float(index / 12) * 130.0)
		host.add_child(enemy)
		enemy.configure(1.0, false)
		actors += 1
	for index in BULLET_COUNT:
		var bullet := PlayerBullet.new()
		bullet.setup(Vector2(-220.0 + float(index % 24) * 18.0, -120.0 + float(index / 24) * 60.0), Vector2.RIGHT.rotated(float(index % 9) * 0.04), false)
		host.add_child(bullet)
		bullet.collision_mask = 0
		bullet.life = 10.0
		bullet.vel *= 0.35
		actors += 1
	_check(actors == ENEMY_COUNT + BULLET_COUNT, "stress fixture contains the declared real actor count")
	await get_tree().process_frame
	var stress := ProfileScript.new()
	await _collect(stress, host, SAMPLE_FRAMES)
	var result := stress.snapshot()
	var baseline_result := baseline.snapshot()
	print("PERF_RESULT baseline=%s stress=%s seed=%d actors=%d" % [JSON.stringify(baseline_result), JSON.stringify(result), Game.rng.seed, actors])
	_check(int(result.get("frames", 0)) == SAMPLE_FRAMES, "stress records the requested frame window")
	_check(float(result.get("p95_ms", 999.0)) <= P95_BUDGET_MS, "stress p95 stays below the 1.5-frame responsiveness envelope")
	_check(float(result.get("p99_ms", 999.0)) <= P99_BUDGET_MS, "stress p99 stays below the burst budget")
	_check(float(result.get("worst_ms", 999.0)) <= WORST_BUDGET_MS, "stress worst frame stays below the hitch ceiling")
	_check(int(result.get("peak_entities", 0)) >= actors, "profile reports the peak actor population")
	_check(float(result.get("peak_memory_mb", 0.0)) >= float(baseline_result.get("peak_memory_mb", 0.0)), "profile reports a monotonic memory peak")

	for child in host.get_children():
		child.queue_free()
	host.queue_free()
	await get_tree().process_frame
	_finish()

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

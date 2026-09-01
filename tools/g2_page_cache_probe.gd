extends Node

## G2A focused probe. The probe intentionally names the Page Cache contract
## before production exists so a missing implementation cannot look green.

const PageCache = preload("res://src/gameplay/page_cache.gd")

var _fails := 0
var _player: Player

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PROBE_PASS ", message)
	else:
		_fails += 1
		print("PROBE_FAIL ", message)

func _run() -> void:
	var cache = PageCache.new()
	_check(cache.capacity() == 3, "page cache capacity is exactly three")
	var first: Dictionary = cache.store(1)
	_check(int(first.get("stored", -1)) == 1 and int(first.get("released", -1)) == 0, "first spare mote is stored")
	var second: Dictionary = cache.store(1)
	_check(int(second.get("stored", -1)) == 2 and int(second.get("released", -1)) == 0, "second spare mote is stored")
	var idle_before: Dictionary = cache.snapshot()
	await _ticks(3)
	_check(cache.snapshot() == idle_before, "stored motes do not decay while idle")
	var flush: Dictionary = cache.store(1)
	_check(int(flush.get("stored", -1)) == 0 and int(flush.get("released", -1)) == 3 and bool(flush.get("flushed", false)), "third mote auto-flushes the full cache")
	var repeated: Dictionary = cache.store(3)
	_check(int(repeated.get("released", -1)) == 3 and cache.count() == 0, "a second full batch flushes without manual release")
	var invalid_before: Dictionary = cache.snapshot()
	var invalid: Dictionary = cache.store(0)
	_check(int(invalid.get("accepted", -1)) == 0 and cache.snapshot() == invalid_before, "non-positive store input is a no-op")
	_check(not cache.has_method("release"), "cache exposes no manual release action")

	Game.state = Game.State.PLAYING
	Game.mode = "classic"
	Game.score = 0
	Game.mult = 1
	Game.patch_levels = {"pagecache": 1}
	Game.stats = {"kills": 0, "shots": 0, "hits": 0, "damage": 0, "time": 0.0, "wave": 1, "boss_kills": 0, "heals": {}}
	_player = Player.new()
	_player.position = Vector2(640, 360)
	add_child(_player)
	await _ticks(2)
	_player.meter = Balance.OC_METER_MAX
	_player.oc_ready = true
	_player.overclock_active = false
	var score_before: int = Game.score
	_player.collect_mote()
	_player.collect_mote()
	var cached: Dictionary = _player.page_cache_snapshot()
	_check(Game.score == score_before and int(cached.get("stored", -1)) == 2, "Page Cache banks spare motes before releasing a bonus")
	var presentation: Dictionary = _player.presentation_snapshot()
	var presented_cache: Dictionary = presentation.get("page_cache", {}) if presentation.get("page_cache", {}) is Dictionary else {}
	_check(int(presented_cache.get("capacity", -1)) == 3 and int(presented_cache.get("stored", -1)) == 2, "Page Cache state crosses the read-only player presentation boundary")
	_player.collect_mote()
	_check(Game.score == score_before + 15 and int(_player.page_cache_snapshot().get("stored", -1)) == 0, "Page Cache auto-release preserves the existing three-mote overflow value")
	_check(_player.meter == Balance.OC_METER_MAX and _player.oc_ready, "Page Cache does not mutate the ready overclock meter")
	Game.patch_levels = {}
	var fallback_score: int = Game.score
	_player.collect_mote()
	_check(Game.score == fallback_score + 5, "without Page Cache the existing overflow score remains immediate")
	_player.queue_free()
	cache = null
	_finish()

func _ticks(count: int) -> void:
	for _i in count:
		await get_tree().process_frame

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

class_name Spawner
extends Node

const ZombieProcess = preload("res://src/enemies/zombie_process.gd")

signal wave_started(wave: int, is_boss: bool)
signal wave_cleared(wave: int)
signal boss_spawned(boss: RootBoss)
signal story_cleared(stage_id: String)

var container: Node2D
var wave := 1
var _queue: Array = []
var _spawn_t := 0.0
var _pending := 0
var _intermission := 0.0
var _running := false
var _boss: RootBoss
var _boss_trickle_t := 0.0
var _awaiting_boss := false
var _spawn_generation := 0
var _debug_spawn_index := 0
var wave_event := ""
var arena_ref: Node2D
var story_mode := false
var story_stage: Dictionary = {}
var story_wave_index := -1
var _story_wave_scale := 1.0
var _story_boss_kind := "boss"

func start(arena_node: Node2D, container_node: Node2D, first_wave: int) -> void:
	arena_ref = arena_node
	container = container_node
	_spawn_generation += 1
	_queue.clear()
	_pending = 0
	_intermission = 0.0
	_awaiting_boss = false
	_boss = null
	story_mode = false
	story_stage = {}
	story_wave_index = -1
	_story_boss_kind = "boss"
	wave = first_wave
	_running = true
	_begin_wave()

func start_story(arena_node: Node2D, container_node: Node2D, stage_def: Dictionary) -> bool:
	if stage_def.is_empty() or stage_def.get("waves", []).is_empty():
		return false
	arena_ref = arena_node
	container = container_node
	_spawn_generation += 1
	_queue.clear()
	_pending = 0
	_intermission = 0.0
	_awaiting_boss = false
	_boss = null
	story_mode = true
	story_stage = stage_def.duplicate(true)
	story_wave_index = 0
	_story_boss_kind = str(story_stage.get("boss_kind", "boss"))
	wave = 1
	_running = true
	_begin_story_wave()
	return true

func stop() -> void:
	_running = false

func cancel_boss_phase_spawns() -> void:
	_spawn_generation += 1
	_queue.clear()
	_pending = 0
	_awaiting_boss = false
	_boss = null
	_boss_trickle_t = 0.0

func _begin_wave() -> void:
	if story_mode:
		_begin_story_wave()
		return
	var is_boss := wave % Balance.BOSS_EVERY == 0
	wave_started.emit(wave, is_boss)
	if _next_event_rolled_for != wave:
		_roll_wave_event(is_boss)
	wave_event = _next_event
	_next_event = ""
	if is_boss:
		_queue.clear()
		_awaiting_boss = true
		_spawn_boss()
	else:
		_build_queue()
	_spawn_t = 1.1

func _begin_story_wave() -> void:
	var waves: Array = story_stage.get("waves", [])
	if story_wave_index < 0 or story_wave_index >= waves.size():
		_running = false
		story_cleared.emit(str(story_stage.get("id", "")))
		return
	wave = story_wave_index + 1
	var wave_def: Array = waves[story_wave_index]
	_queue.clear()
	for raw_kind in wave_def:
		_queue.append(str(raw_kind))
	_story_wave_scale = float(story_stage.get("scale", 1.0))
	var boss_kind := ""
	for raw_kind in _queue:
		if str(raw_kind) == "boss" or str(raw_kind) == "god":
			boss_kind = str(raw_kind)
	if not boss_kind.is_empty():
		_story_boss_kind = boss_kind
	wave_started.emit(wave, not boss_kind.is_empty())
	if not boss_kind.is_empty():
		_queue.clear()
		_awaiting_boss = true
		_spawn_story_boss()
	else:
		_spawn_t = 1.1

var _next_event := ""
var _next_event_rolled_for := -1

func preview_next() -> String:
	var next := wave + 1
	if next % Balance.BOSS_EVERY == 0:
		return RootBoss.title_for_index(int(next / float(Balance.BOSS_EVERY))) + " INCOMING"
	if _next_event_rolled_for != next:
		_roll_wave_event(false, next)
	match _next_event:
		"surge":
			return "SURGE INCOMING"
		"rich":
			return "DATA CACHE INCOMING"
		"swarm":
			return "SWARM INCOMING"
	return "DAEMONS INCOMING"

func _roll_wave_event(is_boss: bool, for_wave := -1) -> void:
	wave_event = ""
	var target := wave if for_wave == -1 else for_wave
	_next_event = ""
	_next_event_rolled_for = target
	if is_boss or target < 4:
		return
	var roll := Game.rng.randi() % 4
	match roll:
		1:
			_next_event = "surge"
		2:
			_next_event = "rich"
		3:
			_next_event = "swarm"
	if for_wave == -1 and _next_event != "":
		hud_banner(_next_event.to_upper() + " DETECTED")

func hud_banner(txt: String) -> void:
	if arena_ref != null and is_instance_valid(arena_ref):
		arena_ref.call_deferred("show_event_banner", txt)

func _build_queue() -> void:
	_queue.clear()
	var budget := Balance.difficulty_wave_budget(wave)
	if wave_event == "surge":
		budget = int(budget * 1.3)
	elif wave_event == "rich":
		budget = int(budget * 0.7)
	var pool: Array = [["drone", 1, 5.0]]
	if wave >= 2:
		pool.append(["spewer", 2, 1.5 + wave * 0.12])
	if wave >= 3:
		pool.append(["lancer", 2, 1.2 + wave * 0.12])
	if wave >= 4:
		pool.append(["splitter", 2, 1.0 + wave * 0.1])
	if wave >= 6:
		pool.append(["bulwark", 4, 0.5 + (wave - 5) * 0.1])
	if wave >= 8:
		pool.append(["trojan", 3, 0.7 + (wave - 7) * 0.12])
	if wave >= 9:
		pool.append(["firewall", 4, 0.6 + (wave - 8) * 0.08])
	if wave >= 7:
		pool.append(["recursor", 3, 0.9 + wave * 0.06])
	if wave >= 5:
		pool.append(["oom", 2, 0.4 + (wave - 4) * 0.05])
	var guard := 200
	while budget > 0 and guard > 0:
		guard -= 1
		var affordable: Array = []
		for e in pool:
			if e[1] <= budget:
				affordable.append(e)
		if affordable.is_empty():
			break
		var total := 0.0
		for e in affordable:
			total += e[2]
		var roll := Game.rng.randf() * total
		var picked: Array = affordable[0]
		for e in affordable:
			roll -= e[2]
			if roll <= 0.0:
				picked = e
				break
		_queue.append(picked[0])
		budget -= picked[1]
	for i in range(_queue.size() - 1, 0, -1):
		var j := Game.rng.randi_range(0, i)
		var tmp = _queue[i]
		_queue[i] = _queue[j]
		_queue[j] = tmp

func _spawn_boss() -> void:
	var idx := int(wave / float(Balance.BOSS_EVERY))
	var generation := _spawn_generation
	var t := get_tree().create_timer(1.5)
	t.timeout.connect(func() -> void:
		if generation != _spawn_generation or not _running or not is_instance_valid(container):
			return
		_awaiting_boss = false
		_boss = GodBoss.new() if _story_boss_kind == "god" else RootBoss.new()
		_boss.boss_index = idx
		_boss.threat_wave = wave
		_boss.configure(Balance.wave_scale(wave), false)
		_boss.position = _edge_point(140.0)
		container.add_child(_boss)
		boss_spawned.emit(_boss)
		)

func _spawn_story_boss() -> void:
	var idx := int(story_stage.get("boss_index", 1))
	var generation := _spawn_generation
	var t := get_tree().create_timer(1.5)
	t.timeout.connect(func() -> void:
		if generation != _spawn_generation or not _running or not is_instance_valid(container):
			return
		_awaiting_boss = false
		_boss = GodBoss.new() if _story_boss_kind == "god" else RootBoss.new()
		_boss.boss_index = idx
		_boss.threat_wave = wave
		_boss.configure(float(story_stage.get("boss_scale", _story_wave_scale)), false)
		_boss.position = _edge_point(140.0)
		container.add_child(_boss)
		boss_spawned.emit(_boss)
	)

func _physics_process(delta: float) -> void:
	if not _running:
		return
	if _intermission > 0.0:
		_intermission -= delta
		if _intermission <= 0.0:
			if story_mode:
				story_wave_index += 1
				if story_wave_index >= story_stage.get("waves", []).size():
					_running = false
					story_cleared.emit(str(story_stage.get("id", "")))
				else:
					_begin_story_wave()
			else:
				wave += 1
				_begin_wave()
		return
	var alive := EnemyBase.shared_list.size()
	if _boss != null and is_instance_valid(_boss):
		if story_mode:
			return
		_boss_trickle_t -= delta
		if _boss_trickle_t <= 0.0 and alive < 8:
			_boss_trickle_t = 4.0
			_spawn_group(["drone"])
		if not is_instance_valid(_boss):
			_boss = null
		return
	if _awaiting_boss:
		return
	if _queue.is_empty() and _pending == 0 and alive == 0:
		_intermission = 2.6
		wave_cleared.emit(wave)
		return
	if _queue.is_empty() or _pending > 0:
		return
	_spawn_t -= delta
	if _spawn_t > 0.0 or alive >= Balance.difficulty_max_alive(wave):
		return
	_spawn_t = maxf(Balance.WAVE_SPAWN_MIN, (Balance.WAVE_SPAWN_INTERVAL - wave * 0.05) * (0.6 if wave_event == "surge" else 1.0))
	var group_size := 1 if wave == 1 else 2
	if wave >= 3:
		group_size += (1 if Game.rng.randf() < 0.5 else 0)
	if wave >= 5:
		group_size += (1 if Game.rng.randf() < 0.4 else 0)
	if wave_event == "swarm":
		group_size += 1
	var group: Array = []
	for i in mini(group_size, _queue.size()):
		group.append(_queue.pop_back())
	_spawn_group(group)

func _spawn_group(names: Array) -> void:
	var pos := _edge_point()
	var generation := _spawn_generation
	for n in names:
		_pending += 1
		_telegraph_spawn(pos, n, generation)
		pos = _edge_point()

func _telegraph_spawn(pos: Vector2, kind: String, generation: int) -> void:
	var col := Balance.COL_DANGER
	Fx.ring(pos, col, 30.0, 6.0, 0.55, 2.0, true)
	Fx.sparks(pos, col, 4, 60.0, 0.5, 2.0)
	var t := get_tree().create_timer(0.55)
	t.timeout.connect(func() -> void:
		if generation != _spawn_generation:
			return
		_pending = maxi(_pending - 1, 0)
		if not _running or not is_instance_valid(container):
			return
		var e := _make_enemy(kind)
		if e == null:
			return
		if kind == "oom" and get_tree().get_nodes_in_group("oom").size() >= 2:
			e = DroneEnemy.new()
			kind = "drone"
		if kind == "drone" and wave_event == "swarm":
			e.setup_mini()
		e.position = pos
		if story_mode:
			_configure_story_enemy(e)
		else:
			_configure_enemy(e, Game.rng.randf() < Balance.difficulty_elite_chance(wave))
		container.add_child(e)
	)

func _configure_enemy(e: EnemyBase, is_elite: bool) -> void:
	e.threat_wave = wave
	e.configure(Balance.wave_scale(wave), is_elite)

func _configure_story_enemy(e: EnemyBase) -> void:
	e.threat_wave = wave
	e.configure(_story_wave_scale, false)
	var theme: Dictionary = story_stage.get("theme", {})
	if str(story_stage.get("act", "")) == "templeos":
		e.era_accent = Color.from_hsv(fmod(float(Game.stats.get("time", 0.0)) * 0.08, 1.0), 0.78, 1.0)
	else:
		e.era_accent = theme.get("accent", Balance.COL_PLAYER)

func _make_enemy(kind: String) -> EnemyBase:
	match kind:
		"drone":
			return DroneEnemy.new()
		"spewer":
			return SpewerEnemy.new()
		"lancer":
			return LancerEnemy.new()
		"splitter":
			return SplitterEnemy.new()
		"bulwark":
			return BulwarkEnemy.new()
		"trojan":
			return TrojanEnemy.new()
		"oom":
			return OomKiller.new()
		"recursor":
			return load("res://src/enemies/recursor.gd").new()
		"firewall":
			return load("res://src/enemies/firewall.gd").new()
		"update_loop":
			return load("res://src/enemies/update_loop.gd").new()
		"bloatware":
			return load("res://src/enemies/bloatware.gd").new()
		"zombie_process":
			return ZombieProcess.new()
		"god":
			return load("res://src/enemies/god_boss.gd").new()
	return null

func _edge_point(min_player_dist := 250.0) -> Vector2:
	var r := Balance.arena_rect()
	var inset := 46.0
	var p := Vector2.ZERO
	for attempt in 8:
		var side := Game.rng.randi() % 4
		match side:
			0:
				p = Vector2(Game.rng.randf_range(r.position.x + inset, r.end.x - inset), r.position.y + inset)
			1:
				p = Vector2(Game.rng.randf_range(r.position.x + inset, r.end.x - inset), r.end.y - inset)
			2:
				p = Vector2(r.position.x + inset, Game.rng.randf_range(r.position.y + inset, r.end.y - inset))
			3:
				p = Vector2(r.end.x - inset, Game.rng.randf_range(r.position.y + inset, r.end.y - inset))
		var player := get_tree().get_nodes_in_group("player")
		if player.is_empty() or p.distance_to(player[0].global_position) >= min_player_dist:
			break
	return p

func force_clear() -> void:
	_queue.clear()

func debug_clear_encounter() -> void:
	_spawn_generation += 1
	_queue.clear()
	_pending = 0
	_intermission = 0.0
	_awaiting_boss = false
	_boss = null
	_boss_trickle_t = 0.0
	if container == null or not is_instance_valid(container):
		return
	for child in container.get_children():
		if is_instance_valid(child):
			child.queue_free()

func debug_skip_to_wave(target_wave: int) -> bool:
	if not _running or container == null or not is_instance_valid(container):
		return false
	debug_clear_encounter()
	wave = maxi(target_wave, 1)
	_next_event = ""
	_next_event_rolled_for = -1
	_begin_wave()
	return true

func debug_spawn_enemy(kind: String) -> EnemyBase:
	if not _running or container == null or not is_instance_valid(container):
		return null
	var enemy := _make_enemy(kind)
	if enemy == null:
		return null
	enemy.position = _debug_spawn_point()
	_configure_enemy(enemy, false)
	container.add_child(enemy)
	return enemy

func debug_spawn_boss(index: int) -> RootBoss:
	if not _running or container == null or not is_instance_valid(container):
		return null
	for existing in get_tree().get_nodes_in_group("boss"):
		if is_instance_valid(existing):
			existing.queue_free()
	_boss = null
	var boss := RootBoss.new()
	boss.boss_index = clampi(index, 1, RootBoss.MK_DATA.size() if RootBoss.MK_DATA.size() > 0 else 4)
	boss.threat_wave = wave
	boss.configure(Balance.wave_scale(wave), false)
	boss.position = _debug_spawn_point()
	_boss = boss
	_awaiting_boss = false
	container.add_child(boss)
	boss_spawned.emit(boss)
	return boss

func debug_spawn_root_split() -> bool:
	var boss := debug_spawn_boss(1)
	if boss == null:
		return false
	boss.call_deferred("_split_into_minis")
	return true

func _debug_spawn_point() -> Vector2:
	var angle := float(_debug_spawn_index % 8) * TAU / 8.0 + 0.3
	_debug_spawn_index += 1
	var center := Balance.arena_rect().get_center()
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty() and is_instance_valid(players[0]):
		center = players[0].global_position
	var point := center + Vector2.from_angle(angle) * 290.0
	var safe_rect := Balance.arena_rect().grow(-70.0)
	return Vector2(clampf(point.x, safe_rect.position.x, safe_rect.end.x), clampf(point.y, safe_rect.position.y, safe_rect.end.y))

class_name MoteField
extends Node2D

## All motes in one packed field: zero per-mote nodes, one MultiMesh draw call.
## Flags bits: 1=alive, 2=magnet, 4=stolen, 8=force_collect
const MAX := 128
const F_ALIVE := 1
const F_MAGNET := 2
const F_STOLEN := 4
const F_FORCE := 8

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _life := PackedFloat32Array()
var _flags := PackedInt32Array()
var _seed_t := PackedFloat32Array()
var _count := 0
var _uid := PackedInt64Array()
var _next_uid := 1
var _mmi: MultiMeshInstance2D
var player: Node2D
var _prev_player_pos := Vector2.ZERO
var _has_prev := false

func _ready() -> void:
	add_to_group("mote_field")
	_pos.resize(MAX)
	_vel.resize(MAX)
	_life.resize(MAX)
	_flags.resize(MAX)
	_seed_t.resize(MAX)
	_uid.resize(MAX)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.instance_count = MAX
	mm.mesh = _build_quad_mesh()
	_mmi = MultiMeshInstance2D.new()
	_mmi.multimesh = mm
	add_child(_mmi)
	for i in MAX:
		_hide_instance(i)

func _build_quad_mesh() -> Mesh:
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		# Outer soft halo.
		Vector3(0.0, -11.0, 0.0), Vector3(7.8, 0.0, 0.0),
		Vector3(0.0, 11.0, 0.0), Vector3(-7.8, 0.0, 0.0),
		# Main yellow diamond.
		Vector3(0.0, -6.0, 0.0), Vector3(4.3, 0.0, 0.0),
		Vector3(0.0, 6.0, 0.0), Vector3(-4.3, 0.0, 0.0),
		# White core.
		Vector3(0.0, -2.4, 0.0), Vector3(1.7, 0.0, 0.0),
		Vector3(0.0, 2.4, 0.0), Vector3(-1.7, 0.0, 0.0),
	])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([
		Color(1.0, 0.824, 0.310, 0.14), Color(1.0, 0.824, 0.310, 0.14),
		Color(1.0, 0.824, 0.310, 0.14), Color(1.0, 0.824, 0.310, 0.14),
		Color(1.0, 0.824, 0.310, 0.95), Color(1.0, 0.824, 0.310, 0.95),
		Color(1.0, 0.824, 0.310, 0.95), Color(1.0, 0.824, 0.310, 0.95),
		Color(1.0, 1.0, 1.0, 0.92), Color(1.0, 1.0, 1.0, 0.92),
		Color(1.0, 1.0, 1.0, 0.92), Color(1.0, 1.0, 1.0, 0.92),
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([
		0, 1, 2, 0, 2, 3,
		4, 5, 6, 4, 6, 7,
		8, 9, 10, 8, 10, 11,
	])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func count() -> int:
	return _count

func is_stolen(idx: int) -> bool:
	return idx >= 0 and idx < MAX and (_flags[idx] & F_STOLEN) != 0

func alive_at(idx: int) -> bool:
	return idx >= 0 and idx < MAX and (_flags[idx] & F_ALIVE) != 0

func pos_of(idx: int) -> Vector2:
	return _pos[idx]

func set_slot_position(idx: int, pos: Vector2) -> void:
	if idx >= 0 and idx < MAX and alive_at(idx):
		_pos[idx] = pos
		_vel[idx] = Vector2.ZERO

func spawn(pos: Vector2) -> int:
	if _count >= MAX:
		# Recycle the oldest near-death slot if full; else drop silently.
		for i in _count:
			if _life[i] < 1.0:
				_init_slot(i, pos)
				return i
		return -1
	var idx := _count
	_init_slot(idx, pos)
	_count += 1
	return idx

func spawn_burst(pos: Vector2, n: int) -> void:
	for i in n:
		spawn(pos + Vector2.from_angle(Game.rng.randf() * TAU) * Game.rng.randf_range(4.0, 16.0))

func _init_slot(idx: int, pos: Vector2) -> void:
	_pos[idx] = pos
	# Motes are pickups, not debris: stay put until magnetized/collected.
	_vel[idx] = Vector2.ZERO
	_life[idx] = Balance.MOTE_LIFE
	_flags[idx] = F_ALIVE
	_uid[idx] = _next_uid
	_next_uid += 1
	_seed_t[idx] = Game.rng.randf() * TAU

func kill_slot(idx: int) -> void:
	if idx < 0 or idx >= _count or not alive_at(idx):
		return
	_count -= 1
	var last := _count
	if idx != last:
		_pos[idx] = _pos[last]
		_vel[idx] = _vel[last]
		_life[idx] = _life[last]
		_flags[idx] = _flags[last]
		_seed_t[idx] = _seed_t[last]
		_uid[idx] = _uid[last]
	_hide_instance(last)
	_flags[last] = 0

func _hide_instance(i: int) -> void:
	_mmi.multimesh.set_instance_transform_2d(i, Transform2D(0.0, Vector2(-9999.0, -9999.0)))
	_mmi.multimesh.set_instance_color(i, Color(0, 0, 0, 0))

func force_collect(idx: int) -> void:
	if alive_at(idx):
		_flags[idx] |= F_FORCE | F_MAGNET

func collect_all() -> void:
	for i in _count:
		force_collect(i)

func magnet_all_near(pos: Vector2, radius: float) -> void:
	for i in _count:
		if alive_at(i) and (_flags[i] & F_STOLEN) == 0 and _pos[i].distance_to(pos) < radius:
			_flags[i] |= F_MAGNET

func nearest_free(pos: Vector2) -> int:
	var best := -1
	var bd := 1e18
	for i in _count:
		if not alive_at(i) or (_flags[i] & F_STOLEN) != 0:
			continue
		var d := _pos[i].distance_squared_to(pos)
		if d < bd:
			bd = d
			best = i
	return best

func steal_nearest(pos: Vector2) -> int:
	var idx := nearest_free(pos)
	return steal(idx)

func steal(idx: int) -> int:
	if idx < 0 or idx >= _count or not alive_at(idx) or is_stolen(idx):
		return -1
	_flags[idx] |= F_STOLEN
	_flags[idx] &= ~F_MAGNET
	return idx

func release_all_stolen(ids: Array = []) -> void:
	for i in _count:
		if (_flags[i] & F_STOLEN) != 0 and (ids.is_empty() or _uid[i] in ids):
			_flags[i] &= ~F_STOLEN
			_vel[i] = Vector2.from_angle(Game.rng.randf() * TAU) * 180.0
			_life[i] = maxf(_life[i], 6.0)

func free_all_stolen(ids: Array = []) -> void:
	for i in range(_count - 1, -1, -1):
		if (_flags[i] & F_STOLEN) != 0 and (ids.is_empty() or _uid[i] in ids):
			kill_slot(i)

func stolen_positions_of(ids: Array) -> Array:
	var out: Array = []
	for i in _count:
		if (_flags[i] & F_STOLEN) != 0 and _uid[i] in ids:
			out.append(i)
	return out

func uid_of(idx: int) -> int:
	if idx < 0 or idx >= _count or not alive_at(idx):
		return -1
	return _uid[idx]

func idx_of_uid(uid: int) -> int:
	if uid <= 0:
		return -1
	for i in _count:
		if alive_at(i) and _uid[i] == uid:
			return i
	return -1

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") if get_tree() != null else null
	var mag: float = player.magnet_radius() if player != null and is_instance_valid(player) else 0.0
	var ppos: Vector2 = player.global_position if player != null and is_instance_valid(player) else Vector2.ZERO
	var sweep_from := _prev_player_pos if _has_prev else ppos
	for i in range(_count - 1, -1, -1):
		if not alive_at(i):
			continue
		_life[i] -= delta
		if _life[i] <= 0.0:
			kill_slot(i)
			continue
		var f := _flags[i]
		if (f & F_STOLEN) != 0:
			continue
		if player != null and is_instance_valid(player):
			var d := _pos[i].distance_to(ppos)
			if (f & F_FORCE) != 0 or d < mag:
				f |= F_MAGNET
				_flags[i] = f
			if (f & F_MAGNET) != 0 and d > 1.0:
				var pull := (ppos - _pos[i]).normalized()
				_vel[i] = _vel[i].move_toward(pull * 560.0, 2600.0 * delta)
			var seg := ppos - sweep_from
			var seg_len_sq := seg.length_squared()
			var seg_t := 0.0
			if seg_len_sq > 0.0001:
				seg_t = clampf((_pos[i] - sweep_from).dot(seg) / seg_len_sq, 0.0, 1.0)
			var nearest := sweep_from + seg * seg_t
			if d < 20.0 or _pos[i].distance_to(nearest) < 20.0:
				player.collect_mote()
				Fx.sparks(_pos[i], Balance.COL_MOTE, 4, 120.0, 0.25, 2.0)
				kill_slot(i)
				continue
		else:
			_flags[i] = f
		if (f & F_MAGNET) == 0:
			_vel[i] = _vel[i].move_toward(Vector2.ZERO, 260.0 * delta)
		_pos[i] += _vel[i] * delta
	_prev_player_pos = ppos
	_has_prev = true
	_push_instances()

func stolen_ids() -> Array:
	var out: Array = []
	for i in _count:
		if (_flags[i] & F_STOLEN) != 0 and alive_at(i):
			out.append(_uid[i])
	return out

func _push_instances() -> void:
	var mm := _mmi.multimesh
	var now := Time.get_ticks_msec() / 1000.0
	for i in _count:
		if not alive_at(i):
			continue
		var blink: bool = _life[i] < 2.5 and fmod(_life[i], 0.22) < 0.11
		if blink:
			_hide_instance(i)
			continue
		var pulse := 1.0
		var xform := Transform2D(0.0, _pos[i])
		xform = xform.scaled(Vector2(pulse, pulse))
		mm.set_instance_transform_2d(i, xform)
		mm.set_instance_color(i, Color.WHITE)
	for j in range(_count, MAX):
		_hide_instance(j)

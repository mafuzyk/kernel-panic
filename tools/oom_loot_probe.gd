extends Node

var _fails := 0

func _ready() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	if value:
		print("PROBE_PASS ", message)
	else:
		_fails += 1
		print("PROBE_FAIL ", message)

func _run() -> void:
	var field := MoteField.new()
	add_child(field)
	await get_tree().process_frame
	for i in 4:
		field.spawn(Vector2(220.0 + i * 20.0, 0.0))
	var a := OomKiller.new()
	var b := OomKiller.new()
	add_child(a)
	add_child(b)
	await get_tree().process_frame
	a._steal(0)
	a._steal(1)
	b._steal(2)
	b._steal(3)
	var a_ids := a.carried_ids.duplicate()
	var b_ids := b.carried_ids.duplicate()
	_check(a_ids.size() == 2 and b_ids.size() == 2, "two OOMs hold distinct mote sets")
	a.die()
	await get_tree().process_frame
	_check(b.carried_ids.size() == 2, "surviving OOM keeps its carried IDs")
	_check(field.is_stolen(field.idx_of_uid(int(b_ids[0]))), "surviving OOM keeps its first mote stolen")
	_check(not field.is_stolen(field.idx_of_uid(int(a_ids[0]))), "dead OOM releases its first mote")
	var escape_a := OomKiller.new()
	var escape_b := OomKiller.new()
	add_child(escape_a)
	add_child(escape_b)
	await get_tree().process_frame
	var escape_i0 := field.spawn(Vector2(320.0, 0.0))
	var escape_i1 := field.spawn(Vector2(340.0, 0.0))
	escape_a._steal(escape_i0)
	escape_b._steal(escape_i1)
	var escape_a_id := int(escape_a.carried_ids[0])
	var escape_b_id := int(escape_b.carried_ids[0])
	escape_a._escape()
	await get_tree().process_frame
	_check(field.is_stolen(field.idx_of_uid(escape_b_id)), "surviving OOM keeps its loot when another escapes")
	_check(field.idx_of_uid(escape_a_id) < 0, "escaping OOM frees its own loot")
	_finish()

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

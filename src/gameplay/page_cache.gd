class_name PageCache
extends RefCounted

## A finite buffer for spare overclock motes. It has no process loop: stored
## motes neither decay nor consume simulation time. The owner decides what a
## released batch means; Player maps it to the existing overflow unit.

const CAPACITY := 3

var _stored := 0
var _flushes := 0

func capacity() -> int:
	return CAPACITY

func count() -> int:
	return _stored

func store(amount: int = 1) -> Dictionary:
	if amount <= 0:
		return _result(0, 0, 0)
	var accepted := 0
	var released := 0
	var remaining := amount
	while remaining > 0:
		var room := CAPACITY - _stored
		var chunk := mini(room, remaining)
		_stored += chunk
		accepted += chunk
		remaining -= chunk
		if _stored == CAPACITY:
			released += _stored
			_stored = 0
			_flushes += 1
	return _result(accepted, _stored, released)

func snapshot() -> Dictionary:
	return {
		"capacity": CAPACITY,
		"stored": _stored,
		"flushes": _flushes,
	}

func _result(accepted: int, stored: int, released: int) -> Dictionary:
	return {
		"accepted": accepted,
		"stored": stored,
		"released": released,
		"flushed": released > 0,
	}

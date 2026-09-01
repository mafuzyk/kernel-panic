class_name VNextUIFocusModel
extends RefCounted

var focus_order: Array[String] = []
var focus_id := ""
var dispatching := false

func set_focus_order(ids: Array) -> bool:
	focus_order.clear()
	for item in ids:
		var id := str(item)
		if not id.is_empty() and id not in focus_order:
			focus_order.append(id)
	if focus_id not in focus_order:
		focus_id = focus_order[0] if not focus_order.is_empty() else ""
	return true

func set_focus(id: String) -> bool:
	if id not in focus_order:
		return false
	focus_id = id
	return true

func move_focus(delta: int) -> String:
	if focus_order.is_empty():
		return ""
	var index := focus_order.find(focus_id)
	index = wrapi(index + delta, 0, focus_order.size())
	focus_id = focus_order[index]
	return focus_id

func snapshot() -> Dictionary:
	return {"focus_id": focus_id, "focus_order": focus_order.duplicate(), "dispatching": dispatching}

func begin_dispatch(action_id: String) -> bool:
	if dispatching or action_id.is_empty() or action_id not in focus_order:
		return false
	dispatching = true
	return true

func end_dispatch() -> void:
	dispatching = false

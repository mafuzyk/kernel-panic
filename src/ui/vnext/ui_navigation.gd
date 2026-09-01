class_name VNextUINavigation
extends RefCounted

var stack: Array[String] = []
var focus_id := "boot"
var focus_order: Array[String] = []
var dispatching := false

func push(route: String) -> void:
	stack.append(route)

func pop() -> String:
	return stack.pop_back() if not stack.is_empty() else ""

func set_focus_order(ids: Array[String]) -> void:
	focus_order = ids.duplicate()
	if focus_id not in focus_order and not focus_order.is_empty():
		focus_id = focus_order[0]

func set_focus(id: String) -> bool:
	if id not in focus_order:
		return false
	focus_id = id
	return true

func move_focus(delta: int) -> String:
	if focus_order.is_empty():
		return focus_id
	var index := focus_order.find(focus_id)
	index = wrapi(index + delta, 0, focus_order.size())
	focus_id = focus_order[index]
	return focus_id

func snapshot() -> Dictionary:
	return {"stack": stack.duplicate(), "focus_id": focus_id, "focus_order": focus_order.duplicate(), "dispatching": dispatching}

func dispatch(action: String, callback: Callable) -> bool:
	if dispatching or action.is_empty() or not callback.is_valid():
		return false
	dispatching = true
	call_deferred("_clear_dispatching")
	callback.call(action)
	dispatching = false
	return true

func _clear_dispatching() -> void:
	dispatching = false

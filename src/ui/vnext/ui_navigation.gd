class_name VNextUINavigation
extends RefCounted

var stack: Array[String] = []
var focus_id := "boot"
var dispatching := false

func push(route: String) -> void:
	stack.append(route)

func pop() -> String:
	return stack.pop_back() if not stack.is_empty() else ""

func dispatch(action: String, callback: Callable) -> bool:
	if dispatching:
		return false
	dispatching = true
	callback.call(action)
	dispatching = false
	return true

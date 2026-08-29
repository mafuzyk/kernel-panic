extends Node

var arena: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if arena == null or not is_instance_valid(arena):
		return
	if arena.has_method("handle_pause_input") and arena.handle_pause_input(event):
		get_viewport().set_input_as_handled()

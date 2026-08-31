extends Node

## Routes input to the Arena while the tree is paused: the Arena inherits the
## pause, so only this ALWAYS node receives _unhandled_input. ESC/pause goes
## through handle_pause_input; Q/R and the patch digits go through
## handle_paused_gameplay_input. Gameplay stays frozen: no simulation node
## is resumed. Events are never processed twice — when the tree is unpaused
## the Arena handles input directly and this router steps aside.

var arena: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if arena == null or not is_instance_valid(arena):
		return
	if not arena.get_tree().paused:
		return
	if arena.has_method("handle_pause_input") and arena.handle_pause_input(event):
		get_viewport().set_input_as_handled()
		return
	if arena.has_method("handle_paused_gameplay_input") and arena.handle_paused_gameplay_input(event):
		get_viewport().set_input_as_handled()

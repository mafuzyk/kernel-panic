extends Node

## Boot scene for the B5 terminal history/autocomplete probe. The runner stays
## under the tree root while the real Arena scene is loaded.

func _ready() -> void:
	var runner := Node.new()
	runner.name = "TerminalHistoryProbeRunner"
	runner.set_script(load("res://tools/terminal_history_probe.gd"))
	runner.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(runner)

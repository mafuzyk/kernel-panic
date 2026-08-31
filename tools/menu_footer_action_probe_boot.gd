extends Node

## Boot scene for the B2 probe. The runner persists while Menu and Arena swap.

func _ready() -> void:
	var runner := Node.new()
	runner.name = "MenuFooterActionProbeRunner"
	runner.set_script(load("res://tools/menu_footer_action_probe.gd"))
	runner.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(runner)

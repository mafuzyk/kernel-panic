extends Node

## Boot scene for the menu overlay probe. Keep the runner under the tree root
## so menu -> arena transitions do not free the probe itself.

func _ready() -> void:
	var runner := Node.new()
	runner.name = "MenuOverlayInputProbeRunner"
	runner.set_script(load("res://tools/menu_overlay_input_probe.gd"))
	runner.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(runner)

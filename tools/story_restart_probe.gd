extends Node

func _ready() -> void:
	var runner := Node.new()
	runner.set_script(load("res://tools/story_restart_probe_runner.gd"))
	runner.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(runner)

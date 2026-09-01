extends Node

func _ready() -> void:
	var runner := Node.new()
	runner.name = "E4ZombieProcessProbeRunner"
	runner.set_script(load("res://tools/e4_zombie_process_probe.gd"))
	runner.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(runner)

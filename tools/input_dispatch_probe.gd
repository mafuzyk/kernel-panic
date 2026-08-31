extends Node

## Boot scene for the input-dispatch regression probe (lote 1: R01-R03/T01).
## Spawns a persistent runner directly under the tree root so scene changes
## (menu -> arena -> menu) never free the probe mid-run. Run with:
##   godot --headless --path . res://tools/input_dispatch_probe.tscn
## Exit code is non-zero when any PROBE_FAIL line is emitted.

func _ready() -> void:
	var runner := Node.new()
	runner.name = "InputDispatchProbeRunner"
	runner.set_script(load("res://tools/input_dispatch_probe_runner.gd"))
	runner.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(runner)

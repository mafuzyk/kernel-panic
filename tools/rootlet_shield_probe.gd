extends Node

## Boot scene for the rootlet shield regression probe (lote R05).
## Spawns a persistent runner directly under the tree root so scene changes
## (menu -> arena -> arena restart) never free the probe mid-run. Run with:
##   godot --headless --path . res://tools/rootlet_shield_probe.tscn
## Exit code is non-zero when any PROBE_FAIL line is emitted.

func _ready() -> void:
	var runner := Node.new()
	runner.name = "RootletShieldProbeRunner"
	runner.set_script(load("res://tools/rootlet_shield_probe_runner.gd"))
	runner.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(runner)

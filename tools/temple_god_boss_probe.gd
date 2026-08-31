extends Node

## Boot scene for the temple_god boss regression probe (lote R06).
## Spawns a persistent runner directly under the tree root so scene changes
## (menu -> arena -> menu) never free the probe mid-run. Run with:
##   godot --headless --path . res://tools/temple_god_boss_probe.tscn
## Exit code is non-zero when any PROBE_FAIL line is emitted.

func _ready() -> void:
	var runner := Node.new()
	runner.name = "TempleGodBossProbeRunner"
	runner.set_script(load("res://tools/temple_god_boss_probe_runner.gd"))
	runner.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(runner)

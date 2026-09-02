extends Node

## P4 red/green probe: split boss presentation must describe live fragments
## only, and the fork title must inherit the actual boss variant.

var _fails := 0
var _finished := false

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PROBE_PASS ", message)
	else:
		_fails += 1
		print("PROBE_FAIL ", message)

func _ticks(count: int) -> void:
	for _i in count:
		await get_tree().process_frame

func _make_mini(slot: int, hp_value: int, title: String) -> RootBoss:
	var mini := RootBoss.new()
	mini.mini = true
	mini.set_meta("mini_slot", slot)
	mini.boss_title = "MINI-" + title
	mini.hp = hp_value
	mini.max_hp = hp_value
	return mini

func _run() -> void:
	var hud_script: Script = load("res://src/ui/hud.gd")
	var boss_script: Script = load("res://src/enemies/root_boss.gd")
	_check(hud_script != null, "HUD script loads for split boss bar audit")
	_check(boss_script != null, "RootBoss script loads for split boss bar audit")
	if hud_script == null or boss_script == null:
		_finish()
		return

	var hud: Control = hud_script.new()
	add_child(hud)
	await _ticks(2)
	var boss := RootBoss.new()
	boss.boss_title = "SEGFAULT"
	hud.set("boss", boss)
	var mini_a := _make_mini(0, 9, "SEGFAULT")
	var mini_b := _make_mini(1, 6, "SEGFAULT")
	hud.call("set_boss_fragments", [mini_a, mini_b])
	_check(hud.has_method("boss_split_rows_snapshot"), "HUD exposes live split-row presentation data")
	_check(str(hud.get("_boss_name")) == "SEGFAULT // FORKED", "split title inherits the active boss variant")
	if hud.has_method("boss_split_rows_snapshot"):
		var both_rows: Array = hud.call("boss_split_rows_snapshot")
		_check(both_rows.size() == 2, "two live fragments produce two split rows")
		if both_rows.size() == 2:
			_check(int(both_rows[0].get("slot", -1)) == 0 and int(both_rows[1].get("slot", -1)) == 1, "split rows retain fragment slot identity")
			_check(str(both_rows[0].get("label", "")) == "MINI-A" and str(both_rows[1].get("label", "")) == "MINI-B", "split rows use stable fragment labels")

		mini_a.free()
		await _ticks(1)
		var one_row: Array = hud.call("boss_split_rows_snapshot")
		_check(one_row.size() == 1, "one live fragment produces one split row")
		_check(one_row.size() == 1 and float(one_row[0].get("fraction", -1.0)) > 0.0, "single split row has live health instead of a zero ghost")

		var mini_b_only := _make_mini(1, 3, "SEGFAULT")
		hud.call("set_boss_fragments", [mini_b_only])
		var b_row: Array = hud.call("boss_split_rows_snapshot")
		_check(b_row.size() == 1 and int(b_row[0].get("slot", -1)) == 1 and str(b_row[0].get("label", "")) == "MINI-B", "remaining B fragment keeps identity without drawing a ghost row")
		mini_b_only.free()

	mini_b.free()
	boss.free()
	hud.queue_free()
	await _ticks(1)
	_finish()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().paused = false
	get_tree().quit(1 if _fails > 0 else 0)

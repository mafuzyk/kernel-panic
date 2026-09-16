extends RefCounted

## Sonda de determinismo.
##
## Premissa do leaderboard verificado: `(seed + comandos) -> mesmo resultado`.
## Se ela não valer, o servidor não consegue reconferir uma run.
##
## O motorista vive DENTRO da árvore e roda no `_physics_process`. A primeira
## versão dirigia de fora, num laço `await get_tree().physics_frame`, e isso
## media a coisa errada: o laço externo pegava a arena em quadros de física
## globais diferentes em cada máquina (medido: 32 contra 37), então os comandos
## entravam em momentos diferentes da simulação e a run divergia por culpa da
## SONDA. Um gravador de verdade tem o mesmo requisito — ele conta os quadros da
## própria arena — então a sonda agora é um protótipo dele.

var h: Node

const FRAMES := 5400
const SAMPLE_EVERY := 300


func _init(harness: Node) -> void:
	h = harness


## Motorista determinístico: um quadro de física, um comando, sem relógio de
## parede em lugar nenhum.
class ScriptedDriver extends Node:
	var arena: Node
	var frame := 0
	var digest: Array = []
	var limit := 0
	var sample_every := 300
	var finished := false

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_PAUSABLE

	func _physics_process(_delta: float) -> void:
		if finished or arena == null or not is_instance_valid(arena):
			return
		var player = arena.get("player")
		if player == null or not is_instance_valid(player) or player.dead:
			_finish(player)
			return
		# A oferta de patch congela a árvore; com `PROCESS_MODE_PAUSABLE` este nó
		# para junto, então a escolha sai daqui mesmo, antes de qualquer passo.
		if bool(arena.get("_patch_open")):
			arena.call("_pick_patch", 0)
			return
		frame += 1
		apply_input(player, frame)
		if frame % sample_every == 0:
			digest.append(snapshot(player))
		if frame >= limit:
			_finish(player)

	func _finish(player) -> void:
		if finished:
			return
		finished = true
		digest.append(snapshot(player))
		print("DET_FRAMES ", frame)
		print("DET_DIGEST ", JSON.stringify(digest))
		get_tree().quit(0)

	## Comando como FUNÇÃO PURA do quadro da arena.
	func apply_input(player, f: int) -> void:
		var t := float(f) / 60.0
		player.touch_move = Vector2(sin(t * 1.7), cos(t * 2.3)).limit_length(1.0)
		player.touch_aim = Vector2(cos(t * 0.9), sin(t * 1.1)) * 100.0
		player.touch_fire = fmod(t, 0.8) < 0.5
		if f % 137 == 0 and player.dash_cd <= 0.0:
			player.request_dash(Vector2.from_angle(t * 2.1))
		if f % 421 == 0 and player.oc_ready:
			player.try_overclock()

	func snapshot(player) -> Dictionary:
		var alive := player != null and is_instance_valid(player)
		return {
			"f": frame,
			"score": Game.score,
			"wave": Game.wave,
			"hp": player.hp if alive else -1,
			"px": snappedf(player.global_position.x, 0.001) if alive else 0.0,
			"py": snappedf(player.global_position.y, 0.001) if alive else 0.0,
			"alive": EnemyBase.shared_list.size(),
			"kills": int(Game.stats.get("kills", 0)),
			"shots": int(Game.stats.get("shots", 0)),
			"rng": str(Game.rng.state),
		}


func probe() -> void:
	h._watchdog(300.0)
	await h._ticks(15)
	Game.mode = "weekly"
	Game.difficulty = "normal"
	Game.program = "kernel"
	Game.start_run()
	var entered: bool = await h._until(func() -> bool:
		var scene := h.get_tree().current_scene
		return scene != null and scene.name == "Arena" and scene.get("player") != null, 10.0, "determinism arena")
	if not entered:
		print("DET_FAIL could not enter the arena")
		h.get_tree().quit(1)
		return
	var arena: Node = h.get_tree().current_scene
	print("DET_SEED ", Game.run_seed, " week ", Game.week_id())
	var driver := ScriptedDriver.new()
	driver.arena = arena
	driver.limit = FRAMES
	driver.sample_every = SAMPLE_EVERY
	arena.add_child(driver)

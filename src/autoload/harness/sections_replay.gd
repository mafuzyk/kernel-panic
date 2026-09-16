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
	## Em reprodução o motorista não dirige: o comando vem do buffer, e mexer em
	## `touch_move` aqui seria escrever por cima do que se quer conferir.
	var drive_input := true
	## Silencioso quando a passada é uma de duas e o resultado é lido por quem
	## chamou, não pela saída.
	var silent := false
	var frame := 0
	var digest: Array = []
	var limit := 0
	var sample_every := 300
	var finished := false

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_PAUSABLE

	## Âncora no TEMPO SIMULADO, não no relógio de parede nem na hora em que
	## este nó entrou na árvore.
	##
	## O motorista é adicionado de dentro de uma corrotina, e isso cai num ponto
	## imprevisível do quadro: em algumas execuções ele pegava o primeiro passo
	## de física junto com a arena, em outras só o sétimo. Um comando entrando um
	## passo adiantado muda a run inteira.
	##
	## Esperar o relógio DA RUN chegar a um valor fixo resolve: ele avança
	## exatamente um passo de física por vez, então `>= ANCHOR_TIME` é sempre o
	## mesmo passo em qualquer máquina. Um gravador de verdade não precisa disto
	## — ele nasce com a arena — mas a sonda precisa.
	const ANCHOR_TIME := 0.5

	func _physics_process(_delta: float) -> void:
		if finished or arena == null or not is_instance_valid(arena):
			return
		if float(Game.stats.get("time", 0.0)) < ANCHOR_TIME:
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
		if drive_input:
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
		if silent:
			return
		print("DET_FRAMES ", frame)
		# Fora do digest de propósito: o quadro global em que a arena entrou na
		# árvore varia com o carregamento da cena e não é simulação. Dentro do
		# digest ele fazia duas runs idênticas parecerem diferentes.
		print("DET_START_FRAME ", Engine.get_physics_frames() - frame)
		print("DET_DIGEST ", JSON.stringify(digest))
		get_tree().quit(0)

	## Comando como FUNÇÃO PURA do quadro da arena.
	func apply_input(player, f: int) -> void:
		var t := float(f) / 60.0
		player.touch_move = Vector2(sin(t * 1.7), cos(t * 2.3)).limit_length(1.0)
		player.touch_aim = Vector2(cos(t * 0.9), sin(t * 1.1)) * 100.0
		player.touch_fire = fmod(t, 0.8) < 0.5
		# Intenção, igual ao toque: chamar `request_dash()` direto furaria o
		# gravador e a sonda mediria a si mesma.
		if f % 137 == 0 and player.dash_cd <= 0.0:
			player.touch_dash = true
		if f % 421 == 0 and player.oc_ready:
			player.touch_overclock = true

	func snapshot(player) -> Dictionary:
		var alive := player != null and is_instance_valid(player)
		return {
			"f": frame,
			"score": Game.score,
			"wave": Game.wave,
			"hp": player.hp if alive else -1,
			"px": ("%.9f" % player.global_position.x) if alive else "",
			"py": ("%.9f" % player.global_position.y) if alive else "",
			"alive": EnemyBase.shared_list.size(),
			"kills": int(Game.stats.get("kills", 0)),
			"shots": int(Game.stats.get("shots", 0)),
			"rng": str(Game.rng.state),
			"tm": "%.9f" % float(Game.stats.get("time", 0.0)),
			"vx": ("%.9f" % player.vel.x) if alive else "",
			"vy": ("%.9f" % player.vel.y) if alive else "",
		}


## Ida e volta do gravador: grava uma run dirigida, reproduz o gravado e
## compara. É o que prova que `(seed + comandos)` basta — sem isso o servidor
## não tem como reconferir pontuação nenhuma.
func roundtrip() -> void:
	h._watchdog(400.0)
	await h._ticks(15)
	Game.mode = "weekly"
	Game.difficulty = "normal"
	Game.program = "kernel"

	var recorded := await _drive_once(true, PackedByteArray(), [])
	if recorded.is_empty():
		print("REPLAY_FAIL recording pass did not run")
		h.get_tree().quit(1)
		return
	print("REPLAY_RECORDED frames=%d bytes=%d picks=%d" % [
		int(recorded["frames"]), int(recorded["bytes"].size()), int(recorded["picks"].size())])

	var replayed := await _drive_once(false, recorded["bytes"], recorded["picks"])
	if replayed.is_empty():
		print("REPLAY_FAIL replay pass did not run")
		h.get_tree().quit(1)
		return
	print("REPLAY_FRAMES record=%d replay=%d" % [int(recorded["frames"]), int(replayed["frames"])])
	var same: bool = str(recorded["digest"]) == str(replayed["digest"])
	print("REPLAY_MATCH ", "yes" if same else "no")
	if not same:
		var a: Array = JSON.parse_string(str(recorded["digest"]))
		var b: Array = JSON.parse_string(str(replayed["digest"]))
		for i in mini(a.size(), b.size()):
			if a[i] != b[i]:
				print("REPLAY_DIVERGE f=", a[i]["f"])
				for k in a[i]:
					if a[i][k] != b[i].get(k):
						print("   ", k, " record=", a[i][k], " replay=", b[i].get(k))
				break
	h.get_tree().quit(0 if same else 1)

## Uma passada: `record` grava enquanto o motorista dirige; caso contrário
## reproduz o buffer e o motorista fica calado.
func _drive_once(record: bool, data: PackedByteArray, picks: Array) -> Dictionary:
	if record:
		Replay.begin_record()
	else:
		Replay.begin_replay(data, picks)
	# A arena ANTERIOR ainda é a cena corrente quando `start_run()` retorna, e ela
	# também se chama "Arena" e também tem um jogador. Esperar só pelo nome
	# devolvia a arena velha, e o motorista ia parar numa árvore prestes a ser
	# liberada. A identidade é o que distingue as duas.
	var previous_id := h.get_tree().current_scene.get_instance_id() if h.get_tree().current_scene != null else 0
	Game.start_run()
	var entered: bool = await h._until(func() -> bool:
		var scene := h.get_tree().current_scene
		return scene != null and scene.name == "Arena" and scene.get("player") != null \
			and scene.get_instance_id() != previous_id, 10.0, "replay arena")
	if not entered:
		Replay.stop()
		return {}
	var arena: Node = h.get_tree().current_scene
	var driver := ScriptedDriver.new()
	driver.arena = arena
	driver.limit = FRAMES
	driver.sample_every = SAMPLE_EVERY
	driver.silent = true
	driver.drive_input = record
	arena.add_child(driver)
	var done: bool = await h._until(func() -> bool: return driver.finished, 200.0, "replay pass")
	var result := {
		"frames": driver.frame,
		"digest": JSON.stringify(driver.digest),
		"bytes": Replay.buffer(),
		"picks": Replay.patch_picks(),
	}
	Replay.stop()
	if not done:
		return {}
	return result

## Grava uma run e escreve o pacote em disco. É a metade "jogadora" do fluxo do
## servidor: o cliente joga e envia isto.
func record_to_file() -> void:
	h._watchdog(400.0)
	await h._ticks(15)
	Game.mode = "weekly"
	Game.difficulty = "normal"
	Game.program = "kernel"
	var pass_result := await _drive_once(true, PackedByteArray(), [])
	if pass_result.is_empty():
		print("REPLAY_FAIL recording pass did not run")
		h.get_tree().quit(1)
		return
	var packet := {
		"week": Game.week_number(),
		"seed": Game.run_seed,
		"frames": int(pass_result["frames"]),
		"score": Game.score,
		"input": Marshalls.raw_to_base64(pass_result["bytes"]),
		"picks": pass_result["picks"],
		"digest": str(pass_result["digest"]),
	}
	var path := OS.get_environment("KP_RECORD_OUT")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("REPLAY_FAIL cannot write ", path)
		h.get_tree().quit(1)
		return
	file.store_string(JSON.stringify(packet))
	file.close()
	print("REPLAY_WROTE %s frames=%d score=%d bytes=%d" % [path, int(packet["frames"]), int(packet["score"]), pass_result["bytes"].size()])
	h.get_tree().quit(0)

## Relê o pacote, re-simula e confere. É a metade "servidor": nenhuma entrada
## vem de teclado, mouse ou tela — só do arquivo.
func verify_from_file() -> void:
	h._watchdog(400.0)
	await h._ticks(15)
	var path := OS.get_environment("KP_VERIFY_IN")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("REPLAY_FAIL cannot read ", path)
		h.get_tree().quit(1)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		print("REPLAY_FAIL packet is not a dictionary")
		h.get_tree().quit(1)
		return
	var packet: Dictionary = parsed
	Game.mode = "weekly"
	Game.difficulty = "normal"
	Game.program = "kernel"
	var replayed := await _drive_once(false, Marshalls.base64_to_raw(str(packet["input"])), packet.get("picks", []))
	if replayed.is_empty():
		print("REPLAY_FAIL verification pass did not run")
		h.get_tree().quit(1)
		return
	var same_digest: bool = str(packet["digest"]) == str(replayed["digest"])
	var same_frames: bool = int(packet["frames"]) == int(replayed["frames"])
	var same_score: bool = int(packet["score"]) == Game.score
	print("REPLAY_VERIFY frames %d/%d score %d/%d digest %s" % [
		int(replayed["frames"]), int(packet["frames"]), Game.score, int(packet["score"]),
		"match" if same_digest else "differ"])
	if not same_digest:
		var a = JSON.parse_string(str(packet["digest"]))
		var b = JSON.parse_string(str(replayed["digest"]))
		if a is Array and b is Array:
			for i in mini(a.size(), b.size()):
				if a[i] != b[i]:
					print("REPLAY_DIVERGE f=", a[i]["f"])
					for k in a[i]:
						if a[i][k] != b[i].get(k):
							print("   ", k, " recorded=", a[i][k], " verified=", b[i].get(k))
					break
	print("REPLAY_MATCH ", "yes" if (same_digest and same_frames and same_score) else "no")
	h.get_tree().quit(0 if (same_digest and same_frames and same_score) else 1)

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

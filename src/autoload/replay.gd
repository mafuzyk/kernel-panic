extends Node

## Gravação e reprodução dos COMANDOS de uma run.
##
## Premissa do leaderboard verificado: `(seed + comandos) -> mesmo resultado`.
## O servidor reconfere uma pontuação re-simulando a run, então ele precisa dos
## comandos exatos que a jogadora deu — não do que o teclado dela mandou.
##
## Por que o comando e não o input cru: o mesmo teclado produz coisas diferentes
## em máquinas diferentes. A mira, por exemplo, nasce do mouse em desktop, do
## toque no celular e do alvo travado no lock-on — três caminhos que dependem de
## resolução, de driver e do estado da cena. Gravar o RESULTADO dos três (uma
## direção) faz a reprodução ignorar por onde ele veio.
##
## Quantização na ORIGEM. O valor gravado é o mesmo que alimenta a simulação ao
## vivo, nunca uma aproximação do que ela usou. Sem isso a run gravada e a run
## jogada divergiriam desde o primeiro passo, e a culpa seria do gravador.

enum Mode { OFF, RECORD, REPLAY }

## Cinco bytes por quadro de física: dois para o vetor de movimento, dois para o
## ângulo de mira, um para as teclas. Uma run de cinco minutos dá ~90 KB.
const BYTES_PER_FRAME := 5
const MOVE_SCALE := 127.0
const ANGLE_STEPS := 65536.0

## Movimento parado, codificado. `0` não é neutro: decodifica para -1.008.
const NEUTRAL_MOVE_BYTE := 128

const FLAG_FIRE := 1
const FLAG_DASH := 2
const FLAG_OVERCLOCK := 4
const FLAG_AIM := 8

var mode: int = Mode.OFF
var frame := 0
var _buffer := PackedByteArray()
## `[quadro, índice]` de cada patch escolhido. Fora do fluxo por quadro porque
## a escolha acontece com a árvore congelada, fora do passo de física.
var _patch_picks: Array = []
var _patch_cursor := 0

## ── prova da run ──────────────────────────────────────────────────────
##
## O servidor confere uma pontuação comparando a PROVA: um resumo do estado da
## simulação tirado a cada N passos de física. Ela é produzida aqui, pelo jogo,
## nos dois sentidos — gravando e reproduzindo — porque uma prova que só o
## harness sabe montar não serviria para uma run de verdade, que não tem
## motorista nenhum dirigindo.
const SAMPLE_EVERY := 300

var digest: Array = []

func digest_json() -> String:
	return JSON.stringify(digest)

## Chamada pela arena a cada passo, depois de `advance()`.
func sample(arena: Node) -> void:
	if mode == Mode.OFF or frame % SAMPLE_EVERY != 0:
		return
	var player: Node = arena.get("player")
	var alive := player != null and is_instance_valid(player) and not bool(player.get("dead"))
	digest.append({
		"f": frame,
		"score": Game.score,
		"wave": Game.wave,
		"hp": int(player.get("hp")) if alive else -1,
		"px": ("%.9f" % float(player.get("global_position").x)) if alive else "",
		"py": ("%.9f" % float(player.get("global_position").y)) if alive else "",
		"alive": EnemyBase.shared_list.size(),
		"kills": int(Game.stats.get("kills", 0)),
		"shots": int(Game.stats.get("shots", 0)),
		"rng": str(Game.rng.state),
	})

func is_recording() -> bool:
	return mode == Mode.RECORD

func is_replaying() -> bool:
	return mode == Mode.REPLAY

func stop() -> void:
	mode = Mode.OFF

func begin_record() -> void:
	mode = Mode.RECORD
	frame = 0
	_buffer = PackedByteArray()
	_patch_picks.clear()
	_patch_cursor = 0
	digest.clear()

func begin_replay(data: PackedByteArray, picks: Array = []) -> void:
	mode = Mode.REPLAY
	frame = 0
	_buffer = data.duplicate()
	_patch_picks = picks.duplicate(true)
	_patch_cursor = 0
	digest.clear()

func recorded_frames() -> int:
	return int(_buffer.size() / BYTES_PER_FRAME)

func buffer() -> PackedByteArray:
	return _buffer.duplicate()

func patch_picks() -> Array:
	return _patch_picks.duplicate(true)

## A arena avança o quadro no `_physics_process`, antes do jogador ler. Dois nós
## lendo o mesmo número no mesmo passo é o que mantém gravação e reprodução
## alinhadas sem cada um contar por si.
func advance() -> void:
	if mode != Mode.OFF:
		frame += 1

## ── quantização ───────────────────────────────────────────────────────

## Quantização IDEMPOTENTE: quantizar duas vezes tem de dar o mesmo resultado.
##
## A primeira versão aplicava `limit_length` DEPOIS de arredondar, então o valor
## devolvido não era múltiplo exato de 1/127 — e codificar esse valor de novo, na
## hora de gravar, caía noutro byte. A run gravada e a reproduzida separavam por
## 1e-5 no décimo quadro e por centenas de quadros no fim.
##
## Agora o valor é, por definição, o que os bytes decodificam. O corte de
## comprimento acontece ANTES, então a diagonal pode passar de 1.0 em no máximo
## 0.22% — e passa igual nos dois lados, que é o que importa.
static func quantize_move(v: Vector2) -> Vector2:
	var clamped := v.limit_length(1.0)
	return Vector2(_from_byte(_to_byte(clamped.x)), _from_byte(_to_byte(clamped.y)))

## Mesma regra do movimento: o ângulo devolvido é exatamente o que o passo
## inteiro decodifica, para gravar duas vezes não deslocar nada.
static func quantize_angle(radians: float) -> float:
	return float(angle_step(radians)) / ANGLE_STEPS * TAU

static func angle_step(radians: float) -> int:
	return wrapped_step(roundi(fposmod(radians, TAU) / TAU * ANGLE_STEPS))

static func wrapped_step(step: int) -> int:
	return posmod(step, int(ANGLE_STEPS))

## ── gravação ──────────────────────────────────────────────────────────

func push(move: Vector2, aim_angle: float, has_aim: bool, fire: bool, dash: bool, overclock: bool) -> void:
	if mode != Mode.RECORD:
		return
	# O buffer é endereçado pelo NÚMERO do quadro, não pela ordem de chegada:
	# um quadro sem jogador vivo simplesmente não escreve, e a reprodução
	# continua encontrando cada comando no lugar certo.
	var slot := frame * BYTES_PER_FRAME
	# Preenchido com o byte NEUTRO, não com zero. `_from_byte(0)` é -1.008: um
	# quadro pulado — a arena avança e o `_physics_process` do jogador sai cedo —
	# reproduziria como diagonal a toda velocidade em vez de parado.
	while _buffer.size() < slot + BYTES_PER_FRAME:
		var offset := _buffer.size() % BYTES_PER_FRAME
		_buffer.append(NEUTRAL_MOVE_BYTE if offset < 2 else 0)
	# `move` já vem quantizado de `_resolve_move`; codificar de novo devolve os
	# mesmos bytes porque a quantização é idempotente.
	_buffer[slot] = _to_byte(move.x)
	_buffer[slot + 1] = _to_byte(move.y)
	var step := angle_step(aim_angle)
	_buffer[slot + 2] = step & 0xFF
	_buffer[slot + 3] = (step >> 8) & 0xFF
	var flags := 0
	if fire:
		flags |= FLAG_FIRE
	if dash:
		flags |= FLAG_DASH
	if overclock:
		flags |= FLAG_OVERCLOCK
	if has_aim:
		flags |= FLAG_AIM
	_buffer[slot + 4] = flags

func record_patch_pick(index: int) -> void:
	if mode == Mode.RECORD:
		_patch_picks.append([frame, index])

## ── reprodução ────────────────────────────────────────────────────────

## Comando do quadro corrente. Fora do gravado devolve parado — uma run que
## acabou não continua se mexendo sozinha.
func command() -> Dictionary:
	var slot := frame * BYTES_PER_FRAME
	if mode != Mode.REPLAY or slot + BYTES_PER_FRAME > _buffer.size():
		return {"move": Vector2.ZERO, "angle": 0.0, "has_aim": false, "fire": false, "dash": false, "overclock": false}
	var flags := int(_buffer[slot + 4])
	var step := int(_buffer[slot + 2]) | (int(_buffer[slot + 3]) << 8)
	return {
		"move": Vector2(_from_byte(_buffer[slot]), _from_byte(_buffer[slot + 1])),
		"angle": float(step) / ANGLE_STEPS * TAU,
		"has_aim": (flags & FLAG_AIM) != 0,
		"fire": (flags & FLAG_FIRE) != 0,
		"dash": (flags & FLAG_DASH) != 0,
		"overclock": (flags & FLAG_OVERCLOCK) != 0,
	}

## Índice do patch a escolher neste quadro, ou -1.
func next_patch_pick() -> int:
	if mode != Mode.REPLAY or _patch_cursor >= _patch_picks.size():
		return -1
	var entry: Array = _patch_picks[_patch_cursor]
	_patch_cursor += 1
	return int(entry[1])

## ── transporte ────────────────────────────────────────────────────────

func to_base64() -> String:
	return Marshalls.raw_to_base64(_buffer)

static func from_base64(text: String) -> PackedByteArray:
	return Marshalls.base64_to_raw(text)

static func _to_byte(value: float) -> int:
	return clampi(roundi(value * MOVE_SCALE), -127, 127) + 128

static func _from_byte(raw: int) -> float:
	return float(int(raw) - 128) / MOVE_SCALE

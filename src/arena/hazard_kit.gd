extends RefCounted

## Regra da fase do Story.
##
## O Story de 3.1 era a mesma arena do endless com outra lista de ondas: o que
## mudava era QUEM aparecia, nunca COMO o campo se comporta. Uma fase agora
## declara um `hazard` e o campo obedece — é isso que separa um set-piece de uma
## planilha de spawns.
##
## Cinco regras, reaproveitadas entre as fases em vez de quinze implementações
## sob medida. Cada uma é ligada por dados no `STAGES`, e o autotest afirma o
## efeito, não a animação.
##
## Tudo aqui anda no `_physics_process` da arena. Um perigo agendado no laço de
## render mediria tempo diferente em cada taxa de quadros — foi exatamente esse
## o defeito encontrado nos cronômetros de spawn.

const SPILL_INTERVAL := 4.5
const SURGE_INTERVAL := 7.0
const SURGE_ORBS := 9
const SURGE_SPEED := 150.0
const SHRINK_PER_WAVE := 0.045
const SHRINK_FLOOR := 0.70
const HASTE_PER_WAVE := 0.05
const HASTE_CAP := 1.35

var a
var kind := "none"
var _base_arena := Vector2.ZERO
var _timer := 0.0
var _wave := 1


func _init(arena) -> void:
	a = arena

func configure(stage: Dictionary) -> void:
	kind = str(stage.get("hazard", "none"))
	_wave = 1
	_timer = _interval()
	_base_arena = Balance.arena_rect().size
	_apply_arena_size()

func active() -> bool:
	return kind != "none" and kind != ""

func _interval() -> float:
	match kind:
		"spill":
			return SPILL_INTERVAL
		"surge":
			return SURGE_INTERVAL
	return 0.0

## `no_heal`: a fase não devolve integridade entre ondas. É a regra que
## transforma uma fase longa numa fase de recurso.
func blocks_heal() -> bool:
	return kind == "no_heal"

## `shrink`: o campo encolhe a cada onda, com piso. Sem piso a arena fecharia
## em cima da jogadora e a fase viraria impossível em vez de apertada.
func arena_scale() -> float:
	if kind != "shrink":
		return 1.0
	return maxf(1.0 - float(maxi(_wave - 1, 0)) * SHRINK_PER_WAVE, SHRINK_FLOOR)

## `haste`: o elenco acelera conforme a fase avança, com teto.
func haste_factor() -> float:
	if kind != "haste":
		return 1.0
	return minf(1.0 + float(maxi(_wave - 1, 0)) * HASTE_PER_WAVE, HASTE_CAP)

func on_wave_started(wave: int) -> void:
	_wave = maxi(wave, 1)
	_apply_arena_size()

func _apply_arena_size() -> void:
	if kind != "shrink" or _base_arena.x <= 0.0:
		return
	Balance.set_arena_size_override(_base_arena * arena_scale())

func tick(delta: float) -> void:
	if not active() or _interval() <= 0.0:
		return
	if a == null or not is_instance_valid(a) or a.player == null or not is_instance_valid(a.player):
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = _interval()
	match kind:
		"spill":
			_spill()
		"surge":
			_surge()

## Poças que brotam sozinhas, longe da jogadora: a fase suja o campo mesmo sem
## um TROJAN vivo para sujá-lo.
func _spill() -> void:
	if a.get_tree().get_nodes_in_group("corruption").size() >= 8:
		return
	var bounds := Balance.arena_rect().grow(-60.0)
	var spot := Vector2(
		Game.rng.randf_range(bounds.position.x, bounds.end.x),
		Game.rng.randf_range(bounds.position.y, bounds.end.y))
	# Nunca em cima de quem está jogando: um perigo que nasce sob os pés não é
	# um perigo, é um pedágio.
	if spot.distance_to(a.player.global_position) < 140.0:
		spot += (spot - a.player.global_position).normalized() * 160.0
	var zone := CorruptionZone.new()
	zone.position = spot
	a.enemy_container.call_deferred("add_child", zone)
	Fx.ring(spot, Balance.COL_DANGER, 10.0, 46.0, 0.45, 2.0, true)

## Um anel de orbes fechando a partir da borda. Tem furo de propósito: a
## resposta é reposicionar, não adivinhar.
func _surge() -> void:
	if not EnemyOrb.can_spawn(a):
		return
	var center := Balance.arena_rect().get_center()
	var radius := Balance.arena_rect().size.length() * 0.5
	var gap := Game.rng.randi_range(0, SURGE_ORBS - 1)
	for index in SURGE_ORBS:
		if index == gap:
			continue
		var angle := TAU * float(index) / float(SURGE_ORBS)
		var from := center + Vector2.from_angle(angle) * radius
		var orb := EnemyOrb.new()
		orb.setup(from, (center - from).normalized(), SURGE_SPEED, Balance.COL_SPEWER)
		a.enemy_container.call_deferred("add_child", orb)
	Fx.ring(center, Balance.COL_SPEWER, radius, radius * 0.9, 0.5, 2.0)

func label() -> String:
	return "" if not active() else tr_hazard(kind)

static func tr_hazard(hazard_kind: String) -> String:
	return TranslationServer.translate("STORY_HAZARD_%s" % hazard_kind.to_upper())

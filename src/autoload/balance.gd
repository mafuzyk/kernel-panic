class_name Balance

const ARENA_W := 1208.0
const ARENA_H := 648.0
static var _arena_size_override := Vector2.ZERO

const PLAYER_MAX_HP := 4
const PLAYER_SPEED := 340.0
const PLAYER_ACCEL := 2800.0
const PLAYER_FRICTION := 2400.0
const PLAYER_RADIUS := 12.0
const FIRE_RATE := 8.0
const FIRE_RATE_OC := 14.0
const BULLET_SPEED := 950.0
const BULLET_LIFE := 1.05
const BULLET_SPREAD := 0.045
const DASH_SPEED := 1150.0
const DASH_TIME := 0.16
const DASH_CD := 0.85
const DASH_IFRAMES := 0.24
const HURT_IFRAMES := 0.95
const OC_DURATION := 6.0
const OC_METER_MAX := 100.0
const MOTE_VALUE := 6.0
const MOTE_KILL_VALUE := 2.0
const MOTE_MAGNET := 115.0
const MOTE_MAGNET_OC := 185.0
const MOTE_LIFE := 12.0
## Teto de motes simultâneos na tela. O MoteField reserva 128 slots, mas o
## teto de projeto é este — ver docs/superpowers/reports/2026-09-11-auditoria-desktop.md (B9).
const MOTE_CAP := 90

const COMBO_WINDOW := 3.0
const COMBO_MAX := 8

## Curva de dificuldade. Estas constantes existiam mas NINGUÉM as lia: as
## funções abaixo traziam os números no corpo, e diferentes dos declarados.
## Decisão da autora (2026-09-11): vale o que roda — é o que shipou no v2.5.0,
## foi jogado, e é a base sobre a qual DIFF_*_MULT foi calibrado. Os valores
## foram corrigidos para a realidade e as funções agora os leem de fato.
## Trocar qualquer um destes AGORA muda o balanceamento de verdade.
const WAVE_BUDGET_BASE := 8
const WAVE_BUDGET_GROWTH := 5
## Termo extra por onda, a partir de WAVE_BUDGET_RAMP_AFTER.
const WAVE_BUDGET_RAMP := 2
const WAVE_BUDGET_RAMP_AFTER := 4
const WAVE_SPAWN_INTERVAL := 1.7
const WAVE_SPAWN_MIN := 0.6
## Incremento de escala por onda.
const WAVE_SCALE_STEP := 0.03
const WAVE_SCALE_CAP := 1.7
const BOSS_EVERY := 5
const HEAL_EVERY := 3

const DIFFICULTY_ORDER := ["easy", "normal", "hard"]
const DIFF_ALIVE_MULT := {"easy": 0.7, "normal": 1.0, "hard": 1.3}
const DIFF_BUDGET_MULT := {"easy": 0.8, "normal": 1.0, "hard": 1.2}
const DIFF_ELITE_MULT := {"easy": 0.6, "normal": 1.0, "hard": 1.4}
const DIFF_CADENCE_SCALE := {"easy": 1.0, "normal": 1.0, "hard": 0.897}
const DIFF_CADENCE_FLOOR := {"easy": 0.90, "normal": 0.78, "hard": 0.70}

const LAYER_PLAYER := 2
const LAYER_ENEMY := 4
const LAYER_PBULLET := 8
const LAYER_EORB := 16
const LAYER_MOTE := 32

const COL_BG := Color("05060e")
const COL_GRID := Color("16233f")
const COL_PLAYER := Color("4ff2ff")
const COL_PLAYER_HOT := Color("d8ffff")
const COL_BULLET := Color("aefaff")
const COL_DRONE := Color("ff3d81")
const COL_LANCER := Color("ff9a3d")
const COL_SPEWER := Color("b46bff")
const COL_SPLITTER := Color("ff5c5c")
const COL_BULWARK := Color("58b8ff")
const COL_SPLITTER_ASSIST := Color("ffb000")
const COL_BULWARK_ASSIST := Color("7b61ff")
const COL_MOTE := Color("ffd24f")
const COL_TEXT := Color("cfe9ff")
const COL_DANGER := Color("ff2a4d")

## ── legibilidade do campo da arena ────────────────────────────────────
##
## Regra: o fundo nunca fica mais claro que a entidade mais escura. O jogador
## lê FORMAS em movimento sobre o campo; quando o campo acende na mesma faixa
## de matiz dos inimigos, as duas leituras competem.
##
## A corrupção era vermelho aceso (0.85, 0.08, 0.28) misturado a 32% sobre 24%
## da tela. Virou escurecimento: um setor corrompido é grade DANIFICADA — luz
## que falta, não luz somada. O matiz vermelho sobrevive na borda do setor, que
## é onde ele informa sem ofuscar.
const BG_CORRUPTION_COL := Color(0.075, 0.012, 0.030)
## Quanto o setor corrompido puxa o campo para a cor acima.
const BG_CORRUPTION_MIX := 0.72
## Fração das células do fundo que podem corromper.
const BG_CORRUPTION_COVERAGE := 0.14
## Peso da grade secundária. Era 0.22 e, correndo em direção oposta à primária,
## produzia moiré — duas réguas em vez de uma régua e uma textura.
const BG_SUBGRID_WEIGHT := 0.10


static func background_corruption_color() -> Color:
	return BG_CORRUPTION_COL

## Escala do inimigo por onda. O teto só passa a valer da onda 24 em diante.
static func wave_scale(wave: int) -> float:
	return minf(1.0 + float(wave - 1) * WAVE_SCALE_STEP, WAVE_SCALE_CAP)

const ERA_TINTS := [
	Color("4ff2ff"),
	Color("ff9a3d"),
	Color("4f8cff"),
	Color("b46bff"),
	Color("ff2a4d"),
]

## Quanto o acento de era tinge a grade do campo.
##
## Era 0.75 no endless. Três das cinco cores de era SÃO cores de inimigo —
## `ff9a3d` é o LANCER, `b46bff` é o SPEWER, `ff2a4d` é o DANGER — então a
## 0.75 o campo inteiro passava cinco ondas com a cor de uma ameaça, e a mesma
## regra que tirou o brilho dos setores corrompidos estava sendo violada pela
## grade. A identidade de era sobrevive; ela só para de gritar.
## A era muda a COR da grade, não a luz dela. Baixar só a mistura apagaria a
## identidade de era junto com o brilho; rebaixar o ganho do acento mantém o
## deslocamento de matiz (ciano → laranja → azul → roxo → vermelho) e tira a
## luminância que competia com as entidades.
const ERA_MIX_ENDLESS := 0.45
const ERA_MIX_STORY := 0.28
const ERA_TINT_GAIN_GRID := 0.45
const ERA_TINT_GAIN_GLOW := 0.32

## Defaults do `bg_grid.gdshader` no modo endless. Existem como constantes para
## o modelo de pico abaixo medir o MESMO campo que o shader desenha.
const FIELD_BASE_DEFAULT := Color(0.012, 0.014, 0.033)
const FIELD_GRID_DEFAULT := Color(0.075, 0.13, 0.24)
const FIELD_GLOW_DEFAULT := Color(0.05, 0.13, 0.2)
## Defaults de `intro_kit._apply_story_theme` quando a fase omite a chave.
const STORY_BASE_DEFAULT := Color("080b18")
const STORY_GLOW_DEFAULT := Color("0d4160")

## Pico de cor do campo: o que o shader produz no centro, onde a grade cheia e
## o brilho central somam. É sobre isto que a asserção de legibilidade mede.
##
## O resultado NÃO é saturado de propósito: um canal acima de 1.0 é exatamente
## a informação que interessa para detectar estouro.
static func field_peak_color(era_tint: Color, era_mix: float,
		base_col: Color = FIELD_BASE_DEFAULT,
		grid_col: Color = FIELD_GRID_DEFAULT,
		glow_col: Color = FIELD_GLOW_DEFAULT) -> Color:
	var grid_ink := grid_col.lerp(shade(era_tint, ERA_TINT_GAIN_GRID), era_mix * 0.7)
	var glow_ink := glow_col.lerp(shade(era_tint, ERA_TINT_GAIN_GLOW), era_mix * 0.9)
	# grade primária (0.55) + secundária, e o brilho central a 0.9.
	var g: float = 0.55 + BG_SUBGRID_WEIGHT
	return Color(
		base_col.r + grid_ink.r * g + glow_ink.r * 0.9,
		base_col.g + grid_ink.g * g + glow_ink.g * 0.9,
		base_col.b + grid_ink.b * g + glow_ink.b * 0.9)

## O mesmo pico para um tema de fase do Story, lido como `_apply_story_theme` lê.
##
## Sem isto nenhum tema de fase era medido: o modelo antigo tinha base, grade e
## brilho FIXOS do endless, então o `Win11` podia nascer com `base_col #dfe9f2`
## — quase branco — e o centro da arena estourava sem nenhum teste reclamar.
static func story_field_peak_color(theme: Dictionary) -> Color:
	return field_peak_color(
		theme.get("accent", COL_PLAYER),
		ERA_MIX_STORY,
		theme.get("base_col", STORY_BASE_DEFAULT),
		theme.get("grid_col", COL_GRID),
		theme.get("glow_col", STORY_GLOW_DEFAULT))

## Tema de fase com o MATIZ invertido e a luz preservada.
##
## É o ataque do KERNEL_TASK: a tela de pânico troca as cores do campo no meio
## de uma esquiva. Girar o matiz meia volta muda a luminância junto (azul e
## amarelo têm o mesmo V e brilhos muito diferentes), então cada cor é
## reescalada de volta para a própria luminância original. Sem isso a inversão
## seria um clarão — exatamente o erro que o `Win11` já cometeu uma vez.
const FIELD_INVERT_KEYS := ["base_col", "grid_col", "glow_col", "accent"]

static func invert_field_theme(theme: Dictionary) -> Dictionary:
	var inverted := theme.duplicate(true)
	for key in FIELD_INVERT_KEYS:
		if not theme.has(key):
			continue
		inverted[key] = invert_hue_keeping_light(theme[key])
	# Preservar a luminância COR A COR não basta: o campo satura no framebuffer,
	# e girar o matiz troca QUAL canal satura. Um tema que estourava no vermelho
	# (peso 0.21) e passava raspando podia, invertido, estourar no verde (peso
	# 0.72) e ficar visivelmente mais claro. A garantia que interessa é sobre o
	# campo montado, então ela é medida no campo montado e corrigida ali.
	var reference := field_display_color(story_field_peak_color(theme)).get_luminance()
	for _pass_index in 4:
		var current := field_display_color(story_field_peak_color(inverted)).get_luminance()
		if current <= reference + 0.001:
			break
		var k := reference / maxf(current, 0.0001)
		for key in FIELD_INVERT_KEYS:
			if not inverted.has(key):
				continue
			var ink: Color = inverted[key]
			inverted[key] = Color(ink.r * k, ink.g * k, ink.b * k, ink.a)
	return inverted

## Gira o matiz meia volta e devolve a cor à MESMA luminância.
##
## Luminância é linear em RGB, então preservá-la cor a cor preserva a do campo
## inteiro — é isso que faz o campo invertido passar pela mesma varredura do
## campo normal, sem uma segunda calibração.
##
## Dois caminhos, porque um matiz não alcança qualquer luminância: escurecer é
## só multiplicar, mas CLAREAR saturado bate no teto do canal (azul puro não
## passa de 0.07 por mais que se multiplique). Quando falta luz, a cor é
## misturada com branco, que a empurra para a luminância certa desbotando em vez
## de estourar — e um pânico desbotado é exatamente a leitura que se quer.
static func invert_hue_keeping_light(source: Color) -> Color:
	var rotated := Color.from_hsv(fmod(source.h + 0.5, 1.0), source.s, source.v, source.a)
	var before := source.get_luminance()
	var after := rotated.get_luminance()
	if after <= 0.0001 or before <= 0.0001:
		return rotated
	if after >= before:
		var k := before / after
		return Color(rotated.r * k, rotated.g * k, rotated.b * k, source.a)
	var t := clampf((before - after) / maxf(1.0 - after, 0.0001), 0.0, 1.0)
	var lifted := rotated.lerp(Color(1.0, 1.0, 1.0, rotated.a), t)
	lifted.a = source.a
	return lifted

## Um campo ESTOURA quando os três canais saturam juntos: aí ele perde o matiz e
## vira tela branca. Um canal sozinho acima de 1.0 é cor forte — a saturação
## vermelha do TempleOS e o azul do XP são escolhas de ato. Três canais é luz, e
## luz branca no fundo é o que machuca o olho.
static func field_whites_out(peak: Color) -> bool:
	return peak.r >= 1.0 and peak.g >= 1.0 and peak.b >= 1.0

## O que a tela realmente mostra: o framebuffer satura em 1.0. O pico cru serve
## para detectar estouro; a luminância percebida mede sobre o valor saturado.
static func field_display_color(peak: Color) -> Color:
	return Color(minf(peak.r, 1.0), minf(peak.g, 1.0), minf(peak.b, 1.0))

static func brightest_entity_luminance() -> float:
	var brightest := 0.0
	for entity in [COL_DRONE, COL_LANCER, COL_SPEWER, COL_SPLITTER, COL_BULWARK,
		COL_MOTE, COL_PLAYER, COL_DANGER]:
		var entity_color: Color = entity
		brightest = maxf(brightest, entity_color.get_luminance())
	return brightest


static func shade(base: Color, mult: float) -> Color:
	return Color(base.r * mult, base.g * mult, base.b * mult, base.a)


static func dimmest_entity_luminance() -> float:
	var dimmest := 1.0
	for entity in [COL_DRONE, COL_LANCER, COL_SPEWER, COL_SPLITTER, COL_BULWARK,
		COL_MOTE, COL_PLAYER, COL_DANGER]:
		var entity_color: Color = entity
		dimmest = minf(dimmest, entity_color.get_luminance())
	return dimmest


static func era_color(wave: int) -> Color:
	return ERA_TINTS[clampi((wave - 1) / 5, 0, ERA_TINTS.size() - 1)]

static func threat_palette(color_assist: bool = false) -> Dictionary:
	if color_assist:
		return {
			"splitter": COL_SPLITTER_ASSIST,
			"bulwark": COL_BULWARK_ASSIST,
		}
	return {
		"splitter": COL_SPLITTER,
		"bulwark": COL_BULWARK,
	}

static func threat_color(id: String, color_assist: bool = false) -> Color:
	return threat_palette(color_assist).get(id, COL_TEXT)

static func wave_budget(wave: int) -> int:
	return WAVE_BUDGET_BASE + (wave - 1) * WAVE_BUDGET_GROWTH \
		+ maxi(0, wave - WAVE_BUDGET_RAMP_AFTER) * WAVE_BUDGET_RAMP

static func max_alive(wave: int) -> int:
	return mini(6 + wave * 2, 10)

static func attack_cadence_factor(wave: int) -> float:
	if wave <= 5:
		return 1.0
	return maxf(0.78, 1.0 - float(wave - 5) * 0.015)

static func elite_chance(wave: int) -> float:
	return clampf(float(wave - 7) * 0.045, 0.0, 0.4)

static func difficulty_applies() -> bool:
	return Game.mode != "story"

static func difficulty_max_alive(wave: int) -> int:
	if not difficulty_applies():
		return max_alive(wave)
	var mult: float = DIFF_ALIVE_MULT.get(Game.difficulty, 1.0)
	return maxi(1, int(ceil(float(max_alive(wave)) * mult)))

static func difficulty_wave_budget(wave: int) -> int:
	if not difficulty_applies():
		return wave_budget(wave)
	var mult: float = DIFF_BUDGET_MULT.get(Game.difficulty, 1.0)
	# Os traits da semana entram DEPOIS da dificuldade: o Weekly roda sempre em
	# NORMAL, então na prática eles são o único multiplicador ali.
	return maxi(1, int(floor(float(wave_budget(wave)) * mult * Weekly.factor("budget"))))

static func difficulty_elite_chance(wave: int) -> float:
	if not difficulty_applies():
		return elite_chance(wave)
	var mult: float = DIFF_ELITE_MULT.get(Game.difficulty, 1.0)
	return clampf(elite_chance(wave) * mult * Weekly.factor("elite_chance"), 0.0, 1.0)

static func difficulty_cadence(wave: int) -> float:
	if not difficulty_applies():
		return attack_cadence_factor(wave)
	var base := attack_cadence_factor(wave)
	if base >= 1.0:
		return 1.0
	var scale: float = DIFF_CADENCE_SCALE.get(Game.difficulty, 1.0)
	var floor_v: float = DIFF_CADENCE_FLOOR.get(Game.difficulty, 0.78)
	return clampf(base * scale, floor_v, 1.0)

## ── tintas de campo ──────────────────────────────────────────────────
##
## Recompensa por limpar um ATO: uma tinta que a jogadora liga no endless. A do
## TempleOS já existia como `temple_rainbow_unlocked` e continua sendo a mesma
## coisa — só que agora tem irmãs, e todas passam pelo mesmo lugar.
##
## `""` é o estado normal, em que a era da onda manda na cor.
const FIELD_TINTS := {
	"unix": Color("4ff2ff"),
	"crt": Color("79d6ce"),
	"aqua": Color("5ac8fa"),
}

## Cor da tinta num instante. O rainbow é o único que depende do tempo.
static func field_tint_color(tint: String, seconds: float) -> Color:
	if tint == "rainbow":
		return Color.from_hsv(fmod(seconds * 0.08, 1.0), 0.78, 1.0)
	return FIELD_TINTS.get(tint, COL_PLAYER)

static func field_tint_names() -> Array:
	var names: Array = ["rainbow"]
	for key in FIELD_TINTS.keys():
		names.append(str(key))
	return names

## ── nota da fase do Story ─────────────────────────────────────────────
##
## O Story não tinha nada a perseguir dentro de uma fase: limpar era limpar. A
## nota mede as duas coisas que a fase já produzia sem usar — integridade
## perdida e tempo — e as transforma num alvo visível.
##
## `S` é o contrato explícito, anunciado na carta de intro: sem dano E dentro do
## tempo. `A` é metade disso. `B` é ter limpado, que continua sendo suficiente
## para destravar a fase seguinte — a nota é um alvo, nunca um portão.
const STORY_RANKS := ["S", "A", "B"]

static func story_rank(damage_taken: int, seconds: float, par_seconds: float) -> String:
	var in_time := par_seconds <= 0.0 or seconds <= par_seconds
	var untouched := damage_taken <= 0
	if untouched and in_time:
		return "S"
	if untouched or in_time:
		return "A"
	return "B"

## Qual das duas notas é a melhor. Existe para o save nunca REBAIXAR um S.
static func better_story_rank(first: String, second: String) -> String:
	var a := STORY_RANKS.find(first)
	var b := STORY_RANKS.find(second)
	if a < 0:
		return second
	if b < 0:
		return first
	return first if a <= b else second

## ── coordenação de ataque ─────────────────────────────────────────────
##
## Antes disto todo inimigo decidia atacar sozinho, olhando só para o próprio
## relógio. Com cinco lancers em campo os cinco carregavam ao mesmo tempo e o
## jogador não tinha o que ler: ou dava sorte no dash, ou tomava. A pressão
## vinha do NÚMERO, não da leitura.
##
## Agora existe um teto de quantos podem estar COMPROMETIDOS com um ataque no
## mesmo instante. Quem não pega vaga continua se reposicionando — a onda
## inteira não para, ela se organiza. O teto cresce com a onda e com a
## dificuldade, que é onde a pressão deve crescer.
const ATTACK_SLOTS_BASE := 2
const ATTACK_SLOTS_CAP := 5
const DIFF_ATTACK_SLOTS := {"easy": -1, "normal": 0, "hard": 1}

static func attack_slot_limit(wave: int) -> int:
	var slots := ATTACK_SLOTS_BASE + int(floor(float(maxi(wave, 1) - 1) / 6.0))
	if difficulty_applies():
		slots += int(DIFF_ATTACK_SLOTS.get(Game.difficulty, 0))
	return clampi(slots, 1, ATTACK_SLOTS_CAP)

## Quanto o inimigo mira ADIANTE do jogador, como fração da velocidade dele.
##
## Mirar onde o jogador está é mirar onde ele não vai estar: um lancer telegrafa
## 0.6s e o jogador percorre mais de 200px nesse tempo, então o lunge sempre
## passava atrás. A antecipação começa em zero — nas primeiras ondas o jogo
## ainda está ensinando o tell — e sobe até um teto que deixa o desvio possível.
const AIM_LEAD_CAP := 0.72
const DIFF_AIM_LEAD := {"easy": 0.6, "normal": 1.0, "hard": 1.25}

static func aim_lead_factor(wave: int) -> float:
	var lead := clampf(float(maxi(wave, 1) - 2) * 0.09, 0.0, AIM_LEAD_CAP)
	if difficulty_applies():
		lead *= float(DIFF_AIM_LEAD.get(Game.difficulty, 1.0))
	return clampf(lead, 0.0, AIM_LEAD_CAP)

static func arena_rect() -> Rect2:
	var arena_size := Vector2(ARENA_W, ARENA_H)
	if _arena_size_override.x > 0.0 and _arena_size_override.y > 0.0:
		arena_size = _arena_size_override
	# O trait `cramped` encolhe o campo. Fica DEPOIS do override porque o
	# TempleOS já escolheu um tamanho e a semana só o aperta mais.
	arena_size *= Weekly.factor("arena")
	return Rect2(-arena_size * 0.5, arena_size)

static func set_arena_size_override(arena_size: Vector2) -> void:
	_arena_size_override = Vector2(maxf(arena_size.x, 0.0), maxf(arena_size.y, 0.0))

static func clear_arena_size_override() -> void:
	_arena_size_override = Vector2.ZERO

static func is_desktop_display(display_name: String = "") -> bool:
	var name := display_name.to_lower() if display_name != "" else DisplayServer.get_name().to_lower()
	return name in ["windows", "macos", "x11", "wayland", "embedded"]

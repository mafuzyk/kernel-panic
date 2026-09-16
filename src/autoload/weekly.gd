extends Node

## Mutadores da semana.
##
## O Weekly de 3.1 era `classic` com uma seed fixa: mesma arena, mesmo elenco,
## mesma tabela de patches. A seed garantia que todo mundo jogasse a MESMA run,
## que é o que faz um placar semanal significar alguma coisa, mas nada tornava a
## semana uma coisa distinta da anterior.
##
## Agora a semana sorteia DOIS traits e um ROSTER — e sorteia com um gerador
## próprio, semeado pelo número da semana. Isso importa: usar a `Game.rng` aqui
## consumiria a mesma sequência que a arena usa para compor as ondas, e a
## composição semanal tem teste de determinismo em cima dela.

## Um trait é um multiplicador nomeado. Mantê-los como dados — e não como `if`
## espalhado — é o que deixa o autotest afirmar cada um sem montar uma arena.
const TRAITS := {
	"swift":     {"enemy_speed": 1.22},
	"armored":   {"enemy_hp": 1.35, "budget": 0.85},
	"swarm":     {"budget": 1.35, "enemy_hp": 0.75},
	"elite":     {"elite_chance": 2.5},
	"cramped":   {"arena": 0.82},
	"nodash":    {"dash": 0.0},
	"glass":     {"max_hp": -1.0},
	"overdrive": {"oc_fill": 1.6, "oc_duration": 0.6},
	"frugal":    {"patch_every": 2.0, "oc_fill": 1.5},
	"volatile":  {"burst_on_death": 1.0},
}

## Um roster é o elenco liberado na semana. Todo um deles inclui pelo menos uma
## unidade barata: sem isso o orçamento da onda não fecha e o spawner gira em
## falso até o `guard` estourar.
const ROSTERS := {
	"swarm":  ["drone", "splitter", "zombie", "spewer"],
	"ranged": ["drone", "spewer", "firewall", "recursor"],
	"heavy":  ["drone", "bulwark", "swap", "trojan"],
	"tricky": ["drone", "oom", "cron", "genius", "trojan"],
	"mixed":  ["drone", "lancer", "spewer", "splitter", "bulwark", "zombie"],
}

const TRAIT_COUNT := 2

var _cache_week := -1
var _cache: Dictionary = {}


## Gerador próprio da semana. Nunca toca a `Game.rng`.
static func rng_for_week(week: int) -> RandomNumberGenerator:
	var generator := RandomNumberGenerator.new()
	generator.seed = int(week) * 2654435761
	return generator

## `{"traits": [id, id], "roster": id}` para uma semana. Função pura do número
## da semana: duas chamadas, o mesmo resultado, em qualquer máquina.
static func plan_for_week(week: int) -> Dictionary:
	var generator := rng_for_week(week)
	var trait_ids: Array = TRAITS.keys()
	trait_ids.sort()
	var picked: Array[String] = []
	# Sorteio sem reposição: dois traits diferentes, sempre.
	var pool := trait_ids.duplicate()
	for _slot in mini(TRAIT_COUNT, pool.size()):
		var index := generator.randi_range(0, pool.size() - 1)
		picked.append(str(pool[index]))
		pool.remove_at(index)
	var roster_ids: Array = ROSTERS.keys()
	roster_ids.sort()
	var roster := str(roster_ids[generator.randi_range(0, roster_ids.size() - 1)])
	return {"traits": picked, "roster": roster}

func plan() -> Dictionary:
	var week := Game.week_number()
	if week != _cache_week:
		_cache_week = week
		_cache = plan_for_week(week)
	return _cache

## Traits só valem no Weekly. Fora dele esta função devolve lista vazia, e todo
## multiplicador abaixo devolve o neutro.
func active_traits() -> Array:
	if Game.mode != "weekly":
		return []
	return plan().get("traits", [])

func active_roster() -> String:
	if Game.mode != "weekly":
		return ""
	return str(plan().get("roster", ""))

func has_trait(id: String) -> bool:
	return active_traits().has(id)

## Produto dos traits ativos para uma chave. `1.0` quando ninguém mexe nela.
func factor(key: String, neutral: float = 1.0) -> float:
	var value := neutral
	for id in active_traits():
		var entry: Dictionary = TRAITS.get(str(id), {})
		if entry.has(key):
			value *= float(entry[key])
	return value

## Soma dos traits ativos para uma chave, para o que é aditivo (integridade).
func offset(key: String) -> float:
	var total := 0.0
	for id in active_traits():
		var entry: Dictionary = TRAITS.get(str(id), {})
		if entry.has(key):
			total += float(entry[key])
	return total

## Elenco liberado. Vazio significa "sem restrição".
func roster_kinds() -> Array:
	var id := active_roster()
	if id == "":
		return []
	return ROSTERS.get(id, [])

func trait_label(id: String) -> String:
	return tr("WEEKLY_TRAIT_%s" % id.to_upper())

func trait_blurb(id: String) -> String:
	return tr("WEEKLY_TRAIT_DESC_%s" % id.to_upper())

func roster_label(id: String) -> String:
	return tr("WEEKLY_ROSTER_%s" % id.to_upper())

## Uma linha para o menu e para o klog da arena. Vazia fora do Weekly.
func summary_line() -> String:
	if Game.mode != "weekly":
		return ""
	return summary_for_week(Game.week_number())

## O plano de uma semana QUALQUER, independente do modo em que se está. O
## placar precisa disto: ele fala do Weekly mesmo para quem acabou de jogar
## Classic, e `summary_line()` devolveria vazio ali.
func summary_for_week(week: int) -> String:
	var plan: Dictionary = plan_for_week(week)
	var ids: Array = plan.get("traits", [])
	if ids.is_empty():
		return ""
	var names: Array[String] = []
	for id in ids:
		names.append(trait_label(str(id)))
	return "%s // %s" % [" + ".join(names), roster_label(str(plan.get("roster", "")))]

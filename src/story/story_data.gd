class_name StoryData
extends RefCounted

## Fixed, hand-authored content for the first UNIX story act.
## Endless mode owns all procedural composition and difficulty scaling.
const STAGES := [
	{
		"id": "boot",
		"build": {},
		"hazard": "none",
		"path": "/boot",
		"title": "BOOT SEQUENCE",
		"intro": "The machine wakes with a clean process table. Something is already moving.",
		"klog": ["init: mounting /boot", "watchdog: first signal acquired", "kernel: input accepted"],
		"waves": [["drone"], ["drone", "drone"], ["drone", "drone", "drone"], ["drone", "drone", "drone", "drone"]],
		"scale": 0.92,
		"theme": {"base_col": Color("080b18"), "grid_col": Color("193456"), "glow_col": Color("0d4160"), "accent": Color("4ff2ff")}
	},
	{
		"id": "var_log",
		"build": {"rapid": 1},
		"hazard": "spill",
		"path": "/var/log",
		"title": "THE LOG PARTITION",
		"intro": "Old warnings spill out of storage. The spewers are not interested in being archived.",
		"klog": ["rsyslog: warning queue growing", "spewer: packet burst detected", "journal: do not rotate me"],
		"waves": [["drone", "drone"], ["spewer", "drone", "drone"], ["spewer", "spewer", "drone", "drone"], ["spewer", "spewer", "drone", "drone", "drone"]],
		"scale": 0.98,
		"theme": {"base_col": Color("100b18"), "grid_col": Color("44304d"), "glow_col": Color("42204d"), "accent": Color("b46bff")}
	},
	{
		"id": "net",
		"build": {"threads": 1, "light": 1},
		"hazard": "surge",
		"path": "/net",
		"title": "NETWORK NAMESPACE",
		"intro": "Every connection is hostile. Lancers have claimed the shortest route to your position.",
		"klog": ["netlink: route table unstable", "lancer: line of sight established", "firewall: handshake refused"],
		"waves": [["drone", "lancer"], ["lancer", "drone", "drone"], ["lancer", "lancer", "spewer", "drone"], ["lancer", "lancer", "lancer", "drone", "drone"]],
		"scale": 1.02,
		"theme": {"base_col": Color("08131b"), "grid_col": Color("174953"), "glow_col": Color("0b4f58"), "accent": Color("53e0cf")}
	},
	{
		"id": "mem",
		"build": {"magnet": 1, "frag": 1},
		"hazard": "shrink",
		"path": "/mem",
		"title": "MEMORY PRESSURE",
		"intro": "Free memory is a lie. The OOM killer is harvesting motes while splitters multiply the mess.",
		"klog": ["kswapd0: reclaim failed", "oom_killer: looking for loose data", "allocator: fragmentation detected"],
		"waves": [["oom", "drone"], ["splitter", "drone", "oom"], ["splitter", "splitter", "oom", "drone"], ["splitter", "oom", "oom", "drone", "drone"], ["splitter", "splitter", "oom", "oom", "drone"]],
		"scale": 1.05,
		"theme": {"base_col": Color("0d0b1b"), "grid_col": Color("3e2a61"), "glow_col": Color("35165c"), "accent": Color("9a4dff")}
	},
	{
		"id": "quarantine",
		"build": {"light": 1, "dash": 1, "shield": 1},
		"hazard": "spill",
		"path": "/quarantine",
		"title": "QUARANTINE",
		"intro": "The infected processes were isolated. They kept their routes, their teeth, and their opinions.",
		"klog": ["security: quarantine boundary active", "trojan: route mutation complete", "corruption: containment failing"],
		"waves": [["trojan", "drone"], ["trojan", "splitter", "drone"], ["trojan", "oom", "spewer", "drone"], ["trojan", "trojan", "splitter", "oom", "drone"], ["firewall", "trojan", "splitter", "oom", "spewer"]],
		"scale": 1.08,
		"theme": {"base_col": Color("180a17"), "grid_col": Color("5a2637"), "glow_col": Color("5a162d"), "accent": Color("ff5c78")}
	},
	{
		"id": "kernel",
		"build": {"heavy": 1, "core": 1, "shield": 1},
		"hazard": "no_heal",
		"path": "/kernel",
		"title": "KERNEL PANIC",
		"intro": "All paths terminate here. The root daemon has reserved the last clean address.",
		"klog": ["kernel: unrecoverable exception", "root.exe: fork requested", "panic: last process standing"],
		"waves": [["drone", "spewer", "lancer"], ["splitter", "oom", "trojan", "drone"], ["recursor", "firewall", "lancer", "spewer"], ["bulwark", "trojan", "splitter", "oom", "recursor"], ["boss"]],
		"boss": "ROOT DAEMON",
		"boss_index": 1,
		"boss_scale": 1.10,
		"scale": 1.10,
		"theme": {"base_col": Color("160812"), "grid_col": Color("572137"), "glow_col": Color("63142e"), "accent": Color("ff3d81")}
	},
	{
		"id": "win98",
		"build": {"rapid": 2, "chain": 1},
		"hazard": "none",
		"act": "windows",
		"path": "C:\\98",
		"title": "WINDOWS 98",
		"intro": "The desktop loads. The desktop immediately asks for a driver it lost in 1998.",
		"klog": ["winlogon: welcome back", "explorer: 47 icons restored", "system: this computer may be shut down"],
		"waves": [["drone", "drone"], ["lancer", "spewer", "drone"], ["splitter", "trojan", "drone", "drone"], ["bulwark", "lancer", "spewer", "trojan"]],
		"scale": 1.02,
		"theme": {"base_col": Color("222b2e"), "grid_col": Color("3a777c"), "glow_col": Color("2b5c61"), "accent": Color("79d6ce"), "grid_style": "crt_heavy", "crt": {"curvature": 0.075, "noise": 0.075, "scanline": 0.22, "aberration": 0.7}},
		"watermark": true
	},
	{
		"id": "winxp",
		"build": {"threads": 2, "dash": 1, "shield": 1},
		"hazard": "surge",
		"act": "windows",
		"path": "C:\\XP",
		"title": "WINDOWS XP",
		"intro": "The Luna shell is smooth, bright, and somehow still installing updates during combat.",
		"klog": ["winlogon: blue-green session active", "update: reboot scheduled", "theme: luna applied successfully"],
		"waves": [["drone", "spewer", "drone"], ["update_loop", "drone", "lancer"], ["update_loop", "spewer", "splitter", "drone"], ["update_loop", "trojan", "bulwark", "lancer"]],
		"scale": 1.06,
		"theme": {"base_col": Color("10223c"), "grid_col": Color("3e7db3"), "glow_col": Color("1f5e9e"), "accent": Color("74b9ff"), "grid_style": "crt_soft", "crt": {"curvature": 0.035, "noise": 0.035, "scanline": 0.10, "aberration": 0.28}},
		"watermark": true
	},
	# Vidro ESCURO, não light mode.
	#
	# O tema original nascia com `base_col #dfe9f2` (luminância 0.91). O shader
	# soma luz sobre a base (`col = base_col + grade` e depois o brilho central),
	# então o centro da arena saía em (1.67, 1.89, 2.06): branco puro, sem matiz,
	# doloroso de olhar. A identidade da fase é "limpo demais" — sem CRT, cantos
	# suaves, azul corporativo, watermark — e nada disso depende de fundo claro.
	{
		"id": "win11",
		"build": {"ricochet": 1, "heavy": 1, "light": 1},
		"hazard": "haste",
		"act": "windows",
		"path": "Win11",
		"title": "WINDOWS 11",
		"intro": "A clean glass desktop hides a familiar problem: too many background processes.",
		"klog": ["shell: rounded corners enabled", "telemetry: everything is fine", "bloatware: 47 background processes active"],
		"waves": [["drone", "update_loop", "drone"], ["bloatware", "spewer", "lancer"], ["bloatware", "update_loop", "splitter", "drone"], ["bloatware", "bloatware", "trojan", "oom", "spewer"]],
		"scale": 1.10,
		"theme": {"base_col": Color("0e141c"), "grid_col": Color("2a3f55"), "glow_col": Color("18354d"), "accent": Color("4aa3e8"), "grid_style": "clean"},
		"watermark": true
	},
	# ── ATO 3 // macOS ──────────────────────────────────────────────────
	#
	# O ato não exige export para macOS: é conteúdo, e roda nos três alvos
	# oficiais. A identidade é o oposto da do Windows — nada de CRT, nada de
	# ruído: superfícies calmas, azul aqua, grafite. A piada é que a máquina
	# educada é a que menos te deixa fazer o que você quer.
	#
	# Todos os quatro temas passam pela varredura de luminância de campo que o
	# `Win11` reprovou, INCLUSIVE invertidos — o boss deste ato inverte o matiz
	# do campo como ataque.
	{
		"id": "mac_system",
		"build": {"light": 2, "dash": 2},
		"hazard": "no_heal",
		"act": "macos",
		"path": "/System",
		"title": "SYSTEM INTEGRITY",
		"intro": "The volume is read-only and very polite about it. Something is spinning.",
		"klog": ["sip: system integrity protection enabled", "beachball: not responding", "launchd: everything is fine"],
		"waves": [["drone", "drone"], ["beachball", "drone"], ["beachball", "spewer", "drone"], ["beachball", "beachball", "lancer", "drone"]],
		"scale": 1.04,
		"theme": {"base_col": Color("0d1117"), "grid_col": Color("33506e"), "glow_col": Color("1c3c5c"), "accent": Color("5ac8fa"), "grid_style": "clean"}
	},
	{
		"id": "mac_apps",
		"build": {"core": 1, "threads": 2, "turbo": 1},
		"hazard": "none",
		"act": "macos",
		"path": "/Applications",
		"title": "THE GENIUS BAR",
		"intro": "Every process here knows what you meant to do. None of them asked.",
		"klog": ["genius: let me correct that for you", "gatekeeper: this process cannot be opened", "dock: magnification enabled"],
		"waves": [["genius", "drone"], ["genius", "beachball", "drone"], ["genius", "genius", "spewer"], ["genius", "beachball", "bulwark", "lancer"]],
		"scale": 1.07,
		"theme": {"base_col": Color("121018"), "grid_col": Color("4b4166"), "glow_col": Color("2e2450"), "accent": Color("c08cff"), "grid_style": "clean"}
	},
	{
		"id": "mac_updates",
		"build": {"splitshot": 1, "rapid": 2, "shield": 1},
		"hazard": "shrink",
		"act": "macos",
		"path": "/Library/Updates",
		"title": "SOFTWARE UPDATE",
		"intro": "The update is ready to install. It has been ready to install for eleven months.",
		"klog": ["softwareupdated: restart required", "beachball: still not responding", "update: remind me tomorrow"],
		"waves": [["update_loop", "beachball", "drone"], ["genius", "update_loop", "spewer"], ["beachball", "genius", "update_loop", "splitter"], ["update_loop", "update_loop", "genius", "beachball", "trojan"]],
		"scale": 1.10,
		"theme": {"base_col": Color("0b1414"), "grid_col": Color("2f5f59"), "glow_col": Color("153f3e"), "accent": Color("4fd8c0"), "grid_style": "clean"}
	},
	{
		"id": "mac_kernel_task",
		"build": {"heavy": 2, "core": 1, "pdash": 1},
		"hazard": "no_heal",
		"act": "macos",
		"path": "kernel_task",
		"title": "KERNEL TASK",
		"intro": "The machine has decided the problem is you. It would like you to restart.",
		"klog": ["kernel_task: thermal pressure nominal", "panic: you need to restart your computer", "watchdog: reboot in 3... 3... 3..."],
		"waves": [["genius", "beachball", "spewer"], ["update_loop", "genius", "bulwark", "beachball"], ["genius", "genius", "beachball", "update_loop", "recursor"], ["kernel_task"]],
		"boss": "KERNEL_TASK",
		"boss_kind": "kernel_task",
		"boss_index": 1,
		"boss_scale": 1.08,
		"scale": 1.12,
		"theme": {"base_col": Color("16121a"), "grid_col": Color("5a4a5e"), "glow_col": Color("3a2440"), "accent": Color("ff6f8f"), "grid_style": "clean"}
	},
	{
		"id": "temple_boot",
		"build": {"ricochet": 1, "chain": 2},
		"hazard": "haste",
		"act": "templeos",
		"path": "TempleOS::BOOT",
		"title": "THE HOLY BOOT",
		"intro": "The system boots in a cathedral of pixels. The rainbow is not optional.",
		"klog": ["temple: praise the scheduler", "graphics: rainbow driver loaded", "oracle: probability is a form of worship"],
		"waves": [["drone", "drone"], ["lancer", "spewer", "drone"], ["splitter", "trojan", "oom", "drone"], ["bulwark", "lancer", "spewer", "trojan"]],
		"scale": 1.04,
		"arena_size": Vector2(640.0, 640.0),
		"theme": {"base_col": Color("180e1d"), "grid_col": Color("d68a46"), "glow_col": Color("ff6d70"), "accent": Color("ffd24f"), "grid_style": "holy", "crt": {"curvature": 0.02, "noise": 0.035, "scanline": 0.16, "aberration": 0.10, "holy": 1.0}}
	},
	{
		"id": "temple_god",
		"build": {"staticf": 1, "core": 2, "shield": 2},
		"hazard": "no_heal",
		"act": "templeos",
		"path": "TempleOS::GOD",
		"title": "ORACLE PROCESS",
		"intro": "The final process does not predict the next attack. It rolls for one.",
		"klog": ["oracle: six-sided truth unavailable", "scheduler: GOD has entered the room", "panic: randomness is now a mechanic"],
		"waves": [["drone", "spewer", "lancer"], ["splitter", "oom", "trojan", "bulwark"], ["recursor", "firewall", "drone", "spewer"], ["god"]],
		"boss": "GOD",
		"boss_kind": "god",
		"boss_index": 1,
		"boss_scale": 1.0,
		"scale": 1.08,
		"arena_size": Vector2(640.0, 640.0),
		"theme": {"base_col": Color("1c0b20"), "grid_col": Color("f2a44e"), "glow_col": Color("ff536d"), "accent": Color("ffd24f"), "grid_style": "holy", "crt": {"curvature": 0.02, "noise": 0.04, "scanline": 0.18, "aberration": 0.12, "holy": 1.0}}
	}
]

## ── objetivo, ritmo e recompensa ──────────────────────────────────────
##
## O Story de 3.0 era uma lista de ondas: entrava, matava, saía. Não havia o que
## PERSEGUIR dentro de uma fase nem o que levar dela. Três coisas mudam isso e
## todas vivem aqui, ao lado das ondas que elas medem.

## Tempo-alvo da fase, em segundos. Derivado das ondas para não virar uma tabela
## paralela que envelhece sozinha; uma fase pode sobrescrever com `"par"`.
## Build FIXO da fase.
##
## O Story rodava sem build nenhum: nenhuma oferta de patch, nenhum patch
## ativo. Isso deixava a fase mecanicamente rasa e — pior — igual à anterior,
## porque o único eixo que mudava era a lista de ondas.
##
## Agora a FASE entrega as ferramentas, montadas à mão e sempre as mesmas. É o
## oposto do endless de propósito: lá o build é sorteado e é o jogo; aqui ele é
## a premissa, e o jogo é o que a fase faz com ela.
static func stage_build(stage_id: String) -> Dictionary:
	return _stage_of(stage_id).get("build", {}).duplicate(true)

## Regra de campo da fase. Ver `src/arena/hazard_kit.gd`.
static func stage_hazard(stage_id: String) -> String:
	return str(_stage_of(stage_id).get("hazard", "none"))

static func stage_par_seconds(stage_id: String) -> float:
	var stage := _stage_of(stage_id)
	if stage.is_empty():
		return 0.0
	if stage.has("par"):
		return float(stage["par"])
	var wave_count: int = stage.get("waves", []).size()
	var boss_time := 45.0 if stage.has("boss") else 0.0
	return float(wave_count) * 22.0 + boss_time

## Falas do antagonista durante a fase. Momentos: OPEN (primeira onda), MID
## (metade), CLEAR (última onda limpa). O texto vive no CSV como todo texto de
## jogador; chave ausente devolve "" e o momento simplesmente não fala.
const BEAT_MOMENTS := ["OPEN", "MID", "CLEAR"]

static func localized_beat(stage_id: String, moment: String) -> String:
	if not BEAT_MOMENTS.has(moment):
		return ""
	return _localized("STORY_BEAT_%s_%s" % [stage_id.to_upper(), moment], "")

## Em que onda cai a fala do meio.
static func beat_wave_for_moment(stage_id: String, moment: String) -> int:
	var wave_count: int = _stage_of(stage_id).get("waves", []).size()
	if wave_count <= 0:
		return -1
	match moment:
		"OPEN":
			return 1
		"MID":
			return maxi(int(ceil(float(wave_count) / 2.0)), 1)
	return -1

## Recompensa por ATO limpo, não por fase: é o que dá um arco ao ato inteiro.
## Cada uma é uma tinta de campo para o endless, escolhida em Settings.
const ACT_REWARDS := {
	"unix": "unix",
	"windows": "crt",
	"macos": "aqua",
	"templeos": "rainbow",
}

static func act_reward(act_id: String) -> String:
	return str(ACT_REWARDS.get(act_id, ""))

## O ato termina na última fase que o declara.
static func is_act_final_stage(stage_id: String) -> bool:
	var stage := _stage_of(stage_id)
	if stage.is_empty():
		return false
	var act := str(stage.get("act", "unix"))
	var last := ""
	for candidate in STAGES:
		if str(candidate.get("act", "unix")) == act:
			last = str(candidate.get("id", ""))
	return last == stage_id

static func _stage_of(stage_id: String) -> Dictionary:
	for stage in STAGES:
		if str(stage.get("id", "")) == stage_id:
			return stage
	return {}

static func stage_count() -> int:
	return STAGES.size()

static func act_stage_count(act_id: String) -> int:
	# Contado do próprio STAGES: a tabela manual dizia "3 windows" e teria de ser
	# editada de novo a cada fase nova, num lugar longe de onde a fase nasce.
	var total := 0
	for stage in STAGES:
		if str(stage.get("act", "unix")) == act_id:
			total += 1
	return total

static func stage_at(index: int) -> Dictionary:
	if index < 0 or index >= STAGES.size():
		return {}
	return STAGES[index].duplicate(true)

static func stage_ids() -> Array:
	var result: Array = []
	for stage in STAGES:
		result.append(str(stage["id"]))
	return result

static func stage_wave_count(index: int) -> int:
	return stage_at(index).get("waves", []).size()

## Fonte única de localização do Story (seletor E runtime). Chaves derivam
## do id estável da fase; ausência de chave cai para o inglês cru do STAGES,
## nunca para a chave crua na tela.
static func localized_title(stage_id: String) -> String:
	return _localized("STORY_TITLE_%s" % stage_id.to_upper(), _raw(stage_id, "title"))

static func localized_intro(stage_id: String) -> String:
	return _localized("STORY_INTRO_%s" % stage_id.to_upper(), _raw(stage_id, "intro"))

static func localized_klog(stage_id: String, line_index: int) -> String:
	var raw_klog: Array = _raw(stage_id, "klog")
	var key := "STORY_KLOG_%s_%d" % [stage_id.to_upper(), line_index]
	var fallback := str(raw_klog[line_index % raw_klog.size()]) if not raw_klog.is_empty() else ""
	return _localized(key, fallback)

const ACT_FALLBACK_LABELS := {
	"unix": "ACT 1 // UNIX RECOVERY LOG",
	"windows": "ACT 2 // WINDOWS RECOVERY LOG",
	"macos": "ACT 3 // MACOS RECOVERY LOG",
	"templeos": "BONUS ACT // TEMPLEOS ORACLE LOG",
}

static func localized_act_label(act_id: String) -> String:
	var act := act_id if ACT_FALLBACK_LABELS.has(act_id) else "unix"
	return _localized("STORY_ACT_%s" % act.to_upper(), str(ACT_FALLBACK_LABELS[act]))

## Ordem em que os atos aparecem, derivada do próprio STAGES.
static func act_ids() -> Array:
	var ids: Array = []
	for stage in STAGES:
		var act := str(stage.get("act", "unix"))
		if not ids.has(act):
			ids.append(act)
	return ids

static func stage_id_of(index: int) -> String:
	return str(stage_at(index).get("id", ""))

static func _raw(stage_id: String, field: String):
	for stage in STAGES:
		if str(stage.get("id", "")) == stage_id:
			return stage.get(field, "")
	return "" if field != "klog" else []

static func _localized(key: String, fallback: String) -> String:
	var translated := TranslationServer.translate(key)
	return fallback if translated == key else translated

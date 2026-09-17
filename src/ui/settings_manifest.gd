class_name SettingsManifest
extends RefCounted

## Quais opções de settings existem em cada plataforma — declaradas UMA vez,
## como dado puro.
##
## Por que existe: até o 3.1 a resposta estava espalhada. `aim_mode` (mira de
## toque: drag/stick/lock-on) e o háptico apareciam no desktop, onde
## `Game.effective_aim_mode()` só é lido por `touch_controls.gd` — ou seja, a
## opção não fazia absolutamente nada num PC. O gate existia (`touch_only` +
## `_touch_only_controls_ok()`) mas estava aplicado a UM controle, o tamanho de
## toque. Toda opção nova repetia a escolha, e metade errava.
##
## Aqui a plataforma é atributo da opção, não um `if` no meio da construção da
## tela. Isso mata a classe de bug "opção que não faz nada aqui" por
## construção, e deixa o teste afirmar a regra sem montar UI nenhuma.
##
## ESCONDER É SÓ UI. O valor continua sendo salvo e carregado normalmente: o
## jogo transfere save entre celular e PC (`Game.SAVE_TRANSFER_FORMAT`), e
## quem configurou lock-on e tamanho de botão no celular tem que achar tudo no
## lugar ao voltar. Nada neste arquivo é consultado por `Sfx.save_settings()`
## nem pelo import — só por quem MONTA a tela.

const TOUCH := Platform.TOUCH
const DESKTOP := Platform.DESKTOP
const BOTH: Array[String] = [Platform.TOUCH, Platform.DESKTOP]
const TOUCH_ONLY: Array[String] = [Platform.TOUCH]
const DESKTOP_ONLY: Array[String] = [Platform.DESKTOP]

## Cada entrada é uma OPÇÃO de verdade — rótulos de grupo, notas e dicas são
## decoração e continuam fora daqui, presos à seção pelo `assign_section()`.
const ENTRIES := [
	{"id": "sfx_vol", "section": "AUDIO", "platforms": BOTH},
	{"id": "music_vol", "section": "AUDIO", "platforms": BOTH},
	{"id": "mute", "section": "AUDIO", "platforms": BOTH},

	# Modo de janela não existe num celular: Android roda em tela cheia e o
	# ciclo janela/cheia/sem-borda não tem para onde ir.
	{"id": "window_mode", "section": "VIDEO", "platforms": DESKTOP_ONLY},
	{"id": "vsync", "section": "VIDEO", "platforms": BOTH},
	{"id": "field_tint", "section": "VIDEO", "platforms": BOTH},

	# CONTROLS é a seção de controles DE CADA PLATAFORMA: teclas no desktop,
	# toque no celular. Estes três só são lidos pelo `touch_controls.gd` e
	# não têm efeito nenhum com mouse e teclado.
	{"id": "haptics", "section": "CONTROLS", "platforms": TOUCH_ONLY},
	{"id": "aim_mode", "section": "CONTROLS", "platforms": TOUCH_ONLY},
	{"id": "touch_scale", "section": "CONTROLS", "platforms": TOUCH_ONLY},
	{"id": "touch_handed", "section": "CONTROLS", "platforms": TOUCH_ONLY},
	{"id": "touch_opacity", "section": "CONTROLS", "platforms": TOUCH_ONLY},
	{"id": "shake", "section": "ACCESSIBILITY", "platforms": BOTH},
	{"id": "flash", "section": "ACCESSIBILITY", "platforms": BOTH},
	{"id": "text_scale", "section": "ACCESSIBILITY", "platforms": BOTH},
	{"id": "run_info", "section": "GAMEPLAY", "platforms": BOTH},

	{"id": "color_assist", "section": "ACCESSIBILITY", "platforms": BOTH},
	{"id": "language", "section": "ACCESSIBILITY", "platforms": BOTH},

	# Remapear tecla precisa de tecla.
	{"id": "keybinds", "section": "CONTROLS", "platforms": DESKTOP_ONLY},

	{"id": "board_enabled", "section": "BOARD", "platforms": BOTH},
	{"id": "board_url", "section": "BOARD", "platforms": BOTH},
	{"id": "board_name", "section": "BOARD", "platforms": BOTH},

	{"id": "save_transfer", "section": "SAVE DATA", "platforms": BOTH},
	{"id": "lifetime_stats", "section": "SAVE DATA", "platforms": BOTH},
	{"id": "reset_score", "section": "SAVE DATA", "platforms": BOTH},
]


## Ordem das seções POR PLATAFORMA.
##
## No celular o que mais importa vem primeiro: os controles de toque, que são
## a razão de alguém abrir esta tela no aparelho, e logo depois acessibilidade.
## No desktop a ordem histórica é mantida — quem já sabe onde as coisas estão
## não ganha nada com a mudança.
const SECTION_ORDER := {
	Platform.TOUCH: ["CONTROLS", "ACCESSIBILITY", "AUDIO", "VIDEO", "GAMEPLAY", "BOARD", "SAVE DATA"],
	Platform.DESKTOP: ["AUDIO", "VIDEO", "GAMEPLAY", "CONTROLS", "ACCESSIBILITY", "BOARD", "SAVE DATA"],
}


## Ordem declarada do perfil, caindo na do desktop se o perfil for desconhecido.
static func order_for(profile: String) -> Array:
	return SECTION_ORDER.get(profile, SECTION_ORDER[Platform.DESKTOP])


## A opção `id` aparece no perfil dado? Id desconhecido responde `true`: a
## tela nunca deve sumir com um controle só porque alguém esqueceu de
## declará-lo. O teste de cobertura é quem cobra a declaração.
static func shows(id: String, profile: String) -> bool:
	for entry in ENTRIES:
		if str(entry["id"]) == id:
			return Platform.serves(entry["platforms"], profile)
	return true


## Ids das opções servidas por um perfil, na ordem de declaração.
static func ids_for(profile: String) -> Array[String]:
	var out: Array[String] = []
	for entry in ENTRIES:
		if Platform.serves(entry["platforms"], profile):
			out.append(str(entry["id"]))
	return out


## Seções que têm ao menos UMA opção no perfil, preservando a ordem de
## `order`. Uma seção sem nada para mostrar não vira aba vazia: hoje é o caso
## de CONTROLS no toque, que só contém keybinds.
static func sections_for(profile: String, order: Array = []) -> Array[String]:
	if order.is_empty():
		order = order_for(profile)
	var served := {}
	for entry in ENTRIES:
		if Platform.serves(entry["platforms"], profile):
			served[str(entry["section"])] = true
	var out: Array[String] = []
	for section in order:
		if served.has(str(section)):
			out.append(str(section))
	return out


## Seção declarada de uma opção, ou string vazia se ela não está no manifesto.
static func section_of(id: String) -> String:
	for entry in ENTRIES:
		if str(entry["id"]) == id:
			return str(entry["section"])
	return ""

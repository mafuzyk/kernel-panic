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
	{"id": "aim_mode", "section": "CONTROLS", "platforms": TOUCH_ONLY, "in_run": true},
	{"id": "touch_scale", "section": "CONTROLS", "platforms": TOUCH_ONLY, "in_run": true},
	{"id": "touch_handed", "section": "CONTROLS", "platforms": TOUCH_ONLY, "in_run": true},
	{"id": "touch_opacity", "section": "CONTROLS", "platforms": TOUCH_ONLY, "in_run": true},
	{"id": "shake", "section": "ACCESSIBILITY", "platforms": BOTH, "in_run": true},
	{"id": "flash", "section": "ACCESSIBILITY", "platforms": BOTH, "in_run": true},
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


## Opções que valem ser ajustadas SEM sair da run.
##
## Até aqui trocar a mira ou o tamanho dos botões no meio de uma partida
## exigia abandoná-la: ir ao menu, mexer, voltar e recomeçar do zero. São
## justamente os ajustes que só se percebe que estão errados jogando.
static func ids_in_run(profile: String) -> Array[String]:
	var out: Array[String] = []
	for entry in ENTRIES:
		if bool(entry.get("in_run", false)) and Platform.serves(entry["platforms"], profile):
			out.append(str(entry["id"]))
	return out


## Rótulo pronto de uma opção, pelo id. É o que a pausa usa para montar as
## mesmas linhas da tela de settings sem conhecer nenhuma delas.
static func label_for(id: String) -> String:
	match id:
		"aim_mode": return TranslationServer.translate("SET_AIM") % Sfx.aim_mode.to_upper()
		"touch_scale": return TranslationServer.translate("SET_TOUCH_SIZE") % [
			TranslationServer.translate("SET_VAL_SMALL"),
			TranslationServer.translate("SET_VAL_NORMAL"),
			TranslationServer.translate("SET_VAL_BIG")][_touch_scale_step()]
		"touch_handed": return _touch_handed_label()
		"touch_opacity": return _touch_opacity_label()
		"shake": return TranslationServer.translate("SET_SHAKE") % [
			TranslationServer.translate("SET_VAL_OFF"),
			TranslationServer.translate("SET_VAL_LOW"),
			TranslationServer.translate("SET_VAL_FULL")][clampi(Sfx.shake_level, 0, 2)]
		"flash": return _flash_label()
	return ""


static func _touch_scale_step() -> int:
	var steps := [0.85, 1.0, 1.2]
	var best := 0
	for i in steps.size():
		if absf(steps[i] - Sfx.touch_scale) < absf(steps[best] - Sfx.touch_scale):
			best = i
	return best


## Avança uma opção para o próximo valor e devolve o rótulo novo.
static func cycle(id: String) -> String:
	match id:
		"aim_mode":
			var order := ["drag", "stick", "lockon"]
			Sfx.aim_mode = order[(order.find(Sfx.aim_mode) + 1) % order.size()]
		"touch_scale":
			var steps := [0.85, 1.0, 1.2]
			Sfx.touch_scale = steps[(_touch_scale_step() + 1) % steps.size()]
		"touch_handed":
			var modes: Array = Sfx.TOUCH_HANDED_MODES
			Sfx.touch_handed = str(modes[(modes.find(Sfx.touch_handed) + 1) % modes.size()])
		"touch_opacity":
			var op: Array = Sfx.TOUCH_OPACITY_STEPS
			Sfx.touch_opacity = float(op[(_touch_opacity_idx() + 1) % op.size()])
		"shake":
			Sfx.shake_level = (Sfx.shake_level + 1) % 3
		"flash":
			Sfx.flash_level = (Sfx.flash_level + 1) % 3
	Sfx.save_settings()
	return label_for(id)


## Seção declarada de uma opção, ou string vazia se ela não está no manifesto.
static func section_of(id: String) -> String:
	for entry in ENTRIES:
		if str(entry["id"]) == id:
			return str(entry["section"])
	return ""


## ── Rótulos das opções ───────────────────────────────────────────────────
##
## Ficam aqui, estáticos, porque agora têm DOIS consumidores: a tela de
## settings e o painel de pausa. Duplicá-los deixaria os dois discordarem no
## primeiro ajuste de texto.
static func _text_scale_idx() -> int:
	var steps: Array = Sfx.TEXT_SCALE_STEPS
	var best := 0
	for i in steps.size():
		if absf(float(steps[i]) - Sfx.text_scale) < absf(float(steps[best]) - Sfx.text_scale):
			best = i
	return best
static func _text_scale_label() -> String:
	var names := [TranslationServer.translate("SET_VAL_NORMAL"), TranslationServer.translate("SET_VAL_BIG"), TranslationServer.translate("SET_VAL_LARGER")]
	return TranslationServer.translate("SET_TEXT_SIZE") % names[_text_scale_idx()]
## Rótulo da intensidade de luz, na mesma escala do shake.
static func _flash_label() -> String:
	var names := [TranslationServer.translate("SET_VAL_OFF"), TranslationServer.translate("SET_VAL_LOW"), TranslationServer.translate("SET_VAL_FULL")]
	return TranslationServer.translate("SET_FLASH") % names[clampi(Sfx.flash_level, 0, 2)]
## Rótulo do lado que comanda. "DIREITA" é o histórico: ações à direita,
## movimento à esquerda.
static func _touch_handed_label() -> String:
	var value := TranslationServer.translate("SET_VAL_LEFT") if Sfx.touch_handed == "left" else TranslationServer.translate("SET_VAL_RIGHT")
	return TranslationServer.translate("SET_TOUCH_HANDED") % value
## Degrau de opacidade mais próximo do valor salvo — o valor em disco é
## contínuo e pode vir de uma versão futura com outra escala.
static func _touch_opacity_idx() -> int:
	var steps: Array = Sfx.TOUCH_OPACITY_STEPS
	var best := 0
	for i in steps.size():
		if absf(float(steps[i]) - Sfx.touch_opacity) < absf(float(steps[best]) - Sfx.touch_opacity):
			best = i
	return best
static func _touch_opacity_label() -> String:
	var names := [TranslationServer.translate("SET_VAL_FAINT"), TranslationServer.translate("SET_VAL_LOW"), TranslationServer.translate("SET_VAL_FULL")]
	return TranslationServer.translate("SET_TOUCH_OPACITY") % names[_touch_opacity_idx()]

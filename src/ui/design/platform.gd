class_name Platform
extends RefCounted

## Perfil de plataforma da INTERFACE.
##
## Não é detecção de sistema operacional. A pergunta que importa para a UI é
## "esta tela está sendo tocada ou clicada?", porque é ela que decide o que
## aparece, em que ordem e com que tamanho de alvo.
##
## O código de JOGO é o mesmo nos dois perfis. O que muda aqui é apresentação:
## quais controles existem na tela, como são agrupados e quão grandes são.
## Nada neste arquivo deve alterar regra, física, pontuação ou save.

const TOUCH := "touch"
const DESKTOP := "desktop"
const ALL: Array[String] = [TOUCH, DESKTOP]


## Delegação deliberada a `Design.touch_input()`: ele já é o predicado do
## projeto e já respeita `KP_FORCE_TOUCH`, que é como o harness prova as duas
## faces sem aparelho real. Um segundo predicado viraria uma segunda verdade,
## e as duas divergiriam no primeiro caso de borda.
static func is_touch() -> bool:
	return Design.touch_input()


## Identificador do perfil corrente, para casar com as listas de plataforma
## do manifesto de settings.
static func id() -> String:
	return TOUCH if is_touch() else DESKTOP


## Verdadeiro quando `platforms` (do manifesto) inclui o perfil dado.
## Lista vazia significa "nenhuma plataforma" e esconde — nunca "todas".
## O contrário deixaria uma entrada malformada vazar para as duas telas.
static func serves(platforms: Array, profile: String) -> bool:
	return platforms.has(profile)

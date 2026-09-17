class_name Design
extends RefCounted

## Tokens de design do KERNEL PANIC — fonte única de verdade para tipografia,
## espaçamento, cor semântica, borda e movimento da interface.
##
## Por que existe: antes disto a UI usava 17 tamanhos de fonte distintos
## (11 deles consecutivos entre 10 e 20px), 21 níveis de opacidade de texto
## e 10 espaçamentos avulsos — nenhum deles uma escala. Cada widget era
## pintado à mão com 310 chamadas `add_theme_*_override` espalhadas.
##
## Regra: nenhum arquivo de UI deve conter número mágico de tamanho, cor,
## espaçamento ou duração. Se falta um token, adicione aqui.
##
## As cores de ENTIDADE (drone, lancer, spewer...) continuam em `Balance`:
## são identidade de gameplay, não de interface. Este arquivo só define os
## papéis de UI e reusa a paleta de lá onde faz sentido.

# ─────────────────────────────────────────────────────────────────────
# TIPOGRAFIA
# ─────────────────────────────────────────────────────────────────────

## Orbitron: títulos e números. Geométrica, wide, alta presença.
const FONT_DISPLAY := preload("res://assets/fonts/Orbitron.ttf")
## Share Tech Mono: corpo, rótulos, tudo que é "terminal".
const FONT_MONO := preload("res://assets/fonts/ShareTechMono.ttf")
## Adwaita Sans (OFL-1.1): grotesca variável para a tipografia editorial das
## telas de estado. Orbitron não faz esse papel — é display geométrica larga e
## em corpo grande lê como logo de ficção científica, não como tipografia.
##
## Custo: 880KB contra 38KB do Orbitron, por ser variável e de cobertura ampla.
## Vale um subsetting (latim + pesos usados) antes de um release mobile.
const FONT_GROTESK := preload("res://assets/fonts/AdwaitaSans.ttf")

## Pesos da grotesca.
const WEIGHT_REGULAR := 400
const WEIGHT_BOLD := 700
const WEIGHT_HEAVY := 800
const WEIGHT_BLACK := 900

## Escala de tipo — 7 degraus, cada um com papel definido.
## Consolidada a partir do uso real: 42/44 eram o mesmo papel, 28/30 também.
const TEXT_MICRO := 11      ## selos, unidades, rodapé de painel
const TEXT_CAPTION := 13    ## rótulos de campo, dicas, legendas
const TEXT_BODY := 15       ## corpo padrão, descrições
const TEXT_SUBHEAD := 18    ## rótulo de botão, cabeçalho de lista
const TEXT_HEADING := 28    ## título de tela (SETTINGS //, BESTIARY //)
const TEXT_TITLE := 36      ## título de painel de estado (PAUSED)
const TEXT_DISPLAY := 60    ## exclusivo do título do menu

## A escala inteira, em ordem. É o único lugar que conhece a sequência, e é
## por onde a escala global de texto vai multiplicar.
const TEXT_SCALE := [TEXT_MICRO, TEXT_CAPTION, TEXT_BODY, TEXT_SUBHEAD,
	TEXT_HEADING, TEXT_TITLE, TEXT_DISPLAY]


## Tamanho final em pixels, com a preferência de texto da pessoa aplicada.
##
## TODO tamanho de fonte da UI passa por aqui. É o que permite uma escala
## global sem tocar em 60 lugares — e só é possível porque nenhum arquivo de
## UI carrega mais número mágico; o harness exige isso.
static func px(size: int) -> int:
	return int(round(float(size) * Sfx.text_scale))


## Um degrau abaixo na escala.
##
## Telas estreitas encolhiam o texto com números avulsos — "32 se compacto,
## senão 60" — que não eram degraus de escala nenhuma e viravam número mágico
## em cada arquivo. Descer degrau é a mesma decisão em todo lugar, então mora
## aqui.
static func step_down(size: int, steps: int = 1) -> int:
	var index := TEXT_SCALE.find(size)
	if index < 0:
		return size
	return int(TEXT_SCALE[maxi(index - maxi(steps, 0), 0)])


## Entrelinha como múltiplo do tamanho da fonte.
const LEADING_TIGHT := 1.15
const LEADING_NORMAL := 1.45

# ─────────────────────────────────────────────────────────────────────
# ESPAÇAMENTO — escala base 4
# ─────────────────────────────────────────────────────────────────────

const SPACE_XS := 4
const SPACE_SM := 8
const SPACE_MD := 12
const SPACE_LG := 16
const SPACE_XL := 24
const SPACE_2XL := 32
const SPACE_3XL := 48
const SPACE_4XL := 64

# ─────────────────────────────────────────────────────────────────────
# COR — papéis semânticos, não valores crus
# ─────────────────────────────────────────────────────────────────────

## Superfícies. Painel de overlay é OPACO por contrato: quatro painéis
## usavam alpha diferente e o de conquistas vazava o menu por trás.
const SURFACE := Color(0.01, 0.012, 0.03, 1.0)
const SURFACE_RAISED := Color(0.015, 0.020, 0.048, 1.0)
const SURFACE_SUNKEN := Color(0.006, 0.008, 0.022, 1.0)
## Véu sobre a cena de jogo (pausa, seleção de patch) — aí a transparência
## é intencional, para manter contexto do que está acontecendo atrás.
const SCRIM := Color(0.005, 0.006, 0.015, 0.82)

## Texto — 5 níveis. Antes eram 21 opacidades indistinguíveis.
const TEXT_PRIMARY := Color("cfe9ff")
const TEXT_SECONDARY := Color(0.812, 0.914, 1.0, 0.72)
const TEXT_MUTED := Color(0.812, 0.914, 1.0, 0.55)
const TEXT_FAINT := Color(0.812, 0.914, 1.0, 0.35)
const TEXT_GHOST := Color(0.812, 0.914, 1.0, 0.15)

## Acento e estados semânticos.
const ACCENT := Color("4ff2ff")           ## ciano do processo do jogador
const ACCENT_HOT := Color("d8ffff")       ## acento em destaque/ativo
const ACCENT_MUTED := Color(0.310, 0.949, 1.0, 0.45)  ## acento de baixa ênfase
const DANGER := Color("ff2a4d")           ## perigo, morte, abandono
const WARNING := Color("ffd24f")          ## atenção, recorde, motes
const SUCCESS := Color("52ff7a")          ## cura, integridade recuperada
const INFO := Color("58b8ff")             ## neutro informativo

## Bordas — derivadas do acento para manter o visual táctico coeso.
const BORDER := Color(0.310, 0.949, 1.0, 0.35)
const BORDER_STRONG := Color(0.310, 0.949, 1.0, 0.65)
const BORDER_SUBTLE := Color(0.310, 0.949, 1.0, 0.15)

## Espessuras de traço.
const STROKE_HAIRLINE := 1.0
const STROKE_REGULAR := 2.0
const STROKE_THICK := 3.0

# ─────────────────────────────────────────────────────────────────────
# ESTADOS INTERATIVOS
# ─────────────────────────────────────────────────────────────────────
## Multiplicadores aplicados sobre a cor base de um controle. Os botões
## usam foco de teclado; nos alvos transparentes, o estado visual também
## precisa alcançar o conteúdo que vive em nós separados.

const STATE_HOVER_BOOST := 1.25      ## brilho no hover
const STATE_PRESSED_BOOST := 0.85    ## afunda no clique
const STATE_DISABLED_ALPHA := 0.35
const FOCUS_RING_WIDTH := 2.0
const FOCUS_RING_COLOR := Color("ffd24f")  ## âmbar: não colide com o ciano

# ─────────────────────────────────────────────────────────────────────
# MOVIMENTO
# ─────────────────────────────────────────────────────────────────────

const MOTION_INSTANT := 0.08   ## resposta de controle (hover, press)
const MOTION_FAST := 0.18      ## troca de aba, aparecer/sumir de chip
const MOTION_NORMAL := 0.35    ## entrada de painel
const MOTION_SLOW := 0.6       ## transição de cena, fade de intro

# ─────────────────────────────────────────────────────────────────────
# LAYOUT RESPONSIVO
# ─────────────────────────────────────────────────────────────────────
## Foco atual é desktop. Os breakpoints existem para o layout parar de
## partir de um palco fixo de 1280x720 e escalar por proporção — que é o
## motivo de tudo acima de 1366px ficar pequeno e sobrando tela.

const BP_COMPACT := 720.0    ## janela estreita / retrato
const BP_MEDIUM := 1100.0    ## laptop
const BP_WIDE := 1500.0      ## desktop
const BP_ULTRA := 1900.0     ## 1080p cheio e acima

## Largura máxima de coluna de conteúdo. Sem isto, um slider de volume
## 0-100% estica por ~1000px em 1920 e o rótulo fica a 1200px do controle.
const CONTENT_MAX_FORM := 720.0     ## formulários (settings)
const CONTENT_MAX_PROSE := 640.0    ## texto corrido (lore, descrições)
const CONTENT_MAX_PANEL := 1080.0   ## painéis de estado (pausa, game over)

## Alvo mínimo de toque/clique. 44px é o mínimo confortável de mouse;
## no celular o alvo sobe (ver TOUCH_TARGET_MIN).
## Largura de um controle deslizante. Um valor de 0-100% não ganha nada em
## esticar: só afasta o rótulo do controle e o controle do valor.
## Largura abaixo da qual a tela se recompõe em coluna única. O número já
## estava repetido como 760 literal em três lugares.
const COMPACT_WIDTH := 760.0
const SLIDER_WIDTH := 320.0

const CLICK_TARGET_MIN := 44.0
const TOUCH_TARGET_MIN := 56.0


## Degrau de breakpoint da largura dada: "compact", "medium", "wide" ou "ultra".
static func breakpoint_for(viewport_width: float) -> String:
	if viewport_width < BP_COMPACT:
		return "compact"
	if viewport_width < BP_MEDIUM:
		return "medium"
	if viewport_width < BP_WIDE:
		return "wide"
	return "ultra"


## Dica de rolagem. "SWIPE TO SCROLL" vazava no build de desktop (B7) porque
## a string era fixa em três painéis. Recebe o modo por parâmetro para ser
## testável sem depender do dispositivo real.
static func scroll_hint(is_touch: bool) -> String:
	return "SWIPE TO SCROLL" if is_touch else "SCROLL // MOUSE WHEEL"


## Verdadeiro quando a entrada corrente é toque.
static func touch_input() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.get_environment("KP_FORCE_TOUCH") != ""


## Alvo mínimo de interação para o dispositivo atual.
##
## Passa por `touch_input()` e não por `DisplayServer` direto: senão
## `KP_FORCE_TOUCH` mudava o que a UI MOSTRA sem mudar o tamanho do alvo, e o
## contrato de 56px ficava impossível de afirmar sem aparelho de verdade.
static func target_min() -> float:
	return TOUCH_TARGET_MIN if touch_input() else CLICK_TARGET_MIN


## Margens da safe area em unidades de canvas. Zero no desktop ou sem cutout.
## O desktop não muda quando não há inset móvel: o retorno é zero exato.
static func safe_margins(canvas_size: Vector2) -> Dictionary:
	var zero := {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	if not touch_input():
		return zero
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return zero
	return safe_margins_from(window_size, DisplayServer.get_display_safe_area(), canvas_size)

## Matemática pura da conversão (testável sem cutout real).
static func safe_margins_from(window_size: Vector2, safe: Rect2i, canvas_size: Vector2) -> Dictionary:
	var zero := {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	if window_size.x <= 0.0 or window_size.y <= 0.0 or canvas_size.x <= 0.0 or canvas_size.y <= 0.0:
		return zero
	var sx := canvas_size.x / window_size.x
	var sy := canvas_size.y / window_size.y
	return {
		"left": maxf(0.0, float(safe.position.x) * sx),
		"top": maxf(0.0, float(safe.position.y) * sy),
		"right": maxf(0.0, (window_size.x - float(safe.end.x)) * sx),
		"bottom": maxf(0.0, (window_size.y - float(safe.end.y)) * sy),
	}


## Aplica um multiplicador de brilho preservando o alpha.
static func shade(base: Color, mult: float) -> Color:
	return Color(
		clampf(base.r * mult, 0.0, 1.0),
		clampf(base.g * mult, 0.0, 1.0),
		clampf(base.b * mult, 0.0, 1.0),
		base.a
	)


## Mesma cor com outro alpha — evita reconstruir Color(c.r, c.g, c.b, a)
## à mão, padrão que aparece dezenas de vezes hoje.
static func alpha(base: Color, a: float) -> Color:
	return Color(base.r, base.g, base.b, a)


## Tag numérica do eixo de peso. `TextServer.name_to_tag()` não é estático, e
## passar a string "wght" como chave de `variation_opentype` é silenciosamente
## ignorado — o texto sai em Regular sem erro nenhum.
static var _WEIGHT_TAG: int = TextServerManager.get_primary_interface().name_to_tag("weight")
static var _grotesk_cache: Dictionary = {}


## Grotesca no peso pedido. As instâncias são cacheadas: criar uma
## FontVariation por Label recarregaria o atlas de glifos a cada vez.
static func grotesk(weight: int = WEIGHT_BLACK) -> FontVariation:
	if _grotesk_cache.has(weight):
		return _grotesk_cache[weight]
	var fv := FontVariation.new()
	fv.base_font = FONT_GROTESK
	fv.variation_opentype = {_WEIGHT_TAG: weight}
	_grotesk_cache[weight] = fv
	return fv

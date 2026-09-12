# Telas de seleção portadas, e uma descoberta sobre o viewport

2026-09-12 · branch `feat/design-system-and-glyphs`

## O que motivou

A autora apontou que `story`, `program`, `bestiary` e `patch_card` estavam
visualmente fora do resto. Estavam: eram um segundo design system rodando ao
lado do primeiro. Medida objetiva antes de começar — uso de token de `Design`
ou de `TacticalStyleBox` por arquivo de UI:

```
achievements_panel.gd  2
story_panel.gd         0
program_panel.gd       0
bestiary_panel.gd      0
patch_card.gd          0
```

As quatro eram `_draw()` puro com offset absoluto de um palco de 1280x720,
Orbitron 13–21 para títulos, mono 9–13 para todo o resto, e a cor de identidade
da entidade pintando moldura, fundo, régua, rodapé e texto ao mesmo tempo.

## Feito

### SELECT PROGRAM → `src/ui/program_panel.gd`

Container no lugar de offset. Escala de tipo real (grotesca preta 30 para o nome
do programa, mono para rótulo). A cor de identidade desceu a **marcador**: o
glyph, o sobrolho do papel e uma régua de 1px. O texto voltou para tinta neutra.
Seleção deixou de ser mais uma moldura por cima — é a barra sólida na borda
esquerda do card, um estado só.

### SELECT MOUNT POINT → `src/ui/story_panel.gd`

O "mapa de rota" (grade de cards ligados por linhas) virou **lista vertical
numerada**. A progressão continua legível de cima para baixo; cada linha tem
largura de sobra para o caminho e o título, que antes caíam para 9px em cards de
156px. O painel de detalhe passou a ser o corpo da tela.

## Três mentiras da UI que o porte expôs

Não são regressões do porte — são coisas que a versão anterior desenhava e não
fazia. Ficam registradas porque eu as corrigi junto.

1. **`>> BOOT KERNEL [ENTER]`** no rodapé do seletor de programa não estava
   ligado em nada. Rótulo sem ação. Agora dá boot.
2. **`MOUNT /boot [ENTER]`** no seletor de fase também não. Pior: `stage_selected`
   ia direto em `_start_story`, então **clicar num card já iniciava a fase** — o
   painel de detalhe, metade da tela, era impossível de ler, porque o clique que
   o preencheria também entrava nela. Agora são dois passos: selecionar destaca,
   montar entra.
3. **`ARENA PREVIEW`** era uma grade estática com um ponto no meio, idêntica para
   as onze fases. Decoração fingindo informação. No lugar entraram as silhuetas
   reais das ameaças da fase, pela mesma `GlyphLib` que a arena usa.

## A descoberta: os breakpoints de largura nunca disparam

`project.godot` usa:

```
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```

Com `expand`, a escala é `min(w/1280, h/720)` e o viewport LÓGICO é a janela
dividida por essa escala. Consequência medida com capturas reais:

| janela física | viewport lógico | breakpoint |
|---|---|---|
| 1920x1080 (16:9) | 1280x720 | `wide` |
| 720x720 (1:1) | 1280x1280 | `wide` |
| 405x720 (9:16) | 1280x2276 | `wide` |
| 2560x1080 (21:9) | ~1706x720 | `ultra` |

**A largura lógica nunca fica abaixo de 1280.** Só a altura varia. Então
`compact` e `medium` de `Design.breakpoint_for()` são inalcançáveis no build
atual, e todo o código de layout estreito — neste porte, na pausa e no resumo de
run — só roda nas asserções do harness, que setam `panel.size` à mão.

Isto corrige, de novo, a afirmação da auditoria. Eu havia escrito que "o jogo
sempre renderiza 1280x720 lógico e escala". É verdade só para 16:9. O enunciado
correto é: **a largura lógica é sempre ≥1280; o que varia é a altura.**

### O que isso significa para o celular

Em retrato 9:16 o jogo monta um palco de 1280x2276 e desenha tudo em 405px de
largura física: texto de 11px vira ~3px. Não é um problema de breakpoint — é
configuração de projeto. O caminho é mudar a base (`viewport_width` menor, ou
`aspect="keep_height"` com base retrato) quando a fase de celular começar, e aí
os breakpoints que já existem passam a valer. Não mexi nisso agora porque a
autora definiu desktop primeiro.

O código estreito fica: ele não custa nada hoje e é o que torna a virada de
celular uma mudança de configuração em vez de um segundo porte.

## Dívida de teste reduzida

Convertidas de texto-fonte para comportamento (R6): 24 → 18.

- `_story_path_test` procurava `_draw_node_brackets`, `_draw_state_glyph` e
  `sin(t` dentro do arquivo. Passavam mesmo se as funções nunca fossem chamadas.
  Agora afirmam: os três estados têm rótulos distintos, tintas distintas, e o
  pulso do marcador não avança a rng de gameplay.
- Duas asserções procuravam `GlyphLib.draw_` no código de `bestiary_panel` e
  `program_panel`. Quebravam ao mover o desenho para `ScreenKit.glyph()` sem
  nenhuma regressão. Agora afirmam que cada silhueta listada por `glyph_kinds()`
  é um tipo que a biblioteca sabe desenhar, e que desenhá-la não toca a rng.

## Strings extraídas

+79 chaves no CSV (programa, fases, rodapés). Inclui título, subtítulo, papéis,
resumos e valores de estatística dos três programas, e título/intro das onze
fases. Os valores perderam o substantivo repetido no caminho — `100% MOVE` virou
`100%`, `MEDIUM RANGE` virou `MEDIUM` — porque o rótulo da linha já diz o eixo, e
era essa repetição que não cabia em card de duas colunas.

O `klog` continua em inglês de propósito: é saída de máquina, voz diegética.

## Falta

- `patch_card` e `bestiary` — as duas últimas da lista de quatro.
- `menu_chrome_kit.gd` (479 linhas construídas e escondidas).
- HUD e arena — ver a seção abaixo.

## HUD e arena (levantado pela autora, ainda não feito)

Capturei `KP_SHOT=game KP_WAVE=7` para olhar. O que está lá:

- Moldura de canto cortado em volta de **cada** módulo (INTEGRITY, CYCLE, SCORE,
  EVENT LOG, DASH READY, PATCH STACK), em um âmbar que não existe em nenhum papel
  do design system.
- **Dois avisos sobrepostos e ilegíveis** no centro. Não é acaso:
  `arena.gd:906` chama `Fx.text(player.global_position + Vector2(0, -46), ...)`
  e `Fx.text` só adiciona `randf_range(-8, 8)` de jitter. Quando duas entidades
  novas são registradas no mesmo instante — que é o normal quando uma onda
  introduz vários tipos — as duas strings caem quase no mesmo pixel. Bug real,
  com causa localizada.
- Grade dupla (âmbar + ciano) sobreposta, e blocos vermelhos translúcidos que
  dominam o campo e competem com as entidades.

A direção editorial **não** se aplica ao HUD como se aplica aos menus: HUD é
leitura periférica, precisa ser lido sem foco central, e tipografia grande de
revista atrapalha isso. Mas três das quatro coisas acima não são sobre
tipografia: a paleta órfã, a moldura por módulo e a colisão de avisos são
problemas independentes da direção, e o ruído da arena também.

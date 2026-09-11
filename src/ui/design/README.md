# Design system do KERNEL PANIC

Fundação de UI no estilo frontend: tokens semânticos, escala de tipo e
espaçamento, componentes com estados, e layout por containers.

## Arquivos

| arquivo | papel |
|---|---|
| `design.gd` | Tokens. Fonte única de cor, tipo, espaço, borda, movimento, breakpoint. |
| `tactical_style_box.gd` | O frame táctico como `StyleBox` de verdade — assignável por tema. |
| `ui_theme.gd` | Constrói o `Theme` a partir dos tokens. |
| `showcase.gd/.tscn` | Style guide vivo. Renderiza tudo numa página para inspeção. |

## Ver o style guide

```sh
tools/virtual-session/kp-virtual.sh showcase /tmp/showcase.png
```

## Usar

```gdscript
# uma vez, na raiz:
get_tree().root.theme = UiTheme.build()

# depois, qualquer widget nasce certo:
var title := Label.new()
title.theme_type_variation = "HeadingLabel"

var go := Button.new()
go.theme_type_variation = "PrimaryButton"   # já vem com hover/pressed/focus/disabled
```

## Regra

**Nenhum arquivo de UI deve conter número mágico** de tamanho de fonte, cor,
espaçamento ou duração. Se falta um token, adicione em `design.gd`.

Antes desta fundação o projeto tinha, medido:

| | antes |
|---|---|
| tamanhos de fonte distintos | **17** (11 deles consecutivos entre 10 e 20px) |
| níveis de opacidade de texto | **21** (nove entre 0.5 e 0.72) |
| espaçamentos avulsos | **10** (4,5,6,7,8 consecutivos) |
| `add_theme_*_override` | **310** |
| `load()` de fonte | **83**, em 19 arquivos |
| `Theme` / `StyleBox` reais | **10** referências no projeto inteiro |
| estados de botão | **nenhum** — sem hover, sem foco, sem disabled |
| paletas concorrentes | **2** — `Balance.COL_PLAYER` #4ff2ff vs `TacticalUI.CYAN` #28e7ff |

## Escala de tipo

Consolidada a partir do uso real, não inventada: 42 e 44 eram o mesmo papel
(título de painel), 28 e 30 também (título de tela).

| token | px | papel |
|---|---|---|
| `TEXT_DISPLAY` | 76 | só o título do menu |
| `TEXT_TITLE` | 44 | título de painel de estado (PAUSED) |
| `TEXT_HEADING` | 32 | título de tela (SETTINGS //) |
| `TEXT_SUBHEAD` | 18 | rótulo de botão, cabeçalho de lista |
| `TEXT_BODY` | 15 | corpo padrão |
| `TEXT_CAPTION` | 13 | rótulo de campo, dica |
| `TEXT_MICRO` | 11 | selo, unidade, rodapé |

## Níveis de texto

Cinco, não vinte e um. `TEXT_PRIMARY`, `TEXT_SECONDARY` (.72), `TEXT_MUTED`
(.55), `TEXT_FAINT` (.35), `TEXT_GHOST` (.15).

## Botões — três níveis de ênfase

`PrimaryButton` domina por tamanho de tipo (32), traço (2px) e preenchimento
(.18). `Button` base é o padrão. `GhostButton` é rebaixado por acento esmaecido
e tipo menor. Variar só o alpha de preenchimento **não** funciona: some no
fundo escuro.

`DangerButton` troca o acento por vermelho — é papel semântico, não nível.

## Painéis

- `TacticalPanel` — frame táctico com preenchimento leve.
- `OverlayPanel` — **opaco por contrato**. Quatro painéis do jogo usavam alphas
  diferentes e o de conquistas (0.88) deixava o menu vazar por trás.
- `ScrimPanel` — véu translúcido sobre a cena de jogo. Aqui a transparência é
  intencional: mantém contexto do que acontece atrás (pausa, escolha de patch).

## Estado da migração

A fundação está pronta e **nenhuma tela usa ela ainda** — o Theme é puramente
aditivo até aqui, e o autotest segue em 1418 PASS / 0 FAIL.

A migração das telas é a próxima fase. Ordem sugerida, da menos para a mais
arriscada: `achievements_panel` → `program_panel` → `story_panel` →
`bestiary_panel` → `menu_settings_kit` → `menu` → `panel_kit` → `hud`.

**Atenção antes de migrar:** 55 asserções do autotest são `grep` no texto-fonte
(`hud_src.contains("_banner_sub_l.offset_top = 186")`). Elas quebram ao
refatorar mesmo sem regressão de comportamento. Ver R6 em
`docs/superpowers/reports/2026-09-11-auditoria-desktop.md`.

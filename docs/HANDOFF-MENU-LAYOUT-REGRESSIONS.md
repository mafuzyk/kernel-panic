# Handoff — Lote R11/R12/T03: regressões do menu e probe de layout

Data: 2026-08-31. Executor: OpenCode/GLM-5.3 (orchestrator) com implementação
delegada ao fixer (probe + correções); investigação, validação e git pelo
orchestrator. Origem: `docs/REVISAO-CONSOLIDADA-2026-08-31.md` itens R11,
R12, T03.

## Branch e commits

Branch: `codex/menu-layout-regressions`, criada a partir da ponta atualizada
de `codex/r05-rootlet-shield` — **hash-base `5ce0bf0`** (inclui `18799c4`/
`6bdff74` do R05 aprovado e o commit documental `5ce0bf0` que registra a
APROVAÇÃO da decisão de economia do overflow — pendência removida do handoff
R05 a pedido do orientador). Sem merge para `main`.

Commits:

- `647edf8` — menu: land in-progress grid-spec redesign as R11/R12 baseline
  (pré-requisito: o redesign local não-commitado de `menu.gd` +
  `menu_chrome_kit.gd` é o código ao qual as regressões R11/R12 se aplicam;
  aterrisado verbatim para que as correções sejam revisáveis por cima —
  **destacar na revisão**). `tactical_icon.gd` permanece sem commit (fora do
  escopo).
- `2f69c46` — test: layout probe — same-space live checks, per-group
  failures, 4-viewport matrix (T03)
- `8441c53` — fix: reset header label anchors in apply_menu_layout (R11)
- `5751f33` — fix: restore the six-frame registry with footer frames (R12)
- docs: handoff for R11/R12/T03 (este commit, ponta da branch)

Alterações locais preservadas fora dos commits: `src/ui/tactical_icon.gd`,
`opencode.jsonc`, `AGENTS.md`, docs pré-existentes, `.opencode/`, imports
órfãos em `media/captures/xvfb/`.

## Causa compartilhada (investigada antes de corrigir)

O redesign local "menu grid spec" dividiu responsabilidades:
`menu_layout_for_viewport()` calcula os rects do spec, `apply_menu_layout()`
aplica em nós reais, `_build_button_row()` constrói nós sem geometria. As
três regressões são falhas dessa migração:

- **R11** — os labels de cabeçalho continuaram com `anchor_right=1.0` da era
  fullscreen; o kit aplica offsets absolutos sem resetar anchors → borda
  direita = `parent_size.x + offset_right` (soma dupla). Medido: largura real
  = spec + viewport.x (2508 vs 1228 em 1280; 3148 vs 1548 em 1600) em
  `_subtitle`, `_controls_line`, `_best_label`, `_prompt`.
- **R12** — `_build_button_row()` criou só os 3 frames dos botões centrais;
  os slots do rodapé (`lay["frames"][3..5]`, SETTINGS/BESTIARY/AWARDS)
  ficaram sem nós (`_menu_frames.size()==3` vs 6 do spec).
- **T03** — o probe existente misturava espaços de coordenadas (filhos do
  HBox medidos em espaço local contra rects do spec em espaço do menu) e
  agregava tudo numa única falha ("122 passes, 1 fail"), sem cobrir os
  labels do R11.

## Correções (mínimas)

- **R11** (`8441c53`): reset dos 4 anchors antes dos offsets nos quatro
  blocos de label em `apply_menu_layout()`. `_version_tag` intocado (compensação
  de anchor 1.0 já bate o spec); `_klog`/`_mode_info` intocados (posição
  correta; tamanho min-clamped pelo texto — ver descobertas).
- **R12** (`5751f33`): 3 `_add_menu_frame(Rect2(), ...)` após cada botão do
  rodapé, na ordem [purge, story, mode, settings, best, awards], com os
  acentos do design original (COL_TEXT 0.015 / COL_SPEWER 0.02 / LIME 0.02).
  O loop existente de `apply_menu_layout()` posiciona os 6; nenhum nó é
  recriado em resize.
- **T03** (`2f69c46`): probe reescrito na seção live — filhos medidos em
  espaço do MENU contra `frames[3..5]`, checks separados por grupo
  (buttons/ids/row/slots/frames/labels/meta/overflow), matriz live de 4
  viewports lógicos (1024, 1280, 1600, 432 — abaixo e acima de 1280),
  checagens de `text_overflow_report()` por viewport.

## Evidência red → green (logs em `.godot/codex-review-menu/`)

| Log | Resultado |
|---|---|
| `baseline-probe.log` (estado T03, probe original) | exit 1 — 122 passes, 1 fail agregado |
| `red-r11r12.log` (probe novo, antes dos fixes) | exit 1 — 128 passes, **2 fails: labels (R11) + frames (R12)** |
| `after-r11.log` (após fix R11) | exit 1 — 129 passes, 1 fail (só frames) |
| `green-r11r12.log` (após fix R12) | **exit 0 — 130 passes, 0 falhas** |

Geometria comparada por viewport (números no log e no diagnóstico): labels
com posição/altura exatas em 1024/1280/1600; em 432 o RichTextLabel
min-clampa a altura (28 vs 26) — o critério do probe aceita
`max(spec, min-size do texto)`, que reprova o double-add do R11 (spec +
viewport) e aprova o crescimento honesto por texto.

## Validação completa (XDG_DATA_HOME isolado)

`KP_VALIDATION_LOGS=.godot/codex-review-menu/val tools/validate_input_dispatch.sh`
→ exit 0, `VALIDATION OK`; probes R04 e R05 re-executados → exit 0,
`fails=0` (`r04-probe.log`, `r05-probe.log`):

| Caso | exit | passes | fails | ERROR baseline |
|---|---|---|---|---|
| Suíte headless `--autotest` | 0 | 1418 AT_PASS | 0 | 7 |
| Probe input headless | 0 | 32 | 0 | 9 |
| Probe input Xvfb (debug ativo) | 0 | 34 | 0 | 23 |
| Probe R04 (órfãos) | 0 | — | 0 | — |
| Probe R05 (escudo ROOTLET) | 0 | 28 | 0 | — |
| Layout probe (R11/R12/T03) | 0 | 130 | 0 | — |

## Comportamento testado × apenas inspecionado

**Testado (probe, evidência em log):** rects reais dos labels de cabeçalho
vs spec em 4 viewports (posição exata; tamanho = max(spec, min-size));
contagem e rects dos 6 frames (exatos); botões centrais e filhos do rodapé
em espaço do menu contra os slots do spec (tolerância 1.5px em larguras
largas; piso de tamanho e borda esquerda do primeiro slot nas compactas);
estabilidade de instância através de resizes (zero rebuilds);
`text_overflow_report()` sem overflow em todos os viewports.

**Apenas inspecionado (diff/diagnóstico, não verificado por captura de
pixels):** o desenho visual dos frames (`TacticalChrome._draw` — padrão
mantido, nenhum `_draw` alterado), a aparência final renderizada (sem
screenshots neste lote — comparação numericamente por retângulos), áudio e
interações do menu.

## Descobertas fora do escopo (registradas, sem correção)

- `_klog` largura min-clamped pelo texto (446 vs spec 340 em 1280) — sem
  sobreposição com o version stamp (termina em 462 < 764).
- `_mode_info` altura min-clamped (677 vs spec 32) — anotação oculta, TOR
  segue passando.
- Linha do rodapé min-clamped pelo conteúdo (637/679/529 vs spec 418/448/334
  — a spec `button_row` é a âncora de registro 448/217/14; o transbordo
  centrado é comportamento do HEAD).
- Em 432 lógico, o texto dos botões excede `button_width` (133) e o rodapé
  transborda o viewport — **comportamento pré-existente do HEAD** (mesma
  fórmula de registro); o probe declara apenas contagem/piso/borda esquerda
  nesse caso.
- Erros de runtime baseline (T02) inalterados: 7/9/23 por ambiente
  (`show_event_banner` R10, lambda, RIDs no exit).

## Limitações

- Comparação de geometria numericamente por retângulos (probe), sem captura
  de pixels/screenshots neste lote.
- O probe de layout não está engatilhado no `--autotest` (comando manual:
  `godot --headless --path . res://tools/layout_probe.tscn`).
- A matriz live usa tamanhos lógicos diretos (regra de stretch
  canvas_items/expand coberta pelas checagens de spec em WINDOWS 432–1366
  físicos).

## Próximos passos (fora deste lote, não iniciados)

1. R06/R07/R08 — boss GOD, hold R preservando modo, isolamento de saque OOM.
2. R10/T04 e T02 (ERRORs gatearem a validação).
3. Decisões de UX pendentes com o usuário (R13/R14, B5/R16, R15/B6, B7,
   H1–H7) e direção visual híbrida já registrada.

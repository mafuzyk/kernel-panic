# UI Review Backlog — fases

> Atualização de 2026-08-31: consulte a
> [revisão consolidada](REVISAO-CONSOLIDADA-2026-08-31.md) antes de implementar.
> Ela registra reproduções, critérios de aceite e erratas deste veredito
> original — especialmente B1, H3 e o suposto leak de lambda em P2.
> Os itens abaixo preservam o histórico; não são todos bugs confirmados.

Estado versionado em `fuzzy/ui-reference-remake`: B1/B2/B3/B4/B5/B6/B7 foram
resolvidos e preservam seus handoffs. O vertical slice visual vNext já cobre
Boot, Program, Story, Bestiary e Accessibility, mas a migração completa dos
fluxos e os itens abaixo continuam pendentes ou precisam ser reavaliados contra
a UI vNext. A Story foi migrada para a gramática `incident console` em um passe
separado; isso não fecha o restante de U2 nem constitui aprovação estética
final. Um item de backlog = um commit; rodar
`godot --headless -- --autotest` antes de cada commit.

## Fase 1 — bugs de fluxo (comportamento errado)

- [x] **B1 — ENTER vaza pelos overlays do menu.** `src/ui/menu.gd:714-733`: os
  branches de program/story/bestiary/awards só tratam `pause` e caem para o
  `confirm` do final (`menu.gd:744-745`), iniciando uma run Classic com o
  painel aberto. Tratar `confirm` como "fechar painel" (ou engolir) quando
  qualquer overlay estiver visível, igual ao branch de settings
  (`menu.gd:701-713`).
- [x] **B2 — Botões de rodapé falsos.** "MOUNT [ENTER]" (`story_panel.gd:351`)
  e ">> BOOT KERNEL [ENTER]" (`program_panel.gd:216-217`) são texto desenhado
  em `_draw()`, não clicáveis. Virar Botões reais ou remover.
- [x] **B3 — Debug input swallow.** `src/arena/arena.gd:915-916`:
  `set_input_as_handled()` incondicional engole ESC/ENTER (pause e game-over
  mortos em builds debug). Mover as duas linhas para dentro do case `KEY_F4`.
- [x] **B4 — Patch 1/2/3 inalcançável.** `arena.gd:542` anuncia, `arena.gd:922-931`
  trata, mas o patch pausa a árvore (`arena.gd:586`) e a Arena é
  `PROCESS_MODE_INHERIT`. Mover o handler para um nó `PROCESS_MODE_ALWAYS`
  (mesmo padrão do PauseInputRouter) ou setar process_mode da Arena.
- [x] **B5 — Terminal anuncia ↑↓/TAB.** `terminal_panel.gd:226` promete history
  e autocomplete que não existem. Implementar history (↑↓) + TAB autocomplete
  sobre os comandos do index, ou trocar o texto.
- [x] **B6 — Prompt do menu morto.** `menu.gd:199` + `menu.gd:636`:
  `_prompt` nunca fica visível. Mostrar o prompt "PRESS [ENTER] OR HIT >> PURGE"
  (piscar discreto) ou remover o label.
- [x] **B7 — Confirmações destrutivas.** Double-click em ABANDON encerra a run
  (`panel_kit.gd:55-58`, `arena.gd:1051-1055`); R no pause reinicia sem
  confirmar (`arena.gd:941-944`). Unificar: mesma janela/estado armado do
  reset high score, e ignorar cliques <0.5s como double-click acidental.

## Fase 2 — hierarquia e legibilidade do HUD

- [x] **H1 — Banner duplicado.** "CYCLE NN" aparece no encounter panel do HUD e
  de novo no banner grande (`arena.gd:448/451`). Colapsar: banner grande só
  para eventos (wave start/boss/story), encounter panel para o estado contínuo.
  O HUD legado agora anuncia `WAVE INBOUND`/`ANOMALY INBOUND`, mantendo
  `CYCLE NN` como registro contínuo; o adaptador vNext só comprime a forma
  antiga que era exatamente um banner `CYCLE ...`.
- [ ] **H2 — Contraste do event log/dicas.** Alpha 0.3–0.5 em fontes 9–12px
  (`hud.gd:521-523`, tooltip `hud.gd:630-632`). Subir para >=0.7 e usar
  `TacticalUI.ellipsis_fit` (já existe, `tactical_ui.gd:128-134`).
- [ ] **H3 — Escala HUD vs painéis.** HUD em window px (`hud.gd:129-139`),
  painéis em design px — hierarquia inverte em 1080p+. Assumir design px no
  HUD também (deixar o stretch trabalhar).
- [ ] **H4 — Sinalização de estado.** HP baixo/dash/overclock dependem de cor ou
  alpha (`hud.gd:534-535`, `hud.gd:650-658`, `hud.gd:550-553`). Adicionar
  texto/glyph + considerar indicador direcional de dano.
- [ ] **H5 — Colisões de layout.** Toast x encounter (`hud.gd:188-193`); SCRAP
  bar/texto (`hud.gd:567-574`); pips HP > 10 (`hud.gd:528-530`); stats game-over
  <800px (`panel_kit.gd:284-290`); pause touch x banner (`touch_controls.gd:109-111`).
- [ ] **H6 — Camadas.** Vinheta de low-HP (layer 80, `arena_overlay.gd:10`) sobre
  game-over/pause (layer 60); watermark sobre painéis. Reordenar layers ou
  atenuar quando painel de estado ativo.
- [ ] **H7 — Widgets mortos.** `_score_label`/`_best_label` (`hud.gd:60-67`),
  `_over_stats` (`panel_kit.gd:182-184`), "SWIPE TO SCROLL" em desktop
  (bestiary/story/program), banner alpha com dead-zone (`hud.gd:352-357`).

## Fase 3 — navegação e consistência

- [ ] **N1 — Foco de teclado no pause/game-over/terminal.** Definir stylebox de
  foco em `panel_kit.gd:228-273`, `grab_focus` no primeiro botão ao abrir,
  navegação ↑↓, ENTER confirma, ESC volta.
- [ ] **N2 — BACK no mesmo canto.** Bestiary/awards reancoram o back para
  baixo-esquerda (`menu.gd:419-427`); program/story usam topo-direita
  (`menu_chrome_kit.gd:484-491`). Padronizar.
- [ ] **N3 — Bestiary abre desincronizado.** Seleção default "root"
  (`bestiary_panel.gd:34`) fora da viewport da lista. Scroll-into-view no open
  e na seleção.
- [ ] **N4 — Fullscreen toggle** nas settings (desktop) — ausente em
  `menu_settings_kit.gd`.
- [ ] **N5 — Autocomplete/history do terminal** (se B5 for "implementar").

## Fase 4 — performance e robustez

- [ ] **P1 — Cache de layout.** `layout_snapshot()` ~10x/frame
  (`hud.gd:386-403...`), `_refresh_responsive_layout()` todo frame com pause
  invisível (`arena.gd:1082` → `panel_kit.gd:79-99`), chip rects todo frame
  (`hud.gd:577-595`). Cache no resize.
- [ ] **P2 — Lambda leak.** `Game.patch_picked.connect(func...)`
  (`hud.gd:119-121`) — trocar por método bound.
- [ ] **P3 — Tweens sobrepostos.** Tip label (`arena.gd:506-520`), boss intro
  (`intro_kit.gd:154-173`). Matar tween anterior antes de criar novo.
- [ ] **P4 — Boss bar fantasma.** "MINI-B" 0% com 1 fragmento (`hud.gd:681-701`),
  nome hardcoded (`hud.gd:323`).

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
- [x] **H2 — Contraste do event log/dicas.** Alpha 0.3–0.5 em fontes 9–12px
  (`hud.gd:521-523`, tooltip `hud.gd:630-632`). Subir para >=0.7 e usar
  `TacticalUI.ellipsis_fit` (já existe, `tactical_ui.gd:128-134`). O event
  log agora usa alpha 0.82, as linhas e o tooltip são truncados pela largura
  medida do painel, e o tooltip expõe as três linhas já ajustadas.
- [x] **H3 — Escala HUD vs painéis.** HUD em window px (`hud.gd:129-139`),
  painéis em design px — hierarquia inverte em 1080p+. A matriz real não
  reproduziu distorção: o HUD compensa o `canvas_items` stretch de forma
  uniforme e seu tamanho efetivo coincide com o viewport lógico em wide,
  ultrawide e portrait. Não foi aplicado um “fix” de escala sem evidência.
- [x] **H4 — Sinalização de estado.** HP baixo/dash/overclock dependiam de cor
  ou alpha (`hud.gd`). O HUD legado agora expõe estados textuais de integridade,
  escudo/overclock e dash, além de `HIT FROM <direção>` após dano; Rootlet usa
  o mesmo canal sem depender de cor para comunicar `SHIELD READY`.
- [x] **H5 — Colisões de layout.** O toast agora reserva o espaço do banner e
  respeita a largura segura; SCRAP usa uma largura medida e texto truncável;
  pips de integridade densos cabem no painel; game-over estreito empilha stats
  e ações; e o alvo de pausa touch foi medido contra o banner sem colisão.
- [x] **H6 — Camadas.** Vinheta de low-HP (layer 80, `arena_overlay.gd:10`) sobre
  game-over/pause (layer 60); watermark sobre painéis. A Arena agora marca
  explicitamente estados modais e oculta o retângulo de efeitos de tela e o
  watermark enquanto pausa, terminal, patch, game-over ou vitória estão ativos.
- [x] **H7 — Widgets mortos.** `_score_label`/`_best_label` e o build label
  oculto foram removidos do HUD; `_over_stats` também não é mais criado. A
  dica `SWIPE TO SCROLL` só aparece com entrada touch, e o fade do banner não
  tem mais a dead-zone para durações acima de dois segundos.

## Fase 3 — navegação e consistência

- [x] **N1 — Foco de teclado no pause/game-over/terminal.** Os painéis legados
  agora definem stylebox de foco, focam a primeira ação ao abrir, encadeiam
  navegação vertical e devolvem o foco ao ponto correto quando o terminal
  fecha. Enter e ESC continuam donos das ações/retorno.
- [x] **N2 — BACK no mesmo canto.** Program, Story, Bestiary e Awards agora
  usam o mesmo slot de rodapé inferior esquerdo, definido uma única vez em
  `menu_chrome_kit.gd::_style_overlay_back()`. A geometria é ancorada ao
  viewport e foi verificada em headless e Xvfb.
- [x] **N3 — Bestiary abre desincronizado.** A seleção default `root` e toda
  seleção posterior agora são levadas para a viewport da lista; o contrato é
  reaplicado quando a superfície muda de tamanho.
- [x] **N4 — Fullscreen toggle** nas settings (desktop). A seção DISPLAY já
	possui fullscreen e target FPS persistidos; o fullscreen é explicitamente
	desktop-only e some em touchscreen/mobile, enquanto o target FPS continua
	disponível para os dois ambientes.
- [x] **N5 — Autocomplete/history do terminal.** B5 implementou ↑↓, TAB e
  comando real; N1 completou a navegação entre prompt e ações do terminal.

## Fase 4 — performance e robustez

- [x] **P1 — Cache de layout.** O HUD agora cacheia o layout por viewport,
	touch e escala; o geometry cache dos chips invalida por viewport, touch,
	escala e estado dos patches; a Arena só relayouta painéis quando o viewport
	ou a altura solicitada mudam, em vez de reaplicar a geometria todo frame.
- [x] **P2 — Lambda leak.** A conexão do HUD com `Game.patch_picked` já era
  bound e foi removida junto com o widget morto que ela alimentava; a Arena
  continua sendo a autoridade que aplica patches.
- [x] **P3 — Tweens sobrepostos.** Tip label e boss intro agora cancelam o
  timeline anterior antes de escrever novamente nos mesmos nós; o fechamento
  da intro também usa um callback nomeado, sem criar uma cadeia órfã ao
  reacionar a apresentação.
- [x] **P4 — Boss bar fantasma.** O HUD agora deriva o título do fork do boss
  real, lista somente fragmentos vivos e compacta as linhas desenhadas; um
  único fragmento não cria mais uma segunda barra em 0%.

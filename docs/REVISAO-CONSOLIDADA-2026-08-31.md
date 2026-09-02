# Revisão consolidada — KERNEL PANIC

Data: 2026-08-31. Base: `f90ca87`, incluindo as alterações locais não
commitadas em `menu.gd`, `menu_chrome_kit.gd` e `tactical_icon.gd`.

Este documento consolida a revisão de código, o confronto com o veredito de
UI e as verificações executadas nesta conversa. Não representa correções
implementadas nem aprovação para release. Os números de linha correspondem
ao estado revisado e podem mudar.

## Escopo, evidência e prioridade

- **Reproduzido:** observado em execução na rodada de revisão, com o método
  indicado no item. Não significa teste em aparelho físico ou build exportada.
- **Estático:** causa e caminho identificados no código; cenário não executado
  integralmente nessa rodada.
- **Pendente:** hipótese ou avaliação visual que precisa de medição/reprodução.
- **P1:** corrigir antes de release; compromete um fluxo central ou acumula
  recursos em uso normal. **P2:** defeito funcional/localizado. **P3:** caso
  limítrofe ou melhoria de menor impacto. Prioridade não mede certeza.

A revisão preservou as mudanças locais e isolou os saves dos testes com
`XDG_DATA_HOME`. Não houve alteração no código de produção. A documentação
foi escrita posteriormente, a pedido do usuário.

## 1. Input, pausa e patches

### R01 — P1 — Q/R na pausa não chegam à Arena

**Reproduzido em headless e desktop via Xvfb.** Com a pausa aberta, Q não
arma abandono e R não reinicia. Os eventos foram enviados por
`Viewport.push_input()`, não por chamada direta ao handler.

**Causa:** a árvore está pausada e a Arena herda o modo de processamento;
seu `_unhandled_input` não recebe os eventos. O `PauseInputRouter` funciona
durante a pausa, mas encaminha apenas o tratamento de ESC.

**Referências:** `src/arena/arena.gd:942–954`,
`src/arena/pause_input_router.gd`, `src/arena/panel_kit.gd:316`.

**Aceite:** pausar pelo fluxo normal; Q arma, segundo Q abandona e R reinicia
preservando o modo. Testar com eventos pelo viewport, inclusive echo,
expiração da confirmação e foco em um botão. Manter gameplay congelado.

### R02 — P1 — Teclas 1/2/3 não selecionam patches

**Reproduzido em headless e desktop via Xvfb.** Abrir uma oferta e enviar 1
mantém `_patch_open == true` e a árvore pausada.

**Causa:** `_try_show_patch()` pausa a árvore; o handler dos números continua
na Arena, que não processa durante a pausa. Compartilha a causa estrutural
de R01. Não foi constatado que os cards deixem de funcionar por clique.

**Referências:** `src/arena/arena.gd:574–600,923–933`.

**Aceite:** cada número escolhe o card correspondente, aplica um único patch
e retoma o jogo, respeitando eventuais ofertas pendentes.

### R03 — P1 — Bloco de debug engole ESC e outras teclas

**Reproduzido em desktop debug via Xvfb.** ESC não abriu a pausa; no headless,
onde os controles de debug estavam desativados, abriu normalmente.

**Causa:** depois do `match` de F1–F4 há `set_input_as_handled()` e `return`
incondicionais para qualquer key press. ESC/ENTER não chegam aos handlers
posteriores. O efeito em ENTER no game-over é uma conclusão estática;
a reprodução dedicada verificou a abertura da pausa com ESC.

**Referências:** `src/arena/arena.gd:242,897–916`.

**Errata:** a avaliação anterior de que chamar `handle_pause_input()` antes
do debug resolveria o problema estava errada. Esse helper exige uma árvore
já pausada: resolve fechar a pausa, não abri-la.

**Aceite:** em desktop debug, F1–F4 mantêm suas funções; ESC abre e fecha
pausa; ENTER/ESC funcionam no game-over. Não validar só em headless.

## 2. Gameplay, recursos e progressão

### R04 — P1 — Um PlayerBullet órfão por ciclo de disparo

**Reproduzido:** 10 chamadas a `_shoot()` aumentaram em 10 o contador
`Performance.OBJECT_ORPHAN_NODE_COUNT`.

**Causa:** `var b := PlayerBullet.new()` cria um Node não utilizado; o loop
cria outros projéteis e adiciona apenas esses à árvore. Perder a referência
local não libera um Node. O acúmulo acompanha os disparos, não só a saída.

**Referência:** `src/player/player.gd:279`.

**Aceite:** disparos repetidos, inclusive splitshot e reinícios, não aumentam
o número de órfãos por esse caminho. Distinguir projéteis vivos de vazamentos.

### R05 — P2 — ROOTLET não recarrega o escudo depois de perdê-lo

**Reproduzido:** após consumir a proteção e coletar 100 motes, o resultado
foi `shield_ready=false`, `shield_meter=0`, `oc_ready=true`.

**Causa:** o impacto desativa `shield_ready`; tanto `collect_mote()` quanto
`add_kill_mote_bonus()` exigem que ela já esteja ativa para carregar escudo.
As motes passam a carregar overclock, mas `try_overclock()` o bloqueia para
o programa com `shield_mode`.

**Referências:** `src/player/player.gd:339,360–369,414–418,451–453`.

**Aceite:** consumir escudo, recarregá-lo por motes e bônus de kill, consumir
de novo. O programa não deve entrar num estado de overclock inutilizável.

### R06 — P2 — TempleOS termina com ROOT em vez de GOD

**Estático.** `temple_god` define `boss_kind: "god"` e a wave final com
`"god"`, mas `_spawn_story_boss()` instancia sempre `RootBoss`. A conclusão
da fase e a recompensa dependem do ID da fase, permitindo o desbloqueio
sem enfrentar o boss previsto.

**Referências:** `src/story/story_data.gd:125`,
`src/arena/spawner.gd:229–244`, `src/autoload/game.gd:725`.

**Aceite:** jogar ou simular a progressão real até a wave final de
`temple_god`; conferir classe, comportamento, HUD e recompensa. Testar apenas
`_make_enemy("god")` não cobre esse caminho.

### R07 — P2 — Hold R troca Story por Classic

**Estático.** Segurar R durante gameplay até o limiar de 0,75 s chama
`Game.start_run()`, que converte explicitamente Story em Classic.
O helper `_restart_current_run()` preserva Story, mas não é usado aqui.

**Referências:** `src/arena/arena.gd:724,1107–1113`,
`src/autoload/game.gd:417`.

**Aceite:** hold R reinicia a mesma fase Story; comparar também os reinícios
por pausa e game-over. Não generalizar o bug para todos os reinícios.

### R08 — P2 — OOM manipula motes roubadas por outros OOM

**Estático.** Há waves com dois OOM. Se ambos roubam motes, a fuga de um
chama `free_all_stolen()` e a morte chama `release_all_stolen()`: ambas
percorrem todas as motes roubadas, sem filtrar o dono. O sobrevivente ainda
conserva seus IDs. `stolen_positions_of(ids)` também ignora o argumento.

**Referências:** `src/story/story_data.gd:43`,
`src/enemies/oom_killer.gd:99–114`, `src/pickups/mote_field.gd:174–191`.

**Aceite:** dois OOM com conjuntos distintos de motes; matar ou deixar fugir
um deve afetar apenas seu conjunto, mantendo os UIDs do outro coerentes.

### R09 — P3 — Mote no centro do jogador pode não ser coletada

**Estático; caso limítrofe.** O teste de coleta está dentro de `d > 1.0`.
Uma mote criada a até 1 px de um jogador parado, com velocidade zero, não
entra na coleta nem na atração. Pode permanecer até movimento ou expiração.

**Referência:** `src/pickups/mote_field.gd:227–239`.

**Aceite:** criar motes a 0, 0,5, 1 e 2 px do jogador parado e verificar coleta,
inclusive pelo fluxo `collect_all()`.

### R10 — P2 — Banner de evento chama método inexistente

**Erro observado na suíte.** `hud_banner()` agenda
`Arena.show_event_banner`, mas a implementação está no `IntroKit`, sem o
delegate correspondente na Arena. O aviso não é exibido por esse caminho.

**Referências:** `src/arena/spawner.gd:157–159`, `src/arena/intro_kit.gd:176`.

**Aceite:** disparar surge/rich/swarm pelo fluxo de eventos, observar o banner
e não registrar erro de método inexistente.

## 3. Menu, painéis e touch

### R11 — P1 — Regressão local: labels centralizados na borda direita

**Reproduzido no desktop em 1280×720.** O subtítulo ocupou x=26 até x=2534
(largura 2508), centralizando o texto em x=1280, não x=640.

**Causa:** o novo layout aplica coordenadas absolutas em `offset_right`, mas
subtitle, controls, best e prompt mantêm `anchor_right=1`. O tamanho do pai
é somado outra vez. Não é um problema exclusivo de janela estreita.

**Referência:** `src/ui/menu_chrome_kit.gd:292–330`.

**Aceite:** comparar retângulos reais dos labels com os retângulos da spec
após resize, e verificar texto visível. Levar em conta o canvas lógico
1280×720 com `canvas_items/expand`, não apenas pixels da janela.

### R12 — P2 — Regressão local: contornos do rodapé não são criados

**Reproduzido:** `_menu_frames.size()` retornou 3, quando o layout prevê 6.
As chamadas que criavam os frames de SETTINGS/BESTIARY/AWARDS foram removidas;
`apply_menu_layout()` só reposiciona os existentes. As ações continuam
clicáveis, mas perderam os limites visuais dos botões transparentes.

**Referência:** `src/ui/menu_chrome_kit.gd:463` e construção de `_menu_frames`.

**Aceite:** seis frames existentes, alinhados aos controles após resize,
sem recriar ou duplicar nós a cada atualização.

### R13 — P2 — ENTER atravessa o seletor de programa; outros overlays não

**Estático, revalidado.** O branch de Program só retorna dentro do ESC;
ENTER pode alcançar `_start()`. Story, Bestiary e Awards têm retorno
incondicional e não apresentam o mesmo vazamento no código atual.
O modo iniciado não é necessariamente Classic: depende do modo selecionado.

**Referência:** `src/ui/menu.gd:719–758`.

**Decisão necessária:** Program desenha um convite a BOOT/ENTER; o boot pode
ser intencional, mas deve ser tratado explicitamente como ação desse painel,
não diagnosticado automaticamente como idêntico aos demais overlays.

**Aceite:** especificar e testar ENTER/ESC em cada overlay separadamente.

### R14 — P2 — Rodapés desenhados anunciam ações sem clique correspondente

**Estático.** MOUNT e BOOT são desenhados, sem botão/hit test correspondente
nesses rodapés. No Story, ENTER é engolido pelo menu, apesar da legenda;
selecionar um card emite `stage_selected` e já inicia a fase. Portanto, não há
um fluxo separado de selecionar, ler os detalhes e confirmar pelo rodapé.

**Referências:** `src/ui/story_panel.gd:34–38,178,350`,
`src/ui/program_panel.gd:216`, `src/ui/menu.gd:341,724`.

**Aceite:** clique, seleção e confirmação devem corresponder ao que a UI
anuncia. No Program, distinguir ENTER disponível de rodapé não clicável.

### R15 — P2 — Prompt invisível esconde confirmação de saída

**Estático.** `_prompt.visible=false` é reaplicado no processamento do menu.
O primeiro ESC muda seu texto para `PRESS ESC AGAIN TO QUIT`, sem torná-lo
visível de forma persistente. O segundo ESC pode sair sem aviso visual.

**Referências:** `src/ui/menu.gd:200,641,745–750`.

**Aceite:** o primeiro ESC mostra aviso durante a janela de confirmação;
expiração, cancelamento e segundo ESC têm comportamento consistente.

### R16 — P2 — Terminal anuncia history/autocomplete inexistentes

**Estático.** A legenda promete ↑↓ HISTORY e TAB AUTOCOMPLETE; não há o
histórico de comandos ou handler de autocomplete correspondente. O
container chamado `history` contém a saída e não implementa esses atalhos.

**Referência:** `src/ui/terminal_panel.gd:210,226`.

**Aceite:** implementar os atalhos anunciados ou corrigir a legenda; verificar
também que TAB não apenas desvia foco contrariando a promessa.

### R17 — P2 — DASH/BOOST invisíveis quando não há mira ativa

**Estático e observado nas capturas anteriores de touch.** `_draw()` retorna
em `not _aim_active` antes de desenhar os botões, embora as áreas de toque
sejam testadas no input. Há ações disponíveis sem indicação visual.

**Referência:** `src/ui/touch_controls.gd:35–40,148,168–188`.

**Aceite:** ações visíveis em idle, com disponibilidade/cooldown legíveis.
ROOTLET tem escudo passivo; não inventar um botão de ativação de escudo.

### R18 — P2 — Toque adicional em DASH/BOOST é ignorado durante a mira

**Estático; identificado ao consolidar.** Os hit tests dos botões estão
dentro do branch que exige `_aim_id == -1`. Mantendo um dedo de mira,
outro dedo pressionando DASH/BOOST não alcança esses handlers.

**Referência:** `src/ui/touch_controls.gd:34–40`.

**Aceite:** testar movimento + mira + ação com multitouch simultâneo em
aparelho ou eventos com índices distintos. Ainda não reproduzido em hardware.

### R19 — P3 — Onboarding touch anuncia teclas de desktop

**Estático e observado nas capturas anteriores.** A Arena enfileira
`MOVE // WASD OR TOUCH` e `DASH // SPACE / SHIFT` sem selecionar as dicas
por dispositivo. No touch, o texto de dash não ensina a ação disponível.

**Referência:** `src/arena/arena.gd:175–176,232–234`.

**Aceite:** dicas adequadas ao input efetivo; verificar legibilidade em
portrait e landscape sem supor que o canvas tem a largura física da janela.

### R20 — P3 — Bestiary abre com detalhe de item fora da lista visível

**Estático.** `_selected_id="root"` com `scroll_y=0`; a seleção inicial
não está entre os primeiros itens visíveis. Detalhe e contexto da lista
ficam desincronizados visualmente.

**Referência:** `src/ui/bestiary_panel.gd:28,34`.

**Aceite:** item selecionado visível ao abrir, ou seleção inicial coerente
com o topo da lista; manter isso ao reabrir e redimensionar.

## 4. Qualidade dos testes e evidência da rodada

### T01 — Testes diretos de handler escondem a falha de dispatch

`src/autoload/harness/sections_tasks_a.gd:46–114` chama
`arena._unhandled_input(...)` diretamente em vários testes de Q/R. Isso
executa o método mesmo quando Godot não entregaria o evento ao nó pausado.
Manter testes unitários é útil, mas precisam de cobertura de integração
via viewport, com foco e pausa reais. O headless também não ativa o branch
de debug desktop, deixando R03 fora dessa cobertura.

### T02 — AUTOTEST_ALL_PASS coexistiu com erros de execução

Comando da rodada anterior: `godot --headless --path . -- --autotest`, com
`XDG_DATA_HOME` apontando para diretório temporário isolado.

Resultado observado: **1418 AT_PASS, zero AT_FAIL, AUTOTEST_ALL_PASS e exit 0**.
O log também continha:

```text
ERROR: Lambda capture at index 0 was freed. Passed "null" instead.
ERROR: Error calling deferred method: 'Node2D(arena.gd)::show_event_banner': Method not found.
ERROR: 9 resources still in use at exit
ERROR: 29 RID allocations of type 'P11GodotArea2D' were leaked at exit.
```

Também houve avisos de recursos gráficos/texto no teardown. Não atribuir
todos eles ao mesmo bug. A captura de lambda liberada apareceu em caminho
do harness (`dev_harness.gd:78`); não prova o suposto leak de lambda do HUD.

**Aceite:** a execução de validação deve falhar ou sinalizar explicitamente
erros de script/método inexistente; separar vazamento durante gameplay de
recursos pendentes no encerramento. Contagem de assertions não basta.

### T03 — layout_probe mistura coordenadas locais e do menu

**Estático; revisor paralelo executou o probe: 122 passes, 1 fail agregado.**
Em `tools/layout_probe.gd:182`, `expected` inclui a posição do rodapé no menu,
mas `kids[i].get_rect()` é relativo ao `HBoxContainer`. Pode reprovar um
filho corretamente posicionado. Além disso, a checagem agregada inclui o
número real de frames, que está errado por R12. Não atribuir o fail inteiro
a resize, nem tratá-lo inteiro como falso positivo.

**Aceite:** comparar retângulos no mesmo espaço e emitir falhas separadas
para frames, labels, container e filhos.

### T04 — Captura de terminal usa API antiga

**Estático.** `src/autoload/harness/sections_modes.gd:290` chama
`arena._open_terminal()`, mas o método está em `src/arena/panel_kit.gd:115`.
Esse caminho de captura precisa ser atualizado e executado; não foi a causa
do erro de banner registrado no autotest.

### Evidência resumida do probe dedicado

O script temporário criou menu e partida, enviou key press/release por
`Viewport.push_input()` e chamou métodos diretamente apenas para preparar
estados e isolar os testes de escudo/disparo. No desktop via Xvfb, registrou:

```text
menu_size=(1280.0, 720.0)
subtitle_rect=[P: (26.0, 218.2), S: (2508.0, 30.0)]
frames=3
debug=true arena_process_mode=0
ESC_opens_pause=false
Q_arms_abandon=false
R_restarted=false still_paused=true
digit_picks_patch=false paused=true
shield_after_100_motes=false shield_meter=0.0 oc_ready=true
orphan_delta_10_shots=10.0
```

No headless, `debug=false` e ESC abriu pausa; Q/R, números, escudo e órfãos
mantiveram os resultados acima. O teste não equivale a jogar a campanha
inteira nem a validar export release, GPU de usuário ou celular físico.

**Retenção:** os logs e o script existiam em `/tmp` durante a revisão, mas
já não estavam disponíveis quando este documento foi escrito. Os resultados
acima são transcritos da saída de ferramentas registrada na conversa, não
de uma nova execução. Reproduzir os critérios de aceite antes de encerrar
os itens; não depender desses caminhos temporários como artefatos duráveis.

## 5. Hipóteses, críticas visuais e erratas do backlog anterior

O arquivo `UI-REVIEW-BACKLOG.md` conserva a crítica original. Seus IDs B/H/N/P
não são a mesma numeração R/T deste relatório. Não executar todo o backlog
como se cada frase já fosse um bug reproduzido.

- **B1:** a afirmação de vazamento em todos os overlays foi descartada;
  ver R13/R14. Também não é sempre uma run Classic.
- **B3/B4:** confirmados, com a errata de ESC descrita em R03. Q/R pausados
  precisam entrar na mesma revisão de dispatch, não apenas os patches.
- **B7:** double-click em abandono e confirmação de restart são decisões
  de segurança de interação ainda a testar. O atalho R pausado está quebrado
  antes disso; distinguir teclado do botão clicável.
- **H1/H2/H4:** duplicação de CYCLE, contraste baixo e dependência de cor
  permanecem críticas de hierarquia/acessibilidade, não falhas funcionais
  universais demonstradas. Validar em capturas de estados reais.
- **H3:** o HUD usa compensação para pixels de janela intencionalmente.
  Não trocar a escala só porque difere dos painéis; medir uma matriz de
  resoluções, stretch e legibilidade primeiro.
- **H5:** colisões entre toast/encounter, SCRAP, muitos pips, game-over e
  pause touch exigem reprodução por estado/resolução. Um snapshot de
  geometria calculada não prova o layout final dos Controls.
- **H6:** overlay de dano/CRT pode prejudicar painéis; a captura com dano
  forte não representa todos os frames. Avaliar camadas e intensidade com
  pausa/game-over abertos antes de alterar a direção visual.
- **H7:** labels de score ocultos não significam score ausente: há desenho
  customizado. Tratar widgets redundantes como manutenção. Legenda SWIPE
  em desktop e dead-zone de alpha precisam de avaliação contextual.
- **N1/N2/N4:** foco/ordem de navegação, posição de BACK e opção de fullscreen
  são melhorias a validar/decidir; não foram todos reproduzidos como bugs.
  N3 é R20. N5 duplica a questão de B5/R16.
- **P1 do backlog:** recomputações de layout são oportunidades de cache,
  não um gargalo de FPS medido por esta revisão.
- **P2 do backlog:** possível retenção pelo lambda de `Game.patch_picked`
  no HUD continua hipótese. Não confundir com o órfão de projétil provado
  em R04 ou com a captura liberada do harness em T02.
- **P3 do backlog:** tweens concorrentes de dicas/intro são risco a
  reproduzir com transições rápidas; não houve quantificação do efeito.
- **P4 do backlog:** mostrar MINI-B em 0% após morte pode ser representação
  intencional do fragmento derrotado. Não declarar boss fantasma sem decidir
  a semântica esperada da barra.
- **Cap de motes:** contagem por grupo deixou de representar o campo
  compactado, mas existe limite próprio (`MAX=128`). Não afirmar crescimento
  ilimitado de motes por causa do cap antigo.
- **OOM preso na borda:** descartado; a base chama `_escape()` em FLEE.
  **Compactação troca o saque:** descartado como explicação geral; OOM usa
  UIDs e resolve índices. Isso não elimina R08.
- **Recompensas de cura de boss:** coexistência de heal/drop não foi provada
  como duplicação indevida. Falta estabelecer a regra de design esperada.
- **GodBoss e recuperação de meia vida:** diferença de implementação é
  candidata a revisão, não regressão validada sem contrato de comportamento.
- **`tactical_icon.gd`:** nenhuma regressão funcional comprovada no diff.

Capturas e stress anteriores usaram renderização virtual/software. Seus
tempos não fundamentam promessa de performance em GPU real ou mobile.
O problema de WebGL/Floorp ao abrir Figma pertence ao ambiente de visualização,
não foi evidência de bug do jogo nativo.

## 6. Ordem sugerida de correção e fechamento

1. R01–R03 e T01: dispatch real de teclado, pausa, patches e debug.
2. R04: eliminar acúmulo de projéteis órfãos e medir reinícios.
3. R05: restaurar o ciclo de escudo do ROOTLET.
4. R11–R12 e T03: corrigir regressões locais do menu e o probe.
5. R06–R08: boss e reinício Story, isolamento do saque dos OOM.
6. R10/T02/T04: remover erros de integração e tornar falhas visíveis no teste.
7. R13–R20/R09: explicitar ações de UI, validar touch e casos limítrofes.
8. Reavaliar hipóteses visuais/performance com matriz de estados e resoluções.

Essa é uma proposta de triagem, não substitui silenciosamente a ordem de
commits B1→B7→H1 do projeto. Conciliar os IDs e a ordem antes da implementação.
Para fechar um item: reproduzir o defeito, corrigir sua causa, executar o
critério de aceite e a suíte, registrar evidência e só então marcar concluído.

Para qualquer mudança de UI, incluir `text_overflow_report()` pertinente e
capturas reais após resize. Para commits, rodar a suíte completa com save
isolado. Nenhum item deste relatório está marcado como corrigido.

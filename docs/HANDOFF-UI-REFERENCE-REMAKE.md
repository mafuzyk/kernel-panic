# KERNEL PANIC — handoff do remake da UI por referências

**Data:** 2026-09-02
**Branch:** `fuzzy/ui-reference-remake`
**Base:** `96ac94c` (`docs: close master plan execution checkpoint`)
**Worktree de execução:** `/tmp/kernel-panic-ui-reference-remake`
**Checkout original preservado:** `/home/mafu/Projetos/kernel-panic`
**Estado:** checkpoint técnico publicado separadamente; sem merge em `main`
**Áudio nas verificações:** sempre desabilitado com `--audio-driver Dummy`

## 1. Resumo e limite deste lote

Este lote transforma a fundação vNext, que já existia como uma implementação
técnica funcional, em uma primeira composição visual realmente guiada pelas
referências de `media/Ideas/`. O trabalho não é uma tentativa de salvar a
hierarquia da UI antiga com novas cores. O shell, os blocos de telemetria, a
assimetria entre identidade e comando, os dossiês e os glyphs foram compostos
novamente a partir do zero dentro das superfícies vNext.

O escopo entregue nesta branch é um **vertical slice visual e responsivo**:

- boot/menu principal com shell persistente de sistema;
- seleção de programas com índice de processos, dossiê e identidade visual;
- Bestiary com índice, estado de descoberta, comportamento, counterplay e
  ilustração code-drawn compartilhada;
- settings/accessibility com composição de workstation e copy sem clipping;
- patch offer como superfície de decisão de build, com cards de consequência
  no desktop e navegação deliberada de uma oferta por vez em narrow;
- combat HUD como superfície code-drawn orientada pela `imagem5.png`, com
  informação no perímetro, combo/telemetria, dock de patches, boss register e
  composição micro-narrow empilhada;
- pausa e terminal com correções de fit específicas para telas estreitas;
- adaptação física de menu, patch, pausa, terminal e game-over a janelas
  estreitas, sem espremer uma composição desktop ilegível;
- reforço das silhuetas code-drawn de `DRONE`, `LANCER`, `SPEWER`, `DAEMON` e
  `ROOTLET`, além das identidades já existentes de `KERNEL` e dos demais
  processos;
- provas automatizadas novas para Bestiary, resize físico e overlays de Arena;
- validador acumulado atualizado para realmente executar os probes vNext do
  slice;
- documentação técnica e release notes separadas.

Este lote **não** promove a vNext para a rota padrão, não remove a UI legada,
não altera balanceamento, não altera o schema de save e não afirma que o jogo
já está pronto para uma publicação oficial. A composição é nova e jogável como
rota opt-in, mas ainda precisa de revisão visual humana final, validação em
hardware/export e fechamento dos gates de release já registrados no plano
mestre.

## 2. Comparação com `media/Ideas/`

As referências usadas são um moodboard, não uma especificação pixel-perfect.
O nome `iamgem9.png` é mantido exatamente como está no diretório.

| Referência | Leitura extraída | Aplicação nesta branch |
| --- | --- | --- |
| `imagem1.png` | menu como terminal de boot, marca à esquerda, comando dominante à direita, telemetria periférica | `boot_surface.gd` ganhou shell persistente, identidade `KERNEL PANIC`, process telemetry, command index, bridge glyph e footer operacional |
| `imagem10.png` | lista de programas à esquerda, ficha detalhada à direita, ação de execução sempre visível | `program_surface.gd` agora usa process index, dossier, identity glyph, linhas de role/playstyle/risk/loadout e ação `BOOT` persistente |
| `imagem2.png` | Bestiary como ferramenta de leitura de ameaça, não como uma grade de ícones | `bestiary_surface.gd` usa field index, logged/locked, enemy identity, behavior, counterplay e o mesmo renderer das entidades |
| `imagem3.png` | settings com organização de workstation e opções explícitas | `accessibility_surface.gd` recebeu shell metadata, cabeçalho, status, 10 controles, reset e footer dentro da safe area |
| `imagem5.png` | HUD encosta nas bordas e libera o centro para combate | `combat_hud_surface.gd` recompõe o HUD em torno do perímetro com integrity, combo, evento, patch dock, boss register, ability, score e rails; `Hud` continua como adapter de estado |
| `imagem6.png` | pausa dramática, jogo ainda visível, contexto da run e poucas decisões | `pause_surface.gd` continua com contexto congelado, ação curta e estado do programa; título agora se ajusta à largura real |
| `imagem8.png` | terminal diegético com stream, comandos, status, prompt e histórico | `terminal_surface.gd` preserva a workstation e evita colisão do título com `CLOSE [ESC]` em narrow |
| `iamgem9.png` | mapa de story com rota, tabs de eras e briefing | `story_surface.gd` traduz a referência para shell persistente, tabs de ato, índice de nós, dossiê da fase e faixa de evidência baseada no estado real |
| brief visual do patch offer | decisão de build com três cards, custo/benefício e comando de instalação | `patch_surface.gd` agora usa shell persistente, cards de consequência, registro da oferta selecionada e ação de instalação/skip com foco real |
| `imagem4.png` e `imagem7.png` | cards de progresso e diagnóstico final | continuam cobertos pelas superfícies existentes e pela fundação vNext; não foram reescritos neste lote sem uma lacuna visual comprovada |

### O que mudou na leitura visual

Antes, a vNext já tinha contratos de layout e ações, mas a primeira leitura
continuava próxima de um conjunto de telas funcionais: muito espaço vazio,
composição centralizada, pouca identidade de sistema e entidades que podiam
ser interpretadas como formas genéricas coloridas.

Depois, os screens principais compartilham uma gramática editorial:

- shell externo fino e recorrente;
- faixa superior com `SYSTEM ONLINE`, rota `KP://...` e sessão;
- título grande e curto com Orbitron;
- telemetria monoespacial em ShareTechMono;
- composição assimétrica entre índice, dossiê e comando;
- ciano para estrutura, branco frio para foco, magenta para ameaça, âmbar
  para aviso e lime para prontidão/recuperação;
- brackets e linhas angulares como estrutura de navegação, não como borda
  aplicada indiscriminadamente;
- ilustrações com núcleo, eixo, componentes e estado, em vez de círculo ou
  triângulo genérico apenas com outra cor;
- simplificação consciente em narrow: uma coluna ou fluxo lista → detalhe,
  com a ação primária e o retorno ainda visíveis.

No HUD, essa gramática agora também aparece durante a run. A arena fica livre no
centro; a informação contínua mora nas bordas; o evento temporário ocupa um
bloco próprio; combo e boss ganham instrumentos visíveis; e o estado de
habilidade não depende só de um ícone flutuante ou de uma mudança de cor.

O resultado deliberadamente não copia cada pixel das imagens. Ele copia o que
define a personalidade delas: máquina operacional, diagnóstico, assimetria,
ritmo de terminal e informação distribuída no perímetro.

## 3. Arquivos e alterações

### 3.1 Contratos e geometria compartilhada

#### `src/ui/vnext/ui_context.gd`

- protege superfícies contra viewport zero ou inválido, usando
  `VNextUITokens.BASE_VIEWPORT` como fallback determinístico;
- mantém `safe_rect`, densidade (`wide`, `compact`, `narrow`), modo de input,
  escala de texto e preferências de acessibilidade como contexto explícito;
- evita que probes headless ou uma janela em transição gerem geometria zero e
  criem um falso estado visual.

#### `src/ui/vnext/ui_layout.gd`

- boot recebeu regiões de shell, metadata, identity, telemetry, navigation,
  illustration e footer;
- foi adicionado `selection(viewport, context)` para programas e Bestiary;
- desktop usa índice + dossiê lado a lado;
- compact mantém duas áreas mais leves;
- narrow muda para um fluxo de lista/detalhe em vez de reduzir todo o desktop;
- ações e texto recebem `Rect2` derivados da mesma geometria que o desenho;
- o footer narrow do boot virou uma linha de três ações com largura distribuída
  para impedir que `SETTINGS` fosse espremido em um botão quase invisível.

#### `src/ui/menu.gd`

- rotas vNext agora incluem Bestiary;
- configurações e rotas recebem o tamanho físico da janela quando disponível;
- `_fit_vnext_surface()` calcula o encaixe uniforme entre a composição física e
  o canvas lógico, preservando a regra `canvas_items + aspect=expand`;
- telas estreitas deixam de ser um desktop esmagado dentro de 432 px;
- resize físico é tratado tanto por notificação quanto por
  `Window.size_changed`, cobrindo mudanças que não alteram o canvas lógico;
- a rota padrão continua legada fora dos switches `KP_VNEXT_*` por decisão de
  rollout e rollback, não por falta de integração.

#### `src/arena/arena.gd`

- patch, pause, terminal e game-over vNext recebem a mesma estratégia de
  tamanho físico e reflow;
- a Arena observa `Window.size_changed` enquanto está viva;
- `_prepare_vnext_surface()` reaplica fit e `reflow_for_viewport()` quando um
  overlay já aberto encontra uma mudança de janela;
- a mudança é de apresentação e integração de viewport: não toca em spawn,
  física, timers de gameplay, valores de balance ou regras de save;
- foi preservado o ownership existente dos actions da Arena e do
  `PauseInputRouter`.

### 3.2 Boot/menu

#### `src/ui/vnext/surfaces/boot_surface.gd`

- composição nova com moldura externa, grid de baixa opacidade, identidade
  `KERNEL PANIC`, slogan de diagnóstico e metadata de versão/sessão;
- process telemetry separada do command index;
- ação `RUN PROCESS` dominante;
- `PROGRAMS`, `STORY`, `BESTIARY`, `SETTINGS` e `BACK` mantêm controles reais;
- foco, mouse, touch e Enter ativam Buttons reais, enquanto a geometria desenhada
  acompanha as mesmas regiões;
- semântica passou a publicar `visual_system: reference_shell`, rota e
  composição para inspeção automatizada.

### 3.3 Programas

#### `src/ui/vnext/surfaces/program_surface.gd`

- lista de processos e detalhe agora seguem o padrão de `imagem10.png`;
- o dossiê apresenta identidade, role, playstyle, integrity, move, fire,
  range e loadout;
- `KERNEL`, `DAEMON` e `ROOTLET` usam identidade code-drawn no mesmo espaço de
  seleção em que serão usados no runtime;
- o caminho narrow separa lista e detalhe, com `PROGRAM LIST` e `BOOT` claros;
- o registry de Button continua sendo o dono da ativação real;
- o texto `READY/LOCKED` foi retirado do texto interno duplicado do botão e
  passou a ser apresentado como estado independente/tooltip;
- footer corrigido para desenhar `BUILD 0.2.3` dentro da própria faixa, sem
  invadir o retângulo de boot.

### 3.4 Bestiary

#### `src/ui/vnext/surfaces/bestiary_surface.gd` — novo

- usa `ContentCatalog.BESTIARY_ENTRIES` como fonte de conteúdo;
- lista real com `ScrollContainer`/`VBoxContainer`, para não tentar colocar 20
  entidades em uma coluna desktop fixa;
- suporta logged/locked sem depender só de cor;
- dossier mostra nome, threat class, threat points, behavior e counterplay;
- a identidade visual vem de `VNextEntityIllustration`, não de um desenho
  paralelo criado apenas para o menu;
- em narrow, a lista vira um estado navegável e o detalhe vira outro estado,
  ambos com ação de retorno;
- o save do Bestiary não é escrito pela superfície: o probe altera o estado
  apenas temporariamente e a tela continua sendo uma consumidora de snapshot;
- footer corrigido para permanecer dentro da área de telemetria.

### 3.5 Settings/accessibility

#### `src/ui/vnext/surfaces/accessibility_surface.gd`

- shell metadata e cabeçalho foram posicionados antes do status;
- dez opções de acessibilidade e reset cabem na safe area em wide, compact e
  narrow;
- a tela publica rota `KP://SETTINGS/ACCESSIBILITY` e sistema visual;
- overflow mede copy real, e não apenas declara que um campo existe;
- controles continuam sendo Buttons reais e preservam persistência através do
  serviço `Sfx` existente.

### 3.6 Pause e terminal

#### `src/ui/vnext/surfaces/pause_surface.gd`

- o título `PAUSED // FROZEN RUN` passou a ser medido com a fonte real
  `Orbitron`, em vez de ser validado acidentalmente com `ShareTechMono`;
- em narrow, o tamanho é ajustado ao retângulo real, respeitando um piso de
  leitura;
- `text_overflow_report()` agora informa fonte/tamanho medidos;
- o título e a semântica usam o mesmo tamanho que o desenho final.

#### `src/ui/vnext/surfaces/terminal_surface.gd`

- o título é encurtado para `DIAGNOSTIC // TTY0` somente no narrow quando o
  título padrão completo não cabe ao lado do close;
- a largura do título reserva explicitamente o espaço de `CLOSE [ESC]`;
- `Orbitron` é usado no relatório de overflow do título;
- a semântica publica título visível e tamanho usado;
- stream, command index, status, prompt, histórico, autocomplete e ESC foram
  preservados;
- não houve alteração no executor de comandos nem no ownership do `rm -rf /`.

### 3.7 Combat HUD

#### `src/ui/vnext/surfaces/combat_hud_surface.gd`

- foi recomposto como uma superfície code-drawn orientada pela referência
  `imagem5.png`, sem transformar a HUD legada em um molde visual obrigatório;
- o perímetro agora contém moldura/rails de calibração, integrity com HP,
  pips, direção do último dano e meter segmentado, combo com fração de cadeia,
  evento temporário, patch dock, ability/dash, score/time/run e boss register;
- cada bloco é alimentado pelo snapshot do `Hud` ou pela fixture de captura;
  combo, patches, boss fragments e damage direction têm representação semântica
  verificável além do desenho;
- o boss foi movido para um registro superior, reduzindo o topo do retângulo
  reservado de gameplay em vez de ocupar o rodapé e competir com os controles;
- a composição usa três densidades: wide, compact/narrow e micro-narrow. Em
  `320×568`, integrity e patch dock empilham, evento/combo/boss seguem abaixo e
  ability/score continuam lado a lado no rodapé com cópia curta e área de ação
  touch-safe;
- todos os textos desenhados passam por `TacticalUI.ellipsis_fit`; o relatório
  de overflow mede a mesma fonte e o mesmo texto efetivamente usado na
  renderização, incluindo formas abreviadas apenas quando micro-narrow ou
  quando a escala de texto exige;
- o surface mantém `MOUSE_FILTER_IGNORE` e só encaminha o hit region explícito
  do dash, deixando o movimento multi-touch sob responsabilidade dos controles
  da Arena;
- o estado do `Hud` continua sendo o adapter de gameplay: não foram alterados
  spawn, física, dano, pontuação, balance ou ownership de input da simulação.

#### `src/ui/hud.gd`

- `_dash_icon` legado agora permanece oculto enquanto `KP_VNEXT_HUD=1`; antes,
  `_process()` tornava o ícone visível novamente a cada frame, produzindo um
  segundo indicador de dash por cima da HUD nova;
- combo fraction é sincronizada no snapshot vNext e a cópia de ciclo fica no
  patch dock quando o banner contínuo está ativo, evitando duplicar `CYCLE NN`
  no bloco de evento temporário;
- o adapter continua responsável por fornecer HP, meter, dash, score, programa,
  boss fragments e damage direction; a superfície não toma decisões de regra.

#### Probes e captura do HUD

- `tools/vnext_combat_hud_probe.gd/.tscn` cobre HP 1–12, estados de meter e
  dash, combo, patches, boss split, fit de evento longo, safe area, não
  sobreposição, reflow, text scale 115%, micro-narrow `320×568`, input e o
  caminho real de `Arena → Hud → CombatHudSurface`;
- `tools/vnext_surface_capture.gd` ganhou fixture silenciosa de `combat_hud`
  com evento, patches, combo, boss e run seed longos, para revisão raster em
  wide, narrow e micro-narrow;
- o probe E3 continua verificando que a habilidade visual permanece específica
  do programa; abreviações (`OC RDY`, `SH RDY`) são usadas no micro-narrow ou
  quando uma escala de texto de pelo menos 110% exige a redução, preservando os
  nomes completos no narrow regular padrão.

### 3.8 Arte code-drawn

#### `src/ui/vnext/core/entity_renderer.gd`

Foram registradas identidades explícitas para separar forma de estado:

| Entidade | Silhueta/motivo | Leitura mecânica |
| --- | --- | --- |
| `DRONE` | `sensor_dart`, `forward_sensor`, `tracking_arc` | perseguição e eixo de rastreio |
| `LANCER` | `execution_spear`, `charge_lance`, `forward_spear` | ameaça linear e carga |
| `SPEWER` | `nozzle_pod`, `burst_mouth`, `scatter_cone` | emissor de pressão e rajada |
| `KERNEL` | `process_core`, `forward_core`, `aim_axis` | programa equilibrado e direção de tiro |
| `DAEMON` | `claw_dart`, `forked_tail`, `close_range_fangs` | agressão curta e dash |
| `ROOTLET` | `shield_kernel`, `barrier_core`, `shield_arc` | núcleo protegido e recarga do escudo |

#### `src/ui/glyph_lib.gd`

- `DRONE` ganhou sensor frontal, quadrícula/núcleo e exaustão;
- `LANCER` ganhou lança de execução, aletas traseiras e eixo de carga;
- `SPEWER` ganhou cápsula de pressão, boca emissora e vents laterais;
- `DAEMON` ganhou garra, cauda bifurcada e núcleo de curta distância;
- `ROOTLET` ganhou placas/barreira e um núcleo protegido;
- a extensão do `SPEWER` foi corrigida para reservar espaço visual suficiente;
- finish/glow continuam subordinados à silhueta e o renderer não altera
  posição, HP, RNG, hitbox, drop ou física.

#### Guard do E2

O hash de apresentação do `e2_legacy_enemy_probe.gd` foi atualizado para
`74c83f953ef3ad2b9a9a739928c37a8ff86c48459434cd20aafbaed173c393df`.

Isso não é uma forma de mascarar uma alteração. O guard antigo protegia um
baseline anterior e corretamente ficou vermelho depois que os silhouettes
aprovados foram modificados. O novo valor registra o baseline intencional desta
branch e o probe continua verificando as demais branches e o desenho real.

### 3.9 Probes e validador

Foram adicionados ou reforçados:

- `tools/vnext_bestiary_probe.gd/.tscn` — fluxo de Bestiary, lista real,
  lock/unlock, renderer e overflow;
- `tools/vnext_window_layout_probe.gd/.tscn` — resize físico de menu em
  `432×720` sob Xvfb;
- `tools/vnext_arena_window_layout_probe.gd/.tscn` — resize físico de pause e
  patch pela Arena real;
- `tools/vnext_state_surfaces_probe.gd` — regressões de título narrow reais
  para pause e terminal;
- `tools/vnext_boot_probe.gd`, `vnext_selection_probe.gd`,
  `vnext_menu_probe.gd`, `vnext_accessibility_probe.gd` e
  `vnext_entity_illustration_probe.gd` — marcadores de shell, rota, semântica
  e identidades;
- `tools/menu_prompt_probe.gd/.tscn` — regressão do prompt de inicialização da
  rota legada, incluindo visibilidade, retângulo real, guard de ESC e overlays;
- `tools/input_dispatch_probe.gd/.tscn` — ampliado para confirmação deliberada
  por teclado, proteção contra echo/duplo input e o callback real do botão de
  abandono;
- `tools/validate_input_dispatch.sh` — inclui boot, selection, Bestiary,
  integração de menu, prompt B6 e os dois probes de resize físico.

## 4. Bugs encontrados durante a própria revisão

### Bug UI-REF-01 — título da pausa cortado em narrow

**Antes:** o desenho usava Orbitron a 27 px sem medir a largura. O relatório
de overflow usava ShareTechMono e, por isso, declarava que cabia mesmo quando
o screenshot cortava `FROZEN RUN`.

**Evidência:** `/tmp/kernel-panic-ui-u4-title-red.log`, um teste narrow falhou
com `pause title uses a readable fitted font on narrow view`.

**Causa:** fonte validada não era a fonte desenhada e o tamanho era fixo.

**Fix:** tamanho dinâmico com Orbitron real, limite por região, piso de 14 px,
campo de overflow com `font_size`, e teste de medição narrow.

**Depois:** `/tmp/kernel-panic-ui-u4-title-green.log`, 0 falhas. Screenshot
validado em `/tmp/kernel-panic-ui-captures.bJIWwN/pause-narrow-v2.png`.

**Risco restante:** 432×720 foi validado; tamanhos menores que o piso e
fontes substitutas de plataformas não foram ainda testados em device/export.

### Bug UI-REF-02 — título do terminal colidia com `CLOSE [ESC]`

**Antes:** `DIAGNOSTIC WORKSTATION // TTY0` era desenhado por cima da região
ocupada pelo botão de fechar no narrow.

**Evidência:** `/tmp/kernel-panic-ui-terminal-title-red.log`, 1 falha de
legibilidade/fit. Screenshot anterior em `/tmp/kernel-panic-ui-captures.SD9LK7/terminal-narrow.png`.

**Causa:** title region usava a largura completa do painel, ignorando o botão
de close; o overflow novamente não usava Orbitron.

**Fix:** reserva de 118 px para close, título narrow curto e semântico,
medição com Orbitron e novo teste de fit.

**Depois:** `/tmp/kernel-panic-ui-terminal-title-green.log`, 0 falhas.
Screenshot validado em `/tmp/kernel-panic-ui-captures.o01WTq/terminal-narrow-v2.png`.

**Trade-off:** narrow perde parte do texto ornamental completo, mas mantém a
identidade da workstation, o TTY e a ação de fechar legíveis. O título completo
continua em wide/compact e a semântica do terminal permanece explícita.

### Bug UI-REF-03 — telemetria `BUILD` do dossiê desenhada fora do footer

**Antes:** Program e Bestiary usavam `rect.end - Vector2(178, -17)`. O `-17`
no eixo Y fazia a baseline ficar 17 px abaixo do final do footer, invadindo a
área do botão `BOOT`.

**Evidência:** screenshot `/tmp/kernel-panic-ui-captures.2Pup2i/program-wide-v4.png`
mostrou o texto entre a faixa de telemetria e o botão de execução.

**Fix:** baseline passou a usar `rect.position + Vector2(rect.size.x - 178, 17)`.

**Depois:** o texto fica dentro da faixa de footer; screenshot v4 já registra
o estado corrigido.

### Bug UI-REF-04 — validador produzia falsos fails por XDG relativo

**Antes:** `tools/validate_input_dispatch.sh` calculava o XDG como
`.godot/codex-review-lote-1/xdg`. Godot rejeitou o caminho relativo segundo a
especificação XDG e caiu no save global do usuário. A suíte então misturou
estado persistido e falhou em touch/lock-on, embora a execução limpa passasse.

**Evidência:** primeira execução da branch registrou 22 `AT_FAIL` e o probe R18
falhou; o log mostrou `XDG_DATA_HOME is a relative path. Ignoring its value`.
Uma segunda execução com `/tmp/kernel-panic-ui-clean-validation.gN7yGa/data`
passou com 1453 `AT_PASS`, 0 `AT_FAIL`, e R18 passou com 6 checks.

**Fix:** o validador converte `LOG_DIR` relativo para caminho absoluto antes de
montar `XDG_DATA_HOME`.

**Depois:** a execução final com logs em
`/tmp/kernel-panic-ui-final-validation.NrT5ZS` terminou em `VALIDATION OK`.

### Bug/ajuste de probe UI-REF-05 — assertion de narrow no patch usava o nível errado

O probe físico inicialmente procurava `layout_snapshot()["narrow"]`, mas o
contrato público do patch expõe `density` no contexto e usa outra forma interna
de layout. A implementação estava correta; a assertion estava errada e falhou
uma vez. Ela foi alterada para verificar `patch_context.density == "narrow"`.
O probe final passou com 12 checks. Esta ocorrência fica documentada para não
ser confundida com bug de produto.

### Bug UI-REF-06 — indicador de dash legado reaparecia sobre o HUD vNext

**Antes:** a nova superfície desenhava o módulo de ability/dash, mas
`src/ui/hud.gd` continuava marcando `_dash_icon.visible = true` a cada frame
quando a janela era desktop. O resultado era um segundo glyph flutuante sobre
o canto inferior da composição nova.

**Evidência:** a captura real da Arena
`/tmp/kernel-panic-ui-captures-hud/hud-runtime-vnext.png` mostrou o indicador
legado duplicado; a captura posterior
`/tmp/kernel-panic-ui-captures-hud/hud-runtime-vnext-v2.png` foi feita depois
da correção e não mostra o glyph extra. O probe real também verifica
`_dash_icon.visible == false` sob `KP_VNEXT_HUD=1`.

**Causa:** o estado de visibilidade era aplicado dentro de `_process()` sem
considerar o modo vNext; a configuração inicial feita em `_ready()` não era
suficiente para um nó reativado por frame.

**Fix:** a visibilidade agora é `not _vnext_hud_mode` além das condições
existentes de plataforma e layout. O adapter continua atualizando o estado,
mas só a superfície escolhida desenha o indicador.

**Impacto:** nenhuma mudança em dash, input, cooldown, touch ou balance; apenas
remove duplicação visual no modo opt-in.

### Bug UI-REF-07 — painéis laterais colidiam na menor largura testada

**Antes:** a primeira matriz do HUD aplicava dois painéis de aproximadamente
160 px lado a lado em um safe rect de 272 px (`320×568`). Os retângulos de
integrity e patch dock se sobrepunham, apesar de 432×720 já estar correto.

**Evidência:** a primeira execução da matriz de viewports do
`vnext_combat_hud_probe` falhou somente em
`viewport (320.0, 568.0) keeps hud panels separate`; as viewports 390, 432,
600, 1280 e 1920 passaram. A captura final
`/tmp/kernel-panic-ui-captures-hud-final/hud-reference-pass-micro-logical-v2.png`
mostra os dois painéis empilhados e o centro de jogo preservado.

**Causa:** o breakpoint `narrow` resolvia “telefone” como uma versão reduzida
do desktop, mas não havia um segundo breakpoint para quando duas colunas já
não cabiam no safe rect.

**Fix:** foi criado o modo `micro-narrow` para safe width inferior a 340 px:
integrity e patch dock ocupam a largura total em linhas consecutivas, os
blocos superiores têm alturas próprias, a ability e o score usam dois cartões
inferiores menores e o retângulo reservado da arena passa a usar a largura
inteira disponível. Cópia curta e glyph lateral evitam esmagar o conteúdo dos
patches.

**Impacto:** a HUD ainda é visualmente a mesma família; apenas muda a
composição em telas extremamente estreitas. O espaço central fica menor, mas
continua explicitamente reservado e mensurado. O aparelho real, safe area de
recorte e orientação landscape ainda não foram comprovados.

### Bug UI-REF-08 — abreviação agressiva quebrou o contrato de identidade do programa

**Antes:** o primeiro passe da compactação usou `SH RDY`/`OC RDY` em toda a
densidade narrow. O probe E3 já verificava que a HUD deveria desenhar
`SHIELD READY` para o Rootlet e passou a falhar, embora a semântica interna
continuasse correta.

**Evidência:** a execução acumulada
`/tmp/kernel-panic-ui-validation-hud-final/probe-e3-program-identity.log`
registrou `PROBE_FAIL combat HUD draws program-specific ability state` e fez o
validador terminar em `VALIDATION FAILED`. Depois do ajuste, a execução direta
de E3 em `/tmp/kernel-panic-ui-validation-e3-after-hud.log` terminou com 35
passes e `PROBE_DONE fails=0`.

**Causa:** o corte visual foi aplicado a `narrow` sem demonstrar que 432 px
exigia abreviação. Isso trocou uma informação de domínio legível por uma
economia de espaço prematura.

**Fix:** as abreviações são usadas em `micro-narrow` e também quando a escala
de texto chega a 110% em narrow regular; 432×720 em escala padrão mantém
`SHIELD READY`/`OC READY`, enquanto 320×568 usa formas curtas quando a
geometria exige. A semântica pública continua publicando o nome completo.

**Lição e risco:** um texto que cabe numericamente não deve ser reduzido sem
considerar contratos de acessibilidade, identidade e testes existentes. Ainda
é necessário revisar as abreviações em PT-BR e com text scale 150–200% em um
dispositivo real.

## 5. Decisões técnicas e alternativas

### 5.1 Shell compartilhado por linguagem, não por herança obrigatória

**Decisão:** usar tokens, `ui_layout.gd` e o mesmo vocabulário de frames, mas
manter parte dos helpers de desenho local em Program e Bestiary.

**Alternativas consideradas:** criar imediatamente um `VNextUIShell`
monolítico; continuar usando o shell legado e apenas trocar cores/labels; ou
duplicar cada tela sem contratos compartilhados.

**Motivo da escolha:** um shell monolítico tenderia a impor a mesma densidade
e a mesma hierarquia a telas com tarefas diferentes. O shell legado foi
descartado porque foi justamente a causa do problema visual que motivou o
remake. A duplicação parcial foi aceita temporariamente para manter a geometria
de cada dossier legível e consolidar depois com evidência.

**Trade-off:** há algum código de moldura repetido. Isso é dívida técnica
conhecida, não duplicação de regras de gameplay. A próxima etapa deve extrair
somente primitivas comprovadamente iguais.

### 5.2 Tamanho físico para composição, canvas lógico para encaixe

**Decisão:** calcular a densidade a partir de `Window.size`, construir a
composição com essa geometria e aplicar fit uniforme ao canvas lógico.

**Alternativa:** usar sempre `get_viewport_rect()` e deixar o stretch escolher
a escala.

**Motivo:** sob `canvas_items + aspect=expand`, a viewport nem sempre comunica
que uma janela portrait precisa de uma composição narrow. A alternativa criou
um desktop comprimido em um screenshot real de 432 px.

**Risco:** input manual que use coordenadas próprias precisa continuar
convertendo transformações de canvas e de superfície. Buttons reais reduzem o
risco; os probes de input e o probe físico cobrem as rotas atuais, mas Android
real e gestos ainda não foram validados.

### 5.3 Bestiary como superfície consumidora de catálogo

**Decisão:** o Bestiary lê `ContentCatalog` e `Game.bestiary_seen`, sem salvar
diretamente.

**Alternativa:** cada tela duplicar os dados de inimigo ou escrever no save ao
abrir o dossiê.

**Motivo:** a tela deve ser previsível, testável e incapaz de transformar uma
visita de menu em mutação de progresso. A descoberta pertence ao gameplay;
visualização pertence à UI.

### 5.4 Code-drawn como fonte principal

**Decisão:** continuar sem sprite raster novo e reforçar GlyphLib + renderer.

**Alternativa:** importar imediatamente uma sprite sheet gerada ou usar imagem
como identidade principal.

**Motivo:** o requisito do projeto é que inimigos/programas permaneçam
code-drawn e o risco observado era a aparência de protótipo genérico. O
renderer permite testar silhueta, facing, estado e bounds sem introduzir
dependência de asset, import ou memória.

**Trade-off:** ilustrações code-drawn exigem mais iteração manual para alcançar
acabamento de arte. A branch entrega estrutura e identidade, não declara o
passe artístico final de todo o cast.

### 5.5 Opt-in em vez de trocar a rota padrão

**Decisão:** manter `KP_VNEXT_BOOT`, `KP_VNEXT_PATCH`, `KP_VNEXT_HUD`,
`KP_VNEXT_U4` e `KP_VNEXT_SETTINGS` como gates de rollout.

**Motivo:** o redesign ainda requer aprovação visual humana e o plano mestre
proíbe tratar teste funcional como aprovação de produto. O rollback continua
sendo remover o switch, sem reverter a main nem perder o runtime legado.

### 5.6 HUD como adapter de estado, não como segunda implementação de gameplay

**Decisão:** `Hud` continua sendo a ponte que lê o estado real da Arena e
`VNextCombatHudSurface` fica responsável por composição, desenho, semântica e
hit regions. A superfície recebe snapshot e não modifica HP, score, cooldown,
spawn, física ou regras de patch.

**Alternativas consideradas:** reescrever o HUD e a coleta de estado ao mesmo
tempo; desenhar a nova superfície diretamente sobre campos de `Arena`; ou
manter o desenho legado e apenas aplicar o shell novo por cima.

**Motivo da escolha:** separar fonte de estado e apresentação permite substituir
a UI sem criar uma segunda autoridade de gameplay. O probe real confirma que o
combo, programa, escudo, dano e boss fragments chegam pelo caminho
`Arena → Hud → surface`; a captura real confirma que a simulação continua
visível atrás da camada.

**Trade-off:** ainda existe um adapter temporário no `Hud`, e parte do código
de layout legado continua sendo executada. Isso evita uma migração arriscada
durante o vertical slice, mas mantém uma etapa futura de limpeza/performance.

### 5.7 Breakpoint micro-narrow orientado por geometria disponível

**Decisão:** não reduzir todos os componentes indefinidamente. Quando o safe
rect fica abaixo de 340 px de largura, a HUD muda para uma composição
empilhada, com painéis superiores de largura total e cartões inferiores
compactos.

**Alternativa:** conservar duas colunas sempre; reduzir fontes, margens e
glyphs até caber; ou esconder o patch dock/boss sem sinalizar a perda.

**Motivo da escolha:** a primeira matriz demonstrou que duas colunas já se
sobrepunham em 320×568. Empilhar preserva a informação crítica, dá uma região
de toque mensurável e mantém a arena central explicitamente reservada. Esconder
informação seria uma regressão de estado; microtexto seria uma falha de
acessibilidade.

**Trade-off:** a área vertical livre fica menor em portrait extremo. Por isso
o probe mede também `reserved_playfield`, e a composição não se apresenta como
equivalente à densidade desktop.

### 5.8 Abreviações só quando a geometria exige

**Decisão:** `OC RDY`, `SH RDY` e equivalentes ficam restritos a
`micro-narrow` ou a narrow com escala de texto igual/superior a 110%; em
narrow regular na escala padrão, `OC READY` e `SHIELD READY` permanecem
visíveis.

**Alternativa:** abreviar todo narrow, ou manter sempre a cópia completa e
aceitar clipping em 320 px.

**Motivo:** o teste E3 mostrou que abreviar 432 px quebrava um contrato de
identidade do programa sem necessidade. O layout micro tem largura real menor
e usa abreviações controladas; a semântica pública continua com o estado
completo para acessibilidade e automação.

## 6. Compatibilidade, performance e impacto

### Compatibilidade

- nenhum save path foi alterado;
- nenhum schema de save foi alterado;
- nenhum valor de balance, hitbox, spawn, recompensa ou regra de gameplay foi
  modificado neste slice visual;
- Bestiary e programas usam snapshots/catalogs já existentes;
- inputs existentes continuam funcionando; os controles reais recebem foco e
  ativação por teclado, mouse e touch;
- a rota antiga continua disponível como fallback;
- novas superfícies não introduzem dependência online, conta, telemetria,
  anúncio ou serviço externo.

### Performance

- a composição usa linhas, polígonos e fontes existentes;
- grid/finish/glow são de baixa opacidade e não alteram simulação;
- o probe E2 confirmou determinismo e que `_draw()` não muta campos de
  gameplay;
- os perfis de performance já registrados no lote anterior continuam sendo a
  referência; hardware-specific frame-time claims permanecem abertos;
- ainda não há medição em Vega integrado real ou Android.

### Breaking changes

Nenhuma breaking change intencional. A alteração do hash E2 é uma atualização
de baseline de teste e não uma API pública. A redução do título do terminal em
narrow é uma adaptação de apresentação, não uma mudança de comando ou input.

## 7. Evidência de testes

Todos os comandos foram executados com `--audio-driver Dummy`.

| Grupo | Resultado final |
| --- | --- |
| DevHarness `--autotest` | exit 0, `1454 AT_PASS`, `0 AT_FAIL`, `AUTOTEST_ALL_PASS` |
| Input dispatch headless | exit 0, 38 passes, 0 fails |
| Input dispatch Xvfb/debug | exit 0, 40 passes, 0 fails; debug desktop confirmado |
| Legacy menu prompt B6 | exit 0, 9 passes, 0 fails |
| Boot reference shell | exit 0, 102 passes, 0 fails |
| Program + Story selection | exit 0, 225 passes, 0 fails |
| Bestiary reference shell | exit 0, 128 passes, 0 fails |
| Menu route integration | exit 0, 22 passes, 0 fails |
| Patch surface | exit 0, 67 passes, 0 fails |
| Patch Arena adapter | exit 0, 19 passes, 0 fails |
| Combat HUD adapter | exit 0, 75 passes, 0 fails |
| Pause/terminal/game-over | exit 0, 75 passes, 0 fails |
| Settings/accessibility | exit 0, 98 passes, 0 fails |
| Shared state surface | exit 0, 145 passes, 0 fails |
| Entity illustration | exit 0, 143 passes, 0 fails |
| E2 legacy enemy presentation | exit 0, 77 passes, 0 fails |
| Physical menu resize Xvfb | exit 0, 8 passes, 0 fails |
| Physical Arena overlays Xvfb | exit 0, 12 passes, 0 fails |

O validador acumulado final terminou com:

```text
VALIDATION OK (teardown diagnostics above remain non-gating)
```

### Comandos reprodutíveis

Rodar o jogo vNext em silêncio:

```sh
KP_VNEXT_BOOT=1 \
KP_VNEXT_SETTINGS=1 \
KP_VNEXT_HUD=1 \
KP_VNEXT_U4=1 \
KP_VNEXT_PATCH=1 \
godot --audio-driver Dummy --path .
```

Rodar a validação acumulada:

```sh
tools/validate_input_dispatch.sh
```

Rodar o probe físico do menu:

```sh
KP_VNEXT_BOOT=1 \
xvfb-run -a -s '-screen 0 640x800x24' \
godot --audio-driver Dummy --path . \
res://tools/vnext_window_layout_probe.tscn
```

Rodar o probe físico da Arena:

```sh
KP_VNEXT_U4=1 KP_VNEXT_PATCH=1 \
xvfb-run -a -s '-screen 0 640x800x24' \
godot --audio-driver Dummy --path . \
res://tools/vnext_arena_window_layout_probe.tscn
```

### Capturas visuais inspecionadas

As capturas são evidência local temporária em `/tmp` e não entram no commit:

- boot wide: `/tmp/kernel-panic-ui-captures.L70rto/menu-wide-v2.png`;
- boot narrow real: `/tmp/kernel-panic-ui-captures.dMgljf/menu-narrow-settings-v2.png`;
- Program wide após correção de footer: `/tmp/kernel-panic-ui-captures.2Pup2i/program-wide-v4.png`;
- Bestiary wide: `/tmp/kernel-panic-ui-captures.FEb0ee/bestiary-wide-v2.png`;
- settings wide: `/tmp/kernel-panic-ui-captures.NpGOX4/settings-wide-v2.png`;
- HUD wide baseline: `/tmp/kernel-panic-ui-captures.XrrC6t/hud-wide.png`;
- HUD reference wide: `/tmp/kernel-panic-ui-captures-hud-final/hud-reference-pass-1280x720.png`;
- HUD reference narrow: `/tmp/kernel-panic-ui-captures-hud-final/hud-reference-pass-432x720.png`;
- HUD reference micro-narrow: `/tmp/kernel-panic-ui-captures-hud-final/hud-reference-pass-micro-logical-v3.png`;
- HUD Arena real after duplicate-dash fix: `/tmp/kernel-panic-ui-captures-hud/hud-runtime-vnext-v2.png`;
- pause wide: `/tmp/kernel-panic-ui-captures.6lgyl3/pause-wide.png`;
- pause narrow após correção: `/tmp/kernel-panic-ui-captures.bJIWwN/pause-narrow-v2.png`;
- terminal narrow após correção: `/tmp/kernel-panic-ui-captures.o01WTq/terminal-narrow-v2.png`.

As imagens confirmam composição, safe area, shell, hierarquia e ausência dos
clippings encontrados. Não confirmam Android, escala de sistema, fonte
fallback de cada plataforma, latência de input ou qualidade final em hardware
integrado.

## 8. Known Issues e incertezas

### Comprovado

- a nova composição está integrada e navegável sob switches opt-in;
- menu, programas, Bestiary e accessibility têm shell e semântica de referência;
- o combat HUD vNext traduz a referência de perímetro e mantém o centro
  reservado, com cobertura específica em wide, narrow e micro-narrow;
- resize real de 432×720 alimenta menu e overlays Arena;
- pause e terminal não cortam os títulos testados em narrow;
- probes focados e suíte acumulada passam sem erros de runtime gating;
- erros de teardown continuam separados dos erros de execução.

### Não comprovado ainda

- não há export final Linux/Windows/Android produzido e executado neste lote;
- não há validação em dispositivo Android, Vega real ou touchscreen físico;
- não há avaliação humana final em grayscale, alto contraste e reduced motion
  para cada captura;
- nem todo inimigo do catálogo recebeu ainda o mesmo passe artístico profundo
  dos cinco silhouettes reforçados nesta branch;
- a rota vNext continua opt-in;
- PT-BR continua parcial no projeto maior e exige revisão editorial nativa;
- o comportamento de screen reader nativo e escalonamento OS não está implementado;
- diagnósticos de teardown ainda aparecem: ObjectDB, recursos, RIDs de texto,
  fontes, texturas e alguns `Area2D`/CanvasItem. Eles não são `SCRIPT ERROR`
  durante o runtime, mas continuam bloqueador de limpeza de release até serem
  categorizados e decididos;
- superfícies legadas e algumas superfícies vNext de estado ainda possuem
  helpers locais; o shell compartilhado cobre Boot, Program, Bestiary e
  Accessibility neste passe, mas a migração total precisa de critérios para não
  centralizar diferenças reais;
- o combat HUD ainda convive com o adapter do `Hud` legado; a fonte de estado é
  compartilhada, mas a remoção completa da apresentação antiga só deve ocorrer
  depois de validar todos os fluxos de pause, game-over, touch e export;
- valores e slogans como `0.2.3` continuam copy de produto sujeita a revisão.

### Risco e validação recomendada

1. abrir a branch com os switches vNext em desktop e comparar visualmente cada
   rota com as referências, inclusive estado locked/ready;
2. repetir o mesmo fluxo em 432×720 com touch real, testando foco, scroll,
   teclado virtual e botões vizinhos;
3. testar todos os programas e inimigos em gameplay, não só no dossiê;
4. revisar grayscale, high contrast, reduced motion e text scale 1.5/2.0;
5. medir FPS e alocações no hardware que será suportado;
6. decidir se o visual está suficientemente autoral para virar default;
7. fechar teardown, exports, PT-BR integral e checklist antes de publicar.

## 9. Veredito de release

**Não está pronto para lançamento oficial.**

Está pronto como um **checkpoint técnico visual revisável**, com uma diferença
importante: a reclamação de UI vazia foi atacada na composição, não só em
cores. A branch agora dá uma base concreta para avaliação humana e para o
próximo passe de arte.

O que falta para um release candidate real é maior que “mais um screenshot”:
promover a rota somente após aprovação das telas, completar o cast e a
localização, validar hardware/export/mobile, fechar os diagnostics de teardown,
revisar acessibilidade de plataforma e realizar playtest/balance final.

## 7.1 Segunda revisão visual — direção única de incidente operacional

Depois da primeira implementação vNext, foi feita uma comparação crítica lado a
lado com as referências de `media/Ideas` (`imagem1`, `imagem2`, `imagem3` e
`imagem10`), com a primeira composição de `media/menu.png` e com as capturas da
UI anterior. A conclusão não foi “faltam efeitos”: o shell estava correto, mas
as telas ainda podiam parecer wireframes de terminal, com densidade visual sem
uma gramática operacional suficientemente compartilhada.

### Achados confirmados

- Boot tinha identidade, telemetria e comando, mas ainda deixava um campo
  central amplo sem um trilho visual que o conectasse ao estado do processo;
- Program tinha a separação índice/dossiê, mas o dossiê não usava toda a área
  inferior para dados verificáveis;
- Bestiary tinha a mesma lacuna no dossiê, especialmente no estado logged, e a
  lista estreita mantinha marcadores de estado apertados demais;
- Accessibility era funcional, porém visualmente uma lista isolada, sem a
  mesma sensação de estação de diagnóstico das referências;
- o rodapé de Program e Bestiary ainda era desenhado com posições de desktop em
  narrow, e os botões do índice de Program não expandiam até a largura da
  coluna real;
- os shells locais repetiam parte da lógica de grid, metadata e moldura, o que
  permitia drift entre telas.

### Decisão consolidada

A direção agora é denominada **incident console**: KERNEL PANIC é uma
workstation hostil acompanhando um processo vivo. Cada tela deve tornar legíveis
rota, estado, objeto inspecionado e próxima ação. Densidade só é válida quando
vem de identidade, estado, navegação ou comparação sustentada por dados reais;
glow, grid e números sem função não são considerados acabamento.

### Alterações deste segundo passe

- `src/ui/vnext/ui_chrome.gd` centraliza o shell code-drawn, grid, rails de
  calibração e blocos de evidência. A camada não inventa métricas: recebe fatos
  da superfície e só define sua apresentação comum;
- Boot passou a usar o shell compartilhado e o telemetry panel passou a ser um
  bloco de evidência com dados de programa e recorde;
- Program passou a usar shell compartilhado, um bloco `MOUNT CHECK` baseado no
  estado de desbloqueio e no perfil real do programa, e sizing horizontal
  explícito para os botões do índice;
- Bestiary passou a usar shell compartilhado e um bloco `THREAT REGISTER`
  baseado na classe, ameaça e estado logged da entrada selecionada;
- Accessibility passou a usar o mesmo shell e ganhou bounds tipográficos
  suficientes para status e aviso de suporte, eliminando um overflow de altura
  que a captura visual mascarava;
- o bloco compacto de evidência foi ampliado depois de uma captura raster
  revelar que sua segunda linha (`PROFILE`/`LOAD`) ficava fora do retângulo
  útil; agora os dois fatos continuam visíveis sem encostar no rodapé;
- os rodapés narrow de Program e Bestiary agora distribuem índice/estado/build
  em três pontos distintos, em vez de reutilizar offsets de wide;
- `tools/vnext_incident_chrome_probe.gd` verifica a API compartilhada, os
  metadados semânticos, as regiões de signature/evidence e o overflow em
  1366×768 e 432×720;
- `tools/vnext_surface_capture.gd` fornece uma captura silenciosa e
  reproduzível de Boot, Program, Bestiary, Accessibility, Story e Patch, com
  recorte para uma viewport estreita quando necessário.

### Revisão da própria correção

Durante o passe houve três falhas introduzidas e corrigidas antes do green
final: a primeira versão do shell usava `shell.end` como se fosse o retângulo de
metadata e colocou rota/usuário no eixo vertical errado; a segunda manteve os
botões de Program com a largura mínima do texto; a terceira deixou apenas a
primeira linha do bloco de evidência compacto visível. As três foram
reproduzidas por captura Xvfb, corrigidas e recapturadas. O probe semântico
sozinho não teria detectado as falhas de composição, por isso a captura
continua sendo uma exigência separada.

Capturas finais desta revisão ficam fora do Git em
`/tmp/kernel-panic-ui-captures-vnext-20260902/`:

- `boot-reference.png`;
- `program-reference.png`;
- `bestiary-reference.png`;
- `accessibility-reference.png`;
- `boot-narrow-v2.png`, `program-narrow-final.png`,
  `bestiary-narrow-final.png` e `accessibility-narrow-final.png`;
- `boot-compact.png`, `program-compact-final-v3.png` e
  `bestiary-compact-final-v2.png` para a verificação intermediária de uma
  coluna;
- as imagens são evidência local efêmera: o utilitário de captura e o probe são
  versionados, mas os PNGs não entram no Git.

O resultado está mais próximo das referências porque a densidade agora é
organizada por evidência e relação entre blocos. Ainda não é uma declaração de
aprovação estética final: o cast completo, gameplay em movimento e a avaliação
humana continuam necessários.

## 7.2 Story — migração para o incidente operacional

### Motivo da alteração

A revisão comparativa foi ampliada para todas as imagens disponíveis em
`media/Ideas`, incluindo `iamgem9.png`. O veredito anterior estava incorreto ao
tratar Story como uma exceção já suficientemente próxima da referência. A
superfície tinha conteúdo funcional, mas ainda não compartilhava de forma
verificável o shell, o índice de estado e a faixa de próxima ação usados nas
outras telas. Isso mantinha justamente a sensação de telas não terminadas e
visualmente desconectadas que motivou o remake.

Antes desta etapa, Story apresentava uma composição mais próxima de um painel
de seleção vertical. Depois, a tela é uma **mount table**: o shell identifica a
rota `KP://STORY`, os atos são tabs navegáveis, os nós visíveis formam um índice
à esquerda e o nó selecionado abre um dossiê à direita. A próxima ação é
repetida como comando explícito e como evidência `STATE / ACT / NEXT`, sem
inventar dados fora dos contratos de `Game`.

### Implementação

- `src/ui/vnext/surfaces/story_surface.gd` foi recomposto, sem migrar a
  hierarquia da Story legada. O layout calcula `safe_rect`, header, tabs,
  índice, dossiê, faixa de evidência, rail de assinatura e ações a partir da
  densidade do viewport;
- os tabs `UNIX`, `WINDOWS`, `TEMPLEOS` e `MACOS` são `Button` reais, com foco,
  mouse e touch, e selecionam o ato usando os dados de desbloqueio existentes;
- o índice usa os caminhos reais das fases em desktop, estado visual explícito
  (`READY`, `LOCKED`, `CLEARED`) e tooltip com a explicação completa. Em narrow,
  o texto curto `NODE NN` evita depender de tooltip ou de uma coluna que não
  existe;
- o dossiê expõe título, path, briefing, regra, recompensa, status e melhor
  pontuação; a faixa inferior usa `Chrome.draw_evidence_block` para mostrar o
  próximo comando, ato e estado do nó;
- a composição narrow vira de fato uma navegação lista → briefing. A lista,
  a ficha, a ação `MOUNT` e o retorno ocupam estados e áreas separados; a
  superfície não espreme um mapa desktop dentro de 432 px;
- `tools/vnext_selection_probe.gd` ganhou contrato de shell/evidência, reserva
  de espaço entre dossiê e evidência, seleção de todos os quatro atos e
  verificação de fit dos dossiês reais;
- `tools/vnext_surface_capture.gd` ganhou captura Story com ato, nó selecionado
  e abertura da ficha narrow. O estado de captura é somente memória de teste e
  não altera o save do jogador.

### Revisão crítica da própria etapa

O primeiro probe negativo foi executado antes da implementação: ele produziu
27 falhas ao exigir as regiões e semântica do shell que ainda não existiam.
Isso confirmou que o teste estava verificando uma mudança real, e não apenas
repetindo o comportamento anterior.

As capturas Xvfb então revelaram problemas que o contrato semântico não poderia
provar sozinho. Foram corrigidos antes do green final:

- a lista começava no mesmo eixo do título e sobrepunha o cabeçalho `NODE
  INDEX`;
- os estados longos dos nós vazavam para fora da coluna e os botões usavam
  apenas a largura mínima do texto;
- o traço do rodapé foi inicialmente desenhado de uma origem até `Rect2.end`,
  formando uma diagonal não intencional;
- a faixa de evidência era baixa demais para três linhas legíveis;
- em narrow, `WAVES`, o rodapé e a ação `NODE LIST` competiam pelo mesmo espaço;
- o cálculo das linhas do `VBoxContainer` ignorava as separações de 6 px e
  deixava o sexto nó abaixo do frame.

Cada correção foi feita no layout/draw do mesmo surface, sem alterar regras de
story, desbloqueio, save ou lançamento. A última captura confirma que o sexto
nó fica dentro do frame e que as variantes list/detail, Windows compacto e
macOS narrow não têm colisão visual óbvia.

### Decisões e alternativas

- **Ação persistente no desktop, ação separada no narrow:** manter `MOUNT`
  junto do dossiê dá leitura imediata na referência larga; transformá-la em
  estado separado no mobile preserva legibilidade e reduz erro de toque. Uma
  coluna única fixa foi descartada porque diminuiria título, briefing e
  comando simultaneamente;
- **Estado em coluna separada no índice largo:** usar o path como label e
  desenhar o estado à direita permite comparar os nós sem truncar a explicação.
  Repetir o estado no mesmo texto foi mantido apenas no narrow, onde não há
  largura para uma segunda coluna;
- **Ato derivado do catálogo real:** os tabs usam `Game.story_stage_def()` e
  `Game.story_act_unlocked()` em vez de uma matriz visual duplicada. Uma lista
  hardcoded foi descartada porque poderia exibir um nó inexistente ou
  contradizer desbloqueios;
- **Faixa comum de evidência:** reutilizar `ui_chrome.gd` mantém a gramática
  visual entre Boot, Program, Bestiary, Accessibility e Story, mas os valores
  continuam fornecidos pela superfície. Um bloco Story desenhado isoladamente
  foi descartado para não criar mais uma variação de shell;
- **Não alterar o default:** a rota continua opt-in. A captura prova a
  composição e o contrato, mas não prova aprovação estética humana, desempenho
  em Android nem a integração de todos os fluxos legados.

### Evidência e limites

Capturas finais, fora do Git:

- `/tmp/kernel-panic-ui-captures-story/story-base-final.png` — 1280×720;
- `/tmp/kernel-panic-ui-captures-story/story-compact-final.png` — 720×720,
  Windows;
- `/tmp/kernel-panic-ui-captures-story/story-narrow-list-final.png` —
  432×720, lista de nós;
- `/tmp/kernel-panic-ui-captures-story/story-narrow-detail-final.png` —
  432×720, dossiê macOS;
- `/tmp/kernel-panic-ui-captures-story/story-macos-wide.png` — 1280×720,
  dossiê macOS em desktop.

Comprovado nesta etapa: carregamento do script, regiões do shell, ações dentro
da safe area, fit tipográfico nos três tamanhos, tabs por teclado/mouse/touch,
separação entre selecionar e montar, bloqueio de nós não liberados, transição
lista → detalhe em narrow e seleção/configuração de todos os atos.

Ainda não comprovado: touch real em aparelho, teclado virtual, safe areas com
recorte de câmera, leitura por screen reader, alteração de locale durante a
transição, scroll de uma campanha com quantidade de nós maior que o catálogo
atual e aprovação estética humana. O risco principal restante é a tela parecer
demasiado limpa ou textual em movimento; a próxima validação precisa observar
o fluxo real da campanha e não apenas uma captura estática.

## 7.3 Auditoria documental — 2026-09-02

Foi conferida a árvore do plano-mestre e os documentos de execução deste
checkpoint. O conjunto esperado está presente: `README.md`,
`00-MASTER-PLAN.md` até `13-RISK-DECISION-GOVERNANCE.md`, além de
`docs/UI-REDESIGN-DIRECTION.md`, este handoff, a release note, a revisão
consolidada e o backlog de UI.

Durante a auditoria, foi detectado que `docs/REVISAO-CONSOLIDADA-2026-08-31.md`
e `docs/UI-REVIEW-BACKLOG.md` existiam apenas como arquivos locais não
versionados no checkout original. Cópias históricas foram incorporadas nesta
branch. O `AGENTS.md` continua sendo instrução local do ambiente e não foi
promovido para documentação de produto.

Essa auditoria confirma completude estrutural da documentação, não conclusão
do plano de produto. O backlog agora distingue B1–B5 já resolvidos dos itens
pendentes; suas descrições originais permanecem preservadas para rastreabilidade
e não devem ser interpretadas como um diagnóstico atualizado sem reprodução.
O plano ainda contém trabalho futuro de refatoração total
da UI, cast completo code-drawn, história macOS, localização PT-BR,
acessibilidade de plataforma, novos inimigos, gameplay, mobile/PC, performance
e preparação de release. Este checkpoint documenta e implementa o segundo
passe da direção visual vNext e, nesta atualização, a migração da Story para a
mesma gramática de incidente operacional; o restante do plano continua aberto.

## 7.4 Patch offer — decisão de build na gramática de incidente

### Motivo da alteração

A tela de patch já tinha uma boa regra funcional — mostrar custo, benefício,
relação e impacto de build — mas ainda era uma superfície isolada. Na captura
baseline, o título competia com o limite superior em narrow, não havia
metadata de rota nem shell persistente, os comandos pareciam texto solto e a
composição não comunicava claramente que o jogador estava diante de uma pausa
de decisão. O visual também reservava espaço excessivo vazio nos cards, sem um
registro explícito da oferta selecionada.

O objetivo desta etapa foi aproximar o fluxo da referência de build decision
sem copiar valores ou coordenadas: três ofertas legíveis em desktop, uma oferta
por vez em narrow, consequência antes de confirmação, estado de conflito
explícito e comandos reais para instalar, pular ou fechar.

### Implementação

- `src/ui/vnext/surfaces/patch_surface.gd` passou a usar
  `VNextUIChrome.draw_shell()` com rota `KP://PATCH`, metadata de sistema,
  rails, grade discreta e header com estado `PAUSED // OFFER NN/NN`;
- o layout agora expõe `shell`, `shell_meta`, `header`, `body`, `cards`,
  `evidence_band`, `footer` e `signature_rail`. Desktop mantém os cards em
  paralelo; narrow conserva uma única oferta com `PREVIOUS`/`NEXT` e alvos
  touch separados dos comandos finais;
- cards passaram a ter registro de oferta, seleção visual por frame, estado
  explícito e faixa `PATCH REGISTER` na oferta selecionada. Em desktop ela
  mostra `STATE`, `BUILD` e `NEXT`; em narrow mostra `STATE` com nível e `NEXT`,
  enquanto o impacto completo continua no corpo do card;
- os comandos de instalação, skip e close continuam sendo `Button` reais e
  agora têm frame code-drawn, foco visível e cores redundantes para estado
  pronto/bloqueado. `CLOSE [ESC]` fica no header em desktop e vira `CLOSE` em
  narrow para evitar colisão;
- a tipografia narrow foi encurtada para `PATCH // DECISION` e
  `READ THE COST BEFORE INSTALL`; o conteúdo do card reduz apenas informação
  redundante de nível, preservando a consequência e mantendo o nível no
  registro de estado;
- `tools/vnext_surface_capture.gd` ganhou a rota de captura `patch` com três
  ofertas determinísticas, estado de build e seleção configurável. A captura
  não toca no estado persistido do jogador;
- `tools/vnext_patch_probe.gd` ganhou contrato do shell, semântica da rota,
  regiões da faixa de evidência, diagnóstico de overflow com medidas e
  containment dos comandos.

### Revisão crítica da própria etapa

O probe foi ampliado antes do código e reproduziu 12 falhas: ausência das
regiões de shell/evidência e da semântica `reference_shell`/`KP://PATCH`.
Depois da primeira implementação, o próprio relatório encontrou um botão
`CLOSE [ESC]` maior que sua área e conteúdo de card que entrava na faixa de
evidência. Em narrow, o título ainda media duas linhas e os campos `RELATION`,
`BUILD IMPACT` e `LEVEL` excediam a região reservada.

Esses casos foram corrigidos com evidência adicional, não ignorados:

- a largura do close foi ajustada para respeitar a largura mínima real do
  `Button` e a safe area;
- as alturas base e os espaçamentos dos campos foram recalibrados, com
  `text_overflow_report()` incluindo altura medida, largura disponível,
  limite de conteúdo e fundo da faixa;
- o nível foi incorporado ao estado da faixa narrow e retirado do corpo apenas
  nessa densidade, preservando a informação sem competir com a consequência;
- três capturas raster foram revisadas: `/tmp/kernel-panic-ui-captures-patch/patch-after-wide.png`,
  `patch-after-compact.png` e `patch-after-narrow.png`. A revisão visual não
  encontrou clipping ou colisão óbvia nas três composições; o compacto continua
  mais denso por necessidade e merece teste em dispositivo real.

### Decisões e alternativas

- **Faixa de registro na oferta selecionada:** foi escolhida para conectar a
  decisão ao build atual sem repetir todos os dados em um quarto painel. Uma
  faixa global foi descartada porque atravessaria o espaço entre cards e
  pareceria pertencer a todas as ofertas ao mesmo tempo;
- **Dois modos de densidade para a faixa:** três linhas cabem com segurança em
  desktop; narrow usa duas linhas e inclui o nível no estado. Forçar três linhas
  no telefone reduziria o corpo do card ou criaria texto microscópico;
- **Cards em paralelo no compacto:** mantidos porque a captura 720×720 ainda
  conserva leitura mensurável e a navegação lateral seria mais lenta para a
  decisão; se a avaliação humana apontar leitura insuficiente, o próximo passe
  deve promover o compacto para a composição narrow;
- **Build derivado do snapshot:** a superfície só apresenta o build e os
  impactos recebidos de `Arena/Game`; não calcula nem muta regras de patch. Isso
  preserva a responsabilidade da Arena e evita divergência entre preview e
  aplicação real;
- **Rota opt-in:** a recomposição não altera o caminho legado nem o momento de
  pausa/retomada. O probe real da Arena confirmou close, skip e confirm, mas a
  promoção ao default continua dependente de revisão estética e mobile.

### Evidência e limites

Comprovado: probe visual/semântico com 0 falhas, três cards sem sobreposição,
containment dos comandos, fit tipográfico em 1280×720 e 432×720, estados
locked/conflict, foco de oferta sem confirmação, confirmação única,
close/skip/retry, navegação mouse/touch, reflow narrow → desktop e isolamento
profundo do snapshot. O probe real da Arena também passou com 18 verificações.

Não comprovado: toque físico, teclado virtual, safe area de recorte, leitura
com screen reader, alteração de locale durante a oferta e comportamento com
mais de três ofertas simultâneas. As capturas usam conteúdo inglês sintético e
não substituem a avaliação do texto PT-BR nem a verificação do fluxo real em
uma run completa.

## 7.5 Combat HUD — tradução da referência de combate para a arena real

### Motivo da alteração

A primeira versão da superfície de combate já tinha um contrato funcional,
mas a captura mostrava o problema que motivou a revisão: o espaço estava quase
vazio, a leitura do combo não tinha instrumento próprio, patches não tinham um
dock visual, e a ameaça não tinha um registro no mesmo idioma operacional das
referências. Além disso, o HUD legado continuava desenhando um indicador de
dash por cima da superfície opt-in.

O objetivo deste passe foi aproximar o HUD da densidade intencional de
`imagem5.png` sem copiar a imagem como fundo. O centro segue limpo para player,
inimigos, projéteis e pickups; a informação contínua se distribui no
perímetro; e eventos recentes ganham um bloco próprio.

### Implementação

- `src/ui/vnext/surfaces/combat_hud_surface.gd` agora desenha a moldura
  angular, rails de calibração, ticks laterais e telemetria inferior;
- o bloco de integrity exibe HP numérico, até 12 pips, direção do último dano,
  programa e meter segmentado com estado `EMPTY`, `CHARGING` ou `FULL`;
- o combo recebeu bloco dedicado, `COMBO xN`, estado de cadeia e barra de
  progresso segmentada alimentada pela fração real de `_combo_frac`;
- o evento temporário fica separado do `CYCLE NN` contínuo, que é mantido no
  patch dock para não duplicar a mesma informação em dois lugares fortes;
- o patch dock mostra ciclo, `PATCH DOCK`, até quatro chips com glyphs próprios e
  status online; os chips são derivados do snapshot/`Game.patch_levels`;
- ability/dash ganhou chevrons code-drawn, estado textual, hint de input e
  carga segmentada. O indicador legado é ocultado durante o modo vNext para não
  duplicar a mesma ação;
- score mostra pontuação, tempo e seed/run; o boss register fica acima da
  arena, com título, fase e uma ou várias barras de vida para split boss;
- o layout passou a calcular um `reserved_playfield` real, evitando que o
  registro de boss ou os cartões inferiores consumam o centro reservado;
- narrow regular mantém labels completos quando 432×720 comporta a cópia;
  micro-narrow usa abreviações controladas e empilha os painéis em 320×568;
  escalas de texto acima de 110% também podem usar essas abreviações quando
  necessário para preservar o fit;
- `src/ui/hud.gd` sincroniza combo fraction/footer e não reativa o
  `_dash_icon` legado quando `KP_VNEXT_HUD=1`;
- o probe e a fixture de captura foram atualizados para testar a cadeia real,
  não apenas o desenho isolado.

### Revisão crítica da própria etapa

O primeiro teste da matriz ampliada reproduziu uma colisão real em 320×568.
Não foi mascarada removendo o viewport da matriz: foi criado um breakpoint
micro-narrow e os painéis foram empilhados. A primeira compactação textual
também quebrou o contrato E3 ao trocar `SHIELD READY` por `SH RDY` em 432 px;
o validador acumulado ficou vermelho, a causa foi isolada e a abreviação foi
restringida ao micro-narrow ou a escalas de texto em que a cópia completa não
cabia.

Outra revisão feita por captura Xvfb revelou o problema de coordenadas da
fixture: executar uma janela física de 320 px fazia o próprio stretch do
projeto reduzir a composição lógica. A captura final foi refeita com uma
janela de renderização suficiente e recorte lógico de 320×568, separando a
validação de composição da validação do stretch físico. Isso evita concluir
erroneamente que uma captura reduzida é um problema do layout quando é a
fixture que está aplicando duas escalas.

### Decisões e alternativas

- **Perímetro em vez de painel central:** escolhido para preservar a área de
  combate e refletir a referência; uma grande caixa central foi descartada
  porque competiria com a leitura de ameaça;
- **Boss acima da arena:** escolhido para dar uma âncora de perigo sem colidir
  com ability/score; manter o boss no rodapé foi descartado depois de observar
  disputa com os controles;
- **Patch chips em vez de texto corrido:** escolhido para permitir comparação
  rápida e glyphs sem inventar uma nova tela; o texto completo continua
  disponível no estado/patch surfaces;
- **Snapshot do Hud como autoridade:** escolhido para não duplicar gameplay;
  acesso direto a Arena e reimplementação de combo/dash foram descartados;
- **Micro-narrow empilhado:** escolhido com base na falha geométrica observada;
  esconder módulos críticos ou reduzir tudo para microtexto foi descartado.

### Evidência e limites

Comprovado nesta etapa: 75 checks do probe do HUD, incluindo HP 1–12, meter,
dash, combo, patches, boss split, safe area, não sobreposição, reflow,
text-scale 115%, micro-narrow 320×568, input, sync por programa, banner/ciclo,
damage direction e Arena real; E3 voltou a 35 checks verdes; a validação
acumulada passou todos os grupos depois da correção do E3. Capturas limpas
foram inspecionadas em 1280×720, 432×720 e 320×568 lógico.

Capturas finais fora do Git:

- `/tmp/kernel-panic-ui-captures-hud-final/hud-reference-pass-1280x720.png`;
- `/tmp/kernel-panic-ui-captures-hud-final/hud-reference-pass-432x720.png`;
- `/tmp/kernel-panic-ui-captures-hud-final/hud-reference-pass-micro-logical-v3.png`;
- `/tmp/kernel-panic-ui-captures-hud/hud-runtime-vnext-v2.png` — Arena real,
  sem o indicador legado duplicado.

Ainda não comprovado: touchscreen Android, safe area de câmera, orientação
landscape em aparelho, fontes fallback, text scale 150–200% no micro-narrow,
FPS em Vega integrado/Android e qualidade da leitura em movimento intenso.
Teardown diagnostics continuam sendo reportados separadamente.

## 7.6 Bugs de fluxo — prompt morto e confirmação destrutiva

### B6 — prompt de inicialização do menu nunca aparecia

**Antes:** `src/ui/menu.gd` criava `_prompt` e o `MenuChromeKit` calculava um
retângulo válido para ele, mas `_process()` executava `_prompt.visible = false`
em todos os frames. A informação essencial para descobrir que ENTER inicia a
run ficava ausente na rota legada, embora a geometria existisse.

**Fix:** o menu agora decide a visibilidade pelo estado real da rota: o prompt
aparece no menu principal legado, some quando um overlay (settings, Program,
Story, Bestiary ou Awards) está aberto e não aparece durante a transição de
boot. O texto padrão foi centralizado para desktop e touch. Um pulso de baixa
amplitude melhora a descoberta sem competir com `PURGE`; a posição continua
sendo dona do `apply_menu_layout()`.

**Evidência:** o probe red em
`/tmp/kernel-panic-ui-b6-red.log` reproduziu 4 falhas (prompt idle, guard de
ESC, restauração após expiração e retorno após overlay). O probe green em
`/tmp/kernel-panic-ui-b6-green.log` terminou com `PROBE_DONE fails=0`, incluindo
retângulo não vazio e todos os estados de overlay.

**Impacto e risco:** somente a apresentação e a descoberta do comando mudam;
nenhum input de boot ou estado de save foi alterado. A mensagem touch foi
consolidada, mas texto e safe area em um aparelho real ainda precisam de
revisão com fonte fallback.

### B7 — ações destrutivas do pause aceitavam confirmação acidental

**Antes:** o primeiro `R` durante a pausa reiniciava imediatamente a run. O
primeiro `Q` armava abandono, porém um segundo acionamento sem intervalo podia
ser interpretado como confirmação; o mesmo valia para dois sinais consecutivos
do botão `ABANDON PROCESS`.

**Fix:** restart e abandon agora compartilham um único estado interno de ação
destrutiva: ação armada, janela de 2 segundos, timestamp monotônico e callback
de expiração protegido por geração. O primeiro `R` apenas arma e mantém a
árvore pausada; outro `R` confirma somente após 0,5 s. `Q` mantém a mesma
semântica de armamento, e confirmações de abandon também ignoram uma segunda
ativação dentro de 0,5 s. Echo/release de teclado não confirmam. A pausa
legada e a superfície vNext mostram a instrução específica (`PRESS R AGAIN`
ou `PRESS Q AGAIN`) e o restart da superfície vNext passou a usar a mesma
regra.

**Evidência:**

- `/tmp/kernel-panic-ui-b7-red2.log` reproduziu as três falhas do novo contrato
  de restart antes do fix;
- `/tmp/kernel-panic-ui-b7-click3.log` terminou com 38 passes e
  `PROBE_DONE fails=0`, cobrindo o botão, Q, echo Q, expiração, restart armado,
  echo R, segunda ativação rápida e confirmação após o intervalo;
- `/tmp/kernel-panic-ui-b7-suite-green.log` terminou com 1454 `AT_PASS`, sem
  `AT_FAIL` e `AUTOTEST_ALL_PASS`; os diagnósticos finais foram somente de
  teardown, separados pelo validador;
- a superfície U4 continuou com 0 falhas em
  `/tmp/kernel-panic-ui-b7-u4.log`.

**Decisão e trade-off:** uma janela comum torna o comportamento previsível e
evita duas implementações de confirmação divergentes. O intervalo também se
aplica ao teclado porque a origem do `Button.pressed` não é confiavelmente
distinguível no callback compartilhado; isso é deliberadamente mais seguro,
mas torna uma confirmação digitada muito rápida inválida. O probe usa o sinal
real do Button para testar o callback; o roteamento nativo de ponteiro em um
display físico e gestos touch continuam sendo validação de plataforma.

**Compatibilidade:** não há mudança de schema/save. Há uma mudança intencional
de UX: reiniciar pela pausa deixou de ser uma ação de um toque e exige duas
ativações deliberadas, igual ao abandono. O restart por `hold R` durante
gameplay continua sendo um caminho separado de speedrun e não foi alterado.

## 7.7 H1 — hierarquia do anúncio de ciclo no HUD legado

### Problema confirmado

O HUD legado desenhava `CYCLE NN` como estado contínuo no encounter panel e o
`Arena._on_wave_started()` enviava a mesma informação de novo no banner grande
(`CYCLE NN` ou `CYCLE NN // ANOMALY`). Em uma tela de combate com pouco texto,
essa repetição fazia o anúncio parecer mais importante do que o evento e
ocupava duas âncoras fortes para uma única informação.

### Alteração

- `src/arena/arena.gd` agora usa `WAVE INBOUND` + `PURGE THE DAEMONS` para uma
  onda normal e `ANOMALY INBOUND` + `ROOT DAEMON INBOUND` para um boss;
- `CYCLE NN` continua sendo calculado e desenhado no encounter panel, então o
  jogador não perde a leitura do ciclo atual;
- o título do boss continua sendo um evento nomeado, não foi substituído por
  um rótulo genérico;
- `src/ui/vnext/surfaces/combat_hud_surface.gd` deixou de tratar qualquer texto
  contendo `WAVE ` como um ciclo descartável. Ele só remove a forma legada
  quando o banner começa exatamente com `CYCLE `; anúncios nomeados e Story
  permanecem no registro temporário;
- `tools/hud_hierarchy_probe.gd` cobre o Arena real no modo legado e verifica
  onda normal, onda de boss, subtítulos, estado do ciclo e ausência de
  duplicação;
- `tools/vnext_combat_hud_probe.gd` cobre também a diferença entre um banner
  legado `CYCLE 02` e um evento nomeado `WAVE INBOUND` no adapter.

### Decisão e alternativas

A decisão foi remover somente a informação contínua do banner, preservando um
nome curto para o evento. Trocar o banner por silêncio reduziria a duplicação,
mas perderia feedback de início de onda; mover `CYCLE` para fora do HUD
eliminaria a âncora contínua usada para orientar o jogador; e manter a forma
antiga deixaria a falha de hierarquia intacta. O adapter vNext conserva uma
regra de compatibilidade para banners antigos, mas não faz uma heurística ampla
com a palavra `WAVE`, porque isso apagava eventos legítimos de Story e de onda.

### Evidência e limites

`res://tools/hud_hierarchy_probe.tscn` terminou com 10 passes e zero falhas em
headless silencioso. O probe criou uma Arena real, confirmou o HUD legado,
acionou onda normal e boss pelo método de produção e inspecionou os textos
resultantes. O probe vNext terminou com zero falhas após validar os dois
formatos do adapter. `git diff --check` também passou.

O teste é semântico e não substitui uma captura humana em todos os tamanhos.
Ele não prova que o texto traduzido para PT-BR caberá nas mesmas linhas; isso
continua parte da etapa de localização e do passe H5.

### Impacto

Não há alteração de gameplay, save, balanceamento, input, API pública ou
compatibilidade de dados. A mudança observável é o texto do anúncio de início
de onda/boss. Os banners de clear, Story e unlock continuam sendo eventos
temporários. O caminho vNext mantém compatibilidade com chamadas antigas de
`show_banner()`.

## 7.8 H2 — legibilidade e limite do texto secundário do HUD

### Problema confirmado

O event log do HUD legado imprimia as últimas linhas com `MUTED` e largura
fixa, sem medir o texto antes de desenhá-lo. A fonte podia ficar pouco
contrastada e payloads longos podiam escapar do registro ou depender do
clipping do renderer. O tooltip dos patches tinha o mesmo problema: título,
descrição e relação eram desenhados diretamente, embora cada linha pudesse
ser arbitrariamente longa.

### Alteração

- `Hud.visible_event_lines()` aceita uma largura e um tamanho de fonte
  opcionais; quando fornecidos, aplica `TacticalUIHelper.ellipsis_fit()` à
  linha completa, incluindo timestamp;
- o event log passa a calcular `score_rect.size.x - 28` e desenhar com alpha
  explícito `0.82`, em vez de depender do alpha mutado de `MUTED`;
- `Hud.tooltip_text_snapshot()` produz cópias medidas para título, detalhe e
  relação, cada uma com seu tamanho de fonte real;
- `_draw_patch_tooltip()` usa esse snapshot e cores com alpha explícito entre
  `0.86` e `0.92`;
- `tools/hud_legibility_probe.gd` cobre entradas normais, payload longo,
  marcador de reticências, largura medida e as três linhas do tooltip;
- `tools/validate_input_dispatch.sh` executa o novo probe junto da validação
  acumulada.

### Decisão e alternativas

Foi escolhido truncamento semântico no limite do painel. Quebrar o event log em
duas linhas exigiria redesenhar sua altura e poderia colidir com o restante do
HUD; reduzir globalmente a fonte prejudicaria a leitura de mensagens normais;
deixar o renderer cortar esconderia a informação sem avisar o jogador. O
snapshot do tooltip evita duplicar a regra de medição entre teste e desenho,
mas não vira uma segunda fonte de conteúdo: ele só transforma os dados que já
estão em `_tooltip_data`.

### Evidência e limites

`res://tools/hud_legibility_probe.tscn` terminou com 8 passes e zero falhas em
headless silencioso. O probe mediu a largura renderizada com a mesma fonte e
tamanho usados pelo HUD e confirmou o marcador `…` para event log e tooltip.
`git diff --check` e a verificação de importação do editor passaram.

Isso prova o contrato tipográfico para as larguras exercitadas, não a qualidade
editorial do texto, leitura em movimento ou contraste percebido em todos os
monitores. O probe não substitui grayscale/high-contrast nem uma captura em
dispositivo móvel; H5 ainda precisa revisar os módulos que podem disputar
espaço com o event log e tooltip.

### Impacto

Não há alteração de gameplay, save, input ou balanceamento. A apresentação de
mensagens longas muda de clipping implícito para reticências explícitas, e o
texto secundário fica mais legível. `visible_event_lines()` sem argumentos
continua retornando o conteúdo completo para consumidores de diagnóstico; a
limitação só é aplicada quando o desenho fornece a largura real.

## 7.9 H3 — auditoria da escala do HUD contra o stretch

### Hipótese revisada

O veredito inicial tratava a diferença entre o espaço local do HUD e o espaço
dos painéis como um erro: o HUD parecia usar pixels da janela enquanto os
overlays usavam o canvas lógico de `1280×720`. A revisão consolidada, porém,
registrou que essa compensação podia ser intencional. Alterar a escala sem
medir poderia quebrar justamente o caso mobile, onde `canvas_items` com
`aspect=expand` cria uma viewport lógica alta.

### Verificação

`tools/hud_scale_matrix_probe.gd` passou a registrar, para `1280×720`,
`1600×900`, `1920×1080`, `432×720` e `720×720`:

- tamanho físico pedido e tamanho de janela observado;
- tamanho local do `Hud`;
- escala aplicada pelo compensador;
- tamanho efetivo no canvas, calculado pelo `get_global_transform_with_canvas()`;
- layout calculado para viewports de referência.

Em Xvfb, os tamanhos wide/ultrawide foram compensados para o viewport lógico
`1280×720`; portrait foi compensado para a viewport expandida `1280×2133`
ou equivalente. A escala permaneceu uniforme e o tamanho efetivo coincidiu
com a viewport em todas as amostras. O mesmo probe headless mantém a cobertura
da matemática sem depender de uma janela física.

### Decisão

H3 foi encerrado como hipótese não reproduzida, não como um convite para
remover `_apply_surface_transform()`. O código existente já faz a adaptação
necessária para o stretch e o HUD vNext usa a mesma ideia explicitamente em
`_fit_vnext_surface()`. A alternativa de converter tudo para design px foi
descartada neste ponto porque perderia a distinção entre janela portrait e
canvas expandido antes de existir uma matriz de export real.

### Evidência e limites

O probe terminou com 24 passes headless e 29 passes no Xvfb wide, zero falhas.
O validador agora executa as duas modalidades; o log Xvfb é
`.godot/codex-review-lote-1/probe-h3-hud-scale-matrix-xvfb.log` quando a suíte
é rodada no checkout. Isso comprova invariantes de transformação, não a
hierarquia estética percebida nem a legibilidade de cada módulo em um monitor
4K ou aparelho Android. H5 continua responsável por verificar colisões depois
da transformação, e export/safe area físicos ainda estão abertos.

### Impacto

Nenhum arquivo de produção foi alterado por H3. O resultado importante é evitar
um regressão especulativa: a implementação atual permanece, agora com um
contrato automatizado que impede uma alteração futura de tornar a transformação
não uniforme ou desconectada do viewport.

## 7.10 H4 — estados do HUD sem depender somente de cor

### Problema confirmado

No HUD legado, integridade baixa, dash em recarga e overclock pronto/ativo eram
comunicados principalmente por cor, alpha e preenchimento de barra. Isso falha
para daltonismo, grayscale, redução de efeitos e leitura rápida em telas
pequenas. O caso Rootlet tinha um agravante: `Hud._process()` lia sempre
`player.meter` e o texto da habilidade era genérico, então a prontidão do
escudo não tinha uma representação textual equivalente à do overclock.

### Alteração

- `src/ui/hud.gd` agora separa o estado do escudo do estado de overclock ao
  sincronizar o jogador; Rootlet usa `shield_meter`, e um escudo pronto é
  representado como medidor cheio sem inventar um valor de gameplay;
- a moldura de integridade expõe `INTEGRITY // STABLE`, `LOW` ou `CRITICAL`;
  quando existe dano recente, acrescenta `HIT FROM E`, `SE`, `S` etc. usando a
  direção real já calculada pelo HUD;
- o instrumento de habilidade expõe `SHIELD READY`, `SHIELD CHARGING`,
  `SHIELD DOWN`, `OVERCLOCK READY`, `OVERCLOCK ACTIVE` ou
  `OVERCLOCK CHARGING`, mantendo cor e preenchimento como reforço visual;
- o módulo de dash expõe `DASH // READY` ou `DASH // COOLDOWN`, sem depender do
  alpha do pip;
- `state_signal_snapshot()` fornece uma leitura somente de estado para testes e
  futuras camadas de acessibilidade. Não é uma nova fonte de autoridade e não
  altera o fluxo de combate;
- o texto da habilidade passa por `TacticalUIHelper.ellipsis_fit()` dentro da
  largura real do instrumento;
- `tools/hud_state_signal_probe.gd/.tscn` verifica o HUD isolado, dano por uma
  Arena real e a prontidão inicial do Rootlet; o validador acumulado executa o
  probe silenciosamente.

### Decisão e alternativas

Foi mantida a linguagem code-drawn existente — cor, alpha, barra e pulso — e
acrescentada uma camada textual curta. Um glyph isolado seria compacto, mas
exigiria uma legenda e seria menos claro para estados compostos; somente subir
contraste não resolve grayscale nem leitura sem cor; um widget separado de
acessibilidade duplicaria a lógica do HUD. O texto foi escolhido como sinal
redundante e os nomes foram mantidos curtos para não forçar uma nova coluna no
combate. A direção cardinal é derivada do ponto de origem do dano, não de uma
animação presumida.

### Evidência e limites

`res://tools/hud_state_signal_probe.tscn` terminou com 12 passes e zero falhas
em headless silencioso. O mesmo passe também reexecutou o contrato do HUD vNext
com `KP_VNEXT_HUD=1`: 77 passes, zero falhas. Isso comprova os estados e a
integração de dados nos caminhos testados, mas não substitui revisão humana em
grayscale, tamanho de texto aumentado, PT-BR ou Android real. O texto ainda é
inglês até a etapa de localização.

### Impacto

Não há alteração de gameplay, balanceamento, save, input ou API de jogo. A
mudança observável é uma comunicação redundante e mais explícita dos estados do
HUD. Para Rootlet, a barra agora representa a carga do escudo em vez do meter
de overclock. O custo é apenas algumas medições e strings no desenho; nenhum
asset raster ou dependência externa foi adicionado. A compatibilidade de dados
permanece intacta.

## 7.11 H5 — colisões de layout em HUD, game-over e touch

### Problemas confirmados por inspeção geométrica

O HUD legado tinha quatro pontos em que a composição dependia de uma largura
desktop implícita: o toast de achievement recebia `430px` mesmo quando a tela
compacta tinha menos espaço; os pips usavam um espaçamento mínimo de `22px`,
fazendo os últimos pips passarem do painel quando a integridade crescia; o
SCRAP tinha barra fixa de `86px` e texto sem limite; e os stats do game-over
eram posicionados por offsets em torno do centro, com `408px` de deslocamento
para a segunda coluna, em vez de serem derivados do painel estreito. Nesse
último caso, a largura menor que `760px` podia colocar os labels fora da janela
e mantinha botões longos em duas colunas apertadas.

O alvo de pausa dos controles touch foi comparado à faixa reservada para o
banner temporário. Ele fica no topo, enquanto o banner compacto começa abaixo
do encounter register; não houve colisão reproduzida nessa relação e nenhuma
mudança especulativa foi aplicada ao input touch.

### Alteração

- `src/ui/hud.gd` passou a centralizar `collision_layout_snapshot()`, com
  retângulos de safe area, banner, toast, pips e SCRAP. O toast é colocado
  depois do espaço reservado ao banner, recebe a largura segura real e usa
  reticências quando o achievement é longo;
- o banner compacto usa `_banner_base_y` calculado, não um `186px` fixo no
  caminho de animação. Isso evita que o subtítulo ocupe o mesmo espaço do
  toast em portrait;
- `hp_pip_rects()` limita o espaçamento ao intervalo disponível entre as duas
  margens do painel e reduz o raio apenas quando a densidade exige. Todos os
  pips continuam existindo; nenhum ponto de vida é descartado;
- `scrap_layout()` calcula a largura que sobra antes da margem direita, e a
  barra e o texto usam o mesmo retângulo medido. O texto também passa por
  `ellipsis_fit()`;
- `src/ui/tactical_state_surface.gd` agora expõe retângulos de seções/stats do
  game-over. Em viewport estreita, os dois blocos e as duas ações são
  empilhados; em viewport wide, a composição de duas colunas permanece;
- `src/arena/panel_kit.gd` posiciona os labels e botões pelo mesmo contrato
  geométrico e `Arena._refresh_responsive_layout()` relayouta o game-over após
  resize, não apenas a pausa;
- `tools/hud_layout_collision_probe.gd/.tscn` mede os cinco tamanhos de
  viewport, do HUD legado e do alvo touch ao estado de game-over. O validador
  acumulado executa esse contrato em modo silencioso.

### Decisão e alternativas

Foi escolhido um contrato de retângulos compartilhado entre desenho, controles
e probe. Corrigir apenas o `offset_right` do toast resolveria um caso, mas
deixaria pips, SCRAP e game-over usando regras divergentes. Manter duas colunas
no game-over exigiria reduzir os labels a um tamanho que prejudicaria a leitura;
empilhar só em telas estreitas preserva a composição desktop e torna a ordem de
leitura explícita. Para os pips, remover os extras ou exibir apenas um contador
seria mais barato, mas esconderia a granularidade que o HUD já comunica; o
espaçamento limitado e o raio adaptativo preservam todos os estados.

O alvo touch não foi movido sem evidência: o probe compara a geometria real do
`TouchControls._pause_btn()` com a faixa de banner para evitar transformar uma
hipótese visual em regressão de input.

### Evidência e limites

`res://tools/hud_layout_collision_probe.tscn` terminou com 69 passes e zero
falhas em `320×568`, `432×720`, `600×600`, `800×600` e `1280×720`. Foram
verificados: toast dentro da safe area e fora do banner; doze pips ainda
representados e dentro do painel; barra e label SCRAP dentro da janela; pausa
touch fora do banner; stats e ações do game-over dentro do painel/viewport e
sem sobreposição. `git diff --check` passou.

Isso é evidência geométrica e não prova de acabamento visual em cada export. O
probe ainda é headless; safe areas de notch, rotação, ponteiro touch nativo,
texto PT-BR e alturas extremas de landscape precisam de validação de
plataforma. O texto do HUD segue em inglês até a etapa de localização.

### Impacto

Não há alteração de gameplay, balanceamento, save ou semântica de input. Há
mudança visual e de ordem de leitura no game-over estreito: stats e ações agora
formam uma coluna. Achievements e SCRAP passam a truncar de modo explícito em
vez de depender do clipping do renderer. O custo de desenho é marginal; não há
asset novo, dependência externa ou breaking change de dados.

## 7.12 H6 — camadas de efeito e estados modais

### Problema confirmado

`ArenaOverlay` vive na `CanvasLayer` 80, acima dos painéis legados de pausa e
game-over (layer 60), do terminal (66) e do patch (65). Portanto, mesmo quando
um modal estava legível em termos de geometria, a vinheta de low-HP, a
aberração cromática e o pulso de dano ainda eram compostos por cima dele. O
mesmo problema aparecia no watermark de Windows, criado na layer 76: o texto
intermitente continuava aparecendo sobre pausa, terminal e game-over. A ordem
numérica das layers não era uma política de estado; qualquer novo painel abaixo
da layer 80 herdaria a mesma colisão.

### Decisão

Foi escolhido um contrato explícito de estado modal, em vez de apenas mover
layers. `Arena` mantém `_state_panel_active` e notifica o `ArenaOverlay` quando
pausa, terminal, patch, game-over, vitória de história ou falha de salvamento
passam a ocupar a leitura principal. O overlay conserva sua layer para não
alterar a composição de gameplay, mas esconde o seu `ColorRect` de tela durante
o modal. A Arena também centraliza a visibilidade do watermark: ele só pode
aparecer durante gameplay e no intervalo temporal original.

Alternativas consideradas:

- mover o overlay para uma layer abaixo de todos os painéis; descartado porque
  criaria novas regras implícitas para reticle, debug, CRT e superfícies vNext,
  além de remover efeitos de gameplay por acidente;
- zerar apenas `aberr`, `hurt` e `low_hp`; descartado porque o shader ainda
  aplicaria scanlines/vignette e continuaria sendo uma composição visual sobre
  o texto do modal;
- testar somente a layer numérica; descartado porque isso não provaria a
  visibilidade real do watermark nem a transição de terminal/patch;
- ocultar o overlay permanentemente quando a Arena inicia; descartado porque
  remove o feedback de dano e low-HP do combate normal.

A escolha de esconder o retângulo inteiro é deliberada: a prioridade de um
modal é leitura e ação inequívoca, e os efeitos visuais não carregam estado
necessário enquanto o jogo está congelado. Ao retomar, a mesma chamada restaura
o retângulo e a regra temporal do watermark.

### Implementação

- `src/arena/arena_overlay.gd` agora mantém referência ao retângulo do shader,
  expõe `set_state_panel_active()`, `state_panel_active()` e
  `visual_effect_visible()`, e alterna somente a camada visual efetiva; a
  lógica de pulsos e seus parâmetros não foi reescrita;
- `src/arena/arena.gd` adiciona `_state_panel_active`, o sincronizador
  `_set_state_panel_active()` e `_update_windows_watermark_visibility()`. As
  transições de patch, pausa, game-over, vitória e falha de save passam pelo
  sincronizador;
- `src/arena/panel_kit.gd` marca o terminal como modal ao abrir. Fechar o
  terminal enquanto a pausa permanece ativa não libera o overlay antes da hora;
  somente retomar a run faz a transição para gameplay;
- `tools/overlay_layer_probe.gd/.tscn` cobre o contrato unitário e a integração
  com duas Arenas reais: pausa/terminal/resume, game-over e o estágio Windows
  com watermark.

### Evidência red → green

Antes do fix, o probe já conseguia carregar o overlay e a Arena, mas falhava em
8 checks: não existia contrato de estado, a pausa não marcava a modalidade, o
terminal e game-over não a propagavam, e o watermark não tinha supressão. O
processo terminou com `PROBE_DONE fails=8`. Depois do fix,
`res://tools/overlay_layer_probe.tscn` terminou com 25 passes, zero falhas e
exit 0 em headless silencioso. Foram comprovados: camada 80 preservada,
retângulo visível fora do modal, retângulo oculto durante pause/terminal/
game-over, restauração no resume, watermark oculto durante modal e restaurado
no gameplay.

### Impacto, limites e risco residual

Não há mudança em gameplay, física, balanceamento, save, input ou ordem de
desenho durante a run. Há uma mudança visual intencional: a tela deixa de sofrer
efeitos CRT/low-HP enquanto um painel modal está aberto. A camada de CRT
específica do estágio continua independente; este item trata o overlay de
feedback global e o watermark.

O teste automatizado não substitui uma captura visual em export Android, uma
janela com notch ou uma sequência de morte real no dispositivo. O estado
modal é atualizado por todas as transições conhecidas no código atual, mas
qualquer novo painel futuro precisa chamar `_set_state_panel_active(true)` ou
ser incluído na política; o probe existe para tornar essa omissão detectável.

## 10. Próximos passos recomendados

### Para avaliação do usuário

- dizer se a composição do boot finalmente remete à referência sem parecer
  vazia;
- avaliar se o contraste entre índice/dossiê/comando funciona de primeira;
- apontar quais entidades ainda parecem genéricas quando vistas em gameplay;
- testar se o narrow é legível e confortável, não apenas “sem clipping”;
- decidir se a rota vNext pode substituir a legada por grupo de telas ou se
  precisa de mais um passe visual.
- verificar se o fluxo `act → node → dossier → mount` explica a progressão sem
  exigir que o jogador conheça a estrutura interna da campanha;
- comparar a leitura de `READY`, `LOCKED` e `CLEARED` em grayscale e com
  redução de efeitos.

### Para implementação posterior

- ampliar o passe de arte code-drawn para todo o cast, com estados de ataque,
  hit, elite, telegraph e grayscale;
- aplicar o mesmo critério de captura e revisão às telas restantes e ao HUD em
  movimento, mantendo a composição do patch e combat HUD consistente com o shell;
- fechar a migração das telas restantes e só depois remover os switches;
- completar PT-BR de todos os textos player-facing;
- validar touch, safe area, export e performance em Android real;
- investigar teardown em categorias por ownership e fazer probes de lifecycle;
- extrair somente as primitivas de shell que se provarem idênticas;
- preparar release candidate, changelog consolidado e checklist de rollback.

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
| `imagem5.png` | HUD encosta nas bordas e libera o centro para combate | o HUD existente foi preservado como fonte de estado e validado junto dos overlays; o adapter da Arena agora também usa fit físico coerente |
| `imagem6.png` | pausa dramática, jogo ainda visível, contexto da run e poucas decisões | `pause_surface.gd` continua com contexto congelado, ação curta e estado do programa; título agora se ajusta à largura real |
| `imagem8.png` | terminal diegético com stream, comandos, status, prompt e histórico | `terminal_surface.gd` preserva a workstation e evita colisão do título com `CLOSE [ESC]` em narrow |
| `iamgem9.png` | mapa de story com rota, tabs de eras e briefing | a superfície story já existente foi preservada por estar visualmente próxima da referência e continua coberta pelo probe de seleção |
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

### 3.7 Arte code-drawn

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

### 3.8 Probes e validador

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
- `tools/validate_input_dispatch.sh` — inclui boot, selection, Bestiary,
  integração de menu e os dois probes de resize físico.

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
| DevHarness `--autotest` | exit 0, `1453 AT_PASS`, `0 AT_FAIL`, `AUTOTEST_ALL_PASS` |
| Input dispatch headless | exit 0, 32 passes, 0 fails |
| Input dispatch Xvfb/debug | exit 0, 34 passes, 0 fails; debug desktop confirmado |
| Boot reference shell | exit 0, 102 passes, 0 fails |
| Program + Story selection | exit 0, 168 passes, 0 fails |
| Bestiary reference shell | exit 0, 128 passes, 0 fails |
| Menu route integration | exit 0, 22 passes, 0 fails |
| Patch surface | exit 0, 52 passes, 0 fails |
| Patch Arena adapter | exit 0, 19 passes, 0 fails |
| Combat HUD adapter | exit 0, 48 passes, 0 fails |
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
- HUD wide: `/tmp/kernel-panic-ui-captures.XrrC6t/hud-wide.png`;
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
  reproduzível de Boot, Program, Bestiary e Accessibility, com recorte para
  uma viewport estreita quando necessário.

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

## 7.2 Auditoria documental — 2026-09-02

Foi conferida a árvore do plano-mestre e os documentos de execução deste
checkpoint. O conjunto esperado está presente: `README.md`,
`00-MASTER-PLAN.md` até `13-RISK-DECISION-GOVERNANCE.md`, além de
`docs/UI-REDESIGN-DIRECTION.md`, este handoff e a release note da revisão.

Essa auditoria confirma completude estrutural da documentação, não conclusão
do plano de produto. O plano ainda contém trabalho futuro de refatoração total
da UI, cast completo code-drawn, história macOS, localização PT-BR,
acessibilidade de plataforma, novos inimigos, gameplay, mobile/PC, performance
e preparação de release. Este checkpoint documenta e implementa apenas o
segundo passe da direção visual vNext e seus instrumentos de validação.

## 10. Próximos passos recomendados

### Para avaliação do usuário

- dizer se a composição do boot finalmente remete à referência sem parecer
  vazia;
- avaliar se o contraste entre índice/dossiê/comando funciona de primeira;
- apontar quais entidades ainda parecem genéricas quando vistas em gameplay;
- testar se o narrow é legível e confortável, não apenas “sem clipping”;
- decidir se a rota vNext pode substituir a legada por grupo de telas ou se
  precisa de mais um passe visual.

### Para implementação posterior

- ampliar o passe de arte code-drawn para todo o cast, com estados de ataque,
  hit, elite, telegraph e grayscale;
- fechar a migração das telas restantes e só depois remover os switches;
- completar PT-BR de todos os textos player-facing;
- validar touch, safe area, export e performance em Android real;
- investigar teardown em categorias por ownership e fazer probes de lifecycle;
- extrair somente as primitivas de shell que se provarem idênticas;
- preparar release candidate, changelog consolidado e checklist de rollback.

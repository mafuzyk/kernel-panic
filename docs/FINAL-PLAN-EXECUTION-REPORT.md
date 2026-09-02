# KERNEL PANIC — Relatório final da execução do plano mestre

**Data do checkpoint:** 2026-09-02
**Branch revisada:** `codex/plan-execution`
**Base:** `295cc0c` (`docs: close master plan review gaps`)
**Worktree de execução:** `/tmp/kernel-panic-plan-execution-resume`
**Checkout original preservado:** `/home/mafu/Projetos/kernel-panic`
**Destino:** `origin/codex/plan-execution`
**Status de publicação:** branch publicada, sem merge em `main`

## 1. Veredito curto

O resultado é um checkpoint técnico forte de desenvolvimento: a arquitetura
de transição, várias correções de gameplay, a fundação da nova UI code-drawn,
o primeiro recorte da história do macOS, a fundação de acessibilidade, a
infraestrutura de PT-BR, o perfil de performance e a documentação de
repositório ficaram implementados e verificados por probes focados.

Ele **não está pronto para lançamento oficial**.

Isso não é por falta de uma checagem cosmética. O candidato ainda não passa
por gates que são obrigatórios para uma versão pública de verdade:

- a UI vNext ainda é opt-in e a UI legada continua sendo a rota padrão;
- a migração completa da UI e a aprovação visual humana do remake from scratch
  ainda não aconteceram;
- PT-BR ainda não cobre todo o texto visível e precisa de revisão nativa;
- o suporte físico a mobile, Vega e Android não foi medido;
- exports Linux/Windows/Android não puderam ser produzidos neste ambiente;
- existem diagnósticos de teardown de recursos/RIDs/ObjectDB que ainda não
  foram eliminados nem explicados por categoria suficiente para uma release;
- persistência crash-safe/journaled, rollback de release e proveniência de
  artefatos ainda não estão fechados;
- balanço, legibilidade dos telegraphs, mix de áudio e qualidade visual ainda
  precisam de avaliação humana.

Portanto, a classificação correta é:

> **Advanced development candidate / pré-release técnico. Não publicar como
> versão oficial ainda.**

## 2. O que foi executado

Foram executados 118 commits de trabalho além da base antes deste relatório,
em lotes pequenos, com probes red/green, revisão adversarial e documentação
por etapa. A branch foi mantida isolada e publicada sem force-push. O checkout
original não foi usado para implementar o plano e não recebeu as alterações da
execução.

O trabalho foi deliberadamente dividido em três camadas:

1. preservar o runtime legado enquanto os contratos eram extraídos;
2. construir a nova UI e os novos sistemas atrás de limites opt-in e
   compatíveis;
3. só considerar promoção quando existissem evidências de comportamento,
   layout, integração, persistência e plataforma.

Essa decisão evitou que o remake visual destruísse, sem retorno, o único
runtime jogável enquanto a direção artística ainda precisa de avaliação.
Também respeitou a decisão do projeto de usar code-drawn como padrão para
inimigos e programas, deixando sprites fechados por enquanto.

## 3. Resultado por frente de trabalho

### 3.1 Arquitetura e contratos — A1 a A5

Foi criado um mapa verificável do projeto, com distinção entre runtime,
conteúdo, ferramentas, arquivos gerados, documentação e estado local. Os
limites de ownership foram registrados para `Game`, `Arena`, `Menu`, `Sfx`,
`StoryData`, kits de UI, entidades e probes.

Foram adicionados ou reforçados:

- contratos de snapshot somente com primitivos, cópias defensivas e metadados
  de schema;
- um catálogo estático para programas, bestiary, achievements, patches, códigos
  e relações de conteúdo, mantendo `StoryData` como autoridade de atos/stages;
- limites de ciclo de vida e sinais entre gameplay, HUD, pause, save,
  localização e UI;
- compatibilidade de save v1, leitura de chaves antigas e importação/exportação
  sem mudar `Sfx.SAVE_PATH`, `SAVE_TRANSFER_FORMAT` ou
  `SAVE_TRANSFER_VERSION`;
- validação de tipos em todos os containers aninhados antes de qualquer
  `ConfigFile` write;
- preservação dos bytes do save original quando o payload importado é inválido;
- watchdogs e marcadores de conclusão para evitar falsos verdes ou probes que
  ficam vivos indefinidamente.

Correção importante nessa frente: a primeira versão do contrato de save
validava apenas o nível externo. A revisão adversarial mostrou que mapas como
`story.best`, `story.cleared`, `bestiary`, `programs` e `achievements` ainda
podiam ter tipos errados. O probe foi endurecido, ficou vermelho, e a produção
passou a rejeitar todos esses casos antes da escrita.

### 3.2 Remake de UI vNext — U1 a U6

Foi construída uma fundação code-drawn from scratch, sem transformar a UI
legada em uma cópia mecânica. O recorte cobre:

- boot e shell de menu;
- seleção de programa;
- seleção de história, acts e stages;
- oferta de patch e decisão de build;
- combat HUD;
- pause, terminal e game-over;
- estados compartilhados de loading, erro, vazio e transição;
- settings/accessibility vNext.

Os contratos centrais estão em:

- `src/ui/vnext/ui_context.gd`;
- `src/ui/vnext/ui_layout.gd`;
- `src/ui/vnext/ui_navigation.gd`;
- `src/ui/vnext/core/ui_state.gd`;
- `src/ui/vnext/core/ui_focus_model.gd`;
- `src/ui/vnext/surfaces/`.

O comportamento adotado foi intencionalmente diferente por faixa de viewport:

- desktop usa composição mais aberta e pode manter lista/detalhe lado a lado;
- telas estreitas usam estados mutuamente exclusivos de lista e detalhe,
  com ação explícita para voltar à lista;
- a geometria de ação é compartilhada entre desenho, hit testing, foco e
  semântica;
- Buttons nativos são donos da ativação real; o fallback de ponteiro consome
  o mesmo evento para impedir dupla ativação;
- entrada de mouse/touch é normalizada pela transformação de stretch;
- `text_overflow_report()` e medições de safe area fazem parte da prova, não
  são uma inspeção posterior opcional.

O ponto crítico: esta é uma fundação funcional e técnica, não o remake final.
As rotas continuam atrás de:

```text
KP_VNEXT_BOOT=1
KP_VNEXT_PATCH=1
KP_VNEXT_HUD=1
KP_VNEXT_U4=1
KP_VNEXT_SETTINGS=1
```

A UI legada continua como default para reduzir risco de migração prematura.
Ainda falta transformar a direção visual das imagens em uma linguagem final
aprovada: hierarquia, densidade, foco, composição, efeitos, estados vazios,
mobile e consistência entre menu, bestiary, pause, HUD e game-over.

### 3.3 Code-drawn para entidades — E1 a E5, com E2 parcial

Foi criada uma fundação de apresentação que separa simulação de ilustração:

- `VNextEntityDescriptor` normaliza identidade, estado, facing, markers e
  qualidade;
- `VNextEntityRenderer` concentra bounds, fit, silhouette e draw;
- `VNextEntityPresentationAdapter` traduz snapshots reais sem tomar ownership
  de HP, posição, RNG, hitbox ou drops;
- `VNextEntityIllustration` preserva o ponto de entrada público e recebe perfis
  desktop/mobile, high-contrast, grayscale, color-assist e reduced-motion;
- identidade, orientação, estado, elite e alerta permanecem legíveis mesmo
  quando finish/glow são reduzidos;
- o registry de sprites segue desligado por padrão; nenhum asset raster novo
  foi introduzido.

O primeiro lote de inimigos com identidade reforçada cobre DRONE, LANCER e
SPEWER, incluindo estados AIM/LUNGE e wind-up. ZOMBIE_PROCESS e
RACE_CONDITION também receberam identidade code-drawn, telegraph, bestiary e
integração com os estados compartilhados.

A regra artística documentada em `docs/ART-DIRECTION-CODE-DRAWN.md` é:

- silhueta preta reconhecível em 24, 48, 96 e 160 px lógicos;
- um motivo estrutural ligado ao comportamento;
- eixo de ataque e facing quando relevantes;
- estados idle, hit, attack/charge e death;
- redundância de cor com forma, padrão ou texto;
- telegraph que comunica ação e counterplay, não só decoração;
- mesma fonte de render para gameplay e bestiary;
- qualidade reduzível sem apagar informação de gameplay.

Ainda não foi feita a aprovação visual humana nem o passe completo de todos os
inimigos/programas. Isso é deliberado: um probe que prova bounds e ausência de
mutação não prova que uma silhueta é bonita, distinta ou memorável.

### 3.4 Gameplay, balance e novos encontros

As seguintes partes foram implementadas e testadas em escopo focado:

- `RunContext` explícito para Classic, Story, Weekly, One-HP e Practice
  reservado;
- Page Cache com limite de três motes e auto-release do bônus agrupado;
- Ring-0 como patch raro/legendário com limite de stack e recuperação;
- settings de display para fullscreen e target FPS 30/60/120/unlimited;
- Weekly mutators determinísticos (`swift_daemons` e `rush_hour`);
- Practice com seleção de wave, limite pelo progresso e fronteira de save
  separada de Classic/Story/Weekly;
- boss desperation em <=8% HP, janela de 0,75 s e telegraph não dependente
  apenas de cor;
- RACE_CONDITION com par vinculado, buff de proximidade, separação e ensino
  progressivo nas waves;
- ZOMBIE_PROCESS com teach wave, shell temporário e counterplay próprio;
- death heatmap local quantizado, limitado por escopo e quantidade de runs;
- camadas de patch music para desktop, com silêncio em headless/mobile e
  toggles persistidos separadamente.

O overflow de mote com Rootlet cheio está registrado como decisão aprovada:
cada mote excedente concede `+5` score e progresso de scrap pela regra já
existente. A decisão altera a economia conscientemente; não foi tratada como
uma otimização neutra.

### 3.5 Bugs e correções de gameplay confirmados

Foram corrigidos os problemas abaixo, cada um com investigação e evidência
focada:

1. **ESC engolido pelo bloco de F1–F4.**
   `set_input_as_handled()` e `return` estavam fora do `KEY_F4`, então o bloco
   consumia ESC, ENTER e outras teclas. O tratamento foi limitado ao case
   correto. Isso explica por que o tratamento antecipado conseguia fechar a
   pausa, mas não abri-la no desktop debug.

2. **Gameplay pausado sem rota centralizada.**
   Dígitos 1/2/3, restart `R` e abandono `Q` passaram a compartilhar o handler
   de gameplay pausado. O router evita processamento duplo e a simulação
   continua congelada.

3. **ESC do terminal quebrado com `LineEdit` focado.**
   O GUI consumia o evento antes do terminal. O fluxo foi movido para
   `gui_input`, preservando a promessa de `ESC CLOSE`.

4. **Painel de pausa não restaurado ao fechar terminal.**
   `close_terminal()` chamava `arena._close_terminal()`, método inexistente e
   dono errado. O caminho passou a usar `panel_kit._close_terminal()`.

5. **Orphan `PlayerBullet`.**
   `_shoot()` criava um `PlayerBullet` não referenciado e fora da árvore a cada
   disparo. A alocação morta foi removida; contagens de disparo, splitshot,
   velocidade, recoil, som e estatística foram preservadas.

6. **Deadlock de recarga do Rootlet.**
   Motes e kill bonus usavam `shield_ready` como gate, mas o consumo zerava a
   própria flag. A recarga ficava impossibilitada. O gate foi separado para
   `shield_mode`; o kill que completa 100% agora ativa o escudo e emite o
   estado correto.

7. **Sinal de escudo completo inconsistente.**
   A transição para `shield_ready=true` passou a emitir
   `meter_changed(shield_meter, true)` somente uma vez. Escudo já cheio não
   gera emissão ou feedback duplicado.

8. **Story Temple/GOD usando RootBoss.**
   O caminho story instanciava `RootBoss.new()` sem respeitar
   `_story_boss_kind`. O spawn agora escolhe `GodBoss` quando o stage declara
   `god`, mantendo o caminho clássico separado.

9. **Regressões do redesign local do menu.**
   Labels de header mantinham `anchor_right=1.0` junto com offsets absolutos,
   duplicando a largura do viewport. O reset de anchors foi corrigido. O
   registry também voltou a conter os seis frames, incluindo os três de
   footer.

10. **Steering de ZOMBIE_PROCESS incompleto.**
    O primeiro teste confundia separação direta com steering reutilizável. A
    prova foi corrigida para testar o caminho real e o comportamento foi
    endurecido sem usar a posição como único sinal.

11. **GodBoss com retorno prematuro.**
    Uma primeira correção podia suprimir casts do oracle permanentemente. A
    revisão adversarial encontrou o fluxo, a guarda foi reescrita e a prova
    cobriu as variantes novamente.

12. **Practice escrevendo registros indevidos.**
    `end_run()` podia cair no fallback Classic e achievements tinham caminho de
    save separado. O contrato de Practice foi aplicado nos dois pontos reais.

13. **M4 reportando vitória antes do save estar confirmado.**
    A conclusão do stage agora prepara o novo estado, tenta o checkpoint e só
    depois comita cleared/best/reward. Falha de escrita permanece retryable e
    não apresenta uma vitória falsa.

14. **Validador aceitando execução vazia.**
    Um binário que saía em silêncio com exit 0 era aceito como verde. Cada caso
    agora exige marcador de conclusão (`AUTOTEST_ALL_PASS` ou
    `PROBE_DONE fails=0`), e o Xvfb exige a confirmação de debug controls.

15. **Guard de hash E2 obsoleto.**
    O probe rejeitava uma mudança legítima de `GlyphLib` feita em lotes aceitos
    depois do baseline. O hash foi atualizado para o baseline aceito e a
    manutenção foi registrada, sem mascarar uma alteração de produção.

16. **Texto do Permission Root acima do orçamento.**
    A primeira descrição do novo boss quebrou overflow e containment do
    bestiary em telas estreitas. A copy foi reduzida, mantendo regra e
    counterplay, e a suíte inteira foi rodada novamente.

### 3.6 MAC-OS history — M1 a M5

Foi implementado um act ficcional de história da evolução do macOS, sem usar
logos ou screenshots proprietários como runtime:

- `mac_classic`;
- `mac_aqua`;
- `mac_darwin`;
- `mac_modern`.

O catálogo possui title, intro, klog, profile, waves, boss metadata e reward
IDs estáveis. O act exige a progressão documentada de `temple_god`, e os stages
antigos continuam no catálogo sem mudança de índice incompatível.

Foi adicionado:

- `MacOSEraOverlay` code-drawn e profile-driven;
- textos narrativos em catálogo inglês/PT-BR;
- reveal por camadas com estado `BACKGROUND`, contagem regressiva e telegraph;
- `PermissionRootBoss` com `PERMISSION CHECK` e `PERMISSION DENIED`;
- recompensa whitelisted, save/export/import e retry após falha de checkpoint;
- integração com story selector, bestiary, renderer e layout narrow.

O route real atravessa `Game.start_story()`, o spawner e o boss final. A
correção do Permission Root no bestiary e no orçamento de texto foi integrada e
verificada antes do fechamento do checkpoint.

O nome “macOS” aqui é uma camada narrativa/temática do jogo, não uma promessa
de build específica para o sistema operacional macOS. A documentação evita
essa ambiguidade.

### 3.7 Localização e PT-BR

Foi criado um autoload `Localization` com catálogos JSON UTF-8:

- `src/data/localization/en.json`;
- `src/data/localization/pt-BR.json`.

O serviço suporta fallback inglês, formatação, plural/select, snapshots,
persistência em `Sfx.SAVE_PATH`, alteração de locale com uma emissão e
validação de parity/placeholders.

O recorte migrado cobre:

- todo o act macOS;
- a superfície de accessibility vNext;
- títulos, estados, explicações e labels dessa superfície;
- selector de idioma na rota legada de Display settings;
- refresh de story/vNext sem recarregar a cena.

`docs/LOCALIZATION-INVENTORY.md` registra o inventário aproximado dos
literais. Ele não finge que toda ocorrência inglesa encontrada por scan é uma
string de produto: nomes técnicos, códigos, debug e conteúdo interno precisam
ser classificados antes da migração.

PT-BR ainda não é uma feature completa de release. Menus legados, HUD e
conteúdo antigo continuam com strings inglesas. É necessária uma tradução
editorial nativa, revisão de acentos, tom, terminologia e comportamento em
telas estreitas.

### 3.8 Acessibilidade e input

O perfil de settings recebeu schema aditivo 3, sem quebrar saves existentes:

- reduced motion;
- reduced flashes;
- left-handed touch.

O perfil tem defaults, normalização, persistência, reset, rollback e
snapshots. O efeito compartilhado de `Fx`, `CameraRig` e touch controls é
controlado por esse perfil, evitando uma flag espalhada e inconsistente.

A superfície dedicada tem 11 controles, estado semântico, foco, overflow,
labels localizados, reset e refresh em troca de idioma. A zona de movimento e
as ações de dash/overclock podem espelhar para canhotos sem alterar o
significado lógico das ações.

Limites deliberadamente explícitos:

- screen reader nativo não foi implementado;
- text scaling do sistema não foi provado;
- high contrast completo não foi implementado;
- remapping de controle/gamepad e a matriz inteira de assistências ainda estão
  pendentes;
- toda partícula, ring, ghost e efeito decorativo ainda precisa de auditoria
  completa para reduced motion/flashes;
- settings novos estão mais completos na vNext, mas a migração da rota legada
  permanece aberta.

### 3.9 Performance e confiabilidade

Foi adicionado `PerformanceProfile` com p50/p95/p99/worst frame, pico de
entidades e memória, mais um stress probe com seed fixa, 48 inimigos reais e
96 projéteis reais. O fixture não entra em um run do usuário e não escreve
save.

Resultados verdes atuais:

| Ambiente | p95 | p99 | pior frame | pico |
|---|---:|---:|---:|---:|
| headless | 16,813 ms | 16,985 ms | 17,163 ms | 144 atores |
| Xvfb / Mesa llvmpipe | 7,322 ms | 7,842 ms | 8,229 ms | 144 atores |

Esses números são um envelope de regressão reproduzível. Eles não certificam
60 FPS na Vega integrada do usuário, não certificam Android e não substituem
um soak test longo.

O baseline e o estado final ainda exibem diagnósticos de teardown, incluindo
recursos, RIDs, text shaping, texturas dummy, CanvasItem e ObjectDB. A
validação os separa de falhas funcionais para não transformar ruído de
encerramento em falso `AT_FAIL`, mas isso não é o mesmo que resolver os
vazamentos. Nenhum claim de leak fix foi feito.

### 3.10 Repositório, open source e release

Foram adicionados:

- `CONTRIBUTING.md`;
- `CODE_OF_CONDUCT.md`;
- `SECURITY.md`;
- `.github/PULL_REQUEST_TEMPLATE.md`;
- `.github/ISSUE_TEMPLATE/bug_report.md`;
- `.github/ISSUE_TEMPLATE/feature_request.md`;
- `.github/workflows/quality.yml`;
- `docs/ART-DIRECTION-CODE-DRAWN.md`;
- `docs/RELEASE-CHECKLIST.md`;
- `docs/CHANGELOG-PLAN-EXECUTION.md`;
- `docs/LOCALIZATION-INVENTORY.md`;
- handoffs e relatórios técnicos por lote.

O CI proposto roda import, DevHarness e o diff check. O workflow não teve uma
execução hospedada real neste ambiente; essa incerteza continua escrita na
checklist. O pacote de release também ainda não tem versão, nome, exports,
proveniência, rollback nem instruções de instalação fechadas.

## 4. Evidências finais

### 4.1 Suite integrada

Com áudio mudo, para não interromper o estudo do usuário:

```text
KP_VALIDATION_TIMEOUT_SECONDS=120 \
KP_VALIDATION_LOGS=/tmp/kernel-panic-final-validation-2 \
tools/validate_input_dispatch.sh
```

Resultado:

```text
VALIDATION OK (teardown diagnostics above remain non-gating)
```

A suite principal terminou com:

```text
exit 0
1453 AT_PASS
0 AT_FAIL
AUTOTEST_ALL_PASS
```

O validator acumulado terminou sem falha gateada nos seguintes grupos:

- input headless: 32/0;
- input Xvfb com debug desktop confirmado: 34/0;
- R04: 7/0;
- R05: 28/0;
- R06: 7/0;
- R07: 4/0;
- R08: 7/0;
- B1: 10/0;
- B2: 8/0;
- B5: 11/0;
- R18: 6/0;
- vNext primitives: 18/0;
- entity illustration: 136/0;
- E2: 77/0 no acumulador;
- E3: 35/0;
- E4: 20/0;
- E5: 18/0;
- G1: 29/0;
- Page Cache: 13/0;
- Ring0: 14/0;
- display: 12/0;
- G3: 44/0;
- G4: 52/0;
- patch music: 52/0;
- vNext patch Arena: 19/0;
- combat HUD: 48/0;
- state surfaces: 71/0;
- accessibility: 78/0;
- shared state: 145/0;
- macOS surface: 25/0;
- accessibility profile: 9/0;
- performance: 9/0;
- Xvfb display/G3/G4/vNext state/accessibility/shared/M5/A11-A14/P1:
  todos verdes nos respectivos grupos.

Os logs finais de referência do recheck de 2026-09-02 são:

- `/tmp/kernel-panic-final-validation-resumed-2.log`;
- `/tmp/kernel-panic-final-validation-resumed-2/suite-headless.log`;
- `/tmp/kernel-panic-final-validation-resumed-2/probe-vnext-accessibility.log`;
- `/tmp/kernel-panic-final-validation-resumed-2/probe-performance-stress.log`;
- `/tmp/kernel-panic-final-validation-resumed-2/probe-performance-stress-xvfb.log`;
- `/tmp/kernel-panic-final-validation-resumed-2/probe-vnext-accessibility-xvfb.log`.

### 4.2 Import e exports

Import do editor/headless terminou com exit 0 usando o driver de áudio Dummy,
mas imprime o aviso conhecido de ambiente sobre Android build-tools.

Tentativas de export foram feitas sem escrever artefatos no repositório:

- Linux x86_64: falhou porque os templates 4.7.2 não estão instalados;
- Windows x86_64: falhou pela mesma ausência de templates;
- Android: falhou por templates ausentes e ausência de SDK/platform-tools,
  build-tools e `adb`/`apksigner` utilizáveis.

Isso é uma limitação do ambiente, mas para a release o efeito é objetivo:
nenhum artefato oficial foi produzido ou lançado.

### 4.3 Limpeza e isolamento

`git diff --check 295cc0c..HEAD` encontrou apenas whitespace histórico em
relatórios anteriores (trailing spaces e blank EOF); nenhum erro foi
introduzido nas alterações funcionais atuais. A correção desses arquivos
históricos não foi feita automaticamente para não misturar limpeza irrelevante
com o checkpoint.

Os arquivos `.uid` e `.png.import` gerados pelo import do Godot continuam
untracked no worktree de execução e não foram staged. Eles não fazem parte do
release. O checkout `/home/mafu/Projetos/kernel-panic` permaneceu fora da
implementação; qualquer alteração local pré-existente ali continua sendo do
usuário.

## 5. Decisões técnicas principais

### Manter legado e vNext simultaneamente

**Escolha:** vNext opt-in por flags, legado como default.
**Alternativa rejeitada:** substituir todas as cenas de uma vez.
**Motivo:** a UI desejada é from scratch, mas a aprovação visual e o suporte
mobile ainda não existem. A substituição imediata criaria uma janela sem
rollback e tornaria regressões de gameplay difíceis de atribuir.
**Trade-off aceito:** duplicação temporária e mais rotas de teste.
**Evidência:** probes de route, foco, resize, input e integração real passaram
sem alterar a rota legada.
**Incerteza:** a migração definitiva ainda exige aprovação do usuário.

### Code-drawn como padrão; sprites sob gate

**Escolha:** renderer e identidade code-drawn, registry de sprite default-off.
**Alternativa rejeitada:** continuar adicionando imagens para cada entidade ou
gerar arte raster antes de fechar a gramática visual.
**Motivo:** combina com a direção definida pelo usuário e permite reduzir
qualidade para mobile preservando informação.
**Trade-off aceito:** alcançar acabamento de “arte” exige mais desenho,
telegraph e revisão manual.
**Evidência:** descritor, adapter, bounds, fit, estados, probes de não-mutação
e profiles de qualidade.
**Incerteza:** qualidade estética e distinção entre inimigos não são provadas
por testes automatizados.

### Snapshot/copy como fronteira UI-gameplay

**Escolha:** UI lê snapshots copiados e emite comandos; gameplay continua
owner de estado mutável.
**Alternativa rejeitada:** kits alterando `Game`/`Arena` diretamente ou uma
segunda fonte de verdade na UI.
**Motivo:** evita corrida de estado, duplica menos regra e facilita rollback.
**Evidência:** probes de deep-copy, schema, save, route e exactly-once input.
**Risco:** novos campos opcionais ainda precisam de consumidores e testes
específicos.

### Acessibilidade aditiva e centralizada

**Escolha:** schema aditivo no save existente e gates compartilhados em Fx,
CameraRig e touch.
**Alternativa rejeitada:** flags locais espalhadas por cada superfície.
**Motivo:** normalização, reset e rollback ficam determinísticos e a ação não
muda com a plataforma.
**Evidência:** perfil 9/0, vNext settings 78/0, localization 32/0 e Xvfb.
**Risco:** screen reader, high contrast, text scale e remapping ainda não
estão resolvidos.

### Evidência por completion marker e teardown separado

**Escolha:** uma execução só fica verde com marcador explícito; diagnósticos de
teardown são reportados separadamente e continuam visíveis.
**Alternativa rejeitada:** confiar apenas em exit 0 ou silenciar todos os
`ERROR` no log.
**Motivo:** exit 0 com execução vazia já foi reproduzido e rejeitado; ocultar
teardown criaria falsa confiança.
**Evidência:** o fake Godot que saía silenciosamente passou a ser rejeitado; a
validação real fechou com marker e zero falhas gateadas.
**Risco:** a separação atual ainda precisa de diagnóstico de cada recurso para
classificar e eliminar os teardown leaks.

## 6. Lacunas, incertezas e como validar

### UI final

1. **Comprovado:** rotas vNext montam, recebem input, refluem e passam
   overflow em viewports lógicos.
2. **Suposição ainda não aceita:** a composição atual representa a direção das
   referências e é agradável em uso real.
3. **Risco:** lançar a UI antes da aprovação pode congelar uma hierarquia ou
   densidade ruim e obrigar retrabalho em todas as superfícies.
4. **Validação:** capturas limpas em 432×720, 390×844, 1280×720, 1600×900 e
   ultrawide; revisão sem glow, com reduced motion, com PT-BR e com foco; só
   depois migrar uma superfície por vez.

### Mobile

1. **Comprovado:** layout lógico, safe-area, touch mapping e canhoto possuem
   probes em viewports simulados.
2. **Suposição ainda não aceita:** isso se comporta bem no aparelho mais fraco
   e com dedos reais.
3. **Risco:** controles podem ficar pequenos, cobrir telegraphs ou sofrer
   jank/thermal throttling.
4. **Validação:** Android arm64 real, matriz retrato/paisagem, touch manual,
   15–30 minutos de soak e perfil de qualidade com P95/P99.

### Performance

1. **Comprovado:** fixture fixa com atores reais passou no headless e Xvfb.
2. **Suposição ainda não aceita:** o envelope representa a Vega integrada e
   Android.
3. **Risco:** `_draw`, text shaping, partículas e waves densas podem estourar
   no dispositivo alvo.
4. **Validação:** medir Vega do usuário, um Android mínimo e um desktop mínimo,
   com baseline, stress, resize, pause, restart e soak.

### Saves

1. **Comprovado:** payloads inválidos são rejeitados sem destruir o save atual;
   completion de story não se anuncia antes do checkpoint aceito.
2. **Suposição ainda não aceita:** `ConfigFile` por si só é suficiente para
   crash, queda de energia ou disco cheio.
3. **Risco:** interrupção durante write pode corromper a única cópia válida.
4. **Validação:** journal/backup atômico, injeção real de falha de escrita,
   recuperação automática e round-trip entre builds antigas/novas.

### Acessibilidade

1. **Comprovado:** reduced motion/flashes e canhoto persistem e alteram os
   subsistemas centrais; labels da superfície vNext têm PT-BR e overflow.
2. **Suposição ainda não aceita:** a cobertura de efeitos é completa e as
   opções são suficientes para pessoas reais.
3. **Risco:** efeitos não auditados podem causar desconforto ou telegraphs podem
   desaparecer sem alternativa.
4. **Validação:** inventário de todo `queue_redraw`, flash, tween, particle,
   ring e camera trauma; revisão com usuários, screen reader possível,
   high-contrast e remapping.

### CI e release

1. **Comprovado:** workflow, checklist e comandos locais existem; local
   validator está verde.
2. **Suposição ainda não aceita:** o workflow hospedado, templates e artefatos
   são reproduzíveis fora deste PC.
3. **Risco:** primeiro release pode falhar na pipeline ou publicar build
   diferente da revisada.
4. **Validação:** executar CI real, fixar versão/commit/toolchain, gerar
   hashes, testar instalação e guardar rollback.

## 7. Próximos passos recomendados

### P0 — antes de qualquer anúncio ou tag oficial

1. **Revisão humana da direção visual.** Aprovar ou rejeitar a gramática
   code-drawn com as referências de `media/Ideas/`; escolher densidade,
   contrastes, efeitos e nível de detalhe para desktop/mobile.
2. **Fechar a UI vNext por fatias.** Migrar menu, settings, story, bestiary,
   pause, HUD e game-over individualmente, com flag de rollback até cada uma
   passar em visual, input, overflow, focus, touch e teardown.
3. **Completar PT-BR.** Inventariar os literais restantes, separar technical
   English intencional, traduzir conteúdo visível e fazer revisão nativa.
4. **Fechar accessibility.** Decidir screen reader, high contrast, text scale,
   gamepad/remapping e auditoria completa de efeitos; não anunciar suporte que
   não foi implementado.
5. **Corrigir ou categorizar teardown.** Criar ownership/cleanup probes para
   resources, RIDs, timers, tweens, signals, fonts, textures e ObjectDB.
6. **Implementar save recovery.** Backup/journal/atomic replace, falha
   injetável e teste de interrupção.
7. **Construir e medir exports.** Instalar templates, produzir Linux/Windows e
   Android, testar abertura, input, save, audio, fullscreen, crash e logs.

### P1 — depois de P0, antes de chamar o jogo de 1.0

1. Completar E2 para o cast restante e E5 finish tiers por entidade.
2. Playtestar G2B, Weekly, Practice, desperation, RACE_CONDITION, Mac
   layered reveal e Permission Root em normal/One-HP.
3. Medir densidade de waves e efeitos em hardware mínimo, incluindo long-run
   soak e repeated restart/overlay.
4. Criar captures de aprovação com camada estrutural limpa e camada final de
   efeitos, sem confundir screenshot com teste de layout.
5. Definir version source, release name, licença/atribuições de assets,
   hashes, artefatos e rollback.

### P2 — evolução pós-primeira release

1. Adicionar novos inimigos apenas depois de silhueta, telegraph, counterplay,
   bestiary, PT-BR, mobile e performance.
2. Considerar sprites seletivos somente se um caso provar valor visual que o
   renderer não consegue entregar dentro do orçamento de memória/performance.
3. Melhorar telemetria local opt-in, heatmap e ferramentas de replay sem criar
   dependência de rede ou coletar dados privados.
4. Expandir conteúdo e UX em lotes que sempre preservem os contratos de save,
   input e acessibilidade.

## 8. O que precisa da avaliação do usuário

Estas decisões não devem ser inventadas pelo código:

- se a UI atual da vNext está realmente na direção das imagens de
  `media/Ideas/`, ou se deve ser mais austera, mais densa ou mais editorial;
- quais telas merecem prioridade no remake from scratch;
- qual nível de detalhe é “carinho” suficiente para enemies/programs sem virar
  poluição visual;
- se o Permission Root precisa de uma silhueta exclusiva antes de qualquer
  release;
- se os quatro stages do act macOS têm tom, nomes e recompensa corretos;
- se o comportamento de Ring-0, Weekly, Practice, desperation e Mac reveal é
  divertido, justo e compreensível;
- qual é o escopo mínimo de PT-BR e a terminologia técnica preferida;
- quais opções de acessibilidade são obrigatórias para declarar suporte;
- qual é o aparelho Android mínimo e quais desktops/GPUs serão suportados;
- se a música de patch deve ser audível e qual é a intensidade aceitável;
- qual conjunto de problemas será aceito como Known Issues no primeiro
  lançamento.

## 9. Documentos entregues

### Para uso técnico interno

- [ledger de execução e progresso](../.superpowers/sdd/00-MASTER-PLAN/progress.md);
- [plano mestre](superpowers/plans/2026-08-31-kernel-panic-master-plan/00-MASTER-PLAN.md);
- relatórios em `../.superpowers/sdd/00-MASTER-PLAN/report-*.md`;
- handoffs em `HANDOFF-*.md`;
- [inventário de localização](LOCALIZATION-INVENTORY.md);
- [direção code-drawn](ART-DIRECTION-CODE-DRAWN.md);
- [checklist de release](RELEASE-CHECKLIST.md).

### Para Release Notes

- [changelog limpo e orientado ao usuário](CHANGELOG-PLAN-EXECUTION.md);
- [log detalhado por lote](release/2026-09-01-plan-execution.md).

O changelog limpo separa Added, Changed, Fixed, Improved, Performance,
Compatibility, Known Issues, Removed e Deprecated. O log longo preserva
decisões, red/green, limitações e evidência de cada frente.

## 10. Conclusão de release

A branch pode ser entregue para revisão, cherry-pick ou continuação do
desenvolvimento. Ela não deve receber tag de release pública ainda.

A promoção para oficial só deve ocorrer quando:

- a UI from scratch tiver aprovação visual humana e rota migrável;
- o PT-BR e accessibility tiverem escopo explícito e testado;
- gameplay/Mac/enemies tiverem playtest humano aprovado;
- teardown, save recovery e CI tiverem resultado aceitável;
- exports forem produzidos e testados nos alvos declarados;
- o commit, versão, hashes, release notes e rollback estiverem congelados.

Até lá, o relatório correto é “muita fundação sólida, nenhum lançamento ainda”.

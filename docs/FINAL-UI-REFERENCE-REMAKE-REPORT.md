# KERNEL PANIC — relatório final do checkpoint de remake da UI

**Data:** 2026-09-02
**Branch:** `fuzzy/ui-reference-remake`
**Base do checkpoint:** `96ac94c` (`docs: close master plan execution checkpoint`)
**Ponta revisada:** `28d2a48` (`fix(ui): remove split boss bar ghosts`)
**Worktree:** `/tmp/kernel-panic-ui-reference-remake`
**Checkout original preservado:** `/home/mafu/Projetos/kernel-panic`
**Status Git:** branch publicada em `origin/fuzzy/ui-reference-remake`, sem
merge em `main` e sem force-push
**Escopo do delta:** 32 commits, 88 arquivos, 8.455 linhas adicionadas e
542 removidas em relação à base do checkpoint
**Áudio nas verificações:** sempre `--audio-driver Dummy`

## 1. Veredito executivo

Este checkpoint é um avanço técnico grande e coerente: a UI vNext deixou de
ser apenas uma fundação funcional e ganhou uma primeira linguagem visual
autoral inspirada nas referências de `media/Ideas/`; o HUD legado recebeu um
tratamento crítico; os fluxos de pausa, terminal, seleção, Bestiary e
fullscreen foram endurecidos; caches e lifecycle de apresentação foram
corrigidos; e a validação acumulada terminou com zero falhas funcionais e zero
erros de runtime gateáveis.

O resultado **ainda não é uma versão pronta para lançamento oficial**.

O motivo é objetivo, não uma preferência estética:

- a vNext continua opt-in e a rota legada ainda é a padrão;
- a aprovação visual humana da composição e das silhuetas ainda não foi feita;
- o passe de arte code-drawn não cobre todo o elenco com o mesmo acabamento;
- PT-BR ainda é parcial na rota legada e não passou por revisão editorial
  brasileira completa;
- nenhum export Linux/Windows/Android de release foi produzido e executado
  neste ambiente;
- touch físico, lifecycle Android, Vega integrada e desempenho em aparelho
  real ainda não foram medidos;
- diagnósticos de teardown de recursos/RIDs/ObjectDB continuam abertos,
  embora estejam separados das falhas funcionais;
- screen reader nativo, escala de texto do sistema, high contrast completo e
  remapeamento de controle ainda não constituem suporte anunciado;
- save journal/backup crash-safe, CI hospedado e proveniência de artefatos
  ainda precisam de fechamento;
- balanço, telegraphs, legibilidade em movimento, mix de áudio e “game feel”
  precisam de playtest humano.

Classificação atual:

> **Candidato técnico avançado / pré-release. Não publicar como versão
> oficial.**

O bloco está pronto para revisão do mantenedor, teste manual e continuação de
desenvolvimento. Não está pronto para receber uma tag pública.

## 2. Escopo e limites

Este documento consolida o delta da branch atual desde `96ac94c` e resume o
estado herdado do plano mestre. O relatório histórico
[`FINAL-PLAN-EXECUTION-REPORT.md`](FINAL-PLAN-EXECUTION-REPORT.md) permanece
preservado para a execução anterior em `codex/plan-execution`; ele contém o
detalhamento original de arquitetura, save, MAC-OS history, localização,
acessibilidade, gameplay e operações de repositório antes do remake visual.

O handoff específico
[`HANDOFF-UI-REFERENCE-REMAKE.md`](HANDOFF-UI-REFERENCE-REMAKE.md) é a fonte
mais completa para cada investigação red/green, incluindo as tentativas
corrigidas durante o trabalho. Este relatório organiza o que foi entregue, o
que mudou para o jogador, quais decisões foram tomadas e por que o release
gate permanece aberto.

Arquivos gerados automaticamente pelo Godot (`.uid` e alguns `.png.import`)
continuam não rastreados e não fazem parte deste checkpoint. Foram preservados,
não foram staged e não devem entrar em um pacote de release.

## 3. O que foi entregue

### 3.1 Remake visual from scratch

A nova UI não é uma troca de cor ou uma migração mecânica das caixas antigas.
Foi criado um shell recorrente de “incident console” com:

- moldura externa e rails de calibração code-drawn;
- rota `KP://...`, estado do sistema e sessão;
- título grande com hierarquia de Orbitron;
- telemetria curta em ShareTechMono;
- separação entre índice, dossiê e ação dominante;
- brackets, linhas e estados de seleção visíveis sem depender somente de cor;
- composição adaptativa para wide, compact, narrow e micro-narrow;
- safe rectangle lógica e hit testing compartilhado com foco/ativação;
- camadas decorativas que podem ser reduzidas antes de sacrificar informação.

O vertical slice cobre Boot, Program, Story, Bestiary, Accessibility, Patch,
combat HUD, Pause, Terminal e Game Over. A intenção é preservar a sensação das
imagens em `media/Ideas/` — sistema hostil, diagnóstico, assimetria e
densidade editorial — sem colocar as imagens como runtime, sem copiar
screenshots proprietários e sem transformar a arena em um painel cheio.

### 3.2 Tradução das referências

| Referência | Regra visual extraída | Tradução implementada |
| --- | --- | --- |
| `imagem1.png` | boot com marca, telemetria periférica e comando dominante | Boot shell, identidade Kernel, process telemetry e ação de boot |
| `imagem10.png` | índice à esquerda, dossiê à direita e execução explícita | Program surface com lista de processos, ficha e `BOOT` persistente |
| `imagem2.png` | bestiary como instrumento de leitura de ameaça | Bestiary com logged/locked, comportamento, counterplay e glyph compartilhado |
| `imagem3.png` | workstation de configurações agrupada | Accessibility surface dedicada, status, controles reais e reset |
| `imagem5.png` | HUD nas bordas, centro livre | Integrity, evento, combo, patch dock, ability, score e boss register |
| `imagem6.png` | pausa dramática sobre a run ainda visível | Pause com contexto congelado, ação primária e confirmação explícita |
| `imagem8.png` | terminal diegético com stream e prompt | Terminal com histórico/autocomplete e retorno seguro |
| `iamgem9.png` | mapa de atos, nós e briefing contextual | Story mount-table com tabs, node index, dossier e `MOUNT` |

As referências são moodboard, não especificação de coordenadas, copy,
quantidade de colunas ou ornamentos. A regra de simplificação está em
[`UI-REDESIGN-DIRECTION.md`](UI-REDESIGN-DIRECTION.md): cada detalhe precisa
identificar um estado, melhorar uma decisão, comunicar uma mudança ou reforçar
a atmosfera sem competir com a leitura.

### 3.3 Code-drawn de inimigos e programas

Foi mantido o princípio aprovado: inimigos e programas são code-drawn e
sprites/raster ficam atrás de um gate explícito. A camada nova separa:

- descritor de identidade, estado, facing, markers e qualidade;
- adapter de snapshots reais para apresentação;
- renderer de bounds, fit, silhouette e draw;
- ilustração reutilizável no gameplay e no Bestiary;
- perfis de qualidade, grayscale, color-assist, high-contrast parcial e
  reduced-motion.

O lote visual reforçou `DRONE`, `LANCER`, `SPEWER`, `DAEMON` e `ROOTLET`,
além das identidades de `KERNEL`, `ZOMBIE_PROCESS` e
`RACE_CONDITION` já presentes na base. A regra registrada em
[`ART-DIRECTION-CODE-DRAWN.md`](ART-DIRECTION-CODE-DRAWN.md) exige silhueta
legível, motivo estrutural ligado ao comportamento, facing/eixo de ataque,
estado redundante e telegraph de counterplay.

Foi comprovada a estabilidade do contrato de desenho, bounds, estados e
ausência de mutação da simulação. Ainda não foi comprovada a qualidade estética
final de cada entidade em movimento, grayscale, tamanho de gameplay e
hardware real.

### 3.4 HUD legado, overlays e UX

Como a vNext ainda é opt-in, o HUD legado também recebeu um passe crítico:

- banner grande reservado a eventos; `CYCLE NN` permanece como estado contínuo;
- event log e tooltips medidos e truncados dentro do registro;
- integridade, shield/overclock, dash e direção de dano com redundância textual;
- Rootlet separado da semântica genérica de overclock;
- pips e copy auxiliar ajustados para largura real;
- game-over narrow empilhado em vez de esmagado em duas colunas;
- low-HP vignette, watermark e efeitos de tela suprimidos por estado modal;
- widgets mortos, labels sem consumidor e callback de patch inútil removidos;
- hint `SWIPE TO SCROLL` limitado a touch;
- fade de banner corrigido para não começar totalmente invisível em durações
  longas;
- dash glyph legado impedido de reaparecer sobre o HUD vNext;
- foco inicial e navegação por teclado adicionados a pause, terminal e
  game-over;
- retorno de Program, Story, Bestiary e Awards unificado no rodapé inferior
  esquerdo;
- Bestiary mantém o card selecionado dentro da lista visível;
- fullscreen aparece somente no contexto desktop.

Também foram corrigidos prompt de lançamento, vazamento de `ENTER` pelos
overlays e confirmações destrutivas acidentais. Em narrow, as superfícies
vNext trocam lista/dossiê ou cards lado a lado por estados deliberados; não há
apenas encolhimento proporcional de um desktop.

### 3.5 Performance e lifecycle

O passe final tratou três riscos diferentes:

- **P1 — trabalho repetido:** HUD e geometria de patch usam caches com chave de
  viewport, touch scale e estado real dos patches; a Arena não reaplica layout
  em cada frame ocioso.
- **P3 — timelines concorrentes:** dicas e intros de boss têm ownership
  explícito; a solicitação recente cancela a anterior, inclusive o
  recolhimento atrasado.
- **P4 — estado visual fantasma:** a boss bar dividida usa somente fragmentos
  vivos, mantém A/B e deriva o nome do fork da variante real.

Nenhum desses lotes altera física, spawn, dano, colisão, score, save ou
balanceamento. O custo aceito é uma pequena camada de observabilidade/cache na
apresentação; desempenho em dispositivo real continua aberto.

## 4. Ledger de bugs e correções

### 4.1 Bugs funcionais herdados

| ID | Sintoma | Causa | Correção |
| --- | --- | --- | --- |
| R01/R02/R03 | ESC, ENTER e comandos pausados eram engolidos | `set_input_as_handled()` fora do `KEY_F4` e handler espalhado | dispatch limitado ao case correto e handler centralizado |
| R04 | um `PlayerBullet` órfão por tiro | `PlayerBullet.new()` sem referência e fora da árvore | alocação morta removida; tiro/split/recoil preservados |
| R05 | Rootlet não recarregava após consumir shield | `shield_ready` era gate da própria recarga | gate separado em `shield_mode`; kill que completa carga ativa shield |
| R06 | Temple/GOD terminava com RootBoss | story spawner ignorava `_story_boss_kind` | spawn usa `GodBoss` no stage `god` |
| R07/R08 | restart story e loot OOM tinham ownership incompleto | transições/saque temporário sem fronteira única | contexto de run, cleanup e probes de caminho real |
| M4 | vitória anunciada antes de save confirmado | cleared/reward commitado antes do checkpoint | persistir primeiro; falha permanece retryable |
| validator | exit 0 silencioso era aceito | ausência de marcador obrigatório | `AUTOTEST_ALL_PASS`/`PROBE_DONE fails=0` obrigatórios |
| menu/layout | anchors duplicavam viewport e footer perdeu frames | redesign misturou anchors/offsets e omitiu registry | anchors resetados e seis frames restaurados |
| E2/Mac | hash obsoleto e copy Permission Root fora do orçamento | baseline de teste antigo e texto sem medição | baseline aceito e copy reduzida com regra preservada |

Os handoffs históricos preservam a reprodução detalhada, logs red/green e
commits desses itens.

### 4.2 Bugs encontrados durante o remake

| ID | Comportamento anterior | Fix e evidência |
| --- | --- | --- |
| UI-REF-01 | vNext funcional, porém vazia e sem identidade de sistema | shell/index/dossier/action recompostos em `27fff38`/`7f5dcb7` |
| UI-REF-02 | overlays estreitos espremiam desktop e colidiam título/fechar | reflow físico em `498144b`, probe de janela e título medido |
| UI-REF-03 | BUILD invadia a região da ação | baseline passou a usar posição interna do footer |
| UI-REF-04 | XDG relativo misturava save do usuário e falsos fails | validador usa caminho absoluto isolado; red reproduzido |
| UI-REF-05 | probe do patch verificava chave que não era contrato | assertion corrigida para `density`; produto não foi alterado por falso bug |
| B6/B7 | prompt morto e ações destrutivas fáceis de acionar | prompt real, armamento, janela monotônica e echo ignorado |
| H1/H2/H4/H5 | banner duplicado, baixo contraste, estados por cor e colisões | hierarquia, medição, texto redundante e reflow |
| H6/H7 | efeitos/modais e widgets mortos confundiam a leitura | visibilidade por estado, remoção e hints por dispositivo |
| N1/N2/N3/N4 | foco, BACK, seleção e fullscreen incoerentes | foco real, slot comum, autoscroll e filtro desktop |
| P1 | relayout/cache repetidos | chave de layout, cache e callbacks idempotentes |
| P3 | dicas/intros acumulavam tweens | ownership, `kill()` e callback nomeado |
| P4 | linha 0% fantasma e fork sempre ROOT | rows de fragmentos vivos e título derivado do boss |

## 5. Código, commits e documentação

O diff exato pode ser auditado com:

```sh
git diff --name-status 96ac94c..28d2a48
git diff --stat 96ac94c..28d2a48
```

As áreas de produção alteradas incluem:

- `src/arena/arena.gd`, `arena_overlay.gd`, `intro_kit.gd` e
  `panel_kit.gd`: dispatch, modal state, layout, cache e lifecycle;
- `src/ui/hud.gd`, `glyph_lib.gd`, `menu.gd`, `menu_chrome_kit.gd`,
  `menu_settings_kit.gd` e `tactical_state_surface.gd`: HUD, shell, glyphs,
  foco, overlays e settings;
- `src/ui/program_panel.gd`, `story_panel.gd`, `bestiary_panel.gd` e
  `terminal_panel.gd`: rotas legadas, seleção, retorno e terminal;
- `src/ui/vnext/ui_chrome.gd`, `ui_context.gd`, `ui_layout.gd` e
  `src/ui/vnext/surfaces/`: Boot, Program, Story, Bestiary, Patch, HUD,
  Pause, Terminal, Game Over, Accessibility e shared state;
- `src/ui/vnext/core/entity_renderer.gd`: integração code-drawn;
- `src/autoload/harness/sections_*.gd`: gates e contagens do DevHarness;
- `tools/validate_input_dispatch.sh`: agregação, timeout, save isolado,
  áudio dummy, completion markers e separação de erros;
- probes focados de resize, escala, legibilidade, estados, overlays, foco,
  cache, tweens e boss bars.

Commits da branch atual, em ordem:

```text
27fff38 feat(ui): rebuild reference shell and selection surfaces
2f06b3e feat(ui): author code-drawn entity silhouettes
498144b fix(ui): reflow vnext overlays across physical windows
de2f0ba docs: record reference remake and validation
7f5dcb7 feat(ui): unify vnext incident console chrome
8a76a8c docs(ui): record incident console direction review
37e160b docs(ui): audit reference remake documentation
469a156 docs: version consolidated ui audit and backlog
3630a38 feat(ui): bring story selection into incident console
a7dd7c5 feat(ui): unify patch offer with incident console
5246554 feat(ui): compose reference-driven combat hud
3e3c9ee docs: record reference-driven combat hud pass
3938337 fix: restore the legacy menu launch prompt
6f1d91c fix: require deliberate pause destructive actions
3f641e4 docs: record menu prompt and pause confirmations
64bec6f fix(ui): restore combat banner hierarchy
9af6992 fix(ui): bound legacy hud secondary copy
9ceae34 fix(ui): improve legacy hud text legibility
3848c2c test(ui): audit hud stretch matrix
00fa846 fix(ui): expose explicit legacy hud states
e5c9c7c fix(ui): close legacy layout collision gaps
b544075 test(ui): align touch HUD source gate
12db675 fix(ui): suppress effects over modal panels
1d6032a refactor(ui): remove dead HUD widgets
b63c968 docs: correct h7 validation count
6ac3d9b fix(ui): add legacy state-panel keyboard focus
829f5e3 fix(ui): unify legacy overlay back position
3a13510 fix(ui): keep bestiary selection in view
4317ed6 fix(ui): scope fullscreen setting to desktop
7ee2bbf perf(ui): cache repeated layout work
35077b8 fix(ui): cancel overlapping presentation tweens
28d2a48 fix(ui): remove split boss bar ghosts
```

O delta herdado do plano mestre continua no ancestral `96ac94c` e inclui
gameplay, save, MAC-OS history, base PT-BR, accessibility profile e repository
governance. Ele está no relatório histórico e nos handoffs próprios; não foi
reescrito nem squashed.

## 6. Verificação

### 6.1 Gate acumulado

Comando executado:

```sh
KP_VALIDATION_TIMEOUT_SECONDS=120 \
KP_VALIDATION_LOGS=/tmp/kernel-panic-p4-validation-final \
tools/validate_input_dispatch.sh
```

Resultado registrado em `/tmp/kernel-panic-p4-validation-final.log`:

```text
VALIDATION OK (teardown diagnostics above remain non-gating)
1454 AT_PASS
0 AT_FAIL
AUTOTEST_ALL_PASS
```

Não houve `SCRIPT ERROR` ou runtime `ERROR` gateável. Diagnósticos de
teardown ficaram visíveis no log e são listados abaixo; não foram silenciados.

### 6.2 Matriz headless

| Grupo | Passes | Falhas |
| --- | ---: | ---: |
| input / R04 / R05 / R06 / R07 / R08 | 38 / 7 / 28 / 7 / 4 / 7 | 0 |
| B1 / B2 / B5 / B6 | 10 / 8 / 11 / 9 | 0 |
| H1 / H2 / H3 / H4 | 10 / 8 / 24 / 12 | 0 |
| H5 / H6 / H7 | 69 / 25 / 28 | 0 |
| N1 / N2 / N3 / N4 | 16 / 17 / 28 / 9 | 0 |
| R18 / primitives / entity illustration | 6 / 18 / 143 | 0 |
| E2 / E3 / E4 / E5 | 77 / 35 / 20 / 18 | 0 |
| G1 / Page Cache / Ring-0 / display | 29 / 13 / 14 / 12 | 0 |
| G3 / G4 | 44 / 52 | 0 |
| vNext Boot / selection / Bestiary | 102 / 225 / 128 | 0 |
| vNext routes / Patch / Patch Arena | 22 / 67 / 19 | 0 |
| vNext Combat HUD / state / Accessibility | 76 / 75 / 98 | 0 |
| vNext shared state / M5 / A11-A14 | 145 / 25 / 9 | 0 |
| P1 cache / P3 tweens / P4 boss bar / stress | 15 / 6 / 10 / 9 | 0 |

### 6.3 Xvfb, desktop debug e touch forçado

| Grupo | Passes | Falhas |
| --- | ---: | ---: |
| input desktop/debug | 40 | 0 |
| H3 HUD scale | 29 | 0 |
| G2 display | 12 | 0 |
| N4 display desktop / touch | 11 / 9 | 0 |
| G3 / G4 | 44 / 52 | 0 |
| state surfaces | 75 | 0 |
| physical menu / Arena overlays | 8 / 12 | 0 |
| Accessibility / shared state | 98 / 145 | 0 |
| M5 / A11-A14 | 25 / 9 | 0 |
| P1 / P3 / P4 / stress | 15 / 6 / 10 / 9 | 0 |

O input probe Xvfb registrou
`PROBE_INFO debug_controls_enabled=true`. Isso prova o contexto em que a
regressão de ESC existia; um headless verde sozinho não bastaria.

### 6.4 Red/green dos últimos lotes

- **P1:** red identificou ausência de contrato de cache e relayout duplicado;
  uma segunda revisão removeu a invalidação dupla; green 15/15 headless e
  15/15 Xvfb.
- **P3:** red reproduziu timelines acumulados em tips/intros; green 6/6 em cada
  ambiente, incluindo o collapse atrasado cancelável.
- **P4:** red reproduziu a linha fantasma e título hardcoded; green 10/10 em
  cada ambiente, com fragmentos vivos, identidade A/B e título da variante.

## 7. Performance, teardown e compatibilidade

### Performance

O stress usa seed fixa, 120 frames, 48 inimigos reais e 96 projéteis reais,
com pico de 144 atores. A execução pós-publicação registrada em
`/tmp/kernel-panic-final-checkpoint-20260902-post/` mediu:

| Perfil | p50 | p95 | p99 | pior frame | pico |
| --- | ---: | ---: | ---: | ---: | ---: |
| headless | 16,673 ms | 16,949 ms | 17,279 ms | 17,379 ms | 144 |
| Xvfb/llvmpipe | 5,410 ms | 9,406 ms | 9,727 ms | 10,101 ms | 144 |

Isso é baseline de regressão, não promessa de 60 FPS na Vega integrada,
Android ou uma sessão longa.

### Teardown e save

Persistem diagnósticos variáveis de shaped text/font, texturas dummy/GL,
recursos em uso e, em alguns fixtures, `GodotArea2D`/ObjectDB. O validador
separa esses tipos conhecidos de erros de runtime, mas não declara os leaks
resolvidos. O próximo passe P5 precisa atribuir cada recurso a um owner,
provar repeated restart/overlay/scene exit e classificar backend versus leak do
jogo.

O slice visual não alterou caminho, schema ou regras de record. A base herdada
rejeita payload inválido e anuncia conclusão depois do checkpoint, mas ainda
falta journal/backup/replace atômico e injeção de falha de escrita.

### Compatibilidade

- saves, IDs de fases, keybinds e transfer v1 permanecem compatíveis;
- a capacidade máxima de duas boss rows continua sendo o contrato geométrico;
- fullscreen continua persistido no desktop; apenas o controle desaparece em
  touch;
- não há conta, anúncio, rede, analytics ou dependência online;
- a vNext é opt-in, portanto o fallback legado continua disponível.

## 8. Decisões principais

### Legado como fallback

Foi mantida a rota legada como default e a vNext como opt-in. Substituir tudo
de uma vez foi rejeitado porque a direção visual ainda precisa de aprovação e
porque rollback de uma UI acoplada ao gameplay seria ruim. O custo aceito é
duplicação temporária; a remoção dos switches depende de aprovação visual,
fluxo manual, matriz e export.

### Shell compartilhado, composição específica

Rails, metadata, tipografia, tokens e action model são compartilhados, mas
Boot, Story, Bestiary, Patch e HUD mantêm composições próprias. Um único card
para todas as telas foi rejeitado porque as referências têm linguagem comum,
não geometria idêntica.

### Code-drawn como arte principal

Silhueta, estado e telegraph vêm do renderer code-drawn. Sprites foram mantidos
opcionais para não virar fonte de verdade antes de fechar a gramática visual.
O trade-off é aceitar mais trabalho manual de desenho e revisão; bounds verdes
não são prova de beleza.

### Cache de uma entrada

O cache usa chave de viewport, density, touch scale e estado relevante. Recalcular
sempre desperdiça trabalho; cache ilimitado aumenta memória e ownership.
Alternância artificial entre dois viewports por frame fica fora do benefício
esperado. P1 confirmou hits, invalidação e ausência de relayout ocioso.

### Última animação vence

Uma nova dica/intro cancela a timeline anterior. Deixar dois tweens terminarem
ou resetar só alpha/scale manteria escritas tardias e contraditórias. A
interrupção da curva antiga é um trade-off aceitável para manter o estado atual
correto.

### Boss bar baseada em fragmentos vivos

O layout fornece capacidade máxima; o snapshot decide quantas linhas existem.
Esconder somente fração zero deixaria uma entidade visual inexistente, e mudar
o contrato geométrico quebraria callers. As linhas são compactadas, preservando
o rótulo A/B.

## 9. Known Issues e incertezas

### Ainda não fechados para release

1. migração visual completa e remoção segura dos switches;
2. aprovação humana contra `media/Ideas/`, inclusive grayscale e sem glow;
3. passe code-drawn do elenco completo em gameplay;
4. PT-BR de todos os literais player-facing e revisão nativa;
5. screen reader, high contrast completo, text scale e remapping/gamepad;
6. auditoria total de reduced motion/flashes e telegraphs redundantes;
7. export Linux/Windows/Android e instalação em aparelho;
8. touch físico, lifecycle Android, insets/cutout, back e IME;
9. medição na Vega integrada e Android mínimo, incluindo soak/thermal;
10. teardown categorizado, save recovery crash-safe e CI hospedado;
11. hashes, proveniência, versão, licença/atribuições, instalação e rollback;
12. playtest de onboarding, fairness, telegraphs, economy, Mac act, inimigos e
    intensidade de efeitos.

### Comprovado

- suite/probes exigem marcador e terminaram verdes;
- input real, foco, resize físico, safe-area lógica, touch forçado e rotas
  principais foram exercitados;
- caches não repetem trabalho com os mesmos parâmetros;
- reentrada de dicas/intros não acumula timelines no caso coberto;
- boss split não fabrica linha para fragmento ausente no caso coberto;
- o slice visual não alterou save/schema/balanceamento;
- branch publicada e checkout original preservado.

### Hipóteses ainda abertas

- a composição final será aprovada sem mudança de densidade/hierarquia;
- os números de performance representam hardware alvo;
- teardown restante é backend/fixture nos casos ainda não atribuídos;
- a cobertura de efeitos reduzidos é suficiente para uso real;
- o escopo atual de accessibility e o ritmo de novos encontros atendem
  jogadores reais.

## 10. Próximos passos

1. abrir e comparar as superfícies vNext com `media/Ideas/`, primeiro limpas
   e depois com efeitos;
2. decidir ajustes visuais concretos e aprovar a migração tela por tela;
3. fechar P5 de teardown/startup e save recovery com evidência;
4. completar PT-BR e playthrough editorial;
5. completar code-drawn do cast e captures estruturais/effect layer;
6. executar matriz de accessibility, viewport, touch e lifecycle;
7. gerar exports e medir Linux/Windows/Android em hardware declarado;
8. playtestar gameplay, telegraphs, balance, Mac act, mobile e PC;
9. atualizar checklist, hashes, versão, licenças, instalação e rollback;
10. somente então produzir release candidate e considerar tag pública.

## 11. Artefatos de release

- [release notes do remake](release/2026-09-02-ui-reference-remake.md);
- [changelog consolidado](CHANGELOG-PLAN-EXECUTION.md);
- [handoff técnico completo](HANDOFF-UI-REFERENCE-REMAKE.md);
- [direção visual](UI-REDESIGN-DIRECTION.md);
- [gramática code-drawn](ART-DIRECTION-CODE-DRAWN.md);
- [checklist de release](RELEASE-CHECKLIST.md);
- [plano mestre](superpowers/plans/2026-08-31-kernel-panic-master-plan/00-MASTER-PLAN.md).

## 12. Conclusão

O código chegou a um checkpoint de qualidade de desenvolvimento que vale ser
preservado: a direção visual não está mais difusa entre telas, os fluxos
legados estão mais honestos, os bugs de lifecycle mais perigosos têm provas
reais, e o validador não aceita execução vazia como sucesso.

A decisão correta agora é tratar esta branch como **pré-release revisável**.
O próximo salto não é adicionar brilho aleatoriamente: é validar a gramática,
completar a migração, medir os alvos reais e fechar os riscos listados. Publicar
antes desses gates seria confundir um excelente checkpoint técnico com um
produto terminado.

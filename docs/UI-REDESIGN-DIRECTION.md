# KERNEL PANIC — direção visual nova

Status: direção registrada para a próxima etapa. Este documento substitui a
ideia de polir indefinidamente o menu e os painéis atuais. A próxima UI deve
ser desenhada do zero, em uma família nova de superfícies, usando o jogo atual
como fonte de estado e regras — não como molde visual obrigatório.

Estado de execução em 2026-09-02: o vertical slice vNext já aplica esta
direção a Boot, Program, Story, Bestiary e Accessibility. Story foi incluída
posteriormente na mesma gramática `incident console` depois de uma revisão que
detectou que a primeira composição ainda era uma exceção visual. Isso é uma
prova de direção e não a aprovação da UI final nem o encerramento das etapas de
mobile, localização, acessibilidade de plataforma e performance.

## Tese

KERNEL PANIC deve parecer uma máquina hostil que foi desenhada por um técnico,
não um painel genérico coberto de neon. O código desenhado é a arte principal:
linhas com intenção, silhuetas legíveis, ritmo de terminal e estados visíveis.
Glow, scanline e ruído só entram depois que a forma funciona sem eles.

O objetivo é que uma captura em preto e branco ainda permita responder:

- onde estou;
- o que está vivo, carregado, bloqueado ou pronto;
- qual ação é primária;
- qual informação mudou agora;
- qual perigo merece atenção primeiro.

## Limites da direção

- A UI atual não é um contrato visual. Não migrar suas caixas, espaçamentos ou
  hierarquia apenas porque já existem.
- A lógica de gameplay, estado de `Game`, input, save e regras de balanceamento
  continua sendo preservada e testada.
- Estrutura, componentes e desenho podem ser substituídos quando a nova
  composição pedir isso.
- Inimigos e programas continuam code-drawn. Cada entidade deve ganhar uma
  silhueta própria, uma linguagem interna e estados de leitura; não serão
  apenas ícones genéricos com outra cor.
- Sprites/raster entram seletivamente em ilustrações estáticas, fundos com
  textura ou elementos que realmente ganhem com pintura. Nunca devem virar a
  fonte de verdade de layout, estado ou legibilidade.

## Decisões herdadas

- O bloco atual de correções de layout e fluxo está aprovado como trabalho
  técnico e como estado intermediário jogável.
- Essa aprovação não transforma a composição atual em direção visual final e
  não obriga a preservá-la durante a reconstrução.
- A direção híbrida está aprovada em princípio; telas finais, paleta final,
  wireframes finais e arquitetura definitiva ainda precisam passar pela
  revisão visual durante a construção.

## Leitura das referências em `media/Ideas`

As imagens disponíveis nessa pasta são um moodboard de direção, não uma
especificação pixel-perfect. Elas mostram com clareza a família visual que
vale perseguir, mas textos, números, coordenadas, proporções e detalhes ainda
estão abertos. Telas ou imagens que não aparecem na pasta continuam decisões
em aberto; a ausência de uma referência não deve ser tratada como requisito
implícito.

| Arquivo | Referência | O que ela ensina |
| --- | --- | --- |
| `imagem1.png` | menu principal | shell persistente, marca grande, telemetria lateral e uma ação primária inequívoca |
| `iamgem9.png` | mapa/story | navegação por nós, progresso de capítulos e briefing contextual em três áreas |
| `imagem10.png` | seleção de programas | lista à esquerda, ficha detalhada à direita e ação de execução sempre visível |
| `imagem2.png` | bestiary | catálogo + dossiê, estatísticas comparáveis e silhueta como identidade |
| `imagem3.png` | configurações | navegação lateral e grupos de opções separados por responsabilidade |
| `imagem4.png` | awards | grade de cartões, progresso e distinção clara entre desbloqueado, progresso e bloqueado |
| `imagem5.png` | HUD de combate | bordas periféricas, centro livre, ameaça e feedback temporário acima da arena |
| `imagem6.png` | pausa | jogo ainda visível e escurecido, menu curto e foco de seleção explícito |
| `imagem7.png` | morte/game over | diagnóstico dramático, resumo da run e duas decisões finais bem separadas |
| `imagem8.png` | terminal de pausa | console diegético, histórico de eventos e painéis de diagnóstico ao lado |

O nome `iamgem9.png` está grafado assim no diretório e é mantido como está;
não vale criar ruído de versionamento só para corrigir o nome de um asset de
referência.

### O que deve sobreviver na nova UI

- Um **shell de sistema** recorrente: estado online/offline/pausado, rota
  atual, usuário ou sessão e uma telemetria discreta. Ele deve dar unidade às
  telas, sem transformar todo painel em um retângulo decorativo.
- Composição assimétrica e editorial: marca, navegação e diagnóstico não
  precisam ocupar a mesma largura nem compartilhar o mesmo alinhamento.
- Tipografia grande e espaçada para títulos, texto monoespacial curto para
  telemetria e valores, e uma leitura de contraste ciano/branco com magenta
  reservado para falha, ameaça ou bloqueio.
- Seleção visível como estrutura, não só como mudança de cor: barra lateral,
  brackets, cursor, linha de conexão ou mudança de peso podem indicar foco.
- Dados organizados como instrumentos: barras segmentadas, contadores,
  pequenos glyphs e linhas de separação devem ajudar a comparar estados.
- A arena deve respirar. A referência do HUD usa o perímetro para informação e
  deixa o centro para inimigos, projéteis, motes e leitura de perigo.
- Cada tela deve ter uma ação dominante. Uma tela pode ter várias áreas de
  informação, mas o jogador nunca deve precisar adivinhar qual comando fecha,
  confirma, executa ou retorna.

### O que continua exploratório

Não estão aprovados como contrato: a cópia exata das telas, o texto em inglês,
os números exibidos, a versão `0.2.3`, os valores de exemplo, o slogan, a
presença obrigatória das rails laterais, a quantidade de colunas, o mapa de
fundo, o ruído de CRT, cada microtraço ou a reprodução de uma fonte específica.
Esses elementos podem ser removidos quando não melhorarem a leitura do jogo.

As imagens são composições desktop muito densas. Elas provam uma direção de
arte e hierarquia, não que a mesma quantidade de informação deva caber numa
tela pequena. O critério é preservar a personalidade e o diagnóstico, não
preservar cada ornamento.

### Regra de simplificação

Todo detalhe precisa pagar seu custo em pelo menos uma destas moedas:

1. identifica uma tela, entidade ou estado;
2. melhora a navegação ou a comparação de dados;
3. dá feedback sobre uma mudança recente;
4. reforça a atmosfera sem competir com os três itens anteriores.

Se não pagar nenhuma dessas moedas, o detalhe sai. Em especial, grade,
scanline, glow, ruído, conectores e microglyphs devem ser camadas opcionais e
reduzíveis. Primeiro aprovamos silhueta, agrupamento, espaçamento, foco e
contraste em uma captura limpa; depois adicionamos acabamento com orçamento
limitado por tela.

## Adaptação para PC e mobile

A referência visual nasce de uma tela larga, mas a implementação não pode ser
um desktop encolhido. O layout deve calcular uma `safe_rect` lógica e escolher
uma composição por espaço disponível, nunca por resolução física fixa.

### Composições por espaço disponível

- **Largo:** pode usar shell completo, rails, duas ou três áreas de conteúdo e
  ficha lateral. É o alvo para o menu, story, bestiary, settings e awards.
- **Compacto:** recolhe telemetria secundária, reduz decoração e transforma
  fichas lado a lado em duas etapas ou duas colunas leves. A ação primária e o
  retorno continuam sempre visíveis.
- **Estreito:** usa uma coluna, cabeçalho curto, navegação explícita e conteúdo
  empilhado. Lista e detalhe viram estados navegáveis; a grade de awards vira
  lista ou cartões de uma coluna; o terminal prioriza o stream e o comando.

Os limites exatos ficam nos tokens e são validados pela geometria real, não
copiados deste documento. Como matriz inicial: 1366×768, 720×720 e 432×720.
Uma superfície só passa quando não depende de hover, não trunca texto, não
esconde o botão de voltar e não coloca informação crítica sob os controles de
touch.

### Regras de interação adaptativa

- Mouse, teclado e touch devem apontar para a mesma geometria de ação e o
  mesmo estado semântico.
- Alvos acionáveis precisam de área confortável, com pelo menos 44–48 px
  lógicos conforme o contexto; o desenho pode ser menor que a área de toque.
- Foco de teclado e toque devem ter um marcador visível equivalente. Cor
  sozinha nunca pode ser a única diferença entre selecionado, bloqueado e
  pronto.
- Em mobile, ações raras vão para uma camada secundária; a ação principal,
  retorno, pausa e estado de perigo permanecem na primeira leitura.
- No HUD, os controles virtuais ocupam cantos reservados e não podem cobrir
  player, ameaça ou pickups. O centro continua sendo espaço de jogo.
- Em telas de alta densidade, ornamentos perdem prioridade antes de texto,
  foco, feedback e estado. Não reduzir tudo proporcionalmente até virar
  microtexto.

### Mapeamento das referências para a implementação

As imagens não serão importadas como painéis nem usadas como fundo de UI. A
tradução pretendida é:

- shell, rails, brackets, separadores e barras → `ui_primitives.gd`;
- menu, seleção, story, settings, bestiary, awards, pausa e morte →
  superfícies com snapshots e composição responsiva;
- glyphs de programas, inimigos e patches → ilustrações code-drawn com
  silhueta, estado e fallback verificáveis;
- textura, ruído ou ilustração estática, se ainda fizer sentido depois do
  teste em preto e branco → raster seletivo, fora da fonte de verdade;
- input, foco, safe area e hit test → contrato comum, incluindo touch.

O primeiro vertical slice deve capturar a sensação de `imagem1.png` sem
reconstruir o menu atual: shell mínimo, marca, uma ação de boot, uma ilustração
code-drawn e uma variante estreita. Depois dele, a mesma linguagem pode ser
testada no HUD de `imagem5.png` antes de expandir para as telas de dados.

## Linguagem visual

### Forma

- Fundo quase preto azul-marinho, com grade fina e baixa opacidade.
- Frames angulares assimétricos, com cortes que indiquem entrada, saída ou
  perigo. Evitar retângulos idênticos em todos os componentes.
- Uma composição tem no máximo um foco primário, dois focos secundários e um
  campo de informação auxiliar.
- Texto curto. Nomes de estado devem ser verbos ou diagnósticos claros:
  `BOOT`, `MOUNT`, `READY`, `LOCKED`, `PURGE`, `REBOOT`.

### Cor

A cor continua semântica, nunca cosmética:

| Papel | Leitura |
| --- | --- |
| ciano | estrutura, navegação, informação estável |
| magenta/vermelho | dano, ameaça, interrupção |
| âmbar | aviso, custo, estado intermediário |
| lime | recuperação, proteção, pronto |
| branco frio | foco atual e informação primária |

Todo estado colorido precisa de pelo menos mais uma pista: texto, forma,
posição, padrão ou ícone.

### Code-drawn como ilustração

Cada desenho importante deve ser construído em quatro camadas, nesta ordem:

1. **silhueta** — reconhecível a 24 px e a 96 px;
2. **estrutura** — circuitos, fissuras, núcleo, membros ou módulos que deem
   identidade;
3. **estado** — o que acende, abre, quebra, gira ou pulsa quando a regra muda;
4. **acabamento** — halo, scan, partículas e micro-ruído, sempre removíveis.

Exemplo de inimigo code-drawn: um `OOM_KILLER` não deve ser um círculo roxo.
Sua forma pode ser uma célula comprimida com uma boca de coleta, dois trilhos
de carga e slots orbitais que aparecem quando carrega motes. Quando foge,
esses trilhos apontam para a borda; quando morre, os slots se abrem e liberam
o saque. A animação explica a regra.

Exemplo de programa code-drawn: o `ROOTLET` deve ter um núcleo protegido por
placas concêntricas e uma linha de escudo que fecha quando a carga termina.
`KERNEL` pode ser uma seta modular e `DAEMON` uma forma bifurcada, mas cada
variante precisa ser identificável sem depender da legenda.

## Exemplos de composição

Os wireframes abaixo são intenção de hierarquia, não coordenadas para copiar.

### Menu de boot

```text
┌ status rail ───────────────────────────────────────────────────────┐
│ KERNEL PANIC                                      RUN 042 / LOCAL   │
│                                                                    │
│                         LAST PROCESS                               │
│                    [ KERNEL / DAEMON / ROOTLET ]                  │
│                                                                    │
│                         [  BOOT  ]                                │
│                   [ story ] [ mode ]                              │
│                                                                    │
│  [settings]       [bestiary]       [awards]      ↑ input hint      │
└────────────────────────────────────────────────────────────────────┘
```

O botão de boot é a única massa dominante. Seleção de programa não deve ficar
escondida em texto lateral; a silhueta e as três diferenças decisivas precisam
ser lidas antes do ENTER.

### HUD de combate

```text
┌ integrity / program ────────────────────── cycle / encounter ─────┐
│ HP  ●●●●    KERNEL                                CYCLE 07         │
│                                                                    │
│                         arena livre                               │
│                                                                    │
│ dash / cooldown                                      score / log   │
│                                                                    │
│                     boss integrity / phase                         │
└────────────────────────────────────────────────────────────────────┘
```

O centro fica quieto para o combate. O HUD não deve competir com inimigos,
projéteis ou pickups; eventos usam uma faixa temporal curta e depois cedem o
espaço ao estado contínuo.

### Pausa e terminal

```text
┌ frozen process ────────────────────────────────────────────────────┐
│ PAUSED                         RUN STATE / SCORE / CYCLE            │
│                                                                    │
│ [RESUME]       [RESTART]       [TERMINAL]                          │
│                                                                    │
│ [ABANDON PROCESS]              warning: action is irreversible     │
└────────────────────────────────────────────────────────────────────┘

┌ TTY0 / FROZEN ─────────────────────────────────────────────────────┐
│ event stream                              command index             │
│                                                                    │
│ kernel@panic:~$ _                         ↑↓ history / TAB complete │
└────────────────────────────────────────────────────────────────────┘
```

Pausa é uma decisão de estado. Terminal é uma estação de diagnóstico. Os dois
podem compartilhar tokens e frames, mas não devem parecer o mesmo componente
com títulos trocados.

## Arquitetura proposta

A nova UI deve viver em uma camada separada até cada tela atingir o aceite.
Uma possível divisão, a validar no primeiro vertical slice:

```text
src/ui/vnext/
  ui_tokens.gd       # escala, tipografia, papéis de cor e espaçamento
  ui_primitives.gd   # frame, rail, meter, glyph, focus, status tag
  ui_surface.gd      # safe area, viewport, input e composição de camadas
  menu_surface.gd
  hud_surface.gd
  pause_surface.gd
  terminal_surface.gd
  entity_illustration.gd
```

Princípios de código:

- um token tem uma definição, não uma cópia por tela;
- geometria recebe viewport e safe area, nunca presume 1280×720 físico;
- desenho e hit test compartilham a mesma geometria;
- estado visual é derivado de um snapshot pequeno, não de chamadas espalhadas
  em `_draw()`;
- `queue_redraw()` só ocorre quando estado ou viewport mudam;
- cada superfície publica `text_overflow_report()` e um snapshot semântico;
- nenhum componente novo usa texto desenhado manualmente como substituto de
  um controle acionável;
- telas antigas só são removidas depois que a nova tela tem teste de fluxo,
  matriz de viewport e captura revisada.

## Critérios de qualidade

Cada superfície nova precisa passar por:

1. leitura sem efeitos: hierarquia, silhueta e contraste;
2. 1366×768: composição completa;
3. 720×720: janela compacta sem colisão;
4. 432×720: modo estreito sem texto truncado ou ação inacessível;
5. teclado, mouse e touch quando a tela os suporta;
6. captura silenciosa real sob Xvfb, guardada fora do repositório;
7. suíte DevHarness e probe específico antes do commit.

O efeito visual não está aprovado porque existe no código: ele está aprovado
quando a regra que ele representa é legível em movimento e em uma captura
parada.

## Ordem de construção

1. contratos de snapshot e tokens, sem alterar a UI antiga;
2. vertical slice do menu de boot com um frame, um botão e uma ilustração;
3. biblioteca code-drawn de programas/inimigos com comparação de silhueta;
4. HUD de combate, priorizando espaço de jogo e estado de ameaça;
5. pausa e terminal como superfícies de estado distintas;
6. seletores de programa, story, patches e bestiary;
7. migração de settings, game-over e touch;
8. remoção do legado morto, depois de todas as rotas antigas estarem cobertas.

Não implementar B6/B7/H1–H7/N1–N4 apenas para deixar a UI antiga mais bonita.
Qualquer bug de lógica, input, save, entidade, spawner ou teste continua sendo
corrigido imediatamente; microajustes visuais aguardam a superfície nova.

## Estado técnico conhecido

Os lotes R01–R10, T01–T04 e B1/B2/B5 estão registrados nos handoffs
versionados. R09 foi revalidado como falso positivo e ganhou cobertura direta
para motes em 0, 0,5, 1 e 2 px. A validação atual não possui erros de
script/runtime; os diagnósticos restantes são de recursos/RIDs no teardown dos
testes e continuam explicitamente separados até haver uma atribuição segura.

## Plano de execução

O caminho completo de produto, refatoração, remake, conteúdo, PT-BR,
acessibilidade, PC/mobile, performance, open source e release está dividido
em [um plano-mestre com micro-documentos](superpowers/plans/2026-08-31-kernel-panic-master-plan/README.md).
Este arquivo define a direção visual; o plano define como transformá-la em
software verificável sem reabrir ou polir indefinidamente a UI legada.

## Revisão visual posterior — 2026-09-02

A primeira composição vNext foi comparada lado a lado com `media/Ideas/imagem1.png`,
`imagem2.png`, `imagem3.png` e `imagem10.png`, além de `media/menu.png` e das
capturas da UI anterior. A conclusão é deliberadamente crítica: a estrutura
vNext já deixou de ser uma migração direta da UI antiga, mas ainda pode parecer
um wireframe de terminal. Moldura, grid, ciano e título não constituem uma
identidade por si só.

### Lacunas comprovadas na comparação

- o menu vNext tem shell e comando, mas deixa um volume grande de espaço sem
  informação operacional equivalente à densidade das referências;
- Program e Bestiary têm a divisão índice/dossiê correta, porém a área de
  análise ainda não tem o mesmo ritmo de cartões, métricas e linhas de leitura
  das referências;
- Accessibility está funcional e sem clipping, mas visualmente é uma lista
  vertical isolada, não uma estação de configuração com contexto de sistema;
- a gramática de shell existe em cada superfície, mas parte dela ainda está
  duplicada localmente, o que permite pequenas diferenças de espaçamento,
  rodapé e hierarquia entre telas;
- os cinco silhouettes code-drawn reforçados ganharam identidade, mas o
  acabamento deve continuar sendo julgado como arte em gameplay, não apenas
  como um contrato semântico do dossiê.

### Decisão de direção consolidada

O próximo passe não será “adicionar neon” nem preencher vazio com ruído. A UI
seguirá uma direção única de **incidente operacional**: KERNEL PANIC é uma
workstation hostil acompanhando um processo vivo. Toda tela deverá responder,
visualmente e sem depender da cor, a quatro perguntas: qual é a rota, qual é o
estado do sistema, qual objeto está sendo inspecionado e qual é a próxima ação.

Essa direção combina a assimetria e o dossiê das referências com o peso heroico,
o contraste de estado e a densidade de telemetria da primeira versão de
`media/menu.png`. Os elementos recorrentes serão:

1. shell e rota persistentes;
2. trilho de telemetria/calibração nas bordas, com uso moderado;
3. blocos de dados reais ou explicitamente diagnósticos, nunca texto aleatório;
4. conectores e marcadores que expliquem relação ou foco;
5. um motivo code-drawn grande o bastante para funcionar como identidade,
   não como ícone decorativo;
6. uma ação dominante e um caminho de retorno inequívoco.

### Regra contra falsa densidade

Antes de adicionar qualquer detalhe, o implementador deve classificá-lo como
identidade, estado, navegação, comparação ou atmosfera. Identidade, estado,
navegação e comparação precisam de uma fonte de dados ou contrato verificável.
Atmosfera só entra depois que as quatro primeiras categorias estiverem legíveis
em uma captura limpa. Linhas, grids, glows e números sem função não contam como
acabamento e devem ser removidos.

### Critério para o próximo passe

Uma captura wide de Boot, Program, Bestiary e Accessibility precisa mostrar a
mesma família visual sem parecer a mesma tela repetida. A versão narrow deve
preservar a leitura operacional em uma coluna, sem resolver densidade com
microtexto. O passe só será considerado tecnicamente concluído quando houver
um probe de chrome/semântica, overflow por fonte real, captura limpa e
comparação contra as referências; a aprovação estética final continua sendo
humana e não será inferida dos testes.

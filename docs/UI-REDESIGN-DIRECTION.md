# KERNEL PANIC — direção visual nova

Status: direção registrada para a próxima etapa. Este documento substitui a
ideia de polir indefinidamente o menu e os painéis atuais. A próxima UI deve
ser desenhada do zero, em uma família nova de superfícies, usando o jogo atual
como fonte de estado e regras — não como molde visual obrigatório.

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

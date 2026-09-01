# E3 — program identity runtime slice

## Objetivo e escopo

E3 cria a primeira fronteira de apresentação dos programas reais. KERNEL,
DAEMON e ROOTLET agora chegam aos consumidores vNext como identidade estável,
orientação e estado runtime somente-leitura. O lote cobre o seletor de
programas, o combat HUD e a pausa; não promove vNext, não reescreve a UI
legada e não altera regras de gameplay.

## Achado principal

`Game.PROGRAM_DEFS` não possui `kind`. O adapter anterior tentava ler
`prog.kind` e usava `kernel` como fallback, fazendo DAEMON e ROOTLET serem
renderizados como KERNEL. O probe vermelho reproduziu isso em instâncias reais
de `Player`: exit 1, 16 falhas e marcador ausente.

## Decisão técnica

Foi adotado um mapa explícito e estável `program_id -> kind` no adapter,
mantendo a identidade canônica no `Player.program_id`, inicializada a partir de
`Game.program` em `_ready()`. O snapshot expõe `program_id`, `kind`, aim,
integridade, overclock, dash, shield, morte e invulnerabilidade sem comandos ou
escritas. O renderer continua recebendo um descriptor normalizado e não acessa
Game/Sfx/Fx nem cria estado gameplay.

Alternativas descartadas: inferir o tipo a partir de strings de silhouette
(frágil e acoplado à arte); adicionar `kind` duplicado em cada definição (risco
de divergência entre save/catalog e apresentação); usar flags de preview no
HUD (não representa o Player real). A limitação aceita é o mapa explícito exigir
atualização se um quarto programa for adicionado — o probe deve falhar até que
esse contrato seja definido.

## Antes e depois

- Antes: adapter real lia apenas `prog`, caía em KERNEL quando `kind` faltava e
  os consumidores usavam `Game.program`/flags parciais.
- Depois: adapter chama `Player.presentation_snapshot()`, resolve os três IDs
  distintamente, preserva aim e projeta fatos atuais. O HUD deriva o estado de
  habilidade do snapshot; pausa recebe e publica o mesmo payload; seletor usa o
  mapa estável, sem substituir nomes de silhouettes.
- ROOTLET tem cor distinta (`Balance.COL_MOTE`) no renderer. No modo narrow o
  placar usa 16px para caber; os demais tamanhos preservam o desenho existente.

## Arquivos

- `src/player/player.gd`: contrato de snapshot e `program_id` runtime.
- `src/ui/vnext/core/entity_presentation_adapter.gd`: mapa e projeção real.
- `src/ui/vnext/core/entity_renderer.gd`: cor distinta do ROOTLET.
- `src/ui/vnext/surfaces/program_surface.gd`: identidade estável no preview.
- `src/ui/vnext/surfaces/combat_hud_surface.gd`: identidade/status reais e
  overflow narrow.
- `src/ui/vnext/surfaces/pause_surface.gd`, `src/arena/arena.gd`: handoff e
  semântica de pausa.
- `src/ui/hud.gd`: consumidor HUD permanece ligado ao player real.
- `tools/e3_program_identity_probe.gd/.tscn`: probe focused.
- `tools/validate_input_dispatch.sh`: entrada acumulada.

## Testes e correções durante a revisão

1. Red primeiro: `16` falhas, sem crash.
2. Primeira implementação: `29` passes; o próprio probe encontrou cor
   duplicada do ROOTLET, expectativa errada de dash e overflow do placar em
   432px. Tudo foi corrigido.
3. Headless final: exit 0, `29 PROBE_PASS`, `0 PROBE_FAIL`, marcador exato.
4. Xvfb final: exit 0, `29/0`; apenas warning de V-Sync e diagnósticos de
   encerramento conhecidos.
5. Import: exit 0; aviso ambiental de Android build-tools ausente.
6. Suíte: exit 0, `1414 AT_PASS`, `0 AT_FAIL`, `AUTOTEST_ALL_PASS`.
7. Validador acumulado final: todas as fatias verdes, incluindo E3 `29/0`,
   input Xvfb `34/0`, E1 `136/0`, E2 `76/0`, e sem runtime ERROR gating.

Houve uma execução acumulada inicialmente rejeitada porque o probe emitia
`PROBE_DONE fails=0 passes=29`, enquanto o validador exige a linha exata. O
marcador foi corrigido em `b6e6eaa` e o validador foi executado novamente.

## Compatibilidade, performance e riscos

Não há breaking change intencional: gameplay, input, saves, balance, áudio,
RNG, rotas e UI legada permanecem intactos; vNext segue opt-in. O snapshot
aloca um Dictionary quando chamado, portanto deve permanecer em sincronização
de UI/adaptação, nunca em hot loop de desenho. A função `available_dash_charges`
é consultada somente para apresentação e não altera estado.

Comprovado: três IDs distintos, colors/kinds distintos, flags reais, cópia
profunda do descriptor, renderer queued em fase válida e imutabilidade do
Player; layouts estreitos medidos sem overflow nos três consumidores.

Não comprovado: aprovação visual humana, Android/dispositivo/touch físico,
Vega, screen reader, PT-BR, benchmark de ondas densas e resolução dos
diagnósticos de teardown existentes. A fronteira ainda depende de
`program_id` ser inicializado por `_ready()` em Players reais; fixtures devem
preenchê-lo explicitamente.

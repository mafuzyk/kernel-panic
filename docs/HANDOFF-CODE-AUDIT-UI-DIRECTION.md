# Handoff — auditoria de código e direção UI vNext

Data: 2026-08-31  
Branch: `codex/code-audit-ui-direction`  
Estado: publicada no remoto, sem merge na `main`.

## Decisão de escopo

O menu, HUD e painéis atuais estão aprovados como estado técnico intermediário
e jogável. Eles não são a direção visual final. A próxima UI será reconstruída
do zero, sem obrigação de preservar a composição atual ou migrar cada painel
um a um.

A linguagem aprovada em princípio é híbrida, com code-drawn como fonte
principal: frames, indicadores, ícones, programas e inimigos devem nascer de
geometria desenhada pelo jogo. Sprites/raster ficam reservados para casos em
que uma textura realmente acrescenta algo — ilustração, textura ou detalhe
que não ganha com geometria. Um sprite gerado não pode substituir estado,
silhueta, orientação ou legibilidade de gameplay sem uma revisão específica.

## Trabalho desta rodada

### R18 — multitouch durante a mira

**Erro:** `src/ui/touch_controls.gd` só entrava no ramo de DASH/BOOST quando
`_aim_id == -1`. Com um dedo segurando a mira, um segundo dedo em DASH ou
BOOST era contado, mas não acionava nada.

**Correção:** as áreas de ação agora têm prioridade própria e são avaliadas
antes da criação do dedo de mira. O dedo de mira continua dono do aim; o
segundo dedo pode disparar a ação sem cancelar o primeiro.

**Evidência:**
`tools/touch_multitouch_probe.tscn` reproduziu a falha antes da correção e
passou depois com DASH e BOOST, incluindo o ciclo de soltura dos dois dedos.
O probe entrou em `tools/validate_input_dispatch.sh`.

Commit: `15bb79b fix: keep touch actions available during aim`.

### Contrato de ownership das motes

**Erro:** `MoteField.stolen_ids()` dizia expor IDs, mas retornava índices de
slot compactado. Como o campo move o último slot para preencher um buraco,
esses valores não são estáveis e não correspondem aos UIDs que OOM mantém.

**Correção:** o método agora retorna `_uid[i]`, alinhado com
`idx_of_uid()`, `carried_ids` e os métodos de liberar/remover saque.

**Evidência:** o probe existente de OOM ganhou uma assertion que exige UID
estável; falhou antes e passou depois. O isolamento entre dois OOM continua
coberto.

Commit: `ccbf19a fix: return OOM mote ownership as UIDs`.

### Lifecycle do sinal de patch no HUD

**Risco estrutural:** o HUD conectava `Game.patch_picked` a uma lambda criada
por instância. Como `Game` é autoload e o HUD é recriado a cada arena, essa
forma mantém um callable anônimo no emissor global durante a vida do jogo.

**Correção:** a conexão usa o método nomeado `_on_patch_picked`, que atualiza
o build apenas enquanto o label ainda é válido. Isso permite que o ciclo de
vida do nó seja reconhecido pelo sistema de sinais e remove a captura anônima
desnecessária.

**Evidência:** o teste de integração exige o método bound e rejeita a lambda.
A suíte completa passou. Os diagnósticos de teardown de recursos/RIDs ainda
existem e continuam separados; não foram falsamente atribuídos a este fix.

Commit: `4034a03 fix: bind HUD patch updates to its lifecycle`.

### Bloqueio explícito de sprites gerados

`src/ui/entity_sprite.gd` agora expõe `sprites_enabled() == false` e retorna
fallback vazio enquanto a paridade visual não for demonstrada. O caminho
existente continua disponível para experimentos, mas `GlyphLib` permanece a
apresentação das entidades no jogo.

O gate exige, antes de qualquer ativação futura: facing, movimento idle,
feedback de hit, silhueta em escala de combate e leitura de todos os estados.
O teste em `src/autoload/harness/sections_polish.gd` também garante que a
consulta de sprites não avança o RNG de gameplay.

Commit: `9fce3c8 fix: keep gameplay entities on code-drawn path`.

## Fundação visual vNext

A primeira camada foi adicionada sem tocar na UI legada:

- `src/ui/vnext/ui_tokens.gd`: safe area, escala de viewport, cantos
  chanfrados, papéis semânticos (`structure`, `danger`, `warning`, `ready`,
  `muted`) e estados com texto/padrão além da cor.
- `src/ui/vnext/ui_primitives.gd`: superfície code-drawn com frame comum,
  marcador de estado, meter, snapshot semântico e contrato de overflow.
- `src/ui/vnext/entity_illustration.gd`: exemplo de ilustração de programa ou
  inimigo usando `GlyphLib`, extent por silhueta e uma camada independente
  para `steady`, `pulse`, `break` e `hatch`. Identidade vem da silhueta;
  estado vem do marcador, não de uma troca arbitrária de cor.

Os probes `tools/vnext_primitives_probe.tscn` e
`tools/vnext_entity_illustration_probe.tscn` cobrem carregamento, desenho em
um Control vivo, fallback seguro para entradas desconhecidas, snapshots e
1366×768, 720×720 e 432×720. Os probes também exigem
`text_overflow_report()`.

Commits: `b1fbb18 feat: add vnext code-drawn surface contract`,
`399a9a5 feat: add vnext code-drawn entity illustration` e
`5da42d8 test: exercise vnext drawing paths`.

Exemplos de intenção para a próxima construção:

```text
OOM_KILLER  = corpo circular + chifres assimétricos + aro de saque
GOD         = núcleo brilhante + órbitas incompletas + estado de ameaça
ROOTLET     = escudo hexagonal + núcleo protegido + hatch quando bloqueado
PATCH       = símbolo da família + valor + estado de disponibilidade
```

A composição final não deve ser decidida copiando o menu atual. O próximo
vertical slice deve ser uma tela de boot/menu nova com um frame, uma ação e
uma ilustração, validada visualmente antes de conectar o resto do jogo.

## Trabalho anterior preservado

Os lotes R01–R10, T01–T04 e B1/B2/B5 já estão na ancestralidade desta branch
com handoffs próprios. Entre os problemas já corrigidos estão:

- dispatch real de pausa, abandono, restart e seleção de patch;
- ESC em build desktop debug e foco do terminal;
- projétil órfão criado a cada disparo;
- deadlock de recarga do escudo ROOTLET, incluindo o overflow aprovado de
  mote cheia (+5 e progresso de scrap);
- TempleOS criando ROOT em vez de GOD no caminho Story;
- restart segurado preservando Story;
- saque de OOM isolado por UID;
- banner de evento apontando para método inexistente;
- probe de captura de terminal usando a rota real;
- overlays do menu, ações de rodapé e history/autocomplete do terminal.

R09 não recebeu fix de produção porque a suspeita era falsa: a coleta já
ocorria no centro por distância/sweep. O caso agora possui cobertura para
0, 0,5, 1 e 2 px no DevHarness.

## Pendências deliberadas

Não foram implementados microajustes cosméticos do menu/HUD legado (B6/B7,
H1–H7, N1–N4 e similares). Eles serão reconsiderados quando suas superfícies
forem reconstruídas. Touch visibility/onboarding também permanece para a nova
camada, exceto o bug funcional R18 corrigido aqui.

Os avisos restantes de encerramento — ObjectDB, recursos, CanvasItem/texto e
RIDs — são observações reais do teardown dos testes, mas não foram misturados
com bugs de gameplay. A atribuição ainda precisa de um lote próprio com
ownership isolado e não deve ser mascarada pelo validador.

## Validação

Entrada única: `tools/validate_input_dispatch.sh`. Todas as execuções desta
rodada usaram `--audio-driver Dummy` para não produzir som.

O validador roda a suíte DevHarness, input probe headless/Xvfb, probes R04,
R05, R06, R07, R08, B1, B2, B5, R18 e os dois contratos vNext. Falhas de
assertion, exit code, marcador ausente e erros de runtime são gates; os
diagnósticos conhecidos de teardown são reportados separadamente.

## Commits publicados nesta rodada

```text
15bb79b  fix: keep touch actions available during aim
b1fbb18  feat: add vnext code-drawn surface contract
399a9a5  feat: add vnext code-drawn entity illustration
5da42d8  test: exercise vnext drawing paths
ccbf19a  fix: return OOM mote ownership as UIDs
4034a03  fix: bind HUD patch updates to its lifecycle
```

Todos foram enviados sem force-push. Alterações locais preexistentes do
usuário continuam fora desses commits: `docs/UI-REDESIGN-DIRECTION.md`,
`src/ui/tactical_icon.gd`, arquivos de configuração, documentação/backlog
local e imports de capturas.

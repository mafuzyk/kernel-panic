# E1 — entity descriptor and renderer foundation

Status: implementado no branch `codex/plan-execution`, 2026-09-01.

## Entregue

- `VNextEntityDescriptor.normalize()` cria um snapshot determinístico,
  serializável em `Dictionary`, com defaults seguros, normalização de facing/HP,
  deep-copy de dados aninhados e remoção de chaves de localização de
  `visible_label`.
- `VNextEntityRenderer` centraliza `fit_rect()`/`draw_bounds()` e desenho
  code-drawn com identidade, eixo de facing, estados idle/attack/hit/elite/death,
  marcador de color-assist, grayscale e reduced-motion. O renderer não acessa
  gameplay, áudio, RNG, filesystem ou troca de cena.
- `VNextEntityPresentationAdapter` oferece entradas para um `Player` e um
  `EnemyBase`, além de fixtures puras. O probe conecta exatamente `kernel` e
  `DRONE`; nenhum comportamento, rota, hitbox ou balanceamento foi alterado.
- `VNextEntityIllustration` preserva suas APIs anteriores e passa a delegar
  extent e `_draw()` ao foundation compartilhado; `visual_rect()` agora
  representa o envelope completo e `glyph_radius()` usa o mesmo contrato do
  renderer.

## Evidência red/green

- Red: probe executado após a primeira extensão, antes dos arquivos de produção;
  exit 1, `PROBE_FAIL entity presentation foundation scripts load` e
  `PROBE_DONE fails=1`.
- Green focado após a correção: import Godot com `--audio-driver Dummy`, exit
  0; probe headless exit 0 com 129 `PROBE_PASS`, 0 `PROBE_FAIL` e
  `PROBE_DONE fails=0`; probe Xvfb com os mesmos 129/0; sem `ERROR`,
  `SCRIPT ERROR` ou `PROBE_FAIL` nos logs focados.
- Suíte: `godot --headless --audio-driver Dummy --path . -- --autotest`, exit 0,
  1414 `AT_PASS`, 0 `AT_FAIL`, `AUTOTEST_ALL_PASS`.
- Validador acumulado: `KP_VALIDATION_LOGS=.godot/codex-review-e1-final tools/validate_input_dispatch.sh`, exit 0, `VALIDATION OK`; entity probe
  129/0 e todas as probes acumuladas passaram. Os diagnósticos de teardown
  seguem visíveis e não-gating, sem novo erro de runtime.
- `git diff --check`: exit 0.

## Revisão adversarial

O primeiro review independente rejeitou a aceitação apesar do probe verde. Ele
encontrou seis problemas concretos: `draw_bounds()` não cobria os marcadores
externos, facing não girava a identidade, adapters de produção não eram
exercitados com objetos reais, `render_key()` dependia da ordem textual de
`Dictionary`, `era_accent` era descartado no renderer e o Control público não
repassava os modos de acessibilidade. A probe também tinha uma falha de escopo
que só comparava o mesmo dicionário consigo mesmo.

Correção local após o review: o extent agora é o maior entre o alcance do
`GlyphLib` e o envelope de todos os marcadores/linhas (`MARKER_EXTENT`), e o
raio é calculado com o mesmo contrato; facing gira o glyph em torno do centro;
`render_key()` canoniza dicionários, arrays, vetores e cores; `color_for()`
mistura o acento de era antes do grayscale; `VNextEntityIllustration` expõe
`set_facing()`/`set_quality()` e os repassa ao renderer; e o probe instancia
`Player.new()`/`DroneEnemy.new()` sem `_ready()` para testar os adapters reais
sem iniciar gameplay. A normalização de booleano também deixou de transformar
qualquer string não-vazia em `true`.

O review próprio da correção confirmou que o tempo cosmético continua separado
do snapshot, `GlyphLib` é fallback, `EntitySprite` continua desabilitado por
default, e não há acesso a `Game`, `Sfx`, `Arena`, RNG, filesystem ou troca de
cena no renderer. A evidência é contratual/geométrica; não substitui captura
visual humana.

Uma segunda revisão independente encontrou outra inconsistência concreta: o
renderer publicava `MARKER_EXTENT`, mas `fit_rect()` e `draw_bounds()` ainda
retornavam o mesmo quadrado, enquanto `glyph_radius()` do Control calculava
fora do foundation. A probe foi ampliada para exigir a relação
`draw_bounds.size = fit.size * extent` e a equivalência do raio público. Contra
o commit anterior, a execução reproduziu 21 falhas; `7a62a90` corrige a
geometria: `fit_rect()` é a alocação interna do corpo, `draw_bounds()` é o
envelope externo completo, e ambos derivam do mesmo fator de extent. O raio
agora usa o extent real do glyph dentro do corpo. O teste verde final foi
executado novamente em headless e Xvfb, e a suíte completa permaneceu verde.

## Limitações e incertezas

- Não houve aprovação visual: não foi produzida nem inspecionada captura deste
  E1.
- O probe prova a transformação de snapshots, o Control compatível e os
  adapters contra instâncias reais ainda fora da árvore. Não conecta uma rota
  de produto nem instancia um Player/Enemy em uma cena viva; isso fica fora do
  E1 para evitar efeitos de `_ready()` e gameplay.
- O renderer usa a malha geométrica existente do `GlyphLib`; novas identidades,
  cast completo, integração de bestiary/selector/HUD e comparação com sprites
  ficam para E2–E5.
- O autotest preserva os diagnósticos de teardown já existentes (recursos/RIDs/
  ObjectDB no encerramento); não são falhas do E1.

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
  extent e `_draw()` ao foundation compartilhado.

## Evidência red/green

- Red: probe executado após a primeira extensão, antes dos arquivos de produção;
  exit 1, `PROBE_FAIL entity presentation foundation scripts load` e
  `PROBE_DONE fails=1`.
- Green focado: import Godot com `--audio-driver Dummy`, exit 0; probe com o
  mesmo driver, exit 0, `PROBE_DONE fails=0`, sem `ERROR`, `SCRIPT ERROR` ou
  `PROBE_FAIL` no log.
- Suíte: `godot --headless --audio-driver Dummy --path . -- --autotest`, exit 0,
  1414 `AT_PASS`, 0 `AT_FAIL`, `AUTOTEST_ALL_PASS`.
- `git diff --check`: exit 0.

## Revisão adversarial

Verificado no diff que a renderização recebe tempo cosmético separado do
snapshot, usa `GlyphLib` como fallback code-drawn, mantém `EntitySprite`
desabilitado por padrão, não muta fixtures e mantém bounds compartilhados para
fit/draw. O probe cobre 24/48/96/160 px, quatro orientações, estados, defaults,
deep-copy, adapter de programa/inimigo e guarda lexical contra Game/Sfx/Arena/
RNG no renderer.

## Limitações e incertezas

- Não houve aprovação visual: não foi produzida nem inspecionada captura deste
  E1.
- O probe prova a transformação de snapshots e o Control compatível, mas não
  conecta uma rota de produto nem instancia o `Player`/`EnemyBase` reais; isso
  fica deliberadamente fora do E1 para evitar efeitos de `_ready()` e gameplay.
- O renderer usa a malha geométrica existente do `GlyphLib`; novas identidades,
  cast completo, integração de bestiary/selector/HUD e comparação com sprites
  ficam para E2–E5.
- O autotest preserva os diagnósticos de teardown já existentes (recursos/RIDs/
  ObjectDB no encerramento); não são falhas do E1.

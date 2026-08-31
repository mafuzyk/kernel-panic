# Handoff — Lote R04: projéteis órfãos por disparo

Data: 2026-08-31. Executor: OpenCode/GLM-5.3 (orchestrator) com implementação
delegada ao fixer (probe + correção); validação e git pelo orchestrator.
Origem: `docs/REVISAO-CONSOLIDADA-2026-08-31.md` item R04 (P1).

## Branch e commits

Branch: `codex/r04-projectile-orphans`, criada explicitamente a partir de
`codex/input-dispatch` @ `786b93a` (Lote 1 aprovado — dependência mantida,
sem merge para `main`).

Commits (nesta ordem — teste antes do fix, espelhando red→green):

- `a0169c7` — test: projectile orphan regression probe (R04)
- `92ba70f` — fix: remove unused PlayerBullet.new() leaking one orphan per shot (R04)
- docs: handoff for R04 projectile orphans (commit que contém este arquivo,
  ponta da branch)

Alterações locais pré-existentes NÃO incluídas (working tree intacto):
`src/ui/menu.gd`, `src/ui/menu_chrome_kit.gd`, `src/ui/tactical_icon.gd`,
`tools/layout_probe.*`, `opencode.jsonc`, `AGENTS.md`, docs pré-existentes,
`.opencode/`, imports órfãos em `media/captures/xvfb/`.

## Causa (confirmada no código atual)

`src/player/player.gd`, `func _shoot()`: `var b := PlayerBullet.new()`
criava um Node nunca referenciado depois; o loop abaixo criava os projéteis
reais (`bullet`) e os adicionava via `get_parent().add_child(bullet)`.
`PlayerBullet` extends `Area2D` (Node, não RefCounted): ao perder a única
referência local, o nó ficava alocado fora da árvore — 1 órfão por ciclo de
disparo, acumulando com os disparos (não só na saída).

## Correção (mínima)

Remoção da linha `var b := PlayerBullet.new()` — nenhuma outra linha da
função tocada. Quantidade, direção, velocidade, recoil (`vel -= dir * 26.0`),
muzzle, som e `Game.stats["shots"]` preservados (verificado pelo probe:
contagens de projéteis vivos idênticas antes/depois do fix).

## Teste (determinístico, reutilizável)

`tools/projectile_orphan_probe.tscn` (boot) + `.gd` + `_runner.gd` (runner
persistente sob a root, padrão do probe de input do Lote 1; timeouts
monotônicos; `PROBE_DONE fails=N`, exit 1 em falha). Execução:

```sh
XDG_DATA_HOME=<dir-isolado> godot --headless --path . res://tools/projectile_orphan_probe.tscn
```

Fases e checks:
1. **Controle** (30 ticks ociosos em PLAYING): delta de órfãos == 0 — isola
   ruído preexistente do baseline (1 órfão prévio constante no ambiente).
2. **10 disparos simples** (chamadas síncronas a `player._shoot()`; o bug é
   interno ao método, não de dispatch): delta de órfãos == 0 **e** 10
   projéteis vivos na árvore.
3. **Splitshot nível 2** (5 disparos): delta == 0 **e** +15 vivos (3/tiro);
   `Game.patch_levels` restaurado depois.
4. **Reinício** (`Game.start_run()`, arena nova, 10 disparos): delta == 0
   **e** 10 vivos — vazamento não reaparece após troca de cena.

Órfãos medidos por `Performance.OBJECT_ORPHAN_NODE_COUNT`; vivos contados
como filhos `PlayerBullet` válidos da Arena — distingue projéteis vivos de
vazamentos.

## Red → Green (logs em `.godot/codex-review-r04/`)

- `red-probe.log` (antes do fix): exit 1, `fails=3` —
  `orphans shots delta=10` (10 disparos), `splitshot delta=5` (5 disparos),
  `restart delta=10`; vivos corretos (10/25/10); controle idle delta=0.
  Exatamente +1 órfão por `_shoot()`.
- `green-probe.log` (depois do fix): exit 0, `fails=0` — todos os deltas 0;
  vivos 10/25/10 (quantidade preservada); baseline de órfãos estável
  (1 antes/depois; 2 após o reinício, pré-existente da troca de cena,
  delta 0 nos disparos).

## Validação completa (suíte + Lote 1, XDG_DATA_HOME isolado)

`KP_VALIDATION_LOGS=.godot/codex-review-r04/val tools/validate_input_dispatch.sh`
→ exit 0, `VALIDATION OK`:

| Caso | exit | passes | fails | ERROR baseline |
|---|---|---|---|---|
| Suíte headless `--autotest` | 0 | 1418 AT_PASS | 0 | 7 |
| Probe input headless | 0 | 32 | 0 | 9 |
| Probe input Xvfb (debug ativo) | 0 | 34 | 0 | 23 |

## Erros preexistentes (baseline T02 — reportados, não corrigidos)

Inalterados em relação ao Lote 1 (ver
`docs/HANDOFF-INPUT-DISPATCH-LOTE-1.md`): `show_event_banner: Method not
found` (R10), `Lambda capture freed`, recursos/RIDs no encerramento
(contagens por ambiente: 7/9/23). Nenhum novo erro introduzido; os RIDs de
`P11GodotArea2D` (29) da suíte não foram reavaliados neste lote — o probe
R04 mede órfãos de **nós** por disparo, não RIDs de física no exit.

## Limitações

- Medição por `OBJECT_ORPHAN_NODE_COUNT` conta nós; não cobre vazamentos de
  RID/recursos no encerramento (baseline separado, T02).
- O probe roda em headless (o bug não depende de display); não incluído no
  `--autotest` nem no `validate_input_dispatch.sh` — comando manual acima.
- Splitshot testado no nível máximo (2); níveis intermediários seguem o
  mesmo caminho de código (loop `range(1 + patch_level)`).
- Reinício testado via `Game.start_run()` (Classic); reinício Story usa o
  mesmo `_shoot()` sem diferença estrutural.

## Próximos passos (fora deste lote, não iniciados)

1. R05 — recarga de escudo do ROOTLET (próximo da ordem sugerida da revisão).
2. R11/R12/T03 — regressões locais do menu + probe de layout (envolvem
   subtitle, controls, best e prompt, não apenas subtitle).
3. R06/R07/R08, R10/T04, T02 (tornar ERRORs gatearem a validação).
4. Decisões de UX pendentes com o usuário (R13/R14, B5/R16, R15/B6, B7,
   H1–H7) e direção visual híbrida já registrada.

Outros problemas observados durante o lote (apenas registro, sem ação):
nenhum novo além do baseline conhecido.

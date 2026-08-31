# Handoff — Lote R06: TempleOS termina com ROOT em vez de GOD

Data: 2026-08-31. Executor: OpenCode/GLM-5.3 (orchestrator) com implementação
delegada ao fixer (probe + correção); validação e git pelo orchestrator.
Origem: `docs/REVISAO-CONSOLIDADA-2026-08-31.md` item R06 (P2).

## Branch e commits

Branch: `codex/r06-temple-god-boss`, criada a partir da ponta de
`codex/menu-layout-regressions` @ `3a726e8` (R11/R12/T03 aprovados + registro
da direção de redesign). Sem merge para `main`.

Commits (test → fix → docs, espelhando red→green):

- `be76f01` — test: temple_god boss regression probe (R06)
- `0259527` — fix: spawn the stage's GOD boss in the story path (R06)
- docs: handoff for R06 temple GOD boss (este commit, ponta da branch)

Alterações locais preservadas fora dos commits: `src/ui/tactical_icon.gd`,
`opencode.jsonc`, `AGENTS.md`, docs pré-existentes, `.opencode/`, imports
órfãos em `media/captures/xvfb/`.

## Causa (confirmada no código atual)

`src/story/story_data.gd` — estágio `temple_god`: waves terminam em
`["god"]`, `boss_kind: "god"`, `boss: "GOD"`. Em `src/arena/spawner.gd`:
`start_story()` seta `_story_boss_kind` a partir de `boss_kind` (l.60);
`_begin_story_wave()` reconfirma pela wave (l.112) e chama
`_spawn_story_boss()` (l.117) — que instanciava `_boss = RootBoss.new()`
incondicionalmente (l.237), ignorando `_story_boss_kind`. O caminho clássico
(`_spawn_boss`, l.220) já tinha o ternário correto. Como `GodBoss extends
RootBoss`, o jogo "funcionava" — mas o boss enfrentado, seu título (ROOT.exe
vs GOD) e comportamento eram os do boss errado, permitindo o desbloqueio sem
enfrentar o previsto.

## Correção (mínima, 1 linha)

`_spawn_story_boss()` (spawner.gd:237):
`_boss = GodBoss.new() if _story_boss_kind == "god" else RootBoss.new()` —
espelho byte a byte do ternário do caminho clássico. Nenhuma outra linha
(`boss_index`, `threat_wave`, `configure`, spawn, sinal) alterada.

## Teste (caminho real do boss, determinístico)

`tools/temple_god_boss_probe.tscn/.gd/_runner.gd` (padrão dos probes
anteriores; watchdog 240s; `PROBE_DONE fails=N`, exit 1 em falha):

```sh
XDG_DATA_HOME=<dir-isolado> godot --headless --path . res://tools/temple_god_boss_probe.tscn
```

Caminho real: `Game.start_story(temple_god)` (desbloqueio via preparo
documentado: estágio anterior marcado limpo) → intro dispensada com ESC real
via `Viewport.push_input` → `spawner.start_story` com o stage def real →
waves 1–3 avançadas pelo ceifador físico (`take_hit(999)` em cada inimigo;
fila drena, alive==0, intermissão, próxima wave — a máquina de estados real
do spawner) → wave 4 `["god"]` → `_spawn_story_boss()` → `boss_spawned` →
asserts de classe/título/HUD → boss morto pelo ceifador até `story_cleared`.

## Red → Green (logs em `.godot/codex-review-r06/`)

- `red-probe.log`: exit 1, `fails=2` — `boss_title=ROOT.exe isGodBoss=false
  isRootBoss=true`; checks de classe e título falham. Guards passam: HUD
  tracked; estágio limpa pelo caminho real; recompensa (`temple_rainbow_
  unlocked`) desbloqueia por id do estágio — exatamente o ponto da revisão
  ("desbloqueio sem enfrentar o boss previsto").
- `green-probe.log`: exit 0, `fails=0` — `boss_title=GOD isGodBoss=true`;
  classe, título e HUD corretos; estágio limpa e recompensa preservadas.

## Escopo de testes

Conforme instrução ("apenas os testes diretamente relacionados"), executado
apenas o probe R06 (red+green). A suíte completa NÃO foi rodada neste lote;
verificado por inspeção que a cobertura existente não é afetada: o teste
TempleOS do harness (`sections_scene.gd:195-232`) valida o spawner scripted
sem chegar ao boss, e `sections_modes.gd:249` instancia `GodBoss`
diretamente (unitário, intocado). Codex pode rodar a suíte completa de forma
independente.

## Comportamento testado × apenas inspecionado

**Testado (probe, evidência em log):** classe do boss spawned na wave final
do temple_god (GodBoss vs RootBoss), `boss_title` ("GOD" vs "ROOT.exe"),
wiring `hud.boss`, conclusão do estágio e recompensa pelo caminho real
(waves reais do spawner story + morte real do boss/splits).

**Apenas inspecionado (diff, não verificado pelo probe):** comportamento
interno do GodBoss (mecânica de aleatoriedade/recuperação — sem assertions
de gameplay do boss), HUD visual do título, texto do log de evento
("BOSS SPAWNED // GOD"), demais estágios story (o ternário é neutro para
`boss_kind != "god"` — `RootBoss.new()`, byte-idêntico ao anterior).

## Erros de runtime / limitações

- Nenhum ERROR novo observado nos logs do probe (red e green limpos além do
  engine banner).
- Escopo: suíte completa não executada (ver Escopo de testes).
- O probe não está engatilhado no `--autotest` (comando manual documentado).
- Boss morto via `take_hit(999)` do ceifador (mesma rotina real de dano);
  splits/minis ceifados no mesmo loop até o clear.

## Próximos passos (fora deste lote, não iniciados)

1. R07 — hold R troca Story por Classic (gameplay de reinício).
2. R08 — isolamento do saque entre OOMs.
3. R10/T04, T02, R13–R20/R09, H1–H7 — conforme ordem aprovada pelo
   orientador.

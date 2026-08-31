# Handoff — Lote R05: recarga do escudo do ROOTLET

Data: 2026-08-31. Executor: OpenCode/GLM-5.3 (orchestrator) com implementação
delegada ao fixer (probe + correção); validação e git pelo orchestrator.
Origem: `docs/REVISAO-CONSOLIDADA-2026-08-31.md` item R05 (P2).

## Branch e commits

Branch: `codex/r05-rootlet-shield`, criada a partir da ponta atualizada de
`codex/r04-projectile-orphans` — **hash-base `a0586d5`** (R04 + ajuste
documental do handoff, aprovados). Sem merge para `main`.

Commits (test → fix → docs, espelhando red→green):

- `39f5ff3` — test: rootlet shield recharge regression probe (R05)
- `a87f45c` — fix: shield_mode gates shield recharge, overflow full-shield motes to scrap (R05)
- docs: handoff for R05 rootlet shield (este commit, ponta da branch)

Alterações locais pré-existentes NÃO incluídas (working tree intacto):
`src/ui/menu.gd`, `src/ui/menu_chrome_kit.gd`, `src/ui/tactical_icon.gd`,
`tools/layout_probe.*`, `opencode.jsonc`, `AGENTS.md`, docs pré-existentes,
`.opencode/`, imports órfãos em `media/captures/xvfb/`.

## Causa (confirmada no código atual)

`src/player/player.gd`:
- `_ready()` inicia ROOTLET (`shield_mode: true` no program def) com
  `shield_ready=true`, `shield_meter=0.0`.
- `take_damage()` consome o escudo: `shield_ready=false`, `shield_meter=0.0`.
- `collect_mote()` e `add_kill_mote_bonus()` só carregavam o escudo sob
  `if shield_ready:` — após o consumo o gate nunca mais abre. As motes caíam
  no caminho de overclock (carregam `meter`, setam `oc_ready=true`), mas
  `try_overclock()` bloqueia shield_mode → deadlock + estado de overclock
  permanentemente inutilizável (sintoma da revisão: 100 de motes →
  `shield_ready=false, shield_meter=0, oc_ready=true`).

## Solução (derivada das regras existentes — nenhum valor novo)

1. Gates de `collect_mote()` e `add_kill_mote_bonus()` trocados de
   `if shield_ready:` para `if bool(prog.get("shield_mode", false)):`.
2. Em `collect_mote()`, motes excedentes com escudo cheio agora seguem o
   destino existente de "meter cheio" — espelho exato da branch `if oc_ready:`
   (`Game.add_score(5)` + `_register_scrap_overflow()` + `return`) — para que
   shield_mode nunca alimente o meter fantasma de overclock.
3. Kill bonus com escudo cheio permanece no-op (comportamento já existente da
   branch, consistente com overclock cheio).
4. Inalterados: `try_overclock()` (shield_mode segue bloqueado — escudo
   passivo por design), `take_damage()`, `shield_ready_full()`, valores de
   `Balance` (MOTE_VALUE 6 / MOTE_KILL_VALUE 2 / OC_METER_MAX 100), HUD.

**Decisão de derivação a validar pelo Codex:** o item 2 mapeia a regra
existente de overflow para o estado análogo (escudo cheio). Sem isso, motes
com escudo cheio continuariam carregando o meter de overclock morto (viola o
aceite "o programa não deve entrar num estado de overclock inutilizável").
Economicamente preserva o desfecho atual (score+scrap), apenas sem o estado
morto intermediário. Nenhum valor inventado; alternativa descartada (A:
apenas trocar o gate) deixaria o meter fantasma acessível com escudo cheio.

## Teste (determinístico, caminho real de gameplay)

`tools/rootlet_shield_probe.tscn/.gd/_runner.gd` (padrão dos probes
anteriores: runner persistente, watchdog 90s, timeouts monotônicos,
`PROBE_DONE fails=N`, exit 1 em falha). Execução:

```sh
XDG_DATA_HOME=<dir-isolado> godot --headless --path . res://tools/rootlet_shield_probe.tscn
```

Caminho real: coleta via `_physics_process` do MoteField (`spawn` a 10px do
player → sweep `d < 20` → `player.collect_mote()`); kill bonus via inimigo
real (DroneEnemy no `enemy_container` → `died` → `arena._on_enemy_died()` →
`player.add_kill_mote_bonus()`, medido no mesmo frame do golpe letal, antes
das motes dropadas chegarem). Preparo de estado documentado:
`spawner.stop()` + limpeza de inimigos residuais (determinismo) e
`take_damage()` como rotina real de dano para os consumos. Motes a 10px
evitam o caso limítrofe ≤1px (R09).

## Red → Green (logs em `.godot/codex-review-r05/`)

- `red-probe.log` (antes do fix): exit 1, `fails=6` — núcleo reproduzido:
  após consumo, 17 motes reais → `shield_ready=false, shield_meter=0.0,
  meter=100.0, oc_ready=true` (sintoma exato da revisão); fases seguintes
  abortaram por pré-condição (esperado no red). Guard de overflow de score
  passou no red (economia existente via oc_ready).
- `green-probe.log` (depois do fix): exit 0, `fails=0` — 18 checks: boot com
  escudo passivo; consumo 1; recarga real por motes (ready=true, 100.0,
  meter/oc_ready intactos); escudo cheio com motes excedentes (permanece 100,
  score +15, sem meter fantasma); kill bonus com escudo cheio (no-op);
  consumo 2; kill bonus pós-consumo (`shield_meter == MOTE_KILL_VALUE` no
  mesmo frame); recarga completa; consumo 3; ROOTLET nunca overclocka;
  kernel nunca carrega escudo, mantém overclock funcional e ativável.

## Validação completa (XDG_DATA_HOME isolado)

`KP_VALIDATION_LOGS=.godot/codex-review-r05/val tools/validate_input_dispatch.sh`
→ exit 0, `VALIDATION OK`; probe R04 re-executado → exit 0, `fails=0`:

| Caso | exit | passes | fails | ERROR baseline |
|---|---|---|---|---|
| Suíte headless `--autotest` | 0 | 1418 AT_PASS | 0 | 7 |
| Probe input headless | 0 | 32 | 0 | 9 |
| Probe input Xvfb (debug ativo) | 0 | 34 | 0 | 23 |
| Probe R04 (órfãos) | 0 | — | 0 | — |

## Comportamento testado × apenas inspecionado

**Testado pelo probe (evidência em log):** transições de estado do escudo
(consumir/recarregar/consumir de novo) por motes reais e kill bonus real;
overflow com escudo cheio (score, sem meter fantasma); guards ROOTLET
(try_overclock bloqueado) e kernel (escudo intacto, overclock funcional);
invariante meter/oc_ready para shield_mode.

**Preservado por inspeção do diff, não verificado pelo probe:** renderização
da barra SHIELD no HUD e o sinal `meter_changed` (o kill bonus emite
`ready_flag=false` — inconsistência pré-existente com o caminho da mote,
mantida); áudio/háptica/textos de feedback ("SHIELD READY" etc.); valores de
Balance (nenhum literal novo); comportamento de programas não-shield
(byte-idêntico, gates avaliam falso); IA/animação de inimigos.

## Erros preexistentes (baseline T02 — reportados, não corrigidos)

Inalterados: `show_event_banner: Method not found` (R10), `Lambda capture
freed`, recursos/RIDs no encerramento (7/9/23 por ambiente). Nenhum novo erro
introduzido.

## Limitações

- Probe não engatilhado no `--autotest`/`validate_input_dispatch.sh`
  (comando manual documentado).
- Consumos feitos via `take_damage()` direto (rotina real de dano, preparo
  documentado) em vez de colisão física com inimigo — o bug R05 está no gate
  interno da recarga, não no dispatch do dano.
- Kill bonus medido com 1 kill real (drone); completude da recarga usa o cap
  em 100 para manter o resultado final determinístico apesar das motes
  dropadas pelo drone.
- Overclock do kernel testado em ativação simples (não duração/efeitos).

## Descobertas fora do escopo (registradas, sem correção)

- `add_kill_mote_bonus()` emite `meter_changed.emit(shield_meter, false)` —
  flag ready inconsistente com o caminho de motes (pré-existente; HUD guarda
  `_oc_ready` com `not shield_mode`, então sem efeito visível conhecido).
- Caso limítrofe de coleta a ≤1px (R09) — já registrado na revisão.

## Próximos passos (fora deste lote, não iniciados)

1. R11/R12/T03 — regressões locais do menu (subtitle, controls, best, prompt
   e frames do rodapé) + probe de layout (espaços de coordenada).
2. R06/R07/R08 — boss GOD, hold R preservando modo, isolamento de saque OOM.
3. R10/T04 e T02 (ERRORs gatearem a validação).
4. Decisões de UX pendentes com o usuário (R13/R14, B5/R16, R15/B6, B7,
   H1–H7) e direção visual híbrida já registrada.

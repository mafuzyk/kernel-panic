# Handoff — Lote R05: recarga do escudo do ROOTLET

Data: 2026-08-31. Executor: OpenCode/GLM-5.3 (orchestrator) com implementação
delegada ao fixer (probe + correção); validação e git pelo orchestrator.
Origem: `docs/REVISAO-CONSOLIDADA-2026-08-31.md` item R05 (P2).

## Branch e commits

Branch: `codex/r05-rootlet-shield`, criada a partir da ponta atualizada de
`codex/r04-projectile-orphans` — **hash-base `a0586d5`** (R04 + ajuste
documental do handoff, aprovados). Sem merge para `main`.

Commits (test → fix → docs em cada rodada, espelhando red→green):

- `39f5ff3` — test: rootlet shield recharge regression probe (R05)
- `a87f45c` — fix: shield_mode gates shield recharge, overflow full-shield motes to scrap (R05)
- `18799c4` — docs: handoff for R05 rootlet shield (entrega inicial do lote)
- `614e9d5` — test: R05 kill-completed shield recharge via real enemy deaths (Codex blocker)
- `f245c41` — fix: activate the shield when the kill bonus completes the charge (R05 blocker)
- docs: handoff update — bloqueador + economia do overflow pendente (este
  commit, ponta da branch)

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

**Mudança de economia — PENDENTE DE DECISÃO DO USUÁRIO:** o item 2 altera a
economia do ROOTLET com escudo cheio. Antes, as primeiras coletas com
escudo cheio alimentavam o meter de overclock inutilizável (sem pontos e
sem progresso de scrap até o meter fantasma encher); agora cada mote
excedente concede imediatamente +5 de score e progresso de scrap. A regra
foi derivada do aceite "o programa não deve entrar num estado de overclock
inutilizável" e do destino existente de meter cheio, mas **não constitui
aprovação** — a decisão final de economia cabe ao usuário e permanece
aberta. Nenhuma regra alternativa foi inventada. (Alegação anterior de
"economia preservada" removida por incorreta, a pedido do Codex.)

## Bloqueador Codex — kill completava a carga sem ativar a proteção (corrigido)

**Achado (reprodução independente do Codex, confirmada no código):**
`add_kill_mote_bonus()` podia levar `shield_meter` ao limite (98 + 2) sem
ativar `shield_ready`; `shield_ready_full()` então impedia para sempre a
entrada no trecho de ativação — a mote seguinte mantinha a proteção
desativada (ia ao overflow), e `take_damage()`, que só consome com
`shield_ready`, aplicava o dano direto ao HP.

**Correção mínima** (`f245c41`): o branch do kill espelha a ativação do
caminho de motes — ao atingir o limite, `shield_ready=true` + feedback
"SHIELD READY" idêntico ao de `collect_mote()`, e
`meter_changed.emit(shield_meter, shield_ready)` (estado correto no sinal;
o `false` anterior era inconsistência pré-existente). Escudo cheio
permanece no-op: sem emissão e sem feedback duplicado (o guard
`if not shield_ready_full():` já garante que só a transição emite).

**Red → Green (FASE 8B do probe, caminho real de morte de inimigo):**
- `red-blocker.log` (antes do fix): exit 1, `fails=8` — `post-kill2
  shield_meter=100.0 shield_ready=false emissions=[[100.0, false]]`; mote
  seguinte no overflow com a proteção morta; impacto com `hp 5→4`;
  recarga posterior em deadlock (`recharge2 ... ready=false`).
- `green-blocker.log` (depois do fix): exit 0, 28 passes, `fails=0` — kill
  ativa e emite `(100.0, true)`; mote seguinte sem travamento (overflow
  +5); kill com escudo cheio sem emissão nova; impacto absorvido sem
  perder HP (`hp=5`), escudo consumido (`meter=0.0`) e recarrega de novo.

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
evitam o caso limítrofe ≤1px (R09). FASE 8B (bloqueador Codex): o kill que
completa a recarga — 16 motes (96) → kill (98) → kill (100/ativação) com
listener de `meter_changed` conectado, mote pós-recarga (não-travamento),
kill com escudo cheio (sem emissão), absorção de impacto sem perda de HP e
recarga final.

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

Bloqueador Codex: ver seção própria (`red-blocker.log` / `green-blocker.log`
— green total de 28 checks incluindo a FASE 8B).

## Validação completa (XDG_DATA_HOME isolado)

`KP_VALIDATION_LOGS=.godot/codex-review-r05/val tools/validate_input_dispatch.sh`
(entrega inicial) e `KP_VALIDATION_LOGS=.godot/codex-review-r05/val2 ...`
(pós-bloqueador) → exit 0, `VALIDATION OK` em ambas; probe R04 re-executado
após o bloqueador → exit 0, `fails=0` (`r04-probe-blocker.log`):

| Caso | exit | passes | fails | ERROR baseline |
|---|---|---|---|---|
| Suíte headless `--autotest` | 0 | 1418 AT_PASS | 0 | 7 |
| Probe input headless | 0 | 32 | 0 | 9 |
| Probe input Xvfb (debug ativo) | 0 | 34 | 0 | 23 |
| Probe R04 (órfãos) | 0 | — | 0 | — |

## Comportamento testado × apenas inspecionado

**Testado pelo probe (evidência em log):** transições de estado do escudo
(consumir/recarregar/consumir de novo) por motes reais e kill bonus real;
ativação quando o kill completa a carga, com emissão correta de
`meter_changed` (100, true) e sem emissão nova com escudo cheio (FASE 8B);
absorção de impacto sem perda de HP pelo escudo recarregado por kill;
não-travamento da mote seguinte à recarga por kill; overflow com escudo
cheio (score, sem meter fantasma); guards ROOTLET (try_overclock bloqueado)
e kernel (escudo intacto, overclock funcional); invariante meter/oc_ready
para shield_mode.

**Preservado por inspeção do diff, não verificado pelo probe:** renderização
da barra SHIELD no HUD (o sinal emite o estado correto, mas o desenho da
barra não é observado); execução de áudio/háptica/textos de feedback
("SHIELD READY" — o bloco do kill é cópia do caminho de motes, mas Sfx/Fx
não são observados headless); valores de Balance (nenhum literal novo);
comportamento de programas não-shield (byte-idêntico, gates avaliam falso);
IA/animação de inimigos.

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

- `meter_changed.emit(shield_meter, false)` no kill bonus — inconsistência
  pré-existente CORRIGIDA pelo bloqueador (`f245c41` agora emite o estado
  real `(shield_meter, shield_ready)`).
- Caso limítrofe de coleta a ≤1px (R09) — já registrado na revisão.
- Boot dos probes pendura indefinidamente (sem quit) quando o script do
  runner falha a parsear — observado ao rodar o red da FASE 8B
  (redeclaração de `score_before` no escopo de `_run`, corrigida no próprio
  probe com renomeação); registrado sem guarda adicional no boot.

## Próximos passos (fora deste lote, não iniciados)

1. R11/R12/T03 — regressões locais do menu (subtitle, controls, best, prompt
   e frames do rodapé) + probe de layout (espaços de coordenada).
2. R06/R07/R08 — boss GOD, hold R preservando modo, isolamento de saque OOM.
3. R10/T04 e T02 (ERRORs gatearem a validação).
4. Decisões de UX pendentes com o usuário (R13/R14, B5/R16, R15/B6, B7,
   H1–H7) e direção visual híbrida já registrada.

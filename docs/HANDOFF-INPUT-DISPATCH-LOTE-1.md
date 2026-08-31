# Handoff — Lote 1: input dispatch (R01–R03 + T01)

Data: 2026-08-31. Executor: OpenCode/GLM-5.3-Flash (build), sob supervisão
Codex. Origem: `docs/REVISAO-CONSOLIDADA-2026-08-31.md` (R01–R03, T01),
priorizada pelo usuário sobre a ordem literal B1→B7 do
`docs/UI-REVIEW-BACKLOG.md`.

## Branch e commits

Branch: `codex/input-dispatch` (base: `f90ca87` em `main`).

- `1f00b1f` — fix: route paused gameplay input and stop debug keys
  swallowing ESC (R01-R03) — `src/arena/arena.gd`,
  `src/arena/pause_input_router.gd`
- `5224bd0` — fix: terminal ESC closes through the focused LineEdit and
  restores pause panel — `src/ui/terminal_panel.gd`
- `9af503d` — test: input dispatch probe via Viewport.push_input (T01) —
  `tools/input_dispatch_probe.{gd,tscn}`, `tools/input_dispatch_probe_runner.gd`
- `604a417` — tooling: lote 1 validation script — `tools/validate_input_dispatch.sh`
- `66d86ce` — fix(tooling): validation rejects empty runs; require end
  markers and active debug under Xvfb (revisão Codex)

## Correções pós-revisão Codex

- **Validador aceitava execução vazia** (passes=0, fails=0, exit=0 →
  VALIDATION OK; reproduzido com um binário `godot` falso em silêncio).
  Agora cada caso exige seu marcador de término: `AUTOTEST_ALL_PASS` na
  suíte, `PROBE_DONE fails=0` nos probes e
  `PROBE_INFO debug_controls_enabled=true` no probe Xvfb (garante que a
  cobertura R03 rodou com debug desktop ativo). Execução vazia reproduz
  VALIDATION FAILED com os três marcadores apontados; validação real segue
  verde (tabela abaixo).
- **Alegação de `rm -rf /` removida:** o comando segue a rotina de morte
  (`_terminal_rm_rf()` → `player._die()` → `_on_player_died` →
  `panel_kit._close_terminal()`), não `TerminalPanel.close_terminal()`.
  Mantém-se que o fluxo não tem cobertura de teste.

Alterações locais pré-existentes NÃO incluídas (permanecem no working tree):
`src/ui/menu.gd`, `src/ui/menu_chrome_kit.gd`, `src/ui/tactical_icon.gd`,
`tools/layout_probe.*`, `opencode.jsonc`, `AGENTS.md`,
`docs/REVISAO-CONSOLIDADA-2026-08-31.md`, `docs/UI-REVIEW-BACKLOG.md`,
imports órfãos em `media/captures/xvfb/`.

## Causa e solução por item

- **R01 (Q/R na pausa):** a Arena é `PROCESS_MODE_INHERIT`; pausada, seu
  `_unhandled_input` não roda, e o `PauseInputRouter` (ALWAYS) só encaminhava
  ESC. Solução: novo `Arena.handle_paused_gameplay_input()` (R restart, Q
  arma/confirma abandono, `_state == "play"` apenas) chamado pelo router
  quando a árvore está pausada e por `_unhandled_input` quando não está —
  caminhos disjuntos, sem processar o evento duas vezes. Nenhum
  `process_mode` da Arena mudado: simulação, player, spawner e física
  continuam congelados. Política de confirmação existente intacta (janela
  de 2 s, echo não confirma).
- **R02 (dígitos 1/2/3):** mesma causa estrutural. O branch `_patch_open`
  migrou para `handle_paused_gameplay_input`; dígitos escolhem exatamente o
  card anunciado e despausam. Echo de dígito ignorado.
- **R03 (debug engole teclas):** `set_input_as_handled()+return`
  incondicionais após o `match` F1–F4 movidos para dentro do case `KEY_F4`.
  F1–F4 mantêm função; ESC/ENTER voltam a fluir em debug desktop.
- **Terminal (guardrail do lote):** o LineEdit focado consumia ESC como GUI
  e o terminal não fechava pelo teclado (legenda promete "ESC CLOSE").
  Corrigido em `_input.gui_input`. `close_terminal()` também mirava
  `arena._close_terminal()` (método inexistente; rota real:
  `arena._panel_kit._close_terminal()`) — painel de pausa não era
  restaurado. **Evidência limitada: o probe cobre o caminho ESC (LineEdit
  focado); o fluxo "rm -rf /" segue a rotina de morte (`_terminal_rm_rf()`
  → `player._die()` → `_on_player_died`), não `close_terminal()`, e
  permanece sem cobertura de teste.**

## Comandos

```sh
# Validação completa do lote (suíte headless + probe headless + probe Xvfb):
tools/validate_input_dispatch.sh

# Probe isolado:
XDG_DATA_HOME=<dir-isolado> godot --headless --path . res://tools/input_dispatch_probe.tscn
XDG_DATA_HOME=<dir-isolado> xvfb-run -a godot --path . res://tools/input_dispatch_probe.tscn

# Suíte DevHarness:
XDG_DATA_HOME=<dir-isolado> godot --headless --path . -- --autotest
```

Logs de runtime em `.godot/codex-review-lote-1/` (gitignored): red/green
por ambiente, suítes e checkpoint detalhado (`CHECKPOINT-LOTE-1.md`).

## Resultados (validação pós-fix, antes dos commits)

| Caso | exit | passes | fails |
|---|---|---|---|
| Suíte headless `--autotest` | 0 | 1418 AT_PASS | 0 AT_FAIL, AUTOTEST_ALL_PASS |
| Probe input headless | 0 | 32 PROBE_PASS | 0 |
| Probe input Xvfb (debug desktop ativo) | 0 | 34 PROBE_PASS | 0 |

Red registrado antes do fix: `red-headless.log` (R01/R02 falham via
dispatch), `red-xvfb.log` (`debug_controls_enabled=true`, "ESC opens pause"
falha — R03 reproduzido). Green: `green-headless.log`/`green-xvfb.log`
(fails=0). Cobertura real T01: press/release, echo, foco de botão e
LineEdit, árvore pausada, transições de cena reais (QQ→Menu, R→Arena nova
preservando story/stage 0, game-over ENTER→run nova, ESC→Menu).

## Erros preexistentes (baseline T02 — reportados, não corrigidos)

- `Error calling deferred method: 'Node2D(arena.gd)::show_event_banner': Method not found.` (R10)
- `Lambda capture at index 0 was freed. Passed "null" instead.` (T02)
- `9 resources still in use at exit` + vazamentos de RID (Area2D, TextServer,
  texturas) no encerramento — contagens variam por ambiente (GLES3 no Xvfb).
- Suíte sob Xvfb (não usada pela validação): 3 AT_FAIL de gates que assumem
  headless — `dev_harness.gd:106` (compara `DisplayServer.get_name()` sem
  `to_lower()`; "X11" capitalizado diverge de `Balance.is_desktop_display()`),
  `sections_misc.gd:60` e `sections_boot.gd:187` (assertam debug desabilitado,
  falso por design em desktop debug). Nenhum relacionado a este diff.

## Limitações

- Probe não roda dentro do `--autotest`; usar o script de validação.
- Eventos pushados precisam de `unicode` para texto no LineEdit (teclado real
  produz unicode).
- R03 só é reproduzível em build debug desktop (Xvfb), nunca em headless.
- Sem hardware touch (R17/R18 fora de escopo).
- Fluxo "rm -rf /" do terminal (rotina de morte) sem cobertura de teste.

## Próximos passos (fora deste lote, não iniciados)

1. Lote 2 (sugestão da revisão): R04 — órfão de PlayerBullet por disparo
   (`src/player/player.gd:279`), com contagem de órfãos em rajada/splitshot.
2. R05 — ciclo de escudo do ROOTLET.
3. R11/R12/T03 — regressões locais do menu (subtitle/controls/best/prompt e
   frames do rodapé) + probe de layout (espaços de coordenada misturados).
   Nota do orientador: R11 envolve subtitle, controls, best e prompt.
4. R06/R07/R08 — boss GOD, hold R preservando modo (sem tocar na política de
   confirmação — R07 não é B7), isolamento de saque entre OOMs.
5. R10/T04 — delegate `show_event_banner`, captura do terminal com API atual.
6. T02 — fazer a validação falhar com ERRORs de script/método inexistente;
   gates headless/Xvfb do harness (itens 1–3 acima).
7. Decisões de UX pendentes com o usuário: R13/R14 (BOOT/MOUNT),
   B5/R16 (history/autocomplete), R15/B6 (prompt), B7 (confirmações),
   H1–H7 (hierarquia/contraste, com matriz de estados/resoluções).

Direção visual registrada para discussão futura com o usuário: híbrido
sprites/code-drawn; inimigos e programs permanecem code-drawn com mais
cuidado visual. Nada de arte foi alterado neste lote.

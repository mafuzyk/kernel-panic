# Handoff — Lote R07: hold R preserva Story

Status: concluído e validado.

## Branch e commits

Branch: `codex/r07-story-restart`, criada a partir de `codex/r06-temple-god-boss`
@ `8665dcb`.

- `test: story restart hold regression probe`
- `fix: preserve story mode on hold restart`
- este handoff

## Causa

Durante o gameplay, o hold de `R` atingia o limiar de 0,75 s e chamava
`Game.start_run()` diretamente. Essa função converte explicitamente o modo
`story` em `classic`, embora o índice da fase permanecesse armazenado.
O helper `_restart_current_run()` já tinha o comportamento correto: chama
`Game.start_story(Game.story_stage_index)` para Story e `Game.start_run()` nos
demais modos.

## Correção

O caminho do hold agora chama `_restart_current_run()`. A alteração é limitada
a uma linha em `src/arena/arena.gd`; o reinício Classic permanece usando
`Game.start_run()` através do helper.

## Teste red → green

`tools/story_restart_probe.tscn`, `.gd` e `_runner.gd` iniciam uma fase Story,
pressionam a ação `restart` por mais de 0,75 s, soltam a ação e verificam o
resultado público do reinício.

O teste confirma que a nova Arena continua em modo Story e conserva o índice
da fase. Antes da correção: `hold R preserves story mode` falhou, embora a nova
Arena e o índice da fase fossem preservados. Depois da correção: 3 checks
passaram e `PROBE_DONE fails=0`.

## Validação

Com `XDG_DATA_HOME` isolado:

- probe R07: exit 0, 3 passes, 0 falhas;
- suíte `--autotest`: exit 0, 1418 `AT_PASS`, 0 `AT_FAIL`;
- probe de input headless: 32 passes, 0 falhas;
- probe de input Xvfb: 34 passes, 0 falhas;
- probe R04: exit 0, 0 falhas;
- probe R05: exit 0, 0 falhas.

Os `ERROR` de encerramento continuam sendo o baseline conhecido do projeto:
`show_event_banner`, captura de lambda e vazamentos de recursos/RIDs. Eles
foram reportados separadamente pela validação e não foram alterados neste lote.

## Limitações

O probe usa `Input.action_press/release` para manter a ação durante o teste,
pois `Viewport.push_input` não mantém o estado contínuo de uma ação no modo
headless. A transição e o comportamento são verificados pela Arena real e
pela função real de reinício. Reinícios pelo botão de pausa e pela tela de
game-over permanecem cobertos pelos probes anteriores.

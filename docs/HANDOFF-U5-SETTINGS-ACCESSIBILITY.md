# Handoff U5 — vNext Settings / Accessibility

U5 está implementado em `codex/plan-execution` atrás de `KP_VNEXT_SETTINGS=1`. Sem a variável, o caminho legado continua padrão.

## Como verificar

```sh
KP_VNEXT_SETTINGS=1 godot --headless --audio-driver Dummy --path . res://tools/vnext_accessibility_probe.tscn
KP_VNEXT_SETTINGS=1 xvfb-run -a godot --headless --audio-driver Dummy --path . res://tools/vnext_accessibility_probe.tscn
godot --headless --audio-driver Dummy --path . -- --autotest
KP_VALIDATION_LOGS=.godot/codex-review-u5-final tools/validate_input_dispatch.sh
```

Resultado controller-fresh: probe headless e Xvfb 59/0; suíte 1414/0 com `AUTOTEST_ALL_PASS`; acumulador `VALIDATION OK`; import exit 0.

## Contrato entregue

`Sfx` mantém `user://kernel_panic.cfg`, oferece defaults, snapshot schema 2 com metadata `supported`, normalização defensiva, apply/reset/reload e escrita sem apagar seções alheias. Os campos funcionais são color assist, haptics, screen shake e touch size. A superfície usa `Button` real, foco determinístico, ESC/Back, regiões de pointer/touch, semântica ON/OFF e confirmação dupla de reset. Resize foi verificado em 1366×768, 720×720, 432×720 e 390×844.

## Limitações explícitas

Não há controles interativos para text scaling, high contrast, reduced flash, leitor de tela ou gamepad. Essas capacidades aparecem somente na nota honesta `NOT AVAILABLE YET` e permanecem trabalho futuro. Não houve simulação forçada de falha de filesystem; o status de recovery é observável e o código restaura o estado anterior se `ConfigFile.save()` falhar. Touch físico, Android, localização, visual review e performance não foram declarados por este handoff.

## Commits

- `f435c03` — contrato Sfx, superfície e integração Menu.
- `0d980dc` — probe, scene runner e acumulador.

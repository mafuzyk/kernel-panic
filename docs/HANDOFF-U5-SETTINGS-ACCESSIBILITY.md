# Handoff U5 — vNext Settings / Accessibility

U5 está implementado em `codex/plan-execution` atrás de `KP_VNEXT_SETTINGS=1`. Sem a variável, o caminho legado continua padrão.

## Como verificar

```sh
KP_VNEXT_SETTINGS=1 godot --headless --audio-driver Dummy --path . res://tools/vnext_accessibility_probe.tscn
KP_VNEXT_SETTINGS=1 xvfb-run -a godot --headless --audio-driver Dummy --path . res://tools/vnext_accessibility_probe.tscn
godot --headless --audio-driver Dummy --path . -- --autotest
KP_VALIDATION_LOGS=.godot/codex-review-u5-final tools/validate_input_dispatch.sh
```

Resultado final controller-fresh: probe headless e Xvfb 66/0; suíte 1414/0 com `AUTOTEST_ALL_PASS`; acumulador `VALIDATION OK`; import exit 0. A suíte final foi executada depois da correção do loader e o acumulador incluiu os lotes anteriores.

## Contrato entregue

`Sfx` mantém `user://kernel_panic.cfg`, oferece defaults, snapshot schema 2 com metadata `supported`, normalização defensiva tanto no apply quanto no carregamento, apply/reset/reload e escrita sem apagar seções alheias. Falha de escrita restaura os valores anteriores em memória e a superfície informa o rollback. Os campos funcionais são color assist, haptics, screen shake e touch size. A superfície usa `Button` real, foco determinístico, ESC/Back, regiões de pointer/touch, semântica ON/OFF e confirmação dupla de reset. Resize foi verificado em 1366×768, 720×720, 432×720 e 390×844.

## Limitações explícitas

Não há controles interativos para text scaling, high contrast, reduced flash, leitor de tela ou gamepad. Essas capacidades aparecem somente na nota honesta `NOT AVAILABLE YET` e permanecem trabalho futuro. O probe força uma falha determinística de `ConfigFile.save()` usando um caminho inválido e confirma rollback/status; falhas físicas de permissão, disco cheio ou storage removível ainda não foram simuladas. Touch físico, Android, localização, visual review e performance não foram declarados por este handoff.

## Commits

- `f435c03` — contrato Sfx, superfície e integração Menu.
- `0d980dc` — probe, scene runner e acumulador.
- `1de633f` — correção pós-revisão: normalização no carregamento, rollback de
  memória, status honesto, fixture forte e fault-injection determinístico.

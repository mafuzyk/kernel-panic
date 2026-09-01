# Handoff U6 — shared state surface vNext

U6 está implementado na branch `codex/plan-execution` sem route de produto e sem mudança no caminho legado.

## Verificação

```sh
godot --headless --audio-driver Dummy --path . res://tools/vnext_state_surface_probe.tscn
xvfb-run -a godot --headless --audio-driver Dummy --path . res://tools/vnext_state_surface_probe.tscn
godot --headless --audio-driver Dummy --path . -- --autotest
KP_VALIDATION_LOGS=.godot/codex-review-u6-final tools/validate_input_dispatch.sh
```

A probe cobre as quatro composições, quatro viewports, contrato deep-copy, sanitização, ações seguras, foco por action ID, Buttons reais e `Viewport.push_input`, pointer/touch, dispatch sem duplicação, overflow e ausência de acesso a gameplay/save/scene APIs. Resultado controller-fresh: 142 passes/0 falhas headless e Xvfb; suíte completa 1414/0 com `AUTOTEST_ALL_PASS`; validator `VALIDATION OK`.

## Producer real versus fixture-only

Não há producer real integrado neste slice. Missing catalog content, malformed-save recovery, unavailable localization e failed transition são fixtures de contrato, explicitamente marcadas pela probe. Menu/Arena continuam owners das rotas existentes; a surface apenas emite actions.

## Limitações

Não comprovados: touch físico, Android/export, PT-BR, screen reader nativo, performance de dispositivo, aprovação visual/grayscale humana e falhas reais de storage. Texto longo é medido e reportado, mas ainda não tem scroll. Diagnósticos de teardown continuam não-gating do baseline.

## Commits

- `a7619bd` — probe U6 vermelha.
- `c709734` — contrato, modelo de foco e superfície.
- `33a3568` — validator acumulado.

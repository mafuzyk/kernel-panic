# Handoff U6 — shared state surface vNext

U6 está implementado na branch `codex/plan-execution` sem route de produto e sem mudança no caminho legado.

## Verificação

```sh
godot --headless --audio-driver Dummy --path . res://tools/vnext_state_surface_probe.tscn
xvfb-run -a godot --headless --audio-driver Dummy --path . res://tools/vnext_state_surface_probe.tscn
godot --headless --audio-driver Dummy --path . -- --autotest
KP_VALIDATION_LOGS=.godot/codex-review-u6-final tools/validate_input_dispatch.sh
```

A probe cobre as quatro composições, quatro viewports, contrato deep-copy, sanitização, ações seguras, foco por action ID, Buttons reais e `Viewport.push_input`, pointer/touch, dispatch sem duplicação, overflow e ausência de acesso a gameplay/save/scene APIs. Resultado final: 145 passes/0 falhas headless e Xvfb; suíte completa 1414/0 com `AUTOTEST_ALL_PASS`; validator `VALIDATION OK`.

A revisão adversarial encontrou e corrigiu dois problemas antes da aceitação: a sanitização deixava chaves visíveis como `state.error.title`, `menu.retry-label` e `catalog.missing` passarem como copy; e o validator tinha timeout, mas não escalava TERM para KILL. A probe cobre agora os três formatos e todas as invocações do validator usam `timeout --kill-after=5s`, configurável por `KP_VALIDATION_KILL_GRACE_SECONDS`. Um comando sintético que ignora TERM foi contido em aproximadamente dois segundos, exit 137. Isso valida a escalada do wrapper, não uma supervisão completa de descendentes arbitrários.

## Producer real versus fixture-only

Não há producer real integrado neste slice. Missing catalog content, malformed-save recovery, unavailable localization e failed transition são fixtures de contrato, explicitamente marcadas pela probe. Menu/Arena continuam owners das rotas existentes; a surface apenas emite actions.

## Limitações

Não comprovados: touch físico, Android/export, PT-BR, screen reader nativo, performance de dispositivo, aprovação visual/grayscale humana e falhas reais de storage. Texto longo é medido e reportado, mas ainda não tem scroll. Diagnósticos de teardown continuam não-gating do baseline.

Dois probes U6 iniciais foram executados sem limite e permaneceram vivos por mais de sete minutos; foram encerrados pelo controller. As execuções finais têm timeout explícito. O incidente é de higiene do harness, não evidência de travamento da superfície em sua execução final.

## Commits

- `a7619bd` — probe U6 vermelha.
- `c709734` — contrato, modelo de foco e superfície.
- `33a3568` — validator acumulado.
- `7c0e7f3` — rejeição de chaves visíveis adicionais e timeout com escalada.

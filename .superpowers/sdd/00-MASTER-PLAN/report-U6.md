# U6 — relatório técnico: shared state surface vNext

## Resultado

U6 adiciona um contrato puro `VNextUIState`, um `VNextUIFocusModel` determinístico e uma superfície `VNextStateSurface` code-drawn para `loading`, `error`, `empty` e `transition`. A superfície emite somente `action_requested`; não conhece `Game`, `Arena`, `ConfigFile`, timers, saves ou troca de cena.

## Ownership e escopo

- `ui_state.gd`: normaliza kind, copy visível, actions, metadata, marcador/padrão, `recoverable` e `busy`; unknown/malformed cai em `error` acionável.
- `ui_focus_model.gd`: ordem por action ID, movimento, snapshot, restauração e guarda de dispatch.
- `state_surface.gd`: shell desenhado, Buttons reais somente para actions presentes, foco, Enter/Space, Escape/Back, pointer/touch, layout seguro e medição por campo.
- `vnext_state_surface_probe.gd/.tscn`: probe focada; os quatro producers citados no brief são fixtures, não integração de catálogo/save/locale/route.
- `validate_input_dispatch.sh`: U6 headless e Xvfb com marcador obrigatório e diagnóstico de runtime separado de teardown.

Não foi criada route de produto nem alterado o comportamento legado. A superfície permanece fixture-only até uma tarefa posterior conectar um owner real.

## Red → green e revisão adversarial

A probe foi criada antes dos arquivos de produção e falhou corretamente com exit 1: `state contract exists`, `focus model exists` e `state surface exists` falharam, terminando em `PROBE_DONE fails=3`. Depois a revisão própria identificou que chamadas diretas a `handle_input` não provavam ownership GUI; a probe foi fortalecida com `Viewport.push_input` para teclado e mouse em Buttons reais, além de retry desabilitado, fixtures nomeadas e guarda lexical contra owners proibidos.

## Evidência

- Focada headless final: exit 0, 142 `PROBE_PASS`, 0 `PROBE_FAIL`, `PROBE_DONE fails=0`; inclui 1366×768, 720×720, 432×720 e 390×844, todos os quatro kinds, target floor, não sobreposição, overflow medido, foco por ID, pointer/touch e Button/Viewport.
- Focada Xvfb: exit 0, 142 `PROBE_PASS`, 0 `PROBE_FAIL`, `PROBE_DONE fails=0`; sem runtime errors gating.
- Import/editor: exit 0; aviso ambiental `Unable to open Android 'build-tools' directory.` permanece conhecido.
- Suíte completa: exit 0, `AUTOTEST_ALL_PASS`, 1414 `AT_PASS`, 0 `AT_FAIL`; teardown diagnostics conhecidos permanecem.
- Validator acumulado: `VALIDATION OK`; U6 headless/Xvfb 118/0 em ambos, runtime errors gating = 0.
- Commits de código: `a7619bd` (probe red), `c709734` (contrato/modelo/superfície), `33a3568` (validator); documentação será commit separado.

## Compatibilidade, rollback e riscos

Sem integração de route, o rollback é remover os três novos arquivos de produção e a entrada do validator; o legado não depende deles. O risco principal é que o texto de locale arbitrariamente longo seja apenas detectado, não rolável. Android, hardware touch, screen reader nativo, performance de dispositivo, PT-BR e aprovação visual não foram declarados. Permanecem os diagnósticos de teardown do baseline.

## Alternativas rejeitadas

Não foi usado `Game`/`Arena` dentro da primitive, não foi criada persistência própria, não foi usado spinner/percentual falso e não foi adicionada ação visível ao menu apenas para alcançar a probe. A integração de producers reais fica para uma tarefa posterior com owner explícito.

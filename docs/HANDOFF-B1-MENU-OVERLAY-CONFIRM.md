# Handoff — B1 — confirmação confinada aos overlays do menu

## Branch

- Branch: `codex/b1-overlay-confirm`
- Base: `4c8fa7d` (`codex/r10-event-banner`)
- Commit do item: `d5913af` — `fix: contain menu overlay confirmation input (B1)`
- Sem merge em `main`; alterações pré-existentes do working tree preservadas.

## Achado

O `_unhandled_input()` do menu tinha tratamento explícito de ESC para cada
overlay, mas Program não retornava quando recebia ENTER e Story retornava sem
tratar ENTER. Isso deixava o contrato da interface implícito e fazia o Story
ignorar a legenda de montagem por ENTER; o seletor de Program dependia do
fallthrough até `_start()` global.

## Regra aplicada

- Program: ESC fecha o seletor; ENTER inicializa uma run com o programa
  selecionado.
- Story: ESC fecha o seletor; ENTER monta o estágio selecionado.
- Settings, Bestiary e Awards: ENTER fica contido no overlay; ESC fecha apenas
  o overlay.
- Cada caminho marca o evento como tratado e retorna antes do `_start()` global.

Não houve alteração de balanceamento, seleção por clique, renderização ou
layout. O comportamento de clique existente permanece intocado; B2 ainda
precisa decidir e implementar a correspondência visual/clicável dos rodapés.

## Teste novo

`tools/menu_overlay_input_probe.tscn` usa um boot persistente para sobreviver a
trocas Menu/Arena e envia press/release reais via `Viewport.push_input`.
Verifica ENTER e ESC individualmente em Settings, Bestiary, Awards, Program e
Story.

Red antes da correção:

- 9 checks passaram;
- `PROBE_FAIL timeout waiting for story ENTER mount`;
- `PROBE_FAIL B1 story ENTER explicitly mounts selected stage`;
- exit 1.

Green após a correção:

- 10 checks passaram;
- `PROBE_DONE fails=0`;
- exit 0.

## Validação final

Comando oficial, executado com `--audio-driver Dummy`:

```bash
KP_VALIDATION_LOGS=<absolute-log-dir> tools/validate_input_dispatch.sh
```

Resultado pós-commit da implementação:

- DevHarness: 1418 passes, 0 failures;
- input dispatch headless: 32/0;
- R04 projectile: 7/0;
- R05 rootlet: 28/0;
- R06 Temple GOD: 7/0;
- R07 Story restart: 4/0;
- R08 OOM loot: 6/0;
- B1 menu overlays: 10/0;
- input dispatch Xvfb debug: 34/0;
- runtime/script errors: 0;
- `VALIDATION OK`, exit 0.

Os diagnósticos de recursos/RIDs/texturas no teardown continuam visíveis e não
gating, conforme T02; nenhum erro de execução é mascarado.

## Próximo item

B2: decidir e implementar os affordances de `MOUNT [ENTER]` e `>> BOOT KERNEL
[ENTER]`, respeitando a separação entre selecionar e confirmar sem reabrir o
problema de fallthrough do B1.

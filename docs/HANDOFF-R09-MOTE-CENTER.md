# Handoff — R09 — coleta de mote no centro do jogador

## Branch

- Branch: `codex/b5-terminal-history`
- Commit de cobertura: `aafc4d1` — `test: lock centered mote collection behavior (R09)`
- Fix de produção já presente na base: `a0d943d` — sweep de coleta do
  `MoteField`.
- Sem merge em `main`; alterações locais pré-existentes foram preservadas.

## Veredito revisado

O achado original dizia que uma mote a até 1 px do jogador não poderia ser
coletada porque a atração usava `d > 1.0`. Isso confundia a condição de puxão
com a condição de coleta. No código atual, `MoteField` coleta quando `d < 20.0`
ou quando a mote cruza o segmento percorrido pelo jogador; essa condição não
tem o bloqueio de 1 px. O caminho legado `Mote` também usa a mesma separação.

Portanto, R09 não é um bug pendente neste estado do código. A lógica do
`d > 1.0` só evita normalizar um vetor degenerado durante a atração.

## Cobertura adicionada

`_mote_center_test()` em `src/autoload/harness/sections_misc.gd` cria uma mote
no caminho real do `MoteField`, com o jogador parado, nas distâncias 0, 0,5,
1 e 2 px. Cada mote precisa desaparecer por coleta em até dois frames. O
teste roda na suíte DevHarness e não altera produção nem balanceamento.

Resultado fresco:

- 4/4 checks do caso R09;
- suíte headless: 1422 passes, 0 failures;
- `AUTOTEST_ALL_PASS`;
- exit 0;
- diagnósticos de recursos/RIDs no teardown continuam separados e não-gating.

## Escopo

Nenhuma mudança visual foi feita. O próximo trabalho deve priorizar auditoria
de código e a nova UI do zero, não acumular microcorreções na UI existente.

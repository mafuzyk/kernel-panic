# Relatório A1 — baseline e inventário

Data: 2026-09-01
Worktree: `/tmp/kernel-panic-plan-execution`
Branch: `codex/plan-execution`

## Escopo executado

Foi feito somente inventário documental. Não foram alterados `project.godot`,
`src/`, `tools/` ou testes. O baseline detalhado está em
[`docs/release/BASELINE-A1-2026-09-01.md`](/tmp/kernel-panic-plan-execution/docs/release/BASELINE-A1-2026-09-01.md).

## Evidência e resultados

Comandos principais executados:

```sh
git status --short --branch
git log -1 --format='commit=%H%nshort=%h%nsubject=%s%nauthor=%an%n date=%aI'
rg -n '...' project.godot export_presets.cfg
rg -n 'get_value\(|set_value\(' src/autoload/game.gd src/autoload/sfx.gd
find src tools -type f \( -name '*.gd' -o -name '*.tscn' \) -print0 | xargs -0 wc -l
godot --headless --audio-driver Dummy --path . --editor --quit
XDG_DATA_HOME=/tmp/kernel-panic-a1-xdg-20260901 godot --headless --audio-driver Dummy --path . -- --autotest
```

Resultados comprovados:

- HEAD `295cc0cca93a970a87af196dd7f9d7d3a4d8812e`, subject `docs: close master plan review gaps`;
- autotest exit `0`, `1414 AT_PASS`, `0 AT_FAIL`, `AUTOTEST_ALL_PASS` presente;
- autotest teardown: 5 linhas `ERROR`, 2 linhas `WARNING`, detalhadas no baseline;
- import exit `0`, com `Unable to open Android 'build-tools' directory.`;
- autoloads exatamente `Game`, `Sfx`, `Fx`, `DevHarness`;
- versão do projeto `2.5.0`, transferência `kernel-panic-save`/versão `1`;
- targets declarados: Android, Linux x86_64, Windows x86_64;
- contagens: 74 `.gd` em `src/`, 22 `.gd` em `tools/`, 15 `.tscn` e 20.661 linhas combinadas de `.gd`/`.tscn` em `src`+`tools`.

## Fatos de persistência confirmados

`Sfx.SAVE_PATH` é `user://kernel_panic.cfg`. As seções/chaves existentes,
defaults e o contrato de transferência estão listados no baseline. A leitura
do código confirmou que gravações passam por `Sfx.save_settings()` ou pelos
helpers de `Game`; nenhum novo campo foi adicionado.

## Suposições e incertezas

- `Godot 4.7.x` é inferido da feature `PackedStringArray("4.7")`; a versão
  exata do binário não foi fixada neste relatório porque não foi necessária
  para a evidência funcional.
- A contagem “testes” é reportada como contagem de `AT_PASS` do DevHarness;
  não há um runner separado de testes unitários confirmado.
- `lifetime` é tratado como seção de persistência separada porque o código usa
  um `ConfigFile` próprio; o nome/caminho exato desse arquivo não foi
  confirmado e permanece incerto.
- Não existe `AGENTS.md` em `/tmp/kernel-panic-plan-execution/`; a tentativa
  de leitura retornou arquivo inexistente. Não foram importadas instruções de
  outro checkout.
- Targets ausentes de macOS/Web não são prova de que export não funcione; são
  apenas targets não declarados nos presets locais.

## Riscos carregados para tarefas seguintes

1. A importação de um checkout limpo é pré-requisito operacional.
2. O warning de Android build-tools bloqueia a confirmação de viabilidade do
   export Android até o ambiente ser corrigido/verificado.
3. Os 5 erros e 2 warnings de teardown são ruído conhecido, mas continuam
   visíveis e não podem ser convertidos em “suite limpa” sem evidência nova.
4. Os arquivos `.uid` e `.png.import` não rastreados existentes devem ficar
   fora do commit A1; nenhum artefato gerado foi estagiado.

## Ordem posterior

Nenhum achado exige reordenar o plano. A1 deve ser citado por A2–A5 antes de
mover caminhos, alterar contratos ou adicionar preferências.

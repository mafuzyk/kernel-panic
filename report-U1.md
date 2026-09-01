# U1 — vNext boot vertical slice

Status: implementado em 2026-09-01 no worktree `/tmp/kernel-panic-plan-execution`, branch `codex/plan-execution`.

## Antes / depois

Antes, `src/ui/vnext/` tinha apenas tokens, primitivas e ilustração, sem contexto, layout, navegação ou superfície. O probe red falhava porque `boot_surface.gd` não existia.

Depois, existe um slice opt-in code-drawn com contexto responsivo, regiões acionáveis compartilhadas, foco, despacho único e shell de boot. A rota legacy continua padrão; `KP_VNEXT_BOOT=1` habilita a nova superfície.

## Arquivos

- `src/ui/vnext/ui_context.gd`
- `src/ui/vnext/ui_layout.gd`
- `src/ui/vnext/ui_navigation.gd`
- `src/ui/vnext/surfaces/boot_surface.gd`
- `tools/vnext_boot_probe.gd`
- `tools/vnext_boot_probe.tscn`
- `src/ui/menu.gd` (somente rota opt-in)

## Evidência

- Red: probe falhou com `File not found` para `boot_surface.gd`.
- Green: `godot --audio-driver Dummy --headless --path . res://tools/vnext_boot_probe.tscn`, `PROBE_DONE fails=0`.
- Full: `godot --audio-driver Dummy --headless --path . -- --autotest`, `AT_FAIL=0`, `AUTOTEST_ALL_PASS`.

O probe cobre 1366×768, 720×720 e 432×720, regiões >=44px, overflow, marcadores semânticos, ENTER, mouse, touch e dupla ativação.

## Decisões e alternativas

Foi escolhido um `Control` code-drawn com uma tabela de `Rect2` como fonte única para desenho e input. O contexto usa densidade lógica por largura disponível. A integração foi mantida opt-in para rollback imediato e nenhuma chamada de gameplay/save foi alterada.

Alternativas rejeitadas: copiar o menu antigo, usar imagens/raster, ou substituir a rota legacy por padrão.

## Riscos e limitações

- A ação de boot incrementa o contador do slice, mas o wiring final para iniciar a run pertence ao próximo passo de integração; não foi alterado gameplay.
- A navegação já tem contrato de stack/dispatch, mas ainda não há múltiplas rotas vNext neste slice.
- Não houve ferramenta de revisão visual disponível; captura e aprovação visual ficam como risco aberto. Nenhuma aprovação visual é declarada.
- Diagnósticos de teardown pré-existentes do projeto permanecem fora do escopo.

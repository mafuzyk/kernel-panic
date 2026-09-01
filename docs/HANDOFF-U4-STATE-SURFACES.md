# Handoff — U4 vNext state surfaces

U4 entrega superfícies experimentais code-drawn para pausa, terminal e
game-over atrás de `KP_VNEXT_U4=1`. O caminho legado continua sendo o padrão.

```text
KP_VNEXT_U4=1 godot --audio-driver Dummy --path .
KP_VNEXT_U4=1 godot --headless --audio-driver Dummy --path . res://tools/vnext_state_surfaces_probe.tscn
KP_VNEXT_U4=1 xvfb-run -a godot --headless --audio-driver Dummy --path . res://tools/vnext_state_surfaces_probe.tscn
godot --headless --audio-driver Dummy --path . -- --autotest
KP_VALIDATION_LOGS=.godot/codex-review-u4-final KP_VALIDATION_TIMEOUT_SECONDS=120 tools/validate_input_dispatch.sh
```

O áudio Dummy é intencional para execuções de validação e estudo. A variável
`KP_VNEXT_U4` é opt-in: sem ela, `Arena` não monta a camada nem troca os
panels legados.

## Estado e input

- `Arena` é dono de pausa, `_state`, confirmação de Q, comandos e transições.
- As superfícies em `src/ui/vnext/surfaces/` só projetam snapshots e emitem
  ações.
- Uma única `CanvasLayer` U4 recebe a superfície corrente.
- ESC abre/fecha pausa, ESC fecha terminal focado, Q arma/confirmar abandono,
  ENTER executa e navega, TAB/setas percorrem foco.
- `LineEdit`, `Button` e foco são Controls reais; o shell e os frames são
  desenhados manualmente.

## Resultado

- Probe headless: `71` passes, `0` fails.
- Probe Xvfb: `71` passes, `0` fails.
- Validador acumulado: `VALIDATION OK`.
- Suíte: `1414 AT_PASS`, `0 AT_FAIL`, marker presente.
- Nenhum `SCRIPT ERROR`/erro de runtime gating no U4.

## Correções importantes da revisão

O primeiro resultado verde foi rejeitado porque os Controls estavam invisíveis,
o probe mascarava Q e não exigia overflow real. A correção também resolveu o
título do terminal cortado em 432 px, o overlap dos botões de game-over,
labels de vitória incorretos, parent inconsistente entre surfaces, semântica
stale após comando e foco adiado depois de `queue_free()`.

## Antes de promover a default

Ainda faltam aprovação visual humana, PT-BR, escala de texto localizada,
acessibilidade persistida, leitor de tela se viável, teste físico touch,
Android export, stress de lifecycle/navegação e investigação separada dos
diagnósticos de teardown (resources/RIDs/ObjectDB/text shaping). U4 também não
altera balanceamento ou regras de gameplay.

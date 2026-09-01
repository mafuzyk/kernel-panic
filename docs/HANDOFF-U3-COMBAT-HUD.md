# Handoff — U3 vNext combat HUD

U3 entrega o HUD experimental atrás de `KP_VNEXT_HUD=1`. `Hud` segue sendo o
ponto de compatibilidade, `Arena` segue dono do runtime e a implementação está
em `src/ui/vnext/surfaces/combat_hud_surface.gd`.

```text
KP_VNEXT_HUD=1 godot --audio-driver Dummy --path .
KP_VNEXT_HUD=1 godot --headless --audio-driver Dummy --path . res://tools/vnext_combat_hud_probe.tscn
godot --headless --audio-driver Dummy --path . -- --autotest
```

Para a bateria acumulada, use `KP_VALIDATION_TIMEOUT_SECONDS=120
tools/validate_input_dispatch.sh`; cada caso tem timeout e um processo que
trava falha por código, em vez de consumir a sessão indefinidamente. O padrão
é 120 segundos e pode ser reduzido em CI rápido.

O probe cobre estados, boss split com duas frações vivas, evento longo, markers,
três larguras, centro reservado, regiões sem overlap, dash touch-safe, resize,
overflow por campo, banner temporário e dano real com direção no Arena. A
superfície não intercepta o ponteiro fullscreen: somente o clique desktop na
região do dash é consumido; o toque continua pertencendo ao `TouchControls`.

Antes de promover a superfície a default, ainda são necessárias captura/revisão
artística humana, teste em dispositivo touch, validação de escala de texto
localizada e export Android. Diagnósticos de teardown permanecem os do
baseline; eles não foram escondidos pela bateria de probes.

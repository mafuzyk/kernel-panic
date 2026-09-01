# Handoff — U3 vNext combat HUD

U3 entrega o HUD experimental atrás de `KP_VNEXT_HUD=1`. `Hud` segue sendo o
ponto de compatibilidade, `Arena` segue dono do runtime e a implementação está
em `src/ui/vnext/surfaces/combat_hud_surface.gd`.

```text
KP_VNEXT_HUD=1 godot --path .
KP_VNEXT_HUD=1 godot --headless --audio-driver Dummy --path . res://tools/vnext_combat_hud_probe.tscn
godot --headless --audio-driver Dummy --path . -- --autotest
```

O probe cobre estados, boss split, evento longo, markers, três larguras,
centro reservado, dash touch-safe, resize, overflow e Arena real. Antes de
promover a superfície a default, ainda são necessárias captura/revisão
artística humana, teste em dispositivo touch e uma fonte real de direção de
dano. Diagnósticos de teardown permanecem os do baseline.

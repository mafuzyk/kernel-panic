# U3 — report: vNext combat HUD

## Resultado

U3 adiciona um HUD de combate code-drawn opt-in por `KP_VNEXT_HUD=1`. Sem a
variável, o HUD legado permanece padrão e sua API/campos observados continuam
intactos. A nova superfície é filha do `Hud` real montado pelo `Arena` e lê
estado autoritativo de `Game`, `Player`, patches e boss.

As zonas são integridade/programa, evento temporário, ciclo + patch dock,
dash, score/combo/tempo e boss condicional. O centro do playfield é reservado
em 432×720, 1280×720 e ultrawide. Estado contínuo e feedback temporário são
separados; estados críticos têm marcadores textuais além da cor.

## Arquivos e compatibilidade

- `src/ui/vnext/surfaces/combat_hud_surface.gd`: desenho, layout, semântica,
  overflow e input.
- `src/ui/hud.gd`: adapter opt-in, sincronização e ação de dash.
- `src/arena/arena.gd`: consultas da integração real.
- `tools/vnext_combat_hud_probe.gd` / `.tscn`: probe vermelho/verde.
- `tools/validate_input_dispatch.sh`: bateria acumulada.

Os campos `player`, `boss`, `_boss_fragments`, `_boss_split`, `_boss_name`,
`_boss_frac`, `_dash_frac`, `_banner_t`, `_banner_text`, `_banner_sub`, filas,
labels, snapshots, tooltips, banners, accent, geometrias e `_process` não foram
removidos ou renomeados. O adapter continua dono dos valores legacy; o
surface não cria um segundo modelo de gameplay nem altera balanceamento.

Alternativas rejeitadas: reescrever o HUD existente, criar mock desconectado
ou montar muitos Controls/Labels. A solução escolhida mantém rollback simples,
uma fonte de layout code-drawn e o Arena como dono do runtime.

## Evidência

O probe foi criado e executado vermelho antes do arquivo de produção existir.
Depois passou com exit 0 e `PROBE_DONE fails=0`, cobrindo 1–12 HP, meter vazio
e cheio, dash pronto/em cooldown, wave/ciclo, boss split, HP baixo, evento
longo, marcadores semânticos, reserva central, barra fora do jogador, touch-safe
dash, input, resize, overflow normal/intencional e montagem no Arena real.

Comandos, sempre com áudio Dummy:

```text
KP_VNEXT_HUD=1 XDG_DATA_HOME=/tmp/kernel-panic-u3-probe godot --headless --audio-driver Dummy --path . res://tools/vnext_combat_hud_probe.tscn
godot --headless --audio-driver Dummy --path . --editor --quit
```

Não há aprovação artística humana neste registro: screenshot estrutural,
geometria e overflow não substituem revisão visual.

## Revisão adversarial e limites

Foi checado que o legado não desenha no opt-in, labels auxiliares legacy ficam
ocultos, resize não usa anchors conflitantes, a superfície não guarda refs de
entidades e não possui loop próprio de gameplay. O teardown ainda apresenta os
diagnósticos de recursos/RIDs/ObjectDB já registrados no baseline W0; U3 não
declara resolvê-los. A direção de dano permanece `NONE` até haver fonte real no
gameplay, sem inventar estado. A touch layer existente continua dona de
movimento/aim; a nova região de dash é touch-safe.

## Release

Registrar um HUD de combate experimental, responsivo e code-drawn atrás de
`KP_VNEXT_HUD=1`; o HUD legado segue default. Não anunciar arte final,
screen-reader, Android ou aprovação visual humana.

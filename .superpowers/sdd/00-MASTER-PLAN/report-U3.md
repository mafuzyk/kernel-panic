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
- `src/player/player.gd`: fonte temporal do vetor do último dano para a
  leitura direcional da HUD; nenhuma regra de dano foi alterada.
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

## Revisão adversarial e correções posteriores

A primeira implementação ficou verde no probe original, mas a revisão
independente encontrou falhas que aquele probe não media: uma superfície
fullscreen com `MOUSE_FILTER_STOP` bloqueava tiro/interação fora do dash; o
boss split desenhava uma barra única com fração `-1`; as regiões inferior e
superior colidiam em 432×720; o texto de patch podia ficar stale e exibia IDs
crus; o overflow usava uma estimativa de caracteres; o evento lia o log em vez
do feedback temporário; e a direção de dano não tinha produtor real.

Esses achados foram convertidos em checks vermelhos e corrigidos antes do
aceite final:

- `MOUSE_FILTER_IGNORE` e `_input()` tratam somente clique de mouse dentro da
  ação desktop de dash; toque continua sob `TouchControls`, preservando o
  joystick de movimento e o dash multitouch existente.
- `boss_bars_snapshot()` projeta cada fragmento vivo por slot e o desenho
  mostra duas barras durante o split, em vez de usar a fração inválida do root.
- O layout reserva uma linha própria para boss abaixo de dash/score; no modo
  estreito o evento desce abaixo dos painéis superiores. O probe agora testa
  interseção entre todas as regiões, não apenas o retângulo reservado.
- O dock calcula etiquetas com código e nível, atualiza quando níveis mudam e
  usa uma assinatura para não reconstruir o array a cada frame.
- O relatório mede cada campo renderizado com `Font.get_string_size()`, fonte,
  tamanho e escala reais; evento, ciclo, patches, integridade, programa, dash,
  score, run e boss são reportados separadamente.
- O ciclo contínuo fica no dock superior direito; banners de ciclo alimentam
  apenas a explicação temporária no centro, evitando repetir `CYCLE NN` em dois
  lugares fortes.
- `Player.take_damage()` registra por 0,85 s o vetor da fonte, sem mudar dano,
  invulnerabilidade ou balanceamento. O adapter converte o vetor para
  `E/SE/S/SW/W/NW/N/NE` e exibe `HIT FROM`, além do marcador semântico.
- A poda de fragmentos legacy só aloca novo array quando existe referência
  inválida, reduzindo trabalho contínuo sem mudar a semântica.

O probe de correção falhou primeiro com o filtro de mouse, método de boss
ausente e overlap; após a correção passou com 48 checks e
`PROBE_DONE fails=0`, incluindo banner real e dano real no Arena. A suíte
legacy permaneceu verde. Isso não constitui aprovação artística humana:
  ainda faltam captura estrutural/finish revisada por pessoa, dispositivo
  touch real e validação Android. Os diagnósticos de teardown de
recursos/RIDs/ObjectDB continuam os resíduos W0 e não foram mascarados.

Durante a revisão foi observado que execuções Godot sem marker podiam ficar
vivas indefinidamente quando um probe travava. A validação acumulada agora
envolve todos os casos, a suíte e o Xvfb em `timeout`, preservando o requisito
de marker e evitando consumir a janela de uso em caso de deadlock. O timeout
não transforma falha em sucesso: o código 124 continua sendo reportado como
falha pelo validador.

## Release

Registrar um HUD de combate experimental, responsivo e code-drawn atrás de
`KP_VNEXT_HUD=1`; o HUD legado segue default. Não anunciar arte final,
screen-reader, Android ou aprovação visual humana. A direção de dano agora tem
fonte real no Player, mas sua apresentação final ainda precisa de revisão
visual e de localização.

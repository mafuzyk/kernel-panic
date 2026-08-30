# Art Migration Batch 1 — Session Report (2026-08-30, CachyOS)

> Fase: início da migração progressiva code-drawn → arte gerada (direção da
> autora, 2026-08-30). Branch `wip/polish-pack`. Councils: 4 rodadas de
> sprites + 1 de ícones (3 cadeiras: glm-5.3-flash / gpt-5.6-luna /
> deepseek-v4-flash-vision-exp — gamma trocada pra variante vision durante a
> sessão porque a anterior não via imagens).

## Resultado

- **Sprites — lote P1 (7/7 GO e aplicados in-game):** kernel, daemon,
  rootlet, oom, update_loop, trojan regenerados + god com artefato limpo.
  Capturas in-situ: arena (batch1), painel de programas, god boss — tint via
  modulate funcionando, silhuetas legíveis, sem glow box.
- **Ícones — 6 kinds adotados + 1 mantido:** settings, bestiary, awards,
  terminal, restart, warning agora têm rasters (o awards era 100% novo — não
  existia raster); music MANTIDO (double-note atual é o gesto mais claro —
  divergiu o council, decisão conservadora). bestiary com opt-out @24px
  (`RASTER_OPTOUT`), pendente iteração fina.
- **Sistema unificado white-base + modulate:** `tactical_icon.gd:130` agora
  desenha rasters com `_accent` (4º arg de `draw_texture_rect`); os 39
  rasters antigos foram convertidos de pré-coloridos para white-base (RGB→
  branco, alpha preservado). Visual in-game idêntico, arquitetura coerente
  com a dos sprites.
- **Autotest: 1418 AT_PASS / 0 AT_FAIL** (+3 checks vs 1415 do polish pack),
  contratos ICON_METRICS/ICON_BOUNDS verdes.

## Hall of fame do debugging (lições pra pipeline)

1. **CopyOpacity:** ordem certa é `magick BASE_BRANCO GRAY_ART -compose
   CopyOpacity -composite` (base primeiro, máscara depois). Invertido = alpha
   zerado. Provado com teste 2x2.
2. **Visualizador dos councillors é white-on-white:** PNG white-base com
   fundo transparente aparece INVISÍVEL pra eles (só o glow semi-alfa
   aparece). Todo gate de arte precisa de flatten prévio sobre o navy da
   arena (#0a1226). Foi o H1 do gamma — confirmado com grid
   `alphacheck` (256px navy / 34px sim / alpha dump).
3. **`-evaluate multiply "r%,g%,b%"` falha silenciosamente** (não aplica). O
   parser de cor do `xc:` tá são — o problema é o evaluate multi-canal.
4. **Imagens geradas não vêm no tamanho pedido** (2048x1024 pedida →
   1536x1024 entregue; 1024 pedida → 1254). Medir ANTES de croppar.
5. **Glow baked vira box:** piso no canal alpha (`-channel A -level
   40%,92%`) mata a névoa do fundo sem lavar o traço.
6. **DstOut com xc:none não puncha nada** — a fonte do punch precisa ser
   opaca (xc:white).
7. **Anúncio de onda em fade** aparece como "texto fantasma" escuro em
   capturas com KP_SHOT_FRAMES=40 — artefato de timing, não bug.

## Decisões da autora aplicadas

- "O intuito é migrar dos glifos pros sprites reais" → nada reverte pra
  glifo; god foi LIMPADO (não revertido), contrariando o P0 do council
  (a evidência da gamma sobre god.png escuro se provou errada no T2 in-game:
  o god renderiza dourado lindo; só a barra-artefato existia).
- Ícones novos + sprites passam por council (4 rodadas sprites, 1 ícones).
- Jogos abrem sem som (`--audio-driver Dummy` nos scripts de captura).

## Pendências autor-gated

1. **Gate visual do lote:** capturas in-situ em
   `media/captures/xvfb/` (batch1/programs/god/menu/pause) — a autora
   valida; revert = `git checkout` dos assets.
2. **bestiary @24px:** opt-out ativo; iterar o pin ou aceitar o fallback.
3. **P2 (futuro):** passe de traço/halo nos sprites mantidos, regen de
   page/bloatware/bluescreen/pagefault se o in-situ condenar, validação do
   painel preenchido ("holograma sólido") estendida ao lote P2.
4. **Questionário de gameplay** (apêndice 9 do polish pack) — em andamento
   com a autora.

## Arquivos-chave

- Candidatos/processados: `media/concepts/sprites-batch1-*`,
  `media/concepts/icons-batch1-*`, `media/concepts/sprites-iter2-*`
- Capturas: `media/captures/xvfb/` (in-situ) — nunca em main
- Código: `tactical_icon.gd` (modulate + optout), `sections_modes.gd`
  (modos de captura `god` e `batch1`)
- Scripts: `/tmp/opencode/capture_xvfb.sh` (Xvfb, sem janela),
  `/tmp/opencode/capture.sh` (janela com pin Hyprland 0.56 Lua) — copiar
  pra `tools/` quando estabilizar

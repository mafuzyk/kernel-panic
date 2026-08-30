# KERNEL PANIC — Session Handoff (2026-08-30, parada segura pré-migração CachyOS)

> **⚠️ RESOLVIDO EM 2026-08-30 (CachyOS, pós-migração) — este doc é histórico.**
> T13 foi CONCLUÍDO (ver `reports/2026-08-30-polish-pack.md`), as decisões
> author-gated 1-2 foram tomadas e aplicadas (ícones v2 adotados, sprites
> migrados — direção: glifo é fallback, sprite é o padrão), o questionário do
> apêndice 9 foi respondido (`specs/2026-08-30-gameplay-backlog-answers.md`),
> o lote de arte batch 1 + passada de polimento P2 estão commitados
> (`reports/2026-08-30-art-migration-batch1.md`). Estado atual do projeto:
> roadmap e specs em `docs/superpowers/`; o backlog de gameplay aguarda
> implementação; branch `wip/polish-pack` com tudo commitado.
> As seções abaixo descrevem o estado da PARADA pré-migração — leia como histórico.

## Por que esta branch existe
A autora migrou Artix → CachyOS. Esta branch (`wip/polish-pack`) preserva TUDO da
sessão de 2026-08-30 antes do wipe: assets gerados que aguardam decisão author-gated,
sheets de conceito (fora do .gitignore de main de propósito AQUI), capturas de
aceitação e este handoff. `main` permanece limpa conforme os gates.

## Estado no momento da parada
- **Polish Pack (plano 2026-08-30-polish-pack.md): T1–T12 concluídos e commitados
  em main. T13 (verificação final + montagens) foi INTERROMPIDO** — capturas
  `final_*.png` ficaram na raiz do repo e estão preservadas aqui em
  `media/captures/2026-08-30-polish-final/`. Retomar T13 na volta.
- Autotest: **flaky confirmado** — `AT_FAIL rootlet has no overclock` apareceu 1x,
  passou na rodada seguinte com a árvore intocada (teste sensível a timing/headless
  sob carga). Estabilizar esse teste no retorno (priority baixa, não é regressão
  comprovada). Última contagem estável do T12: 1415 AT_PASS / 0 AT_FAIL / 77 AT_STEP
  (com sprites no registry) e 1405/77 com registry vazio.
- Último commit em main no momento do park: `c3ea805`.

## O que só existe NESTA branch (não está em main)
- `assets/sprites/generated/` — 20/21 entidades com sprites (256px, white-base,
  tintáveis via modulate). Ship decision da autora PENDENTE; em main o registry
  usa fallback glyph (visual idêntico ao atual).
- `media/concepts/` — sheets geradas: ícones (UI + patches, 2 versões + trials),
  sprites v1/v2 de inimigos, bosses, programas.
- `media/captures/2026-08-30-polish-final/` — capturas de aceitação do T13
  interrompido (menu, settings, awards, bestiary, game, story @1366/432).

## Decisões author-gated pendentes (não decidir sem a autora)
1. **T9 Step 5**: ícones raster aparados — manter ou reverter
   (`/tmp/opencode/icons_trim_sbs.png` se ainda existir; senão regenerar).
2. **T12**: sprites de entidades — manter ativos, ativar por kind, ou reverter.
   Capturas: `media/captures/.../final_game_*.png`. Bosses estão no teto de
   detalhe aprovado — autora pode pedir v2 menos ornamentada.
3. **Backlog de gameplay**: direção aprovada ("sim"), MAS cada ideia precisa das
   respostas de design da autora (ver apêndice 9 da spec polish-pack) antes de
   implementar.

## Problemas conhecidos registrados (não corrigidos)
- **Janela do jogo seguindo o cursor** nas capturas em vez de fixar no DP-1:
  o window_rule runtime (`hl.window_rule` via `hyprctl eval`) não está fixando o
  monitor de spawn no Hyprland 0.56 do autor. Fix proposto para a próxima sessão:
  pós-spawn, resolver o endereço da janela via `hyprctl clients -j` e mover com
  dispatch window-targeted (`hl.dsp.window.*`), como já foi feito para o float
  do 432×720 no T10.
- `hyprctl dispatch` direto quebrado (parser Lua 0.56) — usar sempre `hl.dsp.*`.
- `godot --headless --import` trava no desta máquina — usar
  `godot --headless --editor --quit-after 60 --path .`.
- `pkill -f godot` mata o shell wrapper — usar `pkill -x godot`.

## Próximos passos na volta (ordem sugerida)
1. `git fetch && git checkout wip/polish-pack` (ou revisar no GitHub).
2. Retomar **T13** do polish pack (verificação final + montagens).
3. Decisões author-gated acima (ícones, sprites).
4. Questionário de gameplay (spec polish-pack apêndice 9) — respostas da autora.
5. Migração progressiva code-drawn → arte gerada (direção aprovada 2026-08-30):
   sprites → tiles/era backgrounds → elementos de UI conforme aprovado.

— gerado pelo OX Alpha, com carinho, pra colega de trabalho 💙

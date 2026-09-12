# Deep Bug Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Encontrar, reproduzir e corrigir bugs funcionais de alto impacto no KERNEL PANIC, preservando o estilo de jogo e entregando evidência executada no monitor virtual.

**Architecture:** O trabalho usa o `DevHarness` como contrato de comportamento e adiciona probes pequenos por subsistema. Cada correção nasce de uma asserção que falha, recebe uma alteração mínima na origem do bug e termina com uma rodada completa do harness. A investigação percorre as fronteiras Arena → Spawner → inimigos/pickups → Player → Game → UI para pegar estados que testes unitários isolados não enxergam.

**Tech Stack:** Godot 4.7.2, GDScript, `DevHarness`, `Game.rng`, sessão KWin virtual em 1920×1080; sem testes headless nesta passada.

**Spec:** `KERNEL-PANIC-ROADMAP.md`, `KERNEL-PANIC-HANDOFF.md`, `docs/superpowers/specs/2026-08-27-review-findings.md` e os relatórios em `docs/superpowers/reports/`.

## Global Constraints

- Trabalhar inline, sem subagentes.
- Toda verificação gráfica roda somente em `tools/virtual-session/`.
- Não usar a sessão física, `DISPLAY=:0`, `pkill` ou `killall`.
- Não alterar regras de gameplay sem uma reprodução e uma decisão já registrada.
- One-HP nunca recebe cura, RECOVER ou prevenção de morte.
- A preferência de lock-on permanece acessível conforme as decisões atuais do roadmap.
- O RNG de gameplay usa `Game.rng`; aleatoriedade puramente visual não altera o stream da run.
- Não reverter alterações já presentes no working tree.
- Usar `apply_patch` e não criar testes que leiam a grafia do código-fonte.

---

### Task 1: Baseline e telemetria de falhas

**Files:**
- Modify: `src/autoload/dev_harness.gd`
- Modify: `src/autoload/harness/sections_scene.gd` quando um probe de reprodução precisar de uma entrada nova
- Create: `docs/superpowers/reports/2026-09-12-deep-bug-audit.md`

**Interfaces:**
- Consumes: cenas atuais de `Menu` e `Arena`, `Game.stats`, logs do Godot na sessão virtual.
- Produces: uma tabela de falhas reproduzidas com nome do teste, passos, causa provável e log de execução.

- [x] Executar a suíte completa atual em 1920×1080 no monitor virtual e salvar o log em `/tmp/kp-deep-baseline.log`.
- [x] Contar `AT_PASS`, `AT_FAIL`, `AT_SKIP` e `SCRIPT ERROR`; registrar as duas falhas estreitas sem removê-las.
- [x] Reproduzir em probes separados cada falha que não tem asserção comportamental, usando eventos de viewport ou chamadas públicas do jogo.
- [x] Escrever no relatório somente achados reproduzidos, distinguindo regressão de limitação de viewport.

### Task 2: Combate e transições de estado

**Files:**
- Inspect/Modify: `src/arena/arena.gd`, `src/arena/spawner.gd`, `src/player/player.gd`, `src/autoload/game.gd`
- Test: `src/autoload/harness/sections_tasks_a.gd`, `src/autoload/harness/sections_tasks_b.gd`, `src/autoload/harness/sections_scene.gd`

**Interfaces:**
- Consumes: sinais `wave_started`, `wave_cleared`, `died`, `combo_milestone`, `run_ended` e os estados `Game.State`.
- Produces: invariantes de uma run: primeira onda observável, morte idempotente, reinício limpo, uma única recompensa por boss e nenhuma ação após game over.

- [ ] Criar uma reprodução mínima para cada estado suspeito: start da primeira onda, morte dupla, restart durante pausa, terminal fechado e game over.
- [ ] Rodar cada reprodução no virtual e confirmar a falha esperada antes de editar produção.
- [ ] Corrigir somente a origem do estado duplicado ou perdido e manter as transições centralizadas.
- [ ] Rodar os probes e a suíte completa; comparar contagem de sinais, HP, score, estado e cena corrente.

### Task 3: Entrada desktop/touch e ações compartilhadas

**Files:**
- Inspect/Modify: `src/ui/touch_controls.gd`, `src/player/player.gd`, `src/arena/pause_input_router.gd`, `src/ui/menu.gd`, `src/ui/menu_settings_kit.gd`
- Test: `src/autoload/harness/sections_modes.gd`, `src/autoload/harness/sections_scene.gd`, `src/autoload/harness/sections_polish.gd`

**Interfaces:**
- Consumes: eventos reais de teclado, mouse e toque injetados no viewport, `InputMap` e `Game.effective_aim_mode()`.
- Produces: a mesma ação sem duplicação entre teclado, mouse e toque; remapeamento consistente; foco que não escapa de overlays.

- [ ] Cobrir dash, overclock, pause, abandon, restart, terminal, seleção de patch e troca de aba por cada dispositivo aplicável.
- [ ] Verificar primeiro o caminho central no `Player` e só depois adaptadores de toque/teclado.
- [ ] Corrigir uma divergência por vez, começando por um teste vermelho que observe sinais/estado, não texto de implementação.
- [ ] Repetir a matriz em português e inglês, com preferência de aim e teclas remapeadas.

### Task 4: Determinismo e fronteiras do RNG

**Files:**
- Inspect/Modify: `src/arena/spawner.gd`, `src/enemies/*.gd`, `src/pickups/mote_field.gd`, `src/autoload/game.gd`, `src/player/player.gd`
- Test: `src/autoload/harness/sections_systems_b1.gd`, `src/autoload/harness/sections_systems_b2.gd`, novo probe em `src/autoload/harness/sections_scene.gd` se necessário

**Interfaces:**
- Consumes: `Game.rng.state`, seed de run, sequências de spawn, disparos, drops e telemetria.
- Produces: mesma sequência para mesma seed e nenhuma alteração do stream por desenho, UI ou efeitos visuais.

- [ ] Catalogar cada chamada aleatória de gameplay e separar as chamadas visuais sem alterar ainda.
- [ ] Criar uma reprodução de duas runs com a mesma seed que compare ondas, tipos, posições, drops e ofertas.
- [ ] Rodar a reprodução para obter uma falha real, localizar a primeira divergência e rastrear a origem do valor.
- [ ] Migrar somente a chamada responsável, preservar a ordem de consumo e repetir a comparação por múltiplas ondas.

### Task 5: Inimigos, bosses, orbs e pickups

**Files:**
- Inspect/Modify: `src/enemies/enemy_base.gd`, `src/enemies/root_boss.gd`, `src/enemies/firewall.gd`, `src/enemies/recursor.gd`, `src/enemies/oom_killer.gd`, `src/enemies/*.gd`, `src/pickups/mote_field.gd`, `src/pickups/recover_pickup.gd`
- Test: `src/autoload/harness/sections_systems_a.gd`, `src/autoload/harness/sections_systems_b1.gd`, `src/autoload/harness/sections_systems_b2.gd`

**Interfaces:**
- Consumes: `EnemyBase.die()`, `RootBoss.split_started`, `MoteField` slot APIs, grupos de orbs/corrupção e limites de arena.
- Produces: nenhum inimigo continua emitindo dano ou recompensa depois da morte; summons, zonas, orbs, motes roubados e RECOVER são limpos no dono correto.

- [ ] Exercitar cada inimigo novo e cada fase de boss com arena mínima e contagem de nós/grupos antes e depois da morte.
- [ ] Cobrir a fronteira de slots do MoteField: roubo, liberação, fuga, morte do ladrão e troca de índice.
- [ ] Cobrir limite global de 40 orbs e destruição de orbs do FIREWALL sem apagar orbs de outro dono.
- [x] Corrigir apenas invariantes quebradas, incluindo timers que dependem de `delta` e referências que sobrevivem a `queue_free()`.

### Task 6: Patches, score, save e modos

**Files:**
- Inspect/Modify: `src/autoload/game.gd`, `src/ui/menu.gd`, `src/arena/arena.gd`, `src/ui/hud.gd`, `src/ui/run_summary_panel.gd`
- Test: `src/autoload/harness/sections_tasks_a.gd`, `src/autoload/harness/sections_tasks_b.gd`, `src/autoload/harness/sections_visual.gd`, `src/autoload/harness/sections_boot.gd`

**Interfaces:**
- Consumes: `Game.roll_patch_offer()`, `apply_patch()`, `best_for_mode()`, `export_save_string()`, `import_save_string()`, telemetria de cura e estatísticas de run.
- Produces: economia idempotente, gates de modo corretos, recordes isolados por modo, save round-trip sem perda e HUD coerente com o estado real.

- [ ] Comparar todos os patches com seus efeitos efetivos, nível máximo e exclusões de One-HP.
- [ ] Rodar round-trip de save com dados de cada modo, idioma e programa desbloqueado; observar diferenças estruturais.
- [ ] Reproduzir score/best/game-over em Classic, Weekly, One-HP e Story antes de corrigir qualquer campo.
- [ ] Verificar HUD de dash, Overclock, RECOVER, SCRAP e seed contra os valores do Player/Game.

### Task 7: Layout e telas que ainda falham

**Files:**
- Inspect/Modify: `src/ui/menu_shell.gd`, `src/ui/story_panel.gd`, `src/ui/program_panel.gd`, `src/ui/bestiary_panel.gd`, `src/ui/patch_card.gd`
- Test: `src/autoload/harness/sections_scene.gd`, `src/autoload/harness/sections_polish.gd`, `src/autoload/harness/sections_visual.gd`

**Interfaces:**
- Consumes: `layout_snapshot()`, `text_overflow_report()`, retângulos do viewport e foco real.
- Produces: conteúdo contido no viewport suportado, foco alcançável e textos sem corte indevido.

- [ ] Medir as duas falhas em 432×720 e comparar com a largura lógica mínima 1280 documentada.
- [ ] Se houver correção desktop-safe, escrever o teste vermelho e ajustar containers/mínimos; se for caso mobile adiado, manter a falha e registrar a razão.
- [ ] Repetir captura gráfica das telas afetadas e conferir mouse, teclado e estado desabilitado.

### Task 8: Stress e fechamento

**Files:**
- Modify: `docs/superpowers/reports/2026-09-12-deep-bug-audit.md`
- Test: harness completo e probes virtuais em `/tmp/`

**Interfaces:**
- Consumes: todos os testes das tarefas anteriores e logs do monitor virtual.
- Produces: matriz final de bugs corrigidos, pendências reproduzíveis e evidência de encerramento.

- [ ] Executar múltiplas runs virtuais com seeds diferentes, entrando e saindo de overlays durante combate.
- [x] Confirmar ausência de `SCRIPT ERROR`, crescimento de órfãos acima da linha de base e processos virtuais residuais.
- [x] Rodar a suíte completa final e comparar os únicos `AT_FAIL` permitidos com o baseline.
- [x] Atualizar o relatório com causa raiz, correção, teste vermelho/verde, log e risco residual de cada item.

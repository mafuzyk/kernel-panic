# KERNEL PANIC — Auditoria de código e UI (desktop-first)

> Sessão de 2026-09-11, CachyOS. Foco acordado com a autora: **PC primeiro**
> (código, UI e UX de desktop). Celular volta ao foco quando o desktop estabilizar.
> Escopo aprovado: refatoração de arquitetura **e** redesign visual, em fases.

## Como este relatório foi produzido

- Godot 4.7.2 instalado (`extra/godot`, casa com a versão do projeto).
- **Baseline do autotest: 1418 AT_PASS / 0 AT_FAIL / `AUTOTEST_ALL_PASS`.**
  Tudo abaixo foi encontrado com a árvore verde — são achados novos, não regressões.
- Capturas em 1920×1080 numa sessão KWin Wayland isolada, na GPU real
  (`tools/virtual-session/`, ver README daquele diretório). Ficam em
  `media/captures/2026-09-11-audit/`.

---

## 1. Bugs confirmados

Ordenados por gravidade. Todos reproduzidos, não são suposições.

### B1 — Painel de AWARDS é semitransparente e o menu vaza por trás
`src/ui/achievements_panel.gd:66`

O painel de conquistas é o único dos quatro overlays que usa um `ColorRect` com
alpha **0,88** em vez de pintar fundo opaco. Os irmãos todos fazem
`draw_rect(..., alpha 1.0)`:

| painel | fundo |
|---|---|
| `bestiary_panel.gd:183` | `Color(0.01, 0.012, 0.03, **1.0**)` |
| `story_panel.gd:233` | `Color(0.01, 0.012, 0.03, **1.0**)` |
| `program_panel.gd:143` | `Color(0.01, 0.012, 0.03, **1.0**)` |
| `achievements_panel.gd:66` | `ColorRect` alpha **0.88** |

Resultado: o título KERNEL PANIC, o botão `>> PURGE`, `STORY // ACTS` e
`MODE: CLASSIC` aparecem atrás e colidem com as linhas de conquista.
Ver `media/captures/2026-09-11-audit/awards_bug_transparencia.png`.

### B2 — `SEED` duplicado na tela de morte
`src/arena/arena.gd:692` + `src/autoload/game.gd:517`

```gdscript
"SEED          %s" % Game.run_seed_text()   # arena.gd:692
func run_seed_text() -> String:
    return "SEED %d" % run_seed              # game.gd:517  ← já inclui "SEED"
```

Renderiza `SEED          SEED -1999920091431960591`. O mesmo `run_seed_text()`
é reusado em `core_dump_text()` (game.gd:530), onde o prefixo faz sentido —
então a correção é no lado do arena, não na função.

Junto disso: a seed é um int64 cru de 20 dígitos. Como a proposta dela é ser
uma seed compartilhável (modo Weekly, speedrun), formato hexadecimal curto
seria bem mais utilizável. **Decisão de design — não mexo sem seu aval.**

### B3 — Colunas desalinhadas no resumo de run
`src/arena/arena.gd:694-702`

As colunas são padding manual com espaços, e as larguras não batem. Contando
onde cada valor começa:

| linha | coluna do valor |
|---|---|
| `FINAL SCORE` | 17 |
| `BEST` | 17 |
| `CYCLES` | 14 |
| `DAEMONS PURGED` | 15 |
| `ACCURACY` | 14 |
| `UPTIME` | 14 |
| `HEALS` | sem coluna (formato próprio, via `_heals_line`) |

Três colunas diferentes numa tabela de sete linhas. Mesmo padrão aparece em
`story_panel.gd:377`, `menu.gd:602`, `program_panel.gd:187` — 13 ocorrências no
total. Pede uma função de formatação de tabela, não 13 strings ajustadas na mão.

### B4 — `Arena._open_terminal()` não existe mais (regressão de refactor)
`src/autoload/harness/sections_modes.gd:290`

```
SCRIPT ERROR: Invalid call. Nonexistent function '_open_terminal' in base 'Node2D (Arena)'.
AT_FAIL watchdog timeout
```

O método foi movido para `panel_kit.gd:115` e o forwarding nunca foi criado —
mas o par `_close_terminal` **tem** três chamadas em arena.gd. O harness de
captura `KP_SHOT=terminal` está morto desde então e ninguém percebeu porque
esse caminho não roda no autotest. O jogo em si funciona (o botão da pausa
chama o `panel_kit` direto).

### B5 — Layout de desktop quebra acima de 1366px
O autotest cobre 1366×768, 432×720, 720×720, 900×400 e mais alguns — **nada
acima de 1366 de largura**. Em 1920×1080:

- **Settings**: a aba AUDIO tem 3 controles e ~60% do painel é vazio; os
  sliders esticam ~1000px para um valor de 0–100%; o toggle `MUTE ALL` fica a
  ~1200px do próprio rótulo; o botão `BACK` transborda a borda inferior do
  painel de navegação e do frame principal.
- **Menu**: as linhas de klog no topo são cortadas pela borda do frame.
- **HUD**: os painéis (INTEGRITY / SCORE / EVENT LOG) têm tamanho fixo em px e
  ficam minúsculos e perdidos; o valor de SCORE vaza a borda direita do painel.
- **Story**: os cards de estágio ficam com ~60px de largura e a descrição é
  cortada no meio da palavra, enquanto o painel de detalhe ao lado está vazio.
- **Game over / Pause**: painel de tamanho fixo com grande vazio interno.

Não é um bug pontual, é a consequência de B5 ser sistêmico — ver seção 2.

### B6 — Dica de teclado dentro da caixa de perigo (Pause)
A linha `[ESC] RESUME   [R] RESTART   [Q] ARM ABANDON PROCESS` é renderizada
**dentro** do frame vermelho do `ABANDON PROCESS`, sugerindo que as três teclas
pertencem ao abandono. Existem testes que afirmam o contrário
(`pause volume and abandon warning keep a visible gap`) — eles validam a
geometria entre o bloco de volume e o aviso, mas não entre o aviso e a dica.
Teste com asserção incompleta, não teste ausente.

### B7 — Mobile-ismos vazando no build de desktop
`SWIPE TO SCROLL` aparece no bestiário rodando em desktop. Com o foco em PC,
isso precisa virar texto de scroll/roda do mouse condicionado ao input.

### B8 — Bestiário abre com seleção fora de vista (menor)
`src/ui/bestiary_panel.gd:34` — `_selected_id` começa em `"root"`, que fica no
fim da lista. O painel de detalhe mostra ROOT.exe enquanto a lista visível não
tem nenhuma linha destacada. Ou seleciona a primeira entrada, ou rola até a
seleção.

---

## 2. Alvos de refatoração (ranqueados)

O tamanho não é o problema principal — o acoplamento é.

### R1 — Os "kits" não desacoplaram nada (prioridade máxima)
Os arquivos `panel_kit` / `intro_kit` / `stage_kit` / `menu_chrome_kit` /
`menu_settings_kit` dizem no próprio cabeçalho: *"Functions are moved verbatim
(...) state is prefixed with `a.`"*. O resultado:

| arquivo | acessos de volta ao dono |
|---|---|
| `menu_chrome_kit.gd` | 192 |
| `menu_settings_kit.gd` | 179 |
| `intro_kit.gd` | 136 |
| `panel_kit.gd` | 123 |
| `stage_kit.gd` | 58 |
| **total** | **688** |

Isso não são módulos, é o mesmo objeto espalhado por cinco arquivos. `arena.gd`
caiu de tamanho mas ganhou ~20 métodos que só repassam chamada
(`panel_scale_for_height`, `state_panel_rect`, `pause_action_labels`, ...).
E o custo real apareceu: **B4 é exatamente o bug que esse padrão produz.**

Direção: virar Nodes de verdade com estado próprio e comunicação por sinal,
ou funções estáticas puras que recebem o que precisam por parâmetro.

### R2 — Não existe design system; a UI é estilizada à mão
- **83** chamadas `load("res://assets/fonts/...")` espalhadas em 19 arquivos.
- **310** chamadas `add_theme_*_override` — cada widget pintado individualmente.
- **10** referências a `Theme` / `StyleBoxFlat` / `.tres` no projeto inteiro.
- `menu.tscn` e `arena.tscn` são `Control`/`Node2D` vazios com um script: 100%
  da UI é construída em GDScript.

São 5.930 linhas em `src/ui/`. Boa parte é repetição de "cria Label, seta
fonte, seta tamanho, seta cor, seta âncora". Um `Theme` + um punhado de
componentes reutilizáveis (botão tático, painel, slider, linha de tabela)
cortaria isso de forma significativa e é o pré-requisito do redesign.

### R3 — Layout em coordenadas de design fixas
O layout parte de um palco de 1280×720 e escala
(`PANEL_REFERENCE_HEIGHT := 720.0`, `panel_scale_for_height` com clamp
`0.45..1.0`). Por isso tudo acima de 1366 fica pequeno e com vazio: o teto do
clamp é 1.0, então em 1920 o painel não cresce — só sobra tela.

Direção desktop-first: containers do Godot (`MarginContainer`, `VBoxContainer`,
`GridContainer`) com larguras máximas de conteúdo, em vez de offsets absolutos
calculados.

### R4 — Código morto (limpeza barata)
Símbolos declarados e nunca referenciados:

```
sfx.gd            var _music, stop_music(), set_aim_mode(),
                  set_touch_scale(), set_target_fps()
mote_field.gd     steal_nearest(), stolen_positions_of(), stolen_ids()
balance.gd        COL_BG
spawner.gd        force_clear()
game.gd           keybinds_snapshot()
root_boss.gd      var _rebuild_warning_t
story_panel.gd    var first_index
terminal_panel.gd output_text()
bestiary_panel.gd detail_entry_id()
tactical_ui.gd    const BG
```

### R4b — ⚠️ Os knobs de dificuldade documentados estão MORTOS
Achado mais sério da auditoria. Três constantes de `balance.gd` não são lidas
por ninguém — e as funções que deveriam usá-las têm os valores **hardcoded**,
com números **diferentes** dos das constantes:

| constante | valor declarado | valor real usado no código |
|---|---|---|
| `WAVE_SCALE_CAP` (`balance.gd:37`) | `1.65` | `1.7` hardcoded em `wave_scale()` (`balance.gd:71`) |
| `WAVE_BUDGET_BASE` (`balance.gd:33`) | `6` | `8` hardcoded em `wave_budget()` (`balance.gd:99`) |
| `WAVE_BUDGET_GROWTH` (`balance.gd:34`) | `5` | `5` hardcoded (esse casa, por acaso) |

```gdscript
static func wave_scale(wave: int) -> float:
    return minf(1.0 + float(wave - 1) * 0.03, 1.7)   # ← WAVE_SCALE_CAP ignorado

static func wave_budget(wave: int) -> int:
    return 8 + (wave - 1) * 5 + maxi(0, wave - 4) * 2  # ← BASE/GROWTH ignorados
```

Por que isso importa: **quatro** documentos de planejamento tratam
`WAVE_SCALE_CAP` como knob vivo e proíbem mexer nele
(`plans/2026-08-27-identity-pack.md:17`, `plans/2026-08-27-fixes-pack.md:16`,
`plans/2026-08-29-fixes-difficulty-art.md:19`,
`specs/2026-08-27-review-findings.md:99`), e o handoff v2.3 chega a propor
`WAVE_SCALE_CAP 1.65 → 1.55` como ajuste pós-playtest.

**Esse ajuste não faria absolutamente nada.** A curva de dificuldade real do
jogo está 3% mais agressiva no teto (1.7 em vez de 1.65) e começa com budget
33% maior (8 em vez de 6) do que a documentação descreve. Qualquer playtest de
balanceamento feito com base nesses docs mediu outra coisa.

Correção: fazer as funções lerem as constantes. Mas isso **muda a dificuldade
do jogo** — é mudança de gameplay, não limpeza. Precisa do seu aval sobre qual
valor é o certo: o documentado (1.65 / 6) ou o que está rodando (1.7 / 8).

### R5 — Vazamentos no teardown
O autotest sai com 198 instâncias ObjectDB, 29 RIDs de `Area2D` e 147 de
texto vazados. O leak guard só checa nós órfãos (36 de um teto de 40), então
não pega isso. Não afeta gameplay hoje, mas o teto de 40 está perto demais.

---

---

## 2b. Segunda passada — revisão crítica (mandato ampliado)

> A autora liberou mudar quase tudo, desde que o **estilo de gameplay** não mude.
> Esta seção é mais dura que a primeira e questiona decisões, não só defeitos.

### B9 — ⚠️ O teto de motes na tela não existe mais (bug de gameplay vivo)
`src/arena/arena.gd:808`

```gdscript
var motes := get_tree().get_nodes_in_group("motes").size()   # SEMPRE 0
n = mini(n, maxi(0, 90 - motes))                             # vira mini(n, 90)
```

O grupo `"motes"` só era populado pela classe `Mote`, que a reescrita MultiMesh
(MoteField) aposentou. Nada entra nesse grupo hoje, então `motes` é sempre `0`
e o teto de **90 motes simultâneos vira letra morta** — o que limita de fato é
o `MoteField.MAX := 128` (`mote_field.gd:6`).

Ou seja: o teto de motes na tela subiu de 90 para 128 (**+42%**) sem ninguém
decidir isso. E subiu justamente na mudança que existia para *reduzir* custo de
performance no celular. Correção é uma linha (`mote_field.count()`), mas é
mudança de densidade — **quero seu ok sobre qual teto é o certo.**

### B10 — `Mote` é código morto, e o teste que deveria pegar isso passa em vácuo
`src/pickups/mote.gd` declara `class_name Mote`, entra no grupo `"motes"` e
tem `_physics_process` com `queue_redraw` — e **não é instanciada em lugar
nenhum**. O handoff v2.3 já mandava deletar ("Old Mote class may be deleted
once harness and call sites are green"); ficou.

Pior é o teste em `sections_systems_b1.gd:247-252`: ele itera o grupo `"motes"`,
mata cada um, e depois afirma que o grupo está vazio. Um grupo que **nunca tem
membros**. A asserção passa desde sempre sem verificar nada.

### B11 — ⚠️ O jogo é inutilizável sem mouse (e isso é por design)
Todo botão do projeto seta `focus_mode = Control.FOCUS_NONE`
(`menu_chrome_kit.gd:21,103,187,205,396`, `menu_settings_kit.gd:445,474`,
`debug_panel.gd:119`). Consequências no desktop:

- Não dá para navegar com Tab nem com setas.
- Não existe indicador de foco em lugar nenhum.
- Pelo teclado só há **dois** caminhos no menu inteiro: `Enter` inicia o run e
  `Esc` fecha o jogo (`menu.gd:729-740`). SETTINGS, BESTIARY, STORY, AWARDS e os
  cyclers MODE/PROGRAM/DIFFICULTY são **inalcançáveis sem mouse**.

Foi uma decisão razoável na era mobile (anel de foco fica estranho no toque).
Com foco em PC ela se inverte: é regressão de usabilidade e barreira de
acessibilidade. Navegação por teclado é item básico num jogo de desktop.

### B12 — Não existem opções de vídeo
`menu_settings_kit.gd` tem cinco abas (AUDIO, GAMEPLAY, CONTROLS, ACCESSIBILITY,
SAVE DATA) e **nenhuma** opção de tela cheia, resolução, vsync ou janela sem
borda. Hoje só dá para ir a tela cheia pelo gerenciador de janelas. Num jogo de
PC isso é esperado por padrão.

### R6 — ⚠️ 55 "testes" são `grep` no texto-fonte — e sabotam a refatoração
Este é o achado que mais compromete o trabalho que você quer fazer.

Os arquivos carregam o **código-fonte de produção como string**
(`load("res://src/ui/hud.gd").source_code`) e afirmam que certos trechos
literais existem:

```gdscript
h._check(hud_src.contains("_banner_sub_l.offset_top = 186"),
         "compact wave banner repositions below the encounter panel")
h._check(game_src.contains("TacticalIcon.clear_raster_cache()"),
         "teardown clears the tactical icon raster cache")
h._check(panel_src.contains("ScrollContainer"),
         "achievements panel scrolls instead of blocking mobile input")
```

O primeiro não verifica que o banner está posicionado certo — verifica que a
string `_banner_sub_l.offset_top = 186` existe no arquivo. Isso significa:

- Trocar `186` por uma constante nomeada **quebra o teste** sem quebrar nada.
- O banner pode estar visivelmente errado e o teste **passa**.
- Migrar o HUD para containers (Fase 3) quebra vários desses de uma vez, e
  nenhuma dessas quebras indica regressão real.

São 55 asserções assim, em 7 arquivos de produção lidos como texto. Elas
travam o código na forma literal atual — exatamente o que uma refatoração
precisa mudar. **Precisam ser reescritas como testes de comportamento ou
removidas antes das Fases 2-4**, senão cada refactor vai gerar falhas falsas.

Isso também responde por que 1418 asserções verdes não pegaram B1, B4, B5, B9
nem B10: boa parte da suíte confirma que o código *está escrito de um jeito*,
não que ele *faz a coisa certa*.

### R7 — A suíte é organizada por lote de escrita, não por assunto
Os arquivos se chamam `sections_tasks_a`, `sections_tasks_b`,
`sections_systems_a`, `sections_systems_b1`, `sections_systems_b2` — nomeados
por *quando foram escritos*, não pelo que testam. E são funções gigantes:

| função | linhas |
|---|---|
| `sections_systems_b1.gd:_systems_test_b1()` | **435** |
| `sections_systems_a.gd:_systems_test_a()` | **434** |
| `dev_harness.gd:_autotest()` | **397** |
| `sections_tasks_b.gd:_task9_test()` | **225** |

Uma função de teste de 435 linhas não é um teste, é um script. Quando falha,
não dá para saber o que quebrou sem ler tudo. `_task9_test` não diz nada sobre
o que cobre.

### R8 — `game.gd` é um autoload-deus
837 linhas, **67 funções**, 29 variáveis, 9 sinais, 15 constantes, cuidando de:
estado de run, score/combo, patches, progressão de Story, bestiário,
conquistas, save/load, RNG, keybinds, dificuldade, programas jogáveis, event
log, telemetria de cura e export/import de save. São ~8 responsabilidades
distintas num singleton global que praticamente todo arquivo importa.

Também faz `ConfigFile.load()` + `save()` a cada conquista destravada
(`game.gd:505-510`) — 12 pontos de escrita em disco só nesse arquivo.

### R9 — 299 strings de UI hardcoded, zero `tr()` — e o risco de trabalho dobrado
`grep` encontra **299 strings de UI únicas** espalhadas pelo código e **nenhum**
uso de `tr()`, `TranslationServer` ou arquivo de tradução.

O roadmap coloca i18n (PT-BR + EN) em v2.7 e estima "~8 arquivos". É bem mais
que isso. E tem um problema de ordem: **reconstruir a UI (Fases 2-3) sem
extrair as strings significa varrer toda a UI duas vezes.** Se PT-BR é um
objetivo real — e sendo você e seu namorado brasileiros, parece ser — a
extração deveria acontecer *junto* com a reconstrução, não dois anos depois.

### R10 — `_build_settings()` tem 375 linhas
`menu_settings_kit.gd:_build_settings()` é a maior função de produção do
projeto. Constrói cinco abas inteiras numa tirada só. `menu.gd:_ready()` tem
153. `terminal_panel.gd:_build()` tem 164.

### Q1 — Pergunta aberta: o "desenhado em código" ainda se paga?
O README trata como identidade o fato de quase tudo ser desenhado em GDScript
em vez de sprites. Isso nasceu de uma restrição real — não havia editor no
celular. Hoje o custo é visível: **37 arquivos com `_draw()`** e **17 nós
chamando `queue_redraw()` a cada frame** (todo inimigo, todo pickup, o HUD, o
menu, cada painel). O menu inteiro se repinta 60x por segundo para mostrar uma
tela quase estática.

A migração para sprites já começou (`assets/sprites/generated/`, `EntitySprite`).
Vale decidir explicitamente até onde ela vai, em vez de manter os dois sistemas
em paralelo indefinidamente. **Não é uma recomendação — é uma decisão sua**, e
mexe na identidade visual que o projeto vende.

---

## 3. Plano proposto (fases)

Cada fase termina com autotest verde e capturas de aceitação em 1920×1080.

**Fase 0 — Ferramenta e rede de proteção** (parcialmente feito)
- [x] Godot 4.7.2 + sessão virtual isolada + captura automatizada
- [ ] **Sanear a suíte (R6)** — reescrever as 55 asserções de texto-fonte como
      testes de comportamento, ou removê-las. *Bloqueia as Fases 2-4:* sem isso,
      toda refatoração gera falha falsa e a suíte deixa de ser sinal.
- [ ] Ampliar a matriz de resoluções: somar 1920×1080 e 2560×1440
- [ ] Corrigir B4 para destravar `KP_SHOT=terminal`

**Fase 1 — Bugs de baixo risco** (B1, B2, B3, B6, B7, B8, B10)
Correções pontuais com teste de regressão antes de cada uma. Sem tocar em
arquitetura. Entrega visível rápida.

**Fase 1b — Bugs que mudam comportamento** (B9, R4b) — *precisa da sua decisão*
Teto de motes e knobs de dificuldade. Tecnicamente triviais, mas alteram o
balanceamento. Não faço sem você escolher os valores.

**Fase 2 — Fundação do design system** (R2) **+ extração de strings (R9)**
`Theme` + tokens de cor/tipografia + componentes reutilizáveis, **e** as 299
strings saindo para arquivo de tradução na mesma passada. Sem mudar aparência:
as capturas devem ficar **idênticas** antes e depois. Fazer i18n junto evita
varrer toda a UI duas vezes.

**Fase 3 — Layout responsivo e UX de desktop** (R3, B5, B11, B12)
Migrar painel por painel para containers com largura máxima de conteúdo; somar
navegação por teclado com indicador de foco (B11) e a aba de vídeo (B12).
Aqui as telas finalmente usam 1920×1080 direito.

**Fase 4 — Desacoplar os kits** (R1) **e quebrar `game.gd`** (R8)
Com a UI já sobre componentes, os kits perdem a razão de existir. `game.gd` se
divide por responsabilidade (run/progressão/save/input). Um arquivo por vez.

**Fase 5 — Redesign visual**
Só depois da fundação. Aqui entram as decisões de arte de verdade, incluindo
Q1 (até onde vai a migração para sprites).

Limpeza (R4), vazamentos (R5) e reorganização da suíte (R7) entram como
oportunidade dentro das fases.

---

## 4. Decisões que preciso de você

### Mudam o balanceamento — não toco sem resposta

1. **Knobs de dificuldade mortos** (R4b). A curva real (teto 1.7, budget base 8)
   difere da documentada (1.65 / 6). Qual vale?
   - (a) o que roda hoje é o certo → atualizo constantes e documentação
   - (b) o documentado é o certo → ligo as constantes, o jogo fica mais fácil
   - (c) deixa como está, só marco o problema no código
2. **Teto de motes** (B9). Voltou a 128 sem ninguém decidir. Volto para 90
   (a intenção original) ou oficializo 128?

### Direção

3. **Ordem**. Minha recomendação mudou depois da segunda passada: **Fase 0
   primeiro**, sanear a suíte (R6). É chato e invisível, mas enquanto 55 testes
   travarem o código na forma literal atual, toda refatoração vai gerar falha
   falsa e você não vai conseguir distinguir regressão de ruído. Se preferir
   resultado visível antes, a Fase 1 é segura e independente.
4. **i18n junto da Fase 2?** (R9) PT-BR + EN é objetivo real de médio prazo?
   Se for, extrair as 299 strings durante a reconstrução da UI custa pouco a
   mais; depois custa uma varredura inteira de novo.
5. **Até onde vai a migração para sprites?** (Q1) Isso mexe na identidade
   "desenhado em código" que o README vende. Decisão sua, não minha.

---

## 5. O que já mudou nesta sessão

Nada em `src/`. Só ferramenta nova, não comitada ainda:

- `tools/virtual-session/` — sessão KWin isolada + captura (com README)
- `media/captures/2026-09-11-audit/` — as 11 capturas desta auditoria

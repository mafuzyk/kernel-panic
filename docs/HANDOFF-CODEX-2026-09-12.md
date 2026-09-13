# KERNEL PANIC — handoff

2026-09-12 · branch `feat/design-system-and-glyphs` · autotest **1394 pass / 2 fail**

Escrito para quem assume o trabalho. Leia a seção "armadilhas" antes de rodar
qualquer coisa — a primeira delas me custou horas.

---

## 0. Armadilhas do ambiente (leia primeiro)

### O autotest precisa do separador `--`

```bash
godot --headless --path . -- --autotest      # certo — roda em ~45s
godot --headless --autotest                  # ERRADO — silenciosamente não faz nada
```

`DevHarness` lê `OS.get_cmdline_user_args()`, que só devolve o que vem **depois
de `--`**. Sem o separador o jogo abre o menu e fica parado para sempre: nenhuma
saída, exit 0, CPU em 2%. Parece "suíte lenta". Não é.

Para ver a saída ao vivo, use um pty — o stdout do Godot é bufferizado quando
redirecionado para arquivo, e `stdbuf` não resolve:

```bash
script -qefc "godot --headless --path . -- --autotest" /tmp/at.log
grep -a "AT_FAIL" /tmp/at.log
```

### Sessão virtual (regras de segurança da autora — não negociáveis)

Capturas rodam numa sessão KWin Wayland **separada** da sessão Plasma física:

```bash
tools/virtual-session/kp-virtual.sh capture menu /tmp/x.png KP_PROGRAM=1 KP_CLEAN_SAVE=1
tools/virtual-session/kp-virtual.sh capture game /tmp/y.png KP_WAVE=7
```

Modos: `menu` (+ `KP_PROGRAM` / `KP_STORY` / `KP_BESTIARY` / `KP_SETTINGS` /
`KP_AWARDS`), `game`, `boss`, `mk2`, `god`, `patch`, `over`, `pause`, `terminal`.
`KP_W` / `KP_H` mudam o tamanho da janela.

**Nunca** use `pkill kwin_wayland` / `killall kwin_wayland` — mata o Plasma real
da autora. Só `systemctl --user stop kernel-panic-virtual.service`. Nunca
`ydotool` global; automação só com `DISPLAY=:1 xdotool ...`, nunca `:0`.

### GDScript / Godot 4.7.2

- `breakpoint` é palavra reservada — daí `Design.breakpoint_for()`.
- `Dictionary.get()` devolve Variant; o projeto trata inferência a partir de
  Variant como erro. Sempre anote o tipo.
- `variation_opentype` precisa de tag numérica (`TextServerManager...name_to_tag("weight")`);
  a string `"wght"` é ignorada em silêncio e você recebe o peso Regular.
- `godot --headless --check-only --script <arquivo>` acha erro de sintaxe, mas
  **não tem autoloads** — `Identifier not found: Game` ali é esperado, não é erro.
- Um `class_name` novo só resolve depois de `godot --headless --import`.
- Mudou `assets/i18n/strings.csv`? Rode `godot --headless --import`, senão
  `tr()` devolve a própria chave e a tela mostra `PROGRAM_TITLE` cru.
- **`Button` não dispõe filhos `Control`.** Para um alvo de clique por cima de
  um layout, a raiz tem que ser `PanelContainer` (que estica todos os filhos ao
  mesmo retângulo) e o `Button` entra como último filho. Um `Button` dentro de
  `VBoxContainer` vira **mais uma linha** e injeta ~31px de vazio — foi assim
  que as abas de ato ganharam 90px de buraco.
- `set_anchors_preset` deixa os offsets como estavam; sob `CanvasLayer` isso dá
  tamanho zero. Use `set_anchors_and_offsets_preset`.
- `set_value_no_signal` não dispara `value_changed` — readouts precisam ser
  atualizados à mão.
- Filtre contenção por `is_visible_in_tree()`, não `visible`: filho de container
  escondido continua com `visible == true`.

---

## 1. Estado atual: 2 falhas abertas

```
AT_FAIL story selector content stays inside the screen at 720x720
AT_FAIL story keeps its representative text inside the panel at 1366x768, 720x720, and 432x720
```

Eu já instrumentei as duas asserções para imprimirem o retângulo/entrada
ofensora (`AT_DEBUG story_overflow` em `sections_visual.gd`, `AT_DEBUG overflow`
em `sections_scene.gd`). **Rode e leia o AT_DEBUG antes de mexer** — eu estava
deduzindo em vez de medir, e errei duas vezes.

Suspeitas, em ordem:
1. `_tabs_row` ou `_footer` de `story_panel.gd` estourando a coluna a 720 de
   largura (a coluna útil tem 592px: `size.x - Design.SPACE_4XL * 2`).
2. `text_overflow_report()` de `story_panel.gd` — a entrada `story_row` mede
   `marker + caminho + estado <= inner`. Acabei de corrigir a aritmética (o
   padding estava sendo contado duas vezes) e de tornar a fonte do caminho
   adaptativa (`_path_font_size()`), mas ainda falha em algum degrau.
   O caminho mais longo é `TempleOS::BOOT`.

Remova os dois `AT_DEBUG` quando terminar.

---

## 2. O que já foi feito

### Design system (`src/ui/design/`) — pronto

- **`design.gd`** (`class_name Design`) — fonte única. Escala de tipo de 7
  degraus (`TEXT_MICRO 11` … `TEXT_DISPLAY 76`), espaçamento base-4
  (`SPACE_XS 4` … `SPACE_4XL 64`), 5 níveis de texto, cores semânticas,
  breakpoints, `grotesk(weight)` com cache.
  **Regra do projeto: nenhum arquivo de UI deve ter número mágico de tamanho,
  cor, espaçamento ou duração. Faltou token? Adicione aqui.**
- **`tactical_style_box.gd`** — a moldura de canto cortado como `StyleBox` real,
  para botões ganharem hover/pressed/focus/disabled.
- **`ui_theme.gd`** — `UiTheme.shared()`, variações de Label/Button/Panel.
- **`screen_kit.gd`** — construtores estáticos compartilhados: `grot()`,
  `mono()`, `gap()`, `grow_h/v()`, `rule()`, `page()`, `masthead()`,
  `stat_row()`, `action()`, `glyph()` / `set_glyph_tint()`.
- `showcase.gd`, `glyph_proof.gd`, `mockup_swiss.gd` — style guide vivo, folha
  de prova de silhuetas (imprime cobertura de tinta e IoU par a par), estudo de
  direção.

### Telas reconstruídas

| tela | arquivo | estado |
|---|---|---|
| menu principal | `src/ui/menu_shell.gd` | pronto |
| pausa | `src/ui/pause_panel.gd` | pronto |
| fim de run / vitória | `src/ui/run_summary_panel.gd` | pronto |
| conquistas | `src/ui/achievements_panel.gd` | **meio-porte** — usa tokens mas manteve moldura por linha e cabeçalho centralizado de 13px; ainda lê como a linguagem antiga |
| SELECT PROGRAM | `src/ui/program_panel.gd` | pronto (2 falhas acima são da irmã) |
| SELECT MOUNT POINT | `src/ui/story_panel.gd` | pronto, 2 falhas abertas |
| bestiário | `src/ui/bestiary_panel.gd` | **não portado** |
| patch card | `src/ui/patch_card.gd` | **não portado** |
| HUD | `src/ui/hud.gd` (711 linhas) | **não portado** — ver §4 |

### Silhuetas

19 dos 20 glyphs redesenhados pelo princípio do contorno. `GlyphLib.draw_glyph`
é sempre código; `draw_portrait` existe mas os rasters estão defasados
(`const USE_RASTER_PORTRAITS := false` — não ligue isso).

### i18n

`assets/i18n/strings.csv` → ~137 chaves, `en` + `pt_BR`. Padrão de queda:

```gdscript
var translated := tr(key)
return fallback_em_ingles if translated == key else translated
```

Chave ausente volta como a própria chave — é esse o sinal. Assim conteúdo novo
aparece na tela antes de entrar no CSV.

**Convenção:** título de tela em CAIXA ALTA (`PAUSADO`), ação em caixa de frase
(`Reiniciar`), rótulo de campo em CAIXA ALTA mono. `klog` fica em inglês de
propósito — é saída de máquina.

---

## 3. Três mentiras da UI corrigidas no caminho

Não eram regressões; a UI antiga desenhava e não fazia.

1. `>> BOOT KERNEL [ENTER]` não estava ligado em nada. Agora dá boot.
2. `MOUNT /boot [ENTER]` também não — e `stage_selected` ia direto em
   `_start_story`, então **clicar num card já iniciava a fase**, tornando o
   painel de detalhe (metade da tela) impossível de ler. Agora são dois passos:
   `stage_selected` destaca, `stage_mounted` entra.
3. `ARENA PREVIEW` era uma grade estática idêntica para as onze fases.
   Substituída pelas silhuetas reais das ameaças da fase.

---

## 4. O que falta, em ordem

### 4.1 Fechar as 2 falhas (§1)

### 4.2 Portar `patch_card.gd` e `bestiary_panel.gd`

Mesmas regras das duas já feitas (§5). O bestiário tem
`BestiaryPanel.entry_color(id)` **estática** — use ela, é a fonte única de cor
de entidade, e `story_panel.gd` já depende dela.

### 4.3 HUD e arena — levantado pela autora, com briefing próprio

A direção editorial **não** se aplica ao HUD como aos menus: HUD é leitura
periférica e tipografia grande de revista atrapalha. Mas estes quatro problemas
são independentes da direção:

- **Bug real, causa localizada:** dois avisos se sobrepõem ilegíveis no centro
  da tela. `src/arena/arena.gd:906` chama
  `Fx.text(player.global_position + Vector2(0, -46), ...)` e `Fx.text`
  (`src/autoload/fx.gd:117`) só adiciona `randf_range(-8, 8)` de jitter. Quando
  uma onda introduz dois tipos novos ao mesmo tempo — o normal — as duas strings
  caem quase no mesmo pixel. Precisa de fila/empilhamento, não de mais jitter.
- Moldura de canto cortado em volta de **cada** módulo (INTEGRITY, CYCLE, SCORE,
  EVENT LOG, DASH READY, PATCH STACK), num âmbar que não existe em papel nenhum
  do design system.
- Grade dupla sobreposta (âmbar + ciano) na arena.
- Blocos vermelhos translúcidos que dominam o campo e competem com as entidades.

Capture `KP_SHOT=game KP_WAVE=7` para ver tudo isso de uma vez.

### 4.4 Dívida medida

- **`menu_chrome_kit.gd`** — 479 linhas construídas e **escondidas**. A lógica de
  refresh referencia os widgets, por isso ainda não morreu.
- **18 asserções de texto-fonte** restantes (eram 55; 24 antes desta rodada).
  Converter para comportamento conforme atrapalham. O padrão: pergunte "o que
  esta asserção quer garantir?" e afirme **isso**. Exemplo real — três
  asserções procuravam `_draw_node_brackets` / `_draw_state_glyph` / `sin(t` no
  texto do arquivo; passavam mesmo se as funções nunca fossem chamadas. Viraram:
  os três estados têm rótulos distintos, tintas distintas, e o pulso não avança
  `Game.rng`.
- **~90 strings** ainda literais.
- **`arena.gd` + os "kits"** — acoplamento original intocado (os kits guardam
  referência ao dono e leem o estado dele por `a.`, 688 vezes na auditoria). Só
  game over e pausa saíram de lá.
- **B11** navegação por teclado: as telas novas têm foco, mas restam 8
  `FOCUS_NONE` na UI antiga — ainda não dá para jogar sem mouse.
- **B12** opções de vídeo (fullscreen / vsync / resolução) — não existem.
- **Adwaita Sans 880KB** — precisa de subsetting antes de release mobile.
- `rootlet` lê como arco/letra "A"; `root` e `boss` compartilham glyph. Decisão
  de arte em aberto.

---

## 5. A direção visual, em regras

(Resumo operacional; o estudo está em `src/ui/design/mockup_swiss.gd` e o guia
vivo em `showcase.gd`.)

Suíça/editorial dentro de dark neon. Cinco regras que decidem quase tudo:

1. **Hierarquia por tamanho, não por moldura.** Título em grotesca preta
   (30–76px) lidera; mono fica com a voz de terminal (rótulo, estado, log).
   A linguagem antiga punha tudo em 9–21px, e sem hierarquia o olho não sabe
   onde entrar.
2. **Separe com régua e ar, não com caixa.** A UI antiga encaixotava cada
   elemento; o bestiário chegou a ter três molduras aninhadas.
3. **A cor de identidade é MARCADOR, não tinta.** O ciano do KERNEL aqui é o
   ciano do KERNEL na arena — apagar quebra o reconhecimento, que é a função da
   tela. Mas ela fica restrita ao glyph, ao sobrolho e a uma régua de 1px. Texto
   em tinta neutra. Cada tela expõe `card_ink(id)` com os papéis separados, e o
   autotest afirma que `title != identity` e `marker == identity`.
4. **Um estado de seleção só.** Superfície elevada (`SURFACE_RAISED`) + barra
   sólida de 3px na borda esquerda. Nada de moldura por cima de moldura.
5. **Container, nunca offset absoluto.** Nenhum arquivo de UI novo deve saber o
   tamanho da tela.

Complementos: o wordmark KERNEL/PANIC aparece no **menu** e nas **interrupções
de jogo** (pausa, fim de run) — não em subtela alcançada a partir do menu, onde
é repetição que custa ~79px de altura. Valores de tabela não repetem o
substantivo do rótulo (`100% MOVE` → `100%`, porque a linha já diz VELOCIDADE).

---

## 6. A descoberta sobre o viewport (importa para o celular)

`project.godot` usa `stretch/mode="canvas_items"` + `stretch/aspect="expand"`
com base 1280x720. A escala é `min(w/1280, h/720)` e o viewport lógico é a
janela dividida por ela. Medido com capturas reais:

| janela física | viewport lógico | breakpoint |
|---|---|---|
| 1920x1080 | 1280x720 | `wide` |
| 720x720 | 1280x**1280** | `wide` |
| 405x720 (retrato) | 1280x**2276** | `wide` |
| 2560x1080 | ~1706x720 | `ultra` |

**A largura lógica nunca cai abaixo de 1280 — só a altura varia.** Consequências:

- `compact` e `medium` de `Design.breakpoint_for()` são **inalcançáveis** no
  build atual. Todo o código de layout estreito só roda nas asserções do
  harness, que setam `panel.size` à mão.
- No celular em retrato o jogo monta um palco de 1280x2276 e desenha texto de
  11px em 405px físicos: vira ~3px. **Ilegível.** Não é bug de breakpoint — é
  configuração de projeto. O caminho é mudar a base (`viewport_width` menor, ou
  `aspect="keep_height"` com base retrato) quando a fase de celular começar.

Mantenha o código estreito: ele não custa nada hoje e transforma a virada de
celular numa mudança de configuração em vez de um segundo porte.

**Correção registrada:** a auditoria original dizia "tudo quebra acima de
1366px" (falso — o problema era proporção dentro do palco) e depois eu escrevi
"o jogo sempre renderiza 1280x720 lógico" (verdade só em 16:9). O enunciado
correto é o da tabela acima.

---

## 7. Regras de trabalho da autora

- **TDD é regra dura do projeto**: teste que falha primeiro, para toda mudança
  de comportamento. Nunca declare sucesso sem rodar a suíte inteira.
- **Desktop primeiro.** Celular volta depois que o desktop estiver estável.
- **Não mude o estilo de gameplay.** Fora isso, quase tudo pode mudar.
- "Simples é diferente de feio" — sobre as silhuetas. Simplicidade não é
  desculpa para forma preguiçosa.
- Ela escreve em português; responda em português.

---

## 8. Commits

Nada foi enviado; nenhum PR aberto. 17 commits na branch, o último é
`68f0091`. Todo o trabalho descrito acima está **não commitado** na árvore —
commite depois de fechar as 2 falhas.

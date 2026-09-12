# KERNEL PANIC — briefing: entrada, foco e transparência do HUD

Sucede o `HANDOFF-CODEX-2026-09-12.md`, que continua válido para ambiente e
histórico. Este documento trata do trabalho **aberto**, levantado pela autora
em 2026-09-12:

> "acho que esse hud tem que melhorar e deixar mais transparente, não dá pra
> saber o que o mouse tá selecionando na ui, no caso dá pra saber, mas só nas
> settings, tem coisa que não funciona input de mouse, outras que não funcionam
> input de teclado, então é bom dá uma aprofundada geral em tudo"

Estado na abertura: `944d52b`, suíte em **1569 passes / 0 falhas**.

---

## PARTE 1 — Como se decide coisa neste projeto

Esta parte não é burocracia. É o que separa uma mudança que entra de uma que
tem de ser revertida. Leia antes de escrever linha.

### 1.1 Medir antes de opinar. Sempre.

A regra central do projeto. Quando aparecer uma pergunta de qualidade — "esse
ícone está confuso?", "esse hover dá pra ver?", "esse fundo está claro demais?"
— a resposta **não** é escolher o que parece bom. É construir uma medição,
rodar, e deixar o número decidir.

Exemplos reais que já viraram código aqui:

- Legibilidade da arena virou uma asserção numérica: o fundo nunca fica mais
  claro que a entidade mais escura, verificado contra
  `Balance.dimmest_entity_luminance()`.
- Distinção de silhueta virou máscara binária + interseção-sobre-união.
- "O hover dá pra ver?" virou o número que abre a Parte 3: **1.18:1**.

### 1.2 Um número que você não mediu não entra no código

Se você for escrever um limiar, um alpha, um raio, um tamanho — meça. Não
chute e depois ajuste no olho até parecer bom, porque isso produz um número que
ninguém consegue defender depois e que ninguém sabe quando revisar.

Aconteceu comigo nesta sessão, duas vezes, e as duas viraram correção:

- Escrevi uma asserção `prev > 0.5` num teste de dilatação porque *parecia* uma
  boa magnitude. Medi: o valor real era **0.250**. Troquei o chute pelo medido.
- Estimei que uma faixa do HUD tinha ~600px a partir de um print com zoom de
  220%. Medida real: **330px**.

### 1.3 Um limiar só vale com um ponto de verdade

Não adianta ter métrica. Precisa existir um caso em que você **sabe** a
resposta, para calibrar contra ele.

A calibração que acabou de fechar (commit `944d52b`) é o modelo a seguir:
`root` e `boss` desenham o *mesmo* glifo. Então uma métrica útil tem de dar
1.0 neles e claramente menos em todo o resto. O que se maximiza é a **margem**
entre o par idêntico e o segundo colocado. Varri doze combinações:

```
box=96 raio=0 -> idêntico 1.000, 2º 0.336, margem 0.664  <- escolhido
box=48 raio=3 -> idêntico 1.000, 2º 0.892, margem 0.108  <- config anterior
```

E o resultado **inverteu** a direção em que eu estava indo: a dilatação que eu
tinha adicionado não dava sensibilidade, dava borrão.

### 1.4 Quando a medição não fecha, diga isso — não invente um número

Este é o ponto onde mais se erra por excesso de iniciativa, então é o mais
importante daqui.

Na mesma sessão varri os ícones de patch com ponto de verdade próprio (o mesmo
ícone deslocado 1px). Resultado: no melhor caso o *mesmo* ícone marca 0.760 e
duas famílias **diferentes** marcam 0.560. As faixas quase se encostam.

A saída certa foi **declarar que não existe limiar utilizável** e deixar o
número como comparador de versões, com o porquê escrito no código. A saída
errada, tentadora, seria cravar 0.65 no meio e seguir — um número que
reprovaria desenhos bons ou aprovaria colisões reais dependendo do pixel.

**Entregar "não dá para decidir com o que eu tenho" é entregar. Fabricar um
limiar para poder dizer que fechou, não.**

### 1.5 TDD é regra dura do projeto

Toda mudança de comportamento começa por um teste que **falha**. Sem exceção.
Rodar: `godot --headless --path . -- --autotest` (o `--` é obrigatório, veja 4.1).

### 1.6 Teste comportamento, nunca a grafia do código

O projeto tinha 55 asserções que liam o fonte com `.contains("...")` e
verificavam se um trecho estava escrito de certo jeito. Hoje são **3**. Não
crie novas.

O motivo: uma asserção dessas passa a testar a *ortografia* do código em vez do
que ele faz. Uma delas procurava a **ausência** da string `"m.size.y * 0.44"` —
ou seja, renomear uma variável quebrava o teste, e mudar o comportamento
mantendo o texto não quebrava. É o pior dos dois mundos.

Se algo é difícil de testar sem ler o fonte, o caminho é **expor uma função
pura** e testar ela. Foi assim que `overclock_label(shield, ready, active,
touch) -> String` nasceu.

### 1.7 Não mude o estilo de jogo

Quase tudo pode mudar. O estilo de jogo, não. Arte, UI, layout, arquitetura de
UI: à vontade, com medição. Regras de gameplay: só se a autora pedir.

### 1.8 As duas vozes (para qualquer texto novo)

- Voz da **máquina** (log de evento, terminal, `PURGED // DRONE`): fica em
  **inglês**. É saída de kernel, é diegética. Traduzir seria traduzir um `dmesg`.
- Voz do **jogo falando com o jogador** (menu, settings, dica, descrição de
  patch): **traduzida**, via `tr()` com chave no `assets/i18n/strings.csv`.
- Substantivos próprios do mundo (KERNEL, DAEMON, ROOTLET, OVERCLOCK, DASH,
  MOTE): **intactos** nas duas. São nomes.

Depois de editar o CSV, **sempre** `godot --headless --import`. Sem isso o
`.translation` fica velho, os testes quebram e a tela mostra a chave crua.

### 1.9 "Simples é diferente de feio"

Palavras da autora, sobre silhuetas. Simplificar uma forma é tirar o que não
carrega informação. Não é entregar o rascunho.

### 1.10 Desktop primeiro

Celular é uma passada própria, já combinada e **adiada de propósito**. Não
misture trabalho de mobile aqui (o porquê está em 4.2).

---

## PARTE 2 — O que já está pronto

Não refaça nada disto.

- **Design system** em `src/ui/design/` (`Design`, `UiTheme`, `ScreenKit`,
  `TacticalStyleBox`). É a fonte única de token visual.
- **Telas portadas** para o sistema: mount point, select program, achievements,
  patch cards, bestiário, terminal, story intro, run summary.
- **HUD e arena**: fundo com corrupção que escurece em vez de brilhar; avisos
  flutuantes que não se sobrepõem mais (`Fx` empilha com retângulos medidos);
  marcas de canto que cortavam texto, removidas.
- **i18n**: 337 chaves, regra das duas vozes aplicada.
- **Opções de vídeo**: modo de janela e vsync, persistidos e verificados até o
  `DisplayServer`.
- **`menu_chrome_kit.gd`**: 479 -> 181 linhas. Havia uma fileira de botões
  construída inteira e escondida na linha seguinte.
- **Silhuetas**: métrica calibrada e com limiar validado (`SILHOUETTE_MAX = 0.55`
  sobre máscara **crua**, box 96). Ícone de patch fica sem limiar, de propósito.

---

## PARTE 3 — O trabalho aberto

### 3.1 O diagnóstico, medido

A autora relatou três sintomas. Eles têm **uma causa comum**, e ela não é a
que parece.

**Minha primeira hipótese estava errada e está registrada aqui de propósito,
para você não persegui-la:** eu supus `FOCUS_NONE` espalhado pelos botões.
Contei: são **4 ocorrências no projeto inteiro** (`menu_chrome_kit.gd` ×2,
`debug_panel.gd`, e uma menção em comentário). Não é isso.

O que a contagem mostra:

| sinal | cobertura |
|---|---|
| `stylebox_override("focus")` | 9 arquivos de UI |
| `stylebox_override("hover")` | 10 arquivos de UI |
| `font_hover_color` | **13 das 17 ocorrências estão em `menu_settings_kit.gd`** |
| `font_focus_color` | **1 no projeto inteiro** |

Foco e hover **existem** quase em todo lugar. O problema é a **força visual**.

Medido, sobre `Design.SURFACE`:

```
hover  = alpha(TEXT_PRIMARY, 0.10)  ->  contraste  1.18:1
anel de foco (ffd24f, 2px)          ->  contraste 14.31:1
```

**1.18:1 é invisível.** O limiar perceptual para notar uma mudança de superfície
fica por volta de 1.2–1.3:1. O anel de foco, a 14.31:1, é berrante.

Ou seja: **o teclado acende um farol e o mouse não acende nada.** Assimetria de
~12×. É exatamente o sintoma relatado.

E o motivo de settings ser a única tela onde dá pra saber **não é** o fundo dela
(que é `alpha(..., 0.05)`, ainda mais fraco). É que settings troca a **cor da
fonte** no hover — `font_color` sai de um ciano apagado e vai para `TEXT`
cheio. Brilho de rótulo é uma mudança perceptual muito maior que 10% de lavagem
de fundo.

### 3.2 A armadilha estrutural (leia antes de "só espalhar font_hover_color")

Não funciona espalhar `font_hover_color` pelas outras telas. **Aqueles botões
não têm texto.**

O padrão do projeto é um `hit` transparente (`Button`, `flat = true`,
`PRESET_FULL_RECT`) por **cima** do conteúdo visual, e o rótulo vive num nó
separado. Um `font_hover_color` no `hit` não pinta nada, porque o `hit` não
tem rótulo. Ele falharia **em silêncio** — o pior modo de falha possível.

A boa notícia: a costura já existe. `ScreenKit.action()` guarda os dois nós:

```gdscript
stack.set_meta("label_node", line.get_child(0))
stack.set_meta("hit", hit)
```

Então o caminho é **rotear o estado do `hit` para o `label_node`** —
`mouse_entered` / `mouse_exited` / `focus_entered` / `focus_exited` no `hit`,
pintando o rótulo. Centralize isso no `ScreenKit`, num lugar só. Note que hoje
o projeto **não usa `mouse_entered` em nenhum arquivo de UI** — este seria o
primeiro, e é por isso que a costura precisa ficar em um ponto único.

### 3.3 Unificar hover e foco na mesma linguagem

Hoje hover é **preenchimento** e foco é **anel** — duas linguagens visuais para
a mesma ideia ("é isto que você vai acionar"). A autora navega com os dois
dispositivos na mesma tela; a resposta tem de ser reconhecível como a mesma
coisa.

Direção sugerida (a decisão de arte é da autora, **pergunte antes de cravar**):
o rótulo brilha nos dois casos, e o anel âmbar fica como o extra que distingue
"o teclado está aqui" de "o mouse está por cima".

Não suba o hover para 14:1 só para empatar com o foco. Um hover berrante numa
tela de jogo escuro cansa. Meça e proponha.

### 3.4 Ninguém pega foco ao abrir

Segunda metade do "não funciona input de teclado", e é uma causa independente:

`grab_focus()` aparece em **um** lugar de UI no projeto: o campo de texto do
terminal. **Nenhum painel foca sua primeira ação ao abrir.**

Consequência: você abre qualquer tela, aperta seta ou Enter, e não acontece
nada — não existe controle focado para o teclado partir. Só depois de um Tab
(ou de um clique) a navegação começa a existir.

Corrija por cima do `ScreenKit`, para valer em todas as telas de uma vez, e
teste o caminho completo: abrir -> seta -> Enter, **sem tocar no mouse**.

### 3.5 O racha mouse/teclado

- **10 arquivos** têm `hit` clicável (mouse funciona).
- **2** (`program_panel.gd`, `story_panel.gd`) implementam navegação por
  teclado própria (`ui_up` / `ui_down` / `ui_accept`).

Mapeie tela por tela o que responde a quê. A meta é que **toda ação acionável
funcione pelos dois caminhos**. Onde os dois existirem, cuide para não
duplicar: se o painel trata `ui_accept` *e* o `hit` tem `pressed`, um Enter
pode disparar a ação duas vezes.

### 3.6 Transparência do HUD

Pedido direto da autora. Hoje `Hud.primary_surface_fill()` devolve
`Color(0.012, 0.020, 0.045, 0.92)` — 0.92 de alpha é quase opaco.

A restrição que **não pode** ser quebrada ao deixar mais transparente: a regra
de legibilidade da arena, já asserida na suíte — o campo nunca fica mais claro
que a entidade mais escura (`Balance.dimmest_entity_luminance()`). Um painel
mais transparente deixa o fundo animado passar por baixo do texto do HUD, e é
aí que a regra corre risco.

Meça o contraste do **texto do HUD contra o pior fundo possível** (o pico do
campo, com corrupção), não contra o fundo médio. O caso ruim é o que decide.

### 3.7 Dívida menor, sem pressa

- 3 asserções de fonte restantes (§1.6).
- Card de patch tem um vazio vertical grande entre descrição e rodapé.
- `root` e `boss` compartilham glifo — medido **1.000**, agora com métrica
  confiável. É decisão de arte da autora, não bug.
- Comentário **desatualizado** em `design.gd:112`: diz "todo botão do projeto
  seta `focus_mode = FOCUS_NONE`". Falso hoje (são 4). Documentação que mente
  induz a erro — corrija ao encostar no arquivo.

---

## PARTE 4 — Armadilhas que custam tempo

### 4.1 O autotest precisa do separador `--`

```bash
godot --headless --path . -- --autotest
```

Sem o `--`, o jogo **abre no menu e fica parado**, sem rodar teste nenhum, e
sai com código 0. O harness lê `OS.get_cmdline_user_args()`, que só devolve o
que vem depois do `--`. Eu perdi uma sessão inteira achando que a suíte
rodava. A suíte leva ~45s.

### 4.2 O viewport, e por que celular é passada separada

`stretch/aspect="expand"` com base 1280×720 significa que a largura lógica é
**sempre ≥ 1280**; só a altura varia. Em retrato isso gera um palco de
1280×2276 com texto de 3px. Não é ajuste de layout, é decisão de configuração
de projeto — por isso é passada própria, e não deve ser misturada com este
trabalho.

### 4.3 Godot bufferiza stdout quando redirecionado

`stdbuf` não resolve. Use um pty:

```bash
script -qefc "godot --headless --path . -- --autotest" saida.log
```

Isso me custou uma varredura inteira: o processo rodou, imprimiu tudo, foi
morto por `timeout`, e o buffer **se perdeu** — saída de 0 byte com código 0.

### 4.4 Cenas de prova precisam de caminho de saída

`glyph_proof.tscn` só chama `quit()` dentro de `_capture_if_requested()`, que
retorna cedo se `KP_SHOT_OUT` estiver vazio. Rodar sem essa variável = processo
pendurado até o `timeout`. Sempre passe `KP_SHOT_OUT`.

### 4.5 GDScript, erros que já aconteceram aqui

- Chamada estática via objeto `Script` devolve **Variant**. `var x := s._iou(a,b)`
  não compila ("Cannot infer the type"). Anote: `var x: float = s._iou(a, b)`.
- `has_method()` em nome de classe: "Cannot call non-static function on the
  class directly". Use o `Script` carregado.
- `const` não aceita `tr()` ("Assigned value for constant isn't a constant
  expression"). Guarde a **chave** na constante e traduza no uso — senão o
  idioma congela no load.
- `Button` filho direto de `VBoxContainer` vira linha de ~31px. Para ocupar o
  retângulo, embrulhe num `PanelContainer`.

### 4.6 Sessão virtual — regras de segurança da autora, não negociáveis

- Encerrar: `systemctl --user stop kernel-panic-virtual.service`
- **Nunca** `pkill kwin_wayland` nem `killall kwin_wayland` — mata o Plasma real.
- Automação **sempre** explícita: `DISPLAY=:1 xdotool ...`
- **Nunca** `DISPLAY=:0`, **nunca** `ydotool` global.
- Não usar: `krfb-virtualmonitor`; output virtual dentro da sessão física;
  compositor aninhado ligado ao KWin físico; `pkill`/`killall` amplo.

---

## PARTE 5 — Ordem sugerida

1. Rotear estado do `hit` para o `label_node` no `ScreenKit` (3.2). É a peça
   que destrava todo o resto.
2. Unificar a linguagem de hover e foco (3.3) — **proponha e pergunte** antes
   de cravar a arte.
3. Foco inicial ao abrir painel (3.4).
4. Mapear e fechar o racha mouse/teclado (3.5).
5. Transparência do HUD (3.6), com a medição de pior caso.
6. Dívida menor (3.7).

Cada um começa por um teste que falha.

**E o de sempre: se a medição não fechar, escreva que não fechou. Não invente o
número.**

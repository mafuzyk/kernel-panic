# KERNEL PANIC — Sprites: auditoria e decisão de técnica

> **DECISÃO (autora, 2026-09-11): voltar ao desenho em código para a arena.**
> Isto **reverte** a direção registrada em 2026-08-30
> (`reports/2026-08-30-session-handoff.md`: *"migração progressiva code-drawn →
> arte gerada"*). Sessões futuras: não migrar de volta para raster sem nova
> decisão da autora.
>
> Direção visual aprovada na mesma data: editorial/suíça em dark neon.
> Capturas: `media/captures/2026-09-11-sprites/`

## Por que a decisão está certa (medido, não opinado)

### 1. Os sprites raster mataram a animação de 10 de 21 entidades

`GlyphLib.draw_glyph()` recebe `t` (tempo) e desenha silhuetas animadas.
Quando existe sprite para aquele tipo, ele **retorna antes** e o `t` é
descartado (`glyph_lib.gd:34-36`). Além disso `EntitySprite.draw_entity()`
contra-rotaciona o quad de propósito para o sprite ficar sempre alinhado ao
eixo (`entity_sprite.gd:45`).

Entidades que animam em código e ficaram estáticas com sprite ativo:

`spewer`, `firewall`, `bloatware`, `update_loop`, `root`, `boss`, `segfault`,
`bluescreen`, `pagefault`, `god` — **incluindo todos os bosses.**

Ninguém mediu essa perda quando a migração entrou.

### 2. O problema central do raster é resolução, e código não tem esse problema

Os arquivos são 256×256. O jogo desenha inimigo comum entre **24 e 36px** —
redução de 7 a 10 vezes. Em `tamanho_real_zoom4x.png`, `page`, `trojan`, `oom`,
`bloatware` e `segfault` viram mancha: o detalhe existe no arquivo e nunca
chega na tela.

Desenho em código não tem tamanho de origem. Ele desenha **no tamanho em que
aparece**, sempre com a espessura certa.

### 3. A cobertura varia 7x e não dá para controlar em raster

Área preenchida no tamanho real: `recursor` 6%, `lancer` 8%, ..., `root` 41%.
Inimigos de ameaça parecida com presença visual muito diferente.

Em código a cobertura é parâmetro, não consequência do arquivo que veio.

### 4. A direção aprovada e a técnica concordam

Raster faria sentido se o alvo fosse ilustração. O alvo aprovado é **pictograma
geométrico** — traço firme, forma limpa, zero ornamento. É exatamente o que
código faz melhor e imagem gerada faz pior.

## O que "com mais atenção" precisa significar

O `GlyphLib` de hoje funciona, mas tem os mesmos vícios do resto da UI:

- É um `match kind:` de ~150 linhas com chamadas de desenho imperativas.
- **9 espessuras de traço literais** (1.6, 2.0, 2.2, 2.4, 2.6, 3.0, 3.5, 4.0,
  5.0) — o mesmo "sem escala" que a auditoria achou na tipografia e no
  espaçamento.
- Coordenadas em múltiplos de `radius` espalhadas pelo corpo de cada caso, sem
  espaço normalizado — não dá para medir nem comparar cobertura.

A versão boa:

1. **Forma declarativa em vez de imperativa.** Cada entidade vira dado — uma
   lista de primitivas em espaço normalizado (−1..1) — em vez de sequência de
   `draw_*`. Fica legível, comparável e testável.
2. **Espessura vinda de token** (`Design.STROKE_*`), não literal. Consistência
   por construção.
3. **Cobertura como alvo de projeto**, 18–28% no tamanho real, medida.
4. **Animação preservada e ampliada** — é a vantagem que o raster não tem.
5. **Teste automatizado da arte.** Isto é o que raster nunca permitiu: dá para
   renderizar cada glifo em 24px e afirmar que a cobertura está na faixa e que
   nenhuma silhueta é parecida demais com outra. Arte com teste de regressão.

## O que fazer com os 20 PNGs

Não jogar fora. A conclusão é sobre a **arena**, onde as coisas são pequenas e
se movem. Em tamanho grande e estático o raster continua melhor:

- **Manter raster:** herói do menu (o `kernel.png` a 400px ficou ótimo — ver
  `media/captures/2026-09-11-direcao/swiss_menu.png`), possivelmente o detalhe
  do bestiário.
- **Voltar para código:** tudo que é desenhado na arena.

Ou seja, o registro `EntitySprite` continua existindo, mas **inverte de papel**:
hoje sprite é o padrão e glifo é o fallback; passa a ser usado só onde é
explicitamente melhor.

## Ordem sugerida

1. Normalizar `GlyphLib`: espaço normalizado + espessura por token, sem mudar
   silhueta nenhuma. Capturas devem ficar idênticas.
2. Desligar o sprite na arena e confirmar que a animação das 10 entidades
   voltou.
3. Teste de cobertura e distinção de silhueta em 24px.
4. Aí sim, passada de desenho com atenção — uma entidade por vez, medindo.

## Questão em aberto

Os programas (`kernel`, `daemon`, `rootlet`) aparecem grandes no menu e
pequenos na arena. Sugestão: código na arena, raster no menu — os dois já
existem. Precisa de confirmação da autora.

---

## Execução — passada 1 (2026-09-11)

Princípio adotado, e é o que guia tudo:

> **A distinção tem que estar no contorno, não no miolo.** Em 24px o interior
> some. Se dois inimigos têm o mesmo contorno, são o mesmo inimigo.

### Resultado medido

Similaridade de silhueta em 24px (interseção sobre união), pares reais:

| par | antes | depois |
|---|---|---|
| splitter ↔ oom | **0.823** | fora do top 10 |
| kernel ↔ daemon | **0.725** | fora do top 10 |
| bulwark ↔ update_loop | 0.578 | 0.421 |
| splitter ↔ firewall | 0.533 | fora |
| oom ↔ firewall | 0.528 | fora |
| spewer ↔ firewall | 0.519 | fora |
| bloatware ↔ bluescreen | 0.491 | fora |
| **pior par real** | **0.823** | **0.482** |

Nada acima de 0.5. Antes eram seis pares.

### O que mudou em cada glifo

- **splitter** — era círculo + barra + dois pontos. Agora é um disco partido ao
  meio com folga: a silhueta faz o que o inimigo faz.
- **oom** — os chifres eram detalhes de 0.45r pousados sobre um círculo e
  sumiam em 24px. Agora fazem parte do contorno.
- **daemon** — reusava o mesmo `_dart()` do kernel. Agora é lâmina bifurcada
  com asas recuadas.
- **bulwark** — era quadrado + círculo + X empilhados, sem ideia única. Agora é
  um escudo: ombro largo, base em ponta.
- **update_loop** — era retângulo + arcos. Agora é anel aberto com seta
  girando; a ideia de ciclo está no contorno.
- **firewall** — era octógono (colidia com o hexágono do spewer). Primeira
  tentativa foi muro com ameias, que **trocou uma colisão por outra** (virou
  retângulo largo, bateu com bluescreen em 0.587). Versão final: barras
  separadas, sem contorno sólido algum.
- **bloatware** — era retângulo com linhas. Agora é massa lobulada; o spinner
  de carregamento (telegrafo do ataque) foi para dentro do corpo.

### Infraestrutura

- `src/ui/design/glyph_proof.tscn` — folha de prova: inspeção normalizada,
  tamanho real de arena, e teste de 24px, lado a lado.
- Duas métricas em stdout: `GLYPH_METRIC` (cobertura) e `GLYPH_SIMILAR`
  (similaridade par a par). Arte com teste de regressão.
- A faixa de cobertura é **larga de propósito** (0.15–0.55), calibrada sobre a
  distribuição real. Serve para pegar extremos, não para prescrever densidade:
  o `kernel` tem 0.54 e lê muito bem. Quem governa distinção é a similaridade.

### Arena de volta ao código

`draw_glyph` = sempre desenhado em código. `draw_portrait` = sprite primeiro,
só para UI grande. A animação das 10 entidades voltou.

Duas asserções do autotest quebraram ao renomear o ponto de entrada nos
painéis — eram as de texto-fonte previstas em R6. Foram convertidas para
comportamento, e somou-se uma que **impede reverter** a arena para raster sem
o teste reclamar.

Autotest: **1421 PASS / 0 FAIL**.

### Passada 2 — fila restante executada

- **pagefault** — eram três retângulos vazados de alpha 0.10 que não apareciam
  (cobertura 0.101). Agora é uma página rachada, metades deslocadas.
- **god** — era alvo concêntrico: lia como mira e media ralo (0.133) porque
  tudo era alpha baixo. Agora é um olho com raios. Boss carrega mais detalhe
  que inimigo comum, de propósito.
- **recursor** — **duas tentativas falharam antes de acertar.** O original
  tinha um polígono de 8 pontos que não fechava, deixando um traço solto que
  parecia acidente. A primeira correção (chevrons aninhados) colapsou num V
  único — pior que o original. A espiral resolveu: é auto-similar por
  construção e é a única forma espiralada do conjunto.
- **trojan** — era losango com X, virava mancha em 24px. A primeira tentativa
  apontava para baixo e lia como alfinete de mapa. Invertida, a lança rompe
  por cima e a leitura passa a ser irrupção.
- **rootlet** — era escudo de 6 pontos e colidiu com o bulwark depois que este
  virou escudo. Agora tem contorno ancorado, base chata.

### Estado final das métricas

| | antes | depois |
|---|---|---|
| pior par de silhueta (real) | **0.823** | **0.474** |
| pares acima de 0.5 | **6** | **0** |
| glifos fora da faixa de cobertura | **3** | **0** |
| autotest | 1418 PASS | **1421 PASS / 0 FAIL** |

12 dos 21 glifos redesenhados.

### Honestidade sobre o que não ficou bom

O **rootlet** está dentro das duas métricas e é distinto, mas visualmente lê
como um arco ou a letra "A" — não comunica "âncora blindada". É o mais fraco
do conjunto. Números em faixa não são garantia de acerto; este precisa de outra
passada de desenho.

### Passada 3 — conjunto completo

Os oito não tocados foram revisados; sete redesenhados.

- **drone** — dividia o `_dart()` com kernel e lancer: três entidades, uma
  forma. Agora é um DRONE de verdade — quatro rotores em torno de um núcleo,
  girando. Conceito e forma finalmente concordam.
- **lancer** — mesmo `_dart()` mais uma linha de alpha 0.5 que sumia em jogo.
  Agora a ELONGAÇÃO é a silhueta: lança longa e estreita.
- **spewer** — hexágono + ponto central, genérico. Agora o contorno tem bicos,
  girando: a função (cuspir orbes) está na forma.
- **root** (boss principal) — era anel de arcos com o triângulo fino escondido
  atrás; lia como spinner de carregamento. Agora o triângulo DOMINA, o anel
  quebrado apenas o contém.
- **page** — quadrilátero torto que parecia descuido. Agora é documento com
  canto dobrado; a dobra é contorno, não detalhe interno.
- **segfault** — o laço construía só 4 dos 6 vértices e o resultado parecia
  aleatório. Agora é a mesma forma duplicada e deslocada: leitura em endereço
  errado, que é o que um segfault é.
- **bluescreen** — retângulo puro disputando com page e pagefault. Ganhou pé de
  monitor. *(Primeira versão tinha um bug meu: eu somava `frame.end.y`, que já
  é absoluto, ao `center` de novo — o pé ia parar fora da tela e sumia.)*
- **kernel** — mantido de propósito. Com drone, lancer e daemon fora do
  `_dart()`, ele passou a ser o único, e é o herói do menu.

### Estado final

| | início | fim |
|---|---|---|
| pior par de silhueta (real) | **0.823** | **0.474** |
| pares acima de 0.5 | **6** | **0** |
| glifos fora da faixa de cobertura | **3** | **0** |
| autotest | 1418 PASS | **1421 PASS / 0 FAIL** |

19 dos 20 glifos reais redesenhados (kernel preservado).

### O que as métricas NÃO pegam

Três erros desta sessão passaram pelas duas métricas e só foram vistos no olho:

1. O `recursor` em chevrons aninhados **colapsou num V único** — ficou pior que
   o original e mesmo assim media bem.
2. O `trojan` com a lança para baixo lia como **alfinete de mapa**.
3. O `rootlet` está dentro das duas faixas e ainda assim lê como um arco ou a
   letra "A", não como "âncora blindada".

A métrica de similaridade pega colisão. A de cobertura pega extremo. **Nenhuma
das duas sabe se a forma significa a coisa certa.** Isso continua sendo olho, e
a folha de prova existe para isso.

### Fila restante

| item | nota |
|---|---|
| `rootlet` | métricas ok, leitura conceitual fraca — o mais fraco do conjunto |
| `root ↔ boss` = 1.000 | `"boss"` é alias morto; remover exige tocar a lista `required` do harness |
| `firewall ↔ rootlet` 0.474 | maior par real; ambos têm contorno de blocos verticais |

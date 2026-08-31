# Direção de redesign da UI

Status: decisão aprovada para planejamento futuro.

## Decisão

A interface do KERNEL PANIC será reconstruída do zero em uma frente própria de
design e implementação. O objetivo não é migrar a composição atual para
`_draw()` nem polir superficialmente os painéis existentes. A futura UI deve
repensar composição, hierarquia, navegação, densidade, tipografia, paleta,
formas, animações, feedback e comportamento responsivo.

O code-drawn será o meio principal de execução visual. A meta é que a arte
pareça deliberada e autoral, com acabamento suficiente para não transmitir a
ideia de formas geométricas provisórias. Cada elemento precisa ter função
visual clara: leitura, hierarquia, estado, atmosfera ou feedback.

## Escopo visual

A reconstrução se aplica ao menu, HUD, pausa, terminal, seleção de programas,
bestiário, telas de resultado e demais superfícies de interface. Também se
aplica aos inimigos, programas e elementos desenhados durante o gameplay.

Inimigos e programas continuarão majoritariamente em code-drawn, mas serão
redesenhados de verdade: silhueta, proporção, linguagem de formas, paleta,
animações e estados de dano, alerta, morte e interação devem ser reconsiderados
como um conjunto.

Sprites poderão existir quando forem a melhor ferramenta para um elemento
específico, como efeitos, retratos ou imagens muito orgânicas. Eles não devem
definir sozinhos a identidade visual do jogo.

## O que fica decidido e o que não fica

O bloco atual de correções de layout do menu está aprovado como trabalho
técnico e como estado intermediário jogável. A aprovação não transforma a
composição atual em direção visual definitiva e não exige preservá-la na
reconstrução.

A futura frente visual deve começar por uma especificação nova, antes de
grandes alterações de código. Essa especificação deve definir a linguagem
visual, a hierarquia de cada tela, a densidade de informação, a escala, os
estados, as animações e as regras para diferentes tamanhos de viewport.

Não há ainda uma aprovação de telas finais, paleta final, wireframes finais ou
de uma arquitetura específica de componentes. Essas decisões serão tomadas
durante a fase de direção visual.

## Princípio de qualidade

O resultado deve parecer uma arte construída pelo código: simples quando a
forma simples for melhor, detalhado quando o detalhe comunicar algo, e
consistente entre UI, inimigos, programas, efeitos e feedback de gameplay.

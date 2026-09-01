# Handoff E1 — entity presentation foundation

## Fatos testados

O probe `tools/vnext_entity_illustration_probe.tscn` falha sem os três novos
scripts e passa depois da implementação. Ele verifica descriptor normalizado,
defaults para input malformado, isolamento profundo, extents em quatro tamanhos
e orientações, cinco canais de estado, desenho sem mutação, adapters de
`kernel`/`DRONE` com fixtures e instâncias reais fora da árvore, determinismo
canônico do render key, acento de era, qualidade/facing no Control público e
ausência de dependências de gameplay.

O import e a suíte completa foram executados com `--audio-driver Dummy`. A
suíte terminou com 1414 passes, zero falhas e `AUTOTEST_ALL_PASS`. A prova
focada terminou com 128 passes/0 falhas em headless e Xvfb. O validator
acumulado já inclui este probe; nenhuma nova entry foi necessária.

## Fatos inspecionados

`VNextEntityIllustration` mantém `configure_entity`, `visual_rect`,
`visual_snapshot`, `glyph_radius` e `text_overflow_report`, e agora expõe
`set_facing`/`set_quality`; a registry de sprites continua disabled-by-default.
Não foram tocados classes de gameplay, hitboxes, rotas, balance ou save.

## Assumptions

O snapshot é um `Dictionary` normalizado, adequado ao contrato atual de UI; o
tempo cosmético é fornecido pelo consumidor e não participa de simulação. Os
adapters foram exercitados contra instâncias reais fora da árvore, mas não há
prova ainda de um consumidor de produção montado em uma cena viva.

## Limitações / follow-ups

O primeiro review rejeitou E1 porque o extent e a orientação não eram reais,
adapters de produção não eram exercitados, a chave de renderização não era
canônica, o acento de era era perdido e os modos de acessibilidade não chegavam
ao Control. Essas lacunas foram corrigidas em `be92d2b` e cobertas pela nova
prova vermelha/verde. Sem captura inspecionada, não há afirmação de aprovação
visual. E2 deve aplicar identidade aos inimigos existentes; E3 aos programas;
E4 a novos inimigos; E5 às camadas de acabamento e gate de sprites. Android,
mobile físico, localização, migração de rota e teardown permanecem fora deste
handoff.

## Commits

- `2212c12` — foundation descriptor/renderer/adapter.
- `99e5695` — probe E1.
- `901da80` — documentação inicial.
- `be92d2b` — correção adversarial de extent, orientação, adapters, chave,
  acento e acessibilidade.

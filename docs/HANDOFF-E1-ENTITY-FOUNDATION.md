# Handoff E1 — entity presentation foundation

## Fatos testados

O probe `tools/vnext_entity_illustration_probe.tscn` falha sem os três novos
scripts e passa depois da implementação. Ele verifica descriptor normalizado,
defaults para input malformado, isolamento profundo, extents em quatro tamanhos
e orientações, cinco canais de estado, desenho sem mutação, adapter de `kernel`
e `DRONE`, determinismo do render key e ausência de dependências de gameplay.

O import e a suíte completa foram executados com `--audio-driver Dummy`. A
suíte terminou com 1414 passes, zero falhas e `AUTOTEST_ALL_PASS`. O validator
acumulado já incluía este probe; nenhum entry adicional foi necessário.

## Fatos inspecionados

`VNextEntityIllustration` mantém `configure_entity`, `visual_rect`,
`visual_snapshot`, `glyph_radius` e `text_overflow_report`; a registry de
sprites continua disabled-by-default. Não foram tocados classes de gameplay,
hitboxes, rotas, balance ou save.

## Assumptions

O snapshot é um `Dictionary` normalizado, adequado ao contrato atual de UI; o
tempo cosmético é fornecido pelo consumidor e não participa de simulação. O
adapter de fixtures é a evidência segura para esta fatia, enquanto as entradas
de objeto real ficam prontas para consumidores posteriores.

## Limitações / follow-ups

Sem captura inspecionada, não há afirmação de aprovação visual. E2 deve aplicar
identidade aos inimigos existentes; E3 aos programas; E4 a novos inimigos; E5
às camadas de acabamento e gate de sprites. Android, mobile físico,
localização, migração de rota e teardown permanecem fora deste handoff.

# E3 program identity — handoff

Branch: `codex/plan-execution`  
Commits: `f5a3669` (red probe), `88313c2` (runtime slice), `b6e6eaa`
(validator marker)

## Resultado

E3 implementa a fronteira somente-leitura de apresentação de KERNEL, DAEMON e
ROOTLET. O mapeamento explícito corrige o bug confirmado em que a ausência de
`prog.kind` fazia todos os Players reais caírem em KERNEL. Program selector,
combat HUD e pause recebem a mesma identidade e status runtime.

## Evidência

- Red antes da produção: exit 1, 16 falhas sem crash.
- Headless: exit 0, 29 passes, 0 fails, `PROBE_DONE fails=0`.
- Xvfb: exit 0, 29 passes, 0 fails.
- Import: exit 0.
- Full DevHarness: exit 0, 1414 passes, 0 fails, marker completo.
- Accumulated validator final: `VALIDATION OK`; E3 29/0; no runtime ERROR gates.

## Limitações

Sem aprovação visual humana, profiling denso, Android/export, hardware mobile,
Vega ou PT-BR. Os diagnósticos de recursos/RIDs/ObjectDB no encerramento
continuam baseline não-gating. A cor ROOTLET usa `Balance.COL_MOTE` por ser a
cor distinta existente dentro do escopo; a direção visual final ainda requer
avaliação humana.

## Próximos passos

Revisar visualmente os três programas no jogo opt-in sem áudio, depois avançar
para a próxima fatia do plano somente após preservar o contrato e adicionar
qualquer novo programa ao mapa e ao probe.

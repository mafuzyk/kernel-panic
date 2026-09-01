# E3 program identity — handoff

Branch: `codex/plan-execution`
Commits: `f5a3669` (red probe), `88313c2` (runtime slice), `b6e6eaa`
(validator marker)

## Resultado final após revisão adversarial

E3 implementa a fronteira somente-leitura de apresentação de KERNEL, DAEMON e
ROOTLET. O mapeamento explícito corrige o bug confirmado em que a ausência de
`prog.kind` fazia todos os Players reais caírem em KERNEL. Program selector,
combat HUD e pause recebem a mesma identidade e status runtime.

## Evidência

- Red antes da produção: exit 1, 16 falhas sem crash.
- Headless: exit 0, 35 passes, 0 fails, `PROBE_DONE fails=0`.
- Xvfb: exit 0, 35 passes, 0 fails.
- Import: exit 0.
- Full DevHarness: exit 0, 1414 passes, 0 fails, marker completo.
- Accumulated validator final after the correction: `VALIDATION OK`; E3
  35/0; no runtime ERROR gates.

## Limitações

Sem aprovação visual humana, profiling denso, Android/export, hardware mobile,
Vega ou PT-BR. Os diagnósticos de recursos/RIDs/ObjectDB no encerramento
continuam baseline não-gating. O caminho do Combat HUD foi exercitado com uma
subclasse de captura durante o `_draw()`; a pausa foi verificada pelo helper
de contexto que o próprio `_draw()` chama, não por comparação de pixels.

## Correções pós-revisão adversarial

A primeira revisão independente rejeitou o lote mesmo com o probe original
verde. Ela encontrou:

- ROOTLET usava acidentalmente a cor de mote em vez da cor canônica do catálogo;
- o Combat HUD ainda usava `Game.program` diretamente em uma linha desenhada;
- o Combat HUD desenhava `dash_state` genérico em vez do estado específico do
  programa;
- o probe validava semântica, mas não observava o texto produzido pelo
  `_draw()` do HUD;
- `src/ui/hud.gd` tinha um preload não utilizado;
- o contrato de snapshot era somente-leitura por cópia/convenção, não
  imutabilidade forte;
- a documentação precisava separar o caminho de renderer auxiliar da
  integração efetivamente exercitada.

As correções agora:

- derivam as cores de KERNEL, DAEMON e ROOTLET de
  `ContentCatalog.PROGRAM_DEFS[*].visual.color`, com fallback seguro;
- fazem o Combat HUD usar a identidade e o estado recebidos no snapshot;
- medem e desenham o estado da habilidade específica, com abreviação
  deliberada de OVERCLOCK para OC somente no layout estreito;
- removem o preload morto do HUD legado;
- capturam no probe os textos reais emitidos pelo `_draw()` do Combat HUD e
  verificam o contexto projetado da pausa;
- fortalecem a asserção de cor contra a fonte canônica e adicionam a
  configuração do seletor com a ilustração compartilhada.

Durante a correção, a nova medição revelou um overflow real de `SHIELD READY`
no painel estreito; o estado foi reduzido para 18px nesse painel e o probe
passou novamente. Isso é evidência de que o teste adicional não era
decorativo.

## Próximos passos

Revisar visualmente os três programas no jogo opt-in sem áudio, depois avançar
para a próxima fatia do plano somente após preservar o contrato e adicionar
qualquer novo programa ao mapa e ao probe.

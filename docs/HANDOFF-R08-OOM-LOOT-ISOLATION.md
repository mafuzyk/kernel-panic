# Handoff — Lote R08: isolamento do saque dos OOM

Status: concluído e validado.

## Branch

`codex/r08-oom-loot-isolation`, baseada na ponta de R07
`488d222`. Sem merge para `main`.

## Causa

Cada `OomKiller` mantém seus próprios UIDs em `carried_ids`, mas o
`MoteField` tratava `F_STOLEN` como um conjunto global. As funções
`release_all_stolen()`, `free_all_stolen()` e `stolen_positions_of(ids)` não
filtravam pelo conjunto recebido. Assim, a morte ou fuga de um OOM podia
liberar ou destruir motes carregadas por outro OOM.

## Correção

`MoteField` agora aceita opcionalmente os UIDs do dono e só altera slots cujo
UID pertence ao conjunto recebido. Chamadas antigas sem argumento preservam o
comportamento de operar sobre todas as motes. As rotas `_escape()` e `die()` do
OOM passam `carried_ids` e evitam chamar o campo quando não carregam nada.

## Red → green

O probe isolado cria quatro motes e dois `OomKiller` reais, atribui dois UIDs a
cada um e verifica a morte de um. Antes da correção, o check da primeira mote
do sobrevivente falhava. Depois, o probe também cobre fuga: em ambos os casos o
OOM sobrevivente mantém seu saque e o OOM encerrado libera apenas o próprio.

Resultado green: 6 checks, `PROBE_DONE fails=0`.

## Validação

Com `XDG_DATA_HOME` isolado:

- probe R08: exit 0, 6 passes, 0 falhas;
- probe R04: exit 0, 0 falhas;
- probe R05: exit 0, 0 falhas;
- suíte `--autotest`: exit 0, 1418 `AT_PASS`, 0 `AT_FAIL`;
- probe input headless: 32 passes, 0 falhas;
- probe input Xvfb: 34 passes, 0 falhas.

Os erros de encerramento permanecem no baseline conhecido: `show_event_banner`,
captura de lambda e vazamentos de recursos/RIDs. Foram reportados
separadamente e não fazem parte deste lote.

## Limitações

O probe usa o `MoteField` real e a classe `OomKiller` real, mas prepara os
conjuntos de UIDs chamando `_steal()` diretamente. O movimento autônomo de dois
OOMs até as motes e a decisão de alvo não fazem parte deste teste; o contrato
testado é o isolamento das operações de liberação depois que cada OOM possui
seu saque.

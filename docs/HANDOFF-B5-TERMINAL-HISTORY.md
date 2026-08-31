# Handoff — B5 — history e autocomplete do terminal

## Branch

- Branch: `codex/b5-terminal-history`
- Base: `c1ca3f4` (`codex/b2-footer-actions`)
- Commit do item: `39a5d44` — `fix: implement terminal history and autocomplete (B5)`
- Sem merge em `main`; alterações pré-existentes foram preservadas.

## Achado

O terminal mostrava `↑↓ HISTORY` e `TAB AUTOCOMPLETE` na legenda, mas o
`LineEdit` só tratava ESC. As setas eram entregues ao controle padrão e TAB
não fazia nada, então a interface prometia duas interações inexistentes.

## Regra aplicada

- Comandos não vazios entram no history quando passam pelo caminho real de
  submissão.
- Repetições consecutivas são colapsadas; comandos repetidos depois de outro
  comando continuam sendo entradas válidas.
- ↑ percorre do comando mais recente ao mais antigo.
- ↓ percorre de volta ao mais recente e, depois dele, restaura o rascunho que
  estava no prompt antes da navegação.
- TAB completa uma única correspondência do índice visível: `help`, `top`,
  `dmesg`, `man `, `sudo heal` ou `rm -rf /`.
- Prefixos sem correspondência e prefixos ambíguos ficam inalterados.
- As teclas são consumidas no `gui_input` do `LineEdit`, preservando o foco e
  impedindo que ↑/↓/TAB vazem para o restante da Arena pausada.
- Histórico é local à instância do terminal e não é persistido no save.

Não houve mudança de gameplay, balanceamento, áudio ou layout. A legenda que
já existia agora corresponde a comportamento implementado.

## Teste novo

`tools/terminal_history_probe.tscn` carrega uma Arena real, abre o terminal
pela rota do painel de pausa, mantém a árvore pausada e envia as teclas pelo
`Viewport`:

- terminal abre no caminho real de uma Arena pausada;
- history e autocomplete estão expostos;
- submissão guarda comandos e colapsa duplicata consecutiva;
- foco do prompt é mantido;
- ↑ recente, ↑ antigo, ↓ novo e restauração do rascunho;
- TAB completa `he` para `help`;
- TAB deixa prefixo sem correspondência intacto.

Red antes do código:

- exit 1;
- 1 check inicial passou;
- history e autocomplete não existiam, gerando 2 falhas.

Green após o código:

- 11 checks passaram;
- `PROBE_DONE fails=0`;
- exit 0.

## Validação

Comando oficial, sempre com áudio Dummy:

```bash
KP_VALIDATION_LOGS=<absolute-log-dir> tools/validate_input_dispatch.sh
```

Resultado final desta branch:

- DevHarness: 1418 passes, 0 failures;
- input dispatch headless: 32/0;
- R04: 7/0;
- R05: 28/0;
- R06: 7/0;
- R07: 4/0;
- R08: 6/0;
- B1: 10/0;
- B2: 8/0;
- B5: 11/0;
- input dispatch Xvfb debug: 34/0;
- runtime/script errors: 0;
- `VALIDATION OK`, exit 0.

Diagnósticos de recursos/RIDs/texturas no teardown continuam visíveis e não
gating, conforme T02.

## Limitação deliberada

TAB completa o comando `man `, mas não completa o argumento do inimigo. O
escopo deste item é cumprir o autocomplete dos comandos do índice; completar
nomes do bestiário pode ser uma melhoria separada se a UX pedir isso.

## Próximo item

B6 — decidir o destino do prompt morto do menu (`PRESS [ENTER] OR HIT >>
PURGE`): torná-lo visível com um piscar discreto ou removê-lo.

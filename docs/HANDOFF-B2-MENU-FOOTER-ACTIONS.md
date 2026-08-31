# Handoff — B2 — ações de footer do menu

## Branch

- Branch: `codex/b2-footer-actions`
- Base: `8aadcfb` (`codex/b1-overlay-confirm`)
- Commit do item: `5a720c3` — `fix: make menu footer actions real buttons (B2)`
- Sem merge em `main`; mudanças pré-existentes foram preservadas.

## Achado

Program e Story desenhavam `BOOT KERNEL [ENTER]` e `MOUNT [ENTER]` como texto
sem um controle correspondente. No Story, selecionar um card ainda disparava
a montagem imediatamente, então a interface anunciava uma etapa de confirmação
que não existia.

## Regra aplicada

- Clique em card apenas seleciona e atualiza o detalhe.
- Botão real `BootAction` confirma o programa selecionado.
- Botão real `MountAction` confirma o estágio Story selecionado.
- ENTER continua confirmando a seleção pelo tratamento explícito do B1.
- ESC continua fechando o overlay.
- Os frames continuam desenhados manualmente; os Buttons fornecem hit test,
  foco e sinais `pressed`.
- O texto do botão Program acompanha o programa selecionado; o texto do Story
  acompanha o path selecionado e sua cor.

Não houve mudança de balanceamento nem de regras de gameplay. Em viewport
compacto, o texto do botão Program usa fonte menor; os novos textos também
entraram no `text_overflow_report()` dos painéis.

## Teste novo

`tools/menu_footer_action_probe.tscn` usa um runner persistente durante as
trocas Menu/Arena. O probe verifica os cards pelo caminho de GUI do painel e
os Buttons reais pelo sinal `pressed`:

- Program: card seleciona sem iniciar; `BootAction` inicia a run escolhida.
- Story: card seleciona sem montar; `MountAction` monta o estágio escolhido.

Red antes da implementação:

- 1 check inicial passou;
- Program não tinha Button e a separação de seleção não estava comprovada;
- Story não tinha Button;
- exit 1.

Green após a implementação:

- 8 checks passaram;
- `PROBE_DONE fails=0`;
- exit 0.

## Capturas

Capturas Xvfb silenciosas em 1280×720 foram verificadas visualmente:

- Program: `/tmp/kp-b2-shot.op45gz/program.png`
- Story: `/tmp/kp-b2-story-shot.7ERmMa/story.png`

As imagens não são artefatos versionados.

## Validação

Comando oficial, sempre com áudio Dummy:

```bash
KP_VALIDATION_LOGS=<absolute-log-dir> tools/validate_input_dispatch.sh
```

Resultado final após o código B2:

- DevHarness: 1418 passes, 0 failures;
- input dispatch headless: 32/0;
- R04: 7/0;
- R05: 28/0;
- R06: 7/0;
- R07: 4/0;
- R08: 6/0;
- B1: 10/0;
- B2: 8/0;
- input dispatch Xvfb debug: 34/0;
- runtime/script errors: 0;
- `VALIDATION OK`, exit 0.

Os diagnósticos de recursos/RIDs/texturas no teardown seguem visíveis e não
gating, conforme T02.

## Próximo item

B3/B4 já foram corrigidos nos lotes de dispatch anteriores. O próximo item da
ordem B é B5: decidir entre implementar history/autocomplete do terminal ou
remover a promessa visual, preservando a experiência de terminal coerente.

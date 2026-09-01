# KERNEL PANIC — Pasta do plano-mestre

Esta pasta contém o plano de evolução do jogo a partir do estado atual. Ela é
intencionalmente dividida: o documento `00` explica produto, ordem e gates; os
demais documentos detalham um domínio cada. O plano descreve trabalho futuro;
esta criação não altera o runtime.

## Como ler

1. Leia `00-MASTER-PLAN.md` para entender a tese, dependências, releases e
   definição de pronto.
2. Leia `01-REPOSITORY-ARCHITECTURE.md` antes de mover arquivos ou criar um
   serviço novo.
3. Leia `02-UI-REMAKE-VNEXT.md` e `03-CODE-DRAWN-ENTITY-ART.md` antes de
   implementar qualquer tela, programa ou inimigo.
4. Leia `04-GAMEPLAY-AND-ENEMY-EXPANSION.md` para regras e ordem de conteúdo.
5. Leia `05-MACOS-HISTORY-ACT.md` e `06-LOCALIZATION-PT-BR.md` para conteúdo,
   narrativa e texto.
6. Leia `07-ACCESSIBILITY-SETTINGS.md` e `08-PC-MOBILE-UX.md` para qualquer
   layout, input ou feedback novo.
7. Leia `09-PERFORMANCE-RELIABILITY.md` antes de otimizar ou adicionar efeitos.
8. Use `10-REPOSITORY-RELEASE-OPERATIONS.md` e
   `11-TESTING-REPORTING-RELEASE-LOG.md` em todo checkpoint.
9. Use `12-PRODUCT-UX-AND-SUGGESTIONS.md` como filtro para ideias novas.

## Regra de execução

Cada micro-plano vira uma sequência de branches `codex/...`, probes red/green,
commits pequenos e handoffs versionados. Um agente não deve iniciar a fase
seguinte só porque o código compila: a fase anterior precisa ter sua evidência,
capturas quando aplicável, compatibilidade de save e relatório de release.

## Estado inicial

- Projeto: Godot 4.7.2, `gl_compatibility`.
- UI atual: intermediária e aprovada para jogar, não o design final.
- Direção: remake do zero, code-drawn como arte principal e raster seletivo.
- Plataformas de release existentes: Linux x86_64, Windows x86_64 e Android
  arm64.
- Validação: `tools/validate_input_dispatch.sh`, sempre com áudio dummy e
  saves isolados.
- Interpretação registrada: “MAC-OS history” significa um novo ato histórico
  jogável de macOS; o histórico do terminal já está implementado.
- Imagens de `media/Ideas/`: referências locais/moodboard, não assets de
  runtime nem uma lista de requisitos pixel-perfect.

# U4 — relatório técnico: superfícies de pausa, terminal e game-over

## Resultado

U4 adiciona uma família de superfícies code-drawn opt-in por
`KP_VNEXT_U4=1`: pausa congelada, workstation de terminal e game-over com
diagnóstico. O caminho legado permanece o padrão quando a variável não está
presente.

O lote foi aceito depois de uma implementação inicialmente incompleta, uma
revisão adversarial e uma segunda rodada de testes que encontrou falhas
reais de visibilidade, overflow, layout, roteamento e teardown de foco.

## Arquivos

- `src/ui/vnext/surfaces/pause_surface.gd`: superfície de pausa, foco e
  confirmação de abandono.
- `src/ui/vnext/surfaces/terminal_surface.gd`: workstation, `LineEdit`,
  histórico, autocomplete, ESC e projeção do resultado dos comandos.
- `src/ui/vnext/surfaces/game_over_surface.gd`: diagnóstico de morte/vitória,
  ações primária/menu, foco e estados desabilitados.
- `src/arena/arena.gd`: adapter opt-in, montagem de uma única camada, posse de
  transições, input, pausa e comandos.
- `tools/vnext_state_surfaces_probe.gd` / `.tscn`: probe vermelho/verde com
  Arena real, `Viewport.push_input`, layouts e transições de estado.
- `tools/validate_input_dispatch.sh`: bateria acumulada agora inclui U4
  headless e Xvfb.

## Contrato de ownership

`Arena` continua sendo a única fonte de verdade para `_state`,
`get_tree().paused`, confirmação Q, comandos do terminal e transições para
menu, nova run e game-over. As superfícies só projetam snapshots, desenham
frames e Controls reais, e emitem `action_requested`.

As telas rodam em `PROCESS_MODE_ALWAYS` apenas para permanecer interativas
durante a pausa. Isso não reativa `Player`, `Spawner`, inimigos ou simulação.
Uma única `CanvasLayer` U4 mantém a superfície atual; ao trocar de pausa para
terminal ou game-over, a anterior é escondida e liberada, e a nova é montada
no mesmo parent. O caminho sem `KP_VNEXT_U4=1` não monta nenhum desses nós.

## Comportamento entregue

### Pausa

- ESC real abre a pausa pelo `_unhandled_input`/`PauseInputRouter`.
- ESC, ENTER, TAB, setas e SPACE têm foco determinístico.
- RESUME fecha sem retomar antes da ação.
- RESTART delega à rotina existente de nova run.
- OPEN TERMINAL troca para a workstation sem despausar.
- Q arma confirmação, preserva a árvore congelada e expira na janela já
  existente; um segundo Q confirma pelo caminho real.
- Os quatro botões são Controls reais e permanecem visíveis e focáveis.

### Terminal

- `LineEdit` real recebe foco ao abrir.
- ENTER executa o comando pela API existente de `Arena`.
- TAB completa apenas uma opção única.
- UP/DOWN navega pelo histórico da sessão.
- ESC é tratado no `gui_input` do `LineEdit`, evitando que o foco GUI roube
  o fechamento.
- O resultado é projetado de volta para o snapshot e o tamanho semântico do
  histórico é sincronizado.
- `rm -rf /` permanece uma ação destrutiva somente dentro do comando já
  existente e continua Arena-owned; não houve nova regra de gameplay.

### Game-over

- Morte e vitória têm estados semânticos distintos e diagnóstico textual.
- A ação primária é derivada da rota real: `RETRY RUN`, `NEXT STAGE` ou
  `RETURN TO MENU`, em vez de exibir um rótulo genérico que contradiz o
  destino.
- A ação de menu muda para `STORY SELECT` na vitória e `ABANDON PROCESS` na
  morte.
- A superfície mantém foco nativo, navegação por teclado e ação primária
  desabilitável quando a rota não estiver disponível.

## Red → green e revisão adversarial

O primeiro commit do lote foi um probe vermelho. A primeira execução também
falhou com confirmação Q. A investigação mostrou que o probe enviava
`rm -rf /` antes de testar Q; esse comando mata o Player e muda `_state` para
`dead`, tornando impossível a pré-condição da confirmação. O probe foi
reordenado para provar Q enquanto a run ainda estava viva, sem enfraquecer o
comportamento de `rm -rf /`.

A revisão independente encontrou os seguintes problemas concretos:

1. `show_pause()`, `show_terminal()` e `show_game_over()` chamavam
   `_refresh()` antes de definir `visible`. O refresh copiava `visible=false`
   para os Buttons/LineEdit, deixando os controles invisíveis. A ordem foi
   corrigida e o probe passou a exigir controles visíveis.
2. O probe verificava apenas `has_unmeasured_fields=false`; uma tela podia
   ter overflow real e ainda ficar verde. A asserção passou a exigir
   `has_overflow=false` para as três superfícies em 432, 720 e 1280 px.
3. O probe tinha fallback que chamava `handle_paused_gameplay_input()`
   diretamente quando o Q via viewport não armava. Isso mascarava uma falha
   de roteamento. O fallback foi removido.
4. A medição original não incluía os textos estáticos do terminal e usava
   tamanho de fonte incorreto para títulos. O relatório passou a medir os
   textos efetivamente desenhados, com fonte/tamanho por campo e maior linha
   multiline.
5. Em 432×720, o título do terminal excedia a largura segura. O título usa
   tamanho adaptativo no modo narrow; o terminal também empilha o fluxo de
   eventos, índice de comandos e status.
6. Em 432×720, os dois botões do game-over ocupavam o mesmo retângulo. Eles
   agora são empilhados verticalmente.
7. O game-over de vitória inicialmente mostrava `REBOOT` embora pudesse
   avançar ou retornar ao menu. Labels são agora projetados da decisão de
   rota do Arena.
8. A troca de superfície alternava entre filho direto da Arena e filho de
   `CanvasLayer`. A montagem foi centralizada para manter parent/lifecycle
   consistentes.
9. Chamadas de foco adiadas podiam sobreviver ao `queue_free()` e produzir
   `Condition "!is_inside_tree()"`. O foco agora é aplicado imediatamente
   quando o Control está montado e só é adiado como fallback quando ainda não
   está no tree.

Um possível blocker sobre reboot foi investigado, não aplicado por suposição:
`_restart_current_run()` muda `Game.state`, despausa e agenda uma nova cena;
o `_state="dead"` pertence ao Arena antigo, que é substituído pela nova cena.
O caminho de transição completo já é coberto pelo probe de input R03. O U4
probe verifica a restauração imediata do estado global, e não duplica um
teste de cena que anteriormente travou junto com a troca de root.

## Evidência final

Todos os comandos usaram áudio Dummy para não interromper o usuário.

| Verificação | Resultado |
|---|---|
| Probe U4 headless | exit 0, `71` passes, `0` fails, `PROBE_DONE fails=0` |
| Probe U4 Xvfb | exit 0, `71` passes, `0` fails, `PROBE_DONE fails=0` |
| Validador acumulado | `VALIDATION OK` |
| Suíte headless no validador | exit 0, `1414 AT_PASS`, `0 AT_FAIL`, marker presente |
| Input probe headless | `32` passes, `0` fails |
| Input probe Xvfb | `34` passes, `0` fails, debug desktop confirmado |
| R04/R05/R06/R07/R08/B1/B2/B5/R18 | todos verdes no validador |
| U1/U2b/U3/vNext primitives/entity | todos verdes no validador |
| `git diff --check` | limpo antes do commit |
| import/editor scan | exit 0; warning de Android build-tools do ambiente |

O primeiro probe vermelho e os logs finais ficaram em diretórios `.godot/`
ignorados ou `/tmp`; a bateria usa timeout de 120 s por processo e marcador
obrigatório. Timeout ou execução vazia continuam sendo falha.

## Compatibilidade e impacto

- Sem `KP_VNEXT_U4=1`, nenhuma superfície U4 é criada e os painéis legados,
  APIs e ações existentes permanecem no caminho padrão.
- Com a flag, a aparência dos estados de pausa/terminal/game-over muda, mas
  as ações chamam as mesmas rotinas Arena/Game, salvo a projeção visual dos
  labels de rota.
- Não foram alterados balanceamento, dano, inventário, save schema, áudio ou
  regras de `rm -rf /`.
- O custo contínuo da tela é limitado ao desenho da superfície visível; não há
  polling de gameplay criado pela U4.
- O uso de `Font.get_string_size()` ocorre em relatórios de overflow e
  refreshes de UI, não em um loop de simulação.

## O que foi testado e o que foi inspecionado

Testado: montagem no Arena, pausa real, ESC de abertura/retorno, foco do
terminal, TAB, histórico, ESC com LineEdit, confirmação Q e expiração,
comandos, rota `rm -rf /`, diagnóstico de morte/vitória, labels de rota,
foco/visibilidade dos Controls e geometria/overflow nas três larguras.

Inspecionado: toque em dispositivo físico, teclado virtual Android, leitor de
tela nativo, aprovação artística humana, export Android e comportamento com
traduções longas. Esses pontos permanecem gates posteriores do plano, não são
declarados resolvidos pelo probe headless/Xvfb.

## Resíduos e riscos

- O teardown ainda reporta recursos, RIDs, ObjectDB e text shaping em probes
  que montam Arena/UI diretamente. Esses diagnósticos são não-gating e já
  existiam no baseline; U4 não os mascara nem afirma tê-los corrigido.
- A tela é code-drawn experimental e ainda não recebeu aprovação visual
  humana contra a direção em `media/Ideas/`.
- O texto continua English-only; PT-BR e escala de texto localizada podem
  mudar a geometria e exigem novos dados/probes.
- O parent único reduz risco de lifecycle, mas `queue_free()` continua
  assíncrono; uma troca de superfície muito rápida deve continuar coberta por
  um teste de stress caso a navegação seja tornada mais animada.
- O probe de reboot verifica o estado global e preserva a cobertura real de
  transição no R03; uma futura migração U4 default deve adicionar uma
  transição de cena U4 dedicada antes de remover o caminho legado.

## Decisão

U4 está aceito como slice opt-in. Não é autorização para tornar a UI vNext
default nem para considerar encerrados os gates de acessibilidade,
localização, mobile físico, arte, performance e export.

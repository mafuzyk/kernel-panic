# Entrada e foco — continuação de 2026-09-12

Continua `BRIEFING-CODEX-2026-09-12-input-e-foco.md`. Trabalho inline, sem
subagentes. A autora pediu que a verificação passasse a ocorrer somente no
monitor virtual isolado. Nenhuma mudança de gameplay ou de configuração mobile.

## Correções implementadas

- `ScreenKit` centraliza foco inicial e retorno ao acionador, com referência
  fraca para não manter cenas antigas vivas. Abrir e reabrir são verificados.
- Menu, seletores, bestiário, conquistas, settings, pausa, terminal, ofertas de
  patch e resumo de run recebem foco. Pausa começa em Retomar.
- A seta para baixo de PURGE apontava para o próprio botão. Removida a armadilha.
- PURGE e links colocavam o botão dentro de HBox/VBox: o alvo virava outra
  célula, sem cobrir o texto. Um PanelContainer agora sobrepõe conteúdo e hit.
- Enter em um botão recebe press e release. O atalho global podia iniciar a
  partida antes do release, ou emitir BOOT/MOUNT duas vezes. O atalho sem foco
  agora respeita a presença de um controle focado.
- O botão de fechar Terminal chamava uma rota inexistente na arena. A rota
  existe e restaura pausa e foco no acionador.
- Em build gráfico de depuração, o ramo F1–F4 consumia também teclas comuns.
  Agora somente essas quatro teclas encerram esse ramo.

## Evidência de regressão

Última suíte completa: **1637 passes, 2 falhas, 1 skip**, em monitor virtual
KWin, 1920×1080, save descartável e idioma português. Log:
`/tmp/kp-feedback-full-fullaccess.log`. Sem `SCRIPT ERROR`; vsync desligado e ligado
chegaram ao DisplayServer. As duas falhas são as provas de contenção em
432×720 descritas abaixo. O skip é mira parada de toque em display desktop.
Há avisos de layout e recursos no encerramento; a suíte não está toda verde.

Testes falharam antes das respectivas correções: ausência de foco em abertura
e reabertura; seta presa; Enter iniciando run na ação errada; seleção/BOOT/MOUNT
duplicados; clique no rótulo PURGE sem efeito; pausa sem foco; fechamento do
terminal sem restaurar pausa; ofertas de patch sem foco.

As verificações de UI injetam eventos no viewport e verificam sinais e estado.
Também percorrem Tab nos cinco painéis do menu e conferem alcance de todos os
botões habilitados e contenção de foco no painel aberto.

A execução gráfica encontrou problemas nos testes antigos: comparação do nome
do display sem normalizar maiúsculas; textos presos ao inglês; leitura de
widgets removidos; chamada `Sfx.load_settings()` inexistente, que interrompia
o teste de vídeo antes das asserções e da restauração. Corrigidos para usar
os controles atuais, traduções e `_load_settings()` existente.

O round-trip de vsync requer display gráfico. A prova de mira parada de toque
requer display não desktop, porque o desktop acompanha o mouse. Os casos não
aplicáveis são registrados explicitamente como `AT_SKIP`.

## Arte aprovada e aplicada

Proposta renderizada no Godot, em `/tmp/kp-feedback-proposal-v2.png`: texto
neutro em TEXT_SECONDARY no repouso e TEXT_PRIMARY no hover/foco; ação primária
usa ACCENT_HOT quando ativa; anel âmbar continua identificando teclado.
A autora aprovou explicitamente a aplicação, conforme §3.3 do briefing.
`ScreenKit.bind_feedback()` agora liga os estados reais do hit ao rótulo
separado. Menu, ações compartilhadas, programas, história, bestiário, patches
e resumo de run usam a mesma ligação. A modulação preserva cores semânticas
e atualizações dos seletores. Botão desabilitado volta ao repouso.

Prova anterior à implementação: `/tmp/kp-feedback-red.log`, três falhas
(texto, perigo e superfície primária). Depois da implementação, a prova
de foco fechou sem falhas em `/tmp/kp-feedback-green.log`. A suíte inclui
eventos reais de mouse no viewport, foco, saída, desabilitação durante o
estado ativo, preservação do texto escuro e do anel âmbar.

Captura gráfica após a aplicação, no monitor virtual 1920×1080:
`/tmp/kp-feedback-applied-idle.png`, `/tmp/kp-feedback-applied-mouse.png` e
`/tmp/kp-feedback-applied-keyboard.png`. A comparação confirma o mesmo brilho
do rótulo no mouse e no teclado; somente o estado focado mostra o anel âmbar.

Frontend Design Premium foi carregado nesta continuação junto do skill de
direção visual. A proposta foi mantida dentro do `Design` existente: uma
mudança memorável (brilho do rótulo) e o anel âmbar como sinal exclusivo do
teclado, sem criar uma segunda paleta ou um componente paralelo.

## HUD: medição exploratória, sem novo alpha

Com composição sRGB e luminância linearizada, TEXT_MUTED sobre o pior pico
entre as cinco eras de `Balance.field_peak_color()` produz aproximadamente:

| alpha do painel | contraste mínimo do rótulo |
|---|---:|
| 0,00 | 3,08:1 |
| 0,25 | 3,76:1 |
| 0,50 | 4,49:1 |
| 0,72 | 5,01:1 |
| 0,92 atual | 5,20:1 |

Isso é modelo do campo, não garantia da composição final. Sobre branco atrás
do painel (limite conservador para paredes/efeitos), alpha 0,50 cai para 1,95:1;
0,72 cai para 3,33:1. Não há alpha novo aprovado ou implementado. Faltam medir
todos os fundos e camadas que atravessam os módulos, inclusive efeitos, antes
de fechar a transparência. Nenhum limiar perceptual novo foi inventado.

## Pendências de layout estreito

A suíte gráfica acusa contenção no seletor de história e no menu em 432×720.
Na prova portuguesa do seletor, o corpo exige mínimo de 376 px e começa em
x=64, terminando em x=440: 8 px além da largura artificial de 432. A coluna
útil prevista seria 304 px. O viewport desktop real continua com largura
lógica mínima de 1280, conforme o briefing. Esses casos não foram apagados
nem tiveram asserções relaxadas; a passada mobile continua pendente.

# U5 — relatório técnico: Settings vNext e rota real de Accessibility

## Resultado

U5 adiciona uma rota vNext opt-in por `KP_VNEXT_SETTINGS=1`, preservando o menu legado por padrão. A rota Boot ganha Settings e abre uma superfície Accessibility code-drawn com Controls reais, foco, teclado, pointer/touch, semântica redundante e confirmação em dois passos para reset.

## Arquivos e ownership

- `src/autoload/sfx.gd`: contrato schema 2, defaults, normalização, apply, reset, reload e persistência no `SAVE_PATH` existente.
- `src/ui/vnext/surfaces/accessibility_surface.gd`: desenho, layout seguro, foco, regiões, semântica, overflow e emissão de ações.
- `src/ui/vnext/surfaces/boot_surface.gd` e `src/ui/menu.gd`: ação opt-in Settings, montagem e roteamento.
- `tools/vnext_accessibility_probe.gd/.tscn`: probe focada real.
- `tools/validate_input_dispatch.sh`: entrada headless/Xvfb do acumulador.

O Sfx continua dono dos valores e do save; Menu é dono da rota; a superfície só projeta e emite `action_requested`. A persistência com erro restaura os valores anteriores em memória e expõe `last_accessibility_persisted` para o status da tela.

## Escopo comprovadamente funcional

Somente estes campos são apresentados: `color_assist`, `haptics_enabled`, `shake_level` (`OFF/LOW/FULL`) e `touch_scale` (`SMALL/NORMAL/BIG`). O snapshot schema 2 publica suporte individual e marca como não suportados native screen reader, text scale, high contrast e reduced flash. Não há toggles inertes para essas capacidades.

Reset exige duas ativações; a primeira arma e a segunda confirma. O texto ON, OFF, OFF/LOW/FULL, tamanho e status de save é semântico, não apenas cor.

## Red → green e revisão adversarial

A probe vermelha inicial executou antes da produção: exit 1, 12 falhas, principalmente ausência de defaults/apply/reset, schema/support metadata e rota Settings. Depois foram adicionadas persistência/reload, preservação de uma chave `progress`, despacho GUI único para os quatro controles e cobertura dos quatro viewports. A revisão própria encontrou e corrigiu status desenhado dentro do botão Back e reset falho que recarregava disco em vez de restaurar o estado anterior em memória.

A revisão adversarial independente recusou o primeiro resultado por quatro motivos: o loader aceitava tipos inválidos diretamente do `ConfigFile`, o status de falha dizia que a mudança ficava aplicada embora houvesse rollback, a preservação testava um arquivo recém-criado com pouca diversidade de chaves e a falha de persistência não era exercitada. A correção passou a normalizar o perfil também no carregamento, tornou o status explicitamente `PREVIOUS VALUES RESTORED`, preservou seções/chaves preexistentes no fixture e adicionou um override interno de caminho apenas para provocar `ConfigFile.save()` inválido no probe. O override não é uma opção de usuário nem muda o caminho real de produção.

## Evidência

- Probe U5 corrigida headless: exit 0, 66 `PROBE_PASS`, 0 `PROBE_FAIL`, `PROBE_DONE fails=0`.
- Probe U5 corrigida Xvfb: exit 0, 66 `PROBE_PASS`, 0 `PROBE_FAIL`, `PROBE_DONE fails=0`.
- Import/editor scan: exit 0; permanece o aviso ambiental de Android build-tools ausente.
- Suíte completa: exit 0, 1414 `AT_PASS`, 0 `AT_FAIL`, `AUTOTEST_ALL_PASS`.
- Acumulador: `VALIDATION OK`; U5 headless/Xvfb, U4, U3, U2b, U2/U1, gameplay e input passaram; runtime errors gating = 0.
- `git diff --check`: limpo antes do commit de correção.

Todas as execuções Godot usaram `--audio-driver Dummy`. Logs ficaram em `/tmp` e `.godot/` ignorado; nenhum `.uid` ou import de captura foi estagiado.

## Compatibilidade, riscos e não comprovado

Sem `KP_VNEXT_SETTINGS=1`, a rota legada e seus settings permanecem default. Não há novo save file nem migração destrutiva; chaves fora de `feel` são preservadas. A flag `KP_VNEXT_BOOT=1` segue funcional, sem Settings adicional quando a flag U5 não está presente.

Não foram comprovados hardware Android/touch físico, leitor de tela nativo, gamepad, escala de texto, alto contraste, reduced flash, PT-BR, export, aprovação visual humana ou performance de dispositivo. A falha de persistência foi exercitada deterministicamente fazendo o `ConfigFile` tentar salvar em `res://`; falhas reais de permissão, disco cheio ou storage removível continuam não comprovadas. Diagnósticos de resources/RID/ObjectDB/text shaping no encerramento continuam resíduos não-gating do baseline.

## Commits

- `f435c03` — produção Settings/Accessibility opt-in.
- `0d980dc` — probe U5 e acumulador.
- `1de633f` — correção pós-revisão: loader, status de rollback, fixture de
  preservação e fault-injection determinístico.

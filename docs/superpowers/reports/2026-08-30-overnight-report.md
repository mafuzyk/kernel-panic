# KERNEL PANIC — Relatório da madrugada (2026-08-30)

Missão autônoma executada enquanto a autora dormia. Base: `4c36561` (v2.5.0) → `b591938`. **47 commits.** Estado final: `AUTOTEST_ALL_PASS`, **1194 AT_PASS / 0 AT_FAIL**, 68 AT_STEP labels, tree limpa.

## 1. O que foi alterado

### Pack de correções + features (spec/plano 2026-08-29, 12 tasks)
| Task | Entrega | Commit |
|---|---|---|
| 1 | Story intro: autowrap medido, dismiss por input (0.8s mín + hint + 8s auto), spawner só inicia após o pop-up | `6d1a82e` |
| 2 | HUD de combate transparente (outline + tint 0.06); menus continuam opacos | `02e62cf` |
| 3 | Era accent no HUD (story, wave tint, rainbow TempleOS) | `d117fef` |
| 4 | Auditoria de overflow de texto em todas as superfícies + checks de contenção (1366/720/432) | `1e9f715` |
| 4b | HUD mobile: banner CYCLE duplicado suprimido no compact, hints `[E]`/`[SHIFT]` ocultas no touch, módulo dash desktop oculto, patch dock sem colisão com o botão DASH | `e154ca3` |
| 5 | Motes: coleta por segmento varrido (mata tunneling do dash/turbo) + steal do OOM com handles uid | `a0d943d` |
| 6 | Dificuldade FÁCIL/NORMAL/DIFÍCIL (só infinitos, NORMAL = números atuais, seletor no menu, multipliers em read points) | `974ccf3` |
| 6b | Aba AWARDS no menu (painel de conquistas) + conquistas surfando no event log da run | `6618989` |
| 7 | `glyph_lib.gd` compartilhada: 14 inimigos + 3 programas redesenhados, bestiário/program panel reusando os mesmos glifos, tint de era | `9fbdb34` |
| 7b | Ícones táticos refeitos (10 kinds + 26 patch ids, métricas de contraste/traço) | `d11831e` |
| 7c | Trial de ícones raster gerados por IA atrás de registry com fallback code-drawn + parâmetro `framed` (híbrido contextual) | `9f88f6f` |
| 8 | Verificação final: aceitação visual vs 7 mocks aprovados, 13/13 AT_STEP | `7f0c4b9` |

### Refatoração estrutural (plano 2026-08-30, 16 tasks) — zero mudança de comportamento
| Antes | Depois | Extraído |
|---|---|---|
| dev_harness.gd **3867** | **624** | 10 seções de teste em `src/autoload/harness/` (3414 linhas) |
| arena.gd **1672** | **1146** | `panel_kit` (pause/terminal/game-over), `intro_kit` (intro/story/tips), `stage_kit` (era/dust/walls) |
| menu.gd **1615** | **730** | `menu_settings_kit` (595), `menu_chrome_kit` (367) |
| terminal_panel.gd | 348 | 1 helper morto removido (T15, provado por grep) |

Total do projeto: 16521 → 16866 linhas (+345 de headers/delegates; o ganho é organização, não redução). Autotest byte-idêntico em todos os 47 passos.

## 2. O que encontrei (achados)

- **Story-select rail divergente do mock** (achado estrutural, registrado na spec): renderiza chips de card em vez do caminho com nós conectados do mock `exec-e6d82072`. Fora do escopo do pack; candidato a passe visual futuro.
- **Landmines de dynamic dispatch**: o harness chama membros por string/has_method (`has_method("get")`, chamadas dinâmicas de `background_corruption_for_wave`, handlers do menu). Isso "congelava" arquivos inteiros — resolvido com delegates finos, mas vale padronizar contratos explícitos.
- **Armadilha recorrente do Godot 4.7**: `var x := helper()` em membros movidos perde inferência e quebra o parse (9+ ocorrências durante o split do harness). Padrão documentado no plano para o futuro.
- **Vazamentos de RID/ObjectDB no exit** (~200 ObjectDB, RIDs de CanvasItem/Area2D): conhecidos, não-bloqueantes, mas são leaks reais — candidato a passe de limpeza de teardown.
- **`.SRCINFO` vazio (0 bytes)** e `.omo/` não rastreados: lixo de ambiente, ficaram intocados — decidir deletar/ignorar.
- **RNG/One-HP/lock-on**: nenhuma violação encontrada em todo o diff da noite (verificado por revisão em cada task).

## 3. Pontos positivos e negativos do código

**Positivos**
- O autotest é o maior ativo do projeto: 1194 checks que pegaram cada regressão e tornaram um refactor de 16 tasks seguro de madrugada, sem supervisão.
- Higiene de commit consistente (conventional commits, docs separados de código).
- A arquitetura pós-refactor (kits pré-carregados + delegates) agora tem costuras claras para crescer.
- Dificuldade isolada em read points — zero toque nas constantes locked.

**Negativos**
- O harness misturava engine de teste com 3.8k linhas de casos (resolvido — manter as seções separadas daqui pra frente).
- Chamadas dinâmicas por string espalhadas = refactors cegos (o compilador não ajuda). Migrar para APIs explícitas quando tocar esses pontos.
- Alguns draws ainda assumem métricas fixas; os checks de contenção agora pegam, mas o ideal é centralizar em TacticalUI (parcialmente feito).
- Leaks no teardown e noise de exit mascaram erros reais no log (um SCRIPT ERROR se perde fácil entre warnings).

## 4. Sugestões (BACKLOG — não implementado, precisa da autora)

1. **Decisão pendente: trial raster keep-or-revert** — capturas lado a lado em `/tmp/opencode/trial_side_menu.png`, `trial_side_pause.png`, `trial_side_patch.png` + montagens em `/tmp/opencode/final-acceptance/`. Commit separado author-gated (`9f88f6f` manteve tudo atrás de fallback code-drawn, então reverter é só apagar assets).
2. **Trial de sprites gerados para inimigos/bosses/programas** — agendado pós-pack (decisão da autora); silhuetas atuais via glyph_lib são o baseline de comparação.
3. **Story rail conectado** — alinhar o story select ao mock (nós + conectores em vez de chips).
4. **Teardown limpo** — caçar os ~200 ObjectDB leaks no exit; log de erro mais limpo.
5. **Backlog de gameplay já aprovado em reviews anteriores** (não implementar sem ok): zombie processes `<defunct>`, Ring-0 double overclock, page cache, weekly mutators por seed, boss OOM desperation (<8% HP), par race-condition, SAFE MODE, practice wave select, score-as-PID, death heatmap, camadas de música por patch, fullscreen toggle + target_fps UI.
6. **Roadmap v2.7+** (já planejado): act macOS, i18n PT-BR/EN (alto valor, refazer antes/com story text), photo mode.
7. **Padronizar contratos contra dynamic dispatch** — trocar has_method/string-calls por APIs explícitas conforme os arquivos forem tocados.

## 5. Como testar tudo isso

```sh
godot --headless --path . -- --autotest   # 1194 AT_PASS / 0 AT_FAIL
godot --path .                            # F5 normal; KP_DEMO=1 para smoke
```

— bom dia! ☀️

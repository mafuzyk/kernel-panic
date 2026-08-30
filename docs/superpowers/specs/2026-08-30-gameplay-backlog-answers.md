# Gameplay Backlog — Design Answers (author, 2026-08-30)

> Respostas da autora ao questionário do apêndice 9 do polish pack
> (`docs/superpowers/plans/2026-08-30-polish-pack.md`). Nada aqui está
> implementado — este doc destrava a implementação em sessões futuras.
> Decisões author-approved: não relitigar.

## 1. Zombie processes `<defunct>`
Casco fantasma de inimigo derrotado. **Bloqueia apenas projéteis** (balas do
player somem nele; inimigos/pathing ignoram), **some após tempo fixo**, não
concede chain/combo ao ser destruído.

## 2. Ring-0 double overclock
Empilha via **re-press durante o overclock ativo**; custo do anel 2 =
**cooldown significativamente maior depois**. Sem custo de integridade.
(Nota de integração: verificar interação com o dash overclock do DAEMON.)

## 3. Page cache
Estoca até **3 motes**; ao encher, **libera automaticamente** (bônus).
Sem decay armazenado. Sem ação manual.

## 4. Weekly mutators
**1 mutator por semana** (rotativo por seed, ex: "inimigos 20% mais
rápidos"), **visível no menu antes de entrar**, **leaderboard separado** dos
runs sem mutator.

## 5. Boss OOM desperation (<8% HP)
**Padrão compartilhado por todos os bosses**: abaixo de 8% HP entra em
desespero (ataque mais rápido) com **telegraph visual forte** (borda
piscando). One-HP: revisar balance na implementação — não deixar o threshold
virar morte garantida injusta.

## 6. Race-condition pair
Gêmeos ligados por **leash/corrente**: ficando perto um do outro ganham
buff; **counter-play = mantê-los afastados**. Densidade de spawn e valores
do buff ficam pra spec de implementação (começar conservador).

## 7. SAFE MODE
**Descartada** pela autora — o FÁCIL atual já cobre o papel; esforço vai pra
mutators/practice.

## 8. Practice wave select
Destrava **por onda alcançada no endless** (replay de qualquer wave
alcançada). Runs de practice **não escrevem records**. Entrada: TBD na
implementação (candidatos: painel de pausa ou menu de modo).

## 9. Score-as-PID
**Só flavor**: score exibido como PID narrativo (HUD/event log/game over).
Nenhuma mecânica ligada (sem ordem de spawn, sem efeito de balance).

## 10. Death heatmap
Mapa de calor das posições de morte na **tela de game over**, escopo
**por modo**, **persistente no save**, retenção ~50 runs.

## 11. Patch music layers
**2 stems**: percussão entra com patch ofensivo, bass com defensivo;
**crossfade curto (0.5s)**; **desktop-only** — mobile fica sem (orçamento).

## 12. Fullscreen + target_fps
**Seção nova DISPLAY** nas settings: fullscreen toggle + target_fps
(30/60/120/unlimited). Defaults: mobile=60, desktop=unlimited.

---

## Ordem sugerida de implementação (próximas sessões)

1. **Baratos e de sistema:** 12 (DISPLAY settings), 9 (PID flavor),
   3 (page cache), 1 (zombies)
2. **Médios:** 4 (weekly mutators + leaderboard), 8 (practice), 10 (heatmap)
3. **De balance:** 2 (ring-0), 5 (boss desperation), 6 (race pair)
4. **Desktop-first:** 11 (music stems — só faz sentido com desktop build)

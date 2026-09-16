# Placar semanal — servidor auto-hospedado

O KERNEL PANIC é single-player e o save é uma string base64 que qualquer pessoa
pode editar. Uma pontuação enviada, sozinha, não prova nada.

Este serviço não acredita em ninguém. O cliente envia a **entrada** da run — os
comandos quadro a quadro — e o servidor **re-simula a partida** com o próprio
jogo, headless, para descobrir a pontuação. O número que o cliente afirma é
ignorado; se ele não bater com o da simulação, o envio é recusado.

Medido: uma run gravada numa sessão com tela, GPU e mouse reconfere
byte-idêntica numa máquina headless sem tela nenhuma.

## O que é preciso

- `python3` (só biblioteca padrão — nada para instalar)
- `godot` no PATH
- Uma cópia do projeto do jogo na mesma máquina

## Rodar

```sh
KP_PROJECT=/home/mafu/kernel-panic python3 server/leaderboard/server.py
```

| Variável | Padrão | Para quê |
|---|---|---|
| `KP_BOARD_HOST` | `127.0.0.1` | Endereço de escuta. **Não mude.** Veja abaixo. |
| `KP_BOARD_PORT` | `8710` | Porta local |
| `KP_BOARD_DB` | `server/leaderboard/board.sqlite3` | Banco |
| `KP_PROJECT` | raiz do repositório | Projeto que o verificador roda |
| `KP_GODOT` | `godot` | Executável do Godot |
| `KP_BOARD_TRUST_FORWARDED` | desligado | Ler `X-Forwarded-For` do túnel para o teto total |

Como serviço runit, veja `runit/run`.

## Exposição: use um túnel, nunca abra porta

O serviço escuta em `127.0.0.1` **de propósito**. Hospedar em casa e abrir uma
porta no roteador publica o endereço residencial de quem hospeda para qualquer
pessoa que jogue — e a região física dá para inferir a partir dele. Um túnel
resolve isso: quem joga enxerga o domínio do túnel, o TLS termina lá, e o IP de
casa nunca aparece.

Cloudflare Tunnel:

```sh
cloudflared tunnel --url http://127.0.0.1:8710
```

Tailscale Funnel:

```sh
tailscale funnel 8710
```

Com o túnel no ar, aponte o cliente para a URL que ele imprimir.

## O que o serviço faz para não cair sozinho

- **Corpo limitado a 1 MiB.** Uma run de cinco minutos dá ~90 KB.
- **Peneira barata antes da cara.** Semana aberta, contagem de quadros
  plausível, e o tamanho do buffer conferido contra `input_frames`. Só depois
  disso um processo do jogo é gasto.
- **Fila curta (32) com um trabalhador.** Re-simular custa um processo inteiro;
  fila longa só esconderia sobrecarga. Cheia, responde 503.
- **Dois limites, porque atrás de um túnel todo mundo chega de `127.0.0.1`.**
  Cinco envios por NOME a cada dez minutos — a única identidade que existe aqui
  — e quarenta no total, como teto de CPU do serviço. Contados só quando o envio
  chega a custar alguma coisa: recusar um corpo malformado é um regex e não
  consome vaga. Com `KP_BOARD_TRUST_FORWARDED=1` o teto total passa a usar o
  `X-Forwarded-For` do túnel; **só ligue isso se o túnel for mesmo quem fala com
  o serviço**, senão qualquer pessoa escolhe o próprio balde.
- **Verificador isolado.** Roda com `HOME` e `XDG_*` apontando para um diretório
  temporário descartável: não enxerga o save de ninguém, não escreve em `HOME`,
  e tem tempo limite de 5 minutos.
- **SQL parametrizado** em toda consulta.
- **Nome de 1 a 24 caracteres simples**, porque ele é mostrado para outras
  pessoas.
- **Uma linha por nome por semana**, e só melhora.

## Limites conhecidos

- **O nome não é uma conta.** Qualquer pessoa pode enviar com qualquer nome
  livre. Para o placar entre amigas isso basta; um placar público de verdade
  precisaria de identidade, o que este serviço não tem.
- **Verificar é caro.** Uma run de cinco minutos custa uma re-simulação de
  cinco minutos de CPU. É o preço de não confiar no cliente.
- **Só o Weekly.** É o único modo em que todo mundo joga a mesma partida —
  mesma seed, mesmos traits — então é o único em que comparar pontuação
  significa alguma coisa, e o único que dá para reconferir.
- **A máquina desligada é um placar fora do ar.** O jogo tem de continuar
  jogável sem ele.

## Rotas

| Rota | O que faz |
|---|---|
| `GET /v1/health` | Serviço no ar e semana corrente |
| `GET /v1/board?week=N&limit=M` | Placar da semana (padrão: a corrente, 20) |
| `POST /v1/submit` | `{"name": "...", "run": {...pacote...}}` → `202` com id |
| `GET /v1/submission/<id>` | `queued` / `accepted` / `rejected` / `error` |

O pacote é o que o jogo escreve com `KP_RECORD_OUT`.

## Conferir à mão

```sh
KP_WEEK=<semana> KP_VERIFY_IN=run.json godot --headless --path /home/mafu/kernel-panic
```

Imprime `REPLAY_MATCH yes|no`, `REPLAY_SCORE` e `REPLAY_SEED`.

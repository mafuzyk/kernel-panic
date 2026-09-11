# Sessão virtual isolada (KWin Wayland)

Roda o KERNEL PANIC numa sessão gráfica **completamente separada** da sessão
Plasma física, para testar UI/gameplay sem mexer no desktop da autora.

```
systemd --user → DBus privado → kwin_wayland --virtual → Xwayland próprio → jogo
```

O jogo roda na GPU real (radeonsi), não em software rendering.

## Uso

```sh
tools/virtual-session/kp-virtual.sh start [larg] [alt]   # sobe sessão + jogo
tools/virtual-session/kp-virtual.sh shot saida.png       # captura a janela
tools/virtual-session/kp-virtual.sh status               # unit + display + janela
tools/virtual-session/kp-virtual.sh logs [n]             # journal da unit
tools/virtual-session/kp-virtual.sh stop                 # derruba a sessão
```

Captura automatizada de telas específicas (o jogo monta a cena sozinho pelo
harness `KP_SHOT` e sai — não depende de injeção de input):

```sh
tools/virtual-session/kp-virtual.sh capture menu   /tmp/menu.png
tools/virtual-session/kp-virtual.sh capture menu   /tmp/settings.png KP_SETTINGS=1
tools/virtual-session/kp-virtual.sh capture game   /tmp/game.png
tools/virtual-session/kp-virtual.sh capture boss   /tmp/boss.png
tools/virtual-session/kp-virtual.sh capture over   /tmp/over.png
tools/virtual-session/kp-virtual.sh capture pause  /tmp/pause.png
tools/virtual-session/kp-virtual.sh capture patch  /tmp/patch.png
```

Modos de `capture`: `menu` (com `KP_SETTINGS` / `KP_BESTIARY` / `KP_STORY` /
`KP_PROGRAM` / `KP_AWARDS`), `game`, `boss`, `mk2`, `god`, `patch`, `over`,
`pause`, `terminal`, `trojan`, `batch1`. Ver `src/autoload/harness/sections_modes.gd`.

`KP_CLEAN_SAVE=1` usa um save descartável em vez do progresso real.

## Regras de segurança

- **Nunca** `pkill kwin_wayland` / `killall kwin_wayland` — mataria o Plasma real.
  Sempre `kp-virtual.sh stop` (que usa `systemctl --user stop`).
- **Nunca** executar `kwin_wayland` direto: tem `cap_sys_nice=ep` e leva SIGKILL.
  Sempre via `systemd-run --user`.
- **Nunca** usar `DISPLAY=:0` nem `ydotool` global. O script lê o display do
  `/tmp/kernel-panic-virtual.env` e recusa `:0` explicitamente.
- Sem monitor virtual dentro do Plasma físico, sem compositor aninhado ligado
  ao KWin físico, sem `krfb-virtualmonitor`.

## Limitação conhecida

`kp-virtual.sh key` / `click` usam XTEST, mas um KWin `--virtual` não tem
dispositivo de entrada e o Xwayland rootless não roteia esses eventos sintéticos
até o jogo. Para dirigir o jogo, use `capture` (harness interno) ou o console de
debug (`F1`) numa execução manual. Injeção de input externa segue em aberto.

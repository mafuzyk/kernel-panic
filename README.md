# KERNEL PANIC

<p align="center">
  <img src="assets/icons/launcher.png" width="112" alt="KERNEL PANIC icon">
</p>

<p align="center">
  <strong>One process left. Everything else wants it dead.</strong>
</p>

<p align="center">
  <a href="https://github.com/mafuzyk/kernel-panic/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/mafuzyk/kernel-panic?style=flat-square&color=4ff2ff"></a>
  <img alt="Godot 4.7" src="https://img.shields.io/badge/Godot-4.7-478cbf?style=flat-square&logo=godot-engine&logoColor=white">
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/license-MIT-ff3d81?style=flat-square"></a>
</p>

![KERNEL PANIC menu](media/menu.png)

KERNEL PANIC is a fast arena shooter about keeping one stubborn process alive while corrupted daemons close in. Move, aim, purge, collect memory motes, and push the system into overclock before the next cycle gets worse.

It started as a small mobile game experiment and slowly became a complete little arcade game. No accounts, no ads, no energy system. Open it, hit **PURGE**, and try to survive longer than last time.

## Yes, this was made on a phone

This whole game was made by a 17-year-old girl on an Android phone, inside Termux, without ADB and without root. It started out of boredom and as a way to study game development. The rest was stubbornness, dreams, and hope holding everything together.

Somehow, it worked.

## Play it

Grab the Android, Linux, or Windows build from the [latest release](https://github.com/mafuzyk/kernel-panic/releases/latest). The current release is `v3.1.0`.

### What's new in 3.1.0

- **A fourth act: macOS.** `/System`, `/Applications`, `/Library/Updates` and `kernel_task`, with `BEACHBALL` — which plants a spinning wheel that costs you time instead of health — and `GENIUS`, the lancer that blinks to a better angle when you dodge too early. Its boss flips the colour of the whole field mid-dodge.
- **Story mode has a voice.** The process you are purging answers three times per stage, in both languages. Every stage publishes a target time, announces its contract on the intro card, and grades the clear S, A or B. Clearing an act unlocks a field tint for the endless modes.
- **Three processes that change the rules, not the numbers.** `ZOMBIE` dies into a defunct husk and returns unless you reap it in time. `CRON` never attacks — it schedules, and the cycle will not end while it lives. `SWAP` drags you and the loose motes toward itself; only dash ignores the well.
- **Waves attack in turns.** There is a ceiling on how many enemies commit at once, so a pack of lancers no longer charges simultaneously, and lancers and spewers lead their target instead of aiming where you already were.
- **`rm -rf /` ends the run instead of freezing it** — the pause panel no longer comes back on top of the ending.
- **The Win11 stage stopped hurting to look at.** Its field was blowing out to pure white; it is dark glass now, and every stage theme is measured so it cannot happen again.
- **The combat HUD takes the colour of the arena** and anything walking under a module shows through as a silhouette instead of disappearing.
- **Switching language no longer leaves half the menu behind** — or brings the old button frames back with it.
- **Installs on more than Arch now:** an AppImage for any distribution, an xbps package built from source for Void, and a real Nix flake.

### What's new in 3.0.0

- **Run setup that works:** MODE (CLASSIC / WEEKLY / ONE-HP) and DIFFICULTY rows right in the menu, with mouse and keyboard, saved locally. Story keeps its own fixed curve.
- **Two languages:** full EN/PT-BR switch in Settings, applied instantly, including Story stages, bestiary, terminal, and patch descriptions.
- **A terminal that remembers:** command history (↑↓) and TAB autocomplete in the pause terminal.
- **Fairer fights:** GOD presses harder every phase, bosses telegraph cleanly, overclock arms exactly when the meter fills, and Story restarts stay in Story.
- **Mobile that plays like mobile:** three-finger move + aim + dash/boost, safe-area aware HUD, touch-sized buttons, no keyboard hints, single-pane selectors.
- **TempleOS sounds holy now**, boss intro quotes actually show up, and the menu focus ring finally hugs the PURGE button instead of the whole column.

### What's new in 2.5.0

- A complete tactical UI pass across the menu, settings, program/story/bestiary selectors, combat HUD, patch selection, boss encounters, pause screen, and diagnostic terminal.
- New UNIX, Windows, and TempleOS story acts, with era-specific CRT treatments, bosses, enemies, and arena rules.
- A desktop debug console for skipping cycles, spawning enemies and bosses, forcing ROOT split states, and clearing combatants while testing movement and AI.
- Portable save transfer, achievement/event-log reporting, speedrun diagnostics, and the in-game terminal recovery tools.
- Better desktop input safety, responsive layouts, clearer action icons, aligned controls, and refined pause/terminal behavior on compact windows.
- Linux x86_64 and Windows x86_64 exports now embed their project data, while the Android release targets arm64 devices.

## Install the game

### Android

1. Download `KERNEL-PANIC-v3.1.0-release.apk` from the latest release and open it from your browser or file manager.
> **Updating from 2.5.0 or older?** The original release key was lost, so
> everything from 3.0.0 on is signed with a new key: Android will NOT install
> it as an update. Export your progress first (Settings → Save transfer →
> Export), uninstall the old version, install this one, then import the
> transfer string. Updating from 3.0.0 needs none of this.
2. If Android blocks the installation, allow that app to **Install unknown apps** in the system settings, then open the APK again.
3. Confirm **Install**. The current export targets 64-bit ARM devices (`arm64-v8a`).

KERNEL PANIC stores progress locally and makes no network request on its own.
The optional weekly leaderboard is the only thing that ever sends anything, it
ships switched off with no server configured, and a run only travels when you
press the button. See [the server's README](server/leaderboard/README.md).

### Linux x86_64

Download the single `kernel-panic` executable from the latest release. The project data is embedded in the binary, so no separate `.pck` file is required. Then run:

```sh
chmod +x kernel-panic
./kernel-panic
```

To update an installed release, download the newer `kernel-panic` executable,
replace the old file in the same directory, and keep its execute permission.
Your local save data is kept separately by Godot, so replacing the executable
does not remove the save. The game has no in-game updater yet.

### Any Linux (AppImage)

Download `KERNEL-PANIC-v3.1.0-x86_64.AppImage`, make it executable, and run it.
Nothing is installed and nothing is left behind:

```sh
chmod +x KERNEL-PANIC-v3.1.0-x86_64.AppImage
./KERNEL-PANIC-v3.1.0-x86_64.AppImage
```

On a machine without FUSE — some containers, some minimal installs — run it with
`--appimage-extract-and-run`.

### Windows x86_64

Download `kernel-panic.exe` from the latest release and double-click it to run the game. The project data is embedded in the executable.

### Arch Linux / Artix Linux (AUR)

For the prebuilt release, install `kernel-panic-bin` with an AUR helper:

```sh
paru -S kernel-panic-bin
```

For a local source build, use `kernel-panic-git` instead:

```sh
paru -S kernel-panic-git
```

Update an installed AUR package with your normal system upgrade command, for
example `paru -Syu`. The package manager replaces the executable and keeps the
game's separate local save data.

### Void Linux (xbps)

Void ships Godot 4.7.2 and its export templates at exactly the version this
project uses, so the package is built from source rather than wrapping a
prebuilt binary. Copy the template into your `void-packages` checkout:

```sh
cp -r packaging/void ~/void-packages/srcpkgs/kernel-panic
cd ~/void-packages && ./xbps-src pkg kernel-panic
sudo xbps-install --repository=hostdir/binpkgs kernel-panic
```

To just get the game on this machine without the packaging tree, build an
installable `.xbps` from a release binary:

```sh
./packaging/void/build-xbps.sh path/to/kernel-panic
sudo xbps-install --repository=packaging/void/out kernel-panic
```

### Nix / NixOS

A real derivation — it exports the game from source with `godot_4_7`, not a
wrapper around a downloaded binary:

```sh
nix run github:mafuzyk/kernel-panic          # play it
nix build github:mafuzyk/kernel-panic        # build it
nix develop github:mafuzyk/kernel-panic      # engine + templates, nothing installed
```

Add it to a NixOS configuration through the flake's
`packages.x86_64-linux.kernel-panic`.

## How it plays

![KERNEL PANIC gameplay](media/gameplay.png)

- Clear each cycle before the arena fills up.
- Collect memory motes from defeated daemons.
- Trigger **Overclock** for a burst of firepower.
- Build a run from patches such as ricochet, heavy rounds, chain reactions, and system restore.
- Fight a different ROOT process every fifth cycle.
- Learn enemy behavior in the built-in bestiary.

Later cycles bring processes that change the rules rather than the numbers.
`ZOMBIE` dies into a `<defunct>` husk and comes back at half integrity unless a
second shot reaps it in time. `CRON` never attacks: it schedules reinforcements
on a visible clock, and the cycle will not end while it lives. `SWAP` drags you
and the loose motes toward itself, and dash is the only thing that ignores the
well.

A wave no longer charges all at once, either. There is a ceiling on how many
enemies commit to an attack at the same time — it rises with the cycle and the
difficulty — and whoever misses the window keeps repositioning instead. Lancers
and spewers lead their target now, by an amount that starts at zero and stops
where dodging is still possible.

Your first arena run introduces movement and dash timing, then surfaces a short tactical hint the first time key threats appear. Bestiary records unlock when a daemon enters the arena, so you can learn what you are facing before you purge it.

Three run modes change the rules:

- **Classic** is the full escalating run.
- **Weekly Run** uses a shared local deterministic seed; your selected aim mode, including lock-on, remains active.
- **One-HP** gives you one mistake and no excuses.

Endless modes also expose a **DIFFICULTY** cycler next to **MODE** (EASY /
NORMAL / HARD, default NORMAL). It scales the spawn cap, wave budget, elite
chance, and attack cadence, and it is stored locally; Story keeps its fixed
per-stage curve and weekly runs stay seed-deterministic.

The separate **STORY // ACTS** entry contains fixed stages with hand-authored
waves, an intro log, and an individual best score. Every stage publishes a
**target time**, announces its contract on the intro card — no damage, inside
the time — and grades the clear **S / A / B**. The rank is saved per stage and
never downgraded by a lazier replay; it is a target, not a gate, so a B still
mounts the next path. The process you are purging **talks back** three times
per stage: when it opens, halfway through, and when it falls.

Act 1 covers the UNIX paths `/boot`, `/var/log`, `/net`, `/mem`, `/quarantine`,
and `/kernel`; clearing `/mem` unlocks the ROOTLET program. The Windows act
follows with `C:\98`, `C:\XP`, and `Win11`: heavy CRT, soft CRT/Luna, and a
clean dark-glass era. It adds the reinstalling `UPDATE_LOOP`, the fat
`BLOATWARE` process, and destructible static POPUP orbs.

Act 3 is **macOS**: `/System`, `/Applications`, `/Library/Updates`, and
`kernel_task`. It brings `BEACHBALL`, which plants a spinning wheel that costs
you time instead of integrity, and `GENIUS`, a lancer that blinks to a better
angle when you dodge too early. Its boss `KERNEL_TASK` flips the hue of the
whole field mid-dodge while it prints its stack at you.

The bonus TempleOS act adds `TempleOS::BOOT` and `TempleOS::GOD`. Its arena is
deliberately compact (640×640), cycles through a rainbow palette, and uses a
golden/coral “holy CRT” treatment. GOD is an oracle boss: every attack is
chosen by the run RNG, so the encounter is intentionally unpredictable.

Clearing the **last stage of an act** unlocks a field tint for the endless
modes, picked under Settings → Video. TempleOS's rainbow is one of them.

## Controls

### Android

- Left thumb: move.
- Right thumb: aim and fire.
- A third finger taps the on-screen buttons: dash, overclock/boost, pause.
- All three can be held at once — dash and boost never steal the aim channel.

### Desktop

- `WASD`: move
- Mouse: aim and fire
- `Shift`: dash
- `E`: overclock
- `Esc`: pause
- `Q` while paused: press twice within 2 seconds to abandon the run
- `M`: mute

On desktop, open **SETTINGS** to remap movement, dash, overclock, pause,
abandon, mute, restart, and confirm keys. Select an action and press the new
physical key; **Escape** cancels, duplicate keys are rejected, and
**RESET KEYBINDS** restores the defaults. Mouse aim/fire is not remapped.

### Desktop debug console

Run the project from the Godot editor or use the Linux debug export to open
the QA console with `F1`. It is available only in debug desktop builds and is
disabled on release builds and touch devices:

- `F1`: open or close the console
- `F2`: skip to the next wave
- `F3`: spawn the ROOT split state
- `F4`: clear current combatants

The console also has buttons for each regular enemy and all four boss
variants. It is intended for movement, AI, boss, and HUD observation without
waiting through a full run.

### Pause terminal and speedrun tools

Open the terminal from the pause screen (desktop only). It accepts:

```text
help                 list commands
top                  show current run stats
man <enemy>          inspect a bestiary entry
dmesg                show the current run event log
sudo heal            restore one integrity per run (not in One-HP)
rm -rf /             intentionally trigger a kernel panic
```

Enable **SPEEDRUN HUD** in settings to show the timer, deterministic run seed,
and the hold-to-restart hint. Achievements appear as terminal-style toasts
and are recorded in `dmesg`; deaths include a short core-dump recap.

### Move a save between phone and PC

In **SETTINGS**, use the export action on the old device, then paste the string
into the save field on the new device and import. The transfer
contains records, Story stage progress, bestiary progress, playable programs,
and achievements while leaving audio, controls, and other local settings alone.

## Run and build from source on Linux

KERNEL PANIC is built with **Godot 4.7.2** and GDScript.

1. Clone this repository and enter its directory. The source build instructions below target Linux x86_64; the Windows release is distributed as a prebuilt executable.
2. Open `project.godot` in Godot.
3. Press `F5` to run the project.

To create a Linux x86_64 build, install the Godot export templates and run:

```sh
mkdir -p build/linux-x86_64
godot --headless --path . --export-release "Linux x86_64" build/linux-x86_64/kernel-panic
```

The project data is embedded in the exported Linux executable. The project includes an automated harness that can be run with:

```sh
godot --headless --path . -- --autotest
```

A green run ends with `AUTOTEST_ALL_PASS` and zero failures; the exported
artifact runs the same gate with source-only checks skipped.

## A small technical note

Most of the game's look is drawn in code instead of being assembled from a large sprite library. The neon grid, ships, enemies, projectiles, hit effects, UI, and boss telegraphs all come from a deliberately small set of assets and GDScript systems. Audio is generated locally and imported through Godot's normal audio pipeline.

## License

Source code is available under the [MIT License](LICENSE).

Made by [mafuzyk](https://github.com/mafuzyk).

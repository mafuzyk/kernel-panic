# KERNEL PANIC

<p align="center">
  <img src="icon.svg" width="112" alt="KERNEL PANIC icon">
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

Grab the Android APK from the [latest release](https://github.com/mafuzyk/kernel-panic/releases/latest).

Android may ask for permission to install apps from your browser or file manager. KERNEL PANIC does not request network access and stores progress locally.

## How it plays

![KERNEL PANIC gameplay](media/gameplay.png)

- Clear each cycle before the arena fills up.
- Collect memory motes from defeated daemons.
- Trigger **Overclock** for a burst of firepower.
- Build a run from patches such as ricochet, heavy rounds, chain reactions, and system restore.
- Fight a different ROOT process every fifth cycle.
- Learn enemy behavior in the built-in bestiary.

Three run modes change the rules:

- **Classic** is the full escalating run.
- **Weekly Run** uses a shared deterministic seed.
- **One-HP** gives you one mistake and no excuses.

## Controls

### Android

- Left side: move
- Right side: aim and fire
- On-screen buttons: dash, overclock, pause, and settings

### Desktop

- `WASD`: move
- Mouse: aim and fire
- `Shift`: dash
- `E`: overclock
- `Esc`: pause
- `M`: mute

## Run from source

KERNEL PANIC is built with **Godot 4.7.2** and GDScript.

1. Clone this repository.
2. Open `project.godot` in Godot.
3. Press `F5` to run the project.

For an Android build, install Godot's Android export templates and configure your Android SDK, JDK, and signing key in the editor. Signing credentials belong in `.godot/export_credentials.cfg`; that file is intentionally ignored.

## A small technical note

Most of the game's look is drawn in code instead of being assembled from a large sprite library. The neon grid, ships, enemies, projectiles, hit effects, UI, and boss telegraphs all come from a deliberately small set of assets and GDScript systems. Audio is generated locally and imported through Godot's normal audio pipeline.

The project includes an automated gameplay harness covering core combat, upgrades, bosses, touch controls, and run flow. It is still a small game, though. If you find something strange, opening an issue is welcome.

## License

Source code is available under the [MIT License](LICENSE).

Made by [mafuzyk](https://github.com/mafuzyk).

# KERNEL PANIC - OX Alpha / Hermes Agent Handoff

> **DECISION UPDATES (2026-08-28) — parts of this handoff are superseded.**
> The Weekly lock-on ban described throughout this file was REMOVED
> (author-approved): lock-on is now selectable in every mode. The
> "lock-on must be forbidden/disabled in Weekly" instructions below no longer
> apply. Current decisions live in `KERNEL-PANIC-ROADMAP.md` (source of
> truth); review findings and the fix backlog live in
> `docs/superpowers/specs/2026-08-27-review-findings.md`.

## Ready-to-use prompt

```text
You are OX Alpha, working on KERNEL PANIC, a Godot 4.7.2 mobile-first
arena shooter developed entirely on Android through Termux.

Read this handoff completely before touching code. Inspect the current files
and Git state, preserve existing user changes, and continue from the approved
v2.3 plan below. Work systematically: reproduce bugs, add or improve tests,
make the smallest correct changes, run the full Godot autotest, and verify
Android exports before claiming success.

Important constraints:
- Preserve the neon geometric/procedural identity.
- Keep the game mobile-first, landscape, and touch-first.
- Lock-on is an accessibility feature. Do not remove it, but disable it in
  Weekly mode.
- RECOVER pickups and death-prevention patches must not work in One-HP mode.
- Never mention the legacy local name "OX Trial 2" publicly.
- Never commit APKs, keystores, credentials, passwords, .godot/, or private
  machine paths.
- Publish binaries through GitHub Releases, not Git history.
- Do not revert unrelated work.

Start by checking repository state and reviewing the confirmed bug list.
Recommended order: fix existing bugs and regression tests, implement RECOVER
and touch controls, improve bosses, add enemies, add playable programs, add
QOL, then generate and verify the v2.3 APK. Linux and Windows exports are
planned when the user returns to a PC.
```

## Project

**Public name:** KERNEL PANIC  
**Public repository:** https://github.com/mafuzyk/kernel-panic  
**Branch:** `main`  
**Last known commit:** `8359c3b6d1757dcca57de3c0b6ffdc337f8be491`  
**Current release:** https://github.com/mafuzyk/kernel-panic/releases/tag/v2.2.0  
**Direct APK:** https://github.com/mafuzyk/kernel-panic/releases/download/v2.2.0/KERNEL-PANIC.apk

Local Android/Termux directory:

```text
/storage/emulated/0/OX-Trial-2
```

That directory name is legacy and local only. Never mention `OX Trial 2`
publicly.

Local APK:

```text
/storage/emulated/0/OX-Trial-2/KERNEL-PANIC.apk
```

## Technology and current state

- Godot 4.7.2 and GDScript.
- Android arm64-v8a.
- Android package: `dev.oxp.kernelpanic`.
- Current version: `2.2.0`.
- MIT License.
- Mobile-first, landscape, touch-first.
- Developed on Android through Termux, without root or ADB.
- Visuals are mostly drawn in code.
- Audio is generated locally and imported as `AudioStreamWAV` resources.
- APK works on a Motorola G54.
- Music and sound effects were physically confirmed.
- APK contains 17 `.sample` resources.
- APK signatures V2 and V3 were verified.
- Full harness reports `AUTOTEST_ALL_PASS`.
- README is public, written in English, and includes real screenshots.
- Project and README use the same launcher icon as the APK:
  `assets/icons/launcher.png`.

## Game concept

KERNEL PANIC is a neon arena shooter. The player controls a small blue program,
survives cycles of corrupted daemons, collects motes, charges Overclock,
chooses Kernel Patches, and fights a boss every five cycles.

Current modes:

- Classic
- Weekly Run
- One-HP

Current enemies:

- Drone
- Spewer
- Lancer
- Splitter
- Bulwark
- Trojan
- OOM_KILLER
- Page
- Four cyclic boss kinds

## Playtest feedback

- Boss fights feel too difficult because health cannot be recovered during
  the fight.
- Bosses should inherit mechanics from enemies in their respective eras.
- Aim-stick mode needs an anchored base.
- Lock-on should remain for accessibility but must be forbidden in Weekly.
- Add more Kernel Patches.
- Improve bestiary and enemy art.
- Add unlockable playable programs with distinct mechanics.
- Add new enemies.
- Improve balance and quality of life.

# Approved v2.3 plan

## 1. RECOVER pickup

Add a pickup that restores 1 HP.

Approved chances:

- 8% from a normal enemy.
- 25% from an elite.
- Guaranteed at 50% boss HP.
- Guaranteed when a boss dies.
- Disabled in One-HP mode.

Behavior:

- Green neon visual.
- Approximately 10-second lifetime.
- Not attracted by the normal mote magnet.
- Player must move to collect it.

Related patches:

### RECYCLER

- Adds approximately 6% RECOVER chance per level.
- Suggested maximum: 2 or 3.

### DATA LEECH

- Elites always drop RECOVER.
- Rare patch.
- Excluded from One-HP offers.

The game already heals one HP every three cycles and after boss kills, but
there is no recovery during boss fights. RECOVER addresses that gap.

## 2. Touch controls and lock-on

### Anchored stick

File: `src/ui/touch_controls.gd`

In `stick` mode, `_aim_origin` currently follows the finger when the offset
exceeds 110 pixels. Desired behavior:

- Base circle remains at the initial touch point.
- Knob moves within its limit.
- `_aim_origin` does not move during drag.
- Only the offset is clamped.

### Lock-on

Current lock-on is auto-aim plus auto-fire. Keep it as an accessibility feature.

Rules:

- Allowed in Classic.
- Allowed in One-HP.
- Forbidden in Weekly.
- If a saved lock-on preference exists when Weekly starts, temporarily use
  `stick` or `drag` without deleting the saved preference.
- Settings should skip, hide, disable, or clearly mark lock-on unavailable
  while Weekly is selected.

## 3. Era-based boss mechanics

### ROOT.exe

- Keep current shooting.
- Add a telegraphed dash.
- At 50% HP, split into two mini-ROOTs.
- Mini-ROOTs cannot split again.
- Combined remaining HP should stay fair; suggested split uses roughly 60%
  of the remaining pool per design iteration, subject to playtesting.
- Drop RECOVER when the split triggers.

### SEGFAULT

- Keep teleporting.
- Add a Lancer-style targeting line and charge.
- Telegraph must remain readable.

### BLUE SCREEN

- Keep freeze.
- Add a Spewer-style orb fan.
- Respect the global cap of 40 enemy orbs.

### PAGE FAULT

- Keep Pages and shield.
- At 50% HP, rebuild the shield once.
- Spawn two additional Pages.
- Provide an obvious visual warning.

Suggested boss HP formula:

```gdscript
max_hp = 120 + 42 * (boss_index - 1)
```

New mechanics should replace excessive health, not stack on top of a damage
sponge.

## 4. Unlockable playable programs

"Programs" means playable characters. The current blue character remains the
balanced default.

### DAEMON

- 3 HP.
- Short range.
- Approximately 60% higher close-range fire rate.
- Kills reset or strongly reduce dash cooldown.
- Two dash charges.
- Aggressive momentum playstyle.
- Must have meaningful advantages, not only penalties.

Suggested unlock: reach cycle 5.

### ROOTLET

- 5 HP.
- Slower movement.
- Bullets deal 2 damage.
- Lower fire rate.
- Replaces normal Overclock with a shield mechanic.
- Shield may block one hit per cycle or use its own charge meter.

Suggested unlock: defeat the first boss without taking damage.

Scores and saves should record which program was used.

## 5. New enemies

### RECURSOR

- Green.
- Appears from wave 7 onward.
- Uses short teleports.
- Leaves small corruption zones.
- Telegraphs before teleporting.
- Cannot teleport directly on the player.

### FIREWALL

- Cyan.
- Appears from wave 9 onward.
- Stops in position.
- Creates a rotating wall or line of orbs.
- Its wall disappears when it dies.
- Must respect the global orb cap.
- Controls space instead of dealing unavoidable damage.

Both need Spawner integration, budget costs, bestiary entries, and autotests.

## 6. New Kernel Patches

In addition to RECOVER patches:

### SPLITSHOT

- Adds one angled projectile.
- Reduces fire rate by approximately 10%.
- Test interactions with Heavy Rounds, Ricochet, and Hot Core.

### SECOND WIND

- Prevents death once per run and restores 1 HP.
- Legendary.
- Disabled in One-HP.

### THORNS

- Contact damage reflects 1 damage.
- Needs a cooldown to prevent repeated damage in one overlap.

### TURBO DASH

- Improves dash without duplicating existing Phase Dash.
- Candidate effects: distance, i-frames, or kill-based recharge.

Review existing patches before adding any overlapping effect.

## 7. Art direction

Approved direction: hybrid.

- Preserve code-drawn silhouettes, animation, telegraphs, hit flash, and glow.
- Use GPT ImageGen for concept art.
- Bestiary can use static generated portraits.
- Bosses may receive more detailed bodies, while effects remain procedural.
- Player art should visually connect to the launcher icon.
- Do not replace everything with generic generated sprites.
- Preserve the geometric neon identity.

Concept art may begin on the phone. Final integration is better on PC.

## 8. Quality of life

- Show active patches in the HUD.
- Add counterplay tips to bestiary entries.
- Improve RECOVER feedback.
- Show selected program in menu and game-over screen.
- Keep retry fast.
- Update the visible menu version.
- Review target-FPS settings.
- Keep all mobile UI readable.

# Confirmed and suspected bugs from review

## High priority

### Touch dash bypasses Player dash logic

File: `src/ui/touch_controls.gd`

`_press_dash()` implements dash directly instead of calling the central Player
dash method. On mobile this skips:

- `dash_id` increments.
- Quick Dash patch cooldown reduction.
- Magnetic Dash behavior.
- Phase Dash behavior.
- Some shared effects and feedback.

Centralize dash behavior in Player and call the same API from keyboard and
touch. Add a regression test covering touch plus dash patches.

### Weekly mode is not fully deterministic

Gameplay uses global RNG in multiple places instead of `Game.rng`.

Examples:

- `_queue.shuffle()` in `spawner.gd`.
- Gameplay `randf()` and `randf_range()` calls in Lancer, Spewer, Splitter,
  and drops.
- Mote spawn positions.

All gameplay-affecting random choices must use `Game.rng`. Purely visual
randomness can keep using global RNG. Add a seeded multi-wave regression test.

### First `wave_started` signal is lost

In `arena.gd`, `spawner.start()` is called before `wave_started` is connected.
`start()` immediately calls `_begin_wave()`, so wave 1 emits before its listener
exists.

Connect Spawner signals before calling `start()`.

### Vampic can heal twice

`Game.register_kill()` emits `combo_milestone` at x4 and x8. Arena then emits
`Game.combo_milestone` again after every kill. At x4, Vampic may heal twice.

Remove the duplicate Arena emission and add a regression test.

### Bullet rotation and trajectory can disagree

`Player._shoot()` calculates random spread twice: once for `setup()` and again
when overwriting velocity. Rotation uses one direction while movement uses
another.

Calculate the final direction once and reuse it.

## Medium priority

### Reset high score writes the wrong key

Menu resets `run/best`, while Classic uses `run/best_classic`. Reset may leave
the actual record intact.

### Touch Size can become stuck on BIG

The next index uses clamping instead of wrapping. Once index 2 is reached, it
stays there. Use modulo 3.

### Visible menu version is stale

Menu shows `KERNEL PANIC v1.0` while the current release is 2.2.0. Prefer a
single project version source over another hardcoded string.

### Boss summon count never decreases

`RootBoss._summoned` increments but never decreases when summons die. Decide
whether the limit means alive simultaneously or total summons. Current behavior
eventually disables summoning for the rest of the fight.

### Boss phase flash is frame-rate dependent

`RootBoss._phase_flash` decreases by a fixed amount inside `_draw()`, not by
delta. Move timing into `_process()` or `_physics_process()`.

### Camera mouse lean on touch

CameraRig always uses mouse position. On a touchscreen, stale pointer position
can cause unwanted camera offset. Disable mouse lean for touch or derive it
from player aim.

## Test and architecture issues

- Harness can report: `Lambda capture at index 0 was freed. Passed "null"
  instead.` after replacing an Arena captured by a lambda.
- Harness exits with some RID/ObjectDB leak warnings.
- Existing touch-dash test only checks cooldown and misses patch behavior.
- Adaptive quality only decreases quality and never restores it.
- `arena.gd`, `menu.gd`, and `root_boss.gd` are large; avoid adding unrelated
  responsibilities to them.

# Recommended execution order

1. Inspect Git status and current commit.
2. Add regression tests for confirmed bugs.
3. Fix touch dash, Weekly RNG, wave-1 signal, Vampic, bullet spread, reset key,
   touch-size cycling, version display, and test-harness noise.
4. Implement RECOVER and its patches.
5. Anchor stick base and block lock-on in Weekly.
6. Rework bosses and rebalance HP.
7. Add RECURSOR and FIREWALL.
8. Add playable-program architecture, DAEMON, and ROOTLET.
9. Add HUD and bestiary QOL.
10. Generate and integrate art.
11. Run complete autotest and stress tests.
12. Export, sign, and audit Android APK v2.3.
13. On PC, export and test Linux and Windows builds.
14. Publish binaries through a new GitHub Release.

# Project rules

- Do not revert user or unrelated changes.
- Use `apply_patch` for manual file edits.
- Add or improve tests before behavior changes.
- Preserve mobile-first design.
- Preserve neon procedural identity.
- Do not remove lock-on; it is accessibility functionality.
- Disable lock-on in Weekly.
- Disable RECOVER and death prevention in One-HP.
- Never mention `OX Trial 2` publicly.
- Do not commit APKs, AABs, keystores, credentials, `.godot/`, or private paths.
- Upload binaries only through GitHub Releases.

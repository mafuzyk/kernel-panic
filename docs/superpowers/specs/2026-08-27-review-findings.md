# KERNEL PANIC — Code Review Findings (2026-08-27)

Full read-only review of the codebase (all scripts, configs, shaders, tools).
Nothing here was fixed yet; this file is the input for the next fixes pack
and the idea backlog. The Identity Pack has its own spec:
`2026-08-27-identity-pack-design.md` (partially overlaps item F3).

## Confirmed bugs (fix pack #1, in order)

- **F1 — RECURSOR crashes every teleport.**
  `src/enemies/recursor.gd:72` calls `Sfx.has_sound("teleport")`, which does
  not exist in `src/autoload/sfx.gd` → runtime script error each teleport
  (~every 2–4 s while a recursor is alive), the sound never plays, console
  spam. Fix: `Sfx.play("hit", 1.3, -12.0)` or add `has_sound()` to Sfx +
  generate a `teleport` WAV in `tools/gen_audio.gd`. The autotest misses this
  (`dev_harness.gd:692`) because script errors are not test failures — worth
  hardening the harness while fixing.

- **F2 — Double heal on boss kill.**
  `src/arena/arena.gd:705` and `arena.gd:721` both run
  `if player.hp < player.max_hp: player.heal(1)` inside the same boss-death
  block → +2 HP while the banner says "INTEGRITY +1" and telemetry
  (`register_heal("boss")`) counts one. Decide the intended amount (likely +1)
  and delete the duplicate.

- **F3 — Wayland not detected as desktop.**
  `src/player/player.gd:157` and `src/arena/camera_rig.gd:22` hardcode
  `["windows", "x11", "macos"]`. On Wayland: camera mouse lean never applies;
  on touchscreen laptops with Wayland, mouse aim can fall to the
  touch branch (`aim = Vector2.ZERO`). Fix: new shared static
  `Balance.is_desktop_display()` including `"wayland"` and `"embedded"` —
  the camera half ships with the Identity Pack; the `player.gd` half belongs
  here.

- **F4 — OOM_KILLER can steal the wrong mote.**
  `src/enemies/oom_killer.gd:83` chases slot `idx` but steals
  `f.steal_nearest(global_position)` — the nearest free mote, not necessarily
  the target. Add `MoteField.steal(idx)` and use it.

- **F5 — Dash HUD indicator wrong with QUICK DASH / charges.**
  `src/ui/hud.gd:113` uses fixed `Balance.DASH_CD`; real CD is
  `Balance.DASH_CD * pow(0.82, Game.patch_level("dash"))` (see
  `player.gd:294`). Also: the desktop pip cannot show DAEMON's 2 charges.

## QOL / PC-mobile parity (fix pack #2 candidates)

- Only an Android export preset exists (`export_presets.cfg`) — add
  Windows/Linux presets (roadmap already planned this).
- Keyboard-only texts shown on touch devices: menu controls block
  (`menu.gd:89-102`), pause panel "[ESC] RESUME [R] RESTART [Q] ABANDON"
  (`arena.gd:187`), "OVERCLOCK READY [E]" (`hud.gd:164`). Gate on
  `DisplayServer.is_touchscreen_available()`.
- BOOST touch button is dead weight for ROOTLET (shield_mode never sets
  `oc_ready`) — show shield state on the button instead.
- Game over "BEST" always shows the Classic best (`arena.gd:641` uses
  `Game.best`); HUD already uses `Game.best_for_mode()`.
- `export_presets.cfg:35` `version/code=2` is stale for 2.3.0 (bump).
- Android back button: consider `quit_on_go_back=false` + menu behavior.
- `target_fps` setting exists in `sfx.gd` but has no UI — expose it on PC
  (60/120/144/uncapped) and add a fullscreen toggle.
- Menu button row built once with `_ready` `size` — does not reflow on
  window resize (`menu.gd:194`).

## Minor / cleanup

- `player.gd:264` unused `var b := PlayerBullet.new()` allocated per shot.
- `touch_controls.gd:61-62` dead duplicate branch.
- `recover_pickup.gd:44` `has_method("get")` is always true (dead check).
- `arena.gd:702` `Game.recover_chance(e.elite)` evaluated twice.
- `bestiary_panel.gd:103` integer-division warning (`i / cols`); bestiary and
  menu `queue_redraw()` every frame even idle.
- FIREWALL wall orbs move at `dir * 0.15` (essentially static) — confirm the
  "rotating wall" is intentional or make arms orbit.

## Idea backlog (brainstorming session, not scheduled)

Gameplay: zombie processes `<defunct>` clogging `max_alive`; Ring-0 double
overclock (2 s pierce + slowmo, signature moment); page cache (unspent motes
banked for next-wave micro-bonus, no heals); weekly named mutators derived
from the seed; boss OOM desperation state (<8% HP: faster, no telegraph,
double motes); race-condition enemy pair (must die within 4 s of each other).

UI/audio: boot sequence (shipped in Identity Pack), man-page bestiary
(shipped), stack trace (shipped), score-as-PID (`kill -9 <pid>` on game
over), post-run death heatmap per arena quadrant, patch-themed music layers
on the existing intensity stems, SAFE MODE (start 3 HP, no patches, pick
+1 HP or +1 patch per wave), practice wave select, PC keybind remapping
(actions are runtime-registered in `game.gd`, so remap is easy).

## Decisions log (do not relitigate)

- Identity Pack scope approved (cosmetics only, mobile untouched).
- Reticle style: terminal block with spread ticks + Overclock feedback
  (not a simple custom cursor).
- No controller support; endless stays the primary mode; One-HP never heals.
- UPDATED 2026-08-28 (author-approved, supersedes the line below's earlier
  wording): lock-on is selectable in every mode (Weekly ban removed);
  difficulty no longer fully frozen — `max_alive` ceiling 16→10 and bounded
  `attack_cadence_factor` (floor 0.78) are intentional; `WAVE_SCALE_CAP` and
  `elite_chance` still untouched pending playtest.

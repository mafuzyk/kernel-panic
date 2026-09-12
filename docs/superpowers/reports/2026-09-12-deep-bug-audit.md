# Deep Bug Audit — report 2026-09-12

Plan: `docs/superpowers/plans/2026-09-12-deep-bug-audit.md`.
Branch: `feat/design-system-and-glyphs`, HEAD `7012b97` + dirty tree (32 modified, 3 new).
Full suite (virtual KWin, 1920×1080, clean save): `/tmp/kp-deep-final.log`.

## Final matrix

- 1645 AT_PASS, 2 AT_FAIL, 1 AT_SKIP (expected), 0 SCRIPT ERROR.
- The 2 fails are the known narrow-layout ones, unchanged from baseline:
  `story selector content stays inside the screen at 432x720`,
  `menu shell content stays inside the viewport at 432x720`.
  Desktop-first decision stands; no mobile redesign attempted.
- No new regressions.

## Fixed (all reproduced first, red test before prod fix)

1. **Duplicate enemy death** — multiple hits/signals re-entered before
   `queue_free`, duplicating rewards, fx and `died`.
   Fix: `dead` flag, guards in `take_hit`/`die`, flag set before emit.
   Files: `enemy_base.gd`, `bulwark.gd` (custom path, now emits once),
   `bloatware.gd`, `splitter.gd`, `firewall.gd`, `oom_killer.gd`,
   `page_node.gd`, `update_loop.gd`, `root_boss.gd`.
   Proof: `enemy death emits exactly once under duplicate hits`,
   `bulwark death emits exactly once`.
2. **ROOTLET recharged the wrong meter** — `collect_mote()` and
   `add_kill_mote_bonus()` used `shield_ready`; after shield break, motes
   went to normal Overclock. Fix: use `prog["shield_mode"]`.
   File: `player.gd`. Proof: `rootlet refills shield after shield breaks`.
3. **Global orb cap violated** — producers cap-checked then
   `call_deferred("add_child")`; same-frame checks all saw the stale count
   (39 live became 53). Fix: add orbs immediately, cap-check each RootBoss
   volley incl. corruption volley.
   Files: `enemy_base.gd`, `root_boss.gd`, `page_node.gd`, `firewall.gd`,
   `bulwark.gd`. Proof: `orb cap probe installs 39 live orbs`,
   `deferred orb bursts respect the global cap (40)`.
4. **TempleOS GOD spawned RootBoss** — `_spawn_story_boss()` always built
   `RootBoss`, ignoring `_story_boss_kind == "god"`. Fix: build `GodBoss`
   when stage declares `boss_kind: "god"`. File: `spawner.gd`.
   Proof: `TempleOS GOD stage spawns the GOD boss`.
5. **SPLITSHOT** — rotation/trajectory probe passed before and after; no
   confirmed bug, no prod change.

Harness: `src/autoload/harness/sections_deep.gd`, wired in `dev_harness.gd`.

## Residual

- Anchor warnings (`pause_panel.gd:53`, `run_summary_panel.gd:59`,
  `menu_shell.gd:58`): size overridden after `_ready()`. Cosmetic, not
  errors. Fix later with correct anchors or `set_deferred()`.
- Suspects NOT fixed (unreproduced, per plan): `vampic_cd` reset in
  `start_run()`/`start_story()`; malformed save values in `_load_run_config()`;
  `_setup_input()` mouse-event duplication after reload; RootBoss `sp_acc`
  across spirals; `MoteField.stolen_positions_of(ids)` ignoring `ids`;
  `stolen_ids()` returning indexes; RootBoss summon adding 3 past cap;
  `_pages_alive` using global count; RootBoss `_process()` running one frame
  after `dead`. Each needs a failing probe before any prod edit.

## Risk

Low. All fixes are guarded state transitions or routing corrections, each
covered by a passing probe in the final full run.

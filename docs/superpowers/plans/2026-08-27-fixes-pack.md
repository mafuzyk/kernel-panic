# KERNEL PANIC Fixes Pack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stabilize the v2.3 gameplay baseline and desktop compatibility before executing the Identity Pack.

**Architecture:** Fix the existing systems at their current boundaries instead of adding a parallel boss or reward flow. Root boss fragments will have explicit fragment semantics so they cannot masquerade as boss encounters. Test-only timing and cleanup changes stay in the harness; gameplay changes remain covered by regression checks.

**Tech Stack:** Godot 4.7.2, GDScript 2, existing `DevHarness._autotest`.

**Spec:** `docs/superpowers/specs/2026-08-27-review-findings.md` plus the approved boss/drop decisions from the 2026-08-27 implementation discussion.

## Global Constraints

- Run `godot --headless --path . -- --autotest` after every task.
- Do not change `Balance.WAVE_SCALE_CAP` or `Balance.elite_chance`.
- Preserve lock-on behavior and all One-HP restrictions.
- Cosmetic/random flavor code must not consume `Game.rng`.
- Preserve mobile behavior while fixing desktop/Wayland detection.
- Do not commit APKs, keystores, credentials, `.godot/`, or private paths.
- Do not add Linux packaging or Identity Pack cosmetics until this plan is green.
- Do not reduce RECOVER percentages until duplicate boss rewards are removed and the corrected drop frequency is playtested.

---

### Task 1: ROOT boss locomotion and charge regression

**Files:**
- Modify: `src/enemies/root_boss.gd`
- Modify: `src/autoload/dev_harness.gd`

- [ ] Add a failing harness check proving that a ROOT in `CHARGE_GO` changes position over several physics ticks.
- [ ] Run the focused/full harness and observe the movement assertion fail because `RootBoss` inherits `EnemyBase.vel()`.
- [ ] Add `func vel() -> Vector2: return _v` to `RootBoss`.
- [ ] Reset `_charge_cd` when a ROOT charge starts so a completed charge cannot immediately reschedule every hover frame.
- [ ] Run the full autotest and verify the charge assertion passes without changing difficulty constants.
- [ ] Commit: `fix: apply root boss charge velocity`

### Task 2: First boss split, fragments, and single reward

**Files:**
- Modify: `src/enemies/root_boss.gd`
- Modify: `src/arena/arena.gd`
- Modify: `src/autoload/dev_harness.gd`

- [ ] Add failing checks that the first ROOT splits once near half HP, fragments have positive multi-hit HP, fragments move, fragments never split again, and killing both fragments produces exactly one boss reward/card flow.
- [ ] Run the harness and observe the checks fail against the current lethal-hit split and `remaining * 0.3` HP behavior.
- [ ] Move the first ROOT split trigger to a one-time half-health transition and keep the encounter alive until both fragments are gone.
- [ ] Give fragments explicit non-boss reward semantics, remove the ROOT normal charge-line telegraph from fragment-independent behavior, and give fragments the Lancer-like line/rapid movement plus a reduced ROOT burst.
- [ ] Make the arena count the encounter as one boss: no card, boss heal, boss RECOVER, or boss unlock per fragment; issue the final reward once after the second fragment dies.
- [ ] Run the full autotest and verify all first-boss assertions pass.
- [ ] Commit: `fix: make root split a single rewarded boss phase`

### Task 3: Boss recovery deduplication and heal correctness

**Files:**
- Modify: `src/arena/arena.gd`
- Modify: `src/autoload/dev_harness.gd`

- [ ] Add failing checks for at most one guaranteed RECOVER per boss encounter and exactly one direct boss victory heal.
- [ ] Run the harness and observe the duplicate recovery/heal paths, including the two direct heals in the boss-death block.
- [ ] Keep the mid-fight guaranteed RECOVER as the boss sustain reward, remove the duplicate death RECOVER path, and keep one direct victory heal.
- [ ] Ensure fragment deaths cannot invoke any boss recovery path.
- [ ] Run the full autotest and verify heal telemetry matches actual healing.
- [ ] Commit: `fix: deduplicate boss recovery and victory healing`

### Task 4: Boss and enemy regression failures

**Files:**
- Modify: `src/enemies/root_boss.gd`
- Modify: `src/enemies/recursor.gd`
- Modify: `src/enemies/firewall.gd`
- Modify: `src/autoload/dev_harness.gd`

- [ ] Add focused failing assertions for PAGE FAULT shield reconstruction, SEGFAULT lance wind-up, RECURSOR corruption-zone creation, and FIREWALL wall ownership/orb creation.
- [ ] Reproduce each failure while recording whether the issue is production state, deferred-child timing, or stale harness state.
- [ ] Fix only the confirmed production causes; where `call_deferred` is intentional, synchronize the harness after the deferred boundary instead of weakening the behavior assertion.
- [ ] Ensure the firewall wall is visibly rotating and remains within the global orb cap.
- [ ] Run the full autotest and verify these four assertions pass.
- [ ] Commit: `fix: stabilize boss and enemy regression paths`

### Task 5: Runtime error and MoteField correctness fixes

**Files:**
- Modify: `src/enemies/recursor.gd`
- Modify: `src/pickups/mote_field.gd`
- Modify: `src/enemies/oom_killer.gd`
- Modify: `src/autoload/dev_harness.gd`

- [ ] Add a failing teleport test that executes a RECURSOR teleport without emitting a missing-method error.
- [ ] Replace the invalid `Sfx.has_sound("teleport")` dependency with an existing sound path, preserving seeded gameplay RNG.
- [ ] Add a failing MoteField test proving OOM_KILLER steals the selected slot rather than another nearer mote.
- [ ] Add `MoteField.steal(idx)` and route OOM_KILLER through it without changing the public field behavior.
- [ ] Run the full autotest and verify no RECURSOR runtime error and correct target-mote stealing.
- [ ] Commit: `fix: harden recursor audio and targeted mote stealing`

### Task 6: Freeze, touch-fire, harness timing, and cleanup

**Files:**
- Modify: `src/player/player.gd`
- Modify: `src/ui/touch_controls.gd`
- Modify: `src/autoload/dev_harness.gd`

- [ ] Add/adjust failing checks that wait on elapsed simulation time for FREEZE expiration rather than assuming 70 render frames equal one second.
- [ ] Trace touch-fire state from `TouchControls._input` through `player.touch_fire` into `Player._physics_process`, then add a regression check for an actual shot.
- [ ] Remove only the dead duplicate touch-release branch and fix the confirmed propagation issue if one exists.
- [ ] Replace lambda waits that capture freed nodes with validity-safe harness waits and clean up spawned nodes between sections.
- [ ] Run the full autotest and verify zero `AT_FAIL`, no lambda-capture errors, and no avoidable ObjectDB/RID leak warnings.
- [ ] Commit: `fix: stabilize touch timing and autotest cleanup`

### Task 7: Wayland desktop detection and HUD dash state

**Files:**
- Modify: `src/autoload/balance.gd`
- Modify: `src/player/player.gd`
- Modify: `src/arena/camera_rig.gd`
- Modify: `src/ui/hud.gd`
- Modify: `src/autoload/dev_harness.gd`

- [ ] Add a failing helper/Wayland assertion for desktop display detection.
- [ ] Add `Balance.is_desktop_display()` for Windows, macOS, X11, Wayland, and embedded display servers; route player and camera desktop checks through it without changing touchscreen behavior.
- [ ] Add a failing HUD assertion for QUICK DASH cooldown scaling and DAEMON’s two dash charges.
- [ ] Compute the HUD dash state from the actual player cooldown/charge state rather than fixed `Balance.DASH_CD`.
- [ ] Run the full autotest and verify desktop detection, touch gating, cooldown display, and charge display.
- [ ] Commit: `fix: align wayland detection and dash hud state`

### Task 8: PC/Linux build foundation

**Files:**
- Modify: `export_presets.cfg`
- Modify: `project.godot` only if a desktop setting is required by the export
- Add: `packaging/linux/README.md` with the portable layout and smoke-test command

- [ ] Add a failing release smoke check documenting the expected Linux x86_64 executable plus `.pck` layout.
- [ ] Add a Linux x86_64 export preset without changing Android settings or gameplay.
- [ ] Export a local Linux build, run it headless where possible, and verify the project opens to the menu and the cursor is restored after non-play states.
- [ ] Run the full autotest once more and verify `AUTOTEST_ALL_PASS` with zero `AT_FAIL`.
- [ ] Commit: `build: add portable linux x86_64 export`

## Exit Criteria

- The full autotest prints `AUTOTEST_ALL_PASS` with zero `AT_FAIL`.
- No known production script errors remain in the tested paths.
- First-boss split/reward/heal behavior is covered by regression checks.
- Android restrictions remain unchanged.
- Linux x86_64 export is reproducible and ready for a later `kernel-panic-bin` package.
- Only after this plan is green should `docs/superpowers/plans/2026-08-27-identity-pack.md` be executed.

# KERNEL PANIC Onboarding, AI, Accessibility and QOL Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the approved follow-up review: first-sight onboarding, safe desktop input, qualitative enemy AI, bounded late-wave cadence, accessibility/responsive UI, configurable desktop controls, and patch/Weekly QOL.

**Architecture:** Keep the current Godot scene architecture and extend the existing `Game`, `Arena`, `Hud`, `Sfx`, `Balance`, `Spawner`, and enemy classes through small explicit helpers. Work is split into sequential tasks so shared state has one owner at a time; every task adds a regression probe to the existing headless harness before production code. The debug spawn/skip controller remains a separate future package.

**Tech Stack:** Godot 4.7.2, GDScript, code-drawn `Control` UI, `ConfigFile` local persistence, existing `--autotest` harness, existing desktop bot.

**Spec:** `docs/superpowers/specs/2026-08-28-onboarding-input-safety-design.md`, `docs/superpowers/specs/2026-08-28-enemy-ai-balance-design.md`, `docs/superpowers/specs/2026-08-28-accessibility-responsive-design.md`, `docs/superpowers/specs/2026-08-28-settings-patch-qol-design.md`

## Global Constraints

- Read all four linked specs before implementation; they are authoritative for behavior and scope.
- Preserve the current 17-file AI/HUD package already present in the working tree; capture it in a baseline commit before Task 1.
- Do not add image assets, runtime dependencies, navigation meshes, physics bodies, networking, or a debug controller in this plan.
- UI, hints, palette selection, markers, tooltips, and settings must never consume `Game.rng`; gameplay randomness continues to use the existing seeded stream.
- Mobile behavior must not change: desktop-only settings/keyboard behavior is gated on `Balance.is_desktop_display()` and touch checks; `KP_FORCE_TOUCH`, `KP_FORCE_RETICLE`, and `KP_HINTS` remain valid test controls.
- Do not change the existing touch aim modes, player movement contract, One-HP rules, or patch effects.
- Do not alter wave composition, wave budget, elite chance, max-alive cap, base HP, base damage, projectile damage/speed, or spawn limits. The only intentional difficulty adjustment is the capped cooldown factor in Task 3.
- Boss attack phases and telegraphs retain priority over steering; teleport destinations retain the no-player-overlap safety rule.
- Every task must run `godot --headless --path . -- --autotest` after implementation and require `AUTOTEST_ALL_PASS` with zero `AT_FAIL`; known shutdown leak warnings are recorded but are not failures.
- Every task is implemented and reviewed by an explicitly selected `gpt-5.6-luna` agent. No subagent may spawn another agent.
- Never stage `build/`, `.godot/`, APKs, keystores, credentials, private paths, or the user's handoff files.

## Baseline checkpoint

Before Task 1, run the full autotest and `git diff --check`. Commit only the existing planned source files from the prior enemy-AI/ROOT-HUD package:

```sh
git add src/arena/arena.gd src/autoload/dev_harness.gd src/autoload/game.gd \
  src/enemies/bulwark.gd src/enemies/drone.gd src/enemies/enemy_base.gd \
  src/enemies/firewall.gd src/enemies/lancer.gd src/enemies/oom_killer.gd \
  src/enemies/page_node.gd src/enemies/recursor.gd src/enemies/root_boss.gd \
  src/enemies/spewer.gd src/enemies/splitter.gd src/enemies/trojan.gd \
  src/ui/bestiary_panel.gd src/ui/hud.gd
git commit -m "feat: improve enemy ai and split root hud"
```

Do not stage untracked handoffs, builds, or the four already-committed specs.

---

### Task 1: Unlock bestiary on first sight and add contextual onboarding

**Files:**
- Modify: `src/autoload/game.gd`
- Modify: `src/arena/arena.gd`
- Modify: `src/ui/hud.gd`
- Modify: `src/autoload/dev_harness.gd`
- Modify: `README.md`

**Interfaces:**
- Produces `Game.mark_bestiary_for_enemy(enemy: EnemyBase) -> void`, an idempotent sighting entry point.
- Produces `Game.show_hint_once(id: String) -> bool`, persisted per hint and independent of gameplay RNG.
- `Arena._on_enemy_child` calls the sighting entry point after adding a live enemy; death logging remains safe and idempotent.

- [ ] **Step 1: Write the failing tests**

Add harness probes that construct a regular enemy and a non-mini `RootBoss`, call the child/sighting path before death, and assert the corresponding bestiary ids are unlocked exactly once. Add a first-run hint probe asserting the first call returns true, the second returns false, and a forced `KP_HINTS` path remains available. The probes must fail before the methods and calls exist.

- [ ] **Step 2: Run the test to verify it fails**

Run:

```sh
godot --headless --path . -- --autotest
```

Expected: `AT_FAIL` for the new sighting/hint assertions.

- [ ] **Step 3: Write the minimal implementation**

Load/save a small `tutorial` dictionary through the existing `ConfigFile`. Implement `mark_bestiary_for_enemy()` with the existing display-name and boss-title mapping, skipping mini ROOT duplicates. In `Arena._on_enemy_child`, mark on entry and route these non-blocking messages once: `MOVE // WASD OR TOUCH`, `DASH // SPACE / SHIFT`, `SIDESTEP THE LINE`, `SHOOT THE ORBS DOWN`, and `KILL IT AWAY FROM YOU`. Use the current HUD banner surface with a short queue/rate limit and leave touch hints intact. Update README onboarding wording without changing controls.

- [ ] **Step 4: Run the full verification**

Run the exact autotest command again. Expected: `AUTOTEST_ALL_PASS`, zero `AT_FAIL`, and no new parse errors.

- [ ] **Step 5: Commit**

```sh
git add src/autoload/game.gd src/arena/arena.gd src/ui/hud.gd src/autoload/dev_harness.gd README.md
git commit -m "feat: unlock bestiary entries on first sight"
```

---

### Task 2: Separate overclock from pause-abandon and add confirmation

**Files:**
- Modify: `src/autoload/game.gd`
- Modify: `src/arena/arena.gd`
- Modify: `src/autoload/dev_harness.gd`
- Modify: `README.md`

**Interfaces:**
- Produces `InputMap` action `overclock` with default `E` only and `abandon` with default `Q` only.
- Produces pause confirmation state with a `2.0` second expiry and no effect from `E`.

- [ ] **Step 1: Write the failing tests**

Add harness checks that inspect the physical keycodes for `overclock` and `abandon`, pause a real `Arena`, send an `E` action and assert `Game.state` remains playing, send one `Q` and assert the arena remains active with confirmation armed, then send the second `Q` and assert the menu transition is requested. Assert resume/restart clears the armed state.

- [ ] **Step 2: Run the test to verify it fails**

Run `godot --headless --path . -- --autotest`. Expected: the new action and paused-input assertions fail because `E` and `Q` currently share `overclock` and the paused branch directly calls `Game.to_menu()`.

- [ ] **Step 3: Write the minimal implementation**

Change only the action registration and paused branch: use a dedicated `abandon` action, add an arena `_abandon_armed` flag and countdown, update pause copy to `PRESS Q AGAIN // ABANDON PROCESS`, and call `Game.to_menu()` only on the confirmed second press. Clear it on resume, restart, timeout, game over, and scene teardown. Leave touch buttons and player `overclock` calls unchanged.

- [ ] **Step 4: Run the full verification**

Run the exact autotest command and require `AUTOTEST_ALL_PASS` with zero `AT_FAIL`.

- [ ] **Step 5: Commit**

```sh
git add src/autoload/game.gd src/arena/arena.gd src/autoload/dev_harness.gd README.md
git commit -m "fix: require confirmation before abandoning a run"
```

---

### Task 3: Add bounded cadence and qualitative elite behavior

**Files:**
- Modify: `src/autoload/balance.gd`
- Modify: `src/arena/spawner.gd`
- Modify: `src/enemies/enemy_base.gd`
- Modify: `src/enemies/lancer.gd`
- Modify: `src/enemies/spewer.gd`
- Modify: `src/enemies/root_boss.gd`
- Modify: `src/autoload/dev_harness.gd`

**Interfaces:**
- Produces `Balance.attack_cadence_factor(wave: int) -> float`, equal to `1.0` through wave 5, then decreasing by `0.015` per wave with floor `0.78`.
- Produces `EnemyBase.threat_wave: int` set by `Spawner` before enemy configuration.
- Produces explicit elite profile hooks for `swift` and `volatile`; no elite roll or base stat formula changes.

- [ ] **Step 1: Write the failing tests**

Add assertions for cadence values at waves 1, 5, 6, and 30, including the `0.78` floor. Add an elite probe that configures one `swift` and one `volatile` enemy with a deterministic test RNG state and asserts the profile hooks expose different movement/tempo behavior and the volatile death hazard remains present. Add a LANCER/SPEWER probe showing the cadence factor is applied to repeated intervals while their telegraph durations remain readable.

- [ ] **Step 2: Run the test to verify it fails**

Run the full autotest. Expected: `AT_FAIL` for the missing cadence function/context and the qualitative profile assertions.

- [ ] **Step 3: Write the minimal implementation**

Add the exact capped factor to `Balance`. Pass `wave` through `Spawner` as `threat_wave` without changing queue composition. Refactor elite behavior behind small base hooks: `swift` retains its current speed/ghost identity but gets stronger lateral steering and bounded attack reacquisition; `volatile` retains the existing six-orb death burst and gets an explicit arming/pulse visual. Scale LANCER phase re-entry, SPEWER firing intervals, and repeated ranged-boss cooldowns by the factor; do not shorten attack wind-up telegraphs.

- [ ] **Step 4: Run the full verification**

Run the exact autotest command. Expected: `AUTOTEST_ALL_PASS`, zero `AT_FAIL`.

- [ ] **Step 5: Commit**

```sh
git add src/autoload/balance.gd src/arena/spawner.gd src/enemies/enemy_base.gd \
  src/enemies/lancer.gd src/enemies/spewer.gd src/enemies/root_boss.gd src/autoload/dev_harness.gd
git commit -m "feat: scale enemy cadence and elite behavior by wave"
```

---

### Task 4: Add ranged cover cooperation and contain Splitter elite propagation

**Files:**
- Modify: `src/enemies/enemy_base.gd`
- Modify: `src/enemies/spewer.gd`
- Modify: `src/enemies/splitter.gd`
- Modify: `src/autoload/dev_harness.gd`

**Interfaces:**
- Produces a local `EnemyBase` cover query over `shared_list` that returns a valid Bulwark anchor or `Vector2.ZERO`.
- Spewer consumes the query only when its distance-band/open-space profile is active.

- [ ] **Step 1: Write the failing tests**

Create a player, a SPEWER, and a BULWARK fixture with the Bulwark between the player and Spewer; assert the cover preference points toward a valid point behind/aside the Bulwark. Remove the Bulwark and assert the helper returns zero/falls back to the existing distance-band vector. Configure a Splitter as elite, call its death child path, and assert both child drones are non-elite with an empty `elite_kind`.

- [ ] **Step 2: Run the test to verify it fails**

Run the full autotest. Expected: the cover helper is missing or returns no preference, and Splitter children still inherit `elite`.

- [ ] **Step 3: Write the minimal implementation**

Use only local positions/radii and the exact role name `BULWARK`; require the candidate to be inside `Balance.arena_rect().grow(-radius)`. Bias Spewer's desired vector toward the cover candidate without overriding retreat or telegraph braking. In `SplitterEnemy.die()`, explicitly clear `m.elite` and `m.elite_kind` after `setup_mini()`; retain the existing two-child count and parent volatile behavior.

- [ ] **Step 4: Run the full verification**

Run the exact autotest command and require the full pass marker with zero failures.

- [ ] **Step 5: Commit**

```sh
git add src/enemies/enemy_base.gd src/enemies/spewer.gd src/enemies/splitter.gd src/autoload/dev_harness.gd
git commit -m "feat: coordinate ranged cover and cap splitter elites"
```

---

### Task 5: Make Recursor and boss teleports favor flanking destinations

**Files:**
- Modify: `src/enemies/recursor.gd`
- Modify: `src/enemies/root_boss.gd`
- Modify: `src/autoload/dev_harness.gd`

**Interfaces:**
- Produces a local candidate scorer that accepts player facing/movement vectors and an arena-safe candidate position.
- Preserves the existing random fallback and minimum player distance when no useful heading exists.

- [ ] **Step 1: Write the failing tests**

Place the player with a valid `aim` and `vel`, invoke deterministic teleport candidate selection for RECURSOR and a ranged boss, and assert the selected candidate lies on a flank/behind-facing side rather than directly in front. Also assert every candidate remains inside the inset arena and farther than the existing safety distance from the player.

- [ ] **Step 2: Run the test to verify it fails**

Run the full autotest. Expected: current random/near-player candidate selection fails the flank-direction assertions.

- [ ] **Step 3: Write the minimal implementation**

Build a small deterministic candidate list around the player using the opposite of normalized `aim`, the opposite of normalized movement, and their rotated left/right variants. Score candidates by separation from the facing vector, arena validity, and distance safety; use the current `Game.rng` candidate fallback only when heading data is unavailable. Keep phase timers, corruption placement, boss attacks, and no-overlap checks untouched.

- [ ] **Step 4: Run the full verification**

Run the exact autotest command and require `AUTOTEST_ALL_PASS` with zero `AT_FAIL`.

- [ ] **Step 5: Commit**

```sh
git add src/enemies/recursor.gd src/enemies/root_boss.gd src/autoload/dev_harness.gd
git commit -m "feat: make enemy teleports flank the player"
```

---

### Task 6: Add color assist and redundant Splitter/Bulwark identifiers

**Files:**
- Modify: `src/autoload/balance.gd`
- Modify: `src/autoload/sfx.gd`
- Modify: `src/ui/menu.gd`
- Modify: `src/enemies/splitter.gd`
- Modify: `src/enemies/bulwark.gd`
- Modify: `src/ui/bestiary_panel.gd`
- Modify: `src/autoload/dev_harness.gd`

**Interfaces:**
- Produces persisted `Sfx.color_assist: bool` and a shared palette helper used by combat and bestiary rendering.
- Produces code-drawn `S`/`B` identity markers in color-assist mode without changing hitboxes.

- [ ] **Step 1: Write the failing tests**

Add harness checks that standard Splitter/Bulwark colors are distinct, the color-assist palette returns a distinct accessible pair, the setting persists through reload, and both draw scripts expose their marker path without loading an image. Assert default mode remains standard.

- [ ] **Step 2: Run the test to verify it fails**

Run the full autotest. Expected: no color-assist setting/palette contract and no marker assertions pass.

- [ ] **Step 3: Write the minimal implementation**

Add the shared palette values and config load/save in the existing Sfx settings pattern. Add one menu toggle labelled `COLOR ASSIST: OFF/ON`. Route Splitter, Bulwark, and their bestiary entries through the helper; in assist mode draw compact `SPLIT`/`BULW` marker glyphs or equivalent one-letter markers alongside the existing circle/diamond silhouettes. Do not change enemy stats or touch controls.

- [ ] **Step 4: Run the full verification**

Run the exact autotest command; require `AUTOTEST_ALL_PASS` and zero `AT_FAIL`.

- [ ] **Step 5: Commit**

```sh
git add src/autoload/balance.gd src/autoload/sfx.gd src/ui/menu.gd \
  src/enemies/splitter.gd src/enemies/bulwark.gd src/ui/bestiary_panel.gd src/autoload/dev_harness.gd
git commit -m "feat: add color assist threat markers"
```

---

### Task 7: Make HUD/panels responsive and scale the movement stick

**Files:**
- Modify: `src/ui/hud.gd`
- Modify: `src/arena/arena.gd`
- Modify: `src/ui/touch_controls.gd`
- Modify: `src/autoload/dev_harness.gd`

**Interfaces:**
- Produces viewport-relative bottom positions for HUD resources, patch chips, dash text, and boss bars.
- Produces one scaled movement-stick geometry helper driven by `Sfx.touch_scale` while preserving normalized movement vectors.

- [ ] **Step 1: Write the failing tests**

Add harness probes that set a HUD to two viewport heights and assert the boss bar/dash baseline moves with `size.y`. Exercise touch scale values `0.85`, `1.0`, and `1.2`, assert the movement radius/deadzone/draw knob scale together, and assert an input offset normalized at each scale produces the same vector.

- [ ] **Step 2: Run the test to verify it fails**

Run the full autotest. Expected: fixed `676/688` HUD coordinates and hardcoded `110/90/64` stick geometry fail the new assertions.

- [ ] **Step 3: Write the minimal implementation**

Introduce HUD layout helpers based on `size.y` and safe margins, use them in `_hp_pips`, `_oc_bar`, `_patch_chips`, `_dash_pip`, `_boss_bar`, and `_boss_split_bar`, and convert pause/game-over/patch panel vertical placement to centered or viewport-relative offsets. In TouchControls derive movement travel radius, normalization divisor, draw radius, and knob radius from `_sc()`; divide by the scaled divisor so the resulting normalized vector is unchanged. Preserve aim geometry and mobile side placement.

- [ ] **Step 4: Run the full verification**

Run the exact autotest command and require `AUTOTEST_ALL_PASS` with zero `AT_FAIL`.

- [ ] **Step 5: Commit**

```sh
git add src/ui/hud.gd src/arena/arena.gd src/ui/touch_controls.gd src/autoload/dev_harness.gd
git commit -m "fix: make combat ui follow viewport and touch scale"
```

---

### Task 8: Add desktop key remapping with conflict-safe persistence

**Files:**
- Modify: `src/autoload/game.gd`
- Modify: `src/ui/menu.gd`
- Modify: `src/autoload/dev_harness.gd`
- Modify: `README.md`

**Interfaces:**
- Produces one keyboard action registry with defaults and saved physical keycodes.
- Produces settings capture state: next valid key assigns, `Escape` cancels, duplicates reject, `RESET KEYBINDS` restores defaults.

- [ ] **Step 1: Write the failing tests**

Add harness checks for default action registry creation, save/load of a physical keycode, duplicate rejection without changing the original action, Escape cancellation, and reset-to-default. Assert the capture panel is hidden on touch/forced-touch and visible only on desktop.

- [ ] **Step 2: Run the test to verify it fails**

Run the full autotest. Expected: no saved key registry/capture/reset behavior exists.

- [ ] **Step 3: Write the minimal implementation**

Define defaults for movement, dash, overclock, pause, abandon, mute, restart, and confirm. Load integer physical keycodes from a `controls` ConfigFile section before populating `InputMap`; use the existing default values for old saves. Add a desktop-only code-drawn settings capture row with conflict text and reset action. Do not remap mouse fire/aim and do not process the capture UI on touch.

- [ ] **Step 4: Run the full verification**

Run the exact autotest command. Expected: `AUTOTEST_ALL_PASS`, zero `AT_FAIL`.

- [ ] **Step 5: Commit**

```sh
git add src/autoload/game.gd src/ui/menu.gd src/autoload/dev_harness.gd README.md
git commit -m "feat: add desktop key remapping"
```

---

### Task 9: Add patch tooltips and remove the obsolete Weekly lock-on block

**Files:**
- Modify: `src/autoload/game.gd`
- Modify: `src/ui/hud.gd`
- Modify: `src/ui/menu.gd`
- Modify: `src/autoload/dev_harness.gd`
- Modify: `README.md`

**Interfaces:**
- Produces static patch relation metadata for the HUD tooltip, including the HEAVY/SPLITSHOT fire-rate tradeoff.
- Produces desktop hover and 0.45-second touch-hold tooltip behavior without pause or RNG.
- `Game.effective_aim_mode()` returns the saved lock-on mode in Weekly.

- [ ] **Step 1: Write the failing tests**

Add harness checks that retrieve a patch chip's full title/description/level, expose its documented synergy/tradeoff, and reject unknown relation claims. Simulate desktop hover and a touch hold shorter/longer than `0.45` seconds. Change the Weekly lock-on regression to expect `lockon` rather than `stick` while preserving the saved preference.

- [ ] **Step 2: Run the test to verify it fails**

Run the full autotest. Expected: current two-letter chips have no tooltip metadata and Weekly intentionally downgrades lock-on.

- [ ] **Step 3: Write the minimal implementation**

Add static relation text to patch metadata without changing any patch effect or roll weight. Track chip rectangles in HUD, show a code-drawn tooltip on desktop hover and after a 0.45-second touch hold, and dismiss it on movement/release; keep `mouse_filter`/touch behavior safe for the arena. Remove the Weekly downgrade branch and update menu copy/tests/README to describe local deterministic Weekly play.

- [ ] **Step 4: Run the full verification**

Run the exact autotest command and require `AUTOTEST_ALL_PASS` with zero `AT_FAIL`.

- [ ] **Step 5: Commit**

```sh
git add src/autoload/game.gd src/ui/hud.gd src/ui/menu.gd src/autoload/dev_harness.gd README.md
git commit -m "feat: explain active patches and allow weekly lockon"
```

---

### Task 10: Run final desktop smoke, regression, and scope review

**Files:**
- Modify: none unless a test-only assertion is demonstrably unstable; then only `src/autoload/dev_harness.gd`.
- Verify: all files from Tasks 1–9 and the existing `KP_DEMO` harness.

**Interfaces:**
- Consumes all new persistence, AI, UI, and settings contracts.
- Produces final evidence for tests, desktop demo, mobile gates, and clean scoped diff.

- [ ] **Step 1: Run the full autotest once more**

```sh
godot --headless --path . -- --autotest
```

Require exit `0`, `AUTOTEST_ALL_PASS`, and zero `AT_FAIL`. Record known shutdown leak warnings separately.

- [ ] **Step 2: Run bounded desktop smoke**

```sh
KP_DEMO=/tmp/kernel-panic-followup-demo KP_DEMO_TIME=180 godot --headless --path .
```

Review `DEMO` telemetry for wave, HP, alive, motes, FPS, and process time. If the normal bot dies before a boss, record that honestly; use targeted harness checks for boss behavior and do not change balance to force an observation.

- [ ] **Step 3: Inspect final diff and platform gates**

```sh
git diff --check
git status --short
git diff --stat 27bb4a6..HEAD
```

Confirm no spec file changed after approval, no `player.gd` changed, no `.godot/`/build/handoff files are staged, and only planned source/README files are in the package commits.

- [ ] **Step 4: Review and finish**

Generate the SDD review package from the merge base, dispatch one final whole-branch Luna reviewer, fix at most one final review wave through a Luna implementer plus scoped re-review, then use `superpowers:finishing-a-development-branch` to choose integration. If the final review parks a non-load-bearing observation, record the ruling and cost in the ledger.


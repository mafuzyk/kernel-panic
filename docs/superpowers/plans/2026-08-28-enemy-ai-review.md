# KERNEL PANIC Enemy AI Review + ROOT Split HUD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every enemy a readable role-based steering profile and keep the first ROOT's two mini health bars visible as one combined HUD encounter.

**Architecture:** Add stateless local steering helpers to `EnemyBase`, then let each existing enemy state machine combine those helpers with its current attacks. `Arena` owns the active boss encounter state, while `Hud` renders either the normal single boss bar or two mini rows; `Game` and `BestiaryPanel` receive stable records for every boss variant.

**Tech Stack:** Godot 4.7.2, GDScript, existing `EnemyBase.shared_list`, existing headless autotest harness, code-drawn HUD/bestiary.

**Spec:** `docs/superpowers/specs/2026-08-28-enemy-ai-review-design.md`

## Global Constraints

- Preserve each enemy's identity and keep the first pass behavior-only.
- Do not change base HP, damage, fire rate, wave budget, elite chance, spawn limits, or difficulty knobs.
- Do not modify `src/player/player.gd`.
- Keep mobile/touch controls and lock-on behavior unchanged.
- Do not add a navigation mesh, runtime dependency, image asset, or physics body.
- Do not add new `Game.rng` calls to cosmetic/UI code; steering must be deterministic for the same positions and state.
- Keep existing attack state machines and telegraphs authoritative over movement steering.
- Run `godot --headless --path . -- --autotest` after every task and require `AUTOTEST_ALL_PASS` with zero `AT_FAIL`.
- Never stage handoffs, build outputs, `.godot/`, credentials, or private paths.

## File Map

- `src/enemies/enemy_base.gd`: stateless approach, distance-band, and early-separation vectors.
- `src/enemies/drone.gd`, `lancer.gd`, `splitter.gd`, `bulwark.gd`: melee approach profiles.
- `src/enemies/spewer.gd`, `page_node.gd`, `recursor.gd`: ranged/offset profiles.
- `src/enemies/trojan.gd`, `oom_killer.gd`, `firewall.gd`: special-role steering.
- `src/enemies/root_boss.gd`: boss hover profiles, mini separation, and split signal.
- `src/arena/arena.gd`: boss encounter ownership and split lifecycle.
- `src/ui/hud.gd`: single or two-row combined boss-bar rendering.
- `src/autoload/game.gd`, `src/ui/bestiary_panel.gd`: stable boss-variant records and unlock mapping.
- `src/autoload/dev_harness.gd`: failing regression checks and bot-observable assertions.

---

### Task 1: Add shared steering primitives

**Files:**
- Modify: `src/enemies/enemy_base.gd` after `aim_at_player()`/`dist_to_player()` helpers.
- Modify: `src/autoload/dev_harness.gd` in the existing enemy-system test section.

**Interfaces:**
- Consumes: a target delta, local enemy positions, and the existing `EnemyBase.shared_list`.
- Produces: `steer_approach()`, `steer_distance_band()`, and `steer_separation()` returning normalized `Vector2` directions for enemy state machines.

- [ ] **Step 1: Write the failing test**

Immediately before the existing enemy construction checks, add deterministic probes that call the new contract. The probes must not add nodes or consume gameplay RNG:

```gdscript
	var steering_probe := EnemyBase.new()
	var retreat_dir := steering_probe.steer_distance_band(Vector2(40, 0), 150.0, 300.0, 1.0)
	_check(retreat_dir.dot(Vector2.LEFT) > 0.7, "distance band retreats when target is too close")
	var hold_dir := steering_probe.steer_distance_band(Vector2(220, 0), 150.0, 300.0, 1.0)
	_check(absf(hold_dir.dot(Vector2.RIGHT)) < 0.8 and hold_dir.length() > 0.9, "distance band strafes inside the band")
	var approach_dir := steering_probe.steer_approach(Vector2(220, 0), 0.0, 0.0)
	_check(approach_dir.dot(Vector2.RIGHT) > 0.99, "approach steering points at target")
	EnemyBase.shared_list = [steering_probe]
	var neighbor := EnemyBase.new()
	neighbor.position = Vector2(24, 0)
	steering_probe.position = Vector2.ZERO
	EnemyBase.shared_list.append(neighbor)
	_check(steering_probe.steer_separation(3.0).dot(Vector2.LEFT) > 0.7, "separation pushes away from nearby enemy")
	EnemyBase.shared_list = arena.enemy_list
	steering_probe.free()
	neighbor.free()
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```sh
godot --headless --path . -- --autotest
```

Expected: the run reaches the new steering checks and fails with parse/runtime errors because the three methods do not exist. Fix only test placement or syntax if the failure is unrelated; do not add production methods yet.

- [ ] **Step 3: Write the minimal implementation**

Add these exact methods to `EnemyBase`. They return unit vectors, use no random source, and leave speed/acceleration to each caller:

```gdscript
func steer_approach(to_target: Vector2, lateral_sign: float = 0.0, lateral_weight: float = 0.0) -> Vector2:
	if to_target.length_squared() <= 0.0001:
		return Vector2.ZERO
	var radial := to_target.normalized()
	return (radial + radial.orthogonal() * lateral_sign * lateral_weight).normalized()

func steer_distance_band(to_target: Vector2, min_distance: float, max_distance: float, lateral_sign: float, lateral_weight: float = 0.85) -> Vector2:
	if to_target.length_squared() <= 0.0001:
		return Vector2.ZERO
	var radial := to_target.normalized()
	var distance := to_target.length()
	if distance < min_distance:
		radial = -radial
	elif distance <= max_distance:
		radial = Vector2.ZERO
	return (radial + to_target.normalized().orthogonal() * lateral_sign * lateral_weight).normalized()

func steer_separation(radius_scale: float = 2.0) -> Vector2:
	var push := Vector2.ZERO
	for other in shared_list:
		if other == self or not is_instance_valid(other):
			continue
		var delta := global_position - other.global_position
		var distance := delta.length()
		var safe_radius := radius + other.radius
		var threshold := safe_radius * radius_scale
		if distance > 0.01 and distance < threshold:
			push += delta / distance * (1.0 - distance / threshold)
	return push.normalized() if push.length_squared() > 0.0001 else Vector2.ZERO
```

- [ ] **Step 4: Run the full verification**

Run the same headless autotest. Expected: `AUTOTEST_ALL_PASS`, zero `AT_FAIL`, and no changes to existing gameplay checks.

- [ ] **Step 5: Commit**

```sh
git add src/enemies/enemy_base.gd src/autoload/dev_harness.gd
git commit -m "feat: add shared enemy steering helpers"
```

---

### Task 2: Apply role steering to melee and ranged regular enemies

**Files:**
- Modify: `src/enemies/drone.gd`, `src/enemies/lancer.gd`, `src/enemies/splitter.gd`, `src/enemies/bulwark.gd`.
- Modify: `src/enemies/spewer.gd`, `src/enemies/page_node.gd`.
- Modify: `src/autoload/dev_harness.gd` in the enemy behavior test area.

**Interfaces:**
- Consumes: `EnemyBase.steer_approach()`, `steer_distance_band()`, and `steer_separation()` from Task 1.
- Produces: melee enemies that approach without stacking and ranged enemies that retreat/strafe inside explicit distance bands.

- [ ] **Step 1: Write the failing tests**

Add checks that use real enemy instances and call their existing `_move()` state, with no attack timers due:

```gdscript
	var ai_player := Node2D.new()
	ai_player.position = Vector2.ZERO
	arena.add_child(ai_player)
	var ranged_probe := PageNode.new()
	ranged_probe.player = ai_player
	ranged_probe.position = Vector2(80, 0)
	ranged_probe._fire_t = 99.0
	ranged_probe._move(0.1)
	_check(ranged_probe._v.dot(Vector2.RIGHT) > 0.0, "page node retreats inside minimum range")
	var melee_a := DroneEnemy.new()
	var melee_b := DroneEnemy.new()
	melee_a.player = ai_player
	melee_b.player = ai_player
	melee_a.position = Vector2(80, 0)
	melee_b.position = Vector2(80, 16)
	EnemyBase.shared_list = [melee_a, melee_b]
	melee_a._move(0.1)
	_check(absf(melee_a.vel().y) > 0.01, "melee steering separates from a nearby ally")
	EnemyBase.shared_list = arena.enemy_list
	ranged_probe.free()
	melee_a.free()
	melee_b.free()
	ai_player.free()
```

	These checks fail against the current PageNode close-range drift and the current Drone direct chase, before the profile edits.

- [ ] **Step 2: Run the test to verify it fails**

Run the full autotest and record the specific `AT_FAIL` lines. The PageNode probe is intentionally close enough that its current direct drift points toward the player; the melee probe is placed above the player-facing line so the current direct chase has zero lateral velocity.

- [ ] **Step 3: Write the minimal implementations**

Replace direct chase vectors with the following profile shapes while keeping every existing speed and acceleration value unchanged:

```gdscript
# Melee _move(delta) body shape.
var desired := steer_approach(aim_at_player(), 1.0, 0.35)
desired += steer_separation(2.2) * 0.7
_v = _v.move_toward(desired.limit_length(1.0) * speed, 380.0 * delta)
```

Use the existing enemy-specific acceleration in each file: DRONE keeps `620.0`, LANCER keeps `500.0` in `APPROACH`, SPLITTER keeps `380.0`, and BULWARK keeps `200.0`.

For SPEWER, retain `BAND_MIN`/`BAND_MAX` and replace the local radial calculation with:

```gdscript
var desired := steer_distance_band(to_p, BAND_MIN, BAND_MAX, _strafe_dir, 0.85)
desired += steer_separation(2.2) * 0.65
_v = _v.move_toward(desired.limit_length(1.0) * speed, 420.0 * delta)
```

For `PageNode` without a valid boss anchor, use `steer_distance_band(player.global_position - global_position, 170.0, 300.0, 1.0, 0.65)` and preserve its current fire timing. Its boss-orbit path remains unchanged.

- [ ] **Step 4: Run the full verification**

Run `godot --headless --path . -- --autotest`. Expected: `AUTOTEST_ALL_PASS`; existing shooting, collision, touch, and boss checks remain green.

- [ ] **Step 5: Commit**

```sh
git add src/enemies/drone.gd src/enemies/lancer.gd src/enemies/splitter.gd src/enemies/bulwark.gd src/enemies/spewer.gd src/enemies/page_node.gd src/autoload/dev_harness.gd
git commit -m "feat: apply role based steering to regular enemies"
```

---

### Task 3: Improve special-enemy positioning

**Files:**
- Modify: `src/enemies/trojan.gd`, `src/enemies/oom_killer.gd`, `src/enemies/firewall.gd`, `src/enemies/recursor.gd`.
- Modify: `src/autoload/dev_harness.gd` in the existing `newenemies` and `oom` sections.

**Interfaces:**
- Consumes: shared steering primitives and each special enemy's current state machine.
- Produces: route-aware TROJAN movement, collision-resistant OOM pursuit/flee, stable FIREWALL anchoring, and offset RECURSOR stalking.

- [ ] **Step 1: Write the failing tests**

Add behavior checks before the current construction assertions:

```gdscript
	var special_player := Node2D.new()
	special_player.position = Vector2.ZERO
	arena.add_child(special_player)
	var trojan_probe := TrojanEnemy.new()
	trojan_probe.player = special_player
	trojan_probe.position = Vector2(180, 0)
	trojan_probe._move(0.1)
	_check(absf(trojan_probe.vel().dot(Vector2.LEFT)) < trojan_probe.vel().length(), "trojan approaches with route offset")
	var recursor_probe := load("res://src/enemies/recursor.gd").new()
	recursor_probe.player = special_player
	recursor_probe.position = Vector2(80, 0)
	recursor_probe.phase_t = 99.0
	recursor_probe._move(0.1)
	_check(recursor_probe.vel().dot(Vector2.LEFT) <= 0.0, "recursor does not blindly converge at close range")
	EnemyBase.shared_list = arena.enemy_list
	trojan_probe.free()
	recursor_probe.free()
	special_player.free()
```

The first test should fail against the current centerline-only TROJAN vector; the second should fail when the RECURSOR is close enough to require retreat/offset steering.

- [ ] **Step 2: Run the test to verify it fails**

Run the full autotest and confirm the failures identify the intended special-enemy movement behavior, not a construction or parse error.

- [ ] **Step 3: Write the minimal implementations**

Use a stable lateral sign derived from the current relative position, not a new random roll:

```gdscript
var to_player := player.global_position - global_position if player != null else Vector2.ZERO
var route_sign := -1.0 if global_position.y >= player.global_position.y else 1.0
var desired := steer_approach(to_player, route_sign, 0.6)
desired += steer_separation(2.4) * 0.7
_v = _v.move_toward(desired.limit_length(1.0) * speed, 240.0 * delta)
```

For OOM_KILLER, add `steer_separation(2.4)` to the selected-mote pursuit vector and to the escape vector without changing target selection, stolen slots, or flee speed. For FIREWALL, keep its anchor/ownership model and add separation only while traveling to the anchor; its settled wall remains stationary while the existing `_wall_angle` continues to rotate. For RECURSOR's `STALK` phase, use `steer_distance_band(to_player, 170.0, 330.0, 1.0, 0.55)` plus early separation, preserving all teleport timing and the no-player-position destination guard.

- [ ] **Step 4: Run the full verification**

Run the headless autotest. Expected: `AUTOTEST_ALL_PASS`; OOM theft/release, FIREWALL orb ownership/rotation, and RECURSOR teleport checks remain green.

- [ ] **Step 5: Commit**

```sh
git add src/enemies/trojan.gd src/enemies/oom_killer.gd src/enemies/firewall.gd src/enemies/recursor.gd src/autoload/dev_harness.gd
git commit -m "feat: improve special enemy positioning"
```

---

### Task 4: Add boss profiles and mini-ROOT separation

**Files:**
- Modify: `src/enemies/root_boss.gd`.
- Modify: `src/autoload/dev_harness.gd` in the boss regression sections.

**Interfaces:**
- Consumes: shared steering helpers and the existing boss `kind`, `phase`, and mini state.
- Produces: `signal split_started(minis: Array)`, stable mini slots, ranged hover profiles for SEGFAULT/BLUE SCREEN/PAGE FAULT, and separated mini movement.

- [ ] **Step 1: Write the failing tests**

Add the following checks to the boss behavior test after constructing a configured boss:

```gdscript
	var ranged_boss := RootBoss.new()
	ranged_boss.boss_index = 3
	ranged_boss.configure(1.0, false)
	ranged_boss.player = player
	ranged_boss.position = player.global_position + Vector2(70, 0)
	ranged_boss._move(0.1)
	_check(ranged_boss.vel().dot(Vector2.RIGHT) > 0.0, "ranged boss backs away when player is too close")
	var split_seen := []
	var split_signal_boss := RootBoss.new()
	split_signal_boss.boss_index = 1
	split_signal_boss.configure(1.0, false)
	split_signal_boss.split_started.connect(func(minis: Array) -> void: split_seen = minis)
	split_signal_boss.player = player
	split_signal_boss.position = player.global_position + Vector2(220, 0)
	arena.enemy_container.add_child(split_signal_boss)
	await _ticks(1)
	split_signal_boss._split_into_minis()
	_check(split_seen.size() == 2, "root split reports both mini instances")
	if split_seen.size() == 2:
		_check(split_seen[0].position.distance_to(split_seen[1].position) > 52.0, "root minis start separated")
	EnemyBase.shared_list = arena.enemy_list
	ranged_boss.free()
	split_signal_boss.free()
```

- [ ] **Step 2: Run the test to verify it fails**

Run the full autotest. Expected: the ranged boss check and `split_started` check fail because the current hover converges and the split has no signal/slot contract.

- [ ] **Step 3: Write the minimal implementation**

Add:

```gdscript
signal split_started(minis: Array)
var _mini_side := 1.0
```

In normal `HOVER`, use `steer_approach()` for ROOT kind 1 and `steer_distance_band(to_player, 190.0, 360.0, -1.0 if kind % 2 == 0 else 1.0, 0.7)` for kinds 2–4, then retain the existing speed/acceleration and attack priority. In `_split_into_minis()`, assign `_mini_side` to `-1.0` and `1.0`, set a stable `mini_slot` metadata value, create both nodes in an `Array`, and emit `split_started(minis)` after scheduling them. In `_move_mini()`, combine the mini's current Lancer-like behavior with:

```gdscript
var to_player := player.global_position - global_position if player != null else Vector2.ZERO
var desired := steer_distance_band(to_player, 150.0, 300.0, _mini_side, 0.8)
desired += steer_separation(3.0) * 0.95
_v = _v.move_toward(desired.limit_length(1.0) * speed * 2.0, 520.0 * delta)
```

Attack phases remain unchanged and keep priority over the hover vector.

- [ ] **Step 4: Run the full verification**

Run the full headless suite. Expected: `AUTOTEST_ALL_PASS`; charge, lance, shield, split reward, and mini multi-hit checks remain green.

- [ ] **Step 5: Commit**

```sh
git add src/enemies/root_boss.gd src/autoload/dev_harness.gd
git commit -m "feat: add boss profiles and root mini steering"
```

---

### Task 5: Keep the split ROOT visible with two combined bars

**Files:**
- Modify: `src/arena/arena.gd` (`_on_boss_spawned`, `_on_enemy_died`, and encounter callbacks).
- Modify: `src/ui/hud.gd` (`boss` state, `_process`, and boss-bar drawing).
- Modify: `src/autoload/dev_harness.gd` in the boss split regression section.

**Interfaces:**
- Consumes: `RootBoss.split_started(minis: Array)` from Task 4 and the existing single-boss HUD flow.
- Produces: `Hud.set_boss_fragments(minis: Array)`, `Hud.clear_boss_encounter()`, and two stable mini rows under `ROOT.exe // FORKED`.

- [ ] **Step 1: Write the failing tests**

Add checks after the root split is triggered:

```gdscript
	_check(arena.hud.boss != null, "boss hud tracks root before split")
	root._split_into_minis()
	await _ticks(2)
	_check(arena.hud._boss_fragments.size() == 2, "boss hud tracks both root minis")
	_check(arena.hud._boss_split, "boss hud enters forked layout")
	_check(arena.hud._boss_name == "ROOT.exe // FORKED", "boss hud labels the forked root")
	root.queue_free()
	await _ticks(2)
	_check(arena.hud._boss_split, "forked boss hud survives original root cleanup")
```

- [ ] **Step 2: Run the test to verify it fails**

Run the full autotest. Expected: the current HUD has no `_boss_fragments`/`_boss_split` state and loses its boss reference when the original ROOT is freed.

- [ ] **Step 3: Write the minimal implementation**

In `Hud`, add:

```gdscript
var _boss_fragments: Array[RootBoss] = []
var _boss_split := false

func set_boss_fragments(minis: Array) -> void:
	_boss_fragments.clear()
	for mini in minis:
		if mini is RootBoss:
			_boss_fragments.append(mini)
	_boss_fragments.sort_custom(func(a: RootBoss, b: RootBoss) -> bool:
			return int(a.get_meta("mini_slot", 0)) < int(b.get_meta("mini_slot", 0)))
	_boss_split = _boss_fragments.size() > 0
	_boss_name = "ROOT.exe // FORKED"

func clear_boss_encounter() -> void:
	boss = null
	_boss_fragments.clear()
	_boss_split = false
	_boss_frac = -1.0
	_boss_name = ""
```

Update `_process()` to prune freed fragments and keep `_boss_split` true while at least one valid mini remains. Draw `_boss_split_bar()` before the normal bar when active; it must render the 500px shared container as two 7px rows with `MINI-A`/`MINI-B` labels and each row's own `ceil(hp / max_hp * 20)` filled segments. In `Arena._on_boss_spawned`, connect `boss.split_started` to a callback that calls `hud.set_boss_fragments(minis)`. In `_on_enemy_died`, remove dead minis from the HUD list and call `hud.clear_boss_encounter()` only inside the final `boss_reward` path. Preserve the existing one-reward logic.

- [ ] **Step 4: Run the full verification**

Run the headless autotest. Expected: `AUTOTEST_ALL_PASS`; no cursor, pause, game-over, reward, or touch regressions.

- [ ] **Step 5: Commit**

```sh
git add src/arena/arena.gd src/ui/hud.gd src/autoload/dev_harness.gd
git commit -m "feat: keep root split health bars visible"
```

---

### Task 6: Complete boss-variant bestiary coverage

**Files:**
- Modify: `src/autoload/game.gd` (`BESTIARY_MAP`, mapping helper, and `mark_bestiary`).
- Modify: `src/arena/arena.gd` in `_on_enemy_died`.
- Modify: `src/ui/bestiary_panel.gd` (`ENTRIES`, `_entry_color`, and `_draw_glyph`).
- Modify: `src/autoload/dev_harness.gd` in the initial bestiary checks.

**Interfaces:**
- Consumes: `RootBoss.boss_title`, existing regular enemy display names, and the persistent bestiary dictionary.
- Produces: stable ids `root`, `segfault`, `bluescreen`, and `pagefault`, separate code-drawn records, and unlocks for every current enemy/boss variant.

- [ ] **Step 1: Write the failing tests**

Replace the current bestiary-only check with:

```gdscript
	var required_bestiary_ids := ["drone", "lancer", "spewer", "splitter", "bulwark", "trojan", "oom", "boss", "recursor", "firewall", "root", "segfault", "bluescreen", "pagefault"]
	var entry_ids := {}
	for entry in BestiaryPanel.ENTRIES:
		entry_ids[entry["id"]] = true
	var bestiary_complete := true
	for id in required_bestiary_ids:
		if not entry_ids.has(id):
			bestiary_complete = false
	_check(bestiary_complete, "bestiary lists every current enemy and boss variant")
	_check(Game.BESTIARY_MAP.get("ROOT.exe", "") == "root", "root boss variant maps to bestiary")
	_check(Game.BESTIARY_MAP.get("SEGFAULT", "") == "segfault", "segfault maps to bestiary")
	_check(Game.BESTIARY_MAP.get("BLUE SCREEN", "") == "bluescreen", "blue screen maps to bestiary")
	_check(Game.BESTIARY_MAP.get("PAGE FAULT", "") == "pagefault", "page fault maps to bestiary")
```

- [ ] **Step 2: Run the test to verify it fails**

Run the full autotest. Expected: the four variant entry/map checks fail against the aggregate-only ROOT catalog.

- [ ] **Step 3: Write the minimal implementation**

Add four records with these exact ids and stable display names:

```gdscript
{"id": "root", "name": "ROOT.exe", "desc": "splits at half integrity. track both processes.", "threat": 2500, "bugs": "forks once. both children are real."},
{"id": "segfault", "name": "SEGFAULT", "desc": "glitches, teleports, then opens a lance line.", "threat": 5000, "bugs": "address is invalid. movement is not."},
{"id": "bluescreen", "name": "BLUE SCREEN", "desc": "freezes systems and floods the arena with fan shots.", "threat": 7500, "bugs": "the error is blue. the projectiles are not."},
{"id": "pagefault", "name": "PAGE FAULT", "desc": "pages shield it until the orbiting nodes are purged.", "threat": 10000, "bugs": "read protection enabled. delete the pages."},
```

Extend the map with exact base names and update `mark_bestiary()` to accept boss titles with an optional ` MK-N` suffix by matching the longest known prefix. In `Arena._on_enemy_died`, keep logging `e.display_name` for the aggregate ROOT record and additionally call `Game.mark_bestiary(e.boss_title)` for non-mini `RootBoss` instances. Add variant colors/glyph branches to `BestiaryPanel` while preserving locked `???` rendering and mobile scrolling.

- [ ] **Step 4: Run the full verification**

Run the headless autotest. Expected: `AUTOTEST_ALL_PASS`; existing bestiary, score, boss reward, and menu tests remain green.

- [ ] **Step 5: Commit**

```sh
git add src/autoload/game.gd src/arena/arena.gd src/ui/bestiary_panel.gd src/autoload/dev_harness.gd
git commit -m "feat: add boss variants to bestiary"
```

---

### Task 7: Run desktop bot observation and final regression verification

**Files:**
- Modify: none unless a test-only assertion must be corrected for an observed lifecycle race.
- Verify: all files from Tasks 1–6 and the existing `KP_DEMO` harness.

**Interfaces:**
- Consumes: completed steering profiles, split HUD, bestiary mappings, and the existing autopilot.
- Produces: evidence that behavior remains readable through cycle 20 and a clean final tree ready for a later balance plan.

- [ ] **Step 1: Run the full autotest once more**

```sh
godot --headless --path . -- --autotest
```

Require `AUTOTEST_ALL_PASS` and zero `AT_FAIL`. Existing RID/ObjectDB leak warnings at process shutdown are recorded but are not test failures.

- [ ] **Step 2: Run the bot observation**

Use the existing autopilot for a bounded desktop run:

```sh
KP_DEMO=/tmp/kernel-panic-ai-demo KP_DEMO_TIME=120 godot --headless --path .
```

Review the `DEMO` lines for `alive`, `motes`, `wave`, and `hp`. Confirm the run reaches the first boss or exits only through the existing game-over path; record whether ranged enemies retreat, whether mini-ROOTs remain distinct, and whether alive counts spike due to stacking. Do not change gameplay values from this observation.

- [ ] **Step 3: Inspect the final diff**

```sh
git diff --check
git status --short
git diff --stat 941319e..HEAD
```

Expected: no whitespace errors; only the planned enemy, arena, HUD, game, bestiary, and harness files are changed by this package. Existing handoffs, docs, builds, and `.godot/` remain unstaged.

- [ ] **Step 4: Commit any test-only correction**

If a lifecycle assertion required a correction during the previous task, stage only `src/autoload/dev_harness.gd` and commit it with:

```sh
git add src/autoload/dev_harness.gd
git commit -m "test: stabilize enemy AI regression harness"
```

Otherwise, create no additional commit.

## Follow-up review backlog (post-package)

The user supplied a critical gameplay/UI/UX review on 2026-08-28. Keep these
items for a separate follow-up plan after this behavior-only package:

- Onboarding: first-run tutorial or contextual spawn hints, and unlock basic
  bestiary guidance on first sight rather than first kill.
- Build comprehension: show patch names/synergies and explain anti-synergies.
- Desktop settings: key remapping, plus a dedicated confirmed abandon action
  so the combat overclock key cannot abandon a paused run.
- Accessibility: stronger Splitter/Bulwark contrast, redundant non-color
  indicators, and a possible color-blind mode.
- Difficulty/AI follow-up: qualitative elite behaviors, carefully bounded
  wave-scaled attack cadence, role cooperation, Splitter elite budget review,
  and tactical flanking destinations for Recursor/boss teleports. Any numeric
  changes require a separate balance decision.
- Responsive UI: verify fixed HUD/panel coordinates on expanded viewports and
  make the movement stick respect TOUCH SIZE.
- Weekly mode: revisit the lock-on restriction only alongside a real scoring
  or leaderboard product decision.
- Debug/QA controls: add a desktop-only debug harness mode to skip waves and
  spawn selected regular enemies, bosses, and ROOT split states on demand,
  so movement and HUD scenarios can be observed without waiting through the
  normal progression. Keep it gated out of release/mobile behavior.

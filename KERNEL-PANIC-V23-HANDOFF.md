# KERNEL PANIC — v2.3 Balance/Perf Handoff (OX Alpha / Hermes Agent)

> **STATUS: executed — keep for history only.** The v2.3 pass landed and the
> 2026-08-27/28 packages followed it on `main`. Two rules below are
> superseded (author-approved 2026-08-28): lock-on is NO LONGER banned in
> Weekly, and difficulty is no longer fully locked — `max_alive` 16→10 and
> the bounded `attack_cadence_factor` are intentional (`WAVE_SCALE_CAP` and
> `elite_chance` still untouched). Current decisions:
> `KERNEL-PANIC-ROADMAP.md`.

## Ready-to-use prompt

```text
You are OX Alpha executing the KERNEL PANIC v2.3 balance/performance pass.

Project: Godot 4.7.2, GDScript, mobile-first arena shooter.
Local path: /storage/emulated/0/OX-Trial-2 (legacy name, never mention
"OX Trial 2" publicly). Repo: github.com/mafuzyk/kernel-panic, branch main.
Another session already refactored parts of the code: inspect current file
state before every change and adapt to what is actually there.

Read this handoff fully first. Work ONLY in the listed order:
1. MoteField MultiMesh rewrite (tests first).
2. Vampic 10s internal cooldown.
3. RECOVER pickup + RECYCLER + DATA LEECH.
4. SCRAP DIET (overflow-only).
5. Heal telemetry.
6. Export, sign, and audit APK v2.3.

Difficulty constants are LOCKED until playtest feedback. Do not touch
WAVE_SCALE_CAP or elite_chance.

Run the full Godot autotest after every step (command below), require
AUTOTEST_ALL_PASS, and verify every claim with fresh command output before
reporting success. Use TDD: failing test first for every behavior change.

Autotest command:
  godot --headless --path /storage/emulated/0/OX-Trial-2 -- --autotest

Hard rules:
- One-HP mode must never gain RECOVER, SCRAP DIET, SECOND WIND-style saves,
  or any heal patch from the offer pool.
- Lock-on is accessibility: keep it, but it must stay banned in Weekly mode.
- Preserve the neon procedural identity and mobile-first design.
- Never commit APKs, keystores, credentials, .godot/, or private paths.
- Binaries go to GitHub Releases, never Git history.
- Do not revert unrelated changes from the other refactoring session.
```

## Context

- Public repo: https://github.com/mafuzyk/kernel-panic (branch `main`).
- Current release: v2.2.0 (APK working on Motorola G54, sound confirmed).
- Local project: `/storage/emulated/0/OX-Trial-2`.
- Package: `dev.oxp.kernelpanic`. Next version target: `2.3.0`.
- Godot binary available in Termux: `godot` (4.7.2).
- Android build toolchain already configured (SDK + templates + keystore env
  override via `GODOT_ANDROID_KEYSTORE_RELEASE_PATH/USER/PASSWORD`).
- A parallel session refactored code (new enemies RECURSOR/FIREWALL already
  exist in bestiary). Re-read files before editing; this handoff describes
  intent, not guaranteed line numbers.

## 1. MoteField — MultiMesh rewrite (Option A, approved)

Problem: each mote is a full Area2D + CollisionShape2D + glow Sprite2D +
group member, with `queue_redraw()` every physics frame and a fresh
`PackedVector2Array` allocation in `_draw()`. At the 90-mote cap this is the
main device lag source. Headless physics is cheap (0.01ms); node/draw
overhead is the cost.

Replace all per-mote nodes with one manager node:

```gdscript
class_name MoteField extends Node2D
const MAX := 128
var _pos: PackedVector2Array      # fixed size MAX
var _vel: PackedVector2Array
var _life: PackedFloat32Array
var _flags: PackedInt32Array      # bits: alive, magnet, stolen, force
var _count := 0                   # compacted; swap-remove on death
var _mmi: MultiMeshInstance2D     # diamond + baked glow in one quad
```

Requirements:

- Zero Area2D, zero per-mote Sprite2D, zero group usage.
- One MultiMesh draw call for all motes; pulse/blink via per-instance
  transform/color, no per-node redraws.
- Pickup = single loop over `_count` computing distance to player (<20px),
  calling `player.collect_mote()` — logic unchanged.
- Magnet pull identical to current math (mote.gd `_physics_process`).
- Spawn = write a slot (no node creation). Kill bursts become allocation-free.
- Stolen motes (OOM_KILLER) tracked by the field: orbit positions around the
  carrier, released on carrier death, freed on escape — same visible behavior
  as today.
- Blink when `life < 2.5s`; lifetime `Balance.MOTE_LIFE`.

API replacing the `"motes"` group (migrate every call site):

| Current site | Old | New |
|---|---|---|
| `arena.gd` kill drops | `Mote.new()` + add_child | `field.spawn(pos)` |
| `arena.gd` wave-clear vacuum | group + `force_collect()` | `field.collect_all()` |
| `player.gd` mdash patch | group scan + force_collect | `field.magnet_all_near(pos, r)` |
| `oom_killer.gd` steal/flee/die | group scan + `stolen` flag | `field.steal_nearest()`, `field.release_stolen()` |
| counters (`arena`, harness) | `get_nodes_in_group("motes").size()` | `field.count()` |
| `dev_harness.gd` (~6 uses) | direct `Mote.new()`, `.stolen`, `.force_collect` | field API equivalents |

TDD: adapt the autotest to assert count, pickup, magnet, OOM steal/return,
and vacuum against the field BEFORE swapping production code. Old `Mote`
class may be deleted once harness and call sites are green.

## 2. Vampic rework — 10s internal cooldown (approved)

- Patch `vampic` ("CHAIN x4 HEALS 1 INTEGRITY", legendary, max 1).
- Add a 10-second internal cooldown between heals. Chain x4 while on CD:
  no heal, no counter reset weirdness — just nothing.
- Show CD state: the patch chip in the HUD dims/blinks while on CD so the
  heal never feels silent or random.
- Fix the duplicate-heal bug first if still present: `Game.register_kill()`
  already emits `combo_milestone`; `Arena._on_enemy_died` must not emit it
  again (double heal at x4).
- TDD: regression test that two rapid x4 milestones heal exactly once within
  the CD window, and again after it expires.

## 3. RECOVER pickup (approved)

- Green neon pickup, +1 HP, ~10s lifetime, NOT attracted by mote magnet —
  player must move to it.
- Drop chances: 8% normal kill, 25% elite kill, guaranteed at boss 50% HP
  (once per boss), guaranteed on boss death.
- Disabled entirely in One-HP (no drops, no pool entries).
- Distinct pickup feedback: sound + text "+1 INTEGRITY" + green ring.

New patches (excluded from One-HP offers):

- `RECYCLER` (max 2-3): +6% RECOVER chance per level.
- `DATA LEECH` (rare, max 1): elites always drop RECOVER.

## 4. SCRAP DIET (approved, overflow-only)

- New rare patch, max 2 levels: 25 overflow motes → +1 HP (level 2: 20).
  Counter resets when it heals. Respects `max_hp` cap.
- Overflow = a mote collected while the meter cannot accept it:
  - `oc_ready == true` (meter full, not yet activated), AND
  - `overclock_active == true` (during Overclock).
  Both states count (user-confirmed). In both states motes currently give
  only +5 score; they now also advance the SCRAP counter.
- Meter-filling pickups never advance SCRAP (no competition with Overclock).
- HUD: chip next to the Overclock bar showing `SCRAP 17/25` while owned.
- Excluded from One-HP offers.
- Implementation rides on MoteField: `collect_mote()` path already knows the
  overflow state; add the counter in Player, not in the field.
- TDD: test counter increments only in overflow states, heals at threshold,
  resets, and is absent from One-HP offers.

## 5. Heal telemetry (approved)

- Track heals by source in run stats + lifetime config: `vampic`, `recover`,
  `cycle`, `boss`, `scrap`.
- Game-over screen gains one line, e.g.:
  `HEALS +4 (RECOVER x2, SCRAP x1, CYCLE x1)`.
- Purpose: data-driven tuning for the next balance pass.

## 6. Difficulty knobs — LOCKED

Do NOT change until playtest feedback after this build:

```gdscript
WAVE_SCALE_CAP  1.65 → 1.55   # only if still "impossible" late game
elite_chance    0.045 → 0.038 # only if elite density still spikes
```

Validation protocol after export: author + boyfriend playtest; evaluate
impossible-vs-hard using telemetry (deaths per cycle, heals used by source).

## 7. Export checklist (after steps 1-5 green)

1. Full autotest: `AUTOTEST_ALL_PASS`, no new error classes.
2. `godot --headless --editor --quit` to import new assets.
3. Export release with keystore env overrides (preset has empty keystore
   fields by design).
4. Audit: `apksigner verify`, `aapt2 dump badging` (not debuggable, arm64),
   audio sample count, no `media/` in APK if the exclude filter landed.
5. Copy to `/storage/emulated/0/OX-Trial-2/KERNEL-PANIC.apk`, open installer
   via `termux-open` for on-device test.
6. Commit source changes (no binaries), push, cut release v2.3.0 with APK.

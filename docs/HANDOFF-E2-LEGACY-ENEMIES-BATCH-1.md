# E2 — legacy enemies batch 1 handoff

## Resultado

E2 batch 1 routes `DRONE`, `LANCER` and `SPEWER` through the E1 presentation
adapter/renderer while retaining the legacy code-drawn `GlyphLib` silhouettes.
The new `EnemyBase.presentation_snapshot()` is read-only presentation data;
Lancer adds AIM/LUNGE attack state and axis, and Spewer adds wind-up state and
aim axis. The existing Lancer aim line, Spewer wind-up eye/pulse and Drone
elite/volatile/hit treatment remain in their enemy-owned `_draw()` methods.
Sprites are still disabled and `GlyphLib` is byte-identical.

## Baseline recorded before edits

- Worktree: `/tmp/kernel-panic-plan-execution`
- Branch: `codex/plan-execution`, initial HEAD `35934d4`
- Original checkout was not touched.
- Existing enemy drawing was direct `GlyphLib.draw_glyph()` in all three
  classes; Lancer owned the AIM line, Spewer owned the wind-up eye/pulse and
  Drone owned volatile/elite overlays.
- Existing gameplay fields inspected: `position`, `hp`, `max_hp`, `t`,
  `rotation`, `elite`, `elite_kind`, `_v`, `phase`, `_aim`, `_telegraph`,
  `_fire_t`, and `_wob`.

## Red → green evidence

The focused probe was committed before production as `2827e2b` and run before
production edits with Dummy audio. It ended `exit=1`, `PROBE_DONE fails=15`:
the expected failures were missing Lancer/Spewer presentation states and the
missing renderer state-marker contract; the probe also already executed a real
CanvasItem `_draw()` path after its own fixture setup.

After production changes and adversarial correction:

- Headless focused probe: `exit=0`, 76 `PROBE_PASS`, 0 `PROBE_FAIL`,
  `PROBE_DONE fails=0`.
- Xvfb focused probe: `exit=0`, 76 `PROBE_PASS`, 0 `PROBE_FAIL`,
  `PROBE_DONE fails=0`. Xvfb emitted only the known V-Sync warning and used
  Mesa llvmpipe.
- The probe constructs real enemy script instances without starting gameplay,
  checks identity, facing, position/HP/max HP/time/elite preservation, Lancer
  AIM and LUNGE, Spewer wind-up, state geometry signatures, non-square extent
  containment at 24/48/96/160 logical pixels, deterministic render keys,
  actual enemy `_draw()` execution after queueing the enemy in a live tree,
  unchanged simulation fields across that draw, catalog copy, and the full
  pre-E2 `GlyphLib` SHA-256 scope guard.

## Validation

- Import/editor scan: `godot --headless --audio-driver Dummy --path . --editor
  --quit`, `exit=0`; known environment warning: Android `build-tools` is not
  installed.
- Full DevHarness: `exit=0`, `1414 AT_PASS`, `0 AT_FAIL`,
  `AUTOTEST_ALL_PASS`.
- `git diff --check`: `exit=0`.
- Accumulated validator: `VALIDATION OK`, suite headless `1414/0`, E2 probe
  `76/0`, all runtime error gates 0. The final run was executed after the
  adversarial corrections with the validator's normal per-case timeout under
  a 300-second outer bound.

## Adversarial corrections applied before acceptance

The first independent review rejected the initial green-looking result for
two evidence gaps and one presentation bug. The fixes were made test-first,
then the focused probes and accumulated validator were rerun.

- `MARKER_EXTENT` covered the declared envelope but not the diagonal reach of
  the `attack`/`hit` state marker. The renderer now exposes a conservative
  `DIAGONAL_MARKER_EXTENT` contract of `1.70`, and the E1 illustration probe
  asserts that the resulting extent is safe for all tested non-square slots.
- The first E2 probe exercised a renderer fixture but did not prove that each
  legacy enemy's own `_draw()` method reached the shared renderer. The probe
  now adds each real enemy instance to a temporary tree, disables simulation,
  queues a redraw, waits for the draw frame and compares its simulation
  signature before and after. This is the evidence used for the final 76/0
  result.
- Spewer's old `_draw()` mutated its gameplay-facing node rotation every
  frame, while the glyph already owns its cosmetic spin. The mutation was
  removed; Spewer now passes its aim axis without subtracting the cosmetic
  animation from the node orientation. Its legacy wind-up eye/pulse remains
  intact.

An intermediate direct `_draw()` probe attempt was rejected by Godot because
manual `_draw()` calls outside the engine draw phase are invalid. It was
replaced by the queued, in-tree path above; the intermediate runtime error is
not part of the final validation result.

## Changed files

- `src/enemies/enemy_base.gd` — read-only presentation snapshot and default
  idle/hit/elite/facing projections.
- `src/enemies/drone.gd`, `lancer.gd`, `spewer.gd` — renderer-backed identity
  draw call; Lancer/Spewer presentation-only state/facing overrides.
- `src/ui/vnext/core/entity_presentation_adapter.gd` — consumes the snapshot
  when available while retaining fixture compatibility.
- `src/ui/vnext/core/entity_renderer.gd` — batch color mapping, oriented legacy
  draw helper, non-color state marker geometry/signature and the conservative
  diagonal marker envelope.
- `tools/e2_legacy_enemy_probe.gd`, `.tscn` — focused probe, including queued
  real enemy `_draw()` execution.
- `tools/vnext_entity_illustration_probe.gd` — strengthened state-marker
  envelope assertion used by the E1/E2 contract.
- `tools/validate_input_dispatch.sh` — accumulated validator entry.
- Required docs and release ledger listed in the commits below.

## Scope and compatibility review

No calls or writes were added to movement, phase transitions, attack timing,
collision, spawn/reward/balance/RNG, audio, save, routes or input. The
presentation snapshot reads those fields only; drawing does not call `Game`,
`Sfx`, `Fx`, scene APIs or RNG. No sprite was enabled. The `GlyphLib` hash and
non-batch branch checks pass, and no non-batch glyph source was edited.

## Decisions, alternatives and performance

The shared E1 renderer owns orientation and state-marker geometry; the enemy
classes retain behavior-specific telegraph geometry. A new glyph family or
sprite asset was rejected for this batch because the existing silhouettes are
already the compatibility source and the brief explicitly keeps sprites off.
The enemy draw helper receives primitive presentation values and does not
allocate a snapshot dictionary in the per-frame path; the snapshot remains
available for adapters and probes. No new textures, nodes, audio, RNG or
caches are introduced. Dense-wave performance was not profiled with a fixed-
seed frame budget, so this is an inspected cost claim, not a measured
performance pass.

## Known limitations / not proven

- No human visual approval is claimed; no capture was submitted for art
  approval. The headless/Xvfb draw path proves invocation and contracts, not
  pixel-level readability in a full combat wave.
- The marker-envelope probe covers the current marker geometry at the tested
  cardinal orientations and sizes; it is not a pixel-level sweep of every
  angle or a future-proof proof for changed line thickness/subpixel behavior.
- `presentation_facing()` currently delegates to the pure `aim_at_player()`
  projection. If that helper later gains state mutation, the read-only draw
  contract must be revisited and the probe expanded.
- Mobile physical-device rendering, grayscale/color-assist capture review,
  accessibility settings integration, PT-BR text, screen readers and Android
  export are not proven here.
- The existing teardown diagnostics remain: 8 resources, 10 CanvasItem RIDs,
  3 GodotArea2D RIDs, 14 dummy textures, 147 shaped-text allocations, 2 font
  allocations and 171 ObjectDB instances. E2 neither claims nor attempts to
  fix them.
- Xvfb proves the software-rendered desktop path, not the integrated Vega
  hardware path.

## Commits

- `2827e2b` — test: add E2 legacy enemy presentation probe
- `120c2a8` — feat: route legacy enemy identity through E1 renderer
- `d734e0e` — test: add E2 probe to accumulated validator
- `a62bce9` — perf: avoid snapshots in legacy enemy draw loop
- `d02a607` — fix: close E2 drawing contracts
- `c5c8012` — test: execute legacy enemy draw paths in tree
- `34a228c` — docs: hand off E2 legacy enemy batch 1
- A subsequent documentation commit records the adversarial corrections and
  final aggregate validator run.

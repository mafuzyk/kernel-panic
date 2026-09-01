# A3 — Snapshot contracts report

## Result

Implemented the four additive public methods required by the versioned A3
architecture section:

- `Game.run_snapshot()` — run/progression state owner.
- `Arena.combat_snapshot()` — live combat scene owner.
- `Menu.menu_snapshot()` — live menu scene owner.
- `Sfx.accessibility_snapshot()` — local presentation/settings owner.

No live consumer was replaced or redirected. Gameplay, save format, balance,
input routing, and rendering paths remain unchanged. The probe only inspects
the returned data; it does not exercise a vNext renderer.

## TDD evidence

Initial focused probe command (red):

```text
XDG_DATA_HOME=/tmp/kernel-panic-a3-red-xdg godot --headless --audio-driver Dummy --path . res://tools/snapshot_contract_probe.tscn
```

Result: exit 1, `PROBE_DONE fails=12`. The failures were the four missing
methods plus their contract/isolation assertions; the baseline safety and
side-effect guards were present and behaved as expected for empty snapshots.

The first two attempts exposed probe-entrypoint issues, not product failures:
the standalone script cannot resolve autoload identifiers at compile time and
Godot requires a scene entrypoint for a Node script. The probe was corrected to
use runtime `/root/Game` and `/root/Sfx` owners and a minimal `.tscn`, then the
red result above was reproduced.

After implementation, focused green command:

```text
XDG_DATA_HOME=/tmp/kernel-panic-a3-green-xdg-3 godot --headless --audio-driver Dummy --path . res://tools/snapshot_contract_probe.tscn
```

Result: exit 0, 30 `PROBE_PASS`, 0 `PROBE_FAIL`, `PROBE_DONE fails=0`.

The probe covers method availability, schema metadata, required field
presence, recursive primitive/JSON safety, deep-copy isolation, RNG state,
save bytes, and node-count stability for the real Game, Arena, Menu, and Sfx
owners.

## Hanging-process investigation

The user-reported `hrtimer_nanosleep` state was investigated before continuing.
At inspection time no Godot process remained; the exact-process search returned
only its inspection shell. A clean reproduction with an external 10-second
limit exited normally in 1.1 seconds with exit 0 and all 30 focused checks
passing. This indicates the observed sleeping processes were orphaned or
still-shutting-down Godot processes left by the interrupted tool invocation,
not a reproducible probe loop.

As a minimum defensive correction, the probe now has an 8-second in-process
watchdog that emits `PROBE_FAIL watchdog timeout` and exits 2. A controlled
red reproduction was run with `KP_A3_FORCE_WATCHDOG=1`:

```text
XDG_DATA_HOME=/tmp/kernel-panic-a3-watchdog-red-xdg KP_A3_FORCE_WATCHDOG=1 timeout --signal=TERM 5s godot --headless --audio-driver Dummy --path . res://tools/snapshot_contract_probe.tscn
```

Result: exit 2, explicit `PROBE_FAIL watchdog timeout`, and no remaining
Godot process. A timeout is therefore treated as failure, never success.

## Full-suite evidence

```text
XDG_DATA_HOME=/tmp/kernel-panic-a3-full-xdg godot --headless --audio-driver Dummy --path . -- --autotest
```

- Exit: `0`
- `AT_PASS`: `1414`
- `AT_FAIL`: `0`
- Completion marker: `AUTOTEST_ALL_PASS`

Teardown diagnostics, reported separately from functional status:

- 8 resources still in use;
- 3 `GodotArea2D` RID allocations leaked;
- 14 dummy textures leaked;
- 147 shaped-text allocations leaked;
- 2 advanced-font allocations leaked;
- 10 CanvasItem RIDs and 171 ObjectDB instances reported by warnings.

These match the recorded baseline class of teardown noise. A3 does not claim
to fix or worsen those leaks.

## Changed files and commits

- `tools/snapshot_contract_probe.gd`
- `tools/snapshot_contract_probe.tscn`
- `src/autoload/game.gd`
- `src/autoload/sfx.gd`
- `src/ui/menu.gd`
- `src/arena/arena.gd`

Commits:

- `9092163` — `test: add real-path snapshot contract probe`
- `c1a9b3d` — `refactor: add serializable snapshot contracts`
- `9c5c112` — `test: bound snapshot probe with explicit watchdog`

The existing unrelated generated `.uid` and capture-import artifacts were not
staged.

## Contract decisions

Each method returns a deep-copied dictionary containing `schema_version`,
`owner`, `required_fields`, and `optional_fields`. Mutable owner dictionaries
and arrays are copied recursively. Vectors and rectangles are encoded as
numeric dictionaries; colors are encoded as HTML strings. No returned value
contains a Node, Callable, Resource, Font, Texture, Vector2, Rect2, or Color.
Development assertions make missing required producer fields loud, while the
metadata gives consumers an explicit required/optional boundary.

Alternatives considered:

- A shared snapshot Resource was rejected because Resources would complicate
  the primitive-only boundary and introduce a new ownership layer.
- Replacing current HUD/menu consumers was rejected because A3 explicitly
  introduces the boundary without migration.
- Reading snapshots from UI kits was rejected because the architecture keeps
  state production on Game, Arena, Menu, and Sfx owners.

## Assumptions and remaining risks

- `Arena` enemy state is represented from the current `EnemyBase` fields and
  the current `Spawner` counters; later entity-specific fields may need
  optional additions.
- The probe verifies that unknown optional fields do not affect its own
  consumer logic only indirectly through metadata iteration; a future vNext
  consumer should explicitly ignore unknown optional keys.
- The probe proves snapshot production/inspection does not mutate RNG, saves,
  or node count. It does not prove drawing behavior because no vNext renderer
  consumes these contracts yet.
- Teardown diagnostics remain an open reliability item carried from W0.

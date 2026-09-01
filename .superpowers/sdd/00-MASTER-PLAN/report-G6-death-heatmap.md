# G6 — Local death feedback and heatmap

## Status

Implemented on `codex/plan-execution`. The game now records one quantized death
cell per run in a bounded, versioned local history and exposes an aggregate
snapshot for game-over diagnostics. It stores no screenshot, raw position,
telemetry stream or network data.

## Rule and storage contract

- Each run can record at most one death position. The guard is reset only when
  `Game.start_run()` or `Game.start_story()` begins a new run.
- Coordinates are normalized against `Balance.arena_rect()` and quantized to a
  12×7 grid. Positions outside the arena are clamped to the nearest cell.
- History is scoped by run context: `classic`, `weekly`, `onehp`, `practice`,
  or `story:<stage_id>`. Histories are not merged across modes or story
  stages.
- Each scope stores at most 50 `{x, y}` cells under the ConfigFile
  `[diagnostics]` section. The entry carries schema version 1 and invalid
  scopes, versions, coordinates and malformed runs are discarded on load.
- The public snapshot computes aggregate `{x, y, count}` cells and returns the
  grid/capacity/version metadata. It does not expose screenshots or raw
  positions.

## Before and after

Before, player death transitioned through Arena to game over without retaining
any spatial information. A player could see the killer and run statistics but
could not tell whether deaths clustered near an edge, in a corner or in a
dense central area over repeated local attempts.

After, Arena records the player's position at the actual death boundary before
the delayed game-over transition. The legacy panel has a small code-drawn
diagnostic view, and the vNext game-over surface reserves a compact heatmap
region beside/below the run summary. It is deliberately low priority: retry,
abandon, primary cause and core statistics remain independent controls/content.
Victory screens do not show a death map.

## Files and ownership

- `src/autoload/game.gd`: versioned constants, normalization, mode scope,
  quantization, bounded persistence and aggregate snapshot.
- `src/arena/arena.gd`: records exactly at the player death boundary and passes
  the death snapshot to vNext game over; clears the legacy view for victory.
- `src/ui/death_heatmap_view.gd`: small reusable code-drawn heatmap for the
  legacy game-over panel.
- `src/arena/panel_kit.gd`: mounts the legacy diagnostic view without making it
  responsible for storage or gameplay.
- `src/ui/vnext/surfaces/game_over_surface.gd`: reserves responsive vNext
  geometry and draws the aggregate map.
- `tools/g6_death_heatmap_probe.gd/.tscn`: focused red/green storage, bounds,
  scope, malformed-input and layout contract.

## Compatibility and impact

- No existing save transfer fields, score rules, input actions or mode routes
  changed. The new local diagnostics section is additive and can be absent on
  old profiles.
- The existing Sfx save path is used; no file is written outside the project's
  established settings boundary.
- The history is intentionally local and bounded. A profile with no deaths
  has an empty snapshot and no visible map.
- One ConfigFile save occurs at the death boundary, not every frame. The
  aggregate is computed only when game over is assembled or a caller requests
  it.
- The map uses color for intensity but retains grid geometry, a title and a
  stable position; it is diagnostic context, not a gameplay signal. It is not
  yet a full color-assist pattern system.
- No breaking API or migration is required. `death_heatmap_snapshot()` is
  additive.

## Evidence

- Focused red: `/tmp/g6-red.log`, exit `1`, four expected missing-contract
  failures and `PROBE_DONE fails=4`.
- Focused green: `/tmp/g6-green-final.log`, exit `0`, 33 passes, zero failures and
  `PROBE_DONE fails=0`. It verifies one-record-per-run, 50-run bounding,
  quantized bounds, aggregate counts, version/scope rejection, legacy label
  fit and vNext game-over layout/overflow.
- Editor import/parse: `/tmp/kernel-panic-g6-import2.log`, exit 0 with the
  known Android build-tools warning only.
- The probe used an isolated XDG data directory (`/tmp/kernel-panic-g6-xdg3`)
  so local user save data was not used by the acceptance run.
- `git diff --check` is required at the next aggregate checkpoint; no focused
  runtime errors were reported by the green probe.

## Second-pass self-review

The design was checked for duplicate death signals, restart reset, victory
contamination, mode leakage, old-profile absence, invalid coordinates, grid
overflow, map overlap with primary actions and accidental screenshot/raw-data
storage. The implementation guards duplicate recording, scopes story stages,
clamps/filters data and gives the map a separate responsive region.

The remaining uncertainty is platform behavior: the local ConfigFile write and
window geometry have not yet been tested on Android/macOS or under a full disk
failure. The map's intensity is not itself an accessibility substitute; the
new accessibility system must later decide whether to provide a pattern/legend
for this secondary diagnostic.

# KERNEL PANIC — Repository Architecture and Refactor Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans`. This micro-plan is executed in small, behavior-preserving commits before feature work is allowed to depend on the new boundaries.

**Goal:** Organize the repository around clear ownership boundaries so UI, gameplay, content, tests and release tooling can evolve without turning `Arena`, `Menu`, `Game` or `DevHarness` into shared global dumping grounds.

**Architecture:** Keep public paths and runtime entry points stable while introducing focused modules behind them. `Game` remains the authoritative run/save state, `Arena` remains the scene coordinator, `Spawner` remains the encounter director, and `Menu` remains the route coordinator. New systems communicate through typed-ish dictionaries/snapshots and named signals; they do not reach into arbitrary private nodes.

**Tech Stack:** Godot 4.7.2/GDScript, `RefCounted` kits where an owner reference is appropriate, `Resource` or plain dictionaries for data catalogs, existing autoloads, DevHarness probes and explicit `.uid` sidecars.

**Spec:** [master plan](00-MASTER-PLAN.md), [UI direction](../../../UI-REDESIGN-DIRECTION.md), and the existing [structure refactor plan](../2026-08-30-structure-refactor.md).

## Global Constraints

- Pure extraction tasks preserve behavior, signals, group names, save keys and public method names.
- Do not move `project.godot`, `src/ui/menu.tscn`, autoload paths or any class path until compatibility has been proved.
- Do not split `game.gd` or the frozen HUD drawing path merely because a file is long; split only after a measured ownership problem and a dedicated task.
- No cyclic preloads. Kits receive an untyped owner reference or consume a snapshot; they never preload their owner.
- One task/commit moves one cohesive responsibility and ends with a full green validation.
- New files receive `.uid` sidecars through Godot import and those sidecars are reviewed before staging.

## Current Ownership Map

| Area | Current authority | Future responsibility |
| --- | --- | --- |
| run, story progress, records, patches, save transfer | `src/autoload/game.gd` | state machine and serializable snapshots only |
| audio, haptics, local settings | `src/autoload/sfx.gd` | audio plus local presentation preferences; not gameplay truth |
| balance, colors, platform helpers | `src/autoload/balance.gd` | numeric rules and semantic palette helpers |
| test orchestration | `src/autoload/dev_harness.gd` and `src/autoload/harness/` | registration, assertions and section dispatch |
| scene lifecycle and combat coordination | `src/arena/arena.gd` | coordinator delegating to focused kits |
| waves and boss spawn | `src/arena/spawner.gd` | encounter state and spawn decisions |
| player simulation | `src/player/player.gd` | movement, aim, firing, dash, overclock and player presentation hook |
| enemy simulation | `src/enemies/` | one enemy state machine per file, shared movement/telegraph contract in `EnemyBase` |
| story content | `src/story/` | static stage/act catalogs, no UI drawing |
| UI composition | `src/ui/vnext/` | snapshots, layout, draw primitives, screens, focus and hit geometry |
| legacy UI | `src/ui/*.gd` | compatibility surface until each replacement screen is accepted |
| probes and validation | `tools/` | deterministic real-path checks and aggregate gates |

## Target Directory Shape

The target shape is introduced gradually. Existing files are not mass-moved in
one commit because `res://` paths and `.uid` files are part of the Godot
project's dependency graph.

```text
src/
  autoload/
    game.gd
    sfx.gd
    fx.gd
    balance.gd
    localization.gd
    accessibility.gd
    dev_harness.gd
    harness/
  arena/
    arena.gd              # scene coordinator and compatibility delegates
    spawner.gd             # encounter director
    kits/                  # stage, intro, panel and transition ownership
  gameplay/
    run_snapshot.gd       # serializable presentation snapshot contract
    encounter_snapshot.gd
    mutators.gd
    practice_run.gd
  player/
    player.gd
    bullet.gd
  enemies/
    enemy_base.gd
    legacy/                # only if a later move is proven safe
    bosses/
  pickups/
  story/
    acts/
    story_catalog.gd
    story_data.gd          # compatibility facade while acts migrate
  ui/
    vnext/
      core/                # tokens, safe area, layout, snapshots
      primitives/           # frames, meters, glyphs, focus and state markers
      surfaces/             # menu, HUD, pause, terminal, settings, etc.
      entities/             # code-drawn illustrations and state overlays
      input/                # focus/navigation/action routing
    legacy/                # future home for accepted compatibility files
    glyph_lib.gd           # compatibility entry point during migration
  data/
    localization/
    entities/
    story/
tools/
  probes/
  validation/
docs/
  superpowers/plans/<date-master-plan>/
  handoffs/
  release/
assets/
  fonts/
  icons/
  audio_raw/
media/
  Ideas/                   # moodboard; not shipped runtime content
```

The intermediate tree may keep files at their current paths. A folder is not
considered successful merely because it exists; the important result is that a
module has one owner, one public contract and one testable reason to change.

## Current-to-Target Migration Map

The target tree is a destination, not permission for a mass rename. Before
moving a file, record its current path, all preload/load references, class name,
signals, public methods, scene ownership and `.uid` relationship. The default
migration is an additive compatibility step followed by a removal step.

| Current responsibility | First safe destination | Compatibility rule | Removal evidence |
| --- | --- | --- | --- |
| `src/ui/menu.gd` route/composition mix | `src/ui/vnext/surfaces/` plus a route adapter | `menu.tscn` and public menu actions remain valid | route probe, method inventory and no legacy imports |
| `src/ui/menu_*_kit.gd` composition helpers | `src/ui/vnext/core/` or the owning surface | old owner delegates; kit does not become a second state owner | snapshot/action parity and teardown probe |
| `src/ui/hud.gd` combat drawing/state wiring | `src/ui/vnext/surfaces/combat_hud_surface.gd` | Arena signal names and HUD compatibility entry point remain stable | fixed-seed capture plus lifecycle probe |
| `src/arena/panel_kit.gd` pause/terminal composition | `src/ui/vnext/surfaces/` adapters | Arena remains the only scene coordinator | pause/terminal real-path probe |
| inline story/program/enemy labels | `src/data/` catalogs | IDs and save values do not change when labels move | key parity and save round-trip |
| `tools/*.gd` ad-hoc probes | `tools/probes/` | old validation entry points keep forwarding while referenced | aggregate validator and clean-checkout run |

If a current file owns two responsibilities, split behavior before moving
paths. The split commit must leave the old entry point delegating to exactly one
new owner; otherwise the repository has two implementations that can drift.

## Refactor Sequence

### Task A1 — freeze the baseline

**Files:** `project.godot`, `src/autoload/`, `src/arena/`, `src/ui/`,
`tools/validate_input_dispatch.sh`, `docs/release/`.

- [ ] Record the current commit, branch, line counts, test counts, runtime
  diagnostics and supported export targets.
- [ ] Add a small repository map to the handoff without changing runtime code.
- [ ] Confirm `Game`, `Sfx`, `Fx` and `DevHarness` are the only autoloads.
- [ ] Confirm save keys and transfer version before any new preference is added.

**Acceptance:** a clean checkout can run the full suite; the baseline log has a
completion marker; no generated `.godot` content is staged.

### Task A2 — extract owner-owned kits

The existing structure refactor plan is the source of truth for mechanical
extraction. Complete or revalidate it before introducing new feature code:

- Arena panel/intro/stage helpers remain one-way delegates from `Arena`.
- Menu settings/chrome helpers receive the menu owner and own only composition.
- DevHarness sections call harness helpers through the explicit `h.` prefix.
- Every dynamic dispatch used by probes remains available through a named
  delegate on the owner.

**Acceptance:** existing public calls and private-state probes still resolve;
the full suite has the expected pass count for the current branch; source-scan
landmines documented by the old plan are still satisfied.

### Task A3 — introduce snapshot contracts

Create the following small contracts without replacing live consumers yet:

```gdscript
func run_snapshot() -> Dictionary
func combat_snapshot() -> Dictionary
func menu_snapshot() -> Dictionary
func accessibility_snapshot() -> Dictionary
```

Each snapshot must contain only serializable values: IDs, numbers, booleans,
strings, colors encoded consistently, arrays and nested dictionaries. It must
not contain Nodes, Callables, textures, fonts or references to autoloads.

The snapshot producer is the gameplay/state owner. The UI reads a snapshot and
emits a named action request; it does not mutate `Game` fields directly.

Snapshot schemas receive a small `schema_version` and an owner-defined list of
required/optional fields. Unknown optional fields are ignored by consumers;
missing required fields fail loudly in development with the snapshot owner and
route named in the diagnostic. Producers must not expose mutable live
dictionaries that another surface can modify in place.

**Acceptance:** probes can compare snapshots before/after one action and prove
that drawing a snapshot does not advance `Game.rng`, create gameplay nodes or
change save state.

### Task A4 — split static content from runtime logic

Move new content into catalogs before adding new screens:

- program metadata and display labels;
- enemy metadata, threat class, glyph kind and bestiary key;
- stage/act definitions, wave lists, unlock conditions and era profile;
- localization keys and accessibility labels.

`Game` and `Spawner` may keep compatibility accessors such as
`story_stage_def(index)` and `program_def()`, but the data itself should no
longer be duplicated inside UI files.

**Acceptance:** changing a title, description or bestiary label requires one
catalog edit and does not require changing `_draw()` or combat code.

### Task A5 — migration, rollback and deprecation checkpoints

Every path move or public-contract change is performed in two reviewable
stages. Stage one adds the destination and a compatibility delegate. Stage two
removes the old path only after a repository-wide reference scan, scene-load
probe, save round-trip, input probe and full validation are green. A move that
changes a `res://` path must also verify imported `.uid` data from a clean
checkout.

Before stage one, save a small fixture set under the test harness (not in
`user://`): a fresh profile, a progressed story profile, a profile with old
optional keys and a profile with malformed/truncated data. The rollback test
must prove that reverting the feature commit still opens the last accepted
route and that a failed migration leaves the source save byte-for-byte
untouched. Never use a cleanup commit to hide a failed migration.

Each deprecated delegate gets an owner, a reason, a first release in which it
appeared, a removal condition and a test that fails if it is removed too early.
The handoff must state whether the old path remains runtime-reachable, test-only
or dead. A compatibility layer without a removal condition is considered
unfinished architecture.

**Acceptance:** a clean checkout can build the destination path, the old path
has no untracked consumers, the rollback fixture passes, and the handoff lists
the exact removal gate. No file move is accepted solely because the new folder
looks cleaner.

## Interfaces Required by Later Work

### UI action boundary

The UI may emit actions in this shape:

```gdscript
signal action_requested(action_id: String, payload: Dictionary)
```

Examples: `"start_run"`, `"select_program"`, `"select_stage"`,
`"apply_patch"`, `"open_settings"`, `"set_accessibility"` and
`"abandon_confirmed"`. The coordinator validates the action against the current
state. Invalid actions produce a diagnostic event and no mutation.

### Entity presentation boundary

Every combat entity exposes enough data for the renderer to draw it without
reimplementing gameplay rules:

```gdscript
func presentation_snapshot() -> Dictionary
func presentation_kind() -> String
func presentation_state() -> String
func presentation_facing() -> Vector2
```

The exact methods may be compatibility delegates, but the semantics must stay
stable. The renderer never infers “elite”, “charging” or “dead” from color
alone.

### Persistence boundary

New preferences use an explicit section/key pair and a default. Save changes
must go through existing helpers (`Sfx.save_settings()` for presentation
settings or `Game` save functions for progress). No feature opens its own
uncoordinated file under `user://`.

Every persisted addition also defines its type, default, serialization name,
version/migration behavior, reset behavior and whether it affects records. A
save key is not reused for a different meaning, even if its old value appears
compatible. Settings writes are coalesced at an explicit transition or on
safe exit, never from a render callback.

## Refactor Safety Tests

- [ ] Public-method inventory: compare methods/signals before and after each
  extraction.
- [ ] Scene-load probe: load `src/ui/menu.tscn` and a real Arena through the
  normal `Game.start_run()` path.
- [ ] Save round-trip: export/import current saves and compare stable fields.
- [ ] RNG guard: draw menus, bestiary, entity previews and captures while
  asserting `Game.rng.state` does not change.
- [ ] Input dispatch: viewport `push_input()` for keyboard, pointer, touch,
  echo, focus and paused tree.
- [ ] Runtime error gate: no new script errors, missing methods or invalid
  deferred calls.
- [ ] Ownership/teardown: record resources and RIDs separately; never claim a
  leak is fixed without a before/after attribution.

## Commit and Handoff Boundaries

Use one commit per extraction or interface. Examples:

```text
refactor: extract arena panel ownership
refactor: add serializable combat snapshots
refactor: split story catalogs from runtime state
test: guard snapshot rendering against gameplay mutation
```

The handoff for each task must include the exact files moved, public delegates
kept, source-scan constraints, red/green commands, full-suite result and any
remaining legacy coupling. The next workstream may depend only on a committed
and pushed checkpoint.

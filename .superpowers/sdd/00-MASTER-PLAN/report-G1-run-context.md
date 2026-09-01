# G1 — Explicit Run Context and Mode Contract

## Executive result

G1 is implemented on `codex/plan-execution` in commit `a5972a9`. The project
now has an explicit, serializable gameplay context boundary without moving
simulation ownership out of `Game`. The boundary is ready for later mutator,
Practice and history work, but those features are not silently implemented by
this task.

The implementation also corrected a real contract hole discovered during the
second review: returning `writes_records() == false` for reserved Practice
would have been misleading while the existing `Game.end_run()` fallback still
wrote a Classic record and `unlock_achievement()` still wrote achievements.
The persistence guard is now at the actual write boundary.

## Requirement mapping

| Requirement | Implementation | Evidence |
| --- | --- | --- |
| Explicit mode identity | `RunContext` recognizes Classic, Story, Weekly, One-HP and reserved Practice | 29-pass focused probe |
| Story stage identity | adapter calls `Game.story_stage_id(Game.story_stage_index)` only for Story | focused probe |
| Mutator contract | ordered normalized IDs, duplicate/blank removal, empty for current modes | focused probe |
| Record contract | current modes stay record-writing; Practice is record-safe | focused probe + code inspection + save bytes |
| Deterministic seed contract | Weekly reports true, current other modes false | focused probe + `Game.start_run()` inspection |
| Copy-safe snapshot | array copies and derived booleans; no live objects | focused probe and JSON-safe implementation inspection |
| Compatibility bridge | Game accessors delegate without replacing existing fields | focused probe + full suite |
| Save compatibility | no schema/key changes; existing transfer path remains green | 39-pass save probe + full suite |

## Files changed

### Production

- `src/gameplay/run_context.gd`
  - new `RefCounted` context;
  - normalization of modes, stages and mutator IDs;
  - factories from `Game`-shaped objects and snapshots;
  - primitive-only snapshot and copy-returning accessors.
- `src/autoload/game.gd`
  - preloads the context and exposes compatibility methods;
  - makes `end_run()` skip all persistent run/lifetime writes when the context
    says the mode is record-safe;
  - makes achievement unlocking refuse to persist during Practice.

### Tests/tooling

- `tools/g1_run_context_probe.gd`
  - focused contract probe created before the production boundary;
  - covers runtime adapter, malformed input, copy isolation and Practice
    persistence.
- `tools/g1_run_context_probe.tscn`
  - probe scene.
- `tools/validate_input_dispatch.sh`
  - registers G1 as a required accumulated validator case.

Generated Godot `.uid` and capture-import files were not staged. The original
checkout remains separate from this implementation worktree.

## Before/after behavior

### Before

Mode was an untyped public string in `Game`, with mode-specific behavior spread
over menu, player, spawner and end-run branches. There was no neutral value
object to give UI, future mode selectors or gameplay systems a stable answer to
“which run rules are active?”. A future caller could also infer Practice was
record-safe from a contract without the existing persistence code honoring it.

### After

Callers can ask `Game.run_context()` or the compatibility methods for a fresh
context. The context is derived from current authoritative state, normalizes
unknown IDs, derives record/seed capabilities instead of trusting serialized
flags, and returns copies of mutable collections. Practice is explicitly
reserved and does not write run records or achievements when invoked through
the existing Game boundaries.

No current public launcher or scene was switched to a new mode. No mutator
changes, wave-selection rules or Weekly leaderboard redesign were introduced.

## Evidence details

### Focused probe

The probe was written first and initially failed to load because the production
script did not exist (`/tmp/kernel-panic-g1-red.log`). After implementation and
the Practice enforcement correction:

- `/tmp/kernel-panic-g1-practice-review-2.log`;
- exit `0`;
- 29 `PROBE_PASS`, 0 `PROBE_FAIL`;
- `PROBE_DONE fails=0`;
- no script/runtime errors.

The cases include:

1. Classic defaults, no stage, current record behavior and non-deterministic
   seed capability.
2. Story stage identity and Story persistence behavior.
3. Weekly identity and deterministic seed capability.
4. One-HP identity and record behavior.
5. Practice reserved identity and record exclusion.
6. Unknown mode fallback and mutator normalization.
7. Snapshot restore, derived flags, nested mutation isolation and accessor
   copy isolation.
8. Game adapter stage/Weekly mapping and compatibility method delegation.
9. A Practice end/achievement attempt whose save file remains byte-for-byte
   unchanged.

### Save/config evidence

The existing compatibility probe was run separately because its marker is
`SAVE_PROBE_DONE`, not the generic accumulated-probe marker:

- `/tmp/kernel-panic-g1-save.log`;
- exit `0`;
- 39 `PROBE_PASS`;
- `SAVE_PROBE_DONE fails=0`;
- fresh defaults, old `best` key, full progress profile, export/import round
  trip and malformed import preservation all pass.

This is stronger evidence than merely comparing a schema version: it exercises
the real `Sfx.SAVE_PATH` and reloads `Game` through the existing ConfigFile
loader in an isolated XDG profile.

### Aggregate evidence

- Import: `/tmp/kernel-panic-g1-import.log`, exit `0`.
- Full DevHarness: `/tmp/kernel-panic-g1-full.log`, exit `0`, 1414 passes,
  zero failures and `AUTOTEST_ALL_PASS`.
- Accumulated validator: `/tmp/kernel-panic-g1-validator-summary.log`, final
  `VALIDATION OK`; G1 is 29/0; all existing accumulated cases were green and
  no gated runtime errors were emitted.
- `git diff --check`: exit `0`.
- Script check: `run_context.gd` passed Godot `--check-only`.

Import printed the pre-existing `Unable to open Android 'build-tools'
directory.` warning. The full suite and individual probes continue to report
known teardown resource/RID diagnostics separately; the validator does not
turn them into functional passes and G1 does not claim to fix them.

## Technical design and alternatives

### Boundary shape

`RunContext` is a short-lived `RefCounted` value view. It does not become an
autoload, does not own gameplay, and does not reference UI. This keeps the
dependency direction one-way: `Game` adapts into a value; future UI and
gameplay consumers can read the value without reaching into arbitrary private
scene nodes.

### Normalization

Mode normalization prevents malformed data from creating a new implicit rule
set. Stage identity is discarded outside Story, which prevents a stale Story
index from leaking into Classic or Weekly. Mutator IDs are trimmed, lowercased,
and de-duplicated while preserving first-seen order.

Snapshot booleans are calculated, not restored from caller data. This avoids a
state such as `{mode: "practice", writes_records: true}` from becoming a
record-writing context.

### Compatibility typing

The global class name is retained for editor/runtime vocabulary, but factories
use a resource load for construction and the Game bridge returns `RefCounted`.
The existing vNext context follows the same pattern. This was chosen after a
fresh-project check exposed parser/type-resolution fragility when directly
constructing the new global class from a preloaded autoload. The behavior is
proven at runtime and avoids a cyclic preload; stronger static typing is a
future cleanup only if it remains safe under Godot 4.7 import order.

### Practice enforcement

The first contract version only exposed the false flag. Review of `end_run()`
found that its fallback match would still write `best_classic`, lifetime
statistics and killer counts for Practice. Review of `unlock_achievement()`
found a second persistence path. The implementation was revised before commit
to capture `can_write_records` once at run end, emit the transient completion
signal, then return before all persistent writes; achievements are blocked at
their own write boundary. This is deliberately not a full Practice feature.

## Compatibility, performance and security impact

- Compatibility: current save keys, transfer format/version, scenes and public
  `Game.mode` field remain in place.
- Gameplay: current modes retain their observed seed and record branches.
- Performance: context construction is a tiny value allocation and does not
  create Nodes, load textures or perform per-frame polling. It is not yet wired
  into a per-frame UI loop.
- Persistence: Practice attempts do not call ConfigFile save through the run
  end or achievement paths; all other existing persistence paths remain.
- Security/data safety: no new save path exists; all file access continues
  through `Sfx.SAVE_PATH` and existing helpers. Snapshot data contains no live
  engine objects or callables.
- Breaking changes: none intended for current modes. Deliberately setting the
  previously unused `Game.mode` to `practice` now has record-safe behavior,
  which is the contract requirement rather than a regression.

## Known limitations and uncertainties

1. Practice is reserved but not selectable. G3 must add its launcher, unlock
   rule, wave selection, achievement policy and dedicated UI without assuming
   this G1 probe is sufficient.
2. No mutator IDs are active yet. G3 must extend normalization and prove
   deterministic weekly selection.
3. `Game.mode` is still directly mutable. The context is a safe view, not an
   ownership migration. Direct mutation can still create transitional states
   before a mode start method normalizes them.
4. GDScript cannot enforce full immutability here; copy-returning methods are
   tested, but private fields can be reached by an intentionally invasive
   caller.
5. No physical mobile/Android export, native screen-reader, localization,
   dense-wave performance or human visual acceptance was performed.
6. Existing teardown leaks/diagnostics remain open and are tracked for P/RPO
   work.

## Release-note eligibility

The user-facing note for this internal foundation should be small: “Added a
record-safe Practice foundation and explicit Weekly/Story run metadata for
future mode features.” The implementation details, probe counts and parser
choice belong here, not in public release notes. Since Practice is not yet
launchable, the public note must not imply that a selectable Practice mode is
already shipped.

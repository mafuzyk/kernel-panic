# Handoff — G1 — Explicit Run Context and Mode Contract

## Branch and scope

- Branch: `codex/plan-execution`
- Worktree: `/tmp/kernel-panic-plan-execution`
- Base for the execution sequence: `295cc0c`
- Implementation commit: `a5972a9` — `feat: define explicit run context contract`
- Scope: a serializable, copy-safe gameplay context boundary plus compatibility
  accessors in `Game`.
- Explicit non-scope: mutator selection, Practice UI/wave selection, Weekly
  leaderboard redesign, gameplay simulation extraction, or a change to the
  existing save schema.

## What changed

`src/gameplay/run_context.gd` now owns a small read-only-by-copy description of
the active rule context. It exposes `mode_id()`, `stage_id()`, `mutators()`,
`writes_records()` and `uses_deterministic_seed()`. It is a `RefCounted` object,
not an autoload, and does not hold Nodes, Resources, callables or references to
the live simulation.

The context currently recognizes `classic`, `story`, `weekly`, `onehp` and the
reserved `practice` mode. Unknown or empty mode IDs normalize to `classic`.
Story stage identity is derived from `Game.story_stage_id()` only while the
mode is `story`; all other modes expose an empty stage ID. Mutators are
currently an empty ordered list because no mutator system exists yet. Duplicate
or blank IDs supplied to a restored context are removed without changing the
remaining order.

`Game` remains authoritative. Its compatibility methods create a fresh context
on each call, and context snapshots/accessors duplicate their mutable arrays.
The existing `Game.run_snapshot()` and save-transfer schema were not replaced
or extended.

The reserved Practice contract is now enforced at the existing persistence
boundary: an explicitly set `practice` run can still emit the transient
`run_ended` signal, but `Game.end_run()` does not write best-score, Weekly,
Story, One-HP or lifetime records. `unlock_achievement()` also refuses to
persist an achievement while the current mode is Practice. This does not add a
Practice launcher or wave selector; those belong to G3.

The accumulated validator now runs the G1 probe as an explicit case.

## Public contract

| Method | Current behavior | Ownership |
| --- | --- | --- |
| `mode_id()` | normalized current mode; unknown values become `classic` | `RunContext`, adapted from `Game.mode` |
| `stage_id()` | active Story stage ID, otherwise empty | `Game.story_stage_id()` through adapter |
| `mutators()` | fresh ordered copy; empty for current modes | `RunContext` |
| `writes_records()` | false only for reserved Practice; true for current modes | `RunContext` + `Game.end_run()` enforcement |
| `uses_deterministic_seed()` | true for Weekly, false for current Classic/Story/One-HP/Practice | `RunContext`, matching `Game.start_run()` |
| `snapshot()` | JSON-safe primitives, arrays and dictionaries only | `RunContext` |

The snapshot includes `schema_version`, `owner`, normalized mode/stage,
mutators, and the two rule flags. Those booleans are derived from the context;
they are not trusted from an input snapshot. A snapshot restore therefore
cannot smuggle a record-writing or deterministic-seed promise into a different
mode.

## Red/green history

### Initial bootstrap red

The first focused invocation was intentionally attempted before the production
boundary existed:

- `/tmp/kernel-panic-g1-red.log`
- It reported the missing `res://src/gameplay/run_context.gd` preload and
  dependent probe parse/inference failures.
- The process did not reach the completion marker and was terminated after the
  bounded diagnostic confirmed the expected missing boundary. This is
  bootstrap evidence, not a claim that all semantic cases were red.

### Final focused green

- `/tmp/kernel-panic-g1-practice-review-2.log`
- Exit `0`.
- 29 `PROBE_PASS`, 0 `PROBE_FAIL`, `PROBE_DONE fails=0`.
- Covers all five mode identities, story stage mapping, Weekly determinism,
  Practice record safety, unknown mode normalization, mutator normalization,
  snapshot restore/copy isolation, Game delegation, and byte-for-byte save
  preservation for a Practice end/achievement attempt.
- The log contains no `SCRIPT ERROR`, parse error or runtime `ERROR`.

The separate existing save compatibility probe was also run against the live
ConfigFile path:

- `/tmp/kernel-panic-g1-save.log`
- Exit `0`, 39 passes, `SAVE_PROBE_DONE fails=0`.
- It verifies fresh defaults, legacy `best` compatibility, progress loading,
  export/import round-trip and rejection of malformed imports without changing
  the source save.

## Additional verification

- Import: `/tmp/kernel-panic-g1-import.log`, exit `0`. Godot printed the known
  environment warning `Unable to open Android 'build-tools' directory.`
- Full DevHarness: `/tmp/kernel-panic-g1-full.log`, exit `0`, 1414
  `AT_PASS`, 0 `AT_FAIL`, `AUTOTEST_ALL_PASS`.
- Aggregate validator: `/tmp/kernel-panic-g1-validator-summary.log`, final
  `VALIDATION OK`. The G1 case passed with 29/0; accumulated input, R04–R08,
  R18, E2–E4 and vNext cases also passed. Gated runtime ERRORs were zero.
- `git diff --check`: exit `0` before commit.
- Script check for `run_context.gd`: exit `0` with Godot `--check-only`.

The validator continues to report known process-teardown diagnostics as a
separate non-gating section. They are not hidden by G1 and were not attributed
to this change.

## Technical decisions

### Keep `Game` authoritative

Alternative: move mode, stage, seed and record ownership into the new object.
Rejected because it would create a second mutable gameplay controller and
would require Arena/Spawner/save migration before the contracts are stable.
Evidence: all existing start/end paths remain in `Game`, and the full suite and
save probe remain green.

### Use a non-autoload `RefCounted` context

Alternative: make the context an autoload or a Node owned by the scene tree.
Rejected because the contract is a value-like view and should not participate
in lifecycle, pause processing or scene ownership. A `RefCounted` also makes
the ownership boundary explicit and keeps snapshots free of live objects.

### Normalize input snapshots instead of trusting flags

Alternative: restore `writes_records` and `deterministic_seed` directly from
serialized data. Rejected because flags can disagree with the mode. The
implementation derives both from the normalized mode, and the probe feeds
malformed/duplicate values to the restore path.

### Enforce Practice safety at the persistence boundary

Alternative: only report `writes_records() == false` and wait for G3 to make
`end_run()` honor it. Rejected after review: that would advertise a false
contract, because the existing fallback branch would write a Practice score to
the Classic namespace and achievements would still save. The small guard fixes
the actual persistence boundary without implementing Practice selection or
changing current modes.

### Dynamic script construction for the self-class

The file has `class_name RunContext`, but its factories construct through
`load("res://src/gameplay/run_context.gd")`. This follows the existing
`VNextUIContext` pattern and avoids a parser/type-check cycle in the autoload
when the class is loaded from a fresh imported project. The public Game bridge
returns `RefCounted` for the same compatibility reason. The focused check and
runtime probe prove the path works; stronger static typing can be revisited if
Godot's global-class loading behavior is made reliable in this project.

## Compatibility and risk

- No existing save key, transfer format/version, input action, scene, balance
  value, enemy rule, UI route or current mode launch path changed.
- Classic, Story, Weekly and One-HP retain their current record and seed
  behavior; this was checked against the implementation and full suite.
- The new Practice persistence guard is a deliberate behavior for callers that
  already set `Game.mode = "practice"`; there is still no public Practice mode
  entry point.
- `Game.mode` remains a public mutable field. The context normalizes its view,
  but it does not prevent another caller from assigning an unknown value to
  the live field. A later state-owner migration should decide whether to make
  mode changes command-based.
- The context is copy-safe by construction and API convention. It is not a
  language-enforced immutable type because GDScript fields remain writable by
  a caller that intentionally reaches into private members.
- Physical mobile, Android export, localized copy, native screen readers,
  dense-wave performance and human visual approval remain unproven.
- Existing teardown resource/RID/ObjectDB diagnostics remain open.

## Handoff gate

G1 is complete for the planned contract. Do not treat it as completion of G3:
mutator selection, Practice wave selection and Weekly preview/leaderboard work
must add their own gameplay rules and probes. The next bounded implementation
should be E5 or the explicitly ordered gameplay slice, using this context as a
read-only boundary rather than adding direct UI ownership.

# A4 — static content catalog report

Date: 2026-09-01
Worktree: `/tmp/kernel-panic-plan-execution`
Branch: `codex/plan-execution`

## Result

Static program, bestiary, achievement and patch content now has one owner at
`src/data/content_catalog.gd`. `Game.PROGRAM_DEFS`, `Game.BESTIARY_MAP`,
`Game.ACHIEVEMENT_DEFS`, `Game.PATCH_DEFS`, `Game.PATCH_CODES`,
`Game.PATCH_RELATIONS`, `Game.ONEHP_PATCH_EXCLUDED`, and
`BestiaryPanel.ENTRIES` remain public compatibility names and point directly
to the catalog tables. Catalog accessors return `duplicate(true)` copies for
consumers that need mutable data.

`StoryData` was not moved or copied. `Game.STORY_DATA` remains the only stage
source; the probe scans `Game` and `StoryPanel` for duplicate `STAGES` tables.
No enemy constructor, combat rule, Balance value, save key, input path,
localization string, screen route, or visual drawing behavior was changed.

Bestiary entries retain their existing IDs, order, names, descriptions, threat
values and bug notes. Each now also declares an explicit `threat_class` and
`glyph_key`; both are metadata only in this task, so existing drawing continues
to use the same ID/glyph path.

## TDD evidence

### Red

Command:

```text
XDG_DATA_HOME=/tmp/kernel-panic-a4-red-xdg godot --headless --audio-driver Dummy --path . res://tools/content_catalog_probe.tscn
```

Result: exit 1, six `PROBE_FAIL` assertions, and an explicit missing-resource
diagnostic for `res://src/data/content_catalog.gd`. This was the expected
failure before production edits.

### Green

Command:

```text
XDG_DATA_HOME=/tmp/kernel-panic-a4-green-xdg godot --headless --audio-driver Dummy --path . res://tools/content_catalog_probe.tscn
```

Result: exit 0, all probe assertions passed, `PROBE_DONE fails=0`. The probe
covers ID/order parity, compatibility aliases, bestiary required fields,
defensive deep copies, StoryData authority, and deterministic source scans for
duplicate tables or static labels in drawing files.

### Full suite

Command:

```text
XDG_DATA_HOME=/tmp/kernel-panic-a4-full-xdg godot --headless --audio-driver Dummy --path . -- --autotest
```

Result: exit 0, `1414` `AT_PASS`, zero `AT_FAIL`, and `AUTOTEST_ALL_PASS`.
The import prerequisite also exited 0. Teardown still reports the baseline
resource/RID/ObjectDB diagnostics (8 resources, 3 GodotArea2D RIDs, 14 dummy
textures, 147 shaped-text allocations, 2 advanced-font allocations, 10
CanvasItem RIDs and 171 ObjectDB instances); A4 does not claim to fix them.

## Commits

- `b106be8` — `test: add static content catalog parity probe`
- `105d3bb` — `refactor: extract static game content catalog`
- docs commit — `docs: record A4 static content catalog evidence` (this commit)

## Alternatives and risks

- Kept plain GDScript constants instead of introducing `Resource` assets: this
  preserves `Color` values and current public constant access with no import or
  serialization behavior change.
- Kept compatibility constants as direct aliases rather than replacing all
  consumers with accessor calls: this protects harness/UI/Game references and
  avoids a second table while keeping the migration additive.
- Did not move stage data from `StoryData`: code evidence shows it is already a
  dedicated catalog and `Game` consumes it as the authoritative source.
- Did not change enemy constructors: the metadata boundary is possible without
  touching runtime defaults, so constructor changes would add risk without
  serving A4.
- Residual risk: future consumers must use catalog accessors when mutating
  definitions; direct compatibility constants intentionally remain mutable for
  legacy compatibility and should be treated as read-only by convention.

## Independent review and correction

The first implementation was rejected by an independent Luna review. The
initial probe only checked IDs/order plus selected fields, omitted the
`AchievementsPanel` compatibility alias, and did not exercise every
defensive accessor. That was insufficient evidence for the report's parity
and mutability claims.

The probe was strengthened before accepting A4:

- independent fixtures now compare every legacy program field, every legacy
  bestiary field, every patch record, achievement labels/hints, the complete
  bestiary map, patch codes, patch relations, and one-integrity exclusions;
- `AchievementsPanel.ACHIEVEMENT_HINTS` is checked against the catalog;
- all catalog accessors are mutated through returned values, including nested
  patch relations, and are verified not to mutate the source tables;
- the test's sensitivity was demonstrated by a temporary catalog title
  mutation: the probe produced exit 1 with two failures, then the mutation was
  reverted before the green run;
- controller-fresh green evidence: the focused probe exited 0 with
  `PROBE_DONE fails=0`; the full suite exited 0 with 1414 `AT_PASS`, zero
  `AT_FAIL`, and `AUTOTEST_ALL_PASS`.

The source scans remain intentionally lexical smoke checks, not an AST-level
proof against every possible equivalent duplicate construction. The catalog
fixture comparison and the actual source inspection cover the current
implementation; a future schema tool should replace the lexical guard if the
catalog grows or becomes generated.

This correction changed tests and evidence only; no gameplay or catalog
production data changed during the review.

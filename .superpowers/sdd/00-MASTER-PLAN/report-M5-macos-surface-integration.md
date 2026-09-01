# M5 — macOS surface integration and code-drawn release gate

## Status

Implemented and reviewed on 2026-09-01 in the isolated execution worktree.
The Mac history slice now has a focused integration gate covering its authored
story data, era dressing, responsive story surface, named climax bestiary
identity, and entity-presentation projection.

This is an integration milestone, not a claim that the Mac route has received
human visual approval, physical-device validation, or final release approval.

## Requirement and interpretation

M5 was the point where the Mac route had to stop being only a data/spawner
feature. The authored era profiles and climax identity needed to reach the
surfaces that a player will actually read: story selection, code-drawn era
dressing, the bestiary, and the shared entity renderer/adapter.

The integration deliberately keeps the runtime asset policy code-drawn. The
reference moodboard in `media/Ideas/` is treated as art direction only; no
generated or proprietary raster asset was added to the runtime path. The
implementation therefore validates the contracts and geometry without
pretending that automated bounds checks replace a human art review.

## Before and after

Before M5, the Mac story catalog and climax boss existed, but the new boss was
not present in the bestiary registry and the story detail surface showed only
identity, path, briefing, state, and score. An integration failure could leave
the route technically playable while hiding its rule/reward context from the
selection UI. The existing Mac overlay and adapter had no single release-gate
probe proving that all of these surfaces consumed the same authored data at
desktop, square, and narrow phone dimensions.

After M5:

- `PERMISSION ROOT` maps to a stable `permission_root` bestiary ID and has
  compact player-facing counterplay text that fits the current detail/card
  budgets.
- Story detail exposes the stage rule and reward ID alongside its briefing and
  status, making the new route's purpose inspectable before launch.
- The new focused probe exercises all four Mac story stages through the live
  `Game.story_stage_def()` catalog, verifies era profile/overlay consumption,
  checks Mac story detail/list overflow at 1366×768, 720×720, 432×720, and
  390×844, and confirms the Permission Root telegraph survives the entity
  adapter and fits renderer allocations.

## Files and ownership

- `src/data/content_catalog.gd`: bestiary map and entry for Permission Root.
- `src/ui/vnext/surfaces/story_surface.gd`: rule/reward metadata in the
  from-scratch story detail surface.
- `tools/macos_release_gate_probe.gd/.tscn`: integration and responsive gate.
- `.superpowers/sdd/00-MASTER-PLAN/report-M5-macos-surface-integration.md`:
  technical evidence and decisions.
- `docs/HANDOFF-M5-MACOS-SURFACE-INTEGRATION.md`: concise handoff.

## Technical decisions

### Put rule/reward metadata in the story surface, not in the stage renderer

The story catalog remains authoritative for stage behavior and rewards. The
surface reads those fields and renders concise metadata; it does not infer
gameplay or mutate `Game`. This avoids a second source of truth and keeps the
surface useful for future acts.

Trade-off: longer detail content makes narrow layouts more fragile. The
surface's existing measured-entry contract was retained and the new gate
checks both detail and list states across four viewports rather than relying on
one desktop capture.

### Add a stable bestiary identity instead of reusing a generic boss entry

The Permission Root boss has a distinct telegraph and player-facing identity,
so reusing only `ROOT`/`boss` would make the bestiary lie about the encounter.
The new entry uses the same code-drawn boss glyph as a temporary visual
fallback, but its ID, description, threat class, and counterplay copy are
distinct. A future art pass can give it a dedicated glyph without changing
the content or gameplay contract.

### Use one integration probe with explicit limitations

The probe crosses several boundaries because the risk is integration drift,
not a single pure function. It still avoids pretending to be a visual-quality
review: it proves data flow, draw-path contracts and geometry only. Human
inspection of captures, real touch hardware, dense-wave performance and
exported builds remain separate gates.

## Evidence

### Initial probe correction

The first M5 probe attempt exited by timeout because it called non-static
`ContentCatalog` accessors through a script resource. That was a test harness
defect. The probe was corrected to read the catalog's compatibility constants,
which are the same data used by the legacy consumers, and rerun from a fresh
process. The production files were not changed for this correction.

### Focused green

`/tmp/m5-macos-release-gate.log` exited 0 with `PROBE_DONE fails=0` and 26
passes. It verified:

- four live Mac stages and four stable era profiles;
- profile/theme data reaching the code-drawn era overlay without host-OS
  detection;
- stable Permission Root bestiary mapping and readable counterplay copy;
- story detail and list-state overflow at four viewport sizes;
- safe-area containment of story chrome at each tested size;
- boss variant and permission telegraph preservation through the entity
  adapter;
- renderer bounds and a non-color attack-state marker for the climax.

### Integration checks

- Editor import: `/tmp/m5-import.log`, exit 0; the known Android build-tools
  warning remains environmental.
- Existing Mac story probe: `/tmp/m5-story.log`, exit 0, zero failures.
- Existing layout probe: `/tmp/m5-layout.log`, exit 0, 130 passes, zero
  failures.
- `git diff --check`: exit 0.

## Second-pass self-review

The change was reviewed for stale stage indices, missing bestiary mapping,
Mac-only assumptions in shared UI, narrow detail collisions, reward metadata
being treated as an unlock command, and the adapter dropping the telegraph.
The probe uses live stage IDs rather than assuming that the Mac route starts at
a hard-coded index, and the surface remains a read-only projection.

The remaining risks are intentional: the boss still uses the generic boss
glyph, the visual moodboard has not been approved in an interactive playtest,
global English literals remain elsewhere in the legacy UI, and no physical
mobile/performance/export gate has been passed. Those limitations are carried
to the release log rather than hidden by the green probe.

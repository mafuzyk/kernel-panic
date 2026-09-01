# SDD ledger — plan: docs/superpowers/plans/2026-08-31-kernel-panic-master-plan/00-MASTER-PLAN.md

## Execution contract

- Worktree: `/tmp/kernel-panic-plan-execution`
- Branch: `codex/plan-execution`
- Base: `295cc0c` (`docs: close master plan review gaps`)
- Original checkout: `/home/mafu/Projetos/kernel-panic`; preserved and not used for implementation.
- Agent policy: only the GPT-5.6 Luna family may be delegated work. Use the smallest sufficient Luna variant, one narrowly scoped implementer at a time, and no duplicate analysis without a concrete reason.
- Working mode: autonomous, critical, evidence-first, Caveman persona. Every task needs a failing test or a documented reason why a test is not meaningful, an implementation, a fresh verification run, and a second self-review before being marked complete.
- Commit policy: one task per focused commit; explicit path staging only; no merge into `main`; push only after review gates.
- Documentation policy: update technical decision/evidence records during work and compare the final diff against release-facing notes before completion.

## W0 baseline and environment

The clean worktree initially had no generated Godot import state. The first headless run was not accepted as evidence because it produced missing global-class/import failures before the project could execute. The worktree was then imported with:

```text
godot --headless --audio-driver Dummy --path . --editor --quit
```

That import exited 0 but printed the environment warning `Unable to open Android 'build-tools' directory.` This is not yet classified as a product defect; Android export feasibility remains an explicit later gate.

Measured baseline after import:

```text
XDG_DATA_HOME=/tmp/kernel-panic-plan-baseline-20260901 godot --headless --audio-driver Dummy --path . -- --autotest
```

- Exit code: `0`
- `AT_PASS`: `1414`
- `AT_FAIL`: `0`
- Completion marker: `AUTOTEST_ALL_PASS` present
- Runtime `ERROR` lines: `5`
- Runtime `WARNING` lines: `2`
- Baseline teardown diagnostics:
  - 8 resources still in use;
  - 3 `GodotArea2D` RID allocations leaked;
  - 14 dummy textures leaked;
  - 147 shaped-text allocations leaked;
  - 2 advanced-font allocations leaked;
  - 10 CanvasItem RIDs and 171 ObjectDB instances reported by warnings.
- Interpretation: functional suite is green, but process teardown is not clean. No feature task may claim leak resolution without a task-specific reproduction and before/after evidence. These diagnostics are carried forward as open reliability work.
- Log: `/tmp/kernel-panic-plan-baseline-20260901.log`

## Preflight conflict scan

The plan was scanned for shared files, contracts, lifecycle ownership, and order dependencies before runtime implementation. A conflict means that two tasks cannot be safely edited or validated as isolated work unless the shared boundary is explicitly protected.

| Tasks/interface | Relationship | Finding | Ruling | Cost if wrong |
|---|---|---|---|---|
| A1, A2, A3, A4, A5 | Architecture chain | Ownership, data, state, signals, and compatibility decisions all depend on the initial inventory. | A1 establishes evidence and ownership vocabulary first; later architecture tasks must cite it. | Refactors split responsibility and create hidden coupling. |
| A1 | Self-consistency | Inventory must distinguish runtime, content, tools, generated files, and docs. | Use an explicit classification table and do not infer ownership from directory names alone. | Generated or user-local files get committed or deleted accidentally. |
| A2 | Self-consistency | Target boundaries must map to actual Godot scenes, autoloads, scripts, and tests. | Validate each proposed boundary against code references before moving files. | Broken `preload`, `class_name`, scene, or autoload paths. |
| A3 | Self-consistency | Data-driven content can become a second source of truth. | Introduce catalog/schema only where current behavior can be represented and test it against existing data. | Silent balance/story drift. |
| A4 | Self-consistency | State machines and signals cross gameplay, HUD, pause, save, and localization. | Define lifecycle/ownership contracts before extracting state. | Double emissions, stale listeners, or paused-tree races. |
| A5 | Self-consistency | Compatibility needs to cover saves, settings, controls, and old scenes. | Preserve legacy reads and provide migration/rollback gates before changing schemas. | Existing users lose progress or settings. |
| A3 ↔ U1, U2, U2b, U3, U4, U5, U6 | Shared UI data boundary | UI needs snapshots and actions, while gameplay owns mutable state. | UI reads immutable/view snapshots and emits commands; no UI mutation of gameplay state. | UI becomes a second game controller. |
| A4 ↔ L1, L3, M1, E1, E2, E3, U2, U5 | Lifecycle and signal boundary | Settings, locale, story, entities, and UI all subscribe to state changes. | Every connection must have an owner and teardown path; use bound methods, not fragile captures. | Leaked listeners, callbacks after free, non-deterministic teardown. |
| A4 ↔ E1/E2/E3 and U3/U5 | Pause/input boundary | Game simulation pauses while UI/input can remain interactive. | Define event routing and `set_input_as_handled` ownership before new overlays. | ESC/ENTER swallowed, duplicate commands, gameplay running behind menus. |
| E1 ↔ U3, U5, G5, M5, P2, P4 | Entity rendering/content | New code-drawn entities need stable render contracts and performance budgets. | Keep simulation independent from illustration; pool/cache only after measurements. | Art refactor changes hitboxes or causes frame spikes. |
| G1 ↔ G3, G4, G5, G6, G7, M1 | Gameplay progression chain | Enemy variety, bosses, difficulty, and story rewards share spawn and progression rules. | Add content through explicit registries and deterministic tests; do not bypass stage/story gates. | Boss/reward mismatch or impossible progression. |
| G2 ↔ U2b, X1, X2 | Input/action boundary | New enemy interactions may require pointer/touch and accessibility actions. | Define action semantics once and map devices/UI to them. | Mobile and keyboard behavior diverge. |
| G3/G4/G5 ↔ M3/M4, E4 | Boss/enemy/content visuals | Boss phases, enemy telegraphs, and visual readability are coupled. | Gameplay truth drives telegraphs; visuals cannot be the only warning channel. | Unreadable attacks and inaccessible difficulty spikes. |
| M1 ↔ L1, L3, U2 | History/story presentation | macOS history needs narrative data, transitions, localization, and adaptive panels. | Ship story as data plus a presentation layer; do not bury text in drawing code. | Repeated text, localization dead ends, untestable narrative flow. |
| L1, L2, L3, L4 ↔ U2, U5, U6, A11, A14, X5 | Localization UI contract | PT-BR affects sizing, plural/select rules, input labels, and release metadata. | Inventory strings before migration; overflow tests run in both locales and compact layouts. | Clipped text, semantic mistranslation, broken controls. |
| A11–A15 ↔ U5, X3, X5, L4 | Accessibility/settings boundary | Settings controls, reduced motion, contrast, input remap, and localization share persistence. | Use one settings schema with defaults, migration, and independent section tests. | Preferences apply only visually or reset unexpectedly. |
| X1–X5 ↔ U1–U6, P2, P4 | Responsive/mobile boundary | Insets, safe areas, hit targets, virtual controls, and UI composition are cross-cutting. | Measure logical and physical viewport cases; do not claim mobile support from desktop stretch alone. | Touch occlusion, tiny controls, cutouts, or impossible landscape layouts. |
| P1–P5 ↔ E, G, U, X | Performance boundary | Rendering, spawning, text shaping, input, and mobile scale interact. | Establish p50/p95/p99 and worst-frame budgets before optimization; optimize measured hot paths only. | Premature caching or pooling causes stale state and hides regressions. |
| RPO1–RPO4 ↔ T1–T4, G5, M5 | Reliability/release boundary | Save recovery, deterministic runs, error reporting, and release notes need stable diagnostics. | Keep failures visible; separate environment teardown noise from functional failures without masking either. | False green releases or unrecoverable saves. |
| T1–T4 ↔ every code task | Test boundary | Existing harness uses real scenes and input dispatch, but not every future feature has coverage. | Each behavior-changing task adds or updates a focused probe before production code. | “Compiles” becomes the only evidence. |
| W12 ↔ U, E, G, M, L, A, X | Product validation | User value and legibility cannot be inferred from implementation success. | Use targeted playtest criteria and kill/iterate thresholds; visual approval is not automatic. | Large scope produces a technically clean but worse game. |
| 13-Risk/Governance ↔ all task groups | Decision boundary | Many plan choices are conditional on evidence, platform feasibility, or user taste. | Record assumptions, alternatives, reversibility, and stop conditions in the ledger. | Plausible guesses harden into architecture. |

## Preflight rulings

1. **Ruling: W0/A1 evidence before feature expansion** — the clean worktree required resource import and the measured suite exposes teardown leaks; this is the only defensible starting point — **cost if wrong:** feature work begins on an unverified baseline and later failures cannot be attributed.
2. **Ruling: keep legacy runtime playable while vNext is built behind explicit seams** — the user wants a from-scratch UI, but the plan also requires continuous playability, rollback, and release evidence — **cost if wrong:** a mass rewrite creates a long untestable gap or forces premature deletion.
3. **Ruling: code-drawn is the default for enemies/programs; sprites require an explicit gate** — this matches the user’s stated direction and avoids silently growing an asset pipeline — **cost if wrong:** visual work can create memory/load/performance debt before the art direction is proven.
4. **Ruling: no native screen-reader, controller, Android export, or macOS-platform promise until feasibility is demonstrated** — the plan marks those surfaces conditional and the import already showed an Android environment warning — **cost if wrong:** release claims become misleading or impossible to support.
5. **Ruling: preserve observable gameplay and save compatibility unless a documented migration says otherwise** — current probes protect input, story, rewards, and settings; UI remake is not permission to change gameplay contracts — **cost if wrong:** existing runs or user settings break under a visual refactor.
6. **Ruling: use one implementer subagent at a time and only Luna** — the user explicitly prioritizes usage limits, and this plan has sequential shared interfaces rather than many safely independent edits — **cost if wrong:** token waste, conflicting worktrees, and harder attribution.

## Task inventory

| Group | Tasks | Status | Evidence needed |
|---|---|---|---|
| W0 | Baseline/import/ledger | Completed (with open teardown risk) | Green suite marker plus classified diagnostics; import prerequisite recorded. |
| A | A1, A2, A3, A4, A5 | A1–A3 completed (reviewed) | Inventory, ownership map, A2 kit/delegate/landmine revalidation, snapshot contracts, schema/state compatibility probes. A1 docs: `62b0b87` plus `76f6a0f`; A2 docs: `bd51f4c` plus `ead9d28`; A3 feature/docs: `9092163`/`c1a9b3d`/`9c5c112` plus review `0fb5d50`/`7c55b82`. |
| U | U1, U2, U2b, U3, U4, U5, U6 | Pending | vNext foundation, input/flow, responsive/overflow/visual checks. |
| E | E1, E2, E3, E4, E5 | Pending | Code-drawn primitives, entity contracts, visual/readability/perf evidence. |
| G | G1–G7 | Pending | Deterministic gameplay probes and balance/readability validation. |
| M | M1–M5 | Pending | Story data/flow, history content, rewards, localization and save tests. |
| L | L1–L4 | Pending | String inventory, PT-BR behavior, plural/select/Unicode/overflow tests. |
| Accessibility | A11–A15 | Pending | Settings persistence, remapping, contrast/motion/input/touch checks. |
| X | X1–X5 | Pending | PC/mobile viewport, insets, touch, lifecycle, input and performance evidence. |
| P | P1–P5 | Pending | Profiles, budgets, p50/p95/p99, worst-frame and teardown measurements. |
| RPO | RPO1–RPO4 | Pending | Save recovery, diagnostics, reproducible builds, provenance and rollback. |
| T | T1–T4 | Pending | Test taxonomy, flake policy, capture/manual playtest/release gates. |
| UX | W12/product UX | Pending | Playtest questions, observations, prioritized proposals, kill criteria. |
| Governance | 13/Risk/Decision | Pending | Decision log, review gates, risk register, final self-review. |

## Evidence ledger

| Date | Scope | Evidence | Result | Open risk |
|---|---|---|---|---|
| 2026-09-01 | W0 baseline after Godot import | `--autotest` with Dummy audio, exit 0, 1414 passes, 0 fails, completion marker present | Functional baseline green | 5 teardown errors and 2 warnings; classify and reduce under P tasks. |
| 2026-09-01 | Worktree isolation | `git worktree list`, branch `codex/plan-execution`, original checkout unchanged by execution | Isolation confirmed | Generated `.uid`/capture import artifacts exist only in execution worktree and must not be staged accidentally. |
| 2026-09-01 | A1 repository baseline | `62b0b87` reviewed against `project.godot`, `export_presets.cfg`, `src/autoload/game.gd`, `src/autoload/sfx.gd`; docs corrected by `76f6a0f` | Accepted: no runtime change; repository map, save keys, transfer version, exports and diagnostics recorded | Android build-tools warning; teardown leaks; exact engine/export feasibility still needs dedicated verification. |
| 2026-09-01 | A2 owner-owned kit revalidation | Structural grep/audit plus `XDG_DATA_HOME=/tmp/kernel-panic-a2-xdg godot --headless --audio-driver Dummy --path . -- --autotest` | Accepted: delegates and source-scan landmines present; exit 0, 1414 passes, 0 failures, `AUTOTEST_ALL_PASS`; documentation-only | Controller-generated ignored brief was not visible to delegated inspection; versioned plans were used. Teardown diagnostics remain open. |
| 2026-09-01 | A3 snapshot contracts | Focused red/green probes, forced watchdog failure, and controller-fresh full suite; `0fb5d50`/`7c55b82` add live patch-offer projection after adversarial review | Accepted: four real owners expose primitive-safe, deep-copied schemas; focused final 32/0; full suite 1414/0 with marker | No vNext renderer consumer yet; optional-field consumer behavior and actual drawing remain future evidence; teardown diagnostics remain open. |

## Change log of approach

- Initial direct test attempt was rejected as evidence because a newly created worktree lacked imported Godot resources. Import was performed first; this is recorded as an environment prerequisite, not a code fix.
- A3 added the first runtime contract methods in `Game`, `Arena`, `Menu`, and `Sfx`, plus a focused probe. The controller later corrected a false empty patch-offer projection.
- A1 agent report incorrectly described the `lifetime` save section as a separate file. Controller verification of `Game._record_run()` showed it loads and saves `Sfx.SAVE_PATH`; both baseline documents were corrected in `76f6a0f` before acceptance.
- A2 report initially described the generated task brief as absent. The controller confirmed the ignored brief existed before delegation but was not visible to the delegated inspection; the report was corrected in `ead9d28` and the versioned plans remained the source of truth.
- Next task: A4 split static content from runtime logic. A2 revalidation is documented in `report-A2.md`; A3 is documented in `report-A3.md` with its controller correction.

## A4 static content catalog

- Status: completed on 2026-09-01.
- Probe red: `XDG_DATA_HOME=/tmp/kernel-panic-a4-red-xdg godot --headless --audio-driver Dummy --path . res://tools/content_catalog_probe.tscn` — exit 1 with six explicit failures because the catalog resource did not exist yet.
- Probe green: `XDG_DATA_HOME=/tmp/kernel-panic-a4-green-xdg godot --headless --audio-driver Dummy --path . res://tools/content_catalog_probe.tscn` — exit 0 with `PROBE_DONE fails=0`; verifies IDs/order, aliases, bestiary fields, deep-copy accessors, StoryData authority, and source-scan non-duplication.
- Full suite: `XDG_DATA_HOME=/tmp/kernel-panic-a4-full-xdg godot --headless --audio-driver Dummy --path . -- --autotest` — exit 0, `1414` `AT_PASS`, zero `AT_FAIL`, `AUTOTEST_ALL_PASS`.
- Changed files: `src/data/content_catalog.gd`, `src/autoload/game.gd`, `src/ui/bestiary_panel.gd`, `src/ui/achievements_panel.gd`, `tools/content_catalog_probe.gd`, `tools/content_catalog_probe.tscn`, and `report-A4.md`.
- Source authority: `ContentCatalog` owns programs, bestiary metadata/map, achievements/hints, patches/codes/relations/exclusions. `StoryData` remains the sole stage/act catalog. Compatibility constants are direct aliases; accessor methods deep-copy nested data.
- Alternatives: no `Resource` asset boundary, no UI consumer rewrite, no StoryData move, and no enemy constructor changes; all were unnecessary for behavior-preserving extraction.
- Compatibility/risk: public names and data order remain stable; save keys and gameplay are unchanged. Direct aliases are legacy read-only surfaces, while mutable consumers should use catalog accessors. Baseline teardown diagnostics remain open and are not attributed to A4.
- Commits: `b106be8` (focused test), `105d3bb` (refactor), and this docs commit.
- Independent review initially rejected the evidence: the probe did not prove
  full legacy-value parity, omitted `AchievementsPanel.ACHIEVEMENT_HINTS`,
  and covered only two of the defensive accessors. The controller strengthened
  `tools/content_catalog_probe.gd` with independent legacy fixtures, the
  missing alias assertion, and mutation checks for every accessor, including
  nested patch relations. A temporary catalog mutation produced exit 1 with
  two probe failures, then was reverted. Controller-fresh green evidence after
  the correction: focused probe exit 0 with `PROBE_DONE fails=0`; full suite
  exit 0 with 1414 passes, zero failures, and `AUTOTEST_ALL_PASS`.
- A4 is accepted after correction. Residual limitation: duplicate-source
  guards are lexical scans, not an AST proof; this is explicitly recorded in
  `report-A4.md`. No production data or gameplay behavior changed during the
  correction.

## A3 snapshot contracts

- Status: completed and adversarially corrected on 2026-09-01.
- Red probe: `XDG_DATA_HOME=/tmp/kernel-panic-a3-red-xdg godot --headless --audio-driver Dummy --path . res://tools/snapshot_contract_probe.tscn` — exit 1, 12 failures caused by the four absent methods and dependent assertions.
- Green probe (initial): `XDG_DATA_HOME=/tmp/kernel-panic-a3-green-xdg-3 godot --headless --audio-driver Dummy --path . res://tools/snapshot_contract_probe.tscn` — exit 0, 30 `PROBE_PASS`, 0 `PROBE_FAIL`, `PROBE_DONE fails=0`.
- Hanging-process diagnostic: after the interrupted run, no exact Godot processes remained. A clean reproduction exited in 1.1s. The probe now has an explicit 8s failure watchdog; forced red run with `KP_A3_FORCE_WATCHDOG=1` exited 2 with `PROBE_FAIL watchdog timeout`, and left no Godot processes.
- Full suite: `XDG_DATA_HOME=/tmp/kernel-panic-a3-full-xdg godot --headless --audio-driver Dummy --path . -- --autotest` — exit 0, `AT_PASS=1414`, `AT_FAIL=0`, `AUTOTEST_ALL_PASS`.
- Teardown diagnostics: 8 resources, 3 GodotArea2D RIDs, 14 dummy textures, 147 shaped-text allocations, 2 advanced-font allocations, 10 CanvasItem RIDs, and 171 ObjectDB instances; treated as baseline/open risk, not an A3 fix.
- Adversarial red: `XDG_DATA_HOME=/tmp/kernel-panic-controller-a3-patch-red2-20260901 godot --headless --audio-driver Dummy --path . res://tools/snapshot_contract_probe.tscn` — exit 1, 30 passes, 2 fails, `PROBE_DONE fails=2`, zero script errors.
- Adversarial green: `XDG_DATA_HOME=/tmp/kernel-panic-controller-a3-patch-green-20260901 godot --headless --audio-driver Dummy --path . res://tools/snapshot_contract_probe.tscn` — exit 0, 32 passes, 0 fails, `PROBE_DONE fails=0`, zero script errors.
- Changed files: `src/autoload/game.gd`, `src/autoload/sfx.gd`, `src/ui/menu.gd`, `src/arena/arena.gd`, `tools/snapshot_contract_probe.gd`, `tools/snapshot_contract_probe.tscn`, plus this report and ledger entry.
- Commits: `9092163` test probe; `c1a9b3d` production snapshot contracts; `9c5c112` explicit probe watchdog.
- Proven facts: all four real owners expose primitive-safe snapshots with schema metadata, required-field checks, deep-copy isolation, stable RNG/save/node counts, and no live-consumer migration. Drawing itself is not proven because no vNext renderer consumes the contracts.
- Alternatives: no shared Resource boundary, no UI consumer replacement, and no state ownership moved to kits; all rejected to preserve A3 scope and behavior.
- Assumptions/risks: entity-specific optional fields may grow later; optional-field tolerance needs explicit vNext consumer coverage; teardown noise remains open from W0.

## Review checklist for every task
## A5 migration, rollback and deprecation checkpoint

- Status: completed on 2026-09-01.
- Red probe: XDG_DATA_HOME=<isolated-dir> godot --headless --path . res://tools/save_compatibility_probe.tscn — exit 1 with SAVE_PROBE_DONE fails=2; malformed run/story objects reached typed Dictionary assignments in Game.import_save_string().
- Green probe: XDG_DATA_HOME=<isolated-dir> godot --headless --audio-driver Dummy --path . res://tools/save_compatibility_probe.tscn — exit 0 with SAVE_PROBE_DONE fails=0.
- Probe coverage: fresh profile; progressed story profile; missing and legacy optional keys; real-path export/import round-trip; malformed/truncated inputs; byte-for-byte preservation of the source save after each rejected import; 10-second watchdog; non-zero failure exit.
- Files: tools/save_compatibility_probe.gd, tools/save_compatibility_probe.tscn, and src/autoload/game.gd; report in report-A5.md.
- Bug fixed minimally: validate run, weekly, and story payload types before typed use or ConfigFile writes. No gameplay/UI behavior, save key, transfer version, or res:// path changed.
- Before/after: before, malformed structured input produced script errors; after, it returns false and leaves source bytes unchanged. Accepted import keeps current v1 normalization, so sparse story maps may canonicalize on re-export.
- Contract: Sfx.SAVE_PATH remains user://kernel_panic.cfg; Game.SAVE_TRANSFER_FORMAT remains kernel-panic-save; Game.SAVE_TRANSFER_VERSION remains 1. Existing public export/import helpers remain the runtime compatibility boundary.
- Deprecation/removal gate: do not remove or rename the helpers until a replacement has repository-wide zero-consumer evidence, real Menu/Arena scene-load coverage, save round-trip and invalid-import byte-preservation, input probe, full autotest, and rollback-route proof. Current status is runtime-reachable, not test-only or dead.
- Decision: no new schema or migrator. Current v1 already has defaults, legacy run.best fallback, known-ID filtering, and numeric normalization; another schema would add an unneeded authority and rollback surface.
- Full-suite gate: record a fresh godot --audio-driver Dummy --headless --path . -- --autotest run before accepting this checkpoint. Baseline reference remains 1414 AT_PASS, zero AT_FAIL, AUTOTEST_ALL_PASS, with known teardown diagnostics.
- Full suite: XDG_DATA_HOME=/tmp/kernel-panic-a5-full-xdg-2 godot --audio-driver Dummy --headless --path . -- --autotest — exit 0, AT_PASS=1414, AT_FAIL=0, AUTOTEST_ALL_PASS. Teardown diagnostics match baseline and remain open.


- Read the micro-plan and current code, then inspect shared interfaces.
- Add/adjust a focused failing probe before production code where behavior changes.
- Implement the smallest compatible change; do not opportunistically rewrite unrelated code.
- Run focused verification and relevant regression suite with Dummy audio.
- Re-read the diff as an adversarial reviewer: lifecycle, paused input, save compatibility, responsive geometry, localization, performance, error paths.
- Record proven facts, assumptions, residual risks, and validation method here and in the relevant handoff/release document.
- Commit only explicit task paths; keep unrelated user artifacts out of the commit.

# KERNEL PANIC — Master Product and Release Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Each task must be completed, tested, documented, committed and handed off before the next dependent task begins.

**Goal:** Transform KERNEL PANIC from a complete hobby prototype into a small, polished, free and open-source game with a maintainable codebase, a from-scratch adaptive UI, expressive code-drawn entities, stronger gameplay, a new macOS history act, PT-BR support, accessibility, and release-grade repository practices.

**Architecture:** Work in vertical, independently shippable slices. First stabilize boundaries and evidence, then build the vNext UI foundation, then migrate screens and entity art without changing gameplay accidentally. Gameplay expansion, localization, accessibility, responsive behavior, performance and release operations are separate workstreams connected by shared contracts (`Game`, `Sfx`, localization, snapshots, safe-area layout and DevHarness), never by hidden cross-screen state.

**Tech Stack:** Godot 4.7.2, GDScript with tabs, `gl_compatibility`, code-drawn `CanvasItem._draw()` surfaces, existing `GlyphLib`, Godot input and touch events, local `ConfigFile` persistence through existing helpers, DevHarness plus real viewport probes, Linux/Xvfb capture validation, Linux/Windows/Android exports, MIT-licensed open-source repository.

**Spec:** [UI redesign direction](../../../UI-REDESIGN-DIRECTION.md), [consolidated audit](../../../REVISAO-CONSOLIDADA-2026-08-31.md), [code-audit handoff](../../../HANDOFF-CODE-AUDIT-UI-DIRECTION.md), and the supporting micro-plans in this folder.

## Global Constraints

- Godot 4.7.2 and `gl_compatibility` remain the supported runtime baseline.
- The logical base viewport remains 1280×720, but no new feature may assume that physical window size; every surface receives a measured viewport and safe rectangle.
- GDScript uses tabs. Do not reformat unrelated files or rewrite legacy code merely for style.
- Code-drawn geometry is the source of truth for layout, state, hit testing, entity silhouette and gameplay feedback.
- Raster or generated art is optional and gated; it may not replace a readable code-drawn fallback without a side-by-side review at gameplay size.
- The game remains free, offline-friendly and open source. No account, ads, energy system, telemetry service or network dependency is introduced by this plan.
- Existing saves, keybinds, story progress, achievements and portable save transfer remain readable. Any schema change requires an explicit versioned migration and a backward-compatibility probe.
- Existing gameplay fixes are preserved, including R01–R10, B1/B2/B5, R18, ownership fixes, the ROOTLET overflow decision and the sprite gate.
- Every behavioral change starts with a failing real-path test or probe, then a minimal implementation, then the full suite.
- Validation runs silently with `--audio-driver Dummy`; captures are inspected separately and generated capture imports are never committed accidentally.
- A task is not complete until its handoff records changed files, bugs found, fixes, additions, tests, known limitations and release-facing behavior.
- Work uses `codex/<scope>` branches, explicit path staging, small commits and non-force pushes. The main branch is never changed directly by an agent.

## Product Thesis

KERNEL PANIC is a fast twin-stick survival game about a single process trying to
outlive an operating system that has become hostile. Its strongest identity is
not “neon UI”; it is the collision between readable arcade action and a system
that speaks in terminal diagnostics, process names, memory pressure, patches,
crashes and absurd technical mythology.

The release target must therefore satisfy two standards at the same time:

1. **As a game:** movement, aiming, dashing, overclocking, enemy counterplay,
   patch choices, difficulty and death/retry must feel immediate and fair.
2. **As a product:** a new player must understand how to start, what happened,
   why they died, what changed, how to configure the game and where to report a
   problem without reading source code.

The visual target is the reference family in `media/Ideas/`, interpreted as a
moodboard rather than a pixel-perfect specification. The final design may be
sparser than the references when mobile space, readability or performance
demands it.

## Current Baseline and Non-Goals

The current UI is an approved technical/intermediate state, not the final
composition. The vNext foundation already exists under `src/ui/vnext/`, and the
current branch contains real fixes for input dispatch, projectile ownership,
ROOTLET recharge, TempleOS GOD spawning, story restart, OOM loot ownership,
terminal behavior, multitouch and lifecycle-safe HUD signals. Those fixes are
not to be lost during the remake.

The pre-remake execution checkpoint recorded 1453 harness passes with zero
assertion failures, 32 input-probe passes headless, 34 input-probe passes under
Xvfb with desktop debug controls enabled, and passing R04–R08, B1/B2/B5, R18
and vNext entity/primitive probes. The current reference-remake branch
(`fuzzy/ui-reference-remake`, tip `28d2a48`) has a newer accumulated baseline:
1454 harness passes, 38 input-probe passes headless, 40 input-probe passes
under Xvfb, and zero gateable runtime errors. Its current UI-specific gates
include the reference-shell, entity, responsive, legacy HUD, N1–N4 and P1/P3/P4
probes; the complete matrix is recorded in
`docs/FINAL-UI-REFERENCE-REMAKE-REPORT.md`. Teardown resource/RID diagnostics
remain a separately tracked investigation. Future changes must record their
own current baseline instead of assuming these numbers remain unchanged.

The first release cycle under this plan does **not** attempt to:

- preserve every current panel, coordinate, label or decorative line;
- convert every existing screen in one massive commit;
- replace all code-drawn entities with sprites;
- add online leaderboards, accounts, cloud saves or analytics;
- implement every possible accessibility preference before the core settings
  contract is reliable;
- add enemies without a clear telegraph, counterplay and testable identity;
- optimize by guessing instead of profiling a fixed-seed run.

## Workstreams and Dependency Graph

| ID | Workstream | Depends on | Primary output |
| --- | --- | --- | --- |
| W0 | product baseline and repository safety | none | measured baseline, branch rules, release ledger |
| W1 | repository organization and refactor | W0 | focused modules with compatibility shims |
| W2 | UI vNext remake | W1 | new shell, surfaces, navigation and responsive geometry |
| W3 | code-drawn entity art | W1, W2 foundation | readable legacy programs/enemies and state language |
| W4 | gameplay and new enemies | W0, W1, W3 contracts | stronger loop, new threats, modes and balance evidence |
| W5 | macOS history act | W1, W2, W3, W4 | hand-authored story arc with new era identity |
| W6 | localization and PT-BR | W2 foundation, W5 content | complete English fallback + Brazilian Portuguese catalog |
| W7 | accessibility | W2 foundation, W6 text keys | dedicated settings section and redundant feedback |
| W8 | PC/mobile UX and responsive behavior | W2, W7 | input-specific layouts, onboarding and safe-area behavior |
| W9 | performance and reliability | W1–W8 incrementally | budgets, profiling, ownership and regression gates |
| W10 | repository and release operations | W0, W9 | CI, contribution docs, release checklist and release log |
| W11 | risk, decision and change governance | W0; reviewed at every checkpoint | rollback policy, stop-the-line gates and scope control |
| W12 | product UX and feature prioritization | W0; final sign-off with W2/W4/W7/W8 | player journey, playtest protocol and idea filter |

The workstreams overlap only where their contracts are already stable. For
example, PT-BR can start with the menu catalog before the macOS story exists,
but final localization acceptance waits until the new story content has keys.
Accessibility can add data contracts early, but visual acceptance waits for the
new UI surfaces so effort is not spent polishing legacy layouts that will be
removed.

## Release Train

The exact semantic version is chosen only when the corresponding acceptance
gate is green. The release names below are stable planning milestones, not
promises of a particular number.

### Release A — Foundation

- W0 measured baseline and repository safeguards.
- W1 module boundaries and compatibility tests.
- W2 menu boot vertical slice in the new visual language.
- W9 first performance baseline.

This release is useful even if the old screens still exist: the new route is
behind an explicit development switch or replaces only one approved surface.

### Release B — Playable remake

- New menu, program selection, story selection, patch selection, pause,
  terminal, game-over and HUD surfaces.
- W3 entity silhouette/state pass for the existing cast.
- W7 minimum accessibility tab and W8 responsive input/layout acceptance.

The old UI may remain as a fallback during this release, but it cannot be the
default once every replacement screen has a flow probe and visual review.

### Release C — Content expansion

- W4 new enemies, practice and mutator improvements, balance pass.
- W5 macOS history act with its own story, stage rules and code-drawn identity.
- W6 complete PT-BR coverage for shipped content.

### Release D — Public-quality maintenance

- W9 performance, teardown and device matrix complete.
- W10 CI, contribution workflow, changelog/release log and package checklist.
- W11 governance gates and W12 product playtest/priority evidence.
- Regression-free exports for the supported platforms and a public release
  candidate playtest.

## Universal Task Protocol

Every implementation task in the micro-plans follows this exact loop:

- [ ] Record the current branch, commit, test baseline and affected user flow.
- [ ] Identify the smallest interface and the files that own it.
- [ ] Write a failing test/probe for the real path, including the relevant
  viewport or input mode.
- [ ] Run the targeted test and retain the red log outside the repository.
- [ ] Implement the minimum change that makes the test green.
- [ ] Run the targeted test again, then the full validation command.
- [ ] Capture wide, compact and narrow views when the task changes visuals.
- [ ] Inspect the diff for unrelated changes, generated files, ownership and
  save compatibility.
- [ ] Update the handoff and the release ledger before committing.
- [ ] Re-check scope, decision gates and rollback after the implementation
  result; a test passing does not approve an unreviewed expansion.
- [ ] Commit one coherent task, push without force and stop for review at the
  checkpoint defined by the micro-plan.

The current validation entrypoint is:

```sh
XDG_DATA_HOME=/tmp/kernel-panic-test-data \
  godot --headless --audio-driver Dummy --path . -- --autotest
```

The project validator in `tools/validate_input_dispatch.sh` should remain the
single aggregate gate while new probes are added to it. A green test with a
missing completion marker, suppressed error or empty execution is a failure.

## Definition of Done for the Entire Plan

The plan is complete only when all of these are true:

- New UI surfaces are genuinely composed from scratch and do not merely restyle
  the old menu geometry.
- The reference language is recognizable in a clean, grayscale capture, but
  the interface remains readable at narrow mobile sizes.
- Every shipped enemy and program has a distinct code-drawn silhouette, state
  channel, telegraph and bestiary explanation.
- Existing mechanics are preserved unless a documented gameplay decision says
  otherwise; every change has a red/green evidence trail.
- The macOS history act is playable, unlockable, localized and covered by a
  real story progression probe.
- English fallback and PT-BR are complete for all player-visible shipped text;
  no raw key or accidental mixed-language surface reaches release.
- Accessibility has a dedicated settings area, persisted preferences,
  redundant state communication and input accommodations for desktop and touch.
- Menus, HUD, pause, terminal and game-over work in wide, compact and narrow
  logical viewports without text clipping or inaccessible actions.
- Performance targets are measured on at least one desktop and one
  representative Android device/profile; no optimization claim is based only
  on headless tests.
- CI and release documentation can reproduce tests and exports from a clean
  checkout, and every user-facing change since this plan began has a release
  log entry.
- The plan itself has no unresolved dependency, ownership, platform, save,
  localization, accessibility, legal or rollback gap hidden behind a vague
  “later” note; every deferred decision has an owner, gate and reason.

## Micro-Plan Index

- [01 — repository organization and refactor](01-REPOSITORY-ARCHITECTURE.md)
- [02 — UI remake from scratch](02-UI-REMAKE-VNEXT.md)
- [03 — code-drawn programs and enemies](03-CODE-DRAWN-ENTITY-ART.md)
- [04 — gameplay, balance and new enemies](04-GAMEPLAY-AND-ENEMY-EXPANSION.md)
- [05 — macOS history act](05-MACOS-HISTORY-ACT.md)
- [06 — localization and PT-BR](06-LOCALIZATION-PT-BR.md)
- [07 — accessibility and dedicated settings](07-ACCESSIBILITY-SETTINGS.md)
- [08 — PC/mobile UX and responsiveness](08-PC-MOBILE-UX.md)
- [09 — performance and reliability](09-PERFORMANCE-RELIABILITY.md)
- [10 — repository, open source and releases](10-REPOSITORY-RELEASE-OPERATIONS.md)
- [11 — testing, reporting and release log](11-TESTING-REPORTING-RELEASE-LOG.md)
- [12 — product UX and suggestions](12-PRODUCT-UX-AND-SUGGESTIONS.md)
- [13 — risk, decisions and change governance](13-RISK-DECISION-GOVERNANCE.md)

## Review and Handoff Rule

This master plan is the map, not permission to skip review. Each micro-plan
may be executed only after its preceding dependency has a green checkpoint.
When implementation reveals a requirement that changes gameplay, save format,
platform support or the visual thesis, stop at the current task, record the
conflict in the handoff and update the affected micro-plan before coding
further.

The final report must link every implementation commit and summarize, in
release-ready language: bugs found, reproduction, root cause, fix, new
behavior, files changed, tests, captures, performance observations,
accessibility impact, localization impact, known limitations and migration
notes. The reporting contract is detailed in [11](11-TESTING-REPORTING-RELEASE-LOG.md).

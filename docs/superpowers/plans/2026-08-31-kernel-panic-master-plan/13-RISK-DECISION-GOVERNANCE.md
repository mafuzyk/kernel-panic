# KERNEL PANIC — Risk, Decision and Change Governance Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` when implementing a governed change. This document prevents a large redesign from becoming an unreviewable rewrite.

**Goal:** Keep the master plan executable as it grows by making scope changes,
open decisions, rollback, quality gates and stop-the-line risks explicit.

**Architecture:** Every workstream has a local acceptance gate and a shared
release gate. A feature enters through a small design decision, ships behind a
reversible route while necessary, and is removed or promoted only after
evidence. Handoffs are the historical record; this document is the policy that
decides when work may continue.

**Tech Stack:** Git branches, Markdown decision records, Godot probes,
DevHarness, isolated saves, Xvfb/device captures and the release log contract.

**Spec:** [master plan](00-MASTER-PLAN.md), [testing/reporting](11-TESTING-REPORTING-RELEASE-LOG.md), [repository operations](10-REPOSITORY-RELEASE-OPERATIONS.md), and [product UX filter](12-PRODUCT-UX-AND-SUGGESTIONS.md).

## Global Constraints

- A scope change is recorded before implementation resumes.
- A failing release gate blocks promotion; it is not relabeled as a cosmetic issue.
- Every temporary compatibility path has an owner, a reason, a test and a removal gate.
- No branch is merged because it is large, old or expensive to redo.
- A rollback must preserve player saves and the last accepted playable route.
- Unknowns become explicit decision gates with a recommendation and a deadline tied to a workstream.

## Stop-the-Line Conditions

Stop the current workstream and update its handoff when any of these occurs:

- an existing save cannot load, export or import without loss;
- a current mode changes behavior without a documented gameplay decision;
- a player cannot start, pause, resume, retry or abandon through a supported input method;
- a threat, boss telegraph or critical state is hidden at a supported viewport;
- a translated surface exposes a raw key, clips the primary action or becomes mixed-language;
- mobile frame pacing, heat, memory or touch ownership becomes materially worse;
- a new enemy has no readable counterplay or causes an unavoidable one-HP failure;
- a runtime error, orphan/resource growth or duplicate reward appears;
- a new asset has unclear license/provenance or a platform claim is untested;
- CI and local validation disagree about the same commit.

## Risk Register

| ID | Risk | Impact | Mitigation and gate |
| --- | --- | --- | --- |
| K01 | the UI remake becomes a one-to-one migration | visual stagnation and duplicated code | require a new snapshot/layout/action map and visual review before adapter work |
| K02 | legacy and vNext both mutate state | duplicate actions, leaks and inconsistent saves | one owner per route, adapter-only legacy path, route probe |
| K03 | save schema breaks during new acts/settings | player progress loss | versioned migration fixtures and failure-preserving import |
| K04 | desktop reference is forced onto mobile | clipped text, blocked controls and unfair combat | density-specific composition, safe-area matrix and device playtest |
| K05 | code-drawn detail becomes expensive | frame drops and unreadable visual noise | silhouette-first art review, quality tiers and fixed-seed profiling |
| K06 | new enemies add complexity without mastery | frustration and shallow roster | threat sheet, isolated teach wave, counterplay probe and bestiary copy |
| K07 | localization arrives after layouts freeze | PT-BR clipping and mixed grammar | stable keys before content, placeholder checks and visual copy review |
| K08 | accessibility options are cosmetic promises | players still cannot read/control the game | option-to-runtime matrix and high-contrast/reduced-motion probes |
| K09 | macOS act expands beyond finishable scope | unfinished content delays core polish | four-stage default scope, asset/license gate and act-specific exit criteria |
| K10 | tests pass while runtime errors remain | false release confidence | completion markers, error gates and categorized teardown report |
| K11 | performance is inferred from headless/desktop only | mobile release regressions | real device/profile evidence and measured quality tiers |
| K12 | external references/assets create legal or repo debt | takedown risk and bloated repository | code-drawn default, attribution index and asset review before commit |
| K13 | optional features fragment the default experience | onboarding and mode confusion | product decision filter, feature flags and one primary path |
| K14 | CI/export drift blocks contributors | project becomes hard to build | pinned engine/export instructions and clean-checkout job |

## Decision Gate Protocol

Each gate has one required artifact and one allowed outcome: pass, revise or
defer. “Continue and remember later” is not an outcome.

### Gate G0 — baseline and scope

Required: current commit, test counts, runtime diagnostics, supported platforms,
save fixtures, worktree inventory and a user-facing goal. Pass means the task
can be isolated and rolled back.

### Gate G1 — architecture

Required: owner map, public interfaces, dependency direction, migration path
and test plan. Pass means no new system needs to reach into arbitrary private
nodes or create an untracked save path.

### Gate G2 — visual vertical slice

Required: clean code-drawn capture at wide/compact/narrow, grayscale review,
action map, overflow report and reduced-motion/high-contrast variants. Pass
means the surface has personality and hierarchy before effects.

### Gate G3 — gameplay/content

Required: mechanic specification, telegraph/counterplay description, red/green
probe, balance comparison and mobile/PC playtest notes. Pass means the feature
improves a player decision without making an old mode silently different.

### Gate G4 — localization/accessibility

Required: catalog parity, placeholder report, translated screenshots,
accessibility profile snapshot and input/state matrix. Pass means the feature
does not leave language, focus or sensory alternatives behind.

### Gate G5 — release candidate

Required: clean-checkout CI, exports, save migration, manual smoke run, device
profile, full release log and known-limitations list. Pass means the build is
safe to distribute; missing polish is not enough to pass this gate.

## Reversibility Rules

- New screens may use a development route or feature flag while their probes
  mature. The flag is removed in a separate cleanup commit after acceptance.
- New gameplay content enters disabled or unreachable until its stage/wave
  probe passes; no half-registered enemy appears in procedural selection.
- Save migrations write to a safe temporary representation, validate it, then
  replace the old data through existing helpers. A failed migration leaves the
  source intact.
- Localization falls back to complete English strings, never an empty label or
  raw key.
- A performance regression can lower cosmetic quality tier or revert the
  measured hot-path change without reverting unrelated correctness fixes.
- Reverting a commit is acceptable; rewriting public history or force-pushing
  a shared branch is not.

## Scope Change Record

When a request grows, add a short entry to the current handoff:

```markdown
### Scope change — [date]
- Trigger: [request or discovery]
- Affected workstream: [W0–W12]
- Why the existing plan is insufficient: [concrete gap]
- Recommendation: [smallest safe change]
- New files/contracts/tests: [exact paths]
- Dependency or release impact: [what moves]
- Decision: accept | split | defer
```

All fields are required content. A split change gets its own micro-plan; a
deferred change goes into the idea filter with a reason.

## Plan Review Protocol

At the end of each release train, review this master plan itself against the
repository, the current handoffs and the user-facing build. Check four things:
the dependency graph still matches reality, every promised artifact has an
owner, every deferred decision has a gate, and no acceptance criterion can be
passed without the evidence that makes it meaningful. This is a document
review, not permission to implement the next feature during the review.

The reviewer records the review date, commit, documents inspected, gaps found,
changes made and remaining risks. A plan amendment gets its own documentation
commit and does not silently rewrite the reason a previous task was accepted.
If the amendment changes save format, record policy, platform support, visual
thesis or the default player journey, it requires an explicit decision before
the affected workstream resumes.

Use these decision states consistently:

- **accepted:** implementation may proceed within the recorded scope;
- **split:** the request is valid but requires a smaller independent slice;
- **deferred:** valuable but intentionally outside the current release train;
- **rejected:** conflicts with product, platform, legal or maintenance rules;
- **blocked:** evidence or external capability is missing, with an owner and
  next check recorded.

“Open” is not a final state. Every accepted, split, deferred or blocked item
must state what evidence changes its state and who is responsible for collecting
it.

## Current Decisions Already Locked

- The existing UI is an approved intermediate playable state, not the final
  design.
- The new UI is from scratch; code-drawn geometry is the primary art language.
- Enemies and programs remain code-drawn by default; raster is gated.
- ROOTLET full-shield mote overflow is approved and gives the existing +5/scrap
  progression behavior.
- “MAC-OS history” means a new macOS history/story act in this plan; terminal
  history/autocomplete is already implemented.
- Validation is silent with `--audio-driver Dummy` and isolated saves.
- The project remains free/open source without account, ads, energy or network
  requirements.

## Acceptance Gates

- [ ] Every nontrivial decision has a location, recommendation, owner, review point and acceptance condition.
- [ ] Every temporary path has a rollback route and removal condition.
- [ ] Save, input, accessibility, localization, legal and performance risks are reviewed before release.
- [ ] Scope growth creates a split plan instead of silently expanding a task.
- [ ] Stop-the-line conditions are mentioned in the relevant handoff when triggered.
- [ ] The release candidate can be reconstructed from the decision record, handoffs and release log.
- [ ] Each release train has a dated self-review of this plan with gaps and amendments preserved.

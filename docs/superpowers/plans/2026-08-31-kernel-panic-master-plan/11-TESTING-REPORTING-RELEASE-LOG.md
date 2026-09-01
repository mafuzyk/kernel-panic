# KERNEL PANIC — Testing, Reporting and Release Log Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans`. No task is complete until the evidence and release-facing report are written while the details are still fresh.

**Goal:** Create a trustworthy evidence system that catches gameplay/UI
regressions, proves desktop/mobile behavior, and turns every future code change
into a usable release-log entry containing bugs, fixes, improvements and new
content.

**Architecture:** Use a test pyramid: pure contracts for cheap rules, real-path
Godot probes for scene/input/save behavior, visual captures for composition,
device profiles for performance/touch and manual playtests for feel. The
aggregate validator gates correctness; handoffs and the release ledger preserve
the human explanation of each change.

**Tech Stack:** Godot 4.7.2 headless/Xvfb, DevHarness, deterministic probes,
shell validation, Markdown reports, optional Android/device captures and the
existing `tools/validate_input_dispatch.sh` entrypoint.

**Spec:** [master plan](00-MASTER-PLAN.md), [repository architecture](01-REPOSITORY-ARCHITECTURE.md), [UI remake](02-UI-REMAKE-VNEXT.md), and the existing handoffs under `docs/`.

## Global Constraints

- Tests must exercise the real dispatch/lifecycle path when the bug is about
  dispatch/lifecycle; direct helper calls are supplemental only.
- Every validator has a nonzero failure path and a required completion marker.
- Headless tests use isolated `XDG_DATA_HOME` and `--audio-driver Dummy`.
- Xvfb is required for desktop debug input and visual window behavior.
- Touch behavior uses forced-touch probes plus physical-device verification
  when hardware-specific behavior matters.
- Visual review does not claim pixel equality with a moodboard; it checks
  hierarchy, silhouette, state, overflow, responsiveness and intentionality.
- Teardown diagnostics are recorded separately from assertion results.

## Test Layers

### Layer T0 — static and contract checks

Fast checks for:

- GDScript parse/import;
- tabs/style and forbidden generated files;
- public method/signal inventory;
- localization key parity/placeholders;
- snapshot serializability;
- no `load()` or allocation in a prohibited hot path;
- no fixed physical viewport assumptions in new layout files;
- no sprite activation without the author gate.

Static checks also validate that every new probe has a timeout, a nonzero
failure path, a completion marker and an isolated output location. A test must
not depend on the developer's current save, locale, audio device, window size
or editor state.

### Layer T1 — deterministic unit-ish probes

Small probes isolate:

- balance calculations, mode context and record policy;
- localization formatting/fallback;
- accessibility defaults and migration;
- layout density and safe-area math;
- entity extent/state descriptors;
- mutator and practice unlock rules.

These tests are cheap but cannot replace real scene dispatch.

Pure probes should also assert invariants rather than only example values:
state transitions are legal, rewards are emitted once, IDs remain stable,
snapshots are serializable and invalid input produces no mutation. Property or
table-driven cases are preferred when a rule has multiple modes, thresholds or
viewport densities.

### Layer T2 — real-path integration probes

Use `Viewport.push_input()`, real scenes and actual signals for:

- menu → selector → arena;
- pause → terminal → resume/restart/abandon;
- game-over → retry/menu;
- touch movement + aim + dash/overclock multitouch;
- patch offers and pause-tree input;
- story act unlock → stages → boss → reward;
- save export/import and locale/accessibility persistence.

Each probe prints named phases and a completion line such as
`PROBE_DONE fails=0`. A silent exit 0 is invalid.

Integration probes use explicit phase timeouts and identify the seed, route,
input mode and expected terminal state in their logs. A timeout is a failure,
not an implicit pass. When a probe is flaky, preserve the first failing log,
run a bounded repeat count to classify it and fix the lifecycle/race or mark
the test as blocked with a concrete owner; do not increase retries until the
failure disappears.

### Layer T3 — visual and responsive review

Capture clean and effect-enabled versions at 1366×768, 720×720, 432×720 and
390×844, plus one ultrawide desktop capture. Review:

- black/white hierarchy;
- text overflow and line wrapping;
- focus/locked/ready/danger distinction;
- arena safe space and touch obstruction;
- shell consistency without repeated decorative clutter;
- code-drawn silhouette and state;
- reduced motion/high contrast/large text variants.

Captures stay outside Git unless a carefully selected README asset is
intentionally approved.

Visual review records a deterministic capture recipe: commit, command,
viewport, locale, font/text scale, accessibility profile, effect tier and
route state. Compare semantic regions and readable outcomes, not compression
noise or accidental editor chrome. A visual pass without its recipe cannot be
reproduced and does not qualify as release evidence.

### Layer T4 — device and performance review

Run a fixed-seed stress scenario on a desktop export and a representative
Android build. Record frame pacing, device profile, quality tier, input feel,
orientation, thermals/battery observation when available and any visual
fallbacks. Do not infer mobile performance from a desktop or headless run.

Manual playtests have a short script and a result sheet: first launch, start a
run, understand the first threat, choose a patch, pause/resume, die, retry,
find accessibility and change language. Record observed confusion and
recovery time without collecting personal analytics. A manual result is not a
substitute for a deterministic regression probe; both are required when both
feel and correctness matter.

## Aggregate Validator Contract

Extend `tools/validate_input_dispatch.sh` as work lands. Every case must:

- use an isolated save directory;
- pass `--audio-driver Dummy`;
- write a named log;
- report exit code, passes and failures;
- fail on missing marker, `ERROR` gate or empty output;
- keep non-gating teardown diagnostics in a separate section;
- be reproducible from a clean checkout.

Each case declares its owner, prerequisite, timeout, output path, completion
marker and whether it is a correctness gate or an observation. The aggregate
summary preserves the individual exit codes and logs; it must not replace a
failed case with a total pass count. A test that cannot run because a required
export template/device is unavailable is reported as unavailable, not silently
treated as passed.

The validator's case list should eventually include:

```text
suite
input dispatch
projectile ownership
ROOTLET shield
TempleOS/GOD story path
story restart
OOM loot ownership
menu/layout
vNext primitives/entities
localization
accessibility
responsive UI
macOS story
gameplay/new enemies
save migration
performance smoke
```

## Evidence Work Packages

### Task T1 — validator hardening

Make the aggregate script reject empty execution, missing markers, assertion
failures, unexpected runtime errors, stale logs and nonzero child exits. Keep
case names stable so handoffs and release entries remain searchable. Validate
the validator itself once with a deliberately silent fake runner and once with
a deliberately failing marker.

### Task T2 — probe coverage and invariants

Add probes in dependency order: repository contracts, snapshots, localization,
accessibility, responsive geometry, real route/input flows, new gameplay and
save migration. Each probe must name the real path it exercises and include at
least one invalid/edge case, not only the happy path.

### Task T3 — visual/device recipes

Standardize capture commands and metadata for clean/effected, grayscale,
high-contrast, reduced-motion, PT-BR, wide/compact/narrow and exported-device
views. Keep capture outputs outside Git by default; a selected public image
requires explicit provenance and an intentional repository path.

### Task T4 — reporting and release ledger

Create the append-only release ledger, link each handoff and classify findings
by severity. A task is not closed when the code is green but the report is
missing its limitation, compatibility impact, reproduction recipe or next
safe checkpoint.

## Release Log Contract

Create `docs/RELEASE-LOG.md` or an equivalent versioned file with one entry per
coherent task. Use this exact structure:

```markdown
## [date] — [release or unreleased]

Branch: `codex/...`
Commits: `abc1234`, `def5678`
Area: gameplay | UI | accessibility | localization | performance | repository
Platforms: PC | mobile | both

### Bugs found
- Symptom and where it reproduced.
- Reproduction input/seed/viewport.

### Root cause
- The ownership, state, layout or lifecycle mistake.

### Fixes
- Files and behavior changed.

### Improvements and additions
- Player-visible benefit, new content or new option.

### Compatibility
- Save/input/localization/platform impact and migration.

### Evidence
- Targeted red log and green log.
- Full validator result and completion marker.
- Captures/device profile when visual or performance behavior changed.

### Known limitations
- What remains, why it is safe, and the next review gate.
```

Entries are append-only after a release is published. Corrections use a dated
amendment that points to the original entry; they do not erase an earlier
failure or replace a red log with a later green log. Unreleased work may be
edited until its checkpoint, but the handoff must preserve the final red/green
history. Classify findings as blocker, high, normal or observation so a
release candidate can make an explicit decision instead of hiding unfinished
work under “polish”.

The entry is written in player language first, with technical details beneath
it. A release note should say “pause input no longer eats Escape in desktop
debug” before citing a line number. If no bug was found, say that the task was
an addition/refactor and still record regression evidence.

## Historical Baseline to Preserve

The first entry after this plan should link the existing handoffs and preserve
the confirmed history:

- pause/input/debug dispatch fixes;
- projectile orphan removal;
- ROOTLET recharge and approved full-shield mote overflow;
- TempleOS GOD spawn correction;
- Story hold-R preservation;
- OOM UID ownership;
- terminal ESC/history/autocomplete behavior;
- menu overlay/footer/layout fixes;
- multitouch action dispatch;
- vNext code-drawn primitives/entity illustration;
- sprite gate and lifecycle-safe HUD signal.

Do not rewrite these as new changes. Use them as the baseline against which
future regressions are reported.

## Review Report Template per Task

Before commit, add to the task handoff:

1. scope and user-facing goal;
2. files created/modified/deleted;
3. bug reproduction or design rationale;
4. root cause and alternative fixes rejected;
5. implementation summary;
6. tests written and why they exercise the real path;
7. red result;
8. green result;
9. full-suite result;
10. visual/device/performance evidence;
11. save/input/locale/accessibility impact;
12. known limitations and open decisions;
13. commit hashes and pushed branch;
14. next safe task.

For visual, device and performance work, the report also includes the exact
capture/profile recipe and a statement of what was not tested. For a bug that
cannot be reproduced after the fix, preserve the original reproduction and
explain whether the result is a confirmed fix, a guarded hypothesis or an
environment-only observation.

## Acceptance Gates

- [ ] Every future commit has a linked handoff or release-log entry.
- [ ] Every bug fix has a reproducible symptom, root cause and regression test.
- [ ] Every addition states player benefit, platform impact and compatibility.
- [ ] Every visual change has wide/compact/narrow evidence or a documented reason it does not.
- [ ] Every performance claim has a profile, baseline and measurement method.
- [ ] The aggregate validator rejects silent/empty runs and missing markers.
- [ ] Teardown errors are never silently masked by a green assertion count.
- [ ] A release can be summarized from the log without reading every commit diff.

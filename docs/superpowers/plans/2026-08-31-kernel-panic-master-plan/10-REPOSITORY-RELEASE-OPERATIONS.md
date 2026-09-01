# KERNEL PANIC — Repository, Open Source and Release Operations Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` for changes to automation or release tooling. Repository quality is part of the product users receive.

**Goal:** Make the repository welcoming, reproducible and trustworthy for
players, contributors and future maintainers while preserving the project's
free/open-source identity and keeping releases easy to install.

**Architecture:** Keep source, runtime assets, tests, design references,
generated captures and release artifacts clearly separated. GitHub Actions
validates the same commands used locally; release metadata is generated from a
versioned release log; contribution docs explain the branch, test, localization
and art policies without requiring private context.

**Tech Stack:** Git/GitHub, Godot 4.7.2 headless/editor/import/export
commands, shell scripts, GitHub Actions, Markdown, MIT license and existing
Linux/Windows/Android export paths.

**Spec:** [master plan](00-MASTER-PLAN.md), [repository architecture](01-REPOSITORY-ARCHITECTURE.md), [testing/reporting plan](11-TESTING-REPORTING-RELEASE-LOG.md), and the current [README](../../../../README.md).

## Global Constraints

- Keep the repository free/open source under the existing MIT license.
- Do not add network requirements, telemetry collection, accounts, ads or
  proprietary runtime services.
- Do not commit `.godot/`, generated captures, temporary logs, exported
  binaries, secrets or orphaned `.import` files.
- Every PR/branch has a focused scope, a test log and a handoff.
- Release builds are reproducible from a clean checkout and identify commit,
  version, platform and export configuration.
- New third-party assets, fonts, audio or code require license attribution and
  a documented reason they belong in the project.

## Repository Hygiene Work Packages

### Task RPO1 — document the contributor path

Create or update:

- `CONTRIBUTING.md` — setup, Godot version, branch naming, coding style,
  silent test command, capture rules, commit format and review expectations;
- `CODE_OF_CONDUCT.md` — concise respectful participation rules;
- `SECURITY.md` — responsible reporting for code/security issues without
  promising server-side infrastructure the game does not have;
- `.github/PULL_REQUEST_TEMPLATE.md` — scope, tests, captures, save impact,
  localization, accessibility and performance checklist;
- `.github/ISSUE_TEMPLATE/bug_report.md`, `feature_request.md`,
  `accessibility.md` and `platform.md`.

### Task RPO2 — separate source/runtime/reference assets

Document that `media/Ideas/` is a visual moodboard and not runtime content.
Keep references out of exported builds unless intentionally copied into a
credits/reference screen. Document generated image policy: references may
inspire direction; code-drawn is the shipped default for UI/entities.

Add an asset attribution index if any external font/audio/art remains. Verify
licenses before release rather than assuming a file's presence grants rights.

### Task RPO3 — CI and validation

Add a GitHub Actions workflow that on a clean Linux checkout:

1. installs or locates Godot 4.7.2;
2. imports project resources;
3. runs `tools/validate_input_dispatch.sh` with dummy audio;
4. checks Markdown links and shell syntax;
5. rejects staged generated output and missing completion markers.

Keep platform exports as a separate job when export templates are available;
the core test job must not depend on a paid service.

### Task RPO4 — version and release assets

Define one version source and make README badges/release notes agree with it.
For each release, publish the supported artifacts currently documented:
Linux x86_64, Windows x86_64 and Android arm64. Add future macOS desktop
export only when it has a real tested export; the macOS history act does not
automatically mean macOS platform support.

Release package checklist:

- version and commit recorded;
- clean export starts at menu and reaches a run;
- save directory and transfer path verified;
- controls/settings/accessibility/localization checked;
- no debug console in release build;
- audio and mute behavior checked;
- README install instructions updated;
- release log and known limitations published;
- checksums attached where practical.

## Open Source Product Standards

- Prioritize small, understandable systems over framework sprawl.
- Explain “why” in architecture decisions and handoffs, not only “what” was
  changed.
- Welcome localization and accessibility contributions with examples.
- Keep issues reproducible with platform, version, input mode, seed and logs.
- Avoid collecting player data; provide local diagnostics the player can copy.
- Keep the default game complete and fun without online services or purchases.
- Credit contributors and external references in a maintained file.

## Branch and Commit Policy

Use:

```text
codex/<workstream>-<scope>
```

Commit prefixes:

```text
fix:      confirmed bug correction
feat:     new player-facing behavior/content
refactor: ownership or structure without intended behavior change
test:     probe/harness/validation coverage
docs:     plan, handoff, README or release documentation
perf:     measured performance improvement
chore:    repository/tooling maintenance
```

A branch may contain multiple small commits but must be pushed without force.
The handoff states the base commit, branch, dependency branches, commits,
tests, captures and whether local user files were intentionally left alone.

## Acceptance Gates

- [ ] A new contributor can find setup, test, branch and contribution instructions in under ten minutes.
- [ ] CI runs the same meaningful validation as the local workflow.
- [ ] Runtime content, design references, generated captures and release artifacts are not mixed.
- [ ] Release exports and README install instructions agree on platform, version and filenames.
- [ ] Licenses/attributions are checked before external assets are shipped.
- [ ] Issue/PR templates request enough evidence to reproduce bugs without private access.
- [ ] No open-source promise is contradicted by accounts, telemetry, network dependencies or undocumented generated assets.

# RPO — Repository and release operations

## Scope

This slice establishes repository hygiene, contribution expectations, security-reporting guidance, art-direction review criteria, and a release gate. It does not claim that remote CI, platform exports, mobile devices, save atomicity, or provenance are already verified.

## Changes

- Added contribution, conduct, and security guidance at repository root.
- Added pull-request and issue templates.
- Added a minimal GitHub Actions quality workflow for Godot import, DevHarness, and patch checks.
- Added the code-drawn art-direction contract, including a quality bar for silhouettes, telegraphs, accessibility, and performance.
- Added a release checklist covering repository hygiene, automated and manual validation, platform exports, saves, accessibility, performance, and maintainer decisions.

## Why

The project is moving from a hobby prototype toward a maintainable free/open-source game. The code and visual redesign need guardrails that survive contributors, branches, and future releases. The documents separate proven local checks from release claims that require a real device, human review, or hosted CI.

## Alternatives considered

- A large contributor manual was rejected for now because it would duplicate the master plan and become stale.
- A CI workflow that runs every focused visual probe was rejected as an initial baseline because several probes require Xvfb or project-local fixtures; the workflow starts with the canonical import and DevHarness gates.
- A release checklist that treated local headless success as release approval was rejected because it would hide platform, visual, touch, save, and teardown risks.

## Evidence and uncertainty

- The new files are locally reviewable and `git diff --check` is required before commit.
- The workflow syntax and action availability are not verified against a hosted GitHub runner in this environment.
- Export templates, Android tooling, real hardware, and remote CI remain to be validated before an official release.

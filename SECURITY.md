# Security policy

KERNEL PANIC is an offline, single-player Godot game. It does not currently provide an account system, network service, or server-side player data. Security reports are still welcome for issues that can affect a player's machine, files, privacy, or ability to run the game.

## Reportable issues

Please report, with reproduction steps when possible:

- arbitrary code execution, unsafe command invocation, or unexpected process launching;
- path traversal or writes outside the intended save/configuration locations;
- save corruption, data loss, unsafe deserialization, or malicious project content;
- release artifacts that contain personal data, credentials, private paths, or unintended executable content;
- a crash or denial-of-service caused by ordinary player-controlled input or bundled content.

## Reporting

Do not include passwords, private save files, or sensitive personal data in a public issue. Until a private security contact is published, open a minimal issue asking for a private reporting channel, or contact the maintainer through the repository's configured private channel. Include the affected version/commit, platform, exact steps, expected behavior, observed behavior, and any safe proof-of-concept needed to reproduce the issue.

Please allow time for triage before public disclosure. Reports that only concern balance, visual polish, or ordinary gameplay bugs should use the normal issue tracker instead.

## Release hygiene

Before publishing a build, maintainers must verify that archives do not contain `.godot` state, editor metadata, personal saves, local logs, credentials, or unrelated capture imports. The release checklist in `docs/RELEASE-CHECKLIST.md` is the source of truth for this review.

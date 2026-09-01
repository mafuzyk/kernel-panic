# A5 — save compatibility, rollback and deprecation checkpoint

Date: 2026-09-01
Worktree: /tmp/kernel-panic-plan-execution
Branch: codex/plan-execution

## Result

The checkpoint preserves Sfx.SAVE_PATH user://kernel_panic.cfg, transfer format kernel-panic-save version 1, all res:// paths, scene entry points, save keys, and gameplay/UI behavior. No new schema or standalone migrator was introduced.

The focused probe uses real Game and Sfx autoloads and the real ConfigFile path. It covers fresh profile, story/run progress, missing and legacy optional keys, export/import round-trip, malformed/truncated input, and byte-for-byte source preservation after every rejected import. It has a 10-second watchdog, non-zero failure exits, and SAVE_PROBE_DONE fails=N.

## TDD evidence

Red: the first behaviorally valid run exited 1 with SAVE_PROBE_DONE fails=2. It exposed a real error: malformed run/story strings raised typed-assignment errors in Game.import_save_string() instead of being rejected. The probe fixture also corrected its nonexistent act_1 ID to the real boot ID before evaluating the fix.

Green: XDG_DATA_HOME=<isolated-dir> godot --audio-driver Dummy --headless --path . res://tools/save_compatibility_probe.tscn exited 0 with SAVE_PROBE_DONE fails=0.

The production fix validates run, weekly, and story payload types before typed use or ConfigFile writes. Existing normalization is unchanged.

## Contracts, deprecation and rollback gates

Game remains authoritative for progress/records and Sfx for settings. Accepted transfer inputs retain the current format/version; unknown IDs are filtered by existing known-ID maps; invalid input returns false without changing source bytes.

The public export/import helpers remain runtime-reachable as the compatibility boundary. Do not remove or rename them until a replacement has repository-wide zero-consumer evidence, real Menu/Arena scene-load coverage, save round-trip and invalid-import byte-preservation, input probe, full autotest, and rollback-route proof. The transfer version must not be incremented merely to organize code.

## Why no new schema/migrator

Current version 1 already supplies defaults, legacy run.best reading, known-ID filtering, non-negative numeric normalization, and sparse-map canonicalization. A new schema would add a second authority and an unnecessary migration/rollback surface. Keeping version 1 and hardening rejection is the smaller reversible change.

## Risks and files

Accepted imports may canonicalize sparse dictionaries on re-export; rejected imports are byte-preserving. Baseline teardown diagnostics remain open and are not attributed to A5. The probe directly calls the existing load helper only to isolate fixtures.

Changed: src/autoload/game.gd; added tools/save_compatibility_probe.gd and tools/save_compatibility_probe.tscn; updated the ignored master-plan ledger.

Full suite: XDG_DATA_HOME=/tmp/kernel-panic-a5-full-xdg-2 godot --audio-driver Dummy --headless --path . -- --autotest exited 0 with AT_PASS=1414, AT_FAIL=0, and AUTOTEST_ALL_PASS. Existing teardown diagnostics matched baseline and remain open.

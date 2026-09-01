# M1 — macOS history act catalog and unlock contract

## Status

Implemented and reviewed on `codex/plan-execution`. This slice establishes a
separate, data-owned macOS history act and makes it selectable through the
existing story surfaces when its prerequisite is cleared. It intentionally
does not claim that the act is release-ready: the mechanic, final encounter,
reward persistence, PT-BR copy and physical-device review remain M2–M5 work.

## Requirement and interpretation

The plan interprets “MAC-OS history” as a playable historical story act, not a
second terminal command-history implementation. The existing terminal already
has its own history behavior. The new route is therefore appended after the
TempleOS stages and uses the established `Game.start_story()` and
`story_cleared` progression boundary.

## Before and after

Before, the story catalog contained 11 fixed stages: six UNIX stages, three
Windows stages and two TempleOS stages. The legacy and vNext selectors knew
only those three act tabs, and the arena had no macOS era presentation path.

After, the catalog exposes 15 stages in the same linear compatibility view.
The four appended stages have stable IDs and a separate `macos` act field:
`mac_classic`, `mac_aqua`, `mac_darwin` and `mac_modern`. The new act remains
locked until `temple_god` is cleared. Both legacy and vNext story selectors
show the act; compact vNext uses `MAC` as the tab label to preserve a usable
touch target. The arena mounts a profile-driven, code-drawn era overlay when a
macOS stage is actually loaded.

## Data and presentation

- `src/story/acts/macos_act.gd` owns stage order, stable IDs, wave references,
  profile IDs, reward IDs, boss metadata and narrative keys.
- `src/story/acts/macos_dialogue.gd` owns player-facing English copy as a
  replaceable table. It does not draw or mutate progression.
- `src/story/acts/macos_profiles.gd` owns four fiction-facing visual profiles:
  classic, aqua, darwin and modern. They describe palette/grid/CRT rhythm and
  do not inspect the host operating system.
- `src/story/story_data.gd` remains a compatibility facade and aggregates the
  appended stages without duplicating them into `Game` or the selectors.
- `src/arena/macos_era_overlay.gd` is a small code-drawn abstraction using
  panes, lines and circles. It contains no Apple logo, screenshot, proprietary
  font or generated bitmap.
- `src/arena/stage_kit.gd` and `src/arena/arena.gd` mount the overlay through a
  stage-profile boundary. Gameplay spawning and rendering ownership remain
  separate.

## Progression and compatibility

`Game.story_stage_unlocked(index)` remains the single linear stage rule. The
act-level query `Game.story_act_unlocked("macos")` is additive and checks the
existing `story_cleared["temple_god"]` key. Existing UNIX/Windows/TempleOS
act queries remain unlocked as before. No new save file, transfer version,
reward schema or host-platform detection was introduced.

The `reward_id` values are stable content identifiers for the later M4 reward
implementation. This slice does not pretend that merely declaring a reward ID
grants a reward; `Game.complete_story_stage()` remains the actual completion
boundary and M4 must connect the final reward semantics and transfer tests.

## UI correction found during review

Adding a fourth act exposed two stale assumptions. The vNext narrow tab labels
were too wide for `TEMPLEOS`, and the menu annotation still hardcoded
`UNIX ACT 1` even when the selected stage belonged to another act. The compact
tab labels now use `UNIX`, `WIN`, `TEMPLE` and `MAC`, and the menu derives its
annotation from the selected stage's act. The overflow preview uses the
longest macOS-stage copy (`Mac::MODERN`, 15 total stages) rather than the old
11-stage example.

## Verification

- Red M1 probe: `/tmp/macos-m1-red.log`, exit 1 with the expected missing
  aggregation/live-unlock contracts.
- Green M1 probe: `/tmp/macos-m1-green3.log`, exit 0, all assertions passed,
  `PROBE_DONE fails=0`. It checks the four IDs, resolved narrative, klog,
  profiles, stage waves, final boss/reward metadata, lock/unlock transition,
  live 15-stage aggregation and first macOS-stage unlock.
- Selection regression: `/tmp/macos-selection3.log`, exit 0,
  `PROBE_DONE fails=0`, including mouse/touch selection of the macOS tab and
  narrow text-fit checks.
- Editor import/parse: `/tmp/macos-m1-import2.log`, exit 0. It reports only
  the known environment warning about the unavailable Android build-tools
  directory.
- Full DevHarness: `/tmp/macos-m1-suite.log`, exit 0, 1453 `AT_PASS`, zero
  `AT_FAIL` and `AUTOTEST_ALL_PASS`.

## Second-pass self-review

The implementation was checked for duplicated story authority, an accidental
host-OS branch, broken old stage indices, a Mac tab that could not be focused
or touched, compact text overflow, progression bypass, and reward claims that
were not actually wired. The route still uses the old story facade and linear
unlock path, all old stage indices remain stable, and the Mac reward is
explicitly documented as future M4 work.

Remaining uncertainty is product-facing: the English copy, four profile
palettes, stage wave composition and the static overlay have not received a
human visual/feel approval. M2 must review the copy in all densities before
the remaining stages are treated as authored content; M3/M4 must prove actual
playability and reward persistence.

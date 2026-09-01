# M4 — macOS climax, boss identity and transactional rewards

## Status

Implemented and reviewed on 2026-09-01 in the isolated execution worktree.
The macOS route now has a named climax boss, a directional permission check
telegraph, a stable reward identifier, save-transfer support and a failure
path that refuses to grant story progress when its checkpoint cannot be
written.

This remains a development milestone. It is not a release-readiness or human
balance approval.

## Requirement and interpretation

M4 had four connected requirements: make the final Mac node more than a
generic RootBoss reuse; keep the shared boss/desperation/HUD contract; persist
the reward by a stable ID; and prove that an interrupted or failed save does
not grant only part of the completion.

The implementation keeps the existing RootBoss as the behavior base. A new
`PermissionRootBoss` owns only its additional climax behavior and identity.
This preserves the existing hit, phase, split, HUD and desperation machinery
instead of creating a second boss lifecycle.

## Before and after

Before M4, `mac_modern` declared `boss: "PERMISSION ROOT"`, but the story
spawner treated every ordinary `boss` token as `RootBoss.new()`. The generic
boss then configured its title from `boss_index`, so the final Mac node could
present a PAGE FAULT variant despite its content saying PERMISSION ROOT. Story
completion marked only `story_cleared` and `story_best`; the stage's existing
`reward_id` was not read, saved or included in the portable transfer payload.
The save write was unchecked, so a failed write could leave the in-memory
completion looking successful and the arena without a usable recovery state.

After M4, the final node declares `boss_variant: "permission_root"`. The
generic story boss boundary selects `PermissionRootBoss`, which retains the
shared RootBoss integrity/phase/desperation signals and adds a short
directional `PERMISSION CHECK` wind-up followed by a three-shot `PERMISSION
DENIED` burst. Its countdown is geometric and directional; color is an accent,
not the only warning channel. Its snapshot exposes `boss_variant_id` and the
telegraph data for future vNext consumers.

`Game` now derives the allowed reward IDs from story definitions, loads and
normalizes them, exposes `story_reward_unlocked()`, writes them with the
stage-clear checkpoint and includes them in export/import. The completion path
validates the stage before ending the run, builds updated maps separately,
persists the complete story checkpoint, and mutates the in-memory maps only
after a successful write. When the write fails, existing progress and rewards
remain unchanged and the Arena presents a retryable `STORY SAVE FAILED` state
instead of a false victory.

## Files and ownership

- `src/enemies/permission_root_boss.gd`: code-drawn Mac climax variant;
  shared RootBoss lifecycle remains authoritative.
- `src/story/acts/macos_act.gd`: declares the stable `permission_root`
  variant on `mac_modern`.
- `src/arena/spawner.gd`: selects the variant only at the generic story boss
  spawn boundary; existing classic and GOD branches remain unchanged.
- `src/autoload/game.gd`: reward registry derivation, load/save,
  run-snapshot/export/import and guarded story-completion persistence.
- `src/arena/arena.gd`: dynamic Mac victory copy and save-failure recovery
  surface.
- `src/ui/vnext/core/entity_presentation_adapter.gd`: preserves boss variant
  and permission telegraph fields for future code-drawn UI consumers.
- `tools/macos_climax_probe.gd/.tscn`: real story-spawner, boss-contract,
  save-transfer and forced-save-failure probe.

## Technical decisions

### Reuse RootBoss instead of making a separate boss controller

Alternatives considered were a new standalone boss base, a special case in
`RootBoss` keyed by Mac stage ID, or a small subclass. The subclass was chosen
because it preserves the already-tested shared contracts while keeping the
new behavior data/rule-specific. A stage ID special case inside RootBoss
would couple generic boss code to one story catalog; a standalone controller
would duplicate hit/death/desperation/HUD behavior and increase regression
risk.

Trade-off: the subclass still depends on RootBoss's protected-by-convention
state and helper methods (`_spawn_orb`, `_do_burst`, `_desperation_interval`).
That is acceptable for this incremental codebase, but a future boss API could
make those shared attack primitives explicit if additional variants arrive.

### Use stable reward IDs instead of deriving rewards only from cleared stages

The catalog already had additive `reward_id` metadata. Persisting it explicitly
means future rewards can be changed or granted independently from stage IDs,
and it gives UI/content a stable lookup contract. Only reward IDs declared by
the current story catalog are accepted during load/import, so arbitrary keys
from a transfer string are discarded.

Trade-off: save payloads now contain one more optional story field. The
transfer format remains version 1 because the field is backward-compatible and
older payloads simply import with no rewards. If reward semantics become
non-boolean or require grant metadata, a new transfer version will be needed.

### Commit the story checkpoint after building all updates

The completion path does not mutate `story_cleared`, `story_best` or
`story_rewards` before `ConfigFile.save()` succeeds. The existing run-ending
record write still happens before the story checkpoint because `end_run()` is
the established lifecycle boundary; therefore a failed story checkpoint may
still end the run and emit its normal transient run signal, but it cannot
grant the story clear or its reward. Arena recovery is explicit and retryable.

This is not a crash-proof filesystem transaction: Godot's `ConfigFile.save()`
does not provide a journal/rename protocol here. A process crash during the
file write remains a residual risk for the whole existing save architecture.
RPO save journaling/backup work is still required before a strong release
claim.

## Evidence

### Focused red

`/tmp/m4-probe-red2.log` exited non-zero. It reproduced the missing boss
script/variant, missing reward state and missing reward metadata contract
before the implementation. The first probe draft also contained an invalid
inferred local type and was corrected before the green run; this was a test
harness defect, not hidden as a production pass.

### Focused green

`/tmp/m4-probe-green8.log` exited 0 with `PROBE_DONE fails=0`. It verified:

- the named boss script and catalog metadata load;
- the direct variant owns `PERMISSION ROOT` identity and telegraph snapshot;
- the variant reaches the shared desperation transition;
- the real story `Spawner` creates the exact variant;
- the Mac stage clear marks `mac_modern` and grants `macos_modern_clear`;
- the reward survives export/import;
- a forced save failure returns false and preserves prior cleared stages,
  best scores and rewards.

The probe initially made an incorrect `is RootBoss`/closure assertion and was
corrected to inspect the real script resource path. The production result was
unchanged; the correction is recorded because evidence quality matters.

### Integration

- Editor import: `/tmp/m4-import-green2.log`, exit 0.
- Full DevHarness: `/tmp/m4-suite.log`, exit 0, 1453 `AT_PASS`, 0 `AT_FAIL`,
  `AUTOTEST_ALL_PASS`.
- `git diff --check`: exit 0.

The full suite still reports the known non-gating shutdown diagnostics:
resource/ObjectDB/RID leaks from the baseline. No new gated functional error
was observed in the M4 run.

## Second-pass self-review

The implementation was checked again for invalid stage completion, duplicate
reward grants, stale in-memory maps after a failed write, old transfer
payloads, unknown reward injection, non-Mac boss selection, boss HUD typing,
desperation behavior, telegraph timing, no-player operation and arena retry
dead ends.

Confirmed safe by code/probe: non-Mac boss paths remain unchanged; rewards are
catalog-whitelisted; duplicate completion is blocked by `Game.state`; old
payloads import with an empty reward map; a failed story save does not mutate
the story maps; and the final boss is still a RootBoss-derived object using
the shared boss signal path.

Remaining uncertainty: no human visual playtest has approved the permission
line, no dense-wave frame profile has measured the new draw/effect cost, the
failure path is not yet covered by a physical crash/power-loss test, and the
vNext game-over surface does not yet have a dedicated `save_failed` variant.
These are release-gate items, not silently treated as complete.

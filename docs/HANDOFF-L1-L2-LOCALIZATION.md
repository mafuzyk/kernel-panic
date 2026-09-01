# Handoff — L1/L2 localization foundation and macOS narrative slice

## Branch and status

- Branch: `codex/plan-execution`
- Worktree: `/tmp/kernel-panic-plan-execution`
- No merge into `main`.
- Generated Godot `.uid` and capture import artifacts remain untracked.

## Delivered

- Added the `Localization` autoload and UTF-8 English/PT-BR JSON catalogs.
- Added schema/key-set/placeholder validation plus readable English fallback.
- Added named formatting, plural/select helpers and locale snapshots.
- Persisted the selected locale through Sfx's existing ConfigFile boundary.
- Added a legacy Settings language selector and route refresh hook.
- Migrated all four macOS stage titles, intros and klogs to the service, with
  English fallback and Brazilian Portuguese copy.

## Evidence

```text
/tmp/l1-red2.log
  exit 1, expected missing Localization service contract

/tmp/l1-import2.log
  editor import exit 0, no script errors

/tmp/l1-green4.log
  exit 0, PROBE_DONE fails=0

/tmp/macos-selection3.log
  exit 0, PROBE_DONE fails=0 under English default; Mac tab and narrow layout
  remain green
```

The focused probe is run with an isolated `XDG_DATA_HOME`; no user save was
used as test state. The full game still has known teardown diagnostics tracked
by the reliability plan.

## Not claimed

- The entire existing game is not yet localized.
- PT-BR is not yet approved editorially on every screen or at every text
  scale.
- Native screen readers, platform font scaling and controller accessibility
  remain feasibility work.

## Next task

L2/L3 migration: inventory and move visible menu/settings/program/story,
bestiary, patch, HUD, pause, terminal, game-over, enemy and achievement copy
to stable keys. Keep IDs and gameplay data separate, and add overflow checks in
English and PT-BR before considering the language release-ready.

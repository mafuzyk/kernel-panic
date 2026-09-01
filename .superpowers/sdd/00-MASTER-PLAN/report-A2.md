# A2 review report — owner-owned kits

Date: 2026-09-01  
Worktree: `/tmp/kernel-panic-plan-execution`  
Branch: `codex/plan-execution`

## Scope and uncertainty

Reviewed the A2 section of `docs/superpowers/plans/2026-08-31-kernel-panic-master-plan/01-REPOSITORY-ARCHITECTURE.md`, the mechanical source-of-truth plan `docs/superpowers/plans/2026-08-30-structure-refactor.md`, `KERNEL-PANIC-HANDOFF.md`, `docs/HANDOFF-R10-T02-T04-RUNTIME-INTEGRATION.md`, and `.superpowers/sdd/00-MASTER-PLAN/progress.md`.

The plan has no separately named `A2` micro-plan file; the applicable
specification is the A2 section in the master architecture plan plus the
mechanical structure-refactor plan. The controller generated
`task-A2-brief.md` in the ignored SDD workspace before delegation, but the
delegated inspection did not observe that generated file. This is a process
visibility discrepancy, not a repository/runtime finding; the available
versioned plans were used as the source of truth.

## Evidence

- Arena preloads and initializes `panel_kit`, `intro_kit`, and `stage_kit` with `self`.
- Menu preloads and initializes `menu_settings_kit` and `menu_chrome_kit` with `self`.
- Named compatibility delegates remain on owners: `Arena.handle_pause_input`, `Arena.show_event_banner`, `Arena.story_intro_active`, `Arena.dismiss_story_intro`, `Arena.windows_stage_profile`, `Arena.temple_stage_profile`, `Arena.background_corruption_for_wave`, `Menu.settings_layout_for_viewport`, and `Menu.footer_button_layout_for_viewport`.
- Dynamic story dispatch remains deferred through `_intro_kit._show_story_intro.call_deferred()`.
- R10's required `Arena.show_event_banner(txt)` delegate is present and forwards to `_intro_kit.show_event_banner(txt)`.
- Source-scan landmines remain in the required files: all five HUD strings/expressions are present in `src/ui/hud.gd`, and `_open_achievements` remains in `src/ui/menu.gd`.
- Kit call-token audit was inspected. Owner state and cross-kit calls use `a.`/`m.` prefixes; remaining bare calls are kit-local or Godot/global APIs. No unverified owner call was found.

## Runtime verification

Command:

```text
XDG_DATA_HOME=/tmp/kernel-panic-a2-xdg godot --headless --audio-driver Dummy --path . -- --autotest
```

Result: exit `0`; `1414` `AT_PASS`; `0` `AT_FAIL`; `AUTOTEST_ALL_PASS` present. Full log: `/tmp/kernel-panic-a2-20260901.log`.

The log contains the same teardown diagnostics recorded by W0: 8 resources, 3 GodotArea2D RIDs, 14 dummy textures, 147 shaped-text allocations, and 2 advanced-font allocations. These are residual risks, not evidence of an A2 kit defect. No functional `SCRIPT ERROR` was observed.

## Finding and decision

No reproducible A2 kit/delegate/landmine bug was found. Per task instruction, no focused reproduction or production-code correction was needed. This is a documentation-only review.

## Files changed by this review

- `.superpowers/sdd/00-MASTER-PLAN/report-A2.md`
- `.superpowers/sdd/00-MASTER-PLAN/progress.md`

Generated `.godot`/`.uid`/capture-import artifacts already present in the worktree were not staged.

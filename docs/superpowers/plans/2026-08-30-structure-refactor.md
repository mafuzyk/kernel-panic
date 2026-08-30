# KERNEL PANIC Structure Refactor — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-subagent-driven-development (recommended) or superpowers-executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Shrink the three oversized GDScript files (`dev_harness.gd` 3867 lines, `arena.gd` 1672, `menu.gd` 1615) into preloaded helper/section modules with **zero behavior changes**, keeping the 1194-check autotest fully green after every task.

**Architecture:** Godot 4.7.2 preloaded-helper pattern: each extraction creates a `RefCounted` kit/section script (`const XScript = preload("res://...")`) that receives its owner (Arena/Menu/DevHarness) in `_init` as an untyped reference. All state (every `var`/`@onready`) stays on the owning class; kits hold only functions, so `arena.get("_some_state")`-style harness probes keep working. Public method names on Arena/Menu are preserved as one-line delegate wrappers. `class_name` files stay at their current paths; no scene/autoload/`project.godot` changes.

**Tech Stack:** Godot 4.7.2, GDScript, headless autotest (`godot --headless --path . -- --autotest`), `.uid` sidecars generated via `godot --headless --path . --import`.

**Spec note:** This plan **is** the spec. This is a mechanical, author-approved structural refactor with no feature decisions left open; there is no separate design document. The design rationale is this header plus the Measured Baseline, Hard Constraints, and Global Mechanics sections below; the tasks are the specification.

---

## Measured baseline (2026-08-29, branch `main`, commit `7f0c4b9`)

```
3867 src/autoload/dev_harness.gd
1672 src/arena/arena.gd
1615 src/ui/menu.gd
 832 src/autoload/game.gd
 763 src/enemies/root_boss.gd
 642 src/ui/hud.gd
 581 src/player/player.gd
 466 src/arena/spawner.gd
 400 src/ui/bestiary_panel.gd
 363 src/ui/story_panel.gd
16521 total
```

- Autotest baseline: **1194 `AT_PASS` / 0 `AT_FAIL`, final line `AUTOTEST_ALL_PASS`** (printed by `_finish()` at `dev_harness.gd:3565-3572`).
- `grep -c 'print("AT_STEP' src/autoload/dev_harness.gd` → **68** (constant across all tasks; moved labels are never renamed or reworded).
- Harness function count: 65; arena 102; menu 57; game 66; hud 51.
- 58 `.uid` sidecars are committed; every new `.gd` must get its sidecar committed too.

## Hard constraints (the contract)

1. **Pure moves/extracts only.** No behavior changes, no renames of public APIs/signals/group names, no save-format changes, no visual changes, no balance edits. Moved function bodies are byte-identical except for the mechanical rewrite tables in Global Mechanics.
2. **The autotest suite IS the test.** After every task run the full suite and require `AUTOTEST_ALL_PASS`, `1194` AT_PASS, `0` AT_FAIL. Commit per task in repo style: `refactor: ...`.
3. **Keep entry points identical:** `--autotest` CLI behavior, every `AT_STEP` label, every AT message string, `KP_DEMO`/`KP_STRESS`/`KP_SHOT` env hooks, and the `AUTOTEST_ALL_PASS`/`AUTOTEST_FAILED` terminators stay byte-for-byte.
4. **Paths that must not move:** `src/autoload/dev_harness.gd` (autoload), `src/arena/arena.gd`, `src/ui/menu.gd` (referenced by `.tscn` scenes, `project.godot`, and by name via `load("res://...")` inside tests).
5. **Source-scan landmines — the harness greps `.gd` sources of some production files.** These checks break if the scanned string leaves the scanned file:
   - `dev_harness.gd:2708` — `hud.gd` source must contain `panel_fill_color(combat)`
   - `dev_harness.gd:3317-3321` — `hud.gd` source must contain `if not touch_layout():`, `label += "  READY"`, `"[SHIFT]" if not touch_layout()`, `_banner.text = "" if hide_main else text`, `_banner_sub_l.offset_top = 186`
   - `dev_harness.gd:2876-2908, 2956-2958` — bestiary/program/tactical_icon/patch_card sources (none of these files are touched by this plan)
   - `dev_harness.gd:3841-3844` — `menu.gd` source must contain `_open_achievements` (stays: it is a real method on Menu)
   - **Consequence: `src/ui/hud.gd` is frozen — no task extracts from it.** All five hud checks reference `_draw`-path code that must remain textually in `hud.gd`.
6. **Harness reads private state dynamically.** `arena.get("_abandon_armed")`, `arena.get("_terminal_panel")`, `arena.get("_story_stage")`, `arena.get("_story_intro_panel")`, `menu.get("_capture_action")`, `menu.get("_mode_info")`, `menu.get("_aim_btn_ref")`, `menu.get("_keybind_status")`, `menu.get("_story_btn")` must keep resolving against Arena/Menu. **Therefore every `var`/`@onready`/`const` stays on its owner; kits access them through the owner reference.**
7. **Dynamic dispatch landmines:** `src/arena/pause_input_router.gd:11` calls `arena.handle_pause_input(event)` via `has_method` → Arena keeps a `handle_pause_input` method. `arena.gd` `_ready()` uses `call_deferred("_show_story_intro")` (string dispatch) → Task 11 rewrites this exact call to `_intro_kit._show_story_intro.call_deferred()` (same deferred timing, same method, no behavior change).
8. **No cyclic preloads.** Kit/section scripts reference their owner only via an untyped `var` set in `_init`; the owner preloads the kit. One-way edges only.
9. **`game.gd` (832) and `hud.gd` (642) are intentionally not split** (measured decision): both sit below the pain threshold relative to risk — game.gd is a signal-heavy autoload state machine, hud.gd is frozen by constraint 5. Recorded here so no executor "helpfully" adds a task.
10. **Task sizing:** target ≤ ~400 moved lines per task; two tasks deliberately exceed it (T2: 385 is fine; T13: ~575 lines noted inline) because the moved block is one contiguous, cohesive family and splitting a contiguous verbatim block across tasks would create artificial intermediate states. Every task is independently shippable and green.
11. Never stage `.godot/`, build outputs, or unrelated files. Never "clean up" code while moving it — no reformatting, no reordering, no comment edits inside moved bodies.

## Global mechanics (referenced by every task)

### G1. Full-suite verification recipe (run after every task)

```bash
godot --headless --path . -- --autotest > /tmp/opencode/at_<TASK>.log 2>&1; echo "exit=$?"
grep -c 'AT_PASS ' /tmp/opencode/at_<TASK>.log
grep -c 'AT_FAIL' /tmp/opencode/at_<TASK>.log
grep -c 'AUTOTEST_ALL_PASS' /tmp/opencode/at_<TASK>.log
```

Expected every time: `exit=0`, `1194`, `0`, `1`. Any other result = the task failed; fix or revert before continuing.

### G2. Label-preservation check (harness tasks only)

```bash
cat src/autoload/dev_harness.gd src/autoload/harness/*.gd | grep -c 'print("AT_STEP'
```

Expected: `68` after every harness task (T1–T9).

### G3. RW-H — harness section rewrite (applied once, at move time, to extracted text)

Moved harness bodies call DevHarness helpers. Apply this exact `perl` to the extracted block when writing it into the section file:

```bash
perl -pe 's/\b(_check|_pass|_fail|_ticks|_until|_simulation_seconds|_config_snapshot|_config_snapshot_matches|_config_section_snapshot|_restore_config_section|_config_sections_equal|_restore_config_snapshot|_key_event|_has_physical_key|_color_distance|_populate|_spawn_boss|_autopilot)(?=\()/h.$1/g; s/(?<![.\w])get_tree\(/h.get_tree(/g; s/(?<![.\w])get_viewport\(/h.get_viewport(/g; s/(?<![.\w])get_process_delta_time\(/h.get_process_delta_time(/g'
```

These stay on `dev_harness.gd` and are therefore `h.`-prefixed from sections: `_pass _fail _check _watchdog _ticks _simulation_seconds _until _key_event _has_physical_key _color_distance _config_snapshot _config_snapshot_matches _config_section_snapshot _restore_config_section _config_sections_equal _restore_config_snapshot _populate _spawn_boss _autopilot _finish`. Autoload singletons (`Game`, `Sfx`, `Fx`, `Balance`) and global `class_name`s (`Arena`, `Player`, `GlyphLib`, `BestiaryPanel`, …) stay bare.

### G4. Harness section file skeleton (lines 1–12, exact, every section file)

```gdscript
extends RefCounted

## Autotest section script. Function bodies below are moved verbatim from
## src/autoload/dev_harness.gd; only harness-helper references are prefixed
## with `h` per plan section G3. No behavior changes. AT_STEP labels and
## message strings are byte-identical to the originals.

var h: Node


func _init(harness: Node) -> void:
	h = harness

```

(Line 12 is a trailing blank line; the first moved `func` starts on line 13. Use tabs for indentation, matching the repo.)

### G5. Owner-state rewrites (arena/menu kit tasks)

Kits receive their owner in `_init` and prefix owner-owned identifiers with `a.` (arena) or `m.` (menu). The member lists below are the complete class-level declaration lists of the current files (grep-verified 2026-08-29: 91 `var`/`const` declarations in arena.gd, 42 in menu.gd). Method calls on the owner that are not covered by these tables are rewritten during each task's **call-token audit** (rule: every bare call token in the kit file must be either (a) a function defined in the kit file, (b) a GDScript built-in/global/constructor (`print`, `str`, `load`, `preload`, `Vector2`, `Color`, `Label`, `Button`, `Panel`, `StyleBoxFlat`, `clampf`, `maxf`, `minf`, `floorf`, `is_instance_valid`, `Engine`, `OS`, `DisplayServer`, `Input`, `.new`, …), or (c) prefixed `a.`/`m.`). The audit command per kit file:

```bash
grep -hoE '\b[a-zA-Z_][a-zA-Z0-9_]*\(' <kit file> | sort -u
```

Review every token against rule (a)/(b)/(c); fix violations by adding the `a.`/`m.` prefix. The full autotest (1194 checks; panels/menus/settings are exercised heavily) is the final net.

**RW-ARENA** — apply to every block moved out of `arena.gd` (longer names first; the five preload consts stay bare):

```bash
perl -pe 's/(?<![.\w"])(_story_intro_panel|_story_intro_path|_story_intro_title|_story_intro_text|_story_intro_state|_story_intro_t|_story_intro_hint|_story_spawn_started|_story_victory|_story_next_stage|_story_stage|_boss_fragments_pending|_boss_phase_clear_done|_boss_rewards_claimed|_boss_dmg_snapshot|_pause_volume_rows|_pause_buttons|_over_core_stats|_over_run_stats|ABANDON_CONFIRM_WINDOW|PAUSE_INFO_DEFAULT|PAUSE_INFO_CONFIRM|PANEL_REFERENCE_HEIGHT|PANEL_CONTENT_HEIGHT|PANEL_SAFE_MARGIN|STORY_INTRO_FADE_IN|STORY_INTRO_FADE_OUT|STORY_INTRO_MIN_HOLD|STORY_INTRO_AUTO_DISMISS|STORY_INTRO_MAX_HEIGHT|STORY_INTRO_FONT_FLOOR|_windows_watermark|_patch_offers|_abandon_armed|_abandon_timer|_abandon_generation|_restart_hold_t|_restart_triggered|RESTART_HOLD_DURATION|PATCH_MAX_WIDTH|PATCH_BOX_HEIGHT|enemy_container|mote_container|quality_tier|_pause_panel|_pause_stats|_pause_info|_pause_title|_over_panel|_over_stats|_over_title|_over_sub|_over_primary|_over_menu|_crt_overlay|_temple_mode|_intro_bars|_intro_label|_intro_quote|_patch_panel|_patch_box|_patch_open|_patch_pending|_debug_panel|_terminal_panel|_fps_accum|_fps_time|_tip_label|_tip_index|_abandon_t|_bg_mat|_era_color|_dust|player|cam|spawner|hud|overlay|walls|mote_field|enemy_list|_state|touch|reticle|wave_signal_count|TIPS)(?![\w])/a.$1/g'
```

**RW-MENU-1** — apply to blocks moved out of `menu.gd` in Task 13 only (members from menu.gd lines 7–47, then non-moved menu methods/settings-kit-external chrome calls):

```bash
perl -pe 's/(?<![.\w"])(_settings_keybind_grid|_settings_nav_buttons|_settings_footer_row|_settings_navigation_chrome|_settings_workstation_chrome|_save_transfer_status|_save_transfer_field|_color_assist_btn|_settings_title|_settings_scroll|_keybind_buttons|_keybind_status|_settings_frame|_settings_box|_settings_panel|_capture_action|_keybind_box|_bestiary_panel|_program_panel|_aim_btn_ref|_glitch_t|_starting|_drifters|_best_label|_purge_btn|_program_btn|_story_panel|_story_btn|_ach_panel|_mode_info|_diff_btn|_mode_btn|_klog_t|_esc_armed|_prompt|_title_r|_title_b|_boot|_klog|_title|_t)(?![\w])|(?<![.\w])(_refresh_mode_ui|_cycle_mode|_cycle_difficulty|_refresh_difficulty_label|_refresh_program_label|_open_program_selector|_close_program_selector|_open_story_selector|_close_story_selector|_open_bestiary|_close_bestiary|_open_achievements|_close_achievements|_export_save_to_clipboard|_import_save_from_clipboard|_reset_scores|_update_best|_refresh_aim_label|_desktop_keybinds_enabled|keybind_capture_visible|_style_card_button|_add_button_chrome|_add_button_icon|_add_menu_frame|_settings_nav_style|_set_button_text_inset|_style_settings_footer_button|_style_overlay_back|_mk_title)(?=\()/m.$1/g'
```

**RW-MENU-2** — apply to blocks moved out of `menu.gd` in Task 14 only: same member group as RW-MENU-1, but the method group drops the chrome names that become kit-local in Task 14 (`_style_card_button _add_button_chrome _add_button_icon _add_menu_frame _settings_nav_style _set_button_text_inset _style_settings_footer_button _style_overlay_back _mk_title`) and gains the cross-kit chain rules:

```bash
perl -pe 's/(?<![.\w"])(_settings_keybind_grid|_settings_nav_buttons|_settings_footer_row|_settings_navigation_chrome|_settings_workstation_chrome|_save_transfer_status|_save_transfer_field|_color_assist_btn|_settings_title|_settings_scroll|_keybind_buttons|_keybind_status|_settings_frame|_settings_box|_settings_panel|_capture_action|_keybind_box|_bestiary_panel|_program_panel|_aim_btn_ref|_glitch_t|_starting|_drifters|_best_label|_purge_btn|_program_btn|_story_panel|_story_btn|_ach_panel|_mode_info|_diff_btn|_mode_btn|_klog_t|_esc_armed|_prompt|_title_r|_title_b|_boot|_klog|_title|_t)(?![\w])|(?<![.\w])(_refresh_mode_ui|_cycle_mode|_cycle_difficulty|_refresh_difficulty_label|_refresh_program_label|_open_program_selector|_close_program_selector|_open_story_selector|_close_story_selector|_open_bestiary|_close_bestiary|_open_achievements|_close_achievements|_export_save_to_clipboard|_import_save_from_clipboard|_reset_scores|_update_best|_refresh_aim_label|_desktop_keybinds_enabled|keybind_capture_visible)(?=\()/m.$1/g; s/(?<![.\w])_settings_kit\./m._settings_kit./g; s/(?<![.\w])(add_child|draw_polyline|draw_line|draw_arc|draw_circle|draw_set_transform|draw_string|draw_rect|draw_colored_polygon|queue_redraw|get_theme_font)\(/m.$1(/g; s/(?<![.\w"])size(?![\w])/m.size/g'
```

(The `size` rewrite is audit-checked: if a moved body declares a local named `size`, revert that single rewrite to the local.)

### G6. .uid sidecar generation (every task that creates `.gd` files)

```bash
godot --headless --path . --import > /tmp/opencode/import_<TASK>.log 2>&1
git status --porcelain   # the new <file>.gd.uid must appear; stage it with the task
```

### G7. Extract / delete / diff-verify pattern (harness tasks)

For each moved block, with the snapshot taken in the task's first step:

- Extract+rewrite into the section file: `awk '/^func A\(/{f=1} /^func Z\(/{f=0} f' <snapshot> | <G3 perl>` (end anchor `Z` = the function that follows the block; for a block running to EOF use `awk '/^func A\(/{f=1} f'`).
- Delete from `dev_harness.gd` with one `awk` pass per task using the same anchors (range inclusive of start, exclusive of end): `awk '/^func A1\(/{s=1} /^func Z1\(/{s=0} /^func A2\(/{s=1} /^func Z2\(/{s=0} !s{print}' dev_harness.gd > /tmp/opencode/dh_new.gd && mv /tmp/opencode/dh_new.gd src/autoload/dev_harness.gd`
- Byte-verify: `diff <(awk '<same extraction as above>' <snapshot> | <G3 perl>) <(awk '<extraction with same anchors>' <section file>)` → expected: **empty output** (no output at all). For the last block in a section file, extract the section side to EOF. For the `OnboardingFixtureGuard` class block (T1) the end anchor is `^var active := false`.

---

### Task 1: Harness core plumbing + `sections_boot.gd` (onboarding, task10, task11, color_assist)

**Files:**
- Create: `src/autoload/harness/sections_boot.gd` (moves ~338 lines: guard class + `_onboarding_test` + `_restore_onboarding_fixture` + `_task10_test` + `_task11_test` + `_color_assist_test`)
- Modify: `src/autoload/dev_harness.gd`

Interfaces: produces `DevHarness._sec_boot._onboarding_test(arena)` / `._task10_test(menu)` / `._task11_test(menu)` / `._color_assist_test()`. The `OnboardingFixtureGuard` inner class moves with the onboarding section (it is used only there, at line 473).

- [x] **Step 1: Snapshot and baseline**

```bash
cp src/autoload/dev_harness.gd /tmp/opencode/dh_T1.gd
wc -l src/*/*.gd src/*.gd | sort -rn > /tmp/opencode/wc_before.txt
grep -c 'print("AT_STEP' src/autoload/dev_harness.gd   # expected: 68
mkdir -p src/autoload/harness
```

- [x] **Step 2: Create `src/autoload/harness/sections_boot.gd`**

Write the G4 skeleton (lines 1–12) into the file, then append the three blocks extracted from `/tmp/opencode/dh_T1.gd` in this order, each piped through the G3 perl:

1. Guard class: `awk '/^class OnboardingFixtureGuard extends RefCounted:/{f=1} /^var active := false/{f=0} f' /tmp/opencode/dh_T1.gd` (no G3 perl needed — it is self-contained)
2. `awk '/^func _onboarding_test\(/{f=1} /^func _config_snapshot\(/{f=0} f' /tmp/opencode/dh_T1.gd | <G3 perl>`
3. `awk '/^func _task10_test\(/{f=1} /^func _color_distance\(/{f=0} f' /tmp/opencode/dh_T1.gd | <G3 perl>`

- [x] **Step 3: Delete the moved blocks from `dev_harness.gd`**

```bash
awk '/^class OnboardingFixtureGuard extends RefCounted:/{s=1} /^var active := false/{s=0} /^func _onboarding_test\(/{s=1} /^func _config_snapshot\(/{s=0} /^func _task10_test\(/{s=1} /^func _color_distance\(/{s=0} !s{print}' src/autoload/dev_harness.gd > /tmp/opencode/dh_new.gd && mv /tmp/opencode/dh_new.gd src/autoload/dev_harness.gd
```

Verify: `grep -c '^class OnboardingFixtureGuard' src/autoload/dev_harness.gd` → `0` and `grep -c '^func _onboarding_test\|^func _task10_test\|^func _task11_test\|^func _color_assist_test\|^func _restore_onboarding_fixture' src/autoload/dev_harness.gd` → `0`.

- [x] **Step 4: Add plumbing to `dev_harness.gd`**

Immediately after the line `extends Node` (line 1), add:

```gdscript
const HSectionBoot = preload("res://src/autoload/harness/sections_boot.gd")
```

Immediately after the line `var _fails := 0`, add:

```gdscript
var _sec_boot
```

Immediately before the line `func _autotest() -> void:`, add:

```gdscript
func _init_sections() -> void:
	_sec_boot = HSectionBoot.new(self)

```

Inside `_autotest()`, immediately after the line `_watchdog()`, add:

```gdscript
	_init_sections()
```

- [x] **Step 5: Rewrite the four flow call sites** (each old string is unique — verify with `grep -c` before each edit; each must be exactly 1)

| old | new |
|---|---|
| `await _onboarding_test(` | `await _sec_boot._onboarding_test(` |
| `await _task10_test(` | `await _sec_boot._task10_test(` |
| `await _task11_test(` | `await _sec_boot._task11_test(` |
| `await _color_assist_test(` | `await _sec_boot._color_assist_test(` |

- [x] **Step 6: Rewrite sweep + byte-verify**

```bash
grep -nE '(^|[^.a-zA-Z0-9_"])(_check|_pass|_fail|_ticks|_until|_simulation_seconds|_config_snapshot|_config_snapshot_matches|_config_section_snapshot|_restore_config_section|_config_sections_equal|_restore_config_snapshot|_key_event|_has_physical_key|_color_distance|_populate|_spawn_boss|_autopilot)\(' src/autoload/harness/sections_boot.gd
grep -n 'h\.h\.' src/autoload/harness/sections_boot.gd
diff <(awk '/^func _onboarding_test\(/{f=1} /^func _config_snapshot\(/{f=0} f' /tmp/opencode/dh_T1.gd | perl -pe 's/\b(_check|_pass|_fail|_ticks|_until|_simulation_seconds|_config_snapshot|_config_snapshot_matches|_config_section_snapshot|_restore_config_section|_config_sections_equal|_restore_config_snapshot|_key_event|_has_physical_key|_color_distance|_populate|_spawn_boss|_autopilot)(?=\()/h.$1/g; s/(?<![.\w])get_tree\(/h.get_tree(/g; s/(?<![.\w])get_viewport\(/h.get_viewport(/g; s/(?<![.\w])get_process_delta_time\(/h.get_process_delta_time(/g') <(awk '/^func _onboarding_test\(/{f=1} /^func _config_snapshot\(/{f=0} f' src/autoload/harness/sections_boot.gd)
```

Expected: first two greps no output, diff empty. (If a grep hits a string literal, leave the literal untouched; note it.)

- [x] **Step 7: Labels + .uid**

```bash
cat src/autoload/dev_harness.gd src/autoload/harness/*.gd | grep -c 'print("AT_STEP'   # expected: 68
godot --headless --path . --import > /tmp/opencode/import_T1.log 2>&1
git status --porcelain   # expect: new src/autoload/harness/sections_boot.gd + .uid
```

- [x] **Step 8: Full autotest** — run G1 with `at_T1.log`; expected `exit=0`, `1194`, `0`, `1`.

- [x] **Step 9: Commit**

```bash
git add src/autoload/dev_harness.gd src/autoload/harness/sections_boot.gd src/autoload/harness/sections_boot.gd.uid
git commit -m "refactor: split harness boot sections into a preloaded section script"
```

---

### Task 2: `sections_tasks_a.gd` (input_safety, task2, task5)

**Files:**
- Create: `src/autoload/harness/sections_tasks_a.gd` (~385 lines: `_input_safety_test` + `_task2_should_offer_patch` + `_task2_test` + `_task5_test`)
- Modify: `src/autoload/dev_harness.gd`

Note: `_task2_should_offer_patch` is called only from `_task2_test` (line 973); it moves with task2. `_restore_config_snapshot` (between the blocks) stays on the harness — sections call it as `h._restore_config_snapshot(...)` via G3.

- [x] **Step 1: Snapshot** — `cp src/autoload/dev_harness.gd /tmp/opencode/dh_T2.gd`

- [x] **Step 2: Create section file** — G4 skeleton, then append in order (each through the G3 perl):
  1. `awk '/^func _input_safety_test\(/{f=1} /^func _restore_config_snapshot\(/{f=0} f' /tmp/opencode/dh_T2.gd`
  2. `awk '/^func _task2_should_offer_patch\(/{f=1} /^func _task9_test\(/{f=0} f' /tmp/opencode/dh_T2.gd`

- [x] **Step 3: Delete from harness**

```bash
awk '/^func _input_safety_test\(/{s=1} /^func _restore_config_snapshot\(/{s=0} /^func _task2_should_offer_patch\(/{s=1} /^func _task9_test\(/{s=0} !s{print}' src/autoload/dev_harness.gd > /tmp/opencode/dh_new.gd && mv /tmp/opencode/dh_new.gd src/autoload/dev_harness.gd
```

Verify `grep -c '^func _input_safety_test\|^func _task2_test\|^func _task5_test\|^func _task2_should_offer_patch' src/autoload/dev_harness.gd` → `0`.

- [x] **Step 4: Plumbing** — after `extends Node` add `const HSectionTasksA = preload("res://src/autoload/harness/sections_tasks_a.gd")`; after `var _sec_boot` add `var _sec_tasks_a`; inside `_init_sections()` add the line `_sec_tasks_a = HSectionTasksA.new(self)`.

- [x] **Step 5: Flow call sites** (unique-prefix edits): `await _input_safety_test(` → `await _sec_tasks_a._input_safety_test(`; `await _task2_test(` → `await _sec_tasks_a._task2_test(`; `await _task5_test(` → `await _sec_tasks_a._task5_test(`.

- [x] **Step 6: Sweep + byte-verify** — repeat Step 6 of Task 1 against `sections_tasks_a.gd` with its two block anchors (`_input_safety_test`/`_restore_config_snapshot` and `_task2_should_offer_patch`/`_task9_test`). Expected: greps empty, diffs empty.

- [x] **Step 7: Labels + .uid** — label total `68`; `--import`; new `.uid` staged.

- [x] **Step 8: Full autotest** — G1 with `at_T2.log`; expected `exit=0`, `1194`, `0`, `1`.

- [x] **Step 9: Commit** — `git commit -m "refactor: split harness task sections into sections_tasks_a"`

---

### Task 3: `sections_tasks_b.gd` (task9, task6)

**Files:**
- Create: `src/autoload/harness/sections_tasks_b.gd` (~302 lines: `_task9_test` + `_task6_test`)
- Modify: `src/autoload/dev_harness.gd`

- [x] **Step 1: Snapshot** — `cp src/autoload/dev_harness.gd /tmp/opencode/dh_T3.gd`

- [x] **Step 2: Create section file** — G4 skeleton, then one block through the G3 perl: `awk '/^func _task9_test\(/{f=1} /^func _systems_test\(/{f=0} f' /tmp/opencode/dh_T3.gd`

- [x] **Step 3: Delete from harness**

```bash
awk '/^func _task9_test\(/{s=1} /^func _systems_test\(/{s=0} !s{print}' src/autoload/dev_harness.gd > /tmp/opencode/dh_new.gd && mv /tmp/opencode/dh_new.gd src/autoload/dev_harness.gd
```

Verify `grep -c '^func _task9_test\|^func _task6_test' src/autoload/dev_harness.gd` → `0`.

- [x] **Step 4: Plumbing** — `const HSectionTasksB = preload("res://src/autoload/harness/sections_tasks_b.gd")` after the TasksA const; `var _sec_tasks_b` after `var _sec_tasks_a`; `_sec_tasks_b = HSectionTasksB.new(self)` in `_init_sections()`.

- [x] **Step 5: Flow call sites:** `await _task9_test(` → `await _sec_tasks_b._task9_test(`; `await _task6_test(` → `await _sec_tasks_b._task6_test(`.

- [x] **Step 6: Sweep + byte-verify** — same pattern as Task 1 Step 6 with anchors `_task9_test`/`_systems_test`. Expected: greps empty, diff empty.

- [x] **Step 7: Labels + .uid** — total `68`; `--import`; stage `.uid`.

- [x] **Step 8: Full autotest** — G1 with `at_T3.log`; expected `exit=0`, `1194`, `0`, `1`.

- [x] **Step 9: Commit** — `git commit -m "refactor: split harness task9/task6 into sections_tasks_b"`

---

### Task 4: Split `_systems_test` into a/b1/b2 + move `sections_systems_a.gd`

**Files:**
- Create: `src/autoload/harness/sections_systems_a.gd` (~444 lines: `_systems_test_a`, AT_STEPs mk2→turbo, 14 labels)
- Modify: `src/autoload/dev_harness.gd`

`_systems_test` is one 1015-line function; it is split at two statement boundaries verified against the current file: line before `print("AT_STEP programs")` (preceded by `Game.patch_levels = {}`) and line before `print("AT_STEP oom")` (preceded by `player.hp = player.max_hp`). The split inserts only two function signature lines — statements, order, and labels are untouched, and the flow calls a→b1→b2 sequentially, so runtime behavior is identical.

- [x] **Step 1: Snapshot** — `cp src/autoload/dev_harness.gd /tmp/opencode/dh_T4.gd`

- [x] **Step 2: Split the function in `dev_harness.gd`** (three exact edits; each oldString must be unique — Edit tool errors otherwise)

Edit A — rename: `func _systems_test(arena: Arena) -> void:` → `func _systems_test_a(arena: Arena) -> void:`

Edit B — insert b1 signature (old string is the unique adjacent pair):

```
	Game.patch_levels = {}
	print("AT_STEP programs")
```

becomes

```
	Game.patch_levels = {}

func _systems_test_b1(arena: Arena) -> void:
	print("AT_STEP programs")
```

Edit C — insert b2 signature (unique adjacent pair):

```
	player.hp = player.max_hp
	print("AT_STEP oom")
```

becomes

```
	player.hp = player.max_hp

func _systems_test_b2(arena: Arena) -> void:
	print("AT_STEP oom")
```

- [x] **Step 3: Rewire the flow call** — replace `await _systems_test(arena2)` (unique) with:

```gdscript
	await _sec_systems_a._systems_test_a(arena2)
	await _systems_test_b1(arena2)
	await _systems_test_b2(arena2)
```

- [x] **Step 4: Move `_systems_test_a` into the section file** — first re-snapshot the split file: `cp src/autoload/dev_harness.gd /tmp/opencode/dh_T4b.gd`. Then write the G4 skeleton and append `awk '/^func _systems_test_a\(/{f=1} /^func _systems_test_b1\(/{f=0} f' /tmp/opencode/dh_T4b.gd | <G3 perl>`.

- [x] **Step 5: Delete from harness** — `awk '/^func _systems_test_a\(/{s=1} /^func _systems_test_b1\(/{s=0} !s{print}' src/autoload/dev_harness.gd > /tmp/opencode/dh_new.gd && mv /tmp/opencode/dh_new.gd src/autoload/dev_harness.gd`; verify `grep -c '^func _systems_test_a' src/autoload/dev_harness.gd` → `0`.

- [x] **Step 6: Plumbing** — `const HSectionSystemsA = preload("res://src/autoload/harness/sections_systems_a.gd")`; `var _sec_systems_a`; `_sec_systems_a = HSectionSystemsA.new(self)`.

- [x] **Step 7: Sweep + byte-verify** — anchors `_systems_test_a`/`_systems_test_b1` between `/tmp/opencode/dh_T4b.gd` and the section file. Expected: greps empty, diff empty. Label total still `68`.

- [x] **Step 8: Full autotest** — G1 with `at_T4.log`; expected `exit=0`, `1194`, `0`, `1`. (This run exercises the split: all systems AT_STEPs must still appear, in order.)

- [x] **Step 9: Commit** — `git commit -m "refactor: split systems test into sections and move part A"`

---

### Task 5: `sections_systems_b1.gd` (programs, selection_geometry, desktop_dash_hud, newenemies, teleports)

**Files:**
- Create: `src/autoload/harness/sections_systems_b1.gd` (~431 lines: `_systems_test_b1`, 7 AT_STEPs)
- Modify: `src/autoload/dev_harness.gd`

- [x] **Step 1: Snapshot** — `cp src/autoload/dev_harness.gd /tmp/opencode/dh_T5.gd`

- [x] **Step 2: Create section file** — G4 skeleton + `awk '/^func _systems_test_b1\(/{f=1} /^func _systems_test_b2\(/{f=0} f' /tmp/opencode/dh_T5.gd | <G3 perl>`

- [x] **Step 3: Delete from harness** — `awk '/^func _systems_test_b1\(/{s=1} /^func _systems_test_b2\(/{s=0} !s{print}' src/autoload/dev_harness.gd > /tmp/opencode/dh_new.gd && mv /tmp/opencode/dh_new.gd src/autoload/dev_harness.gd`; verify `grep -c '^func _systems_test_b1' src/autoload/dev_harness.gd` → `0`.

- [x] **Step 4: Plumbing** — `const HSectionSystemsB1 = preload("res://src/autoload/harness/sections_systems_b1.gd")`; `var _sec_systems_b1`; `_init_sections()` line.

- [x] **Step 5: Flow call site:** `await _systems_test_b1(arena2)` → `await _sec_systems_b1._systems_test_b1(arena2)`.

- [x] **Step 6: Sweep + byte-verify** (anchors `_systems_test_b1`/`_systems_test_b2`); label total `68`.

- [x] **Step 7: Full autotest** — G1 with `at_T5.log`; expected `exit=0`, `1194`, `0`, `1`.

- [x] **Step 8: Commit** — `git commit -m "refactor: move systems test part b1 into a section script"`

---

### Task 6: `sections_systems_b2.gd` + `sections_misc.gd` (systems tail + difficulty/debug/mote/oom_identity)

**Files:**
- Create: `src/autoload/harness/sections_systems_b2.gd` (~177 lines: `_systems_test_b2`, AT_STEPs oom→weekly_det, 7 labels)
- Create: `src/autoload/harness/sections_misc.gd` (~156 lines: `_difficulty_test`, `_debug_controls_test`, `_mote_sweep_test`, `_oom_steal_identity_test`, 4 labels)
- Modify: `src/autoload/dev_harness.gd`

- [x] **Step 1: Snapshot** — `cp src/autoload/dev_harness.gd /tmp/opencode/dh_T6.gd`

- [x] **Step 2: Create `sections_systems_b2.gd`** — G4 skeleton + `awk '/^func _systems_test_b2\(/{f=1} /^func _difficulty_test\(/{f=0} f' /tmp/opencode/dh_T6.gd | <G3 perl>`

- [x] **Step 3: Create `sections_misc.gd`** — G4 skeleton + one block through the G3 perl: `awk '/^func _difficulty_test\(/{f=1} /^func _hud_style_test\(/{f=0} f' /tmp/opencode/dh_T6.gd`

- [x] **Step 4: Delete both blocks from harness**

```bash
awk '/^func _systems_test_b2\(/{s=1} /^func _difficulty_test\(/{s=0} /^func _difficulty_test\(/{s=1} /^func _hud_style_test\(/{s=0} !s{print}' src/autoload/dev_harness.gd > /tmp/opencode/dh_new.gd && mv /tmp/opencode/dh_new.gd src/autoload/dev_harness.gd
```

Verify `grep -c '^func _systems_test_b2\|^func _difficulty_test\|^func _debug_controls_test\|^func _mote_sweep_test\|^func _oom_steal_identity_test' src/autoload/dev_harness.gd` → `0`.

- [x] **Step 5: Plumbing** — after the Task 4 const add `const HSectionSystemsB2 = preload("res://src/autoload/harness/sections_systems_b2.gd")` and `const HSectionMisc = preload("res://src/autoload/harness/sections_misc.gd")`; after `var _sec_systems_b1` add `var _sec_systems_b2` and `var _sec_misc`; add `_sec_systems_b2 = HSectionSystemsB2.new(self)` and `_sec_misc = HSectionMisc.new(self)` inside `_init_sections()`.

- [x] **Step 6: Flow call sites:** `await _systems_test_b2(arena2)` → `await _sec_systems_b2._systems_test_b2(arena2)`; `await _difficulty_test(` → `await _sec_misc._difficulty_test(`; `await _debug_controls_test(` → `await _sec_misc._debug_controls_test(`; `await _mote_sweep_test(` → `await _sec_misc._mote_sweep_test(`; `await _oom_steal_identity_test(` → `await _sec_misc._oom_steal_identity_test(`.

- [x] **Step 7: Sweep + byte-verify** both files; label total `68`.

- [x] **Step 8: Full autotest** — G1 with `at_T6.log`; expected `exit=0`, `1194`, `0`, `1`.

- [x] **Step 9: Commit** — `git commit -m "refactor: move systems tail and misc tests into section scripts"`

---

### Task 7: `sections_visual.gd` (hud_style, era_accent, story, windows, temple, glyph_lib, icon_quality, raster_trial, charm_terminal, charm_speedrun)

**Files:**
- Create: `src/autoload/harness/sections_visual.gd` (~367 lines, 10 AT_STEPs)
- Modify: `src/autoload/dev_harness.gd`

These sections contain the `source_code` checks listed in constraint 5 — the moved checks keep working unchanged because they `load()` the production files by path; only the code doing the checking moves.

- [x] **Step 1: Snapshot** — `cp src/autoload/dev_harness.gd /tmp/opencode/dh_T7.gd`

- [x] **Step 2: Create section file** — G4 skeleton + `awk '/^func _hud_style_test\(/{f=1} /^func _story_menu_test\(/{f=0} f' /tmp/opencode/dh_T7.gd | <G3 perl>`

- [x] **Step 3: Delete from harness**

```bash
awk '/^func _hud_style_test\(/{s=1} /^func _story_menu_test\(/{s=0} !s{print}' src/autoload/dev_harness.gd > /tmp/opencode/dh_new.gd && mv /tmp/opencode/dh_new.gd src/autoload/dev_harness.gd
```

Verify `grep -c '^func _hud_style_test\|^func _charm_speedrun_test' src/autoload/dev_harness.gd` → `0`.

- [x] **Step 4: Plumbing** — `const HSectionVisual = preload("res://src/autoload/harness/sections_visual.gd")`; `var _sec_visual`; `_init_sections()` line.

- [x] **Step 5: Flow call sites** (10 unique-prefix edits): `await _hud_style_test(` → `await _sec_visual._hud_style_test(`; same pattern for `_era_accent_test(`, `_story_test(`, `_windows_test(`, `_temple_test(`, `_glyph_lib_test(`, `_icon_quality_test(`, `_raster_trial_test(`, `_charm_terminal_test(`, `_charm_speedrun_test(`.

- [x] **Step 6: Sweep + byte-verify** (anchors `_hud_style_test`/`_story_menu_test`); label total `68`.

- [x] **Step 7: Full autotest** — G1 with `at_T7.log`; expected `exit=0`, `1194`, `0`, `1`.

- [x] **Step 8: Commit** — `git commit -m "refactor: move visual/era test sections into sections_visual"`

---

### Task 8: `sections_scene.gd` (story_menu → charm_save_transfer)

**Files:**
- Create: `src/autoload/harness/sections_scene.gd` (~391 lines: `_story_menu_test`, `_menu_shell_test`, `_story_scene_test`, `_story_intro_auto_test`, `_story_intro_layout_test`, `_temple_scene_test`, `_text_overflow_test`, `_touch_hud_layout_test`, `_charm_save_transfer_test`, 9 AT_STEPs)
- Modify: `src/autoload/dev_harness.gd`

- [x] **Step 1: Snapshot** — `cp src/autoload/dev_harness.gd /tmp/opencode/dh_T8.gd`

- [x] **Step 2: Create section file** — G4 skeleton + `awk '/^func _story_menu_test\(/{f=1} /^func _touch_test\(/{f=0} f' /tmp/opencode/dh_T8.gd | <G3 perl>`

- [x] **Step 3: Delete from harness**

```bash
awk '/^func _story_menu_test\(/{s=1} /^func _touch_test\(/{s=0} !s{print}' src/autoload/dev_harness.gd > /tmp/opencode/dh_new.gd && mv /tmp/opencode/dh_new.gd src/autoload/dev_harness.gd
```

Verify `grep -c '^func _story_menu_test\|^func _charm_save_transfer_test' src/autoload/dev_harness.gd` → `0`.

- [x] **Step 4: Plumbing** — `const HSectionScene = preload("res://src/autoload/harness/sections_scene.gd")`; `var _sec_scene`; `_init_sections()` line.

- [x] **Step 5: Flow call sites** (9 unique-prefix edits): `await _story_menu_test(`, `await _menu_shell_test(`, `await _story_scene_test(`, `await _story_intro_auto_test(`, `await _story_intro_layout_test(`, `await _temple_scene_test(`, `await _text_overflow_test(`, `await _touch_hud_layout_test(`, `await _charm_save_transfer_test(` — all → `await _sec_scene.<same name>(`.

- [x] **Step 6: Sweep + byte-verify** (anchors `_story_menu_test`/`_touch_test`); label total `68`.

- [x] **Step 7: Full autotest** — G1 with `at_T8.log`; expected `exit=0`, `1194`, `0`, `1`.

- [x] **Step 8: Commit** — `git commit -m "refactor: move scene/ui test sections into sections_scene"`

---

### Task 9: `sections_modes.gd` (touch trio, stress, capture, demo, achievements_panel) + `_ready` dispatch

**Files:**
- Create: `src/autoload/harness/sections_modes.gd` (~386 lines: `_touch_test` + `_press` + `_drag` + `_to_window` + `_stress` + `_capture` + `_demo` + `_achievements_panel_test`)
- Modify: `src/autoload/dev_harness.gd`

`_finish`, `_autopilot`, `_populate`, `_spawn_boss` stay on the harness (shared helpers; sections reach them via `h.` per G3). The `_ready()` env-mode dispatch moves to the section object, so `_init_sections()` must run before dispatch.

- [x] **Step 1: Snapshot** — `cp src/autoload/dev_harness.gd /tmp/opencode/dh_T9.gd`

- [x] **Step 2: Create section file** — G4 skeleton, then append in order (each through the G3 perl):
  1. `awk '/^func _touch_test\(/{f=1} /^func _finish\(/{f=0} f' /tmp/opencode/dh_T9.gd`
  2. `awk '/^func _stress\(/{f=1} /^func _autopilot\(/{f=0} f' /tmp/opencode/dh_T9.gd`
  3. `awk '/^func _achievements_panel_test\(/{f=1} f' /tmp/opencode/dh_T9.gd` (runs to EOF)

- [x] **Step 3: Delete the three blocks from harness**

```bash
awk '/^func _touch_test\(/{s=1} /^func _finish\(/{s=0} /^func _stress\(/{s=1} /^func _autopilot\(/{s=0} /^func _achievements_panel_test\(/{s=1} !s{print}' src/autoload/dev_harness.gd > /tmp/opencode/dh_new.gd && mv /tmp/opencode/dh_new.gd src/autoload/dev_harness.gd
```

Verify `grep -c '^func _touch_test\|^func _press\|^func _drag\|^func _to_window\|^func _stress\|^func _capture\|^func _demo\|^func _achievements_panel_test' src/autoload/dev_harness.gd` → `0`, and `grep -c '^func _finish\|^func _autopilot\|^func _populate\|^func _spawn_boss' src/autoload/dev_harness.gd` → `4`.

- [x] **Step 4: Plumbing + dispatch** — `const HSectionModes = preload("res://src/autoload/harness/sections_modes.gd")`; `var _sec_modes`; `_init_sections()` line `_sec_modes = HSectionModes.new(self)`. Move the `_init_sections()` invocation from `_autotest()` to the top of `_ready()` (delete the line `\t_init_sections()` from `_autotest()`, add it as the first statement of `_ready()` before `process_mode = Node.PROCESS_MODE_ALWAYS`). Rewrite the three dispatch calls: `_demo.call_deferred()` → `_sec_modes._demo.call_deferred()`; `_stress.call_deferred()` → `_sec_modes._stress.call_deferred()`; `_capture.call_deferred()` → `_sec_modes._capture.call_deferred()`. Flow call sites: `await _touch_test(` → `await _sec_modes._touch_test(`; `await _achievements_panel_test(` → `await _sec_modes._achievements_panel_test(`.

- [x] **Step 5: Sweep + byte-verify** (three block anchors); label total `68`. Also `grep -c '^func ' src/autoload/dev_harness.gd` → expected `23` (helpers, `_ready`, `_init_sections`, `_autotest`, `_finish`, `_autopilot`, `_populate`, `_spawn_boss`, and the six config-snapshot helpers remain).

- [x] **Step 6: Full autotest** — G1 with `at_T9.log`; expected `exit=0`, `1194`, `0`, `1`.

- [x] **Step 7: Commit** — `git commit -m "refactor: move mode-entry and touch test sections out of dev_harness"`

---

### Task 10: Arena panel kit (`src/arena/panel_kit.gd`) — pause/terminal/game-over builders + panel rect math

**Files:**
- Create: `src/arena/panel_kit.gd` (~380 lines: `_panel_viewport_height`, `panel_scale_for_height`, `panel_control_rect`, `_build_pause_panel`, `_place_pause_control`, `_layout_pause_panel`, `_build_terminal_panel`, `_open_terminal`, `_close_terminal`, `_make_volume_row`, `_build_game_over_panel`, `_make_panel`, `_make_button`, `_position_game_over_button`, `_position_game_over_stat`, `state_panel_rect`, `state_action_rects`, `pause_action_labels`, `pause_action_icon_kinds`, `handle_pause_input`, `game_over_action_labels`, `_make_label`, `_center_panel_control`)
- Modify: `src/arena/arena.gd`

Interfaces kept on Arena via delegates (constraint 7: `pause_input_router.gd` dispatches `handle_pause_input` dynamically; harness calls `arena.state_panel_rect` / `state_action_rects` / `pause_action_labels` / `game_over_action_labels` at dev_harness lines 1338-1373). All state (`_pause_*`, `_over_*`, `_terminal_panel`, `_debug_panel`, constants) stays on Arena.

- [x] **Step 1: Snapshot** — `cp src/arena/arena.gd /tmp/opencode/arena_T10.gd`

- [x] **Step 2: Create `src/arena/panel_kit.gd`** — header:

```gdscript
extends RefCounted

## Arena state-panel kit: pause / terminal / game-over builders and panel rect
## math. Functions are moved verbatim from src/arena/arena.gd; Arena-owned
## state and non-moved calls are prefixed with `a.` (plan G5). Untyped owner
## reference avoids a preload cycle. No behavior changes.

var a


func _init(arena) -> void:
	a = arena

```

Then append the two blocks extracted from `/tmp/opencode/arena_T10.gd`, each piped through the **RW-ARENA perl (G5)**:
  1. `awk '/^func _panel_viewport_height\(/{f=1} /^func patch_box_rect_for_viewport\(/{f=0} f' /tmp/opencode/arena_T10.gd`
  2. `awk '/^func _build_pause_panel\(/{f=1} /^func _build_intro\(/{f=0} f' /tmp/opencode/arena_T10.gd`

- [x] **Step 3: Delete the two blocks from `arena.gd`**

```bash
awk '/^func _panel_viewport_height\(/{s=1} /^func patch_box_rect_for_viewport\(/{s=0} /^func _build_pause_panel\(/{s=1} /^func _build_intro\(/{s=0} !s{print}' src/arena/arena.gd > /tmp/opencode/arena_new.gd && mv /tmp/opencode/arena_new.gd src/arena/arena.gd
```

Verify: `grep -c '^func _build_pause_panel\|^func _make_button\|^func handle_pause_input\|^func state_panel_rect\|^func panel_control_rect' src/arena/arena.gd` → `0`.

- [x] **Step 4: Wire the kit into Arena** — four exact edits:

1. After the line `const PauseInputRouterScript = preload("res://src/arena/pause_input_router.gd")` add:

```gdscript
const PanelKitScript = preload("res://src/arena/panel_kit.gd")
```

2. After the line `var _restart_triggered := false` add:

```gdscript
var _panel_kit
```

3. Inside `_ready()`, immediately after `add_to_group("arena")`, add:

```gdscript
	_panel_kit = PanelKitScript.new(self)
```

4. Add the delegate block immediately before `func _build_intro() -> void:`:

```gdscript
func panel_scale_for_height(viewport_height: float = -1.0) -> float:
	return _panel_kit.panel_scale_for_height(viewport_height)


func panel_control_rect(design_top: float, control_height: float, viewport_height: float = -1.0) -> Rect2:
	return _panel_kit.panel_control_rect(design_top, control_height, viewport_height)


func state_panel_rect(viewport: Vector2, design_top: float = 0.0, control_size: Vector2 = Vector2.ZERO) -> Rect2:
	return _panel_kit.state_panel_rect(viewport, design_top, control_size)


func state_action_rects(viewport: Vector2, count: int) -> Array[Rect2]:
	return _panel_kit.state_action_rects(viewport, count)


func pause_action_labels() -> Array[String]:
	return _panel_kit.pause_action_labels()


func pause_action_icon_kinds() -> Array[String]:
	return _panel_kit.pause_action_icon_kinds()


func handle_pause_input(event: InputEvent) -> bool:
	return _panel_kit.handle_pause_input(event)


func game_over_action_labels() -> Array[String]:
	return _panel_kit.game_over_action_labels()

```

- [x] **Step 5: Rewrite remaining internal call sites in `arena.gd`**

```bash
grep -nE '\b(_build_pause_panel|_place_pause_control|_layout_pause_panel|_build_terminal_panel|_open_terminal|_close_terminal|_make_volume_row|_build_game_over_panel|_make_panel|_make_button|_position_game_over_button|_position_game_over_stat|_make_label|_center_panel_control|_panel_viewport_height)\(' src/arena/arena.gd
```

Prefix every hit **outside the new delegate block** with `_panel_kit.`. Baseline inventory of expected external hits (line numbers shift as earlier hits are edited — re-grep each time): `_ready()` 114–116 (`_build_pause_panel/_build_terminal_panel/_build_game_over_panel`); `_refresh_responsive_layout()` 363 (`_layout_pause_panel`); `_build_intro()`/`_build_story_intro()` 717–762 and `_show_tip()` 1027–1028, `_build_patch_ui()` 1058/1068, `_show_game_over()` 1233–1234 (`_make_label`/`_center_panel_control`/`_make_panel` — the intro builders move out in Task 11, whose chain rule converts these to `a._panel_kit.`); `_close_terminal()` 1190, 1442, 1481. Re-run the grep until the only bare hits are inside the delegates themselves.

- [x] **Step 6: Call-token audit on the kit** — run the G5 audit command on `src/arena/panel_kit.gd`; every token must satisfy rule (a)/(b)/(c). Typical non-member fixes expected: `debug_controls_enabled` / `_terminal_top` / `restart_hold_duration` style calls become `a.debug_controls_enabled(...)` etc. if present.

- [x] **Step 7: .uid + autotest** — `--import`, stage `.uid`; G1 with `at_T10.log`; expected `exit=0`, `1194`, `0`, `1`.

- [x] **Step 8: Commit** — `git commit -m "refactor: extract arena pause/terminal/game-over panel kit"`

---

### Task 11: Arena intro/story kit (`src/arena/intro_kit.gd`)

**Files:**
- Create: `src/arena/intro_kit.gd` (~215 lines: `_build_intro`, `_build_story_intro`, `_show_story_intro`, `_fit_story_intro_text`, `story_intro_active`, `dismiss_story_intro`, `_finish_story_intro`, `_begin_story_spawning`, `_tick_story_intro`, `_apply_story_theme`, `_run_boss_intro`, `show_event_banner`)
- Modify: `src/arena/arena.gd`

State (`_story_stage`, `_story_intro_*`, `_intro_bars`, `_intro_label`, `_intro_quote`, `_story_victory`, `_story_next_stage`) stays on Arena — harness reads `_story_stage`/`_story_intro_panel` via `arena.get(...)` (constraint 6). Public delegates: `story_intro_active`, `dismiss_story_intro`.

- [x] **Step 1: Snapshot** — `cp src/arena/arena.gd /tmp/opencode/arena_T11.gd`

- [x] **Step 2: Create `src/arena/intro_kit.gd`** — same header shape as Task 10 (comment text: "Arena intro/story kit: wave-intro bars, story intro card, boss intro, event banner"), `var a` / `_init(arena)`, then the three blocks through the **RW-ARENA perl (G5) plus this chain rule appended to the same perl invocation**: `; s/(?<![.\w])_panel_kit\./a._panel_kit./g` (the moved intro builders call `_panel_kit._make_label(...)` after Task 10; through the kit they reach it as `a._panel_kit.`). The `STORY_INTRO_*` constants stay on Arena and are reached as `a.STORY_INTRO_*` via RW-ARENA.
  1. `awk '/^func _build_intro\(/{f=1} /^func windows_stage_profile\(/{f=0} f' /tmp/opencode/arena_T11.gd`
  2. `awk '/^func _run_boss_intro\(/{f=1} /^func _on_wave_cleared\(/{f=0} f' /tmp/opencode/arena_T11.gd`
  3. `awk '/^func show_event_banner\(/{f=1} /^func _on_player_hp\(/{f=0} f' /tmp/opencode/arena_T11.gd`

- [x] **Step 3: Delete the three blocks from `arena.gd`** (same awk range-pair technique with anchors `_build_intro`/`windows_stage_profile`, `_run_boss_intro`/`_on_wave_cleared`, `show_event_banner`/`_on_player_hp`); verify `grep -c '^func _build_intro\|^func _build_story_intro\|^func story_intro_active\|^func _run_boss_intro\|^func show_event_banner' src/arena/arena.gd` → `0`.

- [x] **Step 4: Wire the kit** — after `const PanelKitScript = preload(...)` add `const IntroKitScript = preload("res://src/arena/intro_kit.gd")`; after `var _panel_kit` add `var _intro_kit`; in `_ready()` right after the `_panel_kit = ...` line add `\t_intro_kit = IntroKitScript.new(self)`; replace the string dispatch `call_deferred("_show_story_intro")` (unique) with `_intro_kit._show_story_intro.call_deferred()`; add delegates before `func windows_stage_profile() -> void:`:

```gdscript
func story_intro_active() -> bool:
	return _intro_kit.story_intro_active()


func dismiss_story_intro() -> bool:
	return _intro_kit.dismiss_story_intro()

```

- [x] **Step 5: Rewrite internal call sites** — `grep -nE '\b(_build_intro|_build_story_intro|_show_story_intro|_fit_story_intro_text|_finish_story_intro|_begin_story_spawning|_tick_story_intro|_apply_story_theme|_run_boss_intro|show_event_banner)\(' src/arena/arena.gd` → prefix every hit outside the delegate block with `_intro_kit.`. Baseline inventory of expected external hits: `_ready()` 117/120/121; `_on_wave_started()` 923 (`_run_boss_intro`); `_on_story_wave_started()` 941 (`_apply_story_theme`); `_process()` 1610 (`_tick_story_intro`). (`dismiss_story_intro` at 1415 keeps calling the bare Arena delegate; `_fit_story_intro_text`/`_finish_story_intro`/`_begin_story_spawning` hits at 771–826 are kit-internal.)

- [x] **Step 6: Call-token audit** (G5 command on `src/arena/intro_kit.gd`).

- [x] **Step 7: .uid + autotest** — G1 with `at_T11.log`; expected `exit=0`, `1194`, `0`, `1`.

- [x] **Step 8: Commit** — `git commit -m "refactor: extract arena intro/story kit"`

---

### Task 12: Arena stage kit (`src/arena/stage_kit.gd`) — background/dust + windows/temple era visuals

**Files:**
- Create: `src/arena/stage_kit.gd` (~95 lines: `_build_background`, `windows_stage_profile`, `_build_windows_visuals`, `temple_stage_profile`, `_build_temple_visuals`, `background_corruption_for_wave`)
- Modify: `src/arena/arena.gd`

Public delegates: `windows_stage_profile`, `temple_stage_profile` (harness `_windows_test`/`_temple_test` call them on the arena). `_dust`/`_windows_watermark`/`_temple_mode` state stays on Arena; `_process()` keeps updating corruption through the arena-owned state.

- [x] **Step 1: Snapshot** — `cp src/arena/arena.gd /tmp/opencode/arena_T12.gd`

- [x] **Step 2: Create `src/arena/stage_kit.gd`** — header shape as Task 10 (comment: "Arena stage/era visual kit: background dust, Windows and Temple stage dressing"), then three blocks through the **RW-ARENA perl (G5) plus these chain rules appended to the same perl invocation**: `; s/(?<![.\w])_panel_kit\./a._panel_kit./g; s/(?<![.\w])_intro_kit\./a._intro_kit./g` (moved stage builders may call the earlier kits through the Arena reference):
  1. `awk '/^func _build_background\(/{f=1} /^func patch_box_rect_for_viewport\(/{f=0} f' /tmp/opencode/arena_T12.gd` (after Task 10 removed the panel-rect block, `patch_box_rect_for_viewport` is the successor of `_build_background`)
  2. `awk '/^func windows_stage_profile\(/{f=1} /^func _on_wave_started\(/{f=0} f' /tmp/opencode/arena_T12.gd`
  3. `awk '/^func background_corruption_for_wave\(/{f=1} /^func _request_abandon_confirmation\(/{f=0} f' /tmp/opencode/arena_T12.gd`

- [x] **Step 3: Delete the three blocks** (same range-pair awk technique with the three anchor pairs above); verify `grep -c '^func _build_background\|^func windows_stage_profile\|^func _build_windows_visuals\|^func temple_stage_profile\|^func _build_temple_visuals\|^func background_corruption_for_wave' src/arena/arena.gd` → `0`.

- [x] **Step 4: Wire the kit** — `const StageKitScript = preload("res://src/arena/stage_kit.gd")`; `var _stage_kit`; `_ready()` init line after `_intro_kit = ...`; delegates placed directly after the Task 11 delegates:

```gdscript
func windows_stage_profile() -> Dictionary:
	return _stage_kit.windows_stage_profile()


func temple_stage_profile() -> Dictionary:
	return _stage_kit.temple_stage_profile()

```

- [x] **Step 5: Rewrite internal call sites** — `grep -nE '\b(_build_background|_build_windows_visuals|_build_temple_visuals|background_corruption_for_wave)\(' src/arena/arena.gd` → prefix every hit with `_stage_kit.`. Baseline inventory of expected hits: `_ready()` 88/122/123; `_on_wave_started()` 917; `_process()` 1651 (`background_corruption_for_wave`).

- [x] **Step 6: Call-token audit + .uid + autotest** — G1 with `at_T12.log`; expected `exit=0`, `1194`, `0`, `1`.

- [x] **Step 7: Commit** — `git commit -m "refactor: extract arena stage/era visual kit"`

---

### Task 13: Menu settings kit (`src/ui/menu_settings_kit.gd`)

**Files:**
- Create: `src/ui/menu_settings_kit.gd` (~590 lines incl. header — see constraint 10 for the deliberate size): `settings_layout_for_viewport`, `_layout_settings`, `_build_settings`, `_settings_group_label`, `_build_keybind_settings`, `_keybind_action_label`, `_keybind_key_name`, `_refresh_keybind_buttons`, `_begin_keybind_capture`, `_handle_keybind_capture`, `_make_slider_row`, `_open_settings`, `_close_settings`, `_refresh_color_assist_label`
- Modify: `src/ui/menu.gd`

Sizing note (constraint 10): this exceeds the ~400 target because the settings family is one contiguous block (787–1361 in the baseline); splitting it would strand half-built wiring between tasks. The block is verbatim-moved, so review cost stays low. Public delegate on Menu: `settings_layout_for_viewport`. `_open_achievements` is not touched — the menu source-scan check (`dev_harness.gd:3844`) keeps passing. State (`_settings_*`, `_keybind_*`, `_capture_action`, …) stays on Menu — harness probes `menu.get("_capture_action")`, `menu.get("_keybind_status")`, `menu.get("_mode_info")` etc. (constraint 6).

- [ ] **Step 1: Snapshot** — `cp src/ui/menu.gd /tmp/opencode/menu_T13.gd`

- [ ] **Step 2: Create `src/ui/menu_settings_kit.gd`** — header shape as Task 10 with `var m` / `_init(menu)` and comment "Menu settings kit: settings panel build/layout, keybind capture, slider rows. Moved verbatim from src/ui/menu.gd; Menu-owned state and non-moved calls prefixed `m.` (plan G5).", then two blocks through the **RW-MENU-1 perl (G5)**:
  `awk '/^func settings_layout_for_viewport\(/{f=1} /^func _set_main_menu_controls_visible\(/{f=0} f' /tmp/opencode/menu_T13.gd` **plus** `awk '/^func _refresh_color_assist_label\(/{f=1} /^func _mk_title\(/{f=0} f' /tmp/opencode/menu_T13.gd`

- [ ] **Step 3: Delete the two blocks from `menu.gd`** (range-pair awk with anchors `settings_layout_for_viewport`/`_set_main_menu_controls_visible` and `_refresh_color_assist_label`/`_mk_title`); verify `grep -c '^func _build_settings\|^func _build_keybind_settings\|^func _handle_keybind_capture\|^func _make_slider_row\|^func _layout_settings\|^func settings_layout_for_viewport' src/ui/menu.gd` → `0`.

- [ ] **Step 4: Wire the kit** — after `const TacticalIconScript = preload("res://src/ui/tactical_icon.gd")` add `const MenuSettingsKitScript = preload("res://src/ui/menu_settings_kit.gd")`; after `var _settings_keybind_grid: GridContainer` add `var _settings_kit`; in `_ready()`, add `_settings_kit = MenuSettingsKitScript.new(self)` as the **first statement of the function body** (the `_build_settings()` call at baseline line 186 lives in `_ready()`, so the kit must exist before it); add delegate after the (retained) `keybind_capture_visible()` function:

```gdscript
func settings_layout_for_viewport(viewport: Vector2) -> Dictionary:
	return _settings_kit.settings_layout_for_viewport(viewport)

```

- [ ] **Step 5: Rewrite internal call sites** — `grep -nE '\b(settings_layout_for_viewport|_layout_settings|_build_settings|_settings_group_label|_build_keybind_settings|_keybind_action_label|_keybind_key_name|_refresh_keybind_buttons|_begin_keybind_capture|_handle_keybind_capture|_make_slider_row|_open_settings|_close_settings|_refresh_color_assist_label)\(' src/ui/menu.gd` → prefix every hit outside the delegate with `_settings_kit.`. Baseline inventory of expected external hits: `_ready()` 186 (`_build_settings`); `_build_button_row()` 716 (`settings_layout_for_viewport`); `_input()` 1529 and `_unhandled_input()` 1565 (`_close_settings`); `_unhandled_input()` 1561 (`_handle_keybind_capture`). (Hits inside 817–1314 are kit-internal after the move.)

- [ ] **Step 6: Preload consts + call-token audit** — the moved settings code references menu-level preloads (baseline shows `TacticalUIHelper.CYAN`/`MAGENTA` at 1116–1146). Run `grep -oE 'TacticalUIHelper|TacticalChromeScript|TacticalIconScript|TacticalStateSurfaceHelper|PatchCard' src/ui/menu_settings_kit.gd | sort -u` and copy each hit's matching preload line verbatim from the top of `menu.gd` into the kit header below `extends RefCounted` (e.g. `const TacticalUIHelper = preload("res://src/ui/tactical_ui.gd")`). Duplicating a preload const is a pure move-safe change. Then run the G5 audit command on the kit file.

- [ ] **Step 7: .uid + autotest** — G1 with `at_T13.log`; expected `exit=0`, `1194`, `0`, `1`.

- [ ] **Step 8: Commit** — `git commit -m "refactor: extract menu settings kit"`

---

### Task 14: Menu chrome/shell kit (`src/ui/menu_chrome_kit.gd`)

**Files:**
- Create: `src/ui/menu_chrome_kit.gd` (~380 lines: `_style_card_button`, `_add_menu_frame`, `_set_button_text_inset`, `_settings_nav_style`, `_add_button_chrome`, `_add_button_icon`, `_style_settings_footer_button`, `footer_button_layout_for_viewport`, `_build_button_row`, `_style_overlay_back`, `_mk_title`, plus `_draw` body as `draw_shell(m)`)
- Modify: `src/ui/menu.gd`

`Menu._draw()` stays as a two-line method delegating to `MenuChromeKit.draw_shell(self)` — same draw calls, same order, zero visual change. The `_process()` drifter update loop is NOT moved (keeps `_process` intact). Public delegate on Menu: `footer_button_layout_for_viewport`. The source-scan check `menu_src.contains("_open_achievements")` is unaffected.

- [ ] **Step 1: Snapshot** — `cp src/ui/menu.gd /tmp/opencode/menu_T14.gd`

- [ ] **Step 2: Create `src/ui/menu_chrome_kit.gd`** — header shape as Task 13 (comment: "Menu shell/chrome kit: card buttons, frames, button row, overlay back styling, decorative `_draw` output. Moved verbatim from src/ui/menu.gd."), then four blocks through the **RW-MENU-2 perl (G5)** — it already carries the member group, the reduced method group, the `_settings_kit` chain rule, the Node/CanvasItem rewrites, and the `size` rewrite (audit every `size` hit — if a moved body declares a local named `size`, revert that one rewrite to the local):
  1. `awk '/^func _style_card_button\(/{f=1} /^func _refresh_program_label\(/{f=0} f' /tmp/opencode/menu_T14.gd`
  2. `awk '/^func _style_overlay_back\(/{f=1} /^func main_shell_snapshot\(/{f=0} f' /tmp/opencode/menu_T14.gd`
  3. `awk '/^func _mk_title\(/{f=1} /^func _reset_scores\(/{f=0} f' /tmp/opencode/menu_T14.gd`
  4. `_draw` body as `draw_shell`: `awk '/^func _draw\(/{f=1} /^func _input\(/{f=0} f' /tmp/opencode/menu_T14.gd | sed '1s/^func _draw() -> void:/func draw_shell(m) -> void:/' | <rewrites>` (the moved `_draw` header becomes `draw_shell(m)`; its body references `size` and draw methods, rewritten as above).

- [ ] **Step 3: Delete the four blocks from `menu.gd`** (range-pair awk: `_style_card_button`/`_refresh_program_label`, `_style_overlay_back`/`main_shell_snapshot`, `_mk_title`/`_reset_scores`, `_draw`/`_input`); verify `grep -c '^func _style_card_button\|^func _build_button_row\|^func _style_overlay_back\|^func _mk_title\|^func _draw' src/ui/menu.gd` → `0`.

- [ ] **Step 4: Wire the kit + keep `_draw`** — `const MenuChromeKitScript = preload("res://src/ui/menu_chrome_kit.gd")`; `var _chrome_kit`; `_ready()` init line after `_settings_kit = ...`; replace the deleted `_draw` with:

```gdscript
func _draw() -> void:
	if _chrome_kit == null:
		_chrome_kit = MenuChromeKitScript.new(self)
	_chrome_kit.draw_shell(self)
```

(The null guard is construction-order insurance only; the kit is also built in `_ready()`. No drawing happens before `_ready` in Godot, so this changes no behavior.) Add delegate after the retained `keybind_capture_visible()`/`settings_layout_for_viewport()` area:

```gdscript
func footer_button_layout_for_viewport(viewport_size: Vector2) -> Dictionary:
	return _chrome_kit.footer_button_layout_for_viewport(viewport_size)

```

- [ ] **Step 5: Rewrite internal call sites + settings-kit bridges** — first prefix: `grep -nE '\b(_style_card_button|_add_menu_frame|_set_button_text_inset|_settings_nav_style|_add_button_chrome|_add_button_icon|_style_settings_footer_button|_build_button_row|_style_overlay_back|_mk_title)\(' src/ui/menu.gd` → prefix every remaining hit in `menu.gd` with `_chrome_kit.`. Baseline inventory of expected hits: `_ready()` 105–107 (`_mk_title` ×3) and 185 (`_build_button_row`); `_open_program_selector()` 505, `_open_story_selector()` 554, `_open_bestiary()` 609, `_open_achievements()` 641 (`_style_overlay_back`). Second, the bridge: Task 13's settings kit calls four chrome helpers through the Menu reference (`grep -nE 'm\._(style_card_button|add_button_chrome|add_button_icon|add_menu_frame|settings_nav_style|set_button_text_inset|style_settings_footer_button|mk_title)' src/ui/menu_settings_kit.gd` — baseline data says `_style_settings_footer_button`, `_add_button_icon`, `_add_button_chrome`, `_settings_nav_style`). Add a `_chrome_kit.`-delegating method on Menu for **every** name that grep returns, using this exact shape (shown for the four baseline-known names):

```gdscript
func _style_settings_footer_button(button: Button, border: Color) -> void:
	_chrome_kit._style_settings_footer_button(button, border)


func _add_button_icon(button: Button, kind: String, accent: Color, icon_size: float = 52.0) -> void:
	_chrome_kit._add_button_icon(button, kind, accent, icon_size)


func _add_button_chrome(button: Button, accent: Color, alpha: float = 0.02) -> void:
	_chrome_kit._add_button_chrome(button, accent, alpha)


func _settings_nav_style(border: Color) -> StyleBoxFlat:
	return _chrome_kit._settings_nav_style(border)

```

(Copy each delegate's signature verbatim from the moved function's original signature in `/tmp/opencode/menu_T14.gd`.)

- [ ] **Step 6: Preload consts + call-token audit** — same as Task 13 Step 6 against `src/ui/menu_chrome_kit.gd` (baseline shows `TacticalUIHelper` at 441/450; `TacticalIconScript` may appear via `_add_button_icon`), then the G5 audit command on the kit file.

- [ ] **Step 7: .uid + autotest** — G1 with `at_T14.log`; expected `exit=0`, `1194`, `0`, `1`.

- [ ] **Step 8: Commit** — `git commit -m "refactor: extract menu chrome/shell kit"`

---

### Task 15: Dead-code sweep (grep-proven only)

**Files:**
- Modify: only files with a proven-unused private function.

- [ ] **Step 1: Run the candidate scan** (private funcs referenced only by their own definition):

```bash
for f in $(grep -rhoE '^func _[a-z_0-9]+' src/*/*.gd src/*.gd | sed 's/func //' | sort -u); do
  n=$(grep -rc "\b$f\b" src --include='*.gd' --include='*.tscn' | awk -F: '{s+=$2} END{print s}')
  [ "$n" -le 1 ] && echo "CANDIDATE $f"
done
```

- [ ] **Step 2: Verify each candidate individually** — for each `CANDIDATE` output, run `grep -rn '\bNAME\b' src project.godot` (must return exactly one hit: the `func` definition line) and `grep -rn 'NAME' --include='*.tscn' .` (must return nothing). Baseline scan (pre-refactor) found exactly one candidate: `_panel_position` in `src/ui/terminal_panel.gd:268`. Re-run the scan after Tasks 1–14 — if a moved function was orphaned by the moves, it appears here and gets the same treatment; if a candidate is referenced by any harness check or scene, it is NOT dead — leave it and record why in the commit message body.

- [ ] **Step 3: Delete each confirmed candidate** with the Edit tool (exact function text) — e.g. for `_panel_position`, delete `func _panel_position() -> Vector2:` plus its body lines in `src/ui/terminal_panel.gd`.

- [ ] **Step 4: Full autotest** — G1 with `at_T15.log`; expected `exit=0`, `1194`, `0`, `1`.

- [ ] **Step 5: Commit** — `git commit -m "refactor: remove provably unused private helpers"` (list each removed name in the body).

---

### Task 16: Final verification + structure report

**Files:**
- Modify: `docs/superpowers/plans/2026-08-30-structure-refactor.md` (append report)

- [ ] **Step 1: Full autotest** — G1 with `at_T16.log`; expected `exit=0`, `1194`, `0`, `1`. Also re-run the label check: `cat src/autoload/dev_harness.gd src/autoload/harness/*.gd | grep -c 'print("AT_STEP'` → `68`.

- [ ] **Step 2: Produce the after-table**

```bash
wc -l src/*/*.gd src/*.gd | sort -rn > /tmp/opencode/wc_after.txt
diff /tmp/opencode/wc_before.txt /tmp/opencode/wc_after.txt
git log --oneline | head -20
```

- [ ] **Step 3: Append the structure report** to this plan document below this task — a markdown table with columns `file | before | after | delta` for the top-10 baseline files plus every new `src/autoload/harness/*.gd`, `src/arena/*_kit.gd`, `src/ui/menu_*_kit.gd` file, filled from `/tmp/opencode/wc_after.txt`, followed by the `git log --oneline` list of the `refactor:` commits produced by Tasks 1–15. Commit:

```bash
git add docs/superpowers/plans/2026-08-30-structure-refactor.md
git commit -m "docs: append structure refactor report"
```

---

## Expected end state (projections, verified for real in Task 16)

| file | before | after (projected) |
|---|---|---|
| src/autoload/dev_harness.gd | 3867 | ~620 |
| src/arena/arena.gd | 1672 | ~1090 |
| src/ui/menu.gd | 1615 | ~690 |
| new: 9 harness section scripts | 0 | ~3450 |
| new: 3 arena kits | 0 | ~690 |
| new: 2 menu kits | 0 | ~970 |

Every intermediate state is committed, green (`AUTOTEST_ALL_PASS`, 1194/0), and independently revertable. No production behavior, save format, visual, public API, signal, or group name changes at any point.

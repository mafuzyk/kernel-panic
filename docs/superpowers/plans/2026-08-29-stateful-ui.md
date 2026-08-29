# Stateful Tactical UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Bring pause, terminal, game-over, menu, and selection surfaces into the approved Tactical Kernel visual system while preserving their existing actions and mobile behavior.

**Architecture:** Reuse `TacticalUI.angular_points`, semantic colors, Orbitron, and Share Tech Mono. Stateful panels stay code-drawn; existing controls remain the interaction layer. Each surface exposes deterministic geometry or snapshot helpers so the harness can verify containment, ordering, and state text without relying on pixels alone.

**Tech Stack:** Godot 4.7.2, GDScript, CanvasItem drawing, existing `DevHarness` autotest and fullscreen capture hook.

**Spec:** `docs/superpowers/specs/2026-08-29-ui-overhaul-design.md`

## Global Constraints

- Preserve existing action routing, pause semantics, terminal commands, save transfer, and touch controls.
- All visual animation uses global cosmetic randomness only; never consume `Game.rng`.
- Use code-drawn angular frames and existing fonts; do not add image assets.
- Desktop-only controls remain gated by `Balance.is_desktop_display()` and touchscreen checks.
- Restore the OS cursor in every non-play state.
- After every task run `godot --headless --path . -- --autotest`; require `AUTOTEST_ALL_PASS` and zero `AT_FAIL`.
- Compare each representative fullscreen or narrow capture beside its approved mock at the same output size before committing.

---

### Task 1: Pause and game-over tactical panels

**Files:**
- Create: `src/ui/tactical_state_surface.gd`
- Modify: `src/arena/arena.gd`
- Modify: `src/autoload/dev_harness.gd`

**Interfaces:**
- Produces `Arena.state_panel_rect(viewport: Vector2, design_top: float, control_size: Vector2) -> Rect2`.
- Produces `Arena.pause_action_labels() -> Array[String]` and `Arena.game_over_action_labels() -> Array[String]`.

- [ ] **Step 1: Add failing geometry and action assertions**

Assert that the state panel and every action rectangle are contained by 1366×768, 720×720, and 432×720; assert pause exposes `RESUME`, `RESTART`, `OPEN TERMINAL`, and `ABANDON PROCESS`, with abandon remaining last and confirmable.

- [ ] **Step 2: Run the clean autotest and observe the expected failure**

Run `env XDG_DATA_HOME=/tmp/kernel-panic-ui-test/data XDG_CONFIG_HOME=/tmp/kernel-panic-ui-test/config godot --headless --path . -- --autotest`; expect the new Arena API assertion to fail.

- [ ] **Step 3: Implement the panels**

Replace the rounded/flat state treatment with opaque navy angular frames, a compact status rail, separated action rows, and a magenta termination treatment. Keep the existing button callbacks and two-step abandon flow. Add a deterministic `state_panel_rect` and action-label helpers; keep all vertical placement responsive through `_center_panel_control`.

- [ ] **Step 4: Run the autotest and capture both states**

Require `AUTOTEST_ALL_PASS`, then capture `pause` and `over` in fullscreen, inspect them beside `exec-1d634528-bda7-480b-9f34-075c554f9dea.png` and `exec-944e9096-fa9f-466a-bc2d-9e4ed17d5fcb.png`.

- [ ] **Step 5: Commit**

```bash
git add src/arena/arena.gd src/autoload/dev_harness.gd
git commit -m "feat: rebuild pause and game-over tactical panels"
```

### Task 2: Diagnostic terminal workstation

**Files:**
- Modify: `src/ui/terminal_panel.gd`
- Modify: `src/autoload/dev_harness.gd`

**Interfaces:**
- Produces `TerminalPanel.workstation_rect(viewport: Vector2) -> Rect2`.
- Produces `TerminalPanel.status_snapshot() -> Dictionary`.
- Preserves `submit_command`, `output_text`, `open_terminal`, and `close_terminal`.

- [ ] **Step 1: Add failing workstation assertions**

Assert the workstation fits all target viewports, status snapshot includes `TTY0`, `PAUSED`, and a command count, and the prompt remains present after a command.

- [ ] **Step 2: Run the clean autotest and observe the expected failure**

Run the verification command and expect the new workstation API assertion to fail.

- [ ] **Step 3: Implement the diagnostic layout**

Use a wide clipped-corner workstation, left command rail, command-history viewport, right status column, and persistent prompt. Keep the existing router as the only command source and keep the input focus behavior unchanged.

- [ ] **Step 4: Run the autotest and capture the terminal**

Require `AUTOTEST_ALL_PASS`; compare against `exec-29282195-8e49-474d-9535-c3d867495afe.png` at the same fullscreen size.

- [ ] **Step 5: Commit**

```bash
git add src/ui/terminal_panel.gd src/autoload/dev_harness.gd
git commit -m "feat: rebuild diagnostic terminal workstation"
```

### Task 3: Program, story, and bestiary selection surfaces

**Files:**
- Modify: `src/ui/program_panel.gd`
- Modify: `src/ui/story_panel.gd`
- Modify: `src/ui/bestiary_panel.gd`
- Modify: `src/ui/menu.gd`
- Modify: `src/autoload/dev_harness.gd`

**Interfaces:**
- Each selection panel exposes `content_viewport_rect()` and preserves its current selection method and signals.
- Program selection retains `select_program`; story selection retains `select_stage`; bestiary retains its unlock/detail behavior.

- [ ] **Step 1: Add failing selection geometry assertions**

Assert all visible card rectangles are contained by their content viewport, selected program/stage cards have distinct accent treatment, and locked cards remain explicitly labeled.

- [ ] **Step 2: Run the clean autotest and observe the expected failure**

Run the verification command and expect the new visual geometry assertion to fail.

- [ ] **Step 3: Implement the selection treatment**

Use clipped angular cards, readable identity/role/stat blocks, a strong selected outline, connected story route markers, and a bestiary detail rail. Preserve scrolling, pointer/touch selection, and existing progression checks.

- [ ] **Step 4: Run the autotest and capture all three surfaces**

Require `AUTOTEST_ALL_PASS`; compare the program, story, and bestiary captures against their approved mocks at identical sizes.

- [ ] **Step 5: Commit**

```bash
git add src/ui/program_panel.gd src/ui/story_panel.gd src/ui/bestiary_panel.gd src/ui/menu.gd src/autoload/dev_harness.gd
git commit -m "feat: unify program story and bestiary selection UI"
```

### Task 4: Main menu and settings workstation shell

**Files:**
- Modify: `src/ui/menu.gd`
- Modify: `src/autoload/dev_harness.gd`

**Interfaces:**
- Produces `Menu.main_shell_snapshot() -> Dictionary` and `Menu.settings_shell_snapshot() -> Dictionary`.
- Preserves all existing menu button callbacks, keybind capture, settings persistence, and reset confirmation.

- [ ] **Step 1: Add failing shell assertions**

Assert the title, primary purge action, mode explanation, settings groups, and bestiary/program/story routes are exposed in the shell snapshots.

- [ ] **Step 2: Run the clean autotest and observe the expected failure**

Run the verification command and expect the shell assertion to fail.

- [ ] **Step 3: Implement the menu shell**

Use the approved central boot stack, peripheral diagnostic panels, clipped-corner buttons, mode/status readout, and a framed settings scroll surface. Keep touch sizing and desktop keybind visibility unchanged.

- [ ] **Step 4: Run the autotest and capture menu/settings**

Require `AUTOTEST_ALL_PASS`; compare against `exec-7c00ce45-cc08-4066-b55e-b5675ba4f68c.png` and `exec-aa311ce4-b3f4-472a-9824-a8bd022d7e86.png`.

- [ ] **Step 5: Commit**

```bash
git add src/ui/menu.gd src/autoload/dev_harness.gd
git commit -m "feat: rebuild menu and settings tactical shell"
```

### Task 5: Full visual comparison and final verification

**Files:**
- Modify: `docs/superpowers/specs/2026-08-29-ui-overhaul-design.md`
- Modify only the affected UI files for concrete visual corrections.

- [ ] **Step 1: Capture fullscreen and narrow states**

Capture HUD, patch, pause, terminal, menu, program, story, bestiary, settings, and game-over states. Keep output under `/tmp/kernel-panic-ui-overhaul/`.

- [ ] **Step 2: Compare each capture beside its approved mock**

Inspect hierarchy, clipping, alignment, typography, contrast, cursor state, and compositor-scaled narrow output. Record only concrete mismatches in a temporary `Visual correction pass` subsection.

- [ ] **Step 3: Correct and recapture**

Apply the smallest code-drawn corrections, then remove the temporary subsection after every recorded mismatch is resolved.

- [ ] **Step 4: Run final verification**

Run the clean autotest and require `AUTOTEST_ALL_PASS` with zero `AT_FAIL`; run `git diff b8b30a4..HEAD --stat` and ensure no binaries, credentials, `.godot/`, or unrelated handoff files are staged.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/specs/2026-08-29-ui-overhaul-design.md
git commit -m "fix: verify stateful tactical UI surfaces"
```

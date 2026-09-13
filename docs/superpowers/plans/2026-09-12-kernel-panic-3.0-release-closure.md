# KERNEL PANIC 3.0 Cross-Platform Release Closure Implementation Plan

**Goal:** Close the remaining verified blockers for KERNEL PANIC 3.0.0 and produce a release-candidate tree that can honestly ship on Linux x86_64, Windows x86_64, and Android arm64, without reopening already-finished systems or expanding the release into unsupported macOS/photo-mode work.

**Architecture:** Preserve the current Godot 4.7 design-system/UI architecture and the already-dirty 3.0 fixes. Make only narrow corrections at the owning layer: gameplay correctness in `GodBoss`, modal cursor/reticle lifecycle in `Reticle`/`Arena`, primary-action focus geometry in `MenuShell`, localization ownership in `StoryData` + existing UI owners, music-variant policy in `Sfx`, and a dedicated touch/mobile composition layer that reuses gameplay/data/callbacks without shrinking the desktop UI.

**Tech Stack:** Godot 4.7, GDScript, CSV/compiled Godot translations, project DevHarness, KWin/Xwayland virtual-session capture tooling, Godot Linux/Windows export presets, Arch/AUR packaging shell scripts.

**Spec:** `KERNEL-PANIC-ROADMAP.md`, with the release-scope rulings in this document overriding older roadmap items for the 3.0.0 ship decision.

**Global Constraints:**

- Work on the current dirty branch `feat/design-system-and-glyphs`; do not reset, clean, stash, checkout away, or overwrite unrelated work.
- Preserve already-landed 3.0 fixes: live mode/difficulty controls, event-banner delegate, `integrity_restored`, heal semantics, OOM ownership, PAGE FAULT cap, Story restart, DAEMON 0→1→2 dash recharge, terminal history/autocomplete, debug enemy coverage, save hardening, and 3.0.0 metadata.
- Prime remains the only integration owner. If commits are made, stage only the files intentionally changed by that task; never `git add -A` the existing dirty tree.
- No publishing, tagging, GitHub release upload, AUR push, or external deployment in this plan. The final output is a verified local release candidate and artifacts ready for an explicit publish decision.
- Do not broaden PC layout work. Physical 1280×720 and 1920×1080 are already readable; whitespace is intentional in the current editorial direction.
- Android arm64 **is** a supported 3.0.0 target, contingent on the dedicated mobile blockers and real on-device QA below. The user has testers available on Android, Windows, and Linux.
- Windows support is a full 3.0 target, with meaningful smoke testing of the final `.exe` performed by the available Windows tester.
- macOS is intentionally unsupported because there is no macOS test environment/tester; do not add a macOS export/support claim.

---

## 0. Final Council/Judge verdict — authoritative release scope

### Ship target

`3.0.0` targets all three supported/testable platforms:

- Linux x86_64 — target, contingent on final automated/visual/artifact gates.
- Windows x86_64 — target, contingent on final build + meaningful smoke gate by the Windows tester.
- Android arm64 — target, contingent on the dedicated mobile UX/input gates plus real-device smoke/QA by the Android tester.
- macOS — no platform target and no macOS Story act in 3.0.0.

### MUST — blockers for 3.0

1. Correct TempleOS GOD cadence; the final boss currently slows down as HP falls.
2. Fix custom reticle lifecycle so it never remains drawn over patch, pause, or terminal modals and returns only when gameplay resumes.
3. Bound the PURGE keyboard-focus ring to the primary action instead of almost the entire menu action column.
4. Finish the bilingual EN/PT-BR contract for normal player-facing surfaces, with runtime Story localization and a Settings language selector as mandatory parts.
5. Close Android simultaneous-touch routing: move + aim must remain held while a third touch activates DASH/BOOST; disabled BOOST must not steal `_aim_id`.
6. Finish the dedicated landscape-first mobile composition gate: real safe area, touch targets, no keyboard-hint leakage, and mobile layouts for the dense release surfaces instead of compressed desktop composition.
7. Align README/release-facing docs with the actual Linux/Windows/Android 3.0 platform promise.
8. Pass narrow regressions, full harness/release-safe gates, desktop EN/PT visual gates, forced-touch mobile visual gates, fresh Linux/Windows/Android artifacts, tester smokes, and final packaging/AUR reconciliation.

### SHOULD — non-blocking polish after all MUST work is green

- Keep the existing TempleOS `holy` creative intent and implement it as a real, subtle Sfx music variant using only existing stems. No new track/assets/composition system.
- Fix Settings initial keyboard focus locally if final visual/input verification still shows an invisible/ambiguous first focus. Do not redesign Settings.
- Touch HUD/Event Log only if the final 1280 gate reproduces a concrete playfield occlusion. No broad HUD redesign.

### DEFER

- macOS Story act.
- Photo Mode.
- New/distinct generated soundtrack per Windows era.
- Weekly mutators, leaderboard work, practice/wave-select, death heatmap, or other mode expansion.

### REJECT for 3.0

- New patches, regular enemies, ROOT profiles, playable programs, modes, or GOD attacks.
- Any change to GOD's literal gameplay-RNG selection model.
- New audio assets/tracks solely to make `holy` work.

### DO-NOT-TOUCH visually

- Broad 1080p menu/type enlargement.
- Global HUD/state scaling.
- Settings/Achievements whitespace as though it were a defect.
- Existing PC composition of Program, Story, Bestiary, Achievements, Pause, Run Summary, or PC patch-card sizing except for a verified regression.

---

## 1. Establish the release baseline without changing behavior

**Files:**
- Read: `project.godot`
- Read: `export_presets.cfg`
- Read: `README.md`
- Read: `packaging/aur/kernel-panic-bin/PKGBUILD`
- Read: `packaging/aur/kernel-panic-bin/.SRCINFO`
- Read: `src/autoload/dev_harness.gd`

**Step 1 — Record the exact starting tree.**

Capture branch, HEAD, `git status --short`, and `git diff --stat`. Record that existing source changes belong to the current 3.0 work and are not to be reverted.

**Step 2 — Confirm obsolete audit findings are already closed.**

Before changing anything, verify in the live tree that these remain present:

- `project.godot` and export/package metadata report `3.0.0`.
- `MenuShell.mode_cycled` / `difficulty_cycled` are real actions and `menu.gd` connects them.
- `Arena.show_event_banner()` exists.
- `integrity_restored` is actually unlocked through real heal semantics.
- DAEMON multi-charge recharge has the 0→1→2 recovery regression in `sections_deep.gd`.
- terminal history/autocomplete is implemented.

If one of these disappeared because another concurrent edit regressed it, stop and reconcile that regression before continuing. Do not reimplement it from old reports blindly.

**Step 3 — Freeze the platform contract internally.**

From this point through final build, treat supported 3.0 as Linux + Windows + Android. Android must be solved as a dedicated landscape-first composition/input path; do not make its screenshots “look acceptable” by scaling the PC layout.

---

## 2. Write the narrow regressions before correcting the remaining blockers

**Files:**
- Modify: `src/autoload/harness/sections_visual.gd`
- Modify: `src/autoload/harness/sections_scene.gd` and/or `sections_polish.gd` for UI geometry/i18n ownership
- Modify only if needed: `src/autoload/dev_harness.gd` to wire genuinely new test entry points

### 2A. GOD cadence contract

Extend `_temple_test()` so a `GodBoss` exposes a pure interval contract and the test asserts:

```text
interval(P1) > interval(P2) > interval(P3)
```

Target values for the first correction pass are approximately:

```text
P1 = 2.20 s
P2 = 1.90 s
P3 = 1.60 s
```

Keep the existing same-seed oracle-roll assertion. The cadence test must not advance or replace the gameplay RNG.

**Expected pre-fix result:** cadence assertion fails while the deterministic oracle-roll assertion remains green.

### 2B. Reticle/modal contract

Add a behavior-level probe, not a source-text grep:

- gameplay + hidden OS cursor => custom reticle visible;
- patch modal => custom reticle absent;
- pause => absent;
- terminal => absent;
- resume normal gameplay => visible again when the OS cursor returns to hidden mode.

Prefer testing the Reticle lifecycle directly plus one Arena modal integration path. Do not encode arbitrary frame delays as the contract.

### 2C. PURGE focus geometry contract

Expose only the geometry needed for verification from `MenuShell` (for example `primary_action_rect()` / `primary_hit_rect()`), then assert:

- action hit/focus rect encloses the visible PURGE arrow+label;
- height meets `Design.CLICK_TARGET_MIN` or the current primary target contract;
- width is bounded to the primary content plus intentional padding and is materially smaller than the full action column;
- Story/Archives/mode/difficulty/footer actions retain their existing containment/focus behavior.

### 2D. Localization contract

Extend `_i18n_test()` so both `en` and `pt_BR` resolve every new release-critical key. Add behavior checks that:

- `Game.set_language()` changes and persists the selected language;
- Story title, intro, act label, at least one klog line, victory subtitle/meta, Windows watermark, and Story intro dismiss hint resolve differently where PT-BR has a distinct translation;
- Settings exposes a live language control wired to the Game language owner;
- changing language refreshes visible menu/settings text rather than requiring process restart.

Do not make debug/dev console text, command names (`help`, `top`, `dmesg`, etc.), proper names, file paths, or intentional technical identifiers a translation requirement.

---

## 3. Fix TempleOS GOD cadence — MUST

**Files:**
- Modify: `src/enemies/god_boss.gd`
- Test: `src/autoload/harness/sections_visual.gd::_temple_test`

**Current defect:** `_move()` schedules approximately `1.84 → 2.02 → 2.20` seconds from phase 1 to 3 and computes `phase` after the reset, so the finale de-escalates.

**Step 1 — Make interval policy explicit and testable.**

Add a small pure helper such as:

```gdscript
func oracle_interval_for_phase(target_phase: int) -> float:
    match clampi(target_phase, 1, 3):
        1: return 2.20
        2: return 1.90
        _: return 1.60
```

Exact representation may be a constant array/dictionary instead, but there must be one named source of truth for the phase cadence.

**Step 2 — Compute phase from current HP before scheduling the next oracle attack.**

In `_move()`, derive `phase` from current `hp / max_hp` before the `oracle_cd <= 0` reset. Use the helper for the new cooldown.

**Step 3 — Preserve attack selection exactly.**

Do not change `roll_oracle_attack()`, attack weights, attacks themselves, seed usage, or add phase-specific attacks.

**Acceptance:**

- automated `P1 > P2 > P3` interval test green;
- existing same-seed oracle roll test green;
- 20–30 seconds of TempleOS GOD runtime at 640×640 shows increasing cadence without unreadable telegraph overlap or script error.

---

## 4. Fix custom reticle across modal lifecycle — MUST

**Files:**
- Modify: `src/ui/reticle.gd`
- Modify only where necessary: `src/arena/arena.gd`
- Verify integration with: pause, patch, terminal
- Test: appropriate harness section from Task 2B

**Current defect:** patch opening sets `Input.mouse_mode = VISIBLE`, then pauses the tree. `Reticle._process()` is pausable, so it can freeze on the previous visible frame over the patch UI. The same lifecycle can affect pause/terminal.

**Preferred correction:** make Reticle process while paused and derive visibility from the actual cursor/modal state every frame rather than manually hiding it with timing hacks.

Implementation direction:

- add `_ready()` in `reticle.gd` with `process_mode = Node.PROCESS_MODE_ALWAYS`;
- continue deriving `visible` from the OS mouse mode, and only update position/draw when visible;
- if terminal or another modal can intentionally keep the OS cursor hidden, add one explicit Arena modal/reticle-allowed predicate instead of scattered `visible = false` assignments.

Do not create a delay/tween-based workaround.

**Acceptance:**

- no custom cyan reticle over patch, pause, terminal, run summary, or Story victory;
- reticle returns after resume when gameplay owns the mouse again;
- no cursor flicker between `_pick_patch()` unpause and `_try_show_patch()` chained offers;
- desktop mouse aim is unchanged during active gameplay.

---

## 5. Bound the PURGE focus ring without redesigning the menu — MUST

**Files:**
- Modify: `src/ui/menu_shell.gd`
- Test: MenuShell/menu reflow harness

**Current defect:** `_overlay_button()` inherits the expanding horizontal flags of its content host; PURGE therefore receives a FULL_RECT focus Button spanning most of the action column.

**Step 1 — Fix only the primary-action host sizing.**

Keep `_overlay_button()` generic for other actions. Make the PURGE action shrink to its visible arrow+label row plus intentional hit padding, for example by using `SIZE_SHRINK_BEGIN` on the primary host/content and a minimum vertical target.

Do not shrink the actual clickable area below the design click-target minimum.

**Step 2 — Preserve hierarchy.**

Do not enlarge PURGE typography, hero radius, global display tokens, or 1080 layout while touching this code.

**Acceptance:**

- focus ring visually wraps PURGE instead of an empty rectangle across the right side;
- mouse hit still includes arrow + wordmark and is easy to acquire;
- Tab/Shift-Tab navigation still reaches mode, difficulty, Story, Archives, program swap, footer actions;
- 1280×720 and 1920×1080 menu captures retain the current hierarchy.

---

## 6. Centralize Story runtime localization instead of duplicating key maps — MUST

**Files:**
- Modify: `src/story/story_data.gd`
- Modify: `src/ui/story_panel.gd`
- Modify: `src/arena/intro_kit.gd`
- Modify: `src/arena/arena.gd`
- Modify: `src/ui/story_intro_panel.gd`
- Modify: `src/arena/stage_kit.gd`
- Modify: `assets/i18n/strings.csv`
- Regenerate: `assets/i18n/strings.en.translation`, `assets/i18n/strings.pt_BR.translation`
- Test: `src/autoload/harness/sections_visual.gd`, Story scene/intro tests

**Problem:** the Story selector already maps titles/intros to translation keys, while runtime intro, klog, victory, hint, and watermark still consume raw English. Duplicating a second mapping in Arena would make the two paths drift again.

### 6A. Give `StoryData` one localization API

Add shared helpers in `StoryData`, e.g.:

```text
localized_title(index_or_stage)
localized_intro(index_or_stage)
localized_klog(index_or_stage, line_index)
localized_act_label(index_or_stage)
```

The helper may derive keys from the stable stage id. It must use `TranslationServer.translate()` and fall back to the existing raw data when a key is absent. Keep paths, enemy ids, boss ids, mechanics, wave data and themes untouched.

Refactor `story_panel.gd` to consume the same helpers rather than maintaining its own independent title/intro map.

### 6B. Add the missing Story keys to `strings.csv`

Keep the existing 11 title/intro pairs. Add:

- UNIX/Windows/TempleOS act/footer labels used by the runtime intro;
- three klog lines for each of the 11 stages (33 localized lines);
- Story runtime chrome needed for `WAVE`, `FINAL WAVE`, `WAVE CLEAR`, `KLOG`, fallback `wave complete`, and boss inbound where shown to the player;
- Story intro dismiss hint (`PRESS ANY KEY` / PT-BR equivalent);
- Windows activation watermark;
- Temple rainbow-unlock victory line;
- any Story-victory metadata label that is still English-only.

Do not translate stable paths (`/boot`, `C:\\98`, `TempleOS::GOD`) or boss/proper names unless the existing translation design already does so.

### 6C. Replace the raw runtime uses

Use the shared StoryData localization helpers in:

- `intro_kit.gd::_show_story_intro()` for act label/title/intro;
- `arena.gd::_on_story_wave_started()` for player-facing Story wave chrome;
- `arena.gd::_on_story_wave_cleared()` for localized klog;
- `arena.gd::_show_story_victory()` for localized title/meta and rainbow-unlock line;
- `story_intro_panel.gd` for the dismiss hint;
- `stage_kit.gd::_build_windows_visuals()` for the watermark.

Game/event logs that are intentionally machine-like may remain technical if they are not normal UI copy, but anything rendered as banner/panel copy in the release gate must follow the selected locale.

**Acceptance:** PT-BR runtime cannot show the raw English Story intro/klog/victory/watermark strings; EN mirrors the same flow without missing-key fallback.

---

## 7. Add an explicit EN/PT-BR language selector and immediate menu refresh — MUST

**Files:**
- Modify: `src/ui/menu_settings_kit.gd`
- Modify: `src/ui/menu.gd`
- Modify as needed: `src/ui/menu_shell.gd`
- Modify: `assets/i18n/strings.csv` + compiled translations
- Test: i18n/settings harness

### 7A. Place language under Accessibility

Do not add a seventh navigation category. Add a normal cycle button in the existing ACCESSIBILITY section:

```text
LANGUAGE // ENGLISH
LANGUAGE // PORTUGUÊS (BRASIL)
```

Use `Game.LANGUAGES`, `Game.language()`, and `Game.set_language()` as the single persistence owner. Do not write another locale value directly to ConfigFile from the UI.

### 7B. Refresh already-built menu UI immediately

Changing `TranslationServer` alone does not rewrite Labels created with `tr()` at construction time. Implement one explicit Menu-owned refresh path.

Recommended low-risk approach:

1. remember the active Settings section;
2. call `Game.set_language(new_code)`;
3. rebuild the current MenuShell and Settings overlay from their normal constructors;
4. invalidate/free hidden lazy Program/Story/Bestiary/Achievements panels so the next open constructs them in the new locale;
5. reopen Settings on the same section and restore focus to the language control or Accessibility navigation.

Do not reload the whole application process and do not require the player to restart the game. A current-scene reload is acceptable only if the in-place rebuild proves materially riskier, and in that fallback case the test must verify the persisted locale and deterministic return to the menu.

### 7C. Focus behavior

While touching Settings, pass an explicit preferred visible control to `ScreenKit.open_focus()` so fresh keyboard entry has an obvious focus target. Prefer the active section/navigation control rather than an HSlider with no visible focus treatment.

Do not stretch the Settings form or fill the intentional empty area.

**Acceptance:** language choice persists across a fresh menu instance and the visible menu/settings copy changes immediately in the same session.

---

## 8. Close remaining clearly player-facing hardcodes — MUST within bounded scope

**Files:**
- Modify: `src/ui/patch_card.gd`
- Modify: `src/ui/terminal_panel.gd`
- Modify: `src/ui/menu_settings_kit.gd`
- Modify: `src/arena/arena.gd`
- Modify: `assets/i18n/strings.csv` + compiled translations
- Test: i18n/editorial/settings/terminal harness sections

This is not a mandate to translate every source literal. It is a bounded release-surface sweep.

### Patch card

Translate UI chrome currently emitted as literals:

- `STANDARD`, `RARE`, `LEGENDARY`;
- `LEVEL %d → %d`;
- `NEW PATCH`.

Patch proper names may remain their existing names unless a translation already exists; descriptions already use translation keys.

### Terminal

Translate visible workstation chrome/help:

- title/hint/status prose;
- `PROCESS LINK`, `COMMAND INDEX`, command descriptions, `SYSTEM STATUS` labels;
- Close/Run/placeholder/history/autocomplete UI hints;
- TTY ready/help prose where it is user guidance.

Keep actual commands (`help`, `top`, `dmesg`, `man`, `sudo heal`, `rm -rf /`), shell prompt, TTY identifiers, and intentionally technical identifiers unchanged.

### Settings

Translate the literal `SAVE TRANSFER // PHONE ↔ PC` heading. Android is again a supported target, but keep the wording product-oriented rather than device-pair-specific; `SAVE TRANSFER // PORTABLE` / its PT-BR equivalent remains preferable because the same transfer works across Linux, Windows, and Android.

Translate keybind status `BOUND TO` through a format key.

### Arena/run summary

Replace visible `BEST` / `SEED` meta literals and any other release-gated summary chrome still hardcoded in English. Preserve numeric seed value and program/build identifiers.

**Bounded-scope exit test:** in a PT-BR visual pass of the release surfaces, no obvious English UI sentence/chrome remains except intentional commands, identifiers, proper names, or technical flavor explicitly documented as invariant.

---

## 9. SHOULD: make `holy` a real music variant using current stems

**Files:**
- Modify: `src/autoload/sfx.gd`
- Keep call site: `src/arena/stage_kit.gd::_build_temple_visuals()`
- Test: `src/autoload/harness/sections_visual.gd::_temple_test`

Run this only after every MUST above passes its narrow regression.

**Step 1 — Accept `holy` explicitly.**

Add `holy` to the `set_music_variant()` accepted set instead of silently falling back to `normal`.

**Step 2 — Give it a subtle existing-stem treatment.**

Use only current stream players/stems and existing pitch/volume/filter controls. The effect should distinguish TempleOS without clipping or materially changing composition. No new audio asset.

**Step 3 — Test the semantic contract.**

Harness should prove `Sfx.music_variant == "holy"` after TempleOS setup and that leaving the act/reset path can return to the expected variant.

**Skip rule:** if this causes instability after the MUST fixes, revert only this SHOULD change and ship with the dead `holy` request removed/documented instead. It must not delay an otherwise-green cross-platform release.

---

## 9A. Close the Android release blockers as a dedicated mobile product path — MUST

**Files:**
- Modify: `src/ui/touch_controls.gd`
- Modify: `src/ui/tactical_ui.gd` / `src/ui/hud.gd` only where touch-safe shared geometry belongs
- Modify: `src/ui/menu_shell.gd`
- Modify: `src/ui/menu_settings_kit.gd`
- Modify: `src/ui/story_panel.gd`
- Modify: `src/ui/bestiary_panel.gd`
- Modify: `src/ui/pause_panel.gd`
- Modify: `src/ui/run_summary_panel.gd`
- Modify: patch-offer composition in `src/arena/arena.gd` and/or the owning patch UI helper
- Modify only if exposed on touch: `src/ui/terminal_panel.gd`
- Test: `src/autoload/harness/sections_modes.gd::_touch_test`
- Test: `src/autoload/harness/sections_scene.gd::_touch_hud_layout_test`
- Test/capture: `tools/virtual-session/kp-virtual.sh`

The mobile branch shares data, gameplay rules, translation keys, and callbacks with desktop. It does **not** inherit the desktop composition and then scale it down.

### 9A.1 — Fix simultaneous touch routing first

Write the failing regression before the input fix:

1. hold the movement finger;
2. hold the aim/fire finger;
3. press DASH with a third touch;
4. assert DASH fires while both existing move/aim ownership ids and states remain valid;
5. repeat for BOOST/Overclock;
6. assert a disabled BOOST button consumes its own touch and does not become `_aim_id`.

Then change `TouchControls` input priority so momentary action hit-tests occur before aim-channel allocation. Preserve the current movement and aim gesture semantics.

### 9A.2 — Make sensor-landscape the explicit 3.0 Android contract

Keep the existing landscape sensor orientation. Do not add portrait gameplay in this release. A portrait/windowed debug viewport may still exist, but it is not a supported gameplay composition.

### 9A.3 — Integrate real display safe areas

Use the display safe area on Android rather than assuming the full viewport is touch-safe. Normalize it into the viewport/design coordinate system once at the owning layout layer, then use those insets for:

- movement zone;
- aim/action zone;
- pause button;
- HUD edge modules;
- modal/page margins.

The desktop path must remain unchanged when no mobile safe-area inset applies.

### 9A.4 — Enforce a touch-target contract

For the supported Android landscape layouts:

- primary touch actions: at least ~56 px effective hit target;
- secondary touch actions: at least ~44–48 px;
- meaningful gap between adjacent actions: at least ~8 px;
- Back/Confirm/Resume must be reachable without precise taps;
- visual glyph size may remain smaller than the hit target.

Add geometry assertions where a pure rect contract exists; do not replace physical capture/on-device verification with geometry tests alone.

### 9A.5 — Recompose dense screens for touch instead of compressing desktop

Required release behavior:

- **Menu:** compact landscape shell with clear PURGE, mode/difficulty, Story/Archives/Program/Settings/Awards routes; no tiny footer keyboard tokens.
- **Settings:** touch-sized category navigation; hide PC-only video/keybinding controls when they do not apply; language selector remains available.
- **Program:** current scroll/card structure may be reused if target size/readability gates pass.
- **Story:** single-pane or master/detail progression suited to landscape phone width; stage selection and mount action both thumb-usable.
- **Bestiary:** single-pane/list-detail mobile composition; do not squeeze desktop split view until text becomes microcopy.
- **Achievements:** current list may be reused if physical readability/target gates pass.
- **Patch offer:** dominant/touch-native selection surface; do not retain three permanently squeezed desktop cards if they fail the landscape gate. Paging or one-dominant-card selection is acceptable if it preserves the same three choices and game rules.
- **Pause:** full-screen touch sheet with large Resume/Restart/Abandon and touch-safe volume controls; remove keyboard hints.
- **Run Summary:** dedicated compact landscape layout with large primary/secondary actions and readable stats.
- **Terminal:** if intentionally exposed on Android, give it a touch/soft-keyboard-safe compact layout and remove keyboard-only hints. If it is intentionally desktop-only, hide the entry point on touch rather than exposing a broken workstation.

Do not duplicate gameplay content or maintain a second set of strings/data for mobile.

### 9A.6 — Remove keyboard/mouse hint leakage in touch mode

Audit all supported Android release surfaces. Tokens such as `[ESC]`, `[R]`, `[T]`, `[Q]`, `[SHIFT]`, `[E]`, `WASD`, `ENTER`, mouse/cursor instructions, and desktop-only navigation help must either disappear or be replaced with touch-appropriate wording when touch layout is active.

### 9A.7 — Forced-touch visual gate before device handoff

Capture EN and PT-BR with `KP_FORCE_TOUCH=1` at minimum:

- 720×432;
- 960×540;
- 1280×720 landscape.

Required surfaces: menu, Settings, Program, Story, Bestiary, Achievements, gameplay/HUD, patch, pause, Run Summary, and terminal only if it remains exposed on touch.

Reject clipping, microtype, desktop keyboard hints, action overlap, unsafe edge placement, or controls hidden under the gameplay touch zones.

### 9A.8 — Real Android tester gate

After a fresh final APK is built, hand the tester one explicit smoke checklist:

- install/upgrade launch on arm64 Android;
- sensor-landscape orientation and rotation recovery;
- notch/cutout/safe-area behavior;
- move + aim/fire + DASH and BOOST simultaneously with three fingers;
- pause/resume/background/foreground lifecycle;
- menu mode/difficulty/program flow;
- EN/PT-BR language switch and persistence after app restart;
- Story select → intro → combat → victory;
- patch selection;
- save persistence and portable save transfer;
- audio/haptics controls;
- no keyboard/mouse hint leakage on normal touch surfaces;
- sustained combat/performance/thermal sanity on the tester device;
- clean app exit/reopen with progress intact.

Android is not release-ready until this tester gate returns a concrete pass report or all reported blockers are fixed and retested.

---

## 10. Run narrow verification after each subsystem, then the frozen-tree full suite

**Narrow checks:**

- GOD: Temple harness assertions including cadence + same-seed oracle roll.
- Reticle: modal lifecycle regression.
- PURGE: geometry/focus navigation regression.
- i18n: both locales, persistence, runtime Story samples, Settings selector.
- Terminal/patch/settings: respective editorial/overflow/focus checks.
- Android input: three-finger move+aim+DASH/BOOST regression and disabled-BOOST ownership check.
- Android layout: safe-area/target geometry checks plus forced-touch release-surface captures.
- `holy` if implemented: variant state/reset check.

Do not declare the work complete from narrow checks alone.

**Full source-tree gate:** run with isolated XDG paths so the real user save is untouched, e.g.:

```bash
rm -rf /tmp/kp3-final-test
mkdir -p /tmp/kp3-final-test/data /tmp/kp3-final-test/config
env XDG_DATA_HOME=/tmp/kp3-final-test/data \
    XDG_CONFIG_HOME=/tmp/kp3-final-test/config \
    timeout 120s godot --headless --path . -- --autotest \
    2>&1 | tee /tmp/kp3-final-test/autotest.log
```

Required result:

- exit 0;
- `AUTOTEST_ALL_PASS`;
- zero `AT_FAIL`;
- zero production `SCRIPT ERROR`/unexpected engine errors in the run;
- all new regression steps actually executed, not skipped due missing wiring.

If teardown/leak diagnostics still exist, classify them explicitly and make README wording truthful. Do not claim “zero engine errors” unless the final log actually proves it.

---

## 11. Physical desktop visual gate — EN and PT-BR, 720p and 1080p

**Tool:** `tools/virtual-session/kp-virtual.sh`

Use `KP_CLEAN_SAVE=1` and isolated capture runs. Capture both locales at physical:

- 1280×720;
- 1920×1080.

Required surfaces:

- Menu;
- Settings, including language control and visible focus;
- Program selector;
- Story selector;
- Bestiary;
- Achievements;
- gameplay/HUD at a dense mid-run wave;
- Pause;
- Terminal;
- Patch offer;
- Run Summary;
- Story runtime intro;
- Story runtime wave/klog banner;
- Story victory.

Use the existing `capture` mode/environment switches rather than interacting with the physical desktop. Store final evidence under a new cache directory such as `/home/mafu/.cache/kp3-final-gate/`; do not replace `media/menu.png` or `media/gameplay.png` until the release candidate is accepted.

**Visual acceptance:**

- no clipping/overflow or illegible type;
- no giant empty PURGE focus rectangle;
- focus is visible and coherent on keyboard-driven surfaces;
- custom reticle never appears above a modal;
- PT-BR has no obvious English player-facing chrome on the bounded release surfaces;
- EN is not accidentally showing PT text or missing keys;
- 1080p retains the current intentional negative space/hierarchy rather than being “filled” by enlarged UI;
- no new HUD/playfield occlusion introduced by localization.

Do not change the broad desktop composition based only on personal preference after this gate; only fix concrete gate failures.

### Android forced-touch visual acceptance

In addition to the desktop matrix above, the 720×432 / 960×540 / 1280×720 forced-touch matrix must show:

- dedicated landscape composition rather than compressed desktop split layouts;
- readable body type and labels without relying on geometry-only “fits” assertions;
- touch actions clear of safe-area/cutout insets;
- no overlap between patch/HUD content and DASH/BOOST/aim zones;
- no keyboard/mouse hint leakage;
- Back/Confirm/Resume and destructive actions visually distinct and thumb-usable;
- PT-BR and EN both fit without clipping.

---

## 12. Align release-facing docs with the platform verdict

**Files:**
- Modify: `README.md`
- Modify: `KERNEL-PANIC-ROADMAP.md` only where it currently implies the deferred items are 3.0 blockers
- Modify as needed: `packaging/linux/README.md`

### README release promise

- Keep Linux, Windows, and Android as the supported 3.0 platforms only after all three artifact/tester gates are green.
- Keep Android install instructions, but make the architecture requirement (`arm64-v8a`) and tested release status explicit.
- Keep the historical “made on a phone” story; it remains historical context rather than evidence for current compatibility.
- Make the autotest wording match the final log. Prefer concrete `AUTOTEST_ALL_PASS / 0 AT_FAIL` language over an unproven “zero engine errors” claim.
- Do not advertise macOS Story or Photo Mode as completed 3.0 features.

### Roadmap scope

Mark macOS act, Photo Mode, and larger mode/content additions as post-3.0/deferred. Android dedicated UX is part of 3.0 closure and must not be left described as future work once the release candidate is frozen.

---

## 13. Build fresh Linux, Windows, and Android artifacts only after source is frozen

No production source, translation, or release-doc change is allowed after these builds without invalidating all three artifacts and forcing a rebuild.

### Linux x86_64

```bash
rm -f build/linux-x86_64/kernel-panic
godot --headless --path . --export-release "Linux x86_64" build/linux-x86_64/kernel-panic
```

Verify:

- file exists, executable, non-empty;
- `file` identifies the expected x86_64 Linux binary;
- embedded project data is present per preset;
- clean isolated launch reaches menu;
- menu → run works;
- language change persists across restart;
- Story opens and starts;
- patch, pause, and terminal flows render with no reticle leak;
- final artifact can execute the release-safe harness/gate expected by the project.

### Windows x86_64

```bash
rm -f build/windows-x86_64/kernel-panic.exe
godot --headless --path . --export-release "Windows x86_64" build/windows-x86_64/kernel-panic.exe
```

Verify the file/architecture first, then perform a meaningful runtime smoke with the available Windows tester. Minimum smoke mirrors Linux: clean launch, menu, run, language persistence, Story, patch, pause/terminal, clean exit. Record tester environment/build hash and concrete pass/fail results.

### Android

Build the APK only after the same final source freeze used by Linux and Windows:

```bash
rm -f build/android/KERNEL-PANIC-v3.0.0-release.apk
mkdir -p build/android
godot --headless --path . --export-release "Android" build/android/KERNEL-PANIC-v3.0.0-release.apk
```

If the active Godot preset/toolchain requires a different output path, use the preset-compatible path but keep one canonical final APK under `build/android/` for hashing and tester handoff.

Verify before handoff:

- APK exists, non-empty, and is a valid Android package;
- packaged native ABI is arm64-v8a as intended;
- application version reports 3.0.0;
- no unexpected network permission is introduced;
- final APK SHA-256 is recorded.

Then perform the real-device tester checklist from 9A.8. Do not call Android verified from emulator/forced-touch captures alone.

---

## 14. Reconcile Linux packaging/AUR against the final artifact

**Files:**
- Modify: `packaging/aur/kernel-panic-bin/PKGBUILD`
- Regenerate: `packaging/aur/kernel-panic-bin/.SRCINFO`
- Verify: `packaging/aur/test-packages.sh`

**Step 1 — Hash the final Linux binary.**

Compute SHA-256 only after the last rebuild. Replace `sha256sums_x86_64` with the hash of the actual 3.0.0 Linux release asset that will be uploaded.

**Step 2 — Regenerate `.SRCINFO`.**

From `packaging/aur/kernel-panic-bin`:

```bash
makepkg --printsrcinfo > .SRCINFO
```

Do not hand-edit `.SRCINFO` into disagreement with the PKGBUILD.

**Step 3 — Run package checks.**

```bash
packaging/aur/test-packages.sh all
```

Expected final marker: `AUR_PACKAGE_TESTS_PASS`.

If the release asset URL/hash cannot exist yet because publication is intentionally deferred, leave a clearly identified finalization checkpoint rather than inventing a hash. Publication remains outside this plan.

---

## 15. Final immutable release-candidate audit

After automated tests, visual gates, artifact smokes, docs and package metadata are complete:

1. capture final `git status --short --branch` and `git diff --stat`;
2. verify no source/translation file changed after the final artifact timestamps;
3. record SHA-256 of Linux, Windows, and Android artifacts;
4. rerun only non-mutating metadata/package consistency checks if needed;
5. confirm supported-platform wording exactly matches the artifacts that passed smoke;
6. confirm every MUST below is closed.

Do not tag/publish automatically. Present this frozen candidate to the user for the final release decision.

---

## Definition of “3.0 ready”

3.0.0 is ready only when all of the following are true:

- [x] GOD cadence escalates monotonically and literal oracle RNG behavior is preserved.
- [x] Custom reticle is absent on patch/pause/terminal/summary and returns correctly on gameplay resume.
- [x] PURGE focus ring is bounded and keyboard navigation remains complete.
- [x] EN/PT-BR Settings selector works, persists, and refreshes visible UI.
- [x] Runtime Story intro/title/act/klog/wave/victory/watermark/hint follow the selected locale.
- [x] Bounded player-facing PC localization sweep is green; intentional commands/identifiers are the only approved untranslated literals.
- [x] Full isolated source harness is green with `AUTOTEST_ALL_PASS`, zero `AT_FAIL`, and no unexplained production script/engine errors.
- [x] EN and PT-BR visual matrices pass at physical 1280×720 and 1920×1080.
- [x] Linux artifact is freshly built from the final source tree and passes smoke.
- [ ] Windows artifact is freshly built from the same tree and passes the Windows tester smoke.
- [x] Android forced-touch input/layout gates are green, including three-finger move+aim+DASH/BOOST and safe-area handling.
- [ ] Android APK is freshly built from the same tree and passes the real-device Android tester checklist.
- [x] README/roadmap promise only the platforms/features actually validated.
- [ ] Final AUR PKGBUILD/.SRCINFO/hash correspond to the final Linux binary and package checks pass.
- [x] No source/translation change occurred after final builds.
- [x] macOS Story, Photo Mode, and other deferred expansion remain explicitly outside this ship rather than being half-implemented.

SHOULD items may remain open without blocking the release if every MUST/gate above is green and the omission is documented truthfully.

---

## Android tester handoff — required part of 3.0 release closure

Android is a first-class 3.0 target. Treat it as a separate product composition layer that shares gameplay/data/callbacks but does not scale the desktop shell down.

Required Android blockers/gates:

1. **Fix simultaneous touch routing** in `src/ui/touch_controls.gd`: pressed touch priority must be pause → dash → boost → ownership allocation. DASH/BOOST must work while move and aim fingers are already held. Disabled BOOST must consume its own button touch without stealing `_aim_id`. Add a 3-finger regression to `sections_modes.gd::_touch_test` preserving both existing move/aim ids.
2. **Landscape-first contract:** keep sensor-landscape; do not claim portrait gameplay support without a dedicated portrait composition.
3. **Real safe area:** integrate `DisplayServer.get_display_safe_area()` rather than assuming the full viewport is touch-safe.
4. **Touch targets:** primary controls at least ~56 px, secondary at least ~44–48 px with real spacing.
5. **Mobile-specific compositions:** compact menu; 56 px Settings category navigation; single-pane Story/Bestiary master-detail; full/touch-native Pause; dominant/paged patch choice; dedicated Run Summary; keyboard/mouse hints removed globally in touch mode. Program/Achievements may reuse their scroll structures if physical captures prove readability.
6. **On-device QA:** real arm64 Android tester pass for movement+aim+dash/boost, safe areas/notches, orientation, resume/background behavior, install/update/save persistence, PT/EN, and performance before APK publication.

Do not back-port these changes into PC layout unless a separate desktop regression independently justifies it. Android tester failures are blockers for the APK, not justification for broad desktop redesign.

---

## Muse Spark 1.3 execution handoff

Use the following as the implementation prompt after the user authorizes execution:

> You are implementing the final KERNEL PANIC 3.0 cross-platform release closure in `/home/mafu/kernel-panic`. Read `docs/superpowers/plans/2026-09-12-kernel-panic-3.0-release-closure.md` completely before editing. The current dirty worktree contains valid work from other agents: never reset, clean, stash, revert, or rewrite unrelated changes. Execute the plan in order, tests-first for each remaining blocker, and preserve the already-landed 3.0 fixes. Prime is the integration owner.
>
> Release scope is fixed: Linux x86_64 + Windows x86_64 + Android arm64. The user has real testers for all three. macOS Story and Photo Mode are out of this release. Do not redesign desktop 1080p or expand content. Android must use a dedicated landscape-first touch composition rather than a scaled desktop shell.
>
> MUST work: GOD cadence; modal reticle; PURGE focus geometry; EN/PT-BR player-facing i18n including Settings selector and complete runtime Story; Android simultaneous-touch routing; mobile safe-area/touch-target contracts and dedicated landscape compositions; truthful Linux/Windows/Android release docs; full isolated tests; physical desktop EN/PT visual gates at 1280×720 and 1920×1080; forced-touch EN/PT gates at 720×432, 960×540 and 1280×720; fresh Linux/Windows/Android builds; Windows and Android tester smokes; final AUR/package reconciliation. `holy` is a SHOULD only after all MUSTs are green, implemented with existing stems only.
>
> For every task: inspect the live code first because the dirty tree can advance; add/adjust the narrow regression; run it; make the smallest owning-layer fix; rerun the narrow gate. Do not trust old audit line numbers if the live tree has moved. Never declare success from a stale report. At the end run the full isolated suite, fresh desktop/mobile visual matrices, rebuild all three artifacts after the last source change, smoke Linux locally, hand exact final hashes/builds to the Windows/Android testers, reconcile their reports, and freeze the candidate. Do not publish/tag/upload anything.
>
> Tester availability is confirmed for Windows and Android. If either tester reports a blocker, fix it and rebuild/retest from the same release-candidate process; do not waive the failure or silently drop the platform without explicit user direction.

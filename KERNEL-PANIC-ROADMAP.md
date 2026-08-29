# KERNEL PANIC — Roadmap (multi-session source of truth)

## Context prompt (paste for any agent)

```text
You are OX Alpha continuing KERNEL PANIC development. Read this roadmap
fully before proposing work. Local project:
/storage/emulated/0/OX-Trial-2 (legacy local name; never mention
"OX Trial 2" publicly). Repo: github.com/mafuzyk/kernel-panic, branch main.
Godot 4.7.2, GDScript, mobile-first, neon procedural identity.
Companion docs in this same home directory:
KERNEL-PANIC-HANDOFF.md (v2.3 general plan + bug list) and
KERNEL-PANIC-V23-HANDOFF.md (balance/perf execution, currently with
another agent). This file is the long-term roadmap only.
Hard rules: One-HP never gets heal sources; lock-on is an accessibility
feature and is allowed in every mode (Weekly ban removed 2026-08-28);
binaries only via GitHub Releases; never commit
APKs/keystores/.godot/build/private paths; TDD with the Godot autotest
(godot --headless --path <project> -- --autotest) before claiming success.
```

## Current state

- v2.3 balance/perf pass (MoteField MultiMesh, Vampic 10s CD, RECOVER,
  SCRAP DIET, heal telemetry) is DONE in code. v2.3.0 not yet released
  publicly; current public release is still v2.2.0.
- 2026-08-27/28 review + identity/quality packages (Codex, author-approved)
  landed on `main` after `93b9f34`: boot sequence, man-page bestiary, stack
  traces, desktop reticle, desktop key remapping, patch tooltips, abandon
  confirmation (Q,Q), bestiary first-sight unlocks, onboarding hints,
  color-assist + responsive UI, enemy AI rework (cover/flanking teleports,
  qualitative elites), music rework, program selection panel. Full autotest
  green (`AUTOTEST_ALL_PASS`).
- DECISION UPDATES (2026-08-28, author-approved — supersede older handoffs):
  - Lock-on ban in Weekly is REMOVED; lock-on is selectable in every mode.
  - Difficulty is no longer frozen: `max_alive` ceiling 16→10 and the bounded
    `attack_cadence_factor` (floor 0.78) are intentional. `WAVE_SCALE_CAP`
    and `elite_chance` remain untouched pending playtest.
  - `build/` is a local export directory; never stage it.
- A refactor session already added RECURSOR and FIREWALL enemies (present in
  bestiary). Inspect actual file state before any work.
- Full review findings + fix backlog live in
  `docs/superpowers/specs/2026-08-27-review-findings.md` (F1/F2/F3 fixed;
  F4 OOM steal-mismatch and F5 dash-HUD fraction still open).

## Roadmap

### v2.3.0 — Balance/Perf (in flight, another agent)
See KERNEL-PANIC-V23-HANDOFF.md. Do not duplicate.

### v2.3.5 — Charm update (~1 session)
All approved. No controller support (explicitly rejected for now).

- **In-game terminal in pause menu**:
  commands `help`, `top` (run stats), `man <enemy>` (opens bestiary entry),
  `dmesg` (run event log), `sudo heal` (once per run; "permission denied"
  after use), `rm -rf /` (kills all enemies AND ends the run with a real
  kernel panic screen). Terminal aesthetic, monospace, blinking cursor.
- **Achievements as dmesg toasts**: reuse klog style, corner toast like
  `[ 42.000000] achievement: FIRST_BLOOD enabled`. No new UI system.
- **Speedrun kit**: HUD timer (toggle in settings), visible seed, instant
  restart (hold R). Weekly mode is the natural seeded category.
- **Save export/import**: base64 copy-paste string in settings; covers
  progress, bests, bestiary, unlocks. Solves phone→PC migration.
- **Core dump on death**: last-5s recap on game over (killer, hit count,
  build snapshot). Format: `SEGFAULT AT player.hp=0 // state dumped`.
- **Permanent grid corruption**: as waves advance, corruption patches become
  permanent in the background grid via bg_grid.gdshader uniforms. Visual
  pressure, cheap.

### v2.4.0 — Story mode skeleton + Act 1 (UNIX)
- Story mode is a separate menu entry (STORY), not part of the
  classic/weekly/onehp cycle. Chain unlocks: clearing stage N opens N+1.
- Stage = data-driven script: fixed enemy waves (spawner `_queue` scripted,
  not budget-procedural), optional boss, lore intro card, own difficulty
  curve (independent of endless knobs).
- Lore delivery (approved option b): intro card per stage + one klog line
  between waves. Terminal style, no cutscenes.
- **Theme system** ships here: per-stage dict feeding bg_grid uniforms
  (base_col, grid_col, accent), wall tint, dust color; optional new
  `grid_style` uniform. Act 1 theme = current neon look (zero risk).
- Act 1 stages (6): `/boot` (drones, soft tutorial), `/var/log` (spewers +
  drones), `/net` (lancers), `/mem` (oom_killer + splitter),
  `/quarantine` (trojans + corruption), `/kernel` (boss + mix).
- Victory screen per stage; save `cleared` + best per stage.
- Cross-rewards (approved): clearing `/mem` unlocks ROOTLET program.
- DEPENDENCY: playable programs (DAEMON/ROOTLET) must exist before this
  release. Verify whether the refactor session implemented them; if not,
  implement programs first (spec in KERNEL-PANIC-HANDOFF.md section 4).

### v2.5.0 — Act Windows (3 stages, 3 eras)
Comedic arc: the newer the Windows, the prettier and more bloated.

| Stage | Visual | Audio | New enemies |
|---|---|---|---|
| `C:\98` | heavy CRT: scanlines + noise + curvature + aberration; gray/teal Win95 | generated square-wave MIDI-style | 1 twist max on existing cast |
| `C:\XP` | soft CRT, Luna blue/green, brighter | generated "polished but dated" variant | UPDATE_LOOP (dies, "reinstalling", returns) |
| `Win11` | ironically clean: glassmorphism, light mode, rounded corners | calm corporate lo-fi | BLOATWARE + POPUPS |

- **CRT shader**: one parametrized shader (`curvature`, `noise`, `scanline`),
  same screen_tex pattern as overlay.gdshader. Win11 disables it. Optional
  low static SFX layer under music.
- **BLOATWARE**: fat bulwark variant; telegraph = loading spinner; drops
  static POPUP orbs that block shots (destructible); on death spawns
  mini-drones ("47 background processes terminated").
- **Music**: new functions in tools/gen_audio.gd (procedural, no external
  assets, keeps APK small). One variant per era.
- Klog jokes: "your PC ran into a problem", "update scheduled during boss
  fight", blinking "Activate Windows — Go to Settings" corner watermark.
- Cross-reward: clearing the Act unlocks DAEMON program.

### v2.6.0 — TempleOS (bonus act, 2 stages)
- Arena shrinks to 640x640. Rainbow cycling palette, angelic glow.
- CRT shader in "holy" mode (golden scanline, coral static).
- Boss "GOD": oracle boss whose attacks are literal RNG.
- 100% act clear → rainbow grid tint cosmetic for endless modes.

### v2.7.0+ — macOS act + i18n + photo mode
- macOS: BEACHBALL (spewer that freezes area), GENIUS (arrogant lancer),
  light-mode inversion, literal kernel panic boss.
- **PT-BR + EN localization**: texts are hardcoded across ~8 files today.
  Do the i18n refactor BEFORE or WITH the story mode so story text is
  translated once. High value (author + partner + BR players), real effort.
- Photo mode: pause + free camera + hide UI, for shareable screenshots.

## Approved design decisions (do not relitigate)

- Windows Act visual direction: Win95/98 gray-teal retro (not XP bliss).
- Story lore depth: intro cards + inter-wave klog lines only.
- SCRAP DIET overflow states: `oc_ready` AND `overclock_active` both count.
- Vampic internal cooldown: 10 seconds.
- Story difficulty: fixed per-stage curve, independent of endless knobs.
- No gamepad/controller support in the current roadmap (user decision).
- Story mode is never the main mode; endless remains primary.

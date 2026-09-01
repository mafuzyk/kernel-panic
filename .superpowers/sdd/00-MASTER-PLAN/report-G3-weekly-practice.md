# G3 — Weekly mutator and Practice wave selection

## Status

Implemented on `codex/plan-execution` as the G3 gameplay/replayability slice.
The focused contract is green in headless and Xvfb. The default legacy menu
remains the product route; G3 changes that route's existing mode selector but
does not opt a new UI renderer into production.

## Requirement translated into rules

The plan requires one deterministic weekly mutator, a preview before launch,
an independent Weekly record namespace, and a Practice selector whose ceiling
is the highest Endless wave reached. Practice must not write records or satisfy
achievement conditions. The user-approved G2 overflow behavior and existing
weekly save namespace were treated as upstream contracts.

The implementation uses two conservative rotation entries so the weekly seed
has meaningful variation without introducing a new damage or integrity rule:

| ID | Tag | Player-facing effect | Modifier |
| --- | --- | --- | --- |
| `swift_daemons` | `movement` | Daemons move +20% | enemy movement multiplier `1.2` |
| `rush_hour` | `spawn` | Wave budget +20% | wave budget multiplier `1.2` |

`Game.weekly_seed()` derives the same seed used for the Weekly run from the
current week number. `WeeklyMutatorCatalog.for_seed()` selects exactly one
definition using a bounded modulo index. The selected ID travels through
`RunContext`, appears in the menu preview, and is written to the run event log.

The Practice unlock threshold is deliberately literal: any Classic Endless
run reaches wave 1, so the first Classic run unlocks Practice wave 1. The
highest `Game.wave` observed when a Classic run ends becomes the ceiling. This
does not infer a score threshold or require a cleared boss. The selected
Practice wave is clamped to `[1, best_endless_wave]` and starts the Arena at
that wave. Practice is not a deterministic weekly variant and carries no
mutator.

## Before and after

Before this slice, `RunContext` knew that `practice` was reserved and
non-recording, but Game had no weekly mutator object, no persistent Endless
wave ceiling, and no way to start the Arena above wave 1. The mode selector
cycled only Classic, Weekly and unlocked One-HP. Weekly displayed only its
record information; it did not explain a rule change.

After the slice:

- `WeeklyMutatorCatalog` owns the small reviewable content table and provides
  deep-copied definitions by seed or ID.
- `Game` exposes the weekly seed/preview and Practice unlock/selection APIs.
- `RunContext.from_game()` carries the one active weekly ID and keeps Practice
  empty and non-recording.
- Weekly movement and spawn effects are applied only through named helpers in
  `Balance`; regular enemies, RootBoss variants, GodBoss and mini fragments
  receive the movement modifier through their real configure paths.
- Practice starts on its selected wave, never updates Classic/Weekly/Story
  scores, does not write lifetime records, and cannot unlock an achievement
  through `Game.unlock_achievement()`.
- Classic stores `run.best_endless_wave`; save export/import accepts the new
  field with a zero default, preserving older transfer strings.
- The existing menu previews the current Weekly ID/effect. On compact
  layouts, the copy is shortened rather than allowed to overflow. Once
  unlocked, Practice exposes a touchable `PRACTICE WAVE: NN / NN` control.
- The menu snapshot now reports the active preview and Practice state, and its
  settings shell snapshot includes the already-landed DISPLAY section.

## Files and ownership

- `src/gameplay/weekly_mutator_catalog.gd`: declarative mutator IDs, tags,
  labels and selection.
- `src/gameplay/run_context.gd`: mode-to-mutator projection.
- `src/autoload/game.gd`: weekly seed, persistence, Practice unlock/selection,
  run initialization, record boundaries and transfer compatibility.
- `src/autoload/balance.gd`: named weekly movement/budget modifier boundaries.
- `src/enemies/enemy_base.gd`, `src/enemies/root_boss.gd`,
  `src/enemies/god_boss.gd`: real enemy/boss movement application.
- `src/arena/arena.gd`: selected Practice wave is passed to the real Spawner.
- `src/ui/menu.gd`, `src/ui/menu_chrome_kit.gd`: mode cycle, preview copy,
  Practice wave control, compact copy and snapshots.
- `tools/g3_weekly_practice_probe.gd/.tscn`: focused red/green contract probe.
- `tools/validate_input_dispatch.sh`: accumulated headless and Xvfb coverage.

## Compatibility and impact

- Existing Classic, Story, Weekly and One-HP launch behavior is preserved.
- Weekly still uses the pre-existing `[weekly] id/best/last_id/last_best`
  namespace; no leaderboard data was mixed with Classic or Practice.
- Save transfer format remains version `1`; missing `best_endless_wave` values
  import as zero. This is additive, not a breaking change.
- `practice_wave` is a small `[game]` preference. Invalid values are clamped;
  a saved locked Practice mode falls back to Classic.
- Practice does not write run score, lifetime run/kills/best-chain/killer data
  or achievements. Bestiary/program unlock behavior was not broadened by this
  slice because the plan only explicitly excludes records and achievements;
  whether Practice should be a fully non-progressing sandbox remains a future
  product decision.
- `swift_daemons` changes movement speed, including bosses, while
  `rush_hour` changes the wave budget. The modifiers do not affect Story or
  Practice and do not alter player damage, HP, dash, overclock or rewards.
- The menu's long desktop Weekly annotation is compacted under 760 logical
  pixels. The report now checks desktop and compact copy; physical cutouts and
  device-specific font rasterization still need manual validation.

## Evidence

- Red probe: `/tmp/g3-red-probe.log`, exit `124` after the new probe reached
  the expected missing catalog/API state before implementation; no completion
  marker was accepted.
- Final headless focused probe: `/tmp/g3-green7.log`, exit `0`, 44
  `PROBE_PASS`, `PROBE_DONE fails=0`.
- Final Xvfb focused probe: `/tmp/g3-xvfb.log`, exit `0`, 44
  `PROBE_PASS`, `PROBE_DONE fails=0`. Xvfb used Mesa llvmpipe; this is not a
  physical Vega or Android performance result.
- Final full DevHarness: `/tmp/kernel-panic-g3-suite2.log`, exit `0`, 1427
  `AT_PASS`, zero `AT_FAIL`, `AUTOTEST_ALL_PASS`, no script/parse errors.
- `git diff --check` was clean before the documentation checkpoint.
- The probe directly tests deterministic selection, valid tags and IDs,
  movement/budget isolation, regular enemy and boss integration, Practice
  unlock/clamp/selection, menu preview/compact copy/overflow, Practice record
  exclusion and Classic ceiling persistence.

## First implementation issue and correction

The first full-suite run after adding the preview failed the existing boot
assertion because the new Weekly annotation replaced the required `LOCAL`
word. The controller did not weaken the old test. The preview was revised to
retain `LOCAL DETERMINISTIC` on desktop and use a deliberately shorter mobile
variant. A second full suite then passed. The first compact overflow check
also exposed that the old Story annotation was too long for the compact
height; Story received a compact copy as part of the same layout correction.

## Second-pass self-review

The code was reviewed for mode leakage, missing save defaults, invalid Practice
mode restoration, weekly ID determinism, Story/Practice modifier isolation,
boss configure overrides, split/mini boss speed, exact-once mutator selection,
Practice score/lifetime/achievement writes, transfer compatibility, compact
copy and the pre-existing Weekly lock-on contract. The focused and full tests
cover those paths.

Remaining uncertainty is product feel, not code-path correctness: two chosen
mutators and the literal `+20%` values are conservative implementation
assumptions, and the first-run Practice unlock may be too early or too late
for the desired onboarding. Human playtest should decide before a public
release. Existing teardown diagnostics remain open and are not attributed to
G3.

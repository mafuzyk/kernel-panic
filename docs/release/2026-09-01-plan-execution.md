# KERNEL PANIC — plan execution log (2026-09-01)

> This is a development/release-log draft, not a public release announcement.
> The vNext UI described here remains opt-in behind `KP_VNEXT_BOOT=1`,
> `KP_VNEXT_PATCH=1`, `KP_VNEXT_HUD=1`, `KP_VNEXT_U4=1` and
> `KP_VNEXT_SETTINGS=1` until
> the later migration, accessibility, localization, visual-review and export
> gates are complete.

## Scope of this log

This document records the user-visible and release-relevant work executed from
the master plan's stabilization phase through U6. Detailed technical evidence
and alternatives remain in the task reports:

- [A1 repository baseline](../../.superpowers/sdd/00-MASTER-PLAN/report-A1.md)
- [A2 ownership and kit boundaries](../../.superpowers/sdd/00-MASTER-PLAN/report-A2.md)
- [A3 snapshot contracts](../../.superpowers/sdd/00-MASTER-PLAN/report-A3.md)
- [A4 content catalog](../../.superpowers/sdd/00-MASTER-PLAN/report-A4.md)
- [A5 save compatibility](../../.superpowers/sdd/00-MASTER-PLAN/report-A5.md)
- [U1 vNext boot](../../.superpowers/sdd/00-MASTER-PLAN/report-U1.md)
- [U2 vNext program/story selection](../../.superpowers/sdd/00-MASTER-PLAN/report-U2.md)
- [U2b vNext patch/build decision](../../.superpowers/sdd/00-MASTER-PLAN/report-U2b.md)
- [U3 vNext combat HUD](../../.superpowers/sdd/00-MASTER-PLAN/report-U3.md)
- [U4 vNext state surfaces](../../.superpowers/sdd/00-MASTER-PLAN/report-U4.md)
- [U5 vNext settings/accessibility](../../.superpowers/sdd/00-MASTER-PLAN/report-U5.md)
- [U6 vNext shared state surface](../../.superpowers/sdd/00-MASTER-PLAN/report-U6.md)
- [E4 ZOMBIE_PROCESS](../../.superpowers/sdd/00-MASTER-PLAN/report-E4-zombie-process.md)
- [G1 explicit run context](../../.superpowers/sdd/00-MASTER-PLAN/report-G1-run-context.md)

The execution branch is `codex/plan-execution`; it is based on the reviewed
master-plan documentation and does not merge into `main` automatically.

### E1 code-drawn entity foundation

- Added a deterministic descriptor normalizer, shared extent/fit bounds,
  state-aware code-drawn renderer and compatibility adapters for one existing
  program (`kernel`) and one existing enemy (`DRONE`).
- Preserved the legacy `VNextEntityIllustration` surface and sprite registry
  default-off behavior; no gameplay, hitbox, balance or route was changed.
- Evidence: focused probe red before implementation and green after adversarial
  corrections with 136/0 passes in headless and Xvfb; full Dummy-audio autotest
  1414/0 with `AUTOTEST_ALL_PASS`.
- This is technical evidence only. No visual approval is claimed because no E1
  capture was inspected. Full cast, product-route wiring and sprite comparison
  remain E2–E5 work.

### E2 legacy enemy identity batch 1

- Added readable code-drawn identity/state treatment for the high-frequency
  DRONE, LANCER and SPEWER enemies while retaining their existing gameplay
  telegraphs and keeping sprite presentation disabled.
- Lancer AIM/LUNGE and Spewer wind-up now reach the shared presentation state
  channel; Drone tracking/elite/hit signals remain distinct from a generic
  recolor. No gameplay, balance, save, input or route behavior changed.
- Evidence: focused red probe before production (`exit=1`, 15 failures), then
  green headless and Xvfb focused probes (76/0 each) after the review
  corrections; import and full suite were green (`1414 AT_PASS`, `0 AT_FAIL`,
  `AUTOTEST_ALL_PASS`).
- The accumulated validator finished `VALIDATION OK`; its E2 case was 76/0
  and all runtime error gates were 0. The batch validates the actual legacy
  enemy draw path and preserves gameplay fields, but it does not claim human
  visual approval or a measured dense-wave performance budget.
- This is technical evidence only: no human visual approval, dense-wave
  performance measurement or physical-device support is claimed.

### G1 explicit run context and mode safety

- Added an explicit, serializable run-context foundation for Classic, Story,
  Weekly, One-HP and reserved Practice modes. Story stage identity, mutator
  IDs, record-writing capability and deterministic-seed capability now have a
  stable read-only-by-copy contract for future gameplay and UI consumers.
- Preserved `Game` as the authority and kept the existing save keys,
  transfer-format version, launch routes and current mode behavior intact.
- Closed the reserved Practice persistence hole: if a caller enters the
  reserved mode, run/lifetime records and achievements are not written. This
  does not claim that a selectable Practice mode is shipped; its launcher,
  wave selection and rules remain a later gameplay task.
- Evidence: focused G1 probe 29/0 with `PROBE_DONE fails=0`; existing save
  compatibility probe 39/0; full DevHarness 1414/0; aggregate validator green
  with no gated runtime errors. Teardown diagnostics remain separately
  reported and are not claimed as fixed.

### G3 Weekly and Practice foundations

- Added a visible, deterministic Weekly mutator rotation with two readable
  effects: daemons move 20% faster or wave budgets are 20% larger. Weekly
  records remain separate from Classic and Practice, and the selected rule is
  shown before launch.
- Added Practice wave selection unlocked by the highest Classic Endless wave
  reached. Practice starts at the selected wave and is excluded from run
  records, lifetime statistics and achievement conditions.
- Added compact-screen copy for Weekly/Story annotations and a touchable
  Practice wave selector to the existing responsive menu. Save transfer
  version 1 remains compatible with older payloads.
- Validation: dedicated G3 probe passed in headless and Xvfb; full DevHarness
  passed with 1427 checks and `AUTOTEST_ALL_PASS`. No public release claim is
  made for final balance feel, physical mobile support or teardown cleanliness.

## G3 technical notes

The two mutators are tagged `movement` and `spawn`; their effects are routed
through `Balance` rather than hidden in UI code. The selected movement rule
also covers RootBoss/GodBoss configure overrides. Practice's non-recording
boundary is enforced at the existing `Game.end_run()` and achievement paths,
not only in menu copy. The chosen first-run unlock threshold and +20% values
are implementation assumptions awaiting human playtest.

## Technical changelog

### Architecture and repository

- Recorded the repository/runtime/content/test/release boundaries, save path,
  export facts, autoload ownership, generated-file policy and open diagnostics.
- Added a versioned execution ledger with evidence, review history, residual
  risks and next-task gates.
- Preserved the legacy playable route while new surfaces are built behind an
  explicit development switch. This keeps rollback and attribution possible.
- No broad cleanup or generated import artifact was staged. Local `.uid` and
  capture `.png.import` files remain outside the commits.

### Snapshot and content contracts

- Added primitive-safe, deep-copied snapshot contracts for the existing gameplay
  and UI owners. These expose the data needed by vNext without moving mutable
  game state into UI kits.
- Added a static `ContentCatalog` boundary for program, bestiary, achievement,
  patch and relation metadata while keeping `StoryData` authoritative for the
  stage/act catalog.
- Added defensive save payload validation and compatibility probes. Invalid
  structured imports are rejected before typed use or write, and existing save
  bytes remain unchanged on rejection.
- Corrected review-discovered gaps in nested payload validation, catalog parity,
  deep-copy coverage and live patch-offer projection.
- Added `RunContext` as a small gameplay rule boundary with normalized mode and
  mutator identity, copy-safe snapshots and compatibility delegates in `Game`.
- Practice record safety is enforced at `end_run()` and achievement persistence
  rather than only being advertised by a boolean. No new save location or
  schema version was introduced.

### vNext UI foundation and boot route

- Added `VNextUIContext`, shared token/layout helpers and a declared navigation
  focus model.
- Added the from-scratch code-drawn boot surface with safe-area layout,
  semantic action regions, real focusable Buttons and logical pointer/touch
  dispatch.
- Added opt-in Menu integration, resize reconfiguration and protection against
  a child Button activating once and then reaching the parent fallback.
- Added the PROGRAMS and STORY secondary route controls to the boot surface.
- Replaced boot-surface fallback typography with the required Orbitron title and
  ShareTechMono body/control fonts.
- Extended boot overflow evidence to title, subtitle, telemetry, boot,
  program, story and back labels.

### vNext program and story selection

- Added a code-drawn `VNextProgramSurface` using existing `Game.PROGRAM_DEFS`
  and unlock state.
- Added readable process identity, role, playstyle, risk, loadout, locked state,
  program silhouette illustration and explicit launch action.
- Added a code-drawn `VNextStorySurface` using existing stage/act definitions,
  with act tabs, stage state markers, locked reasons, briefing and mount action.
- Added separate narrow list/detail states for both surfaces. The phone layout
  no longer compresses a desktop two-column/map composition into unreadable
  cards.
- Added complete active-state text measurement, native focus controls, keyboard
  navigation, pointer/touch action contracts and duplicate-dispatch checks.
- Corrected the Menu integration path so child BACK returns to boot and does not
  accidentally fall through into a BOOT action.

### vNext patch/build decision

- Added a from-scratch code-drawn patch decision surface, opt-in through
  `KP_VNEXT_PATCH=1`, without changing the default legacy patch overlay.
- Desktop shows all offered patches in parallel; narrow layouts show one
  readable offer with deliberate previous/next navigation.
- Added visible effect, cost/benefit, current-level, relation and before/after
  build information. Locked and unavailable offers explain why they cannot be
  installed; current tradeoff relations remain selectable warnings.
- Added real Arena integration with paused-tree recovery for ESC close, Skip and
  Confirm. Arena validates the snapshot identity and remains the only owner of
  `Game.apply_patch()` and pause state.
- Added deep-copy isolation, safe-area layout, resize reflow, native focusable
  controls, keyboard/mouse/touch handling, and exactly-once command gates.

### vNext combat HUD

- Added an opt-in code-drawn combat HUD mounted on the real Arena HUD path.
- Added responsive information zones, reserved playfield center, conditional
  boss integrity and a touch-safe dash affordance.
- Added explicit state markers and overflow diagnostics while preserving the
  legacy HUD API and default rendering path.
- Added live split-boss bar fractions and a non-color damage-direction marker
  sourced from the real Player hit vector.

### vNext pause, terminal and game-over surfaces

- Added an opt-in code-drawn paused-run surface with real focusable actions,
  frozen simulation semantics and two-step Q abandonment confirmation.
- Added an opt-in diagnostic workstation with a real LineEdit, command
  history, TAB completion, ESC close and Arena-owned command execution.
- Added death/victory diagnosis surfaces with route-accurate retry, next-stage,
  return-to-menu and story-select labels.
- Added responsive narrow layouts for terminal columns and game-over actions,
  safe-area geometry and field-level overflow measurements.
- Preserved the legacy pause, terminal and game-over route when the U4 flag is
  absent.

### Review-driven corrections

The implementation was not accepted at the first green-looking result. The
following concrete defects were found and corrected:

1. Menu BACK had insufficient real GUI evidence; a native Button could have
   been bypassed by direct surface calls. The probe now uses real viewport input
   and checks exactly one Button event and one route action.
2. Story keyboard focus omitted act tabs. The focus registry and probe now cover
   act-tab focus and state change.
3. Narrow program/story composition rendered list and detail simultaneously;
   story content could clip or collide with launch. Both surfaces now switch
   between mutually exclusive list/detail states with explicit return controls.
4. Overflow coverage omitted many rendered labels and used inconsistent font
   assumptions. Reports now use project fonts and cover the actual active
   controls and detail text.
5. Boot route extension left the earlier fallback font and incomplete overflow
   report behind. Both were corrected and regression-tested.
6. A review claim that enabled program launch color was inverted was rejected by
   direct code inspection and a resolved-color assertion; no speculative change
   was made.
7. The first U2b probe was a false green: it did not integrate Arena, showed one
   desktop offer, allowed empty confirmation and missed narrow overlap. The
   controller replaced it with decision-data, state, geometry and real-Arena
   probes before accepting the slice.
8. A second U2b review found weak presentation projection and retry/lifecycle
   evidence. Explicit fields and lock reasons are now preserved, build preview
   is pure, adapter rejection can retry, and next-offer work is deferred.
9. The first U3 green result concealed fullscreen pointer interception, an
   empty split-boss bar, narrow and bottom-panel overlaps, stale patch labels,
   weak overflow measurement and missing real damage direction. Focused red
   checks exposed those defects. The final U3 slice uses pass-through HUD
   input, live fragment bars, a dedicated boss row, measured per-field
   overflow, temporary banner projection and a Player damage-vector source.
10. The first U4 green result left its real Controls invisible because refresh
    ran before visibility, did not require overflow-free text, and used a Q
    fallback that could bypass the actual router. Narrow terminal/game-over
    overflow and overlap were then exposed by stronger checks; the final U4
    slice fixes those issues and keeps one consistent surface parent.

## Main decisions and rationale

### Preserve the old route during the remake

The user wants a genuinely new UI, not a cosmetic migration. The new route is
therefore opt-in until it covers the remaining surfaces and passes compatibility
and visual gates. This accepts temporary duplicate UI code in exchange for a
reversible migration and a playable baseline.

### Let gameplay own truth; let UI project and command

Snapshots read existing Game/StoryData state. UI emits `launch_*` actions and
does not mutate progression, unlocks, balance or save data directly. This
prevents a second source of truth during the remake.

### Use native controls over a code-drawn shell

Frames, illustration and hierarchy remain code-drawn, but real Godot Buttons
own focus and GUI activation. This is slightly more plumbing, but it prevents
fake accessibility/input behavior and makes the action probes meaningful.

### Spend vertical space deliberately on mobile

Narrow screens use a list first and a detail/briefing state second. The tradeoff
is one extra confirmation step before launching, but the player can read the
consequence and navigate back without tiny cards or clipped copy.

### Treat patch conflict as a warning until balance says otherwise

The current relation table describes heavy+splitshot as a tradeoff, not an
invalid combination. The surface exposes the warning and keeps Confirm
available. Disabling the choice would silently change gameplay balance, so that
decision remains with a future gameplay/balance task.

### Keep presentation pure

The patch surface receives copied data and emits commands. The Arena adapter
creates the before/after build preview from a copied level map and applies only
after validating the command. This avoids preview side effects and keeps the
pause/gameplay lifecycle in one owner.

## Verification record

All game execution in this slice used the silent audio driver to avoid
interrupting the user's study session.

| Check | Result |
|---|---|
| Godot import/editor scan | exit 0; known Android build-tools environment warning remains |
| `vnext_boot_probe` | exit 0; `PROBE_DONE fails=0` |
| `vnext_selection_probe` | exit 0; `PROBE_DONE fails=0` |
| `vnext_menu_probe` | exit 0; `PROBE_DONE fails=0` |
| `vnext_patch_probe` | exit 0; `PROBE_DONE fails=0` |
| `vnext_patch_arena_probe` with `KP_VNEXT_PATCH=1` | exit 0; `PROBE_DONE fails=0` |
| `vnext_combat_hud_probe` with `KP_VNEXT_HUD=1` | exit 0; `PROBE_DONE fails=0` |
| `vnext_state_surfaces_probe` with `KP_VNEXT_U4=1` | exit 0; 71 passes, `PROBE_DONE fails=0` |
| `vnext_state_surfaces_probe` with `KP_VNEXT_U4=1` under Xvfb | exit 0; 71 passes, `PROBE_DONE fails=0` |
| existing `layout_probe` | exit 0; `PROBE_RESULT passes=130 fails=0` |
| full `--autotest` suite | exit 0; 1414 `AT_PASS`, 0 `AT_FAIL`, `AUTOTEST_ALL_PASS` |
| `git diff --check` | clean |

The focused probes cover 1366×768, 720×720 and 432×720 logical viewports,
safe-area containment, text scale 1.15, reduced motion/high contrast context,
keyboard, focus, real Button ENTER, direct pointer/touch dispatch, locked
and tradeoff states, route return, resize, empty offers and duplicate
activation.

## Clean release notes draft

### Added

- Added an opt-in rebuilt UI route for booting a process, browsing programs and
  browsing story nodes.
- Added program detail information for identity, playstyle, risk and starting
  loadout.
- Added story act tabs, stage status markers, locked-node explanations and
  readable briefings.
- Added mobile-friendly list/detail navigation for program and story browsing.
- Added an opt-in patch/build decision surface with visible consequences and
  narrow previous/next navigation.
- Added stronger keyboard, mouse and touch interaction coverage in development
  builds.

### Changed

- The experimental vNext UI now uses the game's Orbitron and ShareTechMono
  typography consistently.
- Program/story selection is separate from the final BOOT/MOUNT action, making
  the consequence visible before starting.
- The legacy menu remains the default while the new route is validated.
- The legacy patch overlay remains the default while the new decision surface
  is validated.

### Fixed

- Fixed vNext route BACK handling so returning from Program/Story cannot start
  BOOT accidentally.
- Fixed missing story act-tab keyboard focus.
- Fixed narrow-layout clipping risk by separating list and detail states.
- Fixed incomplete boot-surface text overflow coverage.
- Fixed the first patch-surface false green by integrating the real Arena path,
  rejecting empty/unavailable confirmation, and testing layout/data semantics.
- Fixed vNext HUD fullscreen input interception that could block mouse combat.
- Fixed the split-boss bar using the invalid root fraction instead of live
  fragment health.
- Fixed U3 panel overlap at narrow and desktop layouts, stale patch labels,
  cycle duplication between continuous and temporary feedback, and weak
  overflow measurement.
- Fixed U4 state-surface controls being invisible after refresh, false-green
  overflow/Q evidence, terminal title clipping at narrow width, game-over
  button overlap, stale terminal semantics, inconsistent surface parents and
  misleading victory action labels.

### Improved

- Improved action semantics and focus behavior for keyboard, mouse and touch.
- Improved locked-state communication with explicit reason text and state
  markers instead of opacity alone.
- Improved validation so green probes require completion markers and exercise
  actual route/control behavior.
- Improved patch decisions with build before/after preview, explicit tradeoff
  warnings, and state reasons instead of relying on opacity or color.
- Improved paused-overlay input so ESC, Skip and Confirm recover the Arena
  without duplicate application.
- Improved combat readability with textual integrity/meter/dash/boss states,
  live patch labels, damage direction and a distinct temporary event slot.
- Improved pause/terminal/game-over UX with real focusable controls, command
  history feedback, explicit diagnosis and action labels, and responsive
  narrow composition.

### Compatibility

- Default legacy menu, gameplay, balance, save keys, input bindings and story
  progression remain unchanged by the vNext opt-in route.
- No Android support claim is made by this development slice.

### Performance

- New vNext surfaces do not add a gameplay polling loop, physics body or timer.
- The HUD avoids rebuilding patch labels when patch levels are unchanged, and
  legacy boss-fragment pruning now allocates only when a fragment was freed.
- Performance budgets and device profiling remain future plan gates.
- The patch surface is laid out and measured on configure/resize and adds no
  gameplay polling, physics body or per-frame update while hidden.

### Known Issues

- The rebuilt UI is not yet the default and has not received final grayscale or
  finish-layer visual approval.
- PT-BR/localized copy, persisted accessibility settings and native screen-reader
  support are not implemented yet.
- Physical-device pointer/touch behavior, rapid route cancellation, Android
  export and teardown resource/RID diagnostics still need dedicated evidence.
- The U3 touch dash is intentionally visual in the vNext left module; the
  existing right-side `TouchControls` remains the authoritative touch action
  zone until the touch HUD is reviewed on hardware.
- The test suite is functionally green but still reports the recorded teardown
  resource/RID/ObjectDB diagnostics; these are not hidden or considered fixed.
- Arbitrarily long localized patch copy is detected by the overflow report but
  does not yet have a scrollable card treatment.
- U4 state surfaces remain opt-in and have no final visual approval, PT-BR
  copy, physical-device mobile validation or native screen-reader integration.
- Practice selection, wave selection and Weekly mutator preview are not yet
  shipped; G1 provides the contract and safety boundary only.

## Release-note hygiene

Internal refactors, probe implementation details and font-resource mechanics
belong in the technical reports above. The clean notes intentionally mention
only behavior that could affect a player, tester or maintainer. This draft must
be revisited when U2b–U6 and the final migration gates change the user-facing
scope.

## U6 — shared recoverable state primitive

- Added a reusable vNext state contract and code-drawn surface for loading,
  error, empty and transition states, with safe semantic actions, explicit
  back/cancel policy, real Buttons, focus and measured responsive layouts.
- No visible route, producer integration, gameplay mutation, save path or
  legacy behavior was added by U6; catalog/save/locale/transition examples are
  fixture-only contract evidence.
- Corrected visible-copy sanitization so lowercase identifier-like keys with
  dots, hyphens or underscores cannot be shown as player-facing text.
- Hardened the accumulated validator with a configurable TERM-to-KILL grace
  period. This makes hung invocations fail closed; it is not a promise of
  complete supervision for arbitrary child processes.
- U6 is not a claim of Android, physical-touch, native screen-reader, PT-BR,
  device-performance or final visual support. Long copy is detected by the
  overflow report but is not yet scrollable.

## U5 — vNext Settings and Accessibility

- Status: implemented and verified on 2026-09-01; opt-in only through
  `KP_VNEXT_SETTINGS=1`.
- Added a real Settings route and dedicated Accessibility section with four
  functional controls: color assist, haptics, screen shake and touch size.
- Added Sfx schema-2 defaults, normalization, persistence, reload and
  two-step reset using the existing `user://kernel_panic.cfg`; progress keys
  remain preserved.
- Added semantic state text, native focusable Buttons, keyboard/pointer/touch
  regions, recovery status and responsive overflow checks.
- Text scaling, high contrast, reduced flash, native screen reader and gamepad
  remain explicitly unsupported and non-interactive.
- Evidence before the independent correction: red probe exit 1 with 12 failures;
  U5 headless/Xvfb probe 59/0. The correction added disk-load normalization,
  rollback-status truthfulness, stronger preservation fixtures and deterministic
  save-failure evidence; the corrected focused probe is 66/0.
- Final evidence after correction: import exit 0; full suite 1414 `AT_PASS`,
  0 `AT_FAIL`, `AUTOTEST_ALL_PASS`; accumulated validator `VALIDATION OK`.
- Known limitations: real permission/disk-full failure, physical touch,
  Android/export, localization, visual approval, device performance and
  baseline teardown diagnostics.
- Report: `.superpowers/sdd/00-MASTER-PLAN/report-U5.md`.
- Handoff: `docs/HANDOFF-U5-SETTINGS-ACCESSIBILITY.md`.

## E3 — Program identity runtime slice

### Added

- Added distinct code-drawn runtime identities for KERNEL, DAEMON and ROOTLET
  in the opt-in vNext program selector, combat HUD and pause surface.
- Added user-visible ability status labels derived from the active run:
  overclock, dash and shield readiness/activity.

### Fixed

- Fixed DAEMON and ROOTLET being displayed as KERNEL when the real player was
  routed through the vNext presentation adapter.

### Improved

- Improved narrow HUD readability so the live program ability and score fit in
  the compact layout; OVERCLOCK uses the compact `OC` label only where space
  requires it.

### Evidence

- E3 focused probe: 35/0 in headless and Xvfb after adversarial corrections.
- Canonical program colors now match the existing program catalog, and the
  Combat HUD draw path was checked against a real snapshot rather than only
  its semantic dictionary.

### Compatibility

- vNext remains opt-in; legacy UI, gameplay, saves, input, balance and routes
  are unchanged by E3.

### Known Issues

- No final human visual approval, physical mobile/Android/Vega validation,
  PT-BR or native screen-reader validation is claimed. Existing teardown
  diagnostics remain open and are not represented as fixed.
## 2026-09-01 — unreleased — ZOMBIE_PROCESS

Branch: `codex/plan-execution`
Commits: `16f6f24` implementation; documentation commit recorded in the E4 handoff
Area: gameplay
Platforms: PC | mobile (logical/code path only; no physical mobile validation)

### Bugs found

- No prior implementation could construct or teach the approved temporary
  projectile obstacle; the first real-path probe reproduced five missing
  contracts before the fix.

### Root cause

- The enemy factory, story data, bestiary/catalog, presentation vocabulary and
  reward/pathing ownership had no temporary-process contract.

### Fixes

- Added a stationary 4-second `ZOMBIE_PROCESS` with explicit virtual hooks that
  exclude it from pathing and kill rewards. Expiry and damage destruction leave
  the normal reward path untouched.
- Added the first isolated `/boot` teach wave, shared code-drawn shell/caret/
  timer identity, catalog entry and real-path validator case.

### Improvements and additions

- Players can reposition or wait through a readable dead-process shell that
  blocks shots briefly, with a timer represented by shape/line markers as well
  as color.

### Compatibility

- No save schema, input, bullet constants, ordinary enemy stats, score rules or
  existing enemy behavior changed. No sprite or texture was introduced.

### Evidence

- Red: `/tmp/kernel-panic-e4-red-2.log`, exit 1, `PROBE_DONE fails=5`.
- Green focused headless/Xvfb: exit 0, 18 passes, `PROBE_DONE fails=0`.
- DevHarness: exit 0, 1414 `AT_PASS`, 0 `AT_FAIL`, `AUTOTEST_ALL_PASS`.
- Import: exit 0; Android build-tools environment warning recorded.
- Aggregate validator: `VALIDATION OK`; E4 17/0 and all accumulated cases
  green, with teardown diagnostics reported separately. Final post-commit
  rerun: `/tmp/kernel-panic-e4-post-validator.log`, E4 18/0 and
  `VALIDATION OK`.

### Known limitations

- No human visual approval, screenshots, physical mobile test, Android export,
  dense-wave profile or gameplay-feel review. Existing teardown resource/RID
  diagnostics remain open. The next safe checkpoint is adversarial review of
  this slice; `RACE_CONDITION` is intentionally deferred.

### E4 review correction — enemy pathing exclusion

#### Fixed

- Corrected the shared enemy pathing helpers so `ZOMBIE_PROCESS` is excluded
  from direct separation, steer separation and open-space congestion checks.
  The first version filtered only the base physics separation path, leaving a
  real integration gap for enemies using the reusable steering helpers.

#### Evidence

- Review red: `/tmp/kernel-panic-e4-review-red2.log`, one focused assertion
  failed before the correction.
- Review green: `/tmp/kernel-panic-e4-review-green2.log`, 20 passes, zero
  failures, explicit completion marker.
- Fresh aggregate validation: `/tmp/kernel-panic-e4-review-validator-summary.log`,
  exit 0, `VALIDATION OK`; full suite 1414/0, E2 77/0 and E4 20/0, with no
  gated runtime errors. Teardown diagnostics remain reported separately.

## 2026-09-01 — unreleased — E5 entity quality tiers

This is an internal development-log entry. It is not yet a public release
claim because the vNext route remains opt-in and physical mobile/visual
approval is still open.

### Added

- Added an explicit quality profile for code-drawn entity previews, with
  desktop and mobile tiers plus reduced-motion, high-contrast, color-assist
  and grayscale flags.
- Added a finish-only renderer layer: desktop keeps subtle outer accents,
  while mobile removes that cosmetic work without removing identity, facing or
  state markers.
- Routed the profile into the vNext Boot and Program previews when touch
  context is explicitly active.

### Fixed

- Fixed malformed boolean-like quality values so serialized `"false"` and
  `"off"` do not become truthy settings.
- Fixed preview refreshes from retaining a stale desktop quality profile.

### Improved

- Improved the separation between gameplay-readable structure and optional
  cosmetic finish in the code-drawn renderer.
- Added a real ten-entity draw-path probe and a sprite-policy check.

### Compatibility

- Legacy routes, gameplay, save data, input bindings and raster defaults are
  unchanged. No raster asset was added; code-drawn output remains the default.

### Performance

- Mobile finish work is contractually disabled. Local script-side samples are
  recorded for future budgeting but do not constitute physical-device or GPU
  performance guarantees.

### Known Issues

- Legacy combat enemy custom drawing is not yet routed through the new quality
  profile. Physical mobile/Android/Vega profiling, human visual approval,
  persisted exposure of all accessibility flags, raster comparison and
  teardown diagnostics remain open.

### Evidence

- E5 focused headless and Xvfb probes: 18 passes, zero failures in each.
- Full DevHarness: 1414 passes, zero failures, `AUTOTEST_ALL_PASS`.
- Accumulated validator: `VALIDATION OK`; all registered probes passed with
  zero gated runtime errors.
- Technical report: `.superpowers/sdd/00-MASTER-PLAN/report-E5-entity-quality.md`.
- Handoff: `docs/HANDOFF-E5-ENTITY-QUALITY.md`.

## 2026-09-01 — unreleased — Page Cache

This is an internal development-log entry. It is not yet a public release
claim; the mechanic still needs HUD discoverability, playtest and final
balance approval.

### Added

- Added the optional PAGE CACHE passive patch. It stores up to three spare
  overclock motes and automatically releases a grouped bonus when the third is
  stored.
- Added a read-only cache state to the player presentation payload so a future
  HUD can show stored capacity without taking ownership of gameplay state.

### Changed

- When PAGE CACHE is active, spare-mote overflow is delayed until the cache
  flushes. Shield-mode collection keeps its existing precedence.

### Compatibility

- Without PAGE CACHE, existing full-meter overflow remains immediate.
- No save keys, transfer format, input actions, routes or existing patch
  behavior were removed or changed.

### Economy

- The current implementation preserves the existing overflow unit: each of
  the three released motes gives `+5` score and one existing scrap-progression
  unit, for `+15` per flush. This is an implementation assumption because the
  approved mechanic did not specify a separate reward number.

### Known Issues

- The legacy HUD does not yet show a stored `0/3`, `1/3` or `2/3` cache meter;
  flush feedback is the current discoverability channel.
- Final reward feel, human playtest, physical mobile behavior, dense-wave
  performance and teardown diagnostics remain open.

### Evidence

- Focused red bootstrap: `/tmp/kernel-panic-g2a-red.log`, exit `124` before
  implementation and without a completion marker.
- Focused green: `/tmp/kernel-panic-g2a-green3.log`, exit `0`, `13` passes,
  zero failures and `PROBE_DONE fails=0`.
- Technical report: `.superpowers/sdd/00-MASTER-PLAN/report-G2-page-cache.md`.
- Handoff: `docs/HANDOFF-G2-PAGE-CACHE.md`.

## 2026-09-01 — unreleased — Ring-0 double overclock

This is an internal development-log entry. The exact duration/cooldown tuning
and HUD messaging still need playtest approval.

### Added

- Added the optional RING-0 passive patch. One re-press during an active
  overclock extends the active window once, allowing a two-stack overclock.
- Added a post-double recovery lock and read-only stack/lock state for future
  HUD communication.

### Improved

- DAEMON dash behavior remains intact during the re-press: the dash is not
  cancelled, the charge is consumed once and no integrity is spent.
- Overclock meter projection now uses the complete duration and stays within
  its valid range when duration modifiers are present.

### Compatibility

- Without RING-0, the second press remains inert and ordinary overclock keeps
  its previous single-stack behavior.
- Rootlet shield mode cannot be bypassed by the patch. No save, route or input
  schema changed.

### Known Issues

- The current stack interpretation is “add one existing duration” and the
  recovery lock is one existing duration. These are explicit balance
  interpretations, not final player-facing tuning.
- The legacy HUD does not yet explain the recovery lock with a dedicated
  label. The state is available to the rebuilt HUD boundary.

### Evidence

- Final focused probe: `/tmp/kernel-panic-g2b-green2.log`, exit `0`, `15`
  passes, zero failures and `PROBE_DONE fails=0`.
- Technical report: `.superpowers/sdd/00-MASTER-PLAN/report-G2-ring0.md`.
- Handoff: `docs/HANDOFF-G2-RING0.md`.

## 2026-09-01 — unreleased — Display settings

### Added

- Added a dedicated DISPLAY settings section with fullscreen and target FPS
  controls: 30, 60, 120 or unlimited.

### Changed

- New non-touch desktop profiles default to unlimited FPS; touch contexts
  default to 60. The setting is applied immediately to the engine/window.
- Display values now persist under a dedicated `[display]` section while the
  previous `feel.target_fps` key remains readable and synchronized for
  compatibility.

### Compatibility

- Invalid persisted or requested FPS values fall back to the platform default.
- Headless execution skips window-mode mutation safely.

### Known Issues

- Physical mobile, Android/macOS fullscreen behavior, vNext Settings
  migration, final visual approval and device performance are not proven.

### Evidence

- Headless focused probe: `/tmp/kernel-panic-g2c-green.log`, 13 passes, zero
  failures, `PROBE_DONE fails=0`.
- Xvfb focused probe: `/tmp/kernel-panic-g2c-xvfb.log`, 13 passes, zero failures,
  `PROBE_DONE fails=0`.
- Technical report: `.superpowers/sdd/00-MASTER-PLAN/report-G2-display-settings.md`.
- Handoff: `docs/HANDOFF-G2-DISPLAY-SETTINGS.md`.

## 2026-09-01 — unreleased — Weekly and Practice foundations

### Added

- Weekly mode now previews and runs one deterministic mutator per week:
  daemons move 20% faster, or wave budgets are 20% larger. The rotation is
  tagged and visible before launch.
- Practice wave selection unlocks from the highest Classic Endless wave
  reached. Practice starts at the selected wave and is excluded from run
  records, lifetime statistics and achievement conditions.
- Compact menu copy and a touchable Practice wave selector keep these states
  readable on narrow layouts.

### Compatibility

- Weekly scores remain in their existing separate record namespace. Save
  transfer version 1 remains compatible; older payloads default the new
  Endless-wave field to zero.

### Known Issues

- The two mutators and first-run Practice unlock threshold need human balance
  and onboarding approval. Physical mobile behavior, final visual approval and
  teardown cleanliness remain open.

### Evidence

- Headless and Xvfb G3 probes passed with `PROBE_DONE fails=0`.
- Full DevHarness passed with 1427 checks, zero failures and
  `AUTOTEST_ALL_PASS`.

## 2026-09-01 — unreleased — Boss desperation

### Added

- Bosses now enter a one-shot late-health state at 8% HP with a 0.75-second
  reaction window, a high-contrast non-color telegraph and faster attack
  cadence afterward. Incoming damage is unchanged.
- RootBoss variants, split fragments and GOD share the rule and expose the
  state to the presentation adapter.

### Known Issues

- Normal and One-HP human playtests still need to confirm that the cadence and
  transition window feel dangerous without turning an existing projectile
  pattern into a forced death.

### Evidence

- Focused G4 coverage passed 55 checks across all boss variants, split
  fragments, transition gating, normal damage and dash reaction margin.

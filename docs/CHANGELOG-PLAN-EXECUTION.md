# KERNEL PANIC — unreleased development changelog (consolidated)

This changelog describes the work completed through the current
`fuzzy/ui-reference-remake` checkpoint (`28d2a48`), including the inherited
plan-execution baseline. It is not an official release announcement. The
legacy route remains the default, and several new surfaces are still behind
development switches while visual, platform, balance, and device gates are
completed.

For the current technical audit, evidence ledger, decisions, risks and release
verdict, see [the current final execution report](FINAL-UI-REFERENCE-REMAKE-REPORT.md).
For the older plan-only checkpoint, see the preserved
[historical execution report](FINAL-PLAN-EXECUTION-REPORT.md).

## Added

- Added a from-scratch vNext UI foundation for boot, program selection, story
  selection, patch decisions, combat HUD, pause, terminal, game-over, shared
  state, and dedicated accessibility settings.
- Added the macOS history act with four fictional stages: Classic, Aqua,
  Darwin, and Modern.
- Added layered `BACKGROUND` reveals, a code-drawn Permission Root climax,
  Mac story rewards, and a bestiary identity for the new boss.
- Added deterministic Weekly modifiers and Practice wave selection with
  separate progression rules.
- Added code-drawn identity/state presentation foundations for enemies and
  programs, including Zombie Process and Race Condition encounters.
- Added local death-heatmap diagnostics, desktop patch-music layers, and
  explicit display settings for fullscreen and target FPS.
- Added reduced motion, reduced flashes, and left-handed touch options to the
  accessibility profile and dedicated settings surface.
- Added English/PT-BR locale catalogs, fallback/formatting helpers, Mac story
  translations, and PT-BR accessibility copy.
- Added a deterministic performance profile and fixed-seed stress probe using
  real enemy descendants and real projectiles.
- Added contribution, conduct, security, issue/PR, art-direction, and release
  governance documents.
- Added a reference-driven incident-console shell, Story mount-table surface,
  patch decision surface and perimeter combat HUD for the from-scratch vNext
  route.
- Added focused regression probes for physical window reflow, legacy overlay
  navigation, Bestiary visibility, display-setting scope, layout cache,
  presentation-tween lifecycle and live split-boss rows.

## Changed

- Story and content metadata now cross the runtime/UI boundary through
  copy-safe catalogs and snapshots without moving mutable gameplay ownership
  into presentation code.
- Story completion prepares and checkpoints progress before committing the
  in-memory cleared/reward state; failed story writes remain retryable instead
  of presenting a false success.
- Accessibility settings use additive schema migration, normalization, reset,
  and rollback through the established save path.
- Touch controls can mirror movement and action placement for left-handed play;
  action semantics and keyboard bindings remain unchanged.
- Mac story and accessibility layouts now report measured copy fit across wide,
  square, and narrow logical viewports.
- The validation entry point now includes Mac integration, accessibility,
  performance, and the accumulated gameplay probes.
- Legacy and vNext state panels now use explicit keyboard focus order, a shared
  lower-left return slot, and selection preservation in the Bestiary.
- Fullscreen visibility is now derived from the desktop-only platform
  predicate; target FPS remains available to touch/mobile contexts.
- HUD and Arena responsive layout work is now invalidation-driven instead of
  rebuilding unchanged geometry every frame.
- Re-entered tips and boss intros replace their previous timelines, and split
  boss bars are derived from live fragments and the actual boss variant.

## Fixed

- Fixed paused gameplay and debug-key input swallowing ESC, ENTER, and other
  unrelated keys.
- Fixed terminal ESC behavior while a LineEdit has focus and restored the pause
  panel through the correct ownership path.
- Fixed an unused `PlayerBullet` allocation that leaked one orphan node per
  shot.
- Fixed Rootlet shield recharge deadlock after shield consumption, including
  the kill-bonus completion path and full-shield overflow behavior.
- Fixed the story Temple/GOD path spawning the wrong boss class.
- Fixed menu header anchors and restored the footer frame registry.
- Fixed the first Mac catalog integration regression by keeping Permission Root
  counterplay copy within the existing bestiary text budget.
- Fixed the legacy menu launch prompt and made destructive pause actions
  deliberate instead of one-activation operations.
- Fixed legacy HUD hierarchy, contrast, state redundancy, narrow collisions,
  modal-effect layering, dead widgets and touch-only affordance leakage.
- Fixed a repeated `CYCLE` announcement, overlong event/patch copy, an
  invisible long-lived banner fade, and the legacy dash glyph reappearing over
  the vNext HUD.
- Fixed physical resize handling for menu/Arena overlays and several reference
  surface collisions in narrow layouts.
- Fixed Bestiary selection opening outside the visible list, fullscreen being
  exposed on touch, duplicate presentation tweens and ghost rows in split boss
  bars.

## Improved

- Enemy and program presentation now has shared descriptors, bounds, state
  markers, quality tiers, and renderer/adaptor contracts, making the code-drawn
  language easier to evolve without changing hitboxes.
- Boss desperation is telegraphed with non-color state markers and a reactable
  transition window.
- The UI direction now explicitly favors authored code-drawn silhouettes,
  restrained glow, semantic color plus redundant shape/text cues, and adaptive
  playfield-first layouts.
- Verification now requires completion markers, focused probes, full-suite
  evidence, and separate reporting of runtime errors versus teardown noise.
- Improved the reference remake's visual grammar with a recurring system shell,
  asymmetric index/dossier compositions, semantic rails, explicit primary
  actions and a playfield-first HUD.
- Improved layout efficiency with keyed HUD/Arena caches and retained
  observability for cache hits, builds and relayouts.
- Improved lifecycle safety by giving tip and boss-intro presentation an
  explicit owner and cancellation path.

## Performance

- The fixed stress fixture currently passes with 144 actors at approximately
  16.949 ms p95, 17.279 ms p99, and 17.379 ms worst in headless mode.
- The same fixture passes under Xvfb/Mesa llvmpipe at approximately 9.406 ms
  p95, 9.727 ms p99, and 10.101 ms worst.

These values are repeatable regression baselines, not a guarantee for the
integrated Vega GPU, Android devices, or long sessions.

## Compatibility

- Existing save paths, legacy settings keys, stage IDs, and version-1 progress
  transfer remain readable in the implemented slices.
- New accessibility and locale values are additive local settings.
- New story reward IDs are catalog-whitelisted and optional in imported old
  payloads.

## Known issues

- The full vNext UI is still opt-in; the legacy UI has not been replaced.
- PT-BR is partial. Many legacy player-facing strings still need migration and
  a native editorial review.
- The final Permission Root silhouette still uses the shared boss glyph as a
  temporary code-drawn fallback.
- Native screen readers, OS text scaling, and a true high-contrast theme are
  not implemented.
- Reduced motion and reduced flashes do not yet have a complete audit of every
  particle, ring, ghost, or decorative animation.
- Shutdown still reports known resource/ObjectDB/RID teardown diagnostics.
- Crash-safe save journaling, remote CI verification, release provenance,
  Linux/Windows export validation, Android export/device validation, physical
  mobile UX, and final human visual/balance review are still open.

## Removed / Deprecated

- No player-facing feature was removed in this execution slice.
- No legacy route was deprecated or deleted; the explicit opt-in boundary is
  intentional until the vNext migration receives final approval.

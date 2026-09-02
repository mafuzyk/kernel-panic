# KERNEL PANIC — UI reference remake (unreleased)

> Development release notes for `fuzzy/ui-reference-remake`. This is not an
> official public release. The vNext route remains opt-in while visual,
> platform, accessibility, localization and release gates are completed.

## Added

- Added a from-scratch terminal-system shell for the vNext boot screen, with
  persistent route metadata, process telemetry, command navigation and a
  code-drawn Kernel identity.
- Added a vNext Bestiary surface with a process index, logged/locked states,
  threat dossier, behavior, counterplay and shared code-drawn enemy identity.
- Added physical-window responsive probes for the menu and Arena overlays at
  narrow portrait size.
- Added narrow-layout regression coverage for pause and terminal title fit.
- Added a validation entrypoint for the new boot, selection, Bestiary and
  physical responsive probes.
- Added authored code-drawn structure for Drone, Lancer, Spewer, Daemon and
  Rootlet silhouettes, including directional and mechanical identity cues.

## Changed

- Changed Program selection into an asymmetric process-index/dossier layout
  with a persistent boot action and explicit role, playstyle, risk and loadout
  information.
- Changed accessibility settings to use the reference workstation shell while
  keeping the existing persisted settings service and real controls.
- Changed menu, patch, pause, terminal and game-over vNext surfaces to derive
  layout from the physical window when a narrow window is active, instead of
  squeezing a desktop composition into the available space.
- Changed narrow boot navigation to distribute its footer actions across the
  available width so Back, Bestiary and Settings remain usable.
- Changed the presentation baseline for the accepted E2 code-drawn enemy batch
  to match the intentionally upgraded silhouettes.
- Kept the legacy route as the default rollback path; no public default switch
  was changed in this development checkpoint.

## Fixed

- Fixed a pause title that could render beyond the narrow modal because its
  actual Orbitron font was not part of the overflow measurement.
- Fixed the terminal title colliding with `CLOSE [ESC]` on narrow windows.
- Fixed Program and Bestiary footer build telemetry being drawn below its
  footer band and into the boot action area.
- Fixed the accumulated validator treating a relative `XDG_DATA_HOME` as a
  valid isolated save location, which could produce false touch and lock-on
  failures from shared user state.

## Improved

- Improved menu information hierarchy so the player sees identity, state and
  the next action before decorative detail.
- Improved Bestiary readability by sharing the same entity renderer used by
  code-drawn presentation previews instead of maintaining a separate icon-only
  representation.
- Improved narrow readability with explicit list/detail states and fitted
  headings rather than uniform proportional shrinking.
- Improved entity presentation semantics with explicit sensor, spear, nozzle,
  claw, shield and facing metadata.
- Improved regression evidence by making overflow reports use the font actually
  drawn for headings and by adding real physical-resize probes.

## Performance

- No gameplay loop, collision, spawn or balance path was changed by this UI
  slice.
- The existing deterministic performance profile and accumulated stress probe
  continue to pass; hardware-specific frame-time claims remain open.

## Compatibility

- Existing save path, save schema, gameplay input and legacy UI route remain
  compatible.
- No new online service, account, telemetry endpoint or asset dependency was
  introduced.
- Validation was run with audio disabled so tests and captures do not interrupt
  the developer's study session.

## Known Issues

- The vNext UI is still opt-in; the legacy UI remains the default.
- This is a visual vertical slice, not the final full-cast art pass.
- PT-BR is not yet complete across every player-facing legacy string.
- Android/device/touchscreen/export validation is still pending.
- Native screen-reader integration and OS-level text scaling are still pending.
- Teardown diagnostics for resources, ObjectDB and RIDs remain under
  investigation.
- Final human review of grayscale, high contrast, reduced motion, game feel,
  balance and release hardware is still required.

## Verification summary

- DevHarness: `1453 AT_PASS`, `0 AT_FAIL`, `AUTOTEST_ALL_PASS`.
- Input dispatch: 32 headless passes and 34 Xvfb/debug passes.
- Reference-shell boot: 102 passes.
- Program/Story selection: 168 passes.
- Bestiary: 128 passes.
- Pause/terminal/game-over: 75 passes.
- Accessibility: 98 passes.
- Physical menu resize: 8 passes.
- Physical Arena overlay resize: 12 passes.
- Accumulated validator: `VALIDATION OK`; teardown diagnostics are reported
  separately and remain non-gating for this development checkpoint.

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
- Added a shared `incident console` chrome layer with calibration rails and
  data-backed evidence blocks for the main vNext surfaces.
- Added a Story mount-table surface with act tabs, a node index, stage dossier
  and a data-backed `STATE / ACT / NEXT` evidence block.
- Added a reference-driven patch decision presentation with a selected-offer
  register and deterministic wide/narrow capture fixtures.
- Added a reference-driven combat HUD surface with perimeter rails, integrity
  pips, combo telemetry, event register, patch dock, ability instrument, score
  readout and boss health register.
- Added combat HUD coverage for wide, narrow and micro-narrow logical viewports,
  including panel separation, reserved playfield, text fit, combo sync, boss
  fragments, damage direction and the real Arena adapter path.
- Added a silent, crop-aware vNext surface capture utility and a focused chrome
  contract probe for wide and narrow viewports, including Story list/detail
  captures.
- Added a repeatable visual verification path for the reference-remake
  surfaces; the focused probes report their pass counts in the verification
  summary below and zero failures.

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
- Changed Boot, Program, Bestiary and Accessibility to share the same shell
  grammar while retaining surface-specific composition and facts.
- Changed Story from the remaining selection-panel exception into the same
  incident-console grammar: route metadata, act navigation, node state, stage
  dossier and explicit mount command.
- Changed Story narrow layout to use an intentional list → dossier flow rather
  than compressing the desktop node map into a phone viewport.
- Changed the patch offer to use the shared incident-console shell, with
  `KP://PATCH` route metadata, explicit paused/offer status and consequence
  information tied to the selected build.
- Changed narrow patch navigation to keep one offer readable with deliberate
  previous/next, install, skip and close targets instead of shrinking three
  cards into a phone viewport.
- Changed Program and Bestiary narrow footers to use an explicit three-slot
  layout for index/state/build telemetry.
- Changed the combat HUD from a sparse adapter composition into a perimeter
  instrument inspired by `media/Ideas/imagem5.png`; the center remains open for
  combat entities and projectiles.
- Changed portrait HUD composition at extremely narrow widths to stack the
  integrity and patch registers instead of allowing two side panels to collide.
- Changed micro-narrow, and narrow layouts at 110%+ text scale, to use compact
  ability forms such as `OC RDY` and `SH RDY`; regular narrow at default scale
  keeps full program-specific state names.
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
- Fixed shared-shell metadata being positioned from the shell bottom instead of
  the header baseline during the visual review.
- Fixed Program index buttons retaining text-width sizing instead of occupying
  the actual list column.
- Fixed Accessibility status and unsupported-feature bounds being shorter than
  their measured font height.
- Fixed compact Program/Bestiary evidence panels hiding their second
  data-backed row because the panel height was sized for a single line.
- Fixed Story node rows overflowing their list frame because the container
  spacing was omitted from the row-height calculation.
- Fixed Story long locked-state labels, a diagonal footer guide, clipped
  evidence rows and narrow collisions between dossier, node-list and mount
  actions.
- Fixed patch title/close collision on narrow windows, an undersized close
  target, card text entering the evidence register and level/impact overflow
  in the narrow composition.
- Fixed the legacy dash glyph being re-enabled every frame on top of the vNext
  combat HUD.
- Fixed a 320×568 HUD collision caused by treating every portrait window as a
  two-column narrow desktop.

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
- Improved Story state comprehension by separating path labels from state
  markers on wide layouts while keeping a self-contained `NODE NN READY` form
  on narrow layouts.
- Improved patch decision comprehension with visible selected-offer indexing,
  state/build/next evidence, focus frames and an explicit distinction between
  selectable conflicts and unconfirmable locked/unavailable offers.
- Improved combat readability with explicit HP/meter states, combo progress,
  directional damage marker, patch chips and boss bars that remain distinct
  from temporary event copy.
- Improved micro-narrow HUD legibility by reserving the center explicitly and
  shortening labels only after the 432×720 program-identity contract showed
  that regular narrow could retain full names.

## Performance

- No gameplay loop, collision, spawn or balance path was changed by this UI
  slice.
- The vNext HUD adds code-drawn lines/polygons and a few measured text fields;
  no new raster or online asset dependency was introduced. Hardware-specific
  frame-time claims remain open.
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
- Program/Story selection: 225 passes, 0 failures.
- Patch decision surface: 67 passes, 0 failures; real Arena adapter: 19 passes,
  0 failures.
- Combat HUD Arena adapter: 75 passes, 0 failures.
- Bestiary: 128 passes.
- Pause/terminal/game-over: 75 passes.
- Accessibility: 98 passes.
- Physical menu resize: 8 passes.
- Physical Arena overlay resize: 12 passes.
- Accumulated validator: `VALIDATION OK`; teardown diagnostics are reported
  separately and remain non-gating for this development checkpoint.

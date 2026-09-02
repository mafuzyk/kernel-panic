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
- Changed combat wave announcements so the continuous `CYCLE NN` register is
  not repeated as the large temporary banner; named wave and anomaly events
  remain visible in the event slot.
- Changed legacy event-log rendering to measure and ellipsize each line inside
  the score register, with a stronger readable text alpha.
- Changed legacy HUD status communication to expose readable integrity,
  shield/overclock and dash states, including a cardinal damage-direction
  marker, so color and alpha are no longer the only signal.
- Changed narrow legacy game-over composition to stack its diagnostic blocks and
  actions when two desktop columns would make the copy unusable.
- Kept the legacy route as the default rollback path; no public default switch
  was changed in this development checkpoint.
- Changed legacy pause, terminal and game-over controls to share an explicit
  keyboard focus order while preserving their existing mouse/touch targets.

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
- Fixed the legacy combat HUD repeating `CYCLE NN` in both the encounter panel
  and the large wave/boss announcement.
- Fixed long legacy event-log and patch-tooltip copy escaping its measured
  width; the tooltip now fits title, detail and relation independently.
- Fixed Rootlet's ready shield and shield meter presentation being represented
  through the generic overclock/meter language in the legacy HUD.
- Fixed legacy HUD auxiliary copy, dense integrity pips, scrap telemetry and
  narrow game-over controls exceeding their available layout regions.
- Fixed the low-health/CRT overlay remaining above pause, terminal, patch and
  game-over surfaces, which could distort the very panel needed to read the
  next action.
- Fixed the Windows activation watermark remaining visible over modal state
  panels; it now follows the same explicit gameplay/modal visibility contract.
- Fixed the legacy selection screens showing `SWIPE TO SCROLL` on desktop even
  though the available input is wheel/drag; the swipe affordance is now touch
  only.
- Fixed long legacy HUD event banners spending their first fraction of a
  multi-second lifetime fully invisible; the fade now starts from elapsed time.
- Fixed legacy state panels opening without a visible focus target; pause and
  game-over now focus their primary action, and terminal ESC restores the
  action that opened it.

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
- Improved modal readability by making overlay suppression state-driven rather
  than dependent on CanvasLayer ordering alone; gameplay effects restore when
  the modal closes.
- Improved the HUD's runtime footprint by removing hidden labels and an unused
  patch callback that had no visible consumer.
- Improved keyboard-only operation with visible focus chrome, deterministic
  vertical navigation and a Shift+Tab route out of the legacy terminal prompt.

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

- DevHarness: `1454 AT_PASS`, `0 AT_FAIL`, `AUTOTEST_ALL_PASS`.
- Input dispatch: 38 headless passes and 40 Xvfb/debug passes, 0 failures;
  desktop debug was confirmed in the Xvfb run.
- Legacy menu launch prompt: 9 passes, 0 failures.
- H1 HUD hierarchy: 10 focused headless passes, 0 failures.
- H2 HUD legibility: 8 focused headless passes, 0 failures.
- H3 HUD scale matrix: 24 headless / 29 Xvfb passes, 0 failures; the effective
  HUD canvas matched the stretched viewport in wide, ultrawide and portrait
  samples.
- H4 HUD state signal probe: 12 focused headless passes, 0 failures; critical
  health, dash cooldown, damage direction and Rootlet shield readiness were
  checked through the live HUD state path.
- H5 HUD layout collision probe: 69 focused headless passes, 0 failures across
  320×568, 432×720, 600×600, 800×600 and 1280×720 layouts.
- H6 overlay/layer probe: 25 focused headless passes, 0 failures; direct
  overlay state, pause, terminal, game-over and Windows watermark transitions
  were checked through the real Arena path.
- H7 dead-widget/affordance probe: 28 focused headless passes, 0 failures;
  dead nodes, device-aware scroll hints and long-banner fade timing were
  checked.
- N1 state-panel navigation probe: 16 focused headless passes and 16 Xvfb
  passes, 0 failures; pause, terminal and game-over focus/activation paths were
  checked with real viewport keyboard dispatch.
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

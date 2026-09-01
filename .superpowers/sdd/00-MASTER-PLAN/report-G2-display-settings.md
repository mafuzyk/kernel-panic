# G2C — Display settings implementation report

## Status

Implemented on `codex/plan-execution`. The legacy Settings route now has a
dedicated DISPLAY section with fullscreen and target-FPS controls. Persistence
is backward-compatible with the previous `feel.target_fps` key.

## Requirement

The approved display contract is fullscreen plus target FPS values `30`, `60`,
`120` and unlimited, with mobile defaulting to 60 and desktop defaulting to
unlimited where supported.

## Before

`Sfx` had a `target_fps` field and setter, but the value lived only under the
legacy `feel.target_fps` persistence key. There was no fullscreen state or
window-mode application and no settings UI section exposing either display
control. Invalid FPS values could be written directly to `Engine.max_fps`.

## After

`Sfx` owns a display settings boundary:

- supported values are exactly `30`, `60`, `120` and `0` internally for
  unlimited;
- new profiles default to 60 when a touchscreen is present or forced and to
  unlimited on desktop/headless-compatible non-touch contexts;
- fullscreen is applied through `DisplayServer.window_set_mode()` and skipped
  safely on the headless display server;
- invalid persisted or setter values fall back to the platform default;
- new values persist under `[display]`, while `feel.target_fps` is still read
  and written as a compatibility key.

The legacy code-drawn Settings panel adds a separate DISPLAY section and cycles
the four target values. The control is a real Godot Button/CheckButton, so it
uses the existing focus and input behavior. The vNext accessibility surface is
not silently expanded here; its final DISPLAY migration belongs to the later
settings promotion gate.

## Files and ownership

- `src/autoload/sfx.gd`: persistence, normalization, platform default and
  window/engine application.
- `src/ui/menu_settings_kit.gd`: DISPLAY section, real controls and labels.
- `tools/g2_display_settings_probe.gd` and `.tscn`: focused settings contract
  and persistence probe.
- `tools/validate_input_dispatch.sh`: registered headless and Xvfb cases.

## Evidence

- Red probe: `/tmp/kernel-panic-g2c-red2.log`, exit `124`; before production
  the probe reported missing display methods/section and stopped without its
  completion marker.
- Headless green: `/tmp/kernel-panic-g2c-green.log`, exit `0`, `13` passes,
  `PROBE_DONE fails=0`.
- Xvfb green: `/tmp/kernel-panic-g2c-xvfb.log`, exit `0`, `13` passes,
  `PROBE_DONE fails=0`; fullscreen calls were exercised against a real window
  display rather than assumed from headless behavior.

The probe verifies methods, separate section source, platform defaults, live
setter state, Engine.max_fps application, dedicated-section reload, legacy-key
read, malformed-value fallback and safe fullscreen persistence.

## Compatibility and risks

- Existing settings files continue to load `feel.target_fps` when no display
  key exists.
- Existing non-display feel settings remain in place.
- Unlimited is represented by the Godot-standard `Engine.max_fps = 0`.
- Fullscreen persistence changes window mode on the next load; headless tests
  safely skip window mutation.
- The default is a platform heuristic based on touchscreen availability, not a
  benchmark. A device with a desktop-class touchscreen will receive the mobile
  default; that is a deliberate conservative choice until device profiles are
  measured.
- The new DISPLAY section is in the current legacy Settings panel. It is not
  proof that the from-scratch vNext Settings route is ready for default
  promotion.

## Second-pass self-review

The implementation was checked for missing-config defaults, malformed ConfigFile
types, legacy migration, unsupported FPS values, unlimited semantics, headless
window calls, persistence of both fields and real Xvfb window application. The
probe passed those cases. Physical mobile defaults, platform-specific fullscreen
behavior on Android/macOS and final UX readability remain unproven.


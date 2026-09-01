# A11/A14 — live accessibility profile and left-handed touch layout

## Status

Implemented and adversarially verified on 2026-09-01 in the isolated
execution worktree. The dedicated vNext Accessibility surface now exposes
three additional controls whose values affect the live game: reduced motion,
reduced flashes, and left-handed touch placement.

This does not claim native screen-reader, OS-level text scaling, or a full
high-contrast theme. Those remain explicitly unavailable instead of being
presented as inert controls.

## Before and after

Before this slice, Sfx persisted four accessibility values and the dedicated
surface also exposed two patch-music preferences. Motion and flash effects did
not share a profile boundary: camera shake/zoom and full-screen flash always
ran when gameplay requested them. Touch controls were permanently arranged
with movement on the left and aim/actions on the right.

After this slice:

- `Sfx` schema version 3 normalizes, persists, snapshots, resets and rolls back
  `reduced_motion`, `reduced_flashes`, and `left_handed_touch` alongside the
  existing profile values.
- Reduced motion suppresses camera trauma, zoom punches and the camera's
  residual shake path. It does not change gameplay timing, hitboxes or damage.
- Reduced flashes suppresses creation of new full-screen flash layers. Rings,
  sparks and other effects remain because they are not all equivalent to a
  flash and need a later, more granular audit.
- Left-handed touch mirrors the movement zone and dash/boost action buttons,
  while preserving the center pause affordance and aim semantics.
- The accessibility surface now has real, focusable controls for all three
  options, with minimum hit targets, semantic state labels, reset behavior and
  overflow/overlap checks on four logical viewports.

## Files and ownership

- `src/autoload/sfx.gd`: versioned profile schema, persistence, normalization,
  rollback and snapshot ownership.
- `src/autoload/fx.gd`: reduced-flash and reduced-motion effect gates.
- `src/arena/camera_rig.gd`: reduced-motion camera guard.
- `src/ui/touch_controls.gd`: mirrored touch geometry and input zones.
- `src/ui/vnext/surfaces/accessibility_surface.gd`: dedicated controls,
  labels, semantics and layout.
- `tools/accessibility_profile_probe.gd/.tscn`: focused live-effect gate.
- `tools/vnext_accessibility_probe.gd`: expanded route, persistence, GUI,
  target-size, overflow and rollback coverage.

## Technical decisions and trade-offs

### Keep native assistive-tech claims explicit

The surface still reports native screen readers, OS text scaling and high
contrast as unavailable. Implementing a label without a real effect would be
worse than a visible limitation: it would give players false confidence.
The next step should be a platform-feasibility spike, not a speculative
toggle.

### Gate effects at shared owners

Motion and flash suppression is implemented in `Fx` and `CameraRig`, where
all existing callers converge. This avoids editing every enemy and player
call site and reduces the chance of one boss or patch effect bypassing the
setting. The trade-off is that some animated effects, such as rings and
shards, still need a separate reduced-motion policy if testing shows they are
problematic.

### Mirror geometry, not player semantics

The touch option changes where a finger begins and where action buttons are
drawn. It does not swap game actions, aim modes, or keyboard bindings. This
keeps save compatibility and avoids making left-handed players learn a second
control vocabulary.

## Evidence

- Initial red probe: `/tmp/a11-red.log` exited non-zero, showing the missing
  profile fields, effect gates and mirrored geometry contract.
- Focused green: `/tmp/a11-green.log` exited 0 with 9 passes and
  `PROBE_DONE fails=0`.
- Dedicated vNext route green: `/tmp/a11-vnext-green.log` exited 0 with
  `PROBE_DONE fails=0`; it covered 11 controls, GUI dispatch once each,
  persistence, malformed values, rollback, targets and four viewports.
- PT-BR localization probe: `/tmp/l10n-green.log` and
  `/tmp/l10n-xvfb.log` exited 0 with `PROBE_DONE fails=0`; the accessibility
  labels, semantic title, and layout fit in both the wide and narrow cases.
- Editor import: `/tmp/a11-import.log`, exit 0; the known Android build-tools
  warning remains environmental.

The full DevHarness was rerun after this slice and the M5 catalog integration
correction: `/tmp/full-after-m5-copy-fix.log` exited 0 with 1455
`AT_PASS`, zero `AT_FAIL`, and `AUTOTEST_ALL_PASS`. A prior run exposed a
real integration regression in the newly added Permission Root bestiary copy;
the copy was shortened to fit the existing bestiary text budget and the
failure disappeared in the fresh rerun.

The full DevHarness was rerun after this slice and the M5 catalog integration
correction: `/tmp/full-after-m5-copy-fix.log` exited 0 with 1455
`AT_PASS`, zero `AT_FAIL`, and `AUTOTEST_ALL_PASS`. A prior run exposed a
real integration regression in the newly added Permission Root bestiary copy;
the copy was shortened to fit the existing bestiary text budget and the
failure disappeared in the fresh rerun.

## Second-pass self-review

The change was checked for profile rollback omissions, old save readability,
duplicate GUI dispatch, narrow target sizes, left-handed button collisions,
camera calls bypassing `Fx`, and flash suppression happening after a layer was
created. The probe catches the current shared boundaries.

Remaining uncertainty: reduced motion does not yet disable every animated
particle/ring/ghost effect, and the legacy settings panel does not expose the
three new options while the vNext settings route remains opt-in. Native
assistive technologies, color-contrast certification, physical devices and
controller remapping remain open release work.

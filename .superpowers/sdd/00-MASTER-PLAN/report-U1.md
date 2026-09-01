# U1 — vNext boot/menu vertical slice

## Status

Accepted only after two independent review passes and controller corrections.
This is an opt-in development surface, not a replacement of the legacy menu.
The legacy route remains the default unless `KP_VNEXT_BOOT=1` is present.

## Scope

U1 establishes the first from-scratch code-drawn UI vertical slice and the
shared contracts that later program, story, patch, HUD, pause, settings and
history surfaces will consume:

- a viewport context with safe area, density, input mode and accessibility
  display flags;
- a single layout calculation whose `Rect2` regions feed drawing, hit testing
  and focus navigation;
- a small navigation object with declared focus order and re-entrancy guard;
- a code-drawn boot surface with a real `Button` for each action;
- opt-in Menu integration with boot routing, root back behavior and resize
  reconfiguration;
- a focused probe using direct contract checks and real viewport input.

The slice deliberately does not migrate the existing menu, alter gameplay, add
localization, or claim that the final visual design is approved. The visual
implementation is a structural/dev surface; detailed visual review remains a
later capture gate.

## Files

Added:

- `src/ui/vnext/ui_context.gd`
- `src/ui/vnext/ui_layout.gd`
- `src/ui/vnext/ui_navigation.gd`
- `src/ui/vnext/surfaces/boot_surface.gd`
- `tools/vnext_boot_probe.gd`
- `tools/vnext_boot_probe.tscn`
- `tools/vnext_menu_probe.gd`
- `tools/vnext_menu_probe.tscn`

Modified:

- `src/ui/menu.gd` — opt-in surface construction, action wiring, resize
  refresh and protection against the legacy `_process` touching nil legacy
  controls in the opt-in path.

Generated Godot `.uid` files and capture `.png.import` files are local import
artifacts and are intentionally not part of the commit.

## Before and after

Before U1, the vNext boot surface had only an exploratory drawing shell. Its
input method always treated ENTER/SPACE as boot, had no real action controls,
reported overflow as hardcoded `fits=true`, and used fixed narrow-layout
coordinates. The opt-in Menu route also returned before constructing legacy
state, while the legacy `_process` continued to access those absent controls.

After U1:

- `VNextUIContext.from_viewport()` derives safe margins through the shared token
  helper, classifies wide/compact/narrow layouts, and carries touch/reduced
  motion/high contrast/text-scale inputs.
- `VNextUILayout.boot()` clamps action widths and derives narrow boot and
  illustration positions from safe-area relationships instead of a fixed
  physical Y coordinate.
- `VNextBootSurface` exposes the surface contract, owns a declared `boot` /
  `back` focus order, and keeps focus-aware ENTER/SPACE/TAB/arrow/ESC behavior.
- The same action regions are used by pointer/touch hit testing and by the
  drawn action frames. Pointer events are normalized from window coordinates
  through the viewport stretch transform before registry lookup.
- Buttons are real focusable Godot `Button` nodes. Their GUI events are tracked
  so the child button does not activate once and then reach the surface/menu
  fallback a second time.
- Text measurement uses the fallback font and current text scale and reports
  measured and available widths for title, subtitle, telemetry, boot and back.
- In the opt-in root route, BOOT calls the existing `Menu._start()` path. BACK
  has explicit behavior: because no previous route exists yet, it exits the
  application rather than presenting a dead control.
- The vNext branch skips legacy `_process` work and subscribes to window resize
  notifications. Reconfiguration is idempotent and can be exercised with an
  explicit viewport size in the probe.

## Test-first and adversarial correction history

The first U1 focused probe was written before production completion and exposed
the missing surface APIs. The first implementation then passed its narrow
contract checks. An independent Luna review rejected that result because the
probe and code still had concrete false-green paths:

1. `handle_input()` could increment an activation counter without executing a
   real Menu action;
2. the action labels were only drawn text, not focusable controls;
3. ENTER always targeted boot instead of the focused action;
4. the navigation helper was not integrated into action dispatch;
5. accessibility context values were not passed through the surface API;
6. overflow was hardcoded and the narrow boot region used a fixed coordinate;
7. resize and lifecycle integration were untested;
8. the Menu opt-in route had no action signal connection.

The controller then strengthened the probe before the corrective production
patch. The first corrective run found a real Godot typed-array failure:
`set_focus_order()` required `Array[String]`, while the literal array inferred
as an untyped `Array`. That was fixed with a typed focus-ID helper.

A second independent Luna review found more issues:

- root BACK emitted an event but did nothing in Menu;
- manual `emit_signal("pressed")` did not prove GUI input;
- menu resize was only superficially asserted;
- `Button.button_pressed` was incorrectly used as focus state;
- the opt-in Menu could still execute legacy `_process` against nil labels;
- real pointer coordinates needed stretch-transform normalization;
- the parent/surface input ownership needed to avoid shadowing child buttons.

The controller added real `Viewport.push_input()` press/release checks,
recorded the Button's GUI event identity to suppress only the later fallback,
removed the toggle-state misuse, made root BACK explicit, added the vNext
process guard, added a resize/reconfigure menu probe, and normalized pointer
coordinates through `get_final_transform().affine_inverse()`.

One intermediate red run proved the test was meaningful: after adding real
input checks, the probe exited 1 because the root Control and stretch transform
caused the input to miss the actual button and keyboard/mouse dispatch could
double or fail. The next correction made that failure disappear for the right
reason, rather than weakening the assertions.

## Evidence

Focused boot probe, final controller run:

```text
env XDG_DATA_HOME=/tmp/kernel-panic-u1-real-input4-20260901 \
  godot --headless --audio-driver Dummy --path . \
  res://tools/vnext_boot_probe.tscn
```

- exit `0`;
- `PROBE_DONE fails=0`;
- three viewport sizes: `1366×768`, `720×720`, `432×720`;
- action targets are at least 44 logical pixels and enclosed by the safe rect;
- measured text reports fit for all checked entries;
- context carries touch, reduced-motion, high-contrast and text-scale values;
- focused ENTER dispatches BACK rather than silently redirecting to BOOT;
- TAB follows declared focus order;
- the real Button receives focus;
- real viewport ENTER, mouse press/release and screen-touch press/release each
  cause exactly one action and one Button press event.

Menu integration probe:

```text
env KP_VNEXT_BOOT=1 XDG_DATA_HOME=/tmp/kernel-panic-u1-menu5-20260901 \
  godot --headless --audio-driver Dummy --path . \
  res://tools/vnext_menu_probe.tscn
```

- exit `0`;
- `PROBE_DONE fails=0`;
- Menu creates the opt-in surface and real BOOT control;
- a simulated `432×720` reconfiguration recomputes its safe area, preserves
  default focus and keeps the boot action within safe width;
- real focused ENTER produces exactly one `boot` action and changes
  `Game.state` to `PLAYING` through the existing Menu callback.

The full regression suite after the U1 corrections:

```text
env XDG_DATA_HOME=/tmp/kernel-panic-u1-full-20260901 \
  godot --headless --audio-driver Dummy --path . -- --autotest
```

- exit `0`;
- `1414` `AT_PASS`;
- `0` `AT_FAIL`;
- `AUTOTEST_ALL_PASS` present.

`git diff --check` is clean. The focused probes emit no script errors. The
full suite still reports the known baseline teardown diagnostics: 8 resources,
3 physics RIDs, 14 dummy textures, 147 shaped-text allocations and 2 advanced
fonts, plus 10 CanvasItem RID and 171 ObjectDB warnings. U1 does not claim to
fix those diagnostics.

## Decisions and trade-offs

### Opt-in route instead of replacing the legacy menu

The user wants a from-scratch UI, but a complete replacement before the new
flow has program/story/settings coverage would create an untestable gap. The
opt-in environment route keeps rollback immediate and makes the vertical slice
observable without changing the default game. The trade-off is temporary
duplicate routes and an explicit follow-up gate before promotion.

### Real Buttons plus code-drawn frames

The visual shell remains code-drawn, but action semantics belong to Godot
Controls. This avoids fake buttons that only respond to a custom handler and
gives keyboard focus and pointer/touch dispatch a native target. The trade-off
is a small layer of transparent Controls whose geometry must stay synchronized
with the drawn frames; the action registry and layout are the synchronization
source.

### Root BACK exits in the dev slice

There is no previous vNext route to pop yet. Leaving BACK as a no-op would be a
misleading affordance, so the explicit temporary root behavior is application
exit. This is suitable for the opt-in development root but must be revisited
when a real route stack exists; future surfaces should pop a route and only
exit from an explicit root/quit action.

### Pointer normalization at the surface boundary

The project uses stretch transforms. Registry rectangles live in logical
viewport space while raw pushed/window pointer coordinates can be in window
space. Normalizing once at `_action_at()` keeps drawing, hit testing and the
probe aligned. The trade-off is that callers of `handle_input()` must provide
normal input-event coordinates, not pre-normalized logical positions; the probe
now follows that contract.

### Re-entrancy guard

The navigation object rejects nested dispatch while an action is being handled
and schedules a deferred cleanup as a safety net. GDScript has no general
exception/finally mechanism, so this is not a proof against every possible
native/runtime abort. Current callbacks are synchronous and the focused tests
prove normal dispatch returns unlocked. A future coordinator should own
transaction state rather than relying on arbitrary callbacks.

## Compatibility, performance and UX impact

- Default legacy Menu behavior is unchanged unless `KP_VNEXT_BOOT=1` is set.
- No save key, input binding, gameplay state, content value, or scene route was
  changed for the default path.
- The vNext surface adds two Controls and one illustration; no per-frame
  animation or timer was introduced. The opt-in Menu skips legacy animation
  processing, which offsets some of that cost.
- Touch targets meet the 44-pixel logical floor in the tested viewports.
- Text scale is carried into the surface and button font size, but the current
  boot layout has not been certified at every scale up to the context's future
  clamp. Larger-scale and translated-content gates belong to localization and
  accessibility tasks.
- Native screen-reader semantics, controller navigation, hybrid input-mode
  detection and persistent accessibility preferences are not implemented by
  U1. The context API is groundwork, not a completed accessibility feature.
- No final visual approval is claimed. Captures, grayscale legibility and
  comparison against the Ideas moodboard remain later gates.

## Follow-up gates

Before promoting vNext or deleting legacy Menu code, require:

- program/story selection and route-stack behavior;
- patch decision and combat HUD consumers of the snapshot contracts;
- persistent accessibility settings and locale-aware layout;
- mobile safe-area and touch-device validation beyond synthetic events;
- visual captures at wide/compact/narrow sizes, including grayscale review;
- duplicate-action, rapid route replacement and queued-signal lifecycle probes;
- a fresh full suite and a review of the baseline teardown diagnostics.

# U2 — vNext program and story selection

## Status

Accepted on 2026-09-01 after controller corrections, focused red/green
probes, a fresh full regression run, and three independent Luna review passes.
The route is still behind the explicit `KP_VNEXT_BOOT=1` development switch;
the legacy menu remains the default and no user save or gameplay route was
replaced.

## Scope and intent

U2 turns the exploratory vNext shell into two usable selection surfaces:

- program selection: a process list, readable identity/detail information,
  code-drawn program illustration, explicit locked state, and a real launch
  action;
- story selection: act tabs, stage list, locked/ready/cleared state, readable
  briefing, and a real mount action;
- narrow composition: list and detail are separate readable states instead of
  forcing two desktop columns or a map into a phone-sized viewport;
- one action contract for keyboard, native Godot buttons, pointer hit testing,
  touch hit testing, focus, and route callbacks;
- overflow and target-size evidence for wide, compact, and narrow logical
  viewports;
- extension of the U1 boot surface with PROGRAMS and STORY routes.

This is a structural migration slice, not final art approval. It intentionally
does not implement patch decisions (U2b), localization, persisted
accessibility settings, a complete route stack, gameplay changes, or deletion
of the legacy screens.

## Files and commits

Production:

- `src/ui/menu.gd` — opt-in route construction for boot, program and story
  surfaces; existing Menu start/story callbacks remain the gameplay boundary.
- `src/ui/vnext/surfaces/boot_surface.gd` — project typography, real secondary
  route controls, and complete action overflow coverage.
- `src/ui/vnext/surfaces/program_surface.gd` — new program selection surface,
  selection/detail state machine, native controls, code-drawn detail and
  entity illustration.
- `src/ui/vnext/surfaces/story_surface.gd` — new story selection surface, act
  tabs, stage state projection, list/briefing state machine and native
  controls.
- `src/ui/vnext/ui_layout.gd` — boot secondary route geometry for all density
  classes.

Tests:

- `tools/vnext_selection_probe.gd` — contract, responsive, overflow, locked
  state, keyboard, direct pointer/touch, native Button ENTER and narrow
  list/detail checks.
- `tools/vnext_menu_probe.gd` — opt-in Menu route transitions, real Button
  BACK dispatch, fall-through protection, resize and BOOT integration.
- `tools/vnext_boot_probe.gd` — boot typography/action coverage, complete
  overflow registry, target sizes and real input checks.

Focused commits:

- `018b1b7` — initial red selection-surface probe;
- `35a8671` — hardened selection and Menu integration evidence;
- `e7628bb` — boot typography and overflow evidence;
- `d1b1db8` — production program/story routes and boot extension.

The commits are intentionally separate by concern. Generated `.uid` files and
capture `.png.import` files remain local import artifacts and were not staged.

## Before and after

### Before

The vNext U1 slice could display and operate only a root boot surface. The
existing menu still owned program/story choices. There was no vNext selection
surface, no explicit list/detail contract, no selection semantic snapshot, and
no proof that a child Button could not activate once and then reach a parent
fallback handler.

The U1 boot surface had already grown PROGRAMS and STORY route buttons during
the U2 integration work, but its earlier typography and overflow contract had
not been updated for those new controls.

### After

`VNextProgramSurface` now:

- projects the existing `Game.PROGRAM_DEFS` and unlock state without moving
  gameplay ownership into UI;
- exposes `layout_snapshot()`, `action_regions()`,
  `text_overflow_report()`, `semantic_snapshot()`, `set_focus_id()`,
  `focus_id()`, `handle_input()` and `action_requested`;
- keeps list and detail visible together on wide/compact compositions;
- uses a narrow list state and a narrow detail state, with a deliberate
  `ListAction` to return from detail;
- makes an unlocked program selection distinct from launching it;
- rejects locked selection launch attempts without emitting a route action;
- uses Orbitron for title/detail identity and ShareTechMono for body/control
  text, plus a code-drawn `VNextEntityIllustration` for the selected program;
- derives pointer regions from the same logical layout/control geometry used by
  the surface rather than from unrelated constants.

`VNextStorySurface` now:

- projects the existing StoryData/Game stage catalog, act tabs and stage
  states; it does not duplicate stage definitions;
- exposes real act/stage/launch/back/list controls and an action signal;
- keeps act tabs at a 48 logical-pixel target height;
- uses a narrow stage-list state and a narrow briefing state, rather than
  rendering a compressed desktop map;
- presents locked stages as explicit `LOCKED // CLEAR PREVIOUS NODE` states;
- separates choosing a stage from mounting it;
- wraps and measures the actual identity/path/briefing/status/best content;
- uses the project fonts and preserves the code-drawn shell.

The boot surface now:

- exposes PROGRAMS and STORY as real secondary Buttons;
- routes them through Menu to the two new surfaces;
- measures title, subtitle, telemetry, boot, program, story and back text using
  the actual project fonts;
- keeps the explicit development switch and legacy default path unchanged.

## Input and lifecycle contract

The surface owns semantic action dispatch. Native Buttons own concrete GUI
activation. Each Button reports the input-event instance it received through
`gui_input`; the surface consumes that same event in `_unhandled_input` so the
Menu fallback cannot dispatch it a second time. Custom keyboard, mouse and
touch handling is used only when no child Button already owns the event.

The route callback remains in `Menu`:

- `program` constructs the program surface;
- `story` constructs the story surface;
- `launch_program` calls the existing `Game.set_program()` then existing
  `_start()` path;
- `launch_story` calls the existing `_start_story(index)` path;
- `back` returns child surfaces to boot, while root boot keeps the temporary U1
  exit behavior.

Outgoing surfaces are `queue_free()`d before the new surface is added. The
probe confirms that a real child BACK does not fall through and start BOOT.
There is not yet a general route-stack/transition coordinator; that remains a
future U4/U6 lifecycle task.

## Test-first and adversarial correction history

### 1. Initial selection probe

The initial U2 probe was committed as `018b1b7`. It proved basic surface
contracts, selection, locked states, launch, viewport ENTER, direct pointer and
touch handling, and three viewport sizes. It did not yet prove enough native
Menu integration.

### 2. False-green Menu BACK path

The initial Menu probe invoked the surface handler directly for some routes.
That could pass while a real child Button still allowed a parent fallback to
run. The controller added a real focused `BackAction` Button press/release
through `Viewport.push_input()`, recorded both the Button `pressed` event and
the route signal, and asserted exactly one of each. The pre-fix run failed:

```text
PROBE_FAIL program real back is owned by Button
```

The production event-ownership gate and the hardened probe were committed in
`35a8671`. The follow-up also asserts that program/story BACK leaves
`Game.state == MENU`, proving it cannot fall through into BOOT.

### 3. Focus-order omission

The initial story focus order omitted the act tabs. A controller-added red
assertion could not focus `act_windows` and the act did not update via ENTER.
The surface now registers act tabs in `_buttons`, includes them in the focus
order, and rebuilds the stage portion around the active act. The corrected
probe passes keyboard act selection.

### 4. Responsive false green

The first surface implementation rendered both program/story list and detail
content simultaneously in the narrow layout. The independent review identified
that story content could be clipped or collide with its launch action, and the
probe did not inspect all drawn text. The controller added red assertions for
mutually exclusive narrow view states, launch visibility, complete overflow
reports and all action labels. The production surfaces now use explicit
`list_view`/`detail` state transitions and the narrow layouts reuse the same
readable content area without overlap in the active state.

The tests intentionally do not claim that the list and detail rectangles have
different coordinates: they are two mutually exclusive uses of the same
screen area. The evidence is visibility/state exclusivity and the active
content overflow report, which matches the intended mobile composition.

### 5. Typography and boot overflow gap

The second independent review found that U2 had extended U1 with two new boot
buttons but had not migrated the boot surface's text rendering and measurement
from `ThemeDB.fallback_font`. It also did not report PROGRAMS/STORY entries.
The controller changed the boot surface to use Orbitron and ShareTechMono,
added all seven action/text entries to the report, and added probe assertions
for coverage plus the Button font override. The final boot probe passes at all
three viewports.

### 6. Review claim checked and rejected

One intermediate review claimed the program launch color was inverted. Direct
inspection showed the condition was already `ready if not launch.disabled else
muted`, which is the correct enabled/disabled mapping. The focused probe also
asserts the enabled Button's resolved color is the ready token. No unnecessary
production change was made for that claim.

## Evidence

### Focused boot probe

```text
env XDG_DATA_HOME=/tmp/kernel-panic-u2-boot-final-20260901 \
  godot --headless --audio-driver Dummy --path . \
  res://tools/vnext_boot_probe.tscn
```

Result: exit `0`, `PROBE_DONE fails=0`.

Coverage includes `1366×768`, `720×720` and `432×720`; safe-area
containment; 44-pixel boot target; complete text-entry coverage; actual
ShareTechMono Button override; semantic markers; focus/TAB/ENTER; and real
viewport keyboard, mouse and touch activation with exactly-one checks.

### Focused selection probe

```text
env XDG_DATA_HOME=/tmp/kernel-panic-u2-selection-final2-20260901 \
  godot --headless --audio-driver Dummy --path . \
  res://tools/vnext_selection_probe.tscn
```

Result: exit `0`, `PROBE_DONE fails=0`.

Coverage includes both surfaces at all three viewport sizes, safe-area action
containment, complete active-state overflow reports, project fonts, locked
state rejection, separate selection/launch actions, focus navigation, native
Button ENTER dispatch, direct pointer/touch dispatch, act switching, and
narrow list↔detail transitions with visibility gates.

### Focused Menu integration probe

```text
KP_VNEXT_BOOT=1 \
XDG_DATA_HOME=/tmp/kernel-panic-u2-menu-final2-20260901 \
  godot --headless --audio-driver Dummy --path . \
  res://tools/vnext_menu_probe.tscn
```

Result: exit `0`, `PROBE_DONE fails=0`.

Coverage includes opt-in construction, real program BACK, real Button ownership,
child BACK return to boot, no fall-through into BOOT, story route return,
resize/reconfiguration, safe width and one real boot activation.

### Existing layout probe

```text
env XDG_DATA_HOME=/tmp/kernel-panic-u2-layout-final-20260901 \
  godot --headless --audio-driver Dummy --path . \
  res://tools/layout_probe.tscn
```

Result: exit `0`, `PROBE_RESULT passes=130 fails=0`.

This confirms that the pre-existing menu layout work remained intact; it is not
being presented as a visual approval of the new vNext surfaces.

### Full regression suite

```text
XDG_DATA_HOME=/tmp/kernel-panic-u2-full-final-20260901 \
  godot --headless --audio-driver Dummy --path . -- --autotest
```

Result: exit `0`, `1414` `AT_PASS`, `0` `AT_FAIL`, and
`AUTOTEST_ALL_PASS`.

The process still prints the W0 teardown diagnostics: 10 CanvasItem RID and
171 ObjectDB warnings, plus 8 resources, 3 physics RIDs, 14 dummy textures,
147 shaped-text allocations and 2 advanced-font allocations at exit. These
diagnostics match the recorded baseline category and are not claimed as fixed
by U2. Focused menu/surface probes also print teardown diagnostics; their
functional markers remain green.

Import verification after the changes exited `0`; the known environment
warning about the unavailable Android build-tools directory did not change.
`git diff --check` is clean.

## Decisions and alternatives

### Narrow list/detail state instead of a compressed two-column layout

Chosen because the plan explicitly rejects forcing desktop composition into a
phone viewport and because the independent review found the simultaneous
story layout could clip content. The list and detail intentionally reuse the
same logical panel area, with real controls determining which state is active.

Rejected: keeping both columns and merely shrinking fonts. That would preserve
the geometry while sacrificing reading, touch target size and hierarchy.

Trade-off: one extra activation (`select`, then `mount`) on narrow screens and
one extra `ListAction`. This is acceptable because it keeps the consequence
visible before launch and provides an explicit way back without leaving the
route.

### Native Buttons plus code-drawn presentation

Chosen because drawn labels alone cannot reliably provide focus, pointer/touch
ownership or accessibility affordances. The Buttons are intentionally visually
light and the shell remains `_draw()`-based, matching the from-scratch code
drawn direction.

Rejected: making the surfaces entirely custom-input with no native Controls.
That would duplicate focus/activation semantics and recreate the exact class of
false-green input bugs U1 uncovered.

### Existing Game/StoryData as providers

Chosen to avoid a second authority for unlocks, stage order, program identity,
rewards or balance. The UI consumes snapshots and emits commands; Menu/Game
still owns mutation and starting a run.

Rejected: copying program/stage definitions into the surface. That would make
localization, balance and save compatibility drift likely.

### Project fonts loaded directly in the vNext surface

Chosen because AGENTS.md requires Orbitron titles and ShareTechMono body/UI,
and direct preloads make the rendering and measurement use the same known
resources. The fallback font remains suitable only for unrelated legacy code
or as a later failure fallback; U2 does not rely on it for these surfaces.

### Opt-in route retained

Chosen because the final UI is intentionally being rebuilt from scratch and
must not replace the playable legacy route before U2b–U6, localization,
accessibility, visual review, and rollback gates exist.

Rejected: replacing the default menu now. That would make an incomplete slice
the only route and would make regressions harder to attribute.

## Compatibility, UX, performance and API impact

- Default behavior is unchanged unless `KP_VNEXT_BOOT=1` is set.
- Existing save keys, Game state, story progression, program unlocks, balance,
  input bindings and launch callbacks are unchanged.
- The new surfaces add native Controls and one existing code-drawn entity
  illustration. No gameplay node, physics body, per-frame timer or animation
  loop is added by U2.
- U2 adds a small route construction cost only in the opt-in path. The opt-in
  Menu already skips legacy `_process` work, and the surfaces do not perform
  continuous polling.
- Keyboard users receive declared focus order and ENTER/SPACE/TAB/arrow
  actions; pointer/touch users receive logical action regions and native
  controls. Full remapping and screen-reader semantics remain future work.
- Narrow users receive staged content and a readable briefing action instead
  of a compressed desktop map. Desktop retains list/detail side-by-side.
- The new surface API is development-facing and not a public mod/plugin API.
  Its names are documented in the probe and may evolve before migration.
- No breaking change is introduced to the default game path.

## Known issues and uncertainties

1. **No final visual acceptance yet.** No grayscale/clean-layer/finish-layer
   capture has been approved. The Ideas references remain design material, not
   runtime backgrounds or acceptance screenshots.
2. **Localization is not implemented.** The overflow contract is exercised in
   English at scale `1.15`; PT-BR and long translated strings require L2/L3/L4
   coverage.
3. **Accessibility persistence is not implemented.** Context carries reduced
   motion/high contrast/text scale, but settings storage, dedicated tabs,
   remapping, and native screen-reader support belong to A11–A15/U5.
4. **Route stack/transition cancellation is incomplete.** The direct route
   replacement is safe for the tested normal paths and rejects observed
   fall-through, but rapid replacement with queued/deferred actions needs U6
   lifecycle coverage.
5. **Pointer/touch surface coverage is partly direct.** U2 proves direct
   logical dispatch plus real Button keyboard activation; real physical
   pointer/touch on these child selection Buttons should receive a dedicated
   device/viewport playtest before promotion.
6. **Teardown diagnostics remain open.** Functional green does not mean clean
   process teardown. They are tracked from W0 and must be addressed under
   performance/reliability tasks with before/after evidence.
7. **Android export remains unproven.** The import warning about missing
   Android build-tools was present before U2 and is not an Android support
   claim.

## Acceptance decision

U2 is accepted as an opt-in structural slice because the required behavior is
covered by focused red/green probes, the independent review accepted the final
state, the existing layout probe remains green, and the full functional suite
remains green. It is not accepted as permission to remove legacy Menu code or
as final visual/mobile/accessibility approval.

Next task: U2b patch offer/build decision surface. It must preserve the same
snapshot/action/overflow discipline and add explicit confirm, skip, close,
conflict preview, resize and paused-overlay recovery evidence.

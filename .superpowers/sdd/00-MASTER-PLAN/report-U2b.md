# U2b — vNext patch/build decision surface

Status: accepted after controller correction and an independent Luna review.
Date: 2026-09-01.

## Scope

U2b adds the first from-scratch patch-offer surface behind the explicit
`KP_VNEXT_PATCH=1` opt-in. The legacy `PatchCard` route remains the default.
The surface is a decision view, not a second gameplay controller: Arena owns
the live offer and pause lifecycle, while the surface receives a deep-copied
snapshot and emits `confirm`, `skip`, or `close` commands.

## Initial implementation and rejected evidence

The first implementation added a code-drawn surface and a small probe, but its
green result was not accepted. Independent review found that it showed only
one offer on desktop, did not integrate with Arena, reported every action as
ready, omitted decision fields, allowed keyboard confirmation of an empty
offer, overlapped narrow footer controls, did not reflow on a real resize, and
did not prove GUI/unhandled input ownership. Its conflict assertion was also
invalid: `NO DIRECT INTERACTION` was treated as a positive conflict.

The controller then strengthened the tests before accepting the code. The
second review initially rejected the partial correction for weak content
projection, missing propagation of explicit locked data, unproved real input,
and incomplete retry/lifecycle evidence. Those findings caused another
correction rather than a weaker test.

## Changes

### `src/ui/vnext/surfaces/patch_surface.gd`

- Rebuilt the surface around a normalized, deep-copied offer snapshot.
- Keeps identity, description/effect, level/max, rarity, cost/benefit,
  relation, build impact, availability and reason in the view model.
- Uses project Orbitron and ShareTechMono fonts and the shared token palette.
- Renders all offers in parallel on desktop and one selected offer on narrow
  layouts. Narrow navigation is explicit and uses 44px targets.
- Adds real native `Button` controls as the focus/activation owners over the
  code-drawn card and command rail.
- Uses one action registry for focus, pointer/touch hit testing, semantics and
  overflow checks.
- Distinguishes `ready`, `conflict`, `locked` and `unavailable`. A tradeoff is
  a warning in the current game and remains selectable; only locked or
  unavailable offers disable confirmation. This preserves the existing
  heavy+splitshot gameplay rule instead of inventing a new balance rule.
- Rejects empty offers, unavailable confirmation, invalid indices and repeated
  terminal commands. `reject_action()` reopens the command gate if a live
  adapter rejects a stale payload.
- Reflows through `reflow_for_viewport()` and `NOTIFICATION_RESIZED`.
- Measures title, all displayed decision fields, visible cards and command
  labels. Long content is reported as unsafe rather than falsely marked as
  fitting; arbitrary future translations still need a content-budget gate.

### `src/arena/arena.gd`

- Adds an opt-in vNext patch surface in a process-always CanvasLayer. The
  legacy panel is untouched when `KP_VNEXT_PATCH` is absent.
- Projects current offers into a presentation snapshot without mutating
  `Game.patch_levels`. Explicit presentation fields and locked/reason state
  survive the projection; current-game builds also receive a deterministic
  before/after patch-code preview.
- Validates the returned index and offer identity before calling the existing
  `Game.apply_patch()` path.
- Adds explicit close/skip handling that resumes the frozen Arena and defers
  any queued next offer to avoid reentrant lifecycle work.
- Adds negative-index rejection to `_pick_patch()` and narrow adapter input
  routing.

### `src/arena/panel_kit.gd`

- Keeps ESC consumed while the legacy patch is open.
- Routes ESC to close the vNext patch surface and lets other paused events
  reach its own input contract.

### Probes and validator

- `tools/vnext_patch_probe.gd` now covers real decision fields, conflict
  semantics, desktop parallel cards, narrow navigation, non-overlap, safe
  area, scaled text, deep-copy isolation, empty/locked states, retry after
  rejection, pointer/touch geometry and GUI duplicate suppression.
- `tools/vnext_patch_arena_probe.gd` exercises a real Arena instance with
  `Viewport.push_input`: open, pause, ESC close, reopen, skip, reopen and
  confirm. Confirmation is checked to apply exactly one patch.
- `tools/validate_input_dispatch.sh` includes both focused probes; the Arena
  probe is explicitly run with `KP_VNEXT_PATCH=1`.

## Before / after behavior

Before, the new surface was isolated from Arena and its probe could pass while
the playable patch path still used the old three-card overlay. The surface
also could emit a confirm command with no offer and presented no meaningful
build consequence.

After, the default remains the old route, while the opt-in route freezes the
real Arena, shows all current offers with their decision data, supports a
single readable narrow card, and has one validated command path. Skip/close
leave patch levels unchanged and resume play. Confirm validates identity and
applies one existing patch through Arena. Conflict is visible as a warning;
locked/unavailable offers are explicit and non-confirmable.

## Decisions and alternatives

1. **Opt-in integration.** The legacy route stays default until visual and
   platform gates pass. A permanent replacement now would make a partially
   reviewed surface the production UI; a test-only surface would provide no
   integration evidence. The reversible environment gate is the smallest safe
   seam.
2. **Arena adapter owns mutation.** The surface never calls
   `Game.apply_patch()` or pauses the tree. Moving that responsibility into
   the surface would duplicate gameplay ownership and make scene teardown
   unsafe.
3. **Conflict is a warning.** `PATCH_RELATIONS` currently documents a
   tradeoff, not a lock. Disabling it would change balance without a user
   decision or gameplay requirement. The UI therefore exposes the consequence
   and keeps the already-valid choice available.
4. **Before/after build preview is derived without mutation.** A hypothetical
   level map is copied locally and formatted with existing patch codes. A
   temporary `Game.apply_patch()` followed by rollback was rejected because
   signals and gameplay side effects would make preview impure.
5. **Long text is detected, not silently shrunk.** Shrinking below the global
   readability floor or truncating a decision description would hide a
   consequence. The report intentionally fails for oversized injected text;
   localization/content-budget work must resolve those cases before shipping.

## Evidence

The controller-fresh focused runs used the silent Dummy audio driver:

```text
env XDG_DATA_HOME=/tmp/kernel-panic-u2b-green-surface4-20260901 \
  godot --headless --audio-driver Dummy --path . \
  res://tools/vnext_patch_probe.tscn
exit 0; PROBE_DONE fails=0

KP_VNEXT_PATCH=1 XDG_DATA_HOME=/tmp/kernel-panic-u2b-green-arena11-20260901 \
  godot --headless --audio-driver Dummy --path . \
  res://tools/vnext_patch_arena_probe.tscn
exit 0; PROBE_DONE fails=0
```

The focused results include real Arena input for ESC, Skip and Confirm. The
full suite was re-run after the surface and adapter changes and retained its
existing `1414 AT_PASS`, `0 AT_FAIL`, `AUTOTEST_ALL_PASS` contract. The run
still reports the known teardown diagnostics from W0; those are not claimed
as fixed by U2b. `git diff --check` is clean.

## Compatibility, performance and UX impact

- No default route, save key, patch balance value, public `Game` API or legacy
  `PatchCard` behavior changes when the opt-in flag is absent.
- The vNext surface adds a small number of Buttons and one code-drawn overlay
  only while an offer is open. It does not add per-frame gameplay work.
- Keyboard, native GUI, pointer and touch all share the same semantic command
  gate. The paused simulation remains frozen.
- The surface uses more explanatory text than the old card, so localized and
  high-scale content needs a stricter budget before release.

## Known limitations

- No final visual capture or user art-direction approval was performed.
- Long arbitrary content is detected and reported but has no scrollable
  decision-card treatment yet; current English catalog strings fit the tested
  scale/layouts.
- PT-BR, persisted accessibility preferences, physical-device touch and
  Android export are future plan work.
- Godot still reports baseline exit-time resource/RID/ObjectDB diagnostics;
  the Arena probe also reports them because it creates a live Arena directly.
- The opt-in flag is a development seam, not a release configuration.

## Acceptance

U2b is accepted after the independent Luna reviewer verified the focused
surface and Arena probes, current conflict semantics, explicit state/data
projection, input ownership, lifecycle retry, responsive geometry, and the
legacy default path. The next plan task is U3 combat HUD; U2b must remain
available as an opt-in regression surface while later UI work proceeds.

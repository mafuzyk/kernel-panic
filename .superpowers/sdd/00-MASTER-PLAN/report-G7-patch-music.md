# G7 — Desktop patch music layers

## Status

Implemented on `codex/plan-execution` as a desktop-only feedback layer. The
existing synchronized A/B/C music beds are preserved: combat intensity still
controls the original B/C escalation, while selected patch categories can add
the same beds at a lower presentation layer. A and B/C are crossfaded through
the existing `Sfx` owner; no new audio files or gameplay values were added.

## Decision and alternatives

The chosen mapping is deliberately small and reversible:

- offensive patches (`rapid`, `heavy`, `core`, `ricochet`, `pdash`, `staticf`,
  `splitshot`, `turbo`, `chain`) request the percussion/B stem;
- defensive patches (`hp`, `restore`, `shield`, `absorb`, `vampic`,
  `recycler`, `dataleech`, `secondwind`, `thorns`, `scrapdiet`) request the
  bass/C stem;
- neutral patches do not change the music bed;
- combat intensity wins as an additive requirement, so a boss or overclock can
  still enable a stem even when a patch-layer preference is disabled;
- patch transitions use a 0.5 second crossfade, while the pre-existing combat
  intensity transition remains 0.9 seconds.

This reuses the already synchronized, looped stems instead of introducing a
second asset pipeline or an unmeasured mixer graph. A new three-stem patch
asset set was rejected until the current audio identity has human approval.
Per-patch bespoke motifs were also rejected: they would increase authoring,
mixing and localization/test surface without being required to prove the
feedback idea.

Patch music is supported only on a non-headless, non-touch display. Mobile and
headless paths keep the existing simpler audio behavior; the patch layer is
silent there, while normal combat intensity remains unchanged. This is a
presentation choice, not a gameplay or record-policy branch.

## Before and after

Before, `Game.apply_patch()` changed only gameplay state and emitted
`patch_picked`. `Sfx` knew only about the combat intensity level, so the sound
of a build did not communicate whether the player had entered an offensive or
defensive direction. Accessibility toggles were limited to color assist,
haptics, shake and touch size.

After, `Game` remains the sole owner of patch levels and refreshes Sfx after a
real patch is applied. Sfx derives the two presentation requests from the
static catalog, gates them by device capability, crossfades B/C and exposes a
snapshot for diagnostics. Both legacy Settings and the vNext Accessibility
surface expose independent `PATCH PERCUSSION` and `PATCH BASS` preferences.
The preferences are additive to the existing settings file and default on.

The same change corrected a related profile bug: applying a partial
accessibility update previously normalized omitted values against defaults,
which could silently reset the other profile controls. Partial updates now
merge with the live profile before normalization; a failed save restores all
changed values, including the music-layer flags.

## Files and ownership

- `src/data/content_catalog.gd`: authoritative offensive/defensive patch
  presentation groups and copy-returning accessor.
- `src/autoload/sfx.gd`: desktop capability gate, target calculation,
  crossfade ownership, persistence, profile transaction and snapshots.
- `src/autoload/game.gd`: refreshes patch music at run start, patch selection
  and return-to-menu boundaries.
- `src/ui/menu_settings_kit.gd`: legacy accessibility controls.
- `src/ui/vnext/surfaces/accessibility_surface.gd`: vNext controls, semantic
  states, focus order and responsive layout/overflow coverage.
- `tools/g7_patch_music_probe.gd/.tscn`: red/green probe for source contracts,
  real Game-to-Sfx routing, headless/mobile gating, X11 audibility,
  independent toggles, persistence and partial-profile safety.
- `tools/vnext_accessibility_probe.gd`: extended existing surface probe to
  cover the two new controls at all existing test viewports.

## Compatibility and impact

- Existing `audio`, `feel`, display and progress save keys remain readable.
  New keys live under `[accessibility]` and default to enabled when absent.
- The accessibility snapshot retains its four-key `profile` shape for current
  consumers; music flags are additive top-level fields and in `music_layers`.
- No gameplay damage, spawn, RNG, score, record, story or patch effect changed.
- No audio asset, stream duration, loop point or existing combat intensity
  rule changed.
- The patch-layer map is catalog-owned and does not put gameplay numbers in
  UI code.
- A failed settings write does not leave a changed layer toggle in memory.

## Evidence

- Red probe: `/tmp/g7-red.log`, exit 1 with 10 expected missing contracts and
  `PROBE_DONE fails=10`.
- Headless green: `/tmp/g7-green-headless3.log`, exit 0 with 23 passes,
  `patch_music_supported=false` and `PROBE_DONE fails=0`. It proves the
  mobile/headless-safe path, Game routing, settings persistence and profile
  merge without playing user audio.
- X11/Xvfb green: `/tmp/g7-green-xvfb.log`, exit 0 with 23 passes,
  `patch_music_supported=true` on Mesa llvmpipe. It proves B becomes audible
  for an offensive patch, C becomes audible for a defensive patch, and both
  return to silence when disabled.
- Accessibility regression: `/tmp/g7-access-headless2.log`, exit 0 with all
  existing profile, input, six-control dispatch, overflow and four viewport
  region checks passing under `KP_VNEXT_SETTINGS=1`.
- `--audio-driver Dummy` was used for every run. No audio was emitted to the
  physical device.

## Second-pass self-review

The implementation was reviewed for the main failure modes: patch state
leaking across restart/menu, intensity being disabled by the new layer, a
touch/headless path accidentally enabling desktop mixing, overlapping tweens,
failed-save drift, old profile shape breakage, and accessibility controls
falling outside narrow layouts. Tweens are killed per stem before a new
transition; Game clears the patch layer at each run/menu boundary; the old
profile dictionary remains four keys; and real narrow-layout probes pass.

Remaining uncertainty is perceptual: the mapping and mix levels are
structurally proven but have not been approved by a human listener on the
intended PC speakers/headphones. This must remain a release-candidate review
item. The patch layer also reuses combat B/C beds by design; if that feels too
similar to intensity, the next change should be a measured audio-design
decision, not a silent asset expansion.

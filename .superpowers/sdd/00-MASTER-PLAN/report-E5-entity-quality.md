# E5 — Code-drawn finish tiers, mobile variant and sprite gate

## Executive result

E5 is complete on `codex/plan-execution`. The shared code-drawn entity
renderer now has an explicit quality contract instead of making every caller
implicitly pay for the same cosmetic finish work. Desktop keeps the optional
finish accents; the mobile tier removes those accents while preserving the
glyph, facing line, state marker and elite marker; reduced motion freezes the
cosmetic phase without removing the state channel.

The contract is applied to the vNext boot and program previews. The legacy
enemy combat `_draw()` implementations were intentionally not rewritten in
this slice: they still use their existing `draw_enemy()` compatibility path,
and routing every legacy effect through the new profile needs its own review
because it can affect dense-wave cost and visual balance. No raster candidate
was proposed or enabled. The sprite registry remains author-gated and
disabled by default.

Implementation commits:

- `655a7d3` — `feat: add code-drawn quality tiers`
- `7865f2c` — `fix: normalize malformed entity quality flags`
- `5a88d01` — `feat: route entity quality through vnext previews`

Documentation and handoff are committed separately after the final validation
record is updated.

## Requirement mapping

| Requirement | Result | Evidence |
| --- | --- | --- |
| Desktop/mobile quality distinction | Explicit normalized `desktop` and `mobile` profiles | E5 focused probe |
| Mobile finish reduction | Mobile finish plan is disabled (`segments=0`) | E5 focused probe |
| Reduced-motion behavior | Cosmetic phase is fixed at `0.0`; structural marks remain | E5 focused probe and actual draw callback |
| Identity/state preservation | Descriptor/glyph, facing, state and elite channels remain available | Renderer contract checks |
| Accessibility flags | High contrast, color assist and grayscale survive normalization | E5 focused probe |
| Malformed settings safety | Boolean-like strings/numbers normalize predictably | E5 focused probe |
| Real render-path measurement | Ten snapshots pass through a real `CanvasItem._draw()` callback | Headless/Xvfb timing output |
| Gameplay isolation | RNG, score and probe-owned gameplay values remain unchanged | E5 focused probe |
| Raster policy | No new image asset and registry still disabled | E5 focused probe and code inspection |
| vNext preview integration | Boot and Program illustrations receive mobile/reduced/high-contrast context | Code inspection + import + full suite |

## Files changed

### Production

- `src/ui/vnext/core/entity_quality.gd`
  - introduces the quality vocabulary and normalization boundary;
  - accepts desktop/mobile tier, reduced motion, high contrast, color assist
    and grayscale flags;
  - normalizes malformed boolean-like values rather than letting a string such
    as `"false"` become truthy through a generic cast;
  - returns an explicit bounded finish segment count.
- `src/ui/vnext/core/entity_renderer.gd`
  - normalizes quality before color, render-key and draw decisions;
  - adds `quality_profile()` and `finish_plan()` as inspectable contracts;
  - keeps identity/state drawing unconditional;
  - draws two low-alpha outer finish accents only when the profile enables
    finish work;
  - freezes the finish phase under reduced motion and applies grayscale,
    color-assist and high-contrast decisions at the renderer boundary.
- `src/ui/vnext/entity_illustration.gd`
  - adds `set_quality_profile()` so surface callers do not construct ad-hoc
    dictionaries;
  - continues to expose the generic `set_quality()` compatibility method.
- `src/ui/vnext/surfaces/boot_surface.gd`
  - maps touch input context to the mobile preview tier and forwards reduced
    motion/high contrast on every `configure()` call, including refreshes.
- `src/ui/vnext/surfaces/program_surface.gd`
  - applies the same profile mapping to the program illustration whenever its
    layout is applied.

### Tests and tooling

- `tools/e5_entity_quality_probe.gd` and `.tscn`
  - focused contract probe created before the production boundary;
  - checks profile normalization, malformed flags, public illustration
    integration, structural markers, real draw execution, ten-entity stress,
    state isolation and sprite-policy status.
- `tools/validate_input_dispatch.sh`
  - runs the E5 probe as part of accumulated validation.

Generated Godot `.uid` files and old capture `.png.import` files remain
untracked and were not staged.

## Before and after

### Before

`VNextEntityRenderer.draw()` had one implicit visual path. Callers could pass
an arbitrary quality dictionary, but there was no normalized profile or
contract that explained which work could be removed on a phone, what reduced
motion meant, or whether structural state remained visible. Finish work was
not separated from identity and state work. The preview surfaces did not map
their `VNextUIContext` to an entity quality profile.

There was also a dangerous normalization assumption: generic conversion of a
serialized string could interpret `"false"` as true. This is precisely the
kind of boundary error that becomes a settings bug later.

### After

`VNextEntityQuality.profile()` produces a canonical profile. The renderer
uses it at the color, render-key and draw boundaries. Its finish plan is
explicit and testable:

- desktop: finish enabled, bounded to 24 nominal segments;
- mobile: finish disabled, zero finish segments;
- reduced motion: finish may remain visible on desktop but its cosmetic phase
  is fixed at zero;
- high contrast: state marks use white;
- color assist: a facing-oriented assist arc is added;
- grayscale: the canonical entity color is converted to luminance.

The structural glyph, facing/orientation line, state marker and elite marker
remain in all profiles. Finish is a cosmetic outer accent, not the only
source of gameplay information.

## Red/green history and adversarial review

### Bootstrap red

`/tmp/kernel-panic-e5-red.log` was captured before the production boundary
existed. It exited without a completion marker and reported the missing
quality preload plus dependent probe parse errors. This is valid bootstrap
evidence that the probe was not silently green before implementation; it is
not presented as a semantic failure count.

### First review correction

`/tmp/kernel-panic-e5-review-green.log` exposed a GDScript inference problem
in the first `_bool()` implementation (`var normalized :=` could not infer a
type in the loaded script). The fix changed it to an explicitly typed String
and added the malformed string/number assertions. This correction was made
before accepting the tier boundary.

### Final focused evidence

- Headless: `/tmp/kernel-panic-e5-final-headless.log`, exit `0`, `18`
  `PROBE_PASS`, `0` `PROBE_FAIL`, `PROBE_DONE fails=0`.
- Xvfb desktop-debug: `/tmp/kernel-panic-e5-final-xvfb.log`, exit `0`, `18`
  `PROBE_PASS`, `0` `PROBE_FAIL`, `PROBE_DONE fails=0`.
- The final headless draw samples were desktop `[357, 348, 342, 501]` µs
  and mobile `449` µs for the fixed ten-entity set.
- The final Xvfb samples were desktop `[498, 714, 574, 603]` µs and mobile
  `510` µs.

These timings measure script-side draw-command dispatch in the test
environment, not GPU frame time, thermals, battery use or a physical Android
device. The samples are therefore evidence that the path is bounded and
measurable, not a universal mobile performance guarantee. The profile's
behavioral guarantee is the disabled finish plan, not “mobile is always
faster” based on these noisy samples.

The focused probe also confirmed that the public `VNextEntityIllustration`
API applies a mobile/reduced/high-contrast profile, and that a reduced-motion
profile reaches the actual draw callback.

### Regression evidence

- Import: `/tmp/kernel-panic-e5-final-import.log`, exit `0`.
- Full DevHarness: `/tmp/kernel-panic-e5-final-full.log`, exit `0`, `1414`
  `AT_PASS`, `0` `AT_FAIL`, `AUTOTEST_ALL_PASS`.
- `git diff --check`: exit `0` before the production commit.
- Accumulated validator: `/tmp/kernel-panic-e5-final-validator-summary.log`,
  exit `0`, final `VALIDATION OK`. It reports E5 `18/0`, full suite
  `1414/0`, all accumulated gameplay/vNext cases green, and zero gated
  runtime errors. Teardown diagnostics remain in their separate non-gating
  sections.

The import command printed the known environment warning about the missing
Android `build-tools` directory. Full-suite teardown continues to report
resource/RID/ObjectDB/text-shaping diagnostics as separate non-gating
baseline diagnostics. E5 did not hide or relabel them.

## Technical decisions

### Keep finish separate from structure

Decision: only outer arcs/accents are finish work. Glyph identity, orientation,
state and elite markers remain unconditional.

Alternative rejected: let mobile draw a simpler glyph or remove state marks.
That would save work by destroying readability and could turn a visual
quality setting into a gameplay-information setting. The renderer contract
and probe prove the distinction directly.

### Normalize at the renderer boundary

Decision: callers may provide a dictionary, but the renderer immediately
normalizes it through `VNextEntityQuality`.

Alternative rejected: require every caller to construct a perfect dictionary.
That spreads policy across surfaces, increases drift and makes malformed save
or settings values dangerous. The explicit boundary also makes render keys
stable for equivalent profiles.

### Use touch context for the first mobile mapping

Decision: vNext Boot and Program use the existing `input_mode == "touch"` as
the first mobile-tier signal.

Alternative rejected: infer mobile from viewport width alone. A narrow desktop
window and a large tablet would otherwise receive the wrong profile. This is
still not a complete device capability system; a later platform/profile task
can add explicit device budgets without changing the renderer contract.

### Keep the sprite gate closed

Decision: no raster asset was invented or enabled in E5.

Alternative rejected: add a placeholder sprite just to satisfy comparison
coverage. That would violate the project direction that code-drawn identity is
the fallback and would make an unapproved visual an accidental product
decision. The comparison gate remains open for a future author-supplied
candidate with a paired code-drawn fallback.

### Do not route legacy combat enemies yet

Decision: leave `draw_enemy()` and the custom legacy enemy `_draw()` callers
unchanged in E5.

Alternative rejected: bulk-rewrite all combat actors while the quality policy
was still new. That would combine a visual refactor with dense-wave behavior,
collision-envelope and performance risk. The shared profile is now ready, but
legacy integration needs a separate focused task with visual and dense-wave
evidence.

## Compatibility, performance and data impact

- Gameplay simulation, collisions, score, RNG, waves, save keys and input
  bindings were not changed.
- E5 adds no Nodes, timers, physics bodies or per-frame polling outside the
  existing `_draw()` path.
- `set_quality()` remains available; the new helper is additive.
- Existing callers that omit quality retain normalized desktop behavior.
- Sprite default-off behavior is unchanged.
- No new persistence path or serialized schema was added.
- No breaking change is intended for current legacy routes; vNext remains
  opt-in.
- The first mobile mapping can change the appearance/cost of vNext previews
  when a touch context is explicitly supplied. It does not affect the default
  legacy UI.

## Known limitations and uncertainties

1. No physical mobile device, Android export, Vega GPU run or battery/thermal
   measurement was performed.
2. No human visual approval was performed for the new finish accents. The
   probe proves structure and contracts, not aesthetic quality.
3. Legacy combat enemy custom drawing is not yet routed through the quality
   profile. A future mobile pass must decide whether to add finish gating to
   those actors or keep their current path intentionally fixed.
4. The `color_assist`, grayscale and high-contrast flags are renderer-ready,
   but the current U5 settings surface does not expose all of them as
   persisted controls.
5. The raster comparison gate has no candidate to compare; this is deferred,
   not passed.
6. Teardown resource/RID/ObjectDB/text-shaping diagnostics remain open from
   the baseline and are not E5 regressions based on the final suite output.
7. Timing samples are environment-local microbenchmarks, not release device
   budgets. P1 must establish budgets on representative hardware.

For each unresolved point, the proven fact is recorded above; the remaining
assumption is that the current code-drawn finish is visually acceptable and
that the current mobile reduction is sufficient. The risk is an attractive
contract that still misses real device bottlenecks or visual readability
issues. Validation requires physical-device captures, a GPU/frame-time
profile, and human review against the direction document.

## Release-note eligibility

E5 should not be advertised as a shipped mobile accessibility feature because
the vNext surfaces remain opt-in and the legacy combat renderer is not yet
quality-routed. A future release note may say that the rebuilt UI has
code-drawn entity previews with a reduced-finish mobile profile only after the
route is promoted and receives physical-device and visual approval. The
normalization and benchmark implementation details belong in this technical
report, not in public notes.

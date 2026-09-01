# Handoff — E5 — Entity quality tiers and sprite gate

## Branch and scope

- Branch: `codex/plan-execution`
- Worktree: `/tmp/kernel-panic-plan-execution`
- Scope: explicit code-drawn entity quality profiles, finish-only gating,
  reduced-motion behavior, vNext preview integration and sprite-policy
  evidence.
- Explicit non-scope: legacy enemy combat rewrite, physical mobile support,
  Android export, final visual approval, persisted accessibility control
  migration and raster asset approval.

## Commits

- `655a7d3` — `feat: add code-drawn quality tiers`
- `7865f2c` — `fix: normalize malformed entity quality flags`
- `5a88d01` — `feat: route entity quality through vnext previews`
- documentation commit: follows final validator rerun.

## What changed

`VNextEntityQuality` is a small normalization boundary. It recognizes desktop
and mobile tiers and four independent flags: reduced motion, high contrast,
color assist and grayscale. Unknown tiers fall back to desktop. Boolean-like
strings and numbers are parsed explicitly; the generic `bool("false")` trap
is not used.

`VNextEntityRenderer` now separates structure from finish. Structure is the
glyph identity, facing line, state marker and elite marker. Finish is two
low-alpha outer accents. Desktop retains it, mobile removes it, and reduced
motion freezes its phase. Accessibility flags affect color/markers without
removing the state channel.

`VNextEntityIllustration.set_quality_profile()` is the public convenience
entry point. Boot and Program vNext surfaces apply the profile on each layout
or configuration pass, mapping explicit touch context to mobile and passing
reduced-motion/high-contrast state through.

No raster asset was introduced. `SpriteRegistry.sprites_enabled()` remains
false, so code-drawn output remains the fallback and shipped default.

## Validation

- `/tmp/kernel-panic-e5-final-headless.log`: exit `0`, 18 passes, zero fails,
  `PROBE_DONE fails=0`.
- `/tmp/kernel-panic-e5-final-xvfb.log`: exit `0`, 18 passes, zero fails,
  `PROBE_DONE fails=0`.
- `/tmp/kernel-panic-e5-final-import.log`: exit `0`; known Android
  build-tools environment warning only.
- `/tmp/kernel-panic-e5-final-full.log`: exit `0`, 1414 passes, zero fails,
  `AUTOTEST_ALL_PASS`.
- `/tmp/kernel-panic-e5-final-validator-summary.log`: exit `0`, final
  `VALIDATION OK`; full suite `1414/0`, E5 `18/0`, all accumulated cases
  green and zero gated runtime errors. Teardown diagnostics remain reported
  separately and non-gating.

The E5 probe renders ten fixed entity snapshots through an actual draw
callback. Its timings are script-side microbenchmarks in headless/llvmpipe
environments and are not physical-device claims.

## Review findings addressed

- A first red run correctly failed at the missing quality preload.
- The first implementation's boolean parser could treat `"false"` as true;
  explicit normalization and malformed-value assertions fixed this.
- The first review-green attempt exposed an untyped local inference error in
  the quality helper; the local is explicitly typed now.
- Quality application was placed on every relevant surface configure/layout
  path so an existing illustration cannot retain a stale desktop profile.

## Residual risk

Legacy custom enemy drawing still uses the compatibility `draw_enemy()` path
without this tier policy. Do not interpret E5 as proof that a dense real wave
on a phone has been optimized. The next mobile/art integration task needs a
real device profile, human visual comparison and a decision about whether
legacy finish layers should be gated.

Baseline teardown diagnostics (resources, RIDs, ObjectDB and text shaping)
remain separately reported and are not attributed to E5.

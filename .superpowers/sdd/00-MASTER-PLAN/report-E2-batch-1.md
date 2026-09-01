# E2 batch 1 — technical report

## Contract

The batch covers only DRONE, LANCER and SPEWER. Their gameplay owners remain
the enemy classes; the E1 adapter projects read-only presentation snapshots and
the renderer provides orientation, identity and shape-based state markers.

| Enemy | Identity/state contract | Preserved telegraph |
| --- | --- | --- |
| DRONE | directional dart, idle notch, hit cross, elite ring/core | tracking, volatile pulse, hit flash |
| LANCER | spear axis, AIM/LUNGE attack marker, hit/elite markers | aim line and lunge/recovery behavior |
| SPEWER | emitter body, aim axis, wind-up attack marker | wind-up eye expansion and pressure pulse |

## Evidence

The probe was red before production (`2827e2b`, exit 1, 15 failures) and green
after production in headless and Xvfb (each exit 0, 73 passes, 0 failures).
It uses real enemy script instances without starting a run and a real
CanvasItem `_draw()` host. It checks deterministic render contracts, bounds at
four logical sizes in a non-square slot, state geometry signatures, fields
before/after drawing, catalog copy and a full GlyphLib hash scope guard.

Import and full DevHarness are green: import exit 0; suite exit 0 with 1414
passes, 0 failures and `AUTOTEST_ALL_PASS`. The accumulated validator is green:
`VALIDATION OK`, suite 1414/0, E2 73/0 and runtime error gates 0. A first
30-second bounded validator attempt timed out the suite before its marker;
the final validator run used its default per-case bound under a 300-second
outer bound.

## Adversarial review

The review corrected two concrete issues before final validation: the probe was
made to fail cleanly instead of aborting on a missing method, and renderer use
was changed to retain each enemy's resolved color (including Drone mini/hit
and era mixing). A GDScript inference error for `CanvasItem.rotation` was also
fixed. Source review found no new gameplay/audio/RNG/scene dependency and no
non-batch GlyphLib edit.

## Limitations

No visual approval, fixed-seed dense-wave profile, physical mobile, hardware
Vega run, localization or Android export is claimed. Existing teardown
diagnostics remain open and are explicitly non-gating for this presentation
slice.

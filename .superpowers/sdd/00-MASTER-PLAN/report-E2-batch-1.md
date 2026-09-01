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
after the full correction sequence in headless and Xvfb (each exit 0, 76
passes, 0 failures). It uses real enemy script instances without starting a
run. Each enemy is added to a temporary tree with simulation disabled, queues
its real `_draw()` path and is checked after the draw frame; a separate
renderer fixture covers deterministic contracts. The probe checks bounds at
four logical sizes in a non-square slot, state geometry signatures, fields
before/after actual drawing, catalog copy and a full GlyphLib hash scope
guard.

Import and full DevHarness are green: import exit 0; suite exit 0 with 1414
passes, 0 failures and `AUTOTEST_ALL_PASS`. The accumulated validator is green:
`VALIDATION OK`, suite 1414/0, E2 76/0 and runtime error gates 0. The final
run was executed after the corrections with the validator's normal per-case
timeout under a 300-second outer bound.

## Adversarial review and correction loop

The first independent review rejected the initial result. It found that the
declared marker envelope did not cover diagonal `attack`/`hit` markers, that
the probe did not execute each real legacy enemy's `_draw()`, and that Spewer
mutated its gameplay-facing node rotation inside `_draw()`. The controller
added a red assertion requiring the diagonal extent, then changed the
renderer to expose a conservative `1.70` marker envelope, removed Spewer's
per-frame rotation mutation, and replaced the invalid manual `_draw()` call
with a queued redraw from a real enemy instance inside a temporary scene tree.

The first review had also corrected the probe's missing-method failure mode,
preserved each enemy's resolved color (including Drone mini/hit and era
mixing), and fixed a GDScript inference issue for `CanvasItem.rotation`.
After all corrections, the focused probe passed 76/0 in both environments;
the full suite, import and accumulated validator were rerun. A deliberately
direct `_draw()` invocation failed with Godot's draw-phase guard and was
discarded as evidence; the final tree-based probe is the accepted path.

Source review found no new gameplay/audio/RNG/scene dependency and no
non-batch GlyphLib edit.

## Limitations

No visual approval, fixed-seed dense-wave profile, physical mobile, hardware
Vega run, localization or Android export is claimed. Existing teardown
diagnostics remain open and are explicitly non-gating for this presentation
slice.

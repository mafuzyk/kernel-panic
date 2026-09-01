# Contributing to KERNEL PANIC

KERNEL PANIC is a free and open-source Godot 4.7.2 twin-stick shooter. Contributions are welcome when they improve the game for players without weakening its readability, accessibility, performance, or maintainability.

## Before changing code

- Read `AGENTS.md`, `docs/UI-REVIEW-BACKLOG.md`, and the relevant handoff or plan document.
- Keep changes scoped. One backlog item should normally produce one focused commit.
- Preserve unrelated working-tree changes. Do not include generated files, personal saves, editor state, `.uid` files, or orphaned capture imports.
- Treat `media/Ideas/` as visual direction only. Do not copy third-party artwork, logos, screenshots, or proprietary assets into the runtime.

## Project conventions

- Use Godot 4.7.2 and GDScript.
- Use tabs in GDScript and follow the surrounding file's style.
- The base viewport is 1280×720 with `canvas_items` / `expand`. UI geometry must remain valid at narrow, wide, desktop, and mobile viewports.
- Prefer code-drawn presentation for enemies, programs, HUD surfaces, and tactical decoration. New art must communicate silhouette, state, telegraph, hitbox intent, and counterplay—not merely add detail.
- Route shared colors and gameplay values through `Balance` and `TacticalUI`; do not duplicate balance constants in UI code.
- Use existing autoload helpers for `Game`, `Sfx`, `Fx`, and persistence. Do not write saves outside the established helpers.
- Keep input, simulation, presentation, and persistence boundaries explicit.

## Local verification

Run from the repository root. Audio is intentionally disabled in the commands below so development checks do not interrupt the user.

```sh
godot --headless --audio-driver Dummy --path . --editor --quit
godot --headless --audio-driver Dummy --path . -- --autotest
tools/validate_input_dispatch.sh
```

For a visual check, run the game with Dummy audio and inspect the menu, settings, story, bestiary, pause, HUD, game-over, and mobile/touch layouts at more than one aspect ratio. Xvfb captures may be used for repeatable evidence:

```sh
xvfb-run -a godot --audio-driver Dummy --path .
```

Focused probes should be run for the subsystem changed. A new behavior that can regress should receive a deterministic probe or a DevHarness assertion. A passing process exit is not enough: inspect the expected completion marker, pass/fail counts, runtime errors, and teardown warnings.

## Pull requests

Describe the player-facing result first, then the implementation. Include:

- the problem and the intended behavior;
- before/after behavior and affected paths;
- compatibility, input, save, performance, and accessibility impact;
- focused and full verification results;
- visual evidence for UI or code-drawn art changes;
- known limitations and decisions that still need maintainer review.

Do not merge a change that only passes headless checks when the change affects layout, readability, touch input, animation, visual telegraphs, or device-specific behavior. Those changes require an explicit manual-validation note.

## Commit hygiene

Keep commit messages specific and avoid mixing unrelated refactors with behavior changes. Never force-push a shared review branch unless the maintainer explicitly requests it. Generated `.godot` state, user saves, screenshots, and machine-local configuration do not belong in commits.

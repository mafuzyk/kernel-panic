# Localization inventory and migration boundary

## Current status

The locale service supports English and Brazilian Portuguese with JSON catalogs, schema validation, fallback copy, placeholder formatting, plural branches, select branches, and persistent locale selection. The first shipped content slice covers the macOS history story, HUD examples, the language setting, and the vNext accessibility surface.

This is intentionally not described as a complete translation of the game. The legacy menu, combat HUD, pause, game-over, bestiary, program cards, enemy labels, tutorial copy, debug surfaces, and several code-drawn annotations still contain English literals or only partial locale integration.

## Inventory method

The inventory was performed against the execution branch with searches over `src/ui`, `src/arena`, `src/player`, `src/enemies`, and `src/autoload`. The raw scan finds roughly 770 uppercase string literals and roughly 900 candidate text assignments/draw sites, but those counts include colors, identifiers, debug messages, state tokens, and duplicate branches. They are useful for scope discovery, not a translation count.

The authoritative translatable-key count is the JSON catalog: 21 keys before this slice, with the same key set in English and PT-BR. The accessibility migration adds a coherent set of title, state, status, label, and unavailable-feature keys to both catalogs.

## Migration order

1. Keep the locale service and catalog parity validator as the single data boundary.
2. Migrate player-visible vNext surfaces by screen, beginning with settings and onboarding because their copy is short and their overflow contracts already exist.
3. Migrate HUD, pause, game-over, bestiary, program selection, and legacy menu groups one surface at a time.
4. Add placeholder/plural/select coverage before translating dynamic copy.
5. Run overflow and semantic checks in English and PT-BR at wide, base, narrow, and touch-oriented viewports.
6. Perform a native editorial pass in Brazilian Portuguese. Literal machine-like translation is not a release-quality substitute for a consistent voice.

## Release boundary

PT-BR should not be advertised as fully supported until the legacy route and the vNext route have an explicit coverage report, no high-priority untranslated player-facing copy remains, dynamic text has been reviewed, and a Brazilian Portuguese playthrough has been completed. English remains the fallback for missing keys so incomplete migration cannot leak raw key identifiers to players.

# KERNEL PANIC — Localization and PT-BR Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans`. Localization is a runtime contract, not a final copy search-and-replace pass. Every new string must be born with a stable key and a fitting strategy.

**Goal:** Ship complete Brazilian Portuguese support without breaking the
English experience, without exposing raw keys or mixed-language screens, and
without allowing translated text to overflow the adaptive UI.

**Architecture:** Add one localization service that owns locale selection,
catalog loading, fallback and formatting. Gameplay/content data stores stable
keys; UI asks the service for text. English is the required fallback catalog,
PT-BR is the first translated catalog, and future languages can be added
without changing gameplay or `_draw()` code.

**Tech Stack:** Godot 4.7.2, GDScript autoload `Localization`, UTF-8 CSV or
Godot translation resources kept in `res://src/data/localization/`,
`TranslationServer` only where it helps editor/runtime integration, existing
`TacticalUI.fit_block()`/`ellipsis_fit()`, and localization probes.

**Spec:** [master plan](00-MASTER-PLAN.md), [UI remake](02-UI-REMAKE-VNEXT.md), [accessibility](07-ACCESSIBILITY-SETTINGS.md), and current English content in `src/story/`, `src/ui/`, `src/enemies/` and `README.md`.

## Global Constraints

- PT-BR must be selectable in settings and persist locally.
- English remains complete and is the fallback for missing PT-BR keys.
- A missing key logs a development diagnostic and returns readable fallback
  copy; it never displays `ui.some.key` to players.
- Formatting placeholders are named and validated; translators do not change
  placeholder names or semantic types.
- No translation is implemented by concatenating fragments whose grammar can
  change. Use complete sentence keys or plural/select variants.
- All translated text passes overflow tests at 1366×768, 720×720 and 432×720.
- Technical terms may remain in English when they are part of the game's
  fiction (`KERNEL`, `OOM`, `ROOTLET`, `PATCH`, `OVERLOCK`), but that choice is
  documented per term and must be consistent.
- The chosen fonts and fallbacks must cover Portuguese accents, punctuation,
  arrows, symbols and any glyph used by the terminal fiction. Missing glyphs
  are a release failure, not a reason to remove accents from the copy.

## Locale Service Contract

Create `src/autoload/localization.gd` with a small stable API:

```gdscript
signal locale_changed(locale: String)

func current_locale() -> String
func set_locale(locale: String) -> bool
func tr_key(key: String, fallback: String = "", context: Dictionary = {}) -> String
func has_key(key: String, locale: String = "") -> bool
func format_key(key: String, values: Dictionary, fallback: String = "") -> String
func plural_key(key: String, count: int, values: Dictionary = {}) -> String
func select_key(key: String, branch: String, values: Dictionary = {}) -> String
func locale_snapshot() -> Dictionary
```

The service loads `en` first, then overlays the requested locale only for keys
that exist. `set_locale()` validates the allowed locale list, persists the
choice through the existing settings helper and emits once per actual change.
It must not reload the scene or reset a run.

Recommended translation-inventory fields (runtime catalogs may be split by
locale):

```text
catalog_version,key,context,en,pt_br,max_lines
1,menu.run_process,primary_action,Run Process,Executar processo,1
1,hud.wave,combat_status,Wave {wave},Onda {wave},1
```

The parser must preserve commas, line breaks and Unicode safely. If Godot's
imported translation resource is used instead, keep an equivalent validation
report that compares key sets and placeholders.

The catalog header declares its locale, schema version and source revision.
Duplicate keys, empty player-facing values, invalid line-count metadata and
unpaired Unicode markers fail the catalog check. The English catalog is the
complete source of truth for key inventory; PT-BR may intentionally fall back
only when the missing key is recorded in the localization report.

## Key Taxonomy

Use namespaces that match ownership:

```text
app.*              title, version labels and global shell
nav.*              back, close, confirm, cancel and routes
menu.*             boot, mode, difficulty and main navigation
program.*          program names, roles, descriptions and traits
story.*            acts, stages, intro, klog, objectives and rewards
enemy.*            names, classes, threat and counterplay
patch.*            names, effects, synergy/conflict and rarity
hud.*              wave, combo, score, integrity and transient feedback
pause.*            paused actions and confirmation copy
terminal.*         commands, status and shortcut hints
settings.*         labels, values and accessibility descriptions
game_over.*        cause, summary, retry and return copy
accessibility.*    option names, descriptions and state labels
achievement.*      names and descriptions
```

IDs used by logic stay separate from localized labels. `"oom"` is a gameplay
ID; `Localization.tr_key("enemy.oom.name")` produces the display label.

## Migration Sequence

### Task L1 — catalog and service

**Create:** `src/autoload/localization.gd`, `src/data/localization/en.csv`,
`src/data/localization/pt-BR.csv`, `tools/localization_probe.gd/.tscn`.

**Modify:** `project.godot` autoload registration, `Sfx` or the settings
adapter only for persistence, and the handoff.

Tests:

- locale default is English;
- PT-BR changes emit one signal and persist;
- invalid locale falls back without mutation;
- English and PT-BR key sets match;
- placeholders match by name and count;
- restart/readback returns the same locale.

### Task L2 — migrate UI strings

Migrate menu, settings, program, story, bestiary, awards, pause, terminal,
HUD and game-over text in that order. Keep layout calculations independent from
copy. The UI must subscribe to `locale_changed` and refresh its snapshot, not
rebuild the entire scene unnecessarily.

The migration inventory includes visible copy, tooltips, disabled/locked
reasons, error/recovery messages, input hints, subtitles, accessibility
descriptions, bestiary entries, story klogs and capture/debug labels that can
reach a player-facing build. A source scan alone is insufficient: the first
locale pass must also exercise empty, locked, failure and game-over states.

Use full sentence keys for descriptions and actions. Do not translate by
replacing words inside a technical log string at runtime.

### Task L3 — migrate content and enemy metadata

Move story intros/klogs, program descriptions, enemy classes/counterplay,
patch descriptions and achievement copy into catalogs. Static data keeps keys;
the bestiary and story surface resolve them at draw time.

### Task L4 — PT-BR editorial pass

Review Brazilian Portuguese for:

- natural arcade/game terminology;
- consistent use of “processo”, “onda”, “integridade”, “recarga” and
  “sobrecarga”;
- preserved technical flavor and jokes without machine translation artifacts;
- imperative actions that fit buttons;
- accents and capitalization in uppercase terminal labels;
- line length and readability on mobile.

The final text review must happen with the UI visible, not in a spreadsheet
alone.

## Formatting and Overflow Rules

- `format_key()` accepts named values such as `{wave: 7}` and rejects unknown
  placeholders in development.
- `plural_key()` and `select_key()` preserve named placeholders and reject
  missing branches in development. The fallback sentence must have the same
  placeholder contract as the translated sentence.
- Numbers use a locale-aware formatter only for display; saved numbers stay
  numeric and deterministic.
- Time uses a stable `MM:SS.xx` gameplay format unless a screen explicitly
  needs a localized sentence.
- Buttons have a short label key and a longer accessible description key.
- Long descriptions wrap by measured font width; they never shrink below the
  accessibility text floor just to preserve a desktop composition.
- On narrow layouts, list/detail and terminal sections reflow before text is
  reduced.

## Acceptance Gates

- [ ] Every visible shipped string has an English key.
- [ ] Every visible shipped string has PT-BR copy or an intentional documented English technical term.
- [ ] Changing locale refreshes the current route without losing selection or run state.
- [ ] No raw keys, missing labels or accidental English/Portuguese hybrids appear in a surface.
- [ ] Plural/select branches, placeholder names and required catalog metadata pass validation.
- [ ] Fonts render every required Portuguese accent, symbol and terminal glyph without tofu boxes.
- [ ] PT-BR passes overflow and line-count checks at all required viewports.
- [ ] Screen readers/future accessibility descriptions use the same keys as visible labels.
- [ ] Story, enemy, patch and achievement content are localized before their release is announced.
- [ ] README documents how to select PT-BR and how contributors add a catalog key.
- [ ] Release log records the language addition and any copy that intentionally remains technical English.

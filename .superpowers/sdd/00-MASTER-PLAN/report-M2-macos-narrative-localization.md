# M2 — macOS narrative and localization slice

## Status

Implemented as the first content migration on top of L1. The macOS act now
resolves its title, intro and klog through the locale service while retaining
English fallback data for editor/headless contexts where the autoload is not
present. The first slice is ready for editorial review; the whole game is not
yet fully localized.

## Before and after

Before, the Mac act's `MacOSDialogue` table was English-only and returned its
raw table values directly. Selecting another language was impossible, and a
future translation would have needed to edit story code.

After, the act keeps stable content keys and English fallback text but asks
`Localization` for `story.macos.*` values at stage-resolution time. PT-BR
copy covers all four titles, intros and three-line klogs. Mac story stage data
therefore changes language without changing IDs, waves, unlock logic, reward
keys or stage order. Legacy Settings exposes `LANGUAGE: English` /
`IDIOMA: Português (Brasil)` as an immediately persisted selector. Menu and
vNext route owners refresh their active state when `locale_changed` fires;
the current selection and run state are not reset.

## Editorial choices

- “shell”, “daemon”, “root” and “race condition” retain technical/fiction
  identity where translating them would weaken the game's vocabulary.
- Portuguese uses “área de trabalho”, “tabela de processos”, “serviço em
  segundo plano” and “permissão negada” for readable Brazilian phrasing.
- The humor is written as a system failure/parody and does not depend on an
  Apple logo, copied screenshot, proprietary font or exact product UI.
- PT-BR uppercase labels are not produced by blindly uppercasing accented
  prose; the catalog stores deliberate player-facing strings.

## Files and ownership

- `src/data/localization/en.json` and `pt-BR.json`: source catalogs and parity
  metadata.
- `src/story/acts/macos_dialogue.gd`: stable fallback table plus service
  lookup, with no drawing or progression mutation.
- `src/ui/menu_settings_kit.gd`: language selector in the existing Display
  group, using the service rather than writing a second settings file.
- `src/ui/menu.gd`: locale-change refresh hook for menu/story/vNext surfaces.
- `tools/localization_probe.gd/.tscn`: locale, content and persistence probe.

## Verification

`/tmp/l1-green4.log` exited 0 with `PROBE_DONE fails=0`. It verifies that the
first Mac stage returns `A SHELL AMIGÁVEL` after selecting PT-BR, that the
locale persists under the established ConfigFile path, that an invalid locale
does not mutate state, and that changing to the same locale does not emit a
duplicate event. The import run `/tmp/l1-import2.log` exited 0.

The existing vNext selection probe remains green under the default English
locale; its Mac tab and narrow layout assertions passed in
`/tmp/macos-selection3.log`. Full-surface PT-BR overflow review for every old
screen is deliberately deferred to L2/L4.

## Second-pass self-review

The slice was checked for locale changes reloading scenes, replacing stable
IDs, affecting save transfer, bypassing fallback copy, leaking raw keys or
leaving story stages with mixed title/klog languages. The stage catalog remains
stable and fallback-safe. The main open risk is that only the Mac narrative
slice is migrated: old menu/HUD/bestiary/terminal/game-over literals still
need inventory and migration before PT-BR can be advertised as complete.

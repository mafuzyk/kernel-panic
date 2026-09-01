# L1 — localization catalog and service

## Status

Implemented and reviewed on `codex/plan-execution`. This is the first
localization boundary, not a claim that every old English literal has already
been migrated. The service, catalogs, fallback rules, named formatting,
plural/select helpers and persistence are now available for the remaining L2
and L3 migration work.

## Decision

The runtime catalogs use UTF-8 JSON documents instead of a hand-rolled CSV
parser. JSON keeps commas, line breaks, braces and Portuguese accents
unambiguous while retaining explicit metadata and stable key/value ownership.
The decision avoids a delimiter/parser failure mode in the terminal-style
copy and leaves the source catalog easy to validate in CI. The catalog format
is deliberately small: `_meta` carries schema/locale/source revision and
`keys` carries player-facing values. English is the complete inventory;
PT-BR must have the same keys and placeholder contracts.

## Before and after

Before, player-facing copy was embedded in story tables, menu construction and
draw routines. There was no locale setting, fallback service, placeholder
validation or persisted language choice.

After, `Localization` is an autoload with a stable service API:
`current_locale`, `set_locale`, `tr_key`, `has_key`, `format_key`,
`plural_key`, `select_key`, `locale_snapshot` and `validate_catalogs`.
English and PT-BR catalogs are loaded together. A missing PT-BR value falls
back to English; a missing key with no fallback becomes a readable humanized
sentence and logs a development diagnostic rather than showing a raw key.
`set_locale` emits exactly once for a real change, rejects unknown locales,
and persists through the existing Sfx ConfigFile path under the additive
`[localization] locale` key.

## Formatting contract

Named placeholders use `{name}` and are compared between catalogs. Formatting
never depends on positional replacement. Plural values support `one` and
`other` branches and inject `{count}`; select values support named branches
with an `other` fallback. Catalog validation rejects empty values, key-set
mismatches and placeholder signature mismatches. This validation is exposed
for the probe and future release checks.

## Compatibility and risk

- Existing save keys and transfer version remain unchanged. Locale is a local
  presentation preference and is not included in portable progress transfer.
- Invalid or absent language values resolve to English without blocking menu
  startup.
- JSON is parsed at service startup; future catalogs should remain modest and
  can be cached without changing the API if profiling ever shows a cost.
- A `tr_key` call is not yet a complete migration: old literal strings still
  exist in legacy UI and content. L2/L3 must inventory and replace them.
- Native screen-reader integration is not implied by this service.

## Verification

- Red probe: `/tmp/l1-red2.log`, exit 1 with the expected missing Localization
  service contract.
- First implementation import caught strict GDScript inference errors in the
  probe/service; those were fixed before accepting runtime evidence. The
  correction is recorded here because “import passed” was not assumed from a
  prior state.
- Editor import/parse: `/tmp/l1-import2.log`, exit 0; no script errors.
- Final focused probe: `/tmp/l1-green4.log`, exit 0, all checks passed and
  `PROBE_DONE fails=0`. It covers catalog parity, missing-key safety,
  placeholders, plural/select branches, PT-BR Mac copy, signal cardinality,
  invalid locale rejection, persistence and snapshot state.

## Second-pass self-review

The service was checked for raw-key leakage, fallback order, same-locale
emission, failed save rollback, malformed catalog values, nested plural/select
values, old-profile startup and accidental progress-transfer coupling. The
remaining uncertainty is migration completeness: a source scan and visual
review are still needed to prove that no player-facing literal bypasses the
service. That is the explicit L2/L3 gate.

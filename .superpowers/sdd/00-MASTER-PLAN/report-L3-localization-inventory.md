# L3 — Localization inventory and surface migration

## Scope

This slice extends the existing locale service into the newly implemented vNext accessibility surface and records the boundary of the remaining PT-BR work. It does not claim a full game translation.

## Changes

- Added parity-matched English and PT-BR keys for accessibility titles, explanations, unavailable-feature notices, states, labels, and persistence statuses.
- Changed the accessibility surface to resolve visible and semantic copy through `LocalizationService`, with safe English fallbacks when the service is unavailable.
- Connected the surface to `locale_changed` so an active surface refreshes labels after a locale switch rather than retaining stale text.
- Added PT-BR overflow checks for story and accessibility surfaces at 1366×768, 720×720, 432×720, and 390×844.
- Added `docs/LOCALIZATION-INVENTORY.md` with a quantified but explicitly approximate literal scan and a release boundary for full PT-BR claims.

## Verification

- Headless localization probe: exit 0, 32 `PROBE_PASS`, `PROBE_DONE fails=0`.
- Xvfb localization probe: exit 0, 32 `PROBE_PASS`, `PROBE_DONE fails=0`; only the known V-Sync warning was emitted.
- Catalog validation passed with equal English/PT-BR key sets and matching placeholder signatures.

## Decision and trade-off

The migration is screen-based rather than a blind global replacement. That keeps runtime behavior stable and makes overflow/editorial review possible. The trade-off is that many legacy literals remain until their screen receives a focused migration; the inventory and release checklist make that incompleteness explicit.

## Open risk

The translations are authored for this slice but still require a native Brazilian Portuguese editorial review. The legacy route remains only partially translated, and full accessibility capabilities such as native screen readers, text scaling, and high contrast are still unavailable.

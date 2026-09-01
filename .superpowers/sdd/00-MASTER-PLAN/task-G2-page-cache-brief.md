# G2A — Page Cache

## Goal

Implement the approved Page Cache mechanic as a selectable passive patch:
store up to three spare overclock motes, flush automatically when the third
is stored, and never decay or require a manual release action.

## Interpretation gate

The approval specifies capacity and trigger but does not name a separate
reward value. The conservative implementation interpretation is to preserve
the existing full-meter overflow value: the three cached motes release the
same `+5` score/scrap-progression unit that a normal full-meter overflow mote
already uses, delivered as one automatic flush. This changes timing and
feedback, not the per-mote economy. No healing or integrity effect is added.

The interpretation is isolated behind the patch and `PageCache` contract so
it can be changed later without changing mote ownership or save schema.

## Constraints

- No cache Node, timer, decay loop, physics or RNG.
- Cache only intercepts spare motes after the normal overclock meter is full
  or an overclock is active; shield-mode behavior remains authoritative.
- Capacity is exactly three; a full cache immediately flushes and returns to
  zero.
- Existing non-Page-Cache overflow behavior remains unchanged.
- One-HP receives no healing through the cache; the existing scrap-diet guard
  still owns healing eligibility.
- New patch metadata is catalog-owned and uses existing offer/tooltip paths.

## Required evidence

1. Focused probe exists and fails before `PageCache`/patch integration.
2. Probe proves 1→2→flush-at-3, zero after flush, repeated flushes, no decay
   path, no manual action, and malformed/non-positive input safety.
3. Probe exercises `Player.collect_mote()` with and without the patch and
   proves score timing, meter isolation and existing overflow fallback.
4. Run input/R04–R06/E2–E5/G1 accumulated validation plus full DevHarness.
5. Document the reward interpretation as an explicit assumption, not a hidden
   user decision.

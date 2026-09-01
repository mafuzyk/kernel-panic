# G2B — Ring-0 double overclock implementation report

## Status

Implemented on `codex/plan-execution`. Ring-0 is a max-one rare/legendary
passive patch. It enables exactly one re-press during an active overclock.

## Requirement and implementation decision

The approved rule says that Ring-0 stacks through a re-press while overclock is
active, has a significantly longer cooldown after the second ring, has no
integrity cost, and must be checked against DAEMON's dash-overclock behavior.
It does not specify whether “stack” should increase firepower, movement speed,
or remaining time, nor an exact cooldown duration.

The reversible implementation interpretation is:

- the first press starts the existing overclock with stack `1`;
- one Ring-0 re-press raises the stack to `2` and adds one existing
  `oc_duration()` to the active window;
- a third press is inert because the cap is two stacks;
- after a two-stack use, the player receives a recovery lock equal to one
  existing `oc_duration()`; the first, ordinary use does not receive this lock;
- during the lock, the meter may fill but cannot become ready until the lock
  expires; a full locked meter overflows through the existing score/scrap path;
- no HP/integrity field is read or changed by the Ring-0 path.

This avoids inventing a new damage multiplier and keeps the effect legible as
“a second overclock window.” The duration and cooldown reuse existing balance
values instead of introducing an unexplained literal. The decision remains a
balance assumption for human playtest, not a claim that the unspecified exact
numbers were author-approved.

## Before

`Player.try_overclock()` only accepted `oc_ready` while inactive. Once the
overclock started, `oc_ready` was false and a re-press did nothing. There was no
stack count, no post-double recovery state and no way for the UI adapter to
describe either state. DAEMON's dash code was independent, but there was no
regression proof that a re-press would preserve it.

## After

`Player` owns explicit `overclock_stacks` and a private recovery timer. The
active overclock updates its meter using the complete `oc_duration()` and
clamps the presentation value to the meter range, which also prevents Ring-0
or Overclock Cell from displaying an impossible value above 100. On expiry,
only a two-stack use starts the recovery lock. The lock is visible through the
read-only player presentation payload and adapter.

The patch catalog owns Ring-0's ID (`ring0`), code (`R0`), title, description,
max level and rarity. Existing offer, build and tooltip code consumes that
metadata; no save schema or new input action was introduced.

## Files and ownership

- `src/player/player.gd`: authoritative overclock state, re-press, lock,
  meter and mote behavior.
- `src/data/content_catalog.gd`: Ring-0 metadata.
- `src/ui/vnext/core/entity_presentation_adapter.gd`: read-only projection of
  stack/lock state.
- `tools/g2_ring0_probe.gd` and `.tscn`: focused kernel, DAEMON, no-patch and
  Rootlet regression probe.
- `tools/validate_input_dispatch.sh`: accumulated validation registration.

## Evidence

`/tmp/kernel-panic-g2b-green2.log` exited `0` with `15` passes,
`PROBE_DONE fails=0`. The probe proves first activation, one re-press, duration
extension, no integrity cost, DAEMON dash preservation, double-use recovery
lock, immediate reactivation blocking, no-patch inert behavior and Rootlet
shield protection.

The first focused run (`/tmp/kernel-panic-g2b-green.log`) correctly failed one
probe assertion because the fixture called a double-stack player “single
stack.” The probe was corrected to match the actual fixture before acceptance;
no production weakening was used.

## Compatibility and risks

- Existing overclock behavior without Ring-0 remains single-stack.
- Rootlet cannot bypass shield mode with Ring-0.
- DAEMON dash charges, dash timer, dash ID and HP are preserved through the
  second press.
- No integrity cost, save change, route change or input binding change.
- Meter display is now clamped/normalized for all overclock durations; this is
  a small correctness improvement to a pre-existing Overclock Cell edge case.
- A recovery lock can make a full meter temporarily not-ready. The projected
  lock value gives future HUD work enough truth to explain that state; the
  legacy HUD does not yet expose a dedicated lock label.
- Exact duration/cooldown feel and whether “stack” should instead mean
  stronger firepower require a human balance decision before official release.

## Second-pass self-review

The implementation was checked for repeated presses, a third press, activation
without Ring-0, shield bypass, HP mutation, cooldown bypass, full-meter mote
handling, meter overflow, dash cancellation, dash-charge loss and presentation
write-through. The focused probe covers those deterministic cases. It does not
prove final feel, long-session interaction with every patch, physical mobile
timing or visual HUD messaging; those remain open.


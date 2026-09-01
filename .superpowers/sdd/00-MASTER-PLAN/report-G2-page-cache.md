# G2A — Page Cache implementation report

## Status

Implemented on `codex/plan-execution` as the first G2 gameplay slice. The
mechanic is available only when the new `PAGE CACHE` patch is installed; the
legacy full-meter overflow remains unchanged when the patch is absent.

## Requirement and interpretation

The approved gameplay rule is: “Estoca até 3 motes; ao encher, libera
automaticamente (bônus). Sem decay armazenado. Sem ação manual.” The approval
does not specify a separate numerical reward. The implementation therefore
uses the already-established full-meter overflow unit: each released mote
awards `+5` score and one existing scrap-progression unit. A three-mote flush
is consequently `+15`, emitted as one automatic feedback event. This is an
explicit, reversible implementation assumption, not a claim that the missing
reward number was approved separately.

The other deliberately conservative decisions are:

- Page Cache is a selectable passive patch because the existing patch catalog
  is the game's established acquisition and tooltip boundary.
- Only motes that would already be spare are intercepted: motes while an
  overclock is active or while the overclock meter is already ready.
- Rootlet shield mode keeps precedence. A shield mote still charges or
  overflows through the approved shield rules and never enters Page Cache.
- The cache never heals, changes integrity, changes the overclock meter, adds
  RNG, creates a Node/timer, or stores state in the save file.

## Before

`Player.collect_mote()` charged the overclock meter until full. Once the meter
was ready, or while overclock was active, each additional mote immediately
awarded the existing full-meter overflow (`+5` plus scrap progression). There
was no bounded buffer, no automatic grouped reward and no presentation field
for a cache state.

## After

`PageCache` is a small `RefCounted` value object with a fixed capacity of three.
`store()` accepts positive mote counts, fills the buffer, flushes immediately
at capacity and returns an explicit result containing accepted, stored and
released counts. It has no release method and no time-based behavior.

`Player` owns one cache for the lifetime of the run's player node. When the
patch is active, spare motes are stored and the normal overflow is delayed
until the third mote. The automatic flush applies the existing score and scrap
path in a loop, emits a log/feedback event and leaves the meter/ready state
untouched. Player presentation snapshots and the vNext entity adapter expose a
copy-safe `page_cache` payload for a future HUD indicator; no UI was changed in
this slice.

The catalog owns the new `pagecache` ID, code, title, description and max level.
Existing patch offer, relation, tooltip and save paths consume catalog metadata,
so no duplicate patch definition or new save schema was introduced.

## Files and ownership

- `src/gameplay/page_cache.gd`: bounded cache contract; no scene ownership.
- `src/player/player.gd`: owns cache lifetime and remains authoritative for
  mote collection, score, scrap, feedback and shield precedence.
- `src/data/content_catalog.gd`: owns patch metadata and code.
- `src/ui/vnext/core/entity_presentation_adapter.gd`: projects the cache into
  the existing read-only entity payload.
- `tools/g2_page_cache_probe.gd` and `.tscn`: focused behavior and integration
  evidence.
- `tools/validate_input_dispatch.sh`: registers the probe in accumulated
  validation.

## Evidence

Red bootstrap: `/tmp/kernel-panic-g2a-red.log` exited `124` because the
required production preload did not exist and the probe could not reach its
completion marker. This is the expected pre-implementation failure, not a
false green.

Focused green: `/tmp/kernel-panic-g2a-green3.log` exited `0` with `13` probe
passes and `PROBE_DONE fails=0`. It verifies capacity, 1→2 storage,
no-decay-after-idle, automatic flush at 3, repeated flush, invalid input,
absence of manual release, real `Player.collect_mote()` behavior with and
without the patch, meter isolation and presentation projection.

The first post-change run also exposed a real compile error in the fallback
adapter path: an `Object.get()` call was accidentally written with a default
argument. The adapter was corrected and the focused probe was rerun; no script
or parse errors remained. This correction is part of the engineering record,
not hidden as a baseline issue.

## Compatibility and risk

- No existing patch changes behavior when Page Cache is absent.
- No save key, transfer version, input action, scene route or public gameplay
  method was removed.
- Score still flows through `Game.add_score()`, so existing multipliers remain
  authoritative.
- Scrap progression still flows through `_register_scrap_overflow()`, so the
  existing one-HP and scrap-diet healing guards remain authoritative.
- Cache state resets with the player node on a new run and is not persisted.
- The cache has no visible legacy HUD indicator yet. The snapshot projection is
  intentional groundwork; a later HUD task must make stored motes legible or
  the mechanic will be discoverable only through feedback.
- The reward value remains the main product assumption. If the intended bonus
  is not the existing `+5` unit, only the flush reward boundary should change;
  capacity/ownership/input semantics can remain stable.

## Second-pass self-review

The implementation was reviewed specifically for lost motes, repeated flushes,
meter mutation, shield precedence, one-HP healing, stale cache lifetime,
malformed input, manual-release escape hatches, duplicate patch metadata and
presentation write-through. The focused probe covers each of those behaviors
that can be proven deterministically. No race or timer path exists. What is not
proven here is human discoverability, visual HUD quality, dense-wave timing or
physical-device behavior; those remain later gates.


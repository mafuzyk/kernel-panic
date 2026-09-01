# P1 — deterministic performance profile and stress gate

## Status

Implemented and verified on 2026-09-01 in the isolated execution worktree.
The project now has a small reusable percentile profile and a fixed-seed
stress probe using real enemy descendants and real player bullets. It reports
machine-readable p50/p95/p99/worst frame times, peak entity count and peak
static memory.

## Before and after

Before P1, performance evidence was limited to the adaptive quality code and
spot checks. There was no repeatable project-owned measurement that recorded a
known actor population with percentile data. A single successful run could
not distinguish a smooth average from a bad tail frame.

After P1, `PerformanceProfile` collects sorted percentile statistics and the
stress probe uses seed `0x4B504D35`, 48 real enemies from four enemy classes
and 96 real player bullets. It samples a 120-frame empty baseline and a
120-frame stress window after warmup, then emits `PERF_RESULT` JSON-like
payloads and explicit gates.

The current envelope is intentionally not a false claim of a strict 60 Hz
CPU budget: wall-clock `process_frame` sampling includes scheduler/display
jitter. The provisional gates are p95 ≤25 ms, p99 ≤40 ms and worst ≤100 ms.
They are a regression alarm for this harness, not a device certification.

## Files and ownership

- `src/gameplay/performance_profile.gd`: reusable metric boundary.
- `tools/performance_stress_probe.gd/.tscn`: fixed-seed real-actor stress
  fixture and gate.
- `.superpowers/sdd/00-MASTER-PLAN/report-P1-performance-profile.md`:
  evidence and limitations.

## Technical decisions

### Measure a baseline and a stress fixture

The empty baseline makes scheduler overhead visible and prevents reading the
raw 16.67 ms display interval as if it were all game work. The stress fixture
uses real nodes rather than synthetic loops, but disables bullet collisions and
keeps the actors in bounds so expiry/collision side effects do not contaminate
the measurement.

### Use percentile tails instead of one average

The player feels the bad frame, not the arithmetic mean. p50, p95, p99 and
worst make tail regressions visible. The profile is a separate class so future
probes can reuse it without depending on this exact actor mix.

## Evidence

### Probe corrections

The first stress attempt exposed two harness defects: bullets crossed enemy
areas and called `Game.stats["hits"]` outside a normal run, and off-screen
bullets expired before the sample completed. The fixture was corrected to use
non-colliding, in-bounds bullets with a long test lifetime. The production
runtime was not changed for either correction.

### Headless

`/tmp/p1-headless.log` exited 0 with `PROBE_DONE fails=0`:

```text
baseline p95 16.692 ms; stress p95 16.959 ms
stress p99 17.093 ms; worst 17.311 ms; peak entities 144
```

### Xvfb

`/tmp/p1-xvfb.log` exited 0 with `PROBE_DONE fails=0` under Mesa llvmpipe:

```text
baseline p95 2.199 ms; stress p95 9.011 ms
stress p99 9.604 ms; worst 10.443 ms; peak entities 144
```

## Second-pass self-review

The probe was checked for deterministic seed use, save writes, object expiry,
false actor counts, percentile indexing, memory monotonicity, rendering
coverage and suitability for physical Vega/mobile claims. It does not write a
save or enter a user run, and both headless and Xvfb paths pass.

Remaining uncertainty: Xvfb uses llvmpipe, not the user's integrated Vega;
the wall-clock interval is not a profiler trace; no Android hardware or
long-run leak soak has been measured. The result is a repeatable regression
gate, not proof of release performance on every target.

# Handoff — G2A — Page Cache

## Branch and commit

- Branch: `codex/plan-execution`
- Worktree: `/tmp/kernel-panic-plan-execution`
- Commit: `2d2cac6` — `feat: add page cache overflow mechanic`
- No merge into `main`.

## What landed

Page Cache is a selectable passive patch with a hard capacity of three spare
motes. It automatically flushes at three, never decays and has no manual
release command. It intercepts only the existing spare-mote cases after the
normal meter/overclock logic. Rootlet shield handling remains first and is not
changed.

The flush uses the existing full-meter overflow path: `+5` score and one scrap
progression unit per released mote, so a full flush is `+15`. This reward choice
is explicitly recorded as an implementation assumption because the approved
rule specified capacity and trigger but no independent reward amount.

The cache is exposed through the read-only Player presentation snapshot and
vNext entity adapter. No legacy HUD indicator was added yet; this is a later
UX task, not an omission from the current contract.

## Files

- `src/gameplay/page_cache.gd`
- `src/player/player.gd`
- `src/data/content_catalog.gd`
- `src/ui/vnext/core/entity_presentation_adapter.gd`
- `tools/g2_page_cache_probe.gd`
- `tools/g2_page_cache_probe.tscn`
- `tools/validate_input_dispatch.sh`

## Verification

- Red bootstrap: `/tmp/kernel-panic-g2a-red.log`, exit `124`, missing
  production contract and no completion marker.
- Green focused probe: `/tmp/kernel-panic-g2a-green3.log`, exit `0`, `13`
  passes, `0` failures, `PROBE_DONE fails=0`.
- `git diff --check`: clean before commit.

The green log contains only the known non-gating teardown diagnostics (7
ObjectDB instances and 2 resources). There are no script/parse/compile errors
in the final run. Full and accumulated validation remain the next G2 gate.

## Review notes and limits

The first integration rerun caught and fixed an invalid two-argument
`Object.get()` in the adapter's Object fallback. The final focused run is clean.

Still open:

- decide whether `+5` per mote is the final player-facing Page Cache reward;
- add a clear legacy/vNext HUD indicator for stored capacity and flush state;
- validate discovery and feel in a human playtest;
- include the mechanic in dense-wave and physical-device performance checks.


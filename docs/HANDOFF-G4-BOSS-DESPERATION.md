# Handoff — G4 — Boss desperation

## Branch and checkpoint

- Branch: `codex/plan-execution`
- Worktree: `/tmp/kernel-panic-plan-execution`
- No merge into `main`.

## Delivered behavior

All RootBoss variants, split fragments and GodBoss enter a one-shot
desperation state at or below 8% HP. A 0.75-second stagger/telegraph window
prevents an immediate attack. Afterward, future attack cooldowns are 28%
shorter (`0.72` multiplier). Incoming damage is unchanged.

The visual state is intentionally readable without relying on color: white
outer border, white rotating ticks, transition arc and
`DESPERATION // CADENCE UP`. The entity adapter preserves the state for future
HUD work.

## Verification

```text
env XDG_DATA_HOME=/tmp/kernel-panic-g4-xdg4 godot --audio-driver Dummy --headless --path . res://tools/g4_boss_desperation_probe.tscn
```

Result: exit 0, `PROBE_DONE fails=0`, 55 passes.

The isolated pre-feature contract was run from the G3 parent commit and
failed four expected checks; see `/tmp/g4-red.log`. The final probe attaches
bosses to the scene tree, so kind-4 page lookup and all FX calls exercise the
real lifecycle rather than producing null-tree false negatives.

## Review notes and limits

- The first draft briefly prevented GodBoss oracle casts from ever executing
  after a cooldown reached zero; the condition was corrected to skip only the
  cast during the transition window.
- The code proves reactability structurally (`0.75s` versus `0.24s` dash
  iframes) and proves damage is unchanged. It does not prove that every
  existing projectile field is safe at every player position.
- One-HP and normal human playtests are still required for final values.
- Existing process teardown diagnostics remain open.

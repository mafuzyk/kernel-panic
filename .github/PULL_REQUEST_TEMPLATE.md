## Player-facing summary

<!-- What changes for a player? If there is no observable change, say why the internal change is needed. -->

## Scope

- Problem or requirement:
- Before:
- After:
- Affected systems/files:
- Breaking change: none / yes (explain)

## Verification

- [ ] Focused probe or regression test run
- [ ] `godot --headless --audio-driver Dummy --path . -- --autotest`
- [ ] `tools/validate_input_dispatch.sh` (when applicable)
- [ ] Import check after asset/project changes
- [ ] `git diff --check`
- [ ] Manual visual or device check for UI, input, touch, animation, or rendering changes
- [ ] Runtime errors and teardown warnings inspected separately

Evidence and command results:

## Risk and compatibility

- Save/configuration impact:
- Input/platform impact:
- Performance impact:
- Accessibility impact:
- Known limitations or follow-up work:

## Documentation

- [ ] Relevant handoff/technical ledger updated
- [ ] Release notes updated when the player-visible behavior warrants it
- [ ] No generated `.godot`, `.uid`, personal save, secret, or orphaned import files staged

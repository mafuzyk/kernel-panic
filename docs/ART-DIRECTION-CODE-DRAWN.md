# KERNEL PANIC — Code-drawn art direction

## Intent

The visual target is a deliberate terminal/CRT world that feels authored rather than assembled from generic shapes. The references in `media/Ideas/` are a moodboard: they establish density, contrast, hierarchy, framing, and the relationship between dossier-like information and geometric illustration. They are not runtime assets, a request to reproduce a screenshot, or permission to copy a proprietary mark.

The game should use a hybrid language:

- code-drawn enemies and programs remain the default for gameplay entities;
- a small number of carefully chosen authored assets may support atmosphere or history-specific presentation when code cannot communicate the material well;
- interface panels are rebuilt from first principles around player tasks, not migrated pixel-for-pixel from the current UI;
- visual detail is earned by improving silhouette, state communication, and tactility.

## Quality bar for every code-drawn entity

Before an enemy or program is considered complete, review it at gameplay scale and dossier scale:

1. **Silhouette:** Can a player distinguish it in a crowded wave without reading text?
2. **State:** Are idle, active, damaged, invulnerable, telegraphing, dead, and special states visibly distinct?
3. **Telegraph:** Does the warning precede the dangerous event by enough time, with a shape and color that survive color-vision differences?
4. **Motion:** Does the animation reinforce the behavior and avoid decorative noise? Reduced-motion settings must remove or simplify nonessential motion.
5. **Hitbox intent:** Does the visible body make the collision and danger envelope understandable? If not, add a restrained indicator instead of misleading ornament.
6. **Counterplay:** Can a player infer what to do from the visual language and the encounter behavior?
7. **Bounds:** Does the drawing remain inside its intended footprint at all scales and aspect ratios?
8. **Contrast:** Is the entity readable against the arena, HUD, and CRT treatment without relying on a single hue?
9. **Performance:** Does it avoid per-frame allocations, unbounded redraw work, and expensive effects when many instances are present?
10. **Accessibility:** Does it remain legible with reduced flashes, reduced motion, and color-assist profiles enabled?

## Visual primitives

Use a small, coherent vocabulary: angular frames, scanline or grid hints, vector-like outlines, measured glow, segmented bars, warning brackets, and terminal marks. Reuse `TacticalUI.angular_points`, shared tokens, and explicit draw helpers. Avoid adding one-off corner geometry or arbitrary colors to individual entities.

Detail should be layered:

- base silhouette;
- functional state mark;
- one or two identity details;
- optional low-cost atmosphere.

If removing a detail does not reduce recognition, state comprehension, or personality, it is probably not worth its rendering and maintenance cost.

## Palette and semantics

Color is semantic, not merely decorative. Pair colors with shape, position, motion, text, or fill pattern so a color-blind player can still understand danger, selection, success, and disabled states. Gameplay and UI code should consume `Balance.COL_*` and `TacticalUI` tokens instead of inventing literals.

## UI relationship

The rebuilt UI should borrow the reference mood without preserving the current layout. Menus, dossiers, pause, settings, and HUD should be task-first, adaptive, keyboard/gamepad/touch navigable, and readable at the smallest supported viewport. The playfield gets priority during combat: decorative framing may yield space when it conflicts with aiming, enemy visibility, or touch controls.

## Review checklist

For each new entity or surface, attach:

- a short behavior and counterplay description;
- a normal, narrow, wide, and touch-oriented capture when layout is involved;
- a focused regression probe for state transitions or input;
- a note explaining any intentional deviation from the shared tokens;
- a performance observation when the change affects per-frame drawing or entity count;
- a known-issues note when a platform or assistive feature is not yet verified.

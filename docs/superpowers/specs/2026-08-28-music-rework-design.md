# KERNEL PANIC Music Rework Design

**Date:** 2026-08-28

## Goal

Replace the short, repetitive music loops with a longer code-generated
soundtrack that feels varied in the menu, supports escalating arena
intensity, and gives boss encounters a stronger identity without changing
gameplay or adding runtime dependencies.

## Current system

- `tools/gen_audio.gd` generates all WAV assets, including `music_a`,
  `music_b`, and `music_c`.
- The generator writes mono, 16-bit, 44.1 kHz WAV files to
  `assets/audio_raw/`.
- `src/autoload/sfx.gd` loads the three stems, enables forward looping, starts
  them together, and crossfades stem `b` at intensity 1 and stem `c` at
  intensity 2.
- The menu starts the music at intensity 0. The arena raises intensity for
  overclock/combo play and boss encounters, so the stems must keep identical
  timing and loop length.

## Design

### Longer musical form

All three stems will use the same 16-bar form at 116 BPM, approximately
33 seconds per loop. Each stem will have four distinct four-bar sections
with controlled variation, a clear return to the opening motif, and a
bar-aligned loop boundary. This keeps the memory footprint modest while
making repetition much less obvious than the current 8-bar material.

### Stem roles

- `music_a`: the always-on menu/arena bed. It carries the neon cyberpunk
  pulse, bass movement, sparse percussion, and the main motif without
  becoming tiring when heard alone.
- `music_b`: the combat layer. It adds syncopated arpeggios and brighter
  rhythmic accents, but leaves enough frequency space for the base stem.
- `music_c`: the boss layer. It adds darker sub movement, tension pulses, and
  sparse high-impact accents. It must feel threatening without masking boss
  telegraph sounds.

The existing `Sfx` crossfade remains the sole intensity controller. No new
gameplay signals, difficulty values, or random streams are introduced.

### Determinism and assets

The generator will use fixed musical patterns and local/offline synthesis.
Runtime music will never consume `Game.rng`; the generated WAVs are static
project assets. No external DAW, network service, sample pack, or runtime
dependency is required.

### Runtime safety

`sfx.gd` will continue to tolerate missing audio files and will preserve the
existing mute, volume, pause, menu, and boss transitions. If runtime code
changes are needed, they will be limited to robustly deriving loop frames
from the WAV format rather than assuming a single channel/bit depth.

## Testing

The development harness will verify that:

1. all three music streams load;
2. each stream is at least 30 seconds long;
3. all streams share the same sample rate, channel count, frame count, and
   loop end;
4. each stream has forward looping enabled;
5. intensity 0, 1, and 2 still change stem audibility without errors.

The generator will be run before the full headless suite so the checked-in
WAV assets and their runtime representation are tested together.

## Scope exclusions

- No changes to enemy behavior, bosses, spawn rates, patches, healing,
  difficulty knobs, lock-on, or player movement.
- No new image assets.
- No release keystores, credentials, or private paths.
- No change to the current three-intensity gameplay contract.

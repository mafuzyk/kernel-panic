# KERNEL PANIC Music Rework Implementation Plan

> For agentic workers: REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

Goal: Replace the short repetitive music loops with three synchronized 16-bar procedural stems that vary across sections while preserving the existing menu/arena/boss intensity contract.

Architecture: Keep the existing three-stem AudioStreamPlayer design and its intensity crossfade. Expand only the offline generator's musical form, then add harness assertions for duration, synchronization, loop mode, and intensity safety. Runtime gameplay code remains unchanged.

Tech Stack: Godot 4.7.2, GDScript, mono 16-bit 44.1 kHz WAV assets, the existing tools/gen_audio.gd generator, and the existing headless autotest harness.

Spec: docs/superpowers/specs/2026-08-28-music-rework-design.md

## Global Constraints

- Use the existing three stems: music_a, music_b, and music_c.
- All stems must be the same 16-bar length at 116 BPM, approximately 33 seconds.
- Keep the output format mono, 16-bit, 44.1 kHz WAV.
- Do not consume Game.rng; music generation is offline and runtime music uses static assets.
- Do not change gameplay, balance, difficulty knobs, enemy behavior, player movement, or the three-level intensity contract.
- Do not add runtime dependencies or image assets.
- Run godot --headless --path . -- --autotest after every task.
- Do not commit APKs, binaries, keystores, credentials, .godot/, or private paths.

---

### Task 1: Add failing music contract tests

Files:
- Modify: src/autoload/dev_harness.gd:1000-1004

Interfaces:
- Consumes: Sfx._stems, AudioStreamWAV properties, and the existing _check() helper.
- Produces: Regression checks proving that generated stems are long, synchronized, looped, and safe for intensity changes.

- [ ] Step 1: Write the failing test

Immediately after the existing three-stem check and before the existing intensity calls, add:

~~~gdscript
	_check(Sfx._stems.size() == 3, "three music stems loaded")
	var music_streams: Array[AudioStreamWAV] = []
	for stem in Sfx._stems:
		var stream := stem.stream as AudioStreamWAV
		if stream != null:
			music_streams.append(stream)
	_check(music_streams.size() == 3, "three music streams expose WAV data")
	if music_streams.size() == 3:
		var first := music_streams[0]
		var min_frames := int(first.mix_rate * 30.0)
		_check(first.data.size() / 2 >= min_frames, "music stems are at least 30 seconds")
		for i in music_streams.size():
			var stream := music_streams[i]
			_check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "music stem %d loops forward" % i)
			_check(stream.mix_rate == first.mix_rate, "music stem %d sample rate matches" % i)
			_check(stream.stereo == first.stereo, "music stem %d channel layout matches" % i)
			_check(stream.data.size() == first.data.size(), "music stem %d length matches" % i)
			_check(stream.loop_end == first.loop_end, "music stem %d loop end matches" % i)
~~~

Keep the existing Sfx.set_intensity(2), Sfx.set_intensity(0), and _ticks(2)
lines directly after this block.

- [ ] Step 2: Run the test to verify it fails

Run:

~~~sh
godot --headless --path . -- --autotest
~~~

Expected: the suite reaches AT_FAIL music stems are at least 30 seconds,
because the current generated stems are 8 bars and shorter than the new
30-second floor. The command must not fail due to a parse error.

- [ ] Step 3: Commit the failing test

~~~sh
git add src/autoload/dev_harness.gd
git commit -m "test: define longer synchronized music stems"
~~~

If Git metadata is read-only in the execution environment, leave the file in
the workspace and record that the commit could not be created; do not stage
unrelated handoffs or build artifacts.

---

### Task 2: Expand the procedural music form

Files:
- Modify: tools/gen_audio.gd:227-300

Interfaces:
- Consumes: _buf(), _mix(), _tone(), _noise(), and _normalize().
- Produces: three 16-bar static music stems with the same sample count and distinct base/combat/boss roles.

- [ ] Step 1: Replace the base stem generator

Replace _music_base() with the following 16-bar arrangement. The four
four-bar sections use different roots, bass figures, and percussion density,
while the last section resolves back toward the opening root:

~~~gdscript
func _music_base() -> PackedFloat32Array:
	var bpm := 116.0
	var beat := 60.0 / bpm
	var bars := 16
	var total := beat * 4.0 * bars
	var b := _buf(total)
	var roots := [55.0, 55.0, 65.41, 49.0, 55.0, 73.42, 65.41, 49.0, 61.74, 55.0, 73.42, 49.0, 55.0, 55.0, 65.41, 49.0]
	var bass_shapes := [
		[1.0, 1.0, 1.5, 2.0, 1.0, 1.0, 2.0, 1.5],
		[1.0, 1.5, 2.0, 1.5, 1.0, 2.0, 1.5, 1.0],
		[1.0, 2.0, 1.0, 1.5, 1.5, 1.0, 2.0, 1.0],
		[1.0, 1.0, 2.0, 1.5, 1.0, 1.5, 2.0, 1.0],
	]
	for bar in bars:
		var t0 := bar * beat * 4.0
		var root: float = roots[bar]
		var shape: Array = bass_shapes[(bar / 4) % bass_shapes.size()]
		for beat_i in 4:
			_mix(b, _tone(0.16, 150.0, 44.0, 0.72, 0.001, 2.8, 0), t0 + beat_i * beat)
			if beat_i % 2 == 1 or bar % 4 == 3:
				_mix(b, _noise(0.045, 0.16, 0.001, 4.0, 8500), t0 + beat_i * beat)
		for e in 8:
			var f := root * shape[e]
			if bar >= 8 and e % 4 == 3:
				f *= 0.5
			_mix(b, _tone(beat * 0.42, f, f, 0.38, 0.004, 1.6, 1, 340), t0 + e * beat * 0.5)
		if bar % 4 == 2:
			_mix(b, _tone(beat * 0.7, root * 2.0, root * 1.5, 0.12, 0.04, 1.4, 2, 1200), t0 + beat * 2.0)
		if bar % 4 == 3:
			_mix(b, _noise(beat * 0.5, 0.08, 0.2, 1.4, 5200), t0 + beat * 3.0)
	return _normalize(b, 0.72)
~~~

- [ ] Step 2: Replace the combat layer generator

Replace _music_chain() with:

~~~gdscript
func _music_chain() -> PackedFloat32Array:
	var bpm := 116.0
	var beat := 60.0 / bpm
	var bars := 16
	var total := beat * 4.0 * bars
	var b := _buf(total)
	var arps := [
		[220.0, 261.6, 329.6, 392.0, 440.0, 392.0, 329.6, 261.6],
		[246.9, 293.7, 349.2, 415.3, 493.9, 415.3, 349.2, 293.7],
		[196.0, 246.9, 293.7, 369.9, 392.0, 369.9, 293.7, 246.9],
		[261.6, 311.1, 392.0, 466.2, 523.3, 466.2, 392.0, 311.1],
	]
	for bar in bars:
		var t0 := bar * beat * 4.0
		var seq: Array = arps[(bar / 4) % arps.size()]
		for e in 8:
			var t := t0 + e * beat * 0.5
			var accent := 0.2 if e % 2 == 0 else 0.13
			_mix(b, _tone(0.14, seq[e], seq[e], accent, 0.003, 2.2, 3), t)
			_mix(b, _tone(0.13, seq[e] * 2.0, seq[e] * 2.0, accent * 0.36, 0.003, 2.6, 3), t)
			if bar % 4 == 1 or bar % 4 == 3:
				_mix(b, _tone(0.09, seq[(e + 3) % 8] * 2.0, seq[(e + 3) % 8] * 2.0, 0.06, 0.002, 2.8, 1, 2800), t + beat * 0.25)
		if bar % 4 == 3:
			_mix(b, _tone(beat * 2.0, seq[0] * 2.0, seq[7] * 2.0, 0.11, 0.05, 1.2, 2, 4000), t0 + beat * 2.0)
	return _normalize(b, 0.5)
~~~

- [ ] Step 3: Replace the boss layer generator

Replace _music_boss() with:

~~~gdscript
func _music_boss() -> PackedFloat32Array:
	var bpm := 116.0
	var beat := 60.0 / bpm
	var bars := 16
	var total := beat * 4.0 * bars
	var b := _buf(total)
	var sub_roots := [36.7, 36.7, 41.2, 32.7, 36.7, 43.7, 41.2, 32.7, 38.9, 36.7, 43.7, 32.7, 36.7, 36.7, 41.2, 32.7]
	for bar in bars:
		var t0 := bar * beat * 4.0
		var sub: float = sub_roots[bar]
		_mix(b, _tone(beat * 3.6, sub, sub * 0.98, 0.46, 0.05, 0.8, 2, 200), t0)
		_mix(b, _tone(0.3, sub * 3.0, sub * 2.94, 0.28, 0.01, 1.6, 1, 700), t0)
		if bar % 4 == 1 or bar % 4 == 3:
			_mix(b, _tone(0.3, sub * 3.17, sub * 3.08, 0.2, 0.01, 1.6, 1, 700), t0 + beat * 2.0)
		for beat_i in 4:
			if beat_i % 2 == 0:
				_mix(b, _tone(0.1, 90.0 + bar * 1.5, 40.0, 0.42, 0.001, 3.0, 0), t0 + beat_i * beat)
		if bar % 4 == 2:
			_mix(b, _noise(beat * 2.0, 0.12, 0.7, 1.0, 2400), t0 + beat * 2.0)
		if bar % 4 == 3:
			_mix(b, _tone(beat * 0.8, sub * 6.0, sub * 3.0, 0.16, 0.04, 1.6, 2, 1600), t0 + beat * 3.0)
	return _normalize(b, 0.6)
~~~

- [ ] Step 4: Regenerate the static WAV assets

Run:

~~~sh
godot --headless --path . --script tools/gen_audio.gd
~~~

Expected: AUDIO_GEN_DONE, with assets/audio_raw/music_a.wav,
music_b.wav, and music_c.wav rewritten as approximately 33-second mono
16-bit WAVs.

- [ ] Step 5: Run the focused verification

Run:

~~~sh
godot --headless --path . -- --autotest
~~~

Expected: the new duration/synchronization checks pass and the command ends
with AUTOTEST_ALL_PASS. Existing gameplay, touch, boss, and intensity checks
must remain green.

- [ ] Step 6: Commit the generator and assets

~~~sh
git add tools/gen_audio.gd assets/audio_raw/music_a.wav assets/audio_raw/music_b.wav assets/audio_raw/music_c.wav src/autoload/dev_harness.gd
git commit -m "feat: expand procedural music stems"
~~~

Do not stage .godot/, build outputs, handoffs, or unrelated docs.

---

### Task 3: Validate exported audio and document the result

Files:
- Modify: none
- Verify: assets/audio_raw/music_a.wav, music_b.wav, and music_c.wav

Interfaces:
- Consumes: regenerated WAVs and the runtime harness.
- Produces: verified assets ready for the next Linux/APK export.

- [ ] Step 1: Inspect the generated files

Run:

~~~sh
ffprobe -v error -select_streams a:0 -show_entries stream=codec_name,sample_rate,channels,duration -of default=noprint_wrappers=1 assets/audio_raw/music_a.wav assets/audio_raw/music_b.wav assets/audio_raw/music_c.wav
~~~

Expected: all three entries report PCM 16-bit-compatible WAV audio, 44100 Hz,
one channel, and a duration of at least 30 seconds. If the installed ffprobe
does not accept multiple input paths, run the same command once per file.

- [ ] Step 2: Run the full project verification

Run:

~~~sh
godot --headless --path . -- --autotest
~~~

Expected: AUTOTEST_ALL_PASS and zero AT_FAIL.

- [ ] Step 3: Review the final diff

Run:

~~~sh
git diff --check
git status --short
~~~

Expected: only the planned generator, three music WAVs, test harness, and
music documentation are changed or untracked. Existing handoffs and build
artifacts remain preserved and are not staged.

- [ ] Step 4: Commit the verification record if needed

No source or asset change is required in this step. If a project changelog is
requested later, record the music rework there in a separate documentation
change; do not add a changelog change to this implementation by assumption.

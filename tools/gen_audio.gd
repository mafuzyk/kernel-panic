extends SceneTree
const SR := 44100
const OUT := "res://assets/audio_raw/"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_write("shoot", _shoot())
	_write("hit", _hit())
	_write("explode", _explode())
	_write("explode_big", _explode_big())
	_write("pickup", _pickup())
	_write("dash", _dash())
	_write("hurt", _hurt())
	_write("ready", _ready_chime())
	_write("overclock", _overclock())
	_write("wave", _wave())
	_write("boss", _boss())
	_write("ui", _ui())
	_write("gameover", _gameover())
	_write("charge", _charge())
	_write("music_a", _music_base())
	_write("music_b", _music_chain())
	_write("music_c", _music_boss())
	print("AUDIO_GEN_DONE")
	quit(0)

func _buf(dur: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(dur * SR))
	return b

func _mix(dst: PackedFloat32Array, src: PackedFloat32Array, at: float, gain: float = 1.0) -> void:
	var start := int(at * SR)
	for i in src.size():
		var idx := start + i
		if idx >= 0 and idx < dst.size():
			dst[idx] += src[i] * gain

func _osc_sine(ph: float) -> float:
	return sin(ph)

func _osc_square(ph: float) -> float:
	return 1.0 if fmod(ph, TAU) < PI else -1.0

func _osc_saw(ph: float) -> float:
	return fmod(ph / TAU, 1.0) * 2.0 - 1.0

func _osc_tri(ph: float) -> float:
	return 2.0 * absf(fmod(ph / TAU, 1.0) * 2.0 - 1.0) - 1.0

func _tone(dur: float, f0: float, f1: float, amp: float, attack: float, curve: float, kind: int = 0, lp := 0.0) -> PackedFloat32Array:
	var n := int(dur * SR)
	var b := PackedFloat32Array()
	b.resize(n)
	var ph := 0.0
	var lpv := 0.0
	var lpa := 1.0 if lp <= 0.0 else clampf(1.0 - exp(-TAU * lp / SR), 0.001, 1.0)
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		ph += TAU * f / SR
		var v := 0.0
		match kind:
			0: v = _osc_sine(ph)
			1: v = _osc_square(ph)
			2: v = _osc_saw(ph)
			3: v = _osc_tri(ph)
		if lp > 0.0:
			lpv += (v - lpv) * lpa
			v = lpv
		var env := 1.0
		if t < attack:
			env = t / attack
		env *= pow(1.0 - t, curve)
		b[i] = v * env * amp
	return b

func _noise(dur: float, amp: float, attack: float, curve: float, lp := 0.0, lp1 := -1.0) -> PackedFloat32Array:
	var n := int(dur * SR)
	var b := PackedFloat32Array()
	b.resize(n)
	var lpv := 0.0
	var lpa := 1.0 if lp <= 0.0 else clampf(1.0 - exp(-TAU * lp / SR), 0.001, 1.0)
	for i in n:
		var t := float(i) / n
		var cutoff := lp
		if lp1 >= 0.0:
			cutoff = lerpf(lp, lp1, t)
			lpa = clampf(1.0 - exp(-TAU * maxf(cutoff, 20.0) / SR), 0.001, 1.0)
		var v := randf_range(-1.0, 1.0)
		if cutoff > 0.0:
			lpv += (v - lpv) * lpa
			v = lpv
		var env := 1.0
		if t < attack:
			env = t / attack
		env *= pow(1.0 - t, curve)
		b[i] = v * env * amp
	return b

func _normalize(b: PackedFloat32Array, target: float) -> PackedFloat32Array:
	var peak := 0.001
	for v in b:
		peak = maxf(peak, absf(v))
	var g := target / peak
	for i in b.size():
		b[i] = tanh(b[i] * g * 1.1) * 0.92
	return b

func _write(name: String, b: PackedFloat32Array) -> void:
	var data := PackedByteArray()
	data.resize(b.size() * 2)
	for i in b.size():
		var v := int(clampf(b[i], -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	var f := FileAccess.open(OUT + name + ".wav", FileAccess.WRITE)
	var file_size := 36 + data.size()
	f.store_32(0x46464952)
	f.store_32(file_size)
	f.store_32(0x45564157)
	f.store_32(0x20746D66)
	f.store_32(16)
	f.store_16(1)
	f.store_16(1)
	f.store_32(SR)
	f.store_32(SR * 2)
	f.store_16(2)
	f.store_16(16)
	f.store_32(0x61746164)
	f.store_32(data.size())
	f.store_buffer(data)
	f.close()

func _shoot() -> PackedFloat32Array:
	var b := _buf(0.1)
	_mix(b, _tone(0.08, 1500, 650, 0.6, 0.004, 2.2, 1, 3200), 0.0, 1.0)
	_mix(b, _noise(0.05, 0.18, 0.002, 3.0, 4500), 0.0)
	return _normalize(b, 0.62)

func _hit() -> PackedFloat32Array:
	var b := _buf(0.09)
	_mix(b, _noise(0.06, 0.5, 0.001, 3.5, 1600), 0.0)
	_mix(b, _tone(0.07, 240, 130, 0.5, 0.001, 2.5, 0), 0.0)
	return _normalize(b, 0.55)

func _explode() -> PackedFloat32Array:
	var b := _buf(0.45)
	_mix(b, _noise(0.42, 0.9, 0.004, 2.6, 3200, 160), 0.0)
	_mix(b, _tone(0.3, 110, 38, 0.8, 0.002, 2.0, 0), 0.0)
	_mix(b, _noise(0.12, 0.4, 0.001, 4.0, 6000), 0.0)
	return _normalize(b, 0.85)

func _explode_big() -> PackedFloat32Array:
	var b := _buf(0.85)
	_mix(b, _noise(0.8, 1.0, 0.006, 2.2, 2200, 90), 0.0)
	_mix(b, _tone(0.6, 80, 26, 1.0, 0.004, 1.6, 0), 0.0)
	_mix(b, _tone(0.4, 55, 30, 0.6, 0.01, 2.0, 2, 500), 0.05)
	return _normalize(b, 0.92)

func _pickup() -> PackedFloat32Array:
	var b := _buf(0.12)
	_mix(b, _tone(0.09, 760, 1280, 0.6, 0.004, 1.8, 0), 0.0)
	_mix(b, _tone(0.09, 1520, 2560, 0.25, 0.004, 2.2, 0), 0.0)
	return _normalize(b, 0.42)

func _dash() -> PackedFloat32Array:
	var b := _buf(0.24)
	_mix(b, _noise(0.22, 0.7, 0.02, 1.8, 3400, 420), 0.0)
	_mix(b, _tone(0.18, 900, 240, 0.3, 0.01, 2.0, 3), 0.0)
	return _normalize(b, 0.55)

func _hurt() -> PackedFloat32Array:
	var b := _buf(0.32)
	_mix(b, _tone(0.28, 330, 100, 0.9, 0.003, 1.6, 2, 1900), 0.0)
	_mix(b, _noise(0.16, 0.5, 0.001, 3.0, 2400), 0.0)
	_mix(b, _tone(0.2, 160, 70, 0.6, 0.002, 2.0, 1, 800), 0.0)
	return _normalize(b, 0.75)

func _ready_chime() -> PackedFloat32Array:
	var b := _buf(0.34)
	_mix(b, _tone(0.13, 659, 659, 0.55, 0.006, 1.4, 0), 0.0)
	_mix(b, _tone(0.2, 988, 988, 0.55, 0.006, 1.2, 0), 0.11)
	_mix(b, _tone(0.24, 1976, 1976, 0.18, 0.006, 2.0, 0), 0.11)
	return _normalize(b, 0.5)

func _overclock() -> PackedFloat32Array:
	var b := _buf(0.62)
	_mix(b, _tone(0.58, 170, 1450, 0.6, 0.02, 1.2, 2, 2600), 0.0)
	_mix(b, _noise(0.55, 0.4, 0.25, 1.4, 5200), 0.0)
	_mix(b, _tone(0.5, 640, 2200, 0.22, 0.2, 1.6, 0), 0.08)
	return _normalize(b, 0.7)

func _wave() -> PackedFloat32Array:
	var b := _buf(0.52)
	_mix(b, _tone(0.2, 440, 436, 0.5, 0.008, 1.2, 1, 1900), 0.0)
	_mix(b, _tone(0.24, 330, 326, 0.5, 0.008, 1.2, 1, 1700), 0.22)
	return _normalize(b, 0.45)

func _boss() -> PackedFloat32Array:
	var b := _buf(1.1)
	var freqs := [110.0, 92.5, 73.4]
	for i in 3:
		_mix(b, _tone(0.34, freqs[i], freqs[i] * 0.98, 0.6, 0.01, 1.1, 2, 900), i * 0.3)
		_mix(b, _tone(0.34, freqs[i] * 2, freqs[i] * 1.98, 0.25, 0.01, 1.4, 1, 1200), i * 0.3)
	_mix(b, _noise(0.9, 0.2, 0.5, 1.5, 800), 0.2)
	return _normalize(b, 0.6)

func _ui() -> PackedFloat32Array:
	var b := _buf(0.08)
	_mix(b, _tone(0.06, 920, 900, 0.5, 0.003, 2.0, 3), 0.0)
	return _normalize(b, 0.4)

func _gameover() -> PackedFloat32Array:
	var b := _buf(1.35)
	var notes := [220.0, 164.8, 130.8, 110.0]
	for i in 4:
		_mix(b, _tone(0.4, notes[i], notes[i] * 0.99, 0.5, 0.01, 1.3, 2, 1300), i * 0.26)
		_mix(b, _tone(0.4, notes[i] / 2.0, notes[i] / 2.0, 0.4, 0.01, 1.2, 0), i * 0.26)
	return _normalize(b, 0.55)

func _charge() -> PackedFloat32Array:
	var b := _buf(0.4)
	_mix(b, _tone(0.38, 480, 1150, 0.5, 0.05, 1.0, 0), 0.0)
	_mix(b, _tone(0.38, 960, 2300, 0.2, 0.05, 1.4, 0), 0.0)
	return _normalize(b, 0.4)

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
			var f: float = root * float(shape[e])
			if bar >= 8 and e % 4 == 3:
				f *= 0.5
			_mix(b, _tone(beat * 0.42, f, f, 0.38, 0.004, 1.6, 1, 340), t0 + e * beat * 0.5)
		if bar % 4 == 2:
			_mix(b, _tone(beat * 0.7, root * 2.0, root * 1.5, 0.12, 0.04, 1.4, 2, 1200), t0 + beat * 2.0)
		if bar % 4 == 3:
			_mix(b, _noise(beat * 0.5, 0.08, 0.2, 1.4, 5200), t0 + beat * 3.0)
	return _normalize(b, 0.72)

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
			_mix(b, _tone(beat * 2.0, seq[0] * 2.0, seq[7] * 2.0, 0.12, 0.05, 1.2, 2, 4000), t0 + beat * 2.0)
	return _normalize(b, 0.5)

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

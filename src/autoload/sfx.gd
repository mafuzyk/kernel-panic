extends Node

const DIR := "res://assets/audio_raw/"
const POOL_SIZE := 14

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0
var _music: AudioStreamPlayer
var _stems: Array[AudioStreamPlayer] = []
var _intensity := 0
var _bus_sfx := -1
var _bus_music := -1
var muted := false
var sfx_vol := 0.9
var music_vol := 0.75
var haptics_enabled := true
var shake_level := 2
var target_fps := 60
var touch_scale := 1.0
var aim_mode := "drag"
var color_assist := false
var show_run_info := false

func haptic(ms: int) -> void:
	if not haptics_enabled:
		return
	Input.vibrate_handheld(ms)

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bus_sfx = AudioServer.bus_count
	AudioServer.add_bus(_bus_sfx)
	AudioServer.set_bus_name(_bus_sfx, "SFX")
	_bus_music = AudioServer.bus_count
	AudioServer.add_bus(_bus_music)
	AudioServer.set_bus_name(_bus_music, "Music")

func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_load_settings()
	_load_all()
	_apply_volumes()

func _load_all() -> void:
	for name in ["shoot", "hit", "explode", "explode_big", "pickup", "dash", "hurt", "ready", "overclock", "wave", "boss", "ui", "gameover", "charge", "music_a", "music_b", "music_c"]:
		var s := _load_wav(DIR + name + ".wav")
		if s != null:
			_streams[name] = s
	for stem in ["a", "b", "c"]:
		if _streams.has("music_" + stem):
			var stream: AudioStreamWAV = _streams["music_" + stem]
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			var loop_frames := int(round(stream.get_length() * stream.mix_rate))
			if loop_frames <= 0:
				loop_frames = stream.data.size() / 2
			stream.loop_end = loop_frames
			var p := AudioStreamPlayer.new()
			p.stream = stream
			p.bus = "Music"
			p.volume_db = -80.0 if stem != "a" else linear_to_db(music_vol) - 6.0
			add_child(p)
			_stems.append(p)

func _load_wav(path: String) -> AudioStreamWAV:
	var s := load(path)
	if s is AudioStreamWAV:
		return s
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var b := f.get_buffer(f.get_length())
	f.close()
	if b.size() < 44 or b.slice(0, 4) != "RIFF".to_ascii_buffer():
		return null
	var pos := 12
	var fmt := {}
	var data := PackedByteArray()
	while pos + 8 <= b.size():
		var cid := b.slice(pos, pos + 4).get_string_from_ascii()
		var csize := b.decode_u32(pos + 4)
		var body := b.slice(pos + 8, mini(pos + 8 + csize, b.size()))
		if cid == "fmt ":
			fmt["format"] = body.decode_u16(0)
			fmt["channels"] = body.decode_u16(2)
			fmt["rate"] = body.decode_u32(4)
			fmt["bits"] = body.decode_u16(14)
		elif cid == "data":
			data = body
		pos += 8 + csize + (csize & 1)
	if fmt.is_empty() or data.is_empty():
		return null
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS if int(fmt.get("bits", 16)) == 16 else AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = int(fmt.get("rate", 44100))
	wav.stereo = int(fmt.get("channels", 1)) > 1
	wav.data = data
	return wav

func play(name: String, pitch: float = 1.0, vol_db: float = 0.0, jitter: float = 0.05) -> void:
	if muted or not _streams.has(name):
		return
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % POOL_SIZE
	p.stream = _streams[name]
	p.pitch_scale = clampf(pitch * randf_range(1.0 - jitter, 1.0 + jitter), 0.1, 3.0)
	p.volume_db = vol_db + linear_to_db(sfx_vol)
	p.play()

func play_music() -> void:
	if _stems.is_empty() or _stems[0].playing:
		return
	for p in _stems:
		p.play()

func stop_music() -> void:
	for p in _stems:
		p.stop()

func set_intensity(level: int) -> void:
	if level == _intensity or _stems.size() < 3:
		return
	_intensity = level
	var targets := [linear_to_db(music_vol) - 6.0, -80.0, -80.0]
	if level >= 1:
		targets[1] = linear_to_db(music_vol) - 4.0
	if level >= 2:
		targets[2] = linear_to_db(music_vol) - 3.0
	for i in 3:
		var tw := create_tween()
		tw.tween_property(_stems[i], "volume_db", targets[i], 0.9)

func duck_music(db: float, dur: float) -> void:
	if _stems.is_empty():
		return
	var tw := create_tween()
	tw.tween_property(_stems[0], "volume_db", linear_to_db(music_vol) - 6.0 + db, 0.08)
	tw.tween_interval(dur)
	tw.tween_property(_stems[0], "volume_db", linear_to_db(music_vol) - 6.0, 0.6)

func toggle_mute() -> void:
	set_muted(not muted)

func set_muted(v: bool) -> void:
	muted = v
	_apply_volumes()
	save_settings()

func set_sfx_vol(v: float) -> void:
	sfx_vol = clampf(v, 0.0, 1.0)
	_apply_volumes()
	save_settings()

func set_music_vol(v: float) -> void:
	music_vol = clampf(v, 0.0, 1.0)
	_apply_volumes()
	save_settings()

func _apply_volumes() -> void:
	AudioServer.set_bus_mute(0, muted)
	AudioServer.set_bus_volume_db(_bus_sfx, linear_to_db(maxf(sfx_vol, 0.0001)))
	AudioServer.set_bus_volume_db(_bus_music, linear_to_db(maxf(music_vol, 0.0001)) - 6.0)
	set_intensity(_intensity)

const SAVE_PATH := "user://kernel_panic.cfg"

func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	muted = cf.get_value("audio", "muted", false)
	sfx_vol = cf.get_value("audio", "sfx_vol", 0.9)
	music_vol = cf.get_value("audio", "music_vol", 0.75)
	haptics_enabled = cf.get_value("feel", "haptics", true)
	shake_level = cf.get_value("feel", "shake", 2)
	target_fps = cf.get_value("feel", "target_fps", 60)
	Engine.max_fps = target_fps
	touch_scale = cf.get_value("feel", "touch_scale", 1.0)
	aim_mode = cf.get_value("feel", "aim_mode", "drag")
	color_assist = bool(cf.get_value("feel", "color_assist", false))
	show_run_info = bool(cf.get_value("feel", "show_run_info", false))

func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	cf.set_value("audio", "muted", muted)
	cf.set_value("audio", "sfx_vol", sfx_vol)
	cf.set_value("audio", "music_vol", music_vol)
	cf.set_value("feel", "haptics", haptics_enabled)
	cf.set_value("feel", "shake", shake_level)
	cf.set_value("feel", "target_fps", target_fps)
	cf.set_value("feel", "touch_scale", touch_scale)
	cf.set_value("feel", "aim_mode", aim_mode)
	cf.set_value("feel", "color_assist", color_assist)
	cf.set_value("feel", "show_run_info", show_run_info)
	cf.save(SAVE_PATH)

func set_aim_mode(v: String) -> void:
	aim_mode = v
	save_settings()

func set_touch_scale(v: float) -> void:
	touch_scale = v
	save_settings()

func set_target_fps(v: int) -> void:
	target_fps = v
	Engine.max_fps = v
	save_settings()

func set_color_assist(v: bool) -> void:
	color_assist = v
	save_settings()

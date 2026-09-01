extends Node

const DIR := "res://assets/audio_raw/"
const POOL_SIZE := 14
const ContentCatalog = preload("res://src/data/content_catalog.gd")

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
var fullscreen := false
var touch_scale := 1.0
var aim_mode := "drag"
var locale := "en"
var color_assist := false
var reduced_motion := false
var reduced_flashes := false
var left_handed_touch := false
var show_run_info := false
var music_variant := "normal"
var offensive_music_enabled := true
var defensive_music_enabled := true
var last_accessibility_persisted := true
var _settings_path_override := ""
var _patch_levels: Dictionary = {}
var _stem_tweens: Array = []

const ACCESSIBILITY_SCHEMA_VERSION := 3
const ACCESSIBILITY_TOUCH_SCALES := [0.85, 1.0, 1.2]
const DISPLAY_FPS_OPTIONS := [30, 60, 120, 0]
const PATCH_MUSIC_CROSSFADE_SECONDS := 0.5

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

func set_music_variant(variant: String) -> void:
	music_variant = variant if variant in ["normal", "crt_heavy", "crt_soft", "clean"] else "normal"
	var pitch := 1.0
	match music_variant:
		"crt_heavy":
			pitch = 0.78
		"crt_soft":
			pitch = 0.92
		"clean":
			pitch = 1.04
	for stem in _stems:
		stem.pitch_scale = pitch

func stop_music() -> void:
	for p in _stems:
		p.stop()

func set_intensity(level: int) -> void:
	var normalized_level := clampi(level, 0, 2)
	var changed := normalized_level != _intensity
	_intensity = normalized_level
	if not changed or _stems.size() < 3:
		return
	_apply_music_targets(0.9)

func patch_music_supported() -> bool:
	var display_name := DisplayServer.get_name().to_lower()
	return display_name != "headless" and OS.get_environment("KP_FORCE_TOUCH").is_empty() and not DisplayServer.is_touchscreen_available()

func set_patch_layers(levels: Dictionary) -> void:
	_patch_levels = levels.duplicate(true)
	_apply_music_targets(PATCH_MUSIC_CROSSFADE_SECONDS)

func set_music_layer_enabled(layer: String, enabled: bool) -> bool:
	var previous_offensive := offensive_music_enabled
	var previous_defensive := defensive_music_enabled
	if layer == "offensive":
		offensive_music_enabled = enabled
	elif layer == "defensive":
		defensive_music_enabled = enabled
	else:
		return false
	_apply_music_targets(PATCH_MUSIC_CROSSFADE_SECONDS)
	last_accessibility_persisted = _save_settings_result()
	if not last_accessibility_persisted:
		offensive_music_enabled = previous_offensive
		defensive_music_enabled = previous_defensive
		_apply_music_targets(0.0)
	return last_accessibility_persisted

func patch_music_snapshot() -> Dictionary:
	return {
		"supported": patch_music_supported(),
		"offensive_active": _patch_music_layer_active("offensive"),
		"defensive_active": _patch_music_layer_active("defensive"),
		"offensive_enabled": offensive_music_enabled,
		"defensive_enabled": defensive_music_enabled,
		"crossfade_seconds": PATCH_MUSIC_CROSSFADE_SECONDS,
		"intensity": _intensity,
	}.duplicate(true)

func _patch_music_layer_active(layer: String) -> bool:
	var layers: Dictionary = ContentCatalog.PATCH_MUSIC_LAYERS
	for patch_id in layers.get(layer, []):
		if int(_patch_levels.get(patch_id, 0)) > 0:
			return true
	return false

func _apply_music_targets(duration: float) -> void:
	if _stems.size() < 3:
		return
	var targets := [linear_to_db(music_vol) - 6.0, -80.0, -80.0]
	if _intensity >= 1 or (patch_music_supported() and offensive_music_enabled and _patch_music_layer_active("offensive")):
		targets[1] = linear_to_db(music_vol) - 4.0
	if _intensity >= 2 or (patch_music_supported() and defensive_music_enabled and _patch_music_layer_active("defensive")):
		targets[2] = linear_to_db(music_vol) - 3.0
	for i in 3:
		if duration <= 0.0:
			_stems[i].volume_db = targets[i]
			continue
		while _stem_tweens.size() <= i:
			_stem_tweens.append(null)
		var previous: Tween = _stem_tweens[i]
		if previous != null and previous.is_valid():
			previous.kill()
		var tw := create_tween()
		_stem_tweens[i] = tw
		tw.tween_property(_stems[i], "volume_db", targets[i], duration)

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
	_apply_music_targets(0.0)

const SAVE_PATH := "user://kernel_panic.cfg"

func _settings_path() -> String:
	return _settings_path_override if not _settings_path_override.is_empty() else SAVE_PATH

func _load_settings() -> void:
	target_fps = default_target_fps()
	fullscreen = false
	var cf := ConfigFile.new()
	if cf.load(_settings_path()) != OK:
		_apply_display_settings()
		return
	muted = cf.get_value("audio", "muted", false)
	sfx_vol = cf.get_value("audio", "sfx_vol", 0.9)
	music_vol = cf.get_value("audio", "music_vol", 0.75)
	var raw_haptics = cf.get_value("feel", "haptics", true)
	var raw_shake = cf.get_value("feel", "shake", 2)
	var legacy_target_fps = cf.get_value("feel", "target_fps", target_fps)
	target_fps = _normalize_target_fps(cf.get_value("display", "target_fps", legacy_target_fps), target_fps)
	fullscreen = _normalize_bool(cf.get_value("display", "fullscreen", false), false)
	var raw_touch_scale = cf.get_value("feel", "touch_scale", 1.0)
	var raw_reduced_motion = cf.get_value("feel", "reduced_motion", false)
	var raw_reduced_flashes = cf.get_value("feel", "reduced_flashes", false)
	var raw_left_handed_touch = cf.get_value("feel", "left_handed_touch", false)
	aim_mode = cf.get_value("feel", "aim_mode", "drag")
	var accessibility := _normalize_accessibility_profile({
		"color_assist": cf.get_value("feel", "color_assist", false),
		"haptics_enabled": raw_haptics,
		"shake_level": raw_shake,
		"touch_scale": raw_touch_scale,
		"reduced_motion": raw_reduced_motion,
		"reduced_flashes": raw_reduced_flashes,
		"left_handed_touch": raw_left_handed_touch,
	})
	haptics_enabled = accessibility["haptics_enabled"]
	shake_level = accessibility["shake_level"]
	touch_scale = accessibility["touch_scale"]
	color_assist = accessibility["color_assist"]
	reduced_motion = accessibility["reduced_motion"]
	reduced_flashes = accessibility["reduced_flashes"]
	left_handed_touch = accessibility["left_handed_touch"]
	var saved_locale := str(cf.get_value("localization", "locale", "en"))
	locale = saved_locale if saved_locale in ["en", "pt-BR"] else "en"
	var music_defaults := _music_layer_defaults()
	offensive_music_enabled = _normalize_bool(cf.get_value("accessibility", "offensive_music_enabled", music_defaults["offensive_music_enabled"]), bool(music_defaults["offensive_music_enabled"]))
	defensive_music_enabled = _normalize_bool(cf.get_value("accessibility", "defensive_music_enabled", music_defaults["defensive_music_enabled"]), bool(music_defaults["defensive_music_enabled"]))
	show_run_info = bool(cf.get_value("feel", "show_run_info", false))
	_apply_display_settings()

func save_settings() -> void:
	_save_settings_result()

func _save_settings_result() -> bool:
	var cf := ConfigFile.new()
	var save_path := _settings_path()
	var load_result := cf.load(save_path)
	if load_result != OK and load_result != ERR_FILE_NOT_FOUND:
		return false
	cf.set_value("audio", "muted", muted)
	cf.set_value("audio", "sfx_vol", sfx_vol)
	cf.set_value("audio", "music_vol", music_vol)
	cf.set_value("feel", "haptics", haptics_enabled)
	cf.set_value("feel", "shake", shake_level)
	# Keep the old key readable for older builds and external settings tools.
	cf.set_value("feel", "target_fps", target_fps)
	cf.set_value("feel", "touch_scale", touch_scale)
	cf.set_value("feel", "reduced_motion", reduced_motion)
	cf.set_value("feel", "reduced_flashes", reduced_flashes)
	cf.set_value("feel", "left_handed_touch", left_handed_touch)
	cf.set_value("feel", "aim_mode", aim_mode)
	cf.set_value("feel", "color_assist", color_assist)
	cf.set_value("feel", "show_run_info", show_run_info)
	cf.set_value("localization", "locale", locale)
	cf.set_value("accessibility", "offensive_music_enabled", offensive_music_enabled)
	cf.set_value("accessibility", "defensive_music_enabled", defensive_music_enabled)
	cf.set_value("display", "fullscreen", fullscreen)
	cf.set_value("display", "target_fps", target_fps)
	return cf.save(save_path) == OK

func set_aim_mode(v: String) -> void:
	aim_mode = v
	save_settings()

func set_touch_scale(v: float) -> void:
	touch_scale = v
	save_settings()

func set_target_fps(v: int) -> void:
	target_fps = _normalize_target_fps(v, default_target_fps())
	Engine.max_fps = target_fps
	save_settings()

func set_fullscreen(v: bool) -> void:
	fullscreen = v
	_apply_display_settings()
	save_settings()

func default_target_fps() -> int:
	if DisplayServer.get_name().to_lower() == "headless":
		return 60
	return 60 if DisplayServer.is_touchscreen_available() or OS.get_environment("KP_FORCE_TOUCH") != "" else 0

func display_snapshot() -> Dictionary:
	return {
		"fullscreen": bool(fullscreen),
		"target_fps": int(target_fps),
		"target_fps_options": DISPLAY_FPS_OPTIONS.duplicate(),
		"default_target_fps": default_target_fps(),
	}.duplicate(true)

func _normalize_target_fps(value, fallback: int) -> int:
	var candidate := int(value) if value is int or value is float else fallback
	return candidate if candidate in DISPLAY_FPS_OPTIONS else fallback

func _apply_display_settings() -> void:
	Engine.max_fps = target_fps
	if DisplayServer.get_name().to_lower() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func set_color_assist(v: bool) -> void:
	color_assist = v
	save_settings()

func current_locale() -> String:
	return locale

func set_locale(v: String) -> bool:
	if v not in ["en", "pt-BR"]:
		return false
	var previous := locale
	locale = v
	if _save_settings_result():
		return true
	locale = previous
	return false

func _music_layer_defaults() -> Dictionary:
	return {"offensive_music_enabled": true, "defensive_music_enabled": true}

func accessibility_defaults() -> Dictionary:
	return {
		"color_assist": false,
		"haptics_enabled": true,
		"shake_level": 2,
		"touch_scale": 1.0,
		"reduced_motion": false,
		"reduced_flashes": false,
		"left_handed_touch": false,
	}

func _normalize_accessibility_profile(profile: Dictionary) -> Dictionary:
	var defaults := accessibility_defaults()
	var shake_value = profile.get("shake_level", defaults["shake_level"])
	var shake: int = int(defaults["shake_level"])
	if shake_value is int or shake_value is float:
		shake = clampi(int(shake_value), 0, 2)
	var touch_value = profile.get("touch_scale", defaults["touch_scale"])
	var touch: float = float(defaults["touch_scale"])
	if touch_value is int or touch_value is float:
		var numeric_touch := clampf(float(touch_value), ACCESSIBILITY_TOUCH_SCALES[0], ACCESSIBILITY_TOUCH_SCALES[-1])
		touch = ACCESSIBILITY_TOUCH_SCALES[0]
		for supported_scale in ACCESSIBILITY_TOUCH_SCALES:
			if absf(float(supported_scale) - numeric_touch) < absf(float(touch) - numeric_touch):
				touch = supported_scale
	return {
		"color_assist": _normalize_bool(profile.get("color_assist", defaults["color_assist"]), bool(defaults["color_assist"])),
		"haptics_enabled": _normalize_bool(profile.get("haptics_enabled", defaults["haptics_enabled"]), bool(defaults["haptics_enabled"])),
		"shake_level": shake,
		"touch_scale": touch,
		"reduced_motion": _normalize_bool(profile.get("reduced_motion", defaults["reduced_motion"]), bool(defaults["reduced_motion"])),
		"reduced_flashes": _normalize_bool(profile.get("reduced_flashes", defaults["reduced_flashes"]), bool(defaults["reduced_flashes"])),
		"left_handed_touch": _normalize_bool(profile.get("left_handed_touch", defaults["left_handed_touch"]), bool(defaults["left_handed_touch"])),
	}

func _normalize_bool(value, fallback: bool) -> bool:
	if value is bool:
		return value
	if value is int or value is float:
		return int(value) != 0
	if value is String:
		var normalized: String = value.to_lower()
		if normalized in ["true", "yes", "on", "1"]:
			return true
		if normalized in ["false", "no", "off", "0"]:
			return false
	return fallback

func apply_accessibility_profile(profile: Dictionary, persist := true) -> Dictionary:
	var requested := {
		"color_assist": color_assist,
		"haptics_enabled": haptics_enabled,
		"shake_level": shake_level,
		"touch_scale": touch_scale,
		"reduced_motion": reduced_motion,
		"reduced_flashes": reduced_flashes,
		"left_handed_touch": left_handed_touch,
	}
	for key in requested.keys():
		if profile.has(key):
			requested[key] = profile[key]
	var normalized: Dictionary = _normalize_accessibility_profile(requested)
	var previous: Dictionary = {
		"color_assist": color_assist,
		"haptics_enabled": haptics_enabled,
		"shake_level": shake_level,
		"touch_scale": touch_scale,
		"reduced_motion": reduced_motion,
		"reduced_flashes": reduced_flashes,
		"left_handed_touch": left_handed_touch,
		"offensive_music_enabled": offensive_music_enabled,
		"defensive_music_enabled": defensive_music_enabled,
	}
	color_assist = normalized["color_assist"]
	haptics_enabled = normalized["haptics_enabled"]
	shake_level = normalized["shake_level"]
	touch_scale = normalized["touch_scale"]
	reduced_motion = normalized["reduced_motion"]
	reduced_flashes = normalized["reduced_flashes"]
	left_handed_touch = normalized["left_handed_touch"]
	if profile.has("offensive_music_enabled"):
		offensive_music_enabled = _normalize_bool(profile["offensive_music_enabled"], offensive_music_enabled)
	if profile.has("defensive_music_enabled"):
		defensive_music_enabled = _normalize_bool(profile["defensive_music_enabled"], defensive_music_enabled)
	_apply_music_targets(PATCH_MUSIC_CROSSFADE_SECONDS)
	var persisted := true
	if persist:
		persisted = _save_settings_result()
		if not persisted:
			color_assist = previous["color_assist"]
			haptics_enabled = previous["haptics_enabled"]
			shake_level = previous["shake_level"]
			touch_scale = previous["touch_scale"]
			reduced_motion = previous["reduced_motion"]
			reduced_flashes = previous["reduced_flashes"]
			left_handed_touch = previous["left_handed_touch"]
			offensive_music_enabled = previous["offensive_music_enabled"]
			defensive_music_enabled = previous["defensive_music_enabled"]
			_apply_music_targets(0.0)
	last_accessibility_persisted = persisted
	return normalized.duplicate(true)

func reset_accessibility_profile(persist := true) -> bool:
	var previous: Dictionary = {
		"color_assist": color_assist,
		"haptics_enabled": haptics_enabled,
		"shake_level": shake_level,
		"touch_scale": touch_scale,
		"reduced_motion": reduced_motion,
		"reduced_flashes": reduced_flashes,
		"left_handed_touch": left_handed_touch,
		"offensive_music_enabled": offensive_music_enabled,
		"defensive_music_enabled": defensive_music_enabled,
	}
	var defaults := accessibility_defaults()
	apply_accessibility_profile(defaults, false)
	var music_defaults := _music_layer_defaults()
	offensive_music_enabled = bool(music_defaults["offensive_music_enabled"])
	defensive_music_enabled = bool(music_defaults["defensive_music_enabled"])
	_apply_music_targets(PATCH_MUSIC_CROSSFADE_SECONDS)
	if not persist:
		return true
	var persisted := _save_settings_result()
	last_accessibility_persisted = persisted
	if not persisted:
		color_assist = previous["color_assist"]
		haptics_enabled = previous["haptics_enabled"]
		shake_level = previous["shake_level"]
		touch_scale = previous["touch_scale"]
		reduced_motion = previous["reduced_motion"]
		reduced_flashes = previous["reduced_flashes"]
		left_handed_touch = previous["left_handed_touch"]
		offensive_music_enabled = previous["offensive_music_enabled"]
		defensive_music_enabled = previous["defensive_music_enabled"]
		_apply_music_targets(0.0)
	return persisted

func reload_settings() -> void:
	_load_settings()

func accessibility_snapshot() -> Dictionary:
	var required := ["muted", "haptics_enabled", "shake_level", "target_fps", "touch_scale", "reduced_motion", "reduced_flashes", "left_handed_touch", "aim_mode", "color_assist", "show_run_info"]
	var optional := ["sfx_volume", "music_volume", "music_variant", "palette", "music_layers"]
	var profile := _normalize_accessibility_profile({
		"color_assist": color_assist,
		"haptics_enabled": haptics_enabled,
		"shake_level": shake_level,
		"touch_scale": touch_scale,
		"reduced_motion": reduced_motion,
		"reduced_flashes": reduced_flashes,
		"left_handed_touch": left_handed_touch,
	})
	var snapshot := {
		"schema_version": ACCESSIBILITY_SCHEMA_VERSION,
		"owner": "Sfx",
		"profile": profile.duplicate(true),
		"supported": {
			"color_assist": true,
			"haptics_enabled": true,
			"shake_level": true,
			"touch_scale": true,
			"offensive_music_enabled": true,
			"defensive_music_enabled": true,
			"reduced_motion": true,
			"reduced_flashes": true,
			"left_handed_touch": true,
			"native_screen_reader": false,
			"text_scale": false,
			"high_contrast": false,
		},
		"required_fields": required.duplicate(true),
		"optional_fields": optional.duplicate(true),
		"muted": bool(muted),
		"haptics_enabled": bool(haptics_enabled),
		"shake_level": int(shake_level),
		"target_fps": int(target_fps),
		"fullscreen": bool(fullscreen),
		"touch_scale": float(touch_scale),
		"reduced_motion": bool(reduced_motion),
		"reduced_flashes": bool(reduced_flashes),
		"left_handed_touch": bool(left_handed_touch),
		"offensive_music_enabled": bool(offensive_music_enabled),
		"defensive_music_enabled": bool(defensive_music_enabled),
		"music_layers": {"offensive": bool(offensive_music_enabled), "defensive": bool(defensive_music_enabled)},
		"aim_mode": str(aim_mode),
		"color_assist": bool(color_assist),
		"show_run_info": bool(show_run_info),
		"sfx_volume": float(sfx_vol),
		"music_volume": float(music_vol),
		"music_variant": str(music_variant),
		"palette": {"accent": Balance.COL_PLAYER.to_html(false), "danger": Balance.COL_DANGER.to_html(false)},
	}
	for field in required:
		assert(snapshot.has(field), "Sfx accessibility_snapshot missing required field: " + str(field))
	return snapshot.duplicate(true)

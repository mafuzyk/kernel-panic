extends Node

## L1/M2 red-green probe for the locale service, catalog parity and the first
## macOS story copy slice. It uses the normal user-data boundary; callers must
## isolate XDG_DATA_HOME when running it.

var _fails := 0
var _emissions := 0

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PROBE_PASS ", message)
	else:
		_fails += 1
		print("PROBE_FAIL ", message)

func _run() -> void:
	var service := get_node_or_null("/root/Localization")
	_check(service != null and service.has_method("current_locale"), "Localization autoload exposes the stable service")
	if service == null:
		_finish()
		return
	_check(service.has_method("validate_catalogs") and bool(service.validate_catalogs().get("ok", false)), "English and PT-BR catalogs pass schema validation")
	_check(service.has_method("has_key") and service.has_key("story.macos.mac_classic_title", "en") and service.has_key("story.macos.mac_classic_title", "pt-BR"), "the first macOS narrative key exists in both locales")
	_check(service.has_key("story.macos.mac_classic_title") and service.has_key("settings.language"), "catalog exposes stable story and settings keys")
	_check(service.tr_key("missing.key", "Readable fallback") == "Readable fallback", "missing keys use readable fallback copy")
	_check(not service.tr_key("missing.key", "").contains("missing.key"), "missing keys never leak raw key identifiers")
	_check(service.format_key("hud.wave", {"wave": 7}) == "Wave 7", "named placeholder formatting works in English")
	_check(service.plural_key("hud.daemon_count", 1) == "1 daemon", "plural one branch resolves")
	_check(service.plural_key("hud.daemon_count", 3) == "3 daemons", "plural other branch resolves")
	_check(service.select_key("settings.language_value", "pt-BR") == "Português (Brasil)", "select branches resolve")
	var old_locale: String = str(service.current_locale())
	service.set_locale("en")
	_emissions = 0
	service.locale_changed.connect(_on_locale_changed)
	_check(service.set_locale("pt-BR"), "PT-BR can be selected")
	_check(service.current_locale() == "pt-BR", "PT-BR becomes the active locale")
	_check(service.tr_key("story.macos.mac_classic_title", "fallback") == "A SHELL AMIGÁVEL", "macOS title resolves to Brazilian Portuguese")
	var stage: Dictionary = Game.story_stage_def(11)
	_check(str(stage.get("title", "")) == "A SHELL AMIGÁVEL", "macOS stage data consumes the selected locale")
	var story_surface_script: Script = load("res://src/ui/vnext/surfaces/story_surface.gd")
	var story_surface: Control = story_surface_script.new() if story_surface_script != null else null
	if story_surface != null:
		add_child(story_surface)
		await get_tree().process_frame
		for viewport_size in [Vector2(1366.0, 768.0), Vector2(720.0, 720.0), Vector2(432.0, 720.0)]:
			story_surface.size = viewport_size
			story_surface.configure({"selected": 11}, story_surface_script.context_for_viewport(viewport_size, viewport_size.x <= 432.0))
			await get_tree().process_frame
			var overflow: Array = story_surface.text_overflow_report()
			var all_fit := true
			for entry in overflow:
				if not bool(entry.get("fits", false)):
					all_fit = false
			_check(all_fit, "PT-BR story surface fits at %.0fx%.0f" % [viewport_size.x, viewport_size.y])
		story_surface.queue_free()
	else:
		_check(false, "story surface loads for PT-BR overflow review")
	_check(_emissions == 1, "locale_changed emits once for an actual change")
	_check(service.set_locale("pt-BR") and _emissions == 1, "reselecting the active locale emits nothing")
	_check(not service.set_locale("xx-INVALID") and service.current_locale() == "pt-BR", "invalid locale is rejected without mutation")
	var cf := ConfigFile.new()
	_check(cf.load(Sfx.SAVE_PATH) == OK and str(cf.get_value("localization", "locale", "")) == "pt-BR", "locale persists through the established save path")
	_check(service.locale_snapshot().get("current", "") == "pt-BR", "locale snapshot reports the active locale")
	_check(service.set_locale(old_locale), "probe restores the original locale")
	_finish()

func _finish() -> void:
	print("PROBE_DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

func _on_locale_changed(_locale: String) -> void:
	_emissions += 1

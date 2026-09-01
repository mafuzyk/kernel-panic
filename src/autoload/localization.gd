extends Node
class_name LocalizationService

## Small locale boundary for player-facing copy. JSON is used instead of a
## hand-rolled CSV parser so commas, line breaks and Portuguese Unicode remain
## data, not delimiter accidents. English is the complete fallback catalog.

signal locale_changed(locale: String)

const LOCALES: Array[String] = ["en", "pt-BR"]
const CATALOG_PATHS := {"en": "res://src/data/localization/en.json", "pt-BR": "res://src/data/localization/pt-BR.json"}
const CATALOG_SCHEMA_VERSION := 1

var _catalogs: Dictionary = {}
var _current_locale := "en"
var _missing_logged: Dictionary = {}
var _validation := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_catalogs()
	var saved := str(Sfx.locale) if Sfx.has_method("current_locale") else str(Sfx.get("locale"))
	_current_locale = saved if saved in LOCALES else "en"

func _load_catalogs() -> void:
	_catalogs.clear()
	for locale in LOCALES:
		var loaded := _load_catalog(locale)
		if not loaded.is_empty():
			_catalogs[locale] = loaded
	_validation = _validate_loaded_catalogs()

func _load_catalog(locale: String) -> Dictionary:
	var path := str(CATALOG_PATHS.get(locale, ""))
	if path.is_empty() or not FileAccess.file_exists(path):
		push_error("Localization catalog missing: " + locale)
		return {}
	var raw := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		push_error("Localization catalog is not an object: " + locale)
		return {}
	var document: Dictionary = parsed
	var metadata: Variant = document.get("_meta", {})
	var entries: Variant = document.get("keys", {})
	if not metadata is Dictionary or not entries is Dictionary:
		push_error("Localization catalog has invalid schema: " + locale)
		return {}
	if int(metadata.get("schema_version", 0)) != CATALOG_SCHEMA_VERSION or str(metadata.get("locale", "")) != locale:
		push_error("Localization catalog metadata mismatch: " + locale)
		return {}
	return entries.duplicate(true)

func current_locale() -> String:
	return _current_locale

func available_locales() -> Array[String]:
	return LOCALES.duplicate()

func locale_label(locale: String = "") -> String:
	var normalized := locale if not locale.is_empty() else _current_locale
	return "Português (Brasil)" if normalized == "pt-BR" else "English"

func set_locale(locale: String) -> bool:
	if locale not in LOCALES or not _catalogs.has(locale):
		return false
	if locale == _current_locale:
		return true
	var previous := _current_locale
	if Sfx.has_method("set_locale") and not bool(Sfx.set_locale(locale)):
		return false
	_current_locale = locale
	locale_changed.emit(_current_locale)
	if previous == _current_locale:
		return false
	return true

func tr_key(key: String, fallback: String = "", _context: Dictionary = {}) -> String:
	var value: Variant = _resolve_value(key)
	if value is String and not str(value).is_empty():
		return str(value)
	if not fallback.is_empty():
		return fallback
	if not _missing_logged.has(key):
		_missing_logged[key] = true
		if OS.is_debug_build():
			print("LOCALIZATION_MISSING ", key)
	return _human_fallback(key)

func has_key(key: String, locale: String = "") -> bool:
	var selected := locale if not locale.is_empty() else _current_locale
	var catalog: Dictionary = _catalogs.get(selected, {})
	return catalog.has(key) and _usable_value(catalog[key])

func format_key(key: String, values: Dictionary, fallback: String = "") -> String:
	var sentence := tr_key(key, fallback)
	for placeholder in _placeholder_names(sentence):
		if not values.has(placeholder):
			if OS.is_debug_build():
				print("LOCALIZATION_PLACEHOLDER_MISSING ", key, " // ", placeholder)
			continue
		sentence = sentence.replace("{" + placeholder + "}", str(values[placeholder]))
	return sentence

func plural_key(key: String, count: int, values: Dictionary = {}) -> String:
	var branch := "one" if count == 1 else "other"
	var selected := _resolve_branch(key, branch)
	var merged := values.duplicate(true)
	merged["count"] = count
	if selected.is_empty():
		return format_key(key, merged)
	return _format_sentence(selected, merged, key)

func select_key(key: String, branch: String, values: Dictionary = {}) -> String:
	var selected := _resolve_branch(key, branch)
	if selected.is_empty():
		selected = _resolve_branch(key, "other")
	if selected.is_empty():
		return format_key(key, values)
	return _format_sentence(selected, values, key)

func locale_snapshot() -> Dictionary:
	return {
		"current": _current_locale,
		"available": LOCALES.duplicate(),
		"schema_version": CATALOG_SCHEMA_VERSION,
		"english_key_count": int(_catalogs.get("en", {}).size()),
		"localized_key_count": int(_catalogs.get(_current_locale, {}).size()),
		"validation": _validation.duplicate(true),
	}.duplicate(true)

func validate_catalogs() -> Dictionary:
	_validation = _validate_loaded_catalogs()
	return _validation.duplicate(true)

func _resolve_value(key: String) -> Variant:
	var localized: Dictionary = _catalogs.get(_current_locale, {})
	if localized.has(key) and _usable_value(localized[key]):
		return localized[key]
	var english: Dictionary = _catalogs.get("en", {})
	return english.get(key, null)

func _resolve_branch(key: String, branch: String) -> String:
	var value: Variant = _resolve_value(key)
	if value is Dictionary:
		var branch_value: Variant = value.get(branch, value.get("other", ""))
		return str(branch_value) if branch_value is String else ""
	return str(value) if value is String else ""

func _format_sentence(sentence: String, values: Dictionary, key: String) -> String:
	var result := sentence
	for placeholder in _placeholder_names(result):
		if not values.has(placeholder):
			if OS.is_debug_build():
				print("LOCALIZATION_PLACEHOLDER_MISSING ", key, " // ", placeholder)
			continue
		result = result.replace("{" + placeholder + "}", str(values[placeholder]))
	return result

func _placeholder_names(value: String) -> Array[String]:
	var regex := RegEx.new()
	regex.compile("\\{([A-Za-z0-9_]+)\\}")
	var result: Array[String] = []
	for match in regex.search_all(value):
		var name := match.get_string(1)
		if name not in result:
			result.append(name)
	return result

func _usable_value(value: Variant) -> bool:
	if value is String:
		return not str(value).strip_edges().is_empty()
	if value is Dictionary:
		for branch in value.values():
			if not branch is String or str(branch).strip_edges().is_empty():
				return false
		return not value.is_empty()
	return false

func _validate_loaded_catalogs() -> Dictionary:
	var english: Dictionary = _catalogs.get("en", {})
	var localized: Dictionary = _catalogs.get("pt-BR", {})
	var missing: Array[String] = []
	var extra: Array[String] = []
	var invalid: Array[String] = []
	var placeholder_mismatches: Array[String] = []
	for key in english.keys():
		if not localized.has(key):
			missing.append(str(key))
			continue
		if not _usable_value(english[key]) or not _usable_value(localized[key]):
			invalid.append(str(key))
		if _value_placeholder_signature(english[key]) != _value_placeholder_signature(localized[key]):
			placeholder_mismatches.append(str(key))
	for key in localized.keys():
		if not english.has(key):
			extra.append(str(key))
	return {
		"ok": not english.is_empty() and missing.is_empty() and extra.is_empty() and invalid.is_empty() and placeholder_mismatches.is_empty(),
		"english_count": english.size(),
		"localized_count": localized.size(),
		"missing": missing,
		"extra": extra,
		"invalid": invalid,
		"placeholder_mismatches": placeholder_mismatches,
	}.duplicate(true)

func _value_placeholder_signature(value: Variant) -> Dictionary:
	var result := {}
	if value is String:
		result["string"] = _placeholder_names(str(value))
	elif value is Dictionary:
		for branch in value.keys():
			result[str(branch)] = _placeholder_names(str(value[branch]))
	return result

func _human_fallback(key: String) -> String:
	var readable := key.replace(".", " ").replace("_", " ").strip_edges()
	return readable.capitalize() if not readable.is_empty() else "Text unavailable"

class_name VNextUIState
extends RefCounted

const KINDS := ["loading", "error", "empty", "transition"]

static func make(kind: String, values: Dictionary = {}) -> Dictionary:
	var normalized_kind := kind.to_lower().strip_edges()
	if normalized_kind not in KINDS:
		normalized_kind = "error"
	var defaults := _defaults(normalized_kind)
	for key in values:
		defaults[key] = values[key]
	defaults["kind"] = normalized_kind
	defaults["title"] = _visible_or_default(str(defaults.get("title", "")), _defaults(normalized_kind)["title"])
	defaults["message"] = _visible_or_default(str(defaults.get("message", "")), _defaults(normalized_kind)["message"])
	defaults["reason_code"] = _safe_meta(str(defaults.get("reason_code", "unknown")), "unknown")
	defaults["source"] = _safe_meta(str(defaults.get("source", "unknown")), "unknown")
	defaults["recoverable"] = bool(defaults.get("recoverable", true))
	defaults["busy"] = normalized_kind in ["loading", "transition"]
	defaults["can_retry"] = normalized_kind == "error" and bool(defaults.get("can_retry", false))
	if not defaults["can_retry"]:
		defaults["primary_action"] = ""
		defaults["primary_label"] = ""
	else:
		defaults["primary_action"] = _safe_action(str(defaults.get("primary_action", "retry")), "retry")
		defaults["primary_label"] = _visible_or_default(str(defaults.get("primary_label", "RETRY")), "RETRY")
	if normalized_kind == "empty":
		defaults["title"] = "NO CONTENT"
	if normalized_kind == "loading" and not bool(defaults.get("cancel_safe", false)):
		defaults["back_action"] = ""
		defaults["back_label"] = ""
	if normalized_kind == "transition" and not bool(defaults.get("cancel_safe", false)) and str(defaults.get("back_action", "")).to_lower().contains("cancel"):
		defaults["back_action"] = ""
		defaults["back_label"] = ""
	else:
		defaults["back_action"] = _safe_action(str(defaults.get("back_action", "back")), "back")
		defaults["back_label"] = _visible_or_default(str(defaults.get("back_label", "BACK")), "BACK")
	defaults["semantic_label"] = _semantic_label(normalized_kind)
	defaults["pattern"] = _pattern(normalized_kind)
	return defaults.duplicate(true)

static func snapshot(kind: String, values: Dictionary = {}) -> Dictionary:
	return make(kind, values)

static func _defaults(kind: String) -> Dictionary:
	match kind:
		"loading": return {"kind": kind, "title": "LOADING", "message": "Work is still in progress.", "reason_code": "working", "primary_action": "", "primary_label": "", "back_action": "back", "back_label": "BACK", "can_retry": false, "busy": true, "recoverable": true, "source": "unknown", "cancel_safe": false}
		"empty": return {"kind": kind, "title": "NO CONTENT", "message": "The request succeeded, but there is no content to show.", "reason_code": "no_content", "primary_action": "", "primary_label": "", "back_action": "back", "back_label": "BACK", "can_retry": false, "busy": false, "recoverable": true, "source": "unknown"}
		"transition": return {"kind": kind, "title": "TRANSITION", "message": "Preparing the next route.", "reason_code": "route_change", "primary_action": "", "primary_label": "", "back_action": "back", "back_label": "BACK", "can_retry": false, "busy": true, "recoverable": true, "source": "route", "cancel_safe": false}
		_: return {"kind": "error", "title": "RECOVERY REQUIRED", "message": "The requested action failed. Return and try again.", "reason_code": "unknown_error", "primary_action": "", "primary_label": "", "back_action": "back", "back_label": "BACK", "can_retry": false, "busy": false, "recoverable": true, "source": "unknown"}

static func _semantic_label(kind: String) -> String:
	return {"loading": "WORKING", "error": "ERROR", "empty": "NO CONTENT", "transition": "TRANSITIONING"}.get(kind, "ERROR")

static func _pattern(kind: String) -> String:
	return {"loading": "moving scan", "error": "broken bars", "empty": "open grid", "transition": "forward chevrons"}.get(kind, "broken bars")

static func _visible_or_default(value: String, fallback: String) -> String:
	var text := value.strip_edges()
	if text.is_empty() or _looks_like_key(text):
		return fallback
	return text

static func _looks_like_key(value: String) -> bool:
	return value.begins_with("loc.") or value.begins_with("ui.") or (value.contains("_") and not value.contains(" "))

static func _safe_meta(value: String, fallback: String) -> String:
	var clean := value.strip_edges()
	return clean if not clean.is_empty() else fallback

static func _safe_action(value: String, fallback: String) -> String:
	var clean := value.strip_edges().to_lower()
	return fallback if clean.is_empty() else clean

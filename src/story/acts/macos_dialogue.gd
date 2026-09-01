class_name MacOSDialogue
extends RefCounted

## Player-facing copy for the macOS history act. The act data stores keys so
## localization can replace this table without changing story progression.

const TEXT := {
	"mac_classic_title": "THE FRIENDLY SHELL",
	"mac_classic_intro": "A clean desktop promises simplicity. The process table has other plans.",
	"mac_classic_klog": ["finder: one window opened", "menu bar: pretending to be calm", "process table: welcome, small daemon"],
	"mac_aqua_title": "THE BEAUTIFUL LAYER",
	"mac_aqua_intro": "Everything is translucent, smooth and hiding a route. Read the telegraph, not the polish.",
	"mac_aqua_klog": ["aqua: fluid surface enabled", "compositor: depth is not safety", "race condition: two windows share a bad idea"],
	"mac_darwin_title": "THE SUBSTRATE UNDERNEATH",
	"mac_darwin_intro": "The shell opens onto its lower layer. Background services are still services, even when they look expensive.",
	"mac_darwin_klog": ["darwin: substrate visible", "launchd: background work detected", "memory: the polished shell is still consuming it"],
	"mac_modern_title": "PERMISSION TO PANIC",
	"mac_modern_intro": "The system asks for permission to do everything, then forgets who granted it. Clear the route and keep your process alive.",
	"mac_modern_klog": ["security: consent dialog misplaced", "service: running in the background", "root: permission denied // retrying"],
	"act_label": "ACT 4 // MACOS HISTORY LOG",
	"unlock_label": "UNLOCKS AFTER TEMPLEOS // THE HISTORY CONTINUES",
	"locked_label": "MACOS HISTORY // CLEAR THE ORACLE ROUTE FIRST",
	"reward_label": "MACOS HISTORY ROUTE MOUNTED",
}

static func text(key: String) -> String:
	return str(TEXT.get(key, key))

static func lines(key: String) -> Array[String]:
	var raw: Variant = TEXT.get(key, [])
	var result: Array[String] = []
	if raw is Array:
		for line in raw:
			result.append(str(line))
	return result

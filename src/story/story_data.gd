class_name StoryData
extends RefCounted

## Fixed, hand-authored content for the first UNIX story act.
## Endless mode owns all procedural composition and difficulty scaling.
const STAGES := [
	{
		"id": "boot",
		"path": "/boot",
		"title": "BOOT SEQUENCE",
		"intro": "The machine wakes with a clean process table. Something is already moving.",
		"klog": ["init: mounting /boot", "watchdog: first signal acquired", "kernel: input accepted"],
		"waves": [["drone"], ["drone", "drone"], ["drone", "drone", "drone"], ["drone", "drone", "drone", "drone"]],
		"scale": 0.92,
		"theme": {"base_col": Color("080b18"), "grid_col": Color("193456"), "glow_col": Color("0d4160"), "accent": Color("4ff2ff")}
	},
	{
		"id": "var_log",
		"path": "/var/log",
		"title": "THE LOG PARTITION",
		"intro": "Old warnings spill out of storage. The spewers are not interested in being archived.",
		"klog": ["rsyslog: warning queue growing", "spewer: packet burst detected", "journal: do not rotate me"],
		"waves": [["drone", "drone"], ["spewer", "drone", "drone"], ["spewer", "spewer", "drone", "drone"], ["spewer", "spewer", "drone", "drone", "drone"]],
		"scale": 0.98,
		"theme": {"base_col": Color("100b18"), "grid_col": Color("44304d"), "glow_col": Color("42204d"), "accent": Color("b46bff")}
	},
	{
		"id": "net",
		"path": "/net",
		"title": "NETWORK NAMESPACE",
		"intro": "Every connection is hostile. Lancers have claimed the shortest route to your position.",
		"klog": ["netlink: route table unstable", "lancer: line of sight established", "firewall: handshake refused"],
		"waves": [["drone", "lancer"], ["lancer", "drone", "drone"], ["lancer", "lancer", "spewer", "drone"], ["lancer", "lancer", "lancer", "drone", "drone"]],
		"scale": 1.02,
		"theme": {"base_col": Color("08131b"), "grid_col": Color("174953"), "glow_col": Color("0b4f58"), "accent": Color("53e0cf")}
	},
	{
		"id": "mem",
		"path": "/mem",
		"title": "MEMORY PRESSURE",
		"intro": "Free memory is a lie. The OOM killer is harvesting motes while splitters multiply the mess.",
		"klog": ["kswapd0: reclaim failed", "oom_killer: looking for loose data", "allocator: fragmentation detected"],
		"waves": [["oom", "drone"], ["splitter", "drone", "oom"], ["splitter", "splitter", "oom", "drone"], ["splitter", "oom", "oom", "drone", "drone"], ["splitter", "splitter", "oom", "oom", "drone"]],
		"scale": 1.05,
		"theme": {"base_col": Color("0d0b1b"), "grid_col": Color("3e2a61"), "glow_col": Color("35165c"), "accent": Color("9a4dff")}
	},
	{
		"id": "quarantine",
		"path": "/quarantine",
		"title": "QUARANTINE",
		"intro": "The infected processes were isolated. They kept their routes, their teeth, and their opinions.",
		"klog": ["security: quarantine boundary active", "trojan: route mutation complete", "corruption: containment failing"],
		"waves": [["trojan", "drone"], ["trojan", "splitter", "drone"], ["trojan", "oom", "spewer", "drone"], ["trojan", "trojan", "splitter", "oom", "drone"], ["firewall", "trojan", "splitter", "oom", "spewer"]],
		"scale": 1.08,
		"theme": {"base_col": Color("180a17"), "grid_col": Color("5a2637"), "glow_col": Color("5a162d"), "accent": Color("ff5c78")}
	},
	{
		"id": "kernel",
		"path": "/kernel",
		"title": "KERNEL PANIC",
		"intro": "All paths terminate here. The root daemon has reserved the last clean address.",
		"klog": ["kernel: unrecoverable exception", "root.exe: fork requested", "panic: last process standing"],
		"waves": [["drone", "spewer", "lancer"], ["splitter", "oom", "trojan", "drone"], ["recursor", "firewall", "lancer", "spewer"], ["bulwark", "trojan", "splitter", "oom", "recursor"], ["boss"]],
		"boss": "ROOT DAEMON",
		"boss_index": 1,
		"boss_scale": 1.10,
		"scale": 1.10,
		"theme": {"base_col": Color("160812"), "grid_col": Color("572137"), "glow_col": Color("63142e"), "accent": Color("ff3d81")}
	}
]

static func stage_count() -> int:
	return STAGES.size()

static func stage_at(index: int) -> Dictionary:
	if index < 0 or index >= STAGES.size():
		return {}
	return STAGES[index].duplicate(true)

static func stage_ids() -> Array:
	var result: Array = []
	for stage in STAGES:
		result.append(str(stage["id"]))
	return result

static func stage_wave_count(index: int) -> int:
	return stage_at(index).get("waves", []).size()

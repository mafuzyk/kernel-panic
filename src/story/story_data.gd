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
	},
	{
		"id": "win98",
		"path": "C:\\98",
		"title": "WINDOWS 98",
		"intro": "The desktop loads. The desktop immediately asks for a driver it lost in 1998.",
		"klog": ["winlogon: welcome back", "explorer: 47 icons restored", "system: this computer may be shut down"],
		"waves": [["drone", "drone"], ["lancer", "spewer", "drone"], ["splitter", "trojan", "drone", "drone"], ["bulwark", "lancer", "spewer", "trojan"]],
		"scale": 1.02,
		"theme": {"base_col": Color("222b2e"), "grid_col": Color("3a777c"), "glow_col": Color("2b5c61"), "accent": Color("79d6ce"), "grid_style": "crt_heavy", "crt": {"curvature": 0.075, "noise": 0.075, "scanline": 0.22, "aberration": 0.7}},
		"watermark": true
	},
	{
		"id": "winxp",
		"path": "C:\\XP",
		"title": "WINDOWS XP",
		"intro": "The Luna shell is smooth, bright, and somehow still installing updates during combat.",
		"klog": ["winlogon: blue-green session active", "update: reboot scheduled", "theme: luna applied successfully"],
		"waves": [["drone", "spewer", "drone"], ["update_loop", "drone", "lancer"], ["update_loop", "spewer", "splitter", "drone"], ["update_loop", "trojan", "bulwark", "lancer"]],
		"scale": 1.06,
		"theme": {"base_col": Color("10223c"), "grid_col": Color("3e7db3"), "glow_col": Color("1f5e9e"), "accent": Color("74b9ff"), "grid_style": "crt_soft", "crt": {"curvature": 0.035, "noise": 0.035, "scanline": 0.10, "aberration": 0.28}},
		"watermark": true
	},
	{
		"id": "win11",
		"path": "Win11",
		"title": "WINDOWS 11",
		"intro": "A clean glass desktop hides a familiar problem: too many background processes.",
		"klog": ["shell: rounded corners enabled", "telemetry: everything is fine", "bloatware: 47 background processes active"],
		"waves": [["drone", "update_loop", "drone"], ["bloatware", "spewer", "lancer"], ["bloatware", "update_loop", "splitter", "drone"], ["bloatware", "bloatware", "trojan", "oom", "spewer"]],
		"scale": 1.10,
		"theme": {"base_col": Color("dfe9f2"), "grid_col": Color("8ca7bd"), "glow_col": Color("b9d9ee"), "accent": Color("2e77b8"), "grid_style": "clean"},
		"watermark": true
	}
]

static func stage_count() -> int:
	return STAGES.size()

static func act_stage_count(act_id: String) -> int:
	return 6 if act_id == "unix" else 3 if act_id == "windows" else 0

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

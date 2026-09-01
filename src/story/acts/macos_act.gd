class_name MacOSAct
extends RefCounted

const ACT_ID := "macos"
const UNLOCK_AFTER := "temple_god"
const MacOSDialogueData = preload("res://src/story/acts/macos_dialogue.gd")
const MacOSProfilesData = preload("res://src/story/acts/macos_profiles.gd")

const STAGES := [
	{
		"id": "mac_classic", "act": ACT_ID, "path": "Mac::CLASSIC", "profile": "classic", "title_key": "mac_classic_title", "intro_key": "mac_classic_intro", "klog_key": "mac_classic_klog", "reward_id": "macos_history_route",
		"waves": [["drone"], ["drone", "drone"], ["zombie_process", "drone"], ["drone", "lancer", "drone"]], "scale": 1.0,
	},
	{
		"id": "mac_aqua", "act": ACT_ID, "path": "Mac::AQUA", "profile": "aqua", "title_key": "mac_aqua_title", "intro_key": "mac_aqua_intro", "klog_key": "mac_aqua_klog", "reward_id": "macos_aqua_clear",
		"waves": [["drone", "drone"], ["race_condition", "race_condition"], ["race_condition", "drone", "drone"], ["spewer", "race_condition", "lancer"]], "scale": 1.04,
	},
	{
		"id": "mac_darwin", "act": ACT_ID, "path": "Mac::DARWIN", "profile": "darwin", "title_key": "mac_darwin_title", "intro_key": "mac_darwin_intro", "klog_key": "mac_darwin_klog", "reward_id": "macos_darwin_clear",
		"waves": [["zombie_process", "drone", "lancer"], ["bloatware", "drone", "drone"], ["update_loop", "zombie_process", "spewer"], ["bloatware", "race_condition", "lancer", "drone"]], "scale": 1.08,
	},
	{
		"id": "mac_modern", "act": ACT_ID, "path": "Mac::MODERN", "profile": "modern", "title_key": "mac_modern_title", "intro_key": "mac_modern_intro", "klog_key": "mac_modern_klog", "reward_id": "macos_modern_clear", "boss": "PERMISSION ROOT", "boss_kind": "boss", "boss_index": 3, "boss_scale": 1.12,
		"waves": [["drone", "zombie_process", "race_condition"], ["bloatware", "update_loop", "spewer", "lancer"], ["recursor", "firewall", "race_condition", "zombie_process"], ["boss"]], "scale": 1.12,
	},
]

static func stage_count() -> int:
	return STAGES.size()

static func stage_at(index: int) -> Dictionary:
	if index < 0 or index >= STAGES.size():
		return {}
	var stage: Dictionary = STAGES[index].duplicate(true)
	stage["title"] = MacOSDialogueData.text(str(stage.get("title_key", "")))
	stage["intro"] = MacOSDialogueData.text(str(stage.get("intro_key", "")))
	stage["klog"] = MacOSDialogueData.lines(str(stage.get("klog_key", "")))
	stage["theme"] = MacOSProfilesData.theme(str(stage.get("profile", "classic")))
	return stage

static func stage_ids() -> Array[String]:
	var result: Array[String] = []
	for stage in STAGES:
		result.append(str(stage["id"]))
	return result

static func stage_index_for_id(id: String) -> int:
	for index in STAGES.size():
		if str(STAGES[index].get("id", "")) == id:
			return index
	return -1

class_name WeeklyMutatorCatalog
extends RefCounted

## Small, deterministic content boundary for Weekly mode.
##
## A definition is data, not executable gameplay logic. The `tag` is kept
## explicit so future mutators can be reviewed by category before they are
## admitted to the rotation. The first rotation deliberately contains only
## additive, readable modifiers; neither changes player integrity nor adds a
## hidden rule to Practice or Story.

const MUTATORS: Array[Dictionary] = [
	{
		"id": "swift_daemons",
		"title": "SWIFT DAEMONS",
		"description": "DAEMONS MOVE +20%",
		"tag": "movement",
		"multiplier": 1.2,
	},
	{
		"id": "rush_hour",
		"title": "RUSH HOUR",
		"description": "WAVE BUDGET +20%",
		"tag": "spawn",
		"multiplier": 1.2,
	},
]

static func definitions() -> Array[Dictionary]:
	return MUTATORS.duplicate(true)

static func for_seed(seed: int) -> Dictionary:
	if MUTATORS.is_empty():
		return {}
	return MUTATORS[posmod(seed, MUTATORS.size())].duplicate(true)

static func for_id(id: String) -> Dictionary:
	for definition in MUTATORS:
		if str(definition.get("id", "")) == id:
			return definition.duplicate(true)
	return {}

static func is_known(id: String) -> bool:
	for definition in MUTATORS:
		if str(definition.get("id", "")) == id:
			return true
	return false

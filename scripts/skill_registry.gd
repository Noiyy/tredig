class_name SkillRegistry extends RefCounted

enum SkillType {
	NONE,
	HEAL,
	DURABILITY_UP,
	SWAP,
	SABOTAGE_TILE,
	DYNAMITE,
	FREEZE,
}

const SKILLS := {
	SkillType.HEAL: {
		"name": "SkillNameHeal",
		"icon": preload("res://assets/images/heal.png"),
		"use_count": 2,
		"max_level": 3,
		"description": "SkillDescHeal",
		"modifiers": [10, 15, 20],
	},
	SkillType.DURABILITY_UP: {
		"name": "SkillNameDurUp",
		"icon": preload("res://assets/images/durability_up.png"),
		"use_count": 2,
		"max_level": 3,
		"description": "SkillDescDurUp",
		"modifiers": [25, 35, 50],
	},
	SkillType.SWAP: {
		"name": "SkillNameSwap",
		"icon": preload("res://assets/images/swap.png"),
		"use_count": 1,
		"max_level": 1,
		"description": "SkillDescSwap",
		"modifiers": [10],
	},
	SkillType.SABOTAGE_TILE: {
		"name": "SkillNameSabotage",
		"icon": preload("res://assets/images/sabotage.png"),
		"use_count": 1,
		"max_level": 3,
		"description": "SkillDescSabotage",
		"modifiers": [5, 6, 7],
	},
	SkillType.DYNAMITE: {
		"name": "SkillNameDynamite",
		"icon": preload("res://assets/images/dynamite.png"),
		"use_count": 1,
		"max_level": 3,
		"description": "SkillDescDynamite",
		"modifiers": [3, 4, 5],
	},
	SkillType.FREEZE: {
		"name": "SkillNameFreeze",
		"icon": preload("res://assets/images/freeze.png"),
		"use_count": 1,
		"max_level": 3,
		"description": "SkillDescFreeze",
		"modifiers": [4, 5, 7],
	},
}

const _LEVEL_WEIGHTS := [50.0, 33.0, 17.0]

const ROMAN_NUMERALS := ["I", "II", "III"]

static func get_def(type: int) -> Dictionary:
	return SKILLS[type]

static func get_modifier(type: int, level: int) -> int:
	var def: Dictionary = SKILLS[type]
	var idx: int = clamp(level - 1, 0, def.modifiers.size() - 1)
	return def.modifiers[idx]

static func format_description(type: int, level: int) -> String:
	var def: Dictionary = SKILLS[type]
	# def.description is a localization key; translate it, then fill in the number.
	# Static context: tr() is unavailable, so translate via the singleton.
	var translated: String = TranslationServer.translate(def.description)
	if translated.find("%d") < 0:
		return translated
	return translated % get_modifier(type, level)

## Always returns exactly 3 {type, level} cards with no two identical pairs.
## Types are preferred to be distinct, but the same type at a different level
## is used when the eligible pool has fewer than 3 types.
static func roll_card_choices(opponent_alive: bool) -> Array:
	var pool: Array = []
	for type in SKILLS.keys():
		if (type == SkillType.SABOTAGE_TILE or type == SkillType.SWAP or type == SkillType.DYNAMITE or type == SkillType.FREEZE) and not opponent_alive:
			continue
		pool.append(type)

	# Build a weighted candidate list: level 1 appears 3×, level 2 twice, level 3 once
	# so the existing probability distribution is preserved after shuffling.
	const LEVEL_REPEATS := [3, 2, 1]
	var candidates: Array = []
	for type in pool:
		var def: Dictionary = SKILLS[type]
		for lvl in range(1, def.max_level + 1):
			var reps: int = LEVEL_REPEATS[clamp(lvl - 1, 0, LEVEL_REPEATS.size() - 1)]
			for _i in reps:
				candidates.append({"type": type, "level": lvl})
	candidates.shuffle()

	var cards: Array = []
	var used: Dictionary = {}
	for c in candidates:
		var key: String = "%d_%d" % [c.type, c.level]
		if not used.has(key):
			used[key] = true
			cards.append({"type": c.type, "level": c.level})
			if cards.size() >= 3:
				break
	return cards

static func _roll_level(type: int) -> int:
	var def: Dictionary = SKILLS[type]
	var max_lvl: int = def.max_level
	if max_lvl <= 1:
		return 1
	var total := 0.0
	for i in max_lvl:
		total += _LEVEL_WEIGHTS[i]
	var r := randf() * total
	var cum := 0.0
	for i in max_lvl:
		cum += _LEVEL_WEIGHTS[i]
		if r < cum:
			return i + 1
	return max_lvl

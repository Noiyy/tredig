extends Control

@onready var skill_img: TextureRect = $SkillImg
@onready var use_count_label: Label = $UseCountLabel
@onready var skill_level_label: Label = $SkillLevelLabel
@onready var key_label: Label = $KeyRect/Label

func set_skill(skill_type: int, level: int, uses_remaining: int, key_text: String) -> void:
	var def: Dictionary = SkillRegistry.get_def(skill_type)
	skill_img.texture = def.icon
	key_label.text = key_text

	var show_use_count: bool = def.use_count > 1
	use_count_label.visible = show_use_count
	if show_use_count:
		use_count_label.text = "%dx" % uses_remaining

	var show_level: bool = def.max_level > 1
	skill_level_label.visible = show_level
	if show_level:
		var idx: int = clamp(level - 1, 0, SkillRegistry.ROMAN_NUMERALS.size() - 1)
		skill_level_label.text = SkillRegistry.ROMAN_NUMERALS[idx]

	visible = true

func clear() -> void:
	visible = false

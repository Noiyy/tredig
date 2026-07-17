extends Control

## 3-card skill pick overlay shown over a single player's HUD half on even level-ups.
## Listens only to that player's controls (left/right to navigate, use to confirm) so both
## players can pick simultaneously without focus conflicts.

@onready var card_nodes: Array[Control] = [
	$Panel/HBoxContainer/Card1,
	$Panel/HBoxContainer/Card2,
	$Panel/HBoxContainer/Card3,
]

var _player: CharacterBody2D
var _choices: Array = []
var _focused_idx: int = 0
var _active: bool = false
var _confirm_unlock_time_ms: int = 0
var _wait_for_use_release: bool = false

const FOCUS_BG := Color(1.0, 0.353, 0.122, 0.35)
const NORMAL_BG := Color(0.129, 0.106, 0.169, 0.88)
const CONFIRM_LOCK_MS := 300


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in card_nodes.size():
		var card := card_nodes[i]
		var btn: Button = card.get_node_or_null("ClickButton")
		if btn != null:
			btn.pressed.connect(_on_card_clicked.bind(i))


func show_for(player: CharacterBody2D, choices: Array) -> void:
	_player = player
	_choices = choices
	_focused_idx = 0
	_active = true
	_confirm_unlock_time_ms = Time.get_ticks_msec() + CONFIRM_LOCK_MS
	_wait_for_use_release = true
	_render_cards()
	visible = true


func _render_cards() -> void:
	for i in card_nodes.size():
		var card := card_nodes[i]
		if i >= _choices.size():
			card.visible = false
			continue
		card.visible = true
		var entry: Dictionary = _choices[i]
		var def: Dictionary = SkillRegistry.get_def(entry.type)
		var icon: TextureRect = card.get_node("Icon")
		icon.texture = def.icon
		var name_label: Label = card.get_node("NameLabel")
		name_label.text = def.name
		var level_label: Label = card.get_node("LevelLabel")
		if def.max_level > 1:
			var lvl: int = clamp(entry.level - 1, 0, SkillRegistry.ROMAN_NUMERALS.size() - 1)
			level_label.text = SkillRegistry.ROMAN_NUMERALS[lvl]
			level_label.visible = true
		else:
			level_label.visible = false
		var desc_label: Label = card.get_node("DescriptionLabel")
		desc_label.text = SkillRegistry.format_description(entry.type, entry.level)
		var uses_label: Label = card.get_node("UseCountLabel")
		uses_label.text = "Uses: %dx" % int(def.use_count)
	_apply_focus_visual()


func _apply_focus_visual() -> void:
	for i in card_nodes.size():
		var card := card_nodes[i]
		var bg: Panel = card.get_node_or_null("Bg")
		if bg == null:
			continue
		var sb := StyleBoxFlat.new()
		sb.bg_color = FOCUS_BG if i == _focused_idx else NORMAL_BG
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(1.0, 0.353, 0.122, 1.0) if i == _focused_idx else Color(0.196, 0.169, 0.239, 1.0)
		bg.add_theme_stylebox_override("panel", sb)


func _process(_delta: float) -> void:
	if not _active or _player == null:
		return
	var controls: PlayerControls = _player.controls
	if controls == null:
		return
	if _wait_for_use_release and not Input.is_action_pressed(controls.use):
		_wait_for_use_release = false
	if Input.is_action_just_pressed(controls.move_left):
		_focused_idx = (_focused_idx - 1 + _choices.size()) % _choices.size()
		_apply_focus_visual()
	elif Input.is_action_just_pressed(controls.move_right):
		_focused_idx = (_focused_idx + 1) % _choices.size()
		_apply_focus_visual()
	if Input.is_action_just_pressed(controls.use) and _can_confirm_with_use():
		_confirm(_focused_idx)


func _on_card_clicked(idx: int) -> void:
	if not _active:
		return
	_confirm(idx)


func _confirm(idx: int) -> void:
	if idx < 0 or idx >= _choices.size():
		return
	var entry: Dictionary = _choices[idx]
	if _player != null and "pick_consumed_use_this_frame" in _player:
		_player.pick_consumed_use_this_frame = true
	_active = false
	visible = false
	var gm = _player.game_manager if _player != null else null
	if gm != null:
		gm.assign_skill_from_card(_player, entry.type, entry.level)
	_player = null
	_choices = []


func _can_confirm_with_use() -> bool:
	if _wait_for_use_release:
		return false
	return Time.get_ticks_msec() >= _confirm_unlock_time_ms

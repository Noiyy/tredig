extends Node

const LavaScript = preload("res://scripts/lava.gd")

const SETTINGS_VERSION := 1
const SAVE_PATH := "user://user_settings.cfg"

## Rovnaké `action` ako v settings_menu.gd (CONTROL_ACTIONS)
const PERSISTED_ACTIONS: Array[String] = [
	"p1_left", "p1_right", "p1_up", "p1_down", "p1_use",
	"p2_left", "p2_right", "p2_up", "p2_down", "p2_use",
	"ui_cancel",
]

func _ready() -> void:
	load_and_apply()


func load_and_apply() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	if int(config.get_value("general", "version", -1)) != SETTINGS_VERSION:
		return
	_apply_general_from_config(config)
	_apply_input_from_config(config)


func _apply_general_from_config(config: ConfigFile) -> void:
	if not config.has_section("general"):
		return
	if config.has_section_key("general", "fullscreen"):
		if config.get_value("general", "fullscreen"):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if config.has_section_key("general", "lava_sound"):
		LavaScript.set_lava_sound_enabled(bool(config.get_value("general", "lava_sound")))
	_apply_bus_from_config_key(config, "master", "Master")
	_apply_bus_from_config_key(config, "music", "Music")
	_apply_bus_from_config_key(config, "sfx", "SFX")


func _apply_bus_from_config_key(
	config: ConfigFile, value_key: String, bus_name: String
) -> void:
	if not config.has_section_key("general", value_key):
		return
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		return
	var v: float = float(config.get_value("general", value_key))
	AudioServer.set_bus_volume_linear(bus_idx, v)


func _apply_input_from_config(config: ConfigFile) -> void:
	if not config.has_section("input"):
		return
	for action in PERSISTED_ACTIONS:
		if not config.has_section_key("input", action):
			continue
		var sname: StringName = StringName(action)
		if not InputMap.has_action(sname):
			continue
		var payload: Variant = config.get_value("input", action)
		if typeof(payload) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = payload
		var ev_list: Array = d.get("events", [])
		var deadzone: float = float(d.get("deadzone", 0.5))
		InputMap.action_erase_events(sname)
		for es in ev_list:
			if not (es is String):
				continue
			var ev: Variant = str_to_var(String(es))
			if ev is InputEvent:
				InputMap.action_add_event(sname, (ev as InputEvent).duplicate())
		InputMap.action_set_deadzone(sname, deadzone)


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "version", SETTINGS_VERSION)
	var wmode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	var fs: bool = (
		wmode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or wmode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)
	config.set_value("general", "fullscreen", fs)
	config.set_value("general", "lava_sound", LavaScript.is_lava_sound_enabled())
	_save_bus_to_config(config, "master", "Master")
	_save_bus_to_config(config, "music", "Music")
	_save_bus_to_config(config, "sfx", "SFX")
	for action in PERSISTED_ACTIONS:
		var sname: StringName = StringName(action)
		if not InputMap.has_action(sname):
			continue
		var d: float = InputMap.action_get_deadzone(sname)
		var strs: Array[String] = []
		for ev: InputEvent in InputMap.action_get_events(sname):
			strs.append(var_to_str(ev))
		config.set_value("input", action, {"deadzone": d, "events": strs})
	if config.save(SAVE_PATH) != OK:
		push_warning("UserSettings: failed to save: %s" % SAVE_PATH)


func _save_bus_to_config(
	config: ConfigFile, value_key: String, bus_name: String
) -> void:
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		return
	var v: float = db_to_linear(AudioServer.get_bus_volume_db(bus_idx))
	config.set_value("general", value_key, v)

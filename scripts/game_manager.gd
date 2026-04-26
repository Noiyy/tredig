extends Node

var tile_size = 16
var tiles_to_show = 48
var world_left_x = 8 #0
var world_right_x = 640 - 8 #tiles_to_show * tile_size

#const SHOVEL_LEVEL_EXPS = [
	#120, 270, 390, 540, 660, 810, 930, 1080, 1200, 1350,
	#1470, 1620, 1740, 1890, 2040, 2160, 2310, 2430, 2580,
	#2700, 2850, 3000
#]
const SHOVEL_LEVEL_EXPS = [
	120, 220, 320, 440, 540, 640, 770, 870, 970, 1070,
	1190, 1290, 1390, 1490, 1620, 1720, 1820, 1950, 2050,
	2150, 2270, 2370, 2500, 2620, 2800
]
const MAX_HP := 100
const MAX_DURABILITY := 1000 #1000
const FREEZE_PLAYER_SHADER := preload("res://scripts/freeze_player.gdshader")

var lava
var HUD
var middle_border
var players := {}

var _dynamite_scene: PackedScene
var _freeze_particle_texture: Texture2D

enum BonusType {
	NONE,
	SHARPNESS,
	SSHOVEL,
	DULLNESS,
	OVERLOAD
}

func _ready() -> void:
	HUD = get_parent().get_node("HUD")
	lava = get_tree().root.get_node("Main/HBoxContainer/LeftSubViewportContainer/LeftSubViewport/Level/Lava")
	middle_border = get_tree().root.get_node_or_null("Main/HBoxContainer/LeftSubViewportContainer/LeftSubViewport/Level/MiddleBorder")

func register_player(player: CharacterBody2D):
	var id = player.name
	players[id] = {
		"experience": 0,
		"shovel_level": 1,
		"damage_per_hit": 1,
		"durability": MAX_DURABILITY,
		"hp": MAX_HP,
		"ref": player,
		"active_bonuses": [],
		"damage_count": 0,
		"skills": [null, null, null],
		"won": false,
		"finish_time": -1.0,
		"freeze_token": 0,
		"is_frozen": false,
		"freeze_prev_material": null,
		"freeze_particles_node": null,
	}
	player.sync_stats_from_manager(players[id])

func damage_player(player: CharacterBody2D, _base_amount: int = 10, from_lava: bool = false,
	force_amount: bool = false) -> void:
	if player.is_dead:
		return
	var data = players[player.name]
	
	# Striedanie 5/10 podľa damage_count tohto hráča
	data.damage_count += 1
	var amount = _base_amount if force_amount else (5 if (data.damage_count % 2 == 1) else 10)
	
	data.hp = max(data.hp - amount, 0)
	player.sync_stats_from_manager(data)
	HUD.update_player_hp(player, data.hp, MAX_HP, from_lava)
	
	player.modulate = Color("ff8a8a");
	
	if not player.is_dead:
		AudioManager.play("res://assets/sounds/hp_loss.wav")
		if player.name == "PlayerLeft":
			%LeftCamera2D.screen_shake(7, 0.35)
		else:
			%RightCamera2D.screen_shake(7, 0.35)
			
		var t := get_tree().create_timer(0.35)
		t.timeout.connect(func():
			player.modulate = Color("fff")
		)
	
	if data.hp == 0 and not player.is_dead:
		player.on_dead()
		_check_game_over()

func _check_game_over() -> void:
	_try_finish_match()


func _is_player_finished(data: Dictionary) -> bool:
	var ref: CharacterBody2D = data.ref
	return bool(data.won) or (ref != null and ref.is_dead)


func _try_finish_match() -> void:
	if not players.has("PlayerLeft") or not players.has("PlayerRight"):
		return
	var left_data: Dictionary = players["PlayerLeft"]
	var right_data: Dictionary = players["PlayerRight"]
	if _is_player_finished(left_data) and _is_player_finished(right_data):
		_on_both_players_dead()

func _on_both_players_dead() -> void:
	HUD.stop_timer()
	lava.stop_growing()

func change_durability(player: CharacterBody2D, delta_amount: int, restore: bool) -> void:
	var data = players[player.name]
	var prev_dur: int = data.durability
	data.durability = MAX_DURABILITY if restore \
		else clamp(data.durability + delta_amount, 0, MAX_DURABILITY)
	player.sync_stats_from_manager(data)
	HUD.update_player_durability(player, data.durability, MAX_DURABILITY)
	if not restore and delta_amount < 0 and prev_dur <= 0:
		HUD.pulse_durability_empty_shake(player)

func add_player_exp(player: CharacterBody2D, amount: int):
	var data = players[player.name]
	data.experience += amount
	var exp_needed = SHOVEL_LEVEL_EXPS[data.shovel_level - 1]
	var leveled_up := false
	
	while data.experience >= exp_needed and data.shovel_level < SHOVEL_LEVEL_EXPS.size():
		data.experience -= exp_needed
		data.shovel_level += 1
		data.damage_per_hit += 1
		leveled_up = true
		exp_needed = SHOVEL_LEVEL_EXPS[data.shovel_level - 1]
	player.sync_stats_from_manager(data)
	
	if leveled_up:
		player.on_level_up()
		AudioManager.play("res://assets/sounds/levelup.wav")
		change_durability(player, 0, true)
		if data.shovel_level % 2 == 0:
			try_grant_skill_card_pick(player)

	var player_id := 1 if player.name == "PlayerLeft" else 2
	HUD.update_player_hud(player_id, data.shovel_level, data.experience, leveled_up)

func apply_bonus(player: CharacterBody2D, b_type: int) -> void:
	match b_type:
		BonusType.SHARPNESS:
			_add_timed_stat(player, b_type, "damage", 1, 10.0)
		BonusType.SSHOVEL:
			_add_timed_stat(player, b_type, "sshovel", 1, 10.0)
		BonusType.DULLNESS:
			_add_timed_stat(player, b_type, "dullness", 2, 10.0)
		BonusType.OVERLOAD:
			_add_overload_debuff(player, 3.5)
	
func sync_stat_from_player(player_name: String, key: String, new_value: Variant) -> void:
	var data = players[player_name]
	if key == "damage_per_hit":
		data[key] = maxi(int(new_value), 1)
	else:
		data[key] = new_value


func _clamp_damage_per_hit(data: Dictionary) -> void:
	data.damage_per_hit = maxi(data.damage_per_hit, 1)

func _add_timed_stat(player: CharacterBody2D, b_type: BonusType, key: String, delta: float,
 	duration: float) -> void:
	var data = players[player.name]
	if not data.has("effects"):
		data.effects = {}
	if not data.effects.has(key):
		data.effects[key] = 0.0
	data.effects[key] += delta

	if !can_apply_bonus(player):
		return
		
	if (b_type == BonusType.DULLNESS):
		AudioManager.play("res://assets/sounds/debuff.wav")
	else:
		AudioManager.play("res://assets/sounds/bonus2.wav")
	# uprav stat v dátach
	var original_damage = data.damage_per_hit
	
	if not data.has("temp_original"):
		data.temp_original = {}
	
	var player_id := 1 if player.name == "PlayerLeft" else 2
	
	match key:
		"damage":
			data.damage_per_hit += int(delta)
			HUD.update_player_modifier(player_id, delta)
		"dullness":
			var val = clamp(max(original_damage+1 - int(delta), 1), 1, 2)
			if original_damage < 2: val = 0

			data.damage_per_hit -= val
			_clamp_damage_per_hit(data)
			data.temp_original[key] = val
			print("wtf ", original_damage, " , ", val)
			HUD.update_player_modifier(player_id, -val)

	data.active_bonuses.append(b_type)
	player.sync_stats_from_manager(data)
	HUD.start_player_bonus_timer(player, duration, b_type)
	HUD.update_player_bonuses(player, data.active_bonuses)

	# plánuj zrušenie
	var t := get_tree().create_timer(duration)
	t.timeout.connect(func():
		if not is_instance_valid(player):
			return
		data.effects[key] -= delta
		
		match key:
			"damage":
				data.damage_per_hit -= int(delta)
				_clamp_damage_per_hit(data)
				HUD.update_player_modifier(player_id, 0)
			"dullness":
				data.damage_per_hit += data.temp_original.get(key, 0)  # Obnov z data
				print("kolko ", data.damage_per_hit)
				data.temp_original.erase(key)
				HUD.update_player_modifier(player_id, 0)
				
		data.active_bonuses.erase(b_type)
		player.sync_stats_from_manager(data)
		HUD.update_player_bonuses(player, data.active_bonuses)
	)

func get_enemy_player(player: CharacterBody2D) -> CharacterBody2D:
	return players["PlayerRight"].ref if player.name == "PlayerLeft" else players["PlayerLeft"].ref

func _add_overload_debuff(player: CharacterBody2D, duration: float) -> void:
	var data = players[player.name]
	if not data.has("effects"):
		data.effects = {}

	if !can_apply_bonus(player):
		return
		
	AudioManager.play("res://assets/sounds/debuff.wav")
	data.active_bonuses.append(BonusType.OVERLOAD)

	# aplikuj debuff na hráča
	player.set_can_dig(false)
	player.set_speed_multiplier(0.5)  # 50 % rýchlosti
	player.set_gravity_multiplier(0.9) 

	HUD.start_player_bonus_timer(player, duration, BonusType.OVERLOAD)
	HUD.update_player_bonuses(player, data.active_bonuses)

	var t := get_tree().create_timer(duration)
	t.timeout.connect(func():
		if not is_instance_valid(player):
			return

		# zrušenie efektu
		data.active_bonuses.erase(BonusType.OVERLOAD)
		player.set_can_dig(true)
		player.set_speed_multiplier(1.0)
		player.set_gravity_multiplier(1.0) 

		player.sync_stats_from_manager(data)  # vráť ostatné staty, ak treba
		HUD.update_player_bonuses(player, data.active_bonuses)
	)

func on_game_won(player_name: String):
	print("vyhral ", player_name)
	if not players.has(player_name):
		return
	var player_data: Dictionary = players[player_name]
	if bool(player_data.won):
		return
	
	AudioManager.play("res://assets/sounds/win.wav")
	
	var elapsed = HUD.get_elapsed_time()
	player_data.won = true
	player_data.finish_time = elapsed
	if player_name == "PlayerLeft":
		HUD.show_left_game_over(elapsed, "win")
	if player_name == "PlayerRight":
		HUD.show_right_game_over(elapsed, "win")
	_try_finish_match()

func player_has_active_bonus(player: CharacterBody2D) -> bool:
	return not players[player.name].active_bonuses.is_empty()

func player_has_bonus(player: CharacterBody2D, bonus_type: int) -> bool:
	return players[player.name].active_bonuses.has(bonus_type)

func can_apply_bonus(player: CharacterBody2D) -> bool:
	return players[player.name].active_bonuses.size() < 2  # max 2 bonusy

func get_world_x_boundaries():
	return [world_left_x, world_right_x]
	
func get_shovel_level_exps():
	return SHOVEL_LEVEL_EXPS

func get_max_durability():
	return MAX_DURABILITY
	
func get_tile_size():
	return tile_size


# ============================================================================
# Skills
# ============================================================================

func try_grant_skill_card_pick(player: CharacterBody2D) -> void:
	var data = players[player.name]
	if not data.skills.has(null):
		return
	var enemy := get_enemy_player(player)
	var opponent_alive: bool = enemy != null and not enemy.is_dead
	var choices: Array = SkillRegistry.roll_card_choices(opponent_alive)
	if choices.is_empty():
		return
	var p_hud = _get_player_hud_panel(player)
	if p_hud == null:
		return
	var pick_overlay = p_hud.get_node_or_null("SkillCardPick")
	if pick_overlay == null:
		return
	pick_overlay.show_for(player, choices)


func assign_skill_from_card(player: CharacterBody2D, skill_type: int, level: int) -> void:
	var data = players[player.name]
	var def: Dictionary = SkillRegistry.get_def(skill_type)
	var max_uses: int = def.use_count

	for slot in data.skills:
		if slot != null and slot.type == skill_type:
			slot.level = max(slot.level, level)
			slot.uses_remaining = max_uses
			HUD.update_player_skills(player, data.skills)
			return

	for i in data.skills.size():
		if data.skills[i] == null:
			data.skills[i] = {
				"type": skill_type,
				"level": level,
				"uses_remaining": max_uses,
			}
			HUD.update_player_skills(player, data.skills)
			return


func use_skill(player: CharacterBody2D, slot_index: int) -> void:
	if player.is_dead:
		return
	var data = players[player.name]
	if slot_index < 0 or slot_index >= data.skills.size():
		return
	var slot = data.skills[slot_index]
	if slot == null:
		return

	_run_skill_effect(player, slot.type, slot.level)

	slot.uses_remaining -= 1
	if slot.uses_remaining <= 0:
		data.skills[slot_index] = null
	HUD.update_player_skills(player, data.skills)


func set_skill_slot_for_testing(player: CharacterBody2D, slot_index: int, skill_type: int,
	level: int = 1, uses_override: int = -1) -> void:
	if player == null or not is_instance_valid(player):
		return
	if not players.has(player.name):
		return
	var data: Dictionary = players[player.name]
	if slot_index < 0 or slot_index >= data.skills.size():
		return
	if skill_type == SkillRegistry.SkillType.NONE:
		data.skills[slot_index] = null
		HUD.update_player_skills(player, data.skills)
		return
	if not SkillRegistry.SKILLS.has(skill_type):
		return

	var def: Dictionary = SkillRegistry.get_def(skill_type)
	var clamped_level: int = clamp(level, 1, int(def.max_level))
	var max_uses: int = int(def.use_count)
	var uses: int = max_uses if uses_override < 0 else clamp(uses_override, 1, max_uses)

	data.skills[slot_index] = {
		"type": skill_type,
		"level": clamped_level,
		"uses_remaining": uses,
	}
	HUD.update_player_skills(player, data.skills)


func _run_skill_effect(player: CharacterBody2D, skill_type: int, level: int) -> void:
	var modifier: int = SkillRegistry.get_modifier(skill_type, level)
	var enemy := get_enemy_player(player)
	match skill_type:
		SkillRegistry.SkillType.HEAL:
			_apply_heal(player, modifier)
		SkillRegistry.SkillType.DURABILITY_UP:
			_apply_durability_up(player, modifier)
		SkillRegistry.SkillType.SWAP:
			_apply_swap(player, enemy)
		SkillRegistry.SkillType.SABOTAGE_TILE:
			if enemy != null and not enemy.is_dead:
				enemy.apply_sabotage_effect(modifier, 2)
		SkillRegistry.SkillType.DYNAMITE:
			if enemy != null and not enemy.is_dead:
				_spawn_dynamites(enemy, modifier)
		SkillRegistry.SkillType.FREEZE:
			if enemy != null and not enemy.is_dead:
				_apply_freeze(enemy, modifier)


func _apply_heal(player: CharacterBody2D, amount: int) -> void:
	_flash_player_color(player, Color(0.2, 1.0, 0.2, 0.75), 0.7)
	AudioManager.play("res://assets/sounds/bonus2.wav")
	var data = players[player.name]
	var prev = data.hp
	data.hp = min(data.hp + amount, MAX_HP)
	if data.hp == prev:
		return
	player.sync_stats_from_manager(data)
	HUD.update_player_hp(player, data.hp, MAX_HP, false)


func _apply_durability_up(player: CharacterBody2D, percent: int) -> void:
	var amount: int = int(round(MAX_DURABILITY * percent / 100.0))
	change_durability(player, amount, false)
	AudioManager.play("res://assets/sounds/bonus2.wav")
	_flash_player_color(player, Color(0.2, 0.4, 1.0, 0.75), 0.7)


func _flash_player_color(player: CharacterBody2D, color: Color, duration: float) -> void:
	player.modulate = color
	var tween := player.create_tween()
	tween.tween_property(player, "modulate", Color.WHITE, duration)


func _apply_swap(player: CharacterBody2D, enemy: CharacterBody2D) -> void:
	if enemy == null or enemy.is_dead:
		return
	var pos_a: Vector2 = player.global_position
	var pos_b: Vector2 = enemy.global_position
	player.global_position = pos_b
	enemy.global_position = pos_a

	var a_min: float = player.dig_min_x
	var a_max: float = player.dig_max_x
	player.dig_min_x = enemy.dig_min_x
	player.dig_max_x = enemy.dig_max_x
	enemy.dig_min_x = a_min
	enemy.dig_max_x = a_max

	_swap_cameras(player, enemy)

	var border_shape = _get_middle_border_shape()
	if border_shape != null:
		border_shape.disabled = true

	AudioManager.play("res://assets/sounds/bonus2.wav")

	var t := get_tree().create_timer(10.0)
	t.timeout.connect(func():
		if not is_instance_valid(player) or not is_instance_valid(enemy):
			if border_shape != null and is_instance_valid(border_shape):
				border_shape.disabled = false
			return
		var current_a: Vector2 = player.global_position
		var current_b: Vector2 = enemy.global_position
		player.global_position = current_b
		enemy.global_position = current_a
		var b_min: float = player.dig_min_x
		var b_max: float = player.dig_max_x
		player.dig_min_x = enemy.dig_min_x
		player.dig_max_x = enemy.dig_max_x
		enemy.dig_min_x = b_min
		enemy.dig_max_x = b_max
		_swap_cameras(player, enemy)
		if border_shape != null and is_instance_valid(border_shape):
			border_shape.disabled = false
	)


func _swap_cameras(player: CharacterBody2D, enemy: CharacterBody2D) -> void:
	var rt_a: RemoteTransform2D = null
	var rt_b: RemoteTransform2D = null
	for child in player.get_children():
		if child is RemoteTransform2D:
			rt_a = child
			break
	for child in enemy.get_children():
		if child is RemoteTransform2D:
			rt_b = child
			break
	if rt_a == null or rt_b == null:
		return
	var path_a: NodePath = rt_a.remote_path
	rt_a.remote_path = rt_b.remote_path
	rt_b.remote_path = path_a


func _spawn_dynamites(target: CharacterBody2D, count: int) -> void:
	if _dynamite_scene == null:
		_dynamite_scene = load("res://scenes/dynamite.tscn")
	if _dynamite_scene == null:
		return
	var level_node: Node = _get_level_node()
	if level_node == null:
		return
	var center := Vector2i(
		int(target.global_position.x / float(tile_size)),
		int(target.global_position.y / float(tile_size))
	)
	for i in count:
		var coord := _roll_dynamite_spawn_coord(center)
		var dynamite := _dynamite_scene.instantiate()
		if dynamite.has_method("setup"):
			dynamite.setup(coord, target)
		level_node.add_child(dynamite)
		await get_tree().create_timer(0.1).timeout


func _roll_dynamite_spawn_coord(center: Vector2i) -> Vector2i:
	const MIN_DIST := 1.0
	const MAX_DIST := 3.0
	var min_sq := MIN_DIST * MIN_DIST
	var max_sq := MAX_DIST * MAX_DIST
	for _attempt in 16:
		var dx := randi_range(-3, 3)
		var dy := randi_range(-3, 3)
		var dist_sq := float(dx * dx + dy * dy)
		if dist_sq >= min_sq and dist_sq <= max_sq:
			return center + Vector2i(dx, dy)
	var fallback_dx := randi_range(-3, 3)
	if fallback_dx == 0:
		fallback_dx = 1
	return center + Vector2i(fallback_dx, 0)


func _apply_freeze(target: CharacterBody2D, duration_sec: int) -> void:
	if target == null or not is_instance_valid(target) or target.is_dead:
		return
	var data: Dictionary = players[target.name]
	data.freeze_token += 1
	var token: int = int(data.freeze_token)
	var was_frozen: bool = bool(data.is_frozen)
	data.is_frozen = true

	# Hard freeze: player cannot move, jump, dig, or cast skills.
	target.set_physics_process(false)
	target.set_process(false)
	var sprite: AnimatedSprite2D = target.get_node_or_null("AnimatedSprite2D")
	if sprite != null:
		if not was_frozen:
			data.freeze_prev_material = sprite.material
		var freeze_mat := ShaderMaterial.new()
		freeze_mat.shader = FREEZE_PLAYER_SHADER
		sprite.material = freeze_mat
	_attach_freeze_particles(target, data)
	AudioManager.play("res://assets/sounds/debuff.wav")

	var t := get_tree().create_timer(float(duration_sec))
	t.timeout.connect(func():
		if not is_instance_valid(target):
			return
		if not players.has(target.name):
			return
		var latest: Dictionary = players[target.name]
		# Freeze can be reapplied; only the latest timer can unfreeze.
		if int(latest.freeze_token) != token:
			return
		latest.is_frozen = false
		var sprite_restore: AnimatedSprite2D = target.get_node_or_null("AnimatedSprite2D")
		if sprite_restore != null:
			sprite_restore.material = latest.freeze_prev_material
		latest.freeze_prev_material = null
		_remove_freeze_particles(latest)
		if target.is_dead or bool(latest.won):
			return
		target.set_physics_process(true)
		target.set_process(true)
	)


func _attach_freeze_particles(target: CharacterBody2D, data: Dictionary) -> void:
	if data.freeze_particles_node != null and is_instance_valid(data.freeze_particles_node):
		return
	_ensure_freeze_particle_texture()
	var particles := GPUParticles2D.new()
	particles.name = "FreezeIceParticles"
	particles.z_index = 3
	particles.texture = _freeze_particle_texture
	particles.amount = 14
	particles.lifetime = 0.82
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.45
	particles.emitting = true
	particles.position = Vector2(0, -8)

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(7.0, 10.0, 0.0)
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 12.0
	pm.initial_velocity_min = 6.0
	pm.initial_velocity_max = 13.0
	pm.gravity = Vector3(0.0, 42.0, 0.0)
	pm.scale_min = 0.55
	pm.scale_max = 0.95
	pm.angular_velocity_min = -20.0
	pm.angular_velocity_max = 20.0
	pm.damping_min = 4.0
	pm.damping_max = 8.0

	var grad := Gradient.new()
	grad.set_color(0, Color(0.88, 0.95, 1.0, 0.95))
	grad.set_color(1, Color(0.64, 0.84, 1.0, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	pm.color_ramp = grad_tex

	particles.process_material = pm
	target.add_child(particles)
	data.freeze_particles_node = particles


func _remove_freeze_particles(data: Dictionary) -> void:
	var n = data.freeze_particles_node
	if n != null and is_instance_valid(n):
		n.queue_free()
	data.freeze_particles_node = null


func _ensure_freeze_particle_texture() -> void:
	if _freeze_particle_texture != null:
		return
	var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(1, 5):
		for x in range(1, 5):
			var edge := (x == 1 or x == 4 or y == 1 or y == 4)
			var col := Color(0.74, 0.9, 1.0, 1.0) if edge else Color(0.9, 0.98, 1.0, 1.0)
			img.set_pixel(x, y, col)
	_freeze_particle_texture = ImageTexture.create_from_image(img)


func _get_player_hud_panel(player: CharacterBody2D):
	if HUD == null:
		return null
	if player.name == "PlayerLeft":
		return HUD.get_node_or_null("LeftPlayerHUD")
	return HUD.get_node_or_null("RightPlayerHUD")


func _get_middle_border_shape():
	if middle_border == null:
		return null
	return middle_border.get_node_or_null("CollisionShape2D")


func _get_level_node():
	return get_tree().root.get_node_or_null(
		"Main/HBoxContainer/LeftSubViewportContainer/LeftSubViewport/Level"
	)

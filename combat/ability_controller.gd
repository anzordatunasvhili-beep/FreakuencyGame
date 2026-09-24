class_name AbilityController
extends Node

const ORIGINAL_POWER_IDS := [&"ember_nova", &"arc_storm", &"void_bloom", &"glacial_halo", &"solar_spear", &"spirit_pulse"]

signal ability_selected(index: int, ability: AbilityDefinition)
signal ability_cast(ability: AbilityDefinition)
signal power_equipped(slot: int, ability: AbilityDefinition)

@export var abilities: Array[AbilityDefinition] = []
@export var power_library: Array[AbilityDefinition] = []
@export var equipped_powers: Array[AbilityDefinition] = []
@export var effect_layer: Node2D

var selected_index := 0
var _cooldowns: Dictionary = {}
var _cooldown_durations: Dictionary = {}
var _weapon_damage_bonus := 0
var _weapon_damage_multiplier := 1.0
var _weapon_range_bonus := 0.0
var _weapon_attack_speed_multiplier := 1.0

func _process(delta: float) -> void:
	for ability_id in _cooldowns.keys():
		_cooldowns[ability_id] = maxf(0.0, float(_cooldowns[ability_id]) - delta)

func select(index: int) -> void:
	if index < 0 or index >= abilities.size():
		return
	selected_index = index
	ability_selected.emit(index, abilities[index])

func try_cast(origin: Vector2, aim_direction: Vector2) -> bool:
	return try_cast_index(selected_index, origin, aim_direction)

func try_cast_attack(origin: Vector2, aim_direction: Vector2) -> bool:
	if selected_index < 0 or selected_index >= mini(5, abilities.size()):
		return false
	return try_cast_index(selected_index, origin, aim_direction)

func try_cast_power(power_slot: int, origin: Vector2, aim_direction: Vector2) -> bool:
	if power_slot < 0 or power_slot >= equipped_powers.size():
		return false
	return _try_cast_ability(equipped_powers[power_slot], origin, aim_direction)

func try_cast_index(index: int, origin: Vector2, aim_direction: Vector2) -> bool:
	if index < 0 or index >= abilities.size():
		return false
	return _try_cast_ability(abilities[index], origin, aim_direction)

func cooldown_remaining(ability: AbilityDefinition) -> float:
	return float(_cooldowns.get(ability.ability_id, 0.0)) if ability else 0.0

func cooldown_fraction(ability: AbilityDefinition) -> float:
	if ability == null:
		return 0.0
	var duration := float(_cooldown_durations.get(ability.ability_id, ability.cooldown))
	return clampf(cooldown_remaining(ability) / duration, 0.0, 1.0) if duration > 0.0 else 0.0

func equip_power(slot: int, ability: AbilityDefinition) -> bool:
	if slot < 0 or slot >= equipped_powers.size() or ability == null or ability not in power_library:
		return false
	equipped_powers[slot] = ability
	var game_state := get_node_or_null("/root/GameState")
	if game_state and slot < game_state.equipped_power_ids.size():
		game_state.equipped_power_ids[slot] = String(ability.ability_id)
	power_equipped.emit(slot, ability)
	return true

func apply_saved_power_loadout(power_ids: Array[String]) -> void:
	for slot in mini(power_ids.size(), equipped_powers.size()):
		for power in power_library:
			if String(power.ability_id) == power_ids[slot]:
				equipped_powers[slot] = power
				power_equipped.emit(slot, power)
				break

func _try_cast_ability(ability: AbilityDefinition, origin: Vector2, aim_direction: Vector2) -> bool:
	if ability == null or (ability.effect_texture == null and ability.effect_scene == null):
		return false
	if float(_cooldowns.get(ability.ability_id, 0.0)) > 0.0:
		return false
	var direction := aim_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN
	var cooldown_duration := ability.cooldown / maxf(0.01, _weapon_attack_speed_multiplier)
	_cooldowns[ability.ability_id] = cooldown_duration
	_cooldown_durations[ability.ability_id] = cooldown_duration
	_spawn_effect(ability, origin, direction)
	if ability.power_kind == &"" and ability.ability_id not in ORIGINAL_POWER_IDS:
		_damage_targets(ability, origin, direction)
	ability_cast.emit(ability)
	return true

func _spawn_effect(ability: AbilityDefinition, origin: Vector2, direction: Vector2) -> void:
	var effect: Node2D = ability.effect_scene.instantiate() as Node2D if ability.effect_scene else AbilityEffect.new()
	var parent: Node = effect_layer if is_instance_valid(effect_layer) else get_tree().current_scene
	if parent == null:
		parent = get_parent().get_parent() if get_parent() and get_parent().get_parent() else get_parent()
	parent.add_child(effect)
	effect.global_position = origin + direction * ability.effect_distance
	if effect.has_method("setup"):
		effect.setup(ability, direction)
	if ability.power_kind != &"":
		var runtime := SuperpowerRuntime.new()
		effect.add_child(runtime)
		runtime.setup(ability, origin, direction, _effective_damage(ability))
	elif ability.ability_id in ORIGINAL_POWER_IDS:
		var runtime := OriginalPowerRuntime.new()
		effect.add_child(runtime)
		runtime.setup(ability, origin, direction, _effective_damage(ability), get_parent() as Node2D)

func _damage_targets(ability: AbilityDefinition, origin: Vector2, direction: Vector2) -> void:
	var minimum_dot := cos(deg_to_rad(ability.arc_degrees * 0.5))
	var effective_range := maxf(1.0, ability.range + _weapon_range_bonus)
	var effective_damage := _effective_damage(ability)
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if not is_instance_valid(candidate) or not candidate.has_method("take_damage"):
			continue
		var offset: Vector2 = candidate.global_position - origin
		if offset.length() <= effective_range and (offset == Vector2.ZERO or direction.dot(offset.normalized()) >= minimum_dot):
			candidate.take_damage(effective_damage)

func _effective_damage(ability: AbilityDefinition) -> int:
	var game_state := get_node_or_null("/root/GameState")
	var food_attack_bonus: float = game_state.get_food_buff_total(2) if game_state else 0.0
	return maxi(0, roundi((ability.damage + _weapon_damage_bonus + food_attack_bonus) * _weapon_damage_multiplier))

func apply_weapon(weapon: WeaponDefinition) -> void:
	if weapon == null:
		clear_weapon_modifiers()
		return
	_weapon_damage_bonus = weapon.damage_bonus
	_weapon_damage_multiplier = weapon.damage_multiplier
	_weapon_range_bonus = weapon.range_bonus
	_weapon_attack_speed_multiplier = weapon.attack_speed_multiplier

func clear_weapon_modifiers() -> void:
	_weapon_damage_bonus = 0
	_weapon_damage_multiplier = 1.0
	_weapon_range_bonus = 0.0
	_weapon_attack_speed_multiplier = 1.0

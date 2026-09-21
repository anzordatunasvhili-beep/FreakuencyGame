class_name AbilityController
extends Node

signal ability_selected(index: int, ability: AbilityDefinition)
signal ability_cast(ability: AbilityDefinition)

@export var abilities: Array[AbilityDefinition] = []
@export var effect_layer: Node2D

var selected_index := 0
var _cooldowns: Dictionary = {}

func _process(delta: float) -> void:
	for ability_id in _cooldowns.keys():
		_cooldowns[ability_id] = maxf(0.0, float(_cooldowns[ability_id]) - delta)

func select(index: int) -> void:
	if index < 0 or index >= abilities.size():
		return
	selected_index = index
	ability_selected.emit(index, abilities[index])

func try_cast(origin: Vector2, aim_direction: Vector2) -> bool:
	if selected_index >= abilities.size():
		return false
	var ability := abilities[selected_index]
	if ability == null or ability.effect_texture == null:
		return false
	if float(_cooldowns.get(ability.ability_id, 0.0)) > 0.0:
		return false
	var direction := aim_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN
	_cooldowns[ability.ability_id] = ability.cooldown
	_spawn_effect(ability, origin, direction)
	_damage_targets(ability, origin, direction)
	ability_cast.emit(ability)
	return true

func _spawn_effect(ability: AbilityDefinition, origin: Vector2, direction: Vector2) -> void:
	var effect := AbilityEffect.new()
	var parent: Node = effect_layer if is_instance_valid(effect_layer) else get_tree().current_scene
	if parent == null:
		parent = get_parent().get_parent() if get_parent() and get_parent().get_parent() else get_parent()
	parent.add_child(effect)
	effect.global_position = origin + direction * ability.effect_distance
	effect.setup(ability, direction)

func _damage_targets(ability: AbilityDefinition, origin: Vector2, direction: Vector2) -> void:
	var minimum_dot := cos(deg_to_rad(ability.arc_degrees * 0.5))
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if not is_instance_valid(candidate) or not candidate.has_method("take_damage"):
			continue
		var offset: Vector2 = candidate.global_position - origin
		if offset.length() <= ability.range and (offset == Vector2.ZERO or direction.dot(offset.normalized()) >= minimum_dot):
			candidate.take_damage(ability.damage)

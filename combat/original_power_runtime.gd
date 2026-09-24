class_name OriginalPowerRuntime
extends Node
## Timed gameplay for the original six powers. Geometry follows their VFX cues.

var definition: AbilityDefinition
var origin := Vector2.ZERO
var direction := Vector2.RIGHT
var caster: Node2D
var damage := 0
var elapsed := 0.0
var phase := 0
var hit_ids: Dictionary = {}
var chain_target: Node2D
var chain_point := Vector2.ZERO
var chain_points: PackedVector2Array
var healed := 0

func setup(ability: AbilityDefinition, cast_origin: Vector2, aim: Vector2, effective_damage: int, source: Node2D) -> void:
	definition = ability
	origin = cast_origin
	direction = aim.normalized() if aim != Vector2.ZERO else Vector2.DOWN
	caster = source
	damage = effective_damage
	chain_point = origin
	if ability.ability_id == &"spirit_pulse":
		_heal_caster(8)
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if definition == null:
		return
	var previous := elapsed
	elapsed += delta
	match definition.ability_id:
		&"ember_nova": _ember()
		&"arc_storm": _arc()
		&"void_bloom": _void()
		&"glacial_halo": _glacial()
		&"solar_spear": _solar(previous)
		&"spirit_pulse": _spirit()
	if elapsed > 2.2:
		set_physics_process(false)

func _ember() -> void:
	var times := [0.12, 0.50, 0.91]
	var radii := [38.0, 62.0, definition.range]
	while phase < times.size() and elapsed >= times[phase]:
		var radius: float = radii[phase]
		for target in _targets():
			if target.global_position.distance_squared_to(origin) <= radius * radius:
				target.take_damage(maxi(1, roundi(damage * (0.62 if phase == 0 else 0.38))))
		phase += 1

func _arc() -> void:
	if elapsed < 0.10:
		return
	while phase < 4 and elapsed >= 0.10 + phase * 0.13:
		var best: Node2D = null
		var nearest := INF
		for target in _targets():
			if hit_ids.has(target.get_instance_id()):
				continue
			var offset: Vector2 = target.global_position - chain_point
			if phase == 0:
				if offset.length() > definition.range or direction.dot(offset.normalized()) < cos(deg_to_rad(definition.arc_degrees * 0.5)):
					continue
			elif offset.length() > 78.0:
				continue
			if offset.length_squared() < nearest:
				nearest = offset.length_squared()
				best = target
		if best == null:
			break
		if chain_points.is_empty():
			chain_points.append(origin)
		chain_points.append(best.global_position)
		chain_point = best.global_position
		hit_ids[best.get_instance_id()] = true
		best.take_damage(maxi(1, roundi(damage * pow(0.77, phase))))
		if best.has_method("apply_stasis"):
			best.apply_stasis(get_instance_id(), 0.18)
		var effect := get_parent()
		if effect.has_method("show_chain"):
			effect.show_chain(chain_points)
		phase += 1

func _void() -> void:
	var times := [0.18, 0.48, 0.82]
	while phase < times.size() and elapsed >= times[phase]:
		var petal_direction := direction.rotated(deg_to_rad(-27.0 + phase * 27.0))
		for target in _targets():
			var offset: Vector2 = target.global_position - origin
			if offset.length() > definition.range or offset == Vector2.ZERO:
				continue
			if petal_direction.dot(offset.normalized()) >= cos(deg_to_rad(47.0)):
				target.take_damage(maxi(1, roundi(damage * 0.48)))
		phase += 1

func _glacial() -> void:
	var times := [0.18, 0.47, 0.78]
	var radii := [38.0, 64.0, definition.range]
	while phase < times.size() and elapsed >= times[phase]:
		var radius: float = radii[phase]
		for target in _targets():
			var distance := target.global_position.distance_to(origin)
			if absf(distance - radius) <= 19.0:
				target.take_damage(maxi(1, roundi(damage * 0.8)))
				if target.has_method("apply_stasis"):
					target.apply_stasis(get_instance_id(), 0.38)
		phase += 1

func _solar(previous: float) -> void:
	var start := origin + direction * definition.effect_distance
	var travel := maxf(1.0, definition.range - definition.effect_distance)
	var previous_point := start + direction * travel * clampf(previous / 0.53, 0.0, 1.0)
	var current_point := start + direction * travel * clampf(elapsed / 0.53, 0.0, 1.0)
	for target in _targets():
		if hit_ids.size() >= 2 or hit_ids.has(target.get_instance_id()):
			continue
		if target.global_position.distance_squared_to(Geometry2D.get_closest_point_to_segment(target.global_position, previous_point, current_point)) <= 14.0 * 14.0:
			hit_ids[target.get_instance_id()] = true
			target.take_damage(damage)
	if phase == 0 and elapsed >= 0.53:
		phase = 1
		var end := origin + direction * definition.range
		for target in _targets():
			if target.global_position.distance_squared_to(end) <= 43.0 * 43.0:
				target.take_damage(maxi(1, roundi(damage * 0.46)))

func _spirit() -> void:
	if phase > 0 or elapsed < 0.32:
		return
	phase = 1
	for target in _targets():
		var offset: Vector2 = target.global_position - origin
		if offset.length() > definition.range or offset == Vector2.ZERO:
			continue
		if direction.dot(offset.normalized()) < 0.0:
			continue
		target.take_damage(damage)
		if target is CharacterBody2D:
			(target as CharacterBody2D).move_and_collide(offset.normalized() * 26.0)
		_heal_caster(4)

func _heal_caster(amount: int) -> void:
	if not is_instance_valid(caster) or healed >= 20:
		return
	var state := caster.get_node_or_null("/root/GameState")
	if state != null:
		var actual := mini(amount, 20 - healed)
		state.heal(actual)
		healed += actual

func _targets() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if not is_instance_valid(candidate) or candidate.is_queued_for_deletion() or not candidate is Node2D or not candidate.has_method("take_damage"):
			continue
		var health: Variant = candidate.get("health")
		if health != null and int(health) <= 0:
			continue
		result.append(candidate as Node2D)
	return result

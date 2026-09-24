class_name SuperpowerRuntime
extends Node

## Gameplay follows the visual's charge / sustain / release clock. The effect owns
## this node, so removing a visual also releases every status that it applied.
const LANCE_HALF_WIDTH := 16.0

var definition: AbilityDefinition
var _origin := Vector2.ZERO
var _direction := Vector2.RIGHT
var _damage := 0
var _elapsed := 0.0
var _resolved := false
var _stasis_targets: Dictionary = {}

func setup(ability: AbilityDefinition, origin: Vector2, direction: Vector2, damage: int) -> void:
	definition = ability
	_origin = origin
	_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.DOWN
	_damage = maxi(0, damage)
	_elapsed = 0.0
	_resolved = false
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if definition == null or _resolved:
		return
	_elapsed += delta
	if _elapsed < definition.charge_duration:
		return
	var release_time := definition.charge_duration + definition.sustain_duration
	match definition.power_kind:
		&"event_horizon":
			if _elapsed >= release_time:
				_damage_circle(_field_center())
				_resolve()
			else:
				_pull_targets(delta)
		&"astral_lance":
			_fire_lance()
			_resolve()
		&"chronostasis":
			if _elapsed >= release_time:
				# Also capture on a long frame that crosses the entire active phase.
				_capture_stasis(0.05)
				_release_stasis(true)
				_resolve()
			else:
				_capture_stasis(release_time - _elapsed + 0.1)

func _resolve() -> void:
	_resolved = true
	set_physics_process(false)

func _field_center() -> Vector2:
	var effect := get_parent() as Node2D
	return effect.global_position if effect else _origin + _direction * definition.effect_distance

func _living_targets() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if _is_living_target(candidate):
			result.append(candidate as Node2D)
	return result

func _is_living_target(candidate: Node) -> bool:
	if not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
		return false
	if not candidate is Node2D or not candidate.has_method("take_damage"):
		return false
	# Mob and combat test targets both expose health. Other damageable objects can
	# opt in through the mobs group without needing a particular concrete class.
	var health: Variant = candidate.get("health")
	return health == null or int(health) > 0

func _damage_circle(center: Vector2) -> void:
	for candidate in _living_targets():
		if candidate.global_position.distance_squared_to(center) <= definition.range * definition.range:
			candidate.take_damage(_damage)

func _pull_targets(delta: float) -> void:
	var center := _field_center()
	for candidate in _living_targets():
		var distance := candidate.global_position.distance_to(center)
		if distance <= definition.range and candidate.has_method("apply_gravity_pull"):
			var strength := lerpf(145.0, 65.0, clampf(distance / definition.range, 0.0, 1.0))
			candidate.apply_gravity_pull(center, strength, delta)

func _fire_lance() -> void:
	var endpoint := _origin + _direction * definition.range
	for candidate in _living_targets():
		var closest := Geometry2D.get_closest_point_to_segment(candidate.global_position, _origin, endpoint)
		if candidate.global_position.distance_squared_to(closest) <= LANCE_HALF_WIDTH * LANCE_HALF_WIDTH:
			candidate.take_damage(_damage)

func _capture_stasis(remaining_duration: float) -> void:
	var center := _field_center()
	for candidate in _living_targets():
		if candidate.global_position.distance_squared_to(center) > definition.range * definition.range:
			continue
		if not candidate.has_method("apply_stasis"):
			continue
		candidate.apply_stasis(get_instance_id(), remaining_duration)
		_stasis_targets[candidate.get_instance_id()] = weakref(candidate)

func _release_stasis(deal_damage: bool) -> void:
	for target_ref: WeakRef in _stasis_targets.values():
		var candidate := target_ref.get_ref() as Node2D
		if not is_instance_valid(candidate):
			continue
		if candidate.has_method("remove_stasis"):
			candidate.remove_stasis(get_instance_id())
		if deal_damage and _is_living_target(candidate):
			candidate.take_damage(_damage)
	_stasis_targets.clear()

func _exit_tree() -> void:
	_release_stasis(false)

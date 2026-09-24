extends SceneTree

class Target:
	extends Node2D
	var health := 100
	var hits := 0
	var pull_count := 0
	var stasis: Dictionary = {}
	func take_damage(amount: int) -> void:
		hits += 1
		health -= amount
	func apply_gravity_pull(_center: Vector2, _strength: float, _delta: float) -> void:
		pull_count += 1
	func apply_stasis(source_id: int, duration: float) -> void:
		stasis[source_id] = duration
	func remove_stasis(source_id: int) -> void:
		stasis.erase(source_id)

var _world: Node2D
var _failed := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_world = Node2D.new()
	root.add_child(_world)
	_test_controller_and_horizon()
	_clear_fixture()
	_test_lance_geometry()
	_clear_fixture()
	_test_stasis_lifecycle()
	_clear_fixture()
	await _test_mob_status_and_collision()
	if not _failed:
		print("Superpower smoke test passed: delayed damage, capsule geometry, cooldowns, status cleanup, and collision-safe gravity.")
	quit(1 if _failed else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("Superpower smoke test: " + message)

func _ability(kind: StringName) -> AbilityDefinition:
	var ability := AbilityDefinition.new()
	ability.ability_id = kind
	ability.power_kind = kind
	ability.damage = 23
	ability.range = 100.0
	ability.cooldown = 4.0
	ability.charge_duration = 0.2
	ability.sustain_duration = 0.3
	ability.release_duration = 0.2
	var effect := Node2D.new()
	ability.effect_scene = PackedScene.new()
	ability.effect_scene.pack(effect)
	effect.free()
	return ability

func _target(position: Vector2) -> Target:
	var target := Target.new()
	_world.add_child(target)
	target.global_position = position
	target.add_to_group("mobs")
	return target

func _runtime(ability: AbilityDefinition, direction := Vector2.RIGHT) -> SuperpowerRuntime:
	var effect := Node2D.new()
	_world.add_child(effect)
	effect.global_position = direction * ability.effect_distance
	var runtime := SuperpowerRuntime.new()
	effect.add_child(runtime)
	runtime.setup(ability, Vector2.ZERO, direction, ability.damage)
	runtime.set_physics_process(false)
	return runtime

func _clear_fixture() -> void:
	for child in _world.get_children():
		child.free()

func _test_controller_and_horizon() -> void:
	var ability := _ability(&"event_horizon")
	ability.effect_distance = 80.0
	var controller := AbilityController.new()
	controller.effect_layer = _world
	controller.abilities.append(ability)
	_world.add_child(controller)
	controller.set_process(false)
	var center_target := _target(Vector2(80.0, 0.0))
	var behind_caster := _target(Vector2(-15.0, 0.0))
	var outside := _target(Vector2(190.0, 0.0))
	var dead := _target(Vector2(85.0, 0.0))
	dead.health = 0
	_check(controller.try_cast(Vector2.ZERO, Vector2.RIGHT), "horizon could not cast")
	_check(center_target.hits == 0 and behind_caster.hits == 0, "advanced power applied immediate legacy damage")
	_check(not controller.try_cast(Vector2.ZERO, Vector2.RIGHT), "cooldown allowed duplicate cast")
	_check(is_equal_approx(controller.cooldown_remaining(ability), 4.0), "cooldown seconds are incorrect")
	_check(is_equal_approx(controller.cooldown_fraction(ability), 1.0), "cooldown fraction did not begin full")
	var effect := _world.get_child(_world.get_child_count() - 1)
	var runtime := effect.get_child(0) as SuperpowerRuntime
	_check(runtime != null, "controller did not attach a gameplay runtime")
	if runtime == null:
		return
	runtime.set_physics_process(false)
	runtime._physics_process(0.19)
	_check(center_target.hits == 0 and center_target.pull_count == 0, "horizon acted before charge completed")
	runtime._physics_process(0.06)
	_check(center_target.pull_count == 1 and outside.pull_count == 0, "horizon pull used incorrect radius")
	_check(center_target.hits == 0, "horizon damaged before its collapse")
	runtime._physics_process(0.26)
	_check(center_target.health == 77 and behind_caster.health == 77, "collapse did not use the effect center and full circle")
	_check(outside.hits == 0 and dead.hits == 0 and dead.pull_count == 0, "horizon hit an outside or dead target")
	runtime._physics_process(1.0)
	_check(center_target.hits == 1, "horizon collapse dealt damage twice")
	controller._process(2.0)
	_check(is_equal_approx(controller.cooldown_fraction(ability), 0.5), "cooldown fraction did not decrease")
	controller._process(2.5)
	_check(controller.cooldown_remaining(ability) == 0.0 and controller.cooldown_fraction(ability) == 0.0, "cooldown did not finish at zero")
	_check(controller.try_cast(Vector2.ZERO, Vector2.RIGHT), "finished cooldown did not allow recasting")

func _test_lance_geometry() -> void:
	var ability := _ability(&"astral_lance")
	ability.range = 240.0
	ability.effect_distance = 0.0
	var near := _target(Vector2(10.0, 50.0))
	var far := _target(Vector2(-10.0, 225.0))
	var endcap := _target(Vector2(0.0, 250.0))
	var off_axis := _target(Vector2(17.0, 100.0))
	var beyond := _target(Vector2(0.0, 260.0))
	var behind := _target(Vector2(0.0, -20.0))
	var dead := _target(Vector2(0.0, 100.0))
	dead.health = 0
	var runtime := _runtime(ability, Vector2.DOWN)
	runtime._physics_process(0.19)
	_check(near.hits == 0, "lance hit during charge")
	runtime._physics_process(0.02)
	_check(near.health == 77 and far.health == 77 and endcap.health == 77, "lance failed to pierce targets along its aimed capsule")
	_check(off_axis.hits == 0 and beyond.hits == 0 and behind.hits == 0 and dead.hits == 0, "lance hit outside its capsule or hit a dead target")
	runtime._physics_process(0.8)
	_check(near.hits == 1 and far.hits == 1, "lance repeatedly damaged during sustain")

func _test_stasis_lifecycle() -> void:
	var ability := _ability(&"chronostasis")
	ability.effect_distance = 0.0
	var inside := _target(Vector2(30.0, 0.0))
	var outside := _target(Vector2(101.0, 0.0))
	var runtime := _runtime(ability)
	runtime._physics_process(0.19)
	_check(inside.stasis.is_empty(), "stasis activated before charge")
	runtime._physics_process(0.02)
	_check(inside.stasis.size() == 1 and outside.stasis.is_empty(), "stasis used incorrect timing or radius")
	var overlapping := _runtime(ability)
	overlapping._physics_process(0.21)
	_check(inside.stasis.size() == 2, "overlapping stasis did not keep independent sources")
	runtime.get_parent().free()
	_check(inside.stasis.size() == 1 and inside.hits == 0, "destroyed field did not release only its own status")
	var entrant := _target(Vector2(20.0, 10.0))
	overlapping._physics_process(0.1)
	_check(entrant.stasis.size() == 1, "stasis did not capture an entrant during sustain")
	overlapping._physics_process(0.21)
	_check(inside.stasis.is_empty() and entrant.stasis.is_empty(), "stasis statuses survived release")
	_check(inside.health == 77 and entrant.health == 77 and outside.hits == 0, "stasis release dealt incorrect damage")
	overlapping._physics_process(1.0)
	_check(inside.hits == 1, "stasis release dealt damage twice")

func _test_mob_status_and_collision() -> void:
	var mob := (load("res://scenes/mobs/mob.tscn") as PackedScene).instantiate() as Mob
	mob.definition = (load("res://data/mobs/orc_1.tres") as MobDefinition).duplicate()
	mob.definition.hostile_to_player = false
	_world.add_child(mob)
	await physics_frame
	await physics_frame
	mob.set_physics_process(false)
	mob.wander_timer.stop()
	mob.apply_stasis(100, 0.1)
	mob.apply_stasis(200, 1.0)
	mob._physics_process(0.2)
	_check(mob.is_in_stasis() and mob._stasis_sources.size() == 1, "mob status expiry removed another field's stasis")
	_check(not mob.perform_attack(), "frozen mob was able to attack")
	mob.remove_stasis(200)
	_check(not mob.is_in_stasis(), "mob did not unfreeze after removing its last source")
	mob.apply_stasis(300, 0.1)
	mob._physics_process(0.2)
	_check(not mob.is_in_stasis(), "orphan status did not expire")
	mob.apply_stasis(400, 10.0)
	mob.take_damage(1)
	for frame in 20:
		mob._physics_process(0.15)
	_check(mob.is_in_stasis() and not mob._action_locked, "hurt animation remained locked during stasis")
	mob.remove_stasis(400)
	var wall := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(4.0, 100.0)
	collision.shape = shape
	wall.add_child(collision)
	_world.add_child(wall)
	wall.position = Vector2(25.0, -5.0)
	await physics_frame
	await physics_frame
	mob.apply_gravity_pull(Vector2(100.0, 0.0), 1000.0, 1.0)
	_check(mob.position.x < 15.0 and mob.position.x > 0.0, "gravity pull crossed a solid wall")
	mob.apply_stasis(500, 10.0)
	mob.take_damage(mob.health)
	_check(not mob.is_in_stasis(), "dead mob retained stasis")
	for frame in 20:
		mob._physics_process(0.15)
		if mob.is_queued_for_deletion():
			break
	_check(mob.is_queued_for_deletion(), "stasis prevented death animation cleanup")
	await process_frame

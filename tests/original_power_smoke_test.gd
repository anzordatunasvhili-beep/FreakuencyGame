extends SceneTree

class Target:
	extends Node2D
	var health := 300
	var hits := 0
	var stasis: Dictionary = {}
	func take_damage(amount: int) -> void:
		hits += 1
		health -= amount
	func apply_stasis(source_id: int, duration: float) -> void:
		stasis[source_id] = duration

var arena: Node2D
var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	arena = Node2D.new()
	root.add_child(arena)
	_test_ember()
	_clear()
	_test_arc()
	_clear()
	_test_void()
	_clear()
	_test_glacial()
	_clear()
	_test_solar()
	_clear()
	_test_spirit()
	_clear()
	_test_controller_integration()
	if not failed:
		print("Original power smoke test passed: six timed abilities, targeting, chain limits, pierce, and healing.")
	quit(1 if failed else 0)

func _check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error("Original power smoke test: " + message)

func _target(at: Vector2) -> Target:
	var target := Target.new()
	arena.add_child(target)
	target.position = at
	target.add_to_group("mobs")
	return target

func _runtime(id: String, source: Node2D = null) -> OriginalPowerRuntime:
	var ability := load("res://data/abilities/%s.tres" % id) as AbilityDefinition
	var visual := Node2D.new()
	arena.add_child(visual)
	visual.position = Vector2.RIGHT * ability.effect_distance
	var runtime := OriginalPowerRuntime.new()
	visual.add_child(runtime)
	runtime.setup(ability, Vector2.ZERO, Vector2.RIGHT, ability.damage, source)
	runtime.set_physics_process(false)
	return runtime

func _clear() -> void:
	for child in arena.get_children():
		child.free()

func _test_ember() -> void:
	var close := _target(Vector2(28, 0))
	var outer := _target(Vector2(72, 0))
	var beyond := _target(Vector2(80, 0))
	var runtime := _runtime("ember_nova")
	runtime._physics_process(0.10)
	_check(close.hits == 0, "Ember Nova hit before its first ring")
	runtime._physics_process(0.08)
	_check(close.hits == 1 and outer.hits == 0, "first fire ring radius is incorrect")
	runtime._physics_process(0.8)
	_check(close.hits == 3 and outer.hits == 1 and beyond.hits == 0, "expanding fire rings missed or hit outside range")

func _test_arc() -> void:
	var targets := [_target(Vector2(50, 0)), _target(Vector2(110, 0)), _target(Vector2(170, 0)), _target(Vector2(230, 0))]
	var off := _target(Vector2(200, 110))
	var runtime := _runtime("arc_storm")
	runtime._physics_process(0.09)
	_check(targets[0].hits == 0, "Arc Storm fired without a charge")
	runtime._physics_process(0.55)
	for target in targets:
		_check(target.hits == 1 and target.stasis.size() == 1, "lightning failed to chain or briefly interrupt a target")
	_check(off.hits == 0 and runtime.chain_points.size() == 5, "lightning exceeded its four target chain")

func _test_void() -> void:
	var front := _target(Vector2(60, 0))
	var behind := _target(Vector2(-35, 0))
	var far := _target(Vector2(110, 0))
	var runtime := _runtime("void_bloom")
	runtime._physics_process(1.0)
	_check(front.hits >= 2 and behind.hits == 0 and far.hits == 0, "void petals did not strike the forward fan")

func _test_glacial() -> void:
	var ring := _target(Vector2(88, 0))
	var center := _target(Vector2(0, 0))
	var runtime := _runtime("glacial_halo")
	runtime._physics_process(0.9)
	_check(ring.hits > 0 and ring.stasis.size() == 1, "Glacial Halo rim did not freeze")
	_check(center.hits == 0, "Glacial Halo damaged inside its hollow center")

func _test_solar() -> void:
	var first := _target(Vector2(72, 0))
	var second := _target(Vector2(106, 0))
	var last := _target(Vector2(142, 0))
	var side := _target(Vector2(110, 60))
	var runtime := _runtime("solar_spear")
	runtime._physics_process(0.11)
	_check(first.hits == 1 and second.hits == 0, "Solar Spear did not travel through its first target")
	runtime._physics_process(0.47)
	_check(first.hits == 1 and second.hits >= 1 and last.hits == 1 and side.hits == 0, "Solar Spear pierce or terminal burst failed")

func _test_spirit() -> void:
	var caster := Node2D.new()
	arena.add_child(caster)
	var front := _target(Vector2(60, 0))
	var rear := _target(Vector2(-40, 0))
	var state := root.get_node("GameState")
	var old_hp: int = state.hp
	state.hp = 50
	var runtime := _runtime("spirit_pulse", caster)
	_check(state.hp == 58, "Spirit Pulse did not heal on cast")
	runtime._physics_process(0.36)
	_check(front.hits == 1 and rear.hits == 0 and state.hp == 62, "Spirit Pulse failed to heal from a forward hit")
	state.hp = old_hp

func _test_controller_integration() -> void:
	var ability := load("res://data/abilities/ember_nova.tres") as AbilityDefinition
	var controller := AbilityController.new()
	controller.abilities.append(ability)
	controller.effect_layer = arena
	arena.add_child(controller)
	var target := _target(Vector2(20, 0))
	_check(controller.try_cast(Vector2.ZERO, Vector2.RIGHT), "controller failed to cast an original power")
	_check(target.hits == 0, "controller applied immediate legacy cone damage")
	var effect := arena.get_child(arena.get_child_count() - 1) as PowerEffect
	_check(effect != null, "original power visual did not spawn")
	if effect != null:
		var runtime := effect.get_child(effect.get_child_count() - 1) as OriginalPowerRuntime
		_check(runtime != null, "original power runtime was not attached")

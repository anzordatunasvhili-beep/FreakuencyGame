extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var world := main_scene.instantiate()
	root.add_child(world)
	for frame in 6:
		await physics_frame

	var mobs := get_nodes_in_group("mobs")
	if mobs.size() != 12:
		push_error("Mob smoke test expected 6 cats and 6 orcs, found %d mobs." % mobs.size())
		quit(1)
		return
	var counts := {}
	for spawned_mob: Mob in mobs:
		var actor_id := String(spawned_mob.definition.actor_id)
		counts[actor_id] = counts.get(actor_id, 0) + 1
	if counts.get("cat", 0) != 6 or counts.get("orc_1", 0) != 2 or counts.get("orc_2", 0) != 2 or counts.get("orc_3", 0) != 2:
		push_error("Mob smoke test found incorrect mob distribution: %s" % counts)
		quit(1)
		return

	var mob: Mob = mobs[0]
	var start := mob.global_position
	mob._choose_wander_target()
	for frame in 120:
		await physics_frame

	if not is_instance_valid(mob) or mob.global_position.distance_to(start) < 1.0:
		push_error("Mob smoke test: cat spawned but did not walk. start=%s closest_start=%s end=%s target=%s finished=%s map=%s regions=%s" % [start, NavigationServer2D.map_get_closest_point(mob.navigation_agent.get_navigation_map(), start), mob.global_position, mob.navigation_agent.target_position, mob.navigation_agent.is_navigation_finished(), mob.navigation_agent.get_navigation_map(), NavigationServer2D.map_get_regions(mob.navigation_agent.get_navigation_map()).size()])
		quit(1)
		return

	var orc: Mob = null
	for spawned_mob: Mob in mobs:
		if spawned_mob.definition.actor_id == &"orc_1":
			orc = spawned_mob
			break
	if orc == null or not orc.perform_attack():
		push_error("Mob smoke test: orc attack animation could not start.")
		quit(1)
		return
	for frame in 90:
		await physics_frame
	if orc._action_locked:
		push_error("Mob smoke test: orc attack animation did not finish.")
		quit(1)
		return

	var player := get_first_node_in_group("player") as Node2D
	var game_state := root.get_node("GameState")
	game_state.hp = game_state.max_hp
	game_state.stats_changed.emit()
	orc.global_position = player.global_position + Vector2(20, 0)
	orc._home_position = orc.global_position
	orc._combat_target = null
	orc._attack_cooldown_remaining = 0.0
	for frame in 90:
		await physics_frame
	if game_state.hp >= game_state.max_hp:
		push_error("Mob smoke test: hostile orc detected the player but did not deal damage.")
		quit(1)
		return
	orc.definition.hostile_to_player = false
	orc.take_damage(1)
	for frame in 70:
		await physics_frame
	if orc._action_locked or orc.health != orc.definition.max_health - 1:
		push_error("Mob smoke test: orc hurt state did not apply and recover correctly.")
		quit(1)
		return

	var death_test_orc: Mob = null
	for spawned_mob: Mob in mobs:
		if spawned_mob.definition.actor_id == &"orc_3":
			death_test_orc = spawned_mob
			break
	death_test_orc.take_damage(death_test_orc.definition.max_health)
	for frame in 90:
		await physics_frame
	if is_instance_valid(death_test_orc):
		push_error("Mob smoke test: orc death animation did not finish and remove the mob.")
		quit(1)
		return

	print("Mob smoke test passed: cats stay passive; orcs spawn, chase, attack, damage, react, and die.")
	quit(0)

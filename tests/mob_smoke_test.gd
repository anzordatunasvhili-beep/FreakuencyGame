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
	var generated_ground := world.get_node("Node2D/TileMapLayer") as TileMapLayer
	var generated_details := world.get_node("Node2D/TileMapLayer2") as TileMapLayer
	var water_cells := 0
	for generated_cell in generated_ground.get_used_cells():
		if generated_ground.get_cell_atlas_coords(generated_cell) in ProceduralWorld.WATER_TILES:
			water_cells += 1
	if water_cells == 0 or generated_details.get_used_cells().is_empty():
		push_error("Mob smoke test: improved water or seeded environment details were not generated.")
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
	for spawned_mob: Mob in mobs:
		if spawned_mob.definition.actor_id == &"cat" and not is_equal_approx(spawned_mob.definition.sprite_scale, 0.06):
			push_error("Mob smoke test: cats are not configured at half scale.")
			quit(1)
			return
	for spawned_mob: Mob in mobs:
		if spawned_mob.health_bar == null or spawned_mob.health_bar.bar.value != spawned_mob.health:
			push_error("Mob smoke test: a mob health bar was not initialized correctly.")
			quit(1)
			return
		if spawned_mob.health_bar.visible != spawned_mob.definition.hostile_to_player:
			push_error("Mob smoke test: health bar visibility does not match monster hostility.")
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
	if orc != null:
		# Stop ambient combat before testing a deliberate attack animation.
		orc.definition = orc.definition.duplicate()
		orc.definition.hostile_to_player = false
		for frame in 30:
			if not orc._action_locked:
				break
			await physics_frame
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
	orc.definition.hostile_to_player = true
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

	var ability_controller := player.get_node("AbilityController") as AbilityController
	if ability_controller == null or ability_controller.abilities.size() != 5:
		push_error("Mob smoke test: player attack loadout did not initialize five attacks.")
		quit(1)
		return
	if ability_controller.power_library.size() != 9 or ability_controller.equipped_powers.size() != 2:
		push_error("Mob smoke test: power library or two-slot equipped loadout is invalid.")
		quit(1)
		return
	if game_state.inventory.size() < 14:
		push_error("Mob smoke test: generated foods and potions did not appear in inventory.")
		quit(1)
		return
	for starter_slot in 4:
		if game_state.hotbar[starter_slot] == null:
			push_error("Mob smoke test: starter consumables did not appear on the hotbar.")
			quit(1)
			return
	await process_frame
	var inventory_grid := world.get_node("Inventory/ScrollContainer/GridContainer") as GridContainer
	if inventory_grid.get_child_count() < 14:
		push_error("Mob smoke test: inventory UI did not render the generated items.")
		quit(1)
		return
	var first_inventory_icon := inventory_grid.get_child(0).get_node("Item") as TextureRect
	var first_hotbar_icon := world.get_node("HUD/Control/Hotbar/B1/TextureRect") as TextureRect
	if first_inventory_icon.texture == null:
		push_error("Mob smoke test: inventory did not render item textures.")
		quit(1)
		return
	if first_hotbar_icon.texture == null:
		push_error("Mob smoke test: hotbar did not render item textures.")
		quit(1)
		return
	var weapon_controller := player.get_node("WeaponOrbit") as WeaponController
	if weapon_controller == null or weapon_controller.equipped_weapon == null or weapon_controller.weapon_sprite.texture == null:
		push_error("Mob smoke test: the equipped sword or its orbit visual did not initialize.")
		quit(1)
		return
	var expected_orbit_distance := weapon_controller.equipped_weapon.orbit_radius + weapon_controller.orbit_clearance
	if not is_equal_approx(weapon_controller.weapon_sprite.position.length(), expected_orbit_distance):
		push_error("Mob smoke test: the sword is not positioned on its configured orbit.")
		quit(1)
		return
	for sword_number in range(1, 17):
		var sword_path := "res://data/weapons/swords/ranitaya_sword_%02d.tres" % sword_number
		var sword := load(sword_path) as WeaponDefinition
		if sword == null or sword.world_texture == null or sword.weapon_id == &"":
			push_error("Mob smoke test: invalid weapon definition at %s." % sword_path)
			quit(1)
			return
	orc.global_position = player.global_position + Vector2(30, 0)
	var health_before_ability := orc.health
	ability_controller.select(0)
	if not ability_controller.try_cast(player.global_position, Vector2.RIGHT):
		push_error("Mob smoke test: VFX ability could not be cast.")
		quit(1)
		return
	await process_frame
	var expected_weapon_damage := roundi((ability_controller.abilities[0].damage + weapon_controller.equipped_weapon.damage_bonus) * weapon_controller.equipped_weapon.damage_multiplier)
	if orc.health != health_before_ability - expected_weapon_damage or orc.health_bar.bar.value != orc.health:
		push_error("Mob smoke test: VFX ability did not damage the orc or update its health bar.")
		quit(1)
		return
	if weapon_controller.weapon_sprite.visible:
		push_error("Mob smoke test: equipped sword was not hidden during its attack.")
		quit(1)
		return
	if ability_controller.try_cast(player.global_position, Vector2.RIGHT):
		push_error("Mob smoke test: ability cooldown did not prevent an immediate second cast.")
		quit(1)
		return
	await create_timer(weapon_controller.attack_hide_time + 0.05).timeout
	if not weapon_controller.weapon_sprite.visible:
		push_error("Mob smoke test: equipped sword did not return after its attack.")
		quit(1)
		return
	for power_index in ability_controller.power_library.size():
		if ability_controller.power_library[power_index].effect_scene == null:
			push_error("Mob smoke test: library power %d has no effect scene." % (power_index + 1))
			quit(1)
			return
	if not ability_controller.equip_power(1, ability_controller.power_library[2]):
		push_error("Mob smoke test: a library power could not be equipped to a power slot.")
		quit(1)
		return
	if game_state.equipped_power_ids[1] != String(ability_controller.power_library[2].ability_id):
		push_error("Mob smoke test: equipped power selection was not stored for saving.")
		quit(1)
		return
	var power_list_ui := world.get_node("Inventory/PowerPanel/PowerScroll/PowerList") as VBoxContainer
	if power_list_ui.get_child_count() != ability_controller.power_library.size():
		push_error("Mob smoke test: inventory power loadout did not show every available power.")
		quit(1)
		return
	orc.global_position = player.global_position + Vector2(400, 0)
	ability_controller.equip_power(0, ability_controller.power_library[0])
	if not ability_controller.try_cast_power(0, player.global_position, Vector2.RIGHT):
		push_error("Mob smoke test: Ember Nova could not be cast.")
		quit(1)
		return
	await process_frame
	var ember_effect := root.find_child("EmberNova", true, false) as PowerEffect
	if ember_effect == null or ember_effect.get_child_count() < 2:
		push_error("Mob smoke test: shader/particle power effect did not instantiate correctly.")
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

	var food_ids := ["apple", "bread", "cheese", "cooked_meat", "chicken_leg", "soup", "salad", "berry_pie", "mushroom_stew", "honey_cake"]
	for food_id in food_ids:
		var food_path := "res://data/items/food/%s.tres" % food_id
		var food := load(food_path) as FoodDefinition
		if food == null or food.icon == null or food.icon.get_size() != Vector2(64, 64):
			push_error("Mob smoke test: food asset is invalid or not 64x64 at %s." % food_path)
			quit(1)
			return
		if food.buy_price <= 0 or food.sell_price < 0 or food.sell_price >= food.buy_price or food.max_stack <= 0:
			push_error("Mob smoke test: food economy/stack stats are invalid at %s." % food_path)
			quit(1)
			return
	game_state.hp = 1
	game_state.stamina = 1
	game_state.hunger = 1
	var honey_cake := load("res://data/items/food/honey_cake.tres") as FoodDefinition
	if not honey_cake.use() or game_state.hp <= 1 or game_state.stamina <= 1 or game_state.hunger <= 1:
		push_error("Mob smoke test: consuming food did not apply its immediate stats.")
		quit(1)
		return
	if game_state.get_food_buff_total(game_state.FOOD_BUFF_ATTACK) != honey_cake.buff_value:
		push_error("Mob smoke test: consuming food did not activate its temporary buff.")
		quit(1)
		return
	var potion_ids := ["health_potion", "mana_potion", "stamina_potion", "grand_elixir"]
	for potion_id in potion_ids:
		var potion_path := "res://data/items/potions/%s.tres" % potion_id
		var potion := load(potion_path) as PotionDefinition
		if potion == null or potion.icon == null or potion.icon.get_size() != Vector2(64, 64):
			push_error("Mob smoke test: potion asset is invalid or not 64x64 at %s." % potion_path)
			quit(1)
			return
		if potion.buy_price <= potion.sell_price or potion.max_stack <= 0 or potion.cooldown <= 0.0:
			push_error("Mob smoke test: potion economy/use stats are invalid at %s." % potion_path)
			quit(1)
			return
	game_state.potion_cooldowns.clear()
	game_state.hp = 1
	var health_potion := load("res://data/items/potions/health_potion.tres") as PotionDefinition
	if not health_potion.use(game_state) or game_state.hp != 41:
		push_error("Mob smoke test: health potion did not restore its configured health.")
		quit(1)
		return
	if health_potion.use(game_state):
		push_error("Mob smoke test: potion cooldown did not block immediate reuse.")
		quit(1)
		return

	print("Mob smoke test passed: combat, environment, 16 swords, 10 foods, and 4 potions work.")
	quit(0)

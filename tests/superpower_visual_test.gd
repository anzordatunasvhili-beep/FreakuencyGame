extends SceneTree
## Run with a real rendering driver to validate shaders/particles and save captures.
## godot --path . --rendering-method gl_compatibility --script tests/superpower_visual_test.gd

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	current_scene = world
	for frame in 8:
		await physics_frame
	var player := world.get_node("Player")
	player.can_move = false
	player.get_node("Camera2D").zoom = Vector2(2.0, 2.0)
	for mob in get_nodes_in_group("mobs"):
		mob.set_physics_process(false)
	var controller := player.get_node("AbilityController") as AbilityController
	DirAccess.make_dir_recursive_absolute("res://tmp")
	for kind in ["event_horizon", "astral_lance", "chronostasis"]:
		var ability := load("res://data/abilities/%s.tres" % kind) as AbilityDefinition
		controller.equip_power(0, ability)
		assert(controller.try_cast_power(0, player.global_position, Vector2(1.0, 0.25)), "Power could not cast")
		await create_timer(ability.charge_duration * 0.55).timeout
		await _capture(kind + "_charge")
		await create_timer(ability.charge_duration * 0.45 + 0.12).timeout
		await _capture(kind + "_active")
		await create_timer(maxf(0.0, ability.sustain_duration - 0.12) + ability.release_duration * 0.2).timeout
		await _capture(kind + "_release")
		await create_timer(ability.release_duration + 1.05).timeout
		for child in world.get_children():
			assert(not child is SuperpowerEffect, "Power leaked beyond its particle tail")
	var inventory := world.get_node("Inventory")
	inventory._refresh()
	inventory.show()
	await _capture("power_loadout")
	var panel := inventory.get_node("PowerPanel") as Control
	var items := inventory.get_node("ScrollContainer") as Control
	assert(panel.get_global_rect().position.y < 40.0, "Power loadout is clipped below the screen")
	assert(items.get_global_rect().position.x >= 0.0, "Inventory item names expanded the grid outside the screen")
	assert(items.get_global_rect().end.x <= panel.get_global_rect().position.x, "Items overlap the power loadout")
	if DisplayServer.get_name() == "headless":
		print("Superpower VFX lifecycle test passed: all three effects instantiated and cleaned up.")
	else:
		print("Superpower visual test passed: all three effects rendered and cleaned up. Captures: res://tmp/*_active.png")
	quit(0)

func _capture(filename: String) -> void:
	await process_frame
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var capture := root.get_texture().get_image()
	assert(capture.save_png("res://tmp/" + filename + ".png") == OK)

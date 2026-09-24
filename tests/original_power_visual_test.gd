extends SceneTree
## Run with a rendering driver to capture the six original powers in the world.

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
	player.get_node("Camera2D").zoom = Vector2(1.6, 1.6)
	var mobs := get_nodes_in_group("mobs")
	for index in mobs.size():
		var mob := mobs[index] as Mob
		mob.set_physics_process(false)
		mob.health = 500
		mob.health_bar.hide()
		mob.global_position = player.global_position + Vector2(500 + index * 10, 0)
	for index in mini(4, mobs.size()):
		mobs[index].global_position = player.global_position + [Vector2(50, 0), Vector2(100, 22), Vector2(151, 7), Vector2(203, -10)][index]
	var controller := player.get_node("AbilityController") as AbilityController
	DirAccess.make_dir_recursive_absolute("res://tmp")
	var only := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			only = argument.trim_prefix("--only=")
	for id in ["ember_nova", "arc_storm", "void_bloom", "glacial_halo", "solar_spear", "spirit_pulse"]:
		if not only.is_empty() and id != only:
			continue
		var ability := load("res://data/abilities/%s.tres" % id) as AbilityDefinition
		controller.equip_power(0, ability)
		assert(controller.try_cast_power(0, player.global_position, Vector2.RIGHT), "Original power could not cast: " + id)
		await create_timer(0.65 if id == "ember_nova" else (0.56 if id == "solar_spear" else 0.52)).timeout
		await _capture(id)
		var sample := ability.effect_scene.instantiate() as PowerEffect
		var lifetime := sample.duration
		sample.free()
		await create_timer(lifetime + 0.75).timeout
		for child in world.get_children():
			assert(not child is PowerEffect, "Original power effect leaked")
	if DisplayServer.get_name() == "headless":
		print("Original power VFX lifecycle test passed.")
	else:
		print("Original power visual test passed. Captures: res://tmp/legacy_*.png")
	quit(0)

func _capture(id: String) -> void:
	await process_frame
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://tmp/legacy_" + id + ".png") == OK)

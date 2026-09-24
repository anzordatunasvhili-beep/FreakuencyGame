extends SceneTree
## Loads the actual overworld, verifies dry village sites, and captures its
## initial camera view plus a wider view of the complete building collection.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 800)
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	current_scene = world
	for frame in 7:
		await physics_frame

	var ground := world.get_node("Node2D/TileMapLayer") as TileMapLayer
	var player := world.get_node("Player")
	var trees := world.get_node("VillageTrees") as Node2D
	assert(trees != null and trees.get_child_count() > 0, "Village needs trees around its buildings")
	var building_count := 0
	for child in world.get_children():
		if child is not VillageBuilding:
			continue
		building_count += 1
		var tile := ground.local_to_map(ground.to_local(child.global_position))
		assert(ground.get_cell_atlas_coords(tile) not in ProceduralWorld.WATER_TILES, "Building is on water")
		assert(VillagePlacement.blocks_spawn(ground, world, child.position), "Building footprints must reject saved spawn positions")
	assert(building_count == 5, "Expected all five modular building styles")
	var first_tree := trees.get_child(0) as VillageTree
	assert(VillagePlacement.blocks_spawn(ground, world, world.to_local(first_tree.global_position)), "Tree trunks must reject saved spawn positions")
	assert(not VillagePlacement.blocks_spawn(ground, world, Vector2.ZERO), "Village center must remain a safe spawn")

	player.can_move = false
	player.global_position = ground.to_global(ground.map_to_local(Vector2i.ZERO))
	var camera := player.get_node("Camera2D") as Camera2D
	camera.position = Vector2.ZERO
	await create_timer(0.15).timeout
	await _capture("village_default")
	camera.zoom = Vector2(1.65, 1.65)
	await create_timer(0.15).timeout
	await _capture("village_overview")
	print("Village visual test passed: %d modular buildings and %d scattered trees." % [building_count, trees.get_child_count()])
	quit(0)


func _capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://tmp/" + filename + ".png") == OK)

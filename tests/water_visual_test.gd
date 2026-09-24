extends SceneTree
## Checks the generated shore mask and captures two animation frames in-game.

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
	var water := ground.get_node("WaterSurface") as WaterSurface
	assert(water != null and water.water_cell_count > 0 and water.mask_texture != null)
	var mask := water.mask_texture.get_image()
	var has_shore := false
	var has_depth := false
	for y in mask.get_height():
		for x in mask.get_width():
			var pixel := mask.get_pixel(x, y)
			if pixel.r > 0.5 and pixel.g < 0.15:
				has_shore = true
			if pixel.r > 0.9 and pixel.g > 0.85:
				has_depth = true
	assert(has_shore and has_depth, "Water mask must have both a shore and a deep interior")
	for coordinates in ProceduralWorld.WATER_TILES:
		var atlas := ground.tile_set.get_source(ProceduralWorld.SOURCE_ID) as TileSetAtlasSource
		assert(atlas.get_tile_data(coordinates, 0).modulate.a == 0.0, "Old water tile art remains visible")
	var player := world.get_node("Player")
	player.can_move = false
	var camera := player.get_node("Camera2D") as Camera2D
	camera.zoom = Vector2(2.2, 2.2)
	var best := Vector2.ZERO
	var best_distance := INF
	for cell in ground.get_used_cells():
		if ground.get_cell_atlas_coords(cell) not in ProceduralWorld.WATER_TILES:
			continue
		var water_neighbors := 0
		var land_neighbors := 0
		for offset in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			if ground.get_cell_atlas_coords(cell + offset) in ProceduralWorld.WATER_TILES:
				water_neighbors += 1
			else:
				land_neighbors += 1
		if water_neighbors < 2 or land_neighbors == 0:
			continue
		var local := ground.map_to_local(cell)
		if local.length_squared() < best_distance:
			best_distance = local.length_squared()
			best = local
	assert(best_distance < INF, "No suitable shoreline found")
	camera.position = ground.to_global(best) - player.global_position
	await create_timer(0.15).timeout
	await _capture("water_foam_a")
	await create_timer(1.15).timeout
	await _capture("water_foam_b")
	print("Water visual test passed: %d water cells, %s mask, shoreline and deep water present." % [water.water_cell_count, water.mask_size])
	quit(0)

func _capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://tmp/" + filename + ".png") == OK)

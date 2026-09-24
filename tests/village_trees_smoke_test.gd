extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	assert(main_scene != null)
	var template := main_scene.instantiate()
	var template_ground := template.get_node("Node2D/TileMapLayer") as TileMapLayer
	var stage := Node2D.new()
	root.add_child(stage)
	var ground := TileMapLayer.new()
	ground.tile_set = template_ground.tile_set
	template.free()
	stage.add_child(ground)
	var details := TileMapLayer.new()
	stage.add_child(details)
	ProceduralWorld.generate_overworld(ground, details, 8237, Vector2i(40, 40))

	var reserved: Dictionary = {}
	for y in range(-5, 6):
		for x in range(-5, 6):
			reserved[Vector2i(x, y)] = true
	var grove := VillageTrees.scatter(ground, stage, 8237, reserved)
	assert(grove.get_child_count() > 0)
	var planted: Dictionary = {}
	for child in grove.get_children():
		var tree := child as VillageTree
		assert(tree != null)
		var cell := ground.local_to_map(ground.to_local(tree.global_position))
		assert(not (ground.get_cell_atlas_coords(cell) in ProceduralWorld.WATER_TILES))
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				assert(not reserved.has(cell + Vector2i(dx, dy)))
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				assert(not planted.has(cell + Vector2i(dx, dy)))
		planted[cell] = true
	print("Village tree placement smoke test passed: ", grove.get_child_count(), " trees")
	stage.queue_free()
	await process_frame
	quit(0)

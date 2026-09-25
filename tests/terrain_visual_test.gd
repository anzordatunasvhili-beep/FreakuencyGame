extends SceneTree
## Render the actual pixel tiles, village, and a block plateau at the base,
## ramp and summit. Run with a rendering driver; images go to res://tmp/.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 800)
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(world)
	current_scene = world
	for frame in 10:
		await physics_frame
	var ground := world.get_node("Node2D/TileMapLayer") as TileMapLayer
	var surface := ground.get_node_or_null("TerrainSurface") as Node2D
	if surface == null or surface.get("hills").is_empty():
		push_error("Terrain visual test: expected the actual overworld terrain and hills")
		quit(1)
		return
	var player := world.get_node("Player") as CharacterBody2D
	player.set("can_move", false)
	for mob in get_nodes_in_group("mobs"):
		mob.set_physics_process(false)
	_hide_interface(world)
	var agent := player.get_node("NavigationAgent2D") as NavigationAgent2D
	agent.debug_enabled = false
	var camera := player.get_node("Camera2D") as Camera2D
	camera.position_smoothing_enabled = false
	camera.drag_horizontal_enabled = false
	camera.drag_vertical_enabled = false
	camera.offset = Vector2.ZERO
	camera.position = Vector2.ZERO
	camera.zoom = Vector2(1.65, 1.65)
	player.global_position = ground.to_global(ground.map_to_local(Vector2i.ZERO))
	camera.reset_smoothing()
	camera.force_update_scroll()
	await _capture("terrain_village")
	camera.zoom = Vector2(4.0, 4.0)
	camera.global_position = ground.to_global(Vector2(70, 55))
	camera.force_update_scroll()
	await _capture("terrain_tiles")

	var selected: Dictionary = surface.get("hills")[0]
	for hill: Dictionary in surface.get("hills"):
		if float(hill["height"]) > float(selected["height"]):
			selected = hill
	var center: Vector2 = selected["center"]
	var summit := ground.to_global(surface.call("ground_to_surface", center))
	var base_ground: Vector2 = selected["ramp_base"]
	var base := ground.to_global(surface.call("ground_to_surface", base_ground))
	var ramp_ground := base_ground.lerp(selected["ramp_top"], 0.5)
	var ramp := ground.to_global(surface.call("ground_to_surface", ramp_ground))
	var focus := ground.to_global(center - Vector2(0, float(selected["height"]) * 0.3))
	camera.zoom = Vector2(2.2, 2.2)
	player.global_position = base
	camera.global_position = focus
	camera.reset_smoothing()
	camera.force_update_scroll()
	await _capture("terrain_hill_base")
	player.global_position = ramp
	camera.global_position = focus
	camera.reset_smoothing()
	camera.force_update_scroll()
	await _capture("terrain_hill_ramp")
	player.global_position = summit
	camera.global_position = focus
	camera.reset_smoothing()
	camera.force_update_scroll()
	await _capture("terrain_hill_summit")
	var grove := world.get_node("VillageTrees") as Node2D
	if grove.get_child_count() > 0:
		var tree := grove.get_child(0) as VillageTree
		camera.zoom = Vector2(4.0, 4.0)
		var tree_focus := tree.global_position - Vector2(0, 34)
		player.global_position = tree.global_position + Vector2(12, -14)
		camera.global_position = tree_focus
		camera.force_update_scroll()
		await _capture("terrain_tree_behind")
		player.global_position = tree.global_position + Vector2(12, 14)
		camera.global_position = tree_focus
		camera.force_update_scroll()
		await _capture("terrain_tree_front")
	if DisplayServer.get_name() == "headless":
		print("Terrain visual setup passed (headless; captures skipped).")
	else:
		print("Terrain visual test passed: original pixel tiles, village, %.1f px block hill base/ramp/summit and tree front/behind captures saved to res://tmp/terrain_*.png." % float(selected["height"]))
	quit(0)


func _hide_interface(node: Node) -> void:
	if node is CanvasLayer:
		node.hide()
	elif node is Control:
		node.hide()
	for child in node.get_children():
		_hide_interface(child)


func _capture(filename: String) -> void:
	for frame in 3:
		await physics_frame
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://tmp")
	var result := root.get_texture().get_image().save_png("res://tmp/" + filename + ".png")
	if result != OK:
		push_error("Terrain visual test: could not save " + filename)
		quit(1)

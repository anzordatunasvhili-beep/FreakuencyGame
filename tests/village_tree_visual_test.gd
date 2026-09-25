extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 960)
	root.content_scale_size = root.size
	var tree_scene := load("res://scenes/village_tree.tscn") as PackedScene
	assert(tree_scene != null)
	var stage := Node2D.new()
	root.add_child(stage)
	var background := ColorRect.new()
	background.color = Color("#a2ad87")
	background.size = Vector2(root.size)
	stage.add_child(background)
	for i in VillageTree.VARIANT_COUNT:
		var tree := tree_scene.instantiate() as VillageTree
		assert(tree != null)
		tree.variant = i
		tree.variation_seed = i + 3
		tree.crown_scale = 1.0
		tree.position = Vector2(155 + (i % 4) * 315, 220 + (i / 4) * 225)
		stage.add_child(tree)
		assert(tree.get_node("TrunkBody/CollisionShape2D") != null)
		assert(tree.sprite != null and tree.sprite.texture is AtlasTexture)
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		var screenshot := root.get_viewport().get_texture().get_image()
		var save_path := ProjectSettings.globalize_path("res://tmp/village_trees.png")
		assert(screenshot.save_png(save_path) == OK)
	print("Village tree visual test passed")
	quit(0)

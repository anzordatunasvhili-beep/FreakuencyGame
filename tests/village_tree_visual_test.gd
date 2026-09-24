extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var tree_scene := load("res://scenes/village_tree.tscn") as PackedScene
	assert(tree_scene != null)
	var stage := Node2D.new()
	root.add_child(stage)
	var background := ColorRect.new()
	background.color = Color("#a2ad87")
	background.size = Vector2(900, 350)
	stage.add_child(background)
	for i in range(3):
		var tree := tree_scene.instantiate() as VillageTree
		assert(tree != null)
		tree.form = i as VillageTree.Form
		tree.variation_seed = i + 3
		tree.position = Vector2(170 + i * 275, 265)
		stage.add_child(tree)
		assert(tree.get_node("TrunkBody/CollisionShape2D") != null)
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		var screenshot := root.get_viewport().get_texture().get_image()
		var save_path := ProjectSettings.globalize_path("res://tmp/village_trees.png")
		assert(screenshot.save_png(save_path) == OK)
	print("Village tree visual test passed")
	quit(0)

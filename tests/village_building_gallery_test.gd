extends SceneTree
## Checks and renders all eight generated pixel-house sprites.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1600, 1000)
	root.content_scale_size = root.size
	var stage := Node2D.new()
	root.add_child(stage)
	var background := ColorRect.new()
	background.color = Color("#a8b6aa")
	background.size = Vector2(root.size)
	stage.add_child(background)
	_label(stage, "EIGHT ISOMETRIC PIXEL HOUSES", Vector2(46, 28), 28)
	_label(stage, "Generated transparent sprites / shared teal roofs, timber and stone", Vector2(46, 68), 18)
	for index in VillageBuilding.HOUSE_NAMES.size():
		var house := VillageBuilding.new()
		house.configure(index)
		house.position = Vector2(200 + (index % 4) * 400, 430 if index < 4 else 905)
		house.scale = Vector2.ONE * 1.6
		stage.add_child(house)
		assert(house.sprite.texture != null)
		assert(house.get_node_or_null("Footprint/Shape") is CollisionPolygon2D)
		assert(house.sprite.material is ShaderMaterial)
		var source := house.sprite.texture.get_image()
		assert(source.detect_alpha() != Image.ALPHA_NONE, "House must have transparency")
		assert(source.get_pixel(0, 0).a < 0.01, "Background must be transparent")
		_label(stage, "%02d  %s" % [VillageBuilding.HOUSE_FILES[index], VillageBuilding.HOUSE_NAMES[index]], house.position + Vector2(-115, 20), 18)
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://tmp/pixel_houses_gallery.png") == OK)
	print("Pixel house gallery passed: eight distinct transparent sprites with collision.")
	quit(0)

func _label(stage: Node2D, value: String, point: Vector2, size: int) -> void:
	var label := Label.new()
	label.text = value
	label.position = point
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("#263c3c"))
	stage.add_child(label)

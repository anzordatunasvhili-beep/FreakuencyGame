extends SceneTree
## Renders every village building preset and two independently mixed recipes.

const GALLERY_SIZE := Vector2i(1400, 900)
const COLUMN_X := [205.0, 535.0, 865.0, 1195.0]
const UPPER_Y := 390.0
const LOWER_Y := 785.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = GALLERY_SIZE
	root.content_scale_size = GALLERY_SIZE
	var stage := Node2D.new()
	root.add_child(stage)

	var background := ColorRect.new()
	background.color = Color("#a8b6aa")
	background.size = GALLERY_SIZE
	stage.add_child(background)
	_add_label(stage, "ISOMETRIC VILLAGE BUILDING KIT", Vector2(44, 28), 28, Color("#263c3c"))
	_add_label(stage, "Five presets  /  three roof shapes  /  two custom recipes", Vector2(46, 67), 17, Color("#405a54"))

	var names := ["Cottage · gable", "Inn · cross-gable", "Shop · hip", "Tall house · gable", "Hall · hip"]
	for index in 5:
		var x: float = COLUMN_X[index % 4]
		var y := UPPER_Y if index < 4 else LOWER_Y
		_add_lot(stage, Vector2(x, y))
		var building := VillageBuilding.new()
		building.name = "Preset%d" % index
		building.configure(index, 17 + index * 11)
		building.position = Vector2(x, y)
		stage.add_child(building)
		assert(building.get_node_or_null("Footprint") is StaticBody2D)
		_add_label(stage, names[index], Vector2(x - 105, y + 25), 18, Color("#263c3c"))

	var workshop := VillageBuildingRecipe.new()
	workshop.stories = 1
	workshop.roof_shape = VillageBuildingRecipe.RoofShape.CROSS_GABLE
	workshop.entry_style = VillageBuildingRecipe.EntryStyle.SHOP
	workshop.dormers = 0
	workshop.chimney = true
	workshop.roof_color = Color("#557f90")
	workshop.accent_color = Color("#e3b97c")
	_add_custom(stage, workshop, Vector2(COLUMN_X[1], LOWER_Y), "Workshop · cross-gable", 61)

	var guesthouse := VillageBuildingRecipe.new()
	guesthouse.stories = 3
	guesthouse.roof_shape = VillageBuildingRecipe.RoofShape.HIP
	guesthouse.entry_style = VillageBuildingRecipe.EntryStyle.PORCH
	guesthouse.dormers = 2
	guesthouse.balcony = true
	guesthouse.chimney = false
	guesthouse.roof_color = Color("#796f70")
	guesthouse.plaster_color = Color("#ebd6ba")
	guesthouse.timber_color = Color("#704a39")
	_add_custom(stage, guesthouse, Vector2(COLUMN_X[2], LOWER_Y), "Guesthouse · hip", 92)

	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var screenshot := root.get_texture().get_image()
		assert(screenshot.save_png(ProjectSettings.globalize_path("res://tmp/village_building_gallery.png")) == OK)
	print("Village building gallery passed: 5 presets and 2 custom recipes")
	quit(0)


func _add_custom(stage: Node2D, parts: VillageBuildingRecipe, origin: Vector2, caption: String, seed: int) -> void:
	_add_lot(stage, origin)
	var building := VillageBuilding.new()
	building.name = "Custom%d" % seed
	building.apply_recipe(parts, seed)
	building.position = origin
	stage.add_child(building)
	assert(building.recipe == parts)
	assert(building.get_node_or_null("Footprint") is StaticBody2D)
	_add_label(stage, caption, origin + Vector2(-105, 25), 18, Color("#263c3c"))


func _add_lot(stage: Node2D, origin: Vector2) -> void:
	var lot := Polygon2D.new()
	lot.position = origin
	lot.polygon = PackedVector2Array([Vector2(0, -78), Vector2(96, -39), Vector2(0, 17), Vector2(-96, -39)])
	lot.color = Color("#c3beaa")
	stage.add_child(lot)
	var edge := Line2D.new()
	edge.position = origin
	edge.points = PackedVector2Array([Vector2(0, -78), Vector2(96, -39), Vector2(0, 17), Vector2(-96, -39), Vector2(0, -78)])
	edge.width = 2.0
	edge.default_color = Color("#8e9989")
	stage.add_child(edge)


func _add_label(stage: Node2D, value: String, origin: Vector2, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = value
	label.position = origin
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	stage.add_child(label)

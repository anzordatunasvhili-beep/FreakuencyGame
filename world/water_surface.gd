class_name WaterSurface
extends Polygon2D
## A single continuous surface over the generated isometric water cells.
## The ground keeps its atlas IDs for navigation and spawning; only its artwork
## is hidden. R in the generated mask is water coverage and G is shore depth.

const WATER_SHADER := preload("res://assets/world/shaders/stylized_water.gdshader")
const SAMPLE_STEP := 2.0
const HALF_TILE := Vector2(16.0, 8.0)

var water_cell_count := 0
var mask_size := Vector2i.ZERO
var mask_texture: ImageTexture

func build_from_map(ground: TileMapLayer) -> void:
	var water_cells: Array[Vector2i] = []
	var min_corner := Vector2(INF, INF)
	var max_corner := Vector2(-INF, -INF)
	for cell in ground.get_used_cells():
		if ground.get_cell_atlas_coords(cell) not in ProceduralWorld.WATER_TILES:
			continue
		water_cells.append(cell)
		var center := ground.map_to_local(cell)
		min_corner = min_corner.min(center - HALF_TILE)
		max_corner = max_corner.max(center + HALF_TILE)
	water_cell_count = water_cells.size()
	if water_cells.is_empty():
		hide()
		return
	# The pad keeps the outer antialiased edge inside the texture sampler.
	min_corner -= Vector2.ONE * SAMPLE_STEP
	max_corner += Vector2.ONE * SAMPLE_STEP
	mask_size = Vector2i(ceili((max_corner.x - min_corner.x) / SAMPLE_STEP), ceili((max_corner.y - min_corner.y) / SAMPLE_STEP))
	var mask_bytes := PackedByteArray()
	mask_bytes.resize(mask_size.x * mask_size.y * 4)
	for cell in water_cells:
		_rasterize_diamond(mask_bytes, ground.map_to_local(cell), min_corner)
	_write_depth(mask_bytes)
	var image := Image.create_from_data(mask_size.x, mask_size.y, false, Image.FORMAT_RGBA8, mask_bytes)
	mask_texture = ImageTexture.create_from_image(image)
	var world_size := Vector2(mask_size) * SAMPLE_STEP
	polygon = PackedVector2Array([min_corner, min_corner + Vector2(world_size.x, 0.0), min_corner + world_size, min_corner + Vector2(0.0, world_size.y)])
	uv = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN])
	# A white 1×1 texture keeps Polygon2D UVs normalized; the mask is sampled
	# explicitly by the shader and never inherits pixel-art filtering.
	var white := GradientTexture2D.new()
	white.width = 1
	white.height = 1
	white.gradient = Gradient.new()
	white.gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE])
	texture = white
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var shader_material := ShaderMaterial.new()
	shader_material.shader = WATER_SHADER
	shader_material.set_shader_parameter("mask_texture", mask_texture)
	shader_material.set_shader_parameter("water_world_size", world_size)
	material = shader_material
	_hide_atlas_water_art(ground)

func _rasterize_diamond(bytes: PackedByteArray, center: Vector2, min_corner: Vector2) -> void:
	var left := maxi(0, floori((center.x - HALF_TILE.x - min_corner.x) / SAMPLE_STEP) - 1)
	var right := mini(mask_size.x - 1, ceili((center.x + HALF_TILE.x - min_corner.x) / SAMPLE_STEP) + 1)
	var top := maxi(0, floori((center.y - HALF_TILE.y - min_corner.y) / SAMPLE_STEP) - 1)
	var bottom := mini(mask_size.y - 1, ceili((center.y + HALF_TILE.y - min_corner.y) / SAMPLE_STEP) + 1)
	for y in range(top, bottom + 1):
		var world_y := min_corner.y + (float(y) + 0.5) * SAMPLE_STEP
		for x in range(left, right + 1):
			var world_x := min_corner.x + (float(x) + 0.5) * SAMPLE_STEP
			var diamond_distance := absf(world_x - center.x) / HALF_TILE.x + absf(world_y - center.y) / HALF_TILE.y
			var coverage := clampf((1.0 - diamond_distance) * 8.0 + 0.5, 0.0, 1.0)
			if coverage <= 0.0:
				continue
			var offset := (y * mask_size.x + x) * 4
			# Adding coverage closes shared diamond edges without dark seams.
			bytes[offset] = mini(255, int(bytes[offset]) + roundi(coverage * 255.0))

func _write_depth(bytes: PackedByteArray) -> void:
	var width := mask_size.x
	var height := mask_size.y
	var distances := PackedInt32Array()
	distances.resize(width * height)
	distances.fill(1_000_000)
	for y in height:
		for x in width:
			var index := y * width + x
			if bytes[index * 4] < 128:
				distances[index] = 0
				continue
			var nearest := distances[index]
			if x > 0:
				nearest = mini(nearest, distances[index - 1] + 3)
			if y > 0:
				nearest = mini(nearest, distances[index - width] + 3)
				if x > 0:
					nearest = mini(nearest, distances[index - width - 1] + 4)
				if x + 1 < width:
					nearest = mini(nearest, distances[index - width + 1] + 4)
			distances[index] = nearest
	for y in range(height - 1, -1, -1):
		for x in range(width - 1, -1, -1):
			var index := y * width + x
			var nearest := distances[index]
			if x + 1 < width:
				nearest = mini(nearest, distances[index + 1] + 3)
			if y + 1 < height:
				nearest = mini(nearest, distances[index + width] + 3)
				if x > 0:
					nearest = mini(nearest, distances[index + width - 1] + 4)
				if x + 1 < width:
					nearest = mini(nearest, distances[index + width + 1] + 4)
			distances[index] = nearest
			bytes[index * 4 + 1] = clampi(roundi(float(nearest) / 48.0 * 255.0), 0, 255)
			bytes[index * 4 + 3] = 255

func _hide_atlas_water_art(ground: TileMapLayer) -> void:
	var atlas := ground.tile_set.get_source(ProceduralWorld.SOURCE_ID) as TileSetAtlasSource
	if atlas == null:
		return
	for coordinates in ProceduralWorld.WATER_TILES:
		var tile_data := atlas.get_tile_data(coordinates, 0)
		if tile_data != null:
			tile_data.modulate = Color.TRANSPARENT

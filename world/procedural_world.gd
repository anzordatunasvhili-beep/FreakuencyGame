class_name ProceduralWorld
extends RefCounted

const SOURCE_ID := 0
# Only clean surface cells belong here. Atlas transitions, rocks, plants, and
# cliffs will be placed on separate layers when those generators are added.
const WATER_TILE := Vector2i(3, 8)
const GRASS_TILES: Array[Vector2i] = [
	Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)
]
const DIRT_TILES: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)
]

static func generate_overworld(tile_map: TileMapLayer, world_seed: int, size: Vector2i) -> void:
	tile_map.clear()

	var elevation := FastNoiseLite.new()
	elevation.seed = world_seed
	elevation.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	elevation.frequency = 0.045
	elevation.fractal_octaves = 4

	var moisture := FastNoiseLite.new()
	moisture.seed = world_seed + 10_007
	moisture.noise_type = FastNoiseLite.TYPE_SIMPLEX
	moisture.frequency = 0.075

	var half := size / 2
	for y in range(-half.y, half.y):
		for x in range(-half.x, half.x):
			var cell := Vector2i(x, y)
			var edge := maxf(absf(float(x) / half.x), absf(float(y) / half.y))
			var elevation_value := elevation.get_noise_2d(x, y) - maxf(0.0, edge - 0.72) * 1.8
			var moisture_value := moisture.get_noise_2d(x, y)
			var tile: Vector2i

			# Keep the player and first NPC on a guaranteed navigable clearing.
			if cell.length_squared() <= 100:
				tile = _pick_tile(GRASS_TILES, world_seed, cell)
			elif elevation_value < -0.34:
				tile = WATER_TILE
			elif moisture_value > 0.18:
				tile = _pick_tile(GRASS_TILES, world_seed, cell)
			else:
				tile = _pick_tile(DIRT_TILES, world_seed, cell)

			tile_map.set_cell(cell, SOURCE_ID, tile, 0)

static func _pick_tile(tiles: Array[Vector2i], world_seed: int, cell: Vector2i) -> Vector2i:
	var mixed := world_seed
	mixed = int((mixed ^ (cell.x * 73_856_093)) & 0x7fffffff)
	mixed = int((mixed ^ (cell.y * 19_349_663)) & 0x7fffffff)
	return tiles[mixed % tiles.size()]

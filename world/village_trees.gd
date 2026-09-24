class_name VillageTrees
extends RefCounted

const TREE_SCENE: PackedScene = preload("res://scenes/village_tree.tscn")


## Scatter deterministic groves over generated ground. blocked_cells is the
## village placement's cell dictionary; a one-cell buffer surrounds each key.
static func scatter(ground: TileMapLayer, parent: Node2D, world_seed: int, blocked_cells: Dictionary = {}) -> Node2D:
	var grove := Node2D.new()
	grove.name = "VillageTrees"
	grove.y_sort_enabled = true
	parent.add_child(grove)

	var woodland := FastNoiseLite.new()
	woodland.seed = world_seed + 4021
	woodland.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	woodland.frequency = 0.065
	var occupied: Dictionary = {}
	var used := ground.get_used_rect()
	for y in range(used.position.y, used.end.y):
		for x in range(used.position.x, used.end.x):
			var cell := Vector2i(x, y)
			if not _can_plant(ground, cell, blocked_cells, occupied):
				continue
			var grass := ground.get_cell_atlas_coords(cell) in ProceduralWorld.GRASS_TILES
			var forest_noise := woodland.get_noise_2d(x, y)
			var chance := 45 if forest_noise > 0.11 else 7
			if not grass:
				chance = int(chance * 0.55)
			var mixed := _hash(world_seed, cell)
			if mixed % 1000 >= chance:
				continue
			var tree := TREE_SCENE.instantiate() as VillageTree
			tree.variation_seed = _hash(world_seed + 173, cell)
			tree.form = tree.variation_seed % VillageTree.Form.size()
			tree.crown_scale = 0.82 + float(tree.variation_seed % 9) * 0.045
			grove.add_child(tree)
			tree.position = grove.to_local(ground.to_global(ground.map_to_local(cell)))
			occupied[cell] = true
	return grove


static func _can_plant(ground: TileMapLayer, cell: Vector2i, blocked_cells: Dictionary, occupied: Dictionary) -> bool:
	if ground.get_cell_source_id(cell) < 0:
		return false
	if ground.get_cell_atlas_coords(cell) in ProceduralWorld.WATER_TILES:
		return false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if blocked_cells.has(cell + Vector2i(dx, dy)):
				return false
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if occupied.has(cell + Vector2i(dx, dy)):
				return false
	return true


static func _hash(world_seed: int, cell: Vector2i) -> int:
	return int((world_seed ^ (cell.x * 73_856_093) ^ (cell.y * 19_349_663)) & 0x7fffffff)

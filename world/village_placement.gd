class_name VillagePlacement
extends RefCounted

## Screen-space anchors make the town composition deliberate even though its
## ground is made from isometric map cells. A building's origin is its base.
const BUILDING_ANCHORS: Array[Vector2] = [
	Vector2(-240.0, -85.0),
	Vector2(0.0, -65.0),
	Vector2(240.0, -85.0),
	Vector2(-165.0, 125.0),
	Vector2(165.0, 125.0),
]
const PLAZA_RADIUS := Vector2(47.0, 29.0)
const CLEARING_RADIUS := Vector2(289.0, 166.0)
const PAD_RADIUS := Vector2(78.0, 35.0)
const PATH_HALF_WIDTH := 15.0
const PEDESTRIAN_CENTER := Vector2(20.0, 47.0)
const PEDESTRIAN_RADIUS := Vector2(122.0, 93.0)


## Carve dry, walkable ground before WaterSurface samples the atlas, then place
## one example of every modular building style. Returns cells to keep free of
## scattered trees so roads, entrances, and the square stay open.
static func populate(ground: TileMapLayer, details: TileMapLayer, parent: Node2D, world_seed: int) -> Dictionary:
	var reserved: Dictionary = {}
	var anchors: Array[Vector2] = []
	for desired_anchor in BUILDING_ANCHORS:
		anchors.append(ground.map_to_local(ground.local_to_map(desired_anchor)))

	for cell in ground.get_used_cells():
		var point := ground.map_to_local(cell)
		var in_clearing := _inside_ellipse(point, CLEARING_RADIUS)
		var on_plaza := _inside_ellipse(point, PLAZA_RADIUS)
		var near_people := _inside_ellipse(point - PEDESTRIAN_CENTER, PEDESTRIAN_RADIUS)
		var on_pad := false
		var near_pad := false
		var on_path := false
		for anchor in anchors:
			if absf(point.x - anchor.x) <= PAD_RADIUS.x + 28.0 and absf(point.y - anchor.y) <= PAD_RADIUS.y + 18.0:
				near_pad = true
			if absf(point.x - anchor.x) <= PAD_RADIUS.x and absf(point.y - anchor.y) <= PAD_RADIUS.y:
				on_pad = true
			if _distance_to_segment(point, Vector2.ZERO, anchor) <= PATH_HALF_WIDTH:
				on_path = true
		if not in_clearing and not near_pad and not on_path:
			continue

		# The central clearing can extend past the generator's guaranteed dry
		# radius. Replacing its water first prevents isolated flooded doorsteps.
		var current_tile := ground.get_cell_atlas_coords(cell)
		if on_plaza or on_pad or on_path:
			ground.set_cell(cell, ProceduralWorld.SOURCE_ID, _pick(ProceduralWorld.DIRT_TILES, world_seed + 17, cell))
			details.erase_cell(cell)
		elif current_tile in ProceduralWorld.WATER_TILES:
			ground.set_cell(cell, ProceduralWorld.SOURCE_ID, _pick(ProceduralWorld.GRASS_TILES, world_seed + 31, cell))
			details.erase_cell(cell)

		if near_people or on_plaza or near_pad or on_path:
			reserved[cell] = true

	for index in anchors.size():
		var building := VillageBuilding.new()
		building.name = "VillageBuilding%02d" % (index + 1)
		building.configure(index, world_seed + index * 1009)
		building.position = parent.to_local(ground.to_global(anchors[index]))
		parent.add_child(building)

	return reserved


## Existing saves may put the player inside a new footprint or tree trunk.
## Include the player's small collision radius.
static func blocks_spawn(ground: TileMapLayer, parent: Node2D, local_position: Vector2) -> bool:
	var collision_center := ground.to_local(parent.to_global(local_position + Vector2(0.0, -8.0)))
	for desired_anchor in BUILDING_ANCHORS:
		var anchor := ground.map_to_local(ground.local_to_map(desired_anchor))
		var offset := collision_center - (anchor + Vector2(0.0, -27.0))
		if absf(offset.x) / 72.0 + absf(offset.y) / 36.0 <= 1.0:
			return true
	var trees := parent.get_node_or_null("VillageTrees")
	if trees != null:
		var player_center := parent.to_global(local_position + Vector2(0.0, -8.0))
		for tree in trees.get_children():
			if player_center.distance_to(tree.global_position + Vector2(0.0, -7.0)) < 16.0:
				return true
	return false


static func _inside_ellipse(point: Vector2, radii: Vector2) -> bool:
	var scaled := Vector2(point.x / radii.x, point.y / radii.y)
	return scaled.length_squared() <= 1.0


static func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var line := end - start
	var amount := clampf((point - start).dot(line) / line.length_squared(), 0.0, 1.0)
	return point.distance_to(start + line * amount)


static func _pick(tiles: Array[Vector2i], world_seed: int, cell: Vector2i) -> Vector2i:
	var mixed := (world_seed + cell.x * 73_856_093 + cell.y * 19_349_663) & 0x7fffffff
	return tiles[mixed % tiles.size()]

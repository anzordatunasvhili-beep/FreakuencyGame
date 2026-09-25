class_name TerrainSurface
extends MeshInstance2D
## Atlas tops retain their pixels; only shared edges blend. Block hills have
## solid cliffs and isolated navigation regions connected by walkable ramps.

const GROUND_SHADER := preload("res://assets/world/shaders/blended_ground.gdshader")
const CLIFF_SHADER := preload("res://assets/world/shaders/block_cliff.gdshader")
const CORNERS := [Vector2(0, -8), Vector2(16, 0), Vector2(0, 8), Vector2(-16, 0)]
const NEIGHBORS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const RAMP_LENGTH := 3

var hills: Array[Dictionary] = []
var land_cell_count := 0
var raised_cell_count := 0
var navigation_region: NavigationRegion2D
var _ground: TileMapLayer
var _world: Node2D
var _grid_transform: Transform2D
var _inverse_grid: Transform2D
var _raised_cells: Dictionary = {}
var _raised_art: Node2D
var _cliff_body: StaticBody2D

func build_from_map(ground: TileMapLayer, details: TileMapLayer, reserved: Dictionary, world_seed: int) -> void:
	_ground = ground
	_world = ground.get_parent().get_parent() as Node2D
	ground.set_meta("terrain_surface", self)
	var origin := ground.map_to_local(Vector2i.ZERO)
	_grid_transform = Transform2D(ground.map_to_local(Vector2i.RIGHT) - origin, ground.map_to_local(Vector2i.DOWN) - origin, origin)
	_inverse_grid = _grid_transform.affine_inverse()
	var cells := ground.get_used_cells()
	for cell in cells:
		if _is_land(cell):
			land_cell_count += 1
	_choose_hills(cells, reserved, world_seed)
	_build_material()
	_build_surfaces(cells)
	ground.self_modulate = Color.TRANSPARENT
	ground.navigation_enabled = false
	_place_details(details)

func _choose_hills(cells: Array[Vector2i], reserved: Dictionary, world_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 86_431
	var max_hills := mini(7, maxi(1, land_cell_count / 950))
	for attempt in 1800:
		if hills.size() >= max_hills:
			break
		var cell: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		var center := _ground.map_to_local(cell)
		var radius := 3
		var height := 16.0 if hills.size() % 3 != 2 else 24.0
		var plateau: Array[Vector2i] = []
		var ramps: Array[Vector2i] = []
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if absi(x) == radius and absi(y) == radius:
					continue
				plateau.append(cell + Vector2i(x, y))
		for x in range(radius + 1, radius + RAMP_LENGTH + 1):
			for y in [-1, 0]:
				ramps.append(cell + Vector2i(x, y))
		var footprint: Array[Vector2i] = plateau + ramps
		var safe := true
		for candidate in footprint:
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					var apron := candidate + Vector2i(dx, dy)
					if not _is_land(apron) or reserved.has(apron) or _raised_cells.has(apron) or _ground.map_to_local(apron).length() < 330.0:
						safe = false
						break
				if not safe:
					break
			if not safe:
				break
		if not safe or raised_cell_count + footprint.size() > land_cell_count * 0.085:
			continue
		var hill := {"center": center, "radii": Vector2(128, 64), "height": height, "cell": cell, "radius": radius,
			"cells": footprint, "ramp_cells": ramps,
			"ramp_base": _grid_transform * (Vector2(cell) + Vector2(radius + RAMP_LENGTH + 0.85, -0.5)),
			"ramp_top": _grid_transform * (Vector2(cell) + Vector2(radius - 0.5, -0.5)),
			"cliff_segments": []}
		var index := hills.size()
		hills.append(hill)
		for candidate in footprint:
			_raised_cells[candidate] = {"hill": index, "ramp": candidate in ramps}
		raised_cell_count += footprint.size()

func _cell_height(cell: Vector2i, point: Vector2) -> float:
	if not _raised_cells.has(cell):
		return 0.0
	var data: Dictionary = _raised_cells[cell]
	var hill: Dictionary = hills[data.hill]
	if not data.ramp:
		return hill.height
	var grid := _inverse_grid * point
	var amount: float = (grid.x - hill.cell.x - hill.radius - 0.5) / RAMP_LENGTH
	return hill.height * (1.0 - clampf(amount, 0.0, 1.0))

func height_at_ground(point: Vector2) -> float:
	return _cell_height(_ground.local_to_map(point), point)

func ground_to_surface(point: Vector2) -> Vector2:
	return point - Vector2(0.0, height_at_ground(point))

func surface_to_ground(point: Vector2) -> Vector2:
	# Solve each planar ramp/top projection exactly. Lower-floor navigation is
	# clipped from this entire footprint so a screen point has one walkable height.
	for hill in hills:
		if not Rect2(hill.center - Vector2(180, 120), Vector2(400, 260)).has_point(point):
			continue
		for cell: Vector2i in hill.cells:
			var center := _ground.map_to_local(cell)
			var h := _cell_height(cell, center)
			var dy := _cell_height(cell, center + Vector2(0, 1)) - h
			var dx := _cell_height(cell, center + Vector2(1, 0)) - h
			var ground_y := (point.y + h - dy * center.y + dx * (point.x - center.x)) / (1.0 - dy)
			var candidate := Vector2(point.x, ground_y)
			var offset := candidate - center
			if absf(offset.x) / 16.0 + absf(offset.y) / 8.0 <= 1.00001:
				return candidate
	return point

func get_height_at_surface(point: Vector2) -> float:
	return maxf(0.0, surface_to_ground(point).y - point.y)

func _build_surfaces(cells: Array[Vector2i]) -> void:
	_raised_art = Node2D.new()
	_raised_art.name = "RaisedTerrain"
	_raised_art.y_sort_enabled = true
	_world.add_child(_raised_art)
	_cliff_body = StaticBody2D.new()
	_cliff_body.name = "TerrainCliffs"
	_cliff_body.set_meta("terrain_cliff", true)
	add_child(_cliff_body)
	var cliff_material := ShaderMaterial.new()
	cliff_material.shader = CLIFF_SHADER
	var flat_render := _new_mesh_data()
	var flat_nav := _new_nav_data()
	for index in hills.size():
		var hill: Dictionary = hills[index]
		var hill_nav := _new_nav_data()
		var silhouette := PackedVector2Array()
		for cell: Vector2i in hill.cells:
			var source := _cell_polygon(cell)
			var projected := PackedVector2Array()
			var volume := PackedVector2Array()
			for point in source:
				var top := point - Vector2(0, _cell_height(cell, point))
				projected.append(top)
				volume.append(top)
				volume.append(point)
			var footprint := Geometry2D.convex_hull(volume)
			if silhouette.is_empty():
				silhouette = footprint
			else:
				var merged := Geometry2D.merge_polygons(silhouette, footprint)
				if merged.size() == 1:
					silhouette = merged[0]
			_add_nav_polygon(hill_nav, projected)
			var anchor := _ground.map_to_local(cell) + CORNERS[0]
			var top_art := MeshInstance2D.new()
			top_art.name = "BlockTop"
			_raised_art.add_child(top_art)
			top_art.global_position = _ground.to_global(anchor)
			top_art.material = material
			var top_mesh := _new_mesh_data()
			_add_render_polygon(top_mesh, projected, source, anchor)
			top_art.mesh = _make_mesh(top_mesh)
			_build_cliffs(cell, source, projected, cliff_material)
		hill["silhouette"] = silhouette
		hill["navigation_region"] = _make_navigation(hill_nav, "HillNavigation%d" % index)
		var link := NavigationLink2D.new()
		link.name = "HillRamp%d" % index
		link.bidirectional = true
		link.start_position = hill.ramp_base
		var inside: Vector2 = _grid_transform * (Vector2(hill.cell) + Vector2(hill.radius + RAMP_LENGTH + 0.15, -0.5))
		link.end_position = ground_to_surface(inside)
		add_child(link)
	for cell in cells:
		if not _is_land(cell):
			continue
		var polygon := _cell_polygon(cell)
		_add_render_polygon(flat_render, polygon, polygon, Vector2.ZERO)
		if _raised_cells.has(cell):
			continue
		var pieces: Array[PackedVector2Array] = [polygon]
		for hill in hills:
			if _ground.map_to_local(cell).distance_to(hill.center) > 260:
				continue
			var clipped: Array[PackedVector2Array] = []
			for piece in pieces:
				clipped.append_array(Geometry2D.clip_polygons(piece, hill.silhouette))
			pieces = clipped
		for piece in pieces:
			_add_nav_polygon(flat_nav, piece)
	mesh = _make_mesh(flat_render)
	navigation_region = _make_navigation(flat_nav, "SurfaceNavigation")

func _build_cliffs(cell: Vector2i, source: PackedVector2Array, top: PackedVector2Array, cliff_material: ShaderMaterial) -> void:
	var hill: Dictionary = hills[_raised_cells[cell].hill]
	for edge in 4:
		var next := (edge + 1) % 4
		var a := source[edge]
		var b := source[next]
		var neighbor: Vector2i = cell + NEIGHBORS[edge]
		var low_a := _cell_height(neighbor, a)
		var low_b := _cell_height(neighbor, b)
		if _cell_height(cell, (a + b) * 0.5) <= (low_a + low_b) * 0.5 + 0.01:
			continue
		var bottom_a := a - Vector2(0, low_a)
		var bottom_b := b - Vector2(0, low_b)
		var face := PackedVector2Array([top[edge], top[next], bottom_b, bottom_a])
		hill.cliff_segments.append(PackedVector2Array([top[edge], top[next]]))
		if edge == 1 or edge == 2:
			var anchor := (a + b) * 0.5
			var art := Polygon2D.new()
			_raised_art.add_child(art)
			art.global_position = _ground.to_global(anchor)
			var local_face := PackedVector2Array()
			for point in face:
				local_face.append(point - anchor)
			art.polygon = local_face
			art.uv = PackedVector2Array([Vector2(0, 0), Vector2(18, 0), Vector2(18, 16), Vector2(0, 16)])
			art.color = Color("89603e") if edge == 1 else Color("674934")
			art.material = cliff_material
			_add_cliff_collision(face)
		else:
			var normal := (top[next] - top[edge]).orthogonal().normalized()
			_add_cliff_collision(PackedVector2Array([top[edge] + normal, top[next] + normal, top[next] - normal, top[edge] - normal]))

func _add_cliff_collision(polygon: PackedVector2Array) -> void:
	if Geometry2D.triangulate_polygon(polygon).is_empty():
		return
	var shape := CollisionPolygon2D.new()
	shape.polygon = polygon
	_cliff_body.add_child(shape)

func _new_mesh_data() -> Dictionary:
	return {"vertices": PackedVector3Array(), "uvs": PackedVector2Array(), "colors": PackedColorArray(), "indices": PackedInt32Array()}

func _add_render_polygon(data: Dictionary, projected: PackedVector2Array, source: PackedVector2Array, anchor: Vector2) -> void:
	var triangles := Geometry2D.triangulate_polygon(projected)
	var first: int = data.vertices.size()
	for index in projected.size():
		var point := projected[index] - anchor
		data.vertices.append(Vector3(point.x, point.y, 0))
		data.uvs.append(source[index])
		data.colors.append(Color(1.0 / 1.3, 1, 1, 1))
	for index in triangles:
		data.indices.append(first + index)

func _make_mesh(data: Dictionary) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data.vertices
	arrays[Mesh.ARRAY_TEX_UV] = data.uvs
	arrays[Mesh.ARRAY_COLOR] = data.colors
	arrays[Mesh.ARRAY_INDEX] = data.indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

func _new_nav_data() -> Dictionary:
	return {"vertices": PackedVector2Array(), "lookup": {}, "polygons": []}

func _add_nav_polygon(data: Dictionary, polygon: PackedVector2Array) -> void:
	var triangles := Geometry2D.triangulate_polygon(polygon)
	if triangles.is_empty():
		return
	var indices := PackedInt32Array()
	for point in polygon:
		var key := point.snapped(Vector2.ONE * 0.001)
		if not data.lookup.has(key):
			data.lookup[key] = data.vertices.size()
			data.vertices.append(key)
		indices.append(data.lookup[key])
	for triangle in range(0, triangles.size(), 3):
		data.polygons.append(PackedInt32Array([indices[triangles[triangle]], indices[triangles[triangle + 1]], indices[triangles[triangle + 2]]]))

func _make_navigation(data: Dictionary, node_name: String) -> NavigationRegion2D:
	var polygon := NavigationPolygon.new()
	polygon.vertices = data.vertices
	for triangle: PackedInt32Array in data.polygons:
		polygon.add_polygon(triangle)
	var region := NavigationRegion2D.new()
	region.name = node_name
	region.navigation_polygon = polygon
	region.use_edge_connections = false
	add_child(region)
	return region

func _cell_polygon(cell: Vector2i) -> PackedVector2Array:
	var result := PackedVector2Array()
	var center := _ground.map_to_local(cell)
	for corner in CORNERS:
		result.append(center + corner)
	return result

func _build_material() -> void:
	var used := _ground.get_used_rect()
	var lookup := Image.create(used.size.x + 2, used.size.y + 2, false, Image.FORMAT_RGBA8)
	for y in range(-1, used.size.y + 1):
		for x in range(-1, used.size.x + 1):
			var cell := used.position + Vector2i(clampi(x, 0, used.size.x - 1), clampi(y, 0, used.size.y - 1))
			var atlas := _ground.get_cell_atlas_coords(cell)
			lookup.set_pixel(x + 1, y + 1, Color(float(atlas.x) / 255.0, float(atlas.y) / 255.0, 1.0 if atlas in ProceduralWorld.GRASS_TILES else 0.0, 1.0 if _is_land(cell) else 0.0))
	var shader_material := ShaderMaterial.new()
	shader_material.shader = GROUND_SHADER
	shader_material.set_shader_parameter("tile_lookup", ImageTexture.create_from_image(lookup))
	shader_material.set_shader_parameter("terrain_atlas", (_ground.tile_set.get_source(0) as TileSetAtlasSource).texture)
	shader_material.set_shader_parameter("mask_size", Vector2(lookup.get_size()))
	shader_material.set_shader_parameter("map_origin", _ground.map_to_local(used.position))
	shader_material.set_shader_parameter("map_from_world_x", Vector2(_inverse_grid.x.x, _inverse_grid.y.x))
	shader_material.set_shader_parameter("map_from_world_y", Vector2(_inverse_grid.x.y, _inverse_grid.y.y))
	material = shader_material

func _place_details(details: TileMapLayer) -> void:
	var decoration := Node2D.new()
	decoration.name = "SurfaceDetails"
	decoration.y_sort_enabled = true
	_world.add_child(decoration)
	var atlas := details.tile_set.get_source(ProceduralWorld.SOURCE_ID) as TileSetAtlasSource
	for cell in details.get_used_cells():
		if not _is_land(cell):
			continue
		var coordinates := details.get_cell_atlas_coords(cell)
		var sprite := Sprite2D.new()
		var art := AtlasTexture.new()
		art.atlas = atlas.texture
		art.region = Rect2(Vector2(coordinates) * 32, Vector2(32, 32))
		art.filter_clip = true
		sprite.texture = art
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		decoration.add_child(sprite)
		var foot := _ground.map_to_local(cell) + Vector2(0, 7)
		sprite.global_position = _ground.to_global(foot)
		sprite.offset = Vector2(0, -8 - height_at_ground(foot))
	details.hide()

func _is_land(cell: Vector2i) -> bool:
	return _ground.get_cell_source_id(cell) >= 0 and _ground.get_cell_atlas_coords(cell) not in ProceduralWorld.WATER_TILES

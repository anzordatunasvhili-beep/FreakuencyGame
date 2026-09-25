extends SceneTree
## Exercises the actual overworld and its player, retaining tree/building
## collisions. Ambient mobs are paused so combat cannot interrupt the walk.

var _failed := false
var _ground: TileMapLayer
var _surface: Node2D
var _player: CharacterBody2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(world)
	current_scene = world
	for frame in 10:
		await physics_frame
	_ground = world.get_node("Node2D/TileMapLayer") as TileMapLayer
	_surface = _ground.get_node_or_null("TerrainSurface") as Node2D
	_player = world.get_node("Player") as CharacterBody2D
	if not _check(_surface != null, "The overworld must build its terrain surface"):
		return
	if not _check(_ground.get_meta("terrain_surface", null) == _surface, "Actors must share the ground's terrain surface"):
		return
	_check(not _ground.navigation_enabled, "Flat tile navigation must not overlap projected hill navigation")
	_check(_surface.get("navigation_region") != null, "Projected terrain needs a navigation region")
	_check(not _surface.get("hills").is_empty(), "The permanent overworld should include a few hills")
	if _failed:
		return

	_check_land_and_water()
	_check_town(world)
	_check_plateaus_and_ramps()
	_check_foot_sorting(world)
	if _failed:
		return
	for mob in get_nodes_in_group("mobs"):
		mob.set_physics_process(false)
	_player.set("can_move", false)
	if not await _wait_for_navigation():
		return
	_check_cliff_blocking()
	if _failed:
		return
	var route := _find_clear_hill_route()
	if not _check(not route.is_empty(), "No clear navigable route from flat ground to a hill summit"):
		return
	var hill: Dictionary = route["hill"]
	var base: Vector2 = route["base"]
	var summit: Vector2 = route["summit"]
	if not await _check_ramp_is_only_access(base, summit):
		return
	_player.global_position = base
	_player.velocity = Vector2.ZERO
	for frame in 3:
		await physics_frame
	_check(float(_player.get("terrain_height")) < 0.2, "Player should begin on flat ground")
	var ascent := await _walk_to(summit)
	if not _check(bool(ascent["arrived"]), "Player failed to walk onto the summit: %s" % ascent):
		return
	_check(float(ascent["peak"]) > float(hill["height"]) * 0.8, "Player height must rise while climbing")
	_check(float(_player.get("terrain_height")) > float(hill["height"]) * 0.8, "The player's body must reach the upper surface")
	var descent := await _walk_to(base)
	_check(bool(descent["arrived"]), "Player failed to walk back down: %s" % descent)
	_check(float(_player.get("terrain_height")) < 0.3, "Player height must return to zero below the hill")
	if _failed:
		return
	print("Terrain smoke test passed: %d hills, %d/%d raised land cells; player climbed %.1f px and returned to flat ground with tree collisions enabled." % [
		_surface.get("hills").size(), int(_surface.get("raised_cell_count")), int(_surface.get("land_cell_count")), float(ascent["peak"])
	])
	quit(0)


func _check_land_and_water() -> void:
	var land_count := 0
	var raised_count := 0
	for cell in _ground.get_used_cells():
		var ground_point := _ground.map_to_local(cell)
		var height := float(_surface.call("height_at_ground", ground_point))
		if _ground.get_cell_atlas_coords(cell) in ProceduralWorld.WATER_TILES:
			if not _check(absf(height) < 0.01, "Water must remain at ground level at %s" % cell):
				return
		else:
			land_count += 1
			if height > 0.01:
				raised_count += 1
	_check(land_count > 0 and raised_count > 0, "The world needs both flat land and raised land")
	_check(float(raised_count) / maxi(1, land_count) <= 0.1, "At least 90% of the land must stay flat")
	_check(int(_surface.get("land_cell_count")) == land_count, "Terrain coverage should account for all land")
	_check(float(_surface.get("raised_cell_count")) / maxi(1, land_count) <= 0.1, "Reported hill coverage must remain rare")


func _check_town(world: Node2D) -> void:
	_check(absf(float(_surface.call("height_at_ground", Vector2.ZERO))) < 0.01, "The central plaza must stay flat")
	for child in world.get_children():
		if child is not VillageBuilding:
			continue
		var anchor := _ground.to_local(child.global_position)
		for dx in [-1.0, 0.0, 1.0]:
			for dy in [-1.0, 0.0, 1.0]:
				var point := anchor + Vector2(dx, dy) * VillagePlacement.PAD_RADIUS
				if not _check(absf(float(_surface.call("height_at_ground", point))) < 0.01, "Building pads and entrances must remain flat"):
					return


func _check_plateaus_and_ramps() -> void:
	for hill: Dictionary in _surface.get("hills"):
		var center: Vector2 = hill["center"]
		var plateau_height := float(hill["height"])
		var summit_height := float(_surface.call("height_at_ground", center))
		_check(plateau_height in [16.0, 24.0], "Block hills should use discrete raised levels")
		_check(absf(summit_height - plateau_height) < 0.01, "Hill summits must be flat upper levels")
		_check(not hill["cells"].is_empty() and not hill["ramp_cells"].is_empty(), "Each plateau needs a walkable ramp")
		for cell: Vector2i in hill["cells"]:
			if cell in hill["ramp_cells"]:
				continue
			var point := _ground.map_to_local(cell)
			_check(absf(float(_surface.call("height_at_ground", point)) - plateau_height) < 0.01, "Plateau interiors must stay level rather than become rounded hills")
			_check_projection(point)
		var ramp_base: Vector2 = hill["ramp_base"]
		var ramp_top: Vector2 = hill["ramp_top"]
		var previous_height := float(_surface.call("height_at_ground", ramp_base))
		var previous_ground := ramp_base
		var previous_surface: Vector2 = _surface.call("ground_to_surface", ramp_base)
		_check(previous_height < 0.2, "Ramp entry must begin at ground level")
		for step in range(1, 65):
			var point := ramp_base.lerp(ramp_top, float(step) / 64.0)
			var projected: Vector2 = _surface.call("ground_to_surface", point)
			var height := float(_surface.call("height_at_ground", point))
			_check_projection(point)
			var ground_step := point.distance_to(previous_ground)
			_check(height + 0.1 >= previous_height, "The ramp should climb monotonically toward its plateau")
			_check(absf(height - previous_height) < ground_step * 1.5 + 0.1, "Ramps must connect levels without vertical jumps")
			_check(projected.distance_to(previous_surface) < ground_step * 2.5 + 0.1, "Walkable ramp geometry must remain continuous")
			previous_ground = point
			previous_surface = projected
			previous_height = height
		_check(absf(previous_height - plateau_height) < 0.2, "The ramp must meet the flat plateau at full height")


func _check_projection(point: Vector2) -> void:
	var projected: Vector2 = _surface.call("ground_to_surface", point)
	var restored: Vector2 = _surface.call("surface_to_ground", projected)
	var height := float(_surface.call("height_at_ground", point))
	_check(restored.distance_to(point) < 0.2, "Walkable surface projection must preserve its logical ground position")
	_check(absf(float(_surface.call("get_height_at_surface", projected)) - height) < 0.2, "Surface height must match its rendered level")
	_check(projected.distance_to(point - Vector2(0, height)) < 0.01, "The upper surface must rise by its stated height")


func _check_foot_sorting(world: Node2D) -> void:
	_check(world.y_sort_enabled, "The player and scenery must sort by their feet")
	_check(_player.y_sort_enabled, "The player's elevation wrapper must participate in world sorting")
	var grove := world.get_node("VillageTrees") as Node2D
	_check(grove.y_sort_enabled, "Tree feet must participate in the world's Y sort")
	_check(grove.z_index == _player.z_index, "Trees and the player must share a sorting layer")
	for tree: VillageTree in grove.get_children():
		var art_bottom := tree.sprite.to_global(Vector2(tree.sprite.get_rect().get_center().x, tree.sprite.get_rect().end.y))
		_check(absf(art_bottom.y - tree.global_position.y) < 0.1, "Tree draw origin must coincide with its roots")
		_check(tree.z_index == 0, "A fixed tree Z index must not override front/behind sorting")
		var tree_visuals := tree.get_node("ElevationVisuals") as Node2D
		var tree_height := float(_surface.call("get_height_at_surface", _ground.to_local(tree.global_position)))
		_check(tree.y_sort_enabled and not tree_visuals.y_sort_enabled, "Each complete tree must sort at its logical foot")
		_check(absf(tree_visuals.global_position.y - tree.global_position.y - tree_height) < 0.1, "Trees must share the player's logical elevation sorting")
	var visuals := _player.get_node("ElevationVisuals") as Node2D
	_check(not visuals.y_sort_enabled, "The player's complete visual must sort together")
	var sprite := visuals.get_node("Sprite2D") as Sprite2D
	var player_foot := sprite.to_global(Vector2(sprite.get_rect().get_center().x, sprite.get_rect().end.y))
	_check(absf(player_foot.y - _player.global_position.y) < 2.0, "Player draw origin must remain at its feet")


func _find_clear_hill_route() -> Dictionary:
	var agent := _player.get_node("NavigationAgent2D") as NavigationAgent2D
	var navigation_map := agent.get_navigation_map()
	var diagnostics := {"summit_off_map": 0, "base_off_map": 0, "no_path": 0, "partial_path": 0, "collision": 0}
	for hill: Dictionary in _surface.get("hills"):
		var center: Vector2 = hill["center"]
		var summit := _ground.to_global(_surface.call("ground_to_surface", center))
		if NavigationServer2D.map_get_closest_point(navigation_map, summit).distance_to(summit) > 2.0:
			diagnostics["summit_off_map"] += 1
			print("Hill summit=", summit, ", closest=", NavigationServer2D.map_get_closest_point(navigation_map, summit), ", height=", hill["height"])
			continue
		var base_ground: Vector2 = hill["ramp_base"]
		# Leave enough flat apron for the agent's stopping tolerance on descent.
		var ramp_top: Vector2 = hill["ramp_top"]
		base_ground += (base_ground - ramp_top).normalized() * maxf(18.0, agent.target_desired_distance + 8.0)
		var base := _ground.to_global(_surface.call("ground_to_surface", base_ground))
		if NavigationServer2D.map_get_closest_point(navigation_map, base).distance_to(base) > 2.0:
			diagnostics["base_off_map"] += 1
			continue
		var path := NavigationServer2D.map_get_path(navigation_map, base, summit, true)
		var reverse_path := NavigationServer2D.map_get_path(navigation_map, summit, base, true)
		if path.size() < 2 or reverse_path.size() < 2:
			diagnostics["no_path"] += 1
			continue
		if path[path.size() - 1].distance_to(summit) > 2.0 or reverse_path[reverse_path.size() - 1].distance_to(base) > 2.0:
			diagnostics["partial_path"] += 1
			continue
		if not _check(_path_uses_ramp(path, hill) and _path_uses_ramp(reverse_path, hill), "Navigation between levels must pass through the ramp"):
			return {}
		if _path_is_clear(path) and _path_is_clear(reverse_path):
			return {"hill": hill, "base": base, "summit": summit}
		diagnostics["collision"] += 1
	print("Terrain route diagnostics: ", diagnostics, "; navigation regions=", NavigationServer2D.map_get_regions(navigation_map).size())
	var terrain_region: NavigationRegion2D = _surface.get("navigation_region")
	print("Terrain nav vertices=", terrain_region.navigation_polygon.vertices.size(), ", polygons=", terrain_region.navigation_polygon.get_polygon_count(), ", map=", terrain_region.get_navigation_map(), ", agent map=", navigation_map, ", iteration=", NavigationServer2D.map_get_iteration_id(navigation_map))
	return {}


func _path_uses_ramp(path: PackedVector2Array, hill: Dictionary) -> bool:
	for segment in range(1, path.size()):
		var steps := maxi(1, ceili(path[segment - 1].distance_to(path[segment]) / 3.0))
		for step in range(steps + 1):
			var surface_point := _ground.to_local(path[segment - 1].lerp(path[segment], float(step) / steps))
			var height := float(_surface.call("get_height_at_surface", surface_point))
			var logical: Vector2 = _surface.call("surface_to_ground", surface_point)
			if height > float(hill["height"]) * 0.25 and height < float(hill["height"]) * 0.75 and _ground.local_to_map(logical) in hill["ramp_cells"]:
				return true
	return false


func _check_cliff_blocking() -> void:
	var cliff_body := _surface.get_node_or_null("TerrainCliffs") as StaticBody2D
	if not _check(cliff_body != null and cliff_body.get_meta("terrain_cliff", false), "Block hills need solid cliff colliders"):
		return
	var shape := _player.get_node("CollisionShape2D") as CollisionShape2D
	var space := _player.get_world_2d().direct_space_state
	for hill: Dictionary in _surface.get("hills"):
		var blocked := false
		for edge: PackedVector2Array in hill["cliff_segments"]:
			var midpoint := _ground.to_global((edge[0] + edge[1]) * 0.5)
			var normal := (edge[1] - edge[0]).normalized().orthogonal()
			for sign_value in [-1.0, 1.0]:
				var start := midpoint + normal * 22.0 * sign_value
				var finish := midpoint - normal * 22.0 * sign_value
				var ray := PhysicsRayQueryParameters2D.create(start, finish, _player.collision_mask, [_player.get_rid()])
				var hit := space.intersect_ray(ray)
				if hit.get("collider") != cliff_body:
					continue
				var collision := KinematicCollision2D.new()
				var body_transform := _player.global_transform
				body_transform.origin = start - shape.position
				if _player.test_move(body_transform, finish - start, collision) and collision.get_collider() == cliff_body:
					blocked = true
					break
			if blocked:
				break
		_check(blocked, "The player's collision body must be stopped when moving through a cliff")


func _wait_for_navigation() -> bool:
	# The large projected mesh is synchronized asynchronously by the server.
	# A physics frame alone is insufficient on slower or headless machines.
	var agent := _player.get_node("NavigationAgent2D") as NavigationAgent2D
	var hill: Dictionary = _surface.get("hills")[0]
	var summit := _ground.to_global(_surface.call("ground_to_surface", hill["center"]))
	for frame in 300:
		await physics_frame
		if NavigationServer2D.map_get_closest_point(agent.get_navigation_map(), summit).distance_to(summit) < 2.0:
			return true
	return _check(false, "Projected navigation did not synchronize within five seconds")


func _check_ramp_is_only_access(base: Vector2, summit: Vector2) -> bool:
	var links := _surface.find_children("*", "NavigationLink2D", true, false)
	if not _check(not links.is_empty(), "Plateaus need navigation links at their ramps"):
		return false
	var agent := _player.get_node("NavigationAgent2D") as NavigationAgent2D
	var navigation_map := agent.get_navigation_map()
	var iteration := NavigationServer2D.map_get_iteration_id(navigation_map)
	for link: NavigationLink2D in links:
		link.enabled = false
	if not await _wait_for_map_update(navigation_map, iteration):
		return false
	var closed_path := NavigationServer2D.map_get_path(navigation_map, base, summit, true)
	var can_bypass := not closed_path.is_empty() and closed_path[closed_path.size() - 1].distance_to(summit) < 2.0
	iteration = NavigationServer2D.map_get_iteration_id(navigation_map)
	for link: NavigationLink2D in links:
		link.enabled = true
	if not await _wait_for_map_update(navigation_map, iteration):
		return false
	return _check(not can_bypass, "Navigation must not cross a cliff or bypass a closed ramp")


func _wait_for_map_update(navigation_map: RID, previous_iteration: int) -> bool:
	for frame in 300:
		await physics_frame
		if NavigationServer2D.map_get_iteration_id(navigation_map) > previous_iteration:
			return true
	return _check(false, "Navigation did not synchronize a ramp connection change")


func _path_is_clear(path: PackedVector2Array) -> bool:
	var player_shape := _player.get_node("CollisionShape2D") as CollisionShape2D
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = player_shape.shape
	query.collision_mask = _player.collision_mask
	query.exclude = [_player.get_rid()]
	var space := _player.get_world_2d().direct_space_state
	for segment in range(1, path.size()):
		var count := maxi(1, ceili(path[segment - 1].distance_to(path[segment]) / 4.0))
		for step in range(count + 1):
			var foot := path[segment - 1].lerp(path[segment], float(step) / count)
			query.transform = Transform2D(0.0, foot + player_shape.position)
			if not space.intersect_shape(query, 1).is_empty():
				return false
	return true


func _walk_to(target: Vector2) -> Dictionary:
	var agent := _player.get_node("NavigationAgent2D") as NavigationAgent2D
	var shape := _player.get_node("CollisionShape2D") as CollisionShape2D
	var visuals := _player.get_node("ElevationVisuals") as Node2D
	var sprite := visuals.get_node("Sprite2D") as Sprite2D
	var weapon: Node2D = _player.get("weapon_controller")
	var body_offset := shape.position
	var weapon_offset := weapon.global_position - _player.global_position
	_player.set("can_move", true)
	agent.target_position = target
	var peak := float(_player.get("terrain_height"))
	var previous_height := peak
	var previous_position := _player.global_position
	var traveled := 0.0
	for frame in 900:
		await physics_frame
		var height := float(_player.get("terrain_height"))
		var expected := float(_surface.call("get_height_at_surface", _ground.to_local(_player.global_position)))
		if not _check(absf(height - expected) < 0.25, "Player terrain_height must follow the body's actual surface position"):
			return {"arrived": false, "peak": peak}
		var distance := previous_position.distance_to(_player.global_position)
		_check(absf(height - previous_height) < distance * 2.0 + 0.5, "Player elevation must change continuously while walking")
		_check(shape.position.distance_to(body_offset) < 0.01, "Climbing must keep collision attached to the player's body")
		_check((weapon.global_position - _player.global_position).distance_to(weapon_offset) < 0.01, "Climbing must keep the weapon attached to the player's body")
		_check(absf(visuals.global_position.y - _player.global_position.y - height) < 0.1, "The player must sort at its logical foot height while walking across layers")
		var rendered_foot := sprite.to_global(Vector2(sprite.get_rect().get_center().x, sprite.get_rect().end.y))
		_check(absf(rendered_foot.y - _player.global_position.y) < 2.0, "The player sprite must stay on the same projected level as its collision")
		peak = maxf(peak, height)
		traveled += distance
		previous_position = _player.global_position
		previous_height = height
		if frame > 2 and agent.is_navigation_finished():
			var tolerance := maxf(agent.target_desired_distance + 2.0, 5.0)
			return {"arrived": _player.global_position.distance_to(target) <= tolerance and traveled > 5.0, "peak": peak, "distance": _player.global_position.distance_to(target)}
	return {"arrived": false, "peak": peak, "distance": _player.global_position.distance_to(target)}


func _check(condition: bool, message: String) -> bool:
	if not condition and not _failed:
		push_error("Terrain smoke test: " + message)
		_failed = true
		quit(1)
	return condition

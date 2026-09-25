class_name MobSpawner
extends Node2D

const MOB_SCENE := preload("res://scenes/mobs/mob.tscn")

@export var ground_path: NodePath
@export var spawn_entries: Array[MobSpawnEntry] = []

@onready var ground: TileMapLayer = get_node(ground_path)

func _ready() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	_spawn_all()

func _spawn_all() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SeedManager.seed_for("main_world_mobs", 0)
	for entry in spawn_entries:
		if entry == null or entry.definition == null:
			continue
		for index in entry.count:
			var spawn_position := _find_spawn_position(entry, rng)
			if spawn_position == Vector2.INF:
				push_warning("No valid spawn found for %s" % entry.definition.display_name)
				continue
			var mob: Mob = MOB_SCENE.instantiate()
			mob.definition = entry.definition
			mob.global_position = spawn_position
			add_child(mob)

func _find_spawn_position(entry: MobSpawnEntry, rng: RandomNumberGenerator) -> Vector2:
	# Buildings and tree trunks sit over navigable terrain, so test physical
	# clearance as well as the atlas cell before accepting a spawn.
	var clearance := CircleShape2D.new()
	clearance.radius = 12.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = clearance
	query.collision_mask = 1
	for attempt in 64:
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randi_range(
			entry.minimum_spawn_distance_cells,
			entry.maximum_spawn_distance_cells
		)
		var cell := Vector2i(roundi(cos(angle) * distance), roundi(sin(angle) * distance))
		var atlas_coordinates := ground.get_cell_atlas_coords(cell)
		if atlas_coordinates == Vector2i(-1, -1) or atlas_coordinates in ProceduralWorld.WATER_TILES:
			continue
		var surface_position := ground.map_to_local(cell)
		if ground.has_meta("terrain_surface"):
			var terrain = ground.get_meta("terrain_surface")
			if is_instance_valid(terrain):
				surface_position = terrain.ground_to_surface(surface_position)
		var position := ground.to_global(surface_position)
		query.transform = Transform2D(0.0, position)
		if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			continue
		return position
	return Vector2.INF

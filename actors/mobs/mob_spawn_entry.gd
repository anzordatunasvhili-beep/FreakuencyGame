class_name MobSpawnEntry
extends Resource

@export var definition: MobDefinition
@export_range(0, 1000) var count := 4
@export_range(0, 1000) var minimum_spawn_distance_cells := 8
@export_range(1, 1000) var maximum_spawn_distance_cells := 32

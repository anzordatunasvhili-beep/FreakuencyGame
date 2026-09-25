# main.gd
# Attach to your root Node2D in main.tscn
extends Node2D

@onready var player = $Player
@onready var npc = $NPC
@onready var ground: TileMapLayer = $Node2D/TileMapLayer
@onready var details: TileMapLayer = $Node2D/TileMapLayer2

@export var world_size := Vector2i(96, 96)

func _ready() -> void:
	var world_seed := SeedManager.get_main_world_seed()
	ProceduralWorld.generate_overworld(ground, details, world_seed, world_size)
	var village_reserved := VillagePlacement.populate(ground, details, self, world_seed)
	var terrain := TerrainSurface.new()
	terrain.name = "TerrainSurface"
	ground.add_child(terrain)
	terrain.build_from_map(ground, details, village_reserved, world_seed)
	var grove := VillageTrees.scatter(ground, self, world_seed, village_reserved)
	for tree in grove.get_children():
		var base := ground.to_local(tree.global_position)
		var height := terrain.height_at_ground(base)
		tree.global_position = ground.to_global(terrain.ground_to_surface(base))
		tree.y_sort_enabled = true
		var visual := Node2D.new()
		visual.name = "ElevationVisuals"
		visual.position.y = height
		tree.add_child(visual)
		tree.sprite.reparent(visual, false)
		tree.sprite.position.y -= height
	var water := WaterSurface.new()
	water.name = "WaterSurface"
	ground.add_child(water)
	water.build_from_map(ground)
	await get_tree().process_frame
	var local_ok = SaveManager.load_local(0)
	if not local_ok:
		print("Main: fresh start, no save found")
	ItemDatabase.ensure_starter_items()
	if player and player.ability_controller:
		player.ability_controller.apply_saved_power_loadout(GameState.equipped_power_ids)
	if GameState.main_world_seed != world_seed:
		# Positions from the former static map or another seed are not safe here.
		GameState.last_position = Vector2.ZERO
	GameState.main_world_seed = world_seed

	if player and GameState.last_position != Vector2.ZERO and _safe_saved_position(terrain, GameState.last_position):
		player.position = GameState.last_position
	else:
		player.position = ground.map_to_local(Vector2i.ZERO)

	# The guide waits beside the open village square.
	npc.position = ground.map_to_local(Vector2i(4, 0))
	# NPC art is centered on its node; sort it at the visible feet too.
	var npc_sprite := npc.get_node("Sprite2D") as Sprite2D
	if npc_sprite != null:
		npc_sprite.position.y = -8.0

func _safe_saved_position(terrain: TerrainSurface, saved_position: Vector2) -> bool:
	var surface_point := ground.to_local(to_global(saved_position))
	var cell := ground.local_to_map(terrain.surface_to_ground(surface_point))
	return ground.get_cell_source_id(cell) >= 0 and ground.get_cell_atlas_coords(cell) not in ProceduralWorld.WATER_TILES and not VillagePlacement.blocks_spawn(ground, self, saved_position)

func _unhandled_input(event: InputEvent) -> void:
	# Manual save with F5
	if event.is_action_pressed("manual_save"):
		SaveManager.save_local(0)
		print("Manual save complete")

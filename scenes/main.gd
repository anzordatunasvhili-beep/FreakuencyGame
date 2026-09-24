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
	VillageTrees.scatter(ground, self, world_seed, village_reserved)
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

	if player and GameState.last_position != Vector2.ZERO and not VillagePlacement.blocks_spawn(ground, self, GameState.last_position):
		player.position = GameState.last_position
	else:
		player.position = ground.map_to_local(Vector2i.ZERO)

	# The guide waits beside the open village square.
	npc.position = ground.map_to_local(Vector2i(4, 0))

func _unhandled_input(event: InputEvent) -> void:
	# Manual save with F5
	if event.is_action_pressed("manual_save"):
		SaveManager.save_local(0)
		print("Manual save complete")

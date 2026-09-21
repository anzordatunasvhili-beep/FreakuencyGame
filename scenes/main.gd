# main.gd
# Attach to your root Node2D in main.tscn
extends Node2D

@onready var player = $Player
@onready var npc = $NPC
@onready var ground: TileMapLayer = $Node2D/TileMapLayer

@export var world_size := Vector2i(96, 96)

func _ready() -> void:
	var world_seed := SeedManager.get_main_world_seed()
	ProceduralWorld.generate_overworld(ground, world_seed, world_size)
	await get_tree().process_frame
	var local_ok = SaveManager.load_local(0)
	if not local_ok:
		print("Main: fresh start, no save found")
	if GameState.main_world_seed != world_seed:
		# Positions from the former static map or another seed are not safe here.
		GameState.last_position = Vector2.ZERO
	GameState.main_world_seed = world_seed

	if player and GameState.last_position != Vector2.ZERO:
		player.position = GameState.last_position
	else:
		player.position = ground.map_to_local(Vector2i.ZERO)

	# Stable landmark placement can later be expanded into seeded building/NPC placement.
	npc.position = ground.map_to_local(Vector2i(4, 0))

func _unhandled_input(event: InputEvent) -> void:
	# Manual save with F5
	if event.is_action_pressed("manual_save"):
		SaveManager.save_local(0)
		print("Manual save complete")

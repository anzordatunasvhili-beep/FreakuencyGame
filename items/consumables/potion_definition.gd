class_name PotionDefinition
extends ItemDefinition

@export_group("Restoration")
@export_range(0, 100_000) var health_restore := 0
@export_range(0, 100_000) var mana_restore := 0
@export_range(0, 100_000) var stamina_restore := 0

@export_group("Temporary Buff")
@export_range(0, 5) var buff_type := 0
@export var buff_value := 0.0
@export_range(0.0, 3600.0) var buff_duration := 0.0

@export_group("Use")
@export_range(0.0, 30.0) var cooldown := 2.0
@export_range(0.0, 10.0) var consume_time := 0.35

func use(game_state: Node = null) -> bool:
	var state := game_state
	if state == null:
		var tree := Engine.get_main_loop() as SceneTree
		state = tree.root.get_node_or_null("GameState") if tree else null
	return state != null and state.consume_potion(self)


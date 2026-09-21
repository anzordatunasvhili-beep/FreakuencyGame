extends Node

# This is the permanent seed for the main overworld. Changing it creates a new world.
const MAIN_WORLD_SEED := 731_946_281

func get_main_world_seed() -> int:
	return MAIN_WORLD_SEED

# The same category and instance ID always produce the same seed.
# Examples: seed_for("dungeon", 1), seed_for("maze", 4).
func seed_for(category: StringName, instance_id: int) -> int:
	var seed_text := "%d:%s:%d" % [MAIN_WORLD_SEED, category, instance_id]
	return seed_text.hash() & 0x7fffffff

# Use this when entering newly created procedural content. The counter is saved.
func next_seed(category: StringName) -> int:
	var key := String(category)
	var instance_id: int = GameState.generation_counters.get(key, 0)
	GameState.generation_counters[key] = instance_id + 1
	return seed_for(category, instance_id)

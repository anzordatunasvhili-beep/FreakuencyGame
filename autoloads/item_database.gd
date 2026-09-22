extends Node

const ITEM_PATHS := {
	&"food_apple": "res://data/items/food/apple.tres", &"food_bread": "res://data/items/food/bread.tres",
	&"food_cheese": "res://data/items/food/cheese.tres", &"food_cooked_meat": "res://data/items/food/cooked_meat.tres",
	&"food_chicken_leg": "res://data/items/food/chicken_leg.tres", &"food_soup": "res://data/items/food/soup.tres",
	&"food_salad": "res://data/items/food/salad.tres", &"food_berry_pie": "res://data/items/food/berry_pie.tres",
	&"food_mushroom_stew": "res://data/items/food/mushroom_stew.tres", &"food_honey_cake": "res://data/items/food/honey_cake.tres",
	&"potion_health": "res://data/items/potions/health_potion.tres", &"potion_mana": "res://data/items/potions/mana_potion.tres",
	&"potion_stamina": "res://data/items/potions/stamina_potion.tres", &"potion_grand_elixir": "res://data/items/potions/grand_elixir.tres",
}

const STARTER_QUANTITIES := {
	&"food_apple": 5, &"food_bread": 3, &"food_cheese": 2, &"food_cooked_meat": 2,
	&"food_chicken_leg": 2, &"food_soup": 2, &"food_salad": 2, &"food_berry_pie": 1,
	&"food_mushroom_stew": 1, &"food_honey_cake": 1, &"potion_health": 5,
	&"potion_mana": 5, &"potion_stamina": 5, &"potion_grand_elixir": 1,
}

func get_item(item_id: StringName) -> ItemDefinition:
	var path: String = ITEM_PATHS.get(item_id, "")
	return load(path) as ItemDefinition if not path.is_empty() else null

func make_inventory_entry(item: ItemDefinition, quantity: int) -> Dictionary:
	return {"item_id": String(item.item_id), "item_name": item.display_name,
		"icon_path": item.icon.resource_path if item.icon else "", "rarity": _rarity_name(item.rarity),
		"quantity": quantity, "description": item.description,
		"buy_price": item.buy_price, "sell_price": item.sell_price}

func ensure_starter_items() -> void:
	for item_id in STARTER_QUANTITIES:
		var item := get_item(item_id)
		var existing = GameState.find_inventory_entry(String(item_id))
		if item and existing != null:
			var quantity: int = existing.get("quantity", 1)
			existing.merge(make_inventory_entry(item, quantity), true)
		elif item:
			GameState.inventory.append(make_inventory_entry(item, STARTER_QUANTITIES[item_id]))
	var starter_hotbar := [&"potion_health", &"potion_mana", &"potion_stamina", &"food_apple"]
	if not GameState.starter_consumables_initialized:
		for index in starter_hotbar.size():
			GameState.hotbar[index] = String(starter_hotbar[index])
		GameState.starter_consumables_initialized = true
	GameState.inventory_changed.emit()
	GameState.hotbar_changed.emit()

func use_item(item_id: StringName) -> bool:
	var item := get_item(item_id)
	if item == null or not item.has_method("use") or not item.use(GameState):
		return false
	GameState.remove_item(String(item_id))
	return true

func _rarity_name(rarity: int) -> String:
	return ["common", "uncommon", "rare", "epic", "legendary"][clampi(rarity, 0, 4)]

# game_state.gd
# Autoload as "GameState"
extends Node

const FOOD_BUFF_NONE := 0
const FOOD_BUFF_HEALTH_REGEN := 1
const FOOD_BUFF_ATTACK := 2
const FOOD_BUFF_DEFENSE := 3
const FOOD_BUFF_SPEED := 4
const FOOD_BUFF_LUCK := 5

# ── Player Stats ──────────────────────────────────────────────
var player_name := "Beloved"
var level := 1
var hp := 100
var max_hp := 100
var mana := 50
var max_mana := 50
var gold := 0
var gems := 0
var experience := 0
var stamina := 100
var max_stamina := 100
var hunger := 100
var max_hunger := 100
var active_food_buffs: Array[Dictionary] = []
var potion_cooldowns: Dictionary = {}
var _food_regen_accumulator := 0.0

# ── Position (saved between sessions) ────────────────────────
var last_position := Vector2(0, 0)
var last_map := "main"
var main_world_seed := -1

# ── Inventory ─────────────────────────────────────────────────
# Each entry: { id, item_id, item_name, emoji, rarity, quantity }
var inventory: Array = []

# ── Hotbar slots (item_id or null) ───────────────────────────
var hotbar: Array = [null, null, null, null, null, null, null, null, null]

# ── Active missions ───────────────────────────────────────────
var active_missions: Array = []

# Tracks which procedural dungeon, maze, and activity instance comes next.
var generation_counters: Dictionary = {}
var equipped_power_ids: Array[String] = ["ember_nova", "arc_storm"]
var starter_consumables_initialized := false

# ── Signals ───────────────────────────────────────────────────
signal stats_changed
signal inventory_changed
signal hotbar_changed
signal gold_changed
signal gems_changed

func _process(delta: float) -> void:
	for potion_id in potion_cooldowns.keys():
		potion_cooldowns[potion_id] = maxf(0.0, float(potion_cooldowns[potion_id]) - delta)
		if potion_cooldowns[potion_id] <= 0.0:
			potion_cooldowns.erase(potion_id)
	var buffs_changed := false
	for index in range(active_food_buffs.size() - 1, -1, -1):
		active_food_buffs[index]["remaining"] = float(active_food_buffs[index].get("remaining", 0.0)) - delta
		if active_food_buffs[index]["remaining"] <= 0.0:
			active_food_buffs.remove_at(index)
			buffs_changed = true
	var regen_per_second := get_food_buff_total(FOOD_BUFF_HEALTH_REGEN)
	if regen_per_second > 0.0 and hp < max_hp:
		_food_regen_accumulator += regen_per_second * delta
		var regen_points := int(_food_regen_accumulator)
		if regen_points > 0:
			_food_regen_accumulator -= regen_points
			heal(regen_points)
	if buffs_changed:
		stats_changed.emit()

func get_food_buff_total(buff_type: int) -> float:
	var total := 0.0
	for buff in active_food_buffs:
		if int(buff.get("type", FOOD_BUFF_NONE)) == buff_type:
			total += float(buff.get("value", 0.0))
	return total

# ─────────────────────────────────────────────────────────────

func apply_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit()
	stats_changed.emit()

func apply_gems(amount: int) -> void:
	gems += amount
	gems_changed.emit()
	stats_changed.emit()

func apply_damage(amount: int) -> void:
	hp = clamp(hp - amount, 0, max_hp)
	stats_changed.emit()
	if hp <= 0:
		_on_player_died()

func heal(amount: int) -> void:
	hp = clamp(hp + amount, 0, max_hp)
	stats_changed.emit()

func use_mana(amount: int) -> bool:
	if mana < amount:
		return false
	mana = clamp(mana - amount, 0, max_mana)
	stats_changed.emit()
	return true

func restore_mana(amount: int) -> void:
	mana = clamp(mana + amount, 0, max_mana)
	stats_changed.emit()

func consume_food(food: Resource) -> bool:
	if food == null:
		return false
	hp = clampi(hp + food.health_restore, 0, max_hp)
	mana = clampi(mana + food.mana_restore, 0, max_mana)
	stamina = clampi(stamina + food.stamina_restore, 0, max_stamina)
	hunger = clampi(hunger + food.hunger_restore, 0, max_hunger)
	if food.buff_type != FOOD_BUFF_NONE and food.buff_duration > 0.0:
		active_food_buffs.append({
			"source": String(food.item_id),
			"type": food.buff_type,
			"value": food.buff_value,
			"remaining": food.buff_duration,
		})
	stats_changed.emit()
	return true

func consume_potion(potion: Resource) -> bool:
	if potion == null or float(potion_cooldowns.get(potion.item_id, 0.0)) > 0.0:
		return false
	hp = clampi(hp + potion.health_restore, 0, max_hp)
	mana = clampi(mana + potion.mana_restore, 0, max_mana)
	stamina = clampi(stamina + potion.stamina_restore, 0, max_stamina)
	potion_cooldowns[potion.item_id] = potion.cooldown
	if potion.buff_type != FOOD_BUFF_NONE and potion.buff_duration > 0.0:
		active_food_buffs.append({
			"source": String(potion.item_id),
			"type": potion.buff_type,
			"value": potion.buff_value,
			"remaining": potion.buff_duration,
		})
	stats_changed.emit()
	return true

func add_item(item: Dictionary) -> void:
	# Check if item already exists
	for entry in inventory:
		if entry.get("item_id") == item.get("item_id"):
			entry["quantity"] = entry.get("quantity", 1) + item.get("quantity", 1)
			inventory_changed.emit()
			return
	inventory.append(item)
	inventory_changed.emit()

func find_inventory_entry(item_id: String):
	for entry in inventory:
		if entry.get("item_id") == item_id:
			return entry
	return null

func remove_item(item_id: String) -> void:
	for i in inventory.size():
		if inventory[i].get("item_id") == item_id:
			inventory[i]["quantity"] -= 1
			if inventory[i]["quantity"] <= 0:
				inventory.remove_at(i)
			inventory_changed.emit()
			return

func set_hotbar_slot(slot: int, item_id) -> void:
	if slot >= 0 and slot < 9:
		hotbar[slot] = item_id
		hotbar_changed.emit()

func to_dict() -> Dictionary:
	return {
		"player_name": player_name,
		"level": level,
		"hp": hp,
		"max_hp": max_hp,
		"mana": mana,
		"max_mana": max_mana,
		"gold": gold,
		"gems": gems,
		"experience": experience,
		"stamina": stamina,
		"max_stamina": max_stamina,
		"hunger": hunger,
		"max_hunger": max_hunger,
		"active_food_buffs": active_food_buffs,
		"potion_cooldowns": potion_cooldowns,
		"last_position_x": last_position.x,
		"last_position_y": last_position.y,
		"last_map": last_map,
		"main_world_seed": main_world_seed,
		"hotbar": hotbar,
		"inventory": inventory,
		"active_missions": active_missions,
		"generation_counters": generation_counters,
		"equipped_power_ids": equipped_power_ids,
		"starter_consumables_initialized": starter_consumables_initialized,
	}

func from_dict(data: Dictionary) -> void:
	player_name  = data.get("player_name", "Beloved")
	level        = data.get("level", 1)
	hp           = data.get("hp", 100)
	max_hp       = data.get("max_hp", 100)
	mana         = data.get("mana", 50)
	max_mana     = data.get("max_mana", 50)
	gold         = data.get("gold", 0)
	gems         = data.get("gems", 0)
	experience   = data.get("experience", 0)
	stamina     = data.get("stamina", 100)
	max_stamina = data.get("max_stamina", 100)
	hunger      = data.get("hunger", 100)
	max_hunger  = data.get("max_hunger", 100)
	active_food_buffs.assign(data.get("active_food_buffs", []))
	potion_cooldowns = data.get("potion_cooldowns", {})
	last_position = Vector2(
		data.get("last_position_x", 0),
		data.get("last_position_y", 0)
	)
	last_map     = data.get("last_map", "main")
	main_world_seed = data.get("main_world_seed", -1)
	hotbar       = data.get("hotbar", [null,null,null,null,null,null,null,null,null])
	inventory    = data.get("inventory", [])
	active_missions = data.get("active_missions", [])
	generation_counters = data.get("generation_counters", {})
	equipped_power_ids.assign(data.get("equipped_power_ids", ["ember_nova", "arc_storm"]))
	starter_consumables_initialized = data.get("starter_consumables_initialized", false)
	stats_changed.emit()
	hotbar_changed.emit()
	inventory_changed.emit()
	gold_changed.emit()
	gems_changed.emit()

func _on_player_died() -> void:
	print("Player died — respawning")
	hp = maxi(1, int(max_hp / 2.0))
	last_position = Vector2(0, 0)
	stats_changed.emit()

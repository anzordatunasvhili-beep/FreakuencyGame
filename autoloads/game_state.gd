# game_state.gd
# Autoload as "GameState"
extends Node

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

# ── Signals ───────────────────────────────────────────────────
signal stats_changed
signal inventory_changed
signal hotbar_changed
signal gold_changed
signal gems_changed

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

func add_item(item: Dictionary) -> void:
	# Check if item already exists
	for entry in inventory:
		if entry.get("item_id") == item.get("item_id"):
			entry["quantity"] = entry.get("quantity", 1) + 1
			inventory_changed.emit()
			return
	inventory.append(item)
	inventory_changed.emit()

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
		"last_position_x": last_position.x,
		"last_position_y": last_position.y,
		"last_map": last_map,
		"main_world_seed": main_world_seed,
		"hotbar": hotbar,
		"inventory": inventory,
		"active_missions": active_missions,
		"generation_counters": generation_counters,
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

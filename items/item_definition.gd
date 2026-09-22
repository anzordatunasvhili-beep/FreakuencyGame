class_name ItemDefinition
extends Resource

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export_group("Identity")
@export var item_id: StringName
@export var display_name := "Item"
@export_multiline var description := ""
@export var icon: Texture2D
@export var rarity := Rarity.COMMON
@export var tags: Array[StringName] = []

@export_group("Inventory")
@export_range(1, 999) var max_stack := 20
@export_range(0.0, 1000.0) var weight := 0.1
@export_range(0, 1_000_000) var buy_price := 1
@export_range(0, 1_000_000) var sell_price := 0
@export_range(0, 100) var level_requirement := 0


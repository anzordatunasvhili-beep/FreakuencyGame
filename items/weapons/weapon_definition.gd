class_name WeaponDefinition
extends Resource

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export_group("Identity")
@export var weapon_id: StringName
@export var display_name := "Sword"
@export_multiline var description := ""
@export var rarity := Rarity.COMMON
@export_range(0, 1_000_000) var value := 0

@export_group("Visuals")
@export var world_texture: Texture2D
@export var inventory_texture: Texture2D
@export_range(1.0, 64.0) var orbit_radius := 18.0
@export_range(0.1, 10.0) var visual_scale := 1.0
@export var angle_offset_degrees := 0.0

@export_group("Combat Stats")
@export_range(0, 10_000) var damage_bonus := 0
@export_range(0.1, 10.0) var damage_multiplier := 1.0
@export_range(-100.0, 500.0) var range_bonus := 0.0
@export_range(0.1, 10.0) var attack_speed_multiplier := 1.0

@export_group("Future Abilities")
@export var abilities: Array[AbilityDefinition] = []


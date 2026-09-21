class_name AbilityDefinition
extends Resource

@export var ability_id: StringName
@export var display_name := "Attack"
@export var effect_texture: Texture2D
@export_range(1, 32) var frame_count := 4
@export var frame_size := Vector2i(64, 48)
@export_range(1.0, 60.0) var animation_fps := 18.0
@export_range(0, 10_000) var damage := 10
@export_range(1.0, 500.0) var range := 58.0
@export_range(1.0, 360.0) var arc_degrees := 100.0
@export_range(0.0, 30.0) var cooldown := 0.5
@export_range(0.0, 1.0) var hit_frame_ratio := 0.45
@export var effect_distance := 28.0
@export var effect_scale := 1.0
@export var rotate_with_aim := true


class_name ActorDefinition
extends Resource

@export var actor_id: StringName
@export var display_name := "Actor"
@export var sprite_sheet: Texture2D
@export_range(1, 32) var animation_columns := 4
@export_range(1, 32) var animation_rows := 4
@export_range(1.0, 30.0) var animation_fps := 6.0
@export_range(0, 1023) var default_frame := 0
@export_range(0.01, 2.0) var sprite_scale := 0.12
@export var sprite_offset := Vector2(0, -14)

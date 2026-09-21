class_name MobDefinition
extends ActorDefinition

@export_range(1, 10_000) var max_health := 20
@export_range(1.0, 500.0) var move_speed := 35.0
@export_range(8.0, 1000.0) var wander_radius := 120.0
@export_range(0.1, 30.0) var min_idle_time := 1.0
@export_range(0.1, 30.0) var max_idle_time := 3.0
@export_range(1.0, 100.0) var collision_radius := 10.0

@export_group("Combat")
@export var hostile_to_player := false
@export_range(1.0, 2000.0) var aggro_radius := 220.0
@export_range(1.0, 2000.0) var chase_leash := 420.0
@export_range(1.0, 200.0) var attack_range := 28.0
@export_range(0, 10_000) var attack_damage := 5
@export_range(0.1, 30.0) var attack_cooldown := 1.25

# Optional action-specific sheets. If omitted, sprite_sheet is used as a
# simple walking sheet for backward compatibility.
@export_group("Animation Sheets")
@export var idle_sheet: Texture2D
@export var walk_sheet: Texture2D
@export var run_sheet: Texture2D
@export var attack_sheet: Texture2D
@export var walk_attack_sheet: Texture2D
@export var run_attack_sheet: Texture2D
@export var hurt_sheet: Texture2D
@export var death_sheet: Texture2D
@export var frame_size := Vector2i.ZERO

@export_group("Direction Rows")
@export_range(0, 31) var down_row := 0
@export_range(0, 31) var side_row := 1
@export_range(0, 31) var up_row := 3
@export_range(0, 31) var left_row := 2
@export_range(0, 31) var right_row := 3
@export var use_mirrored_side := true
@export var side_art_faces_right := true

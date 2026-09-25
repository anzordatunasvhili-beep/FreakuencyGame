class_name WeaponController
extends Node2D

signal weapon_equipped(weapon: WeaponDefinition)

@export var starting_weapon: WeaponDefinition
@export var ability_controller: AbilityController
@export_range(1.0, 40.0) var orbit_turn_speed := 16.0
@export_range(0.0, 64.0) var orbit_clearance := 10.0
@export_range(0.0, 2.0) var attack_hide_time := 0.16

@onready var weapon_sprite: Sprite2D = $WeaponSprite

var equipped_weapon: WeaponDefinition
var _target_angle := 0.0
var _hide_generation := 0

func _ready() -> void:
	if ability_controller:
		ability_controller.ability_cast.connect(_on_ability_cast)
	equip(starting_weapon)

func _process(delta: float) -> void:
	rotation = lerp_angle(rotation, _target_angle, 1.0 - exp(-orbit_turn_speed * delta))
	# Draw behind the player while aiming upward and in front while aiming down.
	# Stay in the actor's world depth so the sword also disappears behind trees.
	z_index = 0
	show_behind_parent = sin(rotation) < -0.15

func set_aim_direction(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		_target_angle = direction.angle()

func equip(weapon: WeaponDefinition) -> void:
	equipped_weapon = weapon
	if weapon == null:
		weapon_sprite.texture = null
		visible = false
		if ability_controller:
			ability_controller.clear_weapon_modifiers()
		return
	visible = true
	weapon_sprite.texture = weapon.world_texture
	weapon_sprite.position = Vector2(weapon.orbit_radius + orbit_clearance, 0.0)
	weapon_sprite.rotation = deg_to_rad(weapon.angle_offset_degrees)
	weapon_sprite.scale = Vector2.ONE * weapon.visual_scale
	if ability_controller:
		ability_controller.apply_weapon(weapon)
	weapon_equipped.emit(weapon)

func _on_ability_cast(_ability: AbilityDefinition) -> void:
	_hide_generation += 1
	var generation := _hide_generation
	weapon_sprite.visible = false
	await get_tree().create_timer(attack_hide_time).timeout
	if generation == _hide_generation and equipped_weapon != null:
		weapon_sprite.visible = true

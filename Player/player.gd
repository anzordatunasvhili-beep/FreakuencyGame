# player.gd
extends CharacterBody2D

@export var agent     : NavigationAgent2D
@export var anim_tree : AnimationTree
@export var speed     : float = 100.0
@export var ability_controller: AbilityController
@export var weapon_controller: WeaponController

@onready var elevation_visuals: Node2D = $ElevationVisuals
@onready var sprite: Sprite2D = $ElevationVisuals/Sprite2D

var can_move       := true
var _state_machine
var _follow_mouse  := false
var terrain_height := 0.0
var _terrain_ground: TileMapLayer
var _sprite_ground_offset := Vector2.ZERO
var _weapon_ground_offset := Vector2.ZERO

func _ready() -> void:
	add_to_group("player")
	# The wrapper sorts at the logical foot behind/in front of cliff faces.
	# Its children compensate for height, keeping artwork on the actual body.
	y_sort_enabled = true
	elevation_visuals.y_sort_enabled = false
	_sprite_ground_offset = sprite.position
	if weapon_controller:
		_weapon_ground_offset = weapon_controller.position
	_state_machine = anim_tree.get("parameters/playback")
	position = GameState.last_position if GameState.last_position != Vector2.ZERO else Vector2(0, 0)
	_update_terrain_height()
	SaveManager.load_completed.connect(_on_save_loaded)

func _on_save_loaded(_ok: bool) -> void:
	if GameState.last_position != Vector2.ZERO:
		position = GameState.last_position
	_update_terrain_height()

func _unhandled_input(event: InputEvent) -> void:
	if not can_move:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_follow_mouse = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and ability_controller:
			ability_controller.try_cast_attack(global_position, get_global_mouse_position() - global_position)
	if ability_controller:
		var aim_direction := get_global_mouse_position() - global_position
		if event.is_action_pressed("power_1"):
			ability_controller.try_cast_power(0, global_position, aim_direction)
		elif event.is_action_pressed("power_2"):
			ability_controller.try_cast_power(1, global_position, aim_direction)

var _last_direction := Vector2.DOWN  # default facing down

func _physics_process(delta: float) -> void:
	_update_terrain_height()
	if weapon_controller:
		weapon_controller.set_aim_direction(get_global_mouse_position() - global_position)
	if not can_move:
		velocity = Vector2.ZERO
		_apply_anim("Idle", _last_direction)
		return

	if _follow_mouse:
		agent.target_position = get_global_mouse_position()

	if agent.is_navigation_finished():
		velocity = Vector2.ZERO
		_apply_anim("Idle", _last_direction)  # ← use last direction
		return

	var next      := agent.get_next_path_position()
	var direction := (next - global_position).normalized()
	var food_speed_bonus := GameState.get_food_buff_total(GameState.FOOD_BUFF_SPEED)
	velocity       = direction * speed * (1.0 + food_speed_bonus)
	_last_direction = direction  # ← save it
	move_and_slide()
	_update_terrain_height()
	_apply_anim("Run", direction)
	GameState.last_position = global_position

func _update_terrain_height() -> void:
	# Navigation, collision, aiming and saves use projected surface coordinates.
	# Only the draw-order anchor uses logical ground Y, so raised terrain can
	# occlude a lower actor without separating its artwork from its collider.
	if not is_instance_valid(_terrain_ground):
		_terrain_ground = get_parent().get_node_or_null("Node2D/TileMapLayer") as TileMapLayer
	if _terrain_ground == null or not _terrain_ground.has_meta("terrain_surface"):
		terrain_height = 0.0
	else:
		var terrain = _terrain_ground.get_meta("terrain_surface")
		terrain_height = terrain.get_height_at_surface(_terrain_ground.to_local(global_position)) if is_instance_valid(terrain) else 0.0
	var elevation_offset := Vector2(0.0, terrain_height)
	elevation_visuals.position = elevation_offset
	sprite.position = _sprite_ground_offset - elevation_offset
	if weapon_controller:
		weapon_controller.position = _weapon_ground_offset - elevation_offset

func _apply_anim(anim: String, blend: Vector2) -> void:
	anim_tree.set("parameters/Idle/blend_position", blend)
	anim_tree.set("parameters/Run/blend_position",  blend)
	_state_machine.travel(anim)

func set_dialog_open(open: bool) -> void:
	can_move = not open
	if open:
		_follow_mouse = false
		velocity = Vector2.ZERO
		_apply_anim("Idle", Vector2.ZERO)

func take_damage(amount: int) -> void:
	var food_defense := GameState.get_food_buff_total(GameState.FOOD_BUFF_DEFENSE)
	GameState.apply_damage(maxi(1, amount - roundi(food_defense)))

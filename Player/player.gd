# player.gd
extends CharacterBody2D

@export var agent     : NavigationAgent2D
@export var anim_tree : AnimationTree
@export var speed     : float = 100.0
@export var ability_controller: AbilityController

var can_move       := true
var _state_machine
var _follow_mouse  := false

func _ready() -> void:
	add_to_group("player")
	_state_machine = anim_tree.get("parameters/playback")
	position = GameState.last_position if GameState.last_position != Vector2.ZERO else Vector2(0, 0)
	SaveManager.load_completed.connect(_on_save_loaded)

func _on_save_loaded(_ok: bool) -> void:
	if GameState.last_position != Vector2.ZERO:
		position = GameState.last_position

func _unhandled_input(event: InputEvent) -> void:
	if not can_move:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_follow_mouse = event.pressed
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and ability_controller:
			ability_controller.try_cast(global_position, get_global_mouse_position() - global_position)
	for index in ability_controller.abilities.size() if ability_controller else 0:
		if event.is_action_pressed("hotbar_%d" % (index + 1)):
			ability_controller.select(index)

var _last_direction := Vector2.DOWN  # default facing down

func _physics_process(delta: float) -> void:
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
	velocity       = direction * speed
	_last_direction = direction  # ← save it
	move_and_slide()
	_apply_anim("Run", direction)
	GameState.last_position = global_position

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
	GameState.apply_damage(amount)
